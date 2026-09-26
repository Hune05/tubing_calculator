// 근태 계산(근로기준법 제50·53·54·56·60조). 근거와 가정은 docs/근태관리_근거.md 6절.
//
// - 휴게(제54조): 기본은 법정 최소. 날마다 기록의 breakMin으로 바꿀 수 있다.
// - 연장·야간·휴일(제56조): 휴일 = 일요일 + 관공서 공휴일 표(+ 설정하면 토요일).
//   연장 = 하루 8시간 초과(휴일 부분 제외) + 1주(월~일) 40시간 초과. 두 번 세지 않는다.
// - 주 52시간(제53조): 한 주 연장이 12시간을 넘는지.
// - 연차(제60조): 입사일 기준.
// 화면·PDF·CSV가 모두 이 파일의 값을 쓴다(같은 날 다른 숫자가 나오지 않게).
library;

import 'dart:math' as math;

import '../my_schedule/korean_holidays.dart';
import '../my_work_logs/models/attendance.dart';

/// 요일 이름(월요일 = 0).
const List<String> kWeekdayKo = ['월', '화', '수', '목', '금', '토', '일'];

/// 기본 휴게 설정 값: 법정 최소 자동.
const int kBreakLegalAuto = -1;

/// 법정 최소 휴게(분). [stayMin]은 출근~퇴근 사이 분.
/// 근로시간(휴게 뺀 시간)이 4시간이면 30분, 8시간이면 1시간을 만족하는 가장 작은 값:
/// 4시간 미만 0분, 8시간 30분 미만 30분, 그 이상 1시간.
int legalBreakMinutes(int stayMin) {
  if (stayMin >= 510) return 60;
  if (stayMin >= 240) return 30;
  return 0;
}

/// 계산 설정(근태 설정 화면에서 고른다).
class AttendanceCalcOptions {
  /// 기본 휴게(분). [kBreakLegalAuto]면 법정 최소, 0이면 없음, 60이면 1시간 고정.
  final int defaultBreak;

  /// 토요일 근무를 휴일근로로 계산할지(회사가 토요일을 휴일로 정한 경우).
  final bool saturdayIsHoliday;

  const AttendanceCalcOptions({
    this.defaultBreak = kBreakLegalAuto,
    this.saturdayIsHoliday = false,
  });
}

/// 휴일근로로 보는 날: 일요일, 관공서 공휴일, (설정하면) 토요일.
bool isRestDay(DateTime d, AttendanceCalcOptions o) =>
    d.weekday == DateTime.sunday ||
    isKoreanHoliday(d) ||
    (o.saturdayIsHoliday && d.weekday == DateTime.saturday);

/// 그 날 기록에 적용할 휴게(분).
int breakMinutesFor(AttendanceRecord r, int stayMin, AttendanceCalcOptions o) {
  final b =
      r.breakMin ??
      (o.defaultBreak == kBreakLegalAuto
          ? legalBreakMinutes(stayMin)
          : o.defaultBreak);
  return b.clamp(0, stayMin);
}

/// 하루(근무 한 번) 계산 결과. 모두 분.
class DayWork {
  final int stay; // 출근~퇴근
  final int breakMin;
  final int work; // 근로시간 = stay − breakMin
  final int night; // 22:00~06:00
  final int holiday; // 휴일과 겹친 근로
  final int dailyOver; // 평일 부분 8시간 초과
  const DayWork({
    required this.stay,
    required this.breakMin,
    required this.work,
    required this.night,
    required this.holiday,
    required this.dailyOver,
  });

  int get nonHoliday => work - holiday;
  int get holidayOver8 => math.max(0, holiday - 480);
}

int _overlap(int a0, int a1, int b0, int b1) =>
    math.max(0, math.min(a1, b1) - math.max(a0, b0));

