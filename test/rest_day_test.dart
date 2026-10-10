// 쉬는 날(토·일·공휴일) 알림 규칙(10-10, 사용자: "휴일에는 업무를 안 하는 일이 많은데 업무 일지를 작성하라거나 …
// 작업 지연 알람도 휴일에 오는 건"): 작업 일지 알림은 근무일에만, 쉬는 날 출근(특근)을 찍었으면 그날도.
// 서버 알림(functions/rest_day.js)과 공휴일 표가 같은지도 본다.
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/main.dart'
    show flutterLocalNotificationsPlugin;
import 'package:tubing_calculator/src/core/utils/rest_day.dart';
import 'package:tubing_calculator/src/presentation/my_schedule/korean_holidays.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:tubing_calculator/src/presentation/my_work_logs/models/report_tools.dart';

/// 폰 시각 [local](이 기기 시간대)을 앱처럼 서울 시간대로 바꿔 예약 글 모양('2026-10-12T18:00')으로.
/// 10-10: 시험 PC가 한국 시간이라 '2026-10-12T18:00'을 그대로 적었더니 UTC로 도는 GitHub 시험에서는
/// 같은 순간이 '2026-10-13T03:00'으로 적혀 실패했다. 기대값도 같은 길로 바꿔 시간대와 상관없게 한다.
String seoulOf(DateTime local) {
  late tz.Location seoul;
  try {
    seoul = tz.getLocation('Asia/Seoul');
  } catch (_) {
    // 시간대 표를 처음 읽으면 tz.local이 UTC로 돌아가므로 앱과 같이 서울로 다시 둔다.
    tzdata.initializeTimeZones();
    seoul = tz.getLocation('Asia/Seoul');
    tz.setLocalLocation(seoul);
  }
  final t = tz.TZDateTime.from(local, seoul);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)}T${two(t.hour)}:${two(t.minute)}';
}

