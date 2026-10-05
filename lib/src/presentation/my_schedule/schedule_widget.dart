// 홈 화면 "내 일정" 위젯에 넘길 값. 앱이 오늘·내일 일정(안 끝낸 것)을 모아 JSON으로 만들어 두면
// 위젯은 통신 없이 그것만 그린다(앱이 꺼져 있어도 보인다). 날짜가 바뀌면 위젯이 낡은 값으로 알아본다.
library;

import 'dart:convert';

/// 위젯에 보일 일정 한 줄.
class WidgetAgendaItem {
  /// 0 = 오늘, 1 = 내일.
  final int day;

  /// "09:30". 시간이 없으면(종일·여러 날의 둘째 날부터) null.
  final String? time;
  final String title;

  const WidgetAgendaItem({required this.day, this.time, required this.title});
}

const List<String> _wd = ['월', '화', '수', '목', '금', '토', '일'];

/// "오늘 · 10월 5일 (월)" / "내일 · 10월 6일 (화)" / 그 뒤는 "10월 7일 (수)".
String agendaDayLabel(DateTime today, int offset) {
  final d = DateTime(today.year, today.month, today.day + offset);
  final base = '${d.month}월 ${d.day}일 (${_wd[d.weekday - 1]})';
  if (offset == 0) return '오늘 · $base';
  if (offset == 1) return '내일 · $base';
  return base;
}

/// 시각(시·분)을 "09:30"으로. 0시 0분이면 시간이 없는 일정으로 보고 null.
String? agendaTime(DateTime? d, {bool hasTime = true}) {
  if (d == null || !hasTime) return null;
  if (d.hour == 0 && d.minute == 0) return null;
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// 정렬: 날짜 순, 같은 날은 시간 있는 것을 시간 순으로 먼저, 시간 없는 것은 뒤에.
List<WidgetAgendaItem> sortAgenda(List<WidgetAgendaItem> items) {
  final list = [...items];
  list.sort((a, b) {
    if (a.day != b.day) return a.day.compareTo(b.day);
    if (a.time == null && b.time == null) return 0;
    if (a.time == null) return 1;
    if (b.time == null) return -1;
    return a.time!.compareTo(b.time!);
  });
  return list;
}

/// 위젯 값(JSON). [todayCount]는 오늘 남은 일정 수(요약과 같은 값).
String encodeScheduleWidgetPayload({
  required DateTime now,
  required List<WidgetAgendaItem> items,
  required int todayCount,
  int max = 10,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final sorted = sortAgenda(items).take(max).toList();
  String two(int v) => v.toString().padLeft(2, '0');
  return jsonEncode({
    'date':
        '${today.year.toString().padLeft(4, '0')}-${two(today.month)}-${two(today.day)}',
    'updatedAt': '${two(now.hour)}:${two(now.minute)}',
    'todayCount': todayCount,
    'items': [
      for (final i in sorted)
        {
          'd': i.day,
          'dl': agendaDayLabel(today, i.day),
          if (i.time != null) 't': i.time,
          'x': i.title,
        },
    ],
  });
}
