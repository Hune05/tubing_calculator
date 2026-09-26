// 튜브 허용 사용압력(tube_rating.dart): B31.3 304.1.2 식, 표 A-1 S 보간, A269 허용차, 제조사 표 값
// (Swagelok MS-01-107 Rev W 표 1·3·4)과의 대조, 항복 압력, 체적. 09-26 독립 검증 반영 항목
// (Kell 닫힌 식, 매설(축 구속), B31.1 공압 안전밸브, 조항 번호 고침)도 여기서 본다.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/pressure_calc.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/test_record.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/test_record_pdf.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/tube_rating.dart';

TubeSize tube(String id) => tubeById(id)!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // 기록서 PDF 글꼴(asset)
  group('튜브 목록', () {
    test('인치 23개(1/8"~1"), mm 17개(6~25mm), id가 겹치지 않는다', () {
      expect(tubeSizes(TubeSystem.inch).length, 23);
      expect(tubeSizes(TubeSystem.metric).length, 17);
      expect(kTubeSizes.map((t) => t.id).toSet().length, kTubeSizes.length);
      expect(tube(kTubeDefaultInch).label, '1/4" × 0.035"');
      expect(tube(kTubeDefaultMetric).label, '12 × 1.5 mm');
      for (final od in ['1/8', '1/4', '3/8', '1/2', '3/4', '1']) {
        expect(
          tubeSizes(TubeSystem.inch).where((t) => t.odText == od),
          isNotEmpty,
          reason: od,
        );
      }
    });
    test('치수: 1/4" × 0.035" = 6.35 × 0.889mm, 내경 4.572mm', () {
      final t = tube('i1/4x035');
      expect(t.odMm, closeTo(6.35, 1e-9));
      expect(t.wallMm, closeTo(0.889, 1e-9));
      expect(t.idMm, closeTo(4.572, 1e-9));
      expect(
        tubeSpecText(t, TubeMaterial.ss316),
        'SS316 (ASTM A269/A213) 1/4" × 0.035" (6.35 × 0.89 mm)',
      );
      expect(
        tubeSpecText(tube('m12x1.5'), TubeMaterial.cs),
        '탄소강 (ASTM A179) 12 × 1.5 mm',
      );
    });
    test('mm 탄소강은 제조사 값이 없다(Swagelok 표 2는 EN 10305-1 관)', () {
      for (final t in tubeSizes(TubeSystem.metric)) {
        expect(t.makerKpa(TubeMaterial.cs), isNull, reason: t.id);
        expect(t.makerKpa(TubeMaterial.ss316), isNotNull, reason: t.id);
      }
      for (final t in tubeSizes(TubeSystem.inch)) {
        expect(t.makerKpa(TubeMaterial.cs), isNotNull, reason: t.id);
      }
      expect(tube('i1/4x035').makerText(TubeMaterial.ss316), '5100 psig');
      expect(tube('m12x1.5').makerText(TubeMaterial.ss316), '330 bar');
      expect(
        tube('i1/4x035').makerSource(TubeMaterial.ss316),
        'Swagelok MS-01-107 표 3, 5쪽',
      );
      expect(
        tube('m12x1.5').makerSource(TubeMaterial.ss316),
        'Swagelok MS-01-107 표 4, 6쪽',
      );
      expect(
        tube('i1/4x035').makerSource(TubeMaterial.cs),
        'Swagelok MS-01-107 표 1, 3쪽',
      );
    });
  });

  group('허용 응력 S(B31.3-2018 표 A-1)', () {
    test('SS316: 300°F까지 20.0, 400°F 19.3, 800°F 15.9, 사이는 직선 보간', () {
      const m = TubeMaterial.ss316;
      expect(tubeAllowableKsi(m, 20), 20.0);
      expect(tubeAllowableKsi(m, fToC(300)), closeTo(20.0, 1e-9));
      expect(tubeAllowableKsi(m, fToC(400)), closeTo(19.3, 1e-9));
      expect(tubeAllowableKsi(m, fToC(500)), closeTo(18.0, 1e-9));
      expect(tubeAllowableKsi(m, fToC(650)), closeTo(16.6, 1e-9));
      expect(tubeAllowableKsi(m, fToC(800)), closeTo(15.9, 1e-9));
      expect(tubeAllowableKsi(m, fToC(450)), closeTo((19.3 + 18.0) / 2, 1e-9));
      expect(tubeAllowableKsi(m, -254), 20.0);
      expect(tubeAllowableKsi(m, -255), isNull);
    });
    test(
      '탄소강 A179: 200°F까지 15.7, 300°F 15.3, 400°F 14.8, 800°F 9.2, −29°C 미만은 없음',
      () {
        const m = TubeMaterial.cs;
        expect(tubeAllowableKsi(m, fToC(200)), closeTo(15.7, 1e-9));
        expect(tubeAllowableKsi(m, fToC(300)), closeTo(15.3, 1e-9));
        expect(tubeAllowableKsi(m, fToC(400)), closeTo(14.8, 1e-9));
        expect(tubeAllowableKsi(m, fToC(750)), closeTo(10.7, 1e-9));
        expect(tubeAllowableKsi(m, fToC(800)), closeTo(9.2, 1e-9));
        expect(tubeAllowableKsi(m, -29), 15.7);
        expect(tubeAllowableKsi(m, -30), isNull);
      },
    );
    test('427°C(800°F)까지, 넘으면 계산하지 않는다', () {
      for (final m in TubeMaterial.values) {
        expect(tubeAllowableKsi(m, 427), isNotNull);
        expect(tubeAllowableKsi(m, 428), isNull);
        expect(
          tubeRating(size: tube('i1/2x049'), material: m, designC: 428),
          isNull,
        );
      }
      expect(tubeTempRangeText(TubeMaterial.ss316), '-254~427°C');
      expect(tubeTempRangeText(TubeMaterial.cs), '-29~427°C');
    });
  });

  group('계산 값(304.1.2, 최대 외경·최소 두께)', () {
    test('허용차: SS316 외경 12.7mm 미만 −15%, 이상 −10%, 탄소강은 그대로, 외경 +0.13mm', () {
      expect(
        tubeMinWallMm(tube('i3/8x049'), TubeMaterial.ss316),
        closeTo(0.049 * 25.4 * 0.85, 1e-9),
      );
      expect(
        tubeMinWallMm(tube('i1/2x049'), TubeMaterial.ss316),
        closeTo(0.049 * 25.4 * 0.90, 1e-9),
      );
      expect(
        tubeMinWallMm(tube('m12x1.5'), TubeMaterial.ss316),
        closeTo(1.275, 1e-9),
      );
      expect(
        tubeMinWallMm(tube('m14x2'), TubeMaterial.ss316),
        closeTo(1.8, 1e-9),
      );
      expect(tubeMinWallMm(tube('m12x1.5'), TubeMaterial.cs), 1.5);
      expect(tubeMaxOdMm(tube('i1/4x035')), closeTo(0.255 * 25.4, 1e-9));
      expect(tubeMaxOdMm(tube('m12x1.5')), closeTo(12.13, 1e-9));
    });
    test('식: P = 2·S·t/(D − 2·0.4·t), 두꺼우면(t ≥ D/6) Y = d/(D + d) = Lamé', () {
      // 1/2" × 0.049" SS316: D = 0.505", t = 0.0441" → 3755 psi
      final r = tubeRating(
        size: tube('i1/2x049'),
        material: TubeMaterial.ss316,
      )!;
      const d = 0.505, t = 0.049 * 0.9;
      expect(r.calcKpa / kPsiKpa, closeTo(2 * 20000 * t / (d - 0.8 * t), 1e-6));
      expect(r.thick, isFalse);
      // 1/8" × 0.035" SS316: D = 0.130", t = 0.02975" ≥ D/6 → Lamé 10910 psi
      final k = tubeRating(
        size: tube('i1/8x035'),
        material: TubeMaterial.ss316,
      )!;
      const dd = 0.130, tt = 0.035 * 0.85, di = dd - 2 * tt;
      expect(k.thick, isTrue);
      expect(
        k.calcKpa / kPsiKpa,
        closeTo(20000 * (dd * dd - di * di) / (dd * dd + di * di), 1e-6),
      );
      expect(k.calcKpa / kPsiKpa, closeTo(10910, 1));
    });
    test('SS316 인치: 계산 값을 100psi 아래로 버리면 Swagelok 표 3 값과 모두 같다', () {
      for (final t in tubeSizes(TubeSystem.inch)) {
        final r = tubeRating(size: t, material: TubeMaterial.ss316)!;
        final psi = r.calcKpa / kPsiKpa;
        expect((psi / 100).floor() * 100, t.swSs, reason: t.id);
      }
    });
    test(
      '탄소강 인치: 계산 값이 Swagelok 표 1 값 이상, 100psi 미만 차이(외경 허용차를 0.13mm로 조금 크게 봐 1/8" × 0.035"만 14psi 작다)',
      () {
        for (final t in tubeSizes(TubeSystem.inch)) {
          final r = tubeRating(size: t, material: TubeMaterial.cs)!;
          final psi = r.calcKpa / kPsiKpa;
          expect(psi - t.swCs!, inInclusiveRange(-20, 99.99), reason: t.id);
        }
      },
    );
    test('허용 사용압력 = 계산 값과 제조사 표 값 중 작은 것', () {
      // 1/4" × 0.035" SS316: 제조사 5100psig(351.63bar) < 계산 5147psi
      final a = tubeRating(
        size: tube('i1/4x035'),
        material: TubeMaterial.ss316,
      )!;
      expect(a.makerKpa, closeTo(5100 * kPsiKpa, 1e-9));
      expect(a.allowKpa, a.makerKpa);
      expect(a.makerGoverns, isTrue);
      expect(a.allowKpa / 100, closeTo(351.63, 0.01));
      // 12 × 1.5mm SS316: A269 허용차 계산 316.5bar < 제조사 330bar(EN ISO 1127 T4 기준)
      final b = tubeRating(
        size: tube('m12x1.5'),
        material: TubeMaterial.ss316,
      )!;
      expect(b.makerKpa, 33000);
      expect(b.allowKpa, b.calcKpa);
      expect(b.allowKpa / 100, closeTo(316.5, 0.1));
      expect(b.makerGoverns, isFalse);
      // mm 탄소강: 제조사 값 없이 계산 값
      final c = tubeRating(size: tube('m12x1.5'), material: TubeMaterial.cs)!;
      expect(c.makerKpa, isNull);
      expect(c.makerTableKpa, isNull);
      expect(c.allowKpa, c.calcKpa);
      // 공칭 두께 값은 참고로만(최소 두께 값보다 크다)
      expect(a.nominalKpa, greaterThan(a.calcKpa));
    });
    test('설계 온도가 38°C를 초과하면 제조사 값(−28~37°C)은 비교에서 빼고 S를 보간', () {
      final r = tubeRating(
        size: tube('i1/2x049'),
        material: TubeMaterial.ss316,
        designC: 300,
      )!;
      expect(r.makerKpa, isNull);
      expect(r.makerTableKpa, closeTo(3700 * kPsiKpa, 1e-9));
      // 300°C = 572°F: 500°F 18.0과 600°F 17.0 사이
      final s = 18.0 + (17.0 - 18.0) * (cToF(300) - 500) / 100;
      expect(r.sKsi, closeTo(s, 1e-9));
      expect(r.allowKpa, r.calcKpa);
      expect(r.stRatio, closeTo(20 / s, 1e-9));
      // 38°C·−29°C는 제조사 온도 안
      for (final c in [38.0, -29.0]) {
        expect(
          tubeRating(
            size: tube('i1/2x049'),
            material: TubeMaterial.ss316,
            designC: c,
          )!.makerKpa,
          isNotNull,
          reason: '$c',
        );
      }
      // 비우면 38°C 이하
      final e = tubeRating(
        size: tube('i1/2x049'),
        material: TubeMaterial.ss316,
      )!;
      expect(e.designC, closeTo(fToC(100), 1e-9));
      expect(e.stRatio, 1);
    });
    test('항복 압력(345.2.1(a)): 최소 항복강도(SS316 30ksi, A179 26ksi)로 같은 식', () {
      final r = tubeRating(
        size: tube('i1/4x035'),
        material: TubeMaterial.ss316,
      )!;
      expect(r.yieldKpa, closeTo(r.calcKpa * 30 / 20, 1e-6));
      expect(r.yield90Kpa, closeTo(0.9 * r.yieldKpa, 1e-9));
      final c = tubeRating(size: tube('i1/4x035'), material: TubeMaterial.cs)!;
      expect(c.yieldKpa, closeTo(c.calcKpa * 26 / 15.7, 1e-6));
      // 수압 1.5 × 허용 사용압력은 항복 압력 이내(SS316 S = ⅔Sy)
      for (final t in kTubeSizes) {
        final x = tubeRating(size: t, material: TubeMaterial.ss316)!;
        expect(
          1.5 * x.allowKpa,
          lessThanOrEqualTo(x.yieldKpa + 1e-6),
          reason: t.id,
        );
      }
    });
    test('체적: 1/4" × 0.035" 100m → 1.642L, 구간을 더한다', () {
      final t = tube('i1/4x035');
      expect(
        tubeVolumeL([(t, 100)]),
        closeTo(math.pi / 4 * 4.572e-3 * 4.572e-3 * 100 * 1000, 1e-9),
      );
      expect(tubeVolumeL([(t, 100)]), closeTo(1.6417, 1e-4));
      final u = tube('i1/2x049');
      expect(
        tubeVolumeL([(t, 100), (u, 20), (u, 0)]),
        closeTo(tubeVolumeL([(t, 100)]) + tubeVolumeL([(u, 20)]), 1e-12),
      );
    });
  });

  group('09-26 독립 검증 반영', () {
    test('Kell(1975) 닫힌 식: 표 III 값과 같다(5·10·20·50°C), 4°C 근처 β ≈ 0', () {
      for (final (t, b, k) in [
        (5.0, 16.0, 49.17),
        (10.0, 87.97, 47.81),
        (20.0, 206.78, 45.89),
        (30.0, 303.24, 44.77),
        (50.0, 457.59, 44.17),
      ]) {
        final (beta, kappa) = waterProps(t);
        expect(beta * 1e6, closeTo(b, 0.02), reason: '$t');
        expect(kappa * 1e6, closeTo(k, 0.01), reason: '$t');
      }
      expect(waterProps(3.98).$1.abs(), lessThan(0.1e-6));
      expect(waterProps(0).$1, lessThan(0));
      expect(waterDensity(20), closeTo(998.2041, 1e-3));
      // β = −(1/ρ)dρ/dT (수치 미분과 같은지)
      for (final t in [2.0, 25.0, 60.0, 95.0]) {
        const h = 1e-4;
        final num =
            -(waterDensity(t + h) - waterDensity(t - h)) /
            (2 * h) /
            waterDensity(t);
        expect(waterProps(t).$1, closeTo(num, 1e-9), reason: '$t');
      }
    });
    test('매설(축 구속): (β − 2α)/(κ + D(1 − ν²)/(E·t)), 지상보다 약 6~7% 크다', () {
      final free = hydroBarPerDegC(waterC: 20, odMm: 105, wallMm: 5);
      final res = hydroBarPerDegC(
        waterC: 20,
        odMm: 105,
        wallMm: 5,
        restrained: true,
      );
      final (b, k) = waterProps(20);
      expect(
        res,
        closeTo((b - 2 * 11.7e-6) / (k + 105 * 0.91 / (2.0e6 * 5)), 1e-12),
      );
      expect(res / free, inInclusiveRange(1.06, 1.07));
    });
    test('B31.1 공압: 안전밸브 설정압력 한도 1.5P(1⅓·PT는 늘 초과), 시험압력 값은 그대로', () {
      final p = testPlan(
        code: PipingCode.b311,
        medium: TestMedium.pneumatic,
        designKpa: 1000,
      );
      expect(p.reliefCapKpa, 1500);
      expect(p.minKpa, 1200);
      expect(p.maxKpa, 1500);
      expect(p.reliefRecKpa, isNull);
      expect(p.notes.join(), contains('1.5P(최대 시험압력) 이하로 둡니다(137.2.6)'));
      for (final (c, m) in [
        (PipingCode.b313, TestMedium.hydro),
        (PipingCode.b313, TestMedium.pneumatic),
        (PipingCode.b311, TestMedium.hydro),
      ]) {
        expect(
          testPlan(code: c, medium: m, designKpa: 1000).reliefCapKpa,
          isNull,
        );
      }
    });
    test(
      '조항 번호: 발주처 판단 345.1(b), 저장 에너지 345.5.1, 345.5.4 90%·1.35배, 예비 공기 345.2.1(c)',
      () {
        final pn = testPlan(
          code: PipingCode.b313,
          medium: TestMedium.pneumatic,
          designKpa: 1000,
        ).notes.join('\n');
        expect(pn, contains('수압 시험을 할 수 없다고 판단할 때 대신합니다(345.1(b))'));
        expect(pn, contains('취성 파괴 위험에 특히 주의합니다(345.5.1)'));
        expect(pn, contains('345.2.1(a) 압력의 90%'));
        expect(pn, contains('1.35배'));
        final hy = testPlan(
          code: PipingCode.b313,
          medium: TestMedium.hydro,
          designKpa: 1000,
        ).notes.join('\n');
        expect(
          hy,
          contains('170kPa(25psi) 이하 공기로 큰 누설을 찾을 수 있습니다(345.2.1(c))'),
        );
        expect(hy, contains('다이얼 압력계 기준'));
        expect(hy, contains('발주처 승인 시 더 길게'));
        final b1 = testPlan(
          code: PipingCode.b311,
          medium: TestMedium.hydro,
          designKpa: 1000,
        ).notes.join('\n');
        expect(b1, contains('137.1.4·137.4.5 한도를 넘지 않는 범위에서입니다(137.2.6)'));
        expect(b1, contains('발주처 승인, 용접부 100% 체적 검사(RT·UT)'));
        expect(kGaugeDialNote, contains('디지털 압력계'));
        expect(kGaugeCalNote, contains('발주처가 승인하면'));
      },
    );
  });

  group('기록의 튜브 규격', () {
    test('JSON으로 저장했다 읽어도 같다, 이전 기록은 빈 값', () {
      final r = PtRecord(
        id: 't',
        date: DateTime(2026, 9, 26),
        line: 'IT-101',
        tubeId: 'i1/4x035',
        tubeSpec: tubeSpecText(tube('i1/4x035'), TubeMaterial.ss316),
        tubeMat: 'ss316',
      );
      final back = PtRecord.fromJson(r.toJson());
      expect(back.tubeId, 'i1/4x035');
      expect(back.tubeSpec, r.tubeSpec);
      expect(back.tubeMat, 'ss316');
      final old = PtRecord.fromJson({'id': 'o', 'line': 'L'});
      expect(old.tubeId, '');
      expect(old.tubeSpec, '');
    });
    test('기록서 PDF가 튜브 규격과 함께 만들어진다', () async {
      final r = PtRecord(
        id: 't',
        date: DateTime(2026, 9, 26),
        line: 'IT-101',
        tubeSpec: tubeSpecText(tube('i1/2x049'), TubeMaterial.ss316),
      );
      final bytes = await buildPtRecordPdf(r);
      expect(bytes.length, greaterThan(1000));
    });
    test('CSV에 "튜브 규격" 칸', () {
      final r = PtRecord(
        id: 't',
        date: DateTime(2026, 9, 26),
        line: 'IT-101',
        tubeSpec: tubeSpecText(tube('m12x1.5'), TubeMaterial.cs),
      );
      final lines = ptRecordsCsv([r]).substring(1).trimRight().split('\r\n');
      expect(lines[0], contains(',시험 구간,튜브 규격,규격,'));
      expect(lines[1], contains(',탄소강 (ASTM A179) 12 × 1.5 mm,B31.3,'));
    });
  });

  group('B31.1 튜브 허용 사용압력(104.1.2 식 (9), 표 A-3·A-1)', () {
    const b311 = PipingCode.b311;
    test('S: SS316은 표 A-3 A213 TP316 주 (10) 줄, 탄소강은 표 A-1 A179', () {
      const ss = TubeMaterial.ss316, cs = TubeMaterial.cs;
      expect(tubeAllowableKsi(ss, 20, code: b311), 20.0);
      expect(tubeAllowableKsi(ss, fToC(200), code: b311), closeTo(17.3, 1e-9));
      expect(tubeAllowableKsi(ss, fToC(400), code: b311), closeTo(14.3, 1e-9));
      expect(tubeAllowableKsi(ss, fToC(650), code: b311), closeTo(12.3, 1e-9));
      expect(tubeAllowableKsi(ss, fToC(800), code: b311), closeTo(11.8, 1e-9));
      // 450°F: (14.3 + 13.3)/2
      expect(tubeAllowableKsi(ss, fToC(450), code: b311), closeTo(13.8, 1e-9));
      // 350°C = 662°F: 650°F 12.3과 700°F 12.1 사이
      expect(
        tubeAllowableKsi(ss, 350, code: b311),
        closeTo(12.3 - 0.2 * (662 - 650) / 50, 1e-9),
      );
      expect(tubeAllowableKsi(cs, 20, code: b311), 13.4);
      expect(tubeAllowableKsi(cs, fToC(500), code: b311), closeTo(13.4, 1e-9));
      expect(tubeAllowableKsi(cs, fToC(600), code: b311), closeTo(13.3, 1e-9));
      expect(tubeAllowableKsi(cs, fToC(750), code: b311), closeTo(10.7, 1e-9));
      expect(tubeAllowableKsi(cs, fToC(800), code: b311), closeTo(9.2, 1e-9));
      // B31.3 값은 그대로
      expect(tubeAllowableKsi(ss, fToC(200)), closeTo(20.0, 1e-9));
      expect(tubeAllowableKsi(cs, 20), 15.7);
    });
    test('온도 범위: 두 재질 모두 −29~427°C', () {
      for (final m in TubeMaterial.values) {
        expect(tubeAllowableKsi(m, -29, code: b311), isNotNull);
        expect(tubeAllowableKsi(m, -30, code: b311), isNull);
        expect(tubeAllowableKsi(m, 427, code: b311), isNotNull);
        expect(tubeAllowableKsi(m, 428, code: b311), isNull);
        expect(tubeTempRangeText(m, code: b311), '-29~427°C');
        expect(
          tubeRating(
            size: tube('i1/4x035'),
            material: m,
            designC: -40,
            code: b311,
          ),
          isNull,
        );
      }
      // B31.3 SS316은 −254°C까지 그대로
      expect(tubeAllowableKsi(TubeMaterial.ss316, -100), 20.0);
    });
    test('손 계산: 1/4" × 0.035" SS316 38°C 이하 5147psi(제조사 5100), 200°F 4452psi', () {
      // D = 0.255", t = 0.035 × 0.85 = 0.02975", y = 0.4
      // P = 2 × 20000 × 0.02975 / (0.255 − 0.8 × 0.02975) = 1190 / 0.2312 = 5147.06
      final r = tubeRating(
        size: tube('i1/4x035'),
        material: TubeMaterial.ss316,
        code: b311,
      )!;
      expect(r.code, b311);
      expect(r.calcKpa / kPsiKpa, closeTo(5147.06, 0.01));
      expect(r.thick, isFalse);
      expect(r.makerGoverns, isTrue);
      expect(r.allowKpa / kPsiKpa, closeTo(5100, 1e-9));
      expect(r.stressTableText, 'B31.1 표 A-3, A213 TP316');
      // 200°F: S 17.3 → 2 × 17300 × 0.02975 / 0.2312 = 4452.21, 제조사 값은 비교하지 않음
      final h = tubeRating(
        size: tube('i1/4x035'),
        material: TubeMaterial.ss316,
        designC: fToC(200),
        code: b311,
      )!;
      expect(h.calcKpa / kPsiKpa, closeTo(4452.21, 0.01));
      expect(h.makerKpa, isNull);
      expect(h.allowKpa, h.calcKpa);
    });
    test('손 계산: 1/4" × 0.035" 탄소강 4132psi, 제조사 4800보다 낮아 계산값', () {
      // D = 0.255", t = 0.035"(A179 그대로): 2 × 13400 × 0.035 / (0.255 − 0.028) = 938 / 0.227 = 4132.16
      final r = tubeRating(
        size: tube('i1/4x035'),
        material: TubeMaterial.cs,
        code: b311,
      )!;
      expect(r.calcKpa / kPsiKpa, closeTo(4132.16, 0.01));
      expect(r.makerGoverns, isFalse);
      expect(r.allowKpa, r.calcKpa);
      expect(r.stressTableText, 'B31.1 표 A-1, A179');
      // 같은 튜브 B31.3은 15.7ksi 4841psi라 제조사 4800이 정한다
      final b313 = tubeRating(
        size: tube('i1/4x035'),
        material: TubeMaterial.cs,
      )!;
      expect(b313.calcKpa / kPsiKpa, closeTo(1099 / 0.227, 0.01));
      expect(b313.allowKpa / kPsiKpa, closeTo(4800, 1e-9));
    });
    test('손 계산: Do/tm < 6이면 y = d/(d + Do). 1/8" × 0.035" SS316 10909psi', () {
      // D = 0.130", t = 0.02975", d = 0.0705", y = 0.0705 / 0.2005 = 0.35162
      // P = 1190 / (0.130 − 2 × 0.35162 × 0.02975) = 1190 / 0.109079 = 10909.5
      final r = tubeRating(
        size: tube('i1/8x035'),
        material: TubeMaterial.ss316,
        code: b311,
      )!;
      expect(r.thick, isTrue);
      expect(r.calcKpa / kPsiKpa, closeTo(10909.5, 0.1));
      // 두꺼운 벽에서 y = d/(d + Do)는 B31.3 Lamé 값과 같다
      expect(
        r.calcKpa,
        closeTo(
          tubeRating(
            size: tube('i1/8x035'),
            material: TubeMaterial.ss316,
          )!.calcKpa,
          1e-6,
        ),
      );
      // 경계: Do/tm가 정확히 6이면 B31.1은 y = 0.4(6 미만만), B31.3은 두꺼운 벽
      expect(isThickWall311(6, 1), isFalse);
      expect(isThickWall(6, 1), isTrue);
      expect(
        b311TubeKpa(odMm: 6, tMm: 1, sKsi: 20),
        closeTo(2 * 20 * kKsiKpa / (6 - 0.8), 1e-6),
      );
    });
    test('mm 튜브: 12 × 1.5 SS316 B31.1 = B31.3과 같은 38°C 값(S 20ksi 같음)', () {
      final a = tubeRating(
        size: tube('m12x1.5'),
        material: TubeMaterial.ss316,
        code: b311,
      )!;
      final b = tubeRating(
        size: tube('m12x1.5'),
        material: TubeMaterial.ss316,
      )!;
      expect(a.calcKpa, closeTo(b.calcKpa, 1e-9));
      // 100°C(212°F): B31.1 S = 17.3 − 1.7 × 12/100 = 17.096 → B31.3(20.0)보다 낮다
      final c = tubeRating(
        size: tube('m12x1.5'),
        material: TubeMaterial.ss316,
        designC: 100,
        code: b311,
      )!;
      expect(c.sKsi, closeTo(17.3 - 1.7 * 12 / 100, 1e-9));
      // D = 12.13, t = 1.275: P = 2 × S × t / (D − 0.8t)
      expect(
        c.calcKpa,
        closeTo(2 * c.sKsi * kKsiKpa * 1.275 / (12.13 - 0.8 * 1.275), 1e-6),
      );
    });
  });
}
