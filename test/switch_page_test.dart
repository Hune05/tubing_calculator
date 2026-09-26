// 4-20mA 계산기 교정 점검의 스위치 시험 화면: 전송기/스위치 고르기, 판정과 사유, 조정 전·후,
// 기록 저장·목록·불러오기, 입력 보관, 온도 스위치 센서 값, 좁은 폰(344)·큰 글씨.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/instrument/cal_record.dart';
import 'package:tubing_calculator/src/presentation/instrument/signal_calculator_page.dart';
import 'package:tubing_calculator/src/presentation/instrument/switch_check.dart';

Future<void> pumpPage(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: SignalCalculatorPage()));
  await tester.pumpAndSettle();
}

String textIn(WidgetTester tester, Key key) => tester
    .widgetList<Text>(
      find.descendant(of: find.byKey(key), matching: find.byType(Text)),
    )
    .map((t) => t.data ?? '')
    .join('\n');

String text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data ?? '';

String field(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(Key(key))).controller!.text;

Future<void> openTab(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> scrollTo(
  WidgetTester tester,
  String key, {
  bool up = false,
}) async {
  await tester.dragUntilVisible(
    find.byKey(Key(key)),
    find.byType(ListView),
    Offset(0, up ? 300 : -300),
  );
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key, {bool up = false}) async {
  if (find.byKey(Key(key)).evaluate().isEmpty) {
    await scrollTo(tester, key, up: up);
  }
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> enter(
  WidgetTester tester,
  String key,
  String v, {
  bool up = false,
}) async {
  if (find.byKey(Key(key)).evaluate().isEmpty) {
    await scrollTo(tester, key, up: up);
  }
  await tester.enterText(find.byKey(Key(key)), v);
  await tester.pump();
}

/// 교정 점검 탭 → 스위치, 동작점 5 bar, 허용오차 ±0.1 bar, 반복 세 번.
Future<void> fillSwitch(WidgetTester tester) async {
  await openTab(tester, 'sg_tab_cal');
  await tapKey(tester, 'sc_mode_sw');
  await enter(tester, 'sw_set', '5');
  await enter(tester, 'sw_tol', '0.1');
  for (final (i, t, r) in const [
    (0, '5.05', '4.6'),
    (1, '5.12', '4.7'),
    (2, '4.98', '4.55'),
  ]) {
    await enter(tester, 'sw_trip_$i', t);
    await enter(tester, 'sw_reset_$i', r);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('스위치: 반복마다 오차·데드밴드·판정, 불합격 사유, 반복성', (tester) async {
    await pumpPage(tester);
    await openTab(tester, 'sg_tab_cal');
    // 기본은 전송기(시험점 줄이 보인다)
    expect(find.byKey(const Key('sc_row_0')), findsOneWidget);
    expect(find.byKey(const Key('sw_row_0')), findsNothing);
    await fillSwitch(tester);
    expect(find.byKey(const Key('sc_row_0')), findsNothing);
    expect(text(tester, 'sw_err_0'), '합격 · 오차 +0.05 bar (+0.5%)');
    expect(text(tester, 'sw_db_0'), '데드밴드 0.45 bar');
    expect(text(tester, 'sw_err_1'), '불합격 · 오차 +0.12 bar (+1.2%)');
    expect(text(tester, 'sw_err_2'), '합격 · 오차 -0.02 bar (-0.2%)');
    expect(text(tester, 'sw_mini'), '조정 전 · 최대 오차 +0.12 bar · 불합격');
    await scrollTo(tester, 'sw_result');
    final r = textIn(tester, const Key('sw_result'));
    expect(r, startsWith('조정 전 불합격: 3회 중 1회 불합격\n+0.12 bar'));
    expect(r, contains('반복 2: 동작점 오차 +0.12 bar, 허용오차 ±0.1 bar 초과.'));
    expect(r, contains('최대 오차: 반복 2 (범위의 +1.2%), 허용오차 ±0.1 bar'));
    expect(r, contains('평균 동작점 5.05 bar · 평균 복귀점 4.617 bar'));
    expect(r, contains('평균 데드밴드 0.433 bar'));
    expect(r, contains('반복성(동작점 최대 − 최소): 0.14 bar'));
    expect(r, contains('데드밴드 = |동작점 − 복귀점|'));
    await scrollTo(tester, 'sc_settings_line', up: true);
    expect(
      text(tester, 'sc_settings_line'),
      '스위치 · 상승 동작 · 동작점 5 bar · ±0.1 bar',
    );
    // 전송기로 돌아가면 전송기 화면, 다시 스위치로 오면 값이 그대로
    await tapKey(tester, 'sc_mode_tx');
    expect(find.byKey(const Key('sc_row_0')), findsOneWidget);
    expect(text(tester, 'sc_settings_line'), startsWith('0 bar ~ 10 bar · 선형'));
    await tapKey(tester, 'sc_mode_sw');
    expect(field(tester, 'sw_trip_1'), '5.12');
  });

  testWidgets('스위치: 판정 없음 사유, % 범위, 데드밴드 허용 범위, 복귀점 설정값, 방향', (tester) async {
    await pumpPage(tester);
    await fillSwitch(tester);
    // 허용오차를 비우면 판정 없음
    await enter(tester, 'sw_tol', '', up: true);
    await scrollTo(tester, 'sw_result');
    var r = textIn(tester, const Key('sw_result'));
    expect(r, startsWith('조정 전 동작점 최대 오차\n+0.12 bar'));
    expect(r, contains('허용오차나 데드밴드 허용 범위를 넣으면 합격·불합격을 판정합니다.'));
    // % 범위: 범위가 없으면 판정하지 못한다고 알린다
    await tapKey(tester, 'sw_tolm_pct', up: true);
    await enter(tester, 'sw_tol', '1', up: true);
    await enter(tester, 'sw_urv', '0', up: true);
    await scrollTo(tester, 'sw_result');
    r = textIn(tester, const Key('sw_result'));
    expect(r, contains('% 범위 허용오차는 0% 값과 100% 값을 다르게 넣어야 판정합니다.'));
    expect(text(tester, 'sw_err_0'), '오차 +0.05 bar');
    await enter(tester, 'sw_urv', '10', up: true);
    await scrollTo(tester, 'sw_result');
    expect(
      textIn(tester, const Key('sw_result')),
      startsWith('조정 전 불합격: 3회 중 1회 불합격'),
    );
    // 데드밴드 최대 0.44: 반복 1(0.45) 초과
    await enter(tester, 'sw_dbmax', '0.44', up: true);
    expect(text(tester, 'sw_db_0'), '데드밴드 0.45 bar · 허용 범위 초과');
    expect(text(tester, 'sw_db_1'), '데드밴드 0.42 bar · 허용 범위 이내');
    await scrollTo(tester, 'sw_result');
    r = textIn(tester, const Key('sw_result'));
    expect(r, contains('조정 전 불합격: 3회 중 2회 불합격'));
    expect(r, contains('반복 1: 데드밴드 0.45 bar, 허용 범위(0.44 bar 이하) 초과.'));
    // 복귀점 설정값 4.6: 반복 3(4.55) 오차 -0.05 이내, 반복 2(4.7) +0.1 이내
    await tapKey(tester, 'sw_rref_reset', up: true);
    await enter(tester, 'sw_rval', '4.6', up: true);
    expect(text(tester, 'sw_rerr_2'), '복귀점 오차 -0.05 bar · 허용오차 이내');
    await enter(tester, 'sw_rval', '4.4', up: true);
    expect(text(tester, 'sw_rerr_1'), '복귀점 오차 +0.3 bar · 허용오차 초과');
    await scrollTo(tester, 'sw_result');
    expect(
      textIn(tester, const Key('sw_result')),
      contains('반복 2: 복귀점 오차 +0.3 bar, 허용오차 ±0.1 bar 초과.'),
    );
    // 복귀점을 비운 반복은 복귀점·데드밴드를 판정하지 않았다고 적는다
    await enter(tester, 'sw_reset_2', '', up: true);
    await scrollTo(tester, 'sw_result');
    expect(
      textIn(tester, const Key('sw_result')),
      contains('복귀점을 넣지 않은 반복(반복 3)은 복귀점·데드밴드를 판정하지 않았습니다.'),
    );
    // 하강 동작인데 복귀점이 동작점보다 낮으면 방향을 확인하라고 알린다
    await tapKey(tester, 'sw_dir_falling', up: true);
    expect(text(tester, 'sw_side_0'), '복귀점이 동작점보다 낮습니다. 동작 방향을 확인하십시오.');
    await scrollTo(tester, 'sc_settings_line', up: true);
    expect(
      text(tester, 'sc_settings_line'),
      '스위치 · 하강 동작 · 동작점 5 bar · 복귀점 4.4 bar · ±1% 범위 · 데드밴드 0.44 bar 이하',
    );
  });

  testWidgets('스위치 기록: 조정 전·후 저장, 목록에 스위치 표시, 불러오기', (tester) async {
    await pumpPage(tester);
    await fillSwitch(tester);
    await tapKey(tester, 'sw_ct_no', up: true);
    await tapKey(tester, 'sc_save');
    await tester.enterText(find.byKey(const Key('cs_tag')), 'PSH-1');
    await tester.tap(find.byKey(const Key('cs_save')));
    await tester.pumpAndSettle();
    var saved = (await CalRecordStore.load()).single;
    expect(saved.isSwitch, isTrue);
    expect(saved.sw!.setpoint, 5);
    expect(saved.sw!.tol, 0.1);
    expect(saved.sw!.contact, SwitchContact.no);
    expect(saved.swFound[1].trip, 5.12);
    expect(saved.swLeft, isEmpty);
    expect(saved.finalPass, isFalse);

    // 조정 후 한 번 측정해 고쳐 저장
    await tapKey(tester, 'sc_phase_left', up: true);
    expect(field(tester, 'sw_trip_0'), '');
    await enter(tester, 'sw_trip_0', '5.01');
    await enter(tester, 'sw_reset_0', '4.55');
    await scrollTo(tester, 'sw_result');
    expect(
      textIn(tester, const Key('sw_result')),
      contains('조정 전: 최대 오차 +0.12 bar · 불합격'),
    );
    await tapKey(tester, 'sc_save');
    await tester.tap(find.byKey(const Key('cs_save')));
    await tester.pumpAndSettle();
    saved = (await CalRecordStore.load()).single;
    expect(saved.adjusted, isTrue);
    expect(saved.finalPass, isTrue);

    // 새로 시작, 전송기로 바꾼 뒤 불러오면 스위치로 돌아온다
    await tapKey(tester, 'sc_new');
    await tester.tap(find.byKey(const Key('sc_confirm_ok')));
    await tester.pumpAndSettle();
    expect(field(tester, 'sw_trip_0'), '');
    await tapKey(tester, 'sc_mode_tx', up: true);
    await tapKey(tester, 'sc_records');
    expect(text(tester, 'cr_type_${saved.id}'), '스위치 · 상승 동작 · 동작점 5 bar');
    expect(text(tester, 'cr_phase_${saved.id}'), '조정 전 불합격 → 조정 후 합격');
    await tester.tap(find.byKey(Key('cr_item_${saved.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cr_act_load')));
    await tester.pumpAndSettle();
    await scrollTo(tester, 'sc_settings_line', up: true);
    expect(
      text(tester, 'sc_settings_line'),
      '스위치 · 상승 동작 · 동작점 5 bar · ±0.1 bar · NO (a접점)',
    );
    expect(textIn(tester, const Key('sc_editing')), contains('PSH-1'));
    expect(field(tester, 'sw_trip_1'), '5.12');
    await tapKey(tester, 'sc_phase_left');
    expect(field(tester, 'sw_trip_0'), '5.01');
    // 전송기로 바꾸면 불러온 기록 표시가 사라진다(스위치 기록을 전송기로 덮어쓰지 않게)
    await tapKey(tester, 'sc_mode_tx', up: true);
    expect(find.byKey(const Key('sc_editing')), findsNothing);
  });

  testWidgets('스위치: 이 표 지우기는 지금 구분만, 저장은 동작점 설정값이 있어야', (tester) async {
    await pumpPage(tester);
    await openTab(tester, 'sg_tab_cal');
    await tapKey(tester, 'sc_mode_sw');
    await enter(tester, 'sw_trip_0', '5');
    await tapKey(tester, 'sc_save');
    expect(find.text('동작점 설정값을 넣으십시오.'), findsOneWidget);
    await scrollTo(tester, 'sw_result');
    expect(textIn(tester, const Key('sw_result')), contains('동작점 설정값을 넣으십시오'));
    await enter(tester, 'sw_set', '5', up: true);
    await tapKey(tester, 'sc_phase_left', up: true);
    await enter(tester, 'sw_trip_0', '5.02');
    await tapKey(tester, 'sc_clear');
    await tester.tap(find.byKey(const Key('sc_confirm_ok')));
    await tester.pumpAndSettle();
    expect(field(tester, 'sw_trip_0'), '');
    await tapKey(tester, 'sc_phase_found', up: true);
    expect(field(tester, 'sw_trip_0'), '5');
  });

  testWidgets('입력 보관: 스위치 모드·설정·반복 값이 남는다', (tester) async {
    await pumpPage(tester);
    await fillSwitch(tester);
    await tapKey(tester, 'sw_dir_falling', up: true);
    await tapKey(tester, 'sw_rref_deadband', up: true);
    await enter(tester, 'sw_rval', '0.5', up: true);
    await tapKey(tester, 'sw_tolm_pct', up: true);
    await enter(tester, 'sw_dbmin', '0.2', up: true);
    await tapKey(tester, 'sw_ct_nc', up: true);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const MaterialApp(home: SignalCalculatorPage()));
    await tester.pumpAndSettle();
    await openTab(tester, 'sg_tab_cal');
    expect(find.byKey(const Key('sw_row_0')), findsOneWidget);
    expect(
      text(tester, 'sc_settings_line'),
      '스위치 · 하강 동작 · 동작점 5 bar · 데드밴드 0.5 bar · ±0.1% 범위 · '
      '데드밴드 0.2 bar 이상 · NC (b접점)',
    );
    await scrollTo(tester, 'sw_trip_2');
    expect(field(tester, 'sw_trip_2'), '4.98');
    expect(field(tester, 'sw_reset_1'), '4.7');
  });

  testWidgets('온도 스위치: 동작점·복귀점 설정값의 센서 값', (tester) async {
    await pumpPage(tester);
    await tester.enterText(find.byKey(const Key('sg_urv')), '200');
    await tester.enterText(find.byKey(const Key('sg_unit')), '°C');
    await tester.pump();
    await openTab(tester, 'sg_tab_cal');
    await tapKey(tester, 'sc_mode_sw');
    await enter(tester, 'sw_set', '100');
    await tapKey(tester, 'sw_rref_deadband');
    await enter(tester, 'sw_rval', '5');
    await tapKey(tester, 'sc_sensor_pt100');
    await scrollTo(tester, 'sw_sensor');
    expect(text(tester, 'sw_sensor_set'), '동작점 100 °C: Pt100 138.506 Ω');
    expect(
      text(tester, 'sw_sensor_reset'),
      startsWith('복귀점 95 °C: Pt100 136.6'),
    );
    await tapKey(tester, 'sc_sensor_k', up: true);
    expect(
      text(tester, 'sw_sensor_set'),
      '동작점 100 °C: K형 4.096 mV, 냉접점 20 °C면 3.298 mV',
    );
    await scrollTo(tester, 'sc_settings_line', up: true);
    expect(text(tester, 'sc_settings_line'), endsWith(' · K형'));
    // 단위가 °C가 아니면 센서 값이 없다
    await enter(tester, 'sw_unit', 'bar');
    expect(find.byKey(const Key('sw_sensor')), findsNothing);
    expect(find.byKey(const Key('sc_sensor_k')), findsNothing);
  });

  testWidgets('좁은 폰(344)·큰 글씨: 스위치 설정·반복·결과가 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(344, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: const SignalCalculatorPage(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('sg_urv')), '1000');
    await tester.enterText(find.byKey(const Key('sg_unit')), '°C');
    await tester.pump();
    await openTab(tester, 'sg_tab_cal');
    await tapKey(tester, 'sc_mode_sw');
    expect(tester.takeException(), isNull);
    await enter(tester, 'sw_set', '450.5');
    await tapKey(tester, 'sw_rref_reset');
    await enter(tester, 'sw_rval', '440.25');
    await tapKey(tester, 'sw_tolm_pct');
    await enter(tester, 'sw_tol', '0.5');
    await enter(tester, 'sw_dbmin', '5');
    await enter(tester, 'sw_dbmax', '12.5');
    await tapKey(tester, 'sw_ct_nc');
    await tapKey(tester, 'sc_sensor_k');
    expect(tester.takeException(), isNull);
    for (final (i, t, r) in const [
      (0, '455.75', '430.125'),
      (1, '448.5', '470.25'),
      (2, '462.125', '459.5'),
    ]) {
      await enter(tester, 'sw_trip_$i', t);
      await enter(tester, 'sw_reset_$i', r);
      expect(tester.takeException(), isNull);
    }
    await scrollTo(tester, 'sw_result');
    expect(tester.takeException(), isNull);
    await scrollTo(tester, 'sc_save');
    expect(tester.takeException(), isNull);
    await scrollTo(tester, 'sc_settings_toggle', up: true);
    await tapKey(tester, 'sc_settings_toggle');
    expect(tester.takeException(), isNull);
    await scrollTo(tester, 'sw_sensor');
    expect(tester.takeException(), isNull);
  });
}
