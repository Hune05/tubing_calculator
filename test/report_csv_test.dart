// 작업 일지 CSV: 머리줄·따옴표·줄바꿈 처리, 기간 걸러내기.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/report_csv.dart';

Map<String, dynamic> _log() => {
  'id': 'p1',
  'name': '루마 "계장"',
  'daily_reports': [
    {
      'date': '09/29',
      'dateISO': '2026-09-29',
      'note': '센서 결선\n튜브 연결, "완료"',
      'worker_count': 3,
      'overtime_hours': 1.5,
      'points': 12,
      'wiring_points': 4,
      'work_type': ['결선/트레이싱', '검사/테스트'],
    },
    {'date': '08/31', 'dateISO': '2026-08-31', 'note': '지난달 것'},
    {'date': '09/01', 'dateISO': '2026-09-01', 'note': '월초'},
  ],
};

void main() {
  test('머리줄은 BOM으로 시작하고 열 이름이 맞다', () {
    final csv = buildReportsCsv(const []);
    expect(csv.startsWith('﻿프로젝트,날짜,'), true);
    expect(csv.trim().split('\n').length, 1);
  });

  test('한 줄 = 일지 하나, 따옴표와 줄바꿈이 안전하다', () {
    final log = _log();
    final csv = buildReportsCsv(reportsInRange(log, DateTime(2026, 9, 1), DateTime(2026, 9, 30)));
    final lines = csv.trim().split('\n');
    expect(lines.length, 3); // 머리 + 일지 2개
    // 날짜 오름차순: 9/1 → 9/29
    expect(lines[1], contains('2026-09-01'));
    expect(lines[2], contains('2026-09-29'));
    expect(lines[2], contains('"루마 ""계장"""'));
    expect(lines[2], contains('"센서 결선 튜브 연결, ""완료"""'));
    // 예전 이름('검사/테스트')으로 저장된 일지도 새 이름으로 나온다.
    expect(lines[2], contains('"결선/트레이싱/검사/시험"'));
    expect(lines[2], contains(',3,1.5,12,4,'));
  });

  test('기간 경계 날짜는 포함하고 밖은 뺀다', () {
    final log = _log();
    final rows = reportsInRange(log, DateTime(2026, 9, 1), DateTime(2026, 9, 29));
    expect(rows.length, 2);
    final none = reportsInRange(log, DateTime(2026, 10, 1), DateTime(2026, 10, 31));
    expect(none, isEmpty);
    final aug = reportsInRange(log, DateTime(2026, 8, 1), DateTime(2026, 8, 31));
    expect(aug.single.$2['note'], '지난달 것');
  });
}
