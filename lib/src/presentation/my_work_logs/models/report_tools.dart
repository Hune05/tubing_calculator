import 'dart:convert';

import 'report_style.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'project_phase.dart';

export 'search_tools.dart';
export 'reminder_tools.dart';
export 'report_pdf.dart';

// 🚀 작업일보 부가 기능 모음: 기간 보고서(텍스트/PDF), 통합 검색, 일보 알림.

const List<String> kPhotoTags = ['작업 전', '작업 중', '작업 후', '자재', '이슈', '기타'];

// 일보 날짜는 "MM/dd" 문자열이라 연도가 없다. 올해로 보되, 오늘보다 한참 미래면
// 작년 것으로 본다(연말~연초 걸친 프로젝트 대비).
DateTime reportDate(String mmdd) {
  final parts = mmdd.split('/');
  final now = DateTime.now();
  final m = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 1;
  final d = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 1;
  var dt = DateTime(now.year, m, d);
  if (dt.isAfter(now.add(const Duration(days: 30)))) {
    dt = DateTime(now.year - 1, m, d);
  }
  return dt;
}

// 새 일보는 'dateISO'(yyyy-MM-dd)를 함께 저장한다. 없으면(예전 일보) 위 추정을 쓴다.
DateTime reportDateOf(Map r) {
  final iso = r['dateISO']?.toString();
  if (iso != null) {
    final d = DateTime.tryParse(iso);
    if (d != null) return dayOnly(d);
  }
  return reportDate(r['date']?.toString() ?? '');
}

// ───────────────────────── 기간 보고서 ─────────────────────────
class ReportSection {
  final String heading;
  final List<String> lines;
  final bool newPage; // true면 PDF에서 이 섹션부터 새 페이지
  // 줄 번호 -> 그 줄이 가리키는 이슈(화면에서 눌러 상세로 갈 때 쓴다).
  final Map<int, ({Map<String, dynamic> log, Map punch})>? issueRefs;
  // 줄 번호 -> 그 줄이 가리키는 프로젝트(눌러서 그 프로젝트 화면으로 갈 때 쓴다).
  final Map<int, Map<String, dynamic>>? projectRefs;
  ReportSection(
    this.heading,
    this.lines, {
    this.newPage = false,
    this.issueRefs,
    this.projectRefs,
  });
}

// PDF에 넣을 사진 한 장(경로 또는 URL)과 설명(날짜 · 분류 · 메모).
class ReportPhoto {
  final String path;
  final String label;
  final String? group; // 있으면 PDF에서 이 이름(프로젝트) 소제목 아래로 묶는다
  ReportPhoto(this.path, this.label, {this.group});
}

// 그래프 한 줄(막대). plan이 있으면 계획 막대를 위에 회색으로 함께 그린다.
class ReportChartRow {
  final String label;
  final double value;
  final String valueText;
  final double? plan;
  ReportChartRow(this.label, this.value, this.valueText, {this.plan});
}

class ReportChart {
  final String heading;
  final List<ReportChartRow> rows;
  ReportChart(this.heading, this.rows);
}

// 이슈 처리 전/후 사진 한 쌍.
class ReportCompare {
  final String before;
  final String after;
  final String label;
  ReportCompare(this.before, this.after, this.label);
}

// 도면 위 핀 위치(0~1 비율)를 PDF에 그리기 위한 정보.
class ReportPin {
  final String planPath;
  final double dx;
  final double dy;
  final String label;
  ReportPin(this.planPath, this.dx, this.dy, this.label);
}

