import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/report_tools.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/notification_check_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/retro_overview_page.dart';

import 'helpers_text.dart';

Map<String, dynamic> doneProj(
  String name, {
  String cause = '',
  String lesson = '',
  DateTime? completed,
}) => {
  'id': name,
  'name': name,
  'status': 'DONE',
  'completedAt': completed ?? DateTime.now(),
  'retro': {'cause': cause, 'lesson': lesson},
  'phases': [],
  'schedules': [],
  'punch_lists': [],
  'daily_reports': [],
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('확인된 알림 기록', () {
    final t = DateTime(2026, 9, 19, 18, 2);

    test('알림 아이디만 인정한다', () {
      expect(isReminderNotificationId(918273), true);
      expect(isReminderNotificationId(918274), true);
      expect(isReminderNotificationId(918300), true);
      expect(isReminderNotificationId(918307), true);
      expect(isReminderNotificationId(918308), false);
      expect(isReminderNotificationId(5), false);
    });

    test('같은 알림이 20시간 안에 또 보이면 새로 적지 않는다', () {
      var l = addSeenReminder([], 918300, t);
      expect(l.length, 1);
      l = addSeenReminder(l, 918300, t.add(const Duration(hours: 3)));
      expect(l.length, 1);
      l = addSeenReminder(l, 918300, t.add(const Duration(hours: 24)));
      expect(l.length, 2);
      l = addSeenReminder(l, 918301, t);
      expect(l.length, 3);
    });

    test('최근 10건만 남는다', () {
      var l = <String>[];
      for (var i = 0; i < 15; i++) {
        l = addSeenReminder(l, 918300, t.add(Duration(days: i)));
      }
      expect(l.length, 10);
      expect(l.last.contains('2026-10-03'), true);
    });

    test('표시 문구', () {
      expect(
        seenReminderLabel('918300|${t.toIso8601String()}'),
        '9/19 18:02  작업일보',
      );
      expect(
        seenReminderLabel('918274|${t.toIso8601String()}'),
        '9/19 18:02  주간 보고',
      );
      expect(seenReminderLabel('깨진 줄'), isNull);
      expect(seenReminderLabel('abc|def'), isNull);
    });

    test('저장 후 최신순으로 읽힌다', () async {
      await recordSeenReminders([918300], t);
      await recordSeenReminders([918274, 7], t.add(const Duration(days: 1)));
      final labels = await loadSeenReminderLabels();
      expect(labels, ['9/20 18:02  주간 보고', '9/19 18:02  작업일보']);
    });

    testWidgets('알림 점검 화면에 기록이 보인다', (tester) async {
      await recordSeenReminders([918300], DateTime(2026, 9, 19, 18, 2));
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: NotificationCheckPage(
            logs: const [],
            pendingIdsLoader: () async => {},
            recordActive: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(findTextContaining('최근 확인된 알림: 9/19 18:02  작업일보'), findsOneWidget);
    });

    testWidgets('기록이 없으면 안내 문구가 보인다', (tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: NotificationCheckPage(
            logs: const [],
            pendingIdsLoader: () async => {},
            recordActive: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(findTextContaining('최근 확인된 알림: 아직 없습니다'), findsOneWidget);
    });
  });

  group('결과 정리 모아보기 검색·기간', () {
    final now = DateTime(2026, 9, 19);

    test('이름·원인·참고에서 찾고 대소문자는 가리지 않는다', () {
      final l = doneProj('Line-A', cause: '자재 지연', lesson: '선주문 필요');
      expect(retroMatches(l, '', RetroPeriod.all, now), true);
      expect(retroMatches(l, 'line', RetroPeriod.all, now), true);
      expect(retroMatches(l, '지연', RetroPeriod.all, now), true);
      expect(retroMatches(l, '선주문', RetroPeriod.all, now), true);
      expect(retroMatches(l, '  지연 ', RetroPeriod.all, now), true);
      expect(retroMatches(l, '없는말', RetroPeriod.all, now), false);
    });

    test('기간: 최근 3개월·올해', () {
      final recent = doneProj('r', completed: DateTime(2026, 7, 1));
      final old = doneProj('o', completed: DateTime(2026, 5, 1));
      final last = doneProj('l', completed: DateTime(2025, 12, 31));
      final none = doneProj('n')..remove('completedAt');
      expect(retroMatches(recent, '', RetroPeriod.last3Months, now), true);
      expect(retroMatches(old, '', RetroPeriod.last3Months, now), false);
      expect(retroMatches(old, '', RetroPeriod.thisYear, now), true);
      expect(retroMatches(last, '', RetroPeriod.thisYear, now), false);
      expect(retroMatches(none, '', RetroPeriod.thisYear, now), false);
      expect(retroMatches(none, '', RetroPeriod.all, now), true);
    });

    Future<void> open(WidgetTester tester, List<Map<String, dynamic>> l) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: RetroOverviewPage(logs: l)));
      await tester.pumpAndSettle();
    }

    testWidgets('검색어를 넣으면 맞는 프로젝트만 남는다', (tester) async {
      await open(tester, [
        doneProj('가동', cause: '비 때문에 지연'),
        doneProj('나동', cause: '인원 부족'),
      ]);
      expect(findText('가동'), findsOneWidget);
      expect(findText('나동'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '인원');
      await tester.pumpAndSettle();
      expect(findText('가동'), findsNothing);
      expect(findText('나동'), findsOneWidget);
      expect(findTextContaining('전체 요약 (완료 1건)'), findsOneWidget);
    });

    testWidgets('조건에 맞는 것이 없으면 안내 문구가 나온다', (tester) async {
      await open(tester, [doneProj('가동')]);
      await tester.enterText(find.byType(TextField), '없는말');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(findText('조건에 맞는 프로젝트가 없습니다.'), findsOneWidget);
      // 검색창은 그대로 남아 있어 지우면 다시 보인다.
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      expect(findText('가동'), findsOneWidget);
    });

    testWidgets('기간 칩으로 오래된 프로젝트가 빠진다', (tester) async {
      final t = DateTime.now();
      await open(tester, [
        doneProj('새것', completed: t),
        doneProj('옛것', completed: DateTime(t.year - 1, 1, 1)),
      ]);
      expect(findText('옛것'), findsOneWidget);
      await tester.tap(find.text('올해'));
      await tester.pumpAndSettle();
      expect(findText('새것'), findsOneWidget);
      expect(findText('옛것'), findsNothing);
    });
  });
}
