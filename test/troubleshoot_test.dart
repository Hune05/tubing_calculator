// 고장 진단 흐름: 모든 단계가 이어지고, 판정이 앱 안 계산 함수와 같은 값을 쓴다.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/electrical/protection_calc.dart';
import 'package:tubing_calculator/src/presentation/electrical/troubleshoot_flows.dart';
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
    final src = File('lib/src/presentation/electrical/troubleshoot_flows.dart')
        .readAsStringSync();
    final ids = {for (final f in troubleshootFlows()) ...f.steps.keys};
    final used = RegExp(r"'((?:e|t|m|g)_w+)'").allMatches(src).map((m) => m.group(1)!);
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
}
