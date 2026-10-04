// 근태 화면의 출근·퇴근 카드, 여러 날 기록, 전에 적은 날과 같게 시험.
// 서버 대신 기록 읽기·저장·지우기 함수를 넣어 시험한다(실제 Firestore에 쓰지 않는다).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart'
    show setupFirebaseCoreMocks;
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/attendance/pages/attendance_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/attendance.dart';

class _Store {
  final Map<String, AttendanceRecord> data;
  final List<AttendanceRecord> saved = [];
  final List<DateTime> deleted = [];
  bool failLoad = false;
  _Store(List<AttendanceRecord> l)
    : data = {for (final r in l) dateKey(r.date): r};

  Future<Map<String, AttendanceRecord>?> load(DateTime a, DateTime b) async {
    if (failLoad) return null;
    return {
      for (final e in data.entries)
        if (!e.value.date.isBefore(a) && !e.value.date.isAfter(b))
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

/// [now]를 시험 시각으로 고정해 띄운다. 2026-10-14(수)는 평일이고 공휴일이 아니다.
Future<void> _mount(
  WidgetTester tester,
  _Store store, {
  required DateTime now,
  double textScale = 1.0,
  Size size = const Size(412, 2400),
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
        today: DateTime(now.year, now.month, now.day),
        nowProvider: () => now,
        loadRange: store.load,
        saveRecord: store.save,
        deleteRecord: store.delete,
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
  });

  final wed = DateTime(2026, 10, 14);

  testWidgets('출근 단추를 누르면 지금 시각으로 저장되고, 카드가 근무 중으로 바뀐다', (tester) async {
    final store = _Store([]);
    await _mount(tester, store, now: DateTime(2026, 10, 14, 7, 52));
    expect(_text(tester, 'att_clock_title'), '오늘 출근 전');
    expect(find.byKey(const Key('att_clock_in')), findsOneWidget);

    await tester.tap(find.byKey(const Key('att_clock_in')));
    await tester.pumpAndSettle();

    expect(store.saved.single.date, wed);
    expect(store.saved.single.checkIn, '07:52');
    expect(store.saved.single.checkOut, isNull);
    expect(_text(tester, 'att_clock_title'), '07:52 출근 · 근무 중');
    expect(find.byKey(const Key('att_clock_out')), findsOneWidget);
    expect(find.text('출근 07:52 저장했습니다.'), findsOneWidget);
  });

  testWidgets('퇴근 단추는 퇴근만 채우고, 근로 시간을 알려 준다', (tester) async {
    final store = _Store([
      AttendanceRecord(date: wed, checkIn: '08:00', memo: '태안 3호기'),
    ]);
    await _mount(tester, store, now: DateTime(2026, 10, 14, 17, 31));
    expect(_text(tester, 'att_clock_title'), '08:00 출근 · 근무 중');

    await tester.tap(find.byKey(const Key('att_clock_out')));
    await tester.pumpAndSettle();

    final r = store.saved.single;
    expect(r.checkIn, '08:00');
    expect(r.checkOut, '17:31');
    expect(r.memo, '태안 3호기'); // 있던 메모는 그대로
    expect(_text(tester, 'att_clock_title'), '08:00 ~ 17:31');
    expect(find.textContaining('퇴근 17:31 저장했습니다'), findsOneWidget);
    expect(
      find.textContaining('퇴근 17:31 저장했습니다 · 근로 8시간 31분 · 연장 31분'),
      findsOneWidget,
    );
  });

  testWidgets('잘못 눌렀으면 되돌리기로 전 기록으로 돌린다', (tester) async {
    final store = _Store([]);
    await _mount(tester, store, now: DateTime(2026, 10, 14, 8));
    await tester.tap(find.byKey(const Key('att_clock_in')));
    await tester.pumpAndSettle();
    expect(store.data.containsKey('2026-10-14'), isTrue);

    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();
    expect(store.deleted.single, wed);
    expect(store.data.containsKey('2026-10-14'), isFalse);
    expect(_text(tester, 'att_clock_title'), '오늘 출근 전');
  });

  testWidgets('퇴근을 되돌리면 출근만 있는 기록으로 돌아온다', (tester) async {
    final store = _Store([AttendanceRecord(date: wed, checkIn: '08:00')]);
    await _mount(tester, store, now: DateTime(2026, 10, 14, 17));
    await tester.tap(find.byKey(const Key('att_clock_out')));
    await tester.pumpAndSettle();
    expect(store.data['2026-10-14']!.checkOut, '17:00');

    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();
    expect(store.data['2026-10-14']!.checkOut, isNull);
    expect(_text(tester, 'att_clock_title'), '08:00 출근 · 근무 중');
  });

  testWidgets('출근과 같은 분에는 퇴근이 저장되지 않는다', (tester) async {
    final store = _Store([AttendanceRecord(date: wed, checkIn: '08:00')]);
    await _mount(tester, store, now: DateTime(2026, 10, 14, 8, 0, 20));
    await tester.tap(find.byKey(const Key('att_clock_out')));
    await tester.pumpAndSettle();
    expect(store.saved, isEmpty);
    expect(find.textContaining('방금 출근하셨습니다'), findsOneWidget);
  });

  testWidgets('밤샘: 어제 저녁에 출근했으면 아침에 퇴근을 어제 기록에 찍는다', (tester) async {
    final store = _Store([
      AttendanceRecord(date: DateTime(2026, 10, 13), checkIn: '22:00'),
    ]);
    await _mount(tester, store, now: DateTime(2026, 10, 14, 6, 30));
    expect(_text(tester, 'att_clock_sub'), contains('어제 출근'));

    await tester.tap(find.byKey(const Key('att_clock_out')));
    await tester.pumpAndSettle();
    expect(store.saved.single.date, DateTime(2026, 10, 13));
    expect(store.saved.single.checkOut, '06:30');
  });

  testWidgets('연차인 날은 단추 없이 고치기만 보인다', (tester) async {
    final store = _Store([AttendanceRecord(date: wed, type: '연차')]);
    await _mount(tester, store, now: DateTime(2026, 10, 14, 8));
    expect(_text(tester, 'att_clock_title'), '오늘은 연차입니다');
    expect(find.byKey(const Key('att_clock_in')), findsNothing);
    expect(find.byKey(const Key('att_clock_out')), findsNothing);
    expect(find.byKey(const Key('att_clock_edit')), findsOneWidget);
  });

  testWidgets('기록을 읽지 못하면 출근·퇴근 단추를 막고 다시 읽기를 준다', (tester) async {
    final store = _Store([])..failLoad = true;
    await _mount(tester, store, now: DateTime(2026, 10, 14, 8));
    expect(find.byKey(const Key('att_clock_in')), findsNothing);
    expect(find.byKey(const Key('att_clock_retry')), findsOneWidget);

    store.failLoad = false;
    await tester.tap(find.byKey(const Key('att_clock_retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('att_clock_in')), findsOneWidget);
  });

  testWidgets('퇴근을 안 찍은 지난 날은 목록에 "퇴근 입력 필요", 합계에 안내', (tester) async {
    final store = _Store([
      AttendanceRecord(date: DateTime(2026, 10, 12), checkIn: '08:00'),
      AttendanceRecord(
        date: DateTime(2026, 10, 13),
        checkIn: '08:00',
        checkOut: '17:00',
      ),
    ]);
    await _mount(tester, store, now: DateTime(2026, 10, 14, 9));
    expect(find.byKey(const Key('att_missing_out_2026-10-12')), findsOneWidget);
    expect(find.byKey(const Key('att_missing_out_2026-10-13')), findsNothing);
    expect(find.byKey(const Key('att_sum_missing_out')), findsOneWidget);
  });

  testWidgets('글씨 1.3배·폭 320에서도 카드가 넘치지 않는다', (tester) async {
    final store = _Store([AttendanceRecord(date: wed, checkIn: '08:00')]);
    await _mount(
      tester,
      store,
      now: DateTime(2026, 10, 14, 12),
      textScale: 1.3,
      size: const Size(320, 2400),
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('att_clock_out')), findsOneWidget);
  });

  testWidgets('여러 날: 연차 하루를 기록하면 저장되고 되돌릴 수 있다', (tester) async {
    final store = _Store([]);
    await _mount(tester, store, now: DateTime(2026, 10, 14, 9));
    await tester.tap(find.byKey(const Key('att_range')));
    await tester.pumpAndSettle();
    expect(find.text('여러 날 한 번에 기록'), findsOneWidget);
    expect(_text(tester, 'att_range_preview'), '1일에 기록합니다.');

    await tester.tap(find.byKey(const Key('att_range_type_연차')));
    await tester.pumpAndSettle();
    // 일을 안 하는 종류는 출퇴근 칸이 사라진다.
    expect(find.byKey(const Key('att_range_in')), findsNothing);
    await tester.tap(find.byKey(const Key('att_range_save')));
    await tester.pumpAndSettle();

    expect(store.saved.single.date, wed);
    expect(store.saved.single.type, '연차');
    expect(store.saved.single.checkIn, isNull);
    expect(find.textContaining('1일 기록했습니다'), findsOneWidget);

    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();
    expect(store.data.containsKey('2026-10-14'), isFalse);
  });

  testWidgets('여러 날: 시작일을 앞으로 옮기면 날짜 수가 늘고, 이미 적은 날은 그대로 둔다', (tester) async {
    final store = _Store([
      AttendanceRecord(date: DateTime(2026, 10, 13), type: '반차', memo: '병원'),
    ]);
    await _mount(tester, store, now: DateTime(2026, 10, 14, 9));
    await tester.tap(find.byKey(const Key('att_range')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('att_range_from')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('12'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(_text(tester, 'att_range_preview'), '3일에 기록합니다.');

    await tester.tap(find.byKey(const Key('att_range_save')));
    await tester.pumpAndSettle();

    // 12·14일만 저장, 이미 적은 13일은 그대로.
    expect(store.saved.map((r) => dateKey(r.date)), [
      '2026-10-12',
      '2026-10-14',
    ]);
    expect(store.data['2026-10-13']!.type, '반차');
    expect(find.textContaining('이미 적은 1일은 그대로'), findsOneWidget);
  });

  testWidgets('하루 창: 전에 적은 날과 같게 누르면 시간·종류가 채워진다', (tester) async {
    final store = _Store([
      AttendanceRecord(
        date: DateTime(2026, 10, 12),
        checkIn: '07:30',
        checkOut: '16:30',
        breakMin: 60,
        memo: '태안',
      ),
    ]);
    await _mount(tester, store, now: DateTime(2026, 10, 14, 9));
    await tester.tap(find.textContaining('14일 (').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('att_copy_prev')), findsOneWidget);
    expect(find.text('10월 12일 기록과 같게'), findsOneWidget);

    await tester.tap(find.byKey(const Key('att_copy_prev')));
    await tester.pumpAndSettle();
    expect(find.text('07:30'), findsOneWidget);
    expect(find.text('16:30'), findsOneWidget);

    await tester.tap(find.byKey(const Key('att_save')));
    await tester.pumpAndSettle();
    final r = store.saved.last;
    expect(r.date, wed);
    expect(r.checkIn, '07:30');
    expect(r.checkOut, '16:30');
    expect(r.breakMin, 60);
    expect(r.memo, '태안');
  });

  testWidgets('전에 적은 기록이 없으면 같게 단추가 안 보인다', (tester) async {
    final store = _Store([]);
    await _mount(tester, store, now: DateTime(2026, 10, 14, 9));
    await tester.tap(find.textContaining('14일 (').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('att_copy_prev')), findsNothing);
  });
}
