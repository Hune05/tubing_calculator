// 부하 계산서(PDF, A4). 부하 표(번호·이름·설비용량·수용률·역률·최대수요 kW·kvar·kVA), 합계·부등률·여유·
// 필요 kVA·2차 정격전류·선정 용량·부하율, 작성·검토·승인 서명 칸.
// 미리보기로 먼저 보이고, 공유는 미리보기의 버튼을 눌러야만 된다(SteelPdfPreviewPage).
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../core/utils/pdf_fonts.dart';
import '../steel_cutting/screens/steel_pdf_preview_page.dart';
import 'elec_form_parts.dart' show fmt;
import 'elec_load_sum.dart';

const PdfColor _ink = PdfColor.fromInt(0xFF1F2933);
const PdfColor _grey = PdfColor.fromInt(0xFF6B7280);
const PdfColor _label = PdfColor.fromInt(0xFF374151);
const PdfColor _line = PdfColor.fromInt(0xFFD1D5DB);
const PdfColor _head = PdfColor.fromInt(0xFFF1F5F9);
const PdfColor _red = PdfColor.fromInt(0xFFD32F2F);
const PdfColor _redBg = PdfColor.fromInt(0xFFFDECEC);
const PdfColor _teal = PdfColor.fromInt(0xFF007580);
const PdfColor _tealBg = PdfColor.fromInt(0xFFE6F2F3);
const PdfColor _greyBg = PdfColor.fromInt(0xFFF3F4F6);

