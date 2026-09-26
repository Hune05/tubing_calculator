// 유량 계산 식 시험: 손 계산(별도 스크립트로 푼 값)·교과서 관계와 비교.
// 근거: docs/유량계산_근거.md.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/flow/flow_calc.dart';
import 'package:tubing_calculator/src/presentation/flow/flow_data.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/tube_rating.dart';

void main() {
  group('단위', () {
    test('유량 단위 환산', () {
      expect(flowToM3s(60, FlowUnit.lpm), closeTo(0.001, 1e-12));
      expect(flowToM3s(3.6, FlowUnit.m3h), closeTo(0.001, 1e-12));
      // 1 US gal = 3.785411784 L
      expect(flowToM3s(1, FlowUnit.gpm)! * 60000, closeTo(3.785411784, 1e-9));
      expect(flowToM3s(3600, FlowUnit.kgh, rho: 1000), closeTo(0.001, 1e-12));
      expect(flowToM3s(1, FlowUnit.kgh), isNull);
      for (final u in FlowUnit.values) {
        final q = flowToM3s(12.5, u, rho: 8.3, rhoNormal: 1.29)!;
        expect(m3sToFlow(q, u, rho: 8.3, rhoNormal: 1.29), closeTo(12.5, 1e-9));
      }
    });

    test('Nm³/h: 기준 상태 밀도 비로 운전 상태 부피로 바꾼다', () {
      // 기준 밀도 1.25, 운전 밀도 10 → 운전 부피는 1/8
      expect(
        flowToM3s(80, FlowUnit.nm3h, rho: 10, rhoNormal: 1.25)! * 3600,
        closeTo(10, 1e-9),
      );
    });
  });

  group('물 성질 표', () {
    test('표 값 그대로 읽고 사이는 직선 보간', () {
      final r20 = kWaterTable.firstWhere((r) => r.$1 == 20);
      final s = waterState(20)!;
      expect(s.rho, r20.$2);
      expect(s.mu, closeTo(r20.$3 / 1000, 1e-15));
      final r25 = kWaterTable.firstWhere((r) => r.$1 == 25);
      expect(waterState(22.5)!.rho, closeTo((r20.$2 + r25.$2) / 2, 1e-9));
      expect(waterState(-1), isNull);
      expect(waterState(kWaterTable.last.$1 + 1), isNull);
    });

    test('물 20°C 밀도·점도는 IAPWS 값(998.2kg/m³, 1.0016mPa·s)과 같다', () {
      final s = waterState(20)!;
      expect(s.rho, closeTo(998.2, 0.05));
      expect(s.mu * 1000, closeTo(1.0016, 0.0005));
    });

    test('표는 온도 순서이고 밀도(4°C 위)·점도가 온도에 따라 준다', () {
      for (var i = 1; i < kWaterTable.length; i++) {
        expect(kWaterTable[i].$1, greaterThan(kWaterTable[i - 1].$1));
        expect(kWaterTable[i].$3, lessThan(kWaterTable[i - 1].$3));
        if (kWaterTable[i - 1].$1 >= 5) {
          expect(kWaterTable[i].$2, lessThan(kWaterTable[i - 1].$2));
        }
      }
    });
  });

  group('기체', () {
    test('이상기체 밀도: 공기 0°C 101.325kPa = 28.9647 / 22.414 ≈ 1.2923kg/m³', () {
      expect(
        idealGasDensity(101.325, 0, kAir.molarMass),
        closeTo(1.2923, 0.0002),
      );
    });

    test('게이지 7bar, 20°C 공기 → 절대 801.325kPa, 약 9.53kg/m³', () {
      final s = gasState(kAir, 700, 20)!;
      expect(s.pAbsKpa, closeTo(801.325, 1e-9));
      final expected = 801325 * 0.0289647 / (8.314462618 * 293.15);
      expect(s.rho, closeTo(expected, 0.01));
      expect(s.gas, isTrue);
    });

    test('Sutherland: 기준 온도에서 μ0, 20°C 공기 약 18.1µPa·s', () {
      expect(sutherlandMu(kAir, kAir.t0 - 273.15), closeTo(kAir.mu0, 1e-12));
      expect(sutherlandMu(kAir, 20) * 1e6, closeTo(18.2, 0.2));
      expect(sutherlandMu(kN2, 20) * 1e6, closeTo(17.6, 0.2));
    });
  });

  group('마찰 계수', () {
    test('층류는 64/Re', () {
      expect(darcyF(1000, 1e-4), closeTo(0.064, 1e-12));
    });

    test('Colebrook 반복 해는 식을 만족한다', () {
      for (final re in [5e3, 1e4, 1e5, 1e6, 1e7]) {
        for (final rr in [0.0, 1e-5, 1e-4, 1e-3, 1e-2]) {
          final f = colebrook(re, rr);
          final lhs = 1 / math.sqrt(f);
          final rhs =
              -2 * math.log(rr / 3.7 + 2.51 / (re * math.sqrt(f))) / math.ln10;
          expect(lhs, closeTo(rhs, 1e-9), reason: 'Re $re ε/D $rr');
        }
      }
    });

    test('Swamee–Jain은 Colebrook과 2% 이내, 구석(Re 5000·ε/D 0.01)만 2.83%', () {
      // 별도 스크립트(이분법 Colebrook)로 푼 최대 차이: Re 5000·ε/D 0.01에서 +2.83%, 그 밖은 1.6% 이하.
      for (final re in [5e3, 2e4, 1e5, 1e6, 1e7, 1e8]) {
        for (final rr in [1e-6, 1e-5, 1e-4, 1e-3, 1e-2]) {
          final c = colebrook(re, rr);
          final s = swameeJain(re, rr);
          final corner = re == 5e3 && rr == 1e-2;
          expect(
            (s - c).abs() / c,
            lessThan(corner ? 0.029 : 0.02),
            reason: 'Re $re ε/D $rr',
          );
        }
      }
      // 1/2" × 0.049 튜브 물 50L/min(Re 103,561, ε/D 1.47e-4): 0.18% 차이.
      final rr = 0.0015 / 10.2108;
      expect(
        (swameeJain(103561, rr) - colebrook(103561, rr)).abs() /
            colebrook(103561, rr),
        lessThan(0.005),
      );
    });

    test('매끈한 관 Re 1e5: f ≈ 0.0180 (Moody 선도)', () {
      expect(colebrook(1e5, 0), closeTo(0.0180, 0.0003));
    });

    test(
      '3-K 식(Darby): 90° 엘보 Re 1e5, 1": K = 800/1e5 + 0.14·(1 + 4/1) = 0.708',
      () {
        final elbow = kFittings.firstWhere((f) => f.id == 'elbow90');
        expect(elbow.k(1e5, 1), closeTo(0.708, 1e-12));
        // 2": Ki·(1 + Kd/2^0.3)
        expect(
          elbow.k(1e6, 2),
          closeTo(800 / 1e6 + 0.14 * (1 + 4 / math.pow(2, 0.3)), 1e-12),
        );
        final globe = kFittings.firstWhere((f) => f.id == 'globe');
        expect(globe.k(1e5, 1), closeTo(1500 / 1e5 + 1.7 * (1 + 3.6), 1e-12));
        // 입구·출구는 고정 K
        expect(
          kFittings.firstWhere((f) => f.id == 'entrance').k(100, 0.5),
          0.5,
        );
        expect(kFittings.firstWhere((f) => f.id == 'exit').k(1e6, 4), 1.0);
      },
    );

    test('호칭 글 → 인치', () {
      expect(nominalInch('1/8'), 0.125);
      expect(nominalInch('1-1/4'), 1.25);
      expect(nominalInch('2-1/2'), 2.5);
      expect(nominalInch('20'), 20);
      expect(nominalInch('x'), isNull);
    });
  });

  group('압력손실 손 계산', () {
    // 물 20°C, 50L/min, 1/2" × 0.049" 튜브(내경 10.2108mm), ε 0.0015mm, 직관 10m.
    // 별도 스크립트(이분법 Colebrook): v 10.1768m/s, Re 103,561, f 0.018632, ΔP 943.22kPa.
    final tube = tubeById('i1/2x049')!;
    final s = waterState(20)!;
    final q = flowToM3s(50, FlowUnit.lpm)!;

    test('유속·Re', () {
      expect(tube.idMm, closeTo(10.2108, 1e-9));
      final v = velocity(q, tube.idMm);
      expect(v, closeTo(10.1768, 0.0005));
      expect(reynolds(v, tube.idMm, s), closeTo(103561, 150));
      expect(regimeOf(reynolds(v, tube.idMm, s)), FlowRegime.turbulent);
    });

    test('직관 10m ΔP ≈ 943kPa, 100m당은 10배', () {
      final r = pressureDrop(
        qM3s: q,
        idMm: tube.idMm,
        fluid: s,
        lengthM: 10,
        roughMm: 0.0015,
      );
      expect(r.f, closeTo(0.018632, 0.00005));
      expect(r.straightKpa, closeTo(943.2, 3));
      expect(r.per100mKpa, closeTo(r.straightKpa * 10, 1e-9));
      expect(r.fittingKpa, 0);
      expect(r.elevKpa, 0);
    });

    test('피팅 K·높이 차: ΔP = K·ρv²/2, ρgh', () {
      final r = pressureDrop(
        qM3s: q,
        idMm: tube.idMm,
        fluid: s,
        lengthM: 0,
        roughMm: 0.0015,
        extraK: 2,
        dzM: 10,
      );
      expect(r.sumK, 2);
      expect(r.fittingKpa, closeTo(2 * s.rho * r.v * r.v / 2 / 1000, 1e-9));
      expect(r.elevKpa, closeTo(s.rho * 9.80665 * 10 / 1000, 1e-9));
      expect(r.totalKpa, closeTo(r.fittingKpa + r.elevKpa, 1e-9));
    });

    test('피팅 K 합 = Σ 개수 × K(Re, Dn) + 기타 K, Dn이 없으면 내경(인치)', () {
      final elbow = kFittings.firstWhere((f) => f.id == 'elbow90');
      final tee = kFittings.firstWhere((f) => f.id == 'teeBranch');
      final r = pressureDrop(
        qM3s: q,
        idMm: tube.idMm,
        fluid: s,
        lengthM: 10,
        roughMm: 0.0015,
        fittings: [(elbow, 3), (tee, 1)],
        extraK: 1.5,
      );
      final dn = tube.idMm / 25.4;
      final k = 3 * elbow.k(r.re, dn) + tee.k(r.re, dn) + 1.5;
      expect(r.sumK, closeTo(k, 1e-12));
      expect(r.fittingKpa, closeTo(k * s.rho * r.v * r.v / 2 / 1000, 1e-9));
    });

    test('층류(기름 100cSt, 10L/min, 내경 20mm): Hagen–Poiseuille와 같다', () {
      final oil = oilState(870, 100)!;
      final q2 = flowToM3s(10, FlowUnit.lpm)!;
      final r = pressureDrop(
        qM3s: q2,
        idMm: 20,
        fluid: oil,
        lengthM: 50,
        roughMm: 0.045,
      );
      expect(r.regime, FlowRegime.laminar);
      // ΔP = 128·μ·L·Q / (π·D⁴)
      final hp = 128 * oil.mu * 50 * q2 / (math.pi * math.pow(0.02, 4)) / 1000;
      expect(r.straightKpa, closeTo(hp, hp * 1e-9));
    });

    test('기체 판정(Crane): 10% 미만·10~40%·40% 초과', () {
      expect(gasDropCheck(50, 801.325), GasDropCheck.ok);
      expect(gasDropCheck(200, 801.325), GasDropCheck.useAverage);
      expect(gasDropCheck(400, 801.325), GasDropCheck.invalid);
    });

    test('권장 유속 최소 내경: v = Q/A가 vMax가 된다', () {
      final d = minIdForVelocity(q, 2.5);
      expect(velocity(q, d), closeTo(2.5, 1e-9));
    });
  });

  group('차압 유량계', () {
    test('Q = Qmax·√(ΔP/ΔPmax), 제곱근 관계 표', () {
      expect(dpToFlow(25, 100, 200), closeTo(100, 1e-9));
      expect(dpToFlow(50, 100, 100), closeTo(70.7107, 1e-4));
      expect(dpToFlow(0, 100, 100), 0);
      expect(flowToDp(50, 100, 100), closeTo(25, 1e-9));
      expect(flowToDp(75, 100, 100), closeTo(56.25, 1e-9));
      expect(dpToFlow(flowToDp(37, 25, 80), 25, 80), closeTo(37, 1e-9));
    });
  });

  group('ISO 5167-2 오리피스', () {
    test(
      'fluids 공개 예제: C_Reader_Harris_Gallagher(D 0.07391, d 0.0222, 플랜지) = 0.5990326277',
      () {
        // rho 1.165, mu 1.85e-5, m 0.12kg/s → ReD = 4m/(π·μ·D)
        const d = 73.91;
        final re = 4 * 0.12 / (math.pi * 1.85e-5 * 0.07391);
        expect(
          rhgC(22.2 / d, re, d, OrificeTap.flange),
          closeTo(0.5990326277163659, 1e-12),
        );
      },
    );

    test(
      'simupipe 공개 예제: D 100 d 50 플랜지 탭 10kPa 물 20°C → 19.84m³/h, C 0.60711, 손실 7.32kPa',
      () {
        final r = orificeFlow(
          dPipeMm: 100,
          dBoreMm: 50,
          dpKpa: 10,
          fluid: waterState(20)!,
          tap: OrificeTap.flange,
        )!;
        expect(r.beta, 0.5);
        expect(r.qM3s * 3600, closeTo(19.84, 0.01));
        expect(r.c, closeTo(0.60711, 0.00002));
        expect(r.reD, closeTo(69917, 60));
        expect(r.lossKpa, closeTo(7.32, 0.01));
        expect(r.outOfRange, isEmpty);
        expect(r.uncertaintyPct, 0.5);
      },
    );

    test('fluids dP_orifice 예제: 영구 압력손실 9069.4747Pa', () {
      // D 0.07366, d 0.05, ΔP 17kPa, C 0.61512 (식만 확인)
      const beta = 50 / 73.66;
      const c = 0.61512;
      final b4 = math.pow(beta, 4);
      final s = math.sqrt(1 - b4 * (1 - c * c));
      final loss = (s - c * beta * beta) / (s + c * beta * beta) * 17000;
      expect(loss, closeTo(9069.474705745388, 1e-6));
    });

    test('적용 범위 밖이면 항목을 알려 준다(작은 관·낮은 Re)', () {
      final r = orificeFlow(
        dPipeMm: 30,
        dBoreMm: 10,
        dpKpa: 50,
        fluid: oilState(870, 46)!,
        tap: OrificeTap.flange,
      )!;
      expect(
        r.outOfRange,
        containsAll(['d ≥ 12.5mm', '50mm ≤ D ≤ 1000mm', 'ReD ≥ 5000']),
      );
      expect(r.uncertaintyPct, isNull);
      expect(
        orificeFlow(
          dPipeMm: 50,
          dBoreMm: 60,
          dpKpa: 10,
          fluid: waterState(20)!,
          tap: OrificeTap.corner,
        ),
        isNull,
      );
    });

    test(
      '71.12mm 미만 보정 항: D 52.5 d 26.25 코너 탭 → C = 기본식 + 0.011(0.75−β)(2.8−D/25.4)',
      () {
        const re = 58333.0;
        final withTerm = rhgC(0.5, re, 52.5, OrificeTap.corner);
        final noTerm = rhgC(
          0.5,
          re,
          80,
          OrificeTap.corner,
        ); // 코너 탭은 D가 식에 이 항으로만 들어간다
        expect(
          withTerm - noTerm,
          closeTo(0.011 * 0.25 * (2.8 - 52.5 / 25.4), 1e-12),
        );
      },
    );
  });
}
