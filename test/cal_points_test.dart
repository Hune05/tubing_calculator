// 시험점(3·5·11점, 하강 포함)·히스테리시스 판정·기록 JSON(예전 기록 호환)·CSV·성적서.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/instrument/cal_record.dart';
import 'package:tubing_calculator/src/presentation/instrument/cal_record_pdf.dart';
import 'package:tubing_calculator/src/presentation/instrument/signal_calc.dart';
import 'package:tubing_calculator/src/presentation/instrument/temp_sensor.dart';

/// 0~10 bar, 5점 + 하강. 상승 4.00·8.02·12.03·16.02·20.00, 하강 16.05·12.06·8.04·4.01 mA.
final _updown = calPointList(CalPointSet.p5, withDown: true);
const _readings = [4.0, 8.02, 12.03, 16.02, 20.0, 16.05, 12.06, 8.04, 4.01];
List<CalEntry> get _entries => [
  for (final r in _readings) CalEntry(reading: r),
];

CalSummary _eval({double? tol, double? hyst}) => evaluateCal(
  entries: _entries,
  lrv: 0,
  urv: 10,
  transfer: Transfer.linear,
  kind: ReadKind.ma,
  tolPct: tol,
  points: _updown,
  hystTolPct: hyst,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('시험점 묶음: 3·5·11점, 하강 포함이면 맨 위에서 되돌아 내려온다', () {
    expect(calPointList(CalPointSet.p3).map((d) => d.pct), [0, 50, 100]);
    expect(calPointList(CalPointSet.p5), kDefaultCalPoints);
    expect(calPointList(CalPointSet.p11).length, 11);
    expect(_updown.map((d) => d.pct), [0, 25, 50, 75, 100, 75, 50, 25, 0]);
    expect(_updown.where((d) => d.down).length, 4);
    expect(calPointList(CalPointSet.p11, withDown: true).length, kMaxCalRows);
    expect(calPointLabel(_updown, 2), '상승 50%');
    expect(calPointLabel(_updown, 6), '하강 50%');
    expect(calPointLabel(kDefaultCalPoints, 2), '50%');
    expect(calPointsText(_updown), '5점 상승·하강');
    expect(calPointsText(calPointList(CalPointSet.p3)), '3점');
    for (final s in CalPointSet.values) {
      for (final d in [false, true]) {
        expect(calSetOf(calPointList(s, withDown: d)), (s, d));
      }
    }
    expect(calSetOf(const [CalPointDef(0), CalPointDef(30)]), isNull);
    expect(calSetLabel(CalPointSet.p5), '5점(0·25·50·75·100)');
  });

  test('히스테리시스 = |상승 오차 % − 하강 오차 %|, 하강 점에 적는다', () {
    final s = _eval(tol: 0.5);
    // 오차 % 계산은 점마다 그대로(하강 75%: (16.05 − 16) ÷ 16 × 100)
    expect(s.points[5]!.errPct, closeTo(0.3125, 1e-9));
    expect(s.points[3]!.errPct, closeTo(0.125, 1e-9));
    expect(s.hystAt(3), isNull); // 상승 점에는 없다
    expect(s.hystAt(4), isNull); // 100%는 짝이 없다
    expect(s.hystAt(5), closeTo(0.1875, 1e-9)); // 75%
    expect(s.hystAt(6), closeTo(0.1875, 1e-9)); // 50%
    expect(s.hystAt(7), closeTo(0.125, 1e-9)); // 25%
    expect(s.hystAt(8), closeTo(0.0625, 1e-9)); // 0%
    expect(s.maxHyst!.$1, 5);
    expect(s.maxHyst!.$2, closeTo(0.1875, 1e-9));
    // 허용값이 없으면 히스테리시스는 판정하지 않는다
    expect(s.hystPass(5), isNull);
    expect(s.pass, isTrue);
    // 조정 한계(허용오차 50% = 0.25%)는 그대로: 하강 75%(0.3125%), 하강 50%(0.375%)
    expect(s.adjustAdvised, [5, 6]);
  });

  test('히스테리시스 허용값을 넣으면 넘은 하강 점은 불합격', () {
    final s = _eval(tol: 0.5, hyst: 0.15);
    expect(s.hystFailed, [5, 6]);
    expect(s.errFailed, isEmpty);
    expect(s.failed, [5, 6]);
    expect(s.rowPass(5), isFalse);
    expect(s.rowPass(7), isTrue);
    expect(s.pass, isFalse);
    // 불합격 점은 조정 권장에서 뺀다
    expect(s.adjustAdvised, isEmpty);
    // 허용오차 없이 히스테리시스 허용값만: 상승 점은 판정 없음, 하강 점만 판정
    final h = _eval(hyst: 0.2);
    expect(h.rowPass(0), isNull);
    expect(h.rowPass(5), isTrue);
    expect(h.pass, isTrue);
    // 둘 다 없으면 판정 없음
    expect(_eval().pass, isNull);
    // 0 이하는 넣지 않은 것과 같다
    expect(_eval(tol: 0.5, hyst: 0).hystTolPct, isNull);
  });

  test('상승만 측정했으면 히스테리시스 없음', () {
    final s = evaluateCal(
      entries: [for (final r in _readings.take(5)) CalEntry(reading: r)],
      lrv: 0,
      urv: 10,
      transfer: Transfer.linear,
      kind: ReadKind.ma,
      points: _updown,
      hystTolPct: 0.1,
    );
    expect(s.maxHyst, isNull);
    expect(s.pass, isNull);
  });

  test('기록 JSON: 시험점·히스테리시스 허용값·센서·냉접점을 저장하고 읽는다', () {
    final r = CalRecord(
      id: 'h',
      date: DateTime(2026, 9, 26),
      tag: 'TT-301',
      lrv: 0,
      urv: 200,
      unit: '°C',
      tolPct: 0.5,
      points: _updown,
      hystTolPct: 0.1,
      sensor: TempSensor.k,
      cjC: 20,
      found: _entries,
    );
    final back = CalRecord.fromJson(
      jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>,
    );
    expect(back.points, _updown);
    expect(back.hystTolPct, 0.1);
    expect(back.sensor, TempSensor.k);
    expect(back.cjC, 20);
    expect(back.foundSummary.maxHyst!.$2, closeTo(0.1875, 1e-9));
    expect(calSensorText(back.sensor, back.cjC), 'K형 (IEC 60584-1), 냉접점 20 °C');
    expect(calSensorText(TempSensor.pt100, null), 'Pt100 (IEC 60751)');
    expect(calSensorText(null, null), '');
  });

  test('예전 기록(시험점 칸 없음)은 5점 상승으로 읽힌다', () {
    // 2026-09-26 이전 모양 그대로의 JSON
    const old =
        '{"id":"o","date":"2026-09-20T10:00:00.000","nextDue":null,"tag":"PT-1",'
        '"instrument":"","model":"","refStd":"","worker":"","ambient":"","memo":"",'
        '"lrv":0,"urv":10,"unit":"bar","transfer":"linear","kind":"ma","tol":0.5,'
        '"found":[{"a":null,"r":4.02},{"a":null,"r":null},{"a":null,"r":12.1},'
        '{"a":null,"r":null},{"a":10,"r":19.96}],"left":[]}';
    final r = CalRecord.fromJson(jsonDecode(old) as Map<String, dynamic>);
    expect(r.points, kDefaultCalPoints);
    expect(r.hystTolPct, isNull);
    expect(r.sensor, isNull);
    expect(r.foundSummary.failed, [2]);
    expect(r.foundSummary.maxHyst, isNull);
  });

  test('요약 CSV: 예전 칸은 그대로, 뒤에 시험점·히스테리시스·센서 칸', () {
    final r = CalRecord(
      id: 'c',
      date: DateTime(2026, 9, 26),
      tag: 'PT-5',
      lrv: 0,
      urv: 10,
      unit: 'bar',
      tolPct: 0.5,
      points: _updown,
      hystTolPct: 0.15,
      found: _entries,
    );
    final lines = calRecordsCsv([r]).trim().split('\r\n');
    final head = lines[0].split(',');
    final row = lines[1].split(',');
    expect(head.length, row.length);
    expect(head.sublist(head.length - 5), [
      '시험점',
      '히스테리시스 허용값(%)',
      '조정 전 최대 히스테리시스(%)',
      '조정 후 최대 히스테리시스(%)',
      '센서',
    ]);
    expect(row.sublist(row.length - 5), ['5점 상승·하강', '0.15', '0.1875', '', '']);
    // 고정 칸의 50% 점은 상승 50%(12.03, 오차 0.1875)
    final i50 = head.indexOf('조정 전 50% 측정값');
    expect(row[i50], '12.03');
    expect(row[i50 + 1], '0.1875');
    // 히스테리시스 불합격이 판정에 들어간다
    expect(row[head.indexOf('조정 전 판정')], '불합격');

    // 3점 기록: 25·75% 칸은 비어 있다
    final three = CalRecord(
      id: 't',
      date: DateTime(2026, 9, 26),
      tag: 'PT-6',
      lrv: 0,
      urv: 10,
      points: calPointList(CalPointSet.p3),
      found: const [CalEntry(reading: 4), CalEntry(reading: 12.01)],
    );
    final l3 = calRecordsCsv([three]).trim().split('\r\n');
    final h3 = l3[0].split(','), r3 = l3[1].split(',');
    expect(r3[h3.indexOf('조정 전 25% 측정값')], '');
    expect(r3[h3.indexOf('조정 전 50% 측정값')], '12.01');
  });

  test('측정점 CSV: 측정한 점마다 한 줄, 방향·히스테리시스·판정', () {
    final r = CalRecord(
      id: 'p',
      date: DateTime(2026, 9, 26),
      tag: 'PT-7',
      lrv: 0,
      urv: 10,
      unit: 'bar',
      tolPct: 0.5,
      points: _updown,
      hystTolPct: 0.15,
      found: _entries,
      left: const [CalEntry(reading: 4.0)],
    );
    final csv = calPointsCsv([r]);
    expect(csv.startsWith('﻿태그 번호,교정일,구분,방향,측정점(%),'), isTrue);
    final lines = csv.trim().split('\r\n');
    expect(lines.length, 1 + 9 + 1); // 머리줄 + 조정 전 9점 + 조정 후 1점
    expect(
      lines[6],
      'PT-7,2026-09-26,조정 전,하강,75,7.5,bar,16,16.05,mA,0.3125,0.1875,불합격,전송기 출력(mA)',
    );
    expect(
      lines[1],
      startsWith('PT-7,2026-09-26,조정 전,상승,0,0,bar,4,4,mA,0,,합격,'),
    );
    expect(lines.last, startsWith('PT-7,2026-09-26,조정 후,상승,0,'));
  });

  test('성적서 PDF: 하강 점·히스테리시스·센서가 있어도 만들어진다', () async {
    final a = await buildCalRecordPdf(
      CalRecord(
        id: 'q',
        date: DateTime(2026, 9, 26),
        tag: 'TT-1',
        lrv: 0,
        urv: 100,
        unit: '°C',
        kind: ReadKind.pv,
        tolPct: 0.5,
        points: calPointList(CalPointSet.p11, withDown: true),
        hystTolPct: 0.1,
        sensor: TempSensor.pt100,
        found: const [
          CalEntry(reading: 0.1),
          CalEntry(reading: 10),
          CalEntry(),
          CalEntry(),
          CalEntry(),
          CalEntry(),
          CalEntry(),
          CalEntry(),
          CalEntry(),
          CalEntry(),
          CalEntry(reading: 100),
          CalEntry(),
          CalEntry(),
          CalEntry(),
          CalEntry(),
          CalEntry(),
          CalEntry(),
          CalEntry(),
          CalEntry(),
          CalEntry(reading: 10.3),
          CalEntry(reading: 0.2),
        ],
      ),
    );
    expect(latin1.decode(a.sublist(0, 5)), '%PDF-');
    expect(a.length, greaterThan(10000));
  });
}
