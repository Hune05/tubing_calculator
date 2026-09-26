// 온도 센서 환산: IEC 60751(Pt100·Pt1000)과 NIST ITS-90 열전대 표 값, 역산 왕복, 적용 범위.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/instrument/temp_sensor.dart';

/// NIST ITS-90 Thermocouple Database 표(type_x.tab, 기준접점 0 °C, mV)에서 옮긴 값.
const Map<TempSensor, List<(double, double)>> _nist = {
  TempSensor.k: [
    (-200, -5.891),
    (-100, -3.554),
    (0, 0),
    (100, 4.096),
    (300, 12.209),
    (500, 20.644),
    (1000, 41.276),
    (1372, 54.886),
  ],
  TempSensor.j: [
    (-210, -8.095),
    (-100, -4.633),
    (100, 5.269),
    (400, 21.848),
    (760, 42.919),
    (1000, 57.953),
    (1200, 69.553),
  ],
  TempSensor.t: [
    (-270, -6.258),
    (-200, -5.603),
    (-100, -3.379),
    (100, 4.279),
    (200, 9.288),
    (400, 20.872),
  ],
  TempSensor.e: [
    (-200, -8.825),
    (-100, -5.237),
    (100, 6.319),
    (500, 37.005),
    (1000, 76.373),
  ],
  TempSensor.n: [
    (-200, -3.990),
    (-100, -2.407),
    (100, 2.774),
    (500, 16.748),
    (1000, 36.256),
    (1300, 47.513),
  ],
  TempSensor.r: [
    (-50, -0.226),
    (0, 0),
    (100, 0.647),
    (500, 4.471),
    (1064, 11.361),
    (1500, 17.451),
    (1768, 21.101),
  ],
  TempSensor.s: [
    (-50, -0.236),
    (0, 0),
    (100, 0.646),
    (500, 4.233),
    (1064, 10.332),
    (1500, 15.582),
    (1768, 18.693),
  ],
  TempSensor.b: [
    (0, 0),
    (100, 0.033),
    (250, 0.291),
    (600, 1.792),
    (1000, 4.834),
    (1500, 10.099),
    (1820, 13.820),
  ],
};

