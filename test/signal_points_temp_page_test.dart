// 4-20mA 계산기 화면: 시험점(3·5·11점, 하강 포함)·히스테리시스, 교정 점검 센서 값, 온도 센서 탭, 입력 보관, 좁은 폰.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/instrument/cal_record.dart';
import 'package:tubing_calculator/src/presentation/instrument/signal_calculator_page.dart';
import 'package:tubing_calculator/src/presentation/instrument/temp_sensor.dart';

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

/// 목록에서 [key]가 보일 때까지 끈다(위에 있으면 [up]).
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

/// 누르기. 아직 그려지지 않은 아래쪽 칸이면 먼저 끌어 내린다.
Future<void> tapKey(WidgetTester tester, String key) async {
  if (find.byKey(Key(key)).evaluate().isEmpty) await scrollTo(tester, key);
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

/// 환산 탭에서 측정 범위를 0~[urv] [unit]으로.
Future<void> setRange(WidgetTester tester, String urv, String unit) async {
  await tester.enterText(find.byKey(const Key('sg_urv')), urv);
  await tester.enterText(find.byKey(const Key('sg_unit')), unit);
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('하강 포함: 9줄, 하강 점에 히스테리시스, 허용값을 넣으면 판정', (tester) async {
    await pumpPage(tester);
    await openTab(tester, 'sg_tab_cal');
    await tapKey(tester, 'sc_tol_0.5');
    await tapKey(tester, 'sc_down');
    expect(find.byKey(const Key('sc_label_8')), findsOneWidget);
    expect(find.byKey(const Key('sc_label_9')), findsNothing);
    expect(text(tester, 'sc_label_4'), '상승 100%');
    expect(text(tester, 'sc_label_6'), '하강 50%');
    await tester.enterText(find.byKey(const Key('sc_read_2')), '12.03');
    await tester.enterText(find.byKey(const Key('sc_read_6')), '12.06');
    await tester.pump();
    // |0.1875 − 0.375| = 0.1875%
    expect(text(tester, 'sc_hyst_6'), '히스테리시스 0.19%');
    expect(find.byKey(const Key('sc_hyst_2')), findsNothing);
    var r = textIn(tester, const Key('sg_cal_result'));
    expect(r, contains('조정 전 합격: 2점 모두 ±0.5% 이내'));
    expect(r, contains('최대 히스테리시스: 0.19% (하강 50% 점)'));
    expect(r, contains('히스테리시스 = |상승 오차 % − 하강 오차 %|'));
    // 허용값 0.1% → 하강 50% 불합격(오차는 합격이어도)
    await tester.enterText(find.byKey(const Key('sc_hyst_tol')), '0.1');
    await tester.pump();
    expect(text(tester, 'sc_hyst_6'), '히스테리시스 0.19% · 허용값 초과');
    expect(text(tester, 'sc_err_6'), startsWith('불합격 · 오차 +0.38%'));
    expect(text(tester, 'sc_err_2'), startsWith('합격 · '));
    r = textIn(tester, const Key('sg_cal_result'));
    expect(r, contains('조정 전 불합격: 1점 히스테리시스 허용값 초과'));
    expect(r, contains('히스테리시스 초과: 하강 50%'));
    expect(
      text(tester, 'sc_settings_line'),
      '0 bar ~ 10 bar · 선형 · 전송기 출력(mA) · ±0.5% · 5점 상승·하강 · 히스테리시스 0.1%',
    );
    // 하강을 끄면 허용값 칸도 숨고 판정에서 빠진다(하강 칸 값이 있으니 먼저 묻는다)
    await tapKey(tester, 'sc_down');
    expect(find.text('시험점 바꾸기'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sc_confirm_ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sc_hyst_tol')), findsNothing);
    expect(textIn(tester, const Key('sg_cal_result')), contains('조정 전 합격'));
    expect(field(tester, 'sc_read_2'), '12.03');
  });

  testWidgets('시험점 바꾸기: 없어지는 점에 값이 있으면 묻고, 같은 점 값은 옮긴다', (tester) async {
    await pumpPage(tester);
    await openTab(tester, 'sg_tab_cal');
    await tester.enterText(find.byKey(const Key('sc_read_1')), '8.02');
    await tester.enterText(find.byKey(const Key('sc_read_2')), '12.03');
    await tester.pump();
    await tapKey(tester, 'sc_pts_p3');
    expect(find.text('시험점 바꾸기'), findsOneWidget);
    expect(find.textContaining('(25%)에 입력한 값은 지워집니다'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sc_label_4')), findsOneWidget); // 5점 그대로
    await tapKey(tester, 'sc_pts_p3');
    await tester.tap(find.byKey(const Key('sc_confirm_ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sc_label_3')), findsNothing);
    expect(text(tester, 'sc_label_1'), '50%');
    expect(field(tester, 'sc_read_1'), '12.03');
    // 하강 포함은 없어지는 점이 없어 묻지 않고, 값은 그대로
    await tapKey(tester, 'sc_down');
    expect(find.text('시험점 바꾸기'), findsNothing);
    expect(text(tester, 'sc_label_1'), '상승 50%');
    expect(text(tester, 'sc_label_3'), '하강 50%');
    expect(field(tester, 'sc_read_1'), '12.03');
    // 11점: 50% 값은 여섯째 줄로
    await tapKey(tester, 'sc_pts_p11');
    expect(field(tester, 'sc_read_5'), '12.03');
    expect(text(tester, 'sc_label_5'), '상승 50%');
  });

  testWidgets('센서: 범위가 °C이면 점마다 교정기에 넣을 값(Pt100 Ω, K형 mV·냉접점)', (tester) async {
    await pumpPage(tester);
    // bar 범위에서는 센서 칸이 없다
    await openTab(tester, 'sg_tab_cal');
    expect(find.byKey(const Key('sc_sensor_pt100')), findsNothing);
    await openTab(tester, 'sg_tab_conv');
    await setRange(tester, '100', '°C');
    await openTab(tester, 'sg_tab_cal');
    await tapKey(tester, 'sc_sensor_pt100');
    expect(text(tester, 'sc_sensor_val_4'), 'Pt100 138.506 Ω');
    expect(text(tester, 'sc_sensor_val_0'), 'Pt100 100 Ω');
    expect(find.byKey(const Key('sc_cj')), findsNothing);
    await tapKey(tester, 'sc_sensor_k');
    expect(field(tester, 'sc_cj'), '20');
    expect(text(tester, 'sc_sensor_val_4'), 'K형 4.096 mV, 냉접점 20 °C면 3.298 mV');
    // 입력값을 바꾸면 그 온도의 값
    await tester.enterText(find.byKey(const Key('sc_applied_4')), '500');
    await tester.pump();
    expect(text(tester, 'sc_sensor_val_4'), startsWith('K형 20.644 mV'));
    // 냉접점을 비우면 0 °C 표 값만
    await tester.enterText(find.byKey(const Key('sc_cj')), '');
    await tester.pump();
    expect(text(tester, 'sc_sensor_val_2'), 'K형 2.023 mV');
    // 범위를 벗어난 온도
    await tester.enterText(find.byKey(const Key('sc_applied_4')), '1500');
    await tester.pump();
    expect(text(tester, 'sc_sensor_val_4'), 'K형 범위 초과');
    expect(text(tester, 'sc_settings_line'), endsWith(' · K형'));
    // mA 입력 방법이거나 단위가 °C가 아니면 센서 값을 보이지 않는다
    await tester.enterText(find.byKey(const Key('sc_unit')), 'bar');
    await tester.pump();
    expect(find.byKey(const Key('sc_sensor_val_4')), findsNothing);
    expect(find.byKey(const Key('sc_sensor_k')), findsNothing);
  });

  testWidgets('기록 저장·불러오기: 시험점·하강·히스테리시스 허용값·센서가 기록에 남는다', (tester) async {
    await pumpPage(tester);
    await setRange(tester, '100', '°C');
    await openTab(tester, 'sg_tab_cal');
    await tapKey(tester, 'sc_tol_0.5');
    await tapKey(tester, 'sc_down');
    await tester.enterText(find.byKey(const Key('sc_hyst_tol')), '0.1');
    await tapKey(tester, 'sc_sensor_pt100');
    await tester.enterText(find.byKey(const Key('sc_read_2')), '12.03');
    await tester.enterText(find.byKey(const Key('sc_read_6')), '12.06');
    await tester.pump();
    await tapKey(tester, 'sc_save');
    await tester.enterText(find.byKey(const Key('cs_tag')), 'TT-1');
    await tester.tap(find.byKey(const Key('cs_save')));
    await tester.pumpAndSettle();
    final saved = (await CalRecordStore.load()).single;
    expect(saved.points, calPointList(CalPointSet.p5, withDown: true));
    expect(saved.hystTolPct, 0.1);
    expect(saved.sensor, TempSensor.pt100);
    expect(saved.cjC, isNull);
    expect(saved.found[6].reading, 12.06);
    expect(saved.foundSummary.pass, isFalse); // 히스테리시스 0.19% > 0.1%

    // 새로 시작하고 시험점·센서를 바꾼 뒤 불러오면 기록대로 돌아온다
    await tapKey(tester, 'sc_new');
    await tester.tap(find.byKey(const Key('sc_confirm_ok')));
    await tester.pumpAndSettle();
    await scrollTo(tester, 'sc_down', up: true);
    await tapKey(tester, 'sc_down');
    await tapKey(tester, 'sc_pts_p3');
    await tapKey(tester, 'sc_sensor_none');
    expect(find.byKey(const Key('sc_label_3')), findsNothing);
    await tapKey(tester, 'sc_records');
    await tester.tap(find.byKey(Key('cr_item_${saved.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cr_act_load')));
    await tester.pumpAndSettle();
    await scrollTo(tester, 'sc_settings_line', up: true);
    expect(
      text(tester, 'sc_settings_line'),
      contains('5점 상승·하강 · 히스테리시스 0.1% · Pt100'),
    );
    expect(text(tester, 'sc_sensor_val_2'), 'Pt100 119.397 Ω');
    expect(field(tester, 'sc_read_2'), '12.03');
    await scrollTo(tester, 'sc_read_6');
    expect(text(tester, 'sc_label_6'), '하강 50%');
    expect(field(tester, 'sc_read_6'), '12.06');
  });

  testWidgets('입력 보관: 시험점·하강·허용값·센서·온도 센서 탭 값이 남는다', (tester) async {
    await pumpPage(tester);
    await setRange(tester, '200', '°C');
    await openTab(tester, 'sg_tab_cal');
    await tapKey(tester, 'sc_pts_p3');
    await tapKey(tester, 'sc_down');
    await tester.enterText(find.byKey(const Key('sc_hyst_tol')), '0.2');
    await tapKey(tester, 'sc_sensor_j');
    await tester.enterText(find.byKey(const Key('sc_cj')), '25');
    await tester.pump();
    await openTab(tester, 'sg_tab_temp');
    await tapKey(tester, 'st_s_t');
    await tapKey(tester, 'st_dir_v');
    await tester.enterText(find.byKey(const Key('st_value')), '4.2785');
    await tester.enterText(find.byKey(const Key('st_cj')), '0');
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const MaterialApp(home: SignalCalculatorPage()));
    await tester.pumpAndSettle();
    await openTab(tester, 'sg_tab_cal');
    expect(text(tester, 'sc_label_3'), '하강 50%');
    expect(find.byKey(const Key('sc_label_5')), findsNothing);
    expect(field(tester, 'sc_hyst_tol'), '0.2');
    expect(field(tester, 'sc_cj'), '25');
    expect(text(tester, 'sc_sensor_val_1'), startsWith('J형 5.269 mV'));
    await openTab(tester, 'sg_tab_temp');
    expect(field(tester, 'st_value'), '4.2785');
    // T형 4.2785 mV(기준접점 0 °C) = 100 °C(NIST 표 4.279는 반올림 값)
    expect(textIn(tester, const Key('st_result')), contains('100 °C'));
  });

  testWidgets('온도 센서 탭: Pt100·K형 환산, 냉접점 보상, 범위 초과·미만', (tester) async {
    await pumpPage(tester);
    await openTab(tester, 'sg_tab_temp');
    await tester.enterText(find.byKey(const Key('st_value')), '100');
    await tester.pump();
    var r = textIn(tester, const Key('st_result'));
    expect(r, startsWith('Pt100 저항\n138.506 Ω'));
    expect(r, contains('IEC 60751'));
    await tapKey(tester, 'st_dir_v');
    await tester.enterText(find.byKey(const Key('st_value')), '60.2558');
    await tester.pump();
    expect(textIn(tester, const Key('st_result')), contains('-100 °C'));
    await tapKey(tester, 'st_s_pt1000');
    await tester.enterText(find.byKey(const Key('st_value')), '1385.055');
    await tester.pump();
    expect(textIn(tester, const Key('st_result')), contains('100 °C'));
    // K형 100 °C, 냉접점 20 °C
    await tapKey(tester, 'st_s_k');
    await tapKey(tester, 'st_dir_t');
    await tester.enterText(find.byKey(const Key('st_value')), '100');
    await tester.pump();
    r = textIn(tester, const Key('st_result'));
    expect(r, startsWith('교정기에 넣을 mV (냉접점 20 °C)\n3.298 mV'));
    expect(r, contains('기준접점 0 °C mV: 4.096 mV'));
    expect(r, contains('E(온도) − E(냉접점) = 4.096 − 0.798 = 3.298 mV'));
    expect(r, contains('IEC 60584-1'));
    // 냉접점을 비우면 0 °C
    await tester.enterText(find.byKey(const Key('st_cj')), '');
    await tester.pump();
    expect(
      textIn(tester, const Key('st_result')),
      startsWith('K형 열기전력 (기준접점 0 °C)\n4.096 mV'),
    );
    expect(find.text('냉접점 온도가 비어 있어 0 °C로 계산합니다.'), findsOneWidget);
    // mV → °C: 측정 3.298 mV + E(20 °C) 0.798 = 4.096 mV → 100 °C
    await tester.enterText(find.byKey(const Key('st_cj')), '20');
    await tapKey(tester, 'st_dir_v');
    await tester.enterText(find.byKey(const Key('st_value')), '3.298');
    await tester.pump();
    r = textIn(tester, const Key('st_result'));
    expect(r, contains('100 °C'));
    expect(r, contains('3.298 + 0.798 = 4.096 mV'));
    // 범위 밖
    await tester.enterText(find.byKey(const Key('st_value')), '60');
    await tester.pump();
    r = textIn(tester, const Key('st_result'));
    expect(r, contains('범위 초과'));
    expect(r, contains('-200 ~ 1372 °C'));
    await tapKey(tester, 'st_dir_t');
    await tester.enterText(find.byKey(const Key('st_value')), '1400');
    await tester.pump();
    expect(textIn(tester, const Key('st_result')), contains('범위 초과'));
    await tapKey(tester, 'st_s_pt100');
    await tester.enterText(find.byKey(const Key('st_value')), '-250');
    await tester.pump();
    r = textIn(tester, const Key('st_result'));
    expect(r, contains('범위 미만'));
    expect(r, contains('-200 ~ 850 °C'));
    // B형은 냉접점 0 °C 아래를 계산하지 못한다
    await tapKey(tester, 'st_s_b');
    await tester.enterText(find.byKey(const Key('st_cj')), '-5');
    await tester.enterText(find.byKey(const Key('st_value')), '600');
    await tester.pump();
    expect(
      textIn(tester, const Key('st_result')),
      contains('냉접점 온도를 0 ~ 1820 °C 이내로 넣으십시오'),
    );
  });

  testWidgets('온도 센서 탭 5점 표: 측정 범위 단위가 °C일 때만', (tester) async {
    await pumpPage(tester);
    await openTab(tester, 'sg_tab_temp');
    expect(find.byKey(const Key('st_table_hint')), findsOneWidget);
    expect(find.byKey(const Key('st_table')), findsNothing);
    await openTab(tester, 'sg_tab_conv');
    await setRange(tester, '100', '°C');
    await openTab(tester, 'sg_tab_temp');
    var t = textIn(tester, const Key('st_table'));
    expect(t, contains('5점 표 (Pt100, 0 ~ 100 °C)'));
    expect(t, contains('138.506'));
    expect(t, contains('119.397'));
    await tapKey(tester, 'st_s_k');
    t = textIn(tester, const Key('st_table'));
    // 100 °C: 4.096 − 0.798(냉접점 20 °C) = 3.298
    expect(t, contains('3.298'));
    expect(t, contains('mV는 냉접점 20 °C를 뺀 값(교정기에 넣을 값)입니다.'));
  });

  testWidgets('좁은 폰(344)·큰 글씨: 온도 센서 탭과 11점 하강·센서 교정 점검이 넘치지 않는다', (
    tester,
  ) async {
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
    await setRange(tester, '1000', '°C');
    await openTab(tester, 'sg_tab_temp');
    await tapKey(tester, 'st_s_k');
    await tester.enterText(find.byKey(const Key('st_value')), '1234.5');
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.dragUntilVisible(
      find.byKey(const Key('st_table')),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await scrollTo(tester, 'st_dir_v', up: true);
    await tapKey(tester, 'st_dir_v');
    await tester.enterText(find.byKey(const Key('st_value')), '99');
    await tester.pump();
    expect(tester.takeException(), isNull);

    await openTab(tester, 'sg_tab_cal');
    await tapKey(tester, 'sc_pts_p11');
    await tapKey(tester, 'sc_down');
    await tester.enterText(find.byKey(const Key('sc_hyst_tol')), '0.1');
    await tapKey(tester, 'sc_sensor_k');
    expect(tester.takeException(), isNull);
    await scrollTo(tester, 'sc_settings_toggle', up: true);
    await tapKey(tester, 'sc_settings_toggle');
    await tester.dragUntilVisible(
      find.byKey(const Key('sc_read_19')),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.enterText(find.byKey(const Key('sc_read_19')), '5.62');
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.dragUntilVisible(
      find.byKey(const Key('sc_save')),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
