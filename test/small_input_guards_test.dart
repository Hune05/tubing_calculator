// 큰 값·긴 숫자에서 멈추거나 예외가 나던 곳(10-07 앱 전체 점검 38번).
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/electrical/cable_tray.dart';
import 'package:tubing_calculator/src/presentation/electrical/cable_tray_painter.dart';
import 'package:tubing_calculator/src/presentation/unit_converter/unit_defs.dart';

void main() {
  test('인치 분수 칸에 아주 긴 숫자를 넣어도 예외 없이 못 읽음(null)', () {
    expect(parseInches('1/99999999999999999999'), isNull);
    expect(parseInches('3 1/2'), closeTo(3.5, 1e-9));
  });

  test('트레이 가닥 수가 1억이어도 그림 상한만큼만 놓고 바로 끝난다', () {
    final sw = Stopwatch()..start();
    final l = layoutTray(
      [const TrayCable(name: 'A', od: 20, size: 35, cores: 1, count: 100000000)],
      600,
      100,
      singleLayer: false,
    );
    expect(sw.elapsedMilliseconds, lessThan(1000));
    expect(l.dots.length + l.hidden, 100000000);
  });
}
