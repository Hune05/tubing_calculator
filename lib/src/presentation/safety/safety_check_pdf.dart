// 작업 전 안전 점검(TBM) 기록 PDF(10-14, A4): 일시·현장·작업, 점검 항목 결과 표, 위험 요인·메모,
// 참석자 서명부(번호·업체·이름·서명). 서명은 앱에서 받은 획을 그대로 선으로 그린다.
// 참석자를 하나도 안 받았으면 종이에 서명받을 수 있게 빈 줄을 둔다.
// 미리보기로 먼저 보이고, 공유는 미리보기의 단추를 눌러야만 된다(SteelPdfPreviewPage).
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../core/common_widgets/snack_once.dart';
import '../../core/utils/pdf_fonts.dart';
import '../steel_cutting/screens/steel_pdf_preview_page.dart';
import 'safety_check_model.dart';

const PdfColor _ink = PdfColor.fromInt(0xFF1F2933);
const PdfColor _label = PdfColor.fromInt(0xFF374151);
const PdfColor _grey = PdfColor.fromInt(0xFF6B7280);
const PdfColor _line = PdfColor.fromInt(0xFFD1D5DB);
const PdfColor _head = PdfColor.fromInt(0xFFF1F5F9);
const PdfColor _red = PdfColor.fromInt(0xFFD32F2F);
const PdfColor _teal = PdfColor.fromInt(0xFF007580);

/// 참석자가 없을 때 종이 서명용으로 두는 빈 줄 수.
const int kSafetyBlankSignRows = 8;

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];
String _two(int n) => n.toString().padLeft(2, '0');

/// 서명 획을 PDF 칸에 선으로 그린다(PDF는 아래가 0이라 세로를 뒤집는다).
pw.Widget _sigBox(String sig, double w, double h) {
  final strokes = decodeSignature(sig);
  if (strokes.isEmpty) return pw.SizedBox(width: w, height: h);
  return pw.SizedBox(
    width: w,
    height: h,
    child: pw.CustomPaint(
      size: PdfPoint(w, h),
      painter: (PdfGraphics g, PdfPoint size) {
        final k = (size.x / kSigW) < (size.y / kSigH)
            ? size.x / kSigW
            : size.y / kSigH;
        final dx = (size.x - kSigW * k) / 2;
        final dy = (size.y - kSigH * k) / 2;
        g
          ..setStrokeColor(PdfColors.black)
          ..setLineWidth((9 * k).clamp(0.6, 2.0))
          ..setLineCap(PdfLineCap.round)
          ..setLineJoin(PdfLineJoin.round);
        for (final s in strokes) {
          final f = s.first;
          g.moveTo(dx + f.$1 * k, size.y - (dy + f.$2 * k));
          if (s.length == 1) {
            g.lineTo(dx + f.$1 * k + 0.1, size.y - (dy + f.$2 * k));
          }
          for (final p in s.skip(1)) {
            g.lineTo(dx + p.$1 * k, size.y - (dy + p.$2 * k));
          }
          g.strokePath();
        }
      },
    ),
  );
}

