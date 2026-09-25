// 작업 일지 날짜: 지난 날로 쓰기, 연도 구분(점검 36번).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/reminder_tools.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/daily_report_page.dart';

import 'helpers_text.dart';

String iso(DateTime d) => d.toIso8601String().substring(0, 10);
String mmdd(DateTime d) =>
    "${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}";

void main() {
  test('작년 같은 날 일지만 있으면 오늘은 "안 씀"이다', () {
    final now = DateTime(2026, 9, 25, 18);
    final logs = [
      {
        'name': '작년에만 씀',
        'status': 'ONGOING',
        'daily_reports': [
          {'date': '09/25', 'dateISO': '2025-09-25'},
        ],
      },
      {
        'name': '오늘 씀',
        'status': 'ONGOING',
        'daily_reports': [
          {'date': '09/25', 'dateISO': '2026-09-25'},
        ],
      },
      {
        'name': '예전 일지(연도 없음)',
        'status': 'ONGOING',
        'daily_reports': [
          {'date': '09/25'},
        ],
      },
    ];
    final missing = projectsMissingReport(logs, '09/25', now: now);
    // 예전: "MM/dd"만 견줘 작년 일지를 오늘 것으로 봤다.
    expect(missing.map((e) => e['name']), ['작년에만 씀']);
  });

  testWidgets('이어 쓴 임시 저장은 고른 날짜(지난 날)로 저장된다', (tester) async {
    final day = DateTime.now().subtract(const Duration(days: 3));
    SharedPreferences.setMockInitialValues({
      'draft_t': jsonEncode({
        'savedAt': DateTime.now().toIso8601String(),
        'reportDay': iso(day),
        'note': '어제 못 쓴 일지',
      }),
    });
    tester.view.physicalSize = const Size(1440, 3200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    Map<String, dynamic>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<Map<String, dynamic>>(
                  MaterialPageRoute(
                    builder: (_) => const DailyReportPage(draftKey: 'draft_t'),
                  ),
                );
              },
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(findText('이어서 쓰기'));
    await tester.pumpAndSettle();
    // 머리에 고른 날짜와 "지난 날 일지"
    expect(find.textContaining('${mmdd(day)} · 지난 날 일지'), findsOneWidget);

    final save = find.text('작업 일지 저장');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    // 예전: 날짜는 늘 오늘이었다.
    expect(result?['date'], mmdd(day));
    expect(result?['dateISO'], iso(day));
  });
}
