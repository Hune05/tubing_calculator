// 마킹 엔진 검사.
// ① 손으로 푼 값과 맞는지
// ② 3차원 기하로 따로 걸어 본 값과 맞는지 (조합 형상)
// 여기 값이 바뀌면 현장에 나가는 마킹이 바뀐 것이다.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/core/engine/bend_geometry.dart';
import 'package:tubing_calculator/src/core/engine/tube_bending_engine.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

const double kR = 100.0;

/// 앱이 쓰는 방향 표(0 위, 90 우, 180 아래, 270 좌, 360 앞, 450 뒤).
vm.Vector3 dirFor(double rot) {
  if (rot == 0.0) return vm.Vector3(0, 1, 0);
  if (rot == 90.0) return vm.Vector3(1, 0, 0);
  if (rot == 180.0) return vm.Vector3(0, -1, 0);
  if (rot == 270.0) return vm.Vector3(-1, 0, 0);
  if (rot == 360.0) return vm.Vector3(0, 0, 1);
  if (rot == 450.0) return vm.Vector3(0, 0, -1);
  return vm.Vector3(1, 0, 0);
}

class Seg {
  final double len;
  final double angle;
  final double rot;
  const Seg(this.len, this.angle, this.rot);
}

/// 엔진과 상관없이 3차원으로 직접 걸어 본다(모서리는 반경 R의 호).
({List<double> marks, double developed, vm.Vector3 end, vm.Vector3 dir}) walk(
  List<Seg> segs, {
  double tail = 0.0,
}) {
  var pos = vm.Vector3.zero();
  var dir = vm.Vector3(1, 0, 0);
  final marks = <double>[];
  var developed = 0.0;
  var prevSb = 0.0;

  for (final s in segs) {
    final corner = pos + dir * s.len;
    if (s.angle == 0) {
      developed += s.len - prevSb;
      marks.add(developed);
      pos = corner;
      prevSb = 0.0;
      continue;
    }
    final target = dirFor(s.rot);
    final cross = dir.cross(target);
    final mySb = bendSetback(kR, s.angle);
    developed += s.len - prevSb - mySb;
    marks.add(developed);
    developed += bendArcLength(kR, s.angle);
    if (cross.length > 1e-6) {
      final axis = cross.normalized();
      final rad = s.angle * math.pi / 180.0;
      dir = (dir * math.cos(rad) + axis.cross(dir) * math.sin(rad))
          .normalized();
    }
    pos = corner;
    prevSb = mySb;
  }
  if (tail > 0) {
    developed += tail - prevSb;
    pos = pos + dir * tail;
  }
  return (marks: marks, developed: developed, end: pos, dir: dir);
}

Map<String, dynamic> run(
  List<Seg> segs, {
  double tail = 0.0,
  double gain90 = 0.0,
  double springback = 0.0,
}) {
  return TubeBendingEngine(
    radius: kR,
    userGain90: gain90,
    springbackDeg: springback,
  ).calculate(
    [
      for (final s in segs)
        BendInstruction(length: s.len, angle: s.angle, rotation: s.rot),
    ],
    0,
    tail: tail,
  );
}

void expectSameAsGeometry(List<Seg> segs, {double tail = 0.0}) {
  final t = walk(segs, tail: tail);
  final r = run(segs, tail: tail);
  final steps = r['steps'] as List<StepResult>;
  expect(steps.length, t.marks.length);
  for (var i = 0; i < steps.length; i++) {
    expect(
      steps[i].markingPoint,
      closeTo(t.marks[i], 0.01),
      reason: '${i + 1}번 마킹',
    );
  }
  expect(
    r['totalCutLength'] as double,
    closeTo(t.developed, 0.01),
    reason: '총 절단 길이',
  );
}

