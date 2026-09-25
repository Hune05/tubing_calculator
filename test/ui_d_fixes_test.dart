// UI·UX 점검 묶음 U-D(길 찾기·이름) 고침 확인.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
