// 교정 기록 — 조정 전·후 판정, JSON, 폰 저장(넣기·고치기·지우기), 성적서 PDF.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/instrument/cal_record.dart';
import 'package:tubing_calculator/src/presentation/instrument/cal_record_pdf.dart';
import 'package:tubing_calculator/src/presentation/instrument/signal_calc.dart';

CalRecord sample({String id = '1', List<CalEntry> left = const []}) =>
    CalRecord(
      id: id,
      date: DateTime(2026, 9, 26, 13, 5),
      tag: 'PT-101',
      instrument: '급수 펌프 토출 압력',
      model: 'Rosemount 3051',
      refStd: 'Fluke 754 #1234',
      worker: '홍길동',
      lrv: 0,
      urv: 10,
      unit: 'bar',
      tolPct: 0.5,
      found: const [
        CalEntry(reading: 4.02),
        CalEntry(reading: 8.05),
        CalEntry(reading: 12.1),
        CalEntry(),
        CalEntry(applied: 10, reading: 19.96),
      ],
      left: left,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('조정 전만: 50% 점 넘음 → 최종 판정 넘음(조정 전 기준)', () {
    final r = sample();
    final s = r.foundSummary;
    expect(s.measured.length, 4);
    expect(s.failed, [2]);
    expect(s.pass, isFalse);
    expect(s.worst!.$1, 2);
    expect(r.adjusted, isFalse);
    expect(r.finalPass, isFalse);
  });

  test('조정 후를 넣으면 최종 판정은 조정 후 기준', () {
    final r = sample(
      left: const [
        CalEntry(reading: 4.0),
        CalEntry(reading: 8.01),
        CalEntry(reading: 12.02),
        CalEntry(reading: 15.99),
        CalEntry(reading: 20.0),
      ],
    );
    expect(r.adjusted, isTrue);
    expect(r.leftSummary.pass, isTrue);
    expect(r.finalPass, isTrue);
  });

  test('허용 오차가 없으면 판정 없음(null)', () {
    final r = CalRecord(
      id: 'x',
      date: DateTime(2026),
      tag: 'T',
      lrv: 0,
      urv: 10,
      found: const [CalEntry(reading: 12.1)],
    );
    expect(r.foundSummary.pass, isNull);
    expect(r.finalPass, isNull);
    expect(calVerdictText(null), '판정 없음');
  });

  test('JSON으로 저장했다 읽어도 같다(제곱근·지시값·빈 칸)', () {
    final r = CalRecord(
      id: '7',
      date: DateTime(2026, 9, 26),
      tag: 'FT-201',
      lrv: 0,
      urv: 100,
      unit: 'm3/h',
      transfer: Transfer.sqrt,
      kind: ReadKind.pv,
      found: const [CalEntry(applied: 1, reading: 1.2), CalEntry()],
      left: const [CalEntry(reading: 50)],
    );
    final back = CalRecord.fromJson(
      jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>,
    );
    expect(back.tag, 'FT-201');
    expect(back.transfer, Transfer.sqrt);
    expect(back.kind, ReadKind.pv);
    expect(back.tolPct, isNull);
    expect(back.found[0].applied, 1);
    expect(back.found[1].reading, isNull);
    expect(back.left.single.reading, 50);
  });

  test('폰 저장: 넣기 → 같은 id는 고치기 → 지우기, 최근 것이 앞', () async {
    SharedPreferences.setMockInitialValues({'user_real_name': '차재훈'});
    expect(await CalRecordStore.load(), isEmpty);
    expect((await CalRecordStore.lastWorkerAndRef()).$1, '차재훈');
    await CalRecordStore.put(sample(id: 'a'));
    final newer = CalRecord(
      id: 'b',
      date: DateTime(2026, 9, 27),
      tag: 'TT-5',
      worker: '김',
      refStd: 'REF',
      lrv: 0,
      urv: 1,
      found: const [CalEntry(reading: 4)],
    );
    await CalRecordStore.put(newer);
    var l = await CalRecordStore.load();
    expect(l.map((e) => e.id), ['b', 'a']);
    expect(await CalRecordStore.lastWorkerAndRef(), ('김', 'REF'));
    // 같은 id → 바뀜(늘지 않음)
    await CalRecordStore.put(
      CalRecord(
        id: 'a',
        date: DateTime(2026, 9, 26),
        tag: 'PT-101A',
        lrv: 0,
        urv: 10,
        found: const [],
      ),
    );
    l = await CalRecordStore.load();
    expect(l.length, 2);
    expect(l.firstWhere((e) => e.id == 'a').tag, 'PT-101A');
    await CalRecordStore.delete('b');
    expect((await CalRecordStore.load()).map((e) => e.id), ['a']);
  });

  test('망가진 저장 값은 빈 목록', () async {
    SharedPreferences.setMockInitialValues({CalRecordStore.key: '{깨짐'});
    expect(await CalRecordStore.load(), isEmpty);
  });

  test('성적서 PDF가 만들어진다(조정 전·후, 지시값 역산 열)', () async {
    final a = await buildCalRecordPdf(
      sample(left: const [CalEntry(reading: 12.0)]),
    );
    expect(latin1.decode(a.sublist(0, 5)), '%PDF-');
    expect(a.length, greaterThan(10000));
    final b = await buildCalRecordPdf(
      CalRecord(
        id: 'p',
        date: DateTime(2026, 9, 26),
        tag: 'TT 7/8',
        lrv: -50,
        urv: 150,
        unit: 'C',
        kind: ReadKind.pv,
        tolPct: 1,
        found: const [CalEntry(), CalEntry(reading: 0.5)],
        memo: '센서 교체 뒤 점검',
      ),
    );
    expect(latin1.decode(b.sublist(0, 5)), '%PDF-');
    expect(
      calRecordFileName(
        CalRecord(
          id: 'p',
          date: DateTime(2026, 9, 6),
          tag: 'TT 7/8',
          lrv: 0,
          urv: 1,
          found: const [],
        ),
      ),
      'cal_TT_7_8_20260906.pdf',
    );
  });
  test('조정 한계: 허용오차 ±0.5%의 50%(0.25%)를 넘은 합격 점은 조정 권장', () {
    final r = CalRecord(
      id: 'a',
      date: DateTime(2026, 9, 26),
      tag: 'T',
      lrv: 0,
      urv: 10,
      tolPct: 0.5,
      found: const [
        CalEntry(reading: 4.01), // +0.0625% 합격
        CalEntry(reading: 8.05), // +0.3125% 합격이지만 조정 권장
        CalEntry(reading: 12.1), // +0.625% 불합격
      ],
    );
    expect(r.foundSummary.adjustAdvised, [1]);
    expect(r.foundSummary.failed, [2]);
    expect(calVerdictText(true), '합격');
    expect(calVerdictText(false), '불합격');
  });

  test('mA 입력 방법: 입력값을 비우면 4·8·12mA가 들어간다', () {
    final r = CalRecord(
      id: 'b',
      date: DateTime(2026, 9, 26),
      tag: 'TI',
      lrv: 0,
      urv: 200,
      kind: ReadKind.maIn,
      found: const [CalEntry(), CalEntry(), CalEntry(reading: 101)],
    );
    final p = r.foundSummary.points[2]!;
    expect(p.applied, 12);
    expect(p.expected, closeTo(100, 1e-9));
    expect(p.errPct, closeTo(0.5, 1e-9));
  });

  test('차기 교정일·주위 조건도 저장했다 읽으면 같다', () {
    final r = CalRecord(
      id: 'c',
      date: DateTime(2026, 9, 26),
      nextDue: DateTime(2027, 9, 26),
      tag: 'X',
      ambient: '23°C, 45%RH',
      lrv: 0,
      urv: 1,
      found: const [],
    );
    final back = CalRecord.fromJson(
      jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>,
    );
    expect(back.nextDue, DateTime(2027, 9, 26));
    expect(back.ambient, '23°C, 45%RH');
    // 예전 기록(차기 교정일 칸 없음)도 읽힌다
    final old = Map<String, dynamic>.from(r.toJson())
      ..remove('nextDue')
      ..remove('ambient');
    expect(CalRecord.fromJson(old).nextDue, isNull);
  });

  test('CSV: BOM, 머리줄, 한 기록 한 줄, 쉼표 든 칸은 따옴표', () {
    final csv = calRecordsCsv([
      CalRecord(
        id: 'd',
        date: DateTime(2026, 9, 26),
        nextDue: DateTime(2027, 9, 26),
        tag: 'PT-101',
        memo: '밸브 교체, 재점검',
        lrv: 0,
        urv: 10,
        unit: 'bar',
        tolPct: 0.5,
        found: const [CalEntry(), CalEntry(), CalEntry(reading: 12.1)],
        left: const [CalEntry(), CalEntry(), CalEntry(reading: 12.0)],
      ),
    ]);
    expect(csv.startsWith('﻿태그 번호,'), isTrue);
    final lines = csv.trim().split('\r\n');
    expect(lines.length, 2);
    expect(lines[1], startsWith('PT-101,,,2026-09-26,2027-09-26,0,10,bar,선형,'));
    expect(lines[1], contains('"밸브 교체, 재점검"'));
    expect(lines[1], contains(',0.625,불합격,0,합격,합격,'));
    // 50% 점 조정 전: 입력값 5, 측정값 12.1, 오차 0.625
    expect(lines[1], contains(',5,12.1,0.625,'));
  });
}
