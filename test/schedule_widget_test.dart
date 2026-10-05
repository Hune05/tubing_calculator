import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_schedule/schedule_widget.dart';

void main() {
  final today = DateTime(2026, 10, 5);

  test('날짜 이름표: 오늘·내일·그 뒤', () {
    expect(agendaDayLabel(today, 0), '오늘 · 10월 5일 (월)');
    expect(agendaDayLabel(today, 1), '내일 · 10월 6일 (화)');
    expect(agendaDayLabel(today, 2), '10월 7일 (수)');
  });

  test('월말을 넘겨도 내일 날짜가 맞다', () {
    expect(agendaDayLabel(DateTime(2026, 10, 31), 1), '내일 · 11월 1일 (일)');
  });

  test('시간: 0시 0분·시간 없음은 null', () {
    expect(agendaTime(DateTime(2026, 10, 5, 9, 5)), '09:05');
    expect(agendaTime(DateTime(2026, 10, 5)), isNull);
    expect(agendaTime(DateTime(2026, 10, 5, 9, 5), hasTime: false), isNull);
    expect(agendaTime(null), isNull);
  });

  test('정렬: 날짜 → 시간 있는 것 시간 순 → 시간 없는 것', () {
    final sorted = sortAgenda(const [
      WidgetAgendaItem(day: 1, time: '08:00', title: 'd'),
      WidgetAgendaItem(day: 0, title: 'c'),
      WidgetAgendaItem(day: 0, time: '13:00', title: 'b'),
      WidgetAgendaItem(day: 0, time: '09:00', title: 'a'),
    ]);
    expect(sorted.map((e) => e.title), ['a', 'b', 'c', 'd']);
  });

  test('값 만들기: 최대 개수·필드', () {
    final json = jsonDecode(
      encodeScheduleWidgetPayload(
        now: DateTime(2026, 10, 5, 7, 3),
        todayCount: 2,
        max: 2,
        items: const [
          WidgetAgendaItem(day: 0, time: '09:00', title: 'a'),
          WidgetAgendaItem(day: 0, title: 'b'),
          WidgetAgendaItem(day: 1, time: '08:00', title: 'c'),
        ],
      ),
    ) as Map<String, dynamic>;
    expect(json['date'], '2026-10-05');
    expect(json['updatedAt'], '07:03');
    expect(json['todayCount'], 2);
    final items = json['items'] as List;
    expect(items.length, 2);
    expect(items[0]['t'], '09:00');
    expect(items[1].containsKey('t'), isFalse);
  });
}
