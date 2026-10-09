// 라인 진행 보드(10-10): 프로젝트의 튜브 라인마다 단계(컷팅·벤딩 → 설치 → 서포트 → 압력시험 →
// 루프 체크)를 체크한다. 프로젝트 문서의 line_items(아이디로 합침)·line_stages(바꾼 단계 이름)에 둔다.
// 단계 체크는 단계마다 시각을 적어, 두 기기가 같은 라인의 다른 단계를 체크해도 둘 다 남는다.

/// 라인 목록 칸.
const String kLineItemsKey = 'line_items';

/// 프로젝트마다 바꾼 단계 이름 칸(없으면 [kDefaultLineStages]).
const String kLineStagesKey = 'line_stages';

const List<String> kDefaultLineStages = [
  '컷팅·벤딩',
  '설치',
  '서포트',
  '압력시험',
  '루프 체크',
];

List<String> lineStagesOf(Map log) {
  final raw = log[kLineStagesKey];
  if (raw is List) {
    final l = [
      for (final e in raw)
        if (e.toString().trim().isNotEmpty) e.toString().trim(),
    ];
    if (l.isNotEmpty) return l;
  }
  return List.of(kDefaultLineStages);
}

List<Map<String, dynamic>> lineItemsOf(Map log) => [
  for (final e in (log[kLineItemsKey] as List? ?? const []))
    if (e is Map<String, dynamic>) e else if (e is Map) Map<String, dynamic>.from(e),
];

/// 단계 체크 칸: {단계: {on, at, by}}. 풀 때도 on=false로 시각을 남긴다(합칠 때 다시 살아나지 않게).
Map<String, dynamic> _doneOf(Map line) {
  final d = line['done'];
  return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
}

bool lineStageDone(Map line, String stage) {
  final s = _doneOf(line)[stage];
  return s is Map && s['on'] == true;
}

/// 체크한 사람·때(없으면 null).
({String by, DateTime? at})? lineStageMark(Map line, String stage) {
  final s = _doneOf(line)[stage];
  if (s is! Map || s['on'] != true) return null;
  return (by: (s['by'] ?? '').toString(), at: DateTime.tryParse('${s['at']}'));
}

void setLineStage(
  Map<String, dynamic> line,
  String stage,
  bool on, {
  String who = '',
  DateTime? now,
}) {
  final at = (now ?? DateTime.now()).toIso8601String();
  final d = _doneOf(line);
  d[stage] = {'on': on, 'at': at, if (who.trim().isNotEmpty) 'by': who.trim()};
  line['done'] = d;
  line['updatedAt'] = at;
}

/// 모든 단계를 마친 라인인지.
bool lineComplete(Map line, List<String> stages) =>
    stages.isNotEmpty && stages.every((s) => lineStageDone(line, s));

String _norm(String s) => s.replaceAll(RegExp(r'\s+'), '').toUpperCase();

/// 이름이 같은 라인(띄어쓰기·대소문자 무시).
Map<String, dynamic>? findLine(Map log, String name) {
  final n = _norm(name);
  if (n.isEmpty) return null;
  for (final l in lineItemsOf(log)) {
    if (_norm('${l['name'] ?? ''}') == n) return l;
  }
  return null;
}

List<String> _tokens(String s) => s
    .toUpperCase()
    .split(RegExp(r'[^0-9A-Z가-힣]+'))
    .where((t) => t.isNotEmpty)
    .toList();

/// 계기 태그(예: PT-101)가 들어 있는 라인(예: 1F-PT-101). 이름이 같으면 그것, 아니면 태그 조각이
/// 이어서 들어 있는 라인이 딱 하나일 때만(둘 이상이면 어느 것인지 몰라 null).
Map<String, dynamic>? findLineForTag(Map log, String tag) {
  final same = findLine(log, tag);
  if (same != null) return same;
  final t = _tokens(tag);
  if (t.isEmpty) return null;
  final hits = <Map<String, dynamic>>[];
  for (final l in lineItemsOf(log)) {
    final n = _tokens('${l['name'] ?? ''}');
    for (int i = 0; i + t.length <= n.length; i++) {
      var ok = true;
      for (int j = 0; j < t.length; j++) {
        if (n[i + j] != t[j]) {
          ok = false;
          break;
        }
      }
      if (ok) {
        hits.add(l);
        break;
      }
    }
  }
  return hits.length == 1 ? hits.single : null;
}

