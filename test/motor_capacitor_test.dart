// 전동기 콘덴서·단상 운전·최대 토크: 원문 예제와 손계산 값으로 확인.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/electrical/motor_capacitor.dart';

void main() {
  group('콘덴서 한도(Schneider EIG 장 L)', () {
    test('원문 예: I0 10 A, 400 V → 6.24 kvar', () {
      expect(capacitorLimitKvar(10, 400)!, closeTo(0.9 * 10 * 0.4 * math.sqrt(3), 1e-12));
      expect(capacitorLimitKvar(10, 400)!, closeTo(6.24, 0.005));
    });
    test('무부하 전류 추정: In 41 A, cosφ 0.85 → 12.3 A (원문 도표 역산 12.8 A와 비슷)', () {
      expect(estimateNoLoadAmps(41, 0.85)!, closeTo(12.3, 1e-9));
      expect(estimateNoLoadAmps(41, 1.2), isNull);
    });
    test('계전기 설정 보정: 40 A, cosφ 0.8 → 0.95면 33.7 A', () {
      expect(relaySettingAfter(40, 0.8, 0.95)!, closeTo(40 * 0.8 / 0.95, 1e-12));
      expect(relaySettingAfter(40, 0.8, 0), isNull);
    });
    test('도표 L25 계수와 L24 최대 kvar', () {
      expect(kRelayFactorByRpm[750], 0.88);
      expect(kRelayFactorByRpm[1000], 0.90);
      expect(kRelayFactorByRpm[1500], 0.91);
      expect(kRelayFactorByRpm[3000], 0.93);
      expect(schneiderL24Kvar(22, 1500), 8);
      expect(schneiderL24Kvar(75, 3000), 17);
      expect(schneiderL24Kvar(450, 750), 117);
      expect(schneiderL24Kvar(23, 1500), isNull, reason: '표에 없는 용량');
      expect(schneiderL24Kvar(22, 1800), isNull, reason: '표에 없는 회전수');
    });
    test('원문 예 75 kW 3000 rpm 400 V → 17 kvar 이하와 식이 같은 크기(I0 약 27 A)', () {
      // 17 kvar = 0.9 × I0 × 0.4 × √3 → I0 = 27.3 A
      expect(17 / (0.9 * 0.4 * math.sqrt(3)), closeTo(27.3, 0.05));
    });
  });

  group('콘덴서 환산', () {
    test('100 μF, 220 V, 60 Hz → 8.29 A, 1.83 kvar', () {
      expect(capacitorAmps(100, 220, 60), closeTo(2 * math.pi * 60 * 100e-6 * 220, 1e-12));
      expect(capacitorAmps(100, 220, 60), closeTo(8.294, 0.001));
      expect(capacitorKvarOf(100, 220, 60), closeTo(1.825, 0.001));
    });
  });

  group('3상 모터 단상 운전(Steinmetz)', () {
    test('1 kW 230 V 50 Hz → 69.5 μF (자료의 약 70 μF/kW)', () {
      expect(steinmetzRunMicroFarad(1, 230, 50)!, closeTo(69.5, 0.1));
    });
    test('1 kW 220 V 60 Hz → 63.3 μF, 식 환산', () {
      expect(steinmetzRunMicroFarad(1, 220, 60)!, closeTo(63.3, 0.1));
    });
    test('용량은 출력에 비례한다', () {
      expect(steinmetzRunMicroFarad(2.2, 220, 60)!, closeTo(2.2 * steinmetzRunMicroFarad(1, 220, 60)!, 1e-9));
      expect(steinmetzRunMicroFarad(0, 220, 60), isNull);
    });
    test('콘덴서 무효전력은 출력의 약 1.155배', () {
      final c = steinmetzRunMicroFarad(1, 220, 60)!;
      expect(capacitorKvarOf(c, 220, 60), closeTo(2 / math.sqrt(3), 1e-9));
    });
  });

  group('단상 전동기 콘덴서', () {
    test('1.1 kW → 운전 22~55 μF', () {
      final r = singlePhaseRunRangeUf(1.1)!;
      expect(r.$1, closeTo(22, 1e-9));
      expect(r.$2, closeTo(55, 1e-9));
      expect(singlePhaseRunRangeUf(0), isNull);
    });
  });

  group('최대 토크', () {
    test('정격 60 N·m × 2.3배 = 138 N·m, 90 % 전압이면 81 %', () {
      expect(maxTorqueNm(60, 2.3), closeTo(138, 1e-9));
      expect(torqueAtVoltage(138, 0.9), closeTo(138 * 0.81, 1e-9));
      expect(maxTorqueNm(0, 2), isNull);
    });
    test('IEC 60034-12 설계 N: 표 값과 경계', () {
      expect(iecDesignNMinMultiple(5.5, 4), 2.0);
      expect(iecDesignNMinMultiple(11, 6), 1.8);
      expect(iecDesignNMinMultiple(30, 2), 1.9);
      expect(iecDesignNMinMultiple(75, 8), 1.6);
      expect(iecDesignNMinMultiple(300, 4), 1.6);
      expect(iecDesignNMinMultiple(0.5, 6), 1.7);
      expect(iecDesignNMinMultiple(0.63, 8), 1.6, reason: '0.63 kW 이하 행');
      expect(iecDesignNMinMultiple(0.7, 8), 1.7, reason: '0.63 초과 1.0 이하 행');
      expect(iecDesignNMinMultiple(11, 10), isNull);
    });
    test('NEMA MG-1 12.39 설계 A·B: 확인한 행과 모르는 행', () {
      expect(nemaAbMinPercent(1, 1800), 300);
      expect(nemaAbMinPercent(1, 3600), isNull, reason: '표에서 비어 있는 칸');
      expect(nemaAbMinPercent(3, 1200), 230);
      expect(nemaAbMinPercent(7.5, 900), 200);
      expect(nemaAbMinPercent(50, 1800), 200);
      expect(nemaAbMinPercent(300, 900), 175);
      expect(nemaAbMinPercent(4, 1800), isNull, reason: '표 행 밖(확인하지 못함)');
      expect(nemaAbMinPercent(150, 1800), isNull);
      expect(nemaAbMinPercent(10, 1750), isNull, reason: '동기 회전수가 아님');
    });
  });
}
