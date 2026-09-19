import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/weekly_plan.dart';

void main() {
  test('photos are grouped by project, then date', () {
    final today = DateTime.now();
    String md(DateTime d) => '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
    Map<String, dynamic> proj(String id, String name, List<String> imgs) => {
          'id': id, 'name': name, 'status': 'ACTIVE',
          'phases': [], 'schedules': [],
          'daily_reports': [
            {
              'date': md(today),
              'dateISO': DateTime(today.year, today.month, today.day).toIso8601String(),
              'image_paths': imgs,
            },
          ],
        };
    final logs = [proj('a', 'A현장', ['a1', 'a2']), proj('b', 'B현장', ['b1'])];
    final d = buildWeeklyPlanDoc(logs, includePhotos: true);
    expect(d.photos.map((p) => p.path).toList(), ['a1', 'a2', 'b1']);
    expect(d.photos.map((p) => p.group).toList(), ['A현장', 'A현장', 'B현장']);
    final single = buildWeeklyPlanDoc([logs.first], includePhotos: true);
    expect(single.photos.every((p) => p.group == null), true);
  });
}
