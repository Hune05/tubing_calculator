// 10-14 작업 일지 업체·공종별 인력과 투입 장비: 창에서 적으면 투입 인원이 합계가 되고,
// 저장한 일지·보고서 글·CSV에 남는다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/report_crews.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/report_csv.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/report_tools.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/daily_report_page.dart';

void main() {
  group('셈', () {
    test('빈 줄·0명은 빼고 합을 낸다, 한 줄 글', () {
      final r = {
        'crews': [
          {'company': '대성', 'trade': '배관', 'count': 5, 'hours': 8},
          {'company': '한빛', 'trade': '전기', 'count': '2', 'hours': 0},
          {'company': '', 'trade': '', 'count': 0},
        ],
        'equipment': [
          {'name': '크레인 25t', 'count': 1, 'hours': 4},
          {'name': '', 'count': 3},
          {'name': '고소작업차', 'count': 0},
        ],
      };
      expect(crewTotal(crewsOf(r)), 7);
      expect(crewsLine(r), '대성 배관 5명 8h · 한빛 전기 2명');
      expect(equipmentLine(r), '크레인 25t 1대 4h · 고소작업차 1대');
      expect(crewsLine(const {}), '');
    });

    test('보고서 글과 CSV에 인력·장비 줄', () {
      final r = <String, dynamic>{
        'id': 'r1',
        'date': '10/14',
        'dateISO': '2026-10-14',
        'work_type': ['신규 설치'],
        'worker_count': 7,
        'crews': [
          {'company': '대성', 'trade': '배관', 'count': 7},
        ],
        'equipment': [
          {'name': '크레인 25t', 'count': 1},
        ],
      };
      final log = <String, dynamic>{
        'name': '시험',
        'daily_reports': [r],
      };
      final doc = buildReportDoc(
        log,
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 31),
      );
      final all = doc.sections.expand((s) => s.lines).join('\n');
      expect(all, contains('인력: 대성 배관 7명'));
      expect(all, contains('장비: 크레인 25t 1대'));
      final csv = buildReportsCsv([(log, r)]);
      expect(csv, contains('업체별 인력,투입 장비'));
      expect(csv, contains('"대성 배관 7명"'));
    });
  });

  testWidgets('일지에서 업체별 인력·장비를 적으면 인원이 합계가 되고 저장된다', (tester) async {
    SharedPreferences.setMockInitialValues({});
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
                  MaterialPageRoute(builder: (_) => const DailyReportPage()),
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

    await tester.ensureVisible(find.byKey(const Key('report_crews')));
    await tester.tap(find.byKey(const Key('report_crews')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('crew_company_0')), '대성');
    await tester.enterText(find.byKey(const Key('crew_trade_0')), '배관');
    await tester.enterText(find.byKey(const Key('crew_count_0')), '5');
    await tester.tap(find.byKey(const Key('crew_add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('crew_company_1')), '한빛');
    await tester.enterText(find.byKey(const Key('crew_count_1')), '2');
    await tester.tap(find.byKey(const Key('crew_apply')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('report_worker_total'))).data,
      '7명',
    );

    await tester.ensureVisible(find.byKey(const Key('report_equipment')));
    await tester.tap(find.byKey(const Key('report_equipment')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('equip_name_0')), '크레인 25t');
    await tester.enterText(find.byKey(const Key('equip_hours_0')), '4');
    await tester.tap(find.byKey(const Key('equip_apply')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('report_points')), '3');
    final save = find.text('작업 일지 저장');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(result?['worker_count'], 7);
    expect((result?['crews'] as List).length, 2);
    expect(equipmentLine(result!), '크레인 25t 1대 4h');
  });
}
