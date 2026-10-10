// 쉬는 날(10-10 사용자 결정: 토요일·일요일·공휴일). 이날은 작업 일지·작업 지연·이슈 반복 같은 업무
// 알림을 보내지 않는다(휴일에는 일을 안 하는 일이 많다). 그날 출근을 찍었으면(특근) 작업 일지 알림은 온다.
// 서버 알림도 같은 날을 쓴다(functions/rest_day.js — 공휴일 표를 같이 고칠 것, 시험이 둘을 맞춰 본다).
import '../../presentation/my_schedule/korean_holidays.dart';

/// 공휴일인지(토·일은 보지 않는다).
bool isKoreanHolidayDay(DateTime d) => isKoreanHoliday(d);

bool isRestDay(DateTime d) =>
    d.weekday == DateTime.saturday ||
    d.weekday == DateTime.sunday ||
    isKoreanHoliday(d);

/// [first]부터(그날이 쉬는 날이면 다음 근무일부터) 근무일 같은 시각 [count]개.
List<DateTime> workdaySeries(DateTime first, int count) {
  final out = <DateTime>[];
  var d = first;
  var guard = 0;
  while (out.length < count && guard < 60) {
    if (!isRestDay(d)) out.add(d);
    d = DateTime(d.year, d.month, d.day + 1, d.hour, d.minute);
    guard++;
  }
  return out;
}

/// [d]가 쉬는 날이면 그 앞 근무일(같은 시각). 기한 알림을 휴일 대신 앞 근무일에 받으려고 쓴다.
DateTime previousWorkday(DateTime d) {
  var x = d;
  var guard = 0;
  while (isRestDay(x) && guard < 30) {
    x = DateTime(x.year, x.month, x.day - 1, x.hour, x.minute);
    guard++;
  }
  return x;
}
