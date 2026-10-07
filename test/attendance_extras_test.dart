// 근태 추가 기능 시험: 예상 수당, 연차 사용 내역, 연간 합계, 퇴근 알림 계획, 위젯 값,
// 그리고 화면(연간 보기·연차 내역·수당 줄·설정 칸·위젯 단추로 열렸을 때).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart'
    show setupFirebaseCoreMocks;
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/utils/home_widget_sync.dart';
import 'package:tubing_calculator/src/presentation/attendance/attendance_calc.dart';
import 'package:tubing_calculator/src/presentation/attendance/attendance_clock.dart';
import 'package:tubing_calculator/src/presentation/attendance/attendance_leave_history.dart';
import 'package:tubing_calculator/src/presentation/attendance/attendance_pay.dart';
import 'package:tubing_calculator/src/presentation/attendance/attendance_settings.dart';
import 'package:tubing_calculator/src/presentation/attendance/attendance_year.dart';
import 'package:tubing_calculator/src/presentation/attendance/pages/attendance_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/attendance.dart';

AttendanceRecord _rec(
  DateTime d, {
  String type = kAttendanceNormal,
  String? inT,
  String? outT,
}) => AttendanceRecord(date: d, type: type, checkIn: inT, checkOut: outT);

MonthSummary _sum({
  int work = 0,
  int overtime = 0,
  int night = 0,
  int holiday = 0,
  int holidayOver8 = 0,
}) => MonthSummary(
  timedDays: 1,
  work: work,
  overtime: overtime,
  night: night,
  holiday: holiday,
  holidayOver8: holidayOver8,
  leaveUsed: 0,
  typeCounts: const {},
  weeks: const [],
);

class _Store {
  final Map<String, AttendanceRecord> data;
  final List<AttendanceRecord> saved = [];
  _Store(List<AttendanceRecord> l)
    : data = {for (final r in l) dateKey(r.date): r};

  Future<Map<String, AttendanceRecord>?> load(DateTime a, DateTime b) async => {
    for (final e in data.entries)
      if (!e.value.date.isBefore(a) && !e.value.date.isAfter(b)) e.key: e.value,
  };

  Future<bool> save(AttendanceRecord r) async {
    saved.add(r);
    data[dateKey(r.date)] = r;
    return true;
  }

  Future<bool> delete(DateTime d) async {
    data.remove(dateKey(d));
    return true;
  }
}

