// 배관 압력시험 기록서(PDF, A4). 시험 번호·시험일, 시험 정보, 압력계·안전밸브, 측정 기록 표, 판정 상자,
// 메모, 서명 칸(시험자·시공사·감리·발주처 입회). 압력은 기록의 단위로 적는다.
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
import 'pressure_calc.dart';
import 'pressure_units.dart';
import 'test_record.dart';

const PdfColor _ink = PdfColor.fromInt(0xFF1F2933);
const PdfColor _grey = PdfColor.fromInt(0xFF6B7280);
// 정보 이름표: 인쇄해도 읽히게 _grey보다 진하게.
const PdfColor _label = PdfColor.fromInt(0xFF374151);
const PdfColor _line = PdfColor.fromInt(0xFFD1D5DB);
const PdfColor _head = PdfColor.fromInt(0xFFF1F5F9);
const PdfColor _red = PdfColor.fromInt(0xFFD32F2F);
const PdfColor _redBg = PdfColor.fromInt(0xFFFDECEC);
const PdfColor _teal = PdfColor.fromInt(0xFF007580);
const PdfColor _tealBg = PdfColor.fromInt(0xFFE6F2F3);
const PdfColor _greyBg = PdfColor.fromInt(0xFFF3F4F6);

/// 기록서 PDF 바이트.
Future<Uint8List> buildPtRecordPdf(PtRecord r) async {
  final fonts = await loadKoreanPdfFonts();
  final u = r.unit;
  String p(double? kpa) => kpa == null ? '' : ptPressure(kpa, u);
  final v = r.verdict;
  final pass = v.pass;
  final start = r.startAt ?? r.startReading?.at;

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
            val.trim().isEmpty ? '—' : val.trim(),
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ),
      ],
    ),
  );

  pw.Widget title(String t) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Text(
      t,
      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
    ),
  );

  // 압력계·안전밸브
  final gaugeRows = <pw.TableRow>[
    pw.TableRow(
      decoration: const pw.BoxDecoration(color: _head),
      children: [
        for (final h in ['구분', '번호', '눈금 범위', '검교정 유효일']) cell(h, bold: true),
      ],
    ),
    for (var i = 0; i < 2; i++)
      pw.TableRow(
        children: [
          cell('압력계 ${i + 1}', bold: true),
          cell(i < r.gauges.length ? r.gauges[i].no : ''),
          cell(i < r.gauges.length ? r.gauges[i].range : ''),
          cell(i < r.gauges.length ? r.gauges[i].calDue : ''),
        ],
      ),
    pw.TableRow(
      children: [
        cell('안전밸브', bold: true),
        cell(r.reliefNo),
        cell(r.reliefKpa == null ? '' : '설정압력 ${p(r.reliefKpa)}'),
        cell(''),
      ],
    ),
  ];

  // 측정 기록
  final readRows = <pw.TableRow>[
    pw.TableRow(
      decoration: const pw.BoxDecoration(color: _head),
      children: [
        for (final h in ['구분', '시각', '경과 (분)', '압력 (${u.label})', '온도 (°C)'])
          cell(h, bold: true),
      ],
    ),
    for (final x in r.readings)
      pw.TableRow(
        children: [
          cell(ptReadKindLabel(x.kind), bold: x.kind != PtReadKind.mid),
          cell(ptHms(x.at)),
          cell(
            start == null ? '' : ptFmt(ptMinutes(x.at.difference(start)), 1),
          ),
          cell(ptFmt(x.kpa / u.kpa, 4)),
          cell(x.tempC == null ? '' : ptFmt(x.tempC!, 1)),
        ],
      ),
  ];

  // 판정 상자
  final hydro = r.medium == TestMedium.hydro;
  String corrected() {
    if (!v.ended) return '';
    if (hydro) return '보정하지 않음(수압)';
    if (v.correctedDropKpa == null) return '보정하지 않음(온도 없음)';
    return ptDrop(v.correctedDropKpa!, u);
  }

  final resultRows = <(String, String, bool)>[
    ('측정 압력강하', v.rawDropKpa == null ? '' : ptDrop(v.rawDropKpa!, u), false),
    ('온도 보정 후', corrected(), false),
    (
      '허용 압력강하',
      v.allowKpa == null
          ? '없음(압력강하는 판정하지 않음)'
          : '${p(v.allowKpa)}${v.dropOk == null ? '' : (v.dropOk! ? ' 이내' : ' 초과')}',
      v.dropOk == false,
    ),
    (
      '유지시간 달성',
      v.ended
          ? '${v.holdMet ? '예' : '아니오'} (${ptFmt(v.elapsedMin!, 1)}분 경과, 규정 ${ptFmt(r.holdMin, 1)}분 이상)'
          : '',
      v.ended && !v.holdMet,
    ),
    ('누설·물맺힘 없음', r.leakOk ? '예 (육안 확인)' : '아니오', !r.leakOk),
  ];

  final reasons = pass == true ? const <String>[] : v.reasons(u);
  final dT = v.hydroDeltaC;

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
                '배관 압력시험 기록서',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  '시험 번호 ${r.testNo.trim().isEmpty ? '—' : r.testNo.trim()}',
                  style: const pw.TextStyle(fontSize: 10, color: _ink),
                ),
                pw.Text(
                  '시험일 ${ptDay(r.date)}',
                  style: const pw.TextStyle(fontSize: 10, color: _grey),
                ),
              ],
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
                  info('현장·프로젝트', r.site),
                  info('계통', r.system),
                  info('라인 번호', r.line),
                  info('P&ID·아이소', r.pid),
                  info('시험 구간', r.section),
                ],
              ),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  info('규격', ptCodeLabel(r.code)),
                  info('시험 종류', ptMediumLabel(r.medium)),
                  info('시험유체', ptFluidLabel(r.fluid)),
                  info('설계압력', p(r.designKpa)),
                  info('시험압력', p(r.testKpa)),
                  info('규정 유지시간', '${ptFmt(r.holdMin, 1)}분 이상'),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        title('압력계·안전밸브'),
        pw.Table(
          border: pw.TableBorder.all(color: _line, width: 0.6),
          columnWidths: const {
            0: pw.FlexColumnWidth(1.1),
            1: pw.FlexColumnWidth(1.4),
            2: pw.FlexColumnWidth(1.6),
            3: pw.FlexColumnWidth(1.3),
          },
          children: gaugeRows,
        ),
        pw.SizedBox(height: 14),
        title('측정 기록'),
        if (r.readings.isEmpty)
          pw.Text(
            '측정 기록이 없습니다.',
            style: const pw.TextStyle(fontSize: 10, color: _grey),
          )
        else
          pw.Table(
            border: pw.TableBorder.all(color: _line, width: 0.6),
            children: readRows,
          ),
        if (start != null)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Text(
              '시작 ${ptDay(start)} ${ptHms(start)}'
              '${r.endAt == null ? '' : ' · 종료 ${ptDay(r.endAt!)} ${ptHms(r.endAt!)}'}'
              '${v.elapsedMin == null ? '' : ' · 경과 ${ptFmt(v.elapsedMin!, 1)}분'}',
              style: const pw.TextStyle(fontSize: 9, color: _ink),
            ),
          ),
        pw.SizedBox(height: 14),
        title('판정'),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: pass == false ? _redBg : (pass == true ? _tealBg : _greyBg),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (final (k, val, bad) in resultRows)
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
                          val.isEmpty ? '—' : val,
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
              if (v.hydroTempKpa != null && dT != null)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 3),
                  child: pw.Text(
                    '참고: 물 온도 변화 ${dT > 0 ? '+' : ''}${ptFmt(dT, 1)}°C로 압력이 약 '
                    '${ptPressure(v.hydroTempKpa!.abs(), u)} ${v.hydroTempKpa! < 0 ? '낮아집니다' : '높아집니다'}'
                    '(추정, 공기 없는 막힌 관 기준).',
                    style: const pw.TextStyle(fontSize: 9, color: _grey),
                  ),
                ),
              pw.SizedBox(height: 4),
              pw.Row(
                children: [
                  pw.Text(
                    '최종 판정  ',
                    style: const pw.TextStyle(fontSize: 10, color: _label),
                  ),
                  pw.Text(
                    ptVerdictText(pass),
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: pass == false
                          ? _red
                          : (pass == true ? _teal : _ink),
                    ),
                  ),
                ],
              ),
              for (final t in reasons)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 2),
                  child: pw.Text(
                    '· $t',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: pass == false ? _red : _ink,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (r.memo.trim().isNotEmpty) ...[
          pw.SizedBox(height: 10),
          info('메모', r.memo.trim()),
        ],
        pw.SizedBox(height: 20),
        pw.Row(
          children: [
            for (final (t, name) in [
              ('시험자', r.tester),
              ('시공사 입회', r.witnessContractor),
              ('감리 입회', r.witnessSupervisor),
              ('발주처 입회', r.witnessOwner),
            ])
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
                      pw.SizedBox(height: 4),
                      // 이름이 없어도 서명 줄 높이가 같게 칸 높이를 고정한다.
                      pw.SizedBox(
                        height: 16,
                        child: pw.Text(
                          name.trim(),
                          maxLines: 1,
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 18),
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
          hydro
              ? '수압: 측정 압력강하(시작 − 종료 게이지 압력)로 판정합니다. '
                    '최종 판정은 해당 규격과 시험 절차서를 따릅니다.'
              : '공압: 종료 절대압을 시작 온도 기준으로 환산해 비교합니다(P2·T1/T2, 절대 온도 K). '
                    '최종 판정은 해당 규격과 시험 절차서를 따릅니다.',
          style: const pw.TextStyle(fontSize: 8, color: _grey),
        ),
      ],
    ),
  );
  return doc.save();
}

/// 파일 이름: pt_라인_날짜.pdf(파일 이름에 못 쓰는 글자는 _).
String ptRecordFileName(PtRecord r) {
  final line = r.line.trim().isEmpty
      ? 'noline'
      : r.line.trim().replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
  final d = r.date;
  return 'pt_${line}_${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}.pdf';
}

/// 기록서를 만들어 미리보기로 보여 준다. 공유는 미리보기의 버튼을 눌러야만 된다.
Future<void> openPtRecordPdf(BuildContext context, PtRecord r) async {
  final bytes = await buildPtRecordPdf(r);
  final fileName = ptRecordFileName(r);
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => SteelPdfPreviewPage(
        bytes: bytes,
        fileName: fileName,
        title: '압력시험 기록서 미리보기',
        onShare: () async {
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/$fileName');
          await file.writeAsBytes(bytes);
          // ignore: deprecated_member_use
          await Share.shareXFiles([
            XFile(file.path),
          ], text: '압력시험 기록서 ${r.line}');
        },
      ),
    ),
  );
}
