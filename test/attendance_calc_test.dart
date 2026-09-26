// 근태 계산(휴게·연장·야간·휴일·주 52시간·연차 잔여) 시험. 근거: docs/근태관리_근거.md 6절.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/attendance/attendance_calc.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/attendance.dart';

const _o = AttendanceCalcOptions();

AttendanceRecord _r(
  String date,
  String? inT,
  String? outT, {
  String type = kAttendanceNormal,
  int? breakMin,
}) => AttendanceRecord(
  date: DateTime.parse(date),
  type: type,
  checkIn: inT,
  checkOut: outT,
  breakMin: breakMin,
);

Map<String, AttendanceRecord> _map(List<AttendanceRecord> l) => {
  for (final r in l) dateKey(r.date): r,
};

void main() {
  group('법정 최소 휴게(제54조)', () {
    test('4시간 미만 0, 8시간 30분 미만 30분, 그 이상 1시간', () {
      expect(legalBreakMinutes(239), 0);
      expect(legalBreakMinutes(240), 30);
      expect(legalBreakMinutes(509), 30);
      expect(legalBreakMinutes(510), 60);
      expect(legalBreakMinutes(720), 60);
    });
    test('뺀 뒤 근로시간이 제54조를 늘 만족한다', () {
      for (var stay = 1; stay <= 24 * 60; stay++) {
        final b = legalBreakMinutes(stay);
        final work = stay - b;
        if (work >= 480) expect(b, greaterThanOrEqualTo(60), reason: '$stay');
        if (work >= 240) expect(b, greaterThanOrEqualTo(30), reason: '$stay');
      }
    });
  });

  group('하루 계산', () {
    test('평일 08:00~17:00: 근로 8시간, 휴게 1시간', () {
      final w = computeDay(_r('2026-09-22', '08:00', '17:00'), _o)!;
      expect(w.stay, 540);
      expect(w.breakMin, 60);
      expect(w.work, 480);
      expect(w.night, 0);
      expect(w.holiday, 0);
      expect(w.dailyOver, 0);
    });

    test('평일 07:00~20:00: 연장 4시간', () {
      final w = computeDay(_r('2026-09-22', '07:00', '20:00'), _o)!;
      expect(w.work, 720);
      expect(w.dailyOver, 240);
    });

    test('자정 넘긴 야간 22:00~06:00: 휴게 30분, 야간 7시간 30분', () {
      final w = computeDay(_r('2026-09-22', '22:00', '06:00'), _o)!;
      expect(w.stay, 480);
      expect(w.breakMin, 30);
      expect(w.work, 450);
      expect(w.night, 450);
    });

    test('18:00~23:00: 야간은 22시 뒤 1시간만', () {
      final w = computeDay(_r('2026-09-22', '18:00', '23:00'), _o)!;
      expect(w.night, 60);
    });

    test('일요일 08:00~19:00: 휴일 10시간, 8시간 초과 2시간, 연장은 없음', () {
      final w = computeDay(_r('2026-09-27', '08:00', '19:00'), _o)!;
      expect(w.work, 600);
      expect(w.holiday, 600);
      expect(w.holidayOver8, 120);
      expect(w.dailyOver, 0);
    });

    test('토요일 22:00~일요일 06:00: 0시 뒤 6시간만 휴일근로', () {
      final w = computeDay(_r('2026-09-19', '22:00', '06:00'), _o)!;
      expect(w.work, 450);
      expect(w.holiday, 360);
      expect(w.nonHoliday, 90);
      expect(w.night, 450);
    });

    test('공휴일(한글날 금요일)은 휴일근로', () {
      final w = computeDay(_r('2026-10-09', '08:00', '17:00'), _o)!;
      expect(w.holiday, 480);
    });

    test('토요일은 기본 연장 쪽, 설정을 켜면 휴일근로', () {
      final r = _r('2026-09-12', '08:00', '17:00');
      expect(computeDay(r, _o)!.holiday, 0);
      expect(
        computeDay(
          r,
          const AttendanceCalcOptions(saturdayIsHoliday: true),
        )!.holiday,
        480,
      );
    });

    test('그 날 휴게를 따로 고르면 그 값을 쓴다', () {
      final w = computeDay(
        _r('2026-09-22', '08:00', '17:00', breakMin: 0),
        _o,
      )!;
      expect(w.work, 540);
      expect(w.dailyOver, 60);
    });

    test('기본 휴게 1시간 고정·없음', () {
      const fixed = AttendanceCalcOptions(defaultBreak: 60);
      expect(computeDay(_r('2026-09-22', '08:00', '12:00'), fixed)!.work, 180);
      const none = AttendanceCalcOptions(defaultBreak: 0);
      expect(computeDay(_r('2026-09-22', '08:00', '17:00'), none)!.work, 540);
    });

    test('연차·월차·결근, 시간 없음, 출근=퇴근은 계산하지 않는다', () {
      expect(
        computeDay(_r('2026-09-22', '08:00', '17:00', type: '연차'), _o),
        isNull,
      );
      expect(computeDay(_r('2026-09-22', null, null, type: '결근'), _o), isNull);
      expect(computeDay(_r('2026-09-22', '08:00', null), _o), isNull);
      expect(computeDay(_r('2026-09-22', '08:00', '08:00'), _o), isNull);
    });
  });

  group('주 40시간·52시간', () {
    test('월~금 8시간 + 토 4시간 30분: 토요일 전부 연장', () {
      final recs = _map([
        for (var d = 7; d <= 11; d++)
          _r('2026-09-${d.toString().padLeft(2, '0')}', '08:00', '17:00'),
        _r('2026-09-12', '08:00', '13:00'),
      ]);
      final r = computeRange(
        recs,
        DateTime(2026, 9, 7),
        DateTime(2026, 9, 13),
        _o,
      );
      final sat = r.days.firstWhere((d) => d.date.day == 12);
      expect(sat.work!.work, 270);
      expect(sat.weeklyOver, 270);
      expect(r.weeks.single.work, 2670);
      expect(r.weeks.single.overtime, 270);
      expect(r.weeks.single.over52, isFalse);
    });

    test('하루 초과와 주 초과를 두 번 세지 않는다', () {
      // 월~금 07:00~20:00(12시간씩): 하루 초과 4시간 × 5 = 20시간, 주 기준도 60 − 40 = 20시간.
      final recs = _map([
        for (var d = 7; d <= 11; d++)
          _r('2026-09-${d.toString().padLeft(2, '0')}', '07:00', '20:00'),
      ]);
      final r = computeRange(
        recs,
        DateTime(2026, 9, 7),
        DateTime(2026, 9, 13),
        _o,
      );
      expect(r.weeks.single.overtime, 1200);
      expect(r.weeks.single.over52, isTrue);
    });

    test('월~토 11시간: 주 66시간, 연장 26시간, 52시간 초과', () {
      final recs = _map([
        for (var d = 7; d <= 12; d++)
          _r('2026-09-${d.toString().padLeft(2, '0')}', '07:00', '19:00'),
      ]);
      final r = computeRange(
        recs,
        DateTime(2026, 9, 7),
        DateTime(2026, 9, 13),
        _o,
      );
      expect(r.weeks.single.work, 3960);
      expect(r.weeks.single.overtime, 1560);
      expect(r.weeks.single.over52, isTrue);
    });

    test('합계가 52시간 안이어도 하루 초과 합이 12시간을 넘으면 알린다', () {
      final recs = _map([
        for (var d = 7; d <= 9; d++)
          _r('2026-09-0$d', '06:00', '21:00'), // 14시간 × 3 = 42시간, 하루 초과 18시간
      ]);
      final r = computeRange(
        recs,
        DateTime(2026, 9, 7),
        DateTime(2026, 9, 13),
        _o,
      );
      expect(r.weeks.single.work, 2520);
      expect(r.weeks.single.limitOver, 1080);
      expect(r.weeks.single.over52, isTrue);
    });

    test('휴일근로는 주 40시간 가산 계산에 넣지 않고 52시간 한도에는 넣는다', () {
      final recs = _map([
        for (var d = 7; d <= 11; d++)
          _r('2026-09-${d.toString().padLeft(2, '0')}', '08:00', '17:00'),
        _r('2026-09-13', '08:00', '21:00'), // 일요일 12시간
      ]);
      final r = computeRange(
        recs,
        DateTime(2026, 9, 7),
        DateTime(2026, 9, 13),
        _o,
      );
      expect(r.weeks.single.overtime, 0);
      expect(r.weeks.single.work, 2400 + 720);
      expect(r.weeks.single.limitOver, 720);
      expect(r.weeks.single.over52, isFalse); // 딱 52시간
    });
  });

  group('달 합계', () {
    test('앞 달 기록까지 읽어 첫 주 40시간을 센다', () {
      final recs = _map([
        _r('2026-06-29', '08:00', '17:00'),
        _r('2026-06-30', '08:00', '17:00'),
        _r('2026-07-01', '08:00', '17:00'),
        _r('2026-07-02', '08:00', '17:00'),
        _r('2026-07-03', '08:00', '17:00'),
        _r('2026-07-04', '08:00', '13:00'),
      ]);
      final s = summarizeMonth(recs, DateTime(2026, 7), _o);
      expect(s.timedDays, 4);
      expect(s.work, 3 * 480 + 270);
      expect(s.overtime, 270);
      // 앞 달 기록이 없으면 7월만으로는 40시간을 넘지 않는다.
      final only = Map.of(recs)
        ..remove('2026-06-29')
        ..remove('2026-06-30');
      expect(summarizeMonth(only, DateTime(2026, 7), _o).overtime, 0);
    });

    test('가산 시간: 휴일 10시간 = 8시간 × 50% + 2시간 × 100% = 6시간', () {
      final s = summarizeMonth(
        _map([_r('2026-09-27', '08:00', '19:00')]),
        DateTime(2026, 9),
        _o,
      );
      expect(s.holiday, 600);
      expect(s.holidayOver8, 120);
      expect(s.premiumMinutes, 360);
    });

    test('연차 사용 일수와 종류별 횟수', () {
      final s = summarizeMonth(
        _map([
          _r('2026-09-01', null, null, type: '연차'),
          _r('2026-09-02', '08:00', '12:00', type: '반차'),
          _r('2026-09-03', '08:00', '15:00', type: '반반차'),
          _r('2026-09-04', null, null, type: '월차'),
          _r('2026-09-05', '08:00', '17:00', type: '특근'),
          _r('2026-09-08', null, null, type: '결근'),
        ]),
        DateTime(2026, 9),
        _o,
      );
      expect(s.leaveUsed, 2.75);
      expect(s.typeCounts, {
        '연차': 1,
        '반차': 1,
        '반반차': 1,
        '월차': 1,
        '특근': 1,
        '결근': 1,
      });
    });

    test('시간 글: 분 단위와 소수 시간', () {
      expect(formatMinutes(480), '8시간');
      expect(formatMinutes(510), '8시간 30분');
      expect(formatMinutes(30), '30분');
      expect(formatMinutes(0), '0시간');
      expect(decimalHours(510), '8.5');
      expect(decimalHours(480), '8');
      expect(decimalHours(20), '0.33');
      expect(formatLeaveDays(11.5), '11.5');
      expect(formatLeaveDays(0.25), '0.25');
      expect(formatLeaveDays(15), '15');
    });
  });

  group('연차(제60조, 입사일 기준)', () {
    test('근속연수별 일수: 1·2년 15, 3년 16, 5년 17, 21년 이상 25', () {
      expect(annualLeaveForYears(1), 15);
      expect(annualLeaveForYears(2), 15);
      expect(annualLeaveForYears(3), 16);
      expect(annualLeaveForYears(4), 16);
      expect(annualLeaveForYears(5), 17);
      expect(annualLeaveForYears(21), 25);
      expect(annualLeaveForYears(30), 25);
    });

    test('1년 미만: 결근 없는 달마다 1일, 다음 발생일, 예정 사용', () {
      final b = computeLeaveBalance(
        hire: DateTime(2026, 3, 2),
        today: DateTime(2026, 9, 26),
        types: {
          '2026-05-10': '결근', // 5/2~6/1 달은 개근이 아니다
          '2026-06-15': '월차',
          '2026-10-05': '반차', // 오늘 뒤: 예정
        },
      )!;
      expect(b.years, 0);
      expect(b.lawGranted, 5); // 4/2·5/2·7/2·8/2·9/2에 1일씩(6/2는 결근 때문에 없음)
      expect(b.used, 1);
      expect(b.planned, 0.5);
      expect(b.remaining, 3.5);
      expect(b.nextAccrual, DateTime(2026, 10, 2));
    });

    test('1년 미만 발생은 최대 11일', () {
      final b = computeLeaveBalance(
        hire: DateTime(2025, 10, 1),
        today: DateTime(2026, 9, 30),
        types: const {},
      )!;
      expect(b.years, 0);
      expect(b.lawGranted, 11);
    });

    test('입사 1년 되는 날 15일, 1년 미만 발생분은 새 기간에 넘어가지 않는다', () {
      final b = computeLeaveBalance(
        hire: DateTime(2025, 9, 26),
        today: DateTime(2026, 9, 26),
        types: const {'2026-09-01': '연차'}, // 지난 기간 사용
      )!;
      expect(b.years, 1);
      expect(b.granted, 15);
      expect(b.used, 0);
      expect(b.periodStart, DateTime(2026, 9, 26));
      expect(b.periodEnd, DateTime(2027, 9, 26));
    });

    test('근속 3년 16일, 26년 25일', () {
      expect(
        computeLeaveBalance(
          hire: DateTime(2023, 1, 10),
          today: DateTime(2026, 9, 26),
          types: const {},
        )!.granted,
        16,
      );
      expect(
        computeLeaveBalance(
          hire: DateTime(2000, 1, 1),
          today: DateTime(2026, 9, 26),
          types: const {},
        )!.granted,
        25,
      );
    });

    test('지난 1년 출근율 80% 미만: 개근한 달마다 1일', () {
      final types = <String, String>{};
      for (
        var d = DateTime(2025, 2, 5);
        d.isBefore(DateTime(2025, 5, 5));
        d = DateTime(d.year, d.month, d.day + 1)
      ) {
        if (d.weekday <= 5) types[dateKey(d)] = '결근';
      }
      final b = computeLeaveBalance(
        hire: DateTime(2025, 1, 5),
        today: DateTime(2026, 2, 1),
        types: types,
      )!;
      expect(b.attendanceRate, lessThan(0.8));
      expect(b.lawGranted, 9); // 12달 중 결근 있는 3달 빼고
    });

    test('회사 부여 일수를 넣으면 그 값을 쓴다', () {
      final b = computeLeaveBalance(
        hire: DateTime(2025, 9, 26),
        today: DateTime(2026, 9, 26),
        types: const {},
        overrides: const {'2026-09-26': 16},
      )!;
      expect(b.lawGranted, 15);
      expect(b.granted, 16);
    });

    test('입사 전이면 계산하지 않는다', () {
      expect(
        computeLeaveBalance(
          hire: DateTime(2026, 10, 1),
          today: DateTime(2026, 9, 26),
          types: const {},
        ),
        isNull,
      );
    });

    test('말일 입사: 다음 달에 그 날이 없으면 말일', () {
      expect(addMonthsClamped(DateTime(2024, 1, 31), 1), DateTime(2024, 2, 29));
      expect(addMonthsClamped(DateTime(2023, 1, 31), 1), DateTime(2023, 2, 28));
      expect(
        addMonthsClamped(DateTime(2024, 2, 29), 12),
        DateTime(2025, 2, 28),
      );
    });
  });
}