/// 하루 기록을 계산한다. 일을 안 한 날(연차·월차·결근)이나 출퇴근 시간이 없으면 null.
DayWork? computeDay(AttendanceRecord r, AttendanceCalcOptions o) {
  if (hasNoWorkTime(r.type)) return null;
  final start = minutesOfDay(r.checkIn);
  final stay = stayMinutesOf(r.checkIn, r.checkOut);
  if (start == null || stay == null) return null;
  final end = start + stay; // 출근한 날 0시부터 분(자정 넘기면 1440 이상)
  final brk = breakMinutesFor(r, stay, o);
  final work = stay - brk;

  // 22:00~06:00: 출근한 날 0~6시, 22~30시(다음 날 6시), 46~48시.
  final nightRaw =
      _overlap(start, end, 0, 360) +
      _overlap(start, end, 1320, 1800) +
      _overlap(start, end, 2760, 2880);
  final day = DateTime(r.date.year, r.date.month, r.date.day);
  final next = DateTime(day.year, day.month, day.day + 1);
  final holidayRaw =
      (isRestDay(day, o) ? _overlap(start, end, 0, 1440) : 0) +
      (isRestDay(next, o) ? _overlap(start, end, 1440, 2880) : 0);
  // 휴게는 낮·평일 부분에서 먼저 뺀다고 본다.
  final night = math.min(nightRaw, work);
  final holiday = math.min(holidayRaw, work);
  final dailyOver = math.max(0, (work - holiday) - 480);
  return DayWork(
    stay: stay,
    breakMin: brk,
    work: work,
    night: night,
    holiday: holiday,
    dailyOver: dailyOver,
  );
}

/// 날짜 하나의 결과(주 40시간 초과분을 그 날에 붙인 것 포함).
class DayResult {
  final DateTime date;
  final AttendanceRecord? record;
  final DayWork? work;

  /// 1주 40시간을 넘긴 날에 붙는 연장(분). 하루 8시간 초과분과 겹치지 않는다.
  final int weeklyOver;
  const DayResult(this.date, this.record, this.work, this.weeklyOver);

  int get overtime => (work?.dailyOver ?? 0) + weeklyOver;
}

/// 한 주(월~일) 합계.
class WeekResult {
  final DateTime monday;
  final int work; // 휴일 포함 근로 합
  final int overtime; // 가산 대상 연장(평일 부분)
  final int limitOver; // 제53조 한도 판단용 연장(휴일 포함)
  const WeekResult(this.monday, this.work, this.overtime, this.limitOver);

  /// 연장 12시간(주 52시간) 초과.
  bool get over52 => limitOver > 720;
}

DateTime mondayOf(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  return DateTime(day.year, day.month, day.day - (day.weekday - 1));
}

/// 기간 계산. [records]는 날짜 키(yyyy-MM-dd) → 기록. [from]이 속한 주 월요일부터
/// [to]가 속한 주 일요일까지 날마다 결과를 만든다(주 40시간을 정확히 세려고).
({List<DayResult> days, List<WeekResult> weeks}) computeRange(
  Map<String, AttendanceRecord> records,
  DateTime from,
  DateTime to,
  AttendanceCalcOptions o,
) {
  final start = mondayOf(from);
  final last = DateTime(to.year, to.month, to.day);
  final end = DateTime(last.year, last.month, last.day + (7 - last.weekday));
  final days = <DayResult>[];
  final weeks = <WeekResult>[];
  var weekBase = 0; // 이번 주 min(평일 근로, 8시간) 합
  var weekWork = 0;
  var weekOver = 0;
  var weekDailyAll = 0; // 휴일 포함 하루 8시간 초과 합
  for (
    var d = start;
    !d.isAfter(end);
    d = DateTime(d.year, d.month, d.day + 1)
  ) {
    if (d.weekday == DateTime.monday) {
      weekBase = 0;
      weekWork = 0;
      weekOver = 0;
      weekDailyAll = 0;
    }
    final rec = records[dateKey(d)];
    final w = rec == null ? null : computeDay(rec, o);
    var weekly = 0;
    if (w != null) {
      final base = math.min(w.nonHoliday, 480);
      final before = weekBase;
      weekBase += base;
      weekly = math.max(0, weekBase - 2400) - math.max(0, before - 2400);
      weekWork += w.work;
      weekOver += w.dailyOver + weekly;
      weekDailyAll += math.max(0, w.work - 480);
    }
    days.add(DayResult(d, rec, w, weekly));
    if (d.weekday == DateTime.sunday) {
      weeks.add(
        WeekResult(
          DateTime(d.year, d.month, d.day - 6),
          weekWork,
          weekOver,
          math.max(weekWork - 2400, weekDailyAll),
        ),
      );
    }
  }
  return (days: days, weeks: weeks);
}

/// 한 달 합계.
class MonthSummary {
  final int timedDays; // 출퇴근 시간을 적어 계산한 날
  final int work;
  final int overtime;
  final int night;
  final int holiday;
  final int holidayOver8;
  final double leaveUsed; // 연차에서 빠지는 일수
  final Map<String, int> typeCounts; // 정상근무 빼고 종류별 횟수
  final List<WeekResult> weeks; // 이 달과 겹치는 주
  const MonthSummary({
    required this.timedDays,
    required this.work,
    required this.overtime,
    required this.night,
    required this.holiday,
    required this.holidayOver8,
    required this.leaveUsed,
    required this.typeCounts,
    required this.weeks,
  });

