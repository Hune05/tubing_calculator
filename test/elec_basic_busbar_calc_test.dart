// 전기 계산기 기초 계산 식과 부스바 표(DIN 43671), 직류 전선 선정 계산 시험.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/electrical/basic_calc.dart';
import 'package:tubing_calculator/src/presentation/electrical/busbar_tables.dart';
import 'package:tubing_calculator/src/presentation/electrical/elec_calc.dart';
import 'package:tubing_calculator/src/presentation/electrical/elec_tables.dart';

BusbarRow bar(String label) => kBusbars.firstWhere((r) => r.label == label);

void main() {
  group('옴의 법칙·전력', () {
    test('V·I → R·P, V·R → I·P, I·P → V·R, R·P → I·V', () {
      var r = ohmLaw(v: 220, i: 10)!;
      expect(r.r, closeTo(22, 1e-9));
      expect(r.p, closeTo(2200, 1e-9));
      expect(r.from, ['V', 'I']);
      r = ohmLaw(v: 220, r: 48.4)!;
      expect(r.i, closeTo(4.5455, 1e-4));
      expect(r.p, closeTo(1000, 1e-9));
      r = ohmLaw(i: 2, p: 100)!;
      expect(r.v, closeTo(50, 1e-9));
      expect(r.r, closeTo(25, 1e-9));
      r = ohmLaw(r: 10, p: 1000)!;
      expect(r.i, closeTo(10, 1e-9));
      expect(r.v, closeTo(100, 1e-9));
    });
    test('값이 하나뿐이거나 0·음수면 계산하지 않고, 세 값이면 앞의 두 값을 쓴다', () {
      expect(ohmLaw(v: 12), isNull);
      expect(ohmLaw(v: 12, i: 0), isNull);
      expect(ohmLaw(v: 12, i: -1), isNull);
      final r = ohmLaw(v: 10, i: 2, r: 99)!;
      expect(r.from, ['V', 'I']);
      expect(r.r, closeTo(5, 1e-9));
    });
  });

  group('교류 전력', () {
    test('삼상 380V 100A 역률 0.85 → 65.82kVA, 55.95kW, 34.67kvar', () {
      final a = acPowerFromCurrent(
        volts: 380,
        amps: 100,
        pf: 0.85,
        three: true,
      );
      expect(a.kva, closeTo(65.818, 1e-3));
      expect(a.kw, closeTo(55.945, 1e-3));
      expect(a.kvar, closeTo(34.672, 1e-3));
      expect(a.angleDeg, closeTo(31.79, 0.01));
    });
    test('단상 220V 10A 역률 1 → 2.2kW, 무효전력 0', () {
      final a = acPowerFromCurrent(volts: 220, amps: 10, pf: 1, three: false);
      expect(a.kw, closeTo(2.2, 1e-9));
      expect(a.kvar, closeTo(0, 1e-9));
    });
    test('100kW 역률 0.8 삼상 380V → 125kVA, 75kvar, 189.9A', () {
      final a = acPowerFromKw(kw: 100, pf: 0.8, volts: 380, three: true);
      expect(a.kva, closeTo(125, 1e-9));
      expect(a.kvar, closeTo(75, 1e-9));
      expect(a.amps, closeTo(189.92, 0.01));
    });
  });

  group('Y·Δ 결선', () {
    test('Y 선간 380V → 상 219.4V, 선전류 = 상전류', () {
      final s = starDelta(star: true, fromLine: true, volts: 380, amps: 10);
      expect(s.phaseV, closeTo(219.393, 1e-3));
      expect(s.phaseI, 10);
    });
    test('Δ 선전류 17.32A → 상전류 10A, 선간전압 = 상전압', () {
      final s = starDelta(
        star: false,
        fromLine: true,
        volts: 380,
        amps: 17.3205,
      );
      expect(s.phaseV, 380);
      expect(s.phaseI, closeTo(10, 1e-4));
    });
    test('Y 상 220V → 선간 381V, Δ 상전류 10A → 선전류 17.32A', () {
      expect(
        starDelta(star: true, fromLine: false, volts: 220).lineV,
        closeTo(381.05, 0.01),
      );
      expect(
        starDelta(star: false, fromLine: false, amps: 10).lineI,
        closeTo(17.3205, 1e-4),
      );
    });
  });

  group('전력량·도체 저항', () {
    test('5.5kW × 24h × 30일 = 3960kWh', () {
      expect(energyKwh(5.5, 24, 30), closeTo(3960, 1e-9));
    });
    test('구리 2.5mm² 100m 20°C 0.6896Ω, 90°C 0.8794Ω', () {
      expect(
        conductorResistance(
          metal: ConductorMetal.copper,
          areaMm2: 2.5,
          lengthM: 100,
        ),
        closeTo(0.68964, 1e-5),
      );
      expect(
        conductorResistance(
          metal: ConductorMetal.copper,
          areaMm2: 2.5,
          lengthM: 100,
          tempC: 90,
        ),
        closeTo(0.68964 * (1 + 0.00393 * 70), 1e-5),
      );
    });
    test('알루미늄 50mm² 1km 20°C 0.5653Ω, 온도계수 0.00403', () {
      expect(
        conductorResistance(
          metal: ConductorMetal.aluminium,
          areaMm2: 50,
          lengthM: 1000,
        ),
        closeTo(0.56528, 1e-5),
      );
      expect(alpha20(ConductorMetal.aluminium), 0.00403);
      expect(rho20(ConductorMetal.copper), 0.017241);
    });
    test('직렬·병렬 합성 저항', () {
      expect(seriesResistance([10, 20, 30]), 60);
      expect(parallelResistance([10, 10]), closeTo(5, 1e-9));
      expect(parallelResistance([10, 20, 30]), closeTo(5.4545, 1e-4));
      expect(parallelResistance([10, 0]), 0);
    });
  });

  group('주파수', () {
    test('주기·각주파수: 60Hz → 16.67ms, 377rad/s', () {
      expect(periodSec(60) * 1000, closeTo(16.667, 1e-3));
      expect(angularFreq(60), closeTo(376.99, 0.01));
    });
    test('동기속도: 60Hz 2극 3600, 4극 1800, 6극 1200 / 50Hz 4극 1500', () {
      expect(syncSpeedRpm(60, 2), 3600);
      expect(syncSpeedRpm(60, 4), 1800);
      expect(syncSpeedRpm(60, 6), 1200);
      expect(syncSpeedRpm(50, 4), 1500);
      // 50 → 60Hz는 1.2배.
      expect(syncSpeedRpm(60, 4) / syncSpeedRpm(50, 4), closeTo(1.2, 1e-12));
    });
    test('슬립 1800 → 1750rpm 2.78%, 발전기 4극 1800rpm → 60Hz', () {
      expect(slip(1800, 1750) * 100, closeTo(2.778, 1e-3));
      expect(slip(1800, 1850), lessThan(0));
      expect(generatorHz(4, 1800), 60);
      expect(generatorHz(2, 3600), 60);
    });
    test('XL·XC·공진: 60Hz 100mH 37.7Ω, 100μF 26.53Ω, f0 50.33Hz', () {
      expect(inductiveReactance(60, 0.1), closeTo(37.699, 1e-3));
      expect(capacitiveReactance(60, 100e-6), closeTo(26.526, 1e-3));
      expect(resonanceHz(0.1, 100e-6), closeTo(50.329, 1e-3));
      expect(
        resonanceHz(0.1, 100e-6),
        closeTo(1 / (2 * math.pi * math.sqrt(1e-5)), 1e-9),
      );
    });
  });

  group('부스바 표(DIN 43671)', () {
    test('26규격, 12×2부터 200×10까지, 단면적은 DIN 표 값', () {
      expect(kBusbars.length, 26);
      expect(kBusbars.first.label, '12×2');
      expect(kBusbars.last.label, '200×10');
      expect(bar('12×2').area, 23.5);
      expect(bar('100×10').area, 999);
    });
    test(
      '대표 값: 40×10 교류 1가닥 도장 안 함 715·도장 850, 직류 도장 865, 30×10 도장 안 함 573',
      () {
        expect(
          busbarRating(bar('40×10'), bars: 1, dc: false, painted: false).amps,
          715,
        );
        expect(
          busbarRating(bar('40×10'), bars: 1, dc: false, painted: true).amps,
          850,
        );
        expect(
          busbarRating(bar('40×10'), bars: 1, dc: true, painted: true).amps,
          865,
        );
        expect(
          busbarRating(bar('30×10'), bars: 1, dc: false, painted: false).amps,
          573,
        );
        expect(
          busbarRating(bar('100×10'), bars: 1, dc: true, painted: true).amps,
          1940,
        );
        expect(
          busbarRating(bar('12×2'), bars: 1, dc: false, painted: true).amps,
          123,
        );
      },
    );
    test('출처끼리 달랐던 칸은 두 출처가 같은 값: 1060·1260·839·7710', () {
      expect(
        busbarRating(bar('30×10'), bars: 2, dc: false, painted: false).amps,
        1060,
      );
      expect(
        busbarRating(bar('50×5'), bars: 3, dc: false, painted: false).amps,
        1260,
      );
      expect(
        busbarRating(bar('25×5'), bars: 3, dc: false, painted: true).amps,
        839,
      );
      expect(
        busbarRating(bar('160×10'), bars: 4, dc: true, painted: false).amps,
        7710,
      );
    });
    test('표에 없는 칸과 한 출처뿐인 칸은 값이 없다', () {
      final a = busbarRating(bar('12×2'), bars: 4, dc: false, painted: true);
      expect(a.cell, BusbarCell.notInTable);
      expect(a.amps, isNull);
      expect(a.density, isNull);
      final b = busbarRating(bar('12×2'), bars: 2, dc: true, painted: true);
      expect(b.cell, BusbarCell.notVerified);
      expect(b.amps, isNull);
      expect(
        busbarRating(bar('40×10'), bars: 4, dc: true, painted: true).cell,
        BusbarCell.notInTable,
      );
    });
    test('가닥이 늘면 허용전류가 늘고, 직류 1가닥은 교류 이상(표피 효과)', () {
      for (final r in kBusbars) {
        for (final dc in [false, true]) {
          for (final painted in [false, true]) {
            final col = r.column(dc: dc, painted: painted);
            final ok = [
              for (final v in col)
                if (v > 0) v,
            ];
            for (var i = 1; i < ok.length; i++) {
              expect(
                ok[i],
                greaterThan(ok[i - 1]),
                reason: '${r.label} $dc $painted',
              );
            }
          }
        }
        expect(r.dcBare[0], greaterThanOrEqualTo(r.acBare[0]), reason: r.label);
        expect(r.acPainted[0], greaterThan(r.acBare[0]), reason: r.label);
      }
    });
    test('전류 밀도: 40×10 715A ÷ 399mm² = 1.79 A/mm²', () {
      final k = busbarRating(bar('40×10'), bars: 1, dc: false, painted: false);
      expect(k.density, closeTo(1.792, 1e-3));
      final k2 = busbarRating(bar('40×10'), bars: 2, dc: false, painted: false);
      expect(k2.density, closeTo(1290 / 798, 1e-9));
    });
    test(
      '굵기 선정: 교류 도장 안 함 1000A → 1가닥 100×5, 2가닥 60×5(같은 단면적 30×10보다 큼), 3가닥 20×10',
      () {
        final one = smallestBusbar(1000, bars: 1, dc: false, painted: false)!;
        expect(one.row.label, '100×5');
        expect(one.amps, 1080);
        final two = smallestBusbar(1000, bars: 2, dc: false, painted: false)!;
        expect(two.row.label, '60×5');
        expect(two.amps, 1150);
        final three = smallestBusbar(1000, bars: 3, dc: false, painted: false)!;
        expect(three.row.label, '20×10');
        final four = smallestBusbar(1000, bars: 4, dc: false, painted: false)!;
        expect(four.row.label, '50×5');
        expect(four.amps, 1920);
      },
    );
    test('굵기 선정: 직류 2가닥은 확인 안 된 얇은 규격을 건너뛰고, 표를 넘으면 null', () {
      final k = smallestBusbar(300, bars: 2, dc: true, painted: false)!;
      expect(k.row.label, '20×5');
      expect(k.amps, 502);
      expect(smallestBusbar(10000, bars: 1, dc: false, painted: true), isNull);
    });
  });

  group('직류 전선 선정', () {
    test('125VDC 20A 50m F-CV 트레이: 차단기 없이 10sq(전압강하), 전동기 범위 없음', () {
      final c = chooseCable(
        load: 20,
        margin: 1.25,
        volts: 125,
        phase: Phase.dc,
        ins: Insulation.xlpe90,
        method: InstallMethod.e,
        lengthM: 50,
        motor: true,
      );
      expect(c.breaker, isNull);
      expect(c.motorRange, isNull);
      expect(c.sizeByAmpacity, 1.5); // 2가닥 통전 26A ≥ 25A
      expect(c.size, 10);
      expect(c.iz, 86);
      expect(c.dropV, closeTo(2 * 20 * 0.05 * 1.83 * (1 + 0.00393 * 70), 1e-9));
      expect(c.dropPct, closeTo(3.733, 1e-3));
    });
    test('직류 허용전류는 2가닥 통전 열(단상과 같은 값)', () {
      expect(
        correctedAmpacity(
          size: 16,
          ins: Insulation.xlpe90,
          phase: Phase.dc,
          method: InstallMethod.e,
        ),
        correctedAmpacity(
          size: 16,
          ins: Insulation.xlpe90,
          phase: Phase.single,
          method: InstallMethod.e,
        ),
      );
    });
    test('직류 기존 회로 점검: 전동기라도 차단기 범위는 계산하지 않는다', () {
      final k = checkCircuit(
        size: 10,
        load: 20,
        margin: 1.25,
        breaker: 32,
        volts: 125,
        phase: Phase.dc,
        ins: Insulation.xlpe90,
        method: InstallMethod.e,
        motor: true,
      );
      expect(k.motorRange, isNull);
      expect(k.inOk, isTrue);
      expect(k.ibOk, isTrue);
    });
    test('직류 부하 전류 I = P ÷ (V × 효율): 3.7kW 125V 90% → 32.9A', () {
      expect(
        loadCurrent(kw: 3.7, volts: 125, phase: Phase.dc, pf: 0.5, eff: 0.9),
        closeTo(32.889, 1e-3),
      );
      // 교류 110V 단상 1.1kW 역률·효율 1 → 10A
      expect(
        loadCurrent(kw: 1.1, volts: 110, phase: Phase.single),
        closeTo(10, 1e-9),
      );
    });
  });
}
