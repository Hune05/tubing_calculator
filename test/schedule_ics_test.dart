// 내 일정 → .ics 파일 글.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_schedule/schedule_ics.dart';

void main() {
  test('시간 일정: 시작·끝·알림·장소·메모', () {
    final lines = icsEventLines('abc', {
      'title': '거래처 미팅, 2팀',
      'dateTime': '2026-09-23T09:00:00.000',
      'endTime': '2026-09-23T10:30:00.000',
      'hasTime': true,
      'place': '중부발전',
      'note': '도면 챙기기',
      'category': '업무',
      'reminders': [30, 10],
    });
    expect(lines.first, 'BEGIN:VEVENT');
    expect(lines, contains('UID:abc@tubing_calculator'));
    expect(lines, contains('SUMMARY:거래처 미팅\\, 2팀'));
    expect(lines, contains('DTSTART;TZID=Asia/Seoul:20260923T090000'));
    expect(lines, contains('DTEND;TZID=Asia/Seoul:20260923T103000'));
    expect(lines, contains('LOCATION:중부발전'));
    expect(lines, contains('DESCRIPTION:종류: 업무\\n도면 챙기기'));
    expect(lines.where((l) => l.startsWith('TRIGGER:')), [
      'TRIGGER:-PT30M',
      'TRIGGER:-PT10M',
    ]);
    expect(lines.last, 'END:VEVENT');
  });

  test('끝 시각이 없으면 한 시간짜리', () {
    final lines = icsEventLines('x', {
      'title': 't',
      'dateTime': '2026-09-23T09:00:00.000',
    });
    expect(lines, contains('DTEND;TZID=Asia/Seoul:20260923T100000'));
  });

  test('종일·여러 날: 끝은 다음 날 날짜', () {
    final lines = icsEventLines('x', {
      'title': '출장',
      'dateTime': '2026-09-23T00:00:00.000',
      'hasTime': false,
      'endDate': '2026-09-25T00:00:00.000',
      'reminders': [360, -480],
    });
    expect(lines, contains('DTSTART;VALUE=DATE:20260923'));
    expect(lines, contains('DTEND;VALUE=DATE:20260926'));
    // 당일 아침(음수)은 못 적으니 전날 것만
    expect(lines.where((l) => l.startsWith('TRIGGER:')), ['TRIGGER:-PT360M']);
  });

  test('반복·반복 끝·뺀 회차', () {
    expect(icsRrule('none'), isNull);
    expect(icsRrule('weekdays'), 'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR');
    expect(icsRrule('biweekly'), 'FREQ=WEEKLY;INTERVAL=2');
    expect(
      icsRrule('weekly', until: DateTime(2026, 10, 7)),
      'FREQ=WEEKLY;UNTIL=20261007T235959',
    );
    final lines = icsEventLines('x', {
      'title': '회의',
      'dateTime': '2026-09-23T09:00:00.000',
      'recurrence': 'weekly',
      'recurrenceExceptions': ['2026-09-30T00:00:00.000'],
    });
    expect(lines, contains('RRULE:FREQ=WEEKLY'));
    expect(lines, contains('EXDATE;TZID=Asia/Seoul:20260930T090000'));
  });

  test('날짜가 없으면 빼고, 파일 전체는 VCALENDAR로 감싼다', () {
    final s = buildIcs([
      (id: 'a', data: {'title': 'a', 'dateTime': '2026-09-23T09:00:00.000'}),
      (id: 'b', data: {'title': '없음'}),
    ]);
    expect(s.startsWith('BEGIN:VCALENDAR\r\n'), isTrue);
    expect(s.endsWith('END:VCALENDAR\r\n'), isTrue);
    expect('BEGIN:VEVENT'.allMatches(s).length, 1);
    expect(s.split('\r\n').every((l) => l.length <= 75), isTrue);
  });
}
