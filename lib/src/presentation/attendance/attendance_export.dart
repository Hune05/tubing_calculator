// 월 근태 기록 내보내기: PDF(미리보기 후 공유, SteelPdfPreviewPage)와 CSV(엑셀, UTF-8 BOM).
// 숫자는 모두 attendance_calc.dart에서 나온다(화면과 같은 값).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../core/utils/pdf_fonts.dart';
import '../my_schedule/korean_holidays.dart';
import '../my_work_logs/models/attendance.dart';
import '../steel_cutting/screens/steel_pdf_preview_page.dart';
import 'attendance_calc.dart';

String _two(int v) => v.toString().padLeft(2, '0');

String _csvCell(String s) =>
    s.contains(RegExp(r'[",\n\r]')) ? '"${s.replaceAll('"', '""')}"' : s;

String _hm(int m) => m == 0 ? '' : formatMinutes(m);

/// 월 근태 CSV(UTF-8 BOM 포함, 엑셀에서 바로 열린다). 하루 한 줄 + 합계 줄.
/// 시간 칸은 엑셀에서 더할 수 있게 소수 시간(8.5)으로 적는다.
String attendanceMonthCsv({
  required DateTime month,
  required Map<String, AttendanceRecord> records,
  required AttendanceCalcOptions options,
}) {
  final first = DateTime(month.year, month.month, 1);
  final last = DateTime(month.year, month.month + 1, 0);
  final r = computeRange(records, first, last, options);
  final s = summarizeMonth(records, month, options);
  final rows = <List<String>>[
    [
      '날짜',
      '요일',
      '공휴일',
      '근태',
      '출근',
      '퇴근',
      '휴게(분)',
      '근로(시간)',
      '연장(시간)',
      '야간(시간)',
      '휴일(시간)',
      '휴일 8시간 초과(시간)',
      '메모',
    ],
  ];
  for (final d in r.days) {
    if (d.date.month != month.month || d.date.year != month.year) continue;
    final rec = d.record;
    final w = d.work;
    rows.add([
      dateKey(d.date),
      kWeekdayKo[d.date.weekday - 1],
      holidayName(d.date),
      rec?.type ?? '',
      rec?.checkIn ?? '',
      rec?.checkOut ?? '',
      w == null ? '' : '${w.breakMin}',
      w == null ? '' : decimalHours(w.work),
      w == null ? '' : decimalHours(d.overtime),
      w == null ? '' : decimalHours(w.night),
      w == null ? '' : decimalHours(w.holiday),
      w == null ? '' : decimalHours(w.holidayOver8),
      rec?.memo ?? '',
    ]);
  }
  rows.add([
    '합계',
    '',
    '',
    '연차 사용 ${formatLeaveDays(s.leaveUsed)}일',
    '',
    '',
    '',
    decimalHours(s.work),
    decimalHours(s.overtime),
    decimalHours(s.night),
    decimalHours(s.holiday),
    decimalHours(s.holidayOver8),
    '가산 시간 ${decimalHours(s.premiumMinutes)}',
  ]);
  final body = rows.map((row) => row.map(_csvCell).join(',')).join('\r\n');
  return '\uFEFF$body\r\n';
}

String attendanceFileBase(DateTime month) =>
    'attendance_${month.year}${_two(month.month)}';

const PdfColor _ink = PdfColor.fromInt(0xFF1F2933);
const PdfColor _grey = PdfColor.fromInt(0xFF6B7280);
const PdfColor _line = PdfColor.fromInt(0xFFD1D5DB);
const PdfColor _head = PdfColor.fromInt(0xFFF1F5F9);
const PdfColor _red = PdfColor.fromInt(0xFFD32F2F);
const PdfColor _redBg = PdfColor.fromInt(0xFFFDECEC);
const PdfColor _restBg = PdfColor.fromInt(0xFFFFF5F5);

