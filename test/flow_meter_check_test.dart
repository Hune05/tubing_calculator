// 유량계 점검: 명판 측정 범위·출력 방식으로 루프 mA ↔ 유량, 지시값 대조, 제곱근 잘못 건 경우 찾기.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/flow/flow_meter_check.dart';

void main() {
  group('mA ↔ 유량 %', () {
    test('차압식 제곱근(SQRT) 출력: mA가 유량에 비례, 12mA = 50%', () {
      expect(meterFlowPct(12, MeterType.dp, DpOut.sqrtOut), closeTo(50, 1e-9));
      expect(meterMa(50, MeterType.dp, DpOut.sqrtOut), closeTo(12, 1e-9));
    });

    test('차압식 차압 그대로(LINEAR): 8mA = 차압 25% = 유량 50%', () {
      expect(meterFlowPct(8, MeterType.dp, DpOut.linearDp), closeTo(50, 1e-9));
      expect(meterMa(50, MeterType.dp, DpOut.linearDp), closeTo(8, 1e-9));
      expect(dpPctOfFlow(50), closeTo(25, 1e-9));
      // 4mA 아래는 제곱근을 0으로
      expect(meterFlowPct(3.9, MeterType.dp, DpOut.linearDp), 0);
    });

    test('전자식·와류식·질량식은 설정과 관계없이 선형', () {
      for (final t in [MeterType.mag, MeterType.vortex, MeterType.coriolis]) {
        expect(meterFlowPct(8, t, DpOut.linearDp), closeTo(25, 1e-9));
        expect(meterMa(75, t, DpOut.linearDp), closeTo(16, 1e-9));
      }
    });
  });

  group('지시값 점검', () {
    test('차압식 SQRT 0~100m³/h, 12mA, 지시 50.4, 허용 ±0.5% → 합격', () {
      final r = checkMeter(
        ma: 12,
        lrv: 0,
        urv: 100,
        type: MeterType.dp,
        indicated: 50.4,
        tolSpanPct: 0.5,
      );
      expect(r.expected, closeTo(50, 1e-9));
      expect(r.errSpanPct, closeTo(0.4, 1e-9));
      expect(r.errReadPct, closeTo(0.8, 1e-9));
      expect(r.pass, isTrue);
      expect(r.mistake, isNull);
    });

    test('허용 오차가 없으면 판정하지 않는다', () {
      final r = checkMeter(
        ma: 12,
        lrv: 0,
        urv: 100,
        type: MeterType.mag,
        indicated: 55,
      );
      expect(r.pass, isNull);
      expect(r.errSpanPct, closeTo(5, 1e-9));
    });

    test('LINEAR 전송기인데 DCS가 제곱근을 안 함 → 찾아낸다', () {
      // 12mA = 차압 50% → 유량 70.71%. DCS가 선형이면 50을 보인다.
      final r = checkMeter(
        ma: 12,
        lrv: 0,
        urv: 100,
        type: MeterType.dp,
        dpOut: DpOut.linearDp,
        indicated: 50,
        tolSpanPct: 1,
      );
      expect(r.expected, closeTo(70.7107, 1e-3));
      expect(r.pass, isFalse);
      expect(r.mistake, SqrtMistake.none);
    });

    test('SQRT 전송기인데 DCS도 제곱근 → 제곱근 두 번을 찾아낸다', () {
      // 8mA = 유량 25%. DCS가 한 번 더 제곱근이면 50을 보인다.
      final r = checkMeter(
        ma: 8,
        lrv: 0,
        urv: 100,
        type: MeterType.dp,
        indicated: 50,
        tolSpanPct: 1,
      );
      expect(r.expected, closeTo(25, 1e-9));
      expect(r.mistake, SqrtMistake.twice);
    });

    test('전자식인데 DCS 태그에 제곱근이 켜진 경우도 찾아낸다', () {
      final r = checkMeter(
        ma: 8,
        lrv: 0,
        urv: 200,
        type: MeterType.mag,
        indicated: 100,
      );
      expect(r.expected, closeTo(50, 1e-9));
      expect(r.mistake, SqrtMistake.twice);
    });

    test('범위만 다르면 제곱근 탓으로 돌리지 않는다', () {
      // 12mA, 측정 범위 0~100인데 DCS가 0~120 → 60
      final r = checkMeter(
        ma: 12,
        lrv: 0,
        urv: 100,
        type: MeterType.dp,
        indicated: 60,
        tolSpanPct: 1,
      );
      expect(r.pass, isFalse);
      expect(r.mistake, isNull);
    });

    test('양방향 전자식 −100~100: 12mA = 0, 4mA = −100', () {
      var r = checkMeter(ma: 12, lrv: -100, urv: 100, type: MeterType.mag);
      expect(r.expected, closeTo(0, 1e-9));
      r = checkMeter(ma: 4, lrv: -100, urv: 100, type: MeterType.mag);
      expect(r.expected, closeTo(-100, 1e-9));
      // 기대값 0이면 지시 % 오차는 없다
      r = checkMeter(
        ma: 12,
        lrv: -100,
        urv: 100,
        type: MeterType.mag,
        indicated: 1,
      );
      expect(r.errReadPct, isNull);
      expect(r.errSpanPct, closeTo(0.5, 1e-9));
    });

    test('소유량 차단 아래면 0이 정상', () {
      // 4.5mA = 3.125% < 차단 5%
      final r = checkMeter(
        ma: 4.5,
        lrv: 0,
        urv: 100,
        type: MeterType.vortex,
        indicated: 0,
        tolSpanPct: 0.5,
        cutPct: 5,
      );
      expect(r.cutOff, isTrue);
      expect(r.expected, 0);
      expect(r.pass, isTrue);
    });
  });
}
