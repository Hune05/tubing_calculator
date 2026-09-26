// 현장 자료 화면: 단위 환산 탭 — 홈 "단위 환산"과 같은 화면을 쓴다(2026-09-26 고도화).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/reference/page/tube_reference_page.dart';

Widget app(Widget home) => MaterialApp(home: home);

Future<void> _openUnitTab(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app(const TubeReferencePage()));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('단위 환산'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('단위 환산'));
  await tester.pumpAndSettle();
}

String textOf(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(Key(key))).controller!.text;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('단위 환산 탭에 분류 칩이 있고, 환산 화면의 찾기 칸은 없다(위 찾기를 쓴다)', (tester) async {
    await _openUnitTab(tester);
    expect(find.byKey(const Key('uc_cat_length')), findsOneWidget);
    expect(find.byKey(const Key('uc_cat_pressure')), findsOneWidget);
    expect(find.byKey(const Key('uc_search')), findsNothing);
  });

  testWidgets('mm에 25.4를 넣으면 inch가 1, 분수 1"', (tester) async {
    await _openUnitTab(tester);
    await tester.enterText(find.byKey(const Key('uc_field_mm')), '25.4');
    await tester.pump();
    expect(textOf(tester, 'uc_field_in'), '1');
    expect(textOf(tester, 'uc_field_in_frac'), '1"');
  });

  testWidgets('검색으로 "토크"를 찾으면 단위 환산 탭으로 간다', (tester) async {
    tester.view.physicalSize = const Size(390, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(const TubeReferencePage()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '토크');
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('단위 환산 — 토크'));
    await tester.pumpAndSettle();

    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.controller!.index, 5);
  });
}
