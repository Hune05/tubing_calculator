import 'project_phase.dart';
import 'report_tools.dart';

// 🚀 [주간 업무 보고] 지난주 실적 / 이번주 진행·예정 / 다음주 계획을 프로젝트별로 묶어
// 한 장의 보고서로 만든다. 주는 월요일~일요일 기준.
class WeekRange {
  final String label;
  final DateTime start;
  final DateTime end;
  WeekRange(this.label, this.start, this.end);

  bool contains(DateTime d) {
    final x = dayOnly(d);
    return !x.isBefore(start) && !x.isAfter(end);
  }

  bool overlaps(DateTime s, DateTime e) =>
      !dayOnly(e).isBefore(start) && !dayOnly(s).isAfter(end);

  String get range => '${start.month}/${start.day}~${end.month}/${end.day}';
}

List<WeekRange> weekRanges([DateTime? now]) {
  final today = dayOnly(now ?? DateTime.now());
  final thisMon = today.subtract(Duration(days: today.weekday - 1));
  WeekRange w(String label, DateTime mon) =>
      WeekRange(label, mon, mon.add(const Duration(days: 6)));
  return [
    w('지난주', thisMon.subtract(const Duration(days: 7))),
    w('이번주', thisMon),
    w('다음주', thisMon.add(const Duration(days: 7))),
  ];
}

String _md(DateTime d) => '${d.month}/${d.day}';

String _firstLine(String s) {
  final t = s.trim().split('\n').first.trim();
  return t.length > 60 ? '${t.substring(0, 60)}…' : t;
}

// 한 프로젝트의 한 주 실적(일보 기반). 이번주는 오늘까지 쓴 것만 잡힌다.
List<String> _actualLines(Map<String, dynamic> log, WeekRange w) {
  final lines = <String>[];
  final reports = (log['daily_reports'] as List? ?? []).whereType<Map>().where((
    r,
  ) {
    return w.contains(reportDateOf(r));
  }).toList()..sort((a, b) => reportDateOf(a).compareTo(reportDateOf(b)));

  int manDays = 0;
  final done = <String>[];
  final scheduleTitle = {
    for (final s in schedulesOf(log))
      s['id'].toString(): (s['title'] ?? s['type'] ?? '').toString(),
  };
  for (final r in reports) {
    manDays += (r['worker_count'] as num?)?.toInt() ?? 1;
    final d = reportDateOf(r);
    final types = r['work_type'] is List
        ? (r['work_type'] as List).join('·')
        : (r['work_type']?.toString() ?? '');
    final note = (r['note']?.toString() ?? '').trim();
    final body = (note.isEmpty || note == '특이사항 없음') ? types : _firstLine(note);
    lines.add('  · ${_md(d)} $body');
    for (final id in reportIds(r, 'completedScheduleIds')) {
      final t = scheduleTitle[id];
      if (t != null && t.isNotEmpty) done.add(t);
    }
  }
  if (reports.isNotEmpty) {
    lines.add('  → 작업 ${reports.length}일 · 투입 $manDays인·일');
  }
  if (done.isNotEmpty) lines.add('  ✓ 완료한 일정: ${done.toSet().join(', ')}');

  // 이슈: 그 주에 처리된 것 / 새로 등록된 것
  final punches = (log['punch_lists'] as List? ?? []).whereType<Map>();
  final resolved = punches.where((p) {
    return p['is_completed'] == true &&
        p['resolved_at'] != null &&
        w.contains(asDate(p['resolved_at']));
  }).length;
  final created = punches.where((p) {
    return p['created_at'] != null && w.contains(asDate(p['created_at']));
  }).length;
  if (resolved > 0 || created > 0) {
    lines.add(
      '  ! 이슈 ${created > 0 ? '신규 $created건' : ''}'
      '${created > 0 && resolved > 0 ? ' · ' : ''}'
      '${resolved > 0 ? '처리 $resolved건' : ''}',
    );
  }
  return lines;
}

