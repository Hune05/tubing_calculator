import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/repositories/work_project_repository.dart';
import '../../../core/utils/error_log.dart';
import '../../../core/utils/quick_firestore.dart';
import '../../../data/ownership.dart';
import '../../my_schedule/schedule_reminders.dart'
    show schedulePersonalReminder;
import 'layout_board_models.dart' show LayoutOwner, layoutVisibleTo;
import 'layout_board_owner.dart';
import 'phase_templates.dart';
import '../../../core/database/database_helper.dart';
import '../../../data/conduit_drawings.dart';

// 🚀 [데이터 백업/복원] 내 프로젝트 전체(+단계 템플릿, 자재 즐겨찾기)를 JSON 파일 하나로
// 내보내고, 그 파일에서 다시 불러온다. 사진은 파일이 아니라 클라우드 주소(URL)로 들어
// 있어서, 클라우드에 올라간 사진만 복원 후에도 보인다(아직 못 올라간 로컬 사진은
// 이 기기에서만 보이므로 백업 전에 업로드를 끝내는 게 좋다).

const int _kBackupVersion = 1;

dynamic _enc(dynamic v) {
  if (v is Timestamp) return {'__ts': v.toDate().toIso8601String()};
  if (v is DateTime) return {'__ts': v.toIso8601String()};
  if (v is Map) {
    return {for (final e in v.entries) e.key.toString(): _enc(e.value)};
  }
  if (v is List) return v.map(_enc).toList();
  return v;
}

dynamic _dec(dynamic v) {
  if (v is Map) {
    if (v.length == 1 && v.containsKey('__ts')) {
      final d = DateTime.tryParse(v['__ts'].toString());
      if (d != null) return Timestamp.fromDate(d);
    }
    return {for (final e in v.entries) e.key.toString(): _dec(e.value)};
  }
  if (v is List) return v.map(_dec).toList();
  return v;
}

// 작업 배치도(내 목록에 보이는 것)와 내 개인 일정(로그인한 사람의 것)도 백업에 함께 담는다.
const String _kLayoutsCollectionName = 'layouts';
const String _kPersonalSchedulesName = 'personal_schedules';

/// 백업에 담을 배치도: 배치도 목록 화면과 같은 규칙으로 내 것과 주인 칸 없는 예전 것만.
/// 10-09 사용자 결정: 예전에는 layouts 전체(남의 배치도까지)를 담았다.
bool layoutBelongsInBackup(Map<String, dynamic> data, LayoutOwner me) =>
    layoutVisibleTo(data, me);

/// 백업 속 배치도를 되돌릴 계획.
/// 10-09 사용자 결정: 내 목록에 보이는 것만, 서버에 이미 있는 것은 덮지 않고 없는 것만 넣는다.
/// 예전에는 모두 덮어써서 다른 기기에서 고친 배치도가 옛 내용으로 돌아가고 남의 배치도도 덮었다.
({List<({String id, Map<String, dynamic> data})> write, int kept, int others})
planLayoutRestore(List<dynamic> raw, Set<String> existingIds, LayoutOwner me) {
  final write = <({String id, Map<String, dynamic> data})>[];
  var kept = 0, others = 0;
  for (final r in raw) {
    if (r is! Map || r['id'] is! String || r['data'] is! Map) continue;
    final id = r['id'] as String;
    final data = Map<String, dynamic>.from(_dec(r['data']) as Map);
    if (!layoutBelongsInBackup(data, me)) {
      others++;
    } else if (existingIds.contains(id)) {
      kept++;
    } else {
      write.add((id: id, data: data));
    }
  }
  return (write: write, kept: kept, others: others);
}

