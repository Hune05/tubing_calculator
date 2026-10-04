// 각도 역산(Field Matcher) 시트: 높이와 Travel/Run을 넣으면 실제 각도와 가까운 표준 각도가 나온다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/conduit/widgets/angle_matcher_sheet.dart';

Future<void> open(WidgetTester tester, {Size size = const Size(400, 900), double textScale = 1}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const Key('open'),
                onPressed: () => AngleMatcherSheet.show(context),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
}

/// 숫자 칸은 눌러서 숫자판으로 넣는 칸(읽기 전용)이라, 시험에서는 칸의 값을 바로 바꾼다.
Future<void> type(WidgetTester tester, String key, String text) async {
  tester.widget<TextField>(find.byKey(Key(key))).controller!.text = text;
  await tester.pumpAndSettle();
}

String allText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text, skipOffstage: false))
    .map((t) => t.data ?? '')
    .join('\n');

void main() {
  testWidgets('값이 없으면 "입력 필요", 그림 다시 보기 단추가 있다', (tester) async {
    await open(tester);
    final t = allText(tester);
    expect(t, contains('각도 역산 (Field Matcher)'));
    expect(t, contains('입력 필요'));
    expect(find.byKey(const Key('angle_match_guide_replay')), findsOneWidget);
  });

  testWidgets('Travel로 잰 경우: 높이 100 · Travel 200 → 30°, 표준 각도와 같다', (tester) async {
    await open(tester);
    await type(tester, 'am_rise', '100');
    await type(tester, 'am_measure', '200');
    final t = allText(tester);
    expect(t, contains('30°'));
    expect(t, contains('표준 각도 30°와 같습니다.'));
    expect(t, contains('173.2 mm'), reason: 'Run');
    expect(t, contains('26.8 mm'), reason: '줄어드는 길이');
    expect(find.byKey(const Key('am_row_30')), findsOneWidget);
    expect(find.byKey(const Key('am_row_22.5')), findsOneWidget);
  });

  testWidgets('표준이 아닌 값: 높이 100 · Travel 190 → 31.8°, 가까운 표준 30°와 차이 안내', (tester) async {
    await open(tester);
    await type(tester, 'am_rise', '100');
    await type(tester, 'am_measure', '190');
    final t = allText(tester);
    expect(t, contains('31.8°'));
    expect(t, contains('표준 각도가 아닙니다. 가장 가까운 30°와 1.8° 차이입니다.'));
    expect(t, contains('5mm 낮아집니다'));
  });

  testWidgets('Run으로 바꿔 잰 경우: 높이 100 · Run 100 → 45°', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('am_basis_run')));
    await tester.pumpAndSettle();
    await type(tester, 'am_rise', '100');
    await type(tester, 'am_measure', '100');
    final t = allText(tester);
    expect(t, contains('45°'));
    expect(t, contains('141.4 mm'), reason: 'Travel');
    expect(t, contains('표준 각도 45°와 같습니다.'));
  });

  testWidgets('Travel이 높이보다 짧으면 풀지 않고 이유를 알린다', (tester) async {
    await open(tester);
    await type(tester, 'am_rise', '100');
    await type(tester, 'am_measure', '90');
    expect(find.byKey(const Key('am_problem')), findsOneWidget);
    expect(allText(tester), contains('입력 필요'));
  });

  testWidgets('목록에 넣는 단추는 없다(보기만 하는 계산)', (tester) async {
    await open(tester);
    await type(tester, 'am_rise', '100');
    await type(tester, 'am_measure', '200');
    expect(find.byKey(const Key('cs_add')), findsNothing);
  });

  for (final w in [320.0, 360.0]) {
    testWidgets('폭 $w · 큰 글씨 1.4배에서 넘치지 않는다', (tester) async {
      await open(tester, size: Size(w, 700), textScale: 1.4);
      await type(tester, 'am_rise', '100');
      await type(tester, 'am_measure', '190');
      expect(tester.takeException(), isNull);
    });
  }
}