String _day(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 부하 계산서 PDF 바이트. 입력 오류가 있는 [result]로는 만들지 않는다(StateError).
Future<Uint8List> buildLoadSumPdf(
  LoadSumInput input,
  LoadSumResult result, {
  String title = '',
  DateTime? date,
}) async {
  if (!result.ok) {
    throw StateError('입력 오류가 있는 계산은 계산서로 만들 수 없습니다.');
  }
  final r = result;
  final fonts = await loadKoreanPdfFonts();
  final day = date ?? DateTime.now();
  final pass = r.pass;

  pw.Widget cell(
    String t, {
    bool bold = false,
    PdfColor color = _ink,
    pw.TextAlign align = pw.TextAlign.center,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    child: pw.Text(
      t,
      textAlign: align,
      style: pw.TextStyle(
        fontSize: 9,
        color: color,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );

  pw.Widget info(String k, String val, {double width = 70}) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: width,
          child: pw.Text(
            k,
            style: const pw.TextStyle(fontSize: 9, color: _label),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            val.trim().isEmpty ? '-' : val.trim(),
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ),
      ],
    ),
  );

  pw.Widget sectionTitle(String t) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Text(
      t,
      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
    ),
  );

  final rows = <pw.TableRow>[
    pw.TableRow(
      decoration: const pw.BoxDecoration(color: _head),
      children: [
        for (final h in [
          '번호',
          '부하 이름',
          '설비용량\n(kW)',
          '수용률\n(%)',
          '역률\n(%)',
          '최대수요\n(kW)',
          '최대수요\n(kvar)',
          '최대수요\n(kVA)',
        ])
          cell(h, bold: true),
      ],
    ),
    for (final l in r.lines)
      pw.TableRow(
        children: [
          cell('${l.no}'),
          cell(l.name.isEmpty ? '-' : l.name, align: pw.TextAlign.left),
          cell(fmt(l.kw, 2)),
          cell(fmt(l.dfPct, 2)),
          cell(fmt(l.pfPct, 2)),
          cell(fmt(l.p, 2)),
          cell(fmt(l.q, 2)),
          cell(fmt(l.s, 2)),
        ],
      ),
    pw.TableRow(
      decoration: const pw.BoxDecoration(color: _head),
      children: [
        cell('합계', bold: true),
        cell(''),
        cell(fmt(r.totalKw, 2), bold: true),
        cell(''),
        cell('종합 ${fmt(r.pf * 100, 1)}', bold: true),
        cell(fmt(r.demandKw, 2), bold: true),
        cell(fmt(r.demandKvar, 2), bold: true),
        cell(fmt(r.demandKva, 2), bold: true),
      ],
    ),
  ];

  final result3 = <(String, String, bool)>[
    ('최대수요 합계', '${fmt(r.demandKva, 2)} kVA', false),
    ('부등률', fmt(r.diversity, 2), false),
    ('장래 증설 여유', '${fmt(r.marginPct, 1)} %', false),
    ('필요 변압기 용량', '${fmt(r.requiredKva, 1)} kVA', false),
    ('2차 정격전류', '${fmt(r.ratedAmps, 1)} A (${fmt(r.volts, 0)} V, 3상)', false),
    (
      '선정 변압기 용량',
      r.selectedKva == null ? '입력하지 않음' : '${fmt(r.selectedKva!, 1)} kVA',
      false,
    ),
    ('부하율', r.loadPct == null ? '' : '${fmt(r.loadPct!, 1)} %', pass == false),
  ];

  final doc = pw.Document(theme: fonts.theme);
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 36),
      build: (_) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Expanded(
              child: pw.Text(
                '부하 계산서',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                if (title.trim().isNotEmpty)
                  pw.Text(
                    title.trim(),
                    style: const pw.TextStyle(fontSize: 10, color: _ink),
                  ),
                pw.Text(
                  '작성일 ${_day(day)}',
                  style: const pw.TextStyle(fontSize: 10, color: _grey),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Container(height: 1.2, color: _ink),
        pw.SizedBox(height: 10),
        info('현장·프로젝트', input.site, width: 80),
        pw.SizedBox(height: 6),
        sectionTitle('부하 목록'),
        pw.Table(
          border: pw.TableBorder.all(color: _line, width: 0.6),
          columnWidths: const {
            0: pw.FixedColumnWidth(32),
            1: pw.FlexColumnWidth(2.6),
            2: pw.FlexColumnWidth(1.3),
            3: pw.FlexColumnWidth(1.1),
            4: pw.FlexColumnWidth(1.2),
            5: pw.FlexColumnWidth(1.3),
            6: pw.FlexColumnWidth(1.3),
            7: pw.FlexColumnWidth(1.3),
          },
          children: rows,
        ),
        pw.SizedBox(height: 14),
        sectionTitle('변압기 용량'),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: pass == false ? _redBg : (pass == true ? _tealBg : _greyBg),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (final (k, v, bad) in result3)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 3),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SizedBox(
                        width: 100,
                        child: pw.Text(
                          k,
                          style: const pw.TextStyle(fontSize: 9, color: _label),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          v.isEmpty ? '-' : v,
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: bad ? _red : _ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (pass != null) ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  children: [
                    pw.Text(
                      '판정  ',
                      style: const pw.TextStyle(fontSize: 10, color: _label),
                    ),
                    pw.Text(
                      pass ? '합격 (부하율 100% 이하)' : '불합격 (부하율 100% 초과)',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: pass ? _teal : _red,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (input.memo.trim().isNotEmpty) ...[
          pw.SizedBox(height: 10),
          info('메모', input.memo.trim()),
        ],
        pw.SizedBox(height: 20),
        pw.Row(
          children: [
            for (final t in ['작성', '검토', '승인'])
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.only(right: 12),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        t,
                        style: const pw.TextStyle(fontSize: 9, color: _label),
                      ),
                      pw.SizedBox(height: 26),
                      pw.Container(height: 0.8, color: _line),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        '서명',
                        style: const pw.TextStyle(fontSize: 8, color: _grey),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Text(
          '최대수요 = 설비용량 × 수용률. 필요 변압기 용량 = 최대수요 kVA ÷ 부등률 × (1 + 여유). '
          '줄마다 유효전력 P와 무효전력 Q(= P × tanφ)를 더해 kVA를 구했습니다. '
          '최종 선정은 설계 기준과 제조사 자료를 따릅니다.',
          style: const pw.TextStyle(fontSize: 8, color: _grey),
        ),
      ],
    ),
  );
  return doc.save();
}

/// 파일 이름: load_sum_이름_날짜.pdf(파일 이름에 못 쓰는 글자는 _).
String loadSumFileName(String title, DateTime date) {
  final t = title.trim().isEmpty
      ? 'noname'
      : title.trim().replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
  final d = date;
  return 'load_sum_${t}_${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}.pdf';
}

/// 계산서를 만들어 미리보기로 보여 준다. 공유는 미리보기의 버튼을 눌러야만 된다.
Future<void> openLoadSumPdf(
  BuildContext context,
  LoadSumInput input,
  LoadSumResult result, {
  String title = '',
}) async {
  final now = DateTime.now();
  final bytes = await buildLoadSumPdf(input, result, title: title, date: now);
  final fileName = loadSumFileName(title, now);
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => SteelPdfPreviewPage(
        bytes: bytes,
        fileName: fileName,
        title: '부하 계산서 미리보기',
        onShare: () async {
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/$fileName');
          await file.writeAsBytes(bytes);
          // ignore: deprecated_member_use
          await Share.shareXFiles([
            XFile(file.path),
          ], text: '부하 계산서 ${title.trim()}');
        },
      ),
    ),
  );
}
