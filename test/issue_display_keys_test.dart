// 대시보드 "미해결 이슈"에서 고친 이슈를 프로젝트에 넣을 때 화면용 칸을 뺀다(10-08).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/screens/work_log_main_screen.dart';

void main() {
  test('프로젝트 참조를 뺀 이슈를 넣으면 프로젝트가 순환 없이 저장 글로 바뀐다', () {
    final project = <String, dynamic>{'name': '1층', 'punch_lists': <dynamic>[]};
    final issue = <String, dynamic>{
      'id': 'p1',
      'title': '누설',
      'is_completed': true,
      '_projectRef': project,
      '_projectName': '1층',
    };
    stripIssueDisplayKeys(issue);
    (project['punch_lists'] as List).add(issue);
    expect(issue.containsKey('_projectRef'), isFalse);
    expect(issue.containsKey('_projectName'), isFalse);
    expect(() => jsonEncode(project), returnsNormally);
  });
}
