import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/main.dart'
    show flutterLocalNotificationsPlugin;
import 'package:tubing_calculator/src/presentation/my_schedule/schedule_reminders.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/notification_check_page.dart';

import 'helpers_text.dart';

// 개인 일정(내 일정 관리) 알림 예약과, 알림 점검 화면에서의 예약 상태 표시.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('개인 일정 알림 예약', () {
    final calls = <String>[];
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      calls.clear();
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            final a = call.arguments;
            switch (call.method) {
              case 'cancel':
                calls.add('cancel:${(a as Map)['id']}');
                return null;
              case 'zonedSchedule':
                calls.add('schedule:${(a as Map)['id']}:${a['title']}');
                return null;
              default:
                return null;
            }
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    });

    // 알림 플러그인은 실제 시계로 "미래인지"를 확인하므로, 오늘이 지나도 깨지지 않게 먼 미래 날짜를 쓴다.
    final now = DateTime(2040, 9, 19, 12);
    Map<String, dynamic> data({
      int minutes = 30,
      String recurrence = 'none',
      DateTime? at,
      bool hasTime = true,
    }) => {
      'title': '검사',
      'dateTime': (at ?? DateTime(2040, 9, 20, 10)).toIso8601String(),
      'hasTime': hasTime,
      'recurrence': recurrence,
      'reminderMinutesBefore': minutes,
    };

    test('같은 일정은 늘 같은 알림 아이디를 쓴다', () {
      expect(personalNotifId('abc'), personalNotifId('abc'));
      expect(personalNotifId('abc'), isNot(personalNotifId('abd')));
      expect(personalNotifId('abc'), greaterThanOrEqualTo(0));
    });

    test('알림이 필요하면 예전 예약을 취소하고 새로 예약한다', () async {
      await schedulePersonalReminder('doc1', data(), nowForTest: now);
      final id = personalNotifId('doc1');
      expect(calls.first, 'cancel:$id');
      expect(calls, contains('schedule:$id:일정 알림'));
    });

    test('알림 없음(0분)이면 취소만 한다', () async {
      await schedulePersonalReminder('doc1', data(minutes: 0), nowForTest: now);
      expect(calls.where((c) => c.startsWith('schedule')), isEmpty);
      expect(calls.where((c) => c.startsWith('cancel')).length, 1);
    });

    test('날짜 칸이 없거나 글이 아니면 그 일정만 건너뛴다(예외 없음)', () async {
      final bad = data()..remove('dateTime');
      await schedulePersonalReminder('doc1', bad, nowForTest: now);
      await schedulePersonalReminder(
        'doc2',
        data()..['dateTime'] = 12345,
        nowForTest: now,
      );
      expect(calls.where((c) => c.startsWith('schedule')), isEmpty);
    });

    test('종일 일정이거나 이미 지난 알림이면 예약하지 않는다', () async {
      await schedulePersonalReminder(
        'doc1',
        data(hasTime: false),
        nowForTest: now,
      );
      await schedulePersonalReminder(
        'doc2',
        data(at: DateTime(2040, 9, 19, 12, 10)),
        nowForTest: now,
      );
      expect(calls.where((c) => c.startsWith('schedule')), isEmpty);
    });
  });

  group('알림 점검: 개인 일정 알림 상태', () {
    // 앞 그룹이 남긴 알림 도구 상태와 상관없이 같은 조건에서 시작한다(알림 도구 호출은 빈 답을 준다).
    const ch = MethodChannel('dexterous.com/flutter/local_notifications');
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ch, (call) async {
            if (call.method == 'pendingNotificationRequests') return [];
            return null;
          });
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ch, null);
    });

    Future<void> open(
      WidgetTester tester, {
      required Future<({int expected, int scheduled})?> Function() status,
      Future<int> Function()? resched,
    }) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(900, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: NotificationCheckPage(
            logs: const [],
            pendingIdsLoader: () async => {},
            recordActive: () async {},
            exactChecker: () async => true,
            personalStatusLoader: status,
            personalRescheduler: resched,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('맞게 예약돼 있으면 예약됨으로 보인다', (tester) async {
      await open(tester, status: () async => (expected: 2, scheduled: 2));
      expect(findTextContaining('개인 일정 알림: 예약됨 (2개)'), findsOneWidget);
      expect(find.text('개인 일정 알림 다시 예약'), findsNothing);
    });

    testWidgets('모자라면 안내와 다시 예약 버튼이 나오고, 누르면 다시 읽는다', (tester) async {
      var scheduled = 1;
      var called = 0;
      await open(
        tester,
        status: () async => (expected: 3, scheduled: scheduled),
        resched: () async {
          called++;
          scheduled = 3;
          return 3;
        },
      );
      expect(findTextContaining('필요한 3개 중 1개만 예약돼 있습니다'), findsOneWidget);
      await tester.tap(find.text('개인 일정 알림 다시 예약'));
      await tester.pumpAndSettle();
      expect(called, 1);
      expect(findTextContaining('개인 일정 알림 3개를 다시 예약했습니다'), findsOneWidget);
      expect(findTextContaining('개인 일정 알림: 예약됨 (3개)'), findsOneWidget);
    });

    testWidgets('알림을 켜 둔 일정이 없으면 예약됨(0개)이라고 하지 않는다', (tester) async {
      await open(tester, status: () async => (expected: 0, scheduled: 0));
      expect(findTextContaining('알림을 켜 둔 일정이 없습니다'), findsOneWidget);
      expect(findTextContaining('예약됨 (0개)'), findsNothing);
    });

    testWidgets('사용자를 모르면(null) 이 줄을 보이지 않는다', (tester) async {
      await open(tester, status: () async => null);
      expect(findTextContaining('개인 일정 알림:'), findsNothing);
    });

    testWidgets('상태 확인이 실패해도 화면이 죽지 않는다', (tester) async {
      await open(tester, status: () async => throw StateError('boom'));
      expect(tester.takeException(), isNull);
      expect(findTextContaining('개인 일정 알림:'), findsNothing);
    });
  });
}