class ReportDoc {
  final String title;
  final String period;
  final List<ReportSection> sections;
  final List<ReportPhoto> photos;
  final List<ReportChart> charts;
  final List<ReportPin> pins;
  final List<ReportCompare> compares;
  final String heading; // 문서 종류 표시(예: 작업 보고 / 이슈 보고)
  final String? logoB64; // 프로젝트별 로고(없으면 기본 양식 로고)
  final String? company; // 프로젝트별 머리말(없으면 기본 양식)
  final String? manager;
  // 텍스트 공유에서 섹션 제목을 【제목】으로 쓴다(본문에 이미 ■ 프로젝트 줄이 있는 문서용).
  final bool boxedHeadings;
  final bool showAuthorLine; // PDF 제목 아래에 "작성일 · 작성자" 한 줄
  final String? textFooter; // 텍스트 공유 맨 끝에 붙이는 안내 한 줄
  final String? fileStamp; // PDF 파일 이름에 넣는 날짜(yyyyMMdd). 없으면 오늘
  ReportDoc(
    this.title,
    this.period,
    this.sections, {
    this.photos = const [],
    this.charts = const [],
    this.pins = const [],
    this.compares = const [],
    this.heading = '작업 보고',
    this.company,
    this.manager,
    this.logoB64,
    this.boxedHeadings = false,
    this.showAuthorLine = false,
    this.textFooter,
    this.fileStamp,
  });

  // 문서 종류 표시(heading)만 바꾼 복사본. 마무리 보고서가 일반 "작업 보고"와 구분되게 한다.
  ReportDoc withHeading(String newHeading) => ReportDoc(
    title,
    period,
    sections,
    photos: photos,
    charts: charts,
    pins: pins,
    compares: compares,
    heading: newHeading,
    company: company,
    manager: manager,
    logoB64: logoB64,
    boxedHeadings: boxedHeadings,
    showAuthorLine: showAuthorLine,
    textFooter: textFooter,
    fileStamp: fileStamp,
  );

  // "작성일 2026.9.19 · 작성 홍길동"(작성자는 양식 설정의 담당자, 없으면 생략).
  String authorLine([DateTime? now]) {
    final d = now ?? DateTime.now();
    final mg = (manager ?? ReportStyle.current.manager).trim();
    return '작성일 ${d.year}.${d.month}.${d.day}${mg.isEmpty ? '' : ' · 작성 $mg'}';
  }

  String toText() {
    final b = StringBuffer('[$title] $heading\n$period\n');
    final st = ReportStyle.current;
    final co = company ?? st.company;
    final mg = manager ?? st.manager;
    if (co.isNotEmpty || mg.isNotEmpty) {
      b.writeln(
        [if (co.isNotEmpty) co, if (mg.isNotEmpty) '담당 $mg'].join(' · '),
      );
    }
    for (final s in sections) {
      b.writeln(boxedHeadings ? '\n【${s.heading}】' : '\n■ ${s.heading}');
      for (final l in s.lines) {
        b.writeln(l);
      }
    }
    if (textFooter != null && textFooter!.isNotEmpty) {
      b.writeln('\n$textFooter');
    }
    return b.toString().trimRight();
  }
}

String _md(DateTime d) => '${d.month}/${d.day}';

