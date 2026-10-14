// 프로젝트 변경 기록(10-15). 저장할 때 바로 앞 모습(스냅숏)과 견줘 누가 언제 무엇을 넣고·고치고·지웠는지
// 한 줄씩 남긴다. 여러 기기 것을 아이디로 합친다(project_merge.dart의 kMergedListKeys).
//
// 저장 칸: 'changeLog': [{'id','at'(ISO),'who','kind','text'}], 최근 [kChangeLogMax]건만.
// 사진 주소 바뀜·알림 발송 표시 같은 칸은 "고침"으로 치지 않는다(사진 올리기마다 기록이 쌓였다).
library;

import 'dart:convert';

const String kChangeLogKey = 'changeLog';
const int kChangeLogMax = 300;

/// 기록 종류 → 화면 이름.
const Map<String, String> kChangeKinds = {
  'punch_lists': '이슈',
  'schedules': '일정',
  'phases': '단계',
  'daily_reports': '작업 일지',
  'contacts': '연락처',
  'project': '프로젝트',
};

/// 견줄 때 빼는 칸(바뀌어도 사람이 고친 것이 아닌 것).
const Set<String> _volatile = {
  'updatedAt',
  'image_paths',
  'image_path',
  'image_tags',
  'image_captions',
  'resolution_images',
  'receivePhotos',
  'reminderSent',
  'lastPunchReminderAt',
  'lastOverdueReminderDate',
  'lastLeadReminderDate',
  'updatedBy',
};

String _sig(Map m) {
  final keys =
      m.keys
          .map((k) => k.toString())
          .where((k) => !_volatile.contains(k))
          .toList()
        ..sort();
  return jsonEncode({for (final k in keys) k: _plain(m[k])});
}

Object? _plain(Object? v) {
  if (v is Map) {
    final ks = v.keys.map((k) => k.toString()).toList()..sort();
    return {for (final k in ks) k: _plain(v[k])};
  }
  if (v is List) return [for (final e in v) _plain(e)];
  if (v is num || v is String || v is bool || v == null) return v;
  // Timestamp·DateTime 등은 글로(같은 순간이면 같은 글).
  try {
    final d = (v as dynamic).toDate();
    if (d is DateTime) return d.toIso8601String();
  } catch (_) {}
  return v.toString();
}

String _short(Object? v, [int n = 24]) {
  final s = (v ?? '').toString().replaceAll('\n', ' ').trim();
  return s.length > n ? '${s.substring(0, n)}…' : s;
}

String _labelOf(String key, Map m) => switch (key) {
  'punch_lists' => _short(m['content']),
  'schedules' => _short(m['title'] ?? m['type']),
  'phases' => _short(m['name']),
  'daily_reports' => _short(m['date']),
  'contacts' => _short(m['name']),
  _ => '',
};

bool _doneOf(String key, Map m) => switch (key) {
  'punch_lists' => m['is_completed'] == true,
  'schedules' || 'phases' => m['isCompleted'] == true,
  'daily_reports' => m['locked'] == true,
  _ => false,
};

String? _idOf(String key, Map m) {
  if (key == 'contacts') {
    final n = '${m['name'] ?? ''}|${m['phone'] ?? ''}';
    return n == '|' ? null : n;
  }
  final id = m['id']?.toString();
  return id == null || id.isEmpty ? null : id;
}

/// 견주기용 모습: 목록마다 아이디 → (글, 끝남, 내용 서명), 그리고 바깥 칸 몇 개.
Map<String, dynamic> projectSnapshot(Map log) => {
  for (final key in kChangeKinds.keys)
    if (key != 'project')
      key: {
        for (final m in (log[key] as List?) ?? const [])
          if (m is Map && _idOf(key, m) != null)
            _idOf(key, m)!: {
              'label': _labelOf(key, m),
              'done': _doneOf(key, m),
              'sig': _sig(m),
            },
      },
  'project': {
    'name': (log['name'] ?? '').toString(),
    'status': (log['status'] ?? '').toString(),
    'archived': log['archived'] == true,
    'workType': (log['workType'] ?? '').toString(),
  },
};

