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
/// [start]가 있으면 앱과 같은 날로 맞춘다(10-08): 매달 29~31일은 그 날이 없는 달에 말일로
/// (예전엔 다른 달력 앱이 그 달을 건너뛰었다), 매년 2/29는 평년에 2/28로.
/// [allDay]면 UNTIL을 날짜로, 아니면 UTC 시각으로 적는다(시작이 TZID일 때의 규칙).
String? icsRrule(
  String recurrence, {
  DateTime? until,
  DateTime? start,
  bool allDay = false,
}) {
  final day = start?.day ?? 1;
  String? base = switch (recurrence) {
    'daily' => 'FREQ=DAILY',
    'weekdays' => 'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR',
    'weekly' => 'FREQ=WEEKLY',
    'biweekly' => 'FREQ=WEEKLY;INTERVAL=2',
    'monthly' when day > 28 =>
      'FREQ=MONTHLY;BYMONTHDAY=${[for (var d = 28; d <= day; d++) d].join(',')};BYSETPOS=-1',
    'monthly' => 'FREQ=MONTHLY',
    'yearly' when start != null && start.month == 2 && start.day == 29 =>
      'FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=28,29;BYSETPOS=-1',
    'yearly' => 'FREQ=YEARLY',
    _ => null,
  };
  if (base == null) return null;
  if (until != null) {
    if (allDay) {
      base = '$base;UNTIL=${icsDate(until)}';
    } else {
      // 한국 시각 그날 23:59:59 → UTC(9시간 앞).
      final u = DateTime.utc(until.year, until.month, until.day, 23, 59, 59)
          .subtract(const Duration(hours: 9));
      base = '$base;UNTIL=${icsDateTime(u).substring(0, 13)}${_two(u.second)}Z';
    }
  }
  return base;
}

/// 75바이트(UTF-8)마다 줄을 접는다(형식 규칙). 한글·이모지를 글자 중간에서 자르지 않는다
/// (10-08: 글자 수로 세어 한 줄이 225바이트까지 되고, 이모지가 반으로 쪼개질 수 있었다).
String _fold(String line) {
  final buf = StringBuffer();
  var bytes = 0;
  for (final rune in line.runes) {
    final n = rune < 0x80
        ? 1
        : rune < 0x800
        ? 2
        : rune < 0x10000
        ? 3
        : 4;
    if (bytes + n > 75) {
      buf.write('\r\n ');
      bytes = 1; // 이어지는 줄 앞 빈칸
    }
    buf.write(String.fromCharCode(rune));
    bytes += n;
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
    var end = readEndTime(d, base) ?? base.add(const Duration(hours: 1));
    // 시간이 있는 여러 날 일정은 마지막 날 그 시각까지(10-08: 첫날 1시간짜리로 나갔다).
    final rawEnd = d['endDate'] is String
        ? DateTime.tryParse(d['endDate'] as String)
        : null;
    if (rawEnd != null &&
        DateTime(rawEnd.year, rawEnd.month, rawEnd.day)
            .isAfter(DateTime(base.year, base.month, base.day))) {
      final e = DateTime(rawEnd.year, rawEnd.month, rawEnd.day, end.hour, end.minute);
      if (e.isAfter(base)) end = e;
    }
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
  final rrule = icsRrule(
    recurrence,
    until: readUntil(d),
    start: base,
    allDay: !hasTime,
  );
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
