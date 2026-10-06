// 발전기 용량(PG 방식) 순수 계산과 탭 화면 시험.
// 손계산 근거: PG2 351 kVA는 KIEE 논문(2018) 예제(75kW, β 7.2, C 0.65, X″d 25%, ΔV 20%)와 같은 값이다.
import 'dart:convert';
import 'formula_flat.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/theme/field_view.dart';
import 'package:tubing_calculator/src/presentation/electrical/elec_generator.dart';
import 'package:tubing_calculator/src/presentation/electrical/elec_generator_tab.dart';

GenInput _base({
  double? loadKw = 300,
  double? motorKw = 75,
  double? startPf = 0.31,
  double? genPf = 0.8,
  double? harmonicKva,
  double? harmonicFactor,
  double? volts = 380,
  double? chosenKva,
  double? dvPct = 20,
  double? beta = 7.2,
}) => GenInput(
  loadKw: loadKw,
  demand: 1,
  eff: 0.85,
  pf: 0.8,
  motorKw: motorKw,
  beta: beta,
  startC: 0.65,
  xdPct: 25,
  dvPct: dvPct,
  startPf: startPf,
  genPf: genPf,
  harmonicKva: harmonicKva,
  harmonicFactor: harmonicFactor,
  volts: volts,
  chosenKva: chosenKva,
);

