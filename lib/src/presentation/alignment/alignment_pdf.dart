// 축 정렬 기록 PDF(10-15, A4): 기계·일시·방식, 거리, 다이얼 지시값(검산), 판정, 발 이동량,
// 소프트 풋, 네 발 밑 심(시작·끝), 작업 회차, 메모. 현장 보고·업체 제출용.
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
import '../common/number_text.dart';
import '../steel_cutting/screens/steel_pdf_preview_page.dart';
import 'alignment_math.dart';
import 'alignment_record.dart';
import 'alignment_session.dart';
import 'alignment_shim.dart';

const PdfColor _ink = PdfColor.fromInt(0xFF1F2933);
const PdfColor _label = PdfColor.fromInt(0xFF374151);
const PdfColor _grey = PdfColor.fromInt(0xFF6B7280);
const PdfColor _line = PdfColor.fromInt(0xFF9CA3AF);
const PdfColor _head = PdfColor.fromInt(0xFFF1F5F9);
const PdfColor _red = PdfColor.fromInt(0xFFD32F2F);
const PdfColor _green = PdfColor.fromInt(0xFF2E7D32);
const PdfColor _amber = PdfColor.fromInt(0xFFB26A00);
const PdfColor _teal = PdfColor.fromInt(0xFF007580);

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];
String _two(int n) => n.toString().padLeft(2, '0');

String _num(String? s, {int digits = 2}) {
  final v = parseNumberText(s ?? '');
  return v == null ? '—' : v.toStringAsFixed(digits);
}

String _signed(double v) => v.abs() < 0.005 ? '0.00' : '${v > 0 ? '+' : '−'}${v.abs().toStringAsFixed(2)}';