Future<({List<dynamic> layouts, List<dynamic> schedules, bool failed})>
_collectExtras() async {
  final layouts = <dynamic>[];
  final schedules = <dynamic>[];
  bool failed = false;
  try {
    final me = await loadLayoutOwner();
    final snap = await FirebaseFirestore.instance
        .collection(_kLayoutsCollectionName)
        .get();
    for (final d in snap.docs) {
      if (!layoutBelongsInBackup(d.data(), me)) continue;
      layouts.add({'id': d.id, 'data': _enc(d.data())});
    }
  } catch (e) {
    recordError('배치도 백업', e);
    failed = true;
  }
  try {
    final worker = (await SharedPreferences.getInstance()).getString(
      'user_real_name',
    );
    if (worker != null && worker.isNotEmpty) {
      final snap = await FirebaseFirestore.instance
          .collection(_kPersonalSchedulesName)
          .where('owner', isEqualTo: worker)
          .get();
      for (final d in snap.docs) {
        schedules.add({'id': d.id, 'data': _enc(d.data())});
      }
    }
  } catch (e) {
    recordError('내 일정 백업', e);
    failed = true;
  }
  return (layouts: layouts, schedules: schedules, failed: failed);
}

// ───────────── 도면 보관함(튜브·전선관) ─────────────
// 🚀 [고침] 예전에는 튜브 보관함(폰 DB의 history 표)과 전선관 보관함(폰 설정의
// conduit_saved_drawings_v1)이 어떤 백업에도 안 들어가, 앱을 지우거나 폰을 바꾸면
// 저장해 둔 도면이 모두 사라졌다. 백업 파일에 같이 넣고, 되돌릴 때는 없는 것만 더한다.

/// 튜브 보관함 읽기·쓰기(테스트에서 바꿔 끼운다).
@visibleForTesting
Future<List<Map<String, dynamic>>> Function() tubeDrawingsReader = () =>
    DatabaseHelper.instance.getHistory();
@visibleForTesting
Future<void> Function(Map<String, dynamic> row) tubeDrawingWriter = (row) =>
    DatabaseHelper.instance.insertHistory(row);

const List<String> _kTubeDrawingCols = [
  'date',
  'bend_data',
  'p_to_p',
  'pipe_size',
  'total_length',
];

String _tubeDrawingKey(Map r) =>
    [for (final c in _kTubeDrawingCols) r[c]?.toString() ?? ''].join('\u001F');

/// 백업에 넣을 튜브 도면(폰 DB의 번호 칸은 뺀다). 못 읽으면 빈 목록.
Future<List<Map<String, dynamic>>> _tubeDrawingsForBackup() async {
  try {
    return [
      for (final r in await tubeDrawingsReader())
        {for (final c in _kTubeDrawingCols) c: r[c]},
    ];
  } catch (e) {
    recordError('튜브 보관함 백업', e);
    return const [];
  }
}

Future<List<Map<String, dynamic>>> _conduitDrawingsForBackup() async {
  try {
    return [for (final d in await loadConduitDrawings()) d.toJson()];
  } catch (e) {
    recordError('전선관 보관함 백업', e);
    return const [];
  }
}

/// 백업의 도면을 보관함에 되돌린다. 이미 있는 것은 건너뛴다. 더한 개수를 돌려준다.
Future<({int tube, int conduit})> restoreDrawings(
  Map<String, dynamic> raw,
) async {
  var tube = 0, conduit = 0;
  final tubeRows = (raw['tubeDrawings'] as List? ?? const []).whereType<Map>();
  if (tubeRows.isNotEmpty) {
    try {
      final have = {
        for (final r in await tubeDrawingsReader()) _tubeDrawingKey(r),
      };
      for (final r in tubeRows) {
        final key = _tubeDrawingKey(r);
        if (have.contains(key)) continue;
        await tubeDrawingWriter({
          for (final c in _kTubeDrawingCols) c: r[c]?.toString(),
        });
        have.add(key);
        tube++;
      }
    } catch (e) {
      recordError('튜브 보관함 복원', e);
    }
  }
  for (final j in (raw['conduitDrawings'] as List? ?? const [])) {
    try {
      final d = ConduitDrawing.fromJson(j);
      if (d == null) continue;
      final before = (await loadConduitDrawings()).length;
      await restoreConduitDrawing(d); // 같은 id가 있으면 그대로 둔다
      if ((await loadConduitDrawings()).length > before) conduit++;
    } catch (e) {
      recordError('전선관 보관함 복원', e);
    }
  }
  return (tube: tube, conduit: conduit);
}

