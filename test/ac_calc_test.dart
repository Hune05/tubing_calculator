// 교류 역산·임피던스·케이블 온도·손실·변압기·콘덴서 전압 환산: 손으로 푼 값과 맞춘다.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/electrical/ac_calc.dart';

void main() {
  group('역률·전압 구하기', () {
    test('역률 = kW ÷ kVA: 80 kW ÷ 100 kVA = 0.8, 1을 넘으면 null', () {
      expect(pfFromKwKva(80, 100), closeTo(0.8, 1e-12));
      expect(pfFromKwKva(120, 100), isNull);
    });
    test('역률 = P ÷ (√3 V I): 9.5 kW, 380 V, 18 A → 0.802, 단상 2.2 kW 220 V 12.5 A → 0.8', () {
      expect(pfFromKwVi(kw: 9.5, volts: 380, amps: 18, three: true)!, closeTo(9500 / (math.sqrt(3) * 380 * 18), 1e-12));
      expect(pfFromKwVi(kw: 9.5, volts: 380, amps: 18, three: true)!, closeTo(0.802, 0.001));
      expect(pfFromKwVi(kw: 2.2, volts: 220, amps: 12.5, three: false)!, closeTo(0.8, 1e-12));
      expect(pfFromKwVi(kw: 20, volts: 380, amps: 10, three: true), isNull);
    });
    test('전압: 삼상 P 10 kW, I 18.2 A, cosφ 0.85 → 373 V, 서로 되돌린다', () {
      final v = voltageFromKwIPf(kw: 10, amps: 18.2, pf: 0.85, three: true)!;
      expect(v, closeTo(10000 / (math.sqrt(3) * 18.2 * 0.85), 1e-9));
      expect(pfFromKwVi(kw: 10, volts: v, amps: 18.2, three: true)!, closeTo(0.85, 1e-12));
      expect(voltageFromKva(kva: 100, amps: 152, three: true)!, closeTo(100000 / (math.sqrt(3) * 152), 1e-9));
    });
  });

  group('임피던스', () {
    test('R 30, XL 40: Z 50, 역률 0.6, 위상 53.1°, 220 V에서 4.4 A', () {
      final z = seriesImpedance(r: 30, xl: 40, volts: 220)!;
      expect(z.z, closeTo(50, 1e-12));
      expect(z.pf, closeTo(0.6, 1e-12));
      expect(z.angleDeg, closeTo(53.13, 0.01));
      expect(z.amps, closeTo(4.4, 1e-12));
    });
    test('XL < XC면 용량성(음수 각)', () {
      final z = seriesImpedance(r: 30, xl: 10, xc: 50)!;
      expect(z.x, -40);
      expect(z.angleDeg, closeTo(-53.13, 0.01));
    });
    test('공진(XL = XC)에서는 Z = R, 역률 1', () {
      final z = seriesImpedance(r: 10, xl: 25, xc: 25)!;
      expect(z.z, closeTo(10, 1e-12));
      expect(z.pf, closeTo(1, 1e-12));
    });
    test('XL = 2πfL, XC = 1 ÷ (2πfC): 60 Hz 0.1 H → 37.7 Ω, 100 μF → 26.5 Ω', () {
      expect(inductiveX(60, 0.1), closeTo(37.699, 0.001));
      expect(capacitiveX(60, 100e-6)!, closeTo(26.526, 0.001));
    });
  });

  group('케이블 온도·손실', () {
    test('허용전류에서는 최고 온도, 반이면 상승 1/4: 주위 30, 최고 90, Iz 100', () {
      expect(cableConductorTemp(ambientC: 30, maxC: 90, current: 100, iz: 100), closeTo(90, 1e-12));
      expect(cableConductorTemp(ambientC: 30, maxC: 90, current: 50, iz: 100), closeTo(30 + 60 * 0.25, 1e-12));
      expect(cableConductorTemp(ambientC: 30, maxC: 90, current: 0, iz: 100), closeTo(30, 1e-12));
      expect(cableConductorTemp(ambientC: 90, maxC: 90, current: 5, iz: 100), isNull);
    });
    test('삼상 3 I² R L: 50 A, 1.2 Ω/km, 100 m → 900 W, 단상은 2 I² R L', () {
      final l = cableLoss(current: 50, rOhmPerKm: 1.2, lengthM: 100, three: true, powerKw: 30, hoursYear: 4000)!;
      expect(l.watts, closeTo(3 * 2500 * 1.2 * 0.1, 1e-9));
      expect(l.watts, closeTo(900, 1e-9));
      expect(l.perM, closeTo(9, 1e-9));
      expect(l.pctOfPower!, closeTo(900 / 30000 * 100, 1e-9));
      expect(l.kwhYear!, closeTo(900 * 4000 / 1000, 1e-9));
      final s = cableLoss(current: 50, rOhmPerKm: 1.2, lengthM: 100, three: false)!;
      expect(s.watts, closeTo(2 * 2500 * 1.2 * 0.1, 1e-9));
      expect(s.pctOfPower, isNull);
    });
    test('케이블 임피던스: 0.5 Ω/km, 0.096 Ω/km, 200 m → R 0.1, X 0.0192', () {
      final z = cableImpedance(rOhmPerKm: 0.5, xOhmPerKm: 0.096, lengthM: 200)!;
      expect(z.r, closeTo(0.1, 1e-12));
      expect(z.x, closeTo(0.0192, 1e-12));
      expect(z.z, closeTo(math.sqrt(0.1 * 0.1 + 0.0192 * 0.0192), 1e-12));
    });
  });

  group('콘덴서 전압 환산', () {
    test('440 V 20 kvar 콘덴서를 380 V에 쓰면 14.9 kvar, 50→60 Hz면 × 1.2', () {
      expect(capacitorKvarAtVoltage(ratedKvar: 20, ratedVolts: 440, volts: 380)!, closeTo(20 * math.pow(380 / 440, 2), 1e-9));
      expect(capacitorKvarAtVoltage(ratedKvar: 20, ratedVolts: 440, volts: 380)!, closeTo(14.92, 0.01));
      expect(capacitorKvarAtVoltage(ratedKvar: 10, ratedVolts: 400, volts: 400, ratedHz: 50, hz: 60)!, closeTo(12, 1e-12));
      expect(capacitorKvarAtVoltage(ratedKvar: 0, ratedVolts: 400, volts: 400), isNull);
    });
  });

  group('변압기 무효전력', () {
    test('1000 kVA, i0 1.5 %, usc 6 %: 무부하 15 kvar, 전부하 +60 → 75, 부하율 50 %면 15 + 15', () {
      final f = transformerReactive(kva: 1000, i0Pct: 1.5, uscPct: 6, loadFactor: 1)!;
      expect(f.noLoadKvar, closeTo(15, 1e-12));
      expect(f.leakKvar, closeTo(60, 1e-12));
      expect(f.totalKvar, closeTo(75, 1e-12));
      final h = transformerReactive(kva: 1000, i0Pct: 1.5, uscPct: 6, loadFactor: 0.5)!;
      expect(h.leakKvar, closeTo(15, 1e-12));
      expect(h.totalKvar, closeTo(30, 1e-12));
    });

    test('Schneider EIG 그림 L22: 12개 용량 × 무부하·전부하 24개 값이 원문과 같다', () {
      // 원문(공식 위키, 1차 20 kV 배전용 변압기) 값.
      const src = {
        100: [2.5, 6.1],
        160: [3.7, 9.6],
        250: [5.3, 14.7],
        315: [6.3, 18.4],
        400: [7.6, 22.9],
        500: [9.5, 28.7],
        630: [11.3, 35.7],
        800: [20.0, 54.5],
        1000: [23.9, 72.4],
        1250: [27.4, 94.5],
        1600: [31.9, 126.0],
        2000: [37.8, 176.0],
      };
      expect(kTransformerL22.keys.toList(), src.keys.toList());
      for (final e in src.entries) {
        expect(kTransformerL22[e.key], e.value, reason: '${e.key} kVA');
      }
    });
  });

  group('자동 차단 기준 최대 길이', () {
    test('U0 230, Ia 160 A, Ze 0, 상·PE 2.5 mm² → 약 79.9 m', () {
      final l = maxLengthForTrip(u0: 230, iaA: 160, phaseMm2: 2.5, peMm2: 2.5)!;
      expect(l, closeTo(1.4375 / (0.0225 * 0.8), 1e-9));
      expect(l, closeTo(79.86, 0.01));
    });
    test('전원 쪽 Ze가 클수록 짧아지고, Ze가 Zs 최대 이상이면 0', () {
      final a = maxLengthForTrip(u0: 230, iaA: 160, ze: 0.4, phaseMm2: 2.5, peMm2: 2.5)!;
      expect(a, closeTo((1.4375 - 0.4) / (0.0225 * 0.8), 1e-9));
      expect(maxLengthForTrip(u0: 230, iaA: 160, ze: 2, phaseMm2: 2.5, peMm2: 2.5), 0);
      expect(maxLengthForTrip(u0: 230, iaA: 0, phaseMm2: 2.5, peMm2: 2.5), isNull);
    });
  });
}
