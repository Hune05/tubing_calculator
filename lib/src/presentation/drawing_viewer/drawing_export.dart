// 표시한 도면을 PDF로: 쪽마다 도면 그림 + 표시, 아래 줄에 도번·REV·쪽, 끝에 문제 목록 표와 색 약속.
// 원본 도면 파일은 바꾸지 않는다(새 PDF를 만든다).
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/utils/pdf_fonts.dart';
import 'drawing_mark_painter.dart';
import 'drawing_models.dart';

/// 쪽 그림 위에 표시를 그려 PNG로. 너무 크면 긴 변 [maxSide]로 줄인다.
Future<Uint8List> composePagePng(Uint8List pagePng, List<DrawingMark> marks, int page, {int maxSide = 3000}) async {
  final codec = await ui.instantiateImageCodec(pagePng);
  final src = (await codec.getNextFrame()).image;
  final k = math.min(1.0, maxSide / math.max(src.width, src.height));
  final w = (src.width * k).round(), h = (src.height * k).round();
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.drawImageRect(src, Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()), Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..filterQuality = FilterQuality.medium);
  final size = Size(w.toDouble(), h.toDouble());
  for (final m in marks) {
    if (m.page == page) paintMark(c, m, size);
  }
  final img = await rec.endRecording().toImage(w, h);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  src.dispose();
  img.dispose();
  return data!.buffer.asUint8List();
}

Future<Uint8List> buildMarkedPdf({
  required DrawingDoc doc,
  required List<DrawingMark> marks,
  required Future<String> Function(int page) pagePath,
  required DateTime now,
  String author = '',
}) async {
  final fonts = await loadKoreanPdfFonts();
  final pdf = pw.Document();
  final head = [
    doc.displayName,
    if (doc.drawingNo.isNotEmpty) '도번 ${doc.drawingNo}',
    if (doc.rev.isNotEmpty) 'REV ${doc.rev}',
  ].join('  ·  ');
  final foot = '확인 ${markDate(now)}${author.isNotEmpty ? ' · $author' : ''} · 원본 도면은 바꾸지 않았습니다';

  for (var p = 0; p < doc.pages; p++) {
    final bytes = await File(await pagePath(p)).readAsBytes();
    final png = await composePagePng(bytes, marks, p);
    final (w, h) = p < doc.pageSizes.length ? doc.pageSizes[p] : (4000, 2828);
    final landscape = w >= h;
    final fmt = landscape ? PdfPageFormat.a3.landscape : PdfPageFormat.a3;
    pdf.addPage(
      pw.Page(
        pageFormat: fmt,
        theme: fonts.theme,
        margin: const pw.EdgeInsets.all(18),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Expanded(child: pw.Center(child: pw.Image(pw.MemoryImage(png), fit: pw.BoxFit.contain))),
            pw.SizedBox(height: 6),
            pw.Row(
              children: [
                pw.Expanded(child: pw.Text(head, style: pw.TextStyle(font: fonts.bold, fontSize: 9))),
                pw.Text('${p + 1} / ${doc.pages}쪽   $foot', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 문제 목록
  final issues = issuesOf(marks);
  PdfColor col(MarkColor c) => PdfColor.fromInt(c.argb);
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: fonts.theme,
      margin: const pw.EdgeInsets.all(28),
      build: (_) => [
        pw.Text('도면 확인 문제 목록', style: pw.TextStyle(font: fonts.bold, fontSize: 16)),
        pw.SizedBox(height: 4),
        pw.Text(head, style: const pw.TextStyle(fontSize: 10)),
        pw.Text('파일 ${doc.name} · ${doc.pages}쪽 · $foot', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            for (final c in MarkColor.values) ...[
              pw.Container(width: 10, height: 10, color: col(c)),
              pw.SizedBox(width: 3),
              pw.Text('${c.label} = ${c.meaning}', style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(width: 12),
            ],
          ],
        ),
        pw.SizedBox(height: 10),
        if (issues.isEmpty)
          pw.Text('번호 붙은 문제가 없습니다.', style: const pw.TextStyle(fontSize: 10))
        else
          pw.TableHelper.fromTextArray(
            headers: ['번호', '쪽', '종류', '내용', '상태', '적은 사람', '적은 때'],
            headerStyle: pw.TextStyle(font: fonts.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 9),
            columnWidths: {
              0: const pw.FixedColumnWidth(30),
              1: const pw.FixedColumnWidth(24),
              2: const pw.FixedColumnWidth(34),
              3: const pw.FlexColumnWidth(),
              4: const pw.FixedColumnWidth(34),
              5: const pw.FixedColumnWidth(50),
              6: const pw.FixedColumnWidth(76),
            },
            data: [
              for (final m in issues)
                ['${m.no}', '${m.page + 1}', m.kind.label, m.text.isEmpty ? '-' : m.text, m.done ? '해결' : '남음', m.author, markDate(m.createdAt)],
            ],
          ),
      ],
    ),
  );
  return pdf.save();
}
