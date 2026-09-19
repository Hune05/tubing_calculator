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
