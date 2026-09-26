// 전기 계산기 계산 — 표 값, 보정, 전압강하, 전선·차단기 고르기.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/electrical/elec_calc.dart';
import 'package:tubing_calculator/src/presentation/electrical/elec_tables.dart';
import 'package:tubing_calculator/src/presentation/electrical/motor_tables.dart';

void main() {
  group('표', () {
    test('B.52.4 PVC 3가닥 C열 2.5mm² 24A, B.52.5 XLPE 3가닥 E 16mm² 100A', () {
      expect(baseAmpacity(2.5, Insulation.pvc70, 3, InstallMethod.c), 24);
      expect(baseAmpacity(16, Insulation.xlpe90, 3, InstallMethod.e), 100);
      expect(baseAmpacity(240, Insulation.pvc70, 2, InstallMethod.a1), 321);
      expect(baseAmpacity(25, Insulation.xlpe90, 3, InstallMethod.b2), 105);
    });
    test('온도 보정: 40°C PVC 0.87·XLPE 0.91, 사이 값은 더운 쪽, 넘으면 null', () {
      expect(tempFactor(40, Insulation.pvc70, ground: false), 0.87);
      expect(tempFactor(40, Insulation.xlpe90, ground: false), 0.91);
      expect(tempFactor(37, Insulation.xlpe90, ground: false), 0.91);
      expect(tempFactor(25, Insulation.xlpe90, ground: true), 0.96);
      expect(tempFactor(65, Insulation.pvc70, ground: false), isNull);
    });
    test('회로 수 보정: 묶음 3회로 0.70, 구멍 트레이 10회로 0.72(12 칸), 관로 4회로 0.70', () {
      expect(groupFactor(3, GroupLayout.bunched), 0.70);
      expect(groupFactor(10, GroupLayout.perforatedTray), 0.72);
      expect(groupFactor(4, GroupLayout.groundDuct), 0.70);
      expect(groupFactor(1, GroupLayout.bunched), 1.0);
    });
    test('전압강하 한도: 저압 기타 5%, 150m면 +0.25%, 300m면 +0.5%까지', () {
      expect(voltageDropLimit(SupplyType.lvOther, 50), 5);
      expect(voltageDropLimit(SupplyType.lvOther, 150), closeTo(5.25, 1e-9));
      expect(voltageDropLimit(SupplyType.lvOther, 300), closeTo(5.5, 1e-9));
    });
    test('보호도체: 10→10, 25→16, 95→50(47.5 위 표준), 240→120', () {
      expect(peConductorSize(10), 10);
      expect(peConductorSize(25), 16);
      expect(peConductorSize(95), 50);
      expect(peConductorSize(240), 120);
    });
  });

  group('계산', () {
    test('부하 전류: 삼상 380V 11kW 효율 0.9 역률 0.85 → 21.8A', () {
      final i = loadCurrent(
        kw: 11,
        volts: 380,
        phase: Phase.three,
        pf: 0.85,
        eff: 0.9,
      );
      expect(i, closeTo(21.85, 0.01));
      expect(loadCurrent(kw: 2.2, volts: 220, phase: Phase.single), 10);
    });
    test('전압강하: 삼상 20A 100m 4mm² 역률 1·20°C ≈ 간이식에 가깝다', () {
      final exact = voltageDrop(
        current: 20,
        lengthM: 100,
        size: 4,
        phase: Phase.three,
        pf: 1,
        conductorTempC: 20,
      );
      final simple = voltageDropSimple(
        current: 20,
        lengthM: 100,
        size: 4,
        phase: Phase.three,
      );
      expect(exact, closeTo(15.97, 0.01)); // √3·20·0.1·4.61
      expect(simple, closeTo(15.4, 0.01));
    });
    test('차단기: 21.8A → 30A, 800A 넘으면 null', () {
      expect(breakerFor(21.8), 30);
      expect(breakerFor(15), 15);
      expect(breakerFor(900), isNull);
    });
    test('전선 고르기: 380V 삼상 30A 차단기, F-CV 트레이(E) 50m → 2.5sq(32A ≥ 30A)', () {
      final c = chooseCable(
        load: 21.85,
        volts: 380,
        phase: Phase.three,
        ins: Insulation.xlpe90,
        method: InstallMethod.e,
        lengthM: 50,
        pf: 0.85,
      );
      expect(c.breaker, 30);
      expect(c.sizeByAmpacity, 2.5);
      expect(c.iz, 32);
    });
    test('전선 고르기: 길면 전압강하가 굵기를 정한다', () {
      final c = chooseCable(
        load: 21.85,
        volts: 380,
        phase: Phase.three,
        ins: Insulation.xlpe90,
        method: InstallMethod.e,
        lengthM: 400,
        pf: 0.85,
      );
      expect(c.sizeByDrop!, greaterThan(c.sizeByAmpacity!));
      expect(c.size, c.sizeByDrop);
      expect(c.dropPct!, lessThanOrEqualTo(c.dropLimitPct));
    });
    test('역률 개선: 100kW 0.8 → 0.95 약 42.1kvar', () {
      expect(capacitorKvar(100, 0.8, 0.95), closeTo(42.13, 0.05));
      expect(capacitorKvar(100, 0.95, 0.9), 0);
    });
  });

  group('제어반 내부 배선(IEC 60204-1)', () {
    test('표 6: B1 1.5sq 13.5A, E 120sq 240A, 0.75sq C 9.8A', () {
      expect(panelBaseAmpacity(1.5, InstallMethod.b1), 13.5);
      expect(panelBaseAmpacity(120, InstallMethod.e), 240);
      expect(panelBaseAmpacity(0.75, InstallMethod.c), 9.8);
      expect(panelBaseAmpacity(1.5, InstallMethod.d1), isNull);
    });
    test('D.1 온도: 40 이하 1.0, 45 0.91, 52 → 55 칸 0.71, 61 → null', () {
      expect(panelTempFactor(35), 1.0);
      expect(panelTempFactor(45), 0.91);
      expect(panelTempFactor(52), 0.71);
      expect(panelTempFactor(61), isNull);
    });
    test('D.2 회로 수: B1 3개 → 4 칸 0.65, E 9개 0.72, 12개는 B.52.17', () {
      expect(panelGroupFactor(3, InstallMethod.b1), 0.65);
      expect(panelGroupFactor(9, InstallMethod.e), 0.72);
      expect(panelGroupFactor(12, InstallMethod.b1), 0.45);
    });
    test('반 안 8A 부하, 덕트(B1), 50°C, 6회로 → 차단기 10A, 2.5sq(18.3×0.82×0.57=8.55 < 10 → 4sq)', () {
      final c = chooseCable(
        load: 8,
        volts: 380,
        phase: Phase.three,
        ins: Insulation.xlpe90, // 표 6은 PVC로 바꿔 셈
        method: InstallMethod.b1,
        lengthM: 5,
        ambientC: 50,
        circuits: 6,
        table: AmpacityTable.panel60204,
      );
      expect(c.breaker, 10);
      expect(c.sizeByAmpacity, 4); // 24×0.82×0.57 = 11.2 ≥ 10
    });
  });

  group('전동기 표', () {
    test('NEC 430.250: 15HP 460V 21A, 230V 42A; 100HP 460V 124A', () {
      expect(necRow(15)!.a460, 21);
      expect(necRow(15)!.a230, 42);
      expect(necRow(100)!.a460, 124);
      expect(necRow(13), isNull);
    });
    test('IE3 380V 예: 11kW 22.2A, 식으로 다시 셈해도 1% 안', () {
      final r = ie3Row(11)!;
      expect(r.a380, 22.2);
      expect(r.a440, 19.2);
      final i = loadCurrent(kw: 11, volts: 380, phase: Phase.three, pf: r.pf, eff: r.eff / 100);
      expect((i - r.a380).abs() / r.a380, lessThan(0.01));
    });
  });
}
