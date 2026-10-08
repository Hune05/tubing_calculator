import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

// 🚀 내 개인 일정을 파일로 내보내고 다시 가져오기 위한 순수한 계산(파일·서버 작업은 화면이 한다).
// test/schedule_backup_test.dart 가 규칙을 지킨다.

const String kPersonalBackupKind = 'personal_schedules';

typedef PersonalDoc = ({String id, Map<String, dynamic> data});

// 서버 시간(Timestamp)은 파일에 그대로 못 쓰므로 글(ISO 시각)로 바꾼다.
dynamic _plain(dynamic v) {
  if (v is Timestamp) return v.toDate().toIso8601String();
  if (v is DateTime) return v.toIso8601String();
  if (v is Map) {
    return {for (final e in v.entries) e.key.toString(): _plain(e.value)};
  }
  if (v is List) return [for (final e in v) _plain(e)];
  return v;
}

/// 개인 일정들을 백업 파일 내용(JSON 글)으로 만든다.
String encodePersonalSchedules(List<PersonalDoc> docs, DateTime exportedAt) {
  return const JsonEncoder.withIndent('  ').convert({
    'app': 'tubing_calculator',
    'kind': kPersonalBackupKind,
    'exportedAt': exportedAt.toIso8601String(),
    'items': [
      for (final d in docs) {'id': d.id, 'data': _plain(d.data)},
    ],
  });
}

class PersonalBackup {
  final List<PersonalDoc> items;
  final int skipped; // 읽을 수 없어서 건너뛴 항목 수
  final DateTime? exportedAt;
  PersonalBackup(this.items, this.skipped, this.exportedAt);
}

/// 백업 파일 내용을 읽는다(저장하지 않음). 이 앱의 개인 일정 백업이 아니면 FormatException.
/// 날짜(dateTime)가 없거나 읽을 수 없는 항목은 건너뛰고 [PersonalBackup.skipped]에 센다.
PersonalBackup parsePersonalSchedules(String text) {
  final dynamic j;
  try {
    j = jsonDecode(text);
  } catch (_) {
    throw const FormatException('백업 파일을 읽을 수 없습니다.');
  }
  if (j is! Map ||
      j['app'] != 'tubing_calculator' ||
      j['kind'] != kPersonalBackupKind ||
      j['items'] is! List) {
    throw const FormatException('이 앱의 내 일정 백업 파일이 아닙니다.');
  }
  final items = <PersonalDoc>[];
  var skipped = 0;
  for (final raw in j['items'] as List) {
    if (raw is! Map || raw['id'] is! String || raw['data'] is! Map) {
      skipped++;
      continue;
    }
    final data = Map<String, dynamic>.from(raw['data'] as Map);
    final dt = data['dateTime'];
    if (dt is! String || DateTime.tryParse(dt) == null) {
      skipped++;
      continue;
    }
    items.add((id: raw['id'] as String, data: data));
  }
  return PersonalBackup(
    items,
    skipped,
    DateTime.tryParse(j['exportedAt']?.toString() ?? ''),
  );
}

/// 가져올 때 쓸 문서 번호. 내 일정(주인이 나)이면 같은 번호로 되돌리고, 남이 보낸 일정은
/// 그 번호로 만든 내 사본 번호를 쓴다.
/// 10-09 사용자 결정: 예전에는 남이 보낸 일정도 같은 번호에 주인만 나로 바꿔 써서 보낸 사람의
/// 일정을 빼앗았다. 사본 번호는 늘 같아서 같은 파일을 또 가져오면 사본을 덮고 겹치지 않는다.
String importDocId(PersonalDoc d, String me) {
  final owner = (d.data['owner'] ?? '').toString().trim();
  if (owner.isEmpty || owner == me.trim()) return d.id;
  final who = me.trim().replaceAll(RegExp(r'[/\\]'), '_');
  return 'copy_${who}_${d.id}';
}

/// 가져오면 무엇이 되는지: 새로 생기는 일정 / 같은 것을 덮어쓰는 일정(제목 목록).
/// [me]를 주면 [importDocId]로 쓸 번호를 기준으로 센다.
({List<String> added, List<String> overwritten}) planPersonalRestore(
  PersonalBackup b,
  Set<String> existingIds, {
  String? me,
}) {
  final added = <String>[], over = <String>[];
  for (final d in b.items) {
    final t = (d.data['title']?.toString() ?? '').trim();
    final name = t.isEmpty ? '제목 없음' : t;
    final id = me == null ? d.id : importDocId(d, me);
    (existingIds.contains(id) ? over : added).add(name);
  }
  return (added: added, overwritten: over);
}

/// 가져올 때 서버에 쓸 내용: 옛 시각 필드는 빼고(저장할 때 새로 찍는다) 주인은 지금 사용자로 맞춘다.
Map<String, dynamic> dataForRestore(Map<String, dynamic> data, String owner) {
  final out = Map<String, dynamic>.from(data)
    ..remove('createdAt')
    ..remove('updatedAt');
  out['owner'] = owner;
  return out;
}
