// 지난 알림 "전부 지우기": 잘못 눌러도 "되돌리기"로 그대로 돌아온다(10-02).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/notification/pages/my_notifications_tab.dart';

void main() {
  testWidgets('전부 지우기 뒤 되돌리기를 누르면 지난 알림이 그대로 돌아온다', (tester) async {
    final raw = jsonEncode([
      {
        'id': 'a',
        'title': '오늘 일정 2건',
        'detail': '',
        'dismissedAt': DateTime(2026, 10, 1, 9).toIso8601String(),
      },
      {
        'id': 'b',
        'title': '일지 미작성',
        'detail': '',
        'dismissedAt': DateTime(2026, 10, 1, 18).toIso8601String(),
      },
    ]);
    SharedPreferences.setMockInitialValues({
      'my_notifications_archive_v1': raw,
    });

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PastNotificationsTab())),
    );
    await tester.pumpAndSettle();
    expect(find.text('지난 알림 2건'), findsOneWidget);

    await tester.tap(find.text('전부 지우기'));
    await tester.pumpAndSettle();
    expect(find.text('지난 알림이 없습니다.'), findsOneWidget);
    expect(find.text('삭제했습니다: 지난 알림 2건'), findsOneWidget);
    final p = await SharedPreferences.getInstance();
    expect(p.getString('my_notifications_archive_v1'), isNull);

    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();
    expect(find.text('지난 알림 2건'), findsOneWidget);
    expect(find.text('오늘 일정 2건'), findsOneWidget);
    expect(find.text('일지 미작성'), findsOneWidget);
    expect(p.getString('my_notifications_archive_v1'), raw);
  });
}
