// 장비 관리 대장 PDF(제출용 표)와 QR 라벨 PDF(붙일 스티커 종이), 화면에 그리는 QR.
import 'dart:typed_data';

import 'package:barcode/barcode.dart';
import 'package:flutter/material.dart' as m;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/utils/pdf_fonts.dart';
import 'equipment_model.dart';

/// 관리 대장(가로 A4 표). 기한이 급한 순으로 나온다.
Future<Uint8List> buildLedgerPdf(List<Equipment> all, DateTime now) async {
  final fonts = await loadKoreanPdfFonts();
  final doc = pw.Document(theme: fonts.theme);
  final list = sortLedger(all, now);
  final s = summarize(all, now);

  String due(Equipment e) => e.nextDue == null ? '' : dateLabel(e.nextDue!);
  String state(Equipment e) => switch (e.dueState(now)) {
    DueState.overdue => '만료',
    DueState.soon => '임박',
    DueState.ok => '정상',
    DueState.none => e.isRetired ? '폐기' : '',
  };

  const head = ['관리번호', '장비명', '분류', '제조사·모델', '시리얼', '위치', '마지막 점검', '다음 점검', '상태'];
  final rows = [
    for (final e in list)
      [
        e.assetNo,
        e.name,
        e.category.label,
        [e.maker, e.model].where((v) => v.isNotEmpty).join(' '),
        e.serial,
        e.location,
        e.lastDone == null ? '' : dateLabel(e.lastDone!),
        due(e),
        state(e),
      ],
  ];

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(28),
      header: (_) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('장비 관리 대장', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text(
              '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} 기준 · '
              '전체 ${s.total}대 · 만료 ${s.overdue} · 임박 ${s.soon}',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ],
        ),
      ),
      footer: (c) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('${c.pageNumber} / ${c.pagesCount}', style: const pw.TextStyle(fontSize: 9)),
      ),
      build: (_) => [
        pw.TableHelper.fromTextArray(
          headers: head,
          data: rows,
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignment: pw.Alignment.centerLeft,
          headerAlignment: pw.Alignment.centerLeft,
          border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.5),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          columnWidths: {
            0: const pw.FlexColumnWidth(1.1),
            1: const pw.FlexColumnWidth(1.8),
            2: const pw.FlexColumnWidth(0.9),
            3: const pw.FlexColumnWidth(1.8),
            4: const pw.FlexColumnWidth(1.3),
            5: const pw.FlexColumnWidth(1.2),
            6: const pw.FlexColumnWidth(1.1),
            7: const pw.FlexColumnWidth(1.1),
            8: const pw.FlexColumnWidth(0.7),
            9: const pw.FlexColumnWidth(1.0),
          },
        ),
      ],
    ),
  );
  return doc.save();
}

/// QR 라벨 종이(한 쪽에 3열 × 8줄, 라벨마다 QR + 관리번호 + 장비명). 잘라서 장비에 붙인다.
Future<Uint8List> buildLabelsPdf(List<Equipment> list) async {
  final fonts = await loadKoreanPdfFonts();
  final doc = pw.Document(theme: fonts.theme);
  const cols = 3;
  const perPage = 24;
  for (var start = 0; start < list.length; start += perPage) {
    final page = list.skip(start).take(perPage).toList();
    doc.addPage(
      pw.Page(
        theme: fonts.theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (_) => pw.Wrap(
          children: [
            for (final e in page)
              pw.Container(
                width: (PdfPageFormat.a4.width - 40) / cols,
                height: (PdfPageFormat.a4.height - 40) / 8,
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400, width: 0.4),
                ),
                child: pw.Row(
                  children: [
                    pw.BarcodeWidget(
                      barcode: Barcode.qrCode(),
                      data: e.qrText,
                      drawText: false,
                      width: 62,
                      height: 62,
                    ),
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          if (e.assetNo.isNotEmpty)
                            pw.Text(
                              e.assetNo,
                              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                            ),
                          pw.Text(e.name, style: const pw.TextStyle(fontSize: 9), maxLines: 2),
                          if (e.nextDue != null)
                            pw.Text(
                              '기한 ${dateLabel(e.nextDue!)}',
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
  if (list.isEmpty) {
    doc.addPage(
      pw.Page(
        theme: fonts.theme,
        build: (_) => pw.Center(child: pw.Text('라벨을 만들 장비가 없습니다')),
      ),
    );
  }
  return doc.save();
}

/// 화면에 QR을 그린다(QR 라벨 화면과 장비 상세에서 쓴다).
class QrCodeView extends m.StatelessWidget {
  final String data;
  final double size;
  const QrCodeView({super.key, required this.data, this.size = 200});

  @override
  m.Widget build(m.BuildContext context) => m.Container(
    color: m.Colors.white,
    padding: const m.EdgeInsets.all(8),
    child: m.CustomPaint(size: m.Size.square(size), painter: _QrPainter(data)),
  );
}

class _QrPainter extends m.CustomPainter {
  final String data;
  _QrPainter(this.data);

  @override
  void paint(m.Canvas canvas, m.Size size) {
    final bars = Barcode.qrCode().make(data, width: size.width, height: size.height);
    final paint = m.Paint()..color = m.Colors.black;
    for (final el in bars) {
      if (el is BarcodeBar && el.black) {
        canvas.drawRect(m.Rect.fromLTWH(el.left, el.top, el.width, el.height), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter old) => old.data != data;
}
