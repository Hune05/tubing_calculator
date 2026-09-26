// 스위치 시험: 동작점 오차·데드밴드·반복성·판정, 기록 JSON(예전 기록 호환), CSV, 성적서 PDF.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/instrument/cal_record.dart';
import 'package:tubing_calculator/src/presentation/instrument/cal_record_pdf.dart';
import 'package:tubing_calculator/src/presentation/instrument/switch_check.dart';
import 'package:tubing_calculator/src/presentation/instrument/temp_sensor.dart';

const _reps = [
  SwitchRepeat(trip: 5.05, reset: 4.6),
  SwitchRepeat(trip: 5.12, reset: 4.7),
  SwitchRepeat(trip: 4.98, reset: 4.55),
];

CalRecord _record({
  String id = 's1',
  SwitchSpec spec = const SwitchSpec(setpoint: 5, tol: 0.1),
  List<SwitchRepeat> found = _reps,
  List<SwitchRepeat> left = const [],
  double lrv = 0,
  double urv = 10,
  String unit = 'bar',
  TempSensor? sensor,
  double? cjC,
}) => CalRecord(
  id: id,
  date: DateTime(2026, 9, 26, 10, 0),
  tag: 'PSH-101',
  instrument: '보일러 급수 고압 스위치',
  lrv: lrv,
  urv: urv,
  unit: unit,
  found: const [],
  sw: spec,
  swFound: found,
  swLeft: left,
  sensor: sensor,
  cjC: cjC,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('계산', () {
    test('상승 동작: 오차·범위 %·데드밴드·반복성·평균, 반복 2가 허용오차 초과', () {
      final s = evaluateSwitch(
        spec: const SwitchSpec(setpoint: 5, tol: 0.1),
        repeats: _reps,
        range: (0, 10),
      );
      expect(s.measured.length, 3);
      final r0 = s.rows[0]!;
      expect(r0.err, closeTo(0.05, 1e-9));
      expect(r0.errPct, closeTo(0.5, 1e-9));
      expect(r0.deadband, closeTo(0.45, 1e-9));
      expect(r0.tripPass, isTrue);
      expect(r0.wrongSide, isFalse);
      expect(s.rows[1]!.tripPass, isFalse); // +0.12 > 0.1
      expect(s.rows[2]!.err, closeTo(-0.02, 1e-9));
      expect(s.repeatability, closeTo(0.14, 1e-9));
      expect(s.avgTrip, closeTo(5.05, 1e-9));
      expect(s.avgReset, closeTo(4.6166667, 1e-6));
      expect(s.avgDeadband, closeTo((0.45 + 0.42 + 0.43) / 3, 1e-9));
      expect(s.worst!.$1, 1);
      expect(s.failed, [1]);
      expect(s.pass, isFalse);
    });

    test('허용오차 경계값은 합격, 반복 한 번이면 반복성 없음', () {
      final s = evaluateSwitch(
        spec: const SwitchSpec(setpoint: 5, tol: 0.1),
        repeats: const [SwitchRepeat(trip: 5.1), SwitchRepeat()],
      );
      expect(s.rows[0]!.tripPass, isTrue);
      expect(s.rows[0]!.errPct, isNull); // 범위 없음
      expect(s.rows[1], isNull);
      expect(s.repeatability, isNull);
      expect(s.pass, isTrue);
    });

    test('% 범위 허용오차: 범위가 있으면 스팬 %로 바꾸고, 없으면 판정 없음', () {
      const spec = SwitchSpec(setpoint: 5, tol: 1, tolMode: SwitchTolMode.pct);
      final a = evaluateSwitch(spec: spec, repeats: _reps, range: (0, 10));
      expect(a.tolUnit, closeTo(0.1, 1e-12));
      expect(a.pass, isFalse);
      final b = evaluateSwitch(spec: spec, repeats: _reps);
      expect(b.tolUnit, isNull);
      expect(b.tolNeedsRange, isTrue);
      expect(b.pass, isNull);
      // 거꾸로 된 범위도 스팬은 절댓값
      final c = evaluateSwitch(spec: spec, repeats: _reps, range: (10, 0));
      expect(c.tolUnit, closeTo(0.1, 1e-12));
    });

    test('허용오차·데드밴드 허용 범위가 없으면 판정 없음', () {
      final s = evaluateSwitch(
        spec: const SwitchSpec(setpoint: 5),
        repeats: _reps,
      );
      expect(s.pass, isNull);
      expect(s.rows[0]!.pass, isNull);
    });

    test('복귀점 설정값: 복귀점 오차를 같은 허용오차로 판정', () {
      final s = evaluateSwitch(
        spec: const SwitchSpec(setpoint: 5, resetSet: 4.5, tol: 0.1),
        repeats: const [
          SwitchRepeat(trip: 5.02, reset: 4.55),
          SwitchRepeat(trip: 5.02, reset: 4.3),
          SwitchRepeat(trip: 5.02),
        ],
      );
      expect(s.rows[0]!.resetErr, closeTo(0.05, 1e-9));
      expect(s.rows[0]!.resetPass, isTrue);
      expect(s.rows[1]!.resetErr, closeTo(-0.2, 1e-9));
      expect(s.rows[1]!.resetPass, isFalse);
      expect(s.rows[1]!.pass, isFalse);
      expect(s.rows[2]!.resetPass, isNull);
      expect(s.rows[2]!.pass, isTrue); // 동작점만 판정
      expect(s.resetMissing, [2]);
      expect(s.failed, [1]);
    });

    test('데드밴드 설정값: 데드밴드 − 설정값을 판정, 복귀점 목표는 방향에 따라', () {
      const up = SwitchSpec(setpoint: 5, dbSet: 0.5, tol: 0.1);
      expect(up.resetTarget, 4.5);
      const down = SwitchSpec(
        setpoint: 2,
        dbSet: 0.3,
        dir: SwitchDir.falling,
        tol: 0.1,
      );
      expect(down.resetTarget, closeTo(2.3, 1e-12));
      final s = evaluateSwitch(
        spec: up,
        repeats: const [SwitchRepeat(trip: 5.0, reset: 4.3)],
      );
      expect(s.rows[0]!.deadband, closeTo(0.7, 1e-9));
      expect(s.rows[0]!.resetErr, closeTo(0.2, 1e-9));
      expect(s.rows[0]!.resetPass, isFalse);
    });

    test('데드밴드 허용 범위: 최소 미만·최대 초과는 불합격, 허용오차 없이도 판정', () {
      const spec = SwitchSpec(setpoint: 5, dbMin: 0.2, dbMax: 0.5);
      final s = evaluateSwitch(
        spec: spec,
        repeats: const [
          SwitchRepeat(trip: 5, reset: 4.4), // 0.6 초과
          SwitchRepeat(trip: 5, reset: 4.9), // 0.1 미만
          SwitchRepeat(trip: 5, reset: 4.7), // 0.3
        ],
      );
      expect(s.rows[0]!.dbRangePass, isFalse);
      expect(s.rows[1]!.dbRangePass, isFalse);
      expect(s.rows[2]!.dbRangePass, isTrue);
      expect(s.rows[2]!.tripPass, isNull);
      expect(s.failed, [0, 1]);
      expect(s.pass, isFalse);
      expect(switchDbRangeText(spec, 'bar'), '0.2 ~ 0.5 bar');
      expect(
        switchDbRangeText(const SwitchSpec(setpoint: 0, dbMin: 0.2)),
        '0.2 이상',
      );
      expect(
        switchDbRangeText(const SwitchSpec(setpoint: 0, dbMax: 0.5), 'bar'),
        '0.5 bar 이하',
      );
    });

    test('복귀점이 동작 방향과 반대쪽이면 표시(판정에는 넣지 않음)', () {
      final up = evaluateSwitch(
        spec: const SwitchSpec(setpoint: 5, tol: 0.1),
        repeats: const [SwitchRepeat(trip: 5, reset: 5.4)],
      );
      expect(up.rows[0]!.wrongSide, isTrue);
      expect(up.rows[0]!.deadband, closeTo(0.4, 1e-9));
      expect(up.pass, isTrue);
      final down = evaluateSwitch(
        spec: const SwitchSpec(setpoint: 2, dir: SwitchDir.falling, tol: 0.1),
        repeats: const [
          SwitchRepeat(trip: 1.95, reset: 2.3),
          SwitchRepeat(trip: 1.95, reset: 1.8),
        ],
      );
      expect(down.rows[0]!.wrongSide, isFalse);
      expect(down.rows[1]!.wrongSide, isTrue);
    });

    test('글: 허용오차·방향·접점·센서 값', () {
      expect(
        switchTolText(const SwitchSpec(setpoint: 0, tol: 0.1), 'bar'),
        '±0.1 bar',
      );
      expect(
        switchTolText(
          const SwitchSpec(setpoint: 0, tol: 0.5, tolMode: SwitchTolMode.pct),
        ),
        '±0.5% 범위',
      );
      expect(switchTolText(const SwitchSpec(setpoint: 0)), '');
      expect(switchDirLabel(SwitchDir.falling), '하강 동작');
      expect(switchContactLabel(SwitchContact.nc), 'NC (b접점)');
      expect(switchSensorText(TempSensor.pt100, 100), 'Pt100 138.506 Ω');
      expect(
        switchSensorText(TempSensor.k, 100, cjC: 20),
        'K형 4.096 mV, 냉접점 20 °C면 3.298 mV',
      );
      expect(switchSensorText(TempSensor.pt100, 900), 'Pt100 범위 초과');
    });
  });

  group('기록', () {
    test('JSON 왕복: 스위치 설정·반복 값·센서', () {
      final r = _record(
        spec: const SwitchSpec(
          setpoint: 80,
          dir: SwitchDir.falling,
          resetSet: 85,
          tol: 0.5,
          tolMode: SwitchTolMode.pct,
          dbMin: 2,
          dbMax: 8,
          contact: SwitchContact.nc,
        ),
        found: const [SwitchRepeat(trip: 79.5, reset: 84.8), SwitchRepeat()],
        left: const [SwitchRepeat(trip: 80.1)],
        unit: '°C',
        lrv: 0,
        urv: 150,
        sensor: TempSensor.k,
        cjC: 25,
      );
      final back = CalRecord.fromJson(
        jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>,
      );
      expect(back.isSwitch, isTrue);
      final sp = back.sw!;
      expect(sp.dir, SwitchDir.falling);
      expect(sp.setpoint, 80);
      expect(sp.resetSet, 85);
      expect(sp.dbSet, isNull);
      expect(sp.tolMode, SwitchTolMode.pct);
      expect(sp.tol, 0.5);
      expect(sp.dbMin, 2);
      expect(sp.dbMax, 8);
      expect(sp.contact, SwitchContact.nc);
      expect(back.swFound.length, 2);
      expect(back.swFound[0].reset, 84.8);
      expect(back.swFound[1].trip, isNull);
      expect(back.swLeft.single.trip, 80.1);
      expect(back.sensor, TempSensor.k);
      expect(back.cjC, 25);
      expect(back.adjusted, isTrue);
      // 조정 후 기준: 80.1, 허용오차 0.5% × 150 = 0.75 → 합격
      expect(back.finalPass, isTrue);
      expect(back.foundPass, isTrue);
    });

    test('예전 기록(type 칸 없음)은 전송기 기록으로 읽힌다', () {
      final old = {
        'id': 'o',
        'date': '2026-09-01T09:00:00.000',
        'tag': 'PT-1',
        'lrv': 0,
        'urv': 10,
        'unit': 'bar',
        'tol': 0.5,
        'found': [
          {'a': null, 'r': 4.01},
        ],
        'left': [],
      };
      final r = CalRecord.fromJson(old);
      expect(r.isSwitch, isFalse);
      expect(r.swFound, isEmpty);
      expect(r.toJson().containsKey('type'), isFalse);
      expect(r.foundPass, isTrue);
      expect(r.finalPass, isTrue);
    });

    test('조정 후가 없으면 조정 전 기준, 범위 없음(0% = 100%)이면 % 없음', () {
      final r = _record(lrv: 3, urv: 3);
      expect(r.switchRange, isNull);
      expect(r.adjusted, isFalse);
      expect(r.finalPass, isFalse); // 반복 2 초과
      expect(r.swFoundSummary.rows[0]!.errPct, isNull);
    });

    test('요약 CSV: 스위치 기록은 같은 칸 수, 시험 종류·설정·최대 오차·반복성', () {
      final r = _record(
        spec: const SwitchSpec(
          setpoint: 5,
          dbSet: 0.5,
          tol: 1,
          tolMode: SwitchTolMode.pct,
          dbMin: 0.3,
          dbMax: 0.6,
          contact: SwitchContact.no,
        ),
        left: const [
          SwitchRepeat(trip: 5.01, reset: 4.52),
          SwitchRepeat(trip: 5.03, reset: 4.5),
        ],
      );
      final tx = CalRecord(
        id: 't',
        date: DateTime(2026, 9, 25),
        tag: 'PT-1',
        lrv: 0,
        urv: 10,
        found: const [CalEntry(reading: 4)],
      );
      final lines = calRecordsCsv([r, tx]).trim().split('\r\n');
      final head = lines[0].split(',');
      final row = lines[1].split(',');
      expect(row.length, head.length);
      expect(lines[2].split(',').length, head.length);
      String c(String h) => row[head.indexOf(h)];
      expect(c('태그 번호'), 'PSH-101');
      expect(c('측정 방법'), '스위치 시험');
      expect(c('0% 값'), '0');
      expect(c('100% 값'), '10');
      expect(c('허용오차(±%)'), '1');
      expect(c('조정 전 최대 오차(%)'), '1.2'); // +0.12 bar / 10 bar
      expect(c('조정 전 판정'), '불합격');
      expect(c('조정 후 판정'), '합격');
      expect(c('최종 판정'), '합격');
      expect(c('시험점'), '반복 3회');
      expect(c('시험 종류'), '스위치');
      expect(c('동작 방향'), '상승 동작');
      expect(c('동작점 설정값'), '5');
      expect(c('복귀점 설정값'), '');
      expect(c('데드밴드 설정값'), '0.5');
      expect(c('스위치 허용오차(±단위)'), '0.1');
      expect(c('데드밴드 허용 범위'), '0.3 ~ 0.6');
      expect(c('접점'), 'NO (a접점)');
      expect(c('조정 전 최대 동작점 오차'), '0.12');
      expect(c('조정 전 반복성'), '0.14');
      expect(c('조정 후 반복성'), '0.02');
      expect(c('조정 전 50% 측정값'), '');
      final txRow = lines[2].split(',');
      expect(txRow[head.indexOf('시험 종류')], '전송기');
    });

    test('측정점 CSV: 스위치는 반복마다 한 줄(조정 전·후)', () {
      final r = _record(
        spec: const SwitchSpec(setpoint: 5, resetSet: 4.5, tol: 0.1),
        left: const [SwitchRepeat(trip: 5.01)],
      );
      final lines = calPointsCsv([r]).trim().split('\r\n');
      final head = lines[0].split(',');
      expect(head.sublist(head.length - 6), [
        '시험 종류',
        '반복',
        '복귀점',
        '데드밴드',
        '동작점 오차',
        '복귀 오차',
      ]);
      expect(lines.length, 1 + 3 + 1);
      expect(
        lines[2],
        'PSH-101,2026-09-26,조정 전,상승 동작,50,,bar,5,5.12,bar,1.2,,불합격,스위치 시험,'
        '스위치,2,4.7,0.42,0.12,0.2',
      );
      expect(
        lines[4],
        startsWith('PSH-101,2026-09-26,조정 후,상승 동작,50,,bar,5,5.01,'),
      );
      expect(lines[4].split(',').length, head.length);
    });

    test('성적서 PDF: 스위치 기록(범위·센서·조정 후 있음/없음)', () async {
      for (final r in [
        _record(),
        _record(
          lrv: 0,
          urv: 0,
          spec: const SwitchSpec(
            setpoint: 120,
            dir: SwitchDir.falling,
            dbSet: 5,
            tol: 1,
            dbMin: 2,
            dbMax: 8,
            contact: SwitchContact.nc,
          ),
          found: const [
            SwitchRepeat(trip: 119.2, reset: 124),
            SwitchRepeat(trip: 121.5, reset: 130),
            SwitchRepeat(trip: 120.4),
          ],
          left: const [SwitchRepeat(trip: 120.1, reset: 125)],
          unit: '°C',
          sensor: TempSensor.pt100,
        ),
      ]) {
        final a = await buildCalRecordPdf(r);
        expect(latin1.decode(a.sublist(0, 5)), '%PDF-');
        expect(a.length, greaterThan(10000));
      }
    });
  });
}
