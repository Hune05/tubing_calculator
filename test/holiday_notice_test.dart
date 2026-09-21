import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_schedule/korean_holidays.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/notification_check_page.dart';

import 'helpers_text.dart';

void main() {
  final last = lastHolidayYear;

  test('공휴일 표의 마지막 해 12월부터 새 표가 필요하다고 알려 준다', () {
    expect(holidayTableNotice(DateTime(last, 6, 1)), '');
    expect(holidayTableNotice(DateTime(last, 12, 1)), contains('내년 공휴일'));
    expect(holidayTableNotice(DateTime(last + 1, 1, 2)), contains('$last년까지만'));
  });

  testWidgets('알림 점검 화면에 공휴일 표 안내가 보인다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(900, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationCheckPage(
          logs: const [],
          pendingIdsLoader: () async => {},
          recordActive: () async {},
          exactChecker: () async => true,
          nowForTest: DateTime(last + 1, 1, 2),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(findTextContaining('공휴일 표가'), findsOneWidget);
  });
}
