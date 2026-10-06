// 전기 계산기 2026-09-26 추가 화면 시험: 교류/직류 선택(110V 단상·125VDC), 직류 전선 선정,
// 기초 계산 탭(옴·교류 전력·Y·Δ·전력량·도체 저항·주파수), 부스바 탭, 저장, 좁은 폰·큰 글씨.
import 'dart:convert';
import 'formula_flat.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'electric_legacy_defaults.dart';
import 'package:tubing_calculator/src/presentation/electrical/electric_calculator_page.dart';

Future<void> pumpPage(
  WidgetTester tester, {
  Size size = const Size(390, 3200),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: ElectricCalculatorPage()));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('ec_tab_load')));
  await tester.pumpAndSettle();
}

/// 좁은 폰(344×760)·글씨 1.3배.
Future<void> pumpNarrow(WidgetTester tester) async {
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
      home: const ElectricCalculatorPage(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('ec_tab_load')));
  await tester.pumpAndSettle();
}

String textIn(WidgetTester tester, Key key) {
  final texts = tester.widgetList<Text>(
    find.descendant(of: find.byKey(key), matching: find.byType(Text)),
  );
  return texts.map((t) => t.data ?? '').join('\n');
}

bool chipOn(WidgetTester tester, String key) =>
    tester.widget<ChoiceChip>(find.byKey(Key(key))).selected;

String fieldText(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(Key(key))).controller!.text;

