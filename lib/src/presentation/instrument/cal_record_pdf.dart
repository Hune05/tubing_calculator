// 계기 교정 성적서(PDF 한 장). 계기·기준기·작업자 정보, 조정 전·조정 후 다섯 점 표와 판정, 메모, 서명 칸.
// 미리보기로 먼저 보이고, 공유는 미리보기의 단추를 눌러야만 된다(SteelPdfPreviewPage).
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
import 'cal_record.dart';
import 'signal_calc.dart';

const PdfColor _ink = PdfColor.fromInt(0xFF1F2933);
const PdfColor _grey = PdfColor.fromInt(0xFF6B7280);
// 정보 이름표(태그 번호·계기 …) — 인쇄해도 읽히게 _grey보다 진하게.
const PdfColor _label = PdfColor.fromInt(0xFF374151);
const PdfColor _line = PdfColor.fromInt(0xFFD1D5DB);
const PdfColor _head = PdfColor.fromInt(0xFFF1F5F9);
const PdfColor _red = PdfColor.fromInt(0xFFD32F2F);
const PdfColor _redBg = PdfColor.fromInt(0xFFFDECEC);
const PdfColor _teal = PdfColor.fromInt(0xFF007580);
const PdfColor _tealBg = PdfColor.fromInt(0xFFE6F2F3);

String _fmt(double v, [int d = 3]) {
  var s = (v + (v >= 0 ? 1e-9 : -1e-9)).toStringAsFixed(d);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  if (s == '-0') s = '0';
  return s;
}

String _signed(double v, [int d = 3]) => '${v > 0 ? '+' : ''}${_fmt(v, d)}';

