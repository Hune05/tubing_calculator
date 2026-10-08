// 현장 자료 화면: 발전 설비 탭(사용자 요청 2026-09-25 — 전기 기능사 실무 참고,
// 수소 냉각·씰 오일·윤활유·냉각수·밸브 스테이션 개론).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/reference/page/ref_plant_tab.dart';
import 'package:tubing_calculator/src/presentation/reference/page/reference_widgets.dart';
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
    expect(tabBar.controller!.index, 4);
  });

  // 10-09 전문 자료로 다시 씀: 틀렸던 곳을 바로잡았는지, 새 카드가 있는지, 좁은 화면에서 넘치지 않는지.
  Future<void> pumpAllOpen(WidgetTester tester, {double width = 390, double scale = 1.0}) async {
    kRefExpandAll = true;
    addTearDown(() => kRefExpandAll = false);
    tester.view.physicalSize = Size(width, 20000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const Scaffold(body: RefPlantTab()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets("바로잡은 내용: 진공 탱크는 공기·수분 제거, 씰 오일은 수소 있는 동안 유지, 순도와 노점은 따로", (tester) async {
    await pumpAllOpen(tester);
    expect(find.textContaining("녹은 공기·수분 제거"), findsOneWidget);
    expect(find.textContaining("detraining tank"), findsWidgets);
    expect(find.textContaining("케이싱에 수소가 있는 동안은 정지·turning gear 중에도 씰 오일 유지"), findsOneWidget);
    expect(find.textContaining("순도(H₂ %)와 노점(수분)은 서로 다른 계기"), findsOneWidget);
    // 예전 틀린 설명은 없다.
    expect(find.textContaining("녹아든 수소를 진공으로 뽑아"), findsNothing);
  });

  testWidgets("새 카드: CO₂ 퍼지·고정자 냉각수·복수기·여자/조속기, 카드마다 출처", (tester) async {
    await pumpAllOpen(tester);
    for (final t in [
      "CO₂ 퍼지: 수소 충전·배출 순서",
      "고정자 냉각수(SCW): 수질·압력·감시",
      "복수기 진공: 배압·공기 유입",
      "여자 계통·AVR·조속기(EHC)",
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.textContaining("출처:"), findsAtLeastNWidgets(8));
    expect(find.text("현상"), findsAtLeastNWidgets(6)); // 고장 조치 표(현상/원인/조치)
  });

  testWidgets("모든 카드를 편 채로 폭 320·글씨 1.3배에서 넘치지 않는다", (tester) async {
    final errors = <String>[];
    final old = FlutterError.onError;
    FlutterError.onError = (d) => errors.add(d.exceptionAsString().split("\n").first);
    try {
      await pumpAllOpen(tester, width: 320, scale: 1.3);
    } finally {
      FlutterError.onError = old;
    }
    expect(errors.where((e) => e.contains("overflowed")), isEmpty, reason: errors.join(" / "));
  });
}

