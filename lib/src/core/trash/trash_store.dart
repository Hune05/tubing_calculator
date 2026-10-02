/// 휴지통(10-02): 지운 것을 30일 동안 폰에 보관했다가 저절로 비운다.
///
/// 지울 때 그 자료를 통째로(JSON) 여기에 넣고 원래 자리에서는 지운다. 복원하면 같은
/// 아이디·같은 내용으로 원래 자리에 다시 쓴다. 무엇을 어떻게 다시 쓸지는 화면 쪽
/// `trash_kinds.dart`가 종류(kind)마다 정한다. 여기서는 보관·목록·기한만 다룬다.
///
/// 이 폰에만 보관한다(다른 폰에서 지운 것은 그 폰의 휴지통에 있다).
library;

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 휴지통에 두는 날 수.
const int kTrashKeepDays = 30;

class TrashEntry {
  final String id;

  /// 자료 종류(예: cutting_project, pt_record). 복원할 곳을 정한다.
  final String kind;

  /// 목록에 보이는 이름(예: 프로젝트 이름).
  final String title;

  /// 덧붙이는 글(예: "컷팅 기록 12개"). 없으면 빈 글.
  final String subtitle;
  final DateTime deletedAt;

  /// 복원에 쓰는 자료(종류마다 모양이 다르다).
  final Map<String, dynamic> data;

  const TrashEntry({
    required this.id,
    required this.kind,
    required this.title,
    this.subtitle = '',
    required this.deletedAt,
    required this.data,
  });

  /// 저절로 지워지는 날.
  DateTime get purgeAt => deletedAt.add(const Duration(days: kTrashKeepDays));

  /// 저절로 지워질 때까지 남은 날(0이면 오늘).
  int daysLeft(DateTime now) {
    final d = purgeAt.difference(now).inHours;
    return d <= 0 ? 0 : (d / 24).ceil();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'title': title,
    'subtitle': subtitle,
    'deletedAt': deletedAt.toIso8601String(),
    'data': data,
  };

  static TrashEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final at = DateTime.tryParse('${raw['deletedAt']}');
    final data = raw['data'];
    if (at == null || raw['id'] == null || raw['kind'] == null || data is! Map) return null;
    return TrashEntry(
      id: '${raw['id']}',
      kind: '${raw['kind']}',
      title: '${raw['title'] ?? ''}',
      subtitle: '${raw['subtitle'] ?? ''}',
      deletedAt: at,
      data: Map<String, dynamic>.from(data),
    );
  }
}

/// Firestore 값(Timestamp 등)을 JSON에 넣을 수 있게 바꾼다.
dynamic trashEncode(dynamic v) {
  if (v is Timestamp) return {'__ts': v.toDate().toIso8601String()};
  if (v is DateTime) return {'__ts': v.toIso8601String()};
  if (v is GeoPoint) return {'__geo': [v.latitude, v.longitude]};
  if (v is DocumentReference) return {'__ref': v.path};
  if (v is Map) return {for (final e in v.entries) '${e.key}': trashEncode(e.value)};
  if (v is List) return v.map(trashEncode).toList();
  return v;
}

/// [trashEncode]로 바꾼 것을 Firestore 값으로 되돌린다.
dynamic trashDecode(dynamic v) {
  if (v is Map) {
    if (v.length == 1 && v.containsKey('__ts')) {
      final d = DateTime.tryParse('${v['__ts']}');
      if (d != null) return Timestamp.fromDate(d);
    }
    if (v.length == 1 && v['__geo'] is List && (v['__geo'] as List).length == 2) {
      final g = v['__geo'] as List;
      return GeoPoint((g[0] as num).toDouble(), (g[1] as num).toDouble());
    }
    if (v.length == 1 && v['__ref'] is String) {
      return FirebaseFirestore.instance.doc(v['__ref'] as String);
    }
    return {for (final e in v.entries) '${e.key}': trashDecode(e.value)};
  }
  if (v is List) return v.map(trashDecode).toList();
  return v;
}

/// 휴지통 목록(폰 저장). 최신이 앞.
class TrashStore {
  static const String key = 'trash_v1';

  /// 시험에서 시간을 정할 때.
  static DateTime Function() now = DateTime.now;

  // 같은 순간에 둘을 넣어도 번호가 겹치지 않게.
  static int _seq = 0;

  /// 기한(30일)이 지난 것은 [onExpired]를 부른 뒤(파일 지우기 등) 뺀다.
  static Future<List<TrashEntry>> load({Future<void> Function(TrashEntry e)? onExpired}) async {
    final p = await SharedPreferences.getInstance();
    final list = <TrashEntry>[];
    try {
      final raw = jsonDecode(p.getString(key) ?? '[]');
      if (raw is List) {
        for (final r in raw) {
          final e = TrashEntry.fromJson(r);
          if (e != null) list.add(e);
        }
      }
    } catch (_) {}
    final t = now();
    final keep = <TrashEntry>[];
    var changed = false;
    for (final e in list) {
      if (!t.isBefore(e.purgeAt)) {
        changed = true;
        try {
          await onExpired?.call(e);
        } catch (_) {}
      } else {
        keep.add(e);
      }
    }
    keep.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
    if (changed) await _save(keep);
    return keep;
  }

  static Future<void> _save(List<TrashEntry> list) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(key, jsonEncode([for (final e in list) e.toJson()]));
  }

  /// 휴지통에 넣고 그 항목을 돌려준다. [data]는 JSON으로 저장할 수 있어야 한다
  /// (Firestore 값은 [trashEncode]를 거칠 것).
  static Future<TrashEntry> add({
    required String kind,
    required String title,
    String subtitle = '',
    required Map<String, dynamic> data,
  }) async {
    final at = now();
    final e = TrashEntry(
      id: '${kind}_${at.microsecondsSinceEpoch}_${_seq++}',
      kind: kind,
      title: title,
      subtitle: subtitle,
      deletedAt: at,
      data: data,
    );
    final list = await load();
    await _save([e, ...list]);
    return e;
  }

  /// 휴지통에서 뺀다(복원했거나 완전히 지웠을 때).
  static Future<void> remove(String id) async {
    final list = await load();
    await _save([for (final e in list) if (e.id != id) e]);
  }

  /// 전부 뺀다(휴지통 비우기).
  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(key);
  }
}
