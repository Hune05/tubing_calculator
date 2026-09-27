// 전선관 벤딩 고침(2026-09-27): 3점 새들 가운데를 장애물 중심 위에, 4점 새들은 첫 오프셋 몫만 더함,
// 90°를 넘는 벤드는 막고(입력 상한), 예전 목록은 마킹 메모로 알림. 튜브 새들 셈은 그대로.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/core/engine/bend_geometry.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/bend_sheet_specs.dart';
import 'package:tubing_calculator/src/presentation/conduit/conduit_marking_logic.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_input_tab.dart';

Map<String, dynamic> emt22() => {
  'benderType': 'hand',
  'clr': 114.3,
  'takeUp': 152.4,
  'gain': 82.5,
  'applyShrink': true,
  'applySpringback': false,
};

void main() {
  final s = emt22();
  final conduit = BendSheetSpecs.conduit(s);

  group('3점 새들(전선관): 가운데 꺾이는 점이 장애물 중심 위', () {
    for (final (h, a3) in [
      (50.0, 45.0),
      (100.0, 45.0),
      (100.0, 60.0),
      (200.0, 60.0),
    ]) {
      test('H$h 가운데 $a3°, 장애물 중심 600', () {
        final side = a3 / 2;
        final rad = side * math.pi / 180;
        final run = h / math.tan(rad);
        final travel = h / math.sin(rad);
        final shrinkTotal = 2 * (travel - run);
        final first = conduit.saddle3FirstLength(600, h, a3, shrinkTotal);
        // 첫 꺾이는 점 + 옆 전진 = 가운데 꺾이는 점(수평) = 600.
        expect(first + run, closeTo(600, 1e-9));
        // 관행: 가운데 마킹 눈금(관 따라) = 중심 + 한쪽 수축.
        expect(first + travel, closeTo(600 + (travel - run), 1e-9));
        // 마킹 셈에 넣으면 1번 마킹 = 첫 꺾이는 점 − 테이크업(옆 각).
        final marks = calculateConduitMarkings([
          {'length': first, 'angle': side, 'rotation': 0.0},
          {'length': travel, 'angle': a3, 'rotation': 180.0},
          {'length': travel, 'angle': side, 'rotation': 0.0},
        ], s);
        expect(
          marks.first['mark'] as double,
          closeTo(first - conduitMarkOffset(side, s), 1e-9),
        );
      });
    }

    test('예전 셈(1번 마킹에 총 수축)보다 총 수축만큼 앞에 온다', () {
      const h = 100.0, a3 = 45.0;
      final rad = (a3 / 2) * math.pi / 180;
      final run = h / math.tan(rad);
      final shrinkTotal = 2 * (h / math.sin(rad) - run);
      final start = 600 - run - conduitMarkOffset(a3 / 2, s);
      final old = conduit.firstLength(start, a3 / 2, shrinkTotal);
      final now = conduit.saddle3FirstLength(600, h, a3, shrinkTotal);
      expect(old - now, closeTo(shrinkTotal, 1e-9));
      expect(shrinkTotal, closeTo(39.78, 0.01));
    });

    test('장애물 중심을 비우면 1번 마킹을 관 끝(0)에 둔다', () {
      final len = conduit.saddle3FirstLength(0, 100, 45, 39.8);
      expect(len - conduitMarkOffset(22.5, s), closeTo(0, 1e-9));
    });
  });

  test('3점 새들(튜브)은 그대로: 시작 거리가 1번 마킹', () {
    final tube = BendSheetSpecs(
      radius: 38.1,
      gain90: 0,
      markOffset: (a) => bendSetback(38.1, a),
    );
    expect(
      tube.saddle3FirstLength(150, 100, 45, 39.8),
      tube.firstLength(150, 22.5, 39.8),
    );
  });

  test('4점 새들: 1번 마킹 앞에는 첫 오프셋 몫(절반)만', () {
    expect(conduit.saddle4ShrinkBeforeFirst(40), 20);
    // 전선관은 켜진 스위치대로 그 절반을 1번 마킹에 더한다.
    expect(conduit.shrinkToAdd(conduit.saddle4ShrinkBeforeFirst(40)), 20);
  });

  test('전선관은 90°까지', () {
    expect(conduit.maxAngle, 90);
    expect(kConduitMaxAngle, 90);
    final tube = BendSheetSpecs(radius: 38.1, gain90: 0, markOffset: (_) => 0);
    expect(tube.maxAngle, 180);
  });

  test('예전에 저장한 90° 넘는 벤드는 마킹 메모로 알린다', () {
    final marks = calculateConduitMarkings([
      {'length': 300.0, 'angle': 120.0, 'rotation': 0.0},
      {'length': 300.0, 'angle': 45.0, 'rotation': 0.0},
    ], s);
    expect(marks[0]['note'] as String, contains('90°를 넘는 벤드'));
    expect(marks[1]['note'] as String, isNot(contains('90°를 넘는 벤드')));
  });
}