String _date(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 판정 글: 정상 / 허용 오차 넘음 / 판정 없음.
String calVerdictText(bool? pass) =>
    pass == null ? '판정 없음' : (pass ? '정상' : '허용 오차 넘음');

/// 성적서 PDF 바이트.
Future<Uint8List> buildCalRecordPdf(CalRecord r) async {
  final fonts = await loadKoreanPdfFonts();
  final u = r.unit.trim();
  String pv(double v) => u.isEmpty ? _fmt(v) : '${_fmt(v)} $u';

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

  pw.Widget info(String k, String v) => pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.SizedBox(
        width: 62,
        child: pw.Text(
          k,
          style: const pw.TextStyle(fontSize: 9, color: _label),
        ),
      ),
      pw.Expanded(
        child: pw.Text(
          v.isEmpty ? '—' : v,
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
      ),
    ],
  );

  final range =
      '${pv(r.lrv)} ~ ${pv(r.urv)} = 4 ~ 20 mA${r.transfer == Transfer.sqrt ? ' (제곱근, 차압 유량)' : ''}';
  final readKind = r.kind == ReadKind.ma ? '출력 전류(mA)' : '지시값(DCS·지시계)';
  final tol = r.tolPct == null ? '' : '± ${_fmt(r.tolPct!)} % (스팬 대비)';

  pw.Widget table(String title, List<CalEntry> entries) {
    final s = r.summaryOf(entries);
    final pvKind = r.kind == ReadKind.pv;
    final headers = [
      '점',
      '넣은 값${u.isEmpty ? '' : ' ($u)'}',
      '이론 mA',
      pvKind ? '지시값${u.isEmpty ? '' : ' ($u)'}' : '읽은 mA',
      if (pvKind) '흐르는 mA',
      '오차 %',
      '오차${u.isEmpty ? '' : ' ($u)'}',
      '판정',
    ];
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _head),
        children: [for (final h in headers) cell(h, bold: true)],
      ),
    ];
    for (var i = 0; i < kCalPoints.length; i++) {
      final p = s.points[i];
      final applied = i < entries.length && entries[i].applied != null
          ? entries[i].applied!
          : pctToPv(kCalPoints[i], r.lrv, r.urv);
      final bad = p?.pass == false;
      final c = bad ? _red : _ink;
      rows.add(
        pw.TableRow(
          decoration: bad ? const pw.BoxDecoration(color: _redBg) : null,
          children: [
            cell('${_fmt(kCalPoints[i])}%', bold: true),
            cell(_fmt(applied)),
            cell(_fmt(idealMa(applied, r.lrv, r.urv, r.transfer))),
            cell(p == null ? '—' : _fmt(p.reading)),
            if (pvKind)
              cell(
                p == null
                    ? '—'
                    : _fmt(idealMa(p.reading, r.lrv, r.urv, r.transfer)),
              ),
            cell(p == null ? '—' : _signed(p.errPct, 2), color: c, bold: bad),
            cell(p == null ? '—' : _signed(p.errPv), color: c),
            cell(
              p == null
                  ? '—'
                  : (p.pass == null ? '—' : (p.pass! ? '정상' : '넘음')),
              color: c,
              bold: bad,
            ),
          ],
        ),
      );
    }
    final w = s.worst;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Table(
          border: pw.TableBorder.all(color: _line, width: 0.6),
          children: rows,
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          w == null
              ? '잰 점이 없습니다.'
              : '가장 큰 오차 ${_signed(w.$2.errPct, 2)} % (${_fmt(kCalPoints[w.$1])}% 점) · ${calVerdictText(s.pass)}'
                    '${s.failed.isEmpty ? '' : ' — 넘은 점: ${s.failed.map((i) => '${_fmt(kCalPoints[i])}%').join(', ')}'}',
          style: pw.TextStyle(
            fontSize: 9,
            color: s.pass == false ? _red : _ink,
          ),
        ),
      ],
    );
  }

  final fin = r.finalPass;
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
                '계기 교정 성적서',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Text(
              _date(r.date),
              style: const pw.TextStyle(fontSize: 10, color: _grey),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Container(height: 1.2, color: _ink),
        pw.SizedBox(height: 10),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  info('태그 번호', r.tag),
                  pw.SizedBox(height: 4),
                  info('계기', r.instrument),
                  pw.SizedBox(height: 4),
                  info('제조사·모델', r.model),
                  pw.SizedBox(height: 4),
                  info('기준기', r.refStd),
                ],
              ),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  info('측정 범위', range),
                  pw.SizedBox(height: 4),
                  info('읽은 값', readKind),
                  pw.SizedBox(height: 4),
                  info('허용 오차', tol),
                  pw.SizedBox(height: 4),
                  info('작업자', r.worker),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 14),
        table('조정 전', r.found),
        pw.SizedBox(height: 14),
        if (r.adjusted)
          table('조정 후', r.left)
        else
          pw.Text(
            '조정 후: 조정하지 않았습니다.',
            style: const pw.TextStyle(fontSize: 10, color: _grey),
          ),
        pw.SizedBox(height: 14),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: fin == false ? _redBg : _tealBg,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Row(
            children: [
              pw.Text(
                '최종 판정  ',
                style: const pw.TextStyle(fontSize: 10, color: _grey),
              ),
              pw.Text(
                calVerdictText(fin),
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: fin == false ? _red : _teal,
                ),
              ),
              pw.Text(
                r.adjusted ? '  (조정 후 기준)' : '  (조정 전 기준)',
                style: const pw.TextStyle(fontSize: 9, color: _grey),
              ),
            ],
          ),
        ),
        if (r.memo.trim().isNotEmpty) ...[
          pw.SizedBox(height: 10),
          info('메모', r.memo.trim()),
        ],
        pw.SizedBox(height: 24),
        pw.Row(
          children: [
            for (final t in ['작업자', '확인'])
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.only(right: 16),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        t,
                        style: const pw.TextStyle(fontSize: 9, color: _grey),
                      ),
                      pw.SizedBox(height: 22),
                      pw.Container(height: 0.8, color: _line),
                    ],
                  ),
                ),
              ),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Text(
          r.kind == ReadKind.ma
              ? '오차 % = (읽은 mA − 이론 mA) ÷ 16 mA × 100. 이론 mA는 넣은 값으로 셈.'
              : '오차 % = (지시값 − 넣은 값) ÷ 측정 범위 × 100. 흐르는 mA는 지시값에서 역산.',
          style: const pw.TextStyle(fontSize: 8, color: _grey),
        ),
      ],
    ),
  );
  return doc.save();
}

/// 파일 이름: cal_태그_날짜.pdf(파일 이름에 못 쓰는 글자는 _).
String calRecordFileName(CalRecord r) {
  final tag = r.tag.trim().isEmpty
      ? 'notag'
      : r.tag.trim().replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
  final d = r.date;
  return 'cal_${tag}_${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}.pdf';
}

/// 성적서를 만들어 미리보기로 보여 준다. 공유는 미리보기의 단추를 눌러야만 된다.
Future<void> openCalRecordPdf(BuildContext context, CalRecord r) async {
  final bytes = await buildCalRecordPdf(r);
  final fileName = calRecordFileName(r);
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => SteelPdfPreviewPage(
        bytes: bytes,
        fileName: fileName,
        title: '교정 성적서 미리보기',
        onShare: () async {
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/$fileName');
          await file.writeAsBytes(bytes);
          // ignore: deprecated_member_use
          await Share.shareXFiles([XFile(file.path)], text: '교정 성적서 ${r.tag}');
        },
      ),
    ),
  );
}
