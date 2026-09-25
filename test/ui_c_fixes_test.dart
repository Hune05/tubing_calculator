// UI·UX 점검 묶음 U-C(통신 없음·알림) 고침 확인.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/repositories/work_project_repository.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/report_tools.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/project_detail_page.dart';

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
}
