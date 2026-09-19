import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_optimizer.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_plan_rows.dart';

// 절단 지시서의 "원자재 배치" 표 글자.
void main() {
  test('같은 길이는 묶고 긴 것부터 쓴다', () {
    expect(piecesText([1400, 2600, 2600, 900]), '2600×2 + 1400 + 900');
    expect(piecesText([]), '');
    expect(piecesText([500]), '500');
  });

  test('새 원자재 표: 번호, 배치, 사용, 남는 길이(톱날 손실 뺌)', () {
    final r = optimizeCutting(
      pieces: [2600, 2600, 700],
      stockLength: 6000,
      kerf: 10,
    );
    expect(planRows(r), [
      ['1번 (6000)', '2600×2 + 700', '5900', '70'],
    ]);
    expect(planSummary(r), '새 원자재 1본(6000mm)');
  });

  test('남은 토막이 먼저 나오고 요약에 개수가 들어간다', () {
    final r = optimizeCutting(
      pieces: [900, 5000],
      stockLength: 6000,
      leftovers: [1000],
    );
    final rows = planRows(r);
    expect(rows.first, ['남은 토막 1000', '900', '900', '100']);
    expect(rows.last.first, '1번 (6000)');
    expect(planSummary(r), '새 원자재 1본(6000mm), 남은 토막 1개 사용');
  });

  test('표에 나온 조각을 모두 더하면 입력과 같다', () {
    final input = <double>[1200, 1200, 3100, 800, 800, 800, 2500];
    final r = optimizeCutting(pieces: input, stockLength: 6000);
    final used = planRows(r).fold(0.0, (s, row) => s + double.parse(row[2]));
    expect(used, input.fold(0.0, (s, p) => s + p));
  });
}
