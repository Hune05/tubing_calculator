// 전동기 필수 공식: 손으로 푼 값과 맞춘다.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/electrical/motor_formula.dart';

void main() {
  group('속도·슬립', () {
    test('동기속도 120 f ÷ P: 60 Hz 4극 1800, 50 Hz 6극 1000, 60 Hz 2극 3600', () {
      expect(motorSyncRpm(60, 4), 1800);
      expect(motorSyncRpm(50, 6), 1000);
      expect(motorSyncRpm(60, 2), 3600);
    });
    test('극수는 2 이상 짝수만', () {
      expect(motorSyncRpm(60, 3), isNull);
      expect(motorSyncRpm(60, 0), isNull);
      expect(motorSyncRpm(0, 4), isNull);
    });
    test('슬립: 1800 → 1750 rpm = 2.78 %, 회전수·회전자 주파수', () {
      expect(motorSlip(1800, 1750)!, closeTo(50 / 1800, 1e-12));
      expect(motorSlip(1800, 1800), 0);
      expect(motorRpmFromSlip(1800, 0.03), closeTo(1746, 1e-9));
      expect(rotorHz(60, 0.03), closeTo(1.8, 1e-12));
    });
  });

  group('전류·효율', () {
    test('11 kW, 380 V, 효율 90 %, 역률 85 % 삼상 → 21.85 A, 입력 12.22 kW', () {
      final r = motorElectrical(kw: 11, volts: 380, eff: 0.9, pf: 0.85, three: true)!;
      expect(r.current, closeTo(11000 / (math.sqrt(3) * 380 * 0.85 * 0.9), 1e-9));
      expect(r.current, closeTo(21.85, 0.01));
      expect(r.inputKw, closeTo(11 / 0.9, 1e-12));
      expect(r.apparentKva, closeTo(11 / 0.9 / 0.85, 1e-12));
      expect(r.lossKw, closeTo(11 / 0.9 - 11, 1e-12));
    });
    test('단상은 √3을 쓰지 않는다', () {
      final r = motorElectrical(kw: 2.2, volts: 220, eff: 0.8, pf: 0.8, three: false)!;
      expect(r.current, closeTo(2200 / (220 * 0.8 * 0.8), 1e-9));
    });
    test('범위를 벗어난 값은 null', () {
      expect(motorElectrical(kw: 11, volts: 380, eff: 1.2, pf: 0.85, three: true), isNull);
      expect(motorElectrical(kw: 0, volts: 380, eff: 0.9, pf: 0.85, three: true), isNull);
      expect(motorElectrical(kw: 11, volts: 380, eff: 0.9, pf: 0, three: true), isNull);
    });
  });

  group('토크·출력', () {
    test('11 kW 1750 rpm → 60.0 N·m (= 9549.3 × 11 ÷ 1750), 6.12 kgf·m', () {
      final t = motorTorqueNm(11, 1750)!;
      expect(t, closeTo(9549.3 * 11 / 1750, 0.01));
      expect(t, closeTo(60.02, 0.01));
      expect(nmToKgfM(t), closeTo(6.12, 0.01));
    });
    test('토크 → 출력은 되돌림', () {
      final t = motorTorqueNm(7.5, 3450)!;
      expect(motorPowerKw(t, 3450)!, closeTo(7.5, 1e-9));
    });
    test('0 이하는 null', () {
      expect(motorTorqueNm(11, 0), isNull);
      expect(motorPowerKw(-1, 1750), isNull);
    });
  });

  group('기동 방식', () {
    test('직입 22 A × 6배 = 132 A, Y-Δ는 1/3 = 44 A, 토크 1/3', () {
      final d = motorStart(ratedAmps: 22, multiple: 6, kind: StartKind.direct)!;
      expect(d.lineAmps, 132);
      expect(d.torqueRatio, 1);
      final y = motorStart(ratedAmps: 22, multiple: 6, kind: StartKind.starDelta)!;
      expect(y.lineAmps, closeTo(44, 1e-9));
      expect(y.torqueRatio, closeTo(1 / 3, 1e-12));
    });
    test('기동보상기 65 %: 전원 쪽 전류 0.4225배, 토크 0.4225배', () {
      final r = motorStart(ratedAmps: 22, multiple: 6, kind: StartKind.autoTransformer, tap: 0.65)!;
      expect(r.lineAmps, closeTo(132 * 0.4225, 1e-9));
      expect(r.torqueRatio, closeTo(0.4225, 1e-12));
    });
    test('리액터 65 %: 전류 0.65배, 토크 0.4225배', () {
      final r = motorStart(ratedAmps: 22, multiple: 6, kind: StartKind.reactor, tap: 0.65)!;
      expect(r.lineAmps, closeTo(132 * 0.65, 1e-9));
      expect(r.currentRatio, 0.65);
      expect(r.torqueRatio, closeTo(0.4225, 1e-12));
    });
    test('보상기·리액터는 탭이 0~1 사이여야 한다', () {
      expect(motorStart(ratedAmps: 22, multiple: 6, kind: StartKind.reactor, tap: 1), isNull);
      expect(motorStart(ratedAmps: 22, multiple: 6, kind: StartKind.autoTransformer, tap: 0), isNull);
      expect(motorStart(ratedAmps: 0, multiple: 6, kind: StartKind.direct), isNull);
    });
  });

  group('부하율', () {
    test('18 A / 정격 22 A → 81.8 %, 입력 9.48 kW, 효율 88 %면 출력 8.34 kW', () {
      final r = motorLoad(measuredAmps: 18, ratedAmps: 22, volts: 380, pf: 0.8, three: true, eff: 0.88)!;
      expect(r.loadPct, closeTo(18 / 22 * 100, 1e-9));
      expect(r.inputKw, closeTo(math.sqrt(3) * 380 * 18 * 0.8 / 1000, 1e-9));
      expect(r.inputKw, closeTo(9.478, 0.001));
      expect(r.outputKw!, closeTo(9.478 * 0.88, 0.002));
    });
    test('효율을 안 주면 출력은 없다', () {
      final r = motorLoad(measuredAmps: 18, ratedAmps: 22, volts: 380, pf: 0.8, three: true)!;
      expect(r.outputKw, isNull);
    });
  });
}
