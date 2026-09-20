// 마킹 화면 세 곳이 같이 쓰는 형상 점검.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/calculator/bend_check.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/bend_warning_banner.dart';

List<Map<String, dynamic>> bends(List<List<double>> rows) => [
  for (final r in rows) {'length': r[0], 'angle': r[1], 'rotation': r[2]},
];

void main() {
  group('형상 점검', () {
    test('보통 90°는 아무 말도 하지 않는다', () {
      final c = checkBends(
        bends([
          [600, 90, 0],
          [500, 0, 0],
        ]),
        radius: 38,
        startDir: 'RIGHT',
        outerDiameter: 12.7,
      );
      expect(c.hasWarning, isFalse);
      expect(c.rollByIndex, isEmpty);
    });

    test('엔진 경고를 그대로 실어 준다', () {
      final c = checkBends(
        bends([
          [600, 90, 0],
        ]),
        radius: 38,
        startDir: 'RIGHT',
        engineWarnings: const ['엔진이 한 말'],
      );
      expect(c.warnings, contains('엔진이 한 말'));
    });

    test('한 바퀴 돌아 제자리로 오면 닿는다고 알려 준다', () {
      final c = checkBends(
        bends([
          [200, 90, 0],
          [200, 90, 270],
          [200, 90, 180],
          [200, 0, 0],
        ]),
        radius: 20,
        startDir: 'RIGHT',
        outerDiameter: 12.7,
      );
      expect(c.hasWarning, isTrue);
      expect(c.warnings.any((w) => w.contains('닿습니다')), isTrue);
    });

    test('굵기를 모르면 닿는지는 보지 않는다', () {
      final c = checkBends(
        bends([
          [200, 90, 0],
          [200, 90, 270],
          [200, 90, 180],
          [200, 0, 0],
        ]),
        radius: 20,
        startDir: 'RIGHT',
      );
      expect(c.warnings, isEmpty);
    });

    test('평면이 바뀌면 굴릴 각도를 알려 준다', () {
      // 우 → 위(0) → 앞(360): 평면이 직각으로 바뀐다.
      final c = checkBends(
        bends([
          [600, 90, 0],
          [500, 90, 360],
          [400, 0, 0],
        ]),
        radius: 38,
        startDir: 'RIGHT',
      );
      expect(c.rollByIndex[1], closeTo(90.0, 0.01));
    });

    test('오프셋은 같은 평면이라 굴리지 않는다', () {
      final c = checkBends(
        bends([
          [500, 45, 0],
          [300, 45, 90],
          [500, 0, 0],
        ]),
        radius: 38,
        startDir: 'RIGHT',
      );
      expect(c.rollByIndex, isEmpty);
    });

    test('시작 방향을 따라 형상이 달라진다', () {
      // 시작이 위면 위로는 못 꺾는다.
      final c = checkBends(
        bends([
          [600, 90, 0],
          [400, 0, 0],
        ]),
        radius: 38,
        startDir: 'UP',
      );
      expect(c.warnings.any((w) => w.contains('꺾을 수 없습니다')), isTrue);
    });

    test('배관이 없으면 엔진 말만 넘긴다', () {
      final c = checkBends(
        const [],
        radius: 38,
        startDir: 'RIGHT',
        engineWarnings: const ['빈 목록'],
      );
      expect(c.warnings, ['빈 목록']);
    });
  });

  group('경고 띠', () {
    testWidgets('경고가 없으면 아무것도 안 보인다', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: BendWarningBanner(warnings: [])),
        ),
      );
      expect(find.byKey(const Key('bend_warning_banner')), findsNothing);
    });

    testWidgets('경고가 있으면 줄마다 보여 준다', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BendWarningBanner(warnings: ['첫째 줄', '둘째 줄']),
          ),
        ),
      );
      expect(find.byKey(const Key('bend_warning_banner')), findsOneWidget);
      expect(find.text('이대로는 만들 수 없습니다'), findsOneWidget);
      expect(find.text('첫째 줄'), findsOneWidget);
      expect(find.text('둘째 줄'), findsOneWidget);
    });
  });
}
