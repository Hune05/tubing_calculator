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

/// 반복 일정 회차의 완료 표시 키. 날짜만 본다(예: '2026-09-25T00:00:00.000').
String occurrenceKey(DateTime day) =>
    DateTime(day.year, day.month, day.day).toIso8601String();

/// 회차 완료 표시를 저장할 필드 경로(칸 목록). 키에 점이 들어 있어서 'a.b' 문자열 경로로 쓰면
/// 서버가 점마다 쪼개 중첩으로 넣는다. 그래서 칸 목록(FieldPath)으로 넘긴다.
List<String> occurrenceFieldPath(DateTime day) => [
  'completedOccurrences',
  occurrenceKey(day),
];

/// 예전 코드가 점으로 쪼개 넣은 중첩 모양의 경로({'2026-09-25T00:00:00': {'000': true}}).
/// 완료를 풀 때 이 모양도 같이 지운다.
List<String> legacyOccurrenceFieldPath(DateTime day) => [
  'completedOccurrences',
  occurrenceKey(day).split('.').first,
];

/// [completed](문서의 completedOccurrences)에서 [day] 회차가 완료로 표시됐는지.
/// 예전에 중첩 모양으로 들어간 표시도 같이 인정한다.
bool isOccurrenceCompleted(Map? completed, DateTime day) {
  if (completed == null) return false;
  final key = occurrenceKey(day);
  if (completed[key] == true) return true;
  final dot = key.indexOf('.');
  if (dot < 0) return false;
  final legacy = completed[key.substring(0, dot)];
  return legacy is Map && legacy[key.substring(dot + 1)] == true;
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
  final before = Duration(minutes: minutesBefore);
  if (recurrence != 'weekly' && recurrence != 'monthly') {
    final remind = base.subtract(before);
    return remind.isBefore(now) ? null : remind;
  }
  // 회차(일정 날짜)를 먼저 구하고 거기서 뺀다. 알림 시각에 말일 맞추기를 걸면
  // 1일 일정의 하루 전 알림이 28일로 가는 것처럼 날짜가 틀어진다.
  for (var n = 0; n < 1200; n++) {
    final occ = recurrence == 'weekly'
        ? base.add(Duration(days: 7 * n))
        : addMonthsClamped(base, n);
    final at = occ.subtract(before);
    if (!at.isBefore(now)) return at;
  }
  return null;
}

/// 매달 반복 일정의 알림이 달마다 같은 날·같은 시각에 울리는지.
/// 일정 날짜가 28일 이하이고 알림이 같은 달 안에 있을 때만 그렇다(그래야 폰에 '매달 같은 날'로
/// 되풀이 예약해도 맞는다). 아니면 다음 한 번만 예약하고 앱을 열 때 다시 잡는다.
bool monthlyReminderKeepsDay(DateTime base, int minutesBefore) {
  if (base.day > 28) return false;
  final r = base.subtract(Duration(minutes: minutesBefore));
  return r.year == base.year && r.month == base.month;
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

/// 새로 넣을 일정 [candidate]와 같은 날 시작 시간이 [windowMinutes]분 안쪽으로 가까운 기존 일정들
/// (시간순). 종일·완료한 일정은 뺀다. [excludeKeyPrefix]로 시작하는 key(지금 고치는 일정 자신)도 뺀다.
List<LiteAgenda> conflictsWith(
  LiteAgenda candidate,
  List<LiteAgenda> others, {
  int windowMinutes = 60,
  String? excludeKeyPrefix,
}) {
  if (!candidate.hasTime) return [];
  final c = candidate.date;
  final day = DateTime(c.year, c.month, c.day);
  return others.where((o) {
    if (!o.hasTime || o.isCompleted) return false;
    if (excludeKeyPrefix != null && o.key.startsWith(excludeKeyPrefix)) {
      return false;
    }
    if (DateTime(o.date.year, o.date.month, o.date.day) != day) return false;
    return o.date.difference(c).inMinutes.abs() < windowMinutes;
  }).toList()..sort((a, b) => a.date.compareTo(b.date));
}

/// 검색에 쓸 일정 한 건. [groupKey]가 같은 것(반복 일정의 여러 회차, 여러 날 일정의 각 날)은 한 건으로 본다.
class SearchEntry {
  final String groupKey;
  final String key;
  final DateTime date;
  final String title;
  final String category;
  final String? projectName;
  const SearchEntry({
    required this.groupKey,
    required this.key,
    required this.date,
    required this.title,
    required this.category,
    this.projectName,
  });
}

String _squash(String s) => s.replaceAll(RegExp(r'\s+'), '').toLowerCase();

/// 제목·종류·프로젝트 이름에서 [query]를 찾는다(띄어쓰기·대소문자 무시).
/// 같은 일정의 여러 회차는 오늘에 가장 가까운 하나만 돌려주고, 앞으로 올 것(오늘 포함)은 가까운 순,
/// 지난 것은 최근 순으로 그 뒤에 붙인다. 최대 [limit]건.
List<SearchEntry> searchAgenda(
  List<SearchEntry> all,
  String query, {
  required DateTime now,
  int limit = 50,
}) {
  final q = _squash(query);
  if (q.isEmpty) return [];
  final today = DateTime(now.year, now.month, now.day);
  final best = <String, SearchEntry>{};
  for (final e in all) {
    final hay = _squash('${e.title} ${e.category} ${e.projectName ?? ''}');
    if (!hay.contains(q)) continue;
    final cur = best[e.groupKey];
    if (cur == null) {
      best[e.groupKey] = e;
      continue;
    }
    final dNew = e.date.difference(today).inHours.abs();
    final dCur = cur.date.difference(today).inHours.abs();
    if (dNew < dCur || (dNew == dCur && !e.date.isBefore(today))) {
      best[e.groupKey] = e;
    }
  }
  final upcoming = best.values.where((e) => !e.date.isBefore(today)).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  final past = best.values.where((e) => e.date.isBefore(today)).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  return [...upcoming, ...past].take(limit).toList();
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
