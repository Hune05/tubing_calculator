// 알루미늄 도체(허용전류·저항·병렬 최소 굵기)와 3고조파 저감(표 E.52.1): 근거 조사 값과 원문 예제로 확인.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/electrical/elec_calc.dart';
import 'package:tubing_calculator/src/presentation/electrical/elec_tables.dart';

void main() {
  group('알루미늄 허용전류 표 값', () {
    double? al(double s, Insulation i, int loaded, InstallMethod m) =>
        baseAmpacity(s, i, loaded, m, conductor: Conductor.aluminum);

    test('PVC 3부하 B1 16 mm²: 알루미늄 53 A, 구리 68 A (조사 보고의 대조 칸)', () {
      expect(al(16, Insulation.pvc70, 3, InstallMethod.b1), 53);
      expect(baseAmpacity(16, Insulation.pvc70, 3, InstallMethod.b1), 68);
    });
    test('칸 몇 개: XLPE 3부하 C 300 = 440, XLPE 2부하 B2 95 = 210, PVC 2부하 A1 10 = 36', () {
      expect(al(300, Insulation.xlpe90, 3, InstallMethod.c), 440);
      expect(al(95, Insulation.xlpe90, 2, InstallMethod.b2), 210);
      expect(al(10, Insulation.pvc70, 2, InstallMethod.a1), 36);
    });
    test('10 mm² D2는 표에 값이 없다(null)', () {
      expect(al(10, Insulation.pvc70, 2, InstallMethod.d2), isNull);
      expect(al(10, Insulation.xlpe90, 3, InstallMethod.d2), isNull);
      expect(al(16, Insulation.xlpe90, 3, InstallMethod.d2), 64);
    });
    test('방법 E: PVC 2부하 10 = 54, XLPE 3부하 240 = 409', () {
      expect(al(10, Insulation.pvc70, 2, InstallMethod.e), 54);
      expect(al(240, Insulation.xlpe90, 3, InstallMethod.e), 409);
    });
    test('알루미늄은 10 mm² 미만이 없다', () {
      expect(al(6, Insulation.pvc70, 3, InstallMethod.b1), isNull);
      expect(kAlSizes.first, 10);
      expect(kAlSizes.last, 300);
    });
    test('알루미늄은 같은 굵기·조건의 구리보다 작고 0.7~0.82배 안에 든다', () {
      for (final ins in Insulation.values) {
        for (final loaded in [2, 3]) {
          for (final m in InstallMethod.values) {
            for (final s in kAlSizes) {
              final a = al(s, ins, loaded, m);
              final c = baseAmpacity(s, ins, loaded, m);
              if (a == null || c == null) continue;
              final r = a / c;
              expect(r, inInclusiveRange(0.66, 0.85), reason: '$ins $loaded $m $s: $r');
            }
          }
        }
      }
    });
  });

  group('알루미늄 저항', () {
    test('16 mm² 20℃ 1.91, 90℃는 온도계수 0.00403', () {
      expect(alResistance(16, 20), closeTo(1.91, 1e-9));
      expect(alResistance(16, 90), closeTo(1.91 * (1 + 0.00403 * 70), 1e-9));
    });
    test('같은 굵기에서 구리보다 저항이 크다', () {
      for (final s in kAlSizes) {
        expect(kAlR20[s]!, greaterThan(kCuR20[s]!), reason: '$s');
      }
    });
    test('전압강하: 알루미늄이 구리보다 크다, 같은 굵기·전류', () {
      final cu = voltageDrop(current: 50, lengthM: 100, size: 35, phase: Phase.three);
      final al = voltageDrop(
        current: 50,
        lengthM: 100,
        size: 35,
        phase: Phase.three,
        conductor: Conductor.aluminum,
      );
      expect(al, greaterThan(cu));
    });
    test('알루미늄에 없는 굵기는 저항 null', () {
      expect(wireResistance(6, 20, Conductor.aluminum), isNull);
      expect(wireResistance(6, 20, Conductor.copper), isNotNull);
    });
  });

  group('알루미늄 굵기 선정', () {
    test('100 A 삼상 XLPE 트레이(E): 알루미늄은 35 mm², 구리보다 굵다', () {
      final a = chooseCable(
        load: 100,
        volts: 380,
        phase: Phase.three,
        ins: Insulation.xlpe90,
        method: InstallMethod.e,
        conductor: Conductor.aluminum,
      );
      final c = chooseCable(
        load: 100,
        volts: 380,
        phase: Phase.three,
        ins: Insulation.xlpe90,
        method: InstallMethod.e,
      );
      expect(a.size, 35); // E XLPE 3부하 Al 35 = 120 A ≥ 100 A
      expect(c.size! < a.size!, isTrue);
      expect(a.conductor, Conductor.aluminum);
    });
    test('병렬은 알루미늄 70 mm² 이상', () {
      final r = chooseCable(
        load: 500,
        volts: 380,
        phase: Phase.three,
        ins: Insulation.xlpe90,
        method: InstallMethod.e,
        parallel: 2,
        conductor: Conductor.aluminum,
      );
      expect(r.size!, greaterThanOrEqualTo(70));
      final k = checkCircuit(
        size: 50,
        load: 200,
        breaker: 100,
        volts: 380,
        phase: Phase.three,
        ins: Insulation.xlpe90,
        method: InstallMethod.e,
        parallel: 2,
        conductor: Conductor.aluminum,
      );
      expect(k.notes.any((n) => n.contains('알루미늄 70sq')), isTrue);
    });
    test('기존 회로 점검에서 알루미늄 허용전류를 쓴다', () {
      final k = checkCircuit(
        size: 35,
        load: 80,
        breaker: 100,
        volts: 380,
        phase: Phase.three,
        ins: Insulation.xlpe90,
        method: InstallMethod.e,
        conductor: Conductor.aluminum,
      );
      expect(k.base, 120);
      expect(k.iz, 120);
      expect(k.inOk, isTrue);
    });
  });

  group('3고조파 저감계수(표 E.52.1)', () {
    test('구간: 15 이하 1.0 / 15~33 0.86 / 33~45 0.86(중성선) / 45 초과 1.0(중성선)', () {
      expect(harmonicDerating(10).factor, 1.0);
      expect(harmonicDerating(15).factor, 1.0);
      expect(harmonicDerating(20).factor, 0.86);
      expect(harmonicDerating(20).neutralBased, isFalse);
      expect(harmonicDerating(33).neutralBased, isFalse);
      expect(harmonicDerating(40).factor, 0.86);
      expect(harmonicDerating(40).neutralBased, isTrue);
      expect(harmonicDerating(45).neutralBased, isTrue);
      expect(harmonicDerating(50).factor, 1.0);
      expect(harmonicDerating(50).neutralBased, isTrue);
    });
    test('중성선 전류 = 3 × 함유율 × 선전류 (원문 예제 39 A × 40 % → 46.8 A)', () {
      expect(neutralCurrent(39, 40), closeTo(46.8, 1e-9));
      expect(neutralCurrent(39, 50), closeTo(58.5, 1e-9));
    });

    CableChoice pick(double h3) => chooseCable(
      load: 39,
      volts: 380,
      phase: Phase.three,
      ins: Insulation.pvc70,
      method: InstallMethod.c,
      thirdHarmonicPct: h3,
    );
    test('원문 예제 PVC 4심 방법 C 39 A: 0 % 6 mm², 20 % 10 mm², 40 % 10 mm², 50 % 16 mm²', () {
      expect(pick(0).size, 6);
      expect(pick(20).size, 10); // 39 ÷ 0.86 = 45 A → 10 mm²
      expect(pick(40).size, 10); // 46.8 ÷ 0.86 = 54.4 A → 10 mm²
      expect(pick(50).size, 16); // 58.5 A, 계수 1.0 → 16 mm²
    });
    test('고조파 계수가 허용전류에 곱해진다', () {
      final r = pick(20);
      expect(r.harmonicFactor, 0.86);
      expect(r.iz, closeTo(r.base! * r.tempFactor * r.groupFactor * 0.86, 1e-9));
      expect(r.notes.any((n) => n.contains('저감계수 0.86')), isTrue);
    });
    test('15 % 이하와 단상은 보정 없음', () {
      expect(pick(15).harmonicFactor, 1.0);
      final s = chooseCable(
        load: 39,
        volts: 220,
        phase: Phase.single,
        ins: Insulation.pvc70,
        method: InstallMethod.c,
        thirdHarmonicPct: 40,
      );
      expect(s.harmonicFactor, 1.0);
    });
    test('기존 회로 점검: 중성선 전류가 허용전류를 넘으면 알린다', () {
      final k = checkCircuit(
        size: 6,
        load: 39,
        breaker: 40,
        volts: 380,
        phase: Phase.three,
        ins: Insulation.pvc70,
        method: InstallMethod.c,
        thirdHarmonicPct: 50,
      );
      expect(k.neutralAmps, closeTo(58.5, 1e-9));
      expect(k.notes.any((n) => n.contains('굵기가 부족합니다')), isTrue);
    });
  });
}
