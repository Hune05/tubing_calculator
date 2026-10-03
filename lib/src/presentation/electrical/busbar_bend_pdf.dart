// 부스바 절곡 지시서(PDF, A4): 규격·치수 요약, 꺾은 뒤 옆모습 그림, 자르기 전 마킹 그림, 꺾기 표, 주의,
// 작성·검토·승인 칸. 미리보기로 먼저 보이고, 공유는 미리보기의 버튼을 눌러야만 된다.
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

const PdfColor _ink = PdfColor.fromInt(0xFF1F2933);
const PdfColor _grey = PdfColor.fromInt(0xFF6B7280);
const PdfColor _line = PdfColor.fromInt(0xFFD1D5DB);
const PdfColor _head = PdfColor.fromInt(0xFFF1F5F9);
const PdfColor _teal = PdfColor.fromInt(0xFF0F9D8F);
const PdfColor _orange = PdfColor.fromInt(0xFFE08A1E);
const PdfColor _copper = PdfColor.fromInt(0xFFD9976A);
const PdfColor _copperDark = PdfColor.fromInt(0xFFB66A3C);
const PdfColor _amberBg = PdfColor.fromInt(0xFFFFF4E0);

class BendPdfInput {
  final String title;
  final BusbarBendPlan plan;
  final double thickness, rho;
  final List<(String, String)> summary;
  final List<String> notes;
  const BendPdfInput({
    required this.title,
    required this.plan,
    required this.thickness,
    required this.rho,
    required this.summary,
    required this.notes,
  });
}

PdfColor _col(double turn) => turn >= 0 ? _teal : _orange;

String _n(double v, [int d = 1]) {
  var s = v.toStringAsFixed(d);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s;
}

