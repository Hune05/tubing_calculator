// 근태 출근·퇴근 단추 판단과 여러 날 기록 계산 시험(화면 없이).
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/attendance/attendance_bulk.dart';
import 'package:tubing_calculator/src/presentation/attendance/attendance_clock.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/attendance.dart';

AttendanceRecord _rec(
  DateTime d, {
  String type = kAttendanceNormal,
  String? inT,
  String? outT,
}) => AttendanceRecord(date: d, type: type, checkIn: inT, checkOut: outT);

void main() {
  group('출근·퇴근 상태', () {
    final today = DateTime(2026, 9, 24);
    final yesterday = DateTime(2026, 9, 23);

    test('기록이 없으면 출근 전', () {
      final s = clockStatus(now: DateTime(2026, 9, 24, 7, 50));
      expect(s.phase, ClockPhase.ready);
      expect(s.day, today);
    });

    test('출근만 있으면 근무 중이고 지난 분을 센다', () {
      final s = clockStatus(
        now: DateTime(2026, 9, 24, 10, 5),
        today: _rec(today, inT: '08:00'),
      );
      expect(s.phase, ClockPhase.working);
      expect(s.elapsedMin, 125);
    });

    test('출근·퇴근이 다 있으면 끝', () {
      final s = clockStatus(
        now: DateTime(2026, 9, 24, 18),
        today: _rec(today, inT: '08:00', outT: '17:30'),
      );
      expect(s.phase, ClockPhase.done);
    });

    test('연차·결근인 날은 단추가 없다', () {
      for (final t in ['연차', '월차', kAttendanceAbsent]) {
        final s = clockStatus(
          now: DateTime(2026, 9, 24, 9),
          today: _rec(today, type: t),
        );
        expect(s.phase, ClockPhase.off, reason: t);
      }
    });

    test('반차·특근은 시간이 있으니 단추를 쓴다', () {
      final s = clockStatus(
        now: DateTime(2026, 9, 24, 9),
        today: _rec(today, type: '특근'),
      );
      expect(s.phase, ClockPhase.ready);
    });

    test('밤샘: 어제 저녁에 출근하고 퇴근을 안 찍었으면 어제 기록이 근무 중', () {
      final s = clockStatus(
        now: DateTime(2026, 9, 24, 6, 30),
        yesterday: _rec(yesterday, inT: '22:00'),
      );
      expect(s.phase, ClockPhase.working);
      expect(s.day, yesterday);
      expect(s.elapsedMin, 510);
    });

    test('어제 낮에 출근하고 퇴근을 잊었으면 오늘은 새로 출근한다', () {
      final s = clockStatus(
        now: DateTime(2026, 9, 24, 8),
        yesterday: _rec(yesterday, inT: '08:00'),
      );
      expect(s.phase, ClockPhase.ready);
      expect(s.day, today);
    });

    test('밤샘이어도 16시간이 넘으면 오늘로 본다', () {
      final s = clockStatus(
        now: DateTime(2026, 9, 24, 15),
        yesterday: _rec(yesterday, inT: '22:00'),
      );
      expect(s.phase, ClockPhase.ready);
    });
  });

  group('출근·퇴근 찍기', () {
    final today = DateTime(2026, 9, 24);

    test('출근은 지금 시각(분 단위)으로 채우고 있던 종류·메모를 둔다', () {
      final old = AttendanceRecord(
        date: today,
        type: '특근',
        breakMin: 30,
        memo: '태안',
      );
      final r = punchIn(today, old, DateTime(2026, 9, 24, 7, 5, 59));
      expect(r.checkIn, '07:05');
      expect(r.type, '특근');
      expect(r.breakMin, 30);
      expect(r.memo, '태안');
      expect(r.checkOut, isNull);
    });

    test('기록이 없던 날의 출근은 정상근무', () {
      final r = punchIn(today, null, DateTime(2026, 9, 24, 8));
      expect(r.type, kAttendanceNormal);
      expect(r.date, today);
    });

    test('퇴근은 출근을 그대로 두고 퇴근만 채운다', () {
      final r = punchOut(
        _rec(today, inT: '08:00'),
        DateTime(2026, 9, 24, 17, 31),
      )!;
      expect(r.checkIn, '08:00');
      expect(r.checkOut, '17:31');
    });

    test('출근과 같은 분에는 퇴근을 만들지 않는다', () {
      expect(
        punchOut(_rec(today, inT: '08:00'), DateTime(2026, 9, 24, 8, 0, 30)),
        isNull,
      );
    });

    test('밤샘 퇴근(자정을 넘김)도 만들어지고 시간이 계산된다', () {
      final r = punchOut(
        _rec(DateTime(2026, 9, 23), inT: '22:00'),
        DateTime(2026, 9, 24, 6, 30),
      )!;
      expect(r.checkOut, '06:30');
      expect(stayMinutesOf(r.checkIn, r.checkOut), 510);
    });
  });

  group('퇴근 입력 필요', () {
    final today = DateTime(2026, 9, 24);

    test('지난 날에 출근만 있으면 빠진 날', () {
      expect(
        isMissingCheckOut(_rec(DateTime(2026, 9, 22), inT: '08:00'), today),
        isTrue,
      );
    });

    test('오늘은 아직 근무 중일 수 있어 빠진 날이 아니다', () {
      expect(isMissingCheckOut(_rec(today, inT: '08:00'), today), isFalse);
    });

    test('퇴근이 있거나 일을 안 한 날은 해당 없음', () {
      expect(
        isMissingCheckOut(
          _rec(DateTime(2026, 9, 22), inT: '08:00', outT: '17:00'),
          today,
        ),
        isFalse,
      );
      expect(
        isMissingCheckOut(_rec(DateTime(2026, 9, 22), type: '연차'), today),
        isFalse,
      );
      expect(isMissingCheckOut(null, today), isFalse);
    });

    test('날 수를 세고, 지금 근무 중인 날은 뺀다', () {
      final m = {
        '2026-09-22': _rec(DateTime(2026, 9, 22), inT: '08:00'),
        '2026-09-23': _rec(DateTime(2026, 9, 23), inT: '22:00'),
        '2026-09-21': _rec(DateTime(2026, 9, 21), inT: '08:00', outT: '17:00'),
      };
      expect(missingCheckOutCount(m, today), 2);
      expect(missingCheckOutCount(m, today, skip: DateTime(2026, 9, 23)), 1);
    });
  });

  group('여러 날 한 번에', () {
    test('쉬는 날(토·일·공휴일)을 빼고 평일만 고른다', () {
      // 2026-09-21(월) ~ 09-27(일): 추석 연휴는 9/24~9/26
      final p = planBulk(
        from: DateTime(2026, 9, 21),
        to: DateTime(2026, 9, 27),
        skipOff: true,
        overwrite: true,
      );
      expect(p.days.every((d) => !isOffDay(d)), isTrue);
      expect(p.skippedOff.length + p.days.length, 7);
      expect(p.skippedOff, contains(DateTime(2026, 9, 26))); // 토요일
      expect(p.skippedOff, contains(DateTime(2026, 9, 27))); // 일요일
    });

    test('쉬는 날 빼기를 끄면 모든 날', () {
      final p = planBulk(
        from: DateTime(2026, 10, 3),
        to: DateTime(2026, 10, 4),
        skipOff: false,
        overwrite: true,
      );
      expect(p.days.length, 2);
    });

    test('이미 적은 날은 덮어쓰기를 켜지 않으면 그대로 둔다', () {
      final keep = planBulk(
        from: DateTime(2026, 10, 12),
        to: DateTime(2026, 10, 14),
        skipOff: true,
        overwrite: false,
        existingKeys: {'2026-10-13'},
      );
      expect(keep.days, [DateTime(2026, 10, 12), DateTime(2026, 10, 14)]);
      expect(keep.skippedExisting, [DateTime(2026, 10, 13)]);

      final over = planBulk(
        from: DateTime(2026, 10, 12),
        to: DateTime(2026, 10, 14),
        skipOff: true,
        overwrite: true,
        existingKeys: {'2026-10-13'},
      );
      expect(over.days.length, 3);
      expect(over.skippedExisting, isEmpty);
    });

    test('끝날이 앞이거나 너무 길면 막는다', () {
      expect(
        planBulk(
          from: DateTime(2026, 10, 7),
          to: DateTime(2026, 10, 5),
          skipOff: true,
          overwrite: true,
        ).invalid,
        isTrue,
      );
      final long = planBulk(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
        skipOff: true,
        overwrite: true,
      );
      expect(long.tooLong, isTrue);
      expect(long.days, isEmpty);
    });

    test('일을 안 하는 종류는 시간·휴게를 빼고 입힌다', () {
      final t = AttendanceRecord(
        date: DateTime(2026, 10, 5),
        type: '연차',
        checkIn: '08:00',
        checkOut: '17:00',
        breakMin: 60,
        memo: '휴가',
      );
      final r = bulkRecord(DateTime(2026, 10, 6), t);
      expect(r.date, DateTime(2026, 10, 6));
      expect(r.checkIn, isNull);
      expect(r.checkOut, isNull);
      expect(r.breakMin, isNull);
      expect(r.memo, '휴가');
    });

    test('근무 종류는 시간·휴게를 그대로 입힌다', () {
      final t = AttendanceRecord(
        date: DateTime(2026, 10, 5),
        checkIn: '08:00',
        checkOut: '17:00',
        breakMin: 60,
      );
      final r = bulkRecord(DateTime(2026, 10, 6), t);
      expect(r.checkIn, '08:00');
      expect(r.checkOut, '17:00');
      expect(r.breakMin, 60);
    });

    test('가장 가까운 전 기록을 찾는다(빈 기록·너무 먼 기록은 건너뜀)', () {
      final m = {
        '2026-10-02': _rec(DateTime(2026, 10, 2), inT: '08:00', outT: '17:00'),
        '2026-10-04': _rec(DateTime(2026, 10, 4)), // 정상근무·시간 없음 → 빈 기록
      };
      expect(
        latestRecordBefore(m, DateTime(2026, 10, 5))?.date,
        DateTime(2026, 10, 2),
      );
      expect(latestRecordBefore(m, DateTime(2026, 10, 20)), isNull);
      expect(latestRecordBefore(m, DateTime(2026, 10, 2)), isNull);
    });
  });
}
