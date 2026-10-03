// 전동기 공식 추가분: 전압·역률 구하기, 펌프·팬 동력, 상사법칙, 가속 시간. 손으로 푼 값과 맞춘다.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/electrical/motor_formula.dart';

void main() {
  group('전압·역률 구하기', () {
    test('전류 식과 서로 되돌린다: 11 kW 380 V 효율 .9 역률 .85 → 전류 → 전압·역률', () {
      final r = motorElectrical(kw: 11, volts: 380, eff: 0.9, pf: 0.85, three: true)!;
      expect(motorVoltage(kw: 11, amps: r.current, eff: 0.9, pf: 0.85, three: true)!, closeTo(380, 1e-9));
      expect(motorPowerFactor(kw: 11, volts: 380, amps: r.current, eff: 0.9, three: true)!, closeTo(0.85, 1e-12));
    });
    test('단상 전압', () {
      expect(
        motorVoltage(kw: 2.2, amps: 12.5, eff: 0.8, pf: 0.8, three: false)!,
        closeTo(2200 / (12.5 * 0.8 * 0.8), 1e-9),
      );
    });
    test('역률이 1을 넘는 입력은 null(값이 서로 안 맞음)', () {
      expect(motorPowerFactor(kw: 20, volts: 380, amps: 10, eff: 0.9, three: true), isNull);
    });
  });

  group('펌프·팬 동력', () {
    test('펌프 60 m³/h, 양정 30 m, 효율 70 %: 수동력 4.90 kW, 축동력 7.0 kW, 여유 15 % 8.06 kW', () {
      final r = pumpPower(flowM3h: 60, headM: 30, pumpEff: 0.7, margin: 0.15)!;
      expect(r.hydraulicKw, closeTo(1000 * 9.80665 * (60 / 3600) * 30 / 1000, 1e-9));
      expect(r.hydraulicKw, closeTo(4.903, 0.001));
      expect(r.shaftKw, closeTo(7.005, 0.001));
      expect(r.motorKw, closeTo(7.005 * 1.15, 0.002));
    });
    test('한국식 간이식 0.163 × Q[m³/min] × H ÷ η 와 같다', () {
      final r = pumpPower(flowM3h: 60, headM: 30, pumpEff: 0.7)!;
      expect(r.shaftKw, closeTo(0.163 * (60 / 60) * 30 / 0.7, 0.03));
    });
    test('팬 7200 m³/h, 1200 Pa, 효율 65 % → 공기동력 2.4 kW', () {
      final r = fanPower(flowM3h: 7200, pressurePa: 1200, fanEff: 0.65)!;
      expect(r.hydraulicKw, closeTo(2.4, 1e-9));
      expect(r.shaftKw, closeTo(2.4 / 0.65, 1e-9));
    });
    test('전달 효율은 전동기 소요 출력을 키운다', () {
      final a = pumpPower(flowM3h: 60, headM: 30, pumpEff: 0.7)!;
      final b = pumpPower(flowM3h: 60, headM: 30, pumpEff: 0.7, driveEff: 0.95)!;
      expect(b.motorKw, closeTo(a.motorKw / 0.95, 1e-9));
    });
    test('표준 목록 올림', () {
      const l = [1.5, 2.2, 3.7, 5.5, 7.5, 11.0];
      expect(roundUpToList(5.6, l), 7.5);
      expect(roundUpToList(7.5, l), 7.5);
      expect(roundUpToList(12, l), isNull);
    });
    test('잘못된 값은 null', () {
      expect(pumpPower(flowM3h: 0, headM: 30, pumpEff: 0.7), isNull);
      expect(pumpPower(flowM3h: 60, headM: 30, pumpEff: 1.2), isNull);
      expect(fanPower(flowM3h: 100, pressurePa: -5, fanEff: 0.6), isNull);
    });
  });

  group('상사법칙', () {
    test('1800 → 1500 rpm(r = 0.8333): 유량 ×0.833, 양정 ×0.694, 동력 ×0.579', () {
      final a = affinity(n1: 1800, n2: 1500, q1: 100, h1: 30, p1: 11)!;
      expect(a.ratio, closeTo(1500 / 1800, 1e-12));
      expect(a.flow!, closeTo(100 * 1500 / 1800, 1e-9));
      expect(a.head!, closeTo(30 * math.pow(1500 / 1800, 2), 1e-9));
      expect(a.power!, closeTo(11 * math.pow(1500 / 1800, 3), 1e-9));
      expect(a.power!, closeTo(6.366, 0.001));
    });
    test('속도 절반이면 동력은 1/8', () {
      expect(affinity(n1: 1000, n2: 500, p1: 8)!.power, closeTo(1, 1e-12));
    });
    test('없는 기준값은 null로 둔다', () {
      final a = affinity(n1: 1800, n2: 900, q1: 10)!;
      expect(a.head, isNull);
      expect(a.power, isNull);
    });
  });

  group('가속 시간', () {
    test('J 2.0 kg·m², 1750 rpm, 평균 전동기 토크 90 N·m, 부하 30 N·m → 6.1 초', () {
      final r = accelTime(totalJ: 2.0, rpm: 1750, motorAvgNm: 90, loadAvgNm: 30)!;
      expect(r.accelTorqueNm, 60);
      expect(r.seconds, closeTo(2.0 * (2 * math.pi * 1750 / 60) / 60, 1e-9));
      expect(r.seconds, closeTo(6.108, 0.001));
    });
    test('환산 관성: 부하 축 900 rpm의 J 10, 전동기 1800 rpm → 2.5', () {
      expect(reflectedInertia(10, 900, 1800), closeTo(2.5, 1e-12));
    });
    test('GD² 4 kgf·m² → J 1', () {
      expect(gd2ToJ(4), 1);
    });
    test('부하 토크가 평균 전동기 토크 이상이면 기동하지 못한다(null)', () {
      expect(accelTime(totalJ: 2, rpm: 1750, motorAvgNm: 30, loadAvgNm: 30), isNull);
      expect(accelTime(totalJ: 2, rpm: 1750, motorAvgNm: 30, loadAvgNm: 50), isNull);
    });
  });
}
