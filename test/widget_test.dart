import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/weekly_plan.dart';

// 예전 카운터 앱용 테스트가 전부 주석 처리돼 main이 없어 전체 테스트를 깨뜨렸다.
// Firebase 없이 돌릴 수 있는 간단한 확인으로 바꿨다.
void main() {
  test('weekRanges is Monday-based and consecutive', () {
    final w = weekRanges(DateTime(2026, 9, 19)); // 토요일
    expect(w.map((e) => e.label).toList(), ['전주', '금주', '차주']);
    expect(w[1].start, DateTime(2026, 9, 14)); // 월요일
    expect(w[1].end, DateTime(2026, 9, 20)); // 일요일
    expect(w[0].end.add(const Duration(days: 1)), w[1].start);
    expect(w[1].end.add(const Duration(days: 1)), w[2].start);
  });
}