Future<File> createBackupFile(List<Map<String, dynamic>> projects) async {
  final p = await SharedPreferences.getInstance();
  final templates = (await loadPhaseTemplates())
      .where((t) => !t.builtIn)
      .map((t) => t.toJson())
      .toList();
  final extras = await _collectExtras();
  // 예전엔 통신이 없어 배치도·내 일정을 못 읽어도 빈 목록으로 "성공한" 백업 파일을 만들었고,
  // 나중에 그 파일로 되돌리면 배치도·내 일정이 모두 사라졌다.
  if (extras.failed) {
    throw Exception('배치도·내 일정을 불러오지 못해 백업을 만들지 않았습니다. 통신을 확인하십시오.');
  }
  final data = {
    'app': 'tubing_calculator',
    'version': _kBackupVersion,
    'exportedAt': DateTime.now().toIso8601String(),
    'projects': projects.map(_enc).toList(),
    'templates': templates,
    'favMaterials': p.getStringList('fav_materials_v1') ?? [],
    'layouts': extras.layouts,
    'personalSchedules': extras.schedules,
    'tubeDrawings': await _tubeDrawingsForBackup(),
    'conduitDrawings': await _conduitDrawingsForBackup(),
  };
  final dir = await getTemporaryDirectory();
  final d = DateTime.now();
  final name =
      'report_backup_${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}_${d.millisecondsSinceEpoch}.json';
  final file = File('${dir.path}/$name');
  await file.writeAsString(const JsonEncoder.withIndent(' ').convert(data));
  return file;
}

class BackupPreview {
  final int projects;
  final int templates;
  final DateTime? exportedAt;
  final Map<String, dynamic> raw;
  BackupPreview(this.projects, this.templates, this.exportedAt, this.raw);

  // 옛 백업에는 배치도·내 일정이 없어서 0으로 본다.
  int get layouts => (raw['layouts'] as List?)?.length ?? 0;
  int get schedules => (raw['personalSchedules'] as List?)?.length ?? 0;
  // 옛 백업에는 도면이 없어서 0으로 본다.
  int get tubeDrawings => (raw['tubeDrawings'] as List?)?.length ?? 0;
  int get conduitDrawings => (raw['conduitDrawings'] as List?)?.length ?? 0;
}

// 백업 안에 무엇이 들어 있는지 한 줄로("프로젝트 3건, 템플릿 1개, 배치도 2개, 내 일정 5건").
String backupContentsLine(BackupPreview p) =>
    '프로젝트 ${p.projects}건, 템플릿 ${p.templates}개'
    '${p.layouts > 0 ? ', 배치도 ${p.layouts}개' : ''}'
    '${p.schedules > 0 ? ', 내 일정 ${p.schedules}건' : ''}'
    '${p.tubeDrawings > 0 ? ', 튜브 도면 ${p.tubeDrawings}개' : ''}'
    '${p.conduitDrawings > 0 ? ', 전선관 도면 ${p.conduitDrawings}개' : ''}';

class RestoreResult {
  final int projects;
  final int layouts;
  final int schedules;
  final int tubeDrawings;
  final int conduitDrawings;
  // 배치도: 서버에 이미 있어 그대로 둔 것, 남의 것이라 뺀 것, 통신이 없어 되돌리지 못했는지.
  final int layoutsKept;
  final int layoutsOthers;
  final bool layoutsUnchecked;
  const RestoreResult(
    this.projects,
    this.layouts,
    this.schedules, {
    this.tubeDrawings = 0,
    this.conduitDrawings = 0,
    this.layoutsKept = 0,
    this.layoutsOthers = 0,
    this.layoutsUnchecked = false,
  });
}

/// 복원을 마친 뒤 보일 글.
String restoreResultText(RestoreResult r) =>
    "복원했습니다. 프로젝트 ${r.projects}건"
    "${r.layouts > 0 ? ', 배치도 ${r.layouts}개' : ''}"
    "${r.schedules > 0 ? ', 내 일정 ${r.schedules}건' : ''}"
    "${r.tubeDrawings > 0 ? ', 튜브 도면 ${r.tubeDrawings}개' : ''}"
    "${r.conduitDrawings > 0 ? ', 전선관 도면 ${r.conduitDrawings}개' : ''}"
    "${r.layoutsKept > 0 ? '. 서버에 있는 배치도 ${r.layoutsKept}개는 그대로 두었습니다' : ''}"
    "${r.layoutsOthers > 0 ? '. 다른 사람 배치도 ${r.layoutsOthers}개는 뺐습니다' : ''}"
    "${r.layoutsUnchecked ? '. 통신이 없어 배치도는 되돌리지 않았습니다(통신되는 곳에서 다시 복원하십시오)' : ''}.";

