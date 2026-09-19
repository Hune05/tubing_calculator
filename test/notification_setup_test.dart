import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/notification_check_page.dart';

import 'helpers_text.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('안드로이드 설정(AndroidManifest.xml)', () {
    // 이 설정이 빠지면 예약한 알림이 시간이 돼도 화면에 나오지 않는다(바로 띄우는 알림만 나온다).
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    test('예약 알림을 띄우는 수신기가 있다', () {
      expect(
        manifest.contains(
          'com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver',
        ),
        true,
      );
    });

    test('폰을 다시 켜도 예약이 살아 있게 하는 수신기와 권한이 있다', () {
      expect(
        manifest.contains(
          'com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver',
        ),
        true,
      );
      expect(
        manifest.contains('android.permission.RECEIVE_BOOT_COMPLETED'),
        true,
      );
      expect(manifest.contains('android.intent.action.BOOT_COMPLETED'), true);
    });

    test('정확한 시간 알림을 요청할 수 있는 권한이 있다', () {
      expect(
        manifest.contains('android.permission.SCHEDULE_EXACT_ALARM'),
        true,
      );
    });
  });

  group('알림 점검: 정확한 시간 알림·예약 테스트', () {
    Future<void> open(
      WidgetTester tester, {
      required Future<bool> Function() checker,
      Future<bool> Function()? requester,
      Future<DateTime> Function()? scheduleTest,
    }) async {
      tester.view.physicalSize = const Size(900, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: NotificationCheckPage(
            logs: const [],
            pendingIdsLoader: () async => {},
            recordActive: () async {},
            exactChecker: checker,
            exactRequester: requester,
            scheduleTest: scheduleTest,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('허용 안 됨이면 안내와 허용하기 버튼이 보인다', (tester) async {
      await open(tester, checker: () async => false);
      expect(find.text('정확한 시간 알림: 허용 안 됨'), findsOneWidget);
      expect(find.text('허용하기'), findsOneWidget);
      expect(findTextContaining('최대 1시간 안에 알림이 옵니다'), findsOneWidget);
    });

    testWidgets('허용돼 있으면 버튼이 없고 시간에 맞춰 온다고 안내한다', (tester) async {
      await open(tester, checker: () async => true);
      expect(find.text('정확한 시간 알림: 허용됨'), findsOneWidget);
      expect(find.text('허용하기'), findsNothing);
      expect(findTextContaining('정해진 시간에 맞춰 알림이 옵니다'), findsOneWidget);
    });

    testWidgets('허용하기를 누르면 요청하고 상태를 다시 읽는다', (tester) async {
      var allowed = false;
      var asked = 0;
      await open(
        tester,
        checker: () async => allowed,
        requester: () async {
          asked++;
          allowed = true; // 사용자가 설정에서 허용한 것을 흉내
          return true;
        },
      );
      await tester.tap(find.text('허용하기'));
      await tester.pumpAndSettle();
      expect(asked, 1);
      expect(find.text('정확한 시간 알림: 허용됨'), findsOneWidget);
    });

    testWidgets('1분 뒤 예약 알림 테스트를 누르면 예약하고 시각을 알려 준다', (tester) async {
      var called = 0;
      await open(
        tester,
        checker: () async => true,
        scheduleTest: () async {
          called++;
          return DateTime(2026, 9, 19, 21, 5);
        },
      );
      await tester.tap(find.text('1분 뒤 예약 알림 테스트'));
      await tester.pumpAndSettle();
      expect(called, 1);
      expect(findTextContaining('21:05에 예약 알림이 옵니다'), findsOneWidget);
    });

    testWidgets('예약 테스트가 실패해도 죽지 않고 실패를 알린다', (tester) async {
      await open(
        tester,
        checker: () async => true,
        scheduleTest: () async => throw StateError('boom'),
      );
      await tester.tap(find.text('1분 뒤 예약 알림 테스트'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(findTextContaining('예약 알림 테스트 실패'), findsOneWidget);
    });
  });
}
