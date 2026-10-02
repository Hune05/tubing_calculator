// 휴지통 종류별 넣기·복원·완전 삭제(10-02). 보관 자체는 core/trash/trash_store.dart.
//
// - 폰에 저장되는 기록(압력 시험·교정·축 정렬·안전 점검·벤딩 실측·장비): JSON 통째로 보관,
//   복원은 같은 아이디로 다시 저장.
// - 도면: 폴더를 휴지통 폴더로 옮겨 두고, 복원하면 되돌려 놓는다. 30일 지나면 폴더를 지운다.
// - 서버(Firestore) 문서(컷팅·형강·작업 일지 프로젝트, 배치도): 문서와 딸린 기록(하위
//   컬렉션)을 통째로 읽어 보관한 뒤 지우고, 복원하면 같은 아이디로 다시 쓴다.
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/common_widgets/app_components.dart';
import '../../core/trash/trash_store.dart';
import '../alignment/alignment_record.dart';
import '../bend_check/bend_check_model.dart';
import '../drawing_viewer/drawing_models.dart';
import '../drawing_viewer/drawing_store.dart';
import '../equipment/equipment_model.dart';
import '../equipment/equipment_reminders.dart';
import '../equipment/equipment_store.dart';
import '../instrument/cal_record.dart';
import '../pressure_test/test_record.dart';
import '../safety/safety_check_model.dart';

/// 휴지통 종류.
abstract final class TrashKind {
  static const ptRecord = 'pt_record';
  static const calRecord = 'cal_record';
  static const alignRecord = 'align_record';
  static const safetyRecord = 'safety_record';
  static const bendCheck = 'bend_check';
  static const equipment = 'equipment';
  static const drawing = 'drawing';
  static const cuttingProject = 'cutting_project';
  static const steelProject = 'steel_project';
  static const workProject = 'work_project';
  static const layout = 'layout';
}

/// 휴지통 목록에 보이는 종류 이름과 아이콘.
(String, IconData) trashKindLabel(String kind) => switch (kind) {
  TrashKind.ptRecord => ('압력 시험 기록', Icons.speed_rounded),
  TrashKind.calRecord => ('교정 기록', Icons.tune_rounded),
  TrashKind.alignRecord => ('축 정렬 기록', Icons.straighten_rounded),
  TrashKind.safetyRecord => ('안전 점검 기록', Icons.health_and_safety_outlined),
  TrashKind.bendCheck => ('벤딩 실측 기록', Icons.architecture_rounded),
  TrashKind.equipment => ('장비', Icons.handyman_outlined),
  TrashKind.drawing => ('도면', Icons.picture_as_pdf_outlined),
  TrashKind.cuttingProject => ('튜브 컷팅 프로젝트', Icons.content_cut_rounded),
  TrashKind.steelProject => ('형강 컷팅 프로젝트', Icons.view_column_outlined),
  TrashKind.workProject => ('작업 일지 프로젝트', Icons.assignment_outlined),
  TrashKind.layout => ('작업 배치도', Icons.dashboard_outlined),
  _ => ('기타', Icons.delete_outline_rounded),
};

/// 시험에서 가짜 서버를 넣을 때.
FirebaseFirestore Function() trashDb = () => FirebaseFirestore.instance;

// ───────────── 폰에 저장되는 기록 ─────────────

Future<TrashEntry> trashPtRecord(PtRecord r, {required String title}) async {
  final e = await TrashStore.add(kind: TrashKind.ptRecord, title: title, data: r.toJson());
  await PtRecordStore.delete(r.id);
  return e;
}

Future<TrashEntry> trashCalRecord(CalRecord r, {required String title}) async {
  final e = await TrashStore.add(kind: TrashKind.calRecord, title: title, data: r.toJson());
  await CalRecordStore.delete(r.id);
  return e;
}

Future<TrashEntry> trashAlignRecord(AlignRecord r, {required String title}) async {
  final e = await TrashStore.add(kind: TrashKind.alignRecord, title: title, data: r.toJson());
  await AlignStore.delete(r.id);
  return e;
}

Future<TrashEntry> trashSafetyRecord(SafetyRecord r, {required String title}) async {
  final e = await TrashStore.add(kind: TrashKind.safetyRecord, title: title, data: r.toJson());
  await deleteSafetyRecord(r.id);
  return e;
}

