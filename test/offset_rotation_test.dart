// 오프셋 시트가 두 번째 벤드 방향을 정하는 규칙.
// 앞(360)·뒤(450)를 고르면 예전에는 +180을 해서 아래(180)·좌(270)가 되어
// 관이 틀어졌다. 오프셋이면 끝 방향이 처음 방향과 같아야 한다.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/core/engine/bend_path.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/opposite_rotation.dart';

void main() {
  test('반대 방향 짝', () {
    expect(oppositeRotation(0), 180);
    expect(oppositeRotation(90), 270);
    expect(oppositeRotation(180), 0);
    expect(oppositeRotation(270), 90);
    expect(oppositeRotation(360), 450);
    expect(oppositeRotation(450), 360);
  });

  test('뒤집기를 켜면 1번·2번이 바뀐다', () {
    expect(offsetRotations(360), (360.0, 450.0));
    expect(offsetRotations(360, inverted: true), (450.0, 360.0));
    expect(offsetRotations(0, inverted: true), (180.0, 0.0));
  });

  for (final sel in [0.0, 90.0, 180.0, 270.0, 360.0, 450.0]) {
    for (final inv in [false, true]) {
      test('방향 $sel · 뒤집기 $inv: 오프셋 끝 방향이 처음과 같다', () {
        const h = 100.0;
        final travel = h / math.sin(45 * math.pi / 180);
        final (r1, r2) = offsetRotations(sel, inverted: inv);
        final p = buildBendPath(
          [
            PathSegment(length: 300 + 41.42, angle: 45, rotation: r1),
            PathSegment(length: travel, angle: 45, rotation: r2),
          ],
          radius: 100,
          tail: 300,
        );
        expect(p.endDirection.x, closeTo(1.0, 0.001));
        expect(p.endDirection.y, closeTo(0.0, 0.001));
        expect(p.endDirection.z, closeTo(0.0, 0.001));
      });
    }
  }
}