// 파일 내용을 읽어 검증만 한다(저장하지 않음). 형식이 다르면 예외.
BackupPreview parseBackup(String text) {
  final j = jsonDecode(text);
  if (j is! Map || j['app'] != 'tubing_calculator' || j['projects'] is! List) {
    throw const FormatException('이 앱의 백업 파일이 아닙니다.');
  }
  return BackupPreview(
    (j['projects'] as List).length,
    (j['templates'] as List? ?? []).length,
    DateTime.tryParse(j['exportedAt']?.toString() ?? ''),
    Map<String, dynamic>.from(j),
  );
}

// 복원하면 무엇이 어떻게 되는지: 새로 들어오는 것 / 덮어쓰는 것 / 그대로 두는 것(백업에 없는 지금 프로젝트).
class RestorePlan {
  final List<String> added;
  final List<String> overwritten;
  final int untouched;
  RestorePlan(this.added, this.overwritten, this.untouched);
}

RestorePlan planRestore(BackupPreview b, List<Map<String, dynamic>> current) {
  final have = {for (final c in current) c['id']?.toString(): c};
  final added = <String>[], over = <String>[];
  final inBackup = <String>{};
  for (final raw in (b.raw['projects'] as List)) {
    if (raw is! Map || raw['id'] == null) continue;
    final id = raw['id'].toString();
    inBackup.add(id);
    final name = (raw['name']?.toString() ?? '').isEmpty
        ? '이름 없음'
        : raw['name'].toString();
    (have.containsKey(id) ? over : added).add(name);
  }
  final untouched = have.keys.where((k) => k != null && !inBackup.contains(k));
  return RestorePlan(added, over, untouched.length);
}

