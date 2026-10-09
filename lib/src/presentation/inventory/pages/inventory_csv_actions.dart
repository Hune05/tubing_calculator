// 자재 현황 ⋮ 메뉴의 "엑셀(CSV)로 내보내기 / 가져오기"(10-09). 셈은 inventory_csv.dart.
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/common_widgets/app_components.dart';
import '../../../core/utils/error_text.dart';
import '../../../core/utils/quick_firestore.dart';
import 'inventory_csv.dart';

/// 지금 재고(문서 id → 내용)와 폰 사본에서 읽었는지.
typedef InventorySnapshot = ({
  Map<String, Map<String, dynamic>> docs,
  bool fromCache,
});

Future<InventorySnapshot> _readInventory() async {
  final snap = await readQueryQuick(
    FirebaseFirestore.instance.collection('inventory'),
  );
  return (
    docs: {for (final d in snap.docs) d.id: d.data()},
    fromCache: snap.metadata.isFromCache,
  );
}

/// 고른 파일의 바이트(취소하면 null).
Future<List<int>?> _pickCsvBytes() async {
  final res = await FilePicker.pickFiles(type: FileType.any, withData: true);
  if (res == null || res.files.isEmpty) return null;
  final f = res.files.first;
  return f.bytes ?? (f.path == null ? null : await File(f.path!).readAsBytes());
}

/// 재고를 CSV 파일로 만들어 공유 창을 연다(보낼 곳은 사용자가 고른다).
Future<void> exportInventoryCsv(
  BuildContext context, {
  required String? uid,
  Future<InventorySnapshot> Function()? read,
  Future<void> Function(File file)? share,
}) async {
  try {
    final inv = await (read ?? _readInventory)();
    final csv = buildInventoryCsv([
      for (final e in inv.docs.entries) (e.key, e.value),
    ], uid);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${inventoryCsvFileName(DateTime.now())}');
    await file.writeAsBytes(utf8.encode(csv));
    if (share != null) {
      await share(file);
    } else {
      // ignore: deprecated_member_use
      await Share.shareXFiles([
        XFile(file.path),
      ], text: '재고 목록(엑셀로 열립니다). 고친 뒤 "엑셀(CSV)에서 가져오기"로 넣을 수 있습니다.');
    }
  } catch (e) {
    if (context.mounted) {
      showAppSnack(
        context,
        failText('내보내지 못했습니다', e),
        kind: AppSnackKind.error,
      );
    }
  }
}

/// CSV 파일을 골라 무엇이 바뀌는지 보여 주고, "가져오기"를 누르면 재고에 쓴다.
/// 쓴 건수(취소·실패면 0).
Future<int> importInventoryCsv(
  BuildContext context, {
  required String worker,
  required String? uid,
  Future<List<int>?> Function()? pick,
  Future<InventorySnapshot> Function()? read,
  Future<int> Function(InventoryImportPlan plan, {required bool offline})?
  apply,
}) async {
  final bytes = await (pick ?? _pickCsvBytes)();
  if (bytes == null || !context.mounted) return 0;
  String text;
  try {
    text = utf8.decode(bytes);
  } catch (_) {
    await showAppNotice(
      context,
      title: '글자를 읽지 못했습니다',
      message: '엑셀에서 저장할 때 파일 형식을 "CSV UTF-8(쉼표로 분리)"로 고른 뒤 다시 가져오십시오.',
    );
    return 0;
  }
  final parsed = parseInventoryCsv(text);
  final InventorySnapshot inv;
  try {
    inv = await (read ?? _readInventory)();
  } catch (e) {
    if (context.mounted) {
      showAppSnack(
        context,
        failText('재고를 읽지 못했습니다', e),
        kind: AppSnackKind.error,
      );
    }
    return 0;
  }
  final plan = planInventoryImport(parsed, inv.docs, uid);
  if (!context.mounted) return 0;
  if (plan.isEmpty) {
    await showAppNotice(
      context,
      dialogKey: const Key('inv_csv_nothing'),
      title: '바꿀 것이 없습니다',
      message: inventoryImportSummary(plan),
    );
    return 0;
  }
  final ok = await showAppConfirm(
    context,
    title: '엑셀(CSV)에서 가져오시겠습니까?',
    message: plan.qtyChanged > 0
        ? '${inventoryImportSummary(plan)}\n\n수량이 바뀐 자재는 재고조사 기록으로 남습니다.'
        : inventoryImportSummary(plan),
    okText: '가져오기',
    okKey: const Key('inv_csv_import_ok'),
    icon: const Icon(Icons.upload_file_rounded),
  );
  if (!ok) return 0;
  try {
    final n =
        await (apply ??
            (p, {required bool offline}) => applyInventoryImport(
              p,
              worker: worker,
              uid: uid,
              offline: offline,
            ))(plan, offline: inv.fromCache);
    if (context.mounted) {
      showAppSnack(
        context,
        inv.fromCache ? '$n건을 폰에 적었습니다. 통신되면 서버로 올라갑니다.' : '$n건을 가져왔습니다.',
      );
    }
    return n;
  } catch (e) {
    if (context.mounted) {
      showAppSnack(
        context,
        failText('가져오지 못했습니다', e),
        kind: AppSnackKind.error,
      );
    }
    return 0;
  }
}
