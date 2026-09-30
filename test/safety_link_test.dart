// 안전 점검을 일지·내 알림·퀵바에 연결한 부분.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/common/quick_tool_bar.dart';
import 'package:tubing_calculator/src/presentation/notification/pages/my_notifications_tab.dart';
import 'package:tubing_calculator/src/presentation/safety/safety_check_model.dart';

SafetyRecord _r(String id, DateTime at) =>
    SafetyRecord(id: id, at: at, lines: const []);

void main() {
  final now = DateTime(2026, 9, 30, 10);

  group('오늘 했는지·최근 쓰는지', () {
    test('오늘 점검 중 가장 늦은 것을 돌려준다', () {
      final all = [
        _r('a', DateTime(2026, 9, 30, 7)),
        _r('b', DateTime(2026, 9, 30, 9)),
        _r('c', DateTime(2026, 9, 29, 23)),
      ];
      expect(safetyCheckToday(all, now)!.id, 'b');
      expect(safetyCheckToday([_r('c', DateTime(2026, 9, 29, 23))], now), isNull);
      expect(safetyCheckToday(const [], now), isNull);
    });

    test('최근 14일 안에 했으면 쓰는 사람', () {
      expect(safetyUsedRecently([_r('a', DateTime(2026, 9, 20))], now), true);
      expect(safetyUsedRecently([_r('a', DateTime(2026, 9, 10))], now), false);
      expect(safetyUsedRecently(const [], now), false);
    });
  });

  group('내 알림', () {
    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MyNotificationsTab(currentWorker: '시험')),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('최근에 쓰던 사람이 오늘 안 했으면 알린다', (tester) async {
      final y = DateTime.now().subtract(const Duration(days: 1));
      await addSafetyRecordForTest(_r('y', y));
      await open(tester);
      expect(find.text('오늘 안전 점검 아직'), findsOneWidget);
    });

    testWidgets('오늘 했으면 알리지 않는다', (tester) async {
      await addSafetyRecordForTest(_r('t', DateTime.now()));
      await open(tester);
      expect(find.text('오늘 안전 점검 아직'), findsNothing);
    });

    testWidgets('안 써 본 사람에게는 알리지 않는다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await open(tester);
      expect(find.text('오늘 안전 점검 아직'), findsNothing);
    });
  });

  test('퀵바에 벤딩 실측 기록·안전 점검이 있고 id가 겹치지 않는다', () {
    final ids = kQuickTools.map((t) => t.id).toList();
    expect(ids, containsAll(['bendcheck', 'safety']));
    expect(ids.toSet().length, ids.length);
  });
}

Future<void> addSafetyRecordForTest(SafetyRecord r) async {
  SharedPreferences.setMockInitialValues({});
  await addSafetyRecord(r);
}