// 프로젝트·템플릿·즐겨찾기에 더해 배치도와 내 일정도 되돌린다.
Future<RestoreResult> restoreBackupAll(BackupPreview b) async {
  final repo = WorkProjectRepository();
  int ok = 0;
  int layoutsOk = 0, schedulesOk = 0;
  for (final raw in (b.raw['projects'] as List)) {
    try {
      final proj = Map<String, dynamic>.from(_dec(raw) as Map);
      if (proj['id'] == null) continue;
      // 10-07: 확인 창 말대로 "백업 내용으로 바꾼다"(merge: false). 예전에는 합치기라 지웠던 일지·이슈는
      // 돌아오지 않았다. 서버 응답도 기다리지 않는다(통신이 없으면 복원이 끝나지 않았다) —
      // 폰에 먼저 쓰이고 통신되면 올라간다.
      unawaited(
        repo.upsertProject(proj, merge: false).catchError((Object e) {
          debugPrint('복원 실패(건너뜀): $e');
          recordError('백업 복원', e);
        }),
      );
      ok++;
    } catch (e) {
      debugPrint('복원 실패(건너뜀): $e');
      recordError('백업 복원', e);
    }
  }
  int layoutsKept = 0, layoutsOthers = 0;
  bool layoutsUnchecked = false;
  final rawLayouts = b.raw['layouts'] as List? ?? const [];
  if (rawLayouts.isNotEmpty) {
    try {
      // 서버에 이미 있는지 알아야 덮지 않는다. 폰 사본만 읽혔으면(통신 없음) 서버에 있는 것을
      // 모를 수 있으니 배치도는 되돌리지 않는다.
      final snap = await readQueryQuick(
        FirebaseFirestore.instance.collection(_kLayoutsCollectionName),
      );
      if (snap.metadata.isFromCache) {
        layoutsUnchecked = true;
      } else {
        final plan = planLayoutRestore(
          rawLayouts,
          {for (final d in snap.docs) d.id},
          await loadLayoutOwner(),
        );
        layoutsKept = plan.kept;
        layoutsOthers = plan.others;
        for (final l in plan.write) {
          unawaited(
            FirebaseFirestore.instance
                .collection(_kLayoutsCollectionName)
                .doc(l.id)
                .set(l.data)
                .catchError((Object e) => recordError('배치도 복원', e)),
          );
          layoutsOk++;
        }
      }
    } catch (e) {
      recordError('배치도 복원', e);
      layoutsUnchecked = true;
    }
  }
  for (final raw in (b.raw['personalSchedules'] as List? ?? [])) {
    try {
      if (raw is! Map || raw['id'] is! String || raw['data'] is! Map) continue;
      final id = raw['id'] as String;
      final data = Map<String, dynamic>.from(_dec(raw['data']) as Map);
      unawaited(
        FirebaseFirestore.instance
            .collection(_kPersonalSchedulesName)
            .doc(id)
            .set(data)
            .catchError((Object e) => recordError('내 일정 복원', e)),
      );
      await schedulePersonalReminder(id, data);
      schedulesOk++;
    } catch (e) {
      recordError('내 일정 복원', e);
    }
  }
  for (final t in (b.raw['templates'] as List? ?? [])) {
    try {
      await savePhaseTemplate(
        PhaseTemplate.fromJson(Map<String, dynamic>.from(t as Map)),
      );
    } catch (_) {}
  }
  final favs = (b.raw['favMaterials'] as List? ?? [])
      .map((e) => e.toString())
      .toList();
  if (favs.isNotEmpty) {
    try {
      final p = await SharedPreferences.getInstance();
      final merged = {
        ...(p.getStringList('fav_materials_v1') ?? []),
        ...favs,
      }.toList();
      await p.setStringList('fav_materials_v1', merged);
      // 10-09: 통신이 없으면 이 쓰기에서 복원이 끝나지 않아 도면 복원·완료 알림까지 못 갔다.
      // 쓰는 곳도 예전 공용 문서가 아니라 내 설정 문서로(일지 화면 즐겨찾기와 같은 곳).
      await writeQuick(mySettingsDoc('fav_materials').set({'items': merged}));
    } catch (_) {}
  }
  final drawings = await restoreDrawings(b.raw);
  return RestoreResult(
    ok,
    layoutsOk,
    schedulesOk,
    tubeDrawings: drawings.tube,
    conduitDrawings: drawings.conduit,
    layoutsKept: layoutsKept,
    layoutsOthers: layoutsOthers,
    layoutsUnchecked: layoutsUnchecked,
  );
}

// ───────────────────────── 클라우드 자동 백업 ─────────────────────────
// 일주일에 한 번(앱을 열 때) 백업 파일을 Firebase Storage에 올리고 최근 5개만 남긴다.
const _kAutoOn = 'auto_backup_on';
const _kAutoLast = 'auto_backup_last';
const _kCloudDir = 'app_backups/my_projects';

// 이름별 폴더. 예전엔 모두 한 폴더라 두 사람이 쓰면 서로의 백업을 지웠다.
// 이름이 없으면(게스트) 예전처럼 맨 위 폴더를 쓴다.
Future<Reference> _cloudUserDir() async {
  final root = FirebaseStorage.instance.ref().child(_kCloudDir);
  final name = (await SharedPreferences.getInstance())
      .getString('user_real_name')
      ?.trim();
  return root.child(cloudBackupFolderName(name, currentUid()));
}

/// 클라우드 백업 폴더 이름. 이름이 있으면 이름, 없으면 uid, 둘 다 없으면 '_no_name'.
/// 10-09: 이름이 없는 사람은 맨 위 공용 폴더에 올리고 "최근 5개"만 남기며 지워서, 이름별 폴더가
/// 생기기 전에 올라간 다른 사람의 옛 백업까지 지웠다. 이제 맨 위 폴더에는 쓰지 않는다.
String cloudBackupFolderName(String? name, String? uid) {
  final n = name?.trim() ?? '';
  if (n.isNotEmpty && n != '로그인 필요') {
    return n.replaceAll(RegExp(r'[/\\#?\[\]]'), '_');
  }
  final u = uid?.trim() ?? '';
  return u.isEmpty ? '_no_name' : 'uid_$u';
}