Future<TrashEntry> trashBendCheck(BendCheck c, {required String title}) async {
  final e = await TrashStore.add(kind: TrashKind.bendCheck, title: title, data: c.toJson());
  await deleteBendCheck(c.id);
  return e;
}

Future<TrashEntry> trashEquipment(Equipment q) async {
  final e = await TrashStore.add(
    kind: TrashKind.equipment,
    title: q.name,
    subtitle: q.assetNo,
    data: q.toJson(),
  );
  await EquipmentStore.delete(q.id);
  await cancelEquipmentReminders(q.id);
  return e;
}

// ───────────── 도면(파일) ─────────────

Future<Directory> _drawingTrashDir(String id) async {
  final base = await DrawingStore.baseDir();
  return Directory('${base.parent.path}/drawings_trash/$id');
}

/// 도면을 휴지통으로: 폴더를 옮겨 두고 목록에서 뺀다.
Future<TrashEntry> trashDrawing(DrawingDoc d) async {
  final from = await DrawingStore.dirOf(d.id);
  final to = await _drawingTrashDir(d.id);
  if (await from.exists()) {
    await to.parent.create(recursive: true);
    if (await to.exists()) await to.delete(recursive: true);
    await from.rename(to.path);
  }
  final e = await TrashStore.add(kind: TrashKind.drawing, title: d.title.isNotEmpty ? d.title : d.name, data: d.toJson());
  await DrawingStore.delete(d.id); // 폴더는 이미 옮겼으니 목록에서만 빠진다
  return e;
}

// ───────────── 서버 문서 ─────────────

/// 서버 문서 하나와 딸린 기록([subcollections])을 휴지통에 넣고 지운다.
Future<TrashEntry> trashFirestoreDoc({
  required String kind,
  required String title,
  String subtitle = '',
  required DocumentReference<Map<String, dynamic>> ref,
  List<String> subcollections = const [],
}) async {
  // 통신이 없으면 폰에 남아 있는 것(캐시)으로 읽는다.
  final snap = await _orCache(() => ref.get(), () => ref.get(const GetOptions(source: Source.cache)));
  final subs = <String, Map<String, dynamic>>{};
  final toDelete = <DocumentReference>[];
  for (final name in subcollections) {
    final c = ref.collection(name);
    final q = await _orCache(() => c.get(), () => c.get(const GetOptions(source: Source.cache)));
    subs[name] = {for (final d in q.docs) d.id: trashEncode(d.data())};
    toDelete.addAll(q.docs.map((d) => d.reference));
  }
  final e = await TrashStore.add(
    kind: kind,
    title: title,
    subtitle: subtitle,
    data: {'path': ref.path, 'doc': trashEncode(snap.data() ?? <String, dynamic>{}), 'subs': subs},
  );
  toDelete.add(ref);
  await _commitChunks(toDelete.map((r) => (WriteBatch b) => b.delete(r)).toList());
  return e;
}

/// 서버에서 읽되, 5초 안에 안 되면(통신 없음) 폰에 남은 것으로.
Future<T> _orCache<T>(Future<T> Function() server, Future<T> Function() cache) async {
  try {
    return await server().timeout(const Duration(seconds: 5));
  } catch (_) {
    return cache();
  }
}

/// 한 번에 500개까지라 나눠서 쓴다. 통신이 없으면 서버 답을 기다리지 않는다: 쓰기는 폰에
/// 쌓였다가 통신되면 순서대로 올라가므로(지우기 뒤 복원도 순서가 지켜진다) 5초만 기다린다.
Future<void> _commitChunks(List<void Function(WriteBatch)> ops) async {
  for (var i = 0; i < ops.length; i += 450) {
    final b = trashDb().batch();
    for (final op in ops.skip(i).take(450)) {
      op(b);
    }
    await b.commit().timeout(const Duration(seconds: 5), onTimeout: () {});
  }
}

Future<void> _restoreFirestore(Map<String, dynamic> data) async {
  final ref = trashDb().doc('${data['path']}');
  final ops = <void Function(WriteBatch)>[
    (b) => b.set(ref, Map<String, dynamic>.from(trashDecode(data['doc']) as Map)),
  ];
  final subs = data['subs'];
  if (subs is Map) {
    for (final s in subs.entries) {
      final docs = s.value;
      if (docs is! Map) continue;
      for (final d in docs.entries) {
        final v = Map<String, dynamic>.from(trashDecode(d.value) as Map);
        ops.add((b) => b.set(ref.collection('${s.key}').doc('${d.key}'), v));
      }
    }
  }
  await _commitChunks(ops);
}

