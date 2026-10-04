// 라인 컷팅 구간 카드 개편: 제목(PT1 → PT2)·상태 칩, 한 줄 ± 단추와 "이전과 동일", 결과 상자, 경고 띠.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/models/cutting_project_model.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/screens/cutting_main_screen.dart';

Finder lengthField(int i) => find
    .byWidgetPredicate(
      (w) => w is TextField && (w.decoration?.labelText ?? '').startsWith('전체 길이'),
    )
    .at(i);

Future<void> open(WidgetTester tester, {Size size = const Size(1080, 3600), double scale = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: CuttingMainScreen(
          project: CuttingProject(id: 'p1', name: 'TEST', createdAt: DateTime(2026, 9, 20)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String stateOf(WidgetTester tester, int i) => tester
    .widget<Text>(find.descendant(of: find.byKey(Key('segment_state_$i')), matching: find.byType(Text)))
    .data!;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('구간 카드 제목은 "PT1 → PT2", 처음 상태는 "입력 필요"', (tester) async {
    await open(tester);
    expect(tester.widget<Text>(find.byKey(const Key('segment_title_0'))).data, 'PT1 → PT2');
    expect(stateOf(tester, 0), '입력 필요');
  });

  testWidgets('값을 넣으면 "계산됨", 못 읽는 값은 "확인 필요"', (tester) async {
    await open(tester);
    await tester.enterText(lengthField(0), '1200');
    await tester.pump();
    expect(stateOf(tester, 0), '계산됨');
    await tester.enterText(lengthField(0), '12a0');
    await tester.pump();
    expect(stateOf(tester, 0), '확인 필요');
    expect(find.byKey(const Key('unreadable_0')), findsOneWidget);
  });

  testWidgets('계산 결과 상자에 절단 길이와 식이 나온다', (tester) async {
    await open(tester);
    await tester.enterText(lengthField(0), '1200,5');
    await tester.pump();
    expect(find.byKey(const Key('cut_breakdown_0')), findsOneWidget);
    expect(find.text('절단 1200.5mm'), findsOneWidget);
  });

  testWidgets('"이전과 동일"은 앞 구간에 값이 있을 때만, 누르면 같은 값이 들어간다', (tester) async {
    await open(tester);
    await tester.tap(find.text('포인트 추가'));
    await tester.pump();
    expect(find.byKey(const Key('copy_prev_1')), findsNothing);
    await tester.enterText(lengthField(0), '800');
    await tester.pump();
    expect(find.byKey(const Key('copy_prev_1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('copy_prev_1')));
    await tester.pump();
    expect(tester.widget<TextField>(lengthField(1)).controller!.text, '800');
    expect(stateOf(tester, 1), '계산됨');
  });

  testWidgets('"이전과 동일"과 ± 단추가 같은 줄에 있다', (tester) async {
    await open(tester);
    await tester.tap(find.text('포인트 추가'));
    await tester.pump();
    await tester.enterText(lengthField(0), '800');
    await tester.pump();
    final copyY = tester.getCenter(find.byKey(const Key('copy_prev_1'))).dy;
    final stepY = tester.getCenter(find.text('+10').at(1)).dy;
    expect((copyY - stepY).abs(), lessThan(20));
  });

  for (final w in [320.0, 360.0]) {
    testWidgets('폭 $w · 글자 1.3배에서 구간 카드가 넘치지 않는다', (tester) async {
      await open(tester, size: Size(w * 3, 3600), scale: 1.3);
      await tester.tap(find.text('포인트 추가'));
      await tester.pump();
      await tester.enterText(lengthField(0), '1234.5');
      await tester.enterText(lengthField(1), '12a0');
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
