// 현장에서 나오는 벤딩 형상을 폭넓게 접어 보고, 마킹 값이 3차원 기하와
// 맞는지 확인한다. 값이 틀리면 현장에서 엉뚱한 자리에 금을 긋게 된다.
//
// 검사 방법: 엔진이 낸 마킹·절단 길이를 `buildBendPath`(엔진과 따로 만든
// 공간 기하)로 다시 걸어 본 값과 견준다. 두 가지가 같은 값을 내야 믿을 수 있다.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/core/engine/bend_geometry.dart';
import 'package:tubing_calculator/src/core/engine/bend_path.dart';
import 'package:tubing_calculator/src/core/engine/tube_bending_engine.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

class Shape {
  final String name;
  final List<PathSegment> segs;
  final double tail;

  const Shape(this.name, this.segs, {this.tail = 0.0});
}

PathSegment seg(double len, double angle, double rot) =>
    PathSegment(length: len, angle: angle, rotation: rot);

Map<String, dynamic> run(
  List<PathSegment> segs, {
  required double radius,
  double tail = 0.0,
  double gain90 = 0.0,
}) {
  return TubeBendingEngine(
    radius: radius,
    userGain90: gain90,
  ).calculate(
    [
      for (final s in segs)
        BendInstruction(length: s.length, angle: s.angle, rotation: s.rotation),
    ],
    0,
    tail: tail,
  );
}

/// 엔진 값과 공간 기하 값이 같은지 본다.
void expectAgrees(Shape sh, {required double radius}) {
  final path = buildBendPath(
    sh.segs,
    radius: radius,
    startDirection: vm.Vector3(1, 0, 0),
    tail: sh.tail,
  );
  final r = run(sh.segs, radius: radius, tail: sh.tail);
  final steps = r['steps'] as List<StepResult>;

  expect(
    r['totalCutLength'] as double,
    closeTo(path.developedLength, 0.01),
    reason: '${sh.name}: 자를 길이',
  );

  // 마킹 지점은 "그 벤드가 시작되는 접점까지의 관 길이"다.
  var acc = 0.0;
  var bi = 0;
  for (var i = 0; i < sh.segs.length; i++) {
    final s = sh.segs[i];
    if (s.angle == 0) {
      acc += s.length - (i == 0 ? 0.0 : bendSetback(radius, sh.segs[i - 1].angle));
      expect(
        steps[i].markingPoint,
        closeTo(acc, 0.01),
        reason: '${sh.name}: ${i + 1}번(직선) 마킹',
      );
      continue;
    }
    final b = path.bends[bi];
    acc += b.straightBefore;
    expect(
      steps[i].markingPoint,
      closeTo(acc, 0.01),
      reason: '${sh.name}: ${i + 1}번 마킹',
    );
    acc += bendArcLength(radius, s.angle);
    bi++;
  }
}

/// 만들 수 없다고 하지 않아야 하는 형상인지.
void expectMakeable(Shape sh, {required double radius}) {
  final path = buildBendPath(
    sh.segs,
    radius: radius,
    startDirection: vm.Vector3(1, 0, 0),
    tail: sh.tail,
  );
  expect(path.warnings, isEmpty, reason: '${sh.name}: ${path.warnings}');
}

