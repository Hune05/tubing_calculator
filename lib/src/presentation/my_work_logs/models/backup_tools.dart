import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/repositories/work_project_repository.dart';
import 'phase_templates.dart';

// 🚀 [데이터 백업/복원] 내 프로젝트 전체(+단계 템플릿, 자재 즐겨찾기)를 JSON 파일 하나로
// 내보내고, 그 파일에서 다시 불러온다. 사진은 파일이 아니라 클라우드 주소(URL)로 들어
// 있어서, 클라우드에 올라간 사진만 복원 후에도 보인다(아직 못 올라간 로컬 사진은
// 이 기기에서만 보이므로 백업 전에 업로드를 끝내는 게 좋다).

const int _kBackupVersion = 1;

dynamic _enc(dynamic v) {
  if (v is Timestamp) return {'__ts': v.toDate().toIso8601String()};
  if (v is DateTime) return {'__ts': v.toIso8601String()};
  if (v is Map)
    return {for (final e in v.entries) e.key.toString(): _enc(e.value)};
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

Future<File> createBackupFile(List<Map<String, dynamic>> projects) async {
  final p = await SharedPreferences.getInstance();
  final templates = (await loadPhaseTemplates())
      .where((t) => !t.builtIn)
      .map((t) => t.toJson())
      .toList();
  final data = {
    'app': 'tubing_calculator',
    'version': _kBackupVersion,
    'exportedAt': DateTime.now().toIso8601String(),
    'projects': projects.map(_enc).toList(),
    'templates': templates,
    'favMaterials': p.getStringList('fav_materials_v1') ?? [],
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
}

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

// 같은 id의 프로젝트는 백업 내용으로 덮어쓴다. 성공한 프로젝트 수를 돌려준다.
Future<int> restoreBackup(BackupPreview b) async {
  final repo = WorkProjectRepository();
  int ok = 0;
  for (final raw in (b.raw['projects'] as List)) {
    try {
      final proj = Map<String, dynamic>.from(_dec(raw) as Map);
      if (proj['id'] == null) continue;
      await repo.upsertProject(proj);
      ok++;
    } catch (e) {
      debugPrint('복원 실패(건너뜀): $e');
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
      await FirebaseFirestore.instance
          .collection('my_project_settings')
          .doc('fav_materials')
          .set({'items': merged});
    } catch (_) {}
  }
  return ok;
}

// ───────────────────────── 클라우드 자동 백업 ─────────────────────────
// 일주일에 한 번(앱을 열 때) 백업 파일을 Firebase Storage에 올리고 최근 5개만 남긴다.
const _kAutoOn = 'auto_backup_on';
const _kAutoLast = 'auto_backup_last';
const _kCloudDir = 'app_backups/my_projects';

Future<bool> autoBackupEnabled() async =>
    (await SharedPreferences.getInstance()).getBool(_kAutoOn) ?? true;

Future<void> setAutoBackupEnabled(bool v) async =>
    (await SharedPreferences.getInstance()).setBool(_kAutoOn, v);

Future<DateTime?> lastAutoBackup() async {
  final s = (await SharedPreferences.getInstance()).getString(_kAutoLast);
  return s == null ? null : DateTime.tryParse(s);
}

// 올리기에 성공하면 true.
Future<bool> uploadCloudBackup(List<Map<String, dynamic>> projects) async {
  try {
    final file = await createBackupFile(projects);
    final d = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final name =
        '${d.year}${two(d.month)}${two(d.day)}_${two(d.hour)}${two(d.minute)}.json';
    final dir = FirebaseStorage.instance.ref().child(_kCloudDir);
    await dir.child(name).putFile(file);
    await (await SharedPreferences.getInstance()).setString(
      _kAutoLast,
      d.toIso8601String(),
    );
    final all = (await dir.listAll()).items
      ..sort((a, b) => b.name.compareTo(a.name));
    for (final old in all.skip(5)) {
      try {
        await old.delete();
      } catch (_) {}
    }
    try {
      await file.delete();
    } catch (_) {}
    return true;
  } catch (e) {
    debugPrint('클라우드 백업 실패: $e');
    return false;
  }
}

// 백업이 필요 없거나 꺼져 있으면 null, 성공 true, 실패 false.
Future<bool?> autoBackupIfDue(List<Map<String, dynamic>> projects) async {
  if (projects.isEmpty || !await autoBackupEnabled()) return null;
  final last = await lastAutoBackup();
  if (last != null &&
      DateTime.now().difference(last) < const Duration(days: 7)) {
    return null;
  }
  return uploadCloudBackup(projects);
}

Future<List<Reference>> listCloudBackups() async {
  final r = await FirebaseStorage.instance.ref().child(_kCloudDir).listAll();
  return r.items..sort((a, b) => b.name.compareTo(a.name));
}

Future<String> downloadBackupText(Reference ref) async {
  final bytes = await ref.getData(50 * 1024 * 1024);
  if (bytes == null) throw const FormatException('백업 파일을 받지 못했습니다.');
  return utf8.decode(bytes);
}