/// 월 근태 기록 PDF(A4 한 장). [leave]가 있으면 연차 잔여 줄을 넣는다.
Future<Uint8List> buildAttendanceMonthPdf({
  required DateTime month,
  required Map<String, AttendanceRecord> records,
  required AttendanceCalcOptions options,
  LeaveBalance? leave,
  DateTime? now,
}) async {
  final fonts = await loadKoreanPdfFonts();
  final first = DateTime(month.year, month.month, 1);
  final last = DateTime(month.year, month.month + 1, 0);
  final r = computeRange(records, first, last, options);
  final s = summarizeMonth(records, month, options);
  final made = now ?? DateTime.now();

  pw.Widget cell(
    String t, {
    bool bold = false,
    PdfColor color = _ink,
    pw.TextAlign align = pw.TextAlign.center,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2.2),
    child: pw.Text(
      t,
      textAlign: align,
      maxLines: 1,
      style: pw.TextStyle(
        fontSize: 7.5,
        color: color,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );

  final rows = <pw.TableRow>[
    pw.TableRow(
      decoration: const pw.BoxDecoration(color: _head),
      children: [
        for (final h in [
          '날짜',
          '근태',
          '출근',
          '퇴근',
          '휴게',
          '근로',
          '연장',
          '야간',
          '휴일',
          '메모',
        ])
          cell(h, bold: true),
      ],
    ),
  ];
  for (final d in r.days) {
    if (d.date.month != month.month || d.date.year != month.year) continue;
    final rec = d.record;
    final w = d.work;
    final rest = isRestDay(d.date, options);
    final hn = holidayName(d.date);
    final memo = [if (hn.isNotEmpty) hn, if (rec?.memo != null) rec!.memo!];
    rows.add(
      pw.TableRow(
        decoration: rest ? const pw.BoxDecoration(color: _restBg) : null,
        children: [
          cell(
            '${d.date.day}일 (${kWeekdayKo[d.date.weekday - 1]})',
            color: rest ? _red : _ink,
          ),
          cell(
            rec == null || rec.type == kAttendanceNormal ? '' : rec.type,
            bold: true,
          ),
          cell(rec?.checkIn ?? ''),
          cell(rec?.checkOut ?? ''),
          cell(w == null ? '' : _hm(w.breakMin)),
          cell(w == null ? '' : formatMinutes(w.work), bold: true),
          cell(w == null ? '' : _hm(d.overtime)),
          cell(w == null ? '' : _hm(w.night)),
          cell(w == null ? '' : _hm(w.holiday)),
          cell(memo.join(' · '), align: pw.TextAlign.left),
        ],
      ),
    );
  }

  pw.Widget stat(String k, String v) => pw.Container(
    width: 84,
    padding: const pw.EdgeInsets.all(5),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _line, width: 0.6),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(k, style: const pw.TextStyle(fontSize: 7.5, color: _grey)),
        pw.SizedBox(height: 2),
        pw.Text(
          v,
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
      ],
    ),
  );

  final counts = s.typeCounts.entries
      .map((e) => '${e.key} ${e.value}회')
      .join(' · ');
  final over = s.weeksOver52;

  final doc = pw.Document(theme: fonts.theme);
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 26, 28, 24),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '근태 기록  ${month.year}년 ${month.month}월',
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            '만든 날 ${made.year}-${_two(made.month)}-${_two(made.day)}'
            '   ·   성명 ____________',
            style: const pw.TextStyle(fontSize: 8, color: _grey),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: _line, width: 0.5),
            columnWidths: const {
              0: pw.FixedColumnWidth(46),
              1: pw.FixedColumnWidth(34),
              2: pw.FixedColumnWidth(30),
              3: pw.FixedColumnWidth(30),
              4: pw.FixedColumnWidth(34),
              5: pw.FixedColumnWidth(46),
              6: pw.FixedColumnWidth(40),
              7: pw.FixedColumnWidth(40),
              8: pw.FixedColumnWidth(40),
              9: pw.FlexColumnWidth(),
            },
            children: rows,
          ),
          pw.SizedBox(height: 8),
          pw.Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              stat('근로시간', formatMinutes(s.work)),
              stat('연장', formatMinutes(s.overtime)),
              stat('야간', formatMinutes(s.night)),
              stat('휴일', formatMinutes(s.holiday)),
              stat('휴일 8시간 초과', formatMinutes(s.holidayOver8)),
              stat('가산 시간', formatMinutes(s.premiumMinutes)),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            '출퇴근 시간을 적은 날 ${s.timedDays}일 · 연차 사용 '
            '${formatLeaveDays(s.leaveUsed)}일${counts.isEmpty ? '' : ' · $counts'}',
            style: const pw.TextStyle(fontSize: 8.5),
          ),
          if (leave != null)
            pw.Text(
              '연차 잔여 ${formatLeaveDays(leave.remaining)}일 '
              '(발생 ${formatLeaveDays(leave.granted)}일, 사용 '
              '${formatLeaveDays(leave.used)}일, 예정 ${formatLeaveDays(leave.planned)}일, '
              '기간 ${dateKey(leave.periodStart)} ~ '
              '${dateKey(DateTime(leave.periodEnd.year, leave.periodEnd.month, leave.periodEnd.day - 1))})',
              style: const pw.TextStyle(fontSize: 8.5),
            ),
          if (over.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Container(
              padding: const pw.EdgeInsets.all(5),
              color: _redBg,
              child: pw.Text(
                over
                    .map(
                      (w) =>
                          '${w.monday.month}월 ${w.monday.day}일 주: 근로 ${formatMinutes(w.work)}, '
                          '연장 ${formatMinutes(w.limitOver)}. 1주 연장 12시간(주 52시간)을 초과합니다.',
                    )
                    .join('\n'),
                style: const pw.TextStyle(fontSize: 8, color: _red),
              ),
            ),
          ],
          pw.Spacer(),
          pw.Text(
            '계산: 근로 = 퇴근 − 출근 − 휴게. 연장 = 하루 8시간 초과 + 1주(월~일) 40시간 초과(제50·53조). '
            '야간 22:00~06:00. 휴일 = 일요일·공휴일${options.saturdayIsHoliday ? '·토요일' : ''}(제55·56조). '
            '가산 시간 = 연장·야간·휴일 50%, 휴일 8시간 초과 100%(제56조). '
            '5명 미만 사업장은 가산·52시간·연차 조항이 적용되지 않습니다. '
            '최종 기준은 취업규칙과 근로계약입니다.',
            style: const pw.TextStyle(fontSize: 7, color: _grey),
          ),
        ],
      ),
    ),
  );
  return doc.save();
}

