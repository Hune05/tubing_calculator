import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/main.dart'
    show flutterLocalNotificationsPlugin;
import 'package:tubing_calculator/src/presentation/my_work_logs/models/report_tools.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/notification_check_page.dart';

import 'helpers_text.dart';

// 아침 요약 알림: 켜고 끄기, 예약, 알림 점검 표시.
Map<String, dynamic> proj(String name) => {
  'id': name,
  'name': name,
  'status': 'ACTIVE',
  'phases': [],
  'schedules': [],
  'punch_lists': [],
  'daily_reports': [],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <String>[];
  List<Map<String, Object?>> pending = [];

  setUp(() => SharedPreferences.setMockInitialValues({}));

  final id = kMorningSummaryId;

  group('설정 저장', () {
    test('처음에는 꺼져 있고 시간은 07:30', () async {
      final m = await loadMorningSummary();
      expect(m.enabled, false);
      expect(m.minutes, 7 * 60 + 30);
    });

    test('저장하면 다시 읽힌다', () async {
      await saveMorningSummary(true, 8 * 60);
      final m = await loadMorningSummary();
      expect(m.enabled, true);
      expect(m.minutes, 480);
    });
  });

  group('예약', () {
    setUp(() {
      calls.clear();
      pending = [];
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
                calls.add(
                  'schedule:${(a as Map)['id']}:${a['title']}:${a['body']}',
                );
                return null;
              case 'pendingNotificationRequests':
                return pending;
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

    final now = DateTime(2026, 9, 19, 20); // 저녁 8시

    test('꺼져 있으면 예약하지 않고 예전 것만 취소한다', () async {
      await syncReportReminder([proj('A')], nowForTest: now);
      expect(calls, contains('cancel:$id'));
      expect(calls.where((c) => c.startsWith('schedule:$id')), isEmpty);
    });

    test('켜면 정한 시간으로 예약한다(문구는 확인하라는 말만)', () async {
      await saveMorningSummary(true, 7 * 60 + 30);
      await syncReportReminder([proj('A')], nowForTest: now);
      final s = calls.where((c) => c.startsWith('schedule:$id')).single;
      expect(s, 'schedule:$id:오늘 할 일:$kMorningSummaryBody');
      expect(kMorningSummaryBody, '오늘 일정과 작성할 작업 일지를 확인하십시오.');
    });

    test('진행중 프로젝트가 없어도 켜 두었으면 예약한다', () async {
      await saveMorningSummary(true, 7 * 60 + 30);
      await syncReportReminder([], nowForTest: now);
      expect(calls.where((c) => c.startsWith('schedule:$id')).length, 1);
    });

    test('도착 창(정해진 시간~+70분) 안에서 이미 예약돼 있으면 그대로 둔다', () async {
      await saveMorningSummary(true, 7 * 60 + 30);
      pending = [
        {'id': id, 'title': '오늘 할 일', 'body': 'x', 'payload': null},
      ];
      await syncReportReminder([
        proj('A'),
      ], nowForTest: DateTime(2026, 9, 20, 7, 50));
      expect(calls.contains('cancel:$id'), false);
      expect(calls.where((c) => c.startsWith('schedule:$id')), isEmpty);
    });

    test('창 밖이면 다시 예약한다', () async {
      await saveMorningSummary(true, 7 * 60 + 30);
      pending = [
        {'id': id, 'title': '오늘 할 일', 'body': 'x', 'payload': null},
      ];
      await syncReportReminder([
        proj('A'),
      ], nowForTest: DateTime(2026, 9, 20, 12));
      expect(calls.where((c) => c.startsWith('schedule:$id')).length, 1);
    });

    test('끄면 예약을 취소한다', () async {
      await saveMorningSummary(false, 7 * 60 + 30);
      pending = [
        {'id': id, 'title': '오늘 할 일', 'body': 'x', 'payload': null},
      ];
      await syncReportReminder([proj('A')], nowForTest: now);
      expect(calls, contains('cancel:$id'));
    });
  });

  group('알림 점검 표시', () {
    // 앞 묶음이 남긴 알림 도구 상태와 상관없이 같은 조건에서 시작한다(호출에는 빈 답을 준다).
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'pendingNotificationRequests') return [];
            return null;
          });
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    Future<void> open(WidgetTester tester, Set<int> pendingIds) async {
      tester.view.physicalSize = const Size(900, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: NotificationCheckPage(
            logs: const [],
            pendingIdsLoader: () async => pendingIds,
            recordActive: () async {},
            exactChecker: () async => true,
            personalStatusLoader: () async => null,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('꺼져 있으면 줄이 없다', (tester) async {
      await open(tester, {});
      expect(findTextContaining('아침 요약 알림'), findsNothing);
    });

    testWidgets('켜져 있고 예약돼 있으면 예약됨', (tester) async {
      await saveMorningSummary(true, 7 * 60 + 30);
      await open(tester, {id});
      expect(findText('아침 요약 알림: 예약됨 (매일 07:30)'), findsOneWidget);
    });

    testWidgets('켜져 있는데 예약이 없으면 예약 안 됨', (tester) async {
      await saveMorningSummary(true, 8 * 60);
      await open(tester, {});
      expect(findText('아침 요약 알림: 예약 안 됨 (매일 08:00)'), findsOneWidget);
    });
  });
}
