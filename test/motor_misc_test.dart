// 전동기 기타 계산: 손으로 푼 값과 맞춘다.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/electrical/motor_misc.dart';

void main() {
  insulationGroup();
  group('권선 온도 상승(저항법)', () {
    test('2.0 Ω(20℃) → 2.4 Ω, 주위 30℃: 권선 70.9℃, 상승 40.9 K', () {
      final r = windingTempRise(r1: 2.0, t1: 20, r2: 2.4, t2: 30)!;
      expect(r.hotTempC, closeTo(1.2 * 254.5 - 234.5, 1e-9));
      expect(r.hotTempC, closeTo(70.9, 1e-9));
      expect(r.riseK, closeTo(40.9, 1e-9));
    });
    test('알루미늄은 상수 225', () {
      final r = windingTempRise(r1: 2.0, t1: 20, r2: 2.4, t2: 30, aluminum: true)!;
      expect(r.hotTempC, closeTo(1.2 * 245 - 225, 1e-9));
    });
    test('저항이 같으면 권선 온도는 처음 온도', () {
      expect(windingTempRise(r1: 1, t1: 25, r2: 1, t2: 25)!.riseK, closeTo(0, 1e-9));
      expect(windingTempRise(r1: 0, t1: 25, r2: 1, t2: 25), isNull);
    });
  });

  group('효율 절감·회수', () {
    test('11 kW 부하율 75 % 6000 h 효율 90 → 93 %, 120원: 연 1774 kWh 절감, 21.3만 원, 50만 원 → 2.35년', () {
      final r = energySaving(
        kw: 11, loadFactor: 0.75, hours: 6000, effOld: 0.90, effNew: 0.93, price: 120, extraCost: 500000,
      )!;
      expect(r.kwhOld, closeTo(55000, 1e-6));
      expect(r.kwhNew, closeTo(49500 / 0.93, 1e-6));
      expect(r.savedKwh, closeTo(55000 - 49500 / 0.93, 1e-6));
      expect(r.savedKwh, closeTo(1774.2, 0.1));
      expect(r.savedMoney, closeTo(r.savedKwh * 120, 1e-6));
      expect(r.paybackYears!, closeTo(500000 / r.savedMoney, 1e-9));
    });
    test('효율이 같으면 절감 0, 회수 기간 없음', () {
      final r = energySaving(kw: 11, loadFactor: 1, hours: 1000, effOld: 0.9, effNew: 0.9, price: 100, extraCost: 1000)!;
      expect(r.savedKwh, closeTo(0, 1e-9));
      expect(r.paybackYears, isNull);
    });
    test('잘못된 값은 null', () {
      expect(energySaving(kw: 0, loadFactor: 1, hours: 1, effOld: 0.9, effNew: 0.9, price: 1), isNull);
      expect(energySaving(kw: 1, loadFactor: 1, hours: 1, effOld: 1.1, effNew: 0.9, price: 1), isNull);
    });
  });

  group('감속기·벨트', () {
    test('1750 rpm 11 kW, i = 10, 효율 95 %: 175 rpm, 570 N·m, 10.45 kW', () {
      final g = gearOut(inRpm: 1750, inKw: 11, ratio: 10, eff: 0.95)!;
      expect(g.outRpm, closeTo(175, 1e-9));
      expect(g.outTorqueNm, closeTo(11000 * 60 / (2 * math.pi * 1750) * 10 * 0.95, 1e-9));
      expect(g.outTorqueNm, closeTo(570.2, 0.1));
      expect(g.outKw, closeTo(10.45, 1e-9));
    });
    test('출력 동력 = 출력 토크 × 출력 속도', () {
      final g = gearOut(inRpm: 1450, inKw: 4, ratio: 6, eff: 0.9)!;
      expect(g.outTorqueNm * 2 * math.pi * g.outRpm / 60 / 1000, closeTo(g.outKw, 1e-9));
    });
  });

  group('권상·컨베이어', () {
    test('권상 1000 kg 0.5 m/s 효율 85 % → 5.77 kW', () {
      expect(hoistPowerKw(massKg: 1000, speed: 0.5, eff: 0.85)!, closeTo(5.769, 0.001));
    });
    test('컨베이어 수평: 2000 kg 1 m/s μ 0.03 효율 90 % → 0.654 kW', () {
      expect(
        conveyorPowerKw(massKg: 2000, speed: 1, mu: 0.03, angleDeg: 0, eff: 0.9)!,
        closeTo(2000 * 9.80665 * 0.03 / 900, 1e-9),
      );
    });
    test('경사 10°: 4.43 kW', () {
      final a = 10 * math.pi / 180;
      expect(
        conveyorPowerKw(massKg: 2000, speed: 1, mu: 0.03, angleDeg: 10, eff: 0.9)!,
        closeTo(2000 * 9.80665 * (0.03 * math.cos(a) + math.sin(a)) / 900, 1e-9),
      );
    });
    test('수직에 가까운 경사·잘못된 값은 null', () {
      expect(conveyorPowerKw(massKg: 1, speed: 1, mu: 0, angleDeg: 90, eff: 1), isNull);
      expect(hoistPowerKw(massKg: 0, speed: 1, eff: 1), isNull);
    });
  });

  group('소프트스타터', () {
    test('22 A × 6배, 전압 50 %: 66 A, 토크 25 %', () {
      final s = softStart(ratedAmps: 22, multiple: 6, voltageRatio: 0.5)!;
      expect(s.motorAmps, 66);
      expect(s.torqueRatio, 0.25);
    });
    test('전압 100 %는 직입과 같다', () {
      final s = softStart(ratedAmps: 22, multiple: 6, voltageRatio: 1)!;
      expect(s.motorAmps, 132);
      expect(s.torqueRatio, 1);
      expect(softStart(ratedAmps: 22, multiple: 6, voltageRatio: 1.2), isNull);
    });
  });

  group('제동 에너지', () {
    test('J 2 kg·m², 1750 → 0 rpm, 5초: E 33.6 kJ, 평균 6.72 kW, 최대 13.4 kW, 700 V → 36.5 Ω 이하', () {
      final w = 2 * math.pi * 1750 / 60;
      final b = brakeEnergy(j: 2, rpm1: 1750, rpm2: 0, seconds: 5, vdc: 700)!;
      expect(b.energyJ, closeTo(0.5 * 2 * w * w, 1e-6));
      expect(b.energyJ, closeTo(33583.8, 0.5));
      expect(b.avgKw, closeTo(b.energyJ / 5 / 1000, 1e-9));
      expect(b.peakKw, closeTo(2 * b.avgKw, 1e-9));
      expect(b.maxOhm!, closeTo(700 * 700 / (b.peakKw * 1000), 1e-9));
      expect(b.maxOhm!, closeTo(36.5, 0.05));
    });
    test('속도를 올리는 입력은 null, 직류 전압 없으면 저항 없음', () {
      expect(brakeEnergy(j: 2, rpm1: 1000, rpm2: 1500, seconds: 5), isNull);
      expect(brakeEnergy(j: 2, rpm1: 1000, rpm2: 0, seconds: 5)!.maxOhm, isNull);
    });
  });

  group('직류 전동기', () {
    test('220 V, 20 A, Ra 0.5 Ω: Ea 210 V, 4.2 kW, 1500 rpm이면 26.7 N·m', () {
      final d = dcMotor(volts: 220, ia: 20, ra: 0.5, rpm: 1500)!;
      expect(d.backEmf, 210);
      expect(d.devKw, closeTo(4.2, 1e-12));
      expect(d.torqueNm!, closeTo(4200 / (2 * math.pi * 1500 / 60), 1e-9));
      expect(d.torqueNm!, closeTo(26.74, 0.01));
    });
    test('전압강하가 단자 전압 이상이면 null', () {
      expect(dcMotor(volts: 10, ia: 30, ra: 0.5), isNull);
    });
    test('속도: Ea 210 → 200 V면 1428.6 rpm, 계자 80 %면 1785.7 rpm', () {
      expect(dcSpeedAfter(rpm1: 1500, ea1: 210, ea2: 200)!, closeTo(1500 * 200 / 210, 1e-9));
      expect(dcSpeedAfter(rpm1: 1500, ea1: 210, ea2: 200, fluxRatio: 0.8)!, closeTo(1500 * 200 / 210 / 0.8, 1e-9));
    });
  });
}

