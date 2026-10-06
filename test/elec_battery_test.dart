// 축전지 용량 순수 계산과 탭 화면 시험.
// 손계산 근거: 강의 자료(오리건 주립대 ESE 471, IEEE 485 예제)의 구간 3 합계 37.91 Ah와 최종 105.11 Ah 계산 순서.
import 'dart:convert';
import 'formula_flat.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/theme/field_view.dart';
import 'package:tubing_calculator/src/presentation/electrical/elec_battery.dart';
import 'package:tubing_calculator/src/presentation/electrical/elec_battery_tab.dart';

/// 강의 자료 예제의 앞 세 단계: 5A 15분, 35A 10분, 15A 75분.
const _osuSteps = [
  BatteryStep(5, 15),
  BatteryStep(35, 10),
  BatteryStep(15, 75),
];
const _osuK = {
  '15': 0.78,
  '25': 0.998,
  '10': 0.699,
  '100': 2.472,
  '85': 2.217,
  '75': 2.048,
};

void main() {
  setUpAll(expandFormulaCards);
  group('시간 열쇠와 필요한 K 시간', () {
    test('battTimeKey', () {
      expect(battTimeKey(25), '25');
      expect(battTimeKey(12.5), '12.5');
      expect(battTimeKey(15.0000001), '15');
      expect(battTimeKey(0.5), '0.5');
    });

    test('세 단계면 여섯 시간이 필요하다', () {
      expect(battNeededTimes(_osuSteps), [10, 15, 25, 75, 85, 100]);
    });

    test('한 단계면 그 시간 하나', () {
      expect(battNeededTimes(const [BatteryStep(100, 30)]), [30]);
    });

    test('길이가 같은 구간은 한 번만 센다', () {
      // 10분, 10분: 시간 10(두 번 나옴)과 20
      expect(battNeededTimes(const [BatteryStep(5, 10), BatteryStep(8, 10)]), [
        10,
        20,
      ]);
    });
  });

  group('SBA S 0601', () {
    test('일정 전류: 100A 30분, K 1.2, L 0.8 → 100×1.2÷0.8 = 150 Ah', () {
      final r = calcBattery(
        const BatteryInput(
          method: BatteryMethod.sba,
          steps: [BatteryStep(100, 30)],
          k: {'30': 1.2},
          maintenance: 0.8,
        ),
      );
      expect(r.ok, isTrue);
      expect(r.base, closeTo(120, 1e-9));
      expect(r.required, closeTo(150, 1e-9));
      expect(r.maxSection, 1);
    });

    test('두 단계: 구간 2가 최댓값 26 Ah → 26 ÷ 0.8 = 32.5 Ah', () {
      // 구간 1: 50×K(10)=25, 구간 2: 50×K(30) + (20−50)×K(20) = 50 − 24 = 26
      final r = calcBattery(
        const BatteryInput(
          method: BatteryMethod.sba,
          steps: [BatteryStep(50, 10), BatteryStep(20, 20)],
          k: {'10': 0.5, '30': 1.0, '20': 0.8},
          maintenance: 0.8,
        ),
      );
      expect(r.sections[0].total, closeTo(25, 1e-9));
      expect(r.sections[1].total, closeTo(26, 1e-9));
      expect(r.maxSection, 2);
      expect(r.required, closeTo(32.5, 1e-9));
      // 표의 항목: 구간 2의 둘째 항은 전류 변화 −30 A, 시간 20분
      final t = r.sections[1].terms[1];
      expect(t.dAmps, closeTo(-30, 1e-9));
      expect(t.minutes, closeTo(20, 1e-9));
      expect(t.ah, closeTo(-24, 1e-9));
    });

    test('두 단계: 구간 1이 최댓값이 되는 경우', () {
      // 구간 2: 50×0.7 − 30×0.6 = 35 − 18 = 17, 구간 1: 25
      final r = calcBattery(
        const BatteryInput(
          method: BatteryMethod.sba,
          steps: [BatteryStep(50, 10), BatteryStep(20, 20)],
          k: {'10': 0.5, '30': 0.7, '20': 0.6},
          maintenance: 0.8,
        ),
      );
      expect(r.maxSection, 1);
      expect(r.base, closeTo(25, 1e-9));
    });

    test('보수율 경계: 1은 되고 0과 1.01은 안 된다', () {
      BatteryResult run(double l) => calcBattery(
        BatteryInput(
          method: BatteryMethod.sba,
          steps: const [BatteryStep(10, 60)],
          k: const {'60': 1.0},
          maintenance: l,
        ),
      );
      expect(run(1).required, closeTo(10, 1e-9));
      expect(run(0).ok, isFalse);
      expect(run(1.01).ok, isFalse);
    });
  });

  group('IEEE 485', () {
    test('강의 자료 예제 구간 1~3 합계 3.9, 25.96, 37.91', () {
      final r = calcBattery(
        const BatteryInput(
          method: BatteryMethod.ieee,
          steps: _osuSteps,
          k: _osuK,
          tempFactor: 1.19,
          marginPct: 15,
          agingFactor: 1.25,
        ),
      );
      expect(r.ok, isTrue);
      expect(r.sections[0].total, closeTo(3.9, 1e-9));
      expect(r.sections[1].total, closeTo(25.96, 1e-9));
      expect(r.sections[2].total, closeTo(37.91, 1e-9));
      expect(r.maxSection, 3);
      // 구간 3의 항: 5×2.472, 30×2.217, −20×2.048
      final t = r.sections[2].terms;
      expect(t[0].ah, closeTo(12.36, 1e-9));
      expect(t[1].ah, closeTo(66.51, 1e-9));
      expect(t[2].ah, closeTo(-40.96, 1e-9));
    });

    test('필요 용량 = 37.91 × 1.19 × 1.15 × 1.25 = 64.85 Ah', () {
      final r = calcBattery(
        const BatteryInput(
          method: BatteryMethod.ieee,
          steps: _osuSteps,
          k: _osuK,
          tempFactor: 1.19,
          marginPct: 15,
          agingFactor: 1.25,
        ),
      );
      expect(r.required, closeTo(37.91 * 1.19 * 1.15 * 1.25, 1e-9));
      expect(r.required, closeTo(64.85, 0.01));
    });

    test('강의 자료의 61.445 Ah 최댓값에 같은 순서를 쓰면 105.11 Ah', () {
      // 61.445 × 1.19 × 1.15 ÷ 0.8 = 105.11 (강의 자료의 최종 값)
      expect(61.445 * 1.19 * 1.15 / 0.8, closeTo(105.11, 0.01));
      final r = calcBattery(
        const BatteryInput(
          method: BatteryMethod.ieee,
          steps: [BatteryStep(61.445, 60)],
          k: {'60': 1.0},
          tempFactor: 1.19,
          marginPct: 15,
          agingFactor: 1.25,
        ),
      );
      expect(r.required, closeTo(105.11, 0.01));
    });

    test('온도 보정 1, 여유 0, 노화 1이면 구간 최댓값과 같다', () {
      final r = calcBattery(
        const BatteryInput(
          method: BatteryMethod.ieee,
          steps: [BatteryStep(10, 60)],
          k: {'60': 1.0},
          tempFactor: 1,
          marginPct: 0,
          agingFactor: 1,
        ),
      );
      expect(r.required, closeTo(10, 1e-9));
    });

    test('온도 보정계수·설계 여유·노화계수가 빠지면 입력 확인', () {
      final r = calcBattery(
        const BatteryInput(
          method: BatteryMethod.ieee,
          steps: [BatteryStep(10, 60)],
          k: {'60': 1.0},
        ),
      );
      expect(r.ok, isFalse);
      expect(r.errors.length, 3);
      final neg = calcBattery(
        const BatteryInput(
          method: BatteryMethod.ieee,
          steps: [BatteryStep(10, 60)],
          k: {'60': 1.0},
          tempFactor: 1,
          marginPct: -1,
          agingFactor: 1,
        ),
      );
      expect(neg.errors.single, contains('설계 여유'));
    });
  });

  group('입력 확인', () {
    BatteryResult sba(List<BatteryStep> steps, Map<String, double> k) =>
        calcBattery(
          BatteryInput(
            method: BatteryMethod.sba,
            steps: steps,
            k: k,
            maintenance: 0.8,
          ),
        );

    test('단계가 없다', () {
      expect(sba(const [], const {}).errors, isNotEmpty);
    });

    test('전류·시간이 0 이하', () {
      expect(sba(const [BatteryStep(0, 10)], const {}).errors, isNotEmpty);
      expect(sba(const [BatteryStep(10, 0)], const {}).errors, isNotEmpty);
      expect(sba(const [BatteryStep(-1, 10)], const {}).errors, isNotEmpty);
    });

    test('K가 빠진 시간을 알려 준다', () {
      final r = sba(
        const [BatteryStep(50, 10), BatteryStep(20, 20)],
        {'10': 0.5},
      );
      expect(r.ok, isFalse);
      expect(r.errors.single, contains('20, 30'));
    });

    test('K가 0 이하면 안 된다', () {
      expect(sba(const [BatteryStep(50, 10)], {'10': 0}).ok, isFalse);
    });

    test('전류가 줄어 구간 2가 구간 1보다 작으면 구간 1이 최댓값', () {
      // 구간 1: 50×1.0 = 50, 구간 2: 50×K(20분) + (10−50)×K(10분) = 60 − 40 = 20
      final r = sba(
        const [BatteryStep(50, 10), BatteryStep(10, 10)],
        {'10': 1.0, '20': 1.2},
      );
      expect(r.ok, isTrue);
      expect(r.maxSection, 1);
      expect(r.sections[1].total, closeTo(20, 1e-9));
    });

    test('선정 용량이 0 이하', () {
      final r = calcBattery(
        const BatteryInput(
          method: BatteryMethod.sba,
          steps: [BatteryStep(10, 60)],
          k: {'60': 1.0},
          maintenance: 0.8,
          chosenAh: 0,
        ),
      );
      expect(r.errors.single, contains('선정 용량'));
    });
  });

  group('선정 용량과 셀', () {
    BatteryInput input({
      double? chosen,
      double? bus,
      double? nominal,
      double? cellMin,
      double? cells,
      double? minBus,
      double? lineDrop,
    }) => BatteryInput(
      method: BatteryMethod.sba,
      steps: const [BatteryStep(100, 30)],
      k: const {'30': 1.2},
      maintenance: 0.8,
      chosenAh: chosen,
      busVolts: bus,
      cellNominal: nominal,
      cellMin: cellMin,
      cells: cells,
      minBusVolts: minBus,
      lineDropVolts: lineDrop,
    );

    test('선정 용량 경계: 150은 합격, 149.9는 불합격', () {
      final ok = calcBattery(input(chosen: 150));
      expect(ok.chosenPass, isTrue);
      expect(ok.chosenMarginPct, closeTo(0, 1e-9));
      final no = calcBattery(input(chosen: 149.9));
      expect(no.chosenPass, isFalse);
      final more = calcBattery(input(chosen: 200));
      expect(more.chosenMarginPct, closeTo(33.3333, 1e-3));
    });

    test('셀 수 계산값: 125V ÷ 2.0V = 62.5', () {
      final r = calcBattery(input(bus: 125, nominal: 2.0));
      expect(r.cellRatio, closeTo(62.5, 1e-9));
      expect(r.endVolts, isNull);
    });

    test('방전 종지 전압: 60셀 × 1.75V = 105V, 최저 허용 105V는 합격, 106V는 불합격', () {
      final pass = calcBattery(input(cells: 60, cellMin: 1.75, minBus: 105));
      expect(pass.endVolts, closeTo(105, 1e-9));
      expect(pass.endVoltsPass, isTrue);
      final fail = calcBattery(input(cells: 60, cellMin: 1.75, minBus: 106));
      expect(fail.endVoltsPass, isFalse);
      final none = calcBattery(input(cells: 60, cellMin: 1.75));
      expect(none.endVoltsPass, isNull);
      expect(none.cellMinNeeded, isNull);
      // 선로 전압강하를 비우면 0으로 본다.
      expect(pass.loadEndVolts, closeTo(105, 1e-9));
      expect(pass.cellMinNeeded, closeTo(1.75, 1e-12));
    });

    test('SBA S 0601 4.3: 선로 전압강하 2V를 빼면 60셀 × 1.75V − 2V = 103V, Vd = (Va + Vc) ÷ n', () {
      // 최저 허용 103V: 103 ≥ 103 합격, Vd = (103 + 2) ÷ 60 = 1.75V.
      final ok = calcBattery(input(cells: 60, cellMin: 1.75, minBus: 103, lineDrop: 2));
      expect(ok.endVolts, closeTo(105, 1e-9));
      expect(ok.loadEndVolts, closeTo(103, 1e-9));
      expect(ok.endVoltsPass, isTrue);
      expect(ok.cellMinNeeded, closeTo(1.75, 1e-12));
      // 최저 허용 105V: 103 < 105 불합격, Vd = (105 + 2) ÷ 60 = 1.7833V > 1.75V.
      final no = calcBattery(input(cells: 60, cellMin: 1.75, minBus: 105, lineDrop: 2));
      expect(no.endVoltsPass, isFalse);
      expect(no.cellMinNeeded, closeTo(107 / 60, 1e-12));
      expect(no.cellMinNeeded! > 1.75, isTrue);
      // 음수는 입력 확인.
      final bad = calcBattery(input(cells: 60, cellMin: 1.75, lineDrop: -1));
      expect(bad.ok, isFalse);
      expect(bad.errors.single, contains('선로 전압강하'));
    });

    test('셀 수가 정수가 아니거나 0이면 입력 확인', () {
      expect(calcBattery(input(cells: 60.5, cellMin: 1.75)).ok, isFalse);
      expect(calcBattery(input(cells: 0, cellMin: 1.75)).ok, isFalse);
      expect(calcBattery(input(bus: 0)).ok, isFalse);
      expect(calcBattery(input(nominal: -2)).ok, isFalse);
    });

    test('최저 모선 전압만 넣고 셀당 최저 전압이 없으면 알려 준다', () {
      final r = calcBattery(input(cells: 60, minBus: 105));
      expect(r.errors.single, contains('셀당 최저 전압'));
    });
  });

  group('탭 화면', () {
    Future<void> pumpTab(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(
          home: FieldViewTheme(child: Scaffold(body: ElecBatteryTab())),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> put(WidgetTester tester, String k, String v) async {
      await tester.enterText(find.byKey(Key(k)), v);
      await tester.pump();
    }

    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('빈 화면은 안내만 보인다', (tester) async {
      await pumpTab(tester);
      expect(find.textContaining('방전 단계의 전류와 시간, K 값을 넣으면'), findsOneWidget);
      expect(find.byKey(const Key('eb_sum')), findsNothing);
      expect(find.byKey(const Key('eb_k_30')), findsNothing);
    });

    testWidgets('100A 30분에 K 1.2를 넣으면 150 Ah', (tester) async {
      await pumpTab(tester);
      await put(tester, 'eb_a_0', '100');
      await put(tester, 'eb_m_0', '30');
      expect(find.byKey(const Key('eb_k_30')), findsOneWidget);
      // K가 없으면 입력 확인으로 어느 시간이 빠졌는지 보인다.
      expect(find.textContaining('K 값이 필요한 시간(분): 30'), findsOneWidget);
      await put(tester, 'eb_k_30', '1.2');
      await tester.pumpAndSettle();
      expect(find.text('150 Ah'), findsOneWidget);
      expect(find.textContaining('필요 150 Ah (SBA S 0601)'), findsOneWidget);
      expect(find.byKey(const Key('eb_sections')), findsOneWidget);
      expect(find.textContaining('구간 합계 120 Ah'), findsOneWidget);
    });

    testWidgets('IEEE 485로 바꾸면 보정 칸이 나오고 값이 없으면 입력 확인', (tester) async {
      await pumpTab(tester);
      await put(tester, 'eb_a_0', '100');
      await put(tester, 'eb_m_0', '30');
      await put(tester, 'eb_k_30', '1.2');
      await tester.tap(find.byKey(const Key('eb_method_ieee')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('eb_maint')), findsNothing);
      expect(find.byKey(const Key('eb_temp')), findsOneWidget);
      expect(find.textContaining('온도 보정계수를 0보다 크게'), findsOneWidget);
      await put(tester, 'eb_temp', '1.19');
      await put(tester, 'eb_margin', '15');
      await tester.pumpAndSettle();
      // 120 × 1.19 × 1.15 × 1.25 = 205.3
      expect(find.text('205.3 Ah'), findsOneWidget);
    });

    testWidgets('단계 추가와 지우기, 새 K 칸', (tester) async {
      await pumpTab(tester);
      await put(tester, 'eb_a_0', '50');
      await put(tester, 'eb_m_0', '10');
      await tester.tap(find.byKey(const Key('eb_add')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('eb_a_1')), findsOneWidget);
      await put(tester, 'eb_a_1', '20');
      await put(tester, 'eb_m_1', '20');
      expect(find.byKey(const Key('eb_k_10')), findsOneWidget);
      expect(find.byKey(const Key('eb_k_20')), findsOneWidget);
      expect(find.byKey(const Key('eb_k_30')), findsOneWidget);
      await put(tester, 'eb_k_10', '0.5');
      await put(tester, 'eb_k_20', '0.8');
      await put(tester, 'eb_k_30', '1');
      await tester.pumpAndSettle();
      expect(find.text('32.5 Ah'), findsOneWidget);
      expect(find.textContaining('구간 2 (1~2단계), 최댓값'), findsOneWidget);
      await tester.tap(find.byKey(const Key('eb_del')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('eb_a_1')), findsNothing);
      expect(find.byKey(const Key('eb_del')), findsNothing);
    });

    testWidgets('숫자가 아닌 글은 입력 확인으로 보인다', (tester) async {
      await pumpTab(tester);
      await put(tester, 'eb_a_0', 'abc');
      await put(tester, 'eb_m_0', '30');
      await tester.pumpAndSettle();
      expect(find.text('입력 확인'), findsWidgets);
      expect(find.textContaining('1단계 전류: 숫자가 아닙니다.'), findsOneWidget);
    });

    testWidgets('한쪽만 넣은 단계는 입력 확인', (tester) async {
      await pumpTab(tester);
      await put(tester, 'eb_a_0', '100');
      await tester.pumpAndSettle();
      expect(find.textContaining('전류(A)와 시간(분)을 모두 넣으십시오'), findsOneWidget);
    });

    testWidgets('선정 용량과 셀 전압 합격/불합격', (tester) async {
      await pumpTab(tester);
      await put(tester, 'eb_a_0', '100');
      await put(tester, 'eb_m_0', '30');
      await put(tester, 'eb_k_30', '1.2');
      await put(tester, 'eb_chosen', '100');
      await tester.pumpAndSettle();
      expect(find.textContaining('불합격 (필요 150 Ah에 33.3% 부족)'), findsOneWidget);
      await put(tester, 'eb_chosen', '200');
      await put(tester, 'eb_bus', '125');
      await tester.tap(find.byKey(const Key('eb_cell_lead')));
      await put(tester, 'eb_cellmin', '1.75');
      await put(tester, 'eb_cells', '60');
      await put(tester, 'eb_minbus', '106');
      await tester.pumpAndSettle();
      expect(find.textContaining('합격 (여유 33.3%)'), findsOneWidget);
      expect(allFlat(tester), contains(flat('셀 수 계산값: 125 V ÷ 2 V = 62.5셀')));
      expect(allFlat(tester), contains(flat('105 V, 부하 최저 허용 106 V 미만이라 불합격')));
      await put(tester, 'eb_minbus', '105');
      await tester.pumpAndSettle();
      expect(find.textContaining('105 V 이상이라 합격'), findsOneWidget);
      expect(allFlat(tester), contains(flat('⑤ 방전 종지 모선 전압 = 셀 수 × 셀당 최저 전압 = 60셀 × 1.75 V = 105 V')));
      // 선로 전압강하 2V를 넣으면 부하 쪽 103V로 불합격, Vd 식이 보인다.
      await put(tester, 'eb_linedrop', '2');
      await tester.pumpAndSettle();
      expect(
        allFlat(tester),
        contains(flat('⑤ 방전 종지 부하 쪽 전압 = 셀 수 × 셀당 최저 전압 − 선로 전압강하 = 60셀 × 1.75 V − 2 V = 103 V, 부하 최저 허용 105 V 미만이라 불합격')),
      );
      expect(allFlat(tester), contains(flat('(105 + 2) ÷ 60 = 1.783 V 이상이어야 합니다.')));
    });

    testWidgets('입력값과 K 값이 저장되고 다시 열면 돌아온다', (tester) async {
      await pumpTab(tester);
      await put(tester, 'eb_a_0', '100');
      await put(tester, 'eb_m_0', '30');
      await put(tester, 'eb_k_30', '1.2');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      final prefs = await SharedPreferences.getInstance();
      final saved = jsonDecode(prefs.getString('elec_battery_draft_v1')!);
      expect(saved['steps'], [
        ['100', '30'],
      ]);
      expect(saved['k']['30'], '1.2');

      await tester.pumpWidget(const SizedBox());
      await pumpTab(tester);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('eb_a_0')))
            .controller!
            .text,
        '100',
      );
      expect(find.text('150 Ah'), findsOneWidget);
    });

    testWidgets('풀이 줄: 구간 합 식과 대입, 보수율 나누기', (tester) async {
      await pumpTab(tester);
      await put(tester, 'eb_a_0', '50');
      await put(tester, 'eb_m_0', '10');
      await tester.tap(find.byKey(const Key('eb_add')));
      await tester.pumpAndSettle();
      await put(tester, 'eb_a_1', '20');
      await put(tester, 'eb_m_1', '20');
      await put(tester, 'eb_k_10', '0.5');
      await put(tester, 'eb_k_20', '0.8');
      await put(tester, 'eb_k_30', '1');
      await tester.pumpAndSettle();
      expect(allFlat(tester), contains(flat('① 구간별 용량 = Σ (전류 변화 × K): 구간 1 25 Ah, 구간 2 26 Ah')));
      expect(allFlat(tester), contains(flat('② 구간 용량 최댓값: 구간 2 = 50 × 1 + (-30) × 0.8 = 26 Ah')));
      expect(allFlat(tester), contains(flat('③ 필요 용량 = 구간 최댓값 ÷ 보수율')));
    });
  });
}