/// TBM 기록 PDF 바이트.
Future<Uint8List> buildSafetyCheckPdf(SafetyRecord r) async {
  final fonts = await loadKoreanPdfFonts();
  final at = r.at;
  final when =
      '${at.year}년 ${at.month}월 ${at.day}일 (${_weekdays[at.weekday - 1]}) '
      '${_two(at.hour)}:${_two(at.minute)}';

  pw.Widget cell(
    String t, {
    bool bold = false,
    PdfColor color = _ink,
    pw.TextAlign align = pw.TextAlign.center,
    double size = 9.5,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
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

  pw.Widget info(String k, String v) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 48,
          child: pw.Text(
            k,
            style: const pw.TextStyle(fontSize: 9.5, color: _label),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            v.trim().isEmpty ? '—' : v.trim(),
            style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold),
          ),
        ),
      ],
    ),
  );

  pw.Widget heading(String t, [String tail = '']) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
    child: pw.Row(
      children: [
        pw.Container(width: 3, height: 12, color: _teal),
        pw.SizedBox(width: 6),
        pw.Text(
          t,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        if (tail.isNotEmpty) ...[
          pw.SizedBox(width: 8),
          pw.Text(tail, style: const pw.TextStyle(fontSize: 9.5, color: _grey)),
        ],
      ],
    ),
  );

  (String, PdfColor) result(SafetyAnswer a) => switch (a) {
    SafetyAnswer.yes => ('확인', _ink),
    SafetyAnswer.na => ('해당 없음', _grey),
    SafetyAnswer.fix => ('조치 필요', _red),
    SafetyAnswer.none => ('미확인', _red),
  };

  // 참석자: 서명을 받았으면 그 목록, 예전 기록이면 이름 글을 나눈 것, 없으면 빈 줄.
  final people = r.attendees.isNotEmpty
      ? r.attendees
      : attendeesFromText(r.people);
  const sigW = 120.0, sigH = 40.0;
  final signRows = <pw.TableRow>[
    pw.TableRow(
      decoration: const pw.BoxDecoration(color: _head),
      children: [
        for (final h in ['번호', '업체', '이름', '서명']) cell(h, bold: true),
      ],
    ),
    for (var i = 0; i < people.length; i++)
      pw.TableRow(
        verticalAlignment: pw.TableCellVerticalAlignment.middle,
        children: [
          cell('${i + 1}'),
          cell(people[i].company),
          cell(people[i].name, bold: true),
          pw.Padding(
            padding: const pw.EdgeInsets.all(2),
            child: pw.Center(child: _sigBox(people[i].sig, sigW, sigH)),
          ),
        ],
      ),
    if (people.isEmpty)
      for (var i = 0; i < kSafetyBlankSignRows; i++)
        pw.TableRow(
          children: [
            cell('${i + 1}'),
            cell(''),
            cell(''),
            pw.SizedBox(height: sigH + 4),
          ],
        ),
  ];

  final signed = people.where((a) => a.signed).length;
  final doc = pw.Document(theme: fonts.theme);
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 36),
      footer: (ctx) => pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              signed > 0 ? '서명은 작업자가 앱 화면에 손가락으로 직접 한 것입니다.' : '',
              style: const pw.TextStyle(fontSize: 8, color: _grey),
            ),
          ),
          pw.Text(
            '${ctx.pageNumber} / ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: _grey),
          ),
        ],
      ),
      build: (_) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Expanded(
              child: pw.Text(
                '작업 전 안전 점검 (TBM) 기록',
                style: pw.TextStyle(
                  fontSize: 19,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Text(
              when,
              style: const pw.TextStyle(fontSize: 9.5, color: _label),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Container(height: 1.2, color: _ink),
        pw.SizedBox(height: 10),
        info('일시', when),
        info('현장', r.site),
        info('작업', r.work),
        heading('점검 항목', safetyResultLabel(r)),
        pw.Table(
          border: pw.TableBorder.all(color: _line, width: 0.6),
          columnWidths: const {
            0: pw.FixedColumnWidth(32),
            1: pw.FlexColumnWidth(),
            2: pw.FixedColumnWidth(70),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _head),
              children: [
                for (final h in ['번호', '점검 항목', '결과']) cell(h, bold: true),
              ],
            ),
            for (var i = 0; i < r.lines.length; i++)
              pw.TableRow(
                verticalAlignment: pw.TableCellVerticalAlignment.middle,
                children: [
                  cell('${i + 1}'),
                  cell(r.lines[i].label, align: pw.TextAlign.left),
                  cell(
                    result(r.lines[i].answer).$1,
                    bold: true,
                    color: result(r.lines[i].answer).$2,
                  ),
                ],
              ),
          ],
        ),
        if (r.risks.trim().isNotEmpty) ...[
          heading('위험 요인·메모'),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _line, width: 0.6),
            ),
            child: pw.Text(
              r.risks.trim(),
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
        ],
        heading(
          '참석자 서명부',
          people.isEmpty ? '' : '${people.length}명 · 서명 $signed명',
        ),
        pw.Table(
          border: pw.TableBorder.all(color: _line, width: 0.6),
          columnWidths: const {
            0: pw.FixedColumnWidth(36),
            1: pw.FlexColumnWidth(2),
            2: pw.FlexColumnWidth(2),
            3: pw.FixedColumnWidth(sigW + 12),
          },
          children: signRows,
        ),
      ],
    ),
  );
  return doc.save();
}

/// 파일 이름: tbm_현장_20261014_0805.pdf
String safetyPdfFileName(SafetyRecord r) {
  final site = r.site.trim().isEmpty
      ? 'site'
      : r.site.trim().replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
  final a = r.at;
  return 'tbm_${site}_${a.year}${_two(a.month)}${_two(a.day)}_${_two(a.hour)}${_two(a.minute)}.pdf';
}

bool _busy = false;

/// 기록 PDF를 만들어 미리보기로 보여 준다. 공유는 미리보기의 단추를 눌러야만 된다.
Future<void> openSafetyCheckPdf(BuildContext context, SafetyRecord r) async {
  if (_busy) return;
  _busy = true;
  final messenger = ScaffoldMessenger.maybeOf(context);
  Uint8List bytes;
  try {
    bytes = await buildSafetyCheckPdf(r);
  } catch (_) {
    showSnackOnce(messenger, const SnackBar(content: Text('PDF를 만들지 못했습니다.')));
    return;
  } finally {
    _busy = false;
  }
  final fileName = safetyPdfFileName(r);
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => SteelPdfPreviewPage(
        bytes: bytes,
        fileName: fileName,
        title: '안전 점검 기록 미리보기',
        onShare: () async {
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/$fileName');
          await file.writeAsBytes(bytes);
          // ignore: deprecated_member_use
          await Share.shareXFiles([XFile(file.path)], text: '작업 전 안전 점검 기록');
        },
      ),
    ),
  );
}
