import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' show PdfColor, PdfColors;
import 'package:pdf/widgets.dart' as pw;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'photo_store.dart';
import 'report_style.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

import 'package:tubing_calculator/main.dart'
    show flutterLocalNotificationsPlugin;
import 'project_phase.dart';

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
  ReportSection(this.heading, this.lines, {this.newPage = false});
}

// PDF에 넣을 사진 한 장(경로 또는 URL)과 설명(날짜 · 분류 · 메모).
class ReportPhoto {
  final String path;
  final String label;
  ReportPhoto(this.path, this.label);
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
  });

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
      b.writeln('\n■ ${s.heading}');
      for (final l in s.lines) {
        b.writeln(l);
      }
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
        lines.isEmpty ? ['해당하는 이슈가 없습니다.'] : lines,
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
Future<Uint8List?> loadPhotoBytes(String path) => _pdfPhotoBytes(path);

Future<Uint8List?> _pdfPhotoBytes(String path) async {
  try {
    Uint8List? bytes;
    if (isRemotePhoto(path)) {
      bytes = await FirebaseStorage.instance
          .refFromURL(path)
          .getData(15 * 1024 * 1024);
    } else {
      final f = File(path);
      if (await f.exists()) bytes = await f.readAsBytes();
    }
    if (bytes == null) return null;
    return await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 1000,
      minHeight: 1000,
      quality: 70,
    );
  } catch (_) {
    return null;
  }
}

