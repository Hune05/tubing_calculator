// 근태 관리 화면(필드 헬퍼 4번, 작업 일지와 분리된 화면) 시험.
// 서버 대신 기록 읽기·저장·지우기 함수를 넣어 시험한다(실제 Firestore에 쓰지 않는다).
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart'
    show setupFirebaseCoreMocks;
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/attendance/pages/attendance_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/attendance.dart';
import 'package:tubing_calculator/src/presentation/steel_cutting/screens/steel_pdf_preview_page.dart';

import 'helpers_text.dart';

Future<void> _mount(WidgetTester tester) async {
  tester.view.physicalSize = const Size(412, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // 오늘을 1일로 고정한다(오늘 줄로 옮겨도 1일이 화면에 남고, 날짜에 따라 결과가 바뀌지 않게).
  await tester.pumpWidget(
    MaterialApp(home: AttendancePage(today: DateTime(2026, 9, 1))),
  );
  await tester.pumpAndSettle();
}

/// 가짜 저장소: 메모리 맵. 저장·지우기는 곧바로 끝난다(통신 없는 현장과 같은 모양).
class _FakeStore {
  final Map<String, AttendanceRecord> data;
  final List<AttendanceRecord> saved = [];
  final List<DateTime> deleted = [];
  bool failLoad = false;
  _FakeStore(List<AttendanceRecord> l)
    : data = {for (final r in l) dateKey(r.date): r};

  Future<Map<String, AttendanceRecord>?> load(
    DateTime from,
    DateTime to,
  ) async {
    if (failLoad) return null;
    return {
      for (final e in data.entries)
        if (!e.value.date.isBefore(from) && !e.value.date.isAfter(to))
          e.key: e.value,
    };
  }

  Future<bool> save(AttendanceRecord r) async {
    saved.add(r);
    data[dateKey(r.date)] = r;
    return true;
  }

  Future<bool> delete(DateTime d) async {
    deleted.add(d);
    data.remove(dateKey(d));
    return true;
  }
}

Future<void> _mountFake(
  WidgetTester tester,
  _FakeStore store, {
  DateTime? today,
  Size size = const Size(412, 2400),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: AttendancePage(
        today: today ?? DateTime(2026, 9, 26),
        loadRange: store.load,
        saveRecord: store.save,
        deleteRecord: store.delete,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data ?? '';

void main() {
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });
  setUp(() {
    AttendanceCache.byDate = {};
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('달 머리와 날짜 줄이 보인다', (tester) async {
    await _mount(tester);
    expect(findText("근태 관리"), findsOneWidget);
    expect(findTextContaining("2026년 9월"), findsOneWidget);
    expect(find.textContaining("일 ("), findsWidgets);
  });

  testWidgets('날짜를 누르면 근태 칩이 뜨고, 연차·결근을 고르면 출퇴근 칸이 사라진다', (tester) async {
    await _mount(tester);
    await tester.tap(find.textContaining("1일 (").first);
    await tester.pumpAndSettle();

    for (final label in kAttendanceTypes) {
      expect(find.text(label), findsOneWidget);
    }
    expect(findText("출근 시간"), findsOneWidget);
    expect(findText("퇴근 시간"), findsOneWidget);
    expect(findText("휴게시간"), findsOneWidget);

    await tester.tap(find.text('연차'));
    await tester.pumpAndSettle();
    expect(findText("출근 시간"), findsNothing);
    expect(findText("휴게시간"), findsNothing);

    await tester.tap(find.text('반반차'));
    await tester.pumpAndSettle();
    expect(findText("출근 시간"), findsOneWidget);

    await tester.tap(find.text('결근'));
    await tester.pumpAndSettle();
    expect(findText("퇴근 시간"), findsNothing);
  });

  testWidgets('로그인하지 않았으면 저장하지 못했다고 알린다(창은 닫힌다)', (tester) async {
    await _mount(tester);
    await tester.tap(find.textContaining("1일 (").first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('연차'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('월차'), findsNothing);
    expect(findTextContaining("로그인하지 않아 저장하지 못했습니다"), findsOneWidget);
  });

  testWidgets('이번 달을 열면 1일이 아니라 오늘 줄이 보인다', (tester) async {
    // 폰 크기(세로 800): 1일부터 그리면 26일은 화면 밖이다.
    tester.view.physicalSize = const Size(412, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: AttendancePage(today: DateTime(2026, 9, 26))),
    );
    await tester.pumpAndSettle();

    bool onScreen(String label) {
      final r = tester.getRect(find.text(label));
      return r.top >= 0 && r.bottom <= 800;
    }

    expect(onScreen('26일 (토)'), isTrue);
    expect(onScreen('1일 (화)'), isFalse);
  });

  testWidgets('달 합계: 근로·연장·휴일·가산 시간·연차 사용', (tester) async {
    final store = _FakeStore([
      AttendanceRecord(
        date: DateTime(2026, 9, 22),
        checkIn: '07:00',
        checkOut: '20:00',
      ),
      AttendanceRecord(
        date: DateTime(2026, 9, 27),
        type: '특근',
        checkIn: '08:00',
        checkOut: '19:00',
      ),
      AttendanceRecord(date: DateTime(2026, 9, 23), type: '연차'),
      AttendanceRecord(
        date: DateTime(2026, 9, 21),
        type: '반차',
        checkIn: '08:00',
        checkOut: '12:00',
      ),
    ]);
    await _mountFake(tester, store);
    expect(_textOf(tester, 'att_sum_work'), '25시간 30분'); // 12 + 10 + 3.5
    expect(_textOf(tester, 'att_sum_over'), '4시간');
    expect(_textOf(tester, 'att_sum_holiday'), '10시간');
    expect(_textOf(tester, 'att_sum_premium'), '8시간'); // (4 + 10 + 2) × 0.5
    expect(_textOf(tester, 'att_sum_leave'), '1.5일');
    expect(_textOf(tester, 'att_sum_counts'), contains('특근 1회'));
    // 목록 줄: 시각과 근로시간, 공휴일 이름.
    expect(findTextContaining('07:00 ~ 20:00 · 근로 12시간'), findsOneWidget);
    expect(findText('추석'), findsOneWidget);
  });

  testWidgets('주 52시간을 넘은 주를 빨간 글로 알린다', (tester) async {
    final store = _FakeStore([
      for (var d = 7; d <= 12; d++)
        AttendanceRecord(
          date: DateTime(2026, 9, d),
          checkIn: '07:00',
          checkOut: '19:00',
        ),
    ]);
    await _mountFake(tester, store);
    expect(find.byKey(const Key('att_over52_2026-09-07')), findsOneWidget);
    expect(findTextContaining('주 52시간'), findsWidgets);
  });

  testWidgets('휴게 없음을 고르고 메모를 적어 저장하면 목록에 바로 보인다', (tester) async {
    final store = _FakeStore([
      AttendanceRecord(
        date: DateTime(2026, 9, 22),
        checkIn: '08:00',
        checkOut: '17:00',
      ),
    ]);
    await _mountFake(tester, store);
    await tester.tap(find.text('22일 (화)'));
    await tester.pumpAndSettle();
    expect(_textOf(tester, 'att_day_result'), '근로 8시간 · 휴게 1시간 · 출근~퇴근 9시간');
    await tester.tap(find.byKey(const Key('att_break_0')));
    await tester.pumpAndSettle();
    expect(
      _textOf(tester, 'att_day_result'),
      '근로 9시간 · 휴게 없음 · 출근~퇴근 9시간 · 연장 1시간',
    );
    await tester.enterText(find.byKey(const Key('att_memo')), '태안 3호기');
    await tester.tap(find.byKey(const Key('att_save')));
    await tester.pumpAndSettle();

    expect(store.saved.single.breakMin, 0);
    expect(store.saved.single.memo, '태안 3호기');
    expect(AttendanceCache.byDate['2026-09-22'], kAttendanceNormal);
    expect(findText('태안 3호기'), findsOneWidget);
    expect(_textOf(tester, 'att_sum_work'), '9시간');
  });

  testWidgets('기록 지우기', (tester) async {
    final store = _FakeStore([
      AttendanceRecord(date: DateTime(2026, 9, 23), type: '연차'),
    ]);
    AttendanceCache.byDate = {'2026-09-23': '연차'};
    await _mountFake(tester, store);
    await tester.tap(find.text('23일 (수)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('att_delete')));
    await tester.pumpAndSettle();
    expect(store.deleted.single, DateTime(2026, 9, 23));
    expect(AttendanceCache.byDate.containsKey('2026-09-23'), isFalse);
    expect(_textOf(tester, 'att_sum_leave'), '0일');
  });

  testWidgets('기록을 읽지 못하면 빈 달 대신 알림과 다시 읽기', (tester) async {
    final store = _FakeStore([])..failLoad = true;
    await _mountFake(tester, store);
    expect(find.byKey(const Key('att_load_failed')), findsOneWidget);
    store.failLoad = false;
    await tester.tap(find.text('다시 읽기'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('att_load_failed')), findsNothing);
  });

  testWidgets('달력 보기: 근태 표시, 날짜를 누르면 창이 뜬다, 보기 방식을 기억한다', (tester) async {
    final store = _FakeStore([
      AttendanceRecord(date: DateTime(2026, 9, 23), type: '연차'),
      AttendanceRecord(
        date: DateTime(2026, 9, 22),
        checkIn: '08:00',
        checkOut: '17:00',
      ),
    ]);
    await _mountFake(tester, store);
    await tester.tap(find.byKey(const Key('att_view_toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('att_cal_2026-09-23')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('att_cal_2026-09-23')),
        matching: find.text('연차'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('att_cal_2026-09-22')),
        matching: find.text('8시간'),
      ),
      findsOneWidget,
    );
    final p = await SharedPreferences.getInstance();
    expect(p.getBool('attendance_view_calendar'), isTrue);

    await tester.tap(find.byKey(const Key('att_cal_2026-09-24')));
    await tester.pumpAndSettle();
    expect(findTextContaining('9월 24일 (목) 근태'), findsOneWidget);
  });

  testWidgets('입사일이 있으면 연차 잔여를 보인다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'attendance_hire_date': '2025-03-02',
    });
    AttendanceCache.byDate = {
      '2026-04-10': '연차',
      '2026-09-21': '반차',
      '2026-10-05': '연차', // 예정
    };
    await _mountFake(tester, _FakeStore([]));
    expect(_textOf(tester, 'att_leave_remaining'), '12.5일');
    expect(_textOf(tester, 'att_leave_detail'), '발생 15일 · 사용 1.5일 · 예정 1일');
  });

  testWidgets('설정: 입사일 없으면 안내, 기본 휴게 1시간·토요일 휴일을 저장한다', (tester) async {
    final store = _FakeStore([
      AttendanceRecord(
        date: DateTime(2026, 9, 19), // 토요일
        checkIn: '08:00',
        checkOut: '12:00',
      ),
    ]);
    await _mountFake(tester, store);
    expect(find.byKey(const Key('att_leave_setup')), findsOneWidget);
    expect(_textOf(tester, 'att_sum_work'), '3시간 30분'); // 법정 최소 30분
    expect(_textOf(tester, 'att_sum_holiday'), '0시간');

    await tester.tap(find.byKey(const Key('att_settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('att_default_break_60')));
    await tester.tap(find.byKey(const Key('att_saturday')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('att_settings_save')));
    await tester.pumpAndSettle();

    expect(_textOf(tester, 'att_sum_work'), '3시간');
    expect(_textOf(tester, 'att_sum_holiday'), '3시간');
    final p = await SharedPreferences.getInstance();
    expect(p.getInt('attendance_default_break'), 60);
    expect(p.getBool('attendance_saturday_holiday'), isTrue);
  });

  testWidgets('내보내기: PDF 미리보기가 열린다', (tester) async {
    final old = pdfPreviewBuilder;
    pdfPreviewBuilder = (Uint8List b, String f) => Text('미리보기 $f');
    addTearDown(() => pdfPreviewBuilder = old);
    final store = _FakeStore([
      AttendanceRecord(
        date: DateTime(2026, 9, 22),
        checkIn: '08:00',
        checkOut: '17:00',
      ),
    ]);
    await _mountFake(tester, store);
    await tester.tap(find.byKey(const Key('att_export')));
    await tester.pumpAndSettle();
    expect(find.text('CSV 파일'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('att_export_pdf')));
      await Future<void>.delayed(const Duration(seconds: 2));
    });
    await tester.pumpAndSettle();
    expect(find.text('근태 기록 미리보기'), findsOneWidget);
    expect(find.text('미리보기 attendance_202609.pdf'), findsOneWidget);
  });

  group('좁은 폰(344)·글씨 1.3배에서 넘치지 않는다', () {
    _FakeStore store() => _FakeStore([
      for (var d = 7; d <= 12; d++)
        AttendanceRecord(
          date: DateTime(2026, 9, d),
          type: d == 12 ? '특근' : kAttendanceNormal,
          checkIn: '07:00',
          checkOut: '19:00',
          memo: d == 8 ? '태안 화력 3호기 계장 튜브 포설 출장' : null,
        ),
      AttendanceRecord(date: DateTime(2026, 9, 23), type: '반반차'),
      AttendanceRecord(date: DateTime(2026, 9, 29), type: '결근'),
    ]);

    testWidgets('목록·합계·경고', (tester) async {
      await _mountFake(
        tester,
        store(),
        size: const Size(344, 760),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -3000),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('달력', (tester) async {
      SharedPreferences.setMockInitialValues({
        'attendance_view_calendar': true,
      });
      await _mountFake(
        tester,
        store(),
        size: const Size(344, 760),
        textScale: 1.3,
      );
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -2000),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('하루 창·설정 창·내보내기 창', (tester) async {
      SharedPreferences.setMockInitialValues({
        'attendance_hire_date': '2025-03-02',
      });
      await _mountFake(
        tester,
        store(),
        size: const Size(344, 760),
        textScale: 1.3,
      );
      await tester.ensureVisible(find.textContaining('8일 (화)').first);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('8일 (화)').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('att_day_result')), findsOneWidget);
      Navigator.of(tester.element(find.byKey(const Key('att_memo')))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('att_settings')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('att_grant')), findsOneWidget);
      Navigator.of(tester.element(find.byKey(const Key('att_grant')))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('att_export')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