ReportDoc buildReportDoc(
  Map<String, dynamic> log,
  DateTime from,
  DateTime to, {
  List<Map>? only, // 지정하면 기간 대신 이 일보들만 포함
}) {
  final f = dayOnly(from), t = dayOnly(to);
  final progress = (projectProgress(log) * 100).round();
  final cur = currentPhase(log);
  final due = projectDue(log);
  final today = dayOnly(DateTime.now());

  final overview = <String>['진행률 $progress%'];
  if (cur != null) overview.add('현재 단계: ${cur['name']}');
  if (due != null) {
    final diff = due.difference(today).inDays;
    overview.add(
      '종료 예정 ${due.year}.${due.month}.${due.day} '
      '(${diff == 0
          ? 'D-Day'
          : diff > 0
          ? 'D-$diff'
          : 'D+${-diff}'})',
    );
  }
  final delay = delayedPhase(log);
  if (delay != null) {
    overview.add('⚠ ${delay.phase['name']} 단계 ${delay.days}일 지연');
  }

  final inRange = (log['daily_reports'] as List? ?? []).whereType<Map>().where((
    r,
  ) {
    final d = reportDateOf(r);
    return !d.isBefore(f) && !d.isAfter(t);
  }).toList()..sort((a, b) => reportDateOf(a).compareTo(reportDateOf(b)));

  final reports = only != null
      ? (List<Map>.from(only)
          ..sort((a, b) => reportDateOf(a).compareTo(reportDateOf(b))))
      : inRange;

  final phaseNames = {
    for (final p in phasesOf(log)) p['id'].toString(): p['name'].toString(),
  };
  final dayLines = <String>[];
  final Map<String, int> phaseDays = {};
  int manDays = 0;
  final completedTitles = <String>[];
  final scheduleTitle = {
    for (final s in schedulesOf(log))
      s['id'].toString(): (s['title'] ?? s['type'] ?? '').toString(),
  };
  for (final r in reports) {
    final types = r['work_type'] is List
        ? (r['work_type'] as List).join('·')
        : (r['work_type']?.toString() ?? '');
    final workers = (r['worker_count'] as num?)?.toInt() ?? 1;
    manDays += workers;
    final pt = (r['points'] as num?)?.toInt() ?? 0;
    final wp = (r['wiring_points'] as num?)?.toInt() ?? 0;
    final extra = [
      if (pt > 0) '벤딩 ${pt}pt',
      if (wp > 0) '결선 $wp개소',
      if (r['is_overtime'] == true) '연장',
    ];
    dayLines.add(
      '· ${r['date']}${r['locked'] == true ? ' [확정]' : ''}  $types / $workers명${extra.isEmpty ? '' : ' / ${extra.join(' ')}'}',
    );
    final note = (r['note']?.toString() ?? '').trim();
    if (note.isNotEmpty && note != '특이사항 없음') {
      for (final l in note.split('\n')) {
        dayLines.add('   - $l');
      }
    }
    final mats = (r['materials_used']?.toString() ?? '').trim();
    if (mats.isNotEmpty) dayLines.add('   자재: $mats');
    final caps = Map<String, dynamic>.from((r['image_captions'] as Map?) ?? {});
    final tags = Map<String, dynamic>.from((r['image_tags'] as Map?) ?? {});
    for (final e in caps.entries) {
      final tg = tags[e.key]?.toString();
      dayLines.add('   사진${tg == null ? '' : '($tg)'}: ${e.value}');
    }
    for (final id in reportIds(r, 'workedPhaseIds')) {
      final n = phaseNames[id];
      if (n != null) phaseDays[n] = (phaseDays[n] ?? 0) + 1;
    }
    for (final id in reportIds(r, 'completedScheduleIds')) {
      final n = scheduleTitle[id];
      if (n != null && n.isNotEmpty) completedTitles.add('${r['date']} $n');
    }
  }

  final sections = <ReportSection>[
    ReportSection('진행 현황', overview),
    ReportSection(
      '작업 내역 (${reports.length}일, 투입 $manDays인·일)',
      dayLines.isEmpty ? ['이 기간에 작성된 일보가 없습니다.'] : dayLines,
    ),
  ];
  if (phaseDays.isNotEmpty) {
    sections.add(
      ReportSection(
        '단계별 작업일',
        phaseDays.entries.map((e) => '· ${e.key}: ${e.value}일').toList(),
      ),
    );
  }
  if (completedTitles.isNotEmpty) {
    sections.add(
      ReportSection('완료한 일정', completedTitles.map((e) => '· $e').toList()),
    );
  }

  final mats = schedulesOf(log).where(isMaterialSchedule).toList();
  if (mats.isNotEmpty) {
    final open = mats.where((m) => materialState(m) != 'done').toList();
    final lines = <String>[
      '입고 완료 ${mats.length - open.length} / 전체 ${mats.length}',
    ];
    for (final m in open) {
      final st = materialState(m);
      final label = switch (st) {
        'late' => '입고 지연',
        'pending' => '입고일 미정',
        _ => '입고 예정',
      };
      final dt = m['dateTime'] == null ? '' : ' ${_md(asDate(m['dateTime']))}';
      lines.add('· ${m['title'] ?? m['type']} ($label$dt)');
    }
    sections.add(ReportSection('자재 현황', lines));
  }

  final issues = (log['punch_lists'] as List? ?? [])
      .whereType<Map>()
      .where((p) => p['is_completed'] != true)
      .toList();
  if (issues.isNotEmpty) {
    sections.add(
      ReportSection(
        '미해결 이슈 (${issues.length})',
        issues
            .take(10)
            .map((p) => '· ${p['content'] ?? ''} (${p['location'] ?? ''})')
            .toList(),
      ),
    );
  }

  final lastPlan = reports.isNotEmpty
      ? (reports.last['next_day_plan']?.toString() ?? '').trim()
      : '';
  if (lastPlan.isNotEmpty) {
    sections.add(ReportSection('다음 계획', [lastPlan]));
  }

  sections.removeWhere(
    (s) =>
        ReportStyle.current.hiddenSections.any((h) => s.heading.startsWith(h)),
  );
  final photos = <ReportPhoto>[];
  for (final r in reports) {
    final pTags = Map<String, dynamic>.from((r['image_tags'] as Map?) ?? {});
    final pCaps = Map<String, dynamic>.from(
      (r['image_captions'] as Map?) ?? {},
    );
    for (final p in (r['image_paths'] as List? ?? [])) {
      final k = p.toString();
      photos.add(
        ReportPhoto(
          k,
          [
            r['date'],
            if (pTags[k] != null) pTags[k],
            if (pCaps[k] != null) pCaps[k],
          ].join(' · '),
        ),
      );
    }
  }
  return ReportDoc(
    log['name']?.toString() ?? '프로젝트',
    only != null
        ? '선택한 일보 ${only.length}건'
        : '기간 ${f.year}.${f.month}.${f.day} ~ ${t.year}.${t.month}.${t.day}',
    sections,
    logoB64: headerOverride(log, 'logoB64'),
    company: headerOverride(log, 'company'),
    manager: headerOverride(log, 'manager'),
    photos: photos,
    pins: [
      if ((log['floor_plan_image_path']?.toString() ?? '').isNotEmpty)
        for (final r in reports)
          if (r['locationPinDx'] != null && r['locationPinDy'] != null)
            ReportPin(
              log['floor_plan_image_path'].toString(),
              (r['locationPinDx'] as num).toDouble(),
              (r['locationPinDy'] as num).toDouble(),
              '${r['date']} 작업 위치',
            ),
    ],
  );
}

