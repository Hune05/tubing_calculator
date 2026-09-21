import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/models/cutting_project_model.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_math.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/screens/cutting_main_screen.dart';

import 'helpers_text.dart';

// 튜브 컷팅 계산기 입력 탭: 길이 글자 해석, 절단 길이 계산 과정, 하단 요약 줄.
void main() {
  group('길이 글자 해석', () {
    double? v(String s) => parseLengthInput(s).value;

    test('보통 숫자와 소수', () {
      expect(v('1200'), 1200);
      expect(v('1200.5'), 1200.5);
      expect(v('.5'), 0.5);
      expect(v('12.'), 12);
      expect(v('0'), 0);
    });

    test('쉼표 하나는 소수점으로 읽는다', () {
      expect(v('1200,5'), 1200.5);
      expect(v('12,25'), 12.25);
      expect(v(',5'), 0.5);
    });

    test('세 자리씩 끊은 쉼표는 자릿수 구분으로 읽는다', () {
      expect(v('1,200'), 1200);
      expect(v('12,345'), 12345);
      expect(v('1,234,567'), 1234567);
      expect(v('1,200.5'), 1200.5);
    });

    test('공백은 무시한다', () {
      expect(v(' 1200 '), 1200);
      expect(v('12 00'), 1200);
    });

    test('비었으면 empty, 못 읽으면 unreadable', () {
      expect(parseLengthInput('').empty, true);
      expect(parseLengthInput('   ').empty, true);
      for (final bad in [
        'abc',
        '12a',
        '-5',
        '1.2.3',
        '1,2,3',
        '12mm',
        '..',
        '1e5',
      ]) {
        final p = parseLengthInput(bad);
        expect(p.unreadable, true, reason: bad);
        expect(p.value, isNull, reason: bad);
        expect(p.empty, false, reason: bad);
      }
    });

    test('터무니없이 큰 값은 읽지 않는다', () {
      expect(parseLengthInput('99999999999').unreadable, true);
    });
  });

  group('절단 길이 계산 과정 글자', () {
    test('양쪽 공제값이 있으면 식으로 보여 준다', () {
      expect(
        cutBreakdownText(c2cMm: 2600, startDeduction: 6, endDeduction: 6),
        '절단 2588.0mm = 2600 − 6 − 6',
      );
    });

    test('공제값이 0인 쪽은 뺀다, 둘 다 0이면 식 없이', () {
      expect(
        cutBreakdownText(c2cMm: 2600, startDeduction: 0, endDeduction: 8.5),
        '절단 2591.5mm = 2600 − 8.5',
      );
      expect(
        cutBreakdownText(c2cMm: 2600.5, startDeduction: 0, endDeduction: 0),
        '절단 2600.5mm',
      );
    });

    test('공제값이 음수면 더하기로 쓴다', () {
      expect(
        cutBreakdownText(c2cMm: 100, startDeduction: -3, endDeduction: 2),
        '절단 101.0mm = 100 + 3 − 2',
      );
    });

    test('인치에서 바꾼 값처럼 소수가 있으면 한 자리까지', () {
      expect(
        cutBreakdownText(c2cMm: 254, startDeduction: 4, endDeduction: 6),
        '절단 244.0mm = 254 − 4 − 6',
      );
      expect(
        cutBreakdownText(c2cMm: 304.8, startDeduction: 0, endDeduction: 5),
        '절단 299.8mm = 304.8 − 5',
      );
    });
  });

  group('입력 탭 화면', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Finder lengthField(int i) => find
        .byWidgetPredicate(
          (w) =>
              w is TextField &&
              (w.decoration?.labelText ?? '').startsWith('전체 길이'),
        )
        .at(i);

    Future<void> open(WidgetTester tester, {double scale = 1.0}) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: CuttingMainScreen(
              project: CuttingProject(
                id: 'p1',
                name: 'TEST',
                createdAt: DateTime(2026, 9, 20),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('숫자를 넣으면 절단 길이가 카드에 바로 나온다', (tester) async {
      await open(tester);
      expect(find.byKey(const Key('cut_breakdown_0')).evaluate(), isEmpty);

      await tester.enterText(lengthField(0), '1200,5');
      await tester.pump();
      expect(find.text('절단 1200.5mm'), findsOneWidget);
      expect(find.byKey(const Key('unreadable_0')).evaluate(), isEmpty);
      // 입력 탭 아래에 화면을 가리는 요약 줄은 두지 않는다.
      expect(find.byKey(const Key('set_plus')).evaluate(), isEmpty);
    });

    testWidgets('쉼표로 쓴 길이도 단위를 바꾸면 같은 길이로 환산된다', (tester) async {
      await open(tester);
      await tester.enterText(lengthField(0), '1,500');
      await tester.pump();
      expect(find.text('절단 1500.0mm'), findsOneWidget);
      await tester.tap(find.text('in'));
      await tester.pump();
      // 예전에는 글자가 '1,500' 그대로 남아 1500in(38100mm)로 셈했다.
      expect(find.text('절단 1500.0mm'), findsOneWidget);
      expect(find.text('절단 38100.0mm'), findsNothing);
      await tester.tap(find.text('mm'));
      await tester.pump();
      expect(find.text('절단 1500.0mm'), findsOneWidget);
    });

    testWidgets('± 단추가 쉼표로 쓴 길이를 0으로 보지 않는다', (tester) async {
      await open(tester);
      await tester.enterText(lengthField(0), '1200,5');
      await tester.pump();
      await tester.tap(find.text('+10').first);
      await tester.pump();
      expect(find.text('절단 1210.5mm'), findsOneWidget);
    });

    testWidgets('읽을 수 없는 글자는 알려 주고 계산에서 뺀다', (tester) async {
      await open(tester);
      await tester.enterText(lengthField(0), '12a0');
      await tester.pump();
      expect(find.byKey(const Key('unreadable_0')), findsOneWidget);
      expect(find.textContaining('간섭 발생'), findsNothing);
      expect(find.byKey(const Key('cut_breakdown_0')).evaluate(), isEmpty);

      // 결과 탭에도 나오지 않는다.
      await tester.tap(find.text('결과'));
      await tester.pumpAndSettle();
      expect(find.textContaining('치수를 입력하십시오'), findsOneWidget);
      await tester.tap(find.text('입력'));
      await tester.pumpAndSettle();

      // 고쳐 쓰면 사라진다.
      await tester.enterText(lengthField(0), '1200');
      await tester.pump();
      expect(find.byKey(const Key('unreadable_0')).evaluate(), isEmpty);
      expect(find.text('절단 1200.0mm'), findsOneWidget);
    });

    testWidgets('세트 수는 결과 탭에서 바꾸고 1 아래로는 내려가지 않는다', (tester) async {
      await open(tester);
      await tester.enterText(lengthField(0), '1000');
      await tester.pump();
      await tester.tap(find.text('결과'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('set_plus')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('set_plus')));
      await tester.pump();
      expect(find.text('3 SET'), findsOneWidget);
      expect(find.textContaining('3000.0 mm'), findsWidgets);
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byKey(const Key('set_minus')));
        await tester.pump();
      }
      expect(find.text('1 SET'), findsOneWidget);
    });

    testWidgets('글자를 크게 키워도 입력 탭이 넘치지 않는다', (tester) async {
      await open(tester, scale: 1.5);
      await tester.enterText(lengthField(0), '2600');
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.enterText(lengthField(0), '2600abc');
      await tester.pump();
      expect(find.byKey(const Key('unreadable_0')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('글자를 크게 키워도 결과 탭이 넘치지 않는다', (tester) async {
      await open(tester, scale: 1.5);
      await tester.enterText(lengthField(0), '2600');
      await tester.pump();
      await tester.tap(find.text('결과'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const Key('set_plus')));
        await tester.pump();
      }
      expect(find.text('4 SET'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
