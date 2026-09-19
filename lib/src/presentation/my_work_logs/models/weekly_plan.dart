import 'project_phase.dart';
import 'report_style.dart';
import 'report_tools.dart';

// 🚀 [주간 업무 보고] 전주 실적 / 금주 진행·예정 / 차주 계획을 프로젝트별로 묶어
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
    w('전주', thisMon.subtract(const Duration(days: 7))),
    w('금주', thisMon),
    w('차주', thisMon.add(const Duration(days: 7))),
  ];
}

String _md(DateTime d) => '${d.month}/${d.day}';

String _firstLine(String s) {
  final t = s.trim().split('\n').first.trim();
  return t.length > 60 ? '${t.substring(0, 60)}…' : t;
}

// 한 프로젝트의 한 주 실적(일보 기반). 금주는 오늘까지 쓴 것만 잡힌다.
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
  final punches = _weeklyIssues(log);
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
List<String> _plannedLines(
  Map<String, dynamic> log,
  WeekRange w,
  DateTime today,
) {
  final lines = <String>[];

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
    // 이미 지난 미완료 일정은 "금주"에 지연으로 함께 올린다.
    final late =
        st.isBefore(w.start) && w.contains(today) && en.isBefore(today);
    // 전주에 끝났어야 하는 일정이면 "이월", 그보다 더 오래됐으면 "지연".
    final carried = late && !en.isBefore(weekRanges(today)[0].start);
    if (w.overlaps(st, en) || late) {
      items.add((
        st,
        '  · ${_md(st)}${en != st ? '~${_md(en)}' : ''} $title'
            '${late ? (carried ? ' (전주 이월)' : ' (지연)') : ''}',
      ));
    }
  }
  items.sort((a, b) => a.$1.compareTo(b.$1));
  lines.addAll(items.map((e) => e.$2));
  if (undatedMaterial > 0 &&
      !w.start.isBefore(today.subtract(const Duration(days: 7)))) {
    lines.add('  · 입고일 미정 자재 $undatedMaterial건 확인 필요');
  }

  // 단계: 이번/차주와 겹치는 미완료 단계
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

// 주간 보고에서 뺀(weeklyExclude) 이슈를 걸러낸 이슈 목록.
List<Map> _weeklyIssues(Map<String, dynamic> log) =>
    (log['punch_lists'] as List? ?? [])
        .whereType<Map>()
        .where((p) => p['weeklyExclude'] != true)
        .toList();

String _openIssueText(Map<String, dynamic> log) {
  final issues = _weeklyIssues(log).where((p) => p['is_completed'] != true);
  final open = issues.length;
  if (open == 0) return '';
  final od = issues.where((p) => issueOverdueDays(p) > 0).length;
  return ' · 미해결 이슈 $open건${od > 0 ? '(기한 초과 $od)' : ''}';
}

// 금주 한눈에 보는 요약: 작업일수·투입, 완료한 일정, 이슈 신규/처리.
List<String> _summaryLines(List<Map<String, dynamic>> logs, WeekRange w) {
  int days = 0, manDays = 0, doneSchedules = 0, created = 0, resolved = 0;
  for (final log in logs) {
    for (final r in (log['daily_reports'] as List? ?? []).whereType<Map>()) {
      if (!w.contains(reportDateOf(r))) continue;
      days++;
      manDays += (r['worker_count'] as num?)?.toInt() ?? 1;
      doneSchedules += reportIds(r, 'completedScheduleIds').length;
    }
    for (final p in _weeklyIssues(log)) {
      if (p['created_at'] != null && w.contains(asDate(p['created_at']))) {
        created++;
      }
      if (p['is_completed'] == true &&
          p['resolved_at'] != null &&
          w.contains(asDate(p['resolved_at']))) {
        resolved++;
      }
    }
  }
  return [
    '  · 작업 ${days}일(일보 기준) · 투입 ${manDays}인·일',
    '  · 완료한 일정 ${doneSchedules}건',
    '  · 이슈 신규 ${created}건 · 처리 ${resolved}건',
    // 프로젝트가 여러 개면 한 줄씩 현황(카톡 텍스트로 보낼 때 한눈에 보이게).
    if (logs.length > 1)
      for (final log in logs)
        '  ■ ${log['name'] ?? '프로젝트'} · 진행률 ${(projectProgress(log) * 100).round()}%'
            '${_openIssueText(log)}',
  ];
}

