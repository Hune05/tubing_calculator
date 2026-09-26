// 4-20mA 계산 — 환산, 제곱근, NE43 상태, 교정 점검 오차·판정, 루프 전압.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/instrument/signal_calc.dart';

void main() {
  group('환산', () {
    test('4·12·20mA = 0·50·100%, 범위 0~10bar', () {
      expect(maFromPct(0), 4);
      expect(maFromPct(50), 12);
      expect(maFromPct(100), 20);
      expect(pctFromMa(8), 25);
      expect(pvFromMa(12, 0, 10, Transfer.linear), 5);
      expect(idealMa(7.5, 0, 10, Transfer.linear), 16);
    });
    test('음수 범위 −50~150°C: 0°C = 25% = 8mA', () {
      expect(idealMa(0, -50, 150, Transfer.linear), 8);
      expect(pvFromMa(4, -50, 150, Transfer.linear), -50);
    });
    test('범위가 거꾸로(100~0)여도 맞게: 25 → 75% → 16mA', () {
      expect(idealMa(25, 100, 0, Transfer.linear), 16);
    });
    test('제곱근: 유량 50% → 차압 25% → 8mA, 12mA(차압 50%) → 유량 70.71%', () {
      expect(idealMa(50, 0, 100, Transfer.sqrt), 8);
      expect(pvFromMa(12, 0, 100, Transfer.sqrt), closeTo(70.7107, 1e-4));
      expect(pvFromMa(3.9, 0, 100, Transfer.sqrt), 0); // 0 아래는 0
    });
  });

  test('NAMUR NE43 구간', () {
    expect(signalState(3.6), SignalState.failLow);
    expect(signalState(3.7), SignalState.gapLow);
    expect(signalState(3.8), SignalState.underRange);
    expect(signalState(4), SignalState.normal);
    expect(signalState(20), SignalState.normal);
    expect(signalState(20.5), SignalState.overRange);
    expect(signalState(20.8), SignalState.gapHigh);
    expect(signalState(21), SignalState.failHigh);
  });

  group('교정 점검', () {
    test('mA로 읽음: 50%(5bar)에서 12.08mA → +0.5% 스팬, ±0.5% 안이면 정상', () {
      final p = checkPoint(
        applied: 5,
        reading: 12.08,
        kind: ReadKind.ma,
        lrv: 0,
        urv: 10,
        tolPct: 0.5,
      );
      expect(p.idealMa, 12);
      expect(p.errMa, closeTo(0.08, 1e-9));
      expect(p.errPct, closeTo(0.5, 1e-9));
      expect(p.errPv, closeTo(0.05, 1e-9));
      expect(p.pass, isTrue);
      final q = checkPoint(
        applied: 5,
        reading: 12.1,
        kind: ReadKind.ma,
        lrv: 0,
        urv: 10,
        tolPct: 0.5,
      );
      expect(q.errPct, closeTo(0.625, 1e-9));
      expect(q.pass, isFalse);
    });
    test('지시값으로 읽음: 0~200°C, 넣은 100°C에 지시 99.2°C → −0.4%', () {
      final p = checkPoint(
        applied: 100,
        reading: 99.2,
        kind: ReadKind.pv,
        lrv: 0,
        urv: 200,
      );
      expect(p.errPct, closeTo(-0.4, 1e-9));
      expect(p.errMa, closeTo(-0.064, 1e-9));
      expect(p.pass, isNull); // 허용 오차 없으면 판정 안 함
    });
    test('넣은 값이 점과 조금 달라도(2.51bar) 그 값으로 이론 mA', () {
      final p = checkPoint(
        applied: 2.51,
        reading: 8.016,
        kind: ReadKind.ma,
        lrv: 0,
        urv: 10,
      );
      expect(p.idealMa, closeTo(8.016, 1e-9));
      expect(p.errPct, closeTo(0, 1e-9));
    });
  });

  group('루프 전압', () {
    test('24V, 250Ω, 전선 1.5sq 500m: 20mA 18.64V·21mA 18.37V, 최대 643Ω', () {
      final wire = wireLoopOhm(ohmPerKm: 12.1, lengthM: 500); // 12.1Ω
      expect(wire, closeTo(12.1, 1e-9));
      final lc = loopCheck(
        supplyV: 24,
        minV: 10.5,
        ohms: [250, 0, wire],
        checkMa: 21,
      );
      expect(lc.totalOhm, closeTo(262.1, 1e-9));
      expect(lc.volts20, closeTo(24 - 0.02 * 262.1, 1e-9));
      expect(lc.voltsCheck, closeTo(24 - 0.021 * 262.1, 1e-9));
      expect(lc.maxOhm, closeTo(642.857, 1e-3));
      expect(lc.okAtCheck(10.5), isTrue);
    });
    test('24V, 650Ω: 20mA는 11V로 되지만 21mA는 10.35V < 10.5V', () {
      final lc = loopCheck(supplyV: 24, minV: 10.5, ohms: [650], checkMa: 21);
      expect(lc.okAtCheck(10.5), isFalse);
      expect(lc.okAt20(10.5), isTrue);
    });
    test(
      '기본 확인 전류 23mA: 최대 루프 저항이 Rosemount 식 43.5 × (24 − 10.5) = 587Ω과 같다',
      () {
        final lc = loopCheck(supplyV: 24, minV: 10.5, ohms: [600]);
        expect(lc.checkMa, 23);
        expect(lc.maxOhm, closeTo(43.478 * 13.5, 0.5));
        expect(lc.okAtCheck(10.5), isFalse); // 600Ω는 587Ω 초과
        expect(kLoopCheckMa, [21, 21.75, 22.5, 23]);
      },
    );
    test('지시계 등 기타 전압 강하를 빼고 계산', () {
      final lc = loopCheck(supplyV: 24, minV: 10.5, ohms: [250], extraV: 2);
      expect(lc.volts20, closeTo(24 - 5 - 2, 1e-9));
      expect(lc.maxOhm, closeTo((24 - 10.5 - 2) / 0.023, 1e-9));
    });
  });

  group('제곱근·mA 입력·경계', () {
    test('전송기 제곱근 출력: 차압 25% → 유량 50% → 12mA, 12mA → 차압 25%', () {
      expect(idealMa(25, 0, 100, Transfer.sqrtOut), closeTo(12, 1e-9));
      expect(pvFromMa(12, 0, 100, Transfer.sqrtOut), closeTo(25, 1e-9));
      expect(idealMa(0, 0, 100, Transfer.sqrtOut), 4);
    });
    test('DCS 제곱근 + mA 측정: 10% 아래 점은 측정 단위 오차를 보이지 않는다(부풀려짐)', () {
      final p0 = checkPoint(
        applied: 0,
        reading: 4.02,
        kind: ReadKind.ma,
        lrv: 0,
        urv: 100,
        transfer: Transfer.sqrt,
      );
      expect(p0.errPct, closeTo(0.125, 1e-9));
      expect(p0.errPv.isNaN, isTrue);
      final p50 = checkPoint(
        applied: 50,
        reading: 8.02,
        kind: ReadKind.ma,
        lrv: 0,
        urv: 100,
        transfer: Transfer.sqrt,
      );
      expect(p50.errPv.isNaN, isFalse);
    });
    test('mA 입력 → 지시값: 12mA 넣고 5.05bar 읽으면 이론값 5bar, 오차 +0.5%', () {
      final p = checkPoint(
        applied: 12,
        reading: 5.05,
        kind: ReadKind.maIn,
        lrv: 0,
        urv: 10,
        tolPct: 0.5,
      );
      expect(p.expected, closeTo(5, 1e-9));
      expect(p.idealMa, 12);
      expect(p.errPct, closeTo(0.5, 1e-9));
      expect(p.errMa, closeTo(0.08, 1e-9));
      expect(p.pass, isTrue);
      expect(nominalInput(25, ReadKind.maIn, 0, 10), 8);
      expect(nominalInput(25, ReadKind.pv, 0, 10), 2.5);
    });
    test('거꾸로 된 범위(100~0)에서 지시값 오차 부호가 측정값 쪽과 같다', () {
      final p = checkPoint(
        applied: 50,
        reading: 51,
        kind: ReadKind.pv,
        lrv: 100,
        urv: 0,
      );
      expect(p.errPv, closeTo(1, 1e-9));
      expect(p.errPct, closeTo(1, 1e-9));
      expect(p.errMa, closeTo(-0.16, 1e-9)); // 지시값이 크면 mA는 작은 쪽
    });
    test('허용오차 0은 판정하지 않는다', () {
      final p = checkPoint(
        applied: 5,
        reading: 12.1,
        kind: ReadKind.ma,
        lrv: 0,
        urv: 10,
        tolPct: 0,
      );
      expect(p.pass, isNull);
    });
  });
}
