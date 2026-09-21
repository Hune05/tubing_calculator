// 끝 직관이 앞 벤드 셋백보다 짧으면 벤드가 끝나기 전에 자르게 된다.
// R100·[500 90°, 50 직관]은 예전에 아무 경고 없이 507.08로 잘렸다.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/calculator/bend_check.dart';

List<Map<String, dynamic>> bends(List<List<double>> rows) => [
  for (final r in rows) {'length': r[0], 'angle': r[1], 'rotation': r[2]},
];

void main() {
  test('50mm 끝 직관(셋백 100): 경고', () {
    final c = checkBends(
      bends([
        [500, 90, 0],
        [50, 0, 0],
      ]),
      radius: 100,
      startDir: 'RIGHT',
    );
    expect(
      c.warnings,
      contains('2번 구간: 앞 벤드를 빼면 곧은 부분이 -50.0mm입니다. 이대로 자르면 벤드가 끝나기 전에 잘립니다.'),
    );
  });

  test('셋백보다 길면 말하지 않는다', () {
    final c = checkBends(
      bends([
        [500, 90, 0],
        [150, 0, 0],
      ]),
      radius: 100,
      startDir: 'RIGHT',
    );
    expect(c.warnings.where((w) => w.contains('앞 벤드를 빼면')), isEmpty);
  });

  test('45°는 셋백 41.4로 본다', () {
    final c = checkBends(
      bends([
        [500, 45, 0],
        [30, 0, 0],
      ]),
      radius: 100,
      startDir: 'RIGHT',
    );
    expect(c.warnings.join(), contains('-11.4mm'));
  });

  test('길이 0 빈 직관은 보지 않는다', () {
    final c = checkBends(
      bends([
        [500, 90, 0],
        [0, 0, 0],
      ]),
      radius: 100,
      startDir: 'RIGHT',
    );
    expect(c.warnings.where((w) => w.contains('앞 벤드를 빼면')), isEmpty);
  });
}