  /// 가산 시간(분): 연장·야간·휴일 50%, 휴일 8시간 초과분은 50% 더(합쳐 100%).
  double get premiumMinutes =>
      (overtime + night + holiday + holidayOver8) * 0.5;

  List<WeekResult> get weeksOver52 => weeks.where((w) => w.over52).toList();
}

/// [month] 한 달 요약. [records]에는 이 달 첫 주 월요일~마지막 주 일요일 기록이 있으면
/// 주 40시간·52시간이 정확하다(없는 날은 기록 없음으로 본다).
MonthSummary summarizeMonth(
  Map<String, AttendanceRecord> records,
  DateTime month,
  AttendanceCalcOptions o,
) {
  final first = DateTime(month.year, month.month, 1);
  final lastDay = DateTime(month.year, month.month + 1, 0);
  final r = computeRange(records, first, lastDay, o);
  var timed = 0, work = 0, over = 0, night = 0, hol = 0, hol8 = 0;
  var leave = 0.0;
  final counts = <String, int>{};
  for (final d in r.days) {
    if (d.date.month != month.month || d.date.year != month.year) continue;
    final rec = d.record;
    if (rec != null) {
      leave += leaveDaysOf(rec.type);
      if (rec.type != kAttendanceNormal) {
        counts[rec.type] = (counts[rec.type] ?? 0) + 1;
      }
    }
    final w = d.work;
    if (w == null) continue;
    timed++;
    work += w.work;
    over += d.overtime;
    night += w.night;
    hol += w.holiday;
    hol8 += w.holidayOver8;
  }
  return MonthSummary(
    timedDays: timed,
    work: work,
    overtime: over,
    night: night,
    holiday: hol,
    holidayOver8: hol8,
    leaveUsed: leave,
    typeCounts: counts,
    weeks: r.weeks,
  );
}

/// 분 → "8시간", "8시간 30분", "30분", "0시간".
String formatMinutes(num minutes) {
  final m = minutes.round();
  final h = m ~/ 60;
  final r = m % 60;
  if (r == 0) return '$h시간';
  if (h == 0) return '$r분';
  return '$h시간 $r분';
}

/// 분 → 소수 시간 "8.5"(CSV용, 소수 둘째 자리까지, 끝의 0은 뺀다).
String decimalHours(num minutes) {
  final s = (minutes / 60).toStringAsFixed(2);
  return s.replaceFirst(RegExp(r'\.?0+$'), '');
}

/// 연차 일수 표시: 15 → "15", 11.5 → "11.5", 0.25 → "0.25".
String formatLeaveDays(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}

// ───────────── 연차 (제60조, 입사일 기준) ─────────────

/// [d]에서 [months]달 뒤 같은 날(그 달에 그 날이 없으면 말일).
DateTime addMonthsClamped(DateTime d, int months) {
  final y = d.year + ((d.month - 1 + months) ~/ 12);
  final m = (d.month - 1 + months) % 12 + 1;
  final last = DateTime(y, m + 1, 0).day;
  return DateTime(y, m, math.min(d.day, last));
}

/// 소정근로일(월~금, 공휴일 아님) 수: [from] 포함, [to] 제외.
int scheduledWorkDays(DateTime from, DateTime to) {
  var n = 0;
  for (var d = from; d.isBefore(to); d = DateTime(d.year, d.month, d.day + 1)) {
    if (d.weekday <= DateTime.friday && !isKoreanHoliday(d)) n++;
  }
  return n;
}

bool _hasAbsence(Map<String, String> types, DateTime from, DateTime to) {
  for (final e in types.entries) {
    if (e.value != kAttendanceAbsent) continue;
    final d = DateTime.tryParse(e.key);
    if (d == null) continue;
    if (!d.isBefore(from) && d.isBefore(to)) return true;
  }
  return false;
}

int _absences(Map<String, String> types, DateTime from, DateTime to) {
  var n = 0;
  for (final e in types.entries) {
    if (e.value != kAttendanceAbsent) continue;
    final d = DateTime.tryParse(e.key);
    if (d == null) continue;
    if (!d.isBefore(from) && d.isBefore(to)) n++;
  }
  return n;
}