/// 기록 PDF 바이트.
Future<Uint8List> buildAlignPdf(AlignRecord r) async {
  final fonts = await loadKoreanPdfFonts();
  final at = r.at;
  final when =
      '${at.year}년 ${at.month}월 ${at.day}일 (${_weekdays[at.weekday - 1]}) '
      '${_two(at.hour)}:${_two(at.minute)}';
  final inp = r.inputs;
  final ok = r.verdict == AlignVerdict.ok;

  pw.Widget cell(
    String t, {
    bool bold = false,
    PdfColor color = _ink,
    pw.TextAlign align = pw.TextAlign.center,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
    child: pw.Text(
      t,
      textAlign: align,
      style: pw.TextStyle(
        fontSize: 9.5,
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
          width: 60,
          child: pw.Text(k, style: const pw.TextStyle(fontSize: 9.5, color: _label)),
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
        pw.Text(t, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        if (tail.isNotEmpty) ...[
          pw.SizedBox(width: 8),
          pw.Text(tail, style: const pw.TextStyle(fontSize: 9.5, color: _grey)),
        ],
      ],
    ),
  );

  pw.Widget table(List<String> head, List<List<pw.Widget>> rows, {Map<int, pw.TableColumnWidth>? widths}) => pw.Table(
    border: pw.TableBorder.all(color: _line, width: 0.8),
    columnWidths: widths,
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _head),
        children: [for (final h in head) cell(h, bold: true)],
      ),
      for (final row in rows) pw.TableRow(verticalAlignment: pw.TableCellVerticalAlignment.middle, children: row),
    ],
  );

  final tolO = parseNumberText(inp['tolO'] ?? '');
  final tolA = parseNumberText(inp['tolA'] ?? '');
  final sf = softFootOf(inp);
  final sfOver = softFootOver(sf);
  final sag = [
    for (final (k, n) in [('sagA', '다이얼 A'), ('sagB', '다이얼 B'), ('sagR', '림 다이얼')])
      if ((inp[k] ?? '').trim().isNotEmpty) '$n ${_num(inp[k])}',
  ];
  final target = [
    if ((inp['targetY'] ?? '').trim().isNotEmpty) '위아래 ${_num(inp['targetY'])}',
    if ((inp['targetZ'] ?? '').trim().isNotEmpty) '옆 ${_num(inp['targetZ'])}',
  ];

  final doc = pw.Document(theme: fonts.theme);
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 36),
      footer: (ctx) => pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              '두 축의 어긋남을 직선으로 본 계산입니다. 제조사·사내 정렬 기준이 있으면 그것이 우선입니다.',
              style: const pw.TextStyle(fontSize: 8, color: _grey),
            ),
          ),
          pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: _grey)),
        ],
      ),
      build: (_) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Expanded(
              child: pw.Text(
                '축 정렬 기록 (${r.stage.label})',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Text(when, style: const pw.TextStyle(fontSize: 9.5, color: _label)),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Container(height: 1.2, color: _ink),
        pw.SizedBox(height: 10),
        info('기계', r.machine),
        info('방식', '${methodLabel(r.method)}${r.rpm > 0 ? ' · ${r.rpm} rpm' : ''}'),
        if (tolO != null && tolA != null)
          info('판정 기준', '평행 ${tolO.toStringAsFixed(2)} mm · 각도 ${tolA.toStringAsFixed(2)} mm/100mm'),
        if (r.note.trim().isNotEmpty) info('메모', r.note),

        heading('판정'),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: ok ? _green : _red, width: 1.2)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                verdictLabel(r.verdict),
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: ok ? _green : _red),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                '평행 어긋남 ${r.offset.toStringAsFixed(3)} mm · 각도 ${r.angle100.toStringAsFixed(3)} mm/100mm',
                style: const pw.TextStyle(fontSize: 10.5),
              ),
            ],
          ),
        ),

        heading('발 이동량 (모터)', '심 +는 넣기, −는 빼기 · 옆 +는 오른쪽(펌프 쪽에서 볼 때)'),
        table(
          ['발', '심', '옆 이동'],
          [
            [cell('앞발', bold: true), cell(shimText(r.shimFront)), cell(moveText(r.moveFront))],
            [cell('뒷발', bold: true), cell(shimText(r.shimRear)), cell(moveText(r.moveRear))],
          ],
          widths: const {0: pw.FixedColumnWidth(60)},
        ),

        heading('거리 (mm)'),
        table(
          ['항목', '값'],
          [
            for (final (k, label) in alignDistanceFields(r.method))
              [cell(label, align: pw.TextAlign.left), cell(_num(inp[k], digits: 1))],
          ],
          widths: const {1: pw.FixedColumnWidth(90)},
        ),

        heading('다이얼 지시값 (mm)', '12시에서 0, 3시 + 9시 = 6시면 제대로 읽은 것'),
        table(
          ['다이얼', '12시', '3시', '6시', '9시', '검산 차이'],
          [
            for (final (p, label) in alignDialFields(r.method))
              () {
                final a = parseNumberText(inp['${p}90'] ?? ''), b = parseNumberText(inp['${p}180'] ?? ''), c = parseNumberText(inp['${p}270'] ?? '');
                final diff = a == null || b == null || c == null ? null : (a + c - b).abs();
                return [
                  cell(label, bold: true, align: pw.TextAlign.left),
                  cell('0'),
                  cell(_num(inp['${p}90'])),
                  cell(_num(inp['${p}180'])),
                  cell(_num(inp['${p}270'])),
                  cell(diff == null ? '—' : diff.toStringAsFixed(2), color: diff != null && diff > 0.05 ? _amber : _ink),
                ];
              }(),
          ],
          widths: const {0: pw.FlexColumnWidth(2.2)},
        ),
        if (sag.isNotEmpty || target.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          if (sag.isNotEmpty) info('처짐 보정', '${sag.join(' · ')} mm'),
          if (target.isNotEmpty) info('열팽창 목표', '${target.join(' · ')} mm'),
        ],

        if (sf.isNotEmpty) ...[
          heading('소프트 풋', '한 발씩 풀어 올라온 양 · ${kSoftFootLimit.toStringAsFixed(2)} mm 넘으면 고침'),
          table(
            ['발', '올라온 양 (mm)', '판정'],
            [
              for (final f in AlignFoot.values)
                if (sf.containsKey(f))
                  [
                    cell(f.label, align: pw.TextAlign.left),
                    cell(sf[f]!.toStringAsFixed(2)),
                    cell(sfOver.contains(f) ? '고침 필요' : '이상 없음', bold: true, color: sfOver.contains(f) ? _red : _green),
                  ],
            ],
          ),
        ],

        if (hasFeet(r)) ...[
          heading('네 발 밑 심 (mm)', '왼쪽·오른쪽은 펌프 쪽에서 모터를 볼 때'),
          table(
            ['발', '작업 전', '작업 후', '바뀐 양'],
            [
              for (final f in AlignFoot.values)
                [
                  cell(f.label, align: pw.TextAlign.left),
                  cell((r.footStart[f] ?? 0).toStringAsFixed(2)),
                  cell((r.footEnd[f] ?? 0).toStringAsFixed(2), bold: true),
                  cell(_signed((r.footEnd[f] ?? 0) - (r.footStart[f] ?? 0))),
                ],
            ],
          ),
        ],

        if (r.rounds.isNotEmpty) ...[
          heading('작업 회차', '${r.rounds.length}회'),
          table(
            ['회차', '시각', '평행 (mm)', '각도', '한 일'],
            [
              for (var i = 0; i < r.rounds.length; i++)
                [
                  cell('${i + 1}'),
                  cell('${_two(r.rounds[i].at.hour)}:${_two(r.rounds[i].at.minute)}'),
                  cell(r.rounds[i].offset.toStringAsFixed(3)),
                  cell(r.rounds[i].angle100.toStringAsFixed(3)),
                  cell(doneLine(r.rounds[i]), align: pw.TextAlign.left),
                ],
            ],
            widths: const {
              0: pw.FixedColumnWidth(34),
              1: pw.FixedColumnWidth(44),
              2: pw.FixedColumnWidth(60),
              3: pw.FixedColumnWidth(50),
            },
          ),
        ],
      ],
    ),
  );
  return doc.save();
}

/// 파일 이름: align_기계_20261015_0140.pdf
String alignPdfFileName(AlignRecord r) {
  final m = r.machine.trim().isEmpty ? 'machine' : r.machine.trim().replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
  final a = r.at;
  return 'align_${m}_${a.year}${_two(a.month)}${_two(a.day)}_${_two(a.hour)}${_two(a.minute)}.pdf';
}

bool _busy = false;

/// 기록 PDF를 만들어 미리보기로 보여 준다. 공유는 미리보기의 단추를 눌러야만 된다.
Future<void> openAlignPdf(BuildContext context, AlignRecord r) async {
  if (_busy) return;
  _busy = true;
  final messenger = ScaffoldMessenger.maybeOf(context);
  Uint8List bytes;
  try {
    bytes = await buildAlignPdf(r);
  } catch (_) {
    showSnackOnce(messenger, const SnackBar(content: Text('PDF를 만들지 못했습니다.')));
    return;
  } finally {
    _busy = false;
  }
  final fileName = alignPdfFileName(r);
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => SteelPdfPreviewPage(
        bytes: bytes,
        fileName: fileName,
        title: '축 정렬 기록 미리보기',
        onShare: () async {
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/$fileName');
          await file.writeAsBytes(bytes);
          // ignore: deprecated_member_use
          await Share.shareXFiles([XFile(file.path)], text: '축 정렬 기록');
        },
      ),
    ),
  );
}