void insulationGroup() {
  group('절연 등급', () {
    test('등급 온도: A 105, E 120, B 130, F 155, H 180, N 200 (IEC 60085 표 1)', () {
      expect({for (final c in kInsulation) c.name: c.maxC}, {
        'A': 105, 'E': 120, 'B': 130, 'F': 155, 'H': 180, 'N': 200,
      });
    });
    test('온도 상승 한계(저항법): A 60, E 75, B 80, F 105, H 125, N 없음', () {
      expect({for (final c in kInsulation) c.name: c.riseK}, {
        'A': 60, 'E': 75, 'B': 80, 'F': 105, 'H': 125, 'N': null,
      });
    });
    test('F급 상승 90 K, 주위 40℃ → 권선 130℃, 마진 25 K, 한계 여유 15 K, 수명 약 5.7배', () {
      final r = insulationCheck(cls: insulationByName('F')!, riseK: 90, ambientC: 40)!;
      expect(r.hotTempC, 130);
      expect(r.marginK, 25);
      expect(r.riseMarginK, 15);
      expect(r.lifeFactor, closeTo(math.pow(2, 2.5), 1e-9));
    });
    test('등급 온도를 넘으면 마진이 음수, 수명은 1보다 작다', () {
      final r = insulationCheck(cls: insulationByName('B')!, riseK: 100, ambientC: 40)!;
      expect(r.marginK, -10);
      expect(r.riseMarginK, -20);
      expect(r.lifeFactor, closeTo(0.5, 1e-12));
    });
    test('N급은 상승 한계가 없어 여유 null', () {
      expect(insulationCheck(cls: insulationByName('N')!, riseK: 100, ambientC: 40)!.riseMarginK, isNull);
      expect(insulationByName('X'), isNull);
      expect(insulationCheck(cls: insulationByName('F')!, riseK: -1, ambientC: 40), isNull);
    });
  });
}
