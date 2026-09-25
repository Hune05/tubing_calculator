// 근태·공수 계산(필드 헬퍼 4번).
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/attendance.dart';

void main() {
  group('manDaysOf', () {
    test('정상근무: 투입 인원 그대로', () {
      expect(manDaysOf({'worker_count': 3}), 3.0);
      expect(manDaysOf({}), 1.0); // 인원 안 적으면 1명
    });

    test('연차·월차: 0(일을 안 한 날)', () {
      expect(manDaysOf({'worker_count': 3, 'attendance_type': '연차'}), 0);
      expect(manDaysOf({'worker_count': 5, 'attendance_type': '월차'}), 0);
    });

    test('반차: 절반', () {
      expect(manDaysOf({'worker_count': 2, 'attendance_type': '반차'}), 1.0);
      expect(manDaysOf({'worker_count': 1, 'attendance_type': '반차'}), 0.5);
    });

    test('조퇴·특근: 인원 그대로(그대로 근무일로 친다)', () {
      expect(manDaysOf({'worker_count': 2, 'attendance_type': '조퇴'}), 2.0);
      expect(manDaysOf({'worker_count': 2, 'attendance_type': '특근'}), 2.0);
    });
  });

  test('totalManDays: 여러 날 합', () {
    final reports = [
      {'worker_count': 2},
      {'worker_count': 2, 'attendance_type': '연차'},
      {'worker_count': 2, 'attendance_type': '반차'},
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
    test('정상근무는 빈 문자열(표시 안 함)', () {
      expect(attendanceTag({}), '');
      expect(attendanceTag({'attendance_type': '정상근무'}), '');
    });
    test('그 외는 그대로', () {
      expect(attendanceTag({'attendance_type': '연차'}), '연차');
      expect(attendanceTag({'attendance_type': '특근'}), '특근');
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
  });
}
