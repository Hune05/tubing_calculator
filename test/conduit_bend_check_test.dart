// 전선관 마킹 탭 위 "이대로는 만들 수 없습니다" 띠 검사.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/conduit/conduit_marking_logic.dart';

final Map<String, dynamic> kSettings = {
  'benderType': 'hand',
  'takeUp': 152.4,
  'clr': 114.3,
  'gain': 81.2,
  'applySpringback': false,
  'conduitSize': '22mm',
};

List<Map<String, dynamic>> bends(List<List<double>> rows) => [
  for (final r in rows) {'length': r[0], 'angle': r[1], 'rotation': r[2]},
];

void main() {
  test('제대로 넣은 오프셋은 아무 말 없다', () {
    final c = conduitBendCheck(
      bends([
        [150, 0, 0],
        [72.3, 21, 0],
        [195.3, 21, 180],
        [200, 0, 0],
      ]),
      kSettings,
    );
    expect(c.warnings, isEmpty);
  });

  test('직관 뒤의 짧은 구간은 한 줄로 이어진 관이라 경고하지 않는다', () {
    // 예전 셈으로 넣었던 7.06. 따로 보면 곧은 부분 -14mm로 잡혔다.
    final c = conduitBendCheck(
      bends([
        [150, 0, 0],
        [7.06, 21, 0],
        [195.3, 21, 180],
        [200, 0, 0],
      ]),
      kSettings,
    );
    expect(c.warnings, isEmpty);
  });

  test('90° 두 번 사이가 짧으면 잡고, 구간 번호는 입력 목록 번호다', () {
    // CLR 114.3이면 90° 둘 사이에 228.6mm가 있어야 한다.
    final c = conduitBendCheck(
      bends([
        [300, 0, 0],
        [500, 90, 0],
        [200, 90, 90],
        [300, 0, 0],
      ]),
      kSettings,
    );
    expect(c.warnings, isNotEmpty);
    expect(c.warnings.first, contains('3번 구간'));
    expect(c.warnings.first, contains('만들 수 없습니다'));
  });

  test('사이가 넉넉하면 괜찮다', () {
    final c = conduitBendCheck(
      bends([
        [500, 90, 0],
        [250, 90, 90],
        [300, 0, 0],
      ]),
      kSettings,
    );
    expect(c.warnings, isEmpty);
  });

  test('직관이 여럿 이어져도 합쳐서 본다', () {
    final c = conduitBendCheck(
      bends([
        [100, 0, 0],
        [100, 0, 0],
        [10, 45, 0],
        [400, 0, 0],
      ]),
      kSettings,
    );
    expect(c.warnings, isEmpty);
  });

  test('빈 목록이면 아무 말 없다', () {
    expect(conduitBendCheck(const [], kSettings).warnings, isEmpty);
  });
}
