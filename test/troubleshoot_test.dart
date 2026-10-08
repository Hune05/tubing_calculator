// 고장 진단 흐름: 모든 단계가 이어지고, 판정이 앱 안 계산 함수와 같은 값을 쓴다.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/electrical/protection_calc.dart';
import 'package:tubing_calculator/src/presentation/electrical/troubleshoot_flows.dart';
import 'package:tubing_calculator/src/presentation/electrical/troubleshoot_flows_general.dart';
import 'package:tubing_calculator/src/presentation/electrical/troubleshoot_page.dart';

Future<void> _open(WidgetTester tester, String flowId) async {
  tester.view.physicalSize = const Size(800, 6000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: TroubleshootPage()));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('ts_flow_$flowId')));
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

String _all(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text, skipOffstage: false))
    .map((t) => t.data ?? '')
    .join('\n');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('모든 단계가 이어진다: 다음 단계 id가 실제로 있고, 끝 단계에 닿는다', () {
    for (final f in troubleshootFlows()) {
      expect(f.steps.containsKey(f.start), isTrue, reason: f.id);
      final reach = <String>{};
      void walk(String id) {
        if (!reach.add(id)) return;
        final s = f.steps[id];
        expect(s, isNotNull, reason: '${f.id}: $id 없음');
        if (s is WizChoice) {
          for (final o in s.options) {
            walk(o.$2);
          }
        }
      }

      walk(f.start);
      // 측정 단계의 다음은 판정 결과에서 정해지므로 id를 직접 찾아 모두 있는지 본다.
      for (final s in f.steps.values) {
        if (s is WizMeasure) {
          expect(f.steps.values.any((x) => x.id != s.id), isTrue);
        }
      }
      expect(f.steps.values.whereType<WizEnd>(), isNotEmpty, reason: f.id);
    }
  });

  test('소스에 적힌 다음 단계 id가 모두 실제 단계다', () {
    final src = [
      'lib/src/presentation/electrical/troubleshoot_flows.dart',
      'lib/src/presentation/electrical/troubleshoot_flows_general.dart',
    ].map((f) => File(f).readAsStringSync()).join('\n');
    final ids = {for (final f in troubleshootFlows()) ...f.steps.keys};
    final used = RegExp(r"'((?:e|t|m|g|v|h|x|c|l)_\w+)'").allMatches(src).map((m) => m.group(1)!);
    for (final u in used) {
      expect(ids.contains(u), isTrue, reason: '$u 단계가 없음');
    }
    // 끝 단계는 모두 어딘가에서 이어진다.
    for (final e in ids.where((i) => i.startsWith('e_'))) {
      expect(RegExp("'$e'").allMatches(src).length, greaterThan(1), reason: '$e에 닿는 길이 없음');
    }
  });

  testWidgets('차단기 트립 → 즉시 트립: 절연 불량이면 불합격 판정과 절연 불량 결론', (tester) async {
    await _open(tester, 'trip');
    await _tap(tester, 'ts_opt_t0_0');
    await _type(tester, 'ts_in_t_short_ir', '0.3');
    final spec = lvInsulation(LvCircuit.upTo500);
    var t = _all(tester);
    expect(t, contains('최소 ${spec.minMOhm.toStringAsFixed(0)} MΩ'));
    expect(t, contains('불합격'));
    expect(find.byKey(const Key('ts_end_e_short_ins')), findsOneWidget);
    // 값을 올리면 결론이 바뀐다.
    await _type(tester, 'ts_in_t_short_ir', '50');
    t = _all(tester);
    expect(t, contains('합격'));
    expect(find.byKey(const Key('ts_end_e_short_other')), findsOneWidget);
    expect(find.byKey(const Key('ts_end_e_short_ins')), findsNothing);
  });

  testWidgets('차단기 트립 → 기동 순간: 정격 22 A에 차단기 20 A면 하한 미달', (tester) async {
    await _open(tester, 'trip');
    await _tap(tester, 'ts_opt_t0_1');
    await _type(tester, 'ts_in_t_start_fla', '22');
    await _type(tester, 'ts_in_t_start_in', '20');
    expect(find.byKey(const Key('ts_end_e_start_small')), findsOneWidget);
    await _type(tester, 'ts_in_t_start_in', '40');
    expect(find.byKey(const Key('ts_end_e_start_ok')), findsOneWidget);
  });

  testWidgets('전동기 → 전압 불평형 큰 경우와 결상', (tester) async {
    await _open(tester, 'motor');
    await _tap(tester, 'ts_opt_m0_0');
    await _type(tester, 'ts_in_m_volt_v1', '380');
    await _type(tester, 'ts_in_m_volt_v2', '380');
    await _type(tester, 'ts_in_m_volt_v3', '0');
    expect(find.byKey(const Key('ts_end_e_m_phase')), findsOneWidget);
    await _type(tester, 'ts_in_m_volt_v3', '372');
    expect(find.byKey(const Key('ts_end_e_m_unb')), findsOneWidget);
    expect(_all(tester), contains('전압 불평형'));
    await _type(tester, 'ts_in_m_volt_v3', '380');
    expect(find.byKey(const Key('ts_end_e_m_body')), findsOneWidget);
  });

  testWidgets('전동기 → 과부하계전기: Y-Δ 델타 안은 정격 ÷ √3', (tester) async {
    await _open(tester, 'motor');
    await _tap(tester, 'ts_opt_m0_2');
    await _type(tester, 'ts_in_m_thr_fla', '30');
    await _type(tester, 'ts_in_m_thr_set', '30');
    await _tap(tester, 'ts_sel_m_thr_method_yd_in');
    final t = _all(tester);
    expect(t, contains('17.32 A'));
    expect(find.byKey(const Key('ts_end_e_thr_start')), findsOneWidget);
    await _type(tester, 'ts_in_m_thr_set', '10');
    expect(find.byKey(const Key('ts_end_e_thr_low')), findsOneWidget);
  });

  testWidgets('지락 보호 TN: Zs 최대는 U₀ ÷ Ia', (tester) async {
    await _open(tester, 'earth');
    await _tap(tester, 'ts_opt_g0_0');
    await _type(tester, 'ts_in_g_tn_in', '20');
    await _type(tester, 'ts_in_g_tn_zs', '1.5');
    final ia = tripCurrentIa(ProtDevice.c, 20)!;
    final zmax = maxLoopImpedance(u0: 220, ia: ia)!;
    final t = _all(tester);
    expect(t, contains('Ia = ${ia.toStringAsFixed(0)} A'));
    expect(t, contains('Zs 최대 = U₀ ÷ Ia = 220 ÷ ${ia.toStringAsFixed(0)} = 1.1 Ω'));
    expect(zmax, closeTo(1.1, 1e-9));
    expect(find.byKey(const Key('ts_end_e_g_fail')), findsOneWidget);
    await _type(tester, 'ts_in_g_tn_zs', '0.5');
    expect(find.byKey(const Key('ts_end_e_g_ok')), findsOneWidget);
  });

  testWidgets('지락 보호 TT: 50 V ÷ IΔn', (tester) async {
    await _open(tester, 'earth');
    await _tap(tester, 'ts_opt_g0_1');
    await _type(tester, 'ts_in_g_tt_ra', '2000');
    expect(_all(tester), contains('1667 Ω'));
    expect(find.byKey(const Key('ts_end_e_tt_fail')), findsOneWidget);
    await _type(tester, 'ts_in_g_tt_ra', '50');
    expect(find.byKey(const Key('ts_end_e_tt_ok')), findsOneWidget);
  });

  testWidgets('흐름 목록: 전동기 전용은 맨 뒤, 범용 흐름이 앞에 있다', (tester) async {
    final ids = troubleshootFlows().map((f) => f.id).toList();
    expect(ids.last, 'motor');
    expect(ids.take(3), ['trip', 'voltage', 'heat']);
    expect(ids.toSet().length, ids.length);
  });

  testWidgets('전압 이상: 220 V 기준 198~242 V, 낮음·높음·정상과 무부하 비교', (tester) async {
    await _open(tester, 'voltage');
    await _type(tester, 'ts_in_v_meas_v', '190');
    expect(_all(tester), contains('198~242 V'));
    expect(find.byKey(const Key('ts_end_e_v_low')), findsOneWidget);
    await _type(tester, 'ts_in_v_meas_v', '250');
    expect(find.byKey(const Key('ts_end_e_v_high')), findsOneWidget);
    await _type(tester, 'ts_in_v_meas_v', '220');
    expect(find.byKey(const Key('ts_end_e_v_ok')), findsOneWidget);
    await _type(tester, 'ts_in_v_meas_vno', '230');
    expect(_all(tester), contains('10 V(4.3 %)'));
    await _tap(tester, 'ts_sel_v_meas_nom_380');
    expect(_all(tester), contains('342~418 V'));
    expect(find.byKey(const Key('ts_end_e_v_low')), findsOneWidget); // 220 V는 380 V 기준으로 낮음
  });

  testWidgets('열화상: NETA 비슷한 부품 ΔT 구간, 직무 고시 기준(5 K 이하 정상), 주위 대비', (tester) async {
    await _open(tester, 'heat');
    await _tap(tester, 'ts_opt_h0_0');
    await _type(tester, 'ts_in_h_sim_dt', '2');
    expect(_all(tester), contains('우선순위 4 (1~3 K)'));
    expect(find.byKey(const Key('ts_end_e_h_act')), findsOneWidget);
    await _type(tester, 'ts_in_h_sim_dt', '10');
    expect(_all(tester), contains('우선순위 3 (4~15 K)'));
    await _type(tester, 'ts_in_h_sim_dt', '20');
    expect(_all(tester), contains('우선순위 1 (15 K 초과)'));
    await _type(tester, 'ts_in_h_sim_dt', '0.5');
    expect(find.byKey(const Key('ts_end_e_h_ok')), findsOneWidget);
    await _tap(tester, 'ts_sel_h_sim_std_gosi');
    await _type(tester, 'ts_in_h_sim_dt', '7');
    expect(_all(tester), contains('요주의(5 K 초과 10 K 미만)'));
    expect(_all(tester), contains('별지 제7호서식'));
    await _type(tester, 'ts_in_h_sim_dt', '3');
    expect(find.byKey(const Key('ts_end_e_h_ok')), findsOneWidget);
    // 고시는 "5 ℃ 이하 정상"이라 딱 5 K는 정상이다.
    await _type(tester, 'ts_in_h_sim_dt', '5');
    expect(_all(tester), contains('정상(5 K 이하)'));
    expect(find.byKey(const Key('ts_end_e_h_ok')), findsOneWidget);
    await _type(tester, 'ts_in_h_sim_dt', '10');
    expect(_all(tester), contains('이상(10 K 이상)'));
    // 주위 대비
    await _tap(tester, 'ts_opt_h0_1');
    await _type(tester, 'ts_in_h_amb_dt', '30');
    expect(_all(tester), contains('우선순위 2 (21~40 K)'));
    await _type(tester, 'ts_in_h_amb_dt', '50');
    expect(_all(tester), contains('우선순위 1 (40 K 초과)'));
  });

  testWidgets('변압기: 사용 중 내압 18 kV 요주의, 25 kV 적합, 온도 상승 70 K 초과', (tester) async {
    await _open(tester, 'transformer');
    await _type(tester, 'ts_in_x_meas_bd', '18');
    expect(_all(tester), contains('15~20 kV 요주의'));
    expect(find.byKey(const Key('ts_end_e_x_bad')), findsOneWidget);
    await _type(tester, 'ts_in_x_meas_bd', '25');
    expect(find.byKey(const Key('ts_end_e_x_ok')), findsOneWidget);
    await _type(tester, 'ts_in_x_meas_rise', '70');
    expect(_all(tester), contains('한계 60 K'));
    expect(find.byKey(const Key('ts_end_e_x_bad')), findsOneWidget);
    await _type(tester, 'ts_in_x_meas_rise', '50');
    await _type(tester, 'ts_in_x_meas_acid', '0.3');
    expect(_all(tester), contains('0.2~0.4 요주의'));
    await _tap(tester, 'ts_sel_x_meas_state_new');
    expect(_all(tester), contains('신유는 30 kV 이상 부적합'));
  });

  testWidgets('역률 콘덴서: −5~+10 %와 세 상 최대÷최소 108 %', (tester) async {
    await _open(tester, 'capacitor');
    await _type(tester, 'ts_in_c_meas_rated', '100');
    // Δ 결선(기본): 선간 값 = 한 상 × 1.5(10-09). 한 상 98·101·105 μF → 선간 147·151.5·157.5.
    await _type(tester, 'ts_in_c_meas_cr', '147');
    await _type(tester, 'ts_in_c_meas_cs', '151.5');
    await _type(tester, 'ts_in_c_meas_ct', '157.5');
    expect(find.byKey(const Key('ts_end_e_c_ok')), findsOneWidget);
    expect(_all(tester), contains('107.1 %'));
    await _type(tester, 'ts_in_c_meas_cr', '135'); // 한 상 90
    expect(find.byKey(const Key('ts_end_e_c_bad')), findsOneWidget);
    expect(_all(tester), contains('−5~+10 %'));
    // 100 kvar 초과는 −5~+5 %: +7 %면 벗어난다.
    await _type(tester, 'ts_in_c_meas_cr', '150');
    await _type(tester, 'ts_in_c_meas_cs', '150');
    await _type(tester, 'ts_in_c_meas_ct', '160.5');
    expect(find.byKey(const Key('ts_end_e_c_ok')), findsOneWidget);
    await _tap(tester, 'ts_sel_c_meas_size_gt100');
    expect(_all(tester), contains('허용 −5~+5 %'));
    expect(find.byKey(const Key('ts_end_e_c_bad')), findsOneWidget);
  });

  testWidgets('조명: 증상 고르면 바로 점검 순서가 나온다', (tester) async {
    await _open(tester, 'lighting');
    await _tap(tester, 'ts_opt_l0_0');
    expect(find.byKey(const Key('ts_end_e_l_single')), findsOneWidget);
    await _tap(tester, 'ts_opt_l0_3');
    expect(find.byKey(const Key('ts_end_e_l_none')), findsOneWidget);
    expect(find.byKey(const Key('ts_end_e_l_single')), findsNothing);
  });

  test("콘덴서: 선간 측정값을 한 상 값으로 바꿔 정격과 비교한다(10-09)", () {
    // 정격 한 상 100 μF. Δ 결선이면 선간 150, Y 결선이면 선간 50이 정상.
    expect(capacitorPhaseFromLineLine(150, wye: false), closeTo(100, 1e-9));
    expect(capacitorPhaseFromLineLine(50, wye: true), closeTo(100, 1e-9));
    final step = capacitorFlow().steps["c_meas"] as WizMeasure;
    final delta = step.judge(
      {"rated": 100, "cr": 150, "cs": 151, "ct": 149},
      {"size": "le100", "conn": "delta"},
    );
    expect(delta.warn, isFalse, reason: delta.lines.join(" / "));
    final wye = step.judge(
      {"rated": 100, "cr": 50, "cs": 50.5, "ct": 49.5},
      {"size": "le100", "conn": "wye"},
    );
    expect(wye.warn, isFalse, reason: wye.lines.join(" / "));
    // 한 상이 20 % 줄면 잡는다.
    final low = step.judge(
      {"rated": 100, "cr": 120, "cs": 150, "ct": 150},
      {"size": "le100", "conn": "delta"},
    );
    expect(low.warn, isTrue);
  });
}

