import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/main.dart'
    show flutterLocalNotificationsPlugin;
import 'package:tubing_calculator/src/presentation/my_work_logs/models/report_tools.dart';

// 알림은 정해진 시간부터 최대 1시간 안에 온다. 그 사이에 앱을 열어도 오늘 알림이 사라지면 안 된다.
Map<String, dynamic> proj(String name, {List<String> reportDates = const []}) =>
    {
      'id': name,
      'name': name,
      'status': 'ACTIVE',
      'phases': [],
      'schedules': [],
      'punch_lists': [],
      'daily_reports': [
        for (final d in reportDates) {'date': d},
      ],
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  group('도착 창', () {
    test('정해진 시간 ~ +70분 사이만 창 안', () {
      final base = DateTime(2026, 9, 19); // 토요일
      expect(
        inDeliveryWindow(
          base.add(const Duration(hours: 17, minutes: 59)),
          1080,
        ),
        false,
      );
      expect(inDeliveryWindow(base.add(const Duration(hours: 18)), 1080), true);
      expect(
        inDeliveryWindow(base.add(const Duration(hours: 19, minutes: 9)), 1080),
        true,
      );
      expect(
        inDeliveryWindow(
          base.add(const Duration(hours: 19, minutes: 10)),
          1080,
        ),
        false,
      );
    });

    test('주간 알림은 금요일에만', () {
      final fri = DateTime(2026, 9, 18, 17, 20); // 금요일
      final sat = DateTime(2026, 9, 19, 17, 20);
      expect(inDeliveryWindow(fri, 17 * 60, onlyFriday: true), true);
      expect(inDeliveryWindow(sat, 17 * 60, onlyFriday: true), false);
    });
  });

  group('알림 다시 예약(syncReportReminder)이 오늘 알림을 지우지 않는다', () {
    final calls = <String>[];
    List<Map<String, Object?>> pending = [];

    setUp(() {
      calls.clear();
      pending = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dexterous.com/flutter/local_notifications'),
            (call) async {
              switch (call.method) {
                case 'cancel':
                  calls.add('cancel:${(call.arguments as Map)['id']}');
                  return null;
                case 'zonedSchedule':
                  calls.add('schedule:${(call.arguments as Map)['id']}');
                  return null;
                case 'pendingNotificationRequests':
                  return pending;
                default:
                  return null;
              }
            },
          );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dexterous.com/flutter/local_notifications'),
            null,
          );
    });

    final at1820 = DateTime(2026, 9, 19, 18, 20); // 토요일 18:20(도착 창 안)
    final at2000 = DateTime(2026, 9, 19, 20, 0); // 창 밖

    test('창 안·예약돼 있음·아직 일보 안 씀 → 그대로 둔다(취소도 재예약도 없음)', () async {
      pending = [
        {'id': 918300, 'title': '작업일보', 'body': 'x', 'payload': 'p'},
      ];
      await syncReportReminder([proj('A')], nowForTest: at1820);
      expect(calls.contains('cancel:918300'), false);
      expect(calls.contains('schedule:918300'), false);
    });

    test('창 안이어도 그 사이 오늘 일보를 다 썼다면 지운다', () async {
      pending = [
        {'id': 918300, 'title': '작업일보', 'body': 'x', 'payload': 'p'},
      ];
      await syncReportReminder([
        proj('A', reportDates: ['09/19']),
      ], nowForTest: at1820);
      expect(calls.contains('cancel:918300'), true);
    });

    test('창 밖이면 예전처럼 다시 예약한다(내용 새로고침)', () async {
      pending = [
        {'id': 918300, 'title': '작업일보', 'body': 'x', 'payload': 'p'},
      ];
      await syncReportReminder([proj('A')], nowForTest: at2000);
      expect(calls.contains('cancel:918300'), true);
      expect(calls.contains('schedule:918300'), true);
    });

    test('창 안이라도 폰에 예약이 없으면 새로 예약한다', () async {
      await syncReportReminder([proj('A')], nowForTest: at1820);
      expect(calls.contains('schedule:918300'), true);
    });
  });
}
