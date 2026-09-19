import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/daily_report_page.dart';

import 'helpers_text.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('어제 일보 배너: 폰 폭에서 제목과 버튼 둘이 한 줄에 어색하게 끊기지 않고 들어간다', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400); // 360dp 폭
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: DailyReportPage(
          previousReport: {
            'date': '09/18',
            'dateISO': DateTime(2026, 9, 18).toIso8601String(),
            'worker_count': 2,
            'content': '어제 작업',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final title = findText('어제 일보');
    expect(title, findsOneWidget);
    expect(tester.getSize(title).height, lessThan(24), reason: '제목은 한 줄');
    final b1 = tester.getRect(find.text('기본 정보만'));
    final b2 = tester.getRect(find.text('내용까지'));
    expect(tester.getSize(find.text('기본 정보만')).height, lessThan(24));
    expect(tester.getSize(find.text('내용까지')).height, lessThan(24));
    final t = tester.getRect(title);
    // 셋이 같은 줄에 있다.
    expect((t.center.dy - b1.center.dy).abs(), lessThan(6));
    expect((b1.center.dy - b2.center.dy).abs(), lessThan(4));
  });
}
