// 근태 사규(2026-09-29): 소정 출근·퇴근 시각, 사규 메모, 퐁당일 안내.
// 회사 지정 휴일은 없다고 해서 넣지 않았고, 연차는 입사일 기준 그대로다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart'
    show setupFirebaseCoreMocks;
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/attendance/attendance_calc.dart';
import 'package:tubing_calculator/src/presentation/attendance/attendance_settings.dart';
import 'package:tubing_calculator/src/presentation/attendance/pages/attendance_page.dart';
import 'package:tubing_calculator/src/presentation/attendance/widgets/attendance_sheets.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/attendance.dart';

Future<void> _mount(WidgetTester tester, {DateTime? today}) async {
  tester.view.physicalSize = const Size(412, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: AttendancePage(
        today: today ?? DateTime(2026, 9, 26),
        loadRange: (a, b) async => <String, AttendanceRecord>{},
        saveRecord: (r) async => true,
        deleteRecord: (d) async => true,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });
  setUp(() {
    AttendanceCache.byDate = {};
    SharedPreferences.setMockInitialValues({});
  });

  group('퐁당일', () {
    test('앞날과 뒷날이 모두 쉬는 평일만 퐁당일', () {
      // 2026-05-04(월): 앞 일요일, 뒤 어린이날(5/5 화) → 퐁당일.
      expect(isBridgeDay(DateTime(2026, 5, 4)), isTrue);
      // 공휴일 자체·주말·평범한 평일은 아니다.
      expect(isBridgeDay(DateTime(2026, 5, 5)), isFalse);
      expect(isBridgeDay(DateTime(2026, 5, 3)), isFalse);
      expect(isBridgeDay(DateTime(2026, 9, 29)), isFalse);
    });
  });

  group('설정 저장', () {
    test('소정 시각·사규 메모가 저장됐다가 그대로 읽힌다', () async {
      const s = AttendanceSettings(
        workStart: '08:00',
        workEnd: '17:00',
        ruleNote: '퐁당일은 연차 소진',
      );
      await s.save();
      final r = await AttendanceSettings.load();
      expect(r.workStart, '08:00');
      expect(r.workEnd, '17:00');
      expect(r.ruleNote, '퐁당일은 연차 소진');
      expect(r.hasRules, isTrue);
      expect(r.calcOptions.workStart, '08:00');
      expect(r.calcOptions.workEnd, '17:00');
    });

    test('지우면 저장에서도 빠지고, 알아볼 수 없는 시각은 버린다', () async {
      await const AttendanceSettings(workStart: '08:00').save();
      await const AttendanceSettings().save();
      var r = await AttendanceSettings.load();
      expect(r.workStart, isNull);
      expect(r.hasRules, isFalse);

      SharedPreferences.setMockInitialValues({
        AttendanceSettings.workStartKey: '아침',
      });
      r = await AttendanceSettings.load();
      expect(r.workStart, isNull);
    });

    test('사규를 안 넣으면 계산 설정이 예전과 같다', () {
      const o = AttendanceCalcOptions();
      expect(o.workStart, isNull);
      expect(o.defaultBreak, kBreakLegalAuto);
      expect(isRestDay(DateTime(2026, 9, 29), o), isFalse);
    });
  });

  group('화면', () {
    testWidgets('사규가 없으면 빈 안내와 설정 바로가기가 보인다', (tester) async {
      await _mount(tester);
      await tester.tap(find.byKey(const Key('att_rules')));
      await tester.pumpAndSettle();
      expect(
        find.text('넣어 둔 사규가 없습니다. 설정에서 소정 출근·퇴근 시각과 사규 메모를 넣을 수 있습니다.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('att_rules_edit')), findsOneWidget);
    });

    testWidgets('넣어 둔 소정 시각·메모를 사규 보기에서 본다', (tester) async {
      SharedPreferences.setMockInitialValues({
        AttendanceSettings.workStartKey: '08:00',
        AttendanceSettings.workEndKey: '17:00',
        AttendanceSettings.ruleNoteKey: '지각은 9시 이후',
      });
      await _mount(tester);
      await tester.tap(find.byKey(const Key('att_rules')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('att_rules_time'))).data,
        '08:00 ~ 17:00',
      );
      expect(find.byKey(const Key('att_rules_note')), findsOneWidget);
      expect(find.textContaining('지각은 9시 이후'), findsOneWidget);
    });

    testWidgets('새 기록은 소정 시각으로 미리 채워지고 늦은 출근을 알려 준다', (tester) async {
      SharedPreferences.setMockInitialValues({
        AttendanceSettings.workStartKey: '08:00',
        AttendanceSettings.workEndKey: '17:00',
      });
      await _mount(tester);
      await tester.tap(find.textContaining('1일 (').first);
      await tester.pumpAndSettle();
      final hint = tester
          .widget<Text>(find.byKey(const Key('att_schedule_hint')))
          .data!;
      expect(hint, '사규 소정 08:00~17:00');
    });

    testWidgets('늦은 출근·이른 퇴근을 소정 시각과 비교해 알려 준다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttendanceEditSheet(
              day: DateTime(2026, 9, 1),
              existing: AttendanceRecord(
                date: DateTime(2026, 9, 1),
                type: kAttendanceNormal,
                checkIn: '08:30',
                checkOut: '16:00',
              ),
              options: const AttendanceCalcOptions(
                workStart: '08:00',
                workEnd: '17:00',
              ),
            ),
          ),
        ),
      );
      final hint = tester
          .widget<Text>(find.byKey(const Key('att_schedule_hint')))
          .data!;
      expect(hint, contains('출근 30분 늦음'));
      expect(hint, contains('퇴근 1시간 일찍'));
    });

    testWidgets('퐁당일 날짜 창에 안내가 뜬다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AttendanceEditSheet(day: DateTime(2026, 5, 4))),
        ),
      );
      expect(find.byKey(const Key('att_bridge_hint')), findsOneWidget);
    });

    testWidgets('사규를 안 넣으면 소정 안내 줄이 없다', (tester) async {
      await _mount(tester);
      await tester.tap(find.textContaining('1일 (').first);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('att_schedule_hint')), findsNothing);
    });

    testWidgets('설정에서 사규 메모를 적어 저장하면 폰에 남는다', (tester) async {
      await _mount(tester);
      await tester.tap(find.byKey(const Key('att_settings')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('att_rule_note')));
      await tester.enterText(find.byKey(const Key('att_rule_note')), '퐁당일 연차');
      await tester.ensureVisible(find.byKey(const Key('att_settings_save')));
      await tester.tap(find.byKey(const Key('att_settings_save')));
      await tester.pumpAndSettle();
      final r = await AttendanceSettings.load();
      expect(r.ruleNote, '퐁당일 연차');
    });
  });
}
