// 내 일정을 캘린더 파일(.ics)로 만든다. 구글·네이버·삼성 캘린더가 다 읽는 형식이라
// 카톡·메일로 보내면 그쪽 달력에 넣을 수 있다. 순수한 글 만들기만 하고 파일·공유는 화면이 한다.
import 'schedule_backup.dart' show PersonalDoc;
import 'schedule_logic.dart';

String _two(int v) => v.toString().padLeft(2, '0');

/// 20260923T090000 (폰 시간 그대로, TZID는 Asia/Seoul).
String icsDateTime(DateTime d) =>
    '${d.year}${_two(d.month)}${_two(d.day)}T${_two(d.hour)}${_two(d.minute)}00';

/// 20260923 (종일용).
String icsDate(DateTime d) => '${d.year}${_two(d.month)}${_two(d.day)}';

/// ics 글에 못 넣는 글자(줄바꿈·쉼표·세미콜론)를 규칙대로 바꾼다.
String icsEscape(String s) => s
    .replaceAll('\\', '\\\\')
    .replaceAll('\n', '\\n')
    .replaceAll(',', '\\,')
    .replaceAll(';', '\\;');

/// 반복 종류 → RRULE. 반복이 없으면 null.
String? icsRrule(String recurrence, {DateTime? until}) {
  String? base = switch (recurrence) {
    'daily' => 'FREQ=DAILY',
    'weekdays' => 'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR',
    'weekly' => 'FREQ=WEEKLY',
    'biweekly' => 'FREQ=WEEKLY;INTERVAL=2',
    'monthly' => 'FREQ=MONTHLY',
    'yearly' => 'FREQ=YEARLY',
    _ => null,
  };
  if (base == null) return null;
  if (until != null) {
    base = '$base;UNTIL=${icsDate(until)}T235959';
  }
  return base;
}

/// 75자마다 줄을 접는다(형식 규칙).
String _fold(String line) {
  if (line.length <= 75) return line;
  final buf = StringBuffer();
  var i = 0;
  while (i < line.length) {
    final end = (i + 75).clamp(0, line.length);
    if (i > 0) buf.write('\r\n ');
    buf.write(line.substring(i, end));
    i = end;
  }
  return buf.toString();
}

/// 일정 문서 하나 → VEVENT 줄들. 날짜 칸이 없으면 빈 목록.
List<String> icsEventLines(String id, Map<String, dynamic> d) {
  final base = DateTime.tryParse(d['dateTime']?.toString() ?? '');
  if (base == null) return const [];
  final bool hasTime = d['hasTime'] != false;
  final String title = (d['title'] as String?)?.trim().isNotEmpty == true
      ? d['title'] as String
      : '제목 없음';
  final String recurrence = (d['recurrence'] as String?) ?? 'none';
  final lines = <String>[
    'BEGIN:VEVENT',
    'UID:$id@tubing_calculator',
    'DTSTAMP:${icsDateTime(DateTime.now())}',
    'SUMMARY:${icsEscape(title)}',
  ];
  if (hasTime) {
    final end = readEndTime(d, base) ?? base.add(const Duration(hours: 1));
    lines.add('DTSTART;TZID=Asia/Seoul:${icsDateTime(base)}');
    lines.add('DTEND;TZID=Asia/Seoul:${icsDateTime(end)}');
  } else {
    // 종일은 끝 날짜를 "다음 날"로 적는 규칙. 여러 날 일정은 endDate 다음 날.
    final rawEnd = d['endDate'] is String
        ? DateTime.tryParse(d['endDate'] as String)
        : null;
    final last = rawEnd != null && !rawEnd.isBefore(base) ? rawEnd : base;
    lines.add('DTSTART;VALUE=DATE:${icsDate(base)}');
    lines.add(
      'DTEND;VALUE=DATE:${icsDate(DateTime(last.year, last.month, last.day + 1))}',
    );
  }
  final rrule = icsRrule(recurrence, until: readUntil(d));
  if (rrule != null) lines.add('RRULE:$rrule');
  for (final ex in readExceptions(d)) {
    final exd = DateTime.tryParse(ex);
    if (exd == null) continue;
    lines.add(
      hasTime
          ? 'EXDATE;TZID=Asia/Seoul:${icsDateTime(DateTime(exd.year, exd.month, exd.day, base.hour, base.minute))}'
          : 'EXDATE;VALUE=DATE:${icsDate(exd)}',
    );
  }
  final place = (d['place'] as String?)?.trim() ?? '';
  if (place.isNotEmpty) lines.add('LOCATION:${icsEscape(place)}');
  final parts = <String>[
    if ((d['category'] as String?)?.isNotEmpty == true) '종류: ${d['category']}',
    if ((d['note'] as String?)?.trim().isNotEmpty == true)
      (d['note'] as String).trim(),
  ];
  if (parts.isNotEmpty) lines.add('DESCRIPTION:${icsEscape(parts.join('\n'))}');
  for (final m in readReminders(d)) {
    if (!hasTime && m < 0) continue; // 자정 뒤(당일 아침)는 ics 알림으로 못 적는다
    lines.addAll([
      'BEGIN:VALARM',
      'ACTION:DISPLAY',
      'DESCRIPTION:${icsEscape(title)}',
      'TRIGGER:-PT${m}M',
      'END:VALARM',
    ]);
  }
  lines.add('END:VEVENT');
  return lines;
}

/// 개인 일정들 → .ics 파일 내용.
String buildIcs(List<PersonalDoc> docs) {
  final lines = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//현장 도우미//내 일정//KO',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'X-WR-CALNAME:내 일정',
    'X-WR-TIMEZONE:Asia/Seoul',
  ];
  for (final d in docs) {
    lines.addAll(icsEventLines(d.id, d.data));
  }
  lines.add('END:VCALENDAR');
  return '${lines.map(_fold).join('\r\n')}\r\n';
}
