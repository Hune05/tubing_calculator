// 압력 시험 계산: ASME B31.3·B31.1 시험압력, 압력계 눈금, 물 기둥, 압력강하, 수압 온도,
// 공압 저장 에너지·출입 통제 거리(PCC-2-2022), 질소 용기, 에어 누설.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/pressure_calc.dart';

void main() {
  group('시험압력', () {
    test('B31.3 수압: 1.5 × P, ST/S를 넣으면 곱한다, 1 아래는 1', () {
      final a = testPlan(
        code: PipingCode.b313,
        medium: TestMedium.hydro,
        designKpa: 1000,
      );
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
        testPlan(
          code: PipingCode.b313,
          medium: TestMedium.hydro,
          designKpa: 1000,
          stressRatio: 0.8,
        ).minKpa,
        1500,
      );
    });
    test(
      'B31.3 공압: 1.1P~1.33P, 예비 점검 min(½PT, 170), 안전밸브 PT + min(345, 10%)',
      () {
        final a = testPlan(
          code: PipingCode.b313,
          medium: TestMedium.pneumatic,
          designKpa: 1000,
        );
        expect(a.minKpa, closeTo(1100, 1e-9));
        expect(a.maxKpa, closeTo(1330, 1e-9));
        expect(a.prelimKpa, 170);
        expect(a.prelimOptional, isFalse);
        expect(a.reliefMaxKpa, closeTo(1210, 1e-9));
        final small = testPlan(
          code: PipingCode.b313,
          medium: TestMedium.pneumatic,
          designKpa: 200,
        );
        expect(small.prelimKpa, closeTo(110, 1e-9)); // ½ × 220
        final big = testPlan(
          code: PipingCode.b313,
          medium: TestMedium.pneumatic,
          designKpa: 5000,
        );
        expect(big.reliefMaxKpa, closeTo(5500 + 345, 1e-9));
      },
    );
    test('B31.1 수압 1.5P, 안전밸브 권장 1⅓PT', () {
      final a = testPlan(
        code: PipingCode.b311,
        medium: TestMedium.hydro,
        designKpa: 2000,
      );
      expect(a.minKpa, 3000);
      expect(a.reliefRecKpa, closeTo(4000, 1e-9));
    });
    test('B31.1 공압 1.2P~1.5P, 점검은 min(P, 700kPa), 예비 점검은 175kPa 이하 선택', () {
      final a = testPlan(
        code: PipingCode.b311,
        medium: TestMedium.pneumatic,
        designKpa: 1000,
      );
      expect(a.minKpa, closeTo(1200, 1e-9));
      expect(a.maxKpa, 1500);
      expect(a.examKpa, 700);
      expect(a.prelimKpa, 175);
      expect(a.prelimOptional, isTrue);
      expect(a.steps.first, contains('선택'));
      expect(a.steps.first, isNot(contains('½')));
    });
    test('B31.1 공압 단계 압력: ½PT 뒤 PT/10씩 PT까지', () {
      final a = testPlan(
        code: PipingCode.b311,
        medium: TestMedium.pneumatic,
        designKpa: 1000,
      );
      expect(a.stepKpa.length, 6);
      for (var i = 0; i < 6; i++) {
        expect(a.stepKpa[i], closeTo(600 + 120.0 * i, 1e-9));
      }
      // 실제 시험압력을 넣으면 그 압력으로
      final b = testPlan(
        code: PipingCode.b311,
        medium: TestMedium.pneumatic,
        designKpa: 1000,
        actualKpa: 1400,
      );
      expect(b.stepKpa.first, closeTo(700, 1e-9));
      expect(b.stepKpa.last, closeTo(1400, 1e-9));
      // 다른 규격·수압은 단계 표 없음
      expect(
        testPlan(
          code: PipingCode.b313,
          medium: TestMedium.pneumatic,
          designKpa: 1000,
        ).stepKpa,
        isEmpty,
      );
    });
    test('실제 시험압력을 넣으면 안전밸브를 그 압력으로 계산하고, 범위 밖이면 알린다', () {
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
      // 넣지 않으면 최소 시험압력으로
      final b = testPlan(
        code: PipingCode.b313,
        medium: TestMedium.pneumatic,
        designKpa: 1000,
      );
      expect(b.usedKpa, closeTo(1100, 1e-9));
      // B31.1 수압: 권장 1⅓ × 실제 시험압력, 최대가 없어 최소 이상이면 범위 이내
      final c = testPlan(
        code: PipingCode.b311,
        medium: TestMedium.hydro,
        designKpa: 2000,
        actualKpa: 3300,
      );
      expect(c.reliefRecKpa, closeTo(4400, 1e-9));
      expect(c.actualInRange(3300), isTrue);
      expect(c.actualInRange(2900), isFalse);
      // B31.1 공압: 예비 점검은 시험압력과 관계없이 175kPa 이하(137.5.4)
      final d = testPlan(
        code: PipingCode.b311,
        medium: TestMedium.pneumatic,
        designKpa: 200,
        actualKpa: 280,
      );
      expect(d.prelimKpa, 175);
    });
    test('ST/S가 6.5를 초과하면 이전 판 상한 안내, 이하면 없음', () {
      final hi = testPlan(
        code: PipingCode.b313,
        medium: TestMedium.hydro,
        designKpa: 100,
        stressRatio: 7,
      );
      expect(hi.minKpa, closeTo(1050, 1e-9)); // 상한을 두지 않는다
      expect(hi.notes.first, contains('6.5'));
      expect(hi.notes.first, contains('이전 판'));
      final ok = testPlan(
        code: PipingCode.b313,
        medium: TestMedium.hydro,
        designKpa: 100,
        stressRatio: 6.5,
      );
      expect(ok.notes.where((n) => n.contains('6.5로 제한')), isEmpty);
    });
    test('B31.3는 2024판 345.2.3(기계적 이음부 재조립) 안내가 있다', () {
      for (final m in TestMedium.values) {
        final p = testPlan(code: PipingCode.b313, medium: m, designKpa: 1000);
        expect(p.notes.last, contains('345.2.3'));
      }
      final b311 = testPlan(
        code: PipingCode.b311,
        medium: TestMedium.hydro,
        designKpa: 1000,
      );
      expect(b311.notes.where((n) => n.contains('345.2.3')), isEmpty);
    });
    test('절차·주의 사항 글에 줄표와 지은 말이 없다', () {
      for (final c in PipingCode.values) {
        for (final m in TestMedium.values) {
          final p = testPlan(code: c, medium: m, designKpa: 1000);
          for (final s in [...p.steps, ...p.notes]) {
            expect(s, isNot(contains(' — ')), reason: s);
            for (final w in ['셈', '셉니다', '몫', '어림', '잰', '사전 점검', '누설 점검 압력']) {
              expect(s, isNot(contains(w)), reason: s);
            }
          }
        }
      }
    });
  });

  group('물 기둥·압력계', () {
    test('물 1m = 9.81kPa', () {
      expect(waterHeadKpa(10), closeTo(98.1, 1e-9));
      expect(waterHeadKpa(0), 0);
    });
    test(
      '압력계: 15bar 시험 → 약 30bar, 1.5~4배 이내 EN 837 눈금 25·40·60, 가장 가까운 25',
      () {
        final g = gaugeRange(1500);
        expect(g.recKpa, 3000);
        expect(g.lowKpa, 2250);
        expect(g.highKpa, 6000);
        expect(g.fitBar, [25, 40, 60]);
        expect(g.bestBar, 25);
      },
    );
    test('압력계: 10bar 시험 → 16·25·40, 12bar 시험 → 25·40 중 25', () {
      expect(gaugeRange(1000).fitBar, [16, 25, 40]);
      final g = gaugeRange(1200); // 1.5~4배 = 18~48bar, 2배 24bar
      expect(g.fitBar, [25, 40]);
      expect(g.bestBar, 25);
    });
    test('EN 837 눈금 표(WIKA IN 00.02)', () {
      expect(kEn837Bar.first, 0.6);
      expect(kEn837Bar.last, 1600);
      expect(kEn837Bar, containsAll([1.6, 2.5, 4, 6, 10, 16, 250, 400, 600]));
    });
    test('아주 낮은 시험압력은 맞는 눈금이 없을 수 있다', () {
      final g = gaugeRange(5); // 0.05bar → 0.075~0.2bar
      expect(g.fitBar, isEmpty);
      expect(g.bestBar, isNull);
    });
  });

  group('압력강하', () {
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
      // 시작 온도 20°C면 20°C 표준 환산 그대로
      expect(r.leakSccm, closeTo(r.leakPaM3s! * 9.8692 * 60, 1e-9));
    });
    test('표준 mL/min은 20°C·1기압: 시작 온도 40°C면 293.15/313.15를 곱한다', () {
      final r = pressureDecay(
        p1Kpa: 700,
        p2Kpa: 690,
        t1C: 40,
        t2C: 40,
        volumeL: 100,
        minutes: 60,
      );
      expect(r.t1K, closeTo(313.15, 1e-9));
      expect(
        r.leakSccm,
        closeTo(r.leakPaM3s! * 293.15 / 313.15 * 9.8692 * 60, 1e-9),
      );
      // 1 Pa·m³/s(20°C) = 1e6/101325 cm³/s = 592.2 mL/min
      final one = DecayResult(
        rawDropKpa: 0,
        correctedDropKpa: 0,
        tempEffectKpa: 0,
        t1K: 293.15,
        leakPaM3s: 1,
      );
      expect(one.leakSccm, closeTo(1e6 / 101325 * 60, 0.01));
    });
    test('허용 압력강하: 주면 보정한 강하로 합격/불합격, 없으면 판정 없음', () {
      final r = pressureDecay(p1Kpa: 700, p2Kpa: 690, t1C: 20, t2C: 20);
      expect(r.correctedDropKpa, closeTo(10, 1e-9));
      expect(r.passes(null), isNull);
      expect(r.passes(10), isTrue);
      expect(r.passes(15), isTrue);
      expect(r.passes(5), isFalse);
      // 온도가 내려 읽은 강하가 커도 보정한 강하로 판정
      final t = pressureDecay(p1Kpa: 700, p2Kpa: 672.66, t1C: 20, t2C: 10);
      expect(t.rawDropKpa, greaterThan(20));
      expect(t.passes(1), isTrue);
    });
    test('압력이 오르면 강하가 음수(화면에서 "상승")', () {
      final r = pressureDecay(p1Kpa: 700, p2Kpa: 705, t1C: 20, t2C: 20);
      expect(r.correctedDropKpa, closeTo(-5, 1e-9));
      expect(r.passes(0), isTrue);
    });
  });

  group('수압 물 온도', () {
    test('20°C, 강관 D/t=20 → 약 3.1 bar/°C, 5°C 근처는 거의 0 아래', () {
      final v = hydroBarPerDegC(waterC: 20, odMm: 21 * 5.0, wallMm: 5.0);
      expect(v, closeTo(3.1, 0.15));
      expect(hydroBarPerDegC(waterC: 5, odMm: 105, wallMm: 5), lessThan(0));
      // 단단한 관(벽이 아주 두꺼움)에 가까우면 3.7
      expect(
        hydroBarPerDegC(waterC: 20, odMm: 1000, wallMm: 499),
        closeTo(3.7, 0.1),
      );
    });
    test('5~50°C 밖은 끝 값으로 계산한다(화면에서 알림)', () {
      expect(kWaterMinC, 5);
      expect(kWaterMaxC, 50);
      expect(waterProps(-3), waterProps(5));
      expect(waterProps(70), waterProps(50));
    });
  });

  group('공압 저장 에너지·출입 통제 거리(PCC-2-2022)', () {
    test(
      'ABSA 예: 2172kPa(g), 0.5m³ → 약 1677kJ, R = 20·(2·TNT)^(1/3) = 18.5m < 30m',
      () {
        final e = storedEnergy(testKpa: 2172, volumeL: 500);
        expect(e.joules / 1000, closeTo(1677, 5));
        expect(e.tntKg, closeTo(1677e3 / 4266920, 0.01));
        expect(e.scaledM, closeTo(20 * math.pow(2 * e.tntKg, 1 / 3), 1e-9));
        expect(e.scaledM, closeTo(18.45, 0.05));
        expect(e.distanceM, 30);
        expect(e.beyondFixed, isFalse);
      },
    );
    test(
      'piping-world 예: 24" STD 600m, 10barg → 224MJ, TNT 52.5kg, 94.36m',
      () {
        final id = 609.6 - 2 * 9.53;
        final vol = pipeVolumeL(idMm: id, lengthM: 600);
        final e = storedEnergy(testKpa: 1000, volumeL: vol);
        expect(e.joules, closeTo(224.06e6, 0.2e6));
        expect(e.tntKg, closeTo(52.51, 0.05));
        expect(e.scaledM, closeTo(94.36, 0.05));
        // 135.5MJ < E ≤ 271MJ: 최소 60m보다 식 거리가 커서 식 거리
        expect(e.distanceM, closeTo(94.36, 0.05));
        expect(e.beyondFixed, isFalse);
      },
    );
    test('최소 거리: 135.5MJ 초과 271MJ 이하는 60m 이상', () {
      // 식 거리가 60m보다 작은 경우를 찾기 어려워(2·TNT) 60m 이상인지만 본다
      final e = storedEnergy(testKpa: 1000, volumeL: 110000);
      expect(e.joules, greaterThan(135.5e6));
      expect(e.joules, lessThanOrEqualTo(271e6));
      expect(e.distanceM, greaterThanOrEqualTo(60));
    });
    test('큰 에너지: 271MJ 초과면 식 거리', () {
      final e = storedEnergy(testKpa: 20000, volumeL: 50000);
      expect(e.beyondFixed, isTrue);
      expect(e.distanceM, e.scaledM);
    });
    test('공기·질소(k=1.4)는 식 II-2 그대로: 2.5·Pat·V·[1 − (Pa/Pat)^0.286]', () {
      for (final (pt, v) in [(2172.0, 500.0), (700.0, 30.0), (15000.0, 2.0)]) {
        final pat = pt + kAtmKpa;
        final old =
            2.5 * pat * 1000 * v / 1000 * (1 - math.pow(101 / pat, 0.286));
        expect(storedEnergy(testKpa: pt, volumeL: v).joules, old);
        expect(
          storedEnergy(testKpa: pt, volumeL: v, gas: TestGas.airN2).joules,
          old,
        );
      }
    });
    test('헬륨·아르곤(k=1.67): 식 II-1, 공기보다 작다', () {
      const pt = 2172.0, v = 500.0;
      const k = 1.67;
      final pat = pt + kAtmKpa;
      final want =
          1 /
          (k - 1) *
          pat *
          1000 *
          v /
          1000 *
          (1 - math.pow(101 / pat, (k - 1) / k));
      final he = storedEnergy(testKpa: pt, volumeL: v, gas: TestGas.monatomic);
      expect(he.joules, closeTo(want, 1e-6));
      expect(he.joules, closeTo(1210.1e3, 1e3));
      expect(he.joules, lessThan(storedEnergy(testKpa: pt, volumeL: v).joules));
      expect(TestGas.monatomic.k, 1.67);
      expect(TestGas.airN2.k, 1.4);
    });
    test('관 체적: ID 100mm 10m → 78.5L', () {
      expect(pipeVolumeL(idMm: 100, lengthM: 10), closeTo(78.54, 0.01));
    });
  });

  group('질소 용기', () {
    test('1000L, 10bar → 약 10.87Nm³, 47L·150bar 용기 1병 6.49Nm³ → 2병', () {
      final n = nitrogenNeed(testKpa: 1000, volumeL: 1000);
      expect(n.nm3, closeTo(1101.325 / 101.325, 1e-9));
      expect(n.perCylNm3, closeTo(0.047 * 14000 / 101.325, 1e-9));
      expect(n.cylinders, 2);
      // 가득 찬 용기(0bar까지)는 약 7Nm³
      expect(0.047 * 15000 / 101.325, closeTo(7, 0.1));
    });
    test('시험압력이 150bar 이상이면 용기만으로 못 채운다', () {
      final n = nitrogenNeed(testKpa: 15000, volumeL: 100);
      expect(n.cylinders, isNull);
      expect(n.perCylNm3, 0);
    });
    test('딱 맞으면 병 수를 올리지 않는다', () {
      final one = nitrogenNeed(testKpa: 1000, volumeL: 1000);
      final exact = nitrogenNeed(
        testKpa: 1000,
        volumeL: one.perCylNm3 * 3 / (1101.325 / 101.325) * 1000,
      );
      expect(exact.cylinders, 3);
    });
  });

  group('에어 누설', () {
    test('1/4" 구멍 100psig, Cd 1 → 104cfm(DOE 자료)', () {
      final lps = holeLeakLps(holeMm: 6.35, supplyKpa: 689.476, cd: 1);
      expect(lps * 2.11888, closeTo(104, 2)); // L/s → cfm
    });
    test('압축기 전력: 100cfm ≈ 18kW', () {
      final lps = 100 / 2.11888;
      expect(leakCompressorKw(lps), closeTo(18, 0.1));
    });
    test('식이 맞는 최소 공급 압력 0.9bar(초크 흐름 1.893배)', () {
      expect(kLeakMinKpa, 90);
      expect((kLeakMinKpa + kAtmKpa) / kAtmKpa, closeTo(1.89, 0.01));
    });
  });
}
