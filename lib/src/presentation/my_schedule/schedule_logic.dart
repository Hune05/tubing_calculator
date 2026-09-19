// 🚀 내 일정 관리의 순수한 계산(반복 일정 날짜, 알림 시간, 겹침, 오늘 요약).
// 화면 코드와 떼어 놓아서 test/my_schedule_logic_test.dart 가 규칙을 지킨다.

/// 달의 마지막 날(예: 2월이면 28 또는 29).
int _lastDayOfMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// [base]의 n달 뒤 같은 날. 그 달에 그 날이 없으면(31일 등) 그 달의 마지막 날로 맞춘다.
/// 시각(시·분)은 그대로 둔다.
DateTime addMonthsClamped(DateTime base, int months) {
  final total = base.month - 1 + months;
  final year = base.year + total ~/ 12;
  final month = total % 12 + 1;
  final day = base.day > _lastDayOfMonth(year, month)
      ? _lastDayOfMonth(year, month)
      : base.day;
  return DateTime(year, month, day, base.hour, base.minute);
}

/// 반복 일정([recurrence]: 'weekly' / 'monthly' / 그 외는 반복 없음)의 회차 날짜들.
/// [rangeStart]~[rangeEnd] 안에 있는 회차만 돌려주고, 반복이 없으면 [base] 하나만 돌려준다.
/// 매달 반복은 31일처럼 없는 날짜를 그 달의 마지막 날로 맞춘다.
List<DateTime> recurrenceDates(
  DateTime base,
  String recurrence, {
  required DateTime rangeStart,
  required DateTime rangeEnd,
  int maxCount = 400,
}) {
  if (recurrence != 'weekly' && recurrence != 'monthly') return [base];
  final out = <DateTime>[];
  for (var n = 0; n < maxCount; n++) {
    final d = recurrence == 'weekly'
        ? base.add(Duration(days: 7 * n))
        : addMonthsClamped(base, n);
    if (d.isAfter(rangeEnd)) break;
    if (!d.isBefore(rangeStart)) out.add(d);
  }
  return out;
}

/// [day](날짜만 본다)에 반복 일정이 걸리는지. 반복 일정은 시작일 이후부터 센다.
bool recurrenceOccursOn(DateTime base, String recurrence, DateTime day) {
  final d = DateTime(day.year, day.month, day.day);
  final b = DateTime(base.year, base.month, base.day);
  if (d.isBefore(b)) return false;
  if (recurrence == 'weekly') return d.weekday == b.weekday;
  if (recurrence == 'monthly') {
    final want = b.day > _lastDayOfMonth(d.year, d.month)
        ? _lastDayOfMonth(d.year, d.month)
        : b.day;
    return d.day == want;
  }
  return d == b;
}

/// 일정 알림을 울릴 시각. 알림이 필요 없으면 null.
/// - [minutesBefore]가 0 이하이거나 시간이 없는 일정(종일)이면 알림 없음.
/// - 반복 일정은 지금 이후의 가장 가까운 회차 기준으로 맞춘다.
/// - 반복이 없는데 이미 지난 시각이면 알림 없음.
DateTime? reminderTime({
  required DateTime base,
  required int minutesBefore,
  required String recurrence,
  required bool hasTime,
  required DateTime now,
}) {
  if (minutesBefore <= 0 || !hasTime) return null;
  final remind = base.subtract(Duration(minutes: minutesBefore));
  if (recurrence != 'weekly' && recurrence != 'monthly') {
    return remind.isBefore(now) ? null : remind;
  }
  for (var n = 0; n < 1200; n++) {
    final at = recurrence == 'weekly'
        ? remind.add(Duration(days: 7 * n))
        : addMonthsClamped(remind, n);
    if (!at.isBefore(now)) return at;
  }
  return null;
}

/// 겹침·요약 계산에 필요한 최소한의 일정 정보.
class LiteAgenda {
  final String key;
  final DateTime date;
  final bool hasTime;
  final String title;
  final bool isCompleted;
  const LiteAgenda({
    required this.key,
    required this.date,
    required this.hasTime,
    required this.title,
    required this.isCompleted,
  });
}

/// 같은 날 시작 시간이 [windowMinutes]분 안쪽으로 가까운, 아직 안 끝난 일정들의 key.
/// (종일 일정과 완료한 일정은 겹침으로 보지 않는다.)
Set<String> overlappingKeys(List<LiteAgenda> items, {int windowMinutes = 60}) {
  final timed = items.where((e) => e.hasTime && !e.isCompleted).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  final out = <String>{};
  for (var i = 0; i < timed.length; i++) {
    for (var j = i + 1; j < timed.length; j++) {
      final a = timed[i].date, b = timed[j].date;
      if (DateTime(a.year, a.month, a.day) !=
          DateTime(b.year, b.month, b.day)) {
        break; // 날짜순이라 그 뒤는 더 볼 필요 없다
      }
      if (b.difference(a).inMinutes >= windowMinutes) break;
      out
        ..add(timed[i].key)
        ..add(timed[j].key);
    }
  }
  return out;
}

String _hm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// 오늘 일정 요약 한 줄. [todayItems]는 오늘 날짜 일정들.
String todaySummary(List<LiteAgenda> todayItems, DateTime now) {
  if (todayItems.isEmpty) return '오늘 일정이 없습니다.';
  final remaining = todayItems.where((e) => !e.isCompleted).toList();
  if (remaining.isEmpty) return '오늘 일정 ${todayItems.length}건을 모두 마쳤습니다.';
  final upcoming =
      remaining.where((e) => e.hasTime && !e.date.isBefore(now)).toList()
        ..sort((a, b) => a.date.compareTo(b.date));
  final base = '오늘 일정 ${todayItems.length}건 · 남은 일정 ${remaining.length}건';
  if (upcoming.isEmpty) return base;
  final n = upcoming.first;
  return '$base · 다음 ${_hm(n.date)} ${n.title}';
}