// 프로젝트별로 묶어 한 섹션의 줄 목록을 만든다. 내용이 없는 프로젝트는 뺀다.
List<String> _sectionLines(
  List<Map<String, dynamic>> logs,
  WeekRange w, {
  required bool actual,
  required bool planned,
  required DateTime today,
  bool showProgress = false,
}) {
  final out = <String>[];
  for (final log in logs) {
    String? prog;
    if (showProgress) {
      final pct = (projectProgress(log) * 100).round();
      final d = progressDeltaSince(log, 7);
      prog =
          '  ◐ 진행률 $pct%'
          '${d == null
              ? ''
              : d == 0
              ? ' (전주와 동일)'
              : ' (전주 대비 ${d > 0 ? '+' : ''}$d%p)'}';
    }
    final block = <String>[
      if (prog != null) prog,
      if (actual) ..._actualLines(log, w),
      if (planned) ..._plannedLines(log, w, today),
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
  bool includePhotos = false,
  bool perProject = false,
  DateTime? asOf, // 기준일(없으면 오늘). 과거 주를 다시 볼 때 쓴다.
}) {
  final now0 = dayOnly(DateTime.now());
  final today = dayOnly(asOf ?? now0);
  final isCurrent = today == now0;
  final weeks = weekRanges(today);
  final targets = logs
      .where(
        (l) =>
            l['status'] != 'DONE' &&
            (onlyIds == null || onlyIds.contains(l['id']?.toString())),
      )
      .toList();

  // 다음 계획 메모: 가장 최근 일보의 "내일 계획"(금주 것만)
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

  final combined = <ReportSection>[
    sec(
      weeks[0],
      '— 실적',
      _sectionLines(
        targets,
        weeks[0],
        actual: true,
        planned: false,
        today: today,
      ),
    ),
    sec(
      weeks[1],
      '— 진행 및 예정',
      _sectionLines(
        targets,
        weeks[1],
        actual: true,
        planned: true,
        today: today,
        showProgress: isCurrent,
      ),
    ),
    sec(
      weeks[2],
      '— 계획',
      _sectionLines(
        targets,
        weeks[2],
        actual: false,
        planned: true,
        today: today,
      ),
    ),
  ];

  // 프로젝트별로 나눠 보기: 프로젝트마다 전주/금주/차주 세 칸, PDF는 새 페이지로 시작.
  final sections = <ReportSection>[];
  if (perProject && targets.length > 1) {
    const parts = [
      (0, '— 실적', true, false),
      (1, '— 진행 및 예정', true, true),
      (2, '— 계획', false, true),
    ];
    for (var i = 0; i < targets.length; i++) {
      final t = targets[i];
      for (final (wi, suffix, actual, planned) in parts) {
        final w = weeks[wi];
        // 첫 줄은 프로젝트 이름 줄이라 뺀다(제목에 이미 들어 있다).
        final lines = _sectionLines(
          [t],
          w,
          actual: actual,
          planned: planned,
          today: today,
          showProgress: wi == 1 && isCurrent,
        ).skip(1).toList();
        sections.add(
          ReportSection(
            '${t['name'] ?? '프로젝트'} · ${w.label} (${w.range}) $suffix',
            lines.isEmpty ? ['해당 내용 없음'] : lines,
            newPage: wi == 0 && i > 0,
          ),
        );
      }
    }
  } else {
    sections.addAll(combined);
  }
  sections.insert(
    0,
    ReportSection(
      '금주 요약 (${weeks[1].range})',
      _summaryLines(targets, weeks[1]),
    ),
  );
  if (memo.isNotEmpty) {
    sections.add(ReportSection('최근 일보의 다음 계획 메모', memo));
  }

  // 미해결 이슈 현황(전체)
  final issueLines = <String>[];
  final issueRefs = <int, ({Map<String, dynamic> log, Map punch})>{};
  for (final log in targets) {
    final open = _weeklyIssues(
      log,
    ).where((p) => p['is_completed'] != true).toList();
    if (open.isEmpty) continue;
    // 기한이 지난 이슈를 위로 올리고 "기한 초과"로 표시한다.
    int overdueDays(Map p) {
      if (p['dueDate'] == null) return 0;
      final d = today.difference(dayOnly(asDate(p['dueDate']))).inDays;
      return d > 0 ? d : 0;
    }

    open.sort((x, y) => overdueDays(y).compareTo(overdueDays(x)));
    final overdue = open.where((p) => overdueDays(p) > 0).length;
    final noDue = open.where((p) => p['dueDate'] == null).length;
    issueLines.add(
      '■ ${log['name']} — 미해결 ${open.length}건'
      '${overdue > 0 ? ' (기한 초과 $overdue건)' : ''}'
      '${noDue > 0 ? ' (기한 미정 $noDue건)' : ''}',
    );
    for (final p in open.take(5)) {
      final od = overdueDays(p);
      final due = p['dueDate'] == null
          ? ' · 기한 미정'
          : ' · 기한 ${_md(asDate(p['dueDate']))}${od > 0 ? ' 초과 $od일' : ''}';
      issueRefs[issueLines.length] = (log: log, punch: p);
      issueLines.add(
        '  · [${p['priority'] ?? '보통'}] ${p['location'] ?? ''} ${p['content'] ?? ''}$due',
      );
    }
  }
  if (issueLines.isNotEmpty) {
    sections.add(ReportSection('미해결 이슈 현황', issueLines, issueRefs: issueRefs));
  }

  // 사진: 전주·금주 일보에 붙은 사진 중 최근 12장.
  final photos = <(int, DateTime, ReportPhoto)>[];
  if (includePhotos) {
    for (var ti = 0; ti < targets.length; ti++) {
      final log = targets[ti];
      for (final r in (log['daily_reports'] as List? ?? []).whereType<Map>()) {
        final d = reportDateOf(r);
        if (!weeks[0].contains(d) && !weeks[1].contains(d)) continue;
        final tags = Map<String, dynamic>.from((r['image_tags'] as Map?) ?? {});
        final caps = Map<String, dynamic>.from(
          (r['image_captions'] as Map?) ?? {},
        );
        for (final p in (r['image_paths'] as List? ?? [])) {
          final k = p.toString();
          photos.add((
            ti,
            d,
            ReportPhoto(
              k,
              group: targets.length > 1 ? log['name']?.toString() : null,
              [
                _md(d),
                if (tags[k] != null) tags[k],
                if (caps[k] != null) caps[k],
              ].join(' · '),
            ),
          ));
        }
      }
    }
  }
  // 작업 전/후 사진을 프로젝트별로 순서대로 짝지어 전후 비교로 만든다.
  final compares = <ReportCompare>[];
  if (includePhotos) {
    for (final log in targets) {
      final before = <String>[], after = <String>[];
      final reps =
          (log['daily_reports'] as List? ?? []).whereType<Map>().toList()
            ..sort((a, b) => reportDateOf(a).compareTo(reportDateOf(b)));
      for (final r in reps) {
        final d = reportDateOf(r);
        if (!weeks[0].contains(d) && !weeks[1].contains(d)) continue;
        final tags = Map<String, dynamic>.from((r['image_tags'] as Map?) ?? {});
        for (final p in (r['image_paths'] as List? ?? [])) {
          final k = p.toString();
          if (tags[k] == '작업 전') before.add(k);
          if (tags[k] == '작업 후') after.add(k);
        }
      }
      final n = before.length < after.length ? before.length : after.length;
      for (var i = 0; i < n && compares.length < 6; i++) {
        compares.add(
          ReportCompare(
            before[i],
            after[i],
            '${log['name'] ?? '프로젝트'} · 작업 전/후 ${i + 1}',
          ),
        );
      }
    }
  }

  // 이슈 처리 전(등록 사진) / 후(처리 사진) 사진도 그 주에 처리된 것은 전후 비교에 넣는다.
  if (includePhotos) {
    for (final log in targets) {
      for (final p in (log['punch_lists'] as List? ?? []).whereType<Map>()) {
        if (compares.length >= 6) break;
        if (p['is_completed'] != true || p['resolved_at'] == null) continue;
        final rd = asDate(p['resolved_at']);
        if (!weeks[0].contains(rd) && !weeks[1].contains(rd)) continue;
        final b = (p['image_paths'] as List? ?? []);
        final a = (p['resolution_images'] as List? ?? []);
        if (b.isEmpty || a.isEmpty) continue;
        final loc = (p['location']?.toString() ?? '').trim();
        final what = _firstLine((p['content']?.toString() ?? ''));
        compares.add(
          ReportCompare(
            b.first.toString(),
            a.first.toString(),
            '${log['name'] ?? '프로젝트'} · 이슈 처리 (${loc.isEmpty ? what : '$loc $what'})',
          ),
        );
      }
    }
  }

  // 최근 12장만 남기고, 프로젝트 순서로 묶어 그 안에서는 날짜순으로 둔다.
  photos.sort((a, b) => a.$2.compareTo(b.$2));
  final picked =
      (photos.length > 12
            ? photos.sublist(photos.length - 12)
            : photos.toList())
        ..sort((a, b) {
          final c = a.$1.compareTo(b.$1);
          return c != 0 ? c : a.$2.compareTo(b.$2);
        });

  // 보고서 양식 설정에서 숨긴 항목은 주간 보고에서도 뺀다.
  sections.removeWhere(
    (s) =>
        ReportStyle.current.hiddenSections.any((h) => s.heading.startsWith(h)),
  );

  // 프로젝트가 하나면 그 프로젝트의 머리말(회사·담당자·로고)을 쓴다.
  final one = targets.length == 1 ? targets.first : null;
  return ReportDoc(
    targets.length == 1
        ? (targets.first['name']?.toString() ?? '프로젝트')
        : '진행중 프로젝트 ${targets.length}건',
    '${today.year}.${today.month}.${today.day} 기준'
    '${isCurrent ? '' : ' (지난 주 보기: 진행률·미해결 이슈는 현재 값)'}',
    sections,
    heading: '주간 업무 보고',
    boxedHeadings: true,
    fileStamp:
        '${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}',
    // 사진을 넣도록 골랐으면, 카톡 텍스트에는 사진이 안 가니 PDF를 안내한다.
    textFooter: (includePhotos && (picked.isNotEmpty || compares.isNotEmpty))
        ? '※ 사진 ${picked.length}장'
              '${compares.isEmpty ? '' : ', 작업 전/후 비교 ${compares.length}쌍'}'
              '은 PDF로 보내면 함께 볼 수 있어요.'
        : null,
    logoB64: one == null ? null : headerOverride(one, 'logoB64'),
    company: one == null ? null : headerOverride(one, 'company'),
    manager: one == null ? null : headerOverride(one, 'manager'),
    photos: [for (final e in picked) e.$3],
    compares: compares,
  );
}
