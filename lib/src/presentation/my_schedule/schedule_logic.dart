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

/// 반복 종류. 저장 키 그대로(예전 자료는 'none'·'weekly'·'monthly'만 있다).
const List<String> kRecurrenceKinds = [
  'none',
  'daily',
  'weekdays',
  'weekly',
  'biweekly',
  'monthly',
  'yearly',
];

/// 반복하는 종류인지(모르는 값은 반복 없음으로 본다).
bool isRecurring(String recurrence) =>
    recurrence != 'none' && kRecurrenceKinds.contains(recurrence);

/// [base]에서 [n]번째 회차(0이 첫 회차). 평일 반복은 토·일을 건너뛴다(시작이 주말이면 다음 월요일부터).
/// 매달·매년은 31일처럼 없는 날짜를 그 달의 마지막 날로 맞춘다.
DateTime nthOccurrence(DateTime base, String recurrence, int n) {
  switch (recurrence) {
    case 'daily':
      return base.add(Duration(days: n));
    case 'weekdays':
      var d = base;
      while (d.weekday > 5) {
        d = d.add(const Duration(days: 1));
      }
      d = d.add(Duration(days: 7 * (n ~/ 5)));
      for (var i = 0; i < n % 5; i++) {
        d = d.add(const Duration(days: 1));
        if (d.weekday > 5) d = d.add(Duration(days: 8 - d.weekday));
      }
      return d;
    case 'weekly':
      return base.add(Duration(days: 7 * n));
    case 'biweekly':
      return base.add(Duration(days: 14 * n));
    case 'monthly':
      return addMonthsClamped(base, n);
    case 'yearly':
      return addMonthsClamped(base, 12 * n);
    default:
      return base;
  }
}

/// 이 회차를 보여 줘도 되는지: 반복 끝([until], 날짜만)을 넘지 않고, 뺀 회차([exceptions])가 아니어야 한다.
bool occurrenceAllowed(
  DateTime d, {
  DateTime? until,
  Set<String> exceptions = const {},
}) {
  if (until != null) {
    final u = DateTime(until.year, until.month, until.day);
    if (DateTime(d.year, d.month, d.day).isAfter(u)) return false;
  }
  return !exceptions.contains(occurrenceKey(d));
}

/// 반복 일정의 회차 날짜들. [rangeStart]~[rangeEnd] 안에 있는 회차만 돌려주고,
/// 반복이 없으면 [base] 하나만 돌려준다. [until] 뒤와 [exceptions](뺀 회차)는 뺀다.
List<DateTime> recurrenceDates(
  DateTime base,
  String recurrence, {
  required DateTime rangeStart,
  required DateTime rangeEnd,
  int maxCount = 400,
  DateTime? until,
  Set<String> exceptions = const {},
}) {
  if (!isRecurring(recurrence)) return [base];
  final out = <DateTime>[];
  // 범위 앞의 회차는 세지 않고 건너뛴다(오래된 반복 일정도 [maxCount]가 범위 안에서만 쓰이게).
  var n0 = 0;
  if (rangeStart.isAfter(base)) {
    final days = rangeStart.difference(base).inDays;
    n0 = switch (recurrence) {
      'daily' => days - 1,
      'weekdays' => days * 5 ~/ 7 - 3,
      'weekly' => days ~/ 7 - 1,
      'biweekly' => days ~/ 14 - 1,
      'monthly' =>
        (rangeStart.year - base.year) * 12 + rangeStart.month - base.month - 1,
      'yearly' => rangeStart.year - base.year - 1,
      _ => 0,
    };
    if (n0 < 0) n0 = 0;
  }
  for (var n = n0; n < n0 + maxCount; n++) {
    final d = nthOccurrence(base, recurrence, n);
    if (d.isAfter(rangeEnd)) break;
    if (until != null &&
        DateTime(
          d.year,
          d.month,
          d.day,
        ).isAfter(DateTime(until.year, until.month, until.day))) {
      break;
    }
    if (d.isBefore(rangeStart)) continue;
    if (!occurrenceAllowed(d, exceptions: exceptions)) continue;
    out.add(d);
  }
  return out;
}

/// [day](날짜만 본다)에 반복 일정이 걸리는지. 반복 일정은 시작일 이후부터 센다.
bool recurrenceOccursOn(
  DateTime base,
  String recurrence,
  DateTime day, {
  DateTime? until,
  Set<String> exceptions = const {},
}) {
  final d = DateTime(day.year, day.month, day.day);
  final b = DateTime(base.year, base.month, base.day);
  if (d.isBefore(b)) return false;
  if (!isRecurring(recurrence)) return d == b;
  if (!occurrenceAllowed(d, until: until, exceptions: exceptions)) return false;
  switch (recurrence) {
    case 'daily':
      return true;
    case 'weekdays':
      return d.weekday <= 5;
    case 'weekly':
      return d.weekday == b.weekday;
    case 'biweekly':
      return d.weekday == b.weekday && d.difference(b).inDays % 14 == 0;
    case 'monthly':
      final want = b.day > _lastDayOfMonth(d.year, d.month)
          ? _lastDayOfMonth(d.year, d.month)
          : b.day;
      return d.day == want;
    case 'yearly':
      if (d.month != b.month) return false;
      final want = b.day > _lastDayOfMonth(d.year, d.month)
          ? _lastDayOfMonth(d.year, d.month)
          : b.day;
      return d.day == want;
  }
  return false;
}

