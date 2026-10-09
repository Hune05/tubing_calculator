// 공학용 계산기 현장 도구: 직각삼각형 풀이·볼트 구멍 원·메모리 칸(10-09).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/field_tools/eng_calculator_page.dart';
import 'package:tubing_calculator/src/presentation/field_tools/eng_tools.dart';
import 'package:tubing_calculator/src/presentation/field_tools/eng_tools_page.dart';

void main() {
  group('직각삼각형', () {
    test('3·4·5와 각도', () {
      final t = solveRightTriangle(rise: 300, run: 400);
      expect(t.hyp, closeTo(500, 1e-9));
      expect(t.angle, closeTo(36.8699, 1e-4));
      expect(t.otherAngle, closeTo(53.1301, 1e-4));
      expect(t.slopePercent, closeTo(75, 1e-9));
    });

    test('어느 두 값이든 같은 삼각형', () {
      for (final t in [
        solveRightTriangle(rise: 300, hyp: 500),
        solveRightTriangle(run: 400, hyp: 500),
        solveRightTriangle(rise: 300, angle: 36.86989764584402),
        solveRightTriangle(run: 400, angle: 36.86989764584402),
        solveRightTriangle(hyp: 500, angle: 36.86989764584402),
      ]) {
        expect(t.rise, closeTo(300, 1e-6));
        expect(t.run, closeTo(400, 1e-6));
        expect(t.hyp, closeTo(500, 1e-6));
      }
    });

    test('잘못 넣으면 까닭', () {
      expect(() => solveRightTriangle(rise: 300), throwsA(isA<TriangleError>()));
      expect(() => solveRightTriangle(rise: 3, run: 4, hyp: 5), throwsA(isA<TriangleError>()));
      expect(() => solveRightTriangle(rise: 600, hyp: 500), throwsA(isA<TriangleError>()));
      expect(() => solveRightTriangle(rise: 300, angle: 90), throwsA(isA<TriangleError>()));
    });
  });

  group('볼트 구멍 원', () {
    test('PCD 200 구멍 4개 12시에 1번: 위·오른쪽·아래·왼쪽', () {
      final h = boltCircle(200, 4);
      expect([for (final x in h) (x.x.round(), x.y.round())], [(0, 100), (100, 0), (0, -100), (-100, 0)]);
      expect(boltPitch(200, 4), closeTo(141.4214, 1e-4));
    });

    test('양쪽 걸침: 구멍 8개면 1번이 22.5°', () {
      final h = boltCircle(200, 8, start: straddleStart(8));
      expect(h.first.angle, 22.5);
      expect(h.first.x, closeTo(38.2683, 1e-4));
      expect(h.first.y, closeTo(92.3880, 1e-4));
      expect(h.last.angle, 337.5);
    });
  });

  test('메모리 값을 식에 넣는 글: 반올림 없이, 음수는 괄호', () {
    expect(memExprText(12.5), '12.5');
    expect(memExprText(1 / 3), '0.3333333333');
    expect(memExprText(-4), '(−4)');
    expect(memExprText(0), '0');
  });

  group('화면', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('직각삼각형: 두 칸을 넣으면 빗변이 나온다', (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: RightTrianglePage()));
      await tester.enterText(find.byKey(const Key('tri_rise')), '300');
      await tester.enterText(find.byKey(const Key('tri_run')), '400');
      await tester.pump();
      expect(find.text('500 mm'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('tri_hyp')), '500');
      await tester.pump();
      expect(find.textContaining('두 칸만 넣으십시오'), findsOneWidget);
    });

    testWidgets('볼트 구멍 원: 좌표 표', (tester) async {
      tester.view.physicalSize = const Size(400, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: BoltCirclePage()));
      await tester.enterText(find.byKey(const Key('bolt_pcd')), '200');
      await tester.enterText(find.byKey(const Key('bolt_count')), '4');
      await tester.pump();
      expect(find.byKey(const Key('bolt_row_4')), findsOneWidget);
      expect(find.text('141.42 mm'), findsOneWidget);
      await tester.tap(find.byKey(const Key('bolt_start_top')));
      await tester.pump();
      expect(find.text('0°'), findsOneWidget);
    });

    testWidgets('계산기: 빈 메모리 칸을 누르면 지금 값을 담고, 다시 누르면 식에 넣는다', (tester) async {
      tester.view.physicalSize = const Size(400, 860);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: EngCalculatorPage()));
      await tester.pump();
      await tester.pump();
      for (final k in ['calc_1', 'calc_2', 'calc_eq']) {
        await tester.tap(find.byKey(Key(k)));
        await tester.pump();
      }
      await tester.tap(find.byKey(const Key('calc_mem_A')));
      await tester.pump();
      for (final k in ['calc_ac', 'calc_2', 'calc_mul']) {
        await tester.tap(find.byKey(Key(k)));
        await tester.pump();
      }
      await tester.tap(find.byKey(const Key('calc_mem_A')));
      await tester.pump();
      expect(
        tester.widget<Text>(find.byKey(const Key('calc_display_result'))).data,
        '24',
      );
      final p = await SharedPreferences.getInstance();
      expect(p.getStringList('eng_calc_memory_v1')!.first, '12.0');
    });

    testWidgets('계산기 머리에서 현장 도구를 연다', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: EngCalculatorPage()));
      await tester.pump();
      await tester.tap(find.byKey(const Key('calc_tools')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tool_triangle')), findsOneWidget);
      expect(find.byKey(const Key('tool_bolt_circle')), findsOneWidget);
    });

    testWidgets('가로 화면은 넓은 가로 자판(공학 단추·메모리 포함)으로 바뀐다', (tester) async {
      tester.view.physicalSize = const Size(640, 340);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: EngCalculatorPage()));
      await tester.pump();
      expect(find.byKey(const Key('calc_memory_row')), findsNothing);
      // 가로 자판: 공학 단추가 늘 보이고, 메모리는 자판 맨 아래 줄에 있다.
      expect(find.byKey(const Key('calc_landscape_keypad')), findsOneWidget);
      expect(find.byKey(const Key('calc_sin')), findsOneWidget);
      expect(find.byKey(const Key('calc_mem_A')), findsOneWidget);
      for (final k in ['calc_7', 'calc_mul', 'calc_6', 'calc_eq']) {
        await tester.tap(find.byKey(Key(k)));
        await tester.pump();
      }
      expect(tester.widget<Text>(find.byKey(const Key('calc_display_result'))).data, '42');
      // 단추가 콩알만 하지 않다(가로 640×340 작은 폰에서도 높이 30 이상).
      expect(tester.getSize(find.byKey(const Key('calc_7'))).height, greaterThan(30));
    });

    testWidgets('태블릿 가로(1007×560)에서는 지난 계산 기록 줄도 보인다', (tester) async {
      tester.view.physicalSize = const Size(1007, 560);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: EngCalculatorPage()));
      await tester.pump();
      for (final k in ['calc_7', 'calc_mul', 'calc_6', 'calc_eq']) {
        await tester.tap(find.byKey(Key(k)));
        await tester.pump();
      }
      expect(find.byKey(const Key('calc_landscape_keypad')), findsOneWidget);
      expect(find.byKey(const Key('calc_history')), findsOneWidget);
      expect(find.textContaining('= 42'), findsOneWidget);
    });
  });
}
