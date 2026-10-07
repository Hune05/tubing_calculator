// 두 기기 합치기: 일정·단계·이슈를 고치면 고친 시각을 찍어, 다른 기기의 옛 사본이 저장해도
// 되돌아가지 않는다(10-07 2차 점검).
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/attendance.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/project_merge.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/project_phase.dart';

Map<String, dynamic> _doc() => {
  'id': 'p1',
  'schedules': [
    {'id': 's1', 'title': '배관 설치', 'isCompleted': false},
  ],
  'punch_lists': [
    {'id': 'i1', 'content': '볼트', 'is_completed': false, 'updatedAt': '2026-10-01T09:00:00'},
  ],
};

void main() {
  test('폰에서 완료한 일정·이슈가 태블릿의 옛 사본 저장으로 되돌아가지 않는다', () {
    final phone = _doc();
    final tablet = _doc(); // 같은 때 받아 둔 옛 사본
    final report = {
      'id': 'r1',
      'completedScheduleIds': ['s1'],
      'resolvedIssueIds': ['i1'],
    };
    applyReportEffects(phone, report);
    resolveOpenIssues(phone, note: '처리');
    // 서버에는 폰 것이 올라가 있고, 태블릿이 옛 사본으로 저장한다(태블릿 = local).
    final merged = mergeProjectDocs(local: tablet, server: phone);
    expect((merged['schedules'] as List).first['isCompleted'], isTrue);
    expect((merged['punch_lists'] as List).first['is_completed'], isTrue);
  });

  test('달력이 열린 사이 다른 기기에서 들어온 일지는 지운 것으로 적지 않는다', () {
    final log = <String, dynamic>{
      'daily_reports': [
        {'id': 'r1', 'date': '10/06'},
      ],
    };
    final opened = itemIdsOf(log, 'daily_reports');
    final fromScreen = [
      {'id': 'r1', 'date': '10/06', 'memo': '고침'},
    ];
    // 화면이 열린 사이 합치기로 다른 기기 일지 r2가 들어옴
    (log['daily_reports'] as List).insert(0, {'id': 'r2', 'date': '10/07'});
    replaceItemList(log, 'daily_reports', fromScreen, openedIds: opened);
    expect((log['daily_reports'] as List).map((m) => m['id']), ['r2', 'r1']);
    expect((log['deletedIds'] as List? ?? const []), isEmpty);
    // 화면에서 실제로 지운 것은 지운 것으로 적는다.
    final opened2 = itemIdsOf(log, 'daily_reports');
    replaceItemList(log, 'daily_reports', [
      {'id': 'r2'},
    ], openedIds: opened2);
    expect(log['deletedIds'], contains('r1'));
  });

  test('시각이 붙은 dateISO(PC 일지)도 그날 근태를 찾는다', () {
    AttendanceCache.byDate = {'2026-10-07': '연차'};
    expect(attendanceTypeOf({'dateISO': '2026-10-07T14:23:11.123'}), '연차');
    expect(attendanceTypeOf({'dateISO': '2026-10-07'}), '연차');
    AttendanceCache.byDate = {};
  });
}
