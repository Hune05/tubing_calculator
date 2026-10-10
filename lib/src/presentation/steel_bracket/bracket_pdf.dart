// 형강 브라켓 가공 지시서(PDF, A4, 10-10): 요약 표, 그림(화면과 같은 그림을 PNG로), 자를 것 표,
// 구멍·베이스 판·원자재·볼트 줄, 주의, 작성·검토·승인 칸. 미리보기로 먼저 보이고 공유는 미리보기 단추로만.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:tubing_calculator/src/core/common_widgets/snack_once.dart';

import '../../core/utils/pdf_fonts.dart';
import '../steel_cutting/screens/steel_pdf_preview_page.dart';

const PdfColor _ink = PdfColor.fromInt(0xFF1F2933);
const PdfColor _grey = PdfColor.fromInt(0xFF6B7280);
const PdfColor _label = PdfColor.fromInt(0xFF374151);
const PdfColor _line = PdfColor.fromInt(0xFFD1D5DB);
const PdfColor _head = PdfColor.fromInt(0xFFF1F5F9);
const PdfColor _amberBg = PdfColor.fromInt(0xFFFFF4E0);

/// 지시서 한 구역: 제목, 줄들, (선택) 표.
class BracketPdfSection {
  final String title;
  final List<String> lines;
  final List<String> headers;
  final List<List<String>> rows;
  const BracketPdfSection(
    this.title,
    this.lines, {
    this.headers = const [],
    this.rows = const [],
  });
}

class BracketPdfInput {
  final String title;
  final List<(String, String)> summary;
  final Uint8List drawingPng;
  final List<BracketPdfSection> sections;
  final List<String> notes;

  /// 지시서 맨 위 제목, 첫 그림 제목, 그 뒤에 붙는 그림(제목, PNG). 철판 가공도 같이 쓴다(10-10).
  final String docTitle;
  final String drawingCaption;
  final List<(String, Uint8List)> moreDrawings;
  const BracketPdfInput({
    required this.title,
    required this.summary,
    required this.drawingPng,
    required this.sections,
    required this.notes,
    this.docTitle = '형강 브라켓 가공 지시서',
    this.drawingCaption = '그림 (바깥 치수, mm)',
    this.moreDrawings = const [],
  });
}

String _day(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Future<Uint8List> buildBracketPdf(
  BracketPdfInput input, {
  DateTime? date,
}) async {
  final fonts = await loadKoreanPdfFonts();
  final day = date ?? DateTime.now();
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
              input.docTitle,
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
        for (final (caption, png) in [
          (input.drawingCaption, input.drawingPng),
          ...input.moreDrawings,
        ])
          // 제목과 그림을 한 덩어리로(제목만 앞 쪽 끝에 남고 그림이 다음 쪽으로 가지 않게).
          // pw.Container는 안의 Column을 따라 쪽이 나뉘므로 Inseparable로 묶는다.
          pw.Inseparable(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                sectionTitle(caption),
                pw.Container(
                  height: 300,
                  alignment: pw.Alignment.center,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: _line, width: 0.6),
                  ),
                  child: pw.Image(pw.MemoryImage(png), fit: pw.BoxFit.contain),
                ),
              ],
            ),
          ),
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
          if (sec.rows.isNotEmpty) ...[
            pw.SizedBox(height: 3),
            pw.Table(
              border: pw.TableBorder.all(color: _line, width: 0.6),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _head),
                  repeat: true,
                  children: [for (final h in sec.headers) cell(h, bold: true)],
                ),
                for (final r in sec.rows)
                  pw.TableRow(children: [for (final c in r) cell(c)]),
              ],
            ),
          ],
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

String bracketFileName(
  String title,
  DateTime date, {
  String prefix = 'steel_bracket',
}) {
  final t = title.trim().isEmpty
      ? 'noname'
      : title.trim().replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
  return '${prefix}_${t}_${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}.pdf';
}

// 지시서를 만드는 중인가(두 번 눌러 두 번 만들지 않게).
bool _bracketPdfBusy = false;

/// 지시서를 만들어 미리보기로 보여 준다. [input]은 그림 PNG를 뜬 뒤에 만든다.
Future<void> openBracketPdf(
  BuildContext context,
  Future<BracketPdfInput> Function() input, {
  String previewTitle = '브라켓 가공 지시서 미리보기',
  String filePrefix = 'steel_bracket',
}) async {
  if (_bracketPdfBusy) return;
  _bracketPdfBusy = true;
  final now = DateTime.now();
  final messenger = ScaffoldMessenger.maybeOf(context);
  Uint8List bytes;
  String title;
  String docTitle;
  try {
    final i = await input();
    title = i.title;
    docTitle = i.docTitle;
    bytes = await buildBracketPdf(i, date: now);
  } catch (e) {
    showSnackOnce(
      messenger,
      const SnackBar(content: Text('지시서를 만들지 못했습니다. 다시 해 보십시오.')),
    );
    return;
  } finally {
    _bracketPdfBusy = false;
  }
  final fileName = bracketFileName(title, now, prefix: filePrefix);
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => SteelPdfPreviewPage(
        bytes: bytes,
        fileName: fileName,
        title: previewTitle,
        onShare: () async {
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/$fileName');
          await file.writeAsBytes(bytes);
          // ignore: deprecated_member_use
          await Share.shareXFiles([
            XFile(file.path),
          ], text: '$docTitle ${title.trim()}');
        },
      ),
    ),
  );
}