// 이슈(펀치) 보고서: 미해결만 또는 전체.
ReportDoc buildIssueReportDoc(
  Map<String, dynamic> log, {
  required bool onlyOpen,
}) {
  final all = (log['punch_lists'] as List? ?? []).whereType<Map>().toList();
  final list = onlyOpen
      ? all.where((p) => p['is_completed'] != true).toList()
      : List<Map>.from(all);
  const order = {'긴급': 0, '보통': 1, '여유': 2};
  list.sort((a, b) {
    final ca = a['is_completed'] == true ? 1 : 0;
    final cb = b['is_completed'] == true ? 1 : 0;
    if (ca != cb) return ca - cb;
    return (order[a['priority']] ?? 1).compareTo(order[b['priority']] ?? 1);
  });
  final open = all.where((p) => p['is_completed'] != true).toList();
  final urgent = open.where((p) => p['priority'] == '긴급').length;

  final lines = <String>[];
  final photos = <ReportPhoto>[];
  final pins = <ReportPin>[];
  final compares = <ReportCompare>[];
  final plan = log['floor_plan_image_path']?.toString() ?? '';
  for (final p in list) {
    final done = p['is_completed'] == true;
    final loc = p['location']?.toString() ?? '';
    final content = (p['content']?.toString() ?? '').trim();
    lines.add(
      '· [${done ? '완료' : '미해결'}/${p['priority'] ?? '보통'}] $loc — $content',
    );
    final meta = <String>[
      if (p['created_at'] != null) '등록 ${_md(asDate(p['created_at']))}',
      if ((p['defect_type']?.toString() ?? '').isNotEmpty)
        '유형 ${p['defect_type']}',
      if (p['dueDate'] != null) '기한 ${_md(asDate(p['dueDate']))}',
    ];
    if (meta.isNotEmpty) lines.add('   ${meta.join(' · ')}');
    final note = (p['resolution_note']?.toString() ?? '').trim();
    if (done && note.isNotEmpty) {
      lines.add(
        '   처리: $note${p['resolved_at'] != null ? ' (${_md(asDate(p['resolved_at']))})' : ''}',
      );
    }
    final short = content.length > 18
        ? '${content.substring(0, 18)}…'
        : content;
    final before = [
      for (final i in (p['image_paths'] as List? ?? [])) i.toString(),
    ];
    final after = [
      for (final i in (p['resolution_images'] as List? ?? [])) i.toString(),
    ];
    if (before.isNotEmpty && after.isNotEmpty) {
      compares.add(ReportCompare(before.first, after.first, '$loc · $short'));
      before.removeAt(0);
      after.removeAt(0);
    }
    for (final i in before) {
      photos.add(ReportPhoto(i, '$loc · $short'));
    }
    for (final i in after) {
      photos.add(ReportPhoto(i, '$loc · $short (처리 후)'));
    }
    if (plan.isNotEmpty &&
        p['locationPinDx'] != null &&
        p['locationPinDy'] != null) {
      pins.add(
        ReportPin(
          plan,
          (p['locationPinDx'] as num).toDouble(),
          (p['locationPinDy'] as num).toDouble(),
          '$loc · $short',
        ),
      );
    }
  }
  return ReportDoc(
    log['name']?.toString() ?? '프로젝트',
    onlyOpen ? '미해결 이슈' : '전체 이슈',
    [
      ReportSection('요약', [
        '전체 ${all.length}건 / 미해결 ${open.length}건 / 긴급 미해결 $urgent건',
      ]),
      ReportSection(
        onlyOpen ? '미해결 이슈 (${list.length})' : '이슈 목록 (${list.length})',
        lines.isEmpty ? ['맞는 이슈가 없습니다.'] : lines,
      ),
    ],
    logoB64: headerOverride(log, 'logoB64'),
    company: headerOverride(log, 'company'),
    manager: headerOverride(log, 'manager'),
    photos: photos,
    pins: pins,
    compares: compares,
    heading: '이슈 보고',
  );
}

