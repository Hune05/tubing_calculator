/// 벤딩 마킹지 한 장(PDF). 튜브·전선관 마킹 탭이 같이 쓴다.
///
/// 🚀 [추가] 동료에게 넘기거나 작업일지에 붙일 수 있게, 총 절단 길이·쓴 장비
/// 제원·줄자 띠 그림·마킹표·입력 목록·경고를 한 장에 담는다.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'package:tubing_calculator/src/core/utils/pdf_fonts.dart';
import 'package:tubing_calculator/src/presentation/field/field_marking.dart';
import 'package:tubing_calculator/src/presentation/steel_cutting/screens/steel_pdf_preview_page.dart';

const PdfColor _ink = PdfColor.fromInt(0xFF1F2933);
const PdfColor _grey = PdfColor.fromInt(0xFF6B7280);
const PdfColor _line = PdfColor.fromInt(0xFFD1D5DB);
const PdfColor _red = PdfColor.fromInt(0xFFD32F2F);
const PdfColor _teal = PdfColor.fromInt(0xFF007580);
const PdfColor _tape = PdfColor.fromInt(0xFFFFE082);
const PdfColor _amberBg = PdfColor.fromInt(0xFFFFF3DF);
const PdfColor _amber = PdfColor.fromInt(0xFFC77700);

String _fmt(double v) => (v - v.roundToDouble()).abs() < 0.05
    ? v.round().toString()
    : v.toStringAsFixed(1);

String _dirShort(double rotation) => fieldDirectionLabel(rotation);

/// 줄자로 읽는 값(마킹 자리·간격·절단 길이)은 마킹 탭·현장 탭과 같게 정수 mm로.
String _mm(double v) => v.round().toString();

/// 줄자 띠에 숫자를 몇 mm마다 적을지(12개 안쪽).
double tapeLabelStep(double totalMm) {
  for (final s in const [100.0, 200.0, 500.0, 1000.0, 2000.0]) {
    if (totalMm / s <= 12) return s;
  }
  return 5000.0;
}

Future<Uint8List> buildMarkingSheetPdf({
  required String title,
  required FieldMarkingData data,
  required List<(String, String)> specs,
  required List<Map<String, dynamic>> inputs,
  DateTime? date,
}) async {
  final fonts = await loadKoreanPdfFonts();
  final doc = pw.Document(theme: fonts.theme, title: title);
  final d = date ?? DateTime.now();
  final dateText =
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 28),
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'FIELD HELPER · 벤딩 마킹 계산기',
            style: const pw.TextStyle(fontSize: 8, color: _grey),
          ),
          pw.Text(
            '${ctx.pageNumber} / ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: _grey),
          ),
        ],
      ),
      build: (ctx) => [
        _header(title, dateText, data.totalCut),
        pw.SizedBox(height: 12),
        if (specs.isNotEmpty) _specBox(specs),
        pw.SizedBox(height: 14),
        _sectionTitle('줄자'),
        pw.SizedBox(height: 4),
        _tapeStrip(data),
        pw.SizedBox(height: 14),
        _sectionTitle('마킹표'),
        pw.SizedBox(height: 4),
        _markTable(data),
        if (data.warnings.isNotEmpty) ...[
          pw.SizedBox(height: 10),
          _warnings(data.warnings),
        ],
        pw.SizedBox(height: 14),
        _sectionTitle('입력 목록'),
        pw.SizedBox(height: 4),
        _inputTable(inputs),
      ],
    ),
  );
  return doc.save();
}

