import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_schedule/schedule_logic.dart';
import 'package:tubing_calculator/src/presentation/my_schedule/schedule_search_dialog.dart';

void main() {
  Future<void> open(WidgetTester tester, {required bool filtered}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScheduleSearchDialog(
            entries: [
              SearchEntry(
                groupKey: 'a',
                key: 'a',
                date: DateTime(2026, 9, 25, 10),
                title: '거래처 미팅',
                category: '개인',
              ),
            ],
            filtered: filtered,
            nowForTest: DateTime(2026, 9, 22),
          ),
        ),
      ),
    );
  }

  testWidgets('필터를 걸어 두었으면 그 안에서만 찾는다고 알려 준다', (tester) async {
    await open(tester, filtered: true);
    expect(find.text('종류·프로젝트 필터를 걸어 두어서 그 안에서만 찾습니다.'), findsOneWidget);
  });

  testWidgets('필터가 없으면 안내 줄이 없다', (tester) async {
    await open(tester, filtered: false);
    expect(find.textContaining('필터를 걸어 두어서'), findsNothing);
  });
}
