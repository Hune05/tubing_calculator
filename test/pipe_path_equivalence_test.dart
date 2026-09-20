// 그림이 쓰던 옛 공간 걷기와, 마킹이 쓰는 새 걷기가 같은 형상을 내는지 본다.
// 그림 코드를 한 곳으로 모으기 전에, 형상이 바뀌지 않는지 확인하려고 둔다.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/calculator/bend_check.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/pipe_path_points.dart';
import 'package:vector_math/vector_math_64.dart' as vmath;

vmath.Vector3 _dirFor(double rot) {
  if (rot == 0.0) return vmath.Vector3(0, 1, 0);
  if (rot == 90.0) return vmath.Vector3(1, 0, 0);
  if (rot == 180.0) return vmath.Vector3(0, -1, 0);
  if (rot == 270.0) return vmath.Vector3(-1, 0, 0);
  if (rot == 360.0) return vmath.Vector3(0, 0, 1);
  if (rot == 450.0) return vmath.Vector3(0, 0, -1);
  return vmath.Vector3(1, 0, 0);
}

vmath.Vector3 _startFor(String d) {
  switch (d) {
    case 'UP':
      return vmath.Vector3(0, 1, 0);
    case 'DOWN':
      return vmath.Vector3(0, -1, 0);
    case 'LEFT':
      return vmath.Vector3(-1, 0, 0);
    case 'FRONT':
      return vmath.Vector3(0, 0, 1);
    case 'BACK':
      return vmath.Vector3(0, 0, -1);
    default:
      return vmath.Vector3(1, 0, 0);
  }
}

/// 그림이 쓰던 옛 걷기(사원수로 −각도).
List<vmath.Vector3> _oldWalk(
  List<Map<String, dynamic>> bendList,
  String startDir, {
  double tail = 0.0,
}) {
  final pts = <vmath.Vector3>[];
  var pos = vmath.Vector3.zero();
  pts.add(pos.clone());
  var dir = _startFor(startDir);

  for (final bend in bendList) {
    final len = (bend['length'] as num).toDouble();
    final angle = (bend['angle'] as num).toDouble();
    final rot = (bend['rotation'] as num).toDouble();

    pos += dir * len;
    pts.add(pos.clone());

    if (angle > 0) {
      final target = _dirFor(rot);
      var axis = dir.cross(target);
      if (axis.length2 > 0.001) {
        axis.normalize();
        final q = vmath.Quaternion.axisAngle(axis, -angle * math.pi / 180.0);
        dir = q.rotate(dir)..normalize();
      } else if (dir.dot(target) < -0.9) {
        var fb = vmath.Vector3(0, 0, 1);
        if (dir.cross(fb).length2 < 0.001) fb = vmath.Vector3(0, 1, 0);
        axis = dir.cross(fb)..normalize();
        final q = vmath.Quaternion.axisAngle(axis, -angle * math.pi / 180.0);
        dir = q.rotate(dir)..normalize();
      }
    }
  }

  if (tail > 0) {
    pos += dir * tail;
    pts.add(pos.clone());
  }
  return pts;
}

List<Map<String, dynamic>> bends(List<List<double>> rows) => [
  for (final r in rows) {'length': r[0], 'angle': r[1], 'rotation': r[2]},
];

void main() {
  final shapes = <String, List<Map<String, dynamic>>>{
    '90° 하나': bends([
      [500, 90, 0],
      [300, 0, 0],
    ]),
    'ㄷ자': bends([
      [500, 90, 0],
      [300, 90, 270],
      [500, 0, 0],
    ]),
    '45° 오프셋': bends([
      [400, 45, 0],
      [141.42, 45, 90],
      [400, 0, 0],
    ]),
    '3점 새들': bends([
      [400, 22.5, 0],
      [200, 45, 180],
      [200, 22.5, 0],
      [400, 0, 0],
    ]),
    '세 평면': bends([
      [400, 90, 0],
      [300, 90, 360],
      [200, 90, 90],
      [200, 0, 0],
    ]),
    '완만한 각': bends([
      [400, 10, 0],
      [400, 10, 180],
      [400, 0, 0],
    ]),
    '급한 각': bends([
      [400, 120, 0],
      [400, 0, 0],
    ]),
    '직선이 낀 형상': bends([
      [300, 0, 0],
      [400, 90, 0],
      [300, 0, 0],
      [400, 90, 90],
      [300, 0, 0],
    ]),
  };

  for (final startDir in const ['RIGHT', 'UP', 'FRONT']) {
    group('시작 $startDir · 옛 그림 셈과 새 셈이 같다', () {
      shapes.forEach((name, list) {
        test(name, () {
          // 그 시작 방향에서 꺾을 수 없는 형상이면 견주지 않는다.
          // 옛 그림은 그런 형상도 제멋대로 꺾어 그렸다(아래 따로 확인).
          final check = checkBends(list, radius: 0, startDir: startDir);
          if (check.warnings.any((w) => w.contains('꺾을 수 없습니다'))) return;

          final oldPts = _oldWalk(list, startDir);
          final newPts = pipePathPoints(list, startDir: startDir);
          expect(newPts.length, oldPts.length, reason: '$name: 꼭짓점 수');
          for (var i = 0; i < oldPts.length; i++) {
            expect(newPts[i].x, closeTo(oldPts[i].x, 0.01), reason: '$name #$i x');
            expect(newPts[i].y, closeTo(oldPts[i].y, 0.01), reason: '$name #$i y');
            expect(newPts[i].z, closeTo(oldPts[i].z, 0.01), reason: '$name #$i z');
          }
        });
      });

      test('꺾을 수 없는 방향이면 그림도 꺾지 않는다', () {
        // 위로 가는데 다시 "아래"로 꺾으라고 하면 꺾을 평면이 안 정해진다.
        // 옛 그림은 아무 평면이나 골라 꺾어서, 만들 수 없는 형상을
        // 만들 수 있는 것처럼 그려 줬다.
        final list = bends([
          [400, 90, 0],
          [400, 90, 180],
          [400, 0, 0],
        ]);
        final pts = pipePathPoints(list, startDir: 'UP');
        // 세 마디가 모두 한 방향(위)으로 곧게 간다.
        expect(pts.last.y, closeTo(1200, 0.01));
        expect(pts.last.x, closeTo(0, 0.01));
        expect(pts.last.z, closeTo(0, 0.01));
      });

      test('꼬리까지 붙여도 같다', () {
        final list = shapes['90° 하나']!;
        final oldPts = _oldWalk(list, startDir, tail: 250);
        final newPts = pipePathPoints(list, startDir: startDir, tail: 250);
        expect(newPts.length, oldPts.length);
        expect(newPts.last.x, closeTo(oldPts.last.x, 0.01));
        expect(newPts.last.y, closeTo(oldPts.last.y, 0.01));
        expect(newPts.last.z, closeTo(oldPts.last.z, 0.01));
      });
    });
  }
}