// ───────────── 복원·완전 삭제 ─────────────

/// 휴지통에서 원래 자리로 되돌리고 휴지통에서 뺀다.
Future<void> restoreTrash(TrashEntry e) async {
  final d = e.data;
  switch (e.kind) {
    case TrashKind.ptRecord:
      await PtRecordStore.put(PtRecord.fromJson(d));
    case TrashKind.calRecord:
      await CalRecordStore.put(CalRecord.fromJson(d));
    case TrashKind.alignRecord:
      await AlignStore.put(AlignRecord.fromJson(d));
    case TrashKind.safetyRecord:
      final r = SafetyRecord.fromJson(d);
      if (r != null) await addSafetyRecord(r);
    case TrashKind.bendCheck:
      final c = BendCheck.fromJson(d);
      if (c != null) await addBendCheck(c);
    case TrashKind.equipment:
      await EquipmentStore.put(Equipment.fromJson(d));
      await rescheduleEquipmentReminders(await EquipmentStore.load());
    case TrashKind.drawing:
      final doc = DrawingDoc.fromJson(d);
      final from = await _drawingTrashDir(doc.id);
      final to = await DrawingStore.dirOf(doc.id); // 빈 폴더를 만들어 준다
      if (await from.exists()) {
        if (await to.exists()) await to.delete(recursive: true);
        await from.rename(to.path);
      }
      await DrawingStore.put(doc);
    case TrashKind.cuttingProject || TrashKind.steelProject || TrashKind.workProject || TrashKind.layout:
      await _restoreFirestore(d);
    default:
      throw StateError('알 수 없는 종류: ${e.kind}');
  }
  await TrashStore.remove(e.id);
}

/// 완전히 지울 때 남은 파일을 치운다(도면 폴더). 그 밖에는 할 일이 없다.
Future<void> purgeTrashFiles(TrashEntry e) async {
  if (e.kind != TrashKind.drawing) return;
  final dir = await _drawingTrashDir('${e.data['id']}');
  if (await dir.exists()) await dir.delete(recursive: true);
}

/// 휴지통에서 하나를 완전히 지운다.
Future<void> purgeTrash(TrashEntry e) async {
  await purgeTrashFiles(e);
  await TrashStore.remove(e.id);
}

/// 휴지통 목록(30일 지난 것은 파일까지 치우고 뺀다).
Future<List<TrashEntry>> loadTrash() => TrashStore.load(onExpired: purgeTrashFiles);

/// 휴지통 비우기.
Future<void> emptyTrash() async {
  for (final e in await loadTrash()) {
    await purgeTrashFiles(e);
  }
  await TrashStore.clear();
}

/// 휴지통으로 옮긴 뒤 "휴지통으로 옮겼습니다: 이름 · 되돌리기"(6초). 되돌리면 휴지통에서 복원하고
/// [onRestored]를 부른다(목록 다시 읽기 등). 옮기기([moved])가 끝나기를 기다린 뒤 복원한다.
void showTrashUndo(
  BuildContext context,
  String name,
  Future<TrashEntry> moved, {
  Future<void> Function()? onRestored,
}) {
  if (ScaffoldMessenger.maybeOf(context) == null) return;
  final n = name.trim();
  showAppSnack(
    context,
    n.isEmpty ? '휴지통으로 옮겼습니다' : '휴지통으로 옮겼습니다: $n',
    kind: AppSnackKind.undo,
    onUndo: () async {
      try {
        await restoreTrash(await moved);
        await onRestored?.call();
      } catch (e) {
        debugPrint('휴지통 되돌리기 실패: $e');
        if (context.mounted) {
          showAppSnack(context, '되돌리지 못했습니다. 점 3개 메뉴 → 휴지통에서 복원하십시오.', kind: AppSnackKind.error);
        }
      }
    },
  );
}

/// 휴지통 옮기기가 실패하면 [handler]를 부른다(줄을 다시 보이고 알리기). 밀어서 지운 줄이
/// 화면에서 한 번 빠진 뒤에 다시 넣어야 해서 다음 그림 뒤로 미룬다.
void onTrashFailed(Future<Object?> moved, VoidCallback handler) {
  moved.then((_) {}, onError: (Object _) {
    WidgetsBinding.instance.addPostFrameCallback((_) => handler());
    WidgetsBinding.instance.scheduleFrame();
  });
}
