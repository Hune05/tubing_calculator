// UI·UX 점검 묶음 U-C(통신 없음·알림) 고침 확인.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/repositories/work_project_repository.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/report_tools.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/project_detail_page.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_stock_deduct.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_theme.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('F1 작업 일지 저장 알림: 서버에 닿음·폰에만·실패', () {
    expect(reportSaveNotice(true), "작업 일지를 저장했습니다.");
    expect(reportSaveNotice(false), contains("폰에 저장했습니다"));
    expect(reportSaveNotice(null), contains("저장하지 못했습니다"));
  });

  testWidgets('F1 프로젝트 상세 화면에도 저장 대기 표시', (tester) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(() => WorkProjectRepository.pendingWrites.value = 0);
    final log = <String, dynamic>{
      'id': '1',
      'name': 'A현장',
      'status': 'ONGOING',
      'daily_reports': <dynamic>[],
      'punch_list': <dynamic>[],
      'schedules': <dynamic>[],
    };
    await tester.pumpWidget(
      MaterialApp(
        home: ProjectDetailPage(
          log: log,
          actions: ProjectActions(
            addPunch: () async {},
            openPunch: (_) async {},
            addReport: () async {},
            openReport: (_) async {},
            openReportCalendar: () async {},
            openSchedule: ({String? phaseId, bool add = false}) async {},
            save: () {},
            toggleStatus: () {},
            toggleArchive: () {},
            delete: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('project_pending_sync')), findsNothing);
    WorkProjectRepository.pendingWrites.value = 1;
    await tester.pump();
    expect(find.byKey(const Key('project_pending_sync')), findsOneWidget);
    WorkProjectRepository.pendingWrites.value = 0;
    await tester.pump();
    expect(find.byKey(const Key('project_pending_sync')), findsNothing);
  });

  test('F5 차감 확인창 목록: 무엇을 얼마, 재고에 없는 것 표시', () {
    const takes = [
      StockTake(name: '튜브 1/2"', qty: 2, unit: '본'),
      StockTake(name: 'Union 1/2"', qty: 4, unit: 'EA'),
    ];
    final lines = stockTakeLines(takes, {'튜브 1/2"': 10});
    expect(lines, contains('• 튜브 1/2" 2본'));
    expect(lines, contains('• Union 1/2" 4EA (재고에 없음)'));
    // 통신이 없어 재고를 못 읽었으면 "없음"이라고 잘라 말하지 않는다.
    expect(stockTakeLines(takes, {}), isNot(contains('재고에 없음')));
  });

  test('F5 차감 결과: 못 뺀 것·마이너스를 한 줄씩', () {
    const t = StockTake(name: 'A', qty: 3, unit: 'EA');
    const ok = StockDeductResult(done: [t], missing: []);
    expect(ok.needsAttention, isFalse);
    const r = StockDeductResult(
      done: [t],
      missing: [StockTake(name: 'B', qty: 1, unit: '본')],
      negative: {'A': -2},
    );
    expect(r.needsAttention, isTrue);
    expect(r.detail, contains('• B 1본'));
    expect(r.detail, contains('• A: 남은 수량 -2'));
  });

  testWidgets('F5 부분 실패는 확인을 눌러야 닫히는 창으로', (tester) async {
    const r = StockDeductResult(
      done: [],
      missing: [StockTake(name: 'B', qty: 1, unit: '본')],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showStockDeductResult(context, r),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('stock_deduct_result')), findsOneWidget);
    await tester.pump(const Duration(seconds: 10)); // 알림처럼 저절로 사라지지 않는다
    expect(find.byKey(const Key('stock_deduct_result')), findsOneWidget);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('stock_deduct_result')), findsNothing);
  });
}
