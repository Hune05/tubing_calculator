// 접지바 가공 지시서(PDF, A4): 규격·자르는 길이 요약, 위에서 본 모양(구멍 자리)·꺾은 뒤 옆모습 그림,
// 꺾기 표, 구멍 위치 표(접지·챙/탭·러그), 판넬 취부 자리, 볼트 세트, 주의, 작성·검토 서명 칸.
// 미리보기로 먼저 보이고, 공유는 미리보기의 버튼을 눌러야만 된다(SteelPdfPreviewPage).
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../core/utils/pdf_fonts.dart';
import '../steel_cutting/screens/steel_pdf_preview_page.dart';
import 'busbar_bend.dart';
import 'busbar_ground.dart';

const PdfColor _ink = PdfColor.fromInt(0xFF1F2933);
const PdfColor _grey = PdfColor.fromInt(0xFF6B7280);
const PdfColor _label = PdfColor.fromInt(0xFF374151);
const PdfColor _line = PdfColor.fromInt(0xFFD1D5DB);
const PdfColor _head = PdfColor.fromInt(0xFFF1F5F9);
const PdfColor _teal = PdfColor.fromInt(0xFF0F9D8F);
const PdfColor _orange = PdfColor.fromInt(0xFFE08A1E);
const PdfColor _blue = PdfColor.fromInt(0xFF2563EB);
const PdfColor _copper = PdfColor.fromInt(0xFFD9976A);
const PdfColor _copperDark = PdfColor.fromInt(0xFFB66A3C);
const PdfColor _amberBg = PdfColor.fromInt(0xFFFFF4E0);

/// PDF 한 구역: 제목과 줄 목록.
class GroundPdfSection {
  final String title;
  final List<String> lines;
  const GroundPdfSection(this.title, this.lines);
}

/// 지시서에 들어갈 내용. 글은 화면이 이미 만든 것을 그대로 받는다.
class GroundPdfInput {
  /// 작업 이름(없으면 빈 글).
  final String title;
  final GroundBarPlan plan;

  /// 부스바 두께·폭(mm)과 중립선 반경(옆모습 그림용).
  final double thickness, width, rho;

  /// 요약(항목, 값).
  final List<(String, String)> summary;

  /// 꺾기 표 줄: [번호, 위치, 시작선, 끝선].
  final List<List<String>> bendRows;
  final List<GroundPdfSection> sections;

  /// 주의·알림 글.
  final List<String> notes;

  const GroundPdfInput({
    required this.title,
    required this.plan,
    required this.thickness,
    required this.width,
    required this.rho,
    required this.summary,
    required this.bendRows,
    required this.sections,
    required this.notes,
  });
}

