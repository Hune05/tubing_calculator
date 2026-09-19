import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/retro_overview_page.dart';

String md(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

Map<String, dynamic> done(String name, {String? type, int days = 3}) {
  final t = DateTime.now();
  final start = DateTime(t.year, t.month, t.day).subtract(Duration(days: days));
  return {
    'id': name,
    'name': name,
    'status': 'DONE',
    if (type != null) 'workType': type,
    'completedAt': t,
    'phases': [
      {
        'id': 'p1',
        'name': '설치',
        'isCompleted': true,
        'startDate': start,
        'endDate': DateTime(t.year, t.month, t.day),
      },
    ],
    'schedules': [],
    'punch_lists': [],
    'daily_reports': [
      for (var i = 0; i <= days; i++)
        {
          'date': md(start.add(Duration(days: i))),
          'dateISO': start.add(Duration(days: i)).toIso8601String(),
          'worker_count': 2,
        },
    ],
  };
}

void main() {
  Future<void> open(WidgetTester tester, List<Map<String, dynamic>> logs) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: RetroOverviewPage(logs: logs)));
    await tester.pumpAndSettle();
  }

  testWidgets('a completed project no longer crashes the retro overview', (
    tester,
  ) async {
    await open(tester, [done('완료A', type: '배관 신설')]);
    expect(tester.takeException(), isNull);
    // 유형별 한 줄 요약(계획 → 실제 · 투입)이 그려진다.
    expect(find.textContaining('계획'), findsWidgets);
    expect(find.textContaining('인·일'), findsWidgets);
  });

  testWidgets('several completed projects of mixed types average correctly', (
    tester,
  ) async {
    await open(tester, [
      done('A', type: '배관 신설', days: 3), // 4일, 투입 8
      done('B', type: '배관 신설', days: 5), // 6일, 투입 12
      done('C', days: 1), // 미분류
    ]);
    expect(tester.takeException(), isNull);
    // 배관 신설의 평균: 계획 (4+6)/2=5일 → 실제 5일 · 투입 (8+12)/2=10인·일
    expect(find.textContaining('계획 5일 → 실제 5일 · 투입 10인·일'), findsOneWidget);
  });

  testWidgets('no completed projects shows the empty message', (tester) async {
    await open(tester, []);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('완료한 프로젝트가 아직 없습니다'), findsOneWidget);
  });
}