Future<void> _mount(
  WidgetTester tester,
  _Store store, {
  required DateTime now,
  AttendanceAutoPunch autoPunch = AttendanceAutoPunch.none,
}) async {
  tester.view.physicalSize = const Size(412, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: AttendancePage(
        today: DateTime(now.year, now.month, now.day),
        nowProvider: () => now,
        loadRange: store.load,
        saveRecord: store.save,
        deleteRecord: store.delete,
        autoPunch: autoPunch,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data ?? '';

void main() {
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });
  setUp(() {
    AttendanceCache.byDate = {};
    SharedPreferences.setMockInitialValues({});
    HomeWidgetSync.resetForTest();
  });

  group('예상 수당', () {
    test('연장 1.5배, 야간 0.5배, 휴일 1.5배(8시간 넘는 부분은 2배)로 어림한다', () {
      final p = estimateExtraPay(
        _sum(overtime: 120, night: 60, holiday: 540, holidayOver8: 60),
        10000,
      )!;
      expect(p.overtime, 30000); // 10000 × 1.5 × 2시간
      expect(p.night, 5000); // 10000 × 0.5 × 1시간
      expect(p.holiday, 140000); // 10000 × (1.5 × 9 + 0.5 × 1)
      expect(p.total, 175000);
    });

    test('시급이 없거나 0이면 계산하지 않는다', () {
      expect(estimateExtraPay(_sum(overtime: 60), null), isNull);
      expect(estimateExtraPay(_sum(overtime: 60), 0), isNull);
    });

    test('시간이 없으면 0원', () {
      expect(estimateExtraPay(_sum(), 10000)!.total, 0);
    });

    test('원 단위 표시', () {
      expect(formatWon(0), '0원');
      expect(formatWon(999), '999원');
      expect(formatWon(1234567), '1,234,567원');
      expect(formatWon(100000), '100,000원');
    });
  });

  group('연차 사용 내역', () {
    final start = DateTime(2026, 3, 15);
    final end = DateTime(2027, 3, 15);
    final today = DateTime(2026, 10, 14);

    test('기간 안의 연차·월차·반차·반반차만 날짜순으로, 누계와 예정 표시', () {
      final e = leaveHistory(
        types: {
          '2026-03-14': '연차', // 기간 전
          '2026-04-01': '연차',
          '2026-10-12': '반차',
          '2026-12-24': '반반차', // 예정
          '2026-05-02': '조퇴', // 연차 아님
          '2027-03-15': '연차', // 기간 끝 날(미포함)
        },
        periodStart: start,
        periodEnd: end,
        today: today,
      );
      expect(e.map((x) => dateKey(x.date)), [
        '2026-04-01',
        '2026-10-12',
        '2026-12-24',
      ]);
      expect(e.map((x) => x.days), [1, 0.5, 0.25]);
      expect(e.map((x) => x.usedAfter), [1, 1.5, 1.75]);
      expect(e.map((x) => x.planned), [false, false, true]);
    });

    test('기간이 끝나는 날까지 남은 날 수', () {
      expect(daysUntilPeriodEnd(end, DateTime(2027, 3, 14)), 0);
      expect(daysUntilPeriodEnd(end, DateTime(2027, 3, 1)), 13);
      expect(daysUntilPeriodEnd(end, DateTime(2028, 1, 1)), 0);
    });
  });

  group('연간 합계', () {
    test('달마다 합치고, 두 달에 걸친 주 52시간 초과는 한 번만 센다', () {
      final recs = <String, AttendanceRecord>{};
      // 2026-09-28(월) ~ 10-02(금): 하루 06:00~20:00(휴게 1시간, 근로 13시간) → 주 65시간
      for (var d = 28; d <= 30; d++) {
        final day = DateTime(2026, 9, d);
        recs[dateKey(day)] = _rec(day, inT: '06:00', outT: '20:00');
      }
      for (var d = 1; d <= 2; d++) {
        final day = DateTime(2026, 10, d);
        recs[dateKey(day)] = _rec(day, inT: '06:00', outT: '20:00');
      }
      final y = summarizeYear(recs, 2026, const AttendanceCalcOptions());
      expect(y.months.length, 12);
      expect(y.work, 5 * 13 * 60);
      expect(y.months[8].work + y.months[9].work, y.work); // 9월+10월
      expect(y.weeksOver52, 1);
      expect(y.months[0].work, 0);
    });

    test('연 범위는 1월 첫 주 월요일부터 12월 마지막 주 일요일까지', () {
      final r = yearRange(2026);
      expect(r.from.weekday, DateTime.monday);
      expect(r.to.weekday, DateTime.sunday);
      expect(r.from.isAfter(DateTime(2026, 1, 1)), isFalse);
      expect(r.to.isBefore(DateTime(2026, 12, 31)), isFalse);
    });

    test('시간 표 칸 표기', () {
      expect(shortHours(0), '-');
      expect(shortHours(480), '8');
      expect(shortHours(510), '8.5');
    });
  });

  group('퇴근 알림 계획·위젯 값', () {
    final day = DateTime(2026, 10, 14);

    test('켜져 있고 출근만 찍었으면 소정 퇴근 30분 뒤', () {
      final w = planClockOutReminder(
        enabled: true,
        workEnd: '17:00',
        today: _rec(day, inT: '08:00'),
        now: DateTime(2026, 10, 14, 9),
      );
      expect(w, DateTime(2026, 10, 14, 17, 30));
    });

    test('꺼져 있거나 소정 퇴근이 없거나 퇴근을 찍었거나 시각이 지났으면 없다', () {
      final open = _rec(day, inT: '08:00');
      final now = DateTime(2026, 10, 14, 9);
      expect(
        planClockOutReminder(
          enabled: false,
          workEnd: '17:00',
          today: open,
          now: now,
        ),
        isNull,
      );
      expect(
        planClockOutReminder(
          enabled: true,
          workEnd: null,
          today: open,
          now: now,
        ),
        isNull,
      );
      expect(
        planClockOutReminder(
          enabled: true,
          workEnd: '17:00',
          today: _rec(day, inT: '08:00', outT: '17:10'),
          now: now,
        ),
        isNull,
      );
      expect(
        planClockOutReminder(
          enabled: true,
          workEnd: '17:00',
          today: open,
          now: DateTime(2026, 10, 14, 17, 31),
        ),
        isNull,
      );
      expect(
        planClockOutReminder(
          enabled: true,
          workEnd: '17:00',
          today: null,
          now: now,
        ),
        isNull,
      );
      expect(
        planClockOutReminder(
          enabled: true,
          workEnd: '17:00',
          today: _rec(day, type: '연차'),
          now: now,
        ),
        isNull,
      );
    });

    test('위젯 값: 날짜·상태·글', () {
      final now = DateTime(2026, 10, 14, 9);
      final j =
          jsonDecode(
                encodeClockWidgetPayload(
                  clockStatus(
                    now: now,
                    today: _rec(day, inT: '08:05'),
                  ),
                  now,
                ),
              )
              as Map<String, dynamic>;
      expect(j['date'], '2026-10-14');
      expect(j['phase'], 'working');
      expect(j['text'], '08:05 출근 · 근무 중');

      final r =
          jsonDecode(encodeClockWidgetPayload(clockStatus(now: now), now))
              as Map<String, dynamic>;
      expect(r['phase'], 'ready');
      expect(r['text'], '오늘 출근 전');
    });

    test('위젯 값: 퇴근한 날 근무 시간은 앱처럼 기본 휴게를 뺀다(10-07)', () {
      final now = DateTime(2026, 10, 14, 18);
      final w = jsonDecode(
        encodeClockWidgetPayload(
          clockStatus(now: now, today: _rec(day, inT: '08:00', outT: '17:00')),
          now,
          options: const AttendanceCalcOptions(),
        ),
      ) as Map<String, dynamic>;
      expect(w['big'], '8:00');
    });

    test('위젯 값: 근무 중일 때만 출근 시각(since)을 넘긴다', () {
      final now = DateTime(2026, 10, 14, 9);
      final w =
          jsonDecode(
                encodeClockWidgetPayload(
                  clockStatus(
                    now: now,
                    today: _rec(day, inT: '08:05'),
                  ),
                  now,
                ),
              )
              as Map<String, dynamic>;
      expect(w['since'], DateTime(2026, 10, 14, 8, 5).millisecondsSinceEpoch);

      final done =
          jsonDecode(
                encodeClockWidgetPayload(
                  clockStatus(
                    now: now,
                    today: _rec(day, inT: '08:05', outT: '08:50'),
                  ),
                  now,
                ),
              )
              as Map<String, dynamic>;
      expect(done.containsKey('since'), isFalse);
      expect(done['phase'], 'done');

      // 밤샘: 출근한 날(어제) 기준으로 센다.
      final night =
          jsonDecode(
                encodeClockWidgetPayload(
                  clockStatus(
                    now: DateTime(2026, 10, 14, 6),
                    yesterday: _rec(DateTime(2026, 10, 13), inT: '22:00'),
                  ),
                  DateTime(2026, 10, 14, 6),
                ),
              )
              as Map<String, dynamic>;
      expect(night['since'], DateTime(2026, 10, 13, 22).millisecondsSinceEpoch);
    });

    test('위젯 동작 이름: attendance:in/out/open', () {
      expect(const HomeWidgetAction('attendance:in').attendanceAction, 'in');
      expect(const HomeWidgetAction('attendance:out').attendanceAction, 'out');
      expect(
        const HomeWidgetAction('attendance:open').attendanceAction,
        'open',
      );
      expect(const HomeWidgetAction('quick:내 프로젝트').attendanceAction, isNull);
      expect(const HomeWidgetAction('attendance:in').quickTitle, isNull);
    });
  });

  widgetPayloadTests();

  group('설정 저장', () {
    test('통상시급은 기기에만, 퇴근 알림은 서버에 올리는 칸에 있다', () async {
      await const AttendanceSettings(
        hourlyWage: 12500,
        clockOutReminder: true,
        workEnd: '17:00',
      ).save();
      final s = await AttendanceSettings.load();
      expect(s.hourlyWage, 12500);
      expect(s.clockOutReminder, isTrue);

      final cleared = s.copyWith(clearWage: true);
      await cleared.save();
      expect((await AttendanceSettings.load()).hourlyWage, isNull);
    });
  });

  group('화면', () {
    final wed = DateTime(2026, 10, 14);

    testWidgets('통상시급을 넣으면 한 달 합계에 예상 수당이 보이고, 없으면 안 보인다', (tester) async {
      SharedPreferences.setMockInitialValues({'attendance_hourly_wage': 10000});
      // 08:00~19:00 = 출근~퇴근 11시간, 휴게 1시간 → 근로 10시간 → 연장 2시간
      final store = _Store([_rec(wed, inT: '08:00', outT: '19:00')]);
      await _mount(tester, store, now: DateTime(2026, 10, 14, 20));
      expect(_text(tester, 'att_sum_pay'), '예상 수당 약 30,000원');
      expect(_text(tester, 'att_sum_pay_detail'), '연장 30,000원 · 야간 0원 · 휴일 0원');
    });

    testWidgets('시급이 없으면 예상 수당 줄이 없다', (tester) async {
      final store = _Store([_rec(wed, inT: '08:00', outT: '19:00')]);
      await _mount(tester, store, now: DateTime(2026, 10, 14, 20));
      expect(find.byKey(const Key('att_sum_pay')), findsNothing);
    });

    testWidgets('연간 보기: 달별 표와 합계, 해 넘기기', (tester) async {
      SharedPreferences.setMockInitialValues({'attendance_hourly_wage': 10000});
      final store = _Store([
        _rec(wed, inT: '08:00', outT: '19:00'),
        _rec(DateTime(2026, 3, 4), inT: '08:00', outT: '17:00'),
        _rec(DateTime(2026, 5, 6), type: '연차'),
      ]);
      await _mount(tester, store, now: DateTime(2026, 10, 14, 20));
      await tester.tap(find.byKey(const Key('att_open_year')));
      await tester.pumpAndSettle();

      expect(_text(tester, 'att_year_title'), '2026년');
      expect(find.byKey(const Key('att_year_row_10')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('att_year_row_10')),
          matching: find.text('10'),
        ),
        findsOneWidget,
      ); // 10월 근로 10시간
      expect(
        find.descendant(
          of: find.byKey(const Key('att_year_row_5')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      ); // 5월 연차 1일
      expect(find.byKey(const Key('att_year_total')), findsOneWidget);
      expect(_text(tester, 'att_year_pay'), '예상 수당 합계(참고용) 약 30,000원');

      await tester.tap(find.byKey(const Key('att_year_prev')));
      await tester.pumpAndSettle();
      expect(_text(tester, 'att_year_title'), '2025년');
      expect(find.byKey(const Key('att_year_over52')), findsNothing);
    });

    testWidgets('연차 사용 내역: 쓴 날·예정·남은 일수·기간 끝까지 남은 날', (tester) async {
      SharedPreferences.setMockInitialValues({
        'attendance_hire_date': '2020-03-15',
      });
      AttendanceCache.byDate = {
        '2026-04-01': '연차',
        '2026-10-12': '반차',
        '2026-12-24': '연차',
      };
      final store = _Store([]);
      await _mount(tester, store, now: DateTime(2026, 10, 14, 9));
      expect(_text(tester, 'att_leave_remaining'), '14.5일');

      await tester.ensureVisible(find.byKey(const Key('att_leave_history')));
      await tester.tap(find.byKey(const Key('att_leave_history')));
      await tester.pumpAndSettle();

      expect(
        _text(tester, 'att_leave_sheet_sum'),
        '발생 17일 · 사용 1.5일 · 예정 1일 · 남음 14.5일',
      );
      expect(find.byKey(const Key('att_leave_row_2026-04-01')), findsOneWidget);
      expect(find.byKey(const Key('att_leave_row_2026-10-12')), findsOneWidget);
      expect(find.byKey(const Key('att_leave_row_2026-12-24')), findsOneWidget);
      expect(find.textContaining('예정'), findsWidgets);
      // 기간 끝 2027-03-14까지 151일
      expect(
        _text(tester, 'att_leave_sheet_left'),
        '이 연차 기간이 끝나는 날까지 151일 남았습니다.',
      );
    });

    testWidgets('입사일이 없으면 사용 내역 단추가 없다', (tester) async {
      await _mount(tester, _Store([]), now: DateTime(2026, 10, 14, 9));
      expect(find.byKey(const Key('att_leave_history')), findsNothing);
    });

    testWidgets('설정 창: 소정 퇴근이 없으면 퇴근 알림은 못 켜고, 통상시급을 저장한다', (tester) async {
      await _mount(tester, _Store([]), now: DateTime(2026, 10, 14, 9));
      await tester.tap(find.byKey(const Key('att_settings')));
      await tester.pumpAndSettle();

      final sw = tester.widget<SwitchListTile>(
        find.byKey(const Key('att_clockout_reminder')),
      );
      expect(sw.onChanged, isNull);
      expect(find.text('소정 퇴근 시간을 넣으면 쓸 수 있습니다.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('att_wage')), '12,500');
      await tester.ensureVisible(find.byKey(const Key('att_settings_save')));
      await tester.tap(find.byKey(const Key('att_settings_save')));
      await tester.pumpAndSettle();
      expect((await AttendanceSettings.load()).hourlyWage, 12500);
    });

    testWidgets('위젯 [출근]으로 열리면 읽은 뒤 바로 출근을 찍는다', (tester) async {
      final store = _Store([]);
      await _mount(
        tester,
        store,
        now: DateTime(2026, 10, 14, 7, 45),
        autoPunch: AttendanceAutoPunch.clockIn,
      );
      expect(store.saved.single.checkIn, '07:45');
      expect(_text(tester, 'att_clock_title'), '07:45 출근 · 근무 중');
    });

    testWidgets('위젯 [출근]인데 이미 찍었으면 덮지 않고 알리기만 한다', (tester) async {
      final store = _Store([_rec(wed, inT: '08:00')]);
      await _mount(
        tester,
        store,
        now: DateTime(2026, 10, 14, 9),
        autoPunch: AttendanceAutoPunch.clockIn,
      );
      expect(store.saved, isEmpty);
      expect(find.text('이미 08:00에 출근을 찍었습니다.'), findsOneWidget);
    });

    testWidgets('위젯 [퇴근]으로 열리면 퇴근을 찍는다', (tester) async {
      final store = _Store([_rec(wed, inT: '08:00')]);
      await _mount(
        tester,
        store,
        now: DateTime(2026, 10, 14, 17, 40),
        autoPunch: AttendanceAutoPunch.clockOut,
      );
      expect(store.saved.single.checkOut, '17:40');
    });

    testWidgets('위젯 [퇴근]인데 출근 기록이 없으면 찍지 않고 안내한다', (tester) async {
      final store = _Store([]);
      await _mount(
        tester,
        store,
        now: DateTime(2026, 10, 14, 17, 40),
        autoPunch: AttendanceAutoPunch.clockOut,
      );
      expect(store.saved, isEmpty);
      expect(find.textContaining('출근 기록이 없어 퇴근을 찍지 못했습니다'), findsOneWidget);
    });
  });
}

void widgetPayloadTests() {
  group('위젯 값(큰 글·아랫줄·휴게·메모)', () {
    final now = DateTime(2026, 10, 14, 9);
    final day = DateTime(2026, 10, 14);

    Map<String, dynamic> enc(
      ClockStatus st, {
      Map<String, AttendanceRecord>? recs,
    }) =>
        jsonDecode(encodeClockWidgetPayload(st, now, records: recs))
            as Map<String, dynamic>;

    test('출근 전: 큰 글 00:00, 아랫줄은 지난 퇴근', () {
      final recs = {
        '2026-10-13': AttendanceRecord(
          date: DateTime(2026, 10, 13),
          checkIn: '08:00',
          checkOut: '17:30',
        ),
      };
      final j = enc(clockStatus(now: now), recs: recs);
      expect(j['phase'], 'ready');
      expect(j['big'], '00:00');
      expect(j['sub'], '어제 17:30 퇴근');
    });

    test('지난 퇴근이 없으면 "오늘 출근 전", 며칠 전이면 날짜로', () {
      expect(enc(clockStatus(now: now))['sub'], '오늘 출근 전');
      final recs = {
        '2026-10-10': AttendanceRecord(
          date: DateTime(2026, 10, 10),
          checkIn: '08:00',
          checkOut: '17:10',
        ),
      };
      expect(enc(clockStatus(now: now), recs: recs)['sub'], '10월 10일 17:10 퇴근');
    });

    test('근무 중: 큰 글은 비우고(위젯이 흐르는 시간을 그림), 휴게·메모를 넘긴다', () {
      final r = AttendanceRecord(
        date: day,
        checkIn: '08:05',
        breakMin: 60,
        memo: '출장 태안',
      );
      final j = enc(clockStatus(now: now, today: r));
      expect(j['big'], '');
      expect(j['sub'], '08:05 출근');
      expect(j['brk'], 60);
      expect(j['memo'], '출장 태안');
      expect(j.containsKey('since'), isTrue);
    });

    test('퇴근 뒤: 큰 글은 근무 시간(휴게 뺀 것), 아랫줄은 출퇴근', () {
      final r = AttendanceRecord(
        date: day,
        checkIn: '08:00',
        checkOut: '17:30',
        breakMin: 60,
      );
      final j = enc(clockStatus(now: now, today: r));
      expect(j['big'], '8:30');
      expect(j['sub'], '08:00 ~ 17:30');
    });

    test('휴게·메모가 없으면 그 칸을 넘기지 않는다', () {
      final j = enc(
        clockStatus(
          now: now,
          today: AttendanceRecord(date: day, checkIn: '08:05'),
        ),
      );
      expect(j.containsKey('brk'), isFalse);
      expect(j.containsKey('memo'), isFalse);
    });
  });
}
