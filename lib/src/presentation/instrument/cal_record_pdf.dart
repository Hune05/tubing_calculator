// 계기 교정 성적서(PDF 한 장). 계기·표준기·작업자·교정일·차기 교정일·주위 조건, 조정 전·조정 후 다섯 점 표와
// 판정, 메모, 서명 칸. 미리보기로 먼저 보이고, 공유는 미리보기의 버튼을 눌러야만 된다(SteelPdfPreviewPage).
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
// 정보 이름표(태그 번호·계기 …): 인쇄해도 읽히게 _grey보다 진하게.
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

/// 성적서 PDF 바이트.
Future<Uint8List> buildCalRecordPdf(CalRecord r) async {
  final fonts = await loadKoreanPdfFonts();
  final u = r.unit.trim();
  final uu = u.isEmpty ? '' : ' ($u)';
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

  pw.Widget info(String k, String v) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Row(
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
    ),
  );

  final range =
      '${pv(r.lrv)} ~ ${pv(r.urv)} = 4 ~ 20 mA'
      '${r.transfer == Transfer.linear ? '' : ' · ${transferLabel(r.transfer)}'}';
  final tol = r.tolPct == null ? '' : '± ${_fmt(r.tolPct!)} % (스팬)';

  pw.Widget table(String title, List<CalEntry> entries) {
    final s = r.summaryOf(entries);
    final headers = switch (r.kind) {
      ReadKind.ma => [
        '측정점',
        '입력값$uu',
        '이론값 (mA)',
        '측정값 (mA)',
        '오차 %',
        '오차$uu',
        '판정',
      ],
      ReadKind.pv => [
        '측정점',
        '입력값$uu',
        '이론값 (mA)',
        '지시값$uu',
        '환산 mA',
        '오차 %',
        '오차$uu',
        '판정',
      ],
      ReadKind.maIn => [
        '측정점',
        '입력 (mA)',
        '이론값$uu',
        '지시값$uu',
        '오차 %',
        '오차$uu',
        '판정',
      ],
    };
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
          : nominalInput(kCalPoints[i], r.kind, r.lrv, r.urv);
      final bad = p?.pass == false;
      final c = bad ? _red : _ink;
      String dash(double? v, [String Function(double)? f]) =>
          v == null || v.isNaN ? '—' : (f ?? _fmt)(v);
      rows.add(
        pw.TableRow(
          decoration: bad ? const pw.BoxDecoration(color: _redBg) : null,
          children: [
            cell('${_fmt(kCalPoints[i])}%', bold: true),
            cell(_fmt(applied)),
            cell(
              r.kind == ReadKind.maIn
                  ? _fmt(pvFromMa(applied, r.lrv, r.urv, r.transfer))
                  : _fmt(idealMa(applied, r.lrv, r.urv, r.transfer)),
            ),
            cell(dash(p?.reading)),
            if (r.kind == ReadKind.pv)
              cell(
                dash(
                  p == null
                      ? null
                      : idealMa(p.reading, r.lrv, r.urv, r.transfer),
                ),
              ),
            cell(dash(p?.errPct, (v) => _signed(v, 2)), color: c, bold: bad),
            cell(dash(p?.errPv, _signed), color: c),
            cell(
              p == null || p.pass == null ? '—' : calVerdictText(p.pass),
              color: c,
              bold: bad,
            ),
          ],
        ),
      );
    }
    final w = s.worst;
    final advise = s.adjustAdvised;
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
              ? '측정값이 없습니다.'
              : '최대 오차 ${_signed(w.$2.errPct, 2)} % (${_fmt(kCalPoints[w.$1])}% 점) · ${calVerdictText(s.pass)}'
                    '${s.failed.isEmpty ? '' : ' · 불합격 점: ${s.failed.map((i) => '${_fmt(kCalPoints[i])}%').join(', ')}'}'
                    '${advise.isEmpty ? '' : ' · 조정 권장: ${advise.map((i) => '${_fmt(kCalPoints[i])}%').join(', ')}'}',
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
              calDay(r.date),
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
                  info('계기', r.instrument),
                  info('제조사·모델', r.model),
                  info('표준기', r.refStd),
                  info('주위 조건', r.ambient),
                ],
              ),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  info('측정 범위', range),
                  info('측정 방법', kindLabel(r.kind)),
                  info('허용오차', tol),
                  info('교정일', calDay(r.date)),
                  info('차기 교정일', r.nextDue == null ? '' : calDay(r.nextDue!)),
                  info('작업자', r.worker),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        table('조정 전', r.found),
        pw.SizedBox(height: 14),
        if (r.adjusted)
          table('조정 후', r.left)
        else
          pw.Text(
            '조정 후: 조정 없음',
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
                style: const pw.TextStyle(fontSize: 10, color: _label),
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
                        style: const pw.TextStyle(fontSize: 9, color: _label),
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
              ? '오차 % = (측정값 − 이론값) ÷ 16 mA × 100. 이론값은 입력값으로 계산.'
              : '오차 % = (지시값 − 이론값) ÷ 스팬 × 100.'
                    '${r.kind == ReadKind.pv ? ' 환산 mA는 지시값에서 역산.' : ''}',
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

/// 성적서를 만들어 미리보기로 보여 준다. 공유는 미리보기의 버튼을 눌러야만 된다.
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