String _day(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

PdfColor _bendColor(double turn) => turn >= 0 ? _teal : _orange;

String _n(double v, [int d = 1]) {
  var s = v.toStringAsFixed(d);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s;
}

/// 접지바 가공 지시서 PDF 바이트.
Future<Uint8List> buildGroundBarPdf(
  GroundPdfInput input, {
  DateTime? date,
}) async {
  final fonts = await loadKoreanPdfFonts();
  final day = date ?? DateTime.now();
  final p = input.plan;
  final doc = pw.Document(theme: fonts.theme);

  pw.Widget cell(
    String t, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.center,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
    child: pw.Text(
      t,
      textAlign: align,
      style: pw.TextStyle(
        fontSize: 9,
        color: _ink,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );

  pw.Widget sectionTitle(String t) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
    child: pw.Text(
      t,
      style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold),
    ),
  );

  // ── 요약 ──
  final summaryRows = <pw.TableRow>[
    for (final (k, v) in input.summary)
      pw.TableRow(
        children: [
          pw.Container(
            color: _head,
            child: cell(k, bold: true, align: pw.TextAlign.left),
          ),
          cell(v, align: pw.TextAlign.left),
        ],
      ),
  ];

  // ── 위에서 본 모양 ──
  const drawW = 500.0;
  final len = math.max(p.length, 1.0);
  final sc = math.min(drawW / len, 90 / math.max(input.width, 1.0));
  final barW = len * sc, barH = input.width * sc;
  final topH = barH + 44;
  final x0 = (drawW - barW) / 2;
  const yBase = 26.0; // 막대 아래 여백(치수 글)
  pw.Widget topView() {
    final holes = [...p.tabHoleList, ...p.groundHoles, ...p.lugHoleList];
    final lugIds = {for (final h in p.lugHoleList) h.id};
    return pw.SizedBox(
      width: drawW,
      height: topH,
      child: pw.Stack(
        children: [
          pw.CustomPaint(
            size: PdfPoint(drawW, topH),
            painter: (canvas, size) {
              canvas
                ..setFillColor(_copper)
                ..setStrokeColor(_copperDark)
                ..setLineWidth(0.8)
                ..drawRRect(x0, yBase, barW, barH, 2, 2)
                ..fillAndStrokePath();
              for (final b in p.bends) {
                final c = _bendColor(b.turn);
                final bx = x0 + b.start * sc;
                final bw = math.max((b.end - b.start) * sc, 1.5);
                canvas
                  ..setFillColor(c)
                  ..drawRect(bx, yBase, bw, barH)
                  ..fillPath()
                  ..setStrokeColor(c)
                  ..setLineWidth(1)
                  ..moveTo(bx, yBase - 4)
                  ..lineTo(bx, yBase + barH + 4)
                  ..strokePath()
                  ..moveTo(bx + bw, yBase - 4)
                  ..lineTo(bx + bw, yBase + barH + 4)
                  ..strokePath();
              }
              for (final h in holes) {
                final cx = x0 + h.x * sc;
                final cy = yBase + barH - h.y * sc;
                final r = math.max(h.dia * sc / 2, 1.2);
                canvas
                  ..setFillColor(PdfColors.white)
                  ..setStrokeColor(
                    h.custom ? _orange : PdfColor.fromInt(0xFF555555),
                  )
                  ..setLineWidth(h.custom ? 1.4 : 0.6)
                  ..drawEllipse(cx, cy, r, r)
                  ..fillAndStrokePath();
                if (lugIds.contains(h.id)) {
                  canvas
                    ..setStrokeColor(_blue)
                    ..setLineWidth(1.4)
                    ..drawEllipse(cx, cy, r + 2.5, r + 2.5)
                    ..strokePath();
                }
              }
            },
          ),
          pw.Positioned(
            left: x0,
            top: topH - yBase + 4,
            child: pw.Text(
              '0',
              style: const pw.TextStyle(fontSize: 8, color: _grey),
            ),
          ),
          pw.Positioned(
            left: x0 + barW - 30,
            top: topH - yBase + 4,
            child: pw.SizedBox(
              width: 30,
              child: pw.Text(
                _n(p.length),
                textAlign: pw.TextAlign.right,
                style: const pw.TextStyle(fontSize: 8, color: _grey),
              ),
            ),
          ),
          pw.Positioned(
            left: 0,
            top: 0,
            child: pw.Text(
              '${_n(p.length)} × ${_n(input.width)} mm · 구멍 ${holes.length}개 (파란 테두리 = 러그 구멍, 주황 = 크기 바꾼 구멍, 녹색/주황 띠 = 꺾기)',
              style: const pw.TextStyle(fontSize: 8, color: _grey),
            ),
          ),
        ],
      ),
    );
  }

  // ── 꺾은 뒤 옆모습 ──
  pw.Widget sideView() {
    final bp = p.bendPlan!;
    final pts = busbarShape(bp, input.rho, startHeadingDeg: p.startHeading);
    var minX = 0.0, maxX = 0.0, minY = 0.0, maxY = 0.0;
    for (final q in pts) {
      minX = math.min(minX, q.x);
      maxX = math.max(maxX, q.x);
      minY = math.min(minY, q.y);
      maxY = math.max(maxY, q.y);
    }
    const sideH = 130.0, pad = 22.0;
    final w = math.max(maxX - minX, 1.0), h = math.max(maxY - minY, 1.0);
    final s2 = math.min((drawW - 2 * pad) / w, (sideH - 2 * pad) / h);
    final ox = (drawW - w * s2) / 2 - minX * s2;
    final oy = (sideH - h * s2) / 2 - minY * s2;
    Offset map(math.Point<double> q) => Offset(ox + q.x * s2, oy + q.y * s2);
    final stroke = math.max(input.thickness * s2, 3.0);
    return pw.SizedBox(
      width: drawW,
      height: sideH,
      child: pw.Stack(
        children: [
          pw.CustomPaint(
            size: const PdfPoint(drawW, sideH),
            painter: (canvas, size) {
              canvas
                ..setStrokeColor(_copperDark)
                ..setLineWidth(stroke)
                ..setLineJoin(PdfLineJoin.round)
                ..setLineCap(PdfLineCap.butt);
              final a = map(pts.first);
              canvas.moveTo(a.dx, a.dy);
              for (final q in pts.skip(1)) {
                final o = map(q);
                canvas.lineTo(o.dx, o.dy);
              }
              canvas.strokePath();
            },
          ),
          for (var i = 0; i < p.bends.length; i++)
            () {
              final o = map(busbarPointAt(pts, p.bends[i].center));
              return pw.Positioned(
                left: o.dx - 7,
                top: sideH - o.dy - 7,
                child: pw.Container(
                  width: 14,
                  height: 14,
                  alignment: pw.Alignment.center,
                  decoration: pw.BoxDecoration(
                    color: _bendColor(p.bends[i].turn),
                    shape: pw.BoxShape.circle,
                  ),
                  child: pw.Text(
                    '${i + 1}',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              );
            }(),
          pw.Positioned(
            left: 0,
            top: 0,
            child: pw.Text(
              '옆에서 본 모양(중립선 길이 ${_n(p.length)}mm) · 번호는 아래 꺾기 표 번호',
              style: const pw.TextStyle(fontSize: 8, color: _grey),
            ),
          ),
        ],
      ),
    );
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 34, 36, 34),
      footer: (c) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          '${c.pageNumber} / ${c.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: _grey),
        ),
      ),
      build: (context) => [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              '접지바 가공 지시서',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              _day(day),
              style: const pw.TextStyle(fontSize: 10, color: _label),
            ),
          ],
        ),
        if (input.title.trim().isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 3),
            child: pw.Text(
              input.title.trim(),
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
          ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: _line, width: 0.6),
          columnWidths: const {
            0: pw.FixedColumnWidth(92),
            1: pw.FlexColumnWidth(),
          },
          children: summaryRows,
        ),
        sectionTitle('위에서 본 모양'),
        topView(),
        if (p.bendPlan != null) ...[sectionTitle('꺾은 뒤 모양'), sideView()],
        if (input.bendRows.isNotEmpty) ...[
          sectionTitle('꺾기 (왼쪽 끝에서 잰 거리, mm)'),
          pw.Table(
            border: pw.TableBorder.all(color: _line, width: 0.6),
            columnWidths: const {
              0: pw.FixedColumnWidth(34),
              1: pw.FlexColumnWidth(),
              2: pw.FixedColumnWidth(70),
              3: pw.FixedColumnWidth(70),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _head),
                children: [
                  for (final h in ['번호', '위치', '꺾기 시작선', '꺾기 끝선'])
                    cell(h, bold: true),
                ],
              ),
              for (final r in input.bendRows)
                pw.TableRow(
                  children: [
                    cell(r[0]),
                    cell(r[1], align: pw.TextAlign.left),
                    cell(r[2]),
                    cell(r[3]),
                  ],
                ),
            ],
          ),
        ],
        for (final sec in input.sections) ...[
          sectionTitle(sec.title),
          for (final l in sec.lines)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2.5),
              child: pw.Text(
                l,
                style: const pw.TextStyle(fontSize: 9.5, color: _ink),
              ),
            ),
        ],
        if (input.notes.isNotEmpty) ...[
          sectionTitle('주의'),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            color: _amberBg,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                for (final n in input.notes)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 3),
                    child: pw.Text(
                      '· $n',
                      style: const pw.TextStyle(fontSize: 9, color: _ink),
                    ),
                  ),
              ],
            ),
          ),
        ],
        pw.SizedBox(height: 16),
        pw.Row(
          children: [
            for (final who in ['작성', '검토', '승인'])
              pw.Expanded(
                child: pw.Container(
                  height: 44,
                  margin: const pw.EdgeInsets.only(right: 6),
                  padding: const pw.EdgeInsets.all(4),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: _line, width: 0.6),
                  ),
                  child: pw.Text(
                    who,
                    style: const pw.TextStyle(fontSize: 8, color: _grey),
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
  return doc.save();
}

String groundBarFileName(String title, DateTime date) {
  final t = title.trim().isEmpty
      ? 'noname'
      : title.trim().replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
  return 'ground_bar_${t}_${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}.pdf';
}

/// 지시서를 만들어 미리보기로 보여 준다. 공유는 미리보기의 버튼을 눌러야만 된다.
Future<void> openGroundBarPdf(
  BuildContext context,
  GroundPdfInput input,
) async {
  final now = DateTime.now();
  final bytes = await buildGroundBarPdf(input, date: now);
  final fileName = groundBarFileName(input.title, now);
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => SteelPdfPreviewPage(
        bytes: bytes,
        fileName: fileName,
        title: '접지바 가공 지시서 미리보기',
        onShare: () async {
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/$fileName');
          await file.writeAsBytes(bytes);
          // ignore: deprecated_member_use
          await Share.shareXFiles([
            XFile(file.path),
          ], text: '접지바 가공 지시서 ${input.title.trim()}');
        },
      ),
    ),
  );
}
