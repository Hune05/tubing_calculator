// 단위 환산 계산(unit_defs.dart) — 정의값 환산, 인치 분수, 전선 굵기, 배관 호칭,
// 절대압·수주 온도 기준·온도차·에너지·냉동톤, 쉼표 소수점, 찾기 순위.
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
    test('동력: 1 kW = 1.341022 HP = 859.845 kcal/h', () {
      expect(conv(kPower, 'kw', 1, 'hp'), closeTo(1.341022, 1e-6));
      expect(conv(kPower, 'kw', 1, 'kcalh'), closeTo(859.845, 1e-3));
    });
    test(
      '냉동톤: USRT = 12,000 BTU/h = 3.516853 kW, RT = 3,320 kcal/h = 3.86116 kW',
      () {
        expect(conv(kPower, 'usrt', 1, 'kw'), closeTo(3.516853, 1e-6));
        expect(conv(kPower, 'usrt', 1, 'btuh'), closeTo(12000, 1e-6));
        expect(conv(kPower, 'rt', 1, 'kcalh'), closeTo(3320, 1e-9));
        expect(conv(kPower, 'rt', 1, 'kw'), closeTo(3.86116, 1e-9));
      },
    );
    test('에너지: 1 kWh = 3.6 MJ = 859.845 kcal = 3412.142 BTU', () {
      expect(conv(kEnergy, 'kwh', 1, 'mj'), closeTo(3.6, 1e-12));
      expect(conv(kEnergy, 'kwh', 1, 'kcal'), closeTo(859.8452, 1e-4));
      expect(conv(kEnergy, 'kwh', 1, 'btu'), closeTo(3412.1416, 1e-4));
      expect(conv(kEnergy, 'kcal', 1, 'kj'), closeTo(4.1868, 1e-12));
    });
    test('온도차: 1 °C 차 = 1.8 °F 차 = 1 K', () {
      expect(conv(kTempDiff, 'dc', 1, 'df'), closeTo(1.8, 1e-12));
      expect(conv(kTempDiff, 'df', 18, 'dc'), closeTo(10, 1e-12));
      expect(conv(kTempDiff, 'dk', 5, 'dc'), closeTo(5, 1e-12));
    });
    test('온도: 32 °F → 0 °C가 딱 0(지수 찌꺼기 없음), 절대영도 아래는 belowMin', () {
      expect(formatNumber(conv(kTemperature, 'f', 32, 'c')), '0');
      expect(formatNumber(conv(kTemperature, 'k', 273.15, 'c')), '0');
      final c = kTemperature.unit('c')!;
      expect(kTemperature.belowMin(c.toBase(-273.15)), isFalse);
      expect(kTemperature.belowMin(c.toBase(-274)), isTrue);
      expect(kTemperature.belowMin(kTemperature.unit('k')!.toBase(-1)), isTrue);
      expect(kPressure.belowMin(-1e9), isFalse); // 압력은 막지 않는다
    });
  });

  group('압력: 수주·수은주·절대압·게이지압', () {
    test('mH₂O = 1000 mmH₂O = 9.80665 kPa, cmHg = 10 mmHg, hPa = mbar', () {
      expect(conv(kPressure, 'mh2o', 1, 'kpa'), closeTo(9.80665, 1e-12));
      expect(conv(kPressure, 'mh2o', 1, 'mmh2o'), closeTo(1000, 1e-9));
      expect(conv(kPressure, 'cmhg', 1, 'mmhg'), closeTo(10, 1e-9));
      expect(conv(kPressure, 'hpa', 1, 'mbar'), closeTo(1, 1e-12));
    });
    test('인치 수주: 4 °C 249.0889 Pa, 68 °F 248.64 Pa', () {
      expect(conv(kPressure, 'inh2o', 1, 'pa'), closeTo(249.0889, 1e-4));
      expect(conv(kPressure, 'inh2o68', 1, 'pa'), closeTo(248.64, 1e-9));
      expect(kPressure.unit('inh2o')!.name, contains('4 °C'));
      expect(kPressure.unit('mmh2o')!.name, contains('4 °C'));
      expect(kPressure.unit('inh2o68')!.name, contains('68 °F'));
    });
    test('절대압: 게이지 0 = 1.01325 bar(a) = 14.69595 psia = 101.325 kPa(a)', () {
      expect(conv(kPressure, 'bar', 0, 'bara'), closeTo(1.01325, 1e-12));
      expect(conv(kPressure, 'bar', 0, 'psia'), closeTo(14.695949, 1e-6));
      expect(conv(kPressure, 'bar', 0, 'kpaa'), closeTo(101.325, 1e-9));
      expect(conv(kPressure, 'bar', 0, 'kgfcm2a'), closeTo(1.033227, 1e-6));
      expect(conv(kPressure, 'bara', 2, 'bar'), closeTo(0.98675, 1e-12));
      // 대기압 = 게이지 0, 완전 진공 = 절대 0: 빼기 찌꺼기 없이 딱 0.
      expect(formatNumber(conv(kPressure, 'kpaa', 101.325, 'bar')), '0');
      expect(formatNumber(conv(kPressure, 'kpa', -101.325, 'bara')), '0');
    });
    test('게이지 압력 단위는 "-"가 있는 자판(진공), 절대압은 없다', () {
      for (final id in ['mpa', 'kpa', 'bar', 'kgfcm2', 'psi', 'mmhg', 'mh2o']) {
        expect(kPressure.unit(id)!.signed, isTrue, reason: id);
      }
      for (final id in ['bara', 'kpaa', 'psia', 'kgfcm2a']) {
        expect(kPressure.unit(id)!.signed, isFalse, reason: id);
      }
      expect(kTemperature.unit('c')!.signed, isTrue);
    });
    test('이름: 파운드/제곱인치, kg/cm² (키로), 동력·중량', () {
      expect(kPressure.unit('psi')!.name, '파운드/제곱인치');
      expect(kPressure.unit('kgfcm2')!.name, 'kg/cm² (키로)');
      expect(kPower.unit('hp')!.name, '마력(HP)');
      expect(kPower.unit('ps')!.name, '미터마력(PS)');
      expect(kTorque.unit('ncm')!.name, '뉴턴센티미터');
      expect(kTorque.unit('kgfcm')!.name, '킬로그램힘센티미터');
      expect(kFlow.unit('m3h')!.name, '세제곱미터/시간');
      expect(kPower.label, '동력');
      expect(kMass.label, '중량');
    });
  });

  group('숫자 글', () {
    test('유효 7자리, 끝의 0은 뗀다', () {
      expect(formatNumber(25.4), '25.4');
      // 작은 수도 소수 10자리에서 자르지 않는다: 1 mmH₂O = 0.00000980665 MPa.
      expect(formatNumber(conv(kPressure, 'mmh2o', 1, 'mpa')), '0.00000980665');
      expect(formatNumber(1.5e-9), '0.0000000015');
      expect(formatNumber(1.23456789e-8), '0.00000001234568');
      expect(formatNumber(5e-10), '5.0000e-10'); // 1e-9 미만만 지수
      expect(formatNumber(1), '1');
      expect(formatNumber(14.503773773), '14.50377');
      expect(formatNumber(0.00012345), '0.00012345');
      expect(formatNumber(1234567.89), '1234568');
      expect(formatNumber(-40), '-40');
      expect(formatNumber(0), '0');
    });
    test('읽기: 천 단위 쉼표, 빈 칸·잘못된 글은 null', () {
      expect(parseNumber('1,000.5'), 1000.5);
      expect(parseNumber('1,000'), 1000);
      expect(parseNumber('12,345,678'), 12345678);
      expect(parseNumber(''), isNull);
      expect(parseNumber('-'), isNull);
      expect(parseNumber('abc'), isNull);
      expect(parseNumber('NaN'), isNull);
      expect(parseNumber('1.2.3'), isNull);
    });
    test('쉼표 소수점: "1,5"는 15가 아니라 1.5', () {
      expect(parseNumber('1,5'), 1.5);
      expect(parseNumber('-1,5'), -1.5);
      expect(parseNumber('0,25'), 0.25);
      expect(parseNumber('1,50'), 1.5);
      expect(parseNumber('1,2345'), 1.2345);
      expect(parseNumber('1,2,5'), isNull); // 쉼표 소수점이 둘
      expect(parseNumber('1.000,5'), isNull); // 점 뒤 쉼표
    });
    test('치는 중인 글은 알리지 않는다', () {
      expect(isPartialNumber('-'), isTrue);
      expect(isPartialNumber('.'), isTrue);
      expect(isPartialNumber('-.'), isTrue);
      expect(isPartialNumber('1.2.3'), isFalse);
      expect(isPartialInches('1-3/'), isTrue);
      expect(isPartialInches("4' 1-"), isTrue);
      expect(isPartialInches('abc'), isFalse);
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
      expect(fractionErrorText(0.075, '1-3/8"'), '1-3/8"보다 0.08mm 깁니다');
      expect(fractionErrorText(-0.1, '1/2"'), '1/2"보다 0.10mm 짧습니다');
      expect(fractionErrorText(0, '1"'), '오차 없음');
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
      expect(awgFor(3.31).atLeast, 12); // 표에 반올림해 적은 12 AWG(3.3088)
      expect(awgFor(0.52).atLeast, 20); // 20 AWG 0.5176
      expect(awgFor(34).atLeast, 1); // 2 AWG 33.6은 1% 넘게 가늘다
      expect(awgFor(3.4).atLeast, 10);
      expect(awgFor(6).atLeast, 8); // 10 AWG 5.26 < 6 → 8 AWG 8.37
    });
    test('AWG → SQ: 1/0 AWG 53.5mm² → 가장 가까운 50sq는 가늘고, 같거나 굵은 것은 70sq', () {
      final a = awgAreaMm2(parseAwg('1/0')!);
      expect(a, closeTo(53.5, 0.1));
      expect(sqFor(a).nearest, 50);
      expect(sqFor(a).atLeast, 70);
      expect(sqFor(awgAreaMm2(-3)).atLeast, 120); // 4/0 107.2 → 120sq
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
    test('ASME B36.10M 외경(mm 열): NPS 10 = 273.0, 12 = 323.8, 18 = 457', () {
      double asme(String a) => kPipeSizes.firstWhere((p) => p.a == a).asmeOd;
      expect(asme('250A'), 273.0);
      expect(asme('300A'), 323.8);
      expect(asme('450A'), 457);
      expect(asme('200A'), 219.1);
      expect(asme('65A'), 73.0);
    });
    test('측정한 외경 → 가장 가까운 호칭(5% 이내만)', () {
      final ks = [for (final p in kPipeSizes) (label: p.a, od: p.ksOd)];
      expect(nearestOd(48.6, ks)!.label, '40A');
      expect(nearestOd(48.0, ks)!.label, '40A');
      expect(nearestOd(27.5, ks)!.label, '20A');
      final tube = [
        for (final s in kTubeInchSizes) (label: s, od: parseInches(s)! * 25.4),
      ];
      expect(nearestOd(48.6, tube), isNull); // 1" 튜브 25.4와 멀다
      expect(nearestOd(12.8, tube)!.label, '1/2');
      expect(nearestOd(10, const []), isNull);
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
    test('배관 호칭은 표의 모든 이름으로 찾는다(20A · DN50 · 3/4B · 3/4" · 1 1/2B)', () {
      for (final q in [
        '20A',
        '25a',
        'DN50',
        'dn 100',
        '3/4B',
        '3/4"',
        '1-1/2B',
        '1 1/2B',
        'NPS 2',
        '500A',
        '5/8"',
      ]) {
        final h = searchUnits(q);
        expect(h, isNotEmpty, reason: q);
        expect(h.first.category.id, 'pipe', reason: q);
      }
    });
    test('게이지·절대압 이름: psig, barg, kg/cm2g, kgf/cm2g, psia, bar(a)', () {
      String first(String q) => searchUnits(q).first.unit!.id;
      expect(first('psig'), 'psi');
      expect(first('barg'), 'bar');
      expect(first('kg/cm2g'), 'kgfcm2');
      expect(first('kgf/cm2g'), 'kgfcm2');
      expect(first('psia'), 'psia');
      expect(first('bar(a)'), 'bara');
      expect(first('프사이'), 'psi');
      expect(first('피에스아이'), 'psi');
      expect(searchUnits('절대압').where((h) => h.unit != null).length, 4);
    });
    test('mAq·mH2O는 mH₂O가 먼저(mmH₂O로 가면 1000배 틀린다)', () {
      expect(searchUnits('mAq').first.unit!.id, 'mh2o');
      expect(searchUnits('mH2O').first.unit!.id, 'mh2o');
      expect(searchUnits('mmAq').first.unit!.id, 'mmh2o');
      expect(searchUnits('양정').first.unit!.id, 'mh2o');
    });
    test('이름이 딱 같은 것이 먼저: kg → 중량, kcal → 에너지, 파이 → mm', () {
      expect(searchUnits('kg').first.unit!.id, 'kg');
      expect(searchUnits('kcal').first.category.id, 'energy');
      expect(searchUnits('파이').first.unit!.id, 'mm'); // 파이프(배관 호칭)보다 먼저
      expect(searchUnits('ø').first.unit!.id, 'mm');
      expect(searchUnits('psi').first.unit!.id, 'psi'); // psia보다 먼저
      expect(searchUnits('냉동톤').first.category.id, 'power');
      expect(searchUnits('온도차').first.category.id, 'tempdiff');
      expect(searchUnits('12awg').first.category.id, 'wire');
      expect(searchUnits('2.5sq').first.category.id, 'wire');
    });
    test('분류 차례: 길이·압력·온도·토크·유량·전선·배관이 앞', () {
      expect(kUnitCategories.take(7).map((c) => c.id), [
        'length',
        'pressure',
        'temp',
        'torque',
        'flow',
        'wire',
        'pipe',
      ]);
    });
  });
}
