// 분전반·조명 계산 계산: 손으로 푼 값과 맞춘다.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/electrical/elec_calc.dart';
import 'package:tubing_calculator/src/presentation/electrical/panel_calc.dart';

void main() {
  branchGroup();
  group('조명 광속법', () {
    test('실지수: 10 × 5 m, 높이 2.5 m → 1.33', () {
      expect(roomIndex(x: 10, y: 5, h: 2.5)!, closeTo(50 / (2.5 * 15), 1e-9));
    });
    test('500 lx, 50 m², 3000 lm, U 0.6, M 0.8 → 17.36대 → 18대, 실제 518.4 lx', () {
      final r = lighting(
        lux: 500,
        areaM2: 50,
        lumens: 3000,
        u: 0.6,
        m: 0.8,
        x: 10,
        y: 5,
        wattsEach: 36,
      )!;
      expect(r.exact, closeTo(500 * 50 / (3000 * 0.6 * 0.8), 1e-9));
      expect(r.count, 18);
      expect(r.actualLux, closeTo(18 * 3000 * 0.6 * 0.8 / 50, 1e-9));
      expect(r.totalWatts, 18 * 36);
      expect(r.cols * r.rows, greaterThanOrEqualTo(18));
      // 가로가 세로의 2배인 방: 열이 행보다 많다.
      expect(r.cols, greaterThan(r.rows));
      expect(r.spacingX, closeTo(10 / r.cols, 1e-9));
    });
    test('잘못된 값은 계산하지 않는다', () {
      expect(lighting(lux: 500, areaM2: 50, lumens: 3000, u: 1.2, m: 0.8), isNull);
      expect(lighting(lux: 500, areaM2: 0, lumens: 3000, u: 0.6, m: 0.8), isNull);
      expect(lighting(lux: 500, areaM2: 50, lumens: 3000, u: 0.6, m: 0), isNull);
    });
  });

  group('분전반 상 평형', () {
    const c = [
      PanelCircuit(name: 'a', va: 3000, phase: PanelPhase.r),
      PanelCircuit(name: 'b', va: 1000, phase: PanelPhase.s),
      PanelCircuit(name: 'c', va: 2000, phase: PanelPhase.t),
    ];
    test('R 3000, S 1000, T 2000 VA → 불평형률 100 %, 중성선 7.87 A', () {
      final r = panelBalance(c, phaseVolts: 220)!;
      expect(r.totalVa, 6000);
      expect(r.unbalancePct, closeTo(100, 1e-9));
      expect(r.maxPhase, PanelPhase.r);
      expect(r.minPhase, PanelPhase.s);
      final a = [3000 / 220, 1000 / 220, 2000 / 220];
      final inSq = a[0] * a[0] + a[1] * a[1] + a[2] * a[2] - a[0] * a[1] - a[1] * a[2] - a[2] * a[0];
      expect(r.neutralAmps, closeTo(math.sqrt(inSq), 1e-9));
      expect(r.neutralAmps, closeTo(7.873, 1e-3));
    });
    test('세 상이 같으면 불평형 0, 중성선 0', () {
      final r = panelBalance(const [
        PanelCircuit(name: 'a', va: 1000, phase: PanelPhase.r),
        PanelCircuit(name: 'b', va: 1000, phase: PanelPhase.s),
        PanelCircuit(name: 'c', va: 1000, phase: PanelPhase.t),
      ], phaseVolts: 220)!;
      expect(r.unbalancePct, closeTo(0, 1e-9));
      expect(r.neutralAmps, closeTo(0, 1e-9));
    });
    test('삼상 부하는 세 상에 똑같이 나뉜다', () {
      final r = panelBalance(const [
        PanelCircuit(name: '모터', va: 9000, phase: PanelPhase.r, three: true),
      ], phaseVolts: 220)!;
      expect(r.phaseVa, [3000, 3000, 3000]);
      expect(r.unbalancePct, closeTo(0, 1e-9));
    });
    test('자동 배정은 불평형을 줄이고 합계는 그대로다', () {
      const bad = [
        PanelCircuit(name: '1', va: 3000, phase: PanelPhase.r),
        PanelCircuit(name: '2', va: 2000, phase: PanelPhase.r),
        PanelCircuit(name: '3', va: 1000, phase: PanelPhase.r),
        PanelCircuit(name: '4', va: 1000, phase: PanelPhase.r),
        PanelCircuit(name: '5', va: 1500, phase: PanelPhase.r),
      ];
      final before = panelBalance(bad, phaseVolts: 220)!;
      final after = panelBalance(autoBalance(bad), phaseVolts: 220)!;
      expect(after.totalVa, before.totalVa);
      expect(after.unbalancePct, lessThan(before.unbalancePct));
      expect(after.unbalancePct, lessThan(30));
      // 이름·용량은 그대로
      expect(autoBalance(bad).map((e) => e.name), ['1', '2', '3', '4', '5']);
    });
    test('빈 목록·음수는 계산하지 않는다', () {
      expect(panelBalance(const [], phaseVolts: 220), isNull);
      expect(
        panelBalance(const [PanelCircuit(name: 'x', va: -1, phase: PanelPhase.r)], phaseVolts: 220),
        isNull,
      );
    });
  });

  group('여러 부하 간선 전압강하', () {
    test('끝에 한 점만 있으면 전체 길이로 한 번에 계산한 값과 같다', () {
      final r = feederDrop(
        segments: const [
          FeederSegment(lengthM: 40, loadAmps: 0),
          FeederSegment(lengthM: 60, loadAmps: 20),
        ],
        size: 6,
        phase: Phase.single,
        volts: 220,
      )!;
      final one = voltageDrop(current: 20, lengthM: 100, size: 6, phase: Phase.single);
      expect(r.totalDropV, closeTo(one, 1e-9));
      expect(r.totalDropPct, closeTo(one / 220 * 100, 1e-9));
    });
    test('구간 전류는 뒤쪽 부하의 합이고, 누적은 구간 합이다', () {
      final r = feederDrop(
        segments: const [
          FeederSegment(lengthM: 30, loadAmps: 5),
          FeederSegment(lengthM: 30, loadAmps: 10),
          FeederSegment(lengthM: 30, loadAmps: 15),
        ],
        size: 4,
        phase: Phase.three,
        volts: 380,
        pf: 0.9,
      )!;
      expect(r.segCurrents, [30, 25, 15]);
      expect(r.totalAmps, 30);
      final s0 = voltageDrop(current: 30, lengthM: 30, size: 4, phase: Phase.three, pf: 0.9);
      final s1 = voltageDrop(current: 25, lengthM: 30, size: 4, phase: Phase.three, pf: 0.9);
      final s2 = voltageDrop(current: 15, lengthM: 30, size: 4, phase: Phase.three, pf: 0.9);
      expect(r.segDropV[0], closeTo(s0, 1e-9));
      expect(r.cumDropV.last, closeTo(s0 + s1 + s2, 1e-9));
      expect(r.cumDropV, orderedEquals([...r.cumDropV]..sort()));
      // 같은 부하를 전부 끝에 몰아 두는 것보다 작다.
      final lumped = voltageDrop(current: 30, lengthM: 90, size: 4, phase: Phase.three, pf: 0.9);
      expect(r.totalDropV, lessThan(lumped));
    });
    test('직류는 저항만으로 계산한다', () {
      final r = feederDrop(
        segments: const [FeederSegment(lengthM: 50, loadAmps: 10)],
        size: 10,
        phase: Phase.dc,
        volts: 125,
      )!;
      expect(r.totalDropV, closeTo(voltageDrop(current: 10, lengthM: 50, size: 10, phase: Phase.dc), 1e-9));
    });
    test('빈 구간·음수는 계산하지 않는다', () {
      expect(feederDrop(segments: const [], size: 4, phase: Phase.single, volts: 220), isNull);
      expect(
        feederDrop(
          segments: const [FeederSegment(lengthM: -1, loadAmps: 5)],
          size: 4,
          phase: Phase.single,
          volts: 220,
        ),
        isNull,
      );
    });
  });
}

