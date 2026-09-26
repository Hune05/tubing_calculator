// 압력시험 기록: 판정(공압 온도 보정·수압 물 온도 참고·유지시간·허용 압력강하·누설 확인), JSON,
// 폰 저장(넣기·고치기·지우기·시험자·압력계 기억), CSV, 기록서 PDF, 알림 문구.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/hold_alarm.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/pressure_calc.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/pressure_units.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/test_record.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/test_record_pdf.dart';

final t0 = DateTime(2026, 9, 26, 9, 0, 0);

List<PtReading> reads({
  double p1 = 700,
  double? t1 = 20,
  double p2 = 700,
  double? t2 = 20,
  int endMin = 12,
  bool withEnd = true,
}) => [
  PtReading(at: t0, kpa: p1, tempC: t1, kind: PtReadKind.start),
  PtReading(at: t0.add(const Duration(minutes: 5)), kpa: (p1 + p2) / 2),
  if (withEnd)
    PtReading(
      at: t0.add(Duration(minutes: endMin)),
      kpa: p2,
      tempC: t2,
      kind: PtReadKind.end,
    ),
];

PtRecord sample({String id = '1', DateTime? date, String line = 'P-1001'}) =>
    PtRecord(
      id: id,
      date: date ?? t0,
      testNo: 'PT-001',
      site: '당진 발전소',
      system: '급수 계통',
      line: line,
      pid: 'P&ID-100, ISO-12',
      section: 'V-101 ~ P-201A',
      code: PipingCode.b313,
      medium: TestMedium.pneumatic,
      fluid: PtFluid.nitrogen,
      designKpa: 1000,
      testKpa: 1200,
      unit: PUnit.bar,
      holdMin: 10,
      startAt: t0,
      endAt: t0.add(const Duration(minutes: 12)),
      readings: reads(p1: 1200, p2: 1195),
      allowKpa: 10,
      leakOk: true,
      gauges: const [
        PtGauge(no: 'PG-01', range: '0~25 bar', calDue: '2027-03-31'),
        PtGauge(no: 'PG-02', range: '0~25 bar', calDue: '2027-01-15'),
      ],
      reliefKpa: 1320,
      reliefNo: 'PSV-1',
      tester: '차재훈',
      witnessContractor: '김시공',
      witnessSupervisor: '이감리',
      witnessOwner: '박발주',
      memo: '비눗물 점검, 이상 없음',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('판정', () {
    test(
      '공압: 7bar 20°C → 6.7266bar 10°C는 온도 때문(보정 후 거의 0), 누설 확인·유지시간 → 합격',
      () {
        final v = judgePressureTest(
          medium: TestMedium.pneumatic,
          readings: reads(p2: 672.66, t2: 10),
          holdMin: 10,
          allowKpa: 1,
          leakOk: true,
        );
        expect(v.started, isTrue);
        expect(v.ended, isTrue);
        expect(v.elapsedMin, closeTo(12, 1e-9));
        expect(v.holdMet, isTrue);
        expect(v.rawDropKpa, closeTo(27.34, 1e-9));
        expect(v.correctedDropKpa!.abs(), lessThan(0.01));
        expect(v.tempCorrected, isTrue);
        expect(v.dropOk, isTrue);
        expect(v.pass, isTrue);
        expect(v.reasons(PUnit.bar), isEmpty);
        final d = v.details(PUnit.bar).join('\n');
        expect(d, contains('측정 압력강하: 0.27 bar'));
        expect(d, contains('온도 보정 후 압력강하: 0 bar'));
        expect(d, contains('허용 압력강하 0.01 bar: 이내'));
        expect(d, contains('유지시간: 12분 경과 (규정 10분 이상)'));
      },
    );

    test('유지시간 미만이면 불합격, 이유를 적는다', () {
      final v = judgePressureTest(
        medium: TestMedium.pneumatic,
        readings: reads(endMin: 8),
        holdMin: 10,
        leakOk: true,
      );
      expect(v.holdMet, isFalse);
      expect(v.pass, isFalse);
      expect(v.reasons(PUnit.bar), ['경과 시간 8분: 유지시간 10분 미만']);
    });

    test('허용 압력강하 초과면 불합격(온도 보정한 강하로)', () {
      final v = judgePressureTest(
        medium: TestMedium.pneumatic,
        readings: reads(p2: 690),
        holdMin: 10,
        allowKpa: 5,
        leakOk: true,
      );
      expect(v.correctedDropKpa, closeTo(10, 1e-9));
      expect(v.dropOk, isFalse);
      expect(v.pass, isFalse);
      expect(v.reasons(PUnit.bar), ['압력강하 0.1 bar: 허용 압력강하 0.05 bar 초과']);
    });

    test('누설·물맺힘 없음을 확인하지 않으면 합격이 아니다(판정 없음), 다른 불합격 이유와 같이 적는다', () {
      var v = judgePressureTest(
        medium: TestMedium.hydro,
        readings: reads(),
        holdMin: 10,
      );
      expect(v.pass, isNull);
      expect(v.reasons(PUnit.bar), ['누설·물맺힘 없음(육안 확인)을 확인하지 않았습니다.']);
      v = judgePressureTest(
        medium: TestMedium.hydro,
        readings: reads(endMin: 3),
        holdMin: 10,
      );
      expect(v.pass, isFalse);
      expect(v.reasons(PUnit.bar).length, 2);
    });

    test('종료 전·시작 전은 판정 없음', () {
      var v = judgePressureTest(
        medium: TestMedium.hydro,
        readings: reads(withEnd: false),
        holdMin: 10,
        leakOk: true,
      );
      expect(v.started, isTrue);
      expect(v.ended, isFalse);
      expect(v.pass, isNull);
      expect(v.reasons(PUnit.bar), ['종료하지 않았습니다. 종료 압력을 기록하면 판정합니다.']);
      expect(v.details(PUnit.bar), isEmpty);
      v = judgePressureTest(
        medium: TestMedium.hydro,
        readings: const [],
        holdMin: 10,
      );
      expect(v.started, isFalse);
      expect(v.reasons(PUnit.bar), ['시작하지 않았습니다.']);
    });

    test('공압인데 온도가 없으면 측정 강하로 판정하고 그렇다고 적는다', () {
      final v = judgePressureTest(
        medium: TestMedium.pneumatic,
        readings: reads(p2: 695, t1: null, t2: null),
        holdMin: 10,
        allowKpa: 4,
        leakOk: true,
      );
      expect(v.correctedDropKpa, isNull);
      expect(v.judgedDropKpa, closeTo(5, 1e-9));
      expect(v.pass, isFalse);
      expect(v.details(PUnit.bar), contains('시작·종료 온도가 없어 온도 보정을 하지 않았습니다.'));
    });

    test('수압: 측정 강하로 판정, 외경·두께가 있으면 물 온도 영향(추정)을 참고로', () {
      final v = judgePressureTest(
        medium: TestMedium.hydro,
        readings: reads(p1: 1500, p2: 1300, t1: 20, t2: 19),
        holdMin: 10,
        allowKpa: 100,
        leakOk: true,
        odMm: 60.5,
        wallMm: 3.9,
      );
      expect(v.correctedDropKpa, isNull);
      expect(v.judgedDropKpa, closeTo(200, 1e-9));
      expect(v.pass, isFalse);
      final per = hydroBarPerDegC(waterC: 19.5, odMm: 60.5, wallMm: 3.9);
      expect(v.hydroTempKpa, closeTo(-per * 100, 1e-9));
      expect(v.hydroDeltaC, -1);
      final d = v.details(PUnit.bar).join('\n');
      expect(d, contains('수압은 온도 보정 없이 측정 압력강하로 판정합니다.'));
      expect(d, contains('물 온도 변화 -1°C: 온도만으로 압력이 약'));
      expect(d, contains('낮아집니다(추정, 공기 없는 막힌 관 기준).'));
      // 외경·두께가 없으면 참고 줄 없음
      final w = judgePressureTest(
        medium: TestMedium.hydro,
        readings: reads(t1: 20, t2: 19),
        holdMin: 10,
      );
      expect(w.hydroTempKpa, isNull);
    });

    test('허용 압력강하가 없으면 압력강하는 판정하지 않고 유지시간·누설 확인으로', () {
      final v = judgePressureTest(
        medium: TestMedium.hydro,
        readings: reads(p2: 600),
        holdMin: 10,
        leakOk: true,
      );
      expect(v.dropOk, isNull);
      expect(v.pass, isTrue);
      expect(v.details(PUnit.bar), contains('허용 압력강하를 넣으면 압력강하도 판정합니다.'));
    });

    test('판정 글·시계 글', () {
      expect(ptVerdictText(true), '합격');
      expect(ptVerdictText(false), '불합격');
      expect(ptVerdictText(null), '판정 없음');
      expect(ptClock(const Duration(minutes: 4, seconds: 5)), '04:05');
      expect(
        ptClock(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
      expect(ptClock(const Duration(seconds: -5)), '00:00');
    });
  });

  group('기록', () {
    test('JSON으로 저장했다 읽어도 같다', () {
      final r = sample();
      final back = PtRecord.fromJson(
        jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>,
      );
      expect(back.id, '1');
      expect(back.testNo, 'PT-001');
      expect(back.section, 'V-101 ~ P-201A');
      expect(back.medium, TestMedium.pneumatic);
      expect(back.fluid, PtFluid.nitrogen);
      expect(back.designKpa, 1000);
      expect(back.testKpa, 1200);
      expect(back.startAt, t0);
      expect(back.endAt, t0.add(const Duration(minutes: 12)));
      expect(back.readings.length, 3);
      expect(back.readings.first.kind, PtReadKind.start);
      expect(back.readings.last.tempC, 20);
      expect(back.gauges[1].calDue, '2027-01-15');
      expect(back.reliefKpa, 1320);
      expect(back.witnessOwner, '박발주');
      expect(back.leakOk, isTrue);
      expect(back.verdict.pass, isTrue);
      expect(back.witnessLine, '시공사 김시공 · 감리 이감리 · 발주처 박발주');
    });

    test('칸이 빠지거나 망가져도 읽는다(기본값), 망가진 측정 줄은 건너뛴다', () {
      final r = PtRecord.fromJson({
        'line': 'L-1',
        'unit': 'nope',
        'hold': -3,
        'readings': [
          {'at': '2026-09-26T09:00:00.000', 'kpa': 700, 'k': 'start'},
          {'at': 'x', 'kpa': 1},
          {'kpa': 5},
          'junk',
        ],
        'gauges': ['junk'],
      });
      expect(r.line, 'L-1');
      expect(r.id, isNotEmpty);
      expect(r.unit, PUnit.bar);
      expect(r.holdMin, 10);
      expect(r.code, PipingCode.b313);
      expect(r.medium, TestMedium.hydro);
      expect(r.readings.length, 1);
      expect(r.gauges.single.isEmpty, isTrue);
      expect(r.verdict.pass, isNull);
    });

    test('폰 저장: 넣기 → 같은 id는 고치기 → 지우기, 최근 것이 앞, 시험자·압력계 기억', () async {
      SharedPreferences.setMockInitialValues({'user_real_name': '차재훈'});
      expect(await PtRecordStore.load(), isEmpty);
      expect(await PtRecordStore.lastTester(), '차재훈');
      expect((await PtRecordStore.lastGear()).$1, isEmpty);
      await PtRecordStore.put(sample(id: 'a'));
      await PtRecordStore.put(
        PtRecord(
          id: 'b',
          date: DateTime(2026, 9, 27),
          line: 'P-2002',
          tester: '김',
          gauges: const [PtGauge(no: 'PG-9')],
          reliefKpa: 500,
          reliefNo: 'PSV-9',
        ),
      );
      var l = await PtRecordStore.load();
      expect(l.map((e) => e.id), ['b', 'a']);
      expect(await PtRecordStore.lastTester(), '김');
      final gear = await PtRecordStore.lastGear();
      expect(gear.$1.single.no, 'PG-9');
      expect(gear.$2, 500);
      expect(gear.$3, 'PSV-9');
      await PtRecordStore.put(sample(id: 'a', line: 'P-1001A'));
      l = await PtRecordStore.load();
      expect(l.length, 2);
      expect(l.firstWhere((e) => e.id == 'a').line, 'P-1001A');
      await PtRecordStore.delete('b');
      expect((await PtRecordStore.load()).map((e) => e.id), ['a']);
    });

    test('망가진 저장 값은 빈 목록', () async {
      SharedPreferences.setMockInitialValues({PtRecordStore.key: '{깨짐'});
      expect(await PtRecordStore.load(), isEmpty);
      SharedPreferences.setMockInitialValues({
        PtRecordStore.lastGearKey: '[1,2]',
      });
      expect((await PtRecordStore.lastGear()).$1, isEmpty);
    });
  });

  group('CSV', () {
    test('UTF-8 BOM, 한 기록이 한 줄, 머리와 칸 수가 같고 쉼표는 따옴표로', () {
      final csv = ptRecordsCsv([sample()]);
      expect(csv.startsWith('﻿'), isTrue);
      final lines = csv.substring(1).trimRight().split('\r\n');
      expect(lines.length, 2);
      expect(lines[0], startsWith('시험 번호,시험일,현장·프로젝트,계통,라인 번호'));
      expect(lines[1], contains('"P&ID-100, ISO-12"'));
      expect(lines[1], contains('"비눗물 점검, 이상 없음"'));
      expect(lines[1], contains(',B31.3,공압,질소,bar,10,12,10,'));
      expect(lines[1], contains(',합격,'));
      expect(lines[1], contains('PG-01 · 0~25 bar · 유효일 2027-03-31'));
      expect(lines[1], contains('09:00:00 시작 12bar 20°C; 09:05:00 측정'));
      // 머리 칸 수 = 값 칸 수(따옴표 안 쉼표 제외)
      int cells(String s) {
        var n = 1, q = false;
        for (final ch in s.split('')) {
          if (ch == '"') q = !q;
          if (ch == ',' && !q) n++;
        }
        return n;
      }

      expect(cells(lines[1]), cells(lines[0]));
    });

    test('압력은 기록의 단위로 적는다(psi)', () {
      final r = PtRecord(
        id: 'p',
        date: t0,
        line: 'L',
        unit: PUnit.psi,
        designKpa: 1034.2135939752541, // 150 psi
      );
      final row = ptRecordsCsv([r]).split('\r\n')[1];
      expect(row, contains(',psi,150,'));
    });
  });

  group('기록서 PDF', () {
    test('PDF가 만들어진다(측정 기록·판정·서명 칸), 빈 기록도', () async {
      final a = await buildPtRecordPdf(sample());
      expect(latin1.decode(a.sublist(0, 5)), '%PDF-');
      expect(a.length, greaterThan(10000));
      final b = await buildPtRecordPdf(
        PtRecord(id: 'e', date: t0, line: '', medium: TestMedium.hydro),
      );
      expect(latin1.decode(b.sublist(0, 5)), '%PDF-');
      final c = await buildPtRecordPdf(
        PtRecord(
          id: 'h',
          date: t0,
          line: 'W-1',
          medium: TestMedium.hydro,
          unit: PUnit.kgfcm2,
          readings: reads(p1: 1500, p2: 1490, t1: 20, t2: 18),
          startAt: t0,
          endAt: t0.add(const Duration(minutes: 12)),
          odMm: 60.5,
          wallMm: 3.9,
        ),
      );
      expect(latin1.decode(c.sublist(0, 5)), '%PDF-');
    });

    test('파일 이름: pt_라인_날짜.pdf(못 쓰는 글자는 _)', () {
      expect(
        ptRecordFileName(
          sample(line: '2"-P-1001/A', date: DateTime(2026, 9, 6)),
        ),
        'pt_2_-P-1001_A_20260906.pdf',
      );
      expect(
        ptRecordFileName(sample(line: '  ', date: DateTime(2026, 9, 6))),
        'pt_noline_20260906.pdf',
      );
    });
  });

  group('유지시간 알림', () {
    test('알림 문구: 라인 번호와 유지시간', () {
      expect(kPtHoldTitle, '압력 시험 유지시간 완료');
      expect(kPtHoldNotifId, 918400);
      expect(
        ptHoldBody(line: 'P-1001', holdMin: 30),
        'P-1001 유지시간 30분이 지났습니다. 종료 압력을 기록하십시오.',
      );
      expect(
        ptHoldBody(line: ' ', holdMin: 10),
        '유지시간 10분이 지났습니다. 종료 압력을 기록하십시오.',
      );
    });

    test('알림 플러그인이 없는 곳(위젯 시험)에서도 예외 없이 끝난다, 권한은 앱 전체에서 한 번만 묻는다', () async {
      SharedPreferences.setMockInitialValues({});
      const a = PluginHoldAlarm();
      await a.schedule(t0, title: kPtHoldTitle, body: 'x');
      await a.cancel();
      final p = await SharedPreferences.getInstance();
      expect(p.getBool('notif_permission_asked_v1'), isTrue);
    });
  });
}