// 여러 프로젝트의 보고서를 하나로 묶는다(제목 앞에 프로젝트명을 붙인다).
ReportDoc mergeReportDocs(List<ReportDoc> docs) => ReportDoc(
  '프로젝트 ${docs.length}건',
  '통합 보고',
  [
    for (final d in docs)
      for (final s in d.sections)
        ReportSection('[${d.title}] ${s.heading}', s.lines),
  ],
  photos: [
    for (final d in docs)
      for (final p in d.photos) ReportPhoto(p.path, '[${d.title}] ${p.label}'),
  ],
  pins: [
    for (final d in docs)
      for (final p in d.pins) p,
  ],
);

// 2일이 지난 일보 임시 저장을 지운다(앱 시작 시 호출).
Future<void> cleanOldDrafts() async {
  try {
    final p = await SharedPreferences.getInstance();
    for (final k in p.getKeys().where((k) => k.startsWith('report_draft_'))) {
      final raw = p.getString(k);
      DateTime? saved;
      try {
        saved = DateTime.tryParse(
          (jsonDecode(raw ?? '{}') as Map)['savedAt']?.toString() ?? '',
        );
      } catch (_) {}
      if (saved == null ||
          DateTime.now().difference(saved) > const Duration(days: 2)) {
        await p.remove(k);
      }
    }
  } catch (_) {}
}

Future<void> shareReportText(ReportDoc doc) async {
  // ignore: deprecated_member_use
  await Share.share(doc.toText());
}

// 요약 이미지 등 다른 곳에서 사진 바이트가 필요할 때(줄여서 돌려준다).