/// 회차를 "이후 모두" 끊을 때 옛 일정의 반복 끝: 그 회차 하루 전(날짜만).
DateTime untilBeforeOccurrence(DateTime occurrence) =>
    DateTime(occurrence.year, occurrence.month, occurrence.day - 1);

/// 문서의 알림 목록(분 단위, 시작 전이면 양수). 새 자료는 'reminders' 목록, 예전 자료는
/// 'reminderMinutesBefore' 하나. 종일 일정의 예전 값은 쓰지 않는다(예전엔 종일엔 알림이 없었다).
List<int> readReminders(Map<String, dynamic> data) {
  final raw = data['reminders'];
  if (raw is List) {
    final out = {
      for (final v in raw)
        if (v is num && v.toInt() != 0) v.toInt(),
    }.toList()..sort((a, b) => b.compareTo(a));
    return out;
  }
  if (data['hasTime'] == false) return [];
  final m = (data['reminderMinutesBefore'] as num?)?.toInt() ?? 0;
  return m > 0 ? [m] : [];
}

/// 문서의 뺀 회차 키들.
Set<String> readExceptions(Map<String, dynamic> data) {
  final raw = data['recurrenceExceptions'];
  if (raw is! List) return const {};
  return {for (final v in raw) v.toString()};
}

/// 문서의 반복 끝(날짜만). 없으면 null.
DateTime? readUntil(Map<String, dynamic> data) {
  final raw = data['recurrenceUntil'];
  if (raw is! String) return null;
  final d = DateTime.tryParse(raw);
  return d == null ? null : DateTime(d.year, d.month, d.day);
}

/// 문서의 끝나는 시각(ISO). 시작보다 뒤일 때만.
DateTime? readEndTime(Map<String, dynamic> data, DateTime start) {
  final raw = data['endTime'];
  if (raw is! String) return null;
  final e = DateTime.tryParse(raw);
  if (e == null || !e.isAfter(start)) return null;
  return e;
}

/// 회차의 끝나는 시각: 시작 회차와 같은 길이만큼.
DateTime? occurrenceEnd(DateTime occurrence, DateTime base, DateTime? baseEnd) {
  if (baseEnd == null) return null;
  final dur = baseEnd.difference(base);
  return dur.inMinutes <= 0 ? null : occurrence.add(dur);
}

String _hhmm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// 카드에 쓰는 시각 글: "09:00" 또는 "09:00~10:30".
String formatTimeRange(DateTime start, DateTime? end) =>
    end == null || !end.isAfter(start)
    ? _hhmm(start)
    : '${_hhmm(start)}~${_hhmm(end)}';