void main() {
  group('측온저항체 IEC 60751', () {
    test(
      'Pt100 표 값: 0 °C 100 Ω, 100 °C 138.506 Ω, −100 °C 60.256 Ω (±0.001 Ω)',
      () {
        expect(rtdOhm(0), closeTo(100, 1e-9));
        expect(rtdOhm(100), closeTo(138.506, 0.001));
        expect(rtdOhm(-100), closeTo(60.256, 0.001));
        // 식 그대로 손으로 계산한 값: 100 × (1 + A·100 + B·100²) = 138.5055
        expect(rtdOhm(100), closeTo(138.5055, 1e-9));
        // 100 × (1 − 0.39083 − 0.005775 − 0.0008366) = 60.25584
        expect(rtdOhm(-100), closeTo(60.25584, 1e-9));
      },
    );

    test('Pt100 IEC 표(0.01 Ω 단위로 인쇄된 값)와 반올림 폭 안에서 같다', () {
      const table = [
        (-200.0, 18.52),
        (-50.0, 80.31),
        (200.0, 175.86),
        (300.0, 212.05),
        (400.0, 247.09),
        (600.0, 313.71),
        (850.0, 390.48),
      ];
      for (final (t, r) in table) {
        expect(rtdOhm(t), closeTo(r, 0.005), reason: '$t °C');
      }
    });

    test('Pt1000은 Pt100의 10배', () {
      expect(rtdOhm(100, r0: 1000), closeTo(1385.055, 1e-6));
      expect(rtdOhm(-100, r0: 1000), closeTo(602.5584, 1e-6));
      expect(sensorValue(TempSensor.pt1000, 100), closeTo(1385.1, 0.05));
    });

    test('저항 → 온도 왕복: −200 ~ 850 °C에서 ±0.01 °C 이내', () {
      for (var t = -200.0; t <= 850; t += 2.5) {
        for (final r0 in [100.0, 1000.0]) {
          final back = rtdTemp(rtdOhm(t, r0: r0)!, r0: r0)!;
          expect(back, closeTo(t, 0.01), reason: '$t °C, R0 $r0');
        }
      }
      expect(rtdTemp(138.5055), closeTo(100, 1e-6));
      expect(rtdTemp(60.25584), closeTo(-100, 1e-6));
    });

    test('범위(−200 ~ 850 °C)를 벗어나면 null', () {
      expect(rtdOhm(-201), isNull);
      expect(rtdOhm(851), isNull);
      expect(rtdTemp(18), isNull);
      expect(rtdTemp(400), isNull);
      expect(TempSensor.pt100.tempRange, (-200.0, 850.0));
    });
  });

  group('열전대 NIST ITS-90', () {
    for (final e in _nist.entries) {
      test('${e.key.label}: NIST 표 값과 ±0.001 mV 이내', () {
        expect(e.value.length, greaterThanOrEqualTo(5));
        for (final (t, mv) in e.value) {
          expect(tcEmf(e.key, t), closeTo(mv, 0.001), reason: '$t °C');
        }
      });

      test('${e.key.label}: mV → °C 왕복 ±0.01 °C 이내(역함수 범위 전체)', () {
        final (lo, hi) = e.key.inverseTempRange;
        for (var t = lo; t <= hi; t += 3.7) {
          final back = tcTemp(e.key, tcEmf(e.key, t)!)!;
          expect(back, closeTo(t, 0.01), reason: '$t °C');
        }
        expect(tcTemp(e.key, tcEmf(e.key, hi)!), closeTo(hi, 0.01));
        expect(tcTemp(e.key, tcEmf(e.key, lo)!), closeTo(lo, 0.01));
      });
    }

    test('작업 지시에 적힌 값: K 100·500·1000 °C, J 100 °C, T 100 °C', () {
      expect(tcEmf(TempSensor.k, 100), closeTo(4.096, 0.001));
      expect(tcEmf(TempSensor.k, 500), closeTo(20.644, 0.001));
      expect(tcEmf(TempSensor.k, 1000), closeTo(41.276, 0.001));
      expect(tcEmf(TempSensor.j, 100), closeTo(5.269, 0.001));
      expect(tcEmf(TempSensor.t, 100), closeTo(4.279, 0.001));
    });

    test('적용 범위: 기준 함수 범위 밖 온도와 역함수 범위 밖 mV는 null', () {
      expect(tcEmf(TempSensor.k, 1373), isNull);
      expect(tcEmf(TempSensor.k, -271), isNull);
      expect(tcEmf(TempSensor.t, 401), isNull);
      expect(tcEmf(TempSensor.b, -1), isNull);
      expect(tcTemp(TempSensor.k, 55), isNull);
      // −200 °C(−5.891 mV) 아래는 NIST 역함수가 없다. B형 역함수는 250 °C부터.
      expect(tcTemp(TempSensor.k, -6.0), isNull);
      expect(tcTemp(TempSensor.b, 0.2), isNull);
      expect(TempSensor.k.tempRange, (-270.0, 1372.0));
      expect(TempSensor.k.inverseTempRange, (-200.0, 1372.0));
      expect(TempSensor.b.inverseTempRange, (250.0, 1820.0));
      expect(TempSensor.r.tempRange, (-50.0, 1768.1));
    });

    test('냉접점 보상: K형 100 °C, 냉접점 20 °C → 교정기에 넣을 mV 3.298', () {
      // NIST 표: E(100) = 4.096, E(20) = 0.798 → 3.298
      expect(tcEmf(TempSensor.k, 20), closeTo(0.798, 0.001));
      expect(
        calibratorValue(TempSensor.k, 100, cjC: 20),
        closeTo(3.298, 0.001),
      );
      expect(calibratorValue(TempSensor.k, 100), closeTo(4.096, 0.001));
      expect(
        tempFromMeasured(
          TempSensor.k,
          calibratorValue(TempSensor.k, 100, cjC: 20)!,
          cjC: 20,
        ),
        closeTo(100, 1e-6),
      );
      // 측온저항체는 냉접점과 상관없다
      expect(
        calibratorValue(TempSensor.pt100, 100, cjC: 20),
        closeTo(138.5055, 1e-9),
      );
      // 냉접점 온도가 범위를 벗어나면 null(B형은 0 °C부터)
      expect(calibratorValue(TempSensor.b, 600, cjC: -5), isNull);
    });
  });

  test('단위가 섭씨인지', () {
    for (final u in ['°C', '℃', 'C', 'c', ' degC ']) {
      expect(isCelsiusUnit(u), isTrue, reason: u);
    }
    for (final u in ['bar', 'K', '°F', '']) {
      expect(isCelsiusUnit(u), isFalse, reason: u);
    }
  });

  test('이름·단위·규격', () {
    expect(TempSensor.pt100.label, 'Pt100');
    expect(TempSensor.k.label, 'K형');
    expect(TempSensor.pt1000.unit, 'Ω');
    expect(TempSensor.s.unit, 'mV');
    expect(TempSensor.pt100.standard, 'IEC 60751');
    expect(TempSensor.n.standard, 'IEC 60584-1');
  });
}
