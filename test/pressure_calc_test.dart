// 압력 시험 계산 — ASME B31.3·B31.1 시험 압력, 압력 강하, 수압 온도, 저장 에너지, 구멍 누설.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/pressure_calc.dart';

void main() {
  group('시험 압력', () {
    test('B31.3 수압: 1.5 × P, ST/S를 넣으면 곱한다, 1 아래는 1', () {
      final a = testPlan(code: PipingCode.b313, medium: TestMedium.hydro, designKpa: 1000);
      expect(a.minKpa, 1500);
      expect(a.holdMin, 10);
      expect(a.examKpa, 1000);
      final b = testPlan(
        code: PipingCode.b313,
        medium: TestMedium.hydro,
        designKpa: 1000,
        stressRatio: 1.2,
      );
      expect(b.minKpa, closeTo(1800, 1e-9));
      expect(
        testPlan(code: PipingCode.b313, medium: TestMedium.hydro, designKpa: 1000, stressRatio: 0.8).minKpa,
        1500,
      );
    });
    test('B31.3 공압: 1.1P~1.33P, 사전 점검 min(½PT, 170), 안전밸브 PT + min(345, 10%)', () {
      final a = testPlan(code: PipingCode.b313, medium: TestMedium.pneumatic, designKpa: 1000);
      expect(a.minKpa, closeTo(1100, 1e-9));
      expect(a.maxKpa, closeTo(1330, 1e-9));
      expect(a.prelimKpa, 170);
      expect(a.reliefMaxKpa, closeTo(1210, 1e-9));
      final small = testPlan(code: PipingCode.b313, medium: TestMedium.pneumatic, designKpa: 200);
      expect(small.prelimKpa, closeTo(110, 1e-9)); // ½ × 220
      final big = testPlan(code: PipingCode.b313, medium: TestMedium.pneumatic, designKpa: 5000);
      expect(big.reliefMaxKpa, closeTo(5500 + 345, 1e-9));
    });
    test('B31.1 수압 1.5P, 안전밸브 권장 1⅓PT', () {
      final a = testPlan(code: PipingCode.b311, medium: TestMedium.hydro, designKpa: 2000);
      expect(a.minKpa, 3000);
      expect(a.reliefRecKpa, closeTo(4000, 1e-9));
    });
    test('B31.1 공압 1.2P~1.5P, 점검은 min(P, 700kPa)', () {
      final a = testPlan(code: PipingCode.b311, medium: TestMedium.pneumatic, designKpa: 1000);
      expect(a.minKpa, closeTo(1200, 1e-9));
      expect(a.maxKpa, 1500);
      expect(a.examKpa, 700);
      expect(a.prelimKpa, 175);
    });
    test('실제 시험 압력을 넣으면 안전밸브를 그 압력으로 셈하고, 범위 밖이면 알린다', () {
      // B31.3 공압 설계 10bar: 11~13.3bar. 13.3bar로 올리면 안전밸브 13.3 + 1.33 = 14.63bar.
      final a = testPlan(
        code: PipingCode.b313,
        medium: TestMedium.pneumatic,
        designKpa: 1000,
        actualKpa: 1330,
      );
      expect(a.minKpa, closeTo(1100, 1e-9));
      expect(a.usedKpa, 1330);
      expect(a.reliefMaxKpa, closeTo(1463, 1e-9));
      expect(a.actualInRange(1330), isTrue);
      expect(a.actualInRange(1400), isFalse);
      expect(a.actualInRange(1000), isFalse);
      expect(a.actualInRange(null), isNull);
      // 넣지 않으면 예전처럼 최소 시험 압력으로
      final b = testPlan(code: PipingCode.b313, medium: TestMedium.pneumatic, designKpa: 1000);
      expect(b.usedKpa, closeTo(1100, 1e-9));
      // B31.1 수압: 권장 1⅓ × 실제 시험 압력, 최대가 없어 최소 이상이면 범위 안
      final c = testPlan(
        code: PipingCode.b311,
        medium: TestMedium.hydro,
        designKpa: 2000,
        actualKpa: 3300,
      );
      expect(c.reliefRecKpa, closeTo(4400, 1e-9));
      expect(c.actualInRange(3300), isTrue);
      expect(c.actualInRange(2900), isFalse);
      // B31.1 공압: ½PT가 175kPa보다 작을 때 사전 점검은 실제 PT의 ½
      final d = testPlan(
        code: PipingCode.b311,
        medium: TestMedium.pneumatic,
        designKpa: 200,
        actualKpa: 280,
      );
      expect(d.prelimKpa, closeTo(140, 1e-9));
    });
  });

  group('압력 강하', () {
    test('온도만 내려 압력이 준 것은 누설이 아니다: 700kPa 20°C → 10°C', () {
      // P2abs = 801.325 × 283.15/293.15 = 773.99 → 게이지 672.66
      final r = pressureDecay(p1Kpa: 700, p2Kpa: 672.66, t1C: 20, t2C: 10);
      expect(r.rawDropKpa, closeTo(27.34, 0.01));
      expect(r.correctedDropKpa.abs(), lessThan(0.02));
    });
    test('누설률: 100L, 60분, 700→690kPa, 온도 같음 → 0.2778 Pa·m³/s', () {
      final r = pressureDecay(
        p1Kpa: 700,
        p2Kpa: 690,
        t1C: 20,
        t2C: 20,
        volumeL: 100,
        minutes: 60,
      );
      // V/Δt·ΔP = 0.1/3600 × 10000 Pa
      expect(r.leakPaM3s, closeTo(0.27778, 1e-4));
      expect(r.leakMbarLs, closeTo(2.7778, 1e-3));
      expect(r.leakSccm, closeTo(r.leakPaM3s! * 9.8692 * 60, 1e-9));
    });
  });

  group('수압 물 온도', () {
    test('20°C, 강관 D/t=20 → 약 3.1 bar/°C, 5°C 근처는 거의 0 아래', () {
      final v = hydroBarPerDegC(waterC: 20, odMm: 21 * 5.0, wallMm: 5.0);
      expect(v, closeTo(3.1, 0.15));
      expect(hydroBarPerDegC(waterC: 5, odMm: 105, wallMm: 5), lessThan(0));
      // 단단한 관(벽이 아주 두꺼움)에 가까우면 3.7
      expect(hydroBarPerDegC(waterC: 20, odMm: 1000, wallMm: 499), closeTo(3.7, 0.1));
    });
  });

  group('저장 에너지', () {
    test('ABSA 예: 2172kPa(g), 0.5m³ → 약 1677kJ', () {
      final e = storedEnergy(testKpa: 2172, volumeL: 500);
      expect(e.joules / 1000, closeTo(1677, 5));
      expect(e.tntKg, closeTo(1677e3 / 4266920, 0.01));
      expect(e.distanceM, 30); // 20·0.393^(1/3)=14.7 < 30
      expect(e.beyondFixed, isFalse);
    });
    test('큰 에너지: 식 거리가 고정 거리보다 크면 식 거리', () {
      final e = storedEnergy(testKpa: 20000, volumeL: 50000);
      expect(e.beyondFixed, isTrue);
      expect(e.distanceM, e.scaledM);
    });
    test('관 체적: ID 100mm 10m → 78.5L', () {
      expect(pipeVolumeL(idMm: 100, lengthM: 10), closeTo(78.54, 0.01));
    });
  });

  group('구멍 누설', () {
    test('1/4" 구멍 100psig, Cd 1 → 104cfm(DOE 자료)', () {
      final lps = holeLeakLps(holeMm: 6.35, supplyKpa: 689.476, cd: 1);
      expect(lps * 2.11888, closeTo(104, 2)); // L/s → cfm
    });
    test('압축기 전력: 100cfm ≈ 18kW', () {
      final lps = 100 / 2.11888;
      expect(leakCompressorKw(lps), closeTo(18, 0.1));
    });
  });
}
