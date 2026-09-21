// 퀵 U-Bend를 입력 목록에 넣는 셈(90° 두 번)이 마킹 엔진·손셈과 맞는지 본다.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/core/engine/tube_bending_engine.dart';
import 'package:tubing_calculator/src/presentation/calculator/bend_check.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_quick_u_bend_bottom_sheet.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/u_bend_plan.dart';

const double r = 38.1;

Map<String, dynamic> run(List<Map<String, double>> list, double gain) =>
    TubeBendingEngine(radius: r, userGain90: gain).calculate([
      for (final b in list)
        BendInstruction(
          length: b['length']!,
          angle: b['angle']!,
          rotation: b['rotation']!,
        ),
    ], 0);

List<double> marks(Map<String, dynamic> res) => [
  for (final s in res['steps'] as List)
    if ((s as StepResult).targetAngle > 0) s.markingPoint,
];

void main() {
  group('U-Bend 줄 만들기', () {
    test('빈 목록·오른쪽으로 출발·위로 U: 1번 마킹 = 시작 직관, 절단 = 앞+뒤+πR', () {
      final segs = uBendSegments(
        startStraight: 200,
        returnStraight: 150,
        radius: r,
        turn: 0, // UP
        travel: 90, // RIGHT
      );
      expect(segs[1]['rotation'], 270); // 돌아오는 쪽은 LEFT
      final res = run(segs, 0);
      final m = marks(res);
      expect(m[0], closeTo(200, 1e-6));
      expect(m[1], closeTo(200 + math.pi * r / 2, 1e-6));
      expect(
        res['totalCutLength'] as double,
        closeTo(200 + 150 + math.pi * r, 1e-6),
      );
      // U-Bend 계산기 숫자와 같다.
      expect(
        res['totalCutLength'] as double,
        closeTo(200 + 150 + uBendAllowance(radius: r), 1e-6),
      );
      expect(res['warnings'], isEmpty);
    });

    test('실측 게인 12: 90°당 2R−12씩 먹고, 계산기와 마킹 탭 절단이 같다', () {
      final segs = uBendSegments(
        startStraight: 200,
        returnStraight: 150,
        radius: r,
        turn: 0,
        travel: 90,
      );
      final res = run(segs, 12);
      final m = marks(res);
      expect(m[0], closeTo(200, 1e-6));
      expect(m[1], closeTo(200 + (2 * r - 12), 1e-6));
      final double sheet =
          200 + 150 + uBendAllowance(radius: r, measuredGain90: 12);
      expect(sheet, closeTo(350 + 2 * (2 * r - 12), 1e-6));
      expect(res['totalCutLength'] as double, closeTo(sheet, 1e-6));
    });

    test('형상 점검에 걸리지 않는다(두 번째 벤드가 나란하지 않다)', () {
      final segs = uBendSegments(
        startStraight: 200,
        returnStraight: 150,
        radius: r,
        turn: 360, // FRONT
        travel: 90,
      );
      final c = checkBends(
        segs,
        radius: r,
        startDir: 'RIGHT',
        outerDiameter: 9.53,
      );
      expect(c.warnings, isEmpty);
    });

    test('앞이 90° 벤드면 그 셋백을 더해, U 앞 곧은 길이가 입력값 그대로다', () {
      final List<Map<String, double>> list = [
        {'length': 300, 'angle': 90, 'rotation': 0}, // 위로 꺾음
      ];
      final travel = travelRotation(list, startDir: 'RIGHT', radius: r);
      expect(travel, 0); // 지금 위로 간다
      final segs = uBendSegments(
        startStraight: 120,
        returnStraight: 0,
        radius: r,
        turn: 90, // RIGHT로 U
        travel: travel!,
        prevSetback: lastSetback(list, r),
      );
      expect(segs.length, 2); // 복귀 직관 0이면 넣지 않는다
      expect(segs[1]['rotation'], 180); // 아래로 돌아온다
      final res = run([...list, ...segs], 0);
      final steps = (res['steps'] as List).cast<StepResult>();
      expect(steps[1].straightPart, closeTo(120, 1e-6));
      expect(steps[2].straightPart, closeTo(0, 1e-6));
    });
  });

  group('지금 진행 방향', () {
    test('빈 목록이면 시작 방향', () {
      expect(travelRotation([], startDir: 'RIGHT', radius: r), 90);
      expect(travelRotation([], startDir: 'FRONT', radius: r), 360);
      expect(rotationForName('BACK'), 450);
    });

    test('비스듬히(45°) 가고 있으면 null', () {
      expect(
        travelRotation(
          [
            {'length': 300.0, 'angle': 45.0, 'rotation': 0.0},
          ],
          startDir: 'RIGHT',
          radius: r,
        ),
        isNull,
      );
    });
  });

  group('화면', () {
    Future<List<String>> pumpSheet(
      WidgetTester tester,
      double width, {
      bool withApply = true,
    }) async {
      final errors = <String>[];
      final old = FlutterError.onError;
      FlutterError.onError = (d) =>
          errors.add(d.exceptionAsString().split('\n').first);
      try {
        await tester.binding.setSurfaceSize(Size(width, 1600));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MobileQuickUBendBottomSheet(
                onAddMultipleBends: withApply ? (_) {} : null,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      } finally {
        FlutterError.onError = old;
      }
      return errors;
    }

    for (final w in [320.0, 390.0]) {
      testWidgets('폭 ${w.toInt()}에서 넘치지 않고 방향·넣기 단추가 보인다', (tester) async {
        final errors = await pumpSheet(tester, w);
        expect(errors, isEmpty);
        expect(find.byKey(const Key('u_bend_apply')), findsOneWidget);
        expect(find.byKey(const Key('u_turn_UP')), findsOneWidget);
        expect(find.text('닫기'), findsOneWidget);
        await tester.binding.setSurfaceSize(null);
      });
    }

    testWidgets('넣을 곳이 없으면(값만 보기) 넣기 단추·방향이 없다', (tester) async {
      final errors = await pumpSheet(tester, 390, withApply: false);
      expect(errors, isEmpty);
      expect(find.byKey(const Key('u_bend_apply')), findsNothing);
      expect(find.byKey(const Key('u_turn_UP')), findsNothing);
      await tester.binding.setSurfaceSize(null);
    });
  });
}