// 가로 막대 그래프 한 묶음(PDF용). plan이 있으면 회색 계획 막대가 위에 붙는다.
List<pw.Widget> _chartWidgets(ReportChart c) {
  double mx = 0;
  for (final r in c.rows) {
    if (r.value > mx) mx = r.value;
    if ((r.plan ?? 0) > mx) mx = r.plan!;
  }
  pw.Widget bar(double v, PdfColor color) {
    final a = mx <= 0 ? 0 : ((v / mx).clamp(0.0, 1.0) * 1000).round();
    return pw.Row(
      children: [
        if (a > 0)
          pw.Expanded(
            flex: a,
            child: pw.Container(height: 6, color: color),
          ),
        if (a < 1000)
          pw.Expanded(
            flex: 1000 - a,
            child: pw.Container(height: 6, color: PdfColors.grey200),
          ),
      ],
    );
  }

  return [
    pw.SizedBox(height: 14),
    pw.Text(
      c.heading,
      style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
    ),
    pw.Divider(height: 6),
    for (final r in c.rows)
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          children: [
            pw.SizedBox(
              width: 90,
              child: pw.Text(r.label, style: const pw.TextStyle(fontSize: 10)),
            ),
            pw.Expanded(
              child: pw.Column(
                children: [
                  if (r.plan != null) ...[
                    bar(r.plan!, PdfColors.grey500),
                    pw.SizedBox(height: 2),
                  ],
                  bar(
                    r.value,
                    (r.plan != null && r.plan! > 0 && r.value > r.plan!)
                        ? PdfColors.red
                        : const PdfColor.fromInt(0xFF007580),
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 6),
            pw.SizedBox(
              width: 100,
              child: pw.Text(
                r.valueText,
                style: const pw.TextStyle(fontSize: 9),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
      ),
  ];
}

Future<void> shareReportPdf(ReportDoc doc, {bool withPhotos = false}) async {
  // 사진은 최대 24장까지, 페이지 안에서 잘리지 않게 두 장씩 한 줄로 넣는다.
  final loaded = <(Uint8List, String)>[];
  if (withPhotos) {
    for (final p in doc.photos.take(24)) {
      final b = await _pdfPhotoBytes(p.path);
      if (b != null) loaded.add((b, p.label));
    }
  }
  // 도면 핀: 도면 이미지를 한 번만 받아 크기를 읽고, 핀 위치에 빨간 점을 그린다.
  final planCache = <String, (Uint8List, int, int)>{};
  final pinBoxes = <(Uint8List, double, double, double, String)>[];
  if (withPhotos) {
    for (final pin in doc.pins.take(8)) {
      var c = planCache[pin.planPath];
      if (c == null) {
        final b = await _pdfPhotoBytes(pin.planPath);
        if (b == null) continue;
        try {
          final codec = await ui.instantiateImageCodec(b);
          final fr = await codec.getNextFrame();
          c = (b, fr.image.width, fr.image.height);
          planCache[pin.planPath] = c;
        } catch (_) {
          continue;
        }
      }
      pinBoxes.add((c.$1, c.$3 / c.$2, pin.dx, pin.dy, pin.label));
    }
  }
  final cmp = <(Uint8List, Uint8List, String)>[];
  if (withPhotos) {
    for (final k in doc.compares.take(8)) {
      final a = await _pdfPhotoBytes(k.before);
      final b = await _pdfPhotoBytes(k.after);
      if (a != null && b != null) cmp.add((a, b, k.label));
    }
  }
  final style = ReportStyle.current;
  final hdrCompany = doc.company ?? style.company;
  final hdrManager = doc.manager ?? style.manager;
  final logoSrc = doc.logoB64 ?? style.logoB64;
  pw.MemoryImage? logoImg;
  if (logoSrc != null) {
    try {
      logoImg = pw.MemoryImage(base64Decode(logoSrc));
    } catch (_) {}
  }
  final fontData = await rootBundle.load(
    'assets/fonts/NotoSansKR-VariableFont_wght.ttf',
  );
  final ttf = pw.Font.ttf(fontData);
  final pdf = pw.Document(
    theme: pw.ThemeData.withFont(base: ttf, bold: ttf),
  );
  pdf.addPage(
    pw.MultiPage(
      build: (ctx) => [
        if (logoImg != null || hdrCompany.isNotEmpty || hdrManager.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 10),
            child: pw.Row(
              children: [
                if (logoImg != null)
                  pw.Container(
                    width: 44,
                    height: 44,
                    margin: const pw.EdgeInsets.only(right: 10),
                    child: pw.Image(logoImg, fit: pw.BoxFit.contain),
                  ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (hdrCompany.isNotEmpty)
                      pw.Text(
                        hdrCompany,
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    if (hdrManager.isNotEmpty)
                      pw.Text(
                        '담당 ${hdrManager}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                  ],
                ),
              ],
            ),
          ),
        pw.Text(
          '${doc.title} ${doc.heading}',
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(doc.period, style: const pw.TextStyle(fontSize: 11)),
        for (final s in doc.sections) ...[
          if (s.newPage) pw.NewPage() else pw.SizedBox(height: 14),
          pw.Text(
            s.heading,
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.Divider(height: 6),
          for (final l in s.lines)
            pw.Text(l, style: const pw.TextStyle(fontSize: 11, lineSpacing: 2)),
        ],
        if (cmp.isNotEmpty) ...[
          pw.SizedBox(height: 14),
          pw.Text(
            '처리 전 / 후',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.Divider(height: 6),
          for (final k in cmp)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(k.$3, style: const pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(height: 3),
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          children: [
                            pw.Container(
                              height: 150,
                              width: double.infinity,
                              child: pw.Image(
                                pw.MemoryImage(k.$1),
                                fit: pw.BoxFit.contain,
                              ),
                            ),
                            pw.Text(
                              '처리 전',
                              style: const pw.TextStyle(fontSize: 9),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Expanded(
                        child: pw.Column(
                          children: [
                            pw.Container(
                              height: 150,
                              width: double.infinity,
                              child: pw.Image(
                                pw.MemoryImage(k.$2),
                                fit: pw.BoxFit.contain,
                              ),
                            ),
                            pw.Text(
                              '처리 후',
                              style: const pw.TextStyle(fontSize: 9),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
        for (final c in doc.charts) ..._chartWidgets(c),
        if (pinBoxes.isNotEmpty) ...[
          pw.SizedBox(height: 14),
          pw.Text(
            '작업/이슈 위치 (도면)',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.Divider(height: 6),
          for (int i = 0; i < pinBoxes.length; i += 2)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  for (int j = i; j < i + 2; j++)
                    pw.Expanded(
                      child: j < pinBoxes.length
                          ? pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.SizedBox(
                                  width: 230,
                                  height: 230 * pinBoxes[j].$2,
                                  child: pw.Stack(
                                    children: [
                                      pw.Image(
                                        pw.MemoryImage(pinBoxes[j].$1),
                                        width: 230,
                                        height: 230 * pinBoxes[j].$2,
                                        fit: pw.BoxFit.fill,
                                      ),
                                      pw.Positioned(
                                        left: pinBoxes[j].$3 * 230 - 6,
                                        top:
                                            pinBoxes[j].$4 *
                                                230 *
                                                pinBoxes[j].$2 -
                                            6,
                                        child: pw.Container(
                                          width: 12,
                                          height: 12,
                                          decoration: const pw.BoxDecoration(
                                            color: PdfColors.red,
                                            shape: pw.BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                pw.SizedBox(height: 3),
                                pw.Text(
                                  pinBoxes[j].$5,
                                  style: const pw.TextStyle(fontSize: 9),
                                ),
                              ],
                            )
                          : pw.SizedBox(),
                    ),
                ],
              ),
            ),
        ],
        if (loaded.isNotEmpty) ...[
          pw.SizedBox(height: 14),
          pw.Text(
            '사진 (${loaded.length}장)',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.Divider(height: 6),
          for (int i = 0; i < loaded.length; i += 2)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  for (int j = i; j < i + 2; j++)
                    pw.Expanded(
                      child: j < loaded.length
                          ? pw.Padding(
                              padding: const pw.EdgeInsets.only(right: 8),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Container(
                                    height: 170,
                                    width: double.infinity,
                                    child: pw.Image(
                                      pw.MemoryImage(loaded[j].$1),
                                      fit: pw.BoxFit.contain,
                                    ),
                                  ),
                                  pw.SizedBox(height: 3),
                                  pw.Text(
                                    loaded[j].$2,
                                    style: const pw.TextStyle(fontSize: 9),
                                  ),
                                ],
                              ),
                            )
                          : pw.SizedBox(),
                    ),
                ],
              ),
            ),
        ],
        if (style.signature) ...[
          pw.SizedBox(height: 30),
          pw.Row(
            children: [
              for (final (label, sigImg) in [
                (style.sig1, style.sig1B64),
                (style.sig2, style.sig2B64),
              ])
                pw.Expanded(
                  child: pw.Container(
                    height: 64,
                    margin: const pw.EdgeInsets.only(right: 12),
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey500),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          '$label (서명)',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                        if (sigImg != null)
                          pw.Image(
                            pw.MemoryImage(base64Decode(sigImg)),
                            height: 34,
                            fit: pw.BoxFit.contain,
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    ),
  );
  final dir = await getTemporaryDirectory();
  final file = File(
    '${dir.path}/report_${DateTime.now().millisecondsSinceEpoch}.pdf',
  );
  await file.writeAsBytes(await pdf.save());
  // ignore: deprecated_member_use
  await Share.shareXFiles([
    XFile(file.path),
  ], text: '${doc.title} ${doc.heading}');
}

// ───────────────────────── 통합 검색 ─────────────────────────
class SearchHit {
  final Map<String, dynamic> log;
  final String kind; // 일보 | 이슈
  final String title;
  final String snippet;
  final Map item; // 원본 일보/이슈 Map(바로 열기용)
  SearchHit(this.log, this.kind, this.title, this.snippet, this.item);
}

String _snippet(String text, String q) {
  final i = text.toLowerCase().indexOf(q.toLowerCase());
  if (i < 0) return text.length > 60 ? '${text.substring(0, 60)}…' : text;
  final s = (i - 20).clamp(0, text.length);
  final e = (i + q.length + 40).clamp(0, text.length);
  return '${s > 0 ? '…' : ''}${text.substring(s, e).replaceAll('\n', ' ')}${e < text.length ? '…' : ''}';
}

List<SearchHit> searchProjects(
  List<Map<String, dynamic>> logs,
  String query, {
  String? kind, // '일보' | '이슈' | null(전체)
  String? projectId,
  DateTime? from,
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return [];
  final hits = <SearchHit>[];
  for (final log in logs) {
    if (projectId != null && log['id']?.toString() != projectId) continue;
    final name = log['name']?.toString() ?? '';
    for (final r in (log['daily_reports'] as List? ?? []).whereType<Map>()) {
      if (kind == '이슈') break;
      if (from != null && reportDateOf(r).isBefore(from)) continue;
      final wt = r['work_type'] is List
          ? (r['work_type'] as List).join(' ')
          : (r['work_type']?.toString() ?? '');
      final fields = [
        r['note'],
        r['materials_used'],
        r['next_day_plan'],
        r['as_built_reason'],
        wt,
      ].map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty);
      for (final f in fields) {
        if (f.toLowerCase().contains(q)) {
          hits.add(
            SearchHit(log, '일보', '$name · ${r['date']}', _snippet(f, q), r),
          );
          break;
        }
      }
    }
    for (final p in (log['punch_lists'] as List? ?? []).whereType<Map>()) {
      if (kind == '일보') break;
      if (from != null && p['created_at'] != null) {
        if (dayOnly(asDate(p['created_at'])).isBefore(from)) continue;
      }
      final f = [
        p['content'],
        p['location'],
      ].map((e) => e?.toString() ?? '').join(' ');
      if (f.toLowerCase().contains(q)) {
        hits.add(
          SearchHit(
            log,
            '이슈',
            '$name · ${p['location'] ?? ''}',
            _snippet(p['content']?.toString() ?? f, q),
            p,
          ),
        );
      }
    }
  }
  return hits;
}

// ───────────────────────── 일보 알림 ─────────────────────────
const int _kReminderId = 918273;
const String _kReminderChannel = 'daily_report_reminder';
const String _kPrefEnabled = 'report_reminder_enabled';
const String _kPrefMinutes = 'report_reminder_minutes';
const String _kPrefWeekly = 'weekly_report_reminder_enabled';
const int _kWeeklyId = 918274;
// 금요일 알림을 누르면 주간 업무 보고를 바로 여는 데 쓰는 표식.
const String kWeeklyReportPayload = 'work_weekly_report';
bool _tzReady = false;

Future<({bool enabled, int minutes, bool weekly})> loadReportReminder() async {
  final p = await SharedPreferences.getInstance();
  return (
    enabled: p.getBool(_kPrefEnabled) ?? true,
    minutes: p.getInt(_kPrefMinutes) ?? 18 * 60,
    weekly: p.getBool(_kPrefWeekly) ?? true,
  );
}

Future<void> saveReportReminder(
  bool enabled,
  int minutes, {
  bool weekly = true,
}) async {
  final p = await SharedPreferences.getInstance();
  await p.setBool(_kPrefEnabled, enabled);
  await p.setInt(_kPrefMinutes, minutes);
  await p.setBool(_kPrefWeekly, weekly);
}

// 매주 금요일 17:00에 "이번 주 보고서 초안" 알림(진행중 프로젝트가 있을 때).
Future<void> _syncWeeklyReminder(bool on) async {
  await flutterLocalNotificationsPlugin.cancel(id: _kWeeklyId);
  if (!on) return;
  final now = DateTime.now();
  var at = DateTime(now.year, now.month, now.day, 17, 0);
  while (at.weekday != DateTime.friday || !at.isAfter(now)) {
    at = at.add(const Duration(days: 1));
  }
  await flutterLocalNotificationsPlugin.zonedSchedule(
    id: _kWeeklyId,
    title: '주간 보고서',
    body: '지난·이번·다음주 업무를 정리해 공유해보세요. 눌러서 바로 열 수 있어요.',
    payload: kWeeklyReportPayload,
    scheduledDate: tz.TZDateTime.from(at, tz.local),
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        _kReminderChannel,
        '작업일보 알림',
        channelDescription: '작업일보 작성 리마인더',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
  );
}

// 진행중 프로젝트가 있는데 오늘 일보가 아직 없으면 오늘 정해진 시각에, 이미
// 썼으면 내일부터 매일 알린다. 앱을 열 때/일보 저장 후에 다시 맞춘다.
Future<void> syncReportReminder(List<Map<String, dynamic>> logs) async {
  try {
    final pref = await loadReportReminder();
    await flutterLocalNotificationsPlugin.cancel(id: _kReminderId);
    final active = logs.where((l) => l['status'] != 'DONE').toList();
    if (!_tzReady) {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
      _tzReady = true;
    }
    await _syncWeeklyReminder(pref.weekly && active.isNotEmpty);
    if (!pref.enabled || active.isEmpty) return;

    final now = DateTime.now();
    final todayStr =
        '${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';
    final wroteToday = active.any(
      (l) => (l['daily_reports'] as List? ?? []).whereType<Map>().any(
        (r) => r['date'] == todayStr,
      ),
    );
    var at = DateTime(
      now.year,
      now.month,
      now.day,
      pref.minutes ~/ 60,
      pref.minutes % 60,
    );
    if (wroteToday || !at.isAfter(now)) at = at.add(const Duration(days: 1));

    const channel = AndroidNotificationChannel(
      _kReminderChannel,
      '작업일보 알림',
      description: '작업일보 작성 리마인더',
      importance: Importance.high,
    );
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: _kReminderId,
      title: '작업일보',
      body: '오늘 작업 일보 아직 안 썼어요. 기억날 때 간단히 남겨두세요.',
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _kReminderChannel,
          '작업일보 알림',
          channelDescription: '작업일보 작성 리마인더',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  } catch (e) {
    debugPrint('일보 알림 설정 실패: $e');
  }
}
