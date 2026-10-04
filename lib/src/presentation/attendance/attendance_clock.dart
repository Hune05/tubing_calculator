// 출근·퇴근 단추의 판단: 지금 시각으로 바로 저장하는 기록을 만들고, 단추가 보일 상태를 가린다.
//
// - 출근: 현재 시각(분 단위)으로 그 날 기록의 출근 시각을 채운다. 종류·휴게·메모는 있던 그대로.
// - 퇴근: 현재 시각으로 퇴근을 채운다. 출근과 같은 분이면 계산이 안 되므로 만들지 않는다(null).
// - 밤샘: 어제 오후에 출근하고 퇴근을 안 찍은 채 16시간 안이면 어제 기록에 퇴근을 찍는다.
// - 퇴근을 안 찍은 지난 날은 "퇴근 입력 필요"로 알려 준다(계산에는 들어가지 않는다).
// 계산(연장·야간 등)은 attendance_calc.dart가 그대로 한다. 여기는 시각만 채운다.
library;

import '../my_work_logs/models/attendance.dart';

/// 밤샘 근무로 보는 최대 시간(출근 뒤 이 시간 안이면 어제 기록에 퇴근을 찍는다).
const int kMaxOvernightMinutes = 16 * 60;

/// "HH:mm"(분 단위로 자른다).
String clockText(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

enum ClockPhase {
  /// 아직 출근 전: [출근] 단추.
  ready,

  /// 출근했고 퇴근은 안 찍음: [퇴근] 단추.
  working,

  /// 출근·퇴근 둘 다 있음: 고치기만.
  done,

  /// 연차·월차·결근 등 일을 안 하는 날: 단추 없음.
  off,
}

/// 단추 칸이 보여 줄 상태. [day]는 이 상태가 가리키는 기록의 날짜(밤샘이면 어제).
class ClockStatus {
  final ClockPhase phase;
  final DateTime day;
  final AttendanceRecord? record;

  /// 근무 중일 때 출근 뒤 지난 분(아니면 null).
  final int? elapsedMin;

  const ClockStatus(this.phase, this.day, this.record, [this.elapsedMin]);
}

bool _open(AttendanceRecord? r) =>
    r != null &&
    !hasNoWorkTime(r.type) &&
    minutesOfDay(r.checkIn) != null &&
    r.checkOut == null;

/// [now] 때 단추가 볼 상태. [today]·[yesterday]는 오늘·어제 기록(없으면 null).
ClockStatus clockStatus({
  required DateTime now,
  AttendanceRecord? today,
  AttendanceRecord? yesterday,
}) {
  final d = _day(now);
  final y = DateTime(d.year, d.month, d.day - 1);
  if (_open(yesterday)) {
    final m = minutesOfDay(yesterday!.checkIn)!;
    final start = DateTime(y.year, y.month, y.day, m ~/ 60, m % 60);
    final elapsed = now.difference(start).inMinutes;
    // 오후 3시 이후에 출근해 밤샘 중인 경우만(낮에 출근하고 퇴근을 잊은 어제는 오늘 출근으로 넘어간다).
    if (m >= 15 * 60 && elapsed >= 0 && elapsed <= kMaxOvernightMinutes) {
      return ClockStatus(ClockPhase.working, y, yesterday, elapsed);
    }
  }
  if (today != null && hasNoWorkTime(today.type)) {
    return ClockStatus(ClockPhase.off, d, today);
  }
  final inM = minutesOfDay(today?.checkIn);
  if (today == null || inM == null) {
    return ClockStatus(ClockPhase.ready, d, today);
  }
  if (today.checkOut == null) {
    final start = DateTime(d.year, d.month, d.day, inM ~/ 60, inM % 60);
    final elapsed = now.difference(start).inMinutes;
    return ClockStatus(ClockPhase.working, d, today, elapsed < 0 ? 0 : elapsed);
  }
  return ClockStatus(ClockPhase.done, d, today);
}

/// 출근을 현재 시각으로 찍은 기록. [existing]이 있으면 종류·휴게·메모를 그대로 둔다.
AttendanceRecord punchIn(
  DateTime day,
  AttendanceRecord? existing,
  DateTime now,
) => AttendanceRecord(
  date: _day(day),
  type: existing?.type ?? kAttendanceNormal,
  checkIn: clockText(now),
  checkOut: existing?.checkOut,
  breakMin: existing?.breakMin,
  memo: existing?.memo,
);

/// 퇴근을 현재 시각으로 찍은 기록. 출근과 같은 분이면 null(근무 시간이 0이라 계산이 안 된다).
AttendanceRecord? punchOut(AttendanceRecord existing, DateTime now) {
  final out = clockText(now);
  if (stayMinutesOf(existing.checkIn, out) == null) return null;
  return AttendanceRecord(
    date: existing.date,
    type: existing.type,
    checkIn: existing.checkIn,
    checkOut: out,
    breakMin: existing.breakMin,
    memo: existing.memo,
  );
}

/// 지난 날인데 출근만 있고 퇴근이 없는 기록(퇴근 입력 필요). 일을 안 한 날은 해당 없음.
bool isMissingCheckOut(AttendanceRecord? r, DateTime today) {
  if (!_open(r)) return false;
  return _day(r!.date).isBefore(_day(today));
}

/// [records] 안에서 [from]~[to] 사이 퇴근이 빠진 날 수. [skip]은 지금 근무 중이라 빼는 날(밤샘).
int missingCheckOutCount(
  Map<String, AttendanceRecord> records,
  DateTime today, {
  DateTime? skip,
}) {
  var n = 0;
  for (final r in records.values) {
    if (skip != null && _day(r.date) == _day(skip)) continue;
    if (isMissingCheckOut(r, today)) n++;
  }
  return n;
}