void main() {
  setUpAll(expandFormulaCards);
  group('식 손계산', () {
    test('PG1: 100kW, 수용률 1, 효율 0.85, 역률 0.8 → 100 ÷ 0.68', () {
      expect(genPg1(100, 1, 0.85, 0.8), closeTo(147.0588, 1e-3));
    });

    test('PG1: 수용률 0.7이면 70 ÷ 0.68', () {
      expect(genPg1(100, 0.7, 0.85, 0.8), closeTo(102.941, 1e-3));
    });

    test('PG2: 75×7.2×0.65×0.25×(1−0.2)÷0.2 = 351', () {
      expect(genPg2(75, 7.2, 0.65, 0.25, 0.2), closeTo(351, 1e-9));
    });

    test('PG3: [(300−75)÷0.85 + 75×7.2×0.65×0.31] ÷ 0.8 = 466.895', () {
      // 225 ÷ 0.85 = 264.70588, 351 × 0.31 = 108.81, 합 373.51588, ÷ 0.8
      expect(
        genPg3(300, 75, 0.85, 7.2, 0.65, 0.31, 0.8),
        closeTo(466.8949, 1e-3),
      );
    });

    test('정격전류: 500kVA, 380V → 759.7A', () {
      expect(genRatedCurrent(500, 380), closeTo(759.67, 0.01));
    });
  });

  group('calcGenerator', () {
    test('세 방식 중 최댓값(PG3)과 정격전류', () {
      final r = calcGenerator(_base());
      expect(r.ok, isTrue);
      expect(r.pg1, closeTo(441.176, 1e-3));
      expect(r.pg2, closeTo(351, 1e-9));
      expect(r.pg3, closeTo(466.8949, 1e-3));
      expect(r.required, closeTo(466.8949, 1e-3));
      expect(r.governing, 'PG3');
      expect(r.currentA, closeTo(466894.9 / (1.7320508 * 380), 0.05));
    });

    test('전동기가 없으면 PG1만, 안내 글이 붙는다', () {
      final r = calcGenerator(_base(motorKw: null));
      expect(r.ok, isTrue);
      expect(r.pg2, isNull);
      expect(r.pg3, isNull);
      expect(r.governing, 'PG1');
      expect(r.notes.single, contains('PG2와 PG3'));
    });

    test('기동 역률을 비우면 PG3만 빠지고 안내가 붙는다', () {
      final r = calcGenerator(_base(startPf: null));
      expect(r.pg3, isNull);
      expect(r.pg2, isNotNull);
      expect(r.governing, 'PG1');
      expect(r.notes.single, contains('PG3'));
    });

    test('전동기 기동이 크면 PG2가 최댓값', () {
      final r = calcGenerator(_base(loadKw: 80, startPf: null, genPf: null));
      expect(r.pg1, closeTo(117.647, 1e-3));
      expect(r.pg2, closeTo(351, 1e-9));
      expect(r.governing, 'PG2');
      expect(r.required, closeTo(351, 1e-9));
    });

    test('고조파: PG1 + 50 × 2 = PG1 + 100', () {
      final r = calcGenerator(
        _base(loadKw: 80, motorKw: null, harmonicKva: 50, harmonicFactor: 2),
      );
      expect(r.pg4, closeTo(80 / 0.68 + 100, 1e-6));
      expect(r.governing, 'PG4');
    });

    test('허용 전압강하가 작을수록 PG2가 커진다', () {
      final a = calcGenerator(_base(dvPct: 25)).pg2!;
      final b = calcGenerator(_base(dvPct: 15)).pg2!;
      expect(b, greaterThan(a));
    });

    test('선정 용량 합격/불합격 경계', () {
      final need = calcGenerator(_base()).required!;
      final pass = calcGenerator(_base(chosenKva: need));
      expect(pass.chosenPass, isTrue);
      expect(pass.chosenMarginPct, closeTo(0, 1e-9));
      final fail = calcGenerator(_base(chosenKva: need - 0.5));
      expect(fail.chosenPass, isFalse);
      expect(fail.chosenMarginPct!, lessThan(0));
      final big = calcGenerator(_base(chosenKva: 600));
      expect(big.chosenPass, isTrue);
      expect(big.chosenMarginPct, closeTo((600 / need - 1) * 100, 1e-9));
    });

    test('전압을 비우면 정격전류는 없다', () {
      expect(calcGenerator(_base(volts: null)).currentA, isNull);
    });
  });

  group('입력 확인', () {
    test('부하 합계가 없거나 0 이하', () {
      expect(calcGenerator(_base(loadKw: null)).errors, isNotEmpty);
      expect(calcGenerator(_base(loadKw: 0)).errors, isNotEmpty);
      expect(calcGenerator(_base(loadKw: -5)).errors, isNotEmpty);
    });

    test('효율·역률·수용률 범위', () {
      GenInput g({double eff = 0.85, double pf = 0.8, double demand = 1}) =>
          GenInput(loadKw: 100, demand: demand, eff: eff, pf: pf);
      expect(calcGenerator(g(eff: 0)).errors, isNotEmpty);
      expect(calcGenerator(g(eff: 1.2)).errors, isNotEmpty);
      expect(calcGenerator(g(pf: 0)).errors, isNotEmpty);
      expect(calcGenerator(g(demand: 1.5)).errors, isNotEmpty);
      // 경계: 1.0은 허용
      expect(calcGenerator(g(eff: 1, pf: 1)).ok, isTrue);
    });

    test('전동기를 넣었으면 β·C·X″d·ΔV가 모두 있어야 한다', () {
      final r = calcGenerator(
        const GenInput(loadKw: 100, demand: 1, eff: 0.85, pf: 0.8, motorKw: 30),
      );
      expect(r.ok, isFalse);
      expect(r.errors.length, 4);
    });

    test('ΔV·X″d는 0 초과 100 미만', () {
      expect(calcGenerator(_base(dvPct: 0)).errors, isNotEmpty);
      expect(calcGenerator(_base(dvPct: 100)).errors, isNotEmpty);
      expect(calcGenerator(_base(dvPct: 99.9)).ok, isTrue);
    });

    test('가장 큰 전동기가 부하 합계보다 크면 안 된다', () {
      final r = calcGenerator(_base(loadKw: 50, motorKw: 75));
      expect(r.errors.single, contains('부하 합계보다 큽니다'));
    });

    test('음수 전동기, 고조파 계수 빠짐, 선정 용량 0', () {
      expect(calcGenerator(_base(motorKw: -1)).errors, isNotEmpty);
      expect(
        calcGenerator(_base(harmonicKva: 10)).errors.single,
        contains('가산 계수'),
      );
      expect(calcGenerator(_base(chosenKva: 0)).errors, isNotEmpty);
      expect(calcGenerator(_base(volts: 0)).errors, isNotEmpty);
    });
  });

  group('탭 화면', () {
    Future<void> pumpTab(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(
          home: FieldViewTheme(child: Scaffold(body: ElecGeneratorTab())),
        ),
      );
      await tester.pumpAndSettle();
    }

    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('빈 화면은 안내만 보인다', (tester) async {
      await pumpTab(tester);
      expect(find.text('부하 합계를 넣으면 필요 발전기 용량을 계산합니다'), findsOneWidget);
      expect(find.byKey(const Key('eg_sum')), findsNothing);
    });

    testWidgets('부하만 넣으면 PG1과 안내 문구가 나온다', (tester) async {
      await pumpTab(tester);
      await tester.enterText(find.byKey(const Key('eg_load')), '100');
      await tester.pumpAndSettle();
      expect(find.text('147.1 kVA'), findsOneWidget);
      expect(find.byKey(const Key('eg_sum')), findsOneWidget);
      expect(find.textContaining('필요 147 kVA (PG1)'), findsOneWidget);
      expect(find.textContaining('최종 용량은 제조사 검토로 확정합니다.'), findsOneWidget);
      expect(allFlat(tester), contains(flat('정격전류: 223 A')));
    });

    testWidgets('전동기까지 넣으면 PG2 351이 최댓값이 된다', (tester) async {
      await pumpTab(tester);
      Future<void> put(String k, String v) async =>
          tester.enterText(find.byKey(Key(k)), v);
      await put('eg_load', '80');
      await put('eg_motor', '75');
      await put('eg_beta', '7.2');
      await tester.tap(find.byKey(const Key('eg_start_reactor65')));
      await tester.pump();
      await put('eg_xd', '25');
      await put('eg_dv', '20');
      await tester.pumpAndSettle();
      expect(find.text('351 kVA'), findsOneWidget);
      expect(find.textContaining('PG2 기준'), findsOneWidget);
      expect(find.textContaining('PG3는 기동 역률'), findsOneWidget);
    });

    testWidgets('숫자가 아닌 글은 입력 확인으로 보인다', (tester) async {
      await pumpTab(tester);
      await tester.enterText(find.byKey(const Key('eg_load')), 'abc');
      await tester.pumpAndSettle();
      expect(find.text('입력 확인'), findsWidgets);
      expect(find.textContaining('부하 합계: 숫자가 아닙니다.'), findsOneWidget);
    });

    testWidgets('선정 용량이 모자라면 불합격', (tester) async {
      await pumpTab(tester);
      await tester.enterText(find.byKey(const Key('eg_load')), '100');
      await tester.enterText(find.byKey(const Key('eg_chosen')), '100');
      await tester.pumpAndSettle();
      expect(find.textContaining('불합격'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('eg_chosen')), '200');
      await tester.pumpAndSettle();
      expect(find.textContaining('합격 (여유'), findsOneWidget);
    });

    testWidgets('입력값이 저장되고 다시 열면 돌아온다', (tester) async {
      await pumpTab(tester);
      await tester.enterText(find.byKey(const Key('eg_load')), '123');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      final prefs = await SharedPreferences.getInstance();
      final saved = jsonDecode(prefs.getString('elec_generator_draft_v1')!);
      expect(saved['load'], '123');

      await tester.pumpWidget(const SizedBox());
      await pumpTab(tester);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('eg_load')))
            .controller!
            .text,
        '123',
      );
    });

    testWidgets('풀이 줄: PG별 식과 대입, 가장 큰 값 고르기, 정격전류 식', (tester) async {
      await pumpTab(tester);
      Future<void> put(String k, String v) async =>
          tester.enterText(find.byKey(Key(k)), v);
      await put('eg_load', '80');
      await put('eg_motor', '75');
      await put('eg_beta', '7.2');
      await tester.tap(find.byKey(const Key('eg_start_reactor65')));
      await tester.pump();
      await put('eg_xd', '25');
      await put('eg_dv', '20');
      await tester.pumpAndSettle();
      expect(find.textContaining('① PG1 정상 운전'), findsOneWidget);
      expect(allFlat(tester), contains(flat('② PG2 전동기 기동 전압강하: 351 kVA = 75 × 7.2 × 0.65 × 0.25 × (1 − 0.2) ÷ 0.2')));
      expect(allFlat(tester), contains(flat('⑤ 가장 큰 값을 필요 용량으로 합니다: max(PG1 117.6, PG2 351) = 351 kVA (PG2)')));
      expect(allFlat(tester), contains(flat('정격전류: 533 A = 351 kVA × 1000 ÷ (√3 × 380 V)')));
    });
  });
}
