// 현장 자료 화면: 발전 설비 탭(사용자 요청 2026-09-25 — 전기 기능사 실무 참고,
// 수소 냉각·씰 오일·윤활유·냉각수·밸브 스테이션 개론).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/reference/page/tube_reference_page.dart';

Widget app(Widget home) => MaterialApp(home: home);

Future<void> _openPlantTab(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app(const TubeReferencePage()));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('발전 설비'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('발전 설비'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('발전 설비 탭에 핵심 계통 카드가 있다', (tester) async {
    await _openPlantTab(tester);
    expect(find.textContaining('수소(H₂)로 냉각하나'), findsOneWidget);
    expect(find.textContaining('씰 오일 계통'), findsOneWidget);
    expect(find.textContaining('윤활유 계통(LOT)'), findsOneWidget);
    expect(find.textContaining('냉각수 계통(워터 쿨링)'), findsOneWidget);
    expect(find.textContaining('밸브 스테이션'), findsWidgets);
    expect(find.textContaining('전체 흐름 한눈에 보기'), findsOneWidget);
  });

  testWidgets('참고용 설명이라는 경고가 카드 안팎에 있다', (tester) async {
    await _openPlantTab(tester);
    expect(find.textContaining('절차서(SOP)'), findsNWidgets(2));
  });

  testWidgets('접었다 펴는 카드를 펴면 세부 내용이 보인다', (tester) async {
    await _openPlantTab(tester);
    expect(find.textContaining('가스 판넬(H2 Gas Panel)'), findsNothing);
    await tester.tap(find.textContaining('수소 가스 계통'));
    await tester.pumpAndSettle();
    expect(find.textContaining('가스 판넬(H2 Gas Panel)'), findsOneWidget);
  });

  testWidgets('검색으로 "씰오일탱크"를 찾으면 발전 설비 탭으로 간다', (tester) async {
    tester.view.physicalSize = const Size(390, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(const TubeReferencePage()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '씰오일탱크');
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('씰 오일 계통'));
    await tester.pumpAndSettle();

    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.controller!.index, 6);
  });
}
