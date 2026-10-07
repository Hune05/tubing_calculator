// 쓰다 만 일지 임시 저장은 7일 남는다(10-07: 2일이라 금요일 것이 월요일에 지워졌다).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/report_tools.dart';

void main() {
  test('3일 된 임시 저장은 남고, 8일 된 것만 지운다', () async {
    final now = DateTime.now();
    String draft(int days) =>
        jsonEncode({'savedAt': now.subtract(Duration(days: days)).toIso8601String()});
    SharedPreferences.setMockInitialValues({
      'report_draft_fri': draft(3),
      'report_draft_old': draft(8),
    });
    await cleanOldDrafts();
    final p = await SharedPreferences.getInstance();
    expect(p.containsKey('report_draft_fri'), isTrue);
    expect(p.containsKey('report_draft_old'), isFalse);
    expect(kReportDraftKeep, const Duration(days: 7));
  });
}