Future<void> openTab(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

/// 목록 밖(아직 안 그린) 칸도 찾아 보이게 한다. 아래로 찾고, 없으면 위로.
Future<void> reveal(WidgetTester tester, Finder f) async {
  if (f.evaluate().isEmpty) {
    final s = find
        .descendant(
          of: find.byType(ListView).first,
          matching: find.byType(Scrollable),
        )
        .first;
    try {
      await tester.scrollUntilVisible(f, 200, scrollable: s, maxScrolls: 60);
    } catch (_) {
      await tester.scrollUntilVisible(f, -200, scrollable: s, maxScrolls: 60);
    }
  }
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await reveal(tester, find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> type(WidgetTester tester, String key, String v) async {
  await reveal(tester, find.byKey(Key(key)));
  await tester.enterText(find.byKey(Key(key)), v);
  await tester.pump();
}

Future<void> pickDropdown(WidgetTester tester, String key, String item) async {
  await tapKey(tester, key);
  await tester.tap(find.text(item).last);
  await tester.pumpAndSettle();
}

Future<String> resultOf(WidgetTester tester, String key) async {
  await reveal(tester, find.byKey(Key(key)));
  return textIn(tester, Key(key));
}

Future<String> basisOf(WidgetTester tester, String key) async {
  await reveal(tester, find.byKey(Key(key)));
  await tester.tap(
    find.descendant(of: find.byKey(Key(key)), matching: find.text('근거 보기')),
  );
  await tester.pumpAndSettle();
  return textIn(tester, Key(key));
}

void main() {
  setUp(legacyElectricDefaults);

  group('교류/직류', () {
    testWidgets('교류 110V는 단상: 히터 1.1kW → 10A', (tester) async {
      await pumpPage(tester);
      await tapKey(tester, 'ec_v_110');
      expect(chipOn(tester, 'ec_ph_1'), isTrue);
      await tapKey(tester, 'ec_lt_heater');
      await type(tester, 'ec_kw', '1.1');
      expect(await resultOf(tester, 'ec_load_result'), contains('10 A'));
    });

    testWidgets('직류를 누르면 125V가 기본, 역률 칸이 없고 I = P ÷ (V × 효율)', (tester) async {
      await pumpPage(tester);
      await tapKey(tester, 'ec_load_dc');
      expect(chipOn(tester, 'ec_load_dcv_125'), isTrue);
      expect(find.byKey(const Key('ec_pf')), findsNothing);
      expect(find.byKey(const Key('ec_v_380')), findsNothing);
      // 전동기 3.7kW, 효율 90% → 3700 ÷ (125 × 0.9) = 32.9A
      await type(tester, 'ec_kw', '3.7');
      var r = await resultOf(tester, 'ec_load_result');
      expect(r, contains('32.9 A'));
      expect(r, contains('정격전류(계산값, 직류)'));
      expect(r, isNot(contains('역률 값이 없어')));
      expect(flat(r), contains(flat('I = P × 1000 ÷ (V × 효율)')));
      final b = await basisOf(tester, 'ec_load_basis');
      expect(b, contains('직류는 역률을 쓰지 않습니다'));
      // 히터 2.5kW → 20A
      await tapKey(tester, 'ec_lt_heater');
      await type(tester, 'ec_kw', '2.5');
      r = await resultOf(tester, 'ec_load_result');
      expect(r, contains('20 A'));
      // 24V 계장으로 바꾸면 2.5kW → 104.2A
      await tapKey(tester, 'ec_load_dcv_24');
      expect(await resultOf(tester, 'ec_load_result'), contains('104.2 A'));
    });

    testWidgets('직류 전류 ↔ 전력: 125V 40A → 5kW, 10kW → 80A', (tester) async {
      await pumpPage(tester);
      await tapKey(tester, 'ec_load_dc');
      await type(tester, 'ec_conv_val', '40');
      var r = await resultOf(tester, 'ec_conv_result');
      expect(r, contains('5 kW'));
      expect(flat(r), contains(flat('식: P = V × I ÷ 1000 (직류)')));
      await tapKey(tester, 'ec_conv_kva');
      expect(find.text('kW → 전류'), findsOneWidget);
      await type(tester, 'ec_conv_val', '10');
      r = await resultOf(tester, 'ec_conv_result');
      expect(r, contains('80 A'));
    });

    testWidgets('한 번 고른 교류/직류는 전선 굵기·전압강하·부스바 탭이 같이 쓴다', (tester) async {
      await pumpPage(tester);
      await tapKey(tester, 'ec_load_dc');
      await openTab(tester, 'ec_tab_cable');
      expect(chipOn(tester, 'ec_cable_dc'), isTrue);
      expect(chipOn(tester, 'ec_cable_dcv_125'), isTrue);
      expect(find.byKey(const Key('ec_pf2')), findsNothing);
      await openTab(tester, 'ec_tab_vd');
      expect(chipOn(tester, 'ec_vd_dc'), isTrue);
      await tapKey(tester, 'ec_vd_dcv_110');
      await openTab(tester, 'ec_tab_bus');
      expect(chipOn(tester, 'ec_bus_dc'), isTrue);
      await tapKey(tester, 'ec_bus_ac');
      await openTab(tester, 'ec_tab_load');
      expect(chipOn(tester, 'ec_load_ac'), isTrue);
      expect(find.byKey(const Key('ec_pf')), findsOneWidget);
    });

    testWidgets('직류 전선 굵기: 125V 20A 50m → 10sq, 교류 차단기 대신 직류 차단기 안내', (
      tester,
    ) async {
      await pumpPage(tester);
      await openTab(tester, 'ec_tab_cable');
      await tapKey(tester, 'ec_cable_dc');
      await type(tester, 'ec_ib', '20');
      final r = await resultOf(tester, 'ec_cable_result');
      // 설계전류 25A(×1.25) → 1.5sq면 허용전류는 되지만 전압강하 때문에 10sq.
      // ΔU = 2 × 20 × 0.05 × 1.83 × 1.2751 = 4.67V → 3.73%
      expect(r, contains('10sq'));
      expect(r, contains('2심 기준 추천 굵기(직류)'));
      expect(r, contains('허용전류 86A (보정 후) ≥ 설계전류 25A'));
      expect(r, contains('직류 차단기 정격 In은 설계전류 25A 이상, 허용전류 86A 이하로 선정하십시오'));
      expect(r, contains('직류 정격 전압·차단용량이 표시된 차단기를 쓰십시오'));
      expect(r, contains('전압강하 4.67V (3.73%)'));
      expect(r, isNot(contains('전동기 회로')));
      expect(r, isNot(contains('THR')));
      expect(
        textIn(tester, const Key('ec_sum_cable')),
        '10sq · 직류 · 전압강하 3.7%',
      );
      final b = await basisOf(tester, 'ec_cable_basis');
      expect(b, contains('2가닥 통전(직류)'));
      expect(b, contains('single-phase AC or DC'));
      expect(b, contains('DC 250V를 2극, DC 500V를 3극'));
      expect(flat(b), contains(flat('직류는 리액턴스가 없습니다')));
      expect(b, contains('교류 기준이라 직류에는 계산하지 않습니다'));
      expect(b, isNot(contains('정격전류의 250%')));
    });

    testWidgets('직류 기존 회로 점검: 차단기 32A 넣으면 IB ≤ In ≤ IZ, 직류 차단기 안내', (
      tester,
    ) async {
      await pumpPage(tester);
      await openTab(tester, 'ec_tab_cable');
      await tapKey(tester, 'ec_cable_dc');
      await tapKey(tester, 'ec_mode_check');
      await pickDropdown(tester, 'ec_chk_size', '10sq');
      await type(tester, 'ec_ib', '20');
      await type(tester, 'ec_chk_breaker', '32');
      final r = await resultOf(tester, 'ec_cable_result');
      expect(r, contains('IB 25A ≤ In 32A ≤ IZ 86A: 조건을 만족합니다.'));
      expect(r, contains('직류 회로: 직류 정격 전압·차단용량이 표시된 차단기를 쓰십시오'));
      expect(r, isNot(contains('전동기 회로 차단기 범위')));
    });
  });

  group('기초 계산', () {
    testWidgets('옴의 법칙: 220V·10A → 22Ω·2.2kW, 세 값이면 알림', (tester) async {
      await pumpPage(tester);
      await openTab(tester, 'ec_tab_basic');
      expect(chipOn(tester, 'ec_bs_ohm'), isTrue);
      await type(tester, 'ec_ohm_v', '220');
      await type(tester, 'ec_ohm_i', '10');
      var r = await resultOf(tester, 'ec_ohm_result');
      expect(r, contains('22 Ω · 2.2 kW'));
      expect(r, contains('전압·전류 두 값으로 계산'));
      expect(flat(r), contains(flat('P = 2200 W (2.2 kW)')));
      expect(textIn(tester, const Key('ec_sum_basic')), '22 Ω · 2.2 kW');
      await type(tester, 'ec_ohm_r', '5');
      r = await resultOf(tester, 'ec_ohm_result');
      expect(r, contains('세 칸 이상 넣으면'));
      await type(tester, 'ec_ohm_v', '');
      await type(tester, 'ec_ohm_i', '');
      await type(tester, 'ec_ohm_p', '1000');
      // R 5Ω·P 1000W → I 14.14A, V 70.71V
      r = await resultOf(tester, 'ec_ohm_result');
      expect(r, contains('70.71 V · 14.14 A'));
      await type(tester, 'ec_ohm_p', '-1');
      expect(
        await resultOf(tester, 'ec_ohm_result'),
        contains('음수는 넣을 수 없습니다'),
      );
    });

    testWidgets(
      '교류 전력: 삼상 380V 100A 85% → 55.95kW·34.67kvar·65.82kVA, kW로 역산',
      (tester) async {
        await pumpPage(tester);
        await openTab(tester, 'ec_tab_basic');
        await tapKey(tester, 'ec_bs_acPower');
        await type(tester, 'ec_ac_i', '100');
        var r = await resultOf(tester, 'ec_ac_result');
        expect(r, contains('55.95 kW'));
        expect(flat(r), contains(flat('무효전력 Q = 34.67 kvar')));
        expect(flat(r), contains(flat('피상전력 S = 65.82 kVA')));
        expect(r, contains('위상각 31.8°'));
        expect(
          textIn(tester, const Key('ec_sum_basic')),
          '55.95 kW · 65.82 kVA',
        );
        await tapKey(tester, 'ec_ac_1');
        r = await resultOf(tester, 'ec_ac_result');
        // 단상 380V 100A → 38kVA × 0.85 = 32.3kW
        expect(r, contains('32.3 kW'));
        await tapKey(tester, 'ec_ac_3');
        await tapKey(tester, 'ec_ac_kw');
        await type(tester, 'ec_ac_kw_in', '100');
        await type(tester, 'ec_ac_pf', '80');
        r = await resultOf(tester, 'ec_ac_result');
        expect(r, contains('125 kVA'));
        expect(flat(r), contains(flat('무효전력 Q = 75 kvar')));
        expect(flat(r), contains(flat('전류 I = 189.9 A')));
      },
    );

    testWidgets('Y·Δ: Y 380V 10A → 상전압 219.4V, Δ → 상전류 5.774A, 상 값에서 선간 값', (
      tester,
    ) async {
      await pumpPage(tester);
      await openTab(tester, 'ec_tab_basic');
      await tapKey(tester, 'ec_bs_starDelta');
      await type(tester, 'ec_yd_v', '380');
      await type(tester, 'ec_yd_i', '10');
      var r = await resultOf(tester, 'ec_yd_result');
      expect(r, contains('상전압 219.4 V · 상전류 10 A'));
      expect(r, contains('Y-Δ 기동'));
      await tapKey(tester, 'ec_yd_delta');
      r = await resultOf(tester, 'ec_yd_result');
      expect(r, contains('상전압 380 V · 상전류 5.774 A'));
      await tapKey(tester, 'ec_yd_star');
      await tapKey(tester, 'ec_yd_phase');
      await type(tester, 'ec_yd_v', '220');
      r = await resultOf(tester, 'ec_yd_result');
      expect(r, contains('선간전압 381.1 V'));
    });

    testWidgets('전력량·요금: 5.5kW × 24h × 30일 = 3960kWh, 단가 150원 → 594000원', (
      tester,
    ) async {
      await pumpPage(tester);
      await openTab(tester, 'ec_tab_basic');
      await tapKey(tester, 'ec_bs_energy');
      await type(tester, 'ec_en_kw', '5.5');
      var r = await resultOf(tester, 'ec_en_result');
      expect(r, contains('3960 kWh'));
      expect(flat(r), contains(flat('하루 132 kWh × 30일')));
      await type(tester, 'ec_en_price', '150');
      r = await resultOf(tester, 'ec_en_result');
      expect(r, contains('요금 약 594000원'));
      expect(r, contains('기본요금'));
      await type(tester, 'ec_en_h', '30');
      r = await resultOf(tester, 'ec_en_result');
      expect(r, contains('하루 사용 시간은 24시간까지만 계산합니다.'));
    });

    testWidgets('도체 저항: 구리 2.5mm² 100m → 0.6896Ω, IEC 60228 표 값, 알루미늄, 합성 저항', (
      tester,
    ) async {
      await pumpPage(tester);
      await openTab(tester, 'ec_tab_basic');
      await tapKey(tester, 'ec_bs_resistance');
      await type(tester, 'ec_rs_a', '2.5');
      await type(tester, 'ec_rs_l', '100');
      var r = await resultOf(tester, 'ec_rs_result');
      expect(r, contains('0.6896 Ω'));
      expect(r, contains('왕복(2가닥) 1.379 Ω'));
      expect(r, contains('IEC 60228 2종(연선) 구리 20°C 최대 저항 7.41 Ω/km'));
      await type(tester, 'ec_rs_t', '90');
      r = await resultOf(tester, 'ec_rs_result');
      expect(r, contains('0.8794 Ω'));
      await tapKey(tester, 'ec_rs_al');
      await type(tester, 'ec_rs_t', '20');
      r = await resultOf(tester, 'ec_rs_result');
      // 0.028264 × 100 ÷ 2.5 = 1.131Ω
      expect(r, contains('1.131 Ω'));
      expect(r, isNot(contains('IEC 60228')));
      await type(tester, 'ec_rs_r1', '10');
      await type(tester, 'ec_rs_r2', '10');
      r = await resultOf(tester, 'ec_rs_sp_result');
      expect(r, contains('20 Ω'));
      expect(r, contains('병렬 합성 저항 5 Ω'));
    });

    testWidgets(
      '주파수: 60Hz 4극 1800rpm, 1750rpm 슬립 2.78%, 50Hz 1500rpm, XL·XC·공진',
      (tester) async {
        await pumpPage(tester);
        await openTab(tester, 'ec_tab_basic');
        await tapKey(tester, 'ec_bs_frequency');
        var r = await resultOf(tester, 'ec_hz_result');
        expect(r, contains('16.67 ms'));
        expect(flat(r), contains(flat('각주파수 ω = 377 rad/s')));
        r = await resultOf(tester, 'ec_hz_speed_result');
        expect(r, contains('1800 rpm'));
        expect(
          r,
          contains('60Hz 동기속도(rpm): 2극 3600, 4극 1800, 6극 1200, 8극 900'),
        );
        expect(
          r,
          contains('50Hz 동기속도(rpm): 2극 3000, 4극 1500, 6극 1000, 8극 750'),
        );
        expect(r, contains('동기속도는 1.2배'));
        await type(tester, 'ec_hz_n', '1750');
        r = await resultOf(tester, 'ec_hz_speed_result');
        expect(flat(r), contains(flat('슬립 s = (ns − n) ÷ ns = (1800 − 1750) ÷ 1800 = 2.78%')));
        expect(flat(r), contains(flat('f = p × n ÷ 120 = 4 × 1750 ÷ 120 = 58.33 Hz')));
        expect(
          textIn(tester, const Key('ec_sum_basic')),
          '60Hz · 4극 1800 rpm · 슬립 2.78%',
        );
        await type(tester, 'ec_hz_p', '3');
        expect(
          await resultOf(tester, 'ec_hz_speed_result'),
          contains('극수는 2 이상 짝수입니다'),
        );
        await type(tester, 'ec_hz_p', '2');
        await tapKey(tester, 'ec_hz_50');
        expect(fieldText(tester, 'ec_hz_f'), '50');
        expect(
          await resultOf(tester, 'ec_hz_speed_result'),
          contains('3000 rpm'),
        );
        await tapKey(tester, 'ec_hz_60');
        await type(tester, 'ec_hz_l', '100');
        r = await resultOf(tester, 'ec_hz_x_result');
        expect(r, contains('37.7 Ω'));
        await type(tester, 'ec_hz_c', '100');
        r = await resultOf(tester, 'ec_hz_x_result');
        expect(r, contains('50.33 Hz'));
        expect(flat(r), contains(flat('XC = 1 ÷ (2π × f × C) = 1 ÷ (2π × 60 × 0.0001) = 26.53 Ω (60Hz')));
      },
    );
  });

  group('부스바', () {
    testWidgets(
      '허용전류: 40×10 교류 도장 안 함 715A·1.79A/mm², 도장 2가닥 1470A, 직류 1530A',
      (tester) async {
        await pumpPage(tester);
        await openTab(tester, 'ec_tab_bus');
        expect(chipOn(tester, 'ec_bus_mode_amp'), isTrue);
        expect(chipOn(tester, 'ec_bus_bare'), isTrue);
        var r = await resultOf(tester, 'ec_bus_result');
        expect(r, contains('715 A'));
        expect(flat(r), contains(flat('전류 밀도 1.79 A/mm² = 허용전류 715 A ÷ 단면적 399 mm²')));
        expect(r, contains('조건: DIN 43671, 옥내, 주위 35°C, 부스바 65°C'));
        expect(
          textIn(tester, const Key('ec_sum_bus')),
          '40×10 · 715 A · 1.79 A/mm²',
        );
        await tapKey(tester, 'ec_bus_painted');
        await tapKey(tester, 'ec_bus_n_2');
        r = await resultOf(tester, 'ec_bus_result');
        expect(r, contains('1470 A'));
        expect(flat(r), contains(flat('40×10 × 2 허용전류 (교류, 도장)')));
        await tapKey(tester, 'ec_bus_dc');
        expect(await resultOf(tester, 'ec_bus_result'), contains('1530 A'));
        // 직류 4가닥은 DIN 표에 없다.
        await tapKey(tester, 'ec_bus_n_4');
        r = await resultOf(tester, 'ec_bus_result');
        expect(r, contains('표 값 없음'));
        expect(r, contains('DIN 43671 표에 이 가닥 수 값이 없습니다'));
        // 얇은 부스바 직류 2가닥은 확인한 값이 없다.
        await tapKey(tester, 'ec_bus_n_2');
        await pickDropdown(tester, 'ec_bus_size', '12×2 (23.5 mm²)');
        r = await resultOf(tester, 'ec_bus_result');
        expect(r, contains('두 출처로 확인한 값이 없어 넣지 않았습니다'));
        final b = await basisOf(tester, 'ec_bus_basis');
        expect(b, contains('IEC 61439'));
        expect(b, contains('k2'));
      },
    );

    testWidgets('허용전류 모드에 부하 전류를 넣으면 이내·초과', (tester) async {
      await pumpPage(tester);
      await openTab(tester, 'ec_tab_bus');
      await type(tester, 'ec_bus_i', '700');
      expect(
        await resultOf(tester, 'ec_bus_result'),
        contains('선정 전류 700 A는 허용전류 715 A 이내입니다.'),
      );
      await type(tester, 'ec_bus_i', '800');
      expect(
        await resultOf(tester, 'ec_bus_result'),
        contains('허용전류 715 A를 초과합니다'),
      );
    });

    testWidgets(
      '굵기 선정: 교류 도장 안 함 1000A → 1가닥 100×5, 2가닥 60×5, 3가닥 20×10, 여유 25%',
      (tester) async {
        await pumpPage(tester);
        await openTab(tester, 'ec_tab_bus');
        await tapKey(tester, 'ec_bus_mode_pick');
        expect(find.byKey(const Key('ec_bus_size')), findsNothing);
        await type(tester, 'ec_bus_i', '1000');
        var r = await resultOf(tester, 'ec_bus_result');
        expect(flat(r), contains(flat('1가닥: 100×5 (1080 A, 2.16 A/mm²)')));
        expect(flat(r), contains(flat('2가닥: 60×5 × 2 (1150 A, 1.92 A/mm²)')));
        expect(flat(r), contains(flat('3가닥: 20×10 × 3 (1180 A, 1.98 A/mm²)')));
        expect(flat(r), contains(flat('4가닥: 50×5 × 4 (1920 A, 1.93 A/mm²)')));
        expect(
          textIn(tester, const Key('ec_sum_bus')),
          '1가닥 100×5 · 2가닥 60×5 · 3가닥 20×10',
        );
        await type(tester, 'ec_bus_margin', '25');
        r = await resultOf(tester, 'ec_bus_result');
        expect(flat(r), contains(flat('1가닥: 100×10 (1490 A')));
        expect(flat(r), contains(flat('선정 전류 1250 A = 부하 1000 A × 1.25')));
        await type(tester, 'ec_bus_i', '99999');
        r = await resultOf(tester, 'ec_bus_result');
        expect(r, contains('검토 필요'));
        expect(r, contains('1가닥: 표 안에 맞는 규격이 없습니다'));
      },
    );
  });

  // 결과 상자에 식 → 숫자 대입 → 결과 풀이 줄이 보인다(2026-10-03).
  group('풀이 줄(식 → 대입 → 결과)', () {
    testWidgets('부하 전류: ① 정격전류 ② 설계전류, 직류는 역률 없는 식', (tester) async {
      await pumpPage(tester);
      await type(tester, 'ec_kw', '11');
      var r = await resultOf(tester, 'ec_load_result');
      // 식·대입·결과는 풀이 카드에 세 줄로 따로 나온다.
      expect(flat(r), contains(flat('I = P × 1000 ÷ (√3 × V × 역률 × 효율)')));
      expect(flat(r), contains(flat('11 × 1000 ÷ (√3 × 380 × 0.85 × 0.9)')));
      expect(r, contains('21.8 A'));
      expect(flat(r), contains(flat('설계전류 = 정격전류 × 여유')));
      expect(flat(r), contains(flat('21.8 × 1.25')));
      expect(r, contains('27.3 A'));
      expect(r, contains('50A 이하라 1.25배'));
      await tapKey(tester, 'ec_load_dc');
      await type(tester, 'ec_kw', '5');
      r = await resultOf(tester, 'ec_load_result');
      expect(flat(r), contains(flat('I = P × 1000 ÷ (V × 효율)')));
      expect(flat(r), contains(flat('5 × 1000 ÷ (125 × 0.9)')));
      expect(r, contains('44.4 A'));
    });

    testWidgets('전류 ↔ 전력 환산: 대입 줄', (tester) async {
      await pumpPage(tester);
      await type(tester, 'ec_conv_val', '50');
      var r = await resultOf(tester, 'ec_conv_result');
      expect(flat(r), contains(flat('S = √3 × 380 × 50 ÷ 1000 = 32.9 kVA')));
      expect(flat(r), contains(flat('P = S × 역률 = 32.9 × 0.85 = 28 kW')));
      await tapKey(tester, 'ec_conv_kva');
      await type(tester, 'ec_conv_val', '100');
      r = await resultOf(tester, 'ec_conv_result');
      expect(flat(r), contains(flat('I = 100 × 1000 ÷ (√3 × 380) = 151.9 A')));
    });

    testWidgets('전선 굵기 선정: ① 설계전류 → ② 차단기 → 허용전류 → 전압강하 → 굵기 결정', (
      tester,
    ) async {
      await pumpPage(tester);
      await type(tester, 'ec_kw', '11');
      await tapKey(tester, 'ec_to_cable');
      final r = await resultOf(tester, 'ec_cable_result');
      expect(flat(r), contains(flat('① 설계전류 IB = 부하 전류 × 여유 = 21.8 × 1.25 = 27.3 A (전동기 여유)')));
      expect(flat(r), contains(flat('② 차단기 In = 표준 정격 중 IB 27.3 A 이상인 가장 작은 값 = 30 A')));
      expect(flat(r), contains(flat('2.5sq 허용전류 IZ = 표 값 × 온도 보정 × 다조 포설 보정 = 32 × 1 × 1 = 32 A')));
      expect(flat(r), contains(flat('허용전류 기준 굵기: 보정 후 IZ ≥ In 30 A를 만족하는 가장 가는 굵기 = 2.5sq')));
      expect(flat(r), contains(flat('ΔU = √3 × I × L × (R cosφ + X sinφ) = √3 × 21.8 × (50 ÷ 1000) × (9.448 × 0.85 + 0.096 × 0.53) = 15.26 V')));
      expect(flat(r), contains(flat('전압강하율 = ΔU ÷ V × 100 = 15.26 ÷ 380 × 100 = 4.02 %')));
      expect(flat(r), contains(flat('한도 = 5 % (편도 100 m 이하라 가산 없음). 4.02 % ≤ 5 %이므로 한도 이내입니다.')));
      expect(flat(r), contains(flat('굵기 결정: 허용전류 기준 2.5sq, 전압강하 기준 2.5sq 중 굵은 쪽 = 2.5sq')));
    });

    testWidgets('전선 굵기 직류·병렬: 차단기 대신 IZ ≥ IB, 병렬 가닥 수를 곱한 허용전류', (tester) async {
      await pumpPage(tester);
      await openTab(tester, 'ec_tab_cable');
      await tapKey(tester, 'ec_cable_dc');
      await type(tester, 'ec_ib', '100');
      await type(tester, 'ec_length', '300');
      var r = await resultOf(tester, 'ec_cable_result');
      expect(r, contains('직류는 차단기 정격을 정하지 않고 허용전류 IZ ≥ IB 110 A로 굵기를 정합니다'));
      expect(flat(r), contains(flat('ΔU = 2 × I × L × R = 2 × 100 × (300 ÷ 1000) × 0.0961 = 5.77 V')));
      await tapKey(tester, 'ec_cable_ac');
      await type(tester, 'ec_ib', '300');
      await type(tester, 'ec_length', '200');
      await tapKey(tester, 'ec_par_2');
      r = await resultOf(tester, 'ec_cable_result');
      expect(flat(r), contains(flat('70sq 허용전류 IZ = 표 값 × 온도 보정 × 다조 포설 보정 × 2가닥 = 246 × 1 × 0.8 × 2 = 393.6 A')));
      expect(flat(r), contains(flat('√3 × (300 ÷ 2) × (200 ÷ 1000)')));
    });

    testWidgets('기존 회로 점검: IB ≤ In ≤ IZ 비교 줄과 전압강하 대입', (tester) async {
      await pumpPage(tester);
      await type(tester, 'ec_kw', '11');
      await tapKey(tester, 'ec_to_cable');
      await tapKey(tester, 'ec_mode_check');
      await type(tester, 'ec_chk_breaker', '30');
      final r = await resultOf(tester, 'ec_cable_result');
      expect(flat(r), contains(flat('① 설계전류 IB = 부하 전류 × 여유 = 21.8 × 1.25 = 27.3 A (전동기 여유)')));
      expect(flat(r), contains(flat('② 2.5sq 허용전류 IZ = 표 값 × 온도 보정 × 다조 포설 보정 = 32 × 1 × 1 = 32 A')));
      expect(r, contains('③ IB ≤ In ≤ IZ: 27.3 ≤ 30 ≤ 32 → 만족'));
      expect(flat(r), contains(flat('전압강하율 = ΔU ÷ V × 100 = 15.26 ÷ 380 × 100 = 4.02 %')));
    });

    testWidgets('AWG 선정: IZ = min(절연 열 × 보정, 단자 열), 전압강하 대입', (tester) async {
      await pumpPage(tester);
      await openTab(tester, 'ec_tab_cable');
      await tapKey(tester, 'ec_cable_unit_awg');
      await type(tester, 'ec_ib', '40');
      await type(tester, 'ec_length', '60');
      final r = await resultOf(tester, 'ec_cable_result');
      expect(flat(r), contains(flat('① 설계전류 IB = 부하 전류 × 1.25 = 40 × 1.25 = 50 A (NEC 430.22)')));
      expect(flat(r), contains(flat('6 AWG 허용전류 IZ = min(90°C 열 값 × 온도 보정 × 가닥 감소, 단자 60°C 열 값) = min(75 × 1 × 1, 55) = min(75, 55) = 55 A')));
      expect(flat(r), contains(flat('(R = 6 AWG 75°C 저항 Ω/km)')));
    });

    testWidgets('전압강하: R → ΔU → 전압강하율 → 한도(100 m 넘는 가산) → 최대 길이 → 기동', (
      tester,
    ) async {
      await pumpPage(tester);
      await openTab(tester, 'ec_tab_vd');
      await type(tester, 'ec_vd_i', '20');
      await type(tester, 'ec_vd_len', '150');
      await tapKey(tester, 'ec_vd_start');
      final r = await resultOf(tester, 'ec_vd_result');
      expect(flat(r), contains(flat('R = R20 × (1 + 0.00393 × (θ − 20))')));
      expect(flat(r), contains(flat('4.61 × (1 + 0.00393 × (90 − 20))')));
      expect(r, contains('5.878 Ω/km'));
      expect(flat(r), contains(flat('ΔU = √3 × I × L × (R cosφ + X sinφ)')));
      expect(flat(r), contains(flat('√3 × 20 × (150 ÷ 1000) × (5.878 × 0.85 + 0.096 × 0.53)')));
      expect(r, contains('26.23 V'));
      expect(flat(r), contains(flat('전압강하율 = ΔU ÷ V × 100')));
      expect(flat(r), contains(flat('26.23 ÷ 380 × 100')));
      expect(r, contains('6.9 %'));
      expect(flat(r), contains(flat('한도 = 5 % + (150 − 100) × 0.005 = 5.25 %. 6.9 % > 5.25 %이므로 한도 초과입니다.')));
      expect(flat(r), contains(flat('L = (5 − 0.5) ÷ (0.04601 − 0.005) = 110 m')));
      expect(flat(r), contains(flat('기동 전류 = 정격 전류 × 배수')));
      expect(flat(r), contains(flat('20 × 6')));
      expect(r, contains('120 A'));
      expect(flat(r), contains(flat('√3 × 120 × (150 ÷ 1000) × (5.878 × 0.35 + 0.096 × 0.94)')));
      expect(r, contains('66.95 V'));
    });

    testWidgets('전압강하 직류·AWG: 리액턴스 없는 식, 저항표 값', (tester) async {
      await pumpPage(tester);
      await openTab(tester, 'ec_tab_vd');
      await tapKey(tester, 'ec_vd_dc');
      await pickDropdown(tester, 'ec_vd_size', '1sq');
      await type(tester, 'ec_vd_i', '2');
      await type(tester, 'ec_vd_len', '50');
      var r = await resultOf(tester, 'ec_vd_result');
      expect(flat(r), contains(flat('ΔU = 2 × I × L × R')));
      expect(flat(r), contains(flat('2 × 2 × (50 ÷ 1000) × 23.079')));
      expect(r, contains('4.62 V'));
      await tapKey(tester, 'ec_vd_ac');
      await tapKey(tester, 'ec_vd_unit_awg');
      await type(tester, 'ec_vd_i', '30');
      await type(tester, 'ec_vd_len', '80');
      r = await resultOf(tester, 'ec_vd_result');
      expect(flat(r), contains(flat('① ΔU = √3 × I × L × (R cosφ + X sinφ) = √3 × 30 × (80 ÷ 1000) × (6.5 × 0.85 + 0.096 × 0.53) = 23.18 V')));
    });

    testWidgets('역률 개선: tanφ → Qc → μF → 전류', (tester) async {
      await pumpPage(tester);
      await openTab(tester, 'ec_tab_pf');
      await type(tester, 'ec_pc_kw', '100');
      final r = await resultOf(tester, 'ec_pf_result');
      expect(flat(r), contains(flat('① tanφ = √(1 − 역률²) ÷ 역률: 개선 전 √(1 − 0.8²) ÷ 0.8 = 0.75, 목표 √(1 − 0.95²) ÷ 0.95 = 0.329')));
      expect(flat(r), contains(flat('② 콘덴서 용량 Qc = P × (tanφ1 − tanφ2) = 100 × (0.75 − 0.329) = 42.1 kvar')));
      expect(flat(r), contains(flat('③ 정전용량 C = Qc × 10⁹ ÷ (2π × 60 × V²) = 42.1 × 10⁹ ÷ (2π × 60 × 380²) = 774 μF')));
      expect(flat(r), contains(flat('④ 콘덴서 전류 = Qc × 1000 ÷ (√3 × V) = 42.1 × 1000 ÷ (√3 × 380) = 64 A')));
    });

    testWidgets('전선관: 전선 단면적 → 관 내 단면적 → 점유율 → 한도로 필요한 단면적', (tester) async {
      await pumpPage(tester);
      await openTab(tester, 'ec_tab_conduit');
      final r = await resultOf(tester, 'ec_cd_result');
      expect(flat(r), contains(flat('① 전선 단면적 합 = π ÷ 4 × 외경² × 가닥 수 = π ÷ 4 × 4.1² × 3 = 39.6 mm²')));
      expect(flat(r), contains(flat('② 관 내 단면적 = π ÷ 4 × 내경² = π ÷ 4 × 21.9² = 376.7 mm²')));
      expect(flat(r), contains(flat('③ 점유율 = 전선 단면적 합 ÷ 관 내 단면적 × 100 = 39.6 ÷ 376.7 × 100 = 10.5 %')));
      expect(flat(r), contains(flat('④ 한도 32 %를 지키려면 관 내 단면적 ≥ 39.6 ÷ (32 ÷ 100) = 123.8 mm²')));
    });

    testWidgets('부스바: 여유를 넣은 선정 전류 식', (tester) async {
      await pumpPage(tester);
      await openTab(tester, 'ec_tab_bus');
      await type(tester, 'ec_bus_i', '600');
      await type(tester, 'ec_bus_margin', '10');
      final r = await resultOf(tester, 'ec_bus_result');
      expect(flat(r), contains(flat('선정 전류 = 부하 전류 × (1 + 여유 ÷ 100) = 600 × (1 + 10 ÷ 100) = 660 A')));
    });

    testWidgets('기초 계산: 옴·교류 전력·Y·Δ·전력량·도체 저항·합성 저항·주파수 대입 줄', (tester) async {
      await pumpPage(tester);
      await openTab(tester, 'ec_tab_basic');
      await type(tester, 'ec_ohm_v', '220');
      await type(tester, 'ec_ohm_r', '22');
      var r = await resultOf(tester, 'ec_ohm_result');
      expect(flat(r), contains(flat('I = V ÷ R = 220 ÷ 22 = 10 A')));
      expect(flat(r), contains(flat('P = V² ÷ R = 220² ÷ 22 = 2200 W')));
      await tapKey(tester, 'ec_bs_acPower');
      await type(tester, 'ec_ac_i', '50');
      r = await resultOf(tester, 'ec_ac_result');
      expect(flat(r), contains(flat('S = √3 × V × I ÷ 1000 = √3 × 380 × 50 ÷ 1000 = 32.91 kVA')));
      expect(flat(r), contains(flat('P = S × cosφ = 32.91 × 0.85 = 27.97 kW')));
      await tapKey(tester, 'ec_bs_starDelta');
      await type(tester, 'ec_yd_v', '380');
      r = await resultOf(tester, 'ec_yd_result');
      expect(flat(r), contains(flat('V상 = V선 ÷ √3 = 380 ÷ 1.732 = 219.4 V')));
      await tapKey(tester, 'ec_bs_energy');
      await type(tester, 'ec_en_kw', '5.5');
      await type(tester, 'ec_en_price', '150');
      r = await resultOf(tester, 'ec_en_result');
      expect(flat(r), contains(flat('전력량 = kW × 하루 사용 시간 × 일수 = 5.5 × 24 × 30 = 3960 kWh')));
      expect(flat(r), contains(flat('요금 약 594000원 (= 3960 kWh × 단가 150원/kWh)')));
      await tapKey(tester, 'ec_bs_resistance');
      await type(tester, 'ec_rs_a', '2.5');
      await type(tester, 'ec_rs_l', '100');
      await type(tester, 'ec_rs_r1', '10');
      await type(tester, 'ec_rs_r2', '20');
      r = await resultOf(tester, 'ec_rs_result');
      expect(flat(r), contains(flat('R = 0.017241 × 100 ÷ 2.5 × (1 + 0.00393 × (20 − 20)) = 0.6896 Ω')));
      r = await resultOf(tester, 'ec_rs_sp_result');
      expect(flat(r), contains(flat('직렬 R = 10 + 20 = 30 Ω')));
      expect(flat(r), contains(flat('병렬 R = 1 ÷ (1/10 + 1/20) = 6.667 Ω')));
      await tapKey(tester, 'ec_bs_frequency');
      r = await resultOf(tester, 'ec_hz_result');
      expect(flat(r), contains(flat('T = 1 ÷ 60 = 16.67 ms, ω = 2π × 60 = 377 rad/s')));
      r = await resultOf(tester, 'ec_hz_speed_result');
      expect(flat(r), contains(flat('ns = 120 × f ÷ p = 120 × 60 ÷ 4 = 1800 rpm')));
    });
  });

  group('저장', () {
    testWidgets('교류/직류·기초 계산·부스바 입력을 저장했다가 다시 열면 채운다', (tester) async {
      await pumpPage(tester);
      await tapKey(tester, 'ec_load_dc');
      await tapKey(tester, 'ec_load_dcv_110');
      await openTab(tester, 'ec_tab_basic');
      await tapKey(tester, 'ec_bs_energy');
      await type(tester, 'ec_en_kw', '5.5');
      await openTab(tester, 'ec_tab_bus');
      await tapKey(tester, 'ec_bus_painted');
      await tapKey(tester, 'ec_bus_n_3');
      await pickDropdown(tester, 'ec_bus_size', '60×10 (599 mm²)');
      await tester.pump(const Duration(seconds: 1));
      final prefs = await SharedPreferences.getInstance();
      final m =
          jsonDecode(prefs.getString(ElectricCalculatorPage.draftKey)!)
              as Map<String, dynamic>;
      expect(m['dc'], true);
      expect(m['dcV'], 110);
      expect(m['bsSec'], 'energy');
      expect(m['enKw'], '5.5');
      expect(m['busPainted'], true);
      expect(m['busBars'], 3);
      expect(m['busSize'], '60×10');

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        const MaterialApp(home: ElectricCalculatorPage()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ec_tab_load')));
      await tester.pumpAndSettle();
      expect(chipOn(tester, 'ec_load_dc'), isTrue);
      expect(chipOn(tester, 'ec_load_dcv_110'), isTrue);
      await openTab(tester, 'ec_tab_basic');
      expect(chipOn(tester, 'ec_bs_energy'), isTrue);
      expect(fieldText(tester, 'ec_en_kw'), '5.5');
      await openTab(tester, 'ec_tab_bus');
      expect(chipOn(tester, 'ec_bus_painted'), isTrue);
      expect(chipOn(tester, 'ec_bus_n_3'), isTrue);
      // 60×10 도장 3가닥 직류 2720A
      expect(await resultOf(tester, 'ec_bus_result'), contains('2720 A'));
    });

    testWidgets('예전 저장 칸(전압강하 탭 vdDc·vdDcV)도 읽는다', (tester) async {
      SharedPreferences.setMockInitialValues({
        ElectricCalculatorPage.draftKey: jsonEncode({
          'vdDc': true,
          'vdDcV': 24,
        }),
      });
      await pumpPage(tester);
      await openTab(tester, 'ec_tab_vd');
      expect(chipOn(tester, 'ec_vd_dc'), isTrue);
      expect(chipOn(tester, 'ec_vd_dcv_24'), isTrue);
    });
  });

  group('입력 읽기', () {
    testWidgets('역률에 1 이하를 넣으면 비율로 읽었다고 알려 준다', (tester) async {
      await pumpPage(tester);
      await type(tester, 'ec_kw', '11');
      await type(tester, 'ec_pf', '0.85');
      final r = await resultOf(tester, 'ec_load_result');
      expect(r, contains('비율로 읽어 85%로 계산했습니다'));
      await type(tester, 'ec_pf', '85');
      final r2 = await resultOf(tester, 'ec_load_result');
      expect(r2, isNot(contains('비율로 읽어')));
    });

    testWidgets('전압 직접 입력의 쉼표 소수(1,5)와 천 단위(1,500)를 같은 규칙으로 읽는다', (tester) async {
      await pumpPage(tester);
      await type(tester, 'ec_kw', '1,5');
      final r = await resultOf(tester, 'ec_load_result');
      // 1,5 kW → 1.5 kW (15 kW가 아니다): 380 V 삼상 효율 90·역률 85 → 약 3 A
      expect(r, contains('3 A'));
    });
  });

  group('좁은 폰(344)·큰 글씨', () {
    testWidgets('풀이 카드: 부하 전류·전압강하(기동 포함)가 넘치지 않고 식이 따로 보인다', (tester) async {
      await pumpNarrow(tester);
      await type(tester, 'ec_kw', '11');
      await reveal(tester, find.byKey(const Key('ec_load_formula')));
      expect(find.byKey(const Key('ec_load_formula')), findsOneWidget);
      expect(textIn(tester, const Key('ec_load_formula')), contains('풀이'));
      expect(tester.takeException(), isNull, reason: '부하 전류 풀이');
      await openTab(tester, 'ec_tab_vd');
      await type(tester, 'ec_vd_i', '20');
      await type(tester, 'ec_vd_len', '150');
      await tapKey(tester, 'ec_vd_start');
      await reveal(tester, find.byKey(const Key('ec_vd_formula')));
      final t = textIn(tester, const Key('ec_vd_formula'));
      expect(flat(t), contains(flat('ΔU = √3 × I × L × (R cosφ + X sinφ)')));
      expect(t, contains('L 편도 길이(km)'));
      expect(tester.takeException(), isNull, reason: '전압강하 풀이');
    });

    testWidgets('탭 11개가 모두 열리고 넘치지 않는다', (tester) async {
      await pumpNarrow(tester);
      const tabs = [
        'ec_tab_basic',
        'ec_tab_load',
        'ec_tab_cable',
        'ec_tab_vd',
        'ec_tab_short',
        'ec_tab_ground',
        'ec_tab_loadsum',
        'ec_tab_pf',
        'ec_tab_conduit',
        'ec_tab_bus',
        'ec_tab_batt',
      ];
      for (final t in [...tabs.reversed, ...tabs]) {
        await openTab(tester, t);
        expect(tester.takeException(), isNull, reason: t);
        expect(
          tester.widget<TabBar>(find.byType(TabBar)).controller!.index,
          tabs.indexOf(t),
        );
      }
    });

    testWidgets('직류 부하 전류·전선 굵기(선정·점검)가 넘치지 않는다', (tester) async {
      await pumpNarrow(tester);
      await tapKey(tester, 'ec_load_dc');
      await type(tester, 'ec_kw', '15');
      await type(tester, 'ec_conv_val', '120');
      expect(tester.takeException(), isNull, reason: '직류 부하');
      await tapKey(tester, 'ec_to_cable');
      await type(tester, 'ec_length', '120');
      await reveal(tester, find.byKey(const Key('ec_cable_result')));
      expect(tester.takeException(), isNull, reason: '직류 선정');
      await tapKey(tester, 'ec_mode_check');
      await type(tester, 'ec_chk_breaker', '100');
      await reveal(tester, find.byKey(const Key('ec_cable_result')));
      expect(tester.takeException(), isNull, reason: '직류 점검');
    });

    testWidgets('기초 계산 여섯 항목이 넘치지 않는다', (tester) async {
      await pumpNarrow(tester);
      await openTab(tester, 'ec_tab_basic');
      final inputs = {
        'ec_bs_ohm': {'ec_ohm_v': '220', 'ec_ohm_i': '12.5', 'ec_ohm_r': '3'},
        'ec_bs_acPower': {'ec_ac_i': '1234.5'},
        'ec_bs_starDelta': {'ec_yd_v': '6600', 'ec_yd_i': '1234'},
        'ec_bs_energy': {'ec_en_kw': '1234.5', 'ec_en_price': '185.5'},
        'ec_bs_resistance': {
          'ec_rs_a': '2.5',
          'ec_rs_l': '1234',
          'ec_rs_r1': '10',
          'ec_rs_r2': '22',
          'ec_rs_r3': '47',
        },
        'ec_bs_frequency': {
          'ec_hz_n': '1750',
          'ec_hz_l': '12.5',
          'ec_hz_c': '47',
        },
      };
      const results = {
        'ec_bs_ohm': ['ec_ohm_result'],
        'ec_bs_acPower': ['ec_ac_result'],
        'ec_bs_starDelta': ['ec_yd_result'],
        'ec_bs_energy': ['ec_en_result'],
        'ec_bs_resistance': ['ec_rs_result', 'ec_rs_sp_result'],
        'ec_bs_frequency': [
          'ec_hz_result',
          'ec_hz_speed_result',
          'ec_hz_x_result',
        ],
      };
      for (final e in inputs.entries) {
        await tapKey(tester, e.key);
        for (final f in e.value.entries) {
          await type(tester, f.key, f.value);
        }
        for (final k in results[e.key]!) {
          await reveal(tester, find.byKey(Key(k)));
          expect(tester.takeException(), isNull, reason: k);
        }
        await reveal(tester, find.text('계산 항목'));
        expect(tester.takeException(), isNull, reason: e.key);
      }
      await tapKey(tester, 'ec_bs_acPower');
      await tapKey(tester, 'ec_ac_kw');
      await type(tester, 'ec_ac_kw_in', '250');
      await reveal(tester, find.byKey(const Key('ec_ac_result')));
      expect(tester.takeException(), isNull, reason: 'kW 역산');
    });

    testWidgets('부스바 허용전류·굵기 선정·근거 보기가 넘치지 않는다', (tester) async {
      await pumpNarrow(tester);
      await openTab(tester, 'ec_tab_bus');
      await tapKey(tester, 'ec_bus_n_4');
      await type(tester, 'ec_bus_i', '2500');
      await reveal(tester, find.byKey(const Key('ec_bus_result')));
      expect(tester.takeException(), isNull, reason: '허용전류');
      await pickDropdown(tester, 'ec_bus_size', '60×10 (599 mm²)');
      expect(tester.takeException(), isNull, reason: '규격');
      await tapKey(tester, 'ec_bus_dc');
      await tapKey(tester, 'ec_bus_mode_pick');
      await type(tester, 'ec_bus_margin', '25');
      await reveal(tester, find.byKey(const Key('ec_bus_result')));
      expect(tester.takeException(), isNull, reason: '굵기 선정');
      await basisOf(tester, 'ec_bus_basis');
      expect(tester.takeException(), isNull, reason: '근거 보기');
    });
  });
}