/// 앞 모습([before])과 지금([after])을 견준 기록 줄. 바뀐 게 없으면 빈 목록.
List<Map<String, dynamic>> diffChanges(
  Map before,
  Map after, {
  String who = '',
  DateTime? now,
}) {
  final t = now ?? DateTime.now();
  final out = <Map<String, dynamic>>[];
  var seq = 0;
  void add(String kind, String text) => out.add({
    'id': 'chg_${t.microsecondsSinceEpoch}_${seq++}',
    'at': t.toIso8601String(),
    if (who.trim().isNotEmpty) 'who': who.trim(),
    'kind': kind,
    'text': text,
  });

  for (final key in kChangeKinds.keys) {
    if (key == 'project') continue;
    final name = kChangeKinds[key]!;
    final b = (before[key] as Map?) ?? const {};
    final a = (after[key] as Map?) ?? const {};
    for (final e in a.entries) {
      final cur = e.value as Map;
      final old = b[e.key] as Map?;
      final label = cur['label'];
      if (old == null) {
        add(key, '$name 추가: $label');
      } else if (old['sig'] != cur['sig']) {
        final wasDone = old['done'] == true, isDone = cur['done'] == true;
        if (!wasDone && isDone) {
          add(key, switch (key) {
            'punch_lists' => '이슈 처리 완료: $label',
            'daily_reports' => '작업 일지 확정: $label',
            _ => '$name 완료: $label',
          });
        } else if (wasDone && !isDone) {
          add(key, switch (key) {
            'punch_lists' => '이슈 다시 미해결: $label',
            'daily_reports' => '작업 일지 확정 풀기: $label',
            _ => '$name 완료 취소: $label',
          });
        } else {
          add(key, '$name 고침: $label');
        }
      }
    }
    for (final e in b.entries) {
      if (!a.containsKey(e.key)) {
        add(key, '$name 지움: ${(e.value as Map)['label']}');
      }
    }
  }

  final bp = (before['project'] as Map?) ?? const {};
  final ap = (after['project'] as Map?) ?? const {};
  if (bp.isNotEmpty) {
    if (bp['name'] != ap['name']) {
      add('project', '이름 바꿈: ${bp['name']} → ${ap['name']}');
    }
    if (bp['status'] != ap['status']) {
      add('project', ap['status'] == 'DONE' ? '프로젝트 완료 처리' : '프로젝트 다시 진행');
    }
    if (bp['archived'] != ap['archived']) {
      add('project', ap['archived'] == true ? '보관함으로 옮김' : '보관함에서 꺼냄');
    }
    if (bp['workType'] != ap['workType']) {
      final w = (ap['workType'] ?? '').toString();
      add('project', w.isEmpty ? '공사 유형 지움' : '공사 유형: $w');
    }
  }
  return out;
}

/// 기록 줄을 프로젝트에 더한다(최근 [kChangeLogMax]건만 남긴다).
void appendChanges(Map log, List<Map<String, dynamic>> entries) {
  if (entries.isEmpty) return;
  final list = [
    for (final e in (log[kChangeLogKey] as List?) ?? const [])
      if (e is Map) e,
    ...entries,
  ];
  list.sort(
    (a, b) => (a['at'] ?? '').toString().compareTo((b['at'] ?? '').toString()),
  );
  log[kChangeLogKey] = list.length > kChangeLogMax
      ? list.sublist(list.length - kChangeLogMax)
      : list;
}

/// 화면용: 최근 것이 먼저.
List<Map> changeLogOf(Map log) {
  final list = [
    for (final e in (log[kChangeLogKey] as List?) ?? const [])
      if (e is Map) e,
  ];
  list.sort(
    (a, b) => (b['at'] ?? '').toString().compareTo((a['at'] ?? '').toString()),
  );
  return list;
}