/// PDF를 만들어 미리보기로 보여 준다. 공유는 미리보기의 단추를 눌러야만 된다.
Future<void> openAttendanceMonthPdf(
  BuildContext context, {
  required DateTime month,
  required Map<String, AttendanceRecord> records,
  required AttendanceCalcOptions options,
  LeaveBalance? leave,
}) async {
  final bytes = await buildAttendanceMonthPdf(
    month: month,
    records: records,
    options: options,
    leave: leave,
  );
  final fileName = '${attendanceFileBase(month)}.pdf';
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => SteelPdfPreviewPage(
        bytes: bytes,
        fileName: fileName,
        title: '근태 기록 미리보기',
        onShare: () async {
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/$fileName');
          await file.writeAsBytes(bytes);
          // ignore: deprecated_member_use
          await Share.shareXFiles([
            XFile(file.path),
          ], text: '근태 기록 ${month.year}년 ${month.month}월');
        },
      ),
    ),
  );
}

/// CSV 파일을 만들어 공유 창을 연다(보내기는 사용자가 고른다). 실패하면 false.
Future<bool> shareAttendanceMonthCsv({
  required DateTime month,
  required Map<String, AttendanceRecord> records,
  required AttendanceCalcOptions options,
}) async {
  try {
    final csv = attendanceMonthCsv(
      month: month,
      records: records,
      options: options,
    );
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${attendanceFileBase(month)}.csv');
    await file.writeAsBytes(utf8.encode(csv));
    // ignore: deprecated_member_use
    await Share.shareXFiles([
      XFile(file.path),
    ], text: '근태 기록 ${month.year}년 ${month.month}월');
    return true;
  } catch (_) {
    return false;
  }
}
