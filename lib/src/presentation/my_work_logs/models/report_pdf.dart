import 'dart:convert';
import '../../../core/utils/pdf_fonts.dart';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' show PdfColor, PdfColors;
import 'package:pdf/widgets.dart' as pw;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'photo_store.dart';
import 'report_style.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'project_phase.dart';
import 'report_tools.dart';

// 🚀 보고서 PDF 만들기·공유·정리.
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

// 사진을 두 장씩 한 줄로 배치한다(페이지 안에서 잘리지 않게 줄 단위 위젯).
List<pw.Widget> _photoRows(List<(Uint8List, String)> items) {
  return [
    for (int i = 0; i < items.length; i += 2)
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (int j = i; j < i + 2; j++)
              pw.Expanded(
                child: j < items.length
                    ? pw.Padding(
                        padding: const pw.EdgeInsets.only(right: 8),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Container(
                              height: 170,
                              width: double.infinity,
                              child: pw.Image(
                                pw.MemoryImage(items[j].$1),
                                fit: pw.BoxFit.contain,
                              ),
                            ),
                            pw.SizedBox(height: 3),
                            pw.Text(
                              items[j].$2,
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
  ];
}

// 프로젝트 완료 시 마무리 보고서: 전체 기간 보고서에 총 통계와 결과 정리를 더한다.
ReportDoc buildFinalReportDoc(Map<String, dynamic> log) {
  DateTime? first;
  int days = 0, manDays = 0, points = 0, wiring = 0;
  for (final r in (log['daily_reports'] as List? ?? []).whereType<Map>()) {
    final d = reportDateOf(r);
    if (first == null || d.isBefore(first)) first = d;
    days++;
    manDays += (r['worker_count'] as num?)?.toInt() ?? 1;
    points += (r['points'] as num?)?.toInt() ?? 0;
    wiring += (r['wiring_points'] as num?)?.toInt() ?? 0;
  }
  final end = log['completedAt'] != null
      ? asDate(log['completedAt'])
      : DateTime.now();
  final doc = buildReportDoc(
    log,
    first ?? end.subtract(const Duration(days: 30)),
    end,
  );
  final punches = (log['punch_lists'] as List? ?? []).whereType<Map>().toList();
  final resolved = punches.where((p) => p['is_completed'] == true).length;
  doc.sections.insert(
    1,
    ReportSection('총 통계', [
      '· 작업 $days일 · 총 투입 $manDays인·일',
      if (points > 0) '· 벤딩 총 $points pt',
      if (wiring > 0) '· 결선 총 $wiring개소',
      '· 이슈 ${punches.length}건 중 $resolved건 처리',
    ]),
  );
  final retro = Map<String, dynamic>.from((log['retro'] as Map?) ?? {});
  final cause = (retro['cause']?.toString() ?? '').trim();
  final lesson = (retro['lesson']?.toString() ?? '').trim();
  if (cause.isNotEmpty || lesson.isNotEmpty) {
    doc.sections.add(
      ReportSection('결과 정리', [
        if (cause.isNotEmpty) '· 지연/문제 원인: $cause',
        if (lesson.isNotEmpty) '· 다음에 적용할 점: $lesson',
      ]),
    );
  }
  return doc.withHeading('마무리 보고서');
}

// PDF 파일 이름: 프로젝트_보고서종류_날짜.pdf (폴더/특수문자는 뺀다).
String reportPdfFileName(ReportDoc doc, [DateTime? now]) {
  String safe(String s) => s
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
      .trim()
      .replaceAll(RegExp(r'\s+'), '_');
  final d = now ?? DateTime.now();
  final stamp =
      doc.fileStamp ??
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
  final title = safe(doc.title);
  final kind = safe(doc.heading);
  return '${title.isEmpty ? '보고서' : title}_${kind}_$stamp.pdf';
}

// 공유하려고 임시 폴더에 만든 PDF는 쌓이기만 하므로, 오래된 것(기본 3일)을 지운다.
// 폴더 바로 아래의 .pdf 파일만 대상이고, 지운 개수를 돌려준다.
Future<int> cleanupOldPdfs(
  Directory dir, {
  Duration maxAge = const Duration(days: 3),
  DateTime? now,
}) async {
  var removed = 0;
  final limit = (now ?? DateTime.now()).subtract(maxAge);
  try {
    await for (final e in dir.list(followLinks: false)) {
      if (e is! File || !e.path.toLowerCase().endsWith('.pdf')) continue;
      try {
        if ((await e.lastModified()).isBefore(limit)) {
          await e.delete();
          removed++;
        }
      } catch (_) {}
    }
  } catch (_) {}
  return removed;
}

// 정리를 실행하고 결과(마지막 실행 시간·지운 개수·누적 개수)를 기록한다.
Future<int> runPdfCleanup(
  Directory dir, {
  DateTime? now,
  Duration maxAge = const Duration(days: 3),
}) async {
  final n = await cleanupOldPdfs(dir, now: now, maxAge: maxAge);
  try {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _kPrefPdfCleanupLast,
      (now ?? DateTime.now()).toIso8601String(),
    );
    await p.setInt(_kPrefPdfCleanupLastRemoved, n);
    await p.setInt(
      _kPrefPdfCleanupTotal,
      (p.getInt(_kPrefPdfCleanupTotal) ?? 0) + n,
    );
  } catch (_) {}
  return n;
}

const String _kPrefPdfCleanupLast = 'pdf_cleanup_last';
const String _kPrefPdfCleanupLastRemoved = 'pdf_cleanup_last_removed';
const String _kPrefPdfCleanupTotal = 'pdf_cleanup_total';

Future<({DateTime? lastRun, int lastRemoved, int total})>
loadPdfCleanupRecord() async {
  final p = await SharedPreferences.getInstance();
  return (
    lastRun: DateTime.tryParse(p.getString(_kPrefPdfCleanupLast) ?? ''),
    lastRemoved: p.getInt(_kPrefPdfCleanupLastRemoved) ?? 0,
    total: p.getInt(_kPrefPdfCleanupTotal) ?? 0,
  );
}

// 같은 이름의 파일이 이미 있으면 이름 뒤에 (2), (3)…을 붙여 덮어쓰지 않는다.
String uniquePdfName(String name, bool Function(String) exists) {
  if (!exists(name)) return name;
  final base = name.toLowerCase().endsWith('.pdf')
      ? name.substring(0, name.length - 4)
      : name;
  for (var i = 2; ; i++) {
    final c = '$base($i).pdf';
    if (!exists(c)) return c;
  }
}

Future<Uint8List> buildReportPdfBytes(
  ReportDoc doc, {
  bool withPhotos = false,
}) async {
  // 사진은 최대 24장까지, 페이지 안에서 잘리지 않게 두 장씩 한 줄로 넣는다.
  final loaded = <(Uint8List, String, String?)>[];
  if (withPhotos) {
    for (final p in doc.photos.take(24)) {
      final b = await _pdfPhotoBytes(p.path);
      if (b != null) loaded.add((b, p.label, p.group));
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
  final pdfFonts = await loadKoreanPdfFonts();
  final pdf = pw.Document(theme: pdfFonts.theme);
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
                        '담당 $hdrManager',
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
        if (doc.showAuthorLine)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text(
              doc.authorLine(),
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
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
          for (final g in <String?>{for (final e in loaded) e.$3}) ...[
            if (g != null)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6, top: 4),
                child: pw.Text(
                  '■ $g',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ..._photoRows([
              for (final e in loaded)
                if (e.$3 == g) (e.$1, e.$2),
            ]),
          ],
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
  return pdf.save();
}

// 공유창이 닫힌 뒤 화면 아래에 띄울 안내 문구. 안드로이드는 공유 결과를 항상 알 수 있는 게 아니라
// (unavailable) 그때는 "만들었습니다"까지만 말하고 보냈는지는 단정하지 않는다.
String pdfShareNotice(ShareResultStatus status, String what) {
  switch (status) {
    case ShareResultStatus.success:
      return '$what를 공유했습니다.';
    case ShareResultStatus.dismissed:
      return '$what를 만들었지만 공유하지 않고 닫았습니다. 다시 공유하려면 다시 만드십시오.';
    case ShareResultStatus.unavailable:
      return '$what를 만들어 공유창을 열었습니다. 공유 여부는 확인할 수 없습니다.';
  }
}

// 마무리 보고서를 만들어 공유창을 연 결과를 프로젝트에 남긴다(나중에 "보냈는지" 확인용).
void recordFinalReportShare(
  Map<String, dynamic> log,
  ShareResultStatus status, [
  DateTime? now,
]) {
  log['finalReportShare'] = {
    'status': status.name,
    'at': now ?? DateTime.now(),
  };
}

// 결과 정리 카드에 보여 줄 한 줄. 기록이 없으면 null.
String? finalReportShareLabel(Map<String, dynamic> log) {
  final r = log['finalReportShare'];
  if (r is! Map) return null;
  final at = r['at'] == null ? null : asDate(r['at']);
  final when = at == null
      ? ''
      : '${at.month}/${at.day} ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')} ';
  switch (r['status']?.toString()) {
    case 'success':
      return '$when공유함';
    case 'dismissed':
      return '$when만들었지만 공유하지 않음';
    case 'unavailable':
      return '$when만들어 공유창을 열었음(공유 여부는 확인할 수 없음)';
  }
  return null;
}

// 보고서 PDF를 두는 임시 폴더. 정리(runPdfCleanup)도 이 폴더만 본다 —
// 예전엔 임시 폴더 맨 위의 .pdf를 다 지워서 다른 기능(마킹 시트·배치도 등)이
// 공유하려고 둔 PDF까지 지울 수 있었다.
Future<Directory> reportPdfDir() async {
  final dir = Directory('${(await getTemporaryDirectory()).path}/report_pdf');
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

Future<ShareResult> shareReportPdf(
  ReportDoc doc, {
  bool withPhotos = false,
}) async {
  final bytes = await buildReportPdfBytes(doc, withPhotos: withPhotos);
  final dir = await reportPdfDir();
  final name = uniquePdfName(
    reportPdfFileName(doc),
    (n) => File('${dir.path}/$n').existsSync(),
  );
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(bytes);
  // ignore: deprecated_member_use
  return Share.shareXFiles([
    XFile(file.path),
  ], text: '${doc.title} ${doc.heading}');
}
