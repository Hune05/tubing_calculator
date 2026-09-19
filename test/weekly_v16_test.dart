import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/report_tools.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/weekly_report_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/widgets/create_log_sheet.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/widgets/project_summary_card.dart';

String md(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

Map<String, dynamic> proj(
  String name, {
  List<Map<String, dynamic>> punches = const [],
  String status = 'ACTIVE',
}) {
  final t = DateTime.now();
  return {
    'id': name,
    'name': name,
    'date': '2026-09-19 ~ 진행중',
    'revision': '기준 도면 없음',
    'status': status,
    'phases': [],
    'schedules': [],
    'punch_lists': punches,
    'daily_reports': [
      {
        'date': md(t),
        'dateISO': DateTime(t.year, t.month, t.day).toIso8601String(),
        'note': '$name 작업',
        'worker_count': 1,
      },
    ],
  };
}

Future<void> pump(WidgetTester tester, Widget w) async {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: w)));
  await tester.pumpAndSettle();
}

void main() {
  _deleteReminderTest();
  _focusTest();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('reminder problem message', () {
    test('messages now use the 습니다 style', () {
      expect(reminderCountMismatch(2, 0), '일보 알림 2개가 필요한데 예약이 하나도 없습니다.');
      expect(reminderCountMismatch(3, 1), '일보 알림 3개가 필요한데 1개만 예약돼 있습니다.');
      expect(reminderCountMismatch(1, 3), '일보 알림이 필요한 1개보다 많은 3개 예약돼 있습니다.');
      expect(reminderCountMismatch(2, 2), isNull);
    });

    test(
      'returns null (no false alarm) when the plugin is unavailable',
      () async {
        // 테스트 환경에서는 알림 플러그인이 없어 확인할 수 없다 → 문제로 단정하지 않는다.
        expect(await dailyReminderProblem([proj('A')]), isNull);
        expect(await dailyReminderProblem([]), isNull);
      },
    );
  });

  group('overview sort is remembered', () {
    Future<void> openPage(WidgetTester tester) =>
        pump(tester, WeeklyReportPage(logs: [proj('A현장'), proj('B현장')]));

    testWidgets('a saved choice is restored on open', (tester) async {
      SharedPreferences.setMockInitialValues({'weekly_overview_sort': 1});
      await openPage(tester);
      expect(find.text('진행률 낮은 순'), findsOneWidget);
      expect(find.text('기본 순'), findsNothing);
    });

    testWidgets('changing the sort saves it, and it survives a reopen', (
      tester,
    ) async {
      await openPage(tester);
      expect(find.text('기본 순'), findsOneWidget);
      await tester.tap(find.text('기본 순'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('진행률 낮은 순'));
      await tester.pumpAndSettle();
      expect(find.text('납기 빠른 순'), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getInt('weekly_overview_sort'),
        2,
      );
      // 화면을 닫았다 다시 연다.
      await pump(tester, const SizedBox());
      await openPage(tester);
      expect(find.text('납기 빠른 순'), findsOneWidget);
    });

    testWidgets('an out-of-range saved value falls back to the default', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'weekly_overview_sort': 9});
      await openPage(tester);
      expect(find.text('기본 순'), findsOneWidget);
    });
  });

  group('completed project card shows remaining issues explicitly', () {
    Widget card(Map<String, dynamic> log, bool active) =>
        ProjectSummaryCard(log: log, isActive: active, onTap: () {});

    testWidgets('completed: 이슈 남음 N', (tester) async {
      final log = proj(
        'A',
        status: 'DONE',
        punches: [
          {'is_completed': false},
          {'is_completed': false},
          {'is_completed': true},
        ],
      );
      await pump(tester, card(log, false));
      expect(find.text('이슈 남음 2'), findsOneWidget);
      expect(find.text('이슈 2'), findsNothing);
    });

    testWidgets('active: 이슈 N (unchanged)', (tester) async {
      final log = proj(
        'A',
        punches: [
          {'is_completed': false},
        ],
      );
      await pump(tester, card(log, true));
      expect(find.text('이슈 1'), findsOneWidget);
      expect(find.textContaining('이슈 남음'), findsNothing);
    });

    testWidgets('completed without open issues shows no issue chip', (
      tester,
    ) async {
      final log = proj(
        'A',
        status: 'DONE',
        punches: [
          {'is_completed': true},
        ],
      );
      await pump(tester, card(log, false));
      expect(find.textContaining('이슈'), findsNothing);
    });
  });

  group('reminder time when creating a project', () {
    Future<Map<String, dynamic>?> runSheet(
      WidgetTester tester,
      Future<void> Function() interact,
    ) async {
      Map<String, dynamic>? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () async => result = await CreateLogSheet.show(ctx),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      await interact();
      return result;
    }

    testWidgets('default: no reminder time is stored', (tester) async {
      final r = await runSheet(tester, () async {
        await tester.enterText(find.byType(TextField).first, '새현장');
        await tester.tap(find.text('만들기'));
        await tester.pumpAndSettle();
      });
      expect(r, isNotNull);
      expect(r!['name'], '새현장');
      expect(r.containsKey('reportReminderMinutes'), false);
    });

    testWidgets('picking a time stores it; 기본으로 clears it', (tester) async {
      final r = await runSheet(tester, () async {
        await tester.enterText(find.byType(TextField).first, '새현장');
        expect(find.text('기본 시간 사용'), findsOneWidget);
        await tester.tap(find.text('기본 시간 사용'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK')); // 시간 선택창 기본값(18:00) 확정
        await tester.pumpAndSettle();
        expect(find.text('18:00'), findsOneWidget);
        await tester.tap(find.text('만들기'));
        await tester.pumpAndSettle();
      });
      expect(r!['reportReminderMinutes'], 18 * 60);

      final cleared = await runSheet(tester, () async {
        await tester.enterText(find.byType(TextField).first, '새현장');
        await tester.tap(find.text('기본 시간 사용'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('기본으로'));
        await tester.pumpAndSettle();
        expect(find.text('기본 시간 사용'), findsOneWidget);
        await tester.tap(find.text('만들기'));
        await tester.pumpAndSettle();
      });
      expect(cleared!.containsKey('reportReminderMinutes'), false);
    });

    testWidgets('canceling the time picker keeps the default', (tester) async {
      final r = await runSheet(tester, () async {
        await tester.enterText(find.byType(TextField).first, '새현장');
        await tester.tap(find.text('기본 시간 사용'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.text('기본 시간 사용'), findsOneWidget);
        await tester.tap(find.text('만들기'));
        await tester.pumpAndSettle();
      });
      expect(r!.containsKey('reportReminderMinutes'), false);
    });
  });
}

void _focusTest() {
  testWidgets('opening the time picker drops the keyboard focus first', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () => CreateLogSheet.show(ctx),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.text('새로운 작업을\n시작하시겠습니까?'), findsOneWidget);
    await tester.tap(find.byType(TextField).first); // 이름 입력칸에 포커스
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.hasFocus, true);
    await tester.tap(find.text('기본 시간 사용'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    // 창을 닫은 뒤에도 입력칸이 포커스를 되찾지 않는다(키보드가 다시 뜨지 않는다).
    final editable = tester.state<EditableTextState>(
      find.byType(EditableText).first,
    );
    expect(editable.widget.focusNode.hasFocus, false);
  });
}

void _deleteReminderTest() {
  test(
    'after a project is deleted its own reminder time is no longer planned',
    () {
      final now = DateTime(2026, 9, 19, 10);
      final a = proj('루마');
      final b = proj('TESTN')..['reportReminderMinutes'] = 21 * 60;
      a['daily_reports'] = [];
      b['daily_reports'] = [];
      final before = planDailyReminders([a, b], 18 * 60, now);
      expect(before.map((p) => p.minutes).toList(), [1080, 1260]);
      // 삭제 후 남은 목록으로 다시 계획하면 21:00 알림이 사라진다.
      final after = planDailyReminders([a], 18 * 60, now);
      expect(after.map((p) => p.minutes).toList(), [1080]);
      expect(after.single.names, ['루마']);
    },
  );
}
