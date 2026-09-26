// 단위 환산 계산(unit_defs.dart) — 정의값 환산, 인치 분수, 전선 굵기, 배관 호칭.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/unit_converter/unit_defs.dart';

double conv(UnitCategory c, String from, double v, String to) =>
    c.unit(to)!.fromBase(c.unit(from)!.toBase(v));

void main() {
  group('정의값 환산', () {
    test('길이: 1 inch = 25.4 mm, 1 ft = 304.8 mm', () {
      expect(conv(kLength, 'in', 1, 'mm'), closeTo(25.4, 1e-9));
      expect(conv(kLength, 'ft', 1, 'mm'), closeTo(304.8, 1e-9));
    });
    test(
      '압력: 1 kgf/cm² = 14.2233 psi = 0.0980665 MPa, 1 bar = 14.50377 psi',
      () {
        expect(conv(kPressure, 'kgfcm2', 1, 'psi'), closeTo(14.2233, 1e-4));
        expect(conv(kPressure, 'kgfcm2', 1, 'mpa'), closeTo(0.0980665, 1e-12));
        expect(conv(kPressure, 'bar', 1, 'psi'), closeTo(14.503774, 1e-6));
        expect(conv(kPressure, 'atm', 1, 'kpa'), closeTo(101.325, 1e-9));
      },
    );
    test('토크: 1 N·m = 0.7375621 lbf·ft, 1 kgf·m = 9.80665 N·m', () {
      expect(conv(kTorque, 'nm', 1, 'lbfft'), closeTo(0.7375621, 1e-7));
      expect(conv(kTorque, 'kgfm', 1, 'nm'), closeTo(9.80665, 1e-12));
      expect(conv(kTorque, 'lbfft', 1, 'lbfin'), closeTo(12, 1e-9));
    });
    test('무게·힘: 100 kg = 220.4623 lb, 1 tf = 1000 kgf', () {
      expect(conv(kMass, 'kg', 100, 'lb'), closeTo(220.46226, 1e-5));
      expect(conv(kForce, 'tf', 1, 'kgf'), closeTo(1000, 1e-9));
    });
    test('온도: 100 °C = 212 °F, -40 °C = -40 °F, 0 °C = 273.15 K', () {
      expect(conv(kTemperature, 'c', 100, 'f'), closeTo(212, 1e-9));
      expect(conv(kTemperature, 'c', -40, 'f'), closeTo(-40, 1e-9));
      expect(conv(kTemperature, 'c', 0, 'k'), closeTo(273.15, 1e-9));
    });
    test('유량: 1 GPM = 3.785411784 L/min, 1 m³/h = 16.6667 L/min', () {
      expect(conv(kFlow, 'gpm', 1, 'lmin'), closeTo(3.785411784, 1e-12));
      expect(conv(kFlow, 'm3h', 1, 'lmin'), closeTo(16.666667, 1e-6));
    });
    test('각도·구배: 45° = 100% = 1000 mm/m, 1% ≈ 0.573°', () {
      expect(conv(kAngle, 'deg', 45, 'pct'), closeTo(100, 1e-9));
      expect(conv(kAngle, 'deg', 45, 'mmm'), closeTo(1000, 1e-9));
      expect(conv(kAngle, 'pct', 1, 'deg'), closeTo(0.5729, 1e-4));
    });
    test('전력: 1 kW = 1.341022 HP = 859.845 kcal/h', () {
      expect(conv(kPower, 'kw', 1, 'hp'), closeTo(1.341022, 1e-6));
      expect(conv(kPower, 'kw', 1, 'kcalh'), closeTo(859.845, 1e-3));
    });
  });

  group('숫자 글', () {
    test('유효 7자리, 끝의 0은 뗀다', () {
      expect(formatNumber(25.4), '25.4');
      expect(formatNumber(1), '1');
      expect(formatNumber(14.503773773), '14.50377');
      expect(formatNumber(0.00012345), '0.00012345');
      expect(formatNumber(1234567.89), '1234568');
      expect(formatNumber(-40), '-40');
      expect(formatNumber(0), '0');
    });
    test('읽기: 쉼표 무시, 빈 칸·잘못된 글은 null', () {
      expect(parseNumber('1,000.5'), 1000.5);
      expect(parseNumber(''), isNull);
      expect(parseNumber('-'), isNull);
      expect(parseNumber('abc'), isNull);
    });
  });

  group('인치 분수', () {
    test('여러 모양을 읽는다', () {
      expect(parseInches('3/8'), 0.375);
      expect(parseInches('1-3/8'), 1.375);
      expect(parseInches('1 3/8'), 1.375);
      expect(parseInches('1-3/8"'), 1.375);
      expect(parseInches('1.5'), 1.5);
      expect(parseInches("1' 3-5/8\""), 15.625);
      expect(parseInches("2'"), 24);
      expect(parseInches("1'3\""), 15);
      expect(parseInches('13/8'), 1.625);
      expect(parseInches('1/0'), isNull);
      expect(parseInches('abc'), isNull);
      expect(parseInches(''), isNull);
    });
    test('mm → 가장 가까운 1/16"와 오차', () {
      final f = inchFraction(35 / 25.4); // 1.378"
      expect(f.text, '1-3/8"');
      expect(f.errMm, closeTo(0.075, 1e-9)); // 35 − 34.925
      expect(inchFraction(12.7 / 25.4).text, '1/2"');
      expect(inchFraction(25.4 / 25.4).text, '1"');
      expect(inchFraction(35 / 25.4, denom: 32).text, '1-3/8"');
      expect(inchFraction(1.40625, denom: 64).text, '1-13/32"');
      expect(fractionErrorText(0.075), '실제가 분수보다 0.08mm 깁니다');
      expect(fractionErrorText(-0.1), '실제가 분수보다 0.10mm 짧습니다');
      expect(fractionErrorText(0), '분수와 딱 맞습니다');
    });
    test('피트·인치', () {
      expect(feetInches(49.375), "4' 1-3/8\"");
      expect(feetInches(11.99), "1' 0\""); // 반올림하면 12" → 1'
      expect(feetInches(0.5), '1/2"');
    });
  });

  group('전선 굵기', () {
    test('AWG 단면적: 10 AWG ≈ 5.26 mm², 4/0 ≈ 107.2 mm²', () {
      expect(awgAreaMm2(10), closeTo(5.26, 0.01));
      expect(awgAreaMm2(12), closeTo(3.31, 0.01));
      expect(awgAreaMm2(-3), closeTo(107.2, 0.1));
    });
    test('AWG 글 읽기', () {
      expect(parseAwg('10'), 10);
      expect(parseAwg('1/0'), 0);
      expect(parseAwg('4/0'), -3);
      expect(parseAwg('00'), -1);
      expect(parseAwg('AWG 14'), 14);
      expect(parseAwg('x'), isNull);
      expect(awgLabel(-3), '4/0');
      expect(awgLabel(10), '10');
    });
    test('SQ 고르기: 5.26mm² → 가장 가까운 6sq, 같거나 굵은 6sq; 3.31 → 4sq', () {
      expect(sqFor(5.26).nearest, 6);
      expect(sqFor(5.26).atLeast, 6);
      expect(sqFor(3.31).nearest, 4);
      expect(sqFor(2.08).nearest, 2.5);
      expect(sqFor(2.5).atLeast, 2.5);
    });
    test('mm² → AWG: 2.5sq → 가장 가까운 14(2.08), 같거나 굵은 12', () {
      expect(awgFor(2.5).nearest, 14);
      expect(awgFor(2.5).atLeast, 12);
      expect(awgFor(500).atLeast, isNull); // 4/0보다 굵다
    });
  });

  group('배관 호칭', () {
    test('15A = 1/2B = DN15, KS 21.7 / ASME 21.3', () {
      final r = kPipeSizes.firstWhere((p) => p.a == '15A');
      expect(r.b, '1/2');
      expect(r.dn, 15);
      expect(r.ksOd, 21.7);
      expect(r.asmeOd, 21.3);
    });
    test('A 번호와 DN이 같다', () {
      for (final p in kPipeSizes) {
        expect(p.a, '${p.dn}A');
      }
    });
  });

  group('찾기', () {
    test('psi → 압력의 psi, 토크 → 토크 분류, awg → 전선 굵기', () {
      final psi = searchUnits('psi');
      expect(psi.first.category.id, 'pressure');
      expect(psi.first.unit!.id, 'psi');
      expect(searchUnits('lb-ft').first.unit!.id, 'lbfft');
      expect(searchUnits('awg').first.category.id, 'wire');
      expect(searchUnits('15a').first.category.id, 'pipe');
      expect(searchUnits('인치').any((h) => h.unit?.id == 'in_frac'), isTrue);
      expect(searchUnits(''), isEmpty);
    });
  });
}
