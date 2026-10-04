// 연간 근태 합계: 한 해를 달마다 나눠 계산한다(화면: widgets/attendance_year_page.dart).
// 달 계산은 summarizeMonth를 그대로 쓴다. 주 40시간·52시간이 달 경계를 넘으므로 해 전체 기록을 한 번에 넘긴다.
library;

import '../my_work_logs/models/attendance.dart';
import 'attendance_calc.dart';

class YearSummary {
  final int year;
  final List<MonthSummary> months; // 1~12월
  final int work;
  final int overtime;
  final int night;
  final int holiday;
  final int holidayOver8;
  final double leaveUsed;
  final int weeksOver52;
  const YearSummary({
    required this.year,
    required this.months,
    required this.work,
    required this.overtime,
    required this.night,
    required this.holiday,
    required this.holidayOver8,
    required this.leaveUsed,
    required this.weeksOver52,
  });
}

/// [records]는 해 전체(1월 첫 주 월요일~12월 마지막 주 일요일) 기록. [year]년의 달별 합계와 연 합계.
YearSummary summarizeYear(
  Map<String, AttendanceRecord> records,
  int year,
  AttendanceCalcOptions o,
) {
  final months = <MonthSummary>[
    for (var m = 1; m <= 12; m++) summarizeMonth(records, DateTime(year, m), o),
  ];
  var work = 0, over = 0, night = 0, hol = 0, hol8 = 0;
  var leave = 0.0;
  for (final s in months) {
    work += s.work;
    over += s.overtime;
    night += s.night;
    hol += s.holiday;
    hol8 += s.holidayOver8;
    leave += s.leaveUsed;
  }
  // 주 52시간 초과 주: 해 전체를 한 번 훑어 센다(달마다 세면 두 달에 걸친 주를 두 번 센다).
  final r = computeRange(
    records,
    DateTime(year, 1, 1),
    DateTime(year, 12, 31),
    o,
  );
  final over52 = r.weeks
      .where((w) => w.over52 && _weekTouchesYear(w.monday, year))
      .length;
  return YearSummary(
    year: year,
    months: months,
    work: work,
    overtime: over,
    night: night,
    holiday: hol,
    holidayOver8: hol8,
    leaveUsed: leave,
    weeksOver52: over52,
  );
}

bool _weekTouchesYear(DateTime monday, int year) {
  final sunday = DateTime(monday.year, monday.month, monday.day + 6);
  return monday.year == year || sunday.year == year;
}

/// 해 전체를 읽을 범위: 1월 1일이 속한 주 월요일 ~ 12월 31일이 속한 주 일요일.
({DateTime from, DateTime to}) yearRange(int year) {
  final first = DateTime(year, 1, 1);
  final last = DateTime(year, 12, 31);
  return (
    from: mondayOf(first),
    to: DateTime(last.year, last.month, last.day + (7 - last.weekday)),
  );
}

/// 시간 표 칸용: 0이면 "-", 아니면 소수 한 자리 시간("160.5", "8").
String shortHours(num minutes) {
  if (minutes <= 0) return '-';
  final h = minutes / 60;
  final s = h.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}
