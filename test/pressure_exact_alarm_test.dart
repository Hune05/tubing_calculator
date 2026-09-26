// 유지시간 알림: 정확한 알람이 꺼져 있으면 타이머 아래에 알리고 "설정 열기"로 허용 화면을 연다.
// 허용하고 돌아오면(설정 열기 결과 또는 앱이 다시 앞으로 올 때) 진행 중인 시험의 알림을 다시 예약한다.
// 폰 시험(09-26): 14:50:42 예약 알림이 14:56:11에 왔다(정확한 알람 권한 없음 → inexact).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/hold_alarm.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/pressure_test_page.dart';

class FakeAlarm extends HoldAlarm {
  final scheduled = <(DateTime, String, String)>[];
  var cancels = 0;
  var requests = 0;
  bool exact;
  bool grant; // "설정 열기"에서 허용하는지
  FakeAlarm({this.exact = false, this.grant = true});

  @override
  Future<void> schedule(
    DateTime at, {
    required String title,
    required String body,
  }) async => scheduled.add((at, title, body));

  @override
  Future<void> cancel() async => cancels++;

  @override
  Future<bool> canExact() async => exact;

  @override
  Future<bool> requestExact() async {
    requests++;
    if (grant) exact = true;
    return exact;
  }
}

late FakeAlarm alarm;
late DateTime now;

Widget app({double textScale = 1}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: PressureTestPage(holdAlarm: alarm, now: () => now),
);

Finder get listScroll => find
    .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
    .first;

Future<void> reveal(WidgetTester tester, String key) async {
  if (find.byKey(Key(key)).evaluate().isNotEmpty) return;
  tester.state<ScrollableState>(listScroll).position.jumpTo(0);
  await tester.pump();
  if (find.byKey(Key(key)).evaluate().isNotEmpty) return;
  await tester.scrollUntilVisible(
    find.byKey(Key(key)),
    200,
    scrollable: listScroll,
  );
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await reveal(tester, key);
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> openTab(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> reading(WidgetTester tester, String p, [String? t]) async {
  await tester.enterText(find.byKey(const Key('pt_rd_p')), p);
  if (t != null) await tester.enterText(find.byKey(const Key('pt_rd_t')), t);
  await tester.tap(find.byKey(const Key('pt_rd_ok')));
  await tester.pumpAndSettle();
}

Future<void> pumpRecordTab(WidgetTester tester, {double textScale = 1}) async {
  await tester.pumpWidget(app(textScale: textScale));
  await tester.pumpAndSettle();
  await tapKey(tester, 'pt_pneu');
  await reveal(tester, 'pt_design');
  await tester.enterText(find.byKey(const Key('pt_design')), '10');
  await tester.pump();
  await openTab(tester, 'pt_tab_record');
}

Future<void> finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    alarm = FakeAlarm();
    now = DateTime(2026, 9, 26, 14, 40, 42);
  });

  void bigView(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('정확한 알람이 꺼져 있으면 알리고, 설정 열기 → 허용 → 알림을 다시 예약한다', (tester) async {
    bigView(tester);
    await pumpRecordTab(tester);
    expect(
      tester.widget<Text>(find.byKey(const Key('pt_r_exact_off'))).data,
      '정확한 알람이 꺼져 있어 알림이 몇 분 늦을 수 있습니다.',
    );
    expect(find.text('설정 열기'), findsOneWidget);
    await tapKey(tester, 'pt_r_start');
    await reading(tester, '11', '20');
    expect(alarm.scheduled.length, 1);
    expect(alarm.scheduled.single.$1, DateTime(2026, 9, 26, 14, 50, 42));
    await tapKey(tester, 'pt_r_exact_open');
    expect(alarm.requests, 1);
    expect(find.byKey(const Key('pt_r_exact_off')), findsNothing);
    // 정확한 방식으로 같은 시각에 다시 예약(같은 번호라 앞 예약이 바뀐다)
    expect(alarm.scheduled.length, 2);
    expect(alarm.scheduled.last.$1, DateTime(2026, 9, 26, 14, 50, 42));
    await finish(tester);
  });

  testWidgets('허용하지 않고 돌아오면 줄이 그대로이고 다시 예약하지 않는다', (tester) async {
    bigView(tester);
    alarm = FakeAlarm(grant: false);
    await pumpRecordTab(tester);
    await tapKey(tester, 'pt_r_start');
    await reading(tester, '11', '20');
    await tapKey(tester, 'pt_r_exact_open');
    expect(alarm.requests, 1);
    expect(find.byKey(const Key('pt_r_exact_off')), findsOneWidget);
    expect(alarm.scheduled.length, 1);
    await finish(tester);
  });

  testWidgets('폰 설정에서 직접 켜고 앱으로 돌아오면 다시 확인해 알림을 다시 예약한다', (tester) async {
    bigView(tester);
    await pumpRecordTab(tester);
    await tapKey(tester, 'pt_r_start');
    await reading(tester, '11', '20');
    expect(alarm.scheduled.length, 1);
    alarm.exact = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pt_r_exact_off')), findsNothing);
    expect(alarm.scheduled.length, 2);
    await finish(tester);
  });

  testWidgets('정확한 알람이 켜져 있으면 줄이 없다', (tester) async {
    bigView(tester);
    alarm = FakeAlarm(exact: true);
    await pumpRecordTab(tester);
    expect(find.byKey(const Key('pt_r_exact_off')), findsNothing);
    await finish(tester);
  });

  testWidgets('종료한 뒤에는 정확한 알람 줄을 띄우지 않는다', (tester) async {
    bigView(tester);
    await pumpRecordTab(tester);
    await tapKey(tester, 'pt_r_start');
    await reading(tester, '11', '20');
    now = DateTime(2026, 9, 26, 14, 52, 0);
    await tapKey(tester, 'pt_r_end');
    await reading(tester, '11', '20');
    expect(find.byKey(const Key('pt_r_exact_off')), findsNothing);
    await finish(tester);
  });

  testWidgets('플러그인이 없는 곳(위젯 시험)에서는 정확한 알람으로 보고 예외 없이 끝난다', (tester) async {
    final plugin = const PluginHoldAlarm();
    expect(await plugin.canExact(), isTrue);
    // 플러그인이 없으면 실패를 삼키고 false(줄은 그대로 둔다)
    expect(await plugin.requestExact(), isFalse);
  });

  testWidgets('좁은 폰(344)·큰 글씨: 정확한 알람 줄과 설정 열기 단추가 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(344, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpRecordTab(tester, textScale: 1.3);
    await tapKey(tester, 'pt_r_start');
    expect(tester.takeException(), isNull);
    await reading(tester, '11', '20');
    await reveal(tester, 'pt_r_exact_off');
    await tester.ensureVisible(find.byKey(const Key('pt_r_exact_open')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await finish(tester);
  });
}
