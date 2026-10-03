import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/electrical/ground_calc.dart';
import 'package:tubing_calculator/src/presentation/electrical/motor_protect.dart';

void main() {
  group('접지', () {
    test('보호도체 표 142.3-1: 16 이하 그대로, 35까지 16, 넘으면 절반', () {
      expect(protectiveConductorFromTable(10), 10);
      expect(protectiveConductorFromTable(16), 16);
      expect(protectiveConductorFromTable(25), 16);
      expect(protectiveConductorFromTable(35), 16);
      expect(protectiveConductorFromTable(50), 25);
      expect(protectiveConductorFromTable(70), 35);
    });

    test('단열 식 S = I√t / k (손 계산: 10 kA, 0.5 s, PVC 구리 143 → 49.45)', () {
      final s = adiabaticMinArea(fault: 10000, seconds: 0.5, k: 143)!;
      expect(s, closeTo(10000 * math.sqrt(0.5) / 143, 1e-9));
      expect(s, closeTo(49.45, 0.01));
      expect(roundUpToStd(s), 50);
      expect(
        adiabaticMinArea(fault: 10000, seconds: 6, k: 143),
        isNull,
      ); // 5초 초과
      expect(adiabaticMinArea(fault: 0, seconds: 1, k: 143), isNull);
    });

    test('k 값: PVC·XLPE 구리·알루미늄, 따로 포설/묶음', () {
      expect(
        groundK(GroundMaterial.copper, GroundInsulation.pvc, separate: true),
        143,
      );
      expect(
        groundK(GroundMaterial.copper, GroundInsulation.xlpe, separate: true),
        176,
      );
      expect(
        groundK(GroundMaterial.aluminum, GroundInsulation.pvc, separate: true),
        95,
      );
      expect(
        groundK(GroundMaterial.aluminum, GroundInsulation.xlpe, separate: true),
        116,
      );
      expect(
        groundK(GroundMaterial.copper, GroundInsulation.pvc, separate: false),
        115,
      );
      expect(
        groundK(GroundMaterial.copper, GroundInsulation.xlpe, separate: false),
        143,
      );
      expect(
        groundK(GroundMaterial.aluminum, GroundInsulation.pvc, separate: false),
        76,
      );
      expect(
        groundK(
          GroundMaterial.aluminum,
          GroundInsulation.xlpe,
          separate: false,
        ),
        94,
      );
    });

    test('접지도체 최소(2026 개정): 구리 6/16, 철 50, 알루미늄 불가', () {
      expect(groundingConductorMin(material: 'cu', highVoltage: false).mm2, 6);
      expect(groundingConductorMin(material: 'cu', highVoltage: true).mm2, 16);
      expect(groundingConductorMin(material: 'fe', highVoltage: false).mm2, 50);
      expect(
        groundingConductorMin(material: 'al', highVoltage: false).mm2,
        isNull,
      );
    });

    test('본딩 도체: 가장 큰 보호도체 절반, 6 이상, 25 상한', () {
      expect(bondingConductorMinCopper(10), 6);
      expect(bondingConductorMinCopper(16), 8);
      expect(bondingConductorMinCopper(35), 17.5);
      expect(bondingConductorMinCopper(70), 25);
    });

    test('중성점 접지저항: 150/I, 300/I, 600/I (I = 1선 지락전류)', () {
      expect(neutralGroundMaxOhms(10), 15);
      expect(neutralGroundMaxOhms(10, trip: 'within2s'), 30);
      expect(neutralGroundMaxOhms(10, trip: 'within1s'), 60);
      expect(neutralGroundMaxOhms(0), isNull);
    });

    test('TT: 30 mA 1,667 Ω · 100 mA 500 Ω · 1 A 50 Ω, 직류 120 V', () {
      expect(ttMaxOhms(0.03), closeTo(1666.67, 0.01));
      expect(ttMaxOhms(0.1), 500);
      expect(ttMaxOhms(1), 50);
      expect(ttMaxOhms(0.03, dc: true), 4000);
    });

    test('접지봉: ρ 100, 길이 2.4 m, 지름 14.2 mm 손 계산', () {
      final r = rodResistance(rho: 100, lengthM: 2.4, diaMm: 14.2)!;
      final expected =
          100 / (2 * math.pi * 2.4) * (math.log(4 * 2.4 / 0.0071) - 1);
      expect(r, closeTo(expected, 1e-9));
      expect(r, closeTo(41.2, 0.1));
      // 병렬: 4본, 간격 3 m → K 1.2
      expect(rodsParallel(r, 4, spacingM: 3), closeTo(1.2 * r / 4, 1e-9));
      // 간격 10 m 초과 → K 1.0, 1 m 미만은 쓸 수 없음
      expect(rodsParallel(r, 2, spacingM: 12), closeTo(r / 2, 1e-9));
      expect(rodsParallel(r, 2, spacingM: 0.5), isNull);
      expect(rodsParallel(r, 1, spacingM: 2), r);
      expect(rodResistance(rho: 100, lengthM: 0, diaMm: 14), isNull);
    });
  });

  group('전동기 보호', () {
    test('열동 설정: 직입 = 정격, Y-Δ 델타 내부 = 정격/√3(0.577), 라인 = 정격', () {
      expect(thrSetting(40), 40);
      expect(
        thrSetting(
          40,
          method: StartMethod.starDelta,
          place: RelayPlace.insideDelta,
        ),
        closeTo(40 / math.sqrt(3), 1e-9),
      );
      expect(
        thrSetting(40, method: StartMethod.starDelta, place: RelayPlace.line),
        40,
      );
    });

    test('NEC 430.32 상한: 125% / 115%', () {
      expect(necOverloadMax(40, sf115OrTemp40: true), 50);
      expect(necOverloadMax(40, sf115OrTemp40: false), 46);
    });

    test('EOCR 부하 설정 범위: 운전전류의 110~125%', () {
      final (lo, hi) = eocrRange(30);
      expect(lo, closeTo(33, 1e-9));
      expect(hi, closeTo(37.5, 1e-9));
    });

    test('트립 클래스: 기동시간이 상한 이상이면 주의', () {
      expect(startMayTrip('10', 5), isFalse);
      expect(startMayTrip('10', 10), isTrue);
      expect(startMayTrip('20', 12), isFalse);
      expect(startMayTrip('30', 31), isTrue);
      expect(startMayTrip('없음', 5), isNull);
      expect(startMayTrip('10', 0), isNull);
    });

    test('NEC 430.52 최대 정격: 25 HP 460 V 34 A × 250% = 85 A', () {
      expect(necShortCircuitMax(34, '반한시 차단기'), 85);
      expect(necShortCircuitMax(34, '이중소자(지연) 퓨즈'), closeTo(59.5, 1e-9));
      expect(necShortCircuitMax(34, '비지연 퓨즈'), 102);
      expect(necShortCircuitMax(34, '순시트립 차단기'), 272);
    });

    test('전선 허용전류 하한: FLC × 125%', () {
      expect(motorConductorMin(34), 42.5);
    });
  });
}
