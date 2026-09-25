// 현장 자료 화면: 전기 기준(KEC) 탭. 이 환경 네트워크 정책이 law.go.kr·
// kec.kea.kr 접속을 막아 최신 원문을 확인할 수 없어(2026-09-25), 조문
// 번호·수치 없이 "해마다 다시 확인해야 하는 항목"만 담았다는 걸 확인한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/reference/page/tube_reference_page.dart';

Widget app(Widget home) => MaterialApp(home: home);

Future<void> _openKecTab(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app(const TubeReferencePage()));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('전기 기준(KEC)'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('전기 기준(KEC)'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('전기 기준(KEC) 탭에 확인 방법과 분야별 카드가 있다', (tester) async {
    await _openKecTab(tester);
    expect(find.textContaining('최신 원문을 확인하는 방법'), findsOneWidget);
    expect(find.textContaining('접지·과전류 보호'), findsOneWidget);
    expect(find.textContaining('절연저항·이격거리'), findsOneWidget);
    expect(find.textContaining('최근 몇 년 사이 개정이 잦았던 분야'), findsOneWidget);
  });

  testWidgets('조문 번호·수치를 지어내지 않았다는 경고가 있다', (tester) async {
    await _openKecTab(tester);
    expect(find.textContaining('조문 번호나 수치를 넣지 않았습니다'), findsOneWidget);
  });

  testWidgets('검색으로 "접지"를 찾으면 전기 기준(KEC) 탭으로 간다', (tester) async {
    tester.view.physicalSize = const Size(390, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(const TubeReferencePage()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '계통접지');
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('접지·과전류 보호'));
    await tester.pumpAndSettle();

    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.controller!.index, 7);
  });
}
