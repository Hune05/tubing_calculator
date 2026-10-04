// 여러 날을 한 번에 기록: 날짜 범위·건너뛸 날 계산, 전에 적은 기록 찾기.
//
// 화면(attendance_range_sheet.dart)은 값만 고르고, 어느 날에 무엇을 저장할지는 여기서 정한다.
// 쉬는 날(토·일·공휴일) 건너뛰기, 이미 기록이 있는 날 지키기(덮어쓰기를 켠 때만 바꾼다)를 시험으로 지킨다.
library;

import '../my_schedule/korean_holidays.dart';
import '../my_work_logs/models/attendance.dart';

/// 한 번에 기록할 수 있는 최대 날짜 수(실수로 몇 해치를 채우지 않게).
const int kBulkMaxDays = 62;

/// 토·일·공휴일. 연차를 연달아 쓸 때 이런 날은 보통 빼므로 건너뛰기 기본값으로 쓴다.
bool isOffDay(DateTime d) =>
    d.weekday >= DateTime.saturday || isKoreanHoliday(d);

/// 한 번에 기록할 계획: 저장할 날과 건너뛴 날.
class BulkPlan {
  final List<DateTime> days; // 저장할 날
  final List<DateTime> skippedOff; // 쉬는 날이라 뺀 날
  final List<DateTime> skippedExisting; // 이미 기록이 있어 뺀 날
  final bool tooLong;
  final bool invalid; // 끝날이 시작날보다 앞

  const BulkPlan({
    this.days = const [],
    this.skippedOff = const [],
    this.skippedExisting = const [],
    this.tooLong = false,
    this.invalid = false,
  });
}

/// [from]~[to](둘 다 포함)에서 저장할 날을 가린다.
/// [existingKeys]는 이미 기록이 있는 날짜 키(yyyy-MM-dd). [overwrite]가 거짓이면 그 날은 건너뛴다.
BulkPlan planBulk({
  required DateTime from,
  required DateTime to,
  required bool skipOff,
  required bool overwrite,
  Set<String> existingKeys = const {},
}) {
  final a = DateTime(from.year, from.month, from.day);
  final b = DateTime(to.year, to.month, to.day);
  if (b.isBefore(a)) return const BulkPlan(invalid: true);
  if (b.difference(a).inDays + 1 > kBulkMaxDays) {
    return const BulkPlan(tooLong: true);
  }
  final days = <DateTime>[];
  final off = <DateTime>[];
  final existing = <DateTime>[];
  for (var d = a; !d.isAfter(b); d = DateTime(d.year, d.month, d.day + 1)) {
    if (skipOff && isOffDay(d)) {
      off.add(d);
    } else if (!overwrite && existingKeys.contains(dateKey(d))) {
      existing.add(d);
    } else {
      days.add(d);
    }
  }
  return BulkPlan(days: days, skippedOff: off, skippedExisting: existing);
}

/// 모양([template])을 [day]에 입힌 기록. 일을 안 하는 종류(연차·월차·결근)는 시간·휴게를 뺀다.
AttendanceRecord bulkRecord(DateTime day, AttendanceRecord template) {
  final noTime = hasNoWorkTime(template.type);
  return AttendanceRecord(
    date: DateTime(day.year, day.month, day.day),
    type: template.type,
    checkIn: noTime ? null : template.checkIn,
    checkOut: noTime ? null : template.checkOut,
    breakMin: noTime ? null : template.breakMin,
    memo: template.memo,
  );
}

/// [day] 앞쪽에서 가장 가까운 기록(최대 [maxBack]일 전까지). "전에 적은 날과 같게"에 쓴다.
/// 시간·종류가 하나도 없는 빈 기록은 건너뛴다.
AttendanceRecord? latestRecordBefore(
  Map<String, AttendanceRecord> records,
  DateTime day, {
  int maxBack = 10,
}) {
  for (var i = 1; i <= maxBack; i++) {
    final d = DateTime(day.year, day.month, day.day - i);
    final r = records[dateKey(d)];
    if (r == null) continue;
    final hasTime = r.checkIn != null || r.checkOut != null;
    if (hasTime || r.type != kAttendanceNormal) return r;
  }
  return null;
}
