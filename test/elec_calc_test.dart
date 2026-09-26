// 전기 계산기 계산: 표 값, 보정, 전압강하, 전선·차단기 선정, 회로 점검, 역률.
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
    test('전선 선정: 380V 삼상 30A 차단기, F-CV 트레이(E) 50m → 2.5sq(32A ≥ 30A)', () {
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
    test('전선 선정: 길면 전압강하가 굵기를 정한다', () {
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
    test(
      'D.1 온도: 40 이하 1.0(현행 2016판에 30·35°C 없음), 45 0.91, 52 → 55 칸 0.71, 61 → null',
      () {
        expect(panelTempFactor(30), 1.0);
        expect(panelTempFactor(35), 1.0);
        expect(panelTempFactor(45), 0.91);
        expect(panelTempFactor(52), 0.71);
        expect(panelTempFactor(61), isNull);
      },
    );
    test('D.2 회로 수: B1 3개 → 4 칸 0.65, E 9개 0.72, 12개는 B.52.17', () {
      expect(panelGroupFactor(3, InstallMethod.b1), 0.65);
      expect(panelGroupFactor(9, InstallMethod.e), 0.72);
      expect(panelGroupFactor(12, InstallMethod.b1), 0.45);
    });
    test(
      '반 내부 8A 부하, 덕트(B1), 50°C, 6회로 → 차단기 10A, 2.5sq(18.3×0.82×0.57=8.55 < 10 → 4sq)',
      () {
        final c = chooseCable(
          load: 8,
          volts: 380,
          phase: Phase.three,
          ins: Insulation.xlpe90, // 표 6은 PVC로 바꿔 계산
          method: InstallMethod.b1,
          lengthM: 5,
          ambientC: 50,
          circuits: 6,
          table: AmpacityTable.panel60204,
        );
        expect(c.breaker, 10);
        expect(c.sizeByAmpacity, 4); // 24×0.82×0.57 = 11.2 ≥ 10
      },
    );
  });

  group('전동기 표', () {
    test('NEC 430.250: 15HP 460V 21A, 230V 42A; 100HP 460V 124A', () {
      expect(necRow(15)!.a460, 21);
      expect(necRow(15)!.a230, 42);
      expect(necRow(100)!.a460, 124);
      expect(necRow(13), isNull);
    });
    test('IE3 380V 예: 11kW 22.2A, 식으로 다시 계산해도 1% 이내', () {
      final r = ie3Row(11)!;
      expect(r.a380, 22.2);
      expect(r.a440, 19.2);
      final i = loadCurrent(
        kw: 11,
        volts: 380,
        phase: Phase.three,
        pf: r.pf,
        eff: r.eff / 100,
      );
      expect((i - r.a380).abs() / r.a380, lessThan(0.01));
    });
  });

  group('2026-09-26 점검 반영', () {
    test('B.52.10 PVC 3가닥 방법 E: 70mm² 196, 120mm² 276(세 출처)', () {
      expect(baseAmpacity(70, Insulation.pvc70, 3, InstallMethod.e), 196);
      expect(baseAmpacity(120, Insulation.pvc70, 3, InstallMethod.e), 276);
      expect(baseAmpacity(70, Insulation.pvc70, 2, InstallMethod.e), 232);
    });

    test('리액턴스는 60Hz 0.096 Ω/km(50Hz 0.08의 1.2배)', () {
      expect(kReactanceOhmPerKm, 0.096);
      expect(kReactanceOhmPerKm / kReactance50HzOhmPerKm, closeTo(1.2, 1e-9));
      // 역률 0.8, 95mm² 삼상 100A 100m: X 항이 0.096 × 0.6
      final dv = voltageDrop(
        current: 100,
        lengthM: 100,
        size: 95,
        phase: Phase.three,
        pf: 0.8,
        conductorTempC: 20,
      );
      final expected = 1.7320508 * 100 * 0.1 * (0.193 * 0.8 + 0.096 * 0.6);
      expect(dv, closeTo(expected, 1e-5));
    });

    test('트레이 겹쳐 쌓음(묶음)은 B.52.17 1행, 한 줄은 4행: 6회로 30A → 6sq / 4sq', () {
      CableChoice pick(GroupLayout l) => chooseCable(
        load: 21.85,
        margin: 1.25,
        volts: 380,
        phase: Phase.three,
        ins: Insulation.xlpe90,
        method: InstallMethod.e,
        lengthM: 20,
        circuits: 6,
        layout: l,
      );
      final bunched = pick(GroupLayout.bunched);
      expect(bunched.groupFactor, 0.57);
      expect(bunched.sizeByAmpacity, 6); // 54 × 0.57 = 30.8 ≥ 30
      final single = pick(GroupLayout.perforatedTray);
      expect(single.groupFactor, 0.73);
      expect(single.sizeByAmpacity, 4); // 42 × 0.73 = 30.7 ≥ 30
    });

    test('따로 포설하는 보호도체: 기계적 보호 2.5sq, 보호 없음 4sq, 표 값보다 작지 않다', () {
      expect(peSeparateSize(1.5, mechProtected: true), 2.5);
      expect(peSeparateSize(1.5, mechProtected: false), 4);
      expect(peSeparateSize(2.5, mechProtected: false), 4);
      expect(peSeparateSize(16, mechProtected: false), 16);
      expect(peSeparateSize(95, mechProtected: true), 50);
    });

    test('전동기 여유: 50A 이하 1.25, 50A 초과 1.1(LS 자료)', () {
      expect(motorMargin(21.8), 1.25);
      expect(motorMargin(50), 1.25);
      expect(motorMargin(73.5), 1.1);
    });

    test('전동기 차단기 범위: 21.85A, 2.5sq 32A → 30A ~ 50A(상한 250% 54.6A)', () {
      final c = chooseCable(
        load: 21.85,
        margin: motorMargin(21.85),
        volts: 380,
        phase: Phase.three,
        ins: Insulation.xlpe90,
        method: InstallMethod.e,
        lengthM: 50,
        motor: true,
      );
      final r = c.motorRange!;
      expect(r.low, 30);
      expect(r.necA, closeTo(54.625, 1e-9));
      expect(r.ratedX3A, closeTo(65.55, 1e-9));
      expect(r.izX25A, closeTo(80, 1e-9));
      expect(r.highA, closeTo(54.625, 1e-9));
      expect(r.high, 50);
      // 전선 허용전류 2.5배가 가장 작으면 그것이 상한이다.
      final r2 = motorBreakerRange(load: 40, low: 50, iz: 30);
      expect(r2.highA, 75);
      expect(r2.high, 75);
      // 상한이 하한보다 작으면 범위 없음.
      expect(motorBreakerRange(load: 10, low: 30, iz: 8).high, isNull);
    });

    test('직류 전압강하: 2 × I × L × R, 역률·리액턴스 없음', () {
      final dv = voltageDrop(
        current: 2,
        lengthM: 50,
        size: 1.0,
        phase: Phase.dc,
        pf: 0.5, // 무시
        conductorTempC: 90,
      );
      expect(dv, closeTo(2 * 2 * 0.05 * 18.1 * (1 + 0.00393 * 70), 1e-9));
      expect(loadCurrent(kw: 0.24, volts: 24, phase: Phase.dc, pf: 0.5), 10);
    });

    test('최대 편도 길이: 그 길이의 전압강하가 한도와 같다(100m 안·밖)', () {
      for (final (i, s) in [(20.0, 4.0), (5.0, 4.0), (1.0, 16.0)]) {
        final l = maxLengthForDrop(
          current: i,
          size: s,
          phase: Phase.three,
          volts: 380,
          pf: 0.85,
          conductorTempC: 90,
        )!;
        final pct =
            voltageDrop(
              current: i,
              lengthM: l,
              size: s,
              phase: Phase.three,
              pf: 0.85,
              conductorTempC: 90,
            ) /
            380 *
            100;
        expect(
          pct,
          closeTo(voltageDropLimit(SupplyType.lvOther, l), 1e-6),
          reason: '$i A $s sq',
        );
      }
      expect(
        maxLengthForDrop(current: 0, size: 4, phase: Phase.three, volts: 380),
        isNull,
      );
    });

    test('길이가 없으면 전압강하를 보지 않고 허용전류로만 선정', () {
      final c = chooseCable(
        load: 21.85,
        volts: 380,
        phase: Phase.three,
        ins: Insulation.xlpe90,
        method: InstallMethod.e,
      );
      expect(c.dropChecked, isFalse);
      expect(c.size, c.sizeByAmpacity);
      expect(c.dropV, isNull);
    });

    test('온도가 보정표를 넘으면 그 이유만 알리고 "부족" 글은 내지 않는다', () {
      final c = chooseCable(
        load: 20,
        volts: 380,
        phase: Phase.three,
        ins: Insulation.xlpe90,
        method: InstallMethod.e,
        lengthM: 10,
        ambientC: 85,
      );
      expect(c.size, isNull);
      expect(c.tempOutOfRange, isTrue);
      expect(c.notes.join(), contains('온도 보정계수 표 범위를 넘습니다'));
      expect(c.notes.join(), isNot(contains('부족합니다')));
    });

    test('회로 수가 20을 넘으면 20회로로 계산했다고 알린다', () {
      final c = chooseCable(
        load: 10,
        volts: 380,
        phase: Phase.three,
        ins: Insulation.xlpe90,
        method: InstallMethod.b2,
        lengthM: 10,
        circuits: 25,
      );
      expect(c.groupFactor, 0.38);
      expect(c.notes.join(), contains('20회로로 계산했습니다'));
    });

    test('병렬 2가닥: 50sq 이상만, 허용전류는 가닥 합, 다조 포설은 2가닥으로', () {
      final c = chooseCable(
        load: 500,
        volts: 380,
        phase: Phase.three,
        ins: Insulation.xlpe90,
        method: InstallMethod.e,
        lengthM: 50,
        parallel: 2,
      );
      expect(c.breaker, 500);
      expect(c.groupCount, 2);
      expect(c.groupFactor, 0.80);
      expect(
        c.size,
        120,
      ); // 95: 298×0.8×2 = 476.8 < 500, 120: 346×0.8×2 = 553.6
      expect(c.iz, closeTo(553.6, 1e-9));
      // 가는 전선은 병렬에 쓰지 않는다(KEC 123).
      final small = chooseCable(
        load: 30,
        volts: 380,
        phase: Phase.three,
        ins: Insulation.xlpe90,
        method: InstallMethod.e,
        lengthM: 10,
        parallel: 2,
      );
      expect(small.size, 50);
    });

    test('기존 회로 점검: 2.5sq 32A, 차단기 30A 만족 / 50A는 전선 부족, 전동기면 상한 이내', () {
      CircuitCheck chk(int br, {bool motor = false}) => checkCircuit(
        size: 2.5,
        load: 21.85,
        margin: motor ? 1.25 : 1,
        breaker: br,
        volts: 380,
        phase: Phase.three,
        ins: Insulation.xlpe90,
        method: InstallMethod.e,
        lengthM: 50,
        motor: motor,
      );
      final ok = chk(30, motor: true);
      expect(ok.iz, 32);
      expect(ok.ibOk, isTrue);
      expect(ok.inOk, isTrue);
      expect(ok.dropPct, closeTo(4.02, 0.01));
      final plain = chk(50);
      expect(plain.inOk, isFalse);
      expect(plain.motorOverIzAllowed, isFalse);
      final motor = chk(50, motor: true);
      expect(motor.inOk, isFalse);
      expect(motor.motorOverIzAllowed, isTrue); // 50 ≤ 54.6
      final small = chk(20, motor: true);
      expect(small.ibOk, isFalse); // 27.3 > 20
      // 부하·차단기 없이 허용전류만.
      final only = checkCircuit(
        size: 16,
        volts: 380,
        phase: Phase.three,
        ins: Insulation.xlpe90,
        method: InstallMethod.e,
        ambientC: 40,
      );
      expect(only.iz, closeTo(100 * 0.91, 1e-9));
      expect(only.ibOk, isNull);
      expect(only.inOk, isNull);
    });

    test(
      '콘덴서 μF: 국내 표기 Qc = 2πf·C·V² (380V 20μF 1.089kvar, 220V 100μF 1.82kvar)',
      () {
        expect(capacitorMicroFarad(1.0888, 380), closeTo(20, 0.01));
        expect(capacitorMicroFarad(1.8246, 220), closeTo(100, 0.01));
        expect(capacitorMicroFarad(42.13, 380), closeTo(773.9, 0.2));
      },
    );

    test('전류 ↔ kVA: 삼상 380V 100A 65.8kVA, 단상 220V 10kVA 45.5A', () {
      expect(
        kvaFromCurrent(current: 100, volts: 380, phase: Phase.three),
        closeTo(65.82, 0.01),
      );
      expect(
        currentFromKva(kva: 10, volts: 220, phase: Phase.single),
        closeTo(45.45, 0.01),
      );
      expect(
        currentFromKva(kva: 65.8179, volts: 380, phase: Phase.three),
        closeTo(100, 0.01),
      );
    });

    test('다조 포설 가닥 수 = 회로 수 + 병렬 가닥 − 1', () {
      expect(groupCount(1, 1), 1);
      expect(groupCount(1, 2), 2);
      expect(groupCount(3, 2), 4);
      expect(groupCount(0, 0), 1);
    });
  });
}
