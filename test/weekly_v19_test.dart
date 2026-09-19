import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/report_tools.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/notification_check_page.dart';

String md(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

Map<String, dynamic> proj(
  String name, {
  int? remind,
  String status = 'ACTIVE',
}) {
  return {
    'id': name,
    'name': name,
    'status': status,
    'phases': [],
    'schedules': [],
    'punch_lists': [],
    if (remind != null) 'reportReminderMinutes': remind,
    'daily_reports': [],
  };
}

// 폰에 실제로 예약된 알림 아이디를 흉내 낸다(일보 알림 아이디는 918300부터).
const base = 918300;

Future<void> pump(WidgetTester tester, Widget w) async {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: w));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('dailyReminderSlots', () {
    final now = DateTime(2026, 9, 19, 10);
    final logs = [
      proj('A'),
      proj('B', remind: 21 * 60),
      proj('끝', status: 'DONE'),
    ];

    test('every needed alarm carries whether it is really scheduled', () {
      final all = dailyReminderSlots(logs, 18 * 60, now, {base, base + 1});
      expect(all.length, 2);
      expect(all.map((s) => s.id).toList(), [base, base + 1]);
      expect(all.every((s) => s.scheduled), true);
      expect(all[0].plan.minutes, 1080);
      expect(all[1].plan.minutes, 1260);
    });

    test('only the missing ones are flagged', () {
      final s = dailyReminderSlots(logs, 18 * 60, now, {base});
      expect(s[0].scheduled, true);
      expect(s[1].scheduled, false);
      final none = dailyReminderSlots(logs, 18 * 60, now, {});
      expect(none.every((x) => !x.scheduled), true);
    });

    test('unrelated pending ids do not count; extra ids are ignored', () {
      final s = dailyReminderSlots(logs, 18 * 60, now, {918274, 777, base + 5});
      expect(s.every((x) => !x.scheduled), true);
    });

    test('no active projects → no slots', () {
      expect(
        dailyReminderSlots([proj('끝', status: 'DONE')], 1080, now, {}),
        isEmpty,
      );
    });
  });

  group('알림 점검: 어긋난 항목만 다시 예약', () {
    Widget page({
      required List<Map<String, dynamic>> logs,
      required Set<int> Function() pending,
      required List<int> rescheduled,
      List<String>? weeklyCalls,
    }) => NotificationCheckPage(
      logs: logs,
      pendingIdsLoader: () async => pending(),
      rescheduleSlot: (s) async => rescheduled.add(s.id),
      rescheduleWeekly: () async => weeklyCalls?.add('weekly'),
    );

    final logs2 = [proj('A현장'), proj('B현장', remind: 21 * 60)];

    testWidgets('all scheduled: every row says 예약됨 and no per-item button', (
      tester,
    ) async {
      final called = <int>[];
      await pump(
        tester,
        page(logs: logs2, pending: () => {base, base + 1}, rescheduled: called),
      );
      expect(find.text('예약됨'), findsNWidgets(2));
      expect(find.text('예약 안 됨'), findsNothing);
      expect(find.text('다시 예약'), findsNothing);
    });

    testWidgets('one missing: only that row shows the red state and button', (
      tester,
    ) async {
      final called = <int>[];
      await pump(
        tester,
        page(logs: logs2, pending: () => {base}, rescheduled: called),
      );
      expect(find.text('예약됨'), findsOneWidget);
      expect(find.text('예약 안 됨'), findsOneWidget);
      expect(find.text('다시 예약'), findsWidgets); // 항목별 + 아래 전체 확인 카드의 버튼
      // 항목 줄 안의 "다시 예약" 하나만 누른다(21:00 줄).
      final row = find
          .ancestor(of: find.text('예약 안 됨'), matching: find.byType(Row))
          .first;
      await tester.tap(find.descendant(of: row, matching: find.text('다시 예약')));
      await tester.pumpAndSettle();
      // 어긋난 것(918301)만 다시 예약되고, 멀쩡한 918300은 건드리지 않는다.
      expect(called, [base + 1]);
      expect(find.textContaining('21:00 알림을 다시 예약했습니다'), findsOneWidget);
    });

    testWidgets('after the reschedule the state is re-read and turns green', (
      tester,
    ) async {
      final pendingNow = <int>{base};
      final called = <int>[];
      await pump(
        tester,
        NotificationCheckPage(
          logs: logs2,
          pendingIdsLoader: () async => {...pendingNow},
          rescheduleSlot: (s) async {
            called.add(s.id);
            pendingNow.add(s.id); // 폰에 예약이 생긴 것을 흉내
          },
        ),
      );
      expect(find.text('예약 안 됨'), findsOneWidget);
      final row = find
          .ancestor(of: find.text('예약 안 됨'), matching: find.byType(Row))
          .first;
      await tester.tap(find.descendant(of: row, matching: find.text('다시 예약')));
      await tester.pumpAndSettle();
      expect(called, [base + 1]);
      expect(find.text('예약 안 됨'), findsNothing);
      expect(find.text('예약됨'), findsNWidgets(2));
    });

    testWidgets('a failing reschedule shows an error and does not crash', (
      tester,
    ) async {
      await pump(
        tester,
        NotificationCheckPage(
          logs: logs2,
          pendingIdsLoader: () async => {},
          rescheduleSlot: (s) async => throw StateError('boom'),
        ),
      );
      expect(find.text('예약 안 됨'), findsNWidgets(2));
      final row = find
          .ancestor(of: find.text('예약 안 됨').first, matching: find.byType(Row))
          .first;
      await tester.tap(find.descendant(of: row, matching: find.text('다시 예약')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('다시 예약하지 못했습니다'), findsOneWidget);
    });

    testWidgets(
      'when the phone state cannot be read, times are listed without status',
      (tester) async {
        await pump(
          tester,
          NotificationCheckPage(
            logs: logs2,
            pendingIdsLoader: () async => throw StateError('no plugin'),
          ),
        );
        expect(find.textContaining('· 18:00'), findsOneWidget);
        expect(find.textContaining('· 21:00'), findsOneWidget);
        expect(find.text('예약 안 됨'), findsNothing);
        expect(find.text('예약됨'), findsNothing);
      },
    );
  });
}
