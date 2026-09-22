import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/backup_tools.dart';

// 백업 파일에 배치도·내 일정이 함께 담기는 것과, 옛 백업과의 호환.
String backupText({List? layouts, List? schedules}) => jsonEncode({
  'app': 'tubing_calculator',
  'version': 1,
  'exportedAt': DateTime(2026, 9, 19, 20).toIso8601String(),
  'projects': [
    {'id': '1', 'name': 'A'},
    {'id': '2', 'name': 'B'},
  ],
  'templates': [
    {'id': 't1'},
  ],
  'favMaterials': [],
  'layouts': ?layouts,
  'personalSchedules': ?schedules,
});

void main() {
  test('배치도·내 일정 개수를 읽는다', () {
    final p = parseBackup(
      backupText(
        layouts: [
          {'id': 'l1', 'data': {}},
          {'id': 'l2', 'data': {}},
        ],
        schedules: [
          {'id': 's1', 'data': {}},
        ],
      ),
    );
    expect(p.projects, 2);
    expect(p.templates, 1);
    expect(p.layouts, 2);
    expect(p.schedules, 1);
  });

  test('옛 백업(배치도·내 일정 없음)은 0으로 읽고 그대로 복원할 수 있다', () {
    final p = parseBackup(backupText());
    expect(p.layouts, 0);
    expect(p.schedules, 0);
    expect(p.projects, 2);
  });

  test('한 줄 요약: 있는 것만 붙인다', () {
    expect(backupContentsLine(parseBackup(backupText())), '프로젝트 2건, 템플릿 1개');
    expect(
      backupContentsLine(
        parseBackup(
          backupText(
            layouts: [
              {'id': 'l1'},
            ],
          ),
        ),
      ),
      '프로젝트 2건, 템플릿 1개, 배치도 1개',
    );
    expect(
      backupContentsLine(
        parseBackup(
          backupText(
            layouts: [
              {'id': 'l1'},
            ],
            schedules: [
              {'id': 's1'},
              {'id': 's2'},
            ],
          ),
        ),
      ),
      '프로젝트 2건, 템플릿 1개, 배치도 1개, 내 일정 2건',
    );
  });

  test('프로젝트 복원 미리 보기는 그대로 동작한다', () {
    final p = parseBackup(backupText());
    final plan = planRestore(p, [
      {'id': '1', 'name': 'A현재'},
      {'id': '9', 'name': '없는것'},
    ]);
    expect(plan.overwritten, ['A']);
    expect(plan.added, ['B']);
    expect(plan.untouched, 1);
  });

  test('이 앱의 백업이 아니면 알려 준다', () {
    expect(() => parseBackup('{"app":"x"}'), throwsFormatException);
  });
}
