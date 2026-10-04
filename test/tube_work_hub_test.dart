// 튜브 가공: 라인 컷팅·단관 컷팅으로 들어가는 입구.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/menu/page/mobile_menu_page.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/screens/short_pipe_cutting_page.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/screens/tube_work_hub_page.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('튜브 가공: 라인 컷팅·단관 컷팅 두 칸이 보인다', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: TubeWorkHubPage()));
    await tester.pumpAndSettle();
    expect(find.text('튜브 가공'), findsOneWidget);
    expect(find.text('라인 컷팅'), findsOneWidget);
    expect(find.text('단관 컷팅'), findsOneWidget);
    expect(find.byKey(const Key('hub_line_cutting')), findsOneWidget);
    expect(find.byKey(const Key('hub_short_pipe')), findsOneWidget);
  });

  testWidgets('단관 컷팅 칸을 누르면 단관 컷팅 화면이 열린다', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: TubeWorkHubPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('hub_short_pipe')));
    await tester.pumpAndSettle();
    expect(find.byType(ShortPipeCuttingPage), findsOneWidget);
  });

  test('빠른 실행: 예전 이름 "튜브 컷팅"으로 저장한 것은 "튜브 가공"으로 읽힌다', () {
    expect(renameQuickLaunchTitles(['튜브 컷팅', '압력시험']), ['튜브 가공', '압력시험']);
    expect(renameQuickLaunchTitles(['튜브 가공', '튜브 컷팅']), ['튜브 가공']);
  });
}
