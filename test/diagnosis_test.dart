// 계산기 → 원인 확인: 한도를 넘거나 불합격이면 [원인 확인]이 나오고, 입력값을 가진 채 원인 후보와 고친 값을 보여 준다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'electric_legacy_defaults.dart';
import 'package:tubing_calculator/src/presentation/electrical/diagnosis_causes.dart';
import 'package:tubing_calculator/src/presentation/electrical/elec_calc.dart';
import 'package:tubing_calculator/src/presentation/electrical/elec_tables.dart';
import 'package:tubing_calculator/src/presentation/electrical/electric_calculator_page.dart';

Future<void> _open(WidgetTester tester, String tab) async {
  tester.view.physicalSize = const Size(800, 10000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: ElectricCalculatorPage()));
  await tester.pumpAndSettle();
  final t = find.byKey(Key(tab));
  await tester.ensureVisible(t);
  await tester.pumpAndSettle();
  await tester.tap(t);
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
  setUp(legacyElectricDefaults);

  test('전압강하 원인: 값은 전압강하 계산 함수와 같다', () {
    final d = voltageDropDiagnosis(
      current: 20,
      lengthM: 150,
      size: 4,
      phase: Phase.three,
      pf: 0.85,
      volts: 380,
      ins: Insulation.pvc70,
      supply: SupplyType.lvOther,
      reservedPct: 0,
      inputs: const [],
    );
    final dv = voltageDrop(
      current: 20,
      lengthM: 150,
      size: 4,
      phase: Phase.three,
      pf: 0.85,
      conductorTempC: 70,
    );
    final pct = dv / 380 * 100;
    expect(d.symptom, contains('${pct.toStringAsFixed(2)} %'));
    // 첫 후보: 전류. 허용 전류 = 20 × 한도 ÷ 현재
    final limit = voltageDropLimit(SupplyType.lvOther, 150);
    expect(
      d.causes.first.effect,
      contains((20 * limit / pct).toStringAsFixed(1)),
    );
    // 굵기 후보는 한도를 만족하는 가장 가는 굵기를 준다.
    final sizeCause = d.causes.firstWhere((c) => c.title.contains('굵기'));
    expect(sizeCause.effect, contains('sq로 올리면'));
    expect(d.causes.last.title, contains('실측'));
  });

  testWidgets('전압강하 탭: 한도 초과면 원인 확인 단추 → 증상·입력값·원인 후보', (tester) async {
    await _open(tester, 'ec_tab_vd');
    await _type(tester, 'ec_vd_i', '20');
    await _type(tester, 'ec_vd_len', '100');
    expect(find.byKey(const Key('ec_sum_vd_diag')), findsNothing, reason: '한도 이내면 단추 없음');
    await _type(tester, 'ec_vd_len', '150');
    expect(find.byKey(const Key('ec_sum_vd_diag')), findsOneWidget);
    await _tap(tester, 'ec_sum_vd_diag');
    expect(find.text('전압강하 원인 확인'), findsOneWidget);
    final t = _all(tester);
    expect(t, contains('초과합니다'));
    expect(t, contains('편도 길이: 150 m'));
    expect(t, contains('전류: 20 A'));
    expect(find.byKey(const Key('dg_cause_0')), findsOneWidget);
    expect(t, contains('원인 후보'));
    // 확인함을 누르면 남은 개수가 줄어든다.
    final before = RegExp(r'남은 것 (\d+)개').firstMatch(_all(tester))!.group(1)!;
    await _tap(tester, 'dg_done_0');
    final after = RegExp(r'남은 것 (\d+)개').firstMatch(_all(tester))!.group(1)!;
    expect(int.parse(after), int.parse(before) - 1);
    await _tap(tester, 'dg_back');
    expect(find.byKey(const Key('ec_vd_result')), findsOneWidget);
  });

  testWidgets('기존 회로 점검 불합격: 차단기 50 A > 허용전류 → 원인 확인에서 차단기 낮추기 제안', (tester) async {
    await _open(tester, 'ec_tab_cable');
    await _tap(tester, 'ec_mode_check');
    await _type(tester, 'ec_ib', '21.85');
    await _type(tester, 'ec_chk_breaker', '50');
    await _tap(tester, 'ec_cable_motor'); // 전동기 끔 → 불합격
    expect(find.byKey(const Key('ec_sum_cable_diag')), findsOneWidget);
    await _tap(tester, 'ec_sum_cable_diag');
    expect(find.text('기존 회로 원인 확인'), findsOneWidget);
    final t = _all(tester);
    expect(t, contains('차단기 In 50 A가 허용전류 IZ 32 A를 초과합니다'));
    expect(t, contains('차단기 정격이 전선 허용전류보다 크다'));
    expect(t, contains('차단기를 30 A로 낮추면'));
    expect(t, contains('로 올리면 IZ'));
  });

  testWidgets('합격이면 원인 확인 단추가 없다', (tester) async {
    await _open(tester, 'ec_tab_cable');
    await _tap(tester, 'ec_mode_check');
    await _type(tester, 'ec_ib', '21.85');
    await _type(tester, 'ec_chk_breaker', '30');
    expect(find.byKey(const Key('ec_sum_cable_diag')), findsNothing);
  });
}
