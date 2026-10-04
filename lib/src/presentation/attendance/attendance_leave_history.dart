// 연차 사용 내역: 이번 연차 기간에 쓴(또는 쓰려고 적어 둔) 날을 날짜 순으로 모은다.
// 일수는 attendance.dart의 leaveDaysOf(연차·월차 1, 반차 0.5, 반반차 0.25)를 그대로 쓴다.
library;

import '../my_work_logs/models/attendance.dart';

class LeaveEntry {
  final DateTime date;
  final String type;
  final double days;

  /// 오늘 뒤에 적어 둔 날(아직 안 쓴 예정).
  final bool planned;

  /// 이 줄까지 쓴(예정 포함) 누계 일수.
  final double usedAfter;
  const LeaveEntry({
    required this.date,
    required this.type,
    required this.days,
    required this.planned,
    required this.usedAfter,
  });
}

/// [periodStart] 이상 [periodEnd] 미만의 연차 사용 줄. [types]는 날짜 키(yyyy-MM-dd) → 근태 종류.
List<LeaveEntry> leaveHistory({
  required Map<String, String> types,
  required DateTime periodStart,
  required DateTime periodEnd,
  required DateTime today,
}) {
  final t = DateTime(today.year, today.month, today.day);
  final list = <MapEntry<DateTime, String>>[];
  for (final e in types.entries) {
    final d = DateTime.tryParse(e.key);
    if (d == null || d.isBefore(periodStart) || !d.isBefore(periodEnd)) {
      continue;
    }
    if (leaveDaysOf(e.value) == 0) continue;
    list.add(MapEntry(DateTime(d.year, d.month, d.day), e.value));
  }
  list.sort((a, b) => a.key.compareTo(b.key));
  final out = <LeaveEntry>[];
  var sum = 0.0;
  for (final e in list) {
    final days = leaveDaysOf(e.value);
    sum += days;
    out.add(
      LeaveEntry(
        date: e.key,
        type: e.value,
        days: days,
        planned: e.key.isAfter(t),
        usedAfter: sum,
      ),
    );
  }
  return out;
}

/// 오늘부터 연차 기간이 끝나는 날(마지막 날)까지 남은 일수(오늘 포함 안 함). 이미 지났으면 0.
int daysUntilPeriodEnd(DateTime periodEnd, DateTime today) {
  final last = DateTime(periodEnd.year, periodEnd.month, periodEnd.day - 1);
  final t = DateTime(today.year, today.month, today.day);
  final d = last.difference(t).inDays;
  return d < 0 ? 0 : d;
}