void main() {
  // 3/8" 튜브 기준 반경 38, 1/2" 전선관 기준 반경 100을 같이 돌려 본다.
  for (final radius in const [38.0, 100.0]) {
    final R = radius.toStringAsFixed(0);

    // ── 현장에서 나오는 형상들 ──
    final offsetAngle = 45.0;
    final offsetHeight = 150.0;
    final travel = offsetHeight / math.sin(offsetAngle * math.pi / 180);

    final shapes = <Shape>[
      Shape('곧은 관', [seg(1200, 0, 0)]),
      Shape('90° 하나', [seg(600, 90, 0), seg(500, 0, 0)]),
      Shape('90° 하나 + 꼬리', [seg(600, 90, 0)], tail: 400),
      Shape('Z자(위로 올랐다 다시 수평)', [
        seg(600, 90, 0), // 우 → 위
        seg(500, 90, 90), // 위 → 우
        seg(400, 0, 0),
      ]),
      Shape('ㄷ자(되돌아옴)', [
        seg(600, 90, 0),
        seg(400, 90, 270),
        seg(600, 90, 180),
        seg(300, 0, 0),
      ]),
      Shape('45° 오프셋', [
        seg(500, offsetAngle, 0),
        seg(travel, offsetAngle, 90),
        seg(500, 0, 0),
      ]),
      Shape('30° 오프셋', [
        seg(500, 30, 0),
        seg(offsetHeight / math.sin(30 * math.pi / 180), 30, 90),
        seg(500, 0, 0),
      ]),
      Shape('22.5° 오프셋(완만)', [
        seg(500, 22.5, 0),
        seg(offsetHeight / math.sin(22.5 * math.pi / 180), 22.5, 90),
        seg(500, 0, 0),
      ]),
      Shape('3점 새들', [
        seg(600, 22.5, 0), // 22.5° 올린다
        seg(260, 45, 180), // 가운데 45° 내린다
        seg(260, 22.5, 0), // 22.5° 올려 제자리
        seg(600, 0, 0),
      ]),
      Shape('4점 새들', [
        seg(600, 30, 0), // 30° 올린다
        seg(300, 30, 180), // 수평(장애물 위)
        seg(400, 30, 180), // 30° 내린다
        seg(300, 30, 0), // 수평(제자리 높이)
        seg(600, 0, 0),
      ]),
      Shape('오프셋 뒤 90°(다른 평면)', [
        seg(500, offsetAngle, 0),
        seg(travel, offsetAngle, 90),
        seg(500, 90, 360),
        seg(400, 0, 0),
      ]),
      Shape('90° 뒤 오프셋', [
        seg(600, 90, 0),
        seg(500, offsetAngle, 90),
        seg(travel, offsetAngle, 0),
        seg(400, 0, 0),
      ]),
      Shape('롤링 오프셋(앞·위 동시)', [
        seg(500, 45, 0),
        seg(300, 45, 360),
        seg(500, 0, 0),
      ]),
      Shape('계단 세 칸', [
        seg(400, 45, 0),
        seg(212, 45, 90),
        seg(400, 45, 0),
        seg(212, 45, 90),
        seg(400, 0, 0),
      ]),
      Shape('위아래로 지그재그', [
        seg(500, 30, 0),
        seg(400, 60, 180),
        seg(400, 30, 0),
        seg(500, 0, 0),
      ]),
      Shape('세 평면을 다 쓰는 형상', [
        seg(600, 90, 0), // 우 → 위
        seg(500, 90, 360), // 위 → 앞
        seg(400, 90, 90), // 앞 → 우
        seg(300, 0, 0),
      ]),
      Shape('직선 구간이 사이에 낀 형상', [
        seg(400, 0, 0),
        seg(500, 90, 0),
        seg(300, 0, 0),
        seg(400, 90, 90),
        seg(500, 0, 0),
      ]),
      Shape('아주 완만한 각(10°)', [
        seg(600, 10, 0),
        seg(600, 10, 180),
        seg(600, 0, 0),
      ]),
      Shape('급한 각(120°)', [seg(700, 120, 0), seg(700, 0, 0)]),
      Shape('꼬리까지 붙인 오프셋', [
        seg(500, offsetAngle, 0),
        seg(travel, offsetAngle, 90),
      ], tail: 500),
    ];

    group('R=$R · 엔진과 공간 기하가 같은 값을 낸다', () {
      for (final sh in shapes) {
        test(sh.name, () => expectAgrees(sh, radius: radius));
      }
    });

    group('R=$R · 만들 수 있는 형상으로 낸다', () {
      for (final sh in shapes) {
        test(sh.name, () => expectMakeable(sh, radius: radius));
      }
    });

    group('R=$R · 형상이 실제로 도면대로 나온다', () {
      test('90° 한 번이면 처음 방향과 직각으로 끝난다', () {
        final p = buildBendPath(
          [seg(600, 90, 0), seg(500, 0, 0)],
          radius: radius,
          startDirection: vm.Vector3(1, 0, 0),
        );
        expect(p.endDirection.dot(vm.Vector3(0, 1, 0)), closeTo(1.0, 1e-9));
      });

      test('오프셋은 방향이 그대로고 높이만 올라간다', () {
        final p = buildBendPath(
          [
            seg(500, offsetAngle, 0),
            seg(travel, offsetAngle, 90),
            seg(500, 0, 0),
          ],
          radius: radius,
          startDirection: vm.Vector3(1, 0, 0),
        );
        expect(p.endDirection.dot(vm.Vector3(1, 0, 0)), closeTo(1.0, 1e-9));
        expect(p.endPoint.y, closeTo(offsetHeight, 0.01));
        expect(p.endPoint.z, closeTo(0.0, 1e-9));
      });

      test('3점 새들은 높이 0으로 돌아온다', () {
        final p = buildBendPath(
          [
            seg(600, 22.5, 0),
            seg(260, 45, 180),
            seg(260, 22.5, 0),
            seg(600, 0, 0),
          ],
          radius: radius,
          startDirection: vm.Vector3(1, 0, 0),
        );
        expect(p.endPoint.y, closeTo(0.0, 0.01));
        expect(p.endDirection.dot(vm.Vector3(1, 0, 0)), closeTo(1.0, 1e-9));
      });

      test('3점 새들은 한 평면에서만 꺾으므로 굴리지 않는다', () {
        final p = buildBendPath(
          [
            seg(600, 22.5, 0),
            seg(260, 45, 180),
            seg(260, 22.5, 0),
            seg(600, 0, 0),
          ],
          radius: radius,
          startDirection: vm.Vector3(1, 0, 0),
        );
        for (final b in p.bends) {
          expect(b.rollDeg, closeTo(0.0, 0.01));
        }
      });

      test('오프셋도 같은 평면이라 굴리지 않는다', () {
        final p = buildBendPath(
          [
            seg(500, offsetAngle, 0),
            seg(travel, offsetAngle, 90),
            seg(500, 0, 0),
          ],
          radius: radius,
          startDirection: vm.Vector3(1, 0, 0),
        );
        expect(p.bends[1].rollDeg, closeTo(0.0, 0.01));
      });

      test('ㄷ자는 처음 방향의 정반대로 끝난다', () {
        final p = buildBendPath(
          [seg(600, 90, 0), seg(400, 90, 270), seg(600, 0, 0)],
          radius: radius,
          startDirection: vm.Vector3(1, 0, 0),
        );
        expect(p.endDirection.dot(vm.Vector3(-1, 0, 0)), closeTo(1.0, 1e-9));
      });

      test('오프셋 뒤 90°를 앞으로 꺾으면 평면이 바뀌어 굴림이 생긴다', () {
        final p = buildBendPath(
          [
            seg(500, offsetAngle, 0),
            seg(travel, offsetAngle, 90),
            seg(500, 90, 360),
            seg(400, 0, 0),
          ],
          radius: radius,
          startDirection: vm.Vector3(1, 0, 0),
        );
        expect(p.bends.length, 3);
        // 앞 두 벤드는 같은 평면 — 굴림 없음.
        expect(p.bends[1].rollDeg, closeTo(0.0, 0.01));
        // 세 번째는 평면이 직각으로 바뀐다.
        expect(p.bends[2].rollDeg, closeTo(90.0, 0.01));
      });
    });
  }

  group('실측 게인을 넣어도 형상은 그대로다', () {
    // 실측 게인은 자를 길이만 줄인다. 어디서 꺾느냐(형상)는 바뀌지 않는다.
    const segs = [
      PathSegment(length: 600, angle: 90, rotation: 0),
      PathSegment(length: 500, angle: 90, rotation: 90),
      PathSegment(length: 400, angle: 0, rotation: 0),
    ];

    test('게인을 넣으면 자를 길이가 짧아진다', () {
      final plain = run(segs, radius: 38) ['totalCutLength'] as double;
      final withGain =
          run(segs, radius: 38, gain90: 40) ['totalCutLength'] as double;
      expect(withGain, lessThan(plain));
    });

    test('90°가 두 번이면 게인도 두 번 빠진다', () {
      final plain = run(segs, radius: 38) ['totalCutLength'] as double;
      final withGain =
          run(segs, radius: 38, gain90: 40) ['totalCutLength'] as double;
      // 기하 게인(2·셋백 − 호) 대신 실측 40mm가 벤드마다 쓰인다.
      final geo = geometricGain(38, 90);
      expect(plain - withGain, closeTo((40 - geo) * 2, 0.01));
    });

    test('45°에서는 게인이 비례가 아니라 기하 비율로 줄어든다', () {
      const one = [
        PathSegment(length: 600, angle: 45, rotation: 0),
        PathSegment(length: 500, angle: 0, rotation: 0),
      ];
      final plain = run(one, radius: 38) ['totalCutLength'] as double;
      final withGain =
          run(one, radius: 38, gain90: 40) ['totalCutLength'] as double;
      final used = plain - withGain + geometricGain(38, 45);
      // 40 × (2tan22.5 − 0.7854)/(2 − π/2) = 4.01 — 비례로 치면 20이 나온다.
      expect(used, closeTo(scaleMeasuredGain(40, 45), 0.01));
      expect(used, lessThan(10));
    });
  });

  group('만들 수 없는 형상은 만들 수 없다고 한다', () {
    test('앞뒤 셋백보다 짧은 구간', () {
      final p = buildBendPath(
        [seg(600, 90, 0), seg(120, 90, 90), seg(400, 0, 0)],
        radius: 100,
        startDirection: vm.Vector3(1, 0, 0),
      );
      expect(p.warnings, isNotEmpty);
      expect(p.warnings.first, contains('만들 수 없습니다'));
    });

    test('진행 방향과 같은 쪽으로는 못 꺾는다', () {
      final p = buildBendPath(
        [seg(600, 90, 0), seg(400, 90, 0), seg(400, 0, 0)],
        radius: 38,
        startDirection: vm.Vector3(1, 0, 0),
      );
      expect(p.warnings.any((w) => w.contains('꺾을 수 없습니다')), isTrue);
    });

    test('표에 없는 방향값은 걸러낸다', () {
      final p = buildBendPath(
        [seg(600, 90, 135), seg(400, 0, 0)],
        radius: 38,
        startDirection: vm.Vector3(1, 0, 0),
      );
      expect(p.warnings.any((w) => w.contains('쓸 수 없는 값')), isTrue);
    });
  });
}
