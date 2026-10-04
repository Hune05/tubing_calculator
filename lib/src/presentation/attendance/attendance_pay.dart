// 예상 수당(참고용): 통상시급을 넣었을 때 한 달 연장·야간·휴일 시간에 붙는 돈을 어림한다.
//
// 근로기준법 제56조의 가산율을 그대로 쓴다.
// - 연장 시간: 시급 1.5배 전부(연장 자체 100% + 가산 50%). 월급에 이미 들어 있지 않은 시간 기준.
// - 야간 시간(22~06시): 시급 0.5배(가산분). 연장과 겹치면 둘 다 붙는다(합 2배).
// - 휴일 시간: 시급 1.5배(8시간 넘는 부분은 2배, 즉 넘는 시간에 0.5배를 더).
// 시간은 attendance_calc.dart의 MonthSummary 값을 그대로 쓴다(같은 달에 다른 숫자가 나오지 않게).
// 회사의 급여 체계(포괄임금, 고정 연장수당, 시급제 기본급)와 다를 수 있어 화면에 "참고용"이라고 적는다.
library;

import 'attendance_calc.dart';

class PayEstimate {
  final int wage; // 통상시급(원)
  final int overtime; // 연장 수당
  final int night; // 야간 가산
  final int holiday; // 휴일 수당
  const PayEstimate({
    required this.wage,
    required this.overtime,
    required this.night,
    required this.holiday,
  });

  int get total => overtime + night + holiday;
}

/// 한 달 합계 [s]와 통상시급 [wage]로 어림한 수당. 시급이 없거나 0 이하면 null.
PayEstimate? estimateExtraPay(MonthSummary s, int? wage) {
  if (wage == null || wage <= 0) return null;
  double hours(int min) => min / 60.0;
  int won(double v) => v.round();
  return PayEstimate(
    wage: wage,
    overtime: won(wage * 1.5 * hours(s.overtime)),
    night: won(wage * 0.5 * hours(s.night)),
    holiday: won(wage * (1.5 * hours(s.holiday) + 0.5 * hours(s.holidayOver8))),
  );
}

/// 1234567 → "1,234,567원".
String formatWon(int v) {
  final neg = v < 0;
  final s = v.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '${neg ? '-' : ''}${b.toString()}원';
}