Future<Uint8List> buildBendPdf(BendPdfInput input, {DateTime? date}) async {
  final fonts = await loadKoreanPdfFonts();
  final day = date ?? DateTime.now();
  final p = input.plan;
  final doc = pw.Document(theme: fonts.theme);

  pw.Widget cell(String t, {bool bold = false, pw.TextAlign? align}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
        child: pw.Text(
          t,
          textAlign: align ?? pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 9.5,
            color: _ink,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );
  pw.Widget title(String t) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
    child: pw.Text(
      t,
      style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold),
    ),
  );

  const w = 500.0;
  // 꺾은 뒤 옆모습
  final pts = busbarShape(p, input.rho);
  var minX = 0.0, maxX = 0.0, minY = 0.0, maxY = 0.0;
  for (final q in pts) {
    minX = math.min(minX, q.x);
    maxX = math.max(maxX, q.x);
    minY = math.min(minY, q.y);
    maxY = math.max(maxY, q.y);
  }
  const sideH = 150.0, pad = 22.0;
  final sw = math.max(maxX - minX, 1.0), sh = math.max(maxY - minY, 1.0);
  final s2 = math.min((w - 2 * pad) / sw, (sideH - 2 * pad) / sh);
  final ox = (w - sw * s2) / 2 - minX * s2;
  final oy = (sideH - sh * s2) / 2 - minY * s2;
  Offset map(math.Point<double> q) => Offset(ox + q.x * s2, oy + q.y * s2);

  pw.Widget side() => pw.SizedBox(
    width: w,
    height: sideH,
    child: pw.Stack(
      children: [
        pw.CustomPaint(
          size: const PdfPoint(w, sideH),
          painter: (c, size) {
            c
              ..setStrokeColor(_copperDark)
              ..setLineWidth(math.max(input.thickness * s2, 3.0))
              ..setLineJoin(PdfLineJoin.round)
              ..setLineCap(PdfLineCap.butt);
            final a = map(pts.first);
            c.moveTo(a.dx, a.dy);
            for (final q in pts.skip(1)) {
              final o = map(q);
              c.lineTo(o.dx, o.dy);
            }
            c.strokePath();
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
                  color: _col(p.bends[i].turn),
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
            '옆에서 본 모양(중립선 길이 ${_n(p.cutLength)}mm) · 번호는 꺾기 표 번호',
            style: const pw.TextStyle(fontSize: 8, color: _grey),
          ),
        ),
      ],
    ),
  );

  // 자르기 전 마킹
  const markH = 70.0;
  final len = math.max(p.cutLength, 1.0);
  final sc = (w - 32) / len;
  pw.Widget mark() => pw.SizedBox(
    width: w,
    height: markH,
    child: pw.Stack(
      children: [
        pw.CustomPaint(
          size: const PdfPoint(w, markH),
          painter: (c, size) {
            c
              ..setFillColor(_copper)
              ..setStrokeColor(_copperDark)
              ..setLineWidth(0.8)
              ..drawRRect(16, 22, len * sc, 24, 2, 2)
              ..fillAndStrokePath();
            for (final b in p.bends) {
              final col = _col(b.turn);
              final x = 16 + b.start * sc;
              final bw = math.max((b.end - b.start) * sc, 1.5);
              c
                ..setFillColor(col)
                ..drawRect(x, 22, bw, 24)
                ..fillPath()
                ..setStrokeColor(col)
                ..setLineWidth(1)
                ..moveTo(x, 17)
                ..lineTo(x, 51)
                ..strokePath()
                ..moveTo(x + bw, 17)
                ..lineTo(x + bw, 51)
                ..strokePath();
            }
          },
        ),
        pw.Positioned(
          left: 0,
          top: 0,
          child: pw.Text(
            '자르기 전 곧은 부스바 · 숫자는 한쪽 끝에서 잰 꺾기 시작선(mm)',
            style: const pw.TextStyle(fontSize: 8, color: _grey),
          ),
        ),
        for (var i = 0; i < p.bends.length; i++)
          pw.Positioned(
            left: 16 + p.bends[i].start * sc - 10,
            top: markH - 22,
            child: pw.Text(
              _n(p.bends[i].start),
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
          ),
        pw.Positioned(
          left: 16,
          top: markH - 12,
          child: pw.Text(
            '0',
            style: const pw.TextStyle(fontSize: 8, color: _grey),
          ),
        ),
        pw.Positioned(
          left: 16 + len * sc - 30,
          top: markH - 12,
          child: pw.SizedBox(
            width: 30,
            child: pw.Text(
              _n(p.cutLength),
              textAlign: pw.TextAlign.right,
              style: const pw.TextStyle(fontSize: 8, color: _grey),
            ),
          ),
        ),
      ],
    ),
  );

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
              '부스바 절곡 지시서',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
              style: const pw.TextStyle(fontSize: 10, color: _grey),
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
          children: [
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
          ],
        ),
        title('꺾은 뒤 모양'),
        side(),
        title('자르기 전 마킹'),
        mark(),
        title('꺾기 (한쪽 끝에서 잰 거리, mm)'),
        pw.Table(
          border: pw.TableBorder.all(color: _line, width: 0.6),
          columnWidths: const {
            0: pw.FixedColumnWidth(34),
            1: pw.FlexColumnWidth(),
            2: pw.FixedColumnWidth(80),
            3: pw.FixedColumnWidth(80),
            4: pw.FixedColumnWidth(60),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _head),
              children: [
                for (final h in ['번호', '방향', '꺾기 시작선', '꺾기 끝선', '호 길이'])
                  cell(h, bold: true),
              ],
            ),
            for (var i = 0; i < p.bends.length; i++)
              pw.TableRow(
                children: [
                  cell('${i + 1}'),
                  cell(
                    '${p.bends[i].turn >= 0 ? "위로" : "아래로"} ${_n(p.bends[i].turn.abs())}°',
                  ),
                  cell(_n(p.bends[i].start)),
                  cell(_n(p.bends[i].end)),
                  cell(_n(p.bends[i].end - p.bends[i].start)),
                ],
              ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          '직선 구간(mm): ${p.straights.map((s) => _n(s)).join(" · ")}',
          style: const pw.TextStyle(fontSize: 9.5, color: _ink),
        ),
        if (input.notes.isNotEmpty) ...[
          title('주의'),
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

String bendFileName(String title, DateTime d) {
  final t = title.trim().isEmpty
      ? 'noname'
      : title.trim().replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
  return 'busbar_bend_${t}_${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}.pdf';
}

Future<void> openBendPdf(BuildContext context, BendPdfInput input) async {
  final now = DateTime.now();
  final bytes = await buildBendPdf(input, date: now);
  final fileName = bendFileName(input.title, now);
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => SteelPdfPreviewPage(
        bytes: bytes,
        fileName: fileName,
        title: '부스바 절곡 지시서 미리보기',
        onShare: () async {
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/$fileName');
          await file.writeAsBytes(bytes);
          // ignore: deprecated_member_use
          await Share.shareXFiles([
            XFile(file.path),
          ], text: '부스바 절곡 지시서 ${input.title.trim()}');
        },
      ),
    ),
  );
}
