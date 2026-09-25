// 현장 자료 화면: 단위 환산 탭(현장자료_보충제안_2026-09-25.md 3번).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/reference/page/tube_reference_page.dart';

Widget app(Widget home) => MaterialApp(home: home);

Future<void> _openUnitTab(WidgetTester tester) async {
  // 세로를 넉넉히 잡아 네 카드(TextField 8개)가 모두 화면에 그려지게 한다
  // (ListView는 화면 밖 항목을 안 그린다).
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

void main() {
  testWidgets('단위 환산 탭에 네 가지 환산 카드가 있다', (tester) async {
    await _openUnitTab(tester);
    expect(find.textContaining('길이 (mm'), findsOneWidget);
    expect(find.textContaining('무게 (kg'), findsOneWidget);
    expect(find.textContaining('압력 (bar'), findsOneWidget);
    expect(find.textContaining('토크 (Nm'), findsOneWidget);
  });

  testWidgets('mm에 25.4를 넣으면 inch가 1이 된다', (tester) async {
    await _openUnitTab(tester);
    final mm = find.byKey(const Key('unit_mm_inch_a'));
    final inch = find.byKey(const Key('unit_mm_inch_b'));
    await tester.enterText(mm, '25.4');
    await tester.pump();
    expect(tester.widget<TextField>(inch).controller!.text, '1');
  });

  testWidgets('반대쪽(inch)에 넣어도 mm가 바뀐다', (tester) async {
    await _openUnitTab(tester);
    final mm = find.byKey(const Key('unit_mm_inch_a'));
    final inch = find.byKey(const Key('unit_mm_inch_b'));
    await tester.enterText(inch, '2');
    await tester.pump();
    expect(tester.widget<TextField>(mm).controller!.text, '50.8');
  });

  testWidgets('kg에 100을 넣으면 lb로 정확히 환산된다', (tester) async {
    await _openUnitTab(tester);
    final kg = find.byKey(const Key('unit_kg_lb_a'));
    final lb = find.byKey(const Key('unit_kg_lb_b'));
    await tester.enterText(kg, '100');
    await tester.pump();
    expect(tester.widget<TextField>(lb).controller!.text, '220.4623');
  });

  testWidgets('bar·psi, Nm·lb-ft 카드도 서로 바뀐다', (tester) async {
    await _openUnitTab(tester);
    final bar = find.byKey(const Key('unit_bar_psi_a'));
    final psi = find.byKey(const Key('unit_bar_psi_b'));
    await tester.enterText(bar, '1');
    await tester.pump();
    expect(tester.widget<TextField>(psi).controller!.text, '14.5038');

    final nm = find.byKey(const Key('unit_Nm_lb-ft_a'));
    final lbFt = find.byKey(const Key('unit_Nm_lb-ft_b'));
    await tester.enterText(nm, '10');
    await tester.pump();
    expect(tester.widget<TextField>(lbFt).controller!.text, '7.3756');
  });

  testWidgets('숫자가 아니면 반대쪽을 비운다', (tester) async {
    await _openUnitTab(tester);
    final mm = find.byKey(const Key('unit_mm_inch_a'));
    final inch = find.byKey(const Key('unit_mm_inch_b'));
    await tester.enterText(mm, '10');
    await tester.pump();
    await tester.enterText(mm, '');
    await tester.pump();
    expect(tester.widget<TextField>(inch).controller!.text, '');
  });

  testWidgets('검색으로 "토크"를 찾으면 단위 환산 탭으로 간다', (tester) async {
    tester.view.physicalSize = const Size(390, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(const TubeReferencePage()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '토크');
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('토크 (Nm'));
    await tester.pumpAndSettle();

    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.controller!.index, 5);
  });
}