/// [from]부터 한 달씩 끊어 [until] 전에 끝난 달 중 결근이 없는 달 수.
int _perfectMonths(
  Map<String, String> types,
  DateTime from,
  DateTime until, {
  int max = 11,
}) {
  var n = 0;
  for (var k = 1; k <= 12; k++) {
    final a = addMonthsClamped(from, k - 1);
    final b = addMonthsClamped(from, k);
    if (b.isAfter(until)) break;
    if (!_hasAbsence(types, a, b)) n++;
  }
  return math.min(n, max);
}

/// 근속연수 [years](1 이상)에 대한 법정 연차: 15 + (years − 1) ~/ 2, 최대 25.
int annualLeaveForYears(int years) =>
    math.min(25, 15 + math.max(0, years - 1) ~/ 2);

class LeaveBalance {
  final DateTime periodStart; // 이번 연차 기간 시작(입사일 또는 입사 기념일)
  final DateTime periodEnd; // 다음 기념일(이 날 전까지)
  final int years; // 다 채운 근속연수(0이면 1년 미만)
  final double lawGranted; // 법 기준 발생 일수
  final double? overrideGranted; // 직접 넣은 부여 일수
  final double used; // 오늘까지 쓴 것
  final double planned; // 오늘 뒤에 적어 둔 것
  final String basis; // 근거 한 줄
  final DateTime? nextAccrual; // 1년 미만: 다음 1일이 생기는 날
  final double? attendanceRate; // 1년 이상: 지난 1년 출근율(0~1)
  const LeaveBalance({
    required this.periodStart,
    required this.periodEnd,
    required this.years,
    required this.lawGranted,
    required this.overrideGranted,
    required this.used,
    required this.planned,
    required this.basis,
    this.nextAccrual,
    this.attendanceRate,
  });

  double get granted => overrideGranted ?? lawGranted;
  double get remaining => granted - used - planned;
}

/// 입사일 [hire] 기준 오늘 [today]의 연차 잔여. [types]는 날짜 키 → 근태 종류
/// (AttendanceCache.byDate). 입사 전이면 null.
LeaveBalance? computeLeaveBalance({
  required DateTime hire,
  required DateTime today,
  required Map<String, String> types,
  Map<String, double> overrides = const {},
}) {
  final h = DateTime(hire.year, hire.month, hire.day);
  final t = DateTime(today.year, today.month, today.day);
  if (t.isBefore(h)) return null;
  var years = 0;
  while (!addMonthsClamped(h, 12 * (years + 1)).isAfter(t)) {
    years++;
  }
  final ps = addMonthsClamped(h, 12 * years);
  final pe = addMonthsClamped(h, 12 * (years + 1));

  double lawGranted;
  String basis;
  DateTime? next;
  double? rate;
  if (years == 0) {
    // k번째 달 [a, b)을 개근하면 b(다음 달 같은 날)에 1일이 생긴다.
    lawGranted = _perfectMonths(types, h, t).toDouble();
    basis = '입사 1년 미만: 결근 없는 달마다 1일, 최대 11일(제60조 제2항)';
    for (var k = 1; k <= 11; k++) {
      final b = addMonthsClamped(h, k);
      if (b.isAfter(t)) {
        next = b;
        break;
      }
    }
  } else {
    final prevStart = addMonthsClamped(h, 12 * (years - 1));
    final sched = scheduledWorkDays(prevStart, ps);
    final absent = _absences(types, prevStart, ps);
    rate = sched == 0 ? 1.0 : (sched - absent) / sched;
    if (rate >= 0.8) {
      lawGranted = annualLeaveForYears(years).toDouble();
      basis = years >= 3
          ? '근속 $years년: 15일 + 2년마다 1일, 최대 25일(제60조 제1·4항)'
          : '근속 $years년, 출근율 80% 이상: 15일(제60조 제1항)';
    } else {
      lawGranted = _perfectMonths(types, prevStart, ps, max: 12).toDouble();
      basis = '지난 1년 출근율 80% 미만: 개근한 달마다 1일(제60조 제2항)';
    }
  }

  var used = 0.0, planned = 0.0;
  for (final e in types.entries) {
    final d = DateTime.tryParse(e.key);
    if (d == null || d.isBefore(ps) || !d.isBefore(pe)) continue;
    final v = leaveDaysOf(e.value);
    if (v == 0) continue;
    if (d.isAfter(t)) {
      planned += v;
    } else {
      used += v;
    }
  }
  return LeaveBalance(
    periodStart: ps,
    periodEnd: pe,
    years: years,
    lawGranted: lawGranted,
    overrideGranted: overrides[dateKey(ps)],
    used: used,
    planned: planned,
    basis: basis,
    nextAccrual: next,
    attendanceRate: rate,
  );
}