/// 맨 위 공용 폴더(이름별 폴더 전) 백업인지. 다른 사람 것일 수 있어 목록에 따로 적는다.
bool isSharedFolderBackup(Reference r) => r.parent?.fullPath == _kCloudDir;

Future<bool> autoBackupEnabled() async =>
    (await SharedPreferences.getInstance()).getBool(_kAutoOn) ?? true;

Future<void> setAutoBackupEnabled(bool v) async =>
    (await SharedPreferences.getInstance()).setBool(_kAutoOn, v);

Future<DateTime?> lastAutoBackup() async {
  final s = (await SharedPreferences.getInstance()).getString(_kAutoLast);
  return s == null ? null : DateTime.tryParse(s);
}

// 올리기에 성공하면 true.
// 10-09: 통신이 없으면 putFile이 끝나지 않아 다시 시도(90초마다)가 겹쳐 쌓이고, 통신이 돌아오면
// 거의 같은 백업이 몰려 올라가 "최근 5개"의 옛 백업을 밀어냈다. 실패 때는 임시 파일도 남았다.
// 이제 2분 넘으면 그만두고(올리기 취소), 임시 파일은 늘 지운다.
Future<bool> uploadCloudBackup(List<Map<String, dynamic>> projects) async {
  File? file;
  try {
    file = await createBackupFile(projects);
    final d = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final name =
        '${d.year}${two(d.month)}${two(d.day)}_${two(d.hour)}${two(d.minute)}.json';
    final dir = await _cloudUserDir();
    final task = dir.child(name).putFile(file);
    try {
      await task.timeout(const Duration(minutes: 2));
    } on TimeoutException {
      try {
        await task.cancel();
      } catch (_) {}
      rethrow;
    }
    await (await SharedPreferences.getInstance()).setString(
      _kAutoLast,
      d.toIso8601String(),
    );
    // 오래된 것 지우기는 실패해도 백업은 된 것이다.
    try {
      final all = (await dir.listAll().timeout(const Duration(seconds: 20))).items
        ..sort((a, b) => b.name.compareTo(a.name));
      for (final old in all.skip(5)) {
        try {
          await old.delete();
        } catch (_) {}
      }
    } catch (_) {}
    return true;
  } catch (e) {
    debugPrint('클라우드 백업 실패: $e');
    recordError('클라우드 백업', e);
    return false;
  } finally {
    try {
      if (file != null && await file.exists()) await file.delete();
    } catch (_) {}
  }
}

// 자동 백업이 하나 도는 동안 또 시작하지 않는다(다시 시도 타이머와 화면 열기가 겹친다).
bool _autoBackupRunning = false;

// 백업이 필요 없거나 꺼져 있으면 null, 성공 true, 실패 false.
Future<bool?> autoBackupIfDue(List<Map<String, dynamic>> projects) async {
  if (!await autoBackupEnabled()) return null;
  // 프로젝트가 없어도 도면만 있으면 백업한다.
  if (projects.isEmpty &&
      (await _tubeDrawingsForBackup()).isEmpty &&
      (await _conduitDrawingsForBackup()).isEmpty) {
    return null;
  }
  final last = await lastAutoBackup();
  if (last != null &&
      DateTime.now().difference(last) < const Duration(days: 7)) {
    return null;
  }
  if (_autoBackupRunning) return null;
  _autoBackupRunning = true;
  try {
    return await uploadCloudBackup(projects);
  } finally {
    _autoBackupRunning = false;
  }
}

// 내 폴더 것과, 폴더를 나누기 전(맨 위 폴더) 것을 같이 보여 준다.
Future<List<Reference>> listCloudBackups() async {
  final root = FirebaseStorage.instance.ref().child(_kCloudDir);
  final mine = await _cloudUserDir();
  final items = <Reference>[...(await mine.listAll()).items];
  if (mine.fullPath != root.fullPath) {
    items.addAll((await root.listAll()).items);
  }
  return items..sort((a, b) => b.name.compareTo(a.name));
}

Future<String> downloadBackupText(Reference ref) async {
  final bytes = await ref.getData(50 * 1024 * 1024);
  if (bytes == null) throw const FormatException('백업 파일을 받지 못했습니다.');
  return utf8.decode(bytes);
}
