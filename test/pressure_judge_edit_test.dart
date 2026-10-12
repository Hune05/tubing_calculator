// 10-13 압력 시험 점검 고침: 완료 알림 번호(작업 일지 알림과 겹침), 최소·최대 시험압력 판정,
// 종료한 뒤 고친 측정값의 수정 사유(사용자: "시험 끝나고 왜 수정이 바로 가능한지, 수정하면 수정 코멘트 필수").
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/attendance/attendance_reminder.dart'
    show kClockOutNotifId;
import 'package:tubing_calculator/src/presentation/my_work_logs/models/reminder_tools.dart'
    show isReminderNotificationId, kMorningSummaryId;
import 'package:tubing_calculator/src/presentation/pressure_test/hold_alarm.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/pressure_calc.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/pressure_units.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/test_record.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/test_record_pdf.dart';

final t0 = DateTime(2026, 10, 13, 9, 0, 0);

List<PtReading> reads(double p1, double p2) => [
  PtReading(at: t0, kpa: p1, tempC: 20, kind: PtReadKind.start),
  PtReading(
    at: t0.add(const Duration(minutes: 12)),
    kpa: p2,
    tempC: 20,
    kind: PtReadKind.end,
  ),
];

PtVerdict judge({
  TestMedium medium = TestMedium.hydro,
  required double p1,
  required double p2,
  double? test,
  double? min,
  double? max,
  double? allow,
}) => judgePressureTest(
  medium: medium,
  readings: reads(p1, p2),
  startAt: t0,
  endAt: t0.add(const Duration(minutes: 12)),
  holdMin: 10,
  allowKpa: allow,
  leakOk: true,
  testKpa: test,
  minKpa: min,
  maxKpa: max,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('완료 알림 번호', () {
    test('작업 일지·주간·아침 요약·퇴근 알림 번호와 겹치지 않는다(예전 918400은 일지 근무일 알림과 겹쳤다)', () {
      expect(kPtHoldNotifId, 918600);
      expect(isReminderNotificationId(kPtHoldNotifId), isFalse);
      // 일지 아침 묶음(918480~918489)·아침 요약·퇴근 알림
      expect(kPtHoldNotifId >= 918480 && kPtHoldNotifId < 918490, isFalse);
      expect(kPtHoldNotifId, isNot(kMorningSummaryId));
      expect(kPtHoldNotifId, isNot(kClockOutNotifId));
    });
  });

  group('최소·최대 시험압력 판정', () {
    test('시작 압력이 최소 시험압력 미만이면 불합격(시험압력을 낮게 적어도)', () {
      // 설계 10bar 수압 → 최소 15bar. 실제 시험압력을 12로 잘못 넣고 12로 시험.
      final v = judge(p1: 1200, p2: 1200, test: 1200, min: 1500);
      expect(v.startOk, isTrue);
      expect(v.startMinOk, isFalse);
      expect(v.pass, isFalse);
      expect(v.reasons(PUnit.bar), contains('시작 압력 12 bar: 최소 시험압력 15 bar 미만'));
      // 같은 원인으로 "시험압력 미만" 줄을 또 적지 않는다.
      expect(v.reasons(PUnit.bar).where((t) => t.contains('시험압력 12')), isEmpty);
    });

    test('허용 압력강하를 비워도 종료 압력이 최소 시험압력 아래면 불합격', () {
      final v = judge(p1: 1500, p2: 1100, test: 1500, min: 1500);
      expect(v.dropOk, isNull);
      expect(v.endMinOk, isFalse);
      expect(v.pass, isFalse);
      expect(
        v.reasons(PUnit.bar),
        contains('종료 압력 11 bar: 최소 시험압력 15 bar 미만(시험압력에서 유지하지 못함)'),
      );
    });

    test('최소보다 높게 올려 시험하고 최소 이상에서 끝나면 합격(실제 시험압력까지는 안 봄)', () {
      final v = judge(p1: 1600, p2: 1520, test: 1600, min: 1500);
      expect(v.endMinOk, isTrue);
      expect(v.pass, isTrue);
    });

    test('공압: 최대 시험압력을 넘겨 시작하면 불합격', () {
      final v = judge(
        medium: TestMedium.pneumatic,
        p1: 1400,
        p2: 1400,
        test: 1400,
        min: 1100,
        max: 1330,
      );
      expect(v.peakMaxOk, isFalse);
      expect(v.pass, isFalse);
      expect(
        v.reasons(PUnit.bar),
        contains('최고 압력 14 bar: 최대 시험압력 13.3 bar 초과'),
      );
    });

    test(
      '공압: 시작은 범위 안이어도 측정 압력이 최대를 넘으면 불합격(A11 TEST-P1: 13 → 30 bar가 합격이었다)',
      () {
        final v = judge(
          medium: TestMedium.pneumatic,
          p1: 1300,
          p2: 3000,
          test: 1300,
          min: 1100,
          max: 1330,
        );
        expect(v.peakMaxOk, isFalse);
        expect(v.pass, isFalse);
        expect(
          v.reasons(PUnit.bar),
          contains('최고 압력 30 bar: 최대 시험압력 13.3 bar 초과'),
        );
      },
    );

    test('최소를 저장하지 않은 옛 기록은 판정이 그대로', () {
      final old = PtRecord.fromJson({
        'id': 'old',
        'date': t0.toIso8601String(),
        'line': 'L',
        'medium': 'hydro',
        'test': 1500,
        'hold': 10,
        'start': t0.toIso8601String(),
        'end': t0.add(const Duration(minutes: 12)).toIso8601String(),
        'readings': [for (final r in reads(1500, 1400)) r.toJson()],
        'leakOk': true,
      });
      expect(old.minKpa, isNull);
      expect(old.verdict.pass, isTrue);
    });

    test('기록에 최소·최대를 저장하고 읽는다, CSV 끝에 칸이 있다', () {
      final r = PtRecord(
        id: 'm',
        date: t0,
        line: 'L-1',
        medium: TestMedium.pneumatic,
        testKpa: 1200,
        minKpa: 1100,
        maxKpa: 1330,
        startAt: t0,
        endAt: t0.add(const Duration(minutes: 12)),
        readings: reads(1200, 1195),
        leakOk: true,
      );
      final back = PtRecord.fromJson(jsonDecode(jsonEncode(r.toJson())));
      expect(back.minKpa, 1100);
      expect(back.maxKpa, 1330);
      final lines = ptRecordsCsv([r]).substring(1).trimRight().split('\r\n');
      expect(lines[0], endsWith('측정 기록,최소 시험압력,최대 시험압력,수정 기록'));
      expect(lines[1], endsWith(',11,13.3,'));
    });
  });

  group('수정 기록', () {
    final edit = PtEdit(
      at: DateTime(2026, 10, 13, 9, 20),
      readAt: t0.add(const Duration(minutes: 12)),
      kind: PtReadKind.end,
      fromKpa: 1195,
      fromTempC: 20,
      toKpa: 1180,
      toTempC: 21,
      reason: '게이지 다시 읽음',
    );
    final del = PtEdit(
      at: DateTime(2026, 10, 13, 9, 21),
      readAt: t0.add(const Duration(minutes: 5)),
      kind: PtReadKind.mid,
      fromKpa: 1190,
      reason: '다른 라인 값',
    );

    test('무엇을 무엇으로·지움을 글로', () {
      expect(
        edit.describe(PUnit.bar),
        '종료 09:12:00 압력 11.95 → 11.8 bar, 온도 20°C → 21°C',
      );
      expect(del.describe(PUnit.bar), '측정 09:05:00 지움(11.9 bar)');
      expect(
        ptEditLine(edit, PUnit.bar),
        '10-13 09:20 · 종료 09:12:00 압력 11.95 → 11.8 bar, 온도 20°C → 21°C · 사유: 게이지 다시 읽음',
      );
    });

    test('기록에 저장·읽기, 고친 줄 표시, CSV에 (수정)과 수정 기록', () {
      final rd = [
        PtReading(at: t0, kpa: 1200, tempC: 20, kind: PtReadKind.start),
        PtReading(
          at: t0.add(const Duration(minutes: 12)),
          kpa: 1180,
          tempC: 21,
          kind: PtReadKind.end,
        ),
      ];
      final r = PtRecord(
        id: 'e',
        date: t0,
        line: 'L-2',
        startAt: t0,
        endAt: t0.add(const Duration(minutes: 12)),
        readings: rd,
        edits: [edit, del],
      );
      final back = PtRecord.fromJson(jsonDecode(jsonEncode(r.toJson())));
      expect(back.edits.length, 2);
      expect(back.edits.first.reason, '게이지 다시 읽음');
      expect(back.edits.last.deleted, isTrue);
      expect(ptReadingEdited(back.edits, rd[1]), isTrue);
      expect(ptReadingEdited(back.edits, rd[0]), isFalse);
      final row = ptRecordsCsv([r]).split('\r\n')[1];
      expect(row, contains('09:12:00 종료 11.8bar 21°C(수정)'));
      expect(
        row,
        contains(
          '사유: 게이지 다시 읽음; 10-13 09:21 · 측정 09:05:00 지움(11.9 bar) · 사유: 다른 라인 값',
        ),
      );
    });

    test('수정 기록·최소 시험압력이 있는 기록서 PDF도 만들어진다', () async {
      final bytes = await buildPtRecordPdf(
        PtRecord(
          id: 'pdf',
          date: t0,
          line: 'L-3',
          testKpa: 1500,
          minKpa: 1500,
          startAt: t0,
          endAt: t0.add(const Duration(minutes: 12)),
          readings: reads(1500, 1480),
          edits: [edit],
        ),
      );
      expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
    });
  });
}