// 한 프로젝트의 한 주 예정(일정/자재/단계).
List<String> _plannedLines(Map<String, dynamic> log, WeekRange w) {
  final lines = <String>[];
  final today = dayOnly(DateTime.now());

  final items = <(DateTime, String)>[];
  int undatedMaterial = 0;
  for (final s in schedulesOf(log)) {
    if (s['isCompleted'] == true) continue;
    final title = (s['title'] ?? s['type'] ?? '').toString();
    if (s['dateTime'] == null) {
      if (isMaterialSchedule(s)) undatedMaterial++;
      continue;
    }
    final st = dayOnly(asDate(s['dateTime']));
    final en = s['endDate'] != null ? dayOnly(asDate(s['endDate'])) : st;
    // 이미 지난 미완료 일정은 "이번주"에 지연으로 함께 올린다.
    final late =
        st.isBefore(w.start) && w.contains(today) && en.isBefore(today);
    if (w.overlaps(st, en) || late) {
      items.add((
        st,
        '  · ${_md(st)}${en != st ? '~${_md(en)}' : ''} $title'
            '${late ? ' (지연)' : ''}',
      ));
    }
  }
  items.sort((a, b) => a.$1.compareTo(b.$1));
  lines.addAll(items.map((e) => e.$2));
  if (undatedMaterial > 0 &&
      !w.start.isBefore(
        dayOnly(DateTime.now()).subtract(const Duration(days: 7)),
      )) {
    lines.add('  · 입고일 미정 자재 $undatedMaterial건 확인 필요');
  }

  // 단계: 이번/다음주와 겹치는 미완료 단계
  for (final p in phasesOf(log)) {
    if (phaseIsDone(log, p)) continue;
    final s = phaseStart(p), e = phaseEnd(p);
    if (s == null || e == null) continue;
    if (w.overlaps(s, e)) {
      lines.add('  ▸ 단계: ${p['name']} (${_md(s)}~${_md(e)})');
    }
  }
  return lines;
}

// 프로젝트별로 묶어 한 섹션의 줄 목록을 만든다. 내용이 없는 프로젝트는 뺀다.
List<String> _sectionLines(
  List<Map<String, dynamic>> logs,
  WeekRange w, {
  required bool actual,
  required bool planned,
}) {
  final out = <String>[];
  for (final log in logs) {
    final block = <String>[
      if (actual) ..._actualLines(log, w),
      if (planned) ..._plannedLines(log, w),
    ];
    if (block.isEmpty) continue;
    out.add('■ ${log['name'] ?? '프로젝트'}');
    out.addAll(block);
  }
  return out;
}

ReportDoc buildWeeklyPlanDoc(
  List<Map<String, dynamic>> logs, {
  Set<String>? onlyIds,
}) {
  final today = dayOnly(DateTime.now());
  final weeks = weekRanges(today);
  final targets = logs
      .where(
        (l) =>
            l['status'] != 'DONE' &&
            (onlyIds == null || onlyIds.contains(l['id']?.toString())),
      )
      .toList();

  // 다음 계획 메모: 가장 최근 일보의 "내일 계획"(이번주 것만)
  final memo = <String>[];
  for (final log in targets) {
    final rs = (log['daily_reports'] as List? ?? []).whereType<Map>().toList()
      ..sort((a, b) => reportDateOf(b).compareTo(reportDateOf(a)));
    if (rs.isEmpty) continue;
    final plan = (rs.first['next_day_plan']?.toString() ?? '').trim();
    if (plan.isNotEmpty && weeks[1].contains(reportDateOf(rs.first))) {
      memo.add('■ ${log['name']}: $plan');
    }
  }

  ReportSection sec(WeekRange w, String suffix, List<String> lines) =>
      ReportSection(
        '${w.label} (${w.range}) $suffix',
        lines.isEmpty ? ['해당 내용 없음'] : lines,
      );

  final sections = <ReportSection>[
    sec(
      weeks[0],
      '— 실적',
      _sectionLines(targets, weeks[0], actual: true, planned: false),
    ),
    sec(
      weeks[1],
      '— 진행 및 예정',
      _sectionLines(targets, weeks[1], actual: true, planned: true),
    ),
    sec(
      weeks[2],
      '— 계획',
      _sectionLines(targets, weeks[2], actual: false, planned: true),
    ),
  ];
  if (memo.isNotEmpty) {
    sections.add(ReportSection('최근 일보의 다음 계획 메모', memo));
  }

  // 미해결 이슈 현황(전체)
  final issueLines = <String>[];
  for (final log in targets) {
    final open = (log['punch_lists'] as List? ?? [])
        .whereType<Map>()
        .where((p) => p['is_completed'] != true)
        .toList();
    if (open.isEmpty) continue;
    issueLines.add('■ ${log['name']} — 미해결 ${open.length}건');
    for (final p in open.take(5)) {
      issueLines.add(
        '  · [${p['priority'] ?? '보통'}] ${p['location'] ?? ''} ${p['content'] ?? ''}',
      );
    }
  }
  if (issueLines.isNotEmpty) {
    sections.add(ReportSection('미해결 이슈 현황', issueLines));
  }

  return ReportDoc(
    targets.length == 1
        ? (targets.first['name']?.toString() ?? '프로젝트')
        : '진행중 프로젝트 ${targets.length}건',
    '${today.year}.${today.month}.${today.day} 기준',
    sections,
    heading: '주간 업무 보고',
  );
}
