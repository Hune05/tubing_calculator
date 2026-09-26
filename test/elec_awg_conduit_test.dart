// 전기 계산기 AWG(NEC)·전선관 점유율 계산 시험. 표 값은 docs/전기계산기_근거.md "AWG"·"전선관 굵기".
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/electrical/awg_tables.dart';
import 'package:tubing_calculator/src/presentation/electrical/conduit_tables.dart';
import 'package:tubing_calculator/src/presentation/electrical/elec_calc.dart';
import 'package:tubing_calculator/src/presentation/electrical/elec_tables.dart';
import 'package:tubing_calculator/src/presentation/unit_converter/unit_defs.dart'
    show awgAreaMm2;

AwgSize awg(String label) => awgByLabel(label)!;

void main() {
  group('AWG 표', () {
    test(
      'NEC 310.16 구리: 12 AWG 20·25·30A, 4/0 195·230·260A, 500 kcmil 320·380·430A',
      () {
        expect(
          [awg('12 AWG').a60, awg('12 AWG').a75, awg('12 AWG').a90],
          [20, 25, 30],
        );
        expect(
          [awg('4/0 AWG').a60, awg('4/0 AWG').a75, awg('4/0 AWG').a90],
          [195, 230, 260],
        );
        expect(
          [awg('500 kcmil').a60, awg('500 kcmil').a75, awg('500 kcmil').a90],
          [320, 380, 430],
        );
        expect(awg('18 AWG').a60, isNull);
        expect(awg('18 AWG').a90, 14);
        expect(awg('16 AWG').a90, 18);
      },
    );

    test('허용전류는 굵을수록 커진다(모든 열)', () {
      for (final col in NecColumn.values) {
        int? prev;
        for (final s in kAwgSizes) {
          final a = necAmpacity(s, col);
          if (a == null) continue;
          if (prev != null) {
            expect(a, greaterThan(prev), reason: '${s.label} $col');
          }
          prev = a;
        }
      }
    });

    test('단면적은 AWG 식(단위 환산 화면)과 1% 이내, kcmil은 0.5067 mm²/kcmil', () {
      for (final s in kAwgSizes) {
        if (s.isKcmil) {
          expect(
            s.mm2,
            closeTo(s.cmil * 0.0005067, s.mm2 * 0.01),
            reason: s.label,
          );
          continue;
        }
        final l = s.label.split(' ').first;
        final n = l.contains('/')
            ? 1 - int.parse(l.split('/').first)
            : int.parse(l);
        expect(
          s.mm2,
          closeTo(awgAreaMm2(n), awgAreaMm2(n) * 0.01),
          reason: s.label,
        );
      }
    });

    test(
      'NEC 9장 표 8 75°C 저항: 12 AWG 6.50, 4/0 0.1996, 500 kcmil 0.0845 Ω/km, 굵을수록 작다',
      () {
        expect(awg('12 AWG').r75, 6.50);
        expect(awg('4/0 AWG').r75, 0.1996);
        expect(awg('500 kcmil').r75, 0.0845);
        for (var i = 1; i < kAwgSizes.length; i++) {
          expect(kAwgSizes[i].r75, lessThan(kAwgSizes[i - 1].r75));
        }
      },
    );

    test(
      '온도 보정 310.15(B)(1): 40°C 90°C 열 0.91, 41°C 75°C 열 0.82, 60°C 넘는 60°C 열은 없음',
      () {
        expect(necTempFactor(40, NecColumn.c90), 0.91);
        expect(necTempFactor(41, NecColumn.c75), 0.82);
        expect(necTempFactor(30, NecColumn.c60), 1.0);
        expect(necTempFactor(61, NecColumn.c60), isNull);
        expect(necTempFactor(86, NecColumn.c90), isNull);
      },
    );

    test(
      '가닥 감소 310.15(C)(1): 3 → 1, 4 → 0.8, 9 → 0.7, 20 → 0.5, 41 → 0.35',
      () {
        expect(necAdjustFactor(3), 1.0);
        expect(necAdjustFactor(4), 0.8);
        expect(necAdjustFactor(9), 0.7);
        expect(necAdjustFactor(20), 0.5);
        expect(necAdjustFactor(30), 0.45);
        expect(necAdjustFactor(40), 0.4);
        expect(necAdjustFactor(41), 0.35);
      },
    );

    test('240.4(D): 14 AWG 15A, 12 AWG 20A, 10 AWG 30A, 8 AWG 없음', () {
      expect(necSmallConductorMaxOcpd(awg('14 AWG')), 15);
      expect(necSmallConductorMaxOcpd(awg('12 AWG')), 20);
      expect(necSmallConductorMaxOcpd(awg('10 AWG')), 30);
      expect(necSmallConductorMaxOcpd(awg('8 AWG')), isNull);
    });
  });

  group('AWG 계산', () {
    test('단자 자동: 100A 이하 60°C 열로 제한(12 AWG 90°C 30A → 20A)', () {
      final a = awgAmpacity(
        awg('12 AWG'),
        column: NecColumn.c90,
        terminal: NecTerminal.auto,
        circuitA: 20,
      );
      expect(a.corrected, 30);
      expect(a.terminalLimit, 20);
      expect(a.iz, 20);
      expect(a.terminal, NecColumn.c60);
    });

    test('단자 열은 절연 열보다 높을 수 없다(60°C 전선 + 75°C 단자 → 60°C)', () {
      final a = awgAmpacity(
        awg('6 AWG'),
        column: NecColumn.c60,
        terminal: NecTerminal.c75,
        circuitA: 50,
      );
      expect(a.terminal, NecColumn.c60);
      expect(a.iz, 55);
    });

    test('일반 부하 20A → 12 AWG, 16A → 12 AWG(14 AWG 15A 한도)', () {
      ChoiceProbe p(double a) =>
          ChoiceProbe(chooseAwg(load: a, volts: 220, phase: Phase.single));
      expect(p(20).label, '12 AWG');
      expect(p(16).label, '12 AWG');
      expect(p(15).label, '14 AWG');
    });

    test('전동기 28A ×1.25 = 35A: 단자 자동(60°C) 8 AWG, 75°C 단자 10 AWG', () {
      final auto = chooseAwg(
        load: 28,
        margin: 1.25,
        volts: 460,
        phase: Phase.three,
        motor: true,
      );
      expect(auto.ib, 35);
      expect(auto.size!.label, '8 AWG');
      final t75 = chooseAwg(
        load: 28,
        margin: 1.25,
        volts: 460,
        phase: Phase.three,
        terminal: NecTerminal.c75,
        motor: true,
      );
      expect(t75.size!.label, '10 AWG');
    });

    test('40°C·통전 9가닥 30A(90°C 전선, 75°C 단자) → 8 AWG 35.0A', () {
      final c = chooseAwg(
        load: 30,
        volts: 480,
        phase: Phase.three,
        terminal: NecTerminal.c75,
        ambientC: 40,
        currentCarrying: 9,
      );
      expect(c.size!.label, '8 AWG');
      expect(c.amp!.iz, closeTo(55 * 0.91 * 0.7, 1e-9));
    });

    test('100A 초과는 75°C 열: 150A → 1/0 AWG', () {
      final c = chooseAwg(load: 150, volts: 480, phase: Phase.three);
      expect(c.size!.label, '1/0 AWG');
      expect(c.amp!.terminal, NecColumn.c75);
    });

    test('500 kcmil을 넘으면 선정하지 않고 알린다', () {
      final c = chooseAwg(load: 500, volts: 480, phase: Phase.three);
      expect(c.size, isNull);
      expect(c.notes.join(), contains('500 kcmil'));
    });

    test('전압강하: 삼상 20A 50m 12 AWG 역률 1 → √3 × 20 × 0.05 × 6.50', () {
      final dv = awgVoltageDrop(
        current: 20,
        lengthM: 50,
        size: awg('12 AWG'),
        phase: Phase.three,
        pf: 1,
      );
      expect(dv, closeTo(1.7320508 * 20 * 0.05 * 6.50, 1e-6));
      final dc = awgVoltageDrop(
        current: 2,
        lengthM: 100,
        size: awg('16 AWG'),
        phase: Phase.dc,
      );
      expect(dc, closeTo(2 * 2 * 0.1 * awg('16 AWG').r75, 1e-9));
    });

    test('전압강하가 크면 굵기를 올린다: 단상 120V 15A 60m → 전압강하 기준이 더 굵다', () {
      final c = chooseAwg(
        load: 15,
        volts: 120,
        phase: Phase.single,
        lengthM: 60,
        pf: 1,
      );
      expect(c.byAmpacity!.label, '14 AWG');
      expect(
        kAwgSizes.indexOf(c.size!),
        greaterThan(kAwgSizes.indexOf(awg('14 AWG'))),
      );
      expect(c.dropPct!, lessThanOrEqualTo(c.dropLimitPct + 1e-9));
    });

    test('voltageDrop(SQ)는 voltageDropR과 같다(바꾼 뒤에도 값 그대로)', () {
      final a = voltageDrop(
        current: 30,
        lengthM: 80,
        size: 6,
        phase: Phase.three,
        pf: 0.85,
        conductorTempC: 90,
      );
      final b = voltageDropR(
        current: 30,
        lengthM: 80,
        rOhmPerKm: cuResistance(6, 90),
        phase: Phase.three,
        pf: 0.85,
      );
      expect(a, b);
    });

    test('SQ 환산: 14 AWG → 2.5sq, 1/0 AWG → 70sq', () {
      expect(sqAtLeast(awg('14 AWG').mm2), 2.5);
      expect(sqAtLeast(awg('1/0 AWG').mm2), 70);
    });

    test('UL 508A 표 28.1 참고 값: 14 AWG 75°C 15A, 1/0 AWG 60°C 없음', () {
      expect(kUl508aT281['14 AWG'], (15, 15));
      expect(kUl508aT281['8 AWG'], (40, 50));
      expect(kUl508aT281['1/0 AWG'], (null, 150));
      expect(kUl508aT281['500 kcmil'], (null, 380));
      expect(kUl508aT281['18 AWG'], isNull);
    });
  });

  group('전선관 표', () {
    // 내선규정 표 "내 단면적의 32% 및 48%"(eom.co.kr 표7·표8, 설계 자료 표1.10~1.16). 표는 소수점 아래를 버린 값.
    // 후강 104는 표가 내 단면적 8886mm²(宮地電機 표 값)로 계산해 2mm² 작다. 허용 차이: 1mm² 또는 0.1%.
    double tol(int t) => t * 0.001 > 1 ? t * 0.001 : 1;
    void matchTable(ConduitKind k, List<int> t32, List<int?> t48) {
      final cs = conduitSizes(k);
      expect(cs.length, t32.length, reason: '$k 규격 수');
      for (var i = 0; i < cs.length; i++) {
        final a = conduitArea(cs[i].id);
        expect(
          (a * 0.32).floor(),
          closeTo(t32[i], tol(t32[i])),
          reason: '$k ${cs[i].size} 32%',
        );
        if (t48[i] != null) {
          expect(
            (a * 0.48).floor(),
            closeTo(t48[i]!, tol(t48[i]!)),
            reason: '$k ${cs[i].size} 48%',
          );
        }
      }
    }

    test('후강 내경이 내선규정 32%·48% 표와 맞다', () {
      matchTable(
        ConduitKind.thick,
        [67, 120, 201, 342, 460, 732, 1216, 1701, 2205, 2843],
        [101, 180, 301, 513, 690, 1098, 1825, 2552, 3308, 4265],
      );
      expect(conduitSizes(ConduitKind.thick).first.id, 16.4);
      expect(conduitSizes(ConduitKind.thick).last.id, 106.4);
    });

    test('박강 내경이 내선규정 32%·48% 표와 맞다', () {
      matchTable(
        ConduitKind.thin,
        [63, 123, 205, 305, 569, 889, 1309],
        [95, 185, 308, 458, 853, 1333, 1964],
      );
    });

    test('경질 비닐·2종 가요·PF 내경이 설계 자료 32% 값과 맞다', () {
      matchTable(
        ConduitKind.pvc,
        [49, 81, 121, 196, 307, 401, 653, 1127, 1497],
        [73, 122, 182, 295, 461, 602, 980, 1691, 2245],
      );
      matchTable(ConduitKind.flex2, [
        21,
        32,
        49,
        69,
        142,
        215,
        345,
        605,
        984,
        1450,
        1648,
        2522,
      ], List.filled(12, null));
      matchTable(
        ConduitKind.pf,
        [49, 64, 121, 196, 325, 443],
        [73, 96, 182, 295, 488, 664],
      );
    });

    test(
      '케이블 외경: F-CV 4심 16sq 22, HFIX 2.5sq 4.1, IV 300sq 없음, CVV-S 30심 6sq 없음',
      () {
        expect(cableOd(CableKind.fcv4, 16), 22);
        expect(cableOd(CableKind.fcv1, 10), 9.4);
        expect(cableOd(CableKind.hfix, 2.5), 4.1);
        expect(cableOd(CableKind.iv, 240), 26.6);
        expect(cableOd(CableKind.iv, 300), isNull);
        expect(cableSizes(CableKind.iv).last, 240);
        expect(cableOd(CableKind.cvvs10, 2.5), 20.5);
        expect(cableSizes(CableKind.cvvs30), [1.5, 2.5, 4]);
        expect(cableSizes(CableKind.cvvs15), [1.5, 2.5, 4, 6]);
        expect(cableKindLabel(CableKind.cvvs7), 'F-CVV-S 7심');
      },
    );

    test('외경은 굵을수록 크다(모든 종류)', () {
      for (final k in CableKind.values) {
        final ss = cableSizes(k);
        for (var i = 1; i < ss.length; i++) {
          expect(
            cableOd(k, ss[i])!,
            greaterThanOrEqualTo(cableOd(k, ss[i - 1])!),
            reason: '$k ${ss[i]}',
          );
        }
      }
    });
  });

  group('점유율', () {
    const hfix25x3 = [ConduitWire(CableKind.hfix, 2.5, 3)];

    test('HFIX 2.5sq 3가닥: 후강 22 점유율 10.5%, 최소 후강 16·박강 19·2종 가요 15', () {
      expect(
        wiresArea(hfix25x3),
        closeTo(3 * 3.14159265 / 4 * 4.1 * 4.1, 1e-6),
      );
      final thick22 = conduitSizes(ConduitKind.thick)[1];
      expect(fillPercent(hfix25x3, thick22.id), closeTo(10.52, 0.01));
      expect(
        minConduit(ConduitKind.thick, hfix25x3, FillRule.naesun)!.size,
        16,
      );
      expect(minConduit(ConduitKind.thin, hfix25x3, FillRule.naesun)!.size, 19);
      expect(
        minConduit(ConduitKind.flex2, hfix25x3, FillRule.naesun)!.size,
        15,
      );
    });

    test('내선규정: 같은 굵기 절연전선은 기본 32%, 쉽게 인출하면 48%', () {
      final l = fillLimit(FillRule.naesun, hfix25x3);
      expect(l.pct, 32);
      expect(l.notes.join(), contains('48%'));
      expect(easyPullApplies(hfix25x3), isTrue);
      expect(fillLimit(FillRule.naesun, hfix25x3, easyPull: true).pct, 48);
    });

    test('HFIX 2.5sq 10가닥: 32%면 후강 28, 48%면 후강 22', () {
      const w = [ConduitWire(CableKind.hfix, 2.5, 10)];
      expect(minConduit(ConduitKind.thick, w, FillRule.naesun)!.size, 28);
      expect(
        minConduit(ConduitKind.thick, w, FillRule.naesun, easyPull: true)!.size,
        22,
      );
    });

    test('굵기가 다른 절연전선은 48% 스위치를 켜도 32%', () {
      const w = [
        ConduitWire(CableKind.hfix, 2.5, 3),
        ConduitWire(CableKind.hfix, 4, 2),
      ];
      expect(easyPullApplies(w), isFalse);
      final l = fillLimit(FillRule.naesun, w, easyPull: true);
      expect(l.pct, 32);
      expect(l.reason, contains('굵기가 다른'));
    });

    test(
      '케이블 1본: 내경 ≥ 외경 × 1.5 (F-CV 4심 16sq 외경 22 → 후강 36), NEC 53%도 후강 36',
      () {
        const w = [ConduitWire(CableKind.fcv4, 16, 1)];
        final l = fillLimit(FillRule.naesun, w);
        expect(l.pct, closeTo(44.44, 0.01));
        expect(l.reason, contains('1.5배'));
        final c = minConduit(ConduitKind.thick, w, FillRule.naesun)!;
        expect(c.size, 36);
        expect(c.id, greaterThanOrEqualTo(22 * 1.5));
        expect(conduitSizes(ConduitKind.thick)[2].id, lessThan(22 * 1.5));
        expect(fillLimit(FillRule.nec, w).pct, 53);
        expect(minConduit(ConduitKind.thick, w, FillRule.nec)!.size, 36);
      },
    );

    test('케이블 여러 본은 32%와 알림', () {
      const w = [ConduitWire(CableKind.fcv3, 4, 2)];
      final l = fillLimit(FillRule.naesun, w);
      expect(l.pct, 32);
      expect(l.notes.join(), contains('케이블 여러 본'));
    });

    test('NEC 9장 표 1: 1본 53%, 2본 31%, 3본 이상 40%', () {
      expect(
        fillLimit(FillRule.nec, const [
          ConduitWire(CableKind.hfix, 2.5, 1),
        ]).pct,
        53,
      );
      expect(
        fillLimit(FillRule.nec, const [
          ConduitWire(CableKind.hfix, 2.5, 2),
        ]).pct,
        31,
      );
      expect(fillLimit(FillRule.nec, hfix25x3).pct, 40);
    });

    test('표 끝을 넘으면 최소 전선관 없음', () {
      const w = [ConduitWire(CableKind.fcv4, 300, 4)];
      expect(minConduit(ConduitKind.thick, w, FillRule.naesun), isNull);
      expect(minConduit(ConduitKind.pf, w, FillRule.naesun), isNull);
    });
  });
}

/// 선정 결과를 이름으로 보기.
class ChoiceProbe {
  final AwgChoice c;
  ChoiceProbe(this.c);
  String? get label => c.size?.label;
}