void main() {
  group('손계산과 맞추기', () {
    test('90° 하나 · 500mm: 마킹 400, 총 절단 557.08', () {
      final r = run(const [Seg(500, 90, 0)]);
      final steps = r['steps'] as List<StepResult>;
      expect(steps.first.markingPoint, closeTo(400.0, 0.01));
      expect(r['totalCutLength'] as double, closeTo(557.08, 0.01));
    });

    test('90°×2 · 500/600: 마킹 400·957.08, 총 절단 1114.16', () {
      final r = run(const [Seg(500, 90, 0), Seg(600, 90, 90)]);
      final steps = r['steps'] as List<StepResult>;
      expect(steps[0].markingPoint, closeTo(400.0, 0.01));
      expect(steps[1].markingPoint, closeTo(957.08, 0.01));
      expect(r['totalCutLength'] as double, closeTo(1114.16, 0.01));
    });

    test('꼬리는 마지막 셋백을 빼고 더한다 (300 넣으면 +200)', () {
      final without = run(const [Seg(500, 90, 0)]);
      final with300 = run(const [Seg(500, 90, 0)], tail: 300);
      expect(
        (with300['totalCutLength'] as double) -
            (without['totalCutLength'] as double),
        closeTo(200.0, 0.01),
      );
      // 기하로 따로 구한 값과도 같아야 한다.
      expectSameAsGeometry(const [Seg(500, 90, 0)], tail: 300);
    });

    test('실측 게인 45°: 비례 환산(16mm 오차)으로 돌아가지 않는다', () {
      final r = run(const [Seg(500, 45, 0), Seg(600, 45, 0)], gain90: 40);
      final steps = r['steps'] as List<StepResult>;
      // 맞는 환산이면 벤드당 게인 4.01
      expect(steps[0].sectionGain, closeTo(4.01, 0.01));
      // 예전 방식이면 20.0이었다.
      expect(steps[0].sectionGain < 5.0, isTrue);
    });

    test('스프링백은 마킹을 움직이지 않고 꺾을 각도만 바꾼다', () {
      final a = run(const [Seg(500, 90, 0)]);
      final b = run(const [Seg(500, 90, 0)], springback: 5);
      final sa = (a['steps'] as List<StepResult>).first;
      final sb2 = (b['steps'] as List<StepResult>).first;
      expect(sb2.markingPoint, closeTo(sa.markingPoint, 0.001));
      expect(
        b['totalCutLength'] as double,
        closeTo(a['totalCutLength'] as double, 0.001),
      );
      expect(sb2.targetAngle, closeTo(95.0, 0.001));
    });
  });

  group('조합 형상 — 3차원 기하와 대조', () {
    // 오프셋 계산기가 만드는 목록 (45°, 높이 100, 시작 거리 300)
    final travel = 100 / math.sin(45 * math.pi / 180);
    final run45 = 100 / math.tan(45 * math.pi / 180);
    final shrink = travel - run45;

    test('90° 하나 + 꼬리', () {
      expectSameAsGeometry(const [Seg(500, 90, 0)], tail: 300);
    });

    test('오프셋만', () {
      expectSameAsGeometry([
        Seg(300 + shrink, 45, 0),
        Seg(travel, 45, 180),
      ], tail: 300);
    });

    test('90° + 오프셋 (다른 평면)', () {
      expectSameAsGeometry([
        const Seg(500, 90, 0),
        Seg(300 + shrink, 45, 90),
        Seg(travel, 45, 270),
      ], tail: 300);
    });

    test('3점 새들 (45°, 높이 100)', () {
      final sTravel = 100 / math.sin(22.5 * math.pi / 180);
      final sRun = 100 / math.tan(22.5 * math.pi / 180);
      final sShrink = (sTravel - sRun) * 2;
      expectSameAsGeometry([
        Seg(sShrink, 22.5, 0),
        Seg(sTravel, 45, 180),
        Seg(sTravel, 22.5, 0),
      ], tail: 300);
    });

    test('벤드 뒤 직관 구간도 셋백을 뺀다', () {
      expectSameAsGeometry(const [Seg(500, 90, 0), Seg(400, 0, 0)]);
    });

    test('오프셋 형상: 높이 100만큼 올라가고 방향은 그대로', () {
      final t = walk([
        Seg(300 + shrink, 45, 0),
        Seg(travel, 45, 180),
      ], tail: 300);
      expect(t.dir.x, closeTo(1.0, 0.001));
      expect(t.dir.y, closeTo(0.0, 0.001));
      expect(t.end.y, closeTo(100.0, 0.01));
    });
  });

  group('만들 수 없는 형상은 알려 준다', () {
    test('앞뒤 셋백보다 짧은 구간이면 경고가 붙는다', () {
      final r = run(const [
        Seg(500, 90, 0),
        Seg(150, 90, 90), // 셋백 합 200
        Seg(500, 0, 0),
      ]);
      final warnings = r['warnings'] as List<String>;
      expect(warnings.length, 1);
      expect(warnings.first.contains('2번 구간'), isTrue);
      expect(warnings.first.contains('-50.0mm'), isTrue);
    });

    test('멀쩡한 형상에는 경고가 없다', () {
      final r = run(const [Seg(500, 90, 0), Seg(600, 90, 90)]);
      expect((r['warnings'] as List<String>).isEmpty, isTrue);
    });

    test('꼬리가 마지막 셋백보다 짧아도 알려 준다', () {
      final r = run(const [Seg(500, 90, 0)], tail: 50);
      expect((r['warnings'] as List<String>).first.contains('꼬리'), isTrue);
    });
  });
}