Map<String, dynamic> proj(String name, {List<String> reportDates = const []}) =>
    {
      'id': name,
      'name': name,
      'status': 'ONGOING',
      'daily_reports': [
        for (final d in reportDates) {'date': d},
      ],
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('쉬는 날', () {
    test('토·일·공휴일·대체공휴일', () {
      expect(isRestDay(DateTime(2026, 10, 10)), isTrue); // 토
      expect(isRestDay(DateTime(2026, 10, 11)), isTrue); // 일
      expect(isRestDay(DateTime(2026, 10, 9)), isTrue); // 한글날(금)
      expect(isRestDay(DateTime(2026, 10, 5)), isTrue); // 대체공휴일(월)
      expect(isRestDay(DateTime(2026, 10, 12)), isFalse); // 월
    });

    test('근무일 줄·앞 근무일', () {
      expect(workdaySeries(DateTime(2026, 10, 8, 18), 4), [
        DateTime(2026, 10, 8, 18),
        DateTime(2026, 10, 12, 18), // 9일 한글날, 10·11일 주말 건너뜀
        DateTime(2026, 10, 13, 18),
        DateTime(2026, 10, 14, 18),
      ]);
      expect(
        previousWorkday(DateTime(2026, 10, 11, 9)),
        DateTime(2026, 10, 8, 9),
      );
      expect(
        previousWorkday(DateTime(2026, 10, 14, 9)),
        DateTime(2026, 10, 14, 9),
      );
    });

    test('서버(functions/rest_day.js) 공휴일 표가 앱 표와 같다', () {
      final js = File('functions/rest_day.js').readAsStringSync();
      final server = RegExp(
        r'"(\d{4}-\d{2}-\d{2})"',
      ).allMatches(js).map((m) => m.group(1)!).toSet();
      expect(server, kKoreanHolidays.keys.toSet());
    });
  });

  group('작업 일지 알림 계획', () {
    test('토요일: 다음 근무일(월) 저녁으로, 특근이면 오늘', () {
      final sat = DateTime(2026, 10, 10, 10);
      final p = planDailyReminders([proj('A')], 18 * 60, sat).single;
      expect(p.at, DateTime(2026, 10, 12, 18));
      final w = planDailyReminders(
        [proj('A')],
        18 * 60,
        sat,
        workedToday: true,
      ).single;
      expect(w.at, DateTime(2026, 10, 10, 18));
    });

    test('목요일 저녁 시간이 지나면 금요일(한글날)·주말을 건너 월요일', () {
      final thu = DateTime(2026, 10, 8, 19);
      expect(
        planDailyReminders([proj('A')], 18 * 60, thu).single.at,
        DateTime(2026, 10, 12, 18),
      );
    });

    test('뒤 근무일 예약은 토·일·공휴일을 빼고 10개', () {
      final mon = DateTime(2026, 10, 12, 10);
      final p = planDailyReminders([proj('A')], 18 * 60, mon).single;
      expect(p.at, DateTime(2026, 10, 12, 18));
      final extra = dailyExtraTimes(p, mon);
      expect(extra.length, kWorkdaySeriesDays);
      expect(extra.first, DateTime(2026, 10, 13, 18));
      expect(extra.any(isRestDay), isFalse);
    });

    test('쉬는 날에는 "확인 안 됨"을 띄우지 않는다', () {
      final sat = DateTime(2026, 10, 10, 23);
      final plan = planDailyReminders([proj('A')], 18 * 60, sat).single;
      expect(
        unconfirmedToday([ReminderSlot(918300, plan, true)], [], sat),
        isEmpty,
      );
    });
  });

  group('예약(폰)', () {
    final scheduled = <int, String>{};
    setUp(() {
      scheduled.clear();
      SharedPreferences.setMockInitialValues({});
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dexterous.com/flutter/local_notifications'),
            (call) async {
              if (call.method == 'zonedSchedule') {
                final a = call.arguments as Map;
                scheduled[a['id'] as int] = '${a['scheduledDateTime']}';
              }
              if (call.method == 'pendingNotificationRequests') return [];
              return null;
            },
          );
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dexterous.com/flutter/local_notifications'),
            null,
          );
      debugDefaultTargetPlatformOverride = null;
      workedOnDay = (_) async => false;
    });

    test('토요일 아침: 출근 안 찍었으면 월요일, 매일 반복이 아니라 근무일마다 따로', () async {
      final sat = DateTime(2026, 10, 10, 9);
      workedOnDay = (_) async => false;
      await withClock(
        Clock.fixed(sat),
        () => syncReportReminder([proj('A')], nowForTest: sat),
      );
      expect(
        scheduled[918300],
        startsWith(seoulOf(DateTime(2026, 10, 12, 18))),
      );
      final extras = [
        for (final e in scheduled.entries)
          if (e.key >= 918400 && e.key < 918480) e.value,
      ];
      expect(extras.length, kWorkdaySeriesDays);
      // 10/16(금) 다음은 주말을 건너 10/19(월)
      expect(extras, contains(startsWith(seoulOf(DateTime(2026, 10, 16, 18)))));
      expect(extras, contains(startsWith(seoulOf(DateTime(2026, 10, 19, 18)))));
      for (final weekend in [
        DateTime(2026, 10, 17, 18),
        DateTime(2026, 10, 18, 18),
      ]) {
        expect(extras.any((v) => v.startsWith(seoulOf(weekend))), isFalse);
      }
    });

    test('토요일 아침: 출근을 찍었으면(특근) 오늘 저녁', () async {
      final sat = DateTime(2026, 10, 10, 9);
      workedOnDay = (_) async => true;
      await withClock(
        Clock.fixed(sat),
        () => syncReportReminder([proj('A')], nowForTest: sat),
      );
      expect(
        scheduled[918300],
        startsWith(seoulOf(DateTime(2026, 10, 10, 18))),
      );
    });
  });
}
