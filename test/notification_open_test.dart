// 알림을 누르면 그 항목을 열고, 알림 권한은 켜는 순간에 한 번만 묻는지(점검 34번).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/main.dart' show routeForNotification;
import 'package:tubing_calculator/src/presentation/my_schedule/schedule_reminders.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/reminder_tools.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/hold_alarm.dart'
    show kPtHoldPayload;
import 'package:tubing_calculator/src/presentation/pressure_test/pressure_test_page.dart';

void main() {
  test('개인 일정 알림 글: 일정 id와 날짜가 되읽힌다', () {
    final p = personalReminderPayload('doc-1', DateTime(2026, 10, 3, 9, 30));
    final r = parsePersonalReminderPayload(p)!;
    expect(r.id, 'doc-1');
    expect(r.date, DateTime(2026, 10, 3));
    // 반복 알림은 날짜 없이(=오늘을 연다)
    expect(
      parsePersonalReminderPayload(personalReminderPayload('d', null))!.date,
      isNull,
    );
    // 다른 알림(일일·주간 보고)은 개인 일정이 아니다
    expect(parsePersonalReminderPayload('daily_report'), isNull);
    expect(parsePersonalReminderPayload(null), isNull);
  });

  test('누르면 열 화면: 개인 일정 → 내 일정, 서버 알림 → 작업 일지, 나머지는 없음', () {
    // 예전: 개인 일정 알림엔 글이 없고, 서버 알림은 글만 찍어 홈만 떴다.
    expect(
      routeForNotification(
        personalReminderPayload('d', DateTime(2026, 10, 3)),
        {},
      ),
      isA<MaterialPageRoute<void>>(),
    );
    expect(routeForNotification(null, {'open': 'work_logs'}), isNotNull);
    // 전기 기준(KEC) 새 개정 공고 → 현장 자료 전기 기준 탭
    expect(
      routeForNotification(null, {'open': 'reference_kec'}),
      isA<MaterialPageRoute<void>>(),
    );
    expect(routeForNotification('weekly_report', {}), isNull);
    expect(routeForNotification(null, {}), isNull);
  });

  test('압력 시험 유지시간 완료 알림 글 → 압력 시험 화면(시험 기록 탭)', () {
    expect(kPtHoldPayload, 'pressure_test_record');
    expect(kPtRecordTabIndex, 4);
    expect(
      routeForNotification(kPtHoldPayload, {}),
      isA<MaterialPageRoute<void>>(),
    );
    // 서버 알림 칸(data)으로는 열지 않는다(폰 예약 알림 글만)
    expect(routeForNotification(null, {'open': kPtHoldPayload}), isNull);
  });

  testWidgets('유지시간 완료 알림: 시험 기록 탭으로 열고, 이미 열려 있으면 그 화면의 탭만 바꾼다', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        home: const Scaffold(body: Text('홈')),
      ),
    );
    expect(PressureTestPage.revealOpen(kPtRecordTabIndex), isFalse);

    // 앱이 꺼져 있을 때(또는 화면이 없을 때): 알림 글로 만든 화면을 연다
    nav.currentState!.push(routeForNotification(kPtHoldPayload, {})!);
    await tester.pumpAndSettle();
    TabController tabs() => tester
        .widget<TabBar>(
          find.ancestor(
            of: find.byKey(const Key('pt_tab_record')),
            matching: find.byType(TabBar),
          ),
        )
        .controller!;
    expect(tabs().index, kPtRecordTabIndex);

    // 앱 실행 중: 다른 탭·다른 화면을 보고 있어도 새로 열지 않고 그 화면의 시험 기록 탭으로
    tabs().animateTo(0);
    await tester.pumpAndSettle();
    nav.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('위 화면')),
      ),
    );
    await tester.pumpAndSettle();
    expect(PressureTestPage.revealOpen(kPtRecordTabIndex), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('위 화면'), findsNothing);
    expect(find.byType(PressureTestPage), findsOneWidget);
    expect(tabs().index, kPtRecordTabIndex);

    // 화면을 닫으면 다시 새로 연다
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(PressureTestPage.revealOpen(kPtRecordTabIndex), isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  test('알림 권한은 처음 한 번만 묻는다', () async {
    SharedPreferences.setMockInitialValues({});
    await ensureNotificationPermission();
    final p = await SharedPreferences.getInstance();
    expect(p.getBool('notif_permission_asked_v1'), isTrue);
    await ensureNotificationPermission(); // 두 번째는 묻지 않고 바로
  });
}