pw.Widget _header(String title, String date, double totalCut) {
  return pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 10),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _ink, width: 1.5)),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                date,
                style: const pw.TextStyle(fontSize: 10, color: _grey),
              ),
            ],
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              '총 절단 길이',
              style: const pw.TextStyle(fontSize: 10, color: _grey),
            ),
            pw.Text(
              '${_mm(totalCut)} mm',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: _teal,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _sectionTitle(String t) => pw.Text(
  t,
  style: pw.TextStyle(
    fontSize: 12,
    fontWeight: pw.FontWeight.bold,
    color: _ink,
  ),
);

pw.Widget _specBox(List<(String, String)> specs) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      color: PdfColors.grey100,
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Wrap(
      spacing: 18,
      runSpacing: 4,
      children: [
        for (final (label, value) in specs)
          pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(
                  text: '$label ',
                  style: const pw.TextStyle(fontSize: 9, color: _grey),
                ),
                pw.TextSpan(
                  text: value,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// 관 한 토막을 줄자처럼: 벤드 마킹은 빨간 선·번호, 자르는 자리는 검은 선.
pw.Widget _tapeStrip(FieldMarkingData data) {
  const double h = 64;
  const double barTop = 22; // 위에서
  const double barH = 12;
  final double total = [
    data.totalCut,
    ...data.marks.map((m) => m.position),
  ].fold<double>(1, (a, b) => b > a ? b : a);
  final double step = tapeLabelStep(total);

  return pw.LayoutBuilder(
    builder: (ctx, c) {
      final double w = c!.maxWidth;
      double x(double mm) => (mm / total).clamp(0.0, 1.0) * (w - 16) + 8;

      final labels = <pw.Widget>[];
      for (double mm = 0; mm <= total + 0.1; mm += step) {
        labels.add(
          pw.Positioned(
            left: x(mm) - 14,
            top: barTop + barH + 8,
            child: pw.SizedBox(
              width: 28,
              child: pw.Text(
                _fmt(mm),
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 7, color: _grey),
              ),
            ),
          ),
        );
      }
      for (final m in data.bends) {
        labels.add(
          pw.Positioned(
            left: x(m.position) - 7,
            top: 2,
            child: pw.Container(
              width: 14,
              height: 14,
              alignment: pw.Alignment.center,
              decoration: const pw.BoxDecoration(
                color: _red,
                shape: pw.BoxShape.circle,
              ),
              child: pw.Text(
                '${m.number}',
                style: pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      }
      if (data.totalCut > 0) {
        labels.add(
          pw.Positioned(
            // 오른쪽 끝에서 잘리지 않게 글자를 선 왼쪽에 둔다.
            left: x(data.totalCut) - 38,
            top: 4,
            child: pw.SizedBox(
              width: 36,
              child: pw.Text(
                '자르기',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink,
                ),
              ),
            ),
          ),
        );
      }

      return pw.SizedBox(
        width: w,
        height: h,
        child: pw.Stack(
          children: [
            pw.Positioned.fill(
              child: pw.CustomPaint(
                painter: (PdfGraphics g, PdfPoint size) {
                  // PDF는 아래가 0이라 위에서 잰 값을 뒤집는다.
                  double y(double top) => size.y - top;
                  // 줄자 바탕
                  g
                    ..setFillColor(_tape)
                    ..drawRect(x(0), y(barTop + barH), x(total) - x(0), barH)
                    ..fillPath();
                  g
                    ..setStrokeColor(_ink)
                    ..setLineWidth(0.6)
                    ..drawRect(x(0), y(barTop + barH), x(total) - x(0), barH)
                    ..strokePath();
                  // 눈금
                  final small = step / 5;
                  for (double mm = 0; mm <= total + 0.1; mm += small) {
                    final bool big =
                        (mm / step - (mm / step).roundToDouble()).abs() < 1e-6;
                    g
                      ..setStrokeColor(_ink)
                      ..setLineWidth(big ? 0.8 : 0.4)
                      ..drawLine(
                        x(mm),
                        y(barTop + barH),
                        x(mm),
                        y(barTop + barH + (big ? 6 : 3)),
                      )
                      ..strokePath();
                  }
                  // 직관 끝(회색), 벤드(빨강), 자르기(검정)
                  for (final m in data.marks) {
                    g
                      ..setStrokeColor(m.isBend ? _red : _line)
                      ..setLineWidth(m.isBend ? 1.4 : 0.8)
                      ..drawLine(
                        x(m.position),
                        y(m.isBend ? 16 : barTop - 2),
                        x(m.position),
                        y(barTop + barH),
                      )
                      ..strokePath();
                  }
                  if (data.totalCut > 0) {
                    g
                      ..setStrokeColor(_ink)
                      ..setLineWidth(1.6)
                      ..drawLine(
                        x(data.totalCut),
                        y(14),
                        x(data.totalCut),
                        y(barTop + barH + 2),
                      )
                      ..strokePath();
                  }
                },
              ),
            ),
            ...labels,
          ],
        ),
      );
    },
  );
}

pw.Widget _cell(
  String t, {
  bool bold = false,
  PdfColor color = _ink,
  pw.TextAlign align = pw.TextAlign.center,
  double size = 9,
}) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
  child: pw.Text(
    t,
    textAlign: align,
    style: pw.TextStyle(
      fontSize: size,
      color: color,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    ),
  ),
);

pw.TableRow _headRow(List<String> cols) => pw.TableRow(
  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
  children: [for (final c in cols) _cell(c, bold: true, size: 8.5)],
);

pw.Widget _markTable(FieldMarkingData data) {
  final rows = <pw.TableRow>[
    _headRow(['번호', '줄자 눈금', '앞 마킹에서', '각도', '꺾을 각도', '방향', '굴림']),
  ];
  for (final m in data.bends) {
    rows.add(
      pw.TableRow(
        children: [
          _cell('${m.number}', bold: true, color: _red),
          _cell('${_mm(m.position)} mm', bold: true, size: 11),
          _cell(
            m.number == 1 ? '관 끝 0에서' : '${m.gap >= 0 ? '+' : ''}${_mm(m.gap)}',
          ),
          _cell('${_fmt(m.angle)}°'),
          _cell(m.hasOverBend ? '${_fmt(m.targetAngle)}°' : '-'),
          _cell(_dirShort(m.rotation)),
          _cell(m.roll != null ? '${m.roll!.round()}°' : '-'),
        ],
      ),
    );
  }
  if (data.totalCut > 0) {
    rows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey100),
        children: [
          _cell('자름', bold: true),
          _cell('${_mm(data.totalCut)} mm', bold: true, size: 11),
          _cell('자르는 자리', bold: true),
          _cell(''),
          _cell(''),
          _cell(''),
          _cell(''),
        ],
      ),
    );
  }
  return pw.Table(
    border: const pw.TableBorder(
      horizontalInside: pw.BorderSide(color: _line, width: 0.5),
      bottom: pw.BorderSide(color: _line, width: 0.5),
      top: pw.BorderSide(color: _line, width: 0.5),
    ),
    columnWidths: const {
      0: pw.FixedColumnWidth(30),
      1: pw.FlexColumnWidth(1.4),
      2: pw.FlexColumnWidth(1.2),
      3: pw.FlexColumnWidth(0.8),
      4: pw.FlexColumnWidth(0.9),
      5: pw.FlexColumnWidth(1.4),
      6: pw.FlexColumnWidth(0.7),
    },
    children: rows,
  );
}

pw.Widget _inputTable(List<Map<String, dynamic>> inputs) {
  final rows = <pw.TableRow>[
    _headRow(['줄', '형태', '길이', '방향']),
  ];
  for (var i = 0; i < inputs.length; i++) {
    final b = inputs[i];
    final angle = (b['angle'] as num?)?.toDouble() ?? 0;
    final len = (b['length'] as num?)?.toDouble() ?? 0;
    final rot = (b['rotation'] as num?)?.toDouble() ?? 0;
    rows.add(
      pw.TableRow(
        children: [
          _cell('${i + 1}'),
          _cell(angle > 0 ? '${_fmt(angle)}° 벤딩' : '직관'),
          _cell('${_fmt(len)} mm'),
          _cell(angle > 0 ? _dirShort(rot) : '-'),
        ],
      ),
    );
  }
  return pw.Table(
    border: const pw.TableBorder(
      horizontalInside: pw.BorderSide(color: _line, width: 0.5),
      bottom: pw.BorderSide(color: _line, width: 0.5),
      top: pw.BorderSide(color: _line, width: 0.5),
    ),
    columnWidths: const {
      0: pw.FixedColumnWidth(30),
      1: pw.FlexColumnWidth(1.2),
      2: pw.FlexColumnWidth(1.2),
      3: pw.FlexColumnWidth(1.4),
    },
    children: rows,
  );
}

pw.Widget _warnings(List<String> warnings) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      color: _amberBg,
      border: pw.Border.all(color: _amber, width: 0.8),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '이대로는 만들 수 없습니다',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: _amber,
          ),
        ),
        for (final w in warnings)
          pw.Text(
            '• $w',
            style: const pw.TextStyle(fontSize: 9, color: _amber),
          ),
      ],
    ),
  );
}

/// 마킹지를 만들어 미리보기로 보여 준다. 공유는 미리보기의 단추를 눌러야만 된다.
Future<void> openMarkingSheet(
  BuildContext context, {
  required String title,
  required String fileBase,
  required FieldMarkingData data,
  required List<(String, String)> specs,
  required List<Map<String, dynamic>> inputs,
}) async {
  if (data.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('입력한 배관이 없습니다.')));
    return;
  }
  final bytes = await buildMarkingSheetPdf(
    title: title,
    data: data,
    specs: specs,
    inputs: inputs,
  );
  final d = DateTime.now();
  final fileName =
      '${fileBase}_${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}.pdf';
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => SteelPdfPreviewPage(
        bytes: bytes,
        fileName: fileName,
        title: '마킹지 미리보기',
        onShare: () async {
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/$fileName');
          await file.writeAsBytes(bytes);
          // ignore: deprecated_member_use
          await Share.shareXFiles([XFile(file.path)], text: title);
        },
      ),
    ),
  );
}