void branchGroup() {
  group('분기회로 수', () {
    test('사무실 30 VA/m², 200 m², 220 V 20 A → 6000 VA ÷ 4400 VA = 1.36 → 2회로', () {
      final r = branchCircuits(
        areaM2: 200,
        densityVaPerM2: 30,
        volts: 220,
        branchAmps: 20,
      )!;
      expect(r.totalVa, 6000);
      expect(r.perCircuitVa, 4400);
      expect(r.exact, closeTo(6000 / 4400, 1e-9));
      expect(r.count, 2);
    });
    test('가산부하와 이용률 80 %를 반영한다', () {
      final r = branchCircuits(
        areaM2: 100,
        densityVaPerM2: 40,
        extraVa: 1000,
        volts: 110,
        branchAmps: 15,
        utilization: 0.8,
      )!;
      expect(r.totalVa, 5000);
      expect(r.perCircuitVa, closeTo(110 * 15 * 0.8, 1e-9));
      expect(r.count, (5000 / 1320).ceil());
    });
    test('딱 나누어떨어지면 올림하지 않는다', () {
      final r = branchCircuits(areaM2: 100, densityVaPerM2: 44, volts: 220, branchAmps: 20)!;
      expect(r.exact, closeTo(1, 1e-9));
      expect(r.count, 1);
    });
    test('잘못된 값은 계산하지 않는다', () {
      expect(branchCircuits(areaM2: 0, densityVaPerM2: 0, volts: 220, branchAmps: 20), isNull);
      expect(branchCircuits(areaM2: 10, densityVaPerM2: 30, volts: 0, branchAmps: 20), isNull);
      expect(branchCircuits(areaM2: 10, densityVaPerM2: 30, volts: 220, branchAmps: 20, utilization: 1.5), isNull);
    });
  });
}