/// 기록 종류에 맞는 단계 이름: 압력시험 기록 → "압력"·"기밀"이 든 단계,
/// 교정 기록 → "교정"이 든 단계, 없으면 "루프"가 든 단계. 맞는 단계가 없으면 null.
String? stageForRecord(List<String> stages, {required bool pressure}) {
  String? find(List<String> words) {
    for (final s in stages) {
      if (words.any(s.contains)) return s;
    }
    return null;
  }

  return pressure ? find(['압력', '기밀']) : (find(['교정']) ?? find(['루프']));
}

/// 같은 라인의 두 쪽(폰·서버)을 합친다: 이름·메모는 나중에 고친 쪽, 단계 체크는 단계마다 나중 것.
Map<String, dynamic> mergeLineItem(Map local, Map server) {
  DateTime? at(dynamic m) => m is Map ? DateTime.tryParse('${m['at'] ?? m['updatedAt']}') : null;
  final lAt = at({'at': local['updatedAt']});
  final sAt = at({'at': server['updatedAt']});
  final newer = (sAt != null && (lAt == null || sAt.isAfter(lAt))) ? server : local;
  final out = Map<String, dynamic>.from(newer);
  final ld = _doneOf(local), sd = _doneOf(server);
  final done = <String, dynamic>{};
  for (final k in {...ld.keys, ...sd.keys}) {
    final a = ld[k], b = sd[k];
    if (a == null) {
      done[k] = b;
    } else if (b == null) {
      done[k] = a;
    } else {
      final ta = at(a), tb = at(b);
      done[k] = (tb != null && (ta == null || tb.isAfter(ta))) ? b : a;
    }
  }
  out['done'] = done;
  return out;
}

/// 붙여넣은 글(엑셀 열 복사·한 줄에 하나)을 라인 이름 목록으로. 빈 줄·같은 이름은 뺀다.
List<String> parseLineNames(String text) {
  final out = <String>[];
  final seen = <String>{};
  for (final raw in text.split(RegExp(r'[\r\n\t]+'))) {
    final n = raw.trim();
    if (n.isEmpty || !seen.add(_norm(n))) continue;
    out.add(n);
  }
  return out;
}

/// 단계별 체크 수와 다 마친 라인 수.
({int total, int complete, Map<String, int> perStage}) lineProgress(Map log) {
  final stages = lineStagesOf(log);
  final items = lineItemsOf(log);
  final per = {for (final s in stages) s: 0};
  var complete = 0;
  for (final l in items) {
    for (final s in stages) {
      if (lineStageDone(l, s)) per[s] = per[s]! + 1;
    }
    if (lineComplete(l, stages)) complete++;
  }
  return (total: items.length, complete: complete, perStage: per);
}

String _q(String s) => '"${s.replaceAll('"', '""').replaceAll('\n', ' ')}"';

/// 엑셀(CSV): 라인, 단계마다 체크한 날짜(안 했으면 빈칸), 메모. 맨 앞 BOM.
String buildLineCsv(Map log) {
  final stages = lineStagesOf(log);
  final b = StringBuffer('﻿${['라인', ...stages, '메모'].map(_q).join(',')}\n');
  for (final l in lineItemsOf(log)) {
    final cells = <String>[_q('${l['name'] ?? ''}')];
    for (final s in stages) {
      final m = lineStageMark(l, s);
      final d = m?.at;
      cells.add(
        _q(
          d == null
              ? (m == null ? '' : 'O')
              : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
        ),
      );
    }
    cells.add(_q('${l['note'] ?? ''}'));
    b.writeln(cells.join(','));
  }
  return b.toString();
}
