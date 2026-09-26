// 근태·공수 계산(필드 헬퍼 4번). 근태는 AttendanceCache(날짜 -> 종류)로 따로
// 관리하고, 보고서는 dateISO로 그 날짜의 근태를 찾아온다(연동은 날짜로만).
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/attendance.dart';

void main() {
  setUp(() => AttendanceCache.byDate = {});

  group('manDaysOf', () {
    test('정상근무: 투입 인원 그대로', () {
      expect(manDaysOf({'worker_count': 3, 'dateISO': '2026-09-01'}), 3.0);
      expect(manDaysOf({}), 1.0); // 인원 안 적으면 1명
    });

    test('연차·월차: 0(일을 안 한 날)', () {
      AttendanceCache.byDate = {'2026-09-01': '연차', '2026-09-02': '월차'};
      expect(manDaysOf({'worker_count': 3, 'dateISO': '2026-09-01'}), 0);
      expect(manDaysOf({'worker_count': 5, 'dateISO': '2026-09-02'}), 0);
    });

    test('반차: 절반', () {
      AttendanceCache.byDate = {'2026-09-01': '반차'};
      expect(manDaysOf({'worker_count': 2, 'dateISO': '2026-09-01'}), 1.0);
      expect(manDaysOf({'worker_count': 1, 'dateISO': '2026-09-01'}), 0.5);
    });

    test('조퇴·특근: 인원 그대로(그대로 근무일로 친다)', () {
      AttendanceCache.byDate = {'2026-09-01': '조퇴', '2026-09-02': '특근'};
      expect(manDaysOf({'worker_count': 2, 'dateISO': '2026-09-01'}), 2.0);
      expect(manDaysOf({'worker_count': 2, 'dateISO': '2026-09-02'}), 2.0);
    });

    test('그 날짜의 근태 기록이 없으면 정상근무로 본다', () {
      AttendanceCache.byDate = {'2026-09-01': '연차'};
      expect(manDaysOf({'worker_count': 2, 'dateISO': '2026-09-02'}), 2.0);
    });

    test('dateISO가 없는(예전) 보고서는 정상근무로 본다', () {
      AttendanceCache.byDate = {'2026-09-01': '연차'};
      expect(manDaysOf({'worker_count': 2}), 2.0);
    });
  });

  test('totalManDays: 여러 날 합', () {
    AttendanceCache.byDate = {'2026-09-02': '연차', '2026-09-03': '반차'};
    final reports = [
      {'worker_count': 2, 'dateISO': '2026-09-01'},
      {'worker_count': 2, 'dateISO': '2026-09-02'},
      {'worker_count': 2, 'dateISO': '2026-09-03'},
    ];
    expect(totalManDays(reports), 3.0); // 2 + 0 + 1
  });

  group('formatManDays', () {
    test('정수는 소수점 없이', () {
      expect(formatManDays(3.0), '3');
      expect(formatManDays(0), '0');
    });
    test('소수는 첫째 자리까지', () {
      expect(formatManDays(3.5), '3.5');
      expect(formatManDays(0.5), '0.5');
    });
  });

  group('attendanceTag', () {
    test('정상근무(또는 근태 기록 없음)는 빈 문자열(표시 안 함)', () {
      expect(attendanceTag({}), '');
      expect(attendanceTag({'dateISO': '2026-09-01'}), '');
    });
    test('그 외는 그대로', () {
      AttendanceCache.byDate = {'2026-09-01': '연차', '2026-09-02': '특근'};
      expect(attendanceTag({'dateISO': '2026-09-01'}), '연차');
      expect(attendanceTag({'dateISO': '2026-09-02'}), '특근');
    });
  });

  group('반반차·결근(2026-09-26 추가)', () {
    test('공수: 결근 0, 반반차 3/4', () {
      AttendanceCache.byDate = {'2026-09-01': '결근', '2026-09-02': '반반차'};
      expect(manDaysOf({'worker_count': 2, 'dateISO': '2026-09-01'}), 0);
      expect(manDaysOf({'worker_count': 2, 'dateISO': '2026-09-02'}), 1.5);
    });
    test('연차에서 빠지는 일수', () {
      expect(leaveDaysOf('연차'), 1);
      expect(leaveDaysOf('월차'), 1);
      expect(leaveDaysOf('반차'), 0.5);
      expect(leaveDaysOf('반반차'), 0.25);
      expect(leaveDaysOf('조퇴'), 0);
      expect(leaveDaysOf('특근'), 0);
      expect(leaveDaysOf('결근'), 0);
    });
    test('출퇴근 칸을 감추는 종류: 연차·월차·결근', () {
      expect(hasNoWorkTime('결근'), isTrue);
      expect(hasNoWorkTime('연차'), isTrue);
      expect(hasNoWorkTime('반반차'), isFalse);
    });
    test('종류 목록: 예전 6개가 그대로 들어 있다', () {
      for (final t in ['정상근무', '연차', '월차', '반차', '조퇴', '특근']) {
        expect(kAttendanceTypes, contains(t));
      }
    });
  });

  group('isFullDayLeave', () {
    test('연차·월차만 참', () {
      expect(isFullDayLeave('연차'), isTrue);
      expect(isFullDayLeave('월차'), isTrue);
      expect(isFullDayLeave('반차'), isFalse);
      expect(isFullDayLeave('조퇴'), isFalse);
      expect(isFullDayLeave('특근'), isFalse);
      expect(isFullDayLeave('정상근무'), isFalse);
    });
  });

  group('workedHoursOf', () {
    test('보통 하루(08:00~17:00)', () {
      expect(workedHoursOf('08:00', '17:00'), 9.0);
    });

    test('자정을 넘긴 야간(22:00~06:00)', () {
      expect(workedHoursOf('22:00', '06:00'), 8.0);
    });

    test('하나라도 없으면 null', () {
      expect(workedHoursOf(null, '17:00'), isNull);
      expect(workedHoursOf('08:00', null), isNull);
    });

    test('30분 단위도 정확히', () {
      expect(workedHoursOf('08:30', '17:00'), 8.5);
    });

    test('출근=퇴근은 24시간이 아니라 계산하지 않는다(null)', () {
      expect(workedHoursOf('08:00', '08:00'), isNull);
    });

    test('모양이 틀린 시각은 null', () {
      expect(workedHoursOf('25:00', '17:00'), isNull);
      expect(workedHoursOf('0800', '17:00'), isNull);
    });
  });

  group('AttendanceRecord', () {
    test('toJson/fromJson 왕복', () {
      final r = AttendanceRecord(
        date: DateTime(2026, 9, 25),
        type: '반차',
        checkIn: '08:00',
        checkOut: '12:00',
      );
      final back = AttendanceRecord.fromJson(r.toJson(), r.date);
      expect(back.type, '반차');
      expect(back.checkIn, '08:00');
      expect(back.checkOut, '12:00');
      expect(back.workedHours, 4.0);
    });

    test('휴게·메모 왕복, 예전 기록(칸 없음)은 비어 있는 것으로 읽는다', () {
      final r = AttendanceRecord(
        date: DateTime(2026, 9, 25),
        checkIn: '08:00',
        checkOut: '17:00',
        breakMin: 60,
        memo: ' 태안 3호기 ',
      );
      final j = r.toJson();
      expect(j['breakMin'], 60);
      expect(j['memo'], '태안 3호기');
      final back = AttendanceRecord.fromJson(j, r.date);
      expect(back.breakMin, 60);
      expect(back.memo, '태안 3호기');

      final old = AttendanceRecord.fromJson({
        'date': '2026-09-01',
        'type': '특근',
        'checkIn': '08:00',
        'checkOut': '17:00',
      }, DateTime(2026, 9, 1));
      expect(old.breakMin, isNull);
      expect(old.memo, isNull);
      expect(old.type, '특근');
      // 비어 있는 칸은 저장하지 않는다(예전 모양 그대로).
      final plain = AttendanceRecord(date: DateTime(2026, 9, 1)).toJson();
      expect(plain.containsKey('breakMin'), isFalse);
      expect(plain.containsKey('memo'), isFalse);
    });

    test('dateKey 형식은 yyyy-MM-dd', () {
      expect(dateKey(DateTime(2026, 1, 5)), '2026-01-05');
    });
  });
}
