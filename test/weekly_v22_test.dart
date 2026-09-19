import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/daily_report_page.dart';

import 'helpers_text.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('어제 일보로 시작 배너: 제목이 한 줄로 나오고 버튼 둘이 아래에 나란히 있다', (tester) async {
    // 폰 폭(360dp)에서 확인한다. 좁은 폭에서 제목이 세 줄로 끊기던 모양이 다시 생기면 실패한다.
    tester.view.physicalSize = const Size(1080, 2400);
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

    final title = findText('어제 일보로 빠르게 시작');
    expect(title, findsOneWidget);
    final titleSize = tester.getSize(title);
    expect(titleSize.height, lessThan(24), reason: '제목이 한 줄이어야 한다');

    final b1 = tester.getRect(find.text('값 불러오기'));
    final b2 = tester.getRect(find.text('내용까지 복사'));
    final t = tester.getRect(title);
    expect(b1.top, greaterThan(t.bottom - 1), reason: '버튼은 제목 아래');
    expect(
      (b1.center.dy - b2.center.dy).abs(),
      lessThan(4),
      reason: '버튼 둘은 같은 줄',
    );
    expect(b2.left, greaterThan(b1.right - 1));
  });
}
