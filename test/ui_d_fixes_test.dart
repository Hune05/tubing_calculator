// UI·UX 점검 묶음 U-D(길 찾기·이름) 고침 확인.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_settings_tab.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_settings_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/reminder_tools.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/widgets/project_summary_card.dart';

void main() {
  test('N2 오늘 날짜 "MM/dd"', () {
    expect(todayMmDd(DateTime(2026, 9, 5)), '09/05');
  });

  testWidgets('N6 프로젝트 카드: 빠른 작업을 ⋮ 단추로도 연다', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProjectSummaryCard(
            log: const {'id': '1', 'name': 'A현장', 'status': 'ONGOING'},
            isActive: true,
            onTap: () {},
            onLongPress: () => opened++,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('project_card_more')));
    expect(opened, 1);
  });

  group('U4 설정 위가 고정되지 않고 같이 넘어간다(작은 폰)', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> check(
      WidgetTester tester,
      Widget page,
      String topText,
      Key scroll,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: page));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final before = tester.getTopLeft(find.text(topText)).dy;
      await tester.drag(find.byKey(scroll), const Offset(0, -300));
      await tester.pump(const Duration(seconds: 1));
      final top = find.text(topText);
      // 예전: 고정이라 그대로였다.
      if (top.evaluate().isNotEmpty) {
        expect(tester.getTopLeft(top).dy, lessThan(before - 100));
      }
    }

    testWidgets('전선관 설정: 방식 고르기', (tester) async {
      await check(
        tester,
        const ConduitSettingsPage(),
        '장비 작동 방식 선택',
        const Key('conduit_settings_scroll'),
      );
    });

    testWidgets('튜브 설정: 제목', (tester) async {
      await check(
        tester,
        const Scaffold(body: MobileSettingsTab()),
        '장비 세팅 가이드',
        const Key('tube_settings_scroll'),
      );
    });
  });
}
