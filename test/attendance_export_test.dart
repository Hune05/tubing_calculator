// 월 근태 내보내기(CSV·PDF) 시험. 숫자는 화면과 같은 계산(attendance_calc.dart)에서 나온다.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/attendance/attendance_calc.dart';
import 'package:tubing_calculator/src/presentation/attendance/attendance_export.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/attendance.dart';

Map<String, AttendanceRecord> _recs() {
  final l = [
    AttendanceRecord(
      date: DateTime(2026, 9, 22),
      checkIn: '07:00',
      checkOut: '20:00',
      memo: '태안, 3호기', // 쉼표가 있어 따옴표로 감싸야 한다
    ),
    AttendanceRecord(date: DateTime(2026, 9, 23), type: '연차'),
    AttendanceRecord(
      date: DateTime(2026, 9, 27),
      type: '특근',
      checkIn: '08:00',
      checkOut: '19:00',
    ),
  ];
  return {for (final r in l) dateKey(r.date): r};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('CSV: BOM, 머리줄, 날마다 한 줄, 합계 줄', () {
    final csv = attendanceMonthCsv(
      month: DateTime(2026, 9),
      records: _recs(),
      options: const AttendanceCalcOptions(),
    );
    expect(csv.startsWith('﻿'), isTrue);
    final lines = csv.substring(1).trim().split('\r\n');
    expect(lines.first.split(',').first, '날짜');
    expect(lines.length, 1 + 30 + 1); // 머리 + 9월 30일 + 합계
    final d22 = lines.firstWhere((l) => l.startsWith('2026-09-22'));
    expect(d22, contains('07:00,20:00,60,12,4,0,0,0,"태안, 3호기"'));
    final d23 = lines.firstWhere((l) => l.startsWith('2026-09-23'));
    expect(d23, contains(',연차,'));
    final d25 = lines.firstWhere((l) => l.startsWith('2026-09-25'));
    expect(d25, contains(',추석,'));
    final d27 = lines.firstWhere((l) => l.startsWith('2026-09-27'));
    expect(d27, contains('08:00,19:00,60,10,0,0,10,2,'));
    // 합계: 근로 22, 연장 4, 휴일 10, 8시간 초과 2, 가산 = (4+10+2)×0.5 = 8
    expect(lines.last, startsWith('합계,,,연차 사용 1일,,,,22,4,0,10,2,가산 시간 8'));
  });

  test('PDF: 한 장이 만들어진다', () async {
    final bytes = await buildAttendanceMonthPdf(
      month: DateTime(2026, 9),
      records: _recs(),
      options: const AttendanceCalcOptions(),
      leave: computeLeaveBalance(
        hire: DateTime(2025, 3, 2),
        today: DateTime(2026, 9, 26),
        types: const {'2026-09-23': '연차'},
      ),
      now: DateTime(2026, 9, 26),
    );
    expect(latin1.decode(bytes.sublist(0, 4)), '%PDF');
    expect(bytes.length, greaterThan(1000));
  });

  test('파일 이름', () {
    expect(attendanceFileBase(DateTime(2026, 9)), 'attendance_202609');
  });
}
