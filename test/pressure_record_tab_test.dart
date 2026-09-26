// 압력 시험 계산기 ⑤ 시험 기록 탭: 시험 정보 요약, 유지시간 타이머(시작·경과·남은 시간·완료·종료),
// 알림 예약·취소, 다시 열어도 이어지는 시간, 측정 추가·고치기, 판정, 기록 저장 창, 저장한 기록(불러오기·지우기·
// 기록서 미리보기), 단위 환산, 좁은 폰·큰 글씨.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/hold_alarm.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/pressure_calc.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/pressure_test_page.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/pressure_units.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/test_record.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/test_record_sheet.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/test_records_page.dart';
import 'package:tubing_calculator/src/presentation/steel_cutting/screens/steel_pdf_preview_page.dart';

const _draftKey = 'pressure_test_draft_v1';

class FakeAlarm extends HoldAlarm {
  final scheduled = <(DateTime, String, String)>[];
  var cancels = 0;

  @override
  Future<void> schedule(
    DateTime at, {
    required String title,
    required String body,
  }) async => scheduled.add((at, title, body));

  @override
  Future<void> cancel() async => cancels++;
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

Future<void> pumpPage(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app());
  await tester.pumpAndSettle();
}

Future<void> openTab(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

String textIn(WidgetTester tester, Key key) => tester
    .widgetList<Text>(
      find.descendant(of: find.byKey(key), matching: find.byType(Text)),
    )
    .map((t) => t.data ?? '')
    .join('\n');

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data ?? '';

String fieldText(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(Key(key))).controller!.text;

Finder get listScroll => find
    .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
    .first;

/// 긴 목록은 보이는 곳 근처만 만들므로, 없으면 아래로 내려 찾는다.
Future<void> reveal(WidgetTester tester, String key) async {
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

Future<void> type(WidgetTester tester, String key, String v) async {
  await reveal(tester, key);
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.enterText(find.byKey(Key(key)), v);
  await tester.pump();
}

/// 입력 창에 압력·온도를 넣고 확인.
Future<void> reading(WidgetTester tester, String p, [String? t]) async {
  await tester.enterText(find.byKey(const Key('pt_rd_p')), p);
  if (t != null) await tester.enterText(find.byKey(const Key('pt_rd_t')), t);
  await tester.tap(find.byKey(const Key('pt_rd_ok')));
  await tester.pumpAndSettle();
}

/// 공압 B31.3 설계 10bar·실제 12bar로 시험 기록 탭까지.
Future<void> setupPneumatic(WidgetTester tester) async {
  await pumpPage(tester);
  await tester.tap(find.byKey(const Key('pt_pneu')));
  await tester.enterText(find.byKey(const Key('pt_design')), '10');
  await tester.enterText(find.byKey(const Key('pt_actual')), '12');
  await tester.pump();
  await openTab(tester, 'pt_tab_record');
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    alarm = FakeAlarm();
    now = DateTime(2026, 9, 26, 9, 0, 0);
  });

  testWidgets('시험 정보: 시험 압력 탭의 규격·시험 종류·설계압력·시험압력·규정 유지시간', (tester) async {
    await pumpPage(tester);
    await openTab(tester, 'pt_tab_record');
    var info = textIn(tester, const Key('pt_r_info'));
    expect(info, contains('규격: B31.3 공정 배관'));
    expect(info, contains('시험 종류: 수압'));
    expect(info, contains('설계압력: 없음 (시험 압력 탭에서 넣으십시오)'));
    expect(info, contains('시험압력: 없음'));
    expect(info, contains('규정 유지시간: 10분 이상'));
    expect(fieldText(tester, 'pt_r_hold'), '10');
    // 시험 압력 탭으로 가서 값 넣기
    await tapKey(tester, 'pt_r_goto_plan');
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 0);
    await tester.tap(find.byKey(const Key('pt_pneu')));
    await tester.enterText(find.byKey(const Key('pt_design')), '10');
    await tester.pump();
    await openTab(tester, 'pt_tab_record');
    info = textIn(tester, const Key('pt_r_info'));
    expect(info, contains('시험 종류: 공압'));
    expect(info, contains('설계압력: 10 bar'));
    expect(info, contains('시험압력: 11 bar 이상 (최소 시험압력)'));
    await openTab(tester, 'pt_tab_plan');
    await tester.enterText(find.byKey(const Key('pt_actual')), '12');
    await tester.pump();
    await openTab(tester, 'pt_tab_record');
    expect(
      textIn(tester, const Key('pt_r_info')),
      contains('시험압력: 12 bar (실제 시험압력)'),
    );
    // 시작 전 판정
    final r = textIn(tester, const Key('pt_r_result'));
    expect(r, contains('판정 없음'));
    expect(r, contains('시작하지 않았습니다.'));
    expect(textOf(tester, 'pt_r_status'), '시작 전');
  });

  testWidgets('시작 → 경과·남은 시간, 완료 알림 예약, 유지시간 완료, 측정 추가, 종료 → 판정', (
    tester,
  ) async {
    await setupPneumatic(tester);
    await type(tester, 'pt_r_line', 'P-1001');
    await tapKey(tester, 'pt_r_start');
    // 시작 압력은 시험압력(실제 12bar)으로 미리 채운다
    expect(fieldText(tester, 'pt_rd_p'), '12');
    expect(find.text('확인을 누른 시각부터 유지시간을 계산합니다.'), findsOneWidget);
    await reading(tester, '12', '20');
    expect(alarm.scheduled.length, 1);
    final (at, title, body) = alarm.scheduled.single;
    expect(at, DateTime(2026, 9, 26, 9, 10));
    expect(title, '압력 시험 유지시간 완료');
    expect(body, 'P-1001 유지시간 10분이 지났습니다. 종료 압력을 기록하십시오.');
    expect(textOf(tester, 'pt_r_status'), '유지 중');
    expect(textOf(tester, 'pt_r_elapsed'), '00:00');
    expect(textOf(tester, 'pt_r_remain'), '남은 시간 10:00');
    expect(textOf(tester, 'pt_r_times'), '시작 09:00:00 · 완료 예정 09:10');

    // 4분 뒤: 1초마다 다시 그린다
    now = DateTime(2026, 9, 26, 9, 4, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(textOf(tester, 'pt_r_elapsed'), '04:00');
    expect(textOf(tester, 'pt_r_remain'), '남은 시간 06:00');

    // 측정 추가: 시각은 지금, 앞 값을 미리 채운다
    await tapKey(tester, 'pt_r_add');
    expect(fieldText(tester, 'pt_rd_p'), '12');
    expect(fieldText(tester, 'pt_rd_t'), '20');
    await reading(tester, '11.99');
    final log = textIn(tester, const Key('pt_r_log'));
    expect(log, contains('09:04:00\n4분'));
    expect(log, contains('11.99 bar'));

    // 10분 30초: 유지시간 완료, 경과 시간은 계속 센다
    now = DateTime(2026, 9, 26, 9, 10, 30);
    await tester.pump(const Duration(seconds: 1));
    expect(textOf(tester, 'pt_r_status'), '유지시간 완료');
    expect(textOf(tester, 'pt_r_remain'), '유지시간 완료 (10분)');
    expect(textOf(tester, 'pt_r_elapsed'), '10:30');
    now = DateTime(2026, 9, 26, 9, 12, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(textOf(tester, 'pt_r_elapsed'), '12:00');

    // 종료: 알림 취소, 판정
    await tapKey(tester, 'pt_r_end');
    expect(find.byKey(const Key('pt_rd_note')), findsNothing);
    await reading(tester, '11.95', '20');
    expect(alarm.cancels, greaterThanOrEqualTo(1));
    expect(textOf(tester, 'pt_r_status'), '종료');
    expect(textOf(tester, 'pt_r_elapsed'), '12:00');
    expect(find.byKey(const Key('pt_r_add')), findsNothing);
    var r = textIn(tester, const Key('pt_r_result'));
    expect(r, startsWith('판정\n판정 없음'));
    expect(r, contains('누설·물맺힘 없음(육안 확인)을 확인하지 않았습니다.'));
    expect(r, contains('측정 압력강하: 0.05 bar'));
    expect(r, contains('온도 보정 후 압력강하: 0.05 bar'));
    await tapKey(tester, 'pt_r_leak');
    r = textIn(tester, const Key('pt_r_result'));
    expect(r, startsWith('판정\n합격'));
    await type(tester, 'pt_r_allow', '0.02');
    r = textIn(tester, const Key('pt_r_result'));
    expect(r, startsWith('판정\n불합격'));
    expect(r, contains('압력강하 0.05 bar: 허용 압력강하 0.02 bar 초과'));
    await type(tester, 'pt_r_allow', '0.1');
    r = textIn(tester, const Key('pt_r_result'));
    expect(r, startsWith('판정\n합격'));
    expect(r, contains('허용 압력강하 0.1 bar: 이내'));
  });

  testWidgets('일찍 종료하면 창에서 알리고, 유지시간 미만으로 불합격', (tester) async {
    await setupPneumatic(tester);
    await tapKey(tester, 'pt_r_start');
    await reading(tester, '12', '20');
    now = DateTime(2026, 9, 26, 9, 5, 0);
    await tapKey(tester, 'pt_r_end');
    expect(
      textOf(tester, 'pt_rd_note'),
      '유지시간 10분이 아직 지나지 않았습니다(경과 5분). 지금 종료하면 불합격입니다.',
    );
    await reading(tester, '12', '20');
    await tapKey(tester, 'pt_r_leak');
    final r = textIn(tester, const Key('pt_r_result'));
    expect(r, startsWith('판정\n불합격'));
    expect(r, contains('경과 시간 5분: 유지시간 10분 미만'));
    expect(textOf(tester, 'pt_r_remain'), '유지시간 10분 미만에 종료했습니다.');
  });

  testWidgets('시작 창을 취소하면 시작하지 않고, 압력을 비우면 막는다', (tester) async {
    await setupPneumatic(tester);
    await tapKey(tester, 'pt_r_start');
    await tester.enterText(find.byKey(const Key('pt_rd_p')), '');
    await tester.tap(find.byKey(const Key('pt_rd_ok')));
    await tester.pumpAndSettle();
    expect(find.text('압력을 넣으십시오'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('pt_rd_t')), 'abc');
    await tester.enterText(find.byKey(const Key('pt_rd_p')), '12');
    await tester.tap(find.byKey(const Key('pt_rd_ok')));
    await tester.pumpAndSettle();
    expect(find.text('온도는 숫자로 넣으십시오'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pt_rd_cancel')));
    await tester.pumpAndSettle();
    expect(textOf(tester, 'pt_r_status'), '시작 전');
    expect(alarm.scheduled, isEmpty);
  });

  testWidgets('화면을 나가도 시작 시각·측정값이 임시 저장되고, 다시 열면 그 시각으로 경과 시간 계산·알림 다시 예약', (
    tester,
  ) async {
    await setupPneumatic(tester);
    await tapKey(tester, 'pt_r_start');
    await reading(tester, '12', '20');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    final prefs = await SharedPreferences.getInstance();
    final m = jsonDecode(prefs.getString(_draftKey)!) as Map;
    expect(m['record']['start'], DateTime(2026, 9, 26, 9).toIso8601String());
    expect((m['record']['reads'] as List).single['kpa'], 1200);

    // 12분 5초 뒤 다시 연다
    alarm = FakeAlarm();
    now = DateTime(2026, 9, 26, 9, 12, 5);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await openTab(tester, 'pt_tab_record');
    expect(textOf(tester, 'pt_r_elapsed'), '12:05');
    expect(textOf(tester, 'pt_r_status'), '유지시간 완료');
    // 완료 시각이 지났으면 다시 예약하지 않는다
    expect(alarm.scheduled, isEmpty);
  });

  testWidgets('다시 열 때 아직 진행 중이면 같은 알림을 다시 예약한다(유지시간 30분·라인 번호)', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      _draftKey: jsonEncode({
        'unit': 'bar',
        'medium': 'hydro',
        'fields': {'rHold': '30', 'rLine': 'L-7'},
        'record': {
          'start': '2026-09-26T09:00:00.000',
          'reads': [
            {
              'at': '2026-09-26T09:00:00.000',
              'kpa': 1500,
              't': 18,
              'k': 'start',
            },
          ],
        },
      }),
    });
    now = DateTime(2026, 9, 26, 9, 12, 5);
    await pumpPage(tester);
    await openTab(tester, 'pt_tab_record');
    expect(textOf(tester, 'pt_r_elapsed'), '12:05');
    expect(textOf(tester, 'pt_r_remain'), '남은 시간 17:55');
    expect(alarm.scheduled.length, 1);
    expect(alarm.scheduled.single.$1, DateTime(2026, 9, 26, 9, 30));
    expect(alarm.scheduled.single.$3, 'L-7 유지시간 30분이 지났습니다. 종료 압력을 기록하십시오.');
    expect(textIn(tester, const Key('pt_r_log')), contains('15 bar'));
  });

  testWidgets('유지시간: 규격 최소보다 짧으면 알리고 10분으로 판정, 바꾸면 알림을 다시 예약', (tester) async {
    await setupPneumatic(tester);
    await tapKey(tester, 'pt_r_start');
    await reading(tester, '12', '20');
    expect(alarm.scheduled.single.$1, DateTime(2026, 9, 26, 9, 10));
    await type(tester, 'pt_r_hold', '5');
    expect(textOf(tester, 'pt_r_hold_warn'), '규격 최소 10분 미만이라 10분으로 판정합니다.');
    expect(textOf(tester, 'pt_r_remain'), '남은 시간 10:00');
    await type(tester, 'pt_r_hold', '30');
    expect(find.byKey(const Key('pt_r_hold_warn')), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    expect(alarm.scheduled.last.$1, DateTime(2026, 9, 26, 9, 30));
    expect(alarm.scheduled.last.$3, contains('유지시간 30분이 지났습니다'));
    expect(textOf(tester, 'pt_r_remain'), '남은 시간 30:00');
  });

  testWidgets('새로 시작은 확인을 받고, 알림을 취소한다', (tester) async {
    await setupPneumatic(tester);
    await type(tester, 'pt_r_line', 'P-1');
    await tapKey(tester, 'pt_r_start');
    await reading(tester, '12', '20');
    // 취소하면 그대로
    await tapKey(tester, 'pt_r_new');
    expect(find.textContaining('유지시간 알림도 취소합니다.'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(textOf(tester, 'pt_r_status'), '유지 중');
    expect(alarm.cancels, 0);
    await tapKey(tester, 'pt_r_new');
    await tester.tap(find.byKey(const Key('pt_r_confirm_ok')));
    await tester.pumpAndSettle();
    expect(alarm.cancels, 1);
    expect(textOf(tester, 'pt_r_status'), '시작 전');
    expect(find.byKey(const Key('pt_r_log')), findsNothing);
    expect(fieldText(tester, 'pt_r_line'), '');
  });

  testWidgets('측정값 줄을 누르면 고치고, 중간 측정은 지울 수 있다', (tester) async {
    await setupPneumatic(tester);
    await tapKey(tester, 'pt_r_start');
    await reading(tester, '12', '20');
    now = DateTime(2026, 9, 26, 9, 3, 0);
    await tapKey(tester, 'pt_r_add');
    await reading(tester, '11.9', '21');
    // 시작 줄: 지우기 없음
    await tapKey(tester, 'pt_r_read_0');
    expect(find.byKey(const Key('pt_rd_delete')), findsNothing);
    expect(textOf(tester, 'pt_rd_note'), '시각(09:00:00)은 그대로 둡니다.');
    await reading(tester, '12.01', '19.5');
    var log = textIn(tester, const Key('pt_r_log'));
    expect(log, contains('12.01 bar\n19.5°C'));
    // 중간 측정 지우기
    await tapKey(tester, 'pt_r_read_1');
    await tester.tap(find.byKey(const Key('pt_rd_delete')));
    await tester.pumpAndSettle();
    log = textIn(tester, const Key('pt_r_log'));
    expect(log, isNot(contains('11.9 bar')));
    expect(find.byKey(const Key('pt_r_read_1')), findsNothing);
  });

  testWidgets('단위를 바꾸면 허용 압력강하 칸과 측정 기록이 새 단위로', (tester) async {
    await setupPneumatic(tester);
    await tapKey(tester, 'pt_r_start');
    await reading(tester, '12', '20');
    await type(tester, 'pt_r_allow', '0.1');
    await tapKey(tester, 'pt_u_psi');
    expect(fieldText(tester, 'pt_r_allow'), '1.4504');
    expect(textIn(tester, const Key('pt_r_log')), contains('174.0453 psi'));
    await tapKey(tester, 'pt_u_bar');
    expect(fieldText(tester, 'pt_r_allow'), '0.1');
  });

  testWidgets('수압(배관): 외경·두께를 넣으면 물 온도 영향을 참고로 보이고 측정 강하로 판정', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byKey(const Key('pt_kind_pipe')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('pt_design')), '10');
    await tester.pump();
    await openTab(tester, 'pt_tab_record');
    await tapKey(tester, 'pt_r_start');
    // 수압 최소 시험압력 15bar를 미리 채운다
    expect(fieldText(tester, 'pt_rd_p'), '15');
    await reading(tester, '15', '20');
    now = DateTime(2026, 9, 26, 9, 11, 0);
    await tapKey(tester, 'pt_r_end');
    await reading(tester, '14', '19');
    await type(tester, 'pt_r_od', '60.5');
    await type(tester, 'pt_r_wall', '3.9');
    await tapKey(tester, 'pt_r_leak');
    final r = textIn(tester, const Key('pt_r_result'));
    expect(r, startsWith('판정\n합격'));
    expect(r, contains('측정 압력강하: 1 bar'));
    expect(r, contains('수압은 온도 보정 없이 측정 압력강하로 판정합니다.'));
    expect(r, contains('물 온도 변화 -1°C: 온도만으로 압력이 약'));
    expect(r, isNot(contains('온도 보정 후')));
  });

  testWidgets('기록 저장: 라인 번호 필수, 시험자·압력계·안전밸브 기억, 목록에서 불러오기', (tester) async {
    SharedPreferences.setMockInitialValues({'user_real_name': '차재훈'});
    await setupPneumatic(tester);
    await tapKey(tester, 'pt_r_save');
    expect(find.text('시작 압력을 넣고 시작한 뒤 저장하십시오.'), findsOneWidget);
    await tapKey(tester, 'pt_r_start');
    await reading(tester, '12', '20');
    now = DateTime(2026, 9, 26, 9, 12, 0);
    await tapKey(tester, 'pt_r_end');
    await reading(tester, '11.95', '20');
    await tapKey(tester, 'pt_r_leak');
    await tapKey(tester, 'pt_r_save');
    expect(fieldText(tester, 'ps_tester'), '차재훈');
    expect(find.text('2026-09-26'), findsOneWidget);
    expect(
      tester.widget<ChoiceChip>(find.byKey(const Key('ps_fluid_air'))).selected,
      isTrue,
    );
    await tapKey(tester, 'ps_save');
    expect(find.text('라인 번호를 넣으십시오'), findsOneWidget);
    await type(tester, 'ps_line', 'P-1001');
    await type(tester, 'ps_testno', 'PT-001');
    await type(tester, 'ps_g1_no', 'PG-01');
    await type(tester, 'ps_g1_range', '0~25 bar');
    await type(tester, 'ps_g1_due', '2027-03-31');
    await type(tester, 'ps_relief', '13.2');
    await type(tester, 'ps_relief_no', 'PSV-1');
    await type(tester, 'ps_w_s', '이감리');
    await tapKey(tester, 'ps_fluid_nitrogen');
    await tapKey(tester, 'ps_save');
    expect(find.text('P-1001 기록을 저장했습니다.'), findsOneWidget);
    expect(find.text('기록서 보기'), findsOneWidget);
    expect(find.byKey(const Key('pt_r_editing')), findsOneWidget);
    expect(fieldText(tester, 'pt_r_line'), 'P-1001');
    final saved = (await PtRecordStore.load()).single;
    expect(saved.line, 'P-1001');
    expect(saved.testNo, 'PT-001');
    expect(saved.fluid, PtFluid.nitrogen);
    expect(saved.code, PipingCode.b313);
    expect(saved.medium, TestMedium.pneumatic);
    expect(saved.designKpa, closeTo(1000, 1e-9));
    expect(saved.testKpa, closeTo(1200, 1e-9));
    expect(saved.holdMin, 10);
    expect(saved.readings.length, 2);
    expect(saved.gauges.single.no, 'PG-01');
    expect(saved.reliefKpa, closeTo(1320, 1e-9));
    expect(saved.witnessSupervisor, '이감리');
    expect(saved.tester, '차재훈');
    expect(saved.date, DateTime(2026, 9, 26, 9, 0));
    expect(saved.verdict.pass, isTrue);

    // 다시 저장: 불러온 기록이라 "고쳐 저장"이 기본
    await tapKey(tester, 'pt_r_save');
    expect(find.text('압력시험 기록 고치기'), findsOneWidget);
    expect(find.byKey(const Key('ps_save_new')), findsOneWidget);
    await tapKey(tester, 'ps_save');
    expect((await PtRecordStore.load()).length, 1);

    // 새로 시작 → 다음 시험의 저장 창에 시험자·압력계·안전밸브가 미리 채워진다
    await tapKey(tester, 'pt_r_new');
    await tester.tap(find.byKey(const Key('pt_r_confirm_ok')));
    await tester.pumpAndSettle();
    now = DateTime(2026, 9, 26, 10, 0, 0);
    await tapKey(tester, 'pt_r_start');
    await reading(tester, '12', '20');
    await tapKey(tester, 'pt_r_save');
    expect(find.text('압력시험 기록 저장'), findsOneWidget);
    expect(fieldText(tester, 'ps_g1_no'), 'PG-01');
    expect(fieldText(tester, 'ps_relief'), '13.2');
    expect(fieldText(tester, 'ps_relief_no'), 'PSV-1');
    expect(fieldText(tester, 'ps_line'), '');
    await type(tester, 'ps_line', 'P-2002');
    await tapKey(tester, 'ps_save');
    expect((await PtRecordStore.load()).length, 2);

    // 저장한 기록 → P-1001 불러오기
    await tapKey(tester, 'pt_r_records');
    expect(find.text('P-1001'), findsOneWidget);
    expect(find.text('P-2002'), findsOneWidget);
    expect(find.text('합격'), findsOneWidget);
    expect(find.text('판정 없음'), findsOneWidget);
    await tester.tap(find.byKey(Key('pr_item_${saved.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pr_act_load')));
    await tester.pumpAndSettle();
    expect(find.text('P-1001 기록을 불러왔습니다.'), findsOneWidget);
    expect(textIn(tester, const Key('pt_r_editing')), contains('P-1001'));
    expect(textOf(tester, 'pt_r_status'), '종료');
    expect(textOf(tester, 'pt_r_elapsed'), '12:00');
    expect(textIn(tester, const Key('pt_r_result')), startsWith('판정\n합격'));
  });

  testWidgets('다시 열면 "불러온 기록" 표시도 되살린다', (tester) async {
    await PtRecordStore.put(
      PtRecord(id: 'k', date: DateTime(2026, 9, 25), line: 'P-9'),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _draftKey,
      jsonEncode({
        'record': {'editing': 'k'},
      }),
    );
    await pumpPage(tester);
    await openTab(tester, 'pt_tab_record');
    expect(
      textIn(tester, const Key('pt_r_editing')),
      '불러온 기록: P-9 · 2026-09-25',
    );
  });

  testWidgets('psi로 저장한 기록을 불러오면 단위가 psi가 되고 다른 탭 값도 psi로 환산', (tester) async {
    final t0 = DateTime(2026, 9, 26, 9);
    await PtRecordStore.put(
      PtRecord(
        id: 'u',
        date: t0,
        line: 'P-150',
        code: PipingCode.b311,
        medium: TestMedium.pneumatic,
        unit: PUnit.psi,
        designKpa: 1034.2135939752541, // 150 psi
        testKpa: 1241.056312770305, // 180 psi
        startAt: t0,
        endAt: t0.add(const Duration(minutes: 10)),
        readings: [
          PtReading(at: t0, kpa: 1241.056312770305, kind: PtReadKind.start),
          PtReading(
            at: t0.add(const Duration(minutes: 10)),
            kpa: 1241.056312770305,
            kind: PtReadKind.end,
          ),
        ],
        leakOk: true,
      ),
    );
    await pumpPage(tester);
    await openTab(tester, 'pt_tab_decay');
    await tester.enterText(find.byKey(const Key('pt_p1')), '7');
    await tester.pump();
    await openTab(tester, 'pt_tab_record');
    await tapKey(tester, 'pt_r_records');
    await tester.tap(find.byKey(const Key('pr_item_u')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pr_act_load')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ChoiceChip>(find.byKey(const Key('pt_u_psi'))).selected,
      isTrue,
    );
    final info = textIn(tester, const Key('pt_r_info'));
    expect(info, contains('규격: B31.1 동력 배관'));
    expect(info, contains('시험 종류: 공압'));
    expect(info, contains('설계압력: 150 psi'));
    expect(info, contains('시험압력: 180 psi (실제 시험압력)'));
    expect(textIn(tester, const Key('pt_r_result')), startsWith('판정\n합격'));
    await openTab(tester, 'pt_tab_decay');
    expect(fieldText(tester, 'pt_p1'), '101.53');
    await openTab(tester, 'pt_tab_plan');
    expect(fieldText(tester, 'pt_design'), '150');
    expect(fieldText(tester, 'pt_actual'), '180');
  });

  testWidgets('저장 창: 불러온 기록의 라인 번호를 바꾸면 "새로 저장"이 기본', (tester) async {
    PtSaveResult? got;
    final ed = PtRecord(id: 'x', date: DateTime(2026, 9, 26), line: 'P-1');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                got = await showModalBottomSheet<PtSaveResult>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => PtSaveSheet(
                    editing: ed,
                    unit: PUnit.bar,
                    medium: TestMedium.hydro,
                    line: 'P-1',
                    date: DateTime(2026, 9, 26),
                    tester: '홍',
                  ),
                );
              },
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ps_save_new')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('ps_line')), 'P-2');
    await tester.pump();
    expect(find.byKey(const Key('ps_save_overwrite')), findsOneWidget);
    // 둘째 압력계만 적으면 첫째 자리로
    await tester.ensureVisible(find.byKey(const Key('ps_g2_no')));
    await tester.enterText(find.byKey(const Key('ps_g2_no')), 'PG-2');
    await tester.ensureVisible(find.byKey(const Key('ps_save')));
    await tester.tap(find.byKey(const Key('ps_save')));
    await tester.pumpAndSettle();
    expect(got!.asNew, isTrue);
    expect(got!.line, 'P-2');
    expect(got!.gauges.single.no, 'PG-2');
    expect(got!.fluid, PtFluid.water);
  });

  testWidgets('저장한 기록 지우기는 확인을 받는다, CSV 내보내기 단추가 있다', (tester) async {
    await PtRecordStore.put(
      PtRecord(
        id: 'z',
        date: DateTime(2026, 9, 26),
        line: 'L-9',
        testNo: 'HT-9',
        system: '급수',
        medium: TestMedium.hydro,
      ),
    );
    await tester.pumpWidget(const MaterialApp(home: PtRecordsPage()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pr_csv')), findsOneWidget);
    expect(find.text('HT-9 · 급수'), findsOneWidget);
    expect(textOf(tester, 'pr_kind_z'), 'B31.3 수압 · 물');
    await tester.tap(find.byKey(const Key('pr_item_z')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pr_act_delete')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('L-9 2026-09-26 00:00 기록을 지우겠습니까?'),
      findsOneWidget,
    );
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect((await PtRecordStore.load()).length, 1);
    await tester.tap(find.byKey(const Key('pr_item_z')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pr_act_delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pr_delete_ok')));
    await tester.pumpAndSettle();
    expect(await PtRecordStore.load(), isEmpty);
    expect(find.textContaining('저장한 기록이 없습니다'), findsOneWidget);
    expect(find.byKey(const Key('pr_csv')), findsNothing);
  });

  testWidgets('기록서 보기는 미리보기로 열린다(공유는 단추를 눌러야만)', (tester) async {
    await PtRecordStore.put(
      PtRecord(id: 'q', date: DateTime(2026, 9, 26), line: 'P-7'),
    );
    pdfPreviewBuilder = (bytes, name) =>
        Text('미리보기 $name ${bytes.length > 1000}');
    await tester.pumpWidget(const MaterialApp(home: PtRecordsPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pr_item_q')));
    await tester.pumpAndSettle();
    expect(find.text('기록서 보기'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('pr_act_pdf')));
      for (
        var i = 0;
        i < 40 && find.textContaining('미리보기 pt_').evaluate().isEmpty;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
    expect(find.text('미리보기 pt_P-7_20260926.pdf true'), findsOneWidget);
    expect(find.text('압력시험 기록서 미리보기'), findsOneWidget);
    expect(find.byKey(const Key('pdf_preview_share')), findsOneWidget);
  });

  testWidgets('좁은 폰(344)·큰 글씨: 시험 기록 탭·입력 창·저장 창·기록 목록이 넘치지 않는다', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(344, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await PtRecordStore.put(
      PtRecord(
        id: 'n',
        date: DateTime(2026, 9, 26),
        line: '2"-P-1001-A1A-HC-아주긴라인번호',
        testNo: 'HT-2026-0001-REV.2',
        system: '보일러 급수 계통 고압 가열기 우회 배관',
        tester: '홍길동',
        medium: TestMedium.pneumatic,
        fluid: PtFluid.nitrogen,
      ),
    );
    await tester.pumpWidget(app(textScale: 1.3));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pt_pneu')));
    await type(tester, 'pt_design', '100');
    await type(tester, 'pt_actual', '120');
    await openTab(tester, 'pt_tab_record');
    expect(tester.takeException(), isNull);
    await type(tester, 'pt_r_hold', '5');
    await type(tester, 'pt_r_line', '2"-P-1001-A1A-HC');
    expect(tester.takeException(), isNull);
    await tapKey(tester, 'pt_r_start');
    expect(tester.takeException(), isNull);
    await reading(tester, '120.1234', '-12.5');
    now = DateTime(2026, 9, 26, 9, 2, 0);
    await tapKey(tester, 'pt_r_add');
    await reading(tester, '119.9876', '-11');
    now = DateTime(2026, 9, 26, 9, 3, 0);
    await tapKey(tester, 'pt_r_end');
    expect(find.byKey(const Key('pt_rd_note')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await reading(tester, '119.5', '-10');
    await type(tester, 'pt_r_allow', '0.25');
    await tapKey(tester, 'pt_r_leak');
    await tester.scrollUntilVisible(
      find.byKey(const Key('pt_r_result')),
      300,
      scrollable: listScroll,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('pt_r_new')),
      300,
      scrollable: listScroll,
    );
    expect(tester.takeException(), isNull);
    // 저장 창
    await tapKey(tester, 'pt_r_save');
    expect(tester.takeException(), isNull);
    await type(tester, 'ps_testno', 'HT-2026-0001-REV.2');
    await type(tester, 'ps_g1_range', '0~160 bar');
    await type(tester, 'ps_relief', '132');
    await tester.ensureVisible(find.byKey(const Key('ps_save')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('ps_save')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // 기록 목록
    // 저장 알림("기록서 보기" 단추가 있어 떠 있는 스낵바)이 아래 단추를 가리므로 닫는다.
    ScaffoldMessenger.of(
      tester.element(find.byKey(const Key('pt_r_result'))),
    ).hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await tapKey(tester, 'pt_r_records');
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('pr_item_n')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
