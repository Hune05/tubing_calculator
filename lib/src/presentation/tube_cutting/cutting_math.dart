// 한 구간의 절단 길이 계산. 화면(_calculate)에서 옮겨 와 테스트로 지킨다.
// 절단 길이 = 중심 간 거리(c2c) - 양쪽 피팅 공제값. 공제값은 항상 mm 기준이라
// 입력이 인치면 먼저 mm로 바꾼다. 결과가 음수면 피팅끼리 간섭한다는 뜻이다.

const double kInchToMm = 25.4;

double cutLengthMm({
  required double c2cInput,
  required bool inputIsInch,
  required double startDeduction,
  required double endDeduction,
}) {
  final c2c = inputIsInch ? c2cInput * kInchToMm : c2cInput;
  return c2c - startDeduction - endDeduction;
}

// ── 길이 입력 해석 ──
// 길이 칸에 쓴 글자를 숫자로 읽는다. 폰 숫자 키패드에는 쉼표(,)가 있어서 "1200,5"처럼
// 쓰면 예전에는 읽지 못하고 조용히 0으로 계산했다. 이제는
//  - 공백은 무시하고,
//  - "1,200"처럼 세 자리씩 끊은 쉼표는 자릿수 구분으로 보고("1,500" = 1500),
//  - 그 밖의 쉼표 하나는 소수점으로 보고("1200,5" = 1200.5),
//  - 그래도 못 읽으면 못 읽었다고 알려 준다(음수·글자·점이 둘 이상인 값 등).
class LengthParse {
  final double? value; // 읽은 값. 비었거나 못 읽었으면 null
  final bool empty;
  bool get unreadable => !empty && value == null;

  const LengthParse.empty() : value = null, empty = true;
  const LengthParse.ok(double v) : value = v, empty = false;
  const LengthParse.bad() : value = null, empty = false;
}

LengthParse parseLengthInput(String raw) {
  var t = raw.replaceAll(RegExp(r'\s+'), '');
  if (t.isEmpty) return const LengthParse.empty();
  if (RegExp(r'^\d{1,3}(,\d{3})+(\.\d+)?$').hasMatch(t)) {
    t = t.replaceAll(',', '');
  } else if (RegExp(r'^\d*,\d+$').hasMatch(t)) {
    t = t.replaceFirst(',', '.');
  }
  if (!RegExp(r'^(\d+\.?\d*|\.\d+)$').hasMatch(t)) {
    return const LengthParse.bad();
  }
  final v = double.tryParse(t);
  if (v == null || !v.isFinite || v > 1e9) return const LengthParse.bad();
  return LengthParse.ok(v);
}

// ── 절단 길이 계산 과정 글자 ──
// "절단 2588.0mm = 2600 − 6 − 6" 처럼 어떻게 나온 값인지 보여 준다.
// 정수에 가까우면 소수점을 생략하고, 공제값이 음수면 더하기로 쓴다.
String fmtMm(double v) => (v - v.roundToDouble()).abs() < 0.05
    ? '${v.round()}'
    : v.toStringAsFixed(1);

String cutBreakdownText({
  required double c2cMm,
  required double startDeduction,
  required double endDeduction,
}) {
  final cut = c2cMm - startDeduction - endDeduction;
  final head = '절단 ${cut.toStringAsFixed(1)}mm';
  final parts = <String>[fmtMm(c2cMm)];
  for (final d in [startDeduction, endDeduction]) {
    if (d == 0) continue;
    parts.add(d > 0 ? '− ${fmtMm(d)}' : '+ ${fmtMm(-d)}');
  }
  return parts.length == 1 ? head : '$head = ${parts.join(' ')}';
}