/// 종일 일정 알림 고르기(자정 기준 몇 분 전, 음수는 그 날 아침).
const Map<int, String> kAllDayReminderOptions = {
  360: "전날 18:00",
  900: "전날 09:00",
  -480: "당일 08:00",
};

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
/// [allowAllDay]가 참이면 종일 일정도 그 날 자정 기준으로 셈한다([minutesBefore]가 음수면 그 날
/// 아침처럼 자정 뒤). 예전 호출은 종일이면 알림 없음 그대로.
DateTime? reminderTime({
  required DateTime base,
  required int minutesBefore,
  required String recurrence,
  required bool hasTime,
  required DateTime now,
  bool allowAllDay = false,
  DateTime? until,
  Set<String> exceptions = const {},
}) {
  if (minutesBefore == 0) return null;
  if (!hasTime && !allowAllDay) return null;
  if (minutesBefore < 0 && hasTime) return null;
  final start = hasTime ? base : DateTime(base.year, base.month, base.day);
  final before = Duration(minutes: minutesBefore);
  if (!isRecurring(recurrence)) {
    final remind = start.subtract(before);
    return remind.isBefore(now) ? null : remind;
  }
  // 회차(일정 날짜)를 먼저 구하고 거기서 뺀다. 알림 시각에 말일 맞추기를 걸면
  // 1일 일정의 하루 전 알림이 28일로 가는 것처럼 날짜가 틀어진다.
  for (var n = 0; n < 1200; n++) {
    final occ = nthOccurrence(start, recurrence, n);
    if (until != null &&
        DateTime(
          occ.year,
          occ.month,
          occ.day,
        ).isAfter(DateTime(until.year, until.month, until.day))) {
      return null;
    }
    if (!occurrenceAllowed(occ, exceptions: exceptions)) continue;
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
  // 끝나는 시각(있으면 겹침을 구간으로 본다).
  final DateTime? end;
  const LiteAgenda({
    required this.key,
    required this.date,
    required this.hasTime,
    required this.title,
    required this.isCompleted,
    this.end,
  });
}

/// 두 일정이 겹치는지. 둘 다 끝나는 시각이 있으면 구간이 겹치는지, 아니면 시작이 [windowMinutes]분 안쪽인지.
bool _agendaOverlap(LiteAgenda a, LiteAgenda b, int windowMinutes) {
  if (a.end != null && b.end != null) {
    return a.date.isBefore(b.end!) && b.date.isBefore(a.end!);
  }
  return b.date.difference(a.date).inMinutes.abs() < windowMinutes;
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
      final bool ov = _agendaOverlap(timed[i], timed[j], windowMinutes);
      if (!ov) {
        // 시작 순이라, 이 뒤 것은 더 늦게 시작한다. 구간이 있으면 끝 시각까지는 더 본다.
        final aEnd = timed[i].end;
        if (aEnd == null || !b.isBefore(aEnd)) break;
        continue;
      }
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
    return _agendaOverlap(candidate, o, windowMinutes);
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

DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// 기간 일정의 시작일을 [newStart]로 옮길 때의 새 종료일(날짜만).
/// 원래 기간(일수)을 그대로 두고 종료일도 같이 옮긴다. 종료일이 없으면 null.
/// 원래 시작일을 모르면 종료일이 새 시작일보다 앞설 때만 버린다.
DateTime? shiftedEndDate({
  required DateTime? oldStart,
  required DateTime? oldEnd,
  required DateTime newStart,
}) {
  if (oldEnd == null) return null;
  final ns = _dayOnly(newStart);
  if (oldStart == null) {
    return _dayOnly(oldEnd).isAfter(ns) ? _dayOnly(oldEnd) : null;
  }
  final days = _dayOnly(oldEnd).difference(_dayOnly(oldStart)).inDays;
  if (days <= 0) return null;
  return DateTime(ns.year, ns.month, ns.day + days);
}

/// 기간 일정을 달력에 펼칠 때의 최대 일수. 프로젝트 일정 편집의 종료일 선택(시작일 + 730일)과 맞춘다.
const int kMaxSpanDays = 731;

/// [start]~[end](날짜만 본다) 기간 일정이 달력에 차지하는 일수. 종료일이 없거나 시작보다 앞서면 1,
/// [kMaxSpanDays]를 넘으면 잘못 넣은 값으로 보고 1.
int spanDayCount(DateTime start, DateTime? end) {
  if (end == null) return 1;
  final s = _dayOnly(start);
  final e = _dayOnly(end);
  if (e.isBefore(s)) return 1;
  final days = (e.difference(s).inHours / 24).round() + 1;
  return days > kMaxSpanDays ? 1 : days;
}

/// 기간 일정([start]~[end])이 [day]에 걸리는지. 달력과 같은 규칙([spanDayCount])으로 본다.
bool spanCoversDay(DateTime start, DateTime? end, DateTime day) {
  final s = _dayOnly(start);
  final d = _dayOnly(day);
  if (d.isBefore(s)) return false;
  final last = DateTime(s.year, s.month, s.day + spanDayCount(start, end) - 1);
  return !d.isAfter(last);
}

/// 날짜 고르기 창의 범위. 고치려는 날짜([initial])가 기본 범위([first]~[last]) 밖이면 그 날짜까지
/// 넓힌다(1년 넘게 지난 일정을 고칠 때 창이 오류로 멈추지 않게).
({DateTime first, DateTime last}) pickerRangeFor(
  DateTime initial,
  DateTime first,
  DateTime last,
) {
  final d = _dayOnly(initial);
  return (
    first: d.isBefore(_dayOnly(first)) ? d : first,
    last: d.isAfter(_dayOnly(last)) ? d : last,
  );
}

/// [initial]을 [first]~[last] 안으로 맞춘다(이미 지난 기한을 다시 고를 때 오늘부터 보이게).
DateTime clampPickerInitial(DateTime initial, DateTime first, DateTime last) {
  if (initial.isBefore(first)) return first;
  if (initial.isAfter(last)) return last;
  return initial;
}

/// 일정 제목 칸 검사. 비어 있으면 까닭을 돌려준다.
String? scheduleTitleError(String text) =>
    text.trim().isEmpty ? '제목을 입력하십시오.' : null;

/// 장소를 지도 검색으로 고른 뒤([pickedName]) 칸의 글이 [now]로 바뀌었으면 고른 주소·좌표를 버려야 하는지.
/// 고른 장소가 없으면(빈 글자) 버릴 것도 없다.
bool shouldForgetPickedPlace(String pickedName, String now) =>
    pickedName.trim().isNotEmpty && now.trim() != pickedName.trim();

/// 이름을 모를 때 내 일정 화면이 쓰는 자리 글. 이 이름으로는 일정을 저장하지 않는다
/// (이름이 없는 여러 폰이 같은 주인 '로그인 필요' 일정을 서로 보고 고치게 되므로).
const String kNoWorkerName = '로그인 필요';

/// [worker]로 개인 일정을 저장해도 되는지.
bool canSaveAsWorker(String worker) {
  final w = worker.trim();
  return w.isNotEmpty && w != kNoWorkerName;
}
