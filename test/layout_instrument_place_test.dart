// 폰 배치도: 아래 칸 "계기"를 눌러 목록에서 고르면 도면에 그 크기로 놓인다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/layout_board_page.dart';

void main() {
  testWidgets('계기 목록에서 고르면 도면에 놓인다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'layout_board_onboarding_shown_v1': true,
    });
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: LayoutBoardPage()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('instrument_button')));
    await tester.pumpAndSettle();
    expect(find.text('계기 놓기'), findsOneWidget);
    expect(find.text('요꼬가와'), findsOneWidget);
    await tester.ensureVisible(find.text('APT3100 DPT'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('APT3100 DPT'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(InteractiveViewer),
        matching: find.text('APT3100 DPT'),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
