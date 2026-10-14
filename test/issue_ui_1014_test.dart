// 10-14 이슈 화면 개편: 순서·기한 글, 목록(집계·거르기·찾기·밀어서 지우기), 상세(고치기·지우기·
// 처리 완료 바로 저장·기한 없애기).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/theme/app_icon_set.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/issue_view.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/punch_detail_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/widgets/issue_list_section.dart';

final _now = DateTime(2026, 10, 14, 9);

Map<String, dynamic> _p(
  String id, {
  String content = '내용',
  String priority = '보통',
  DateTime? due,
  bool done = false,
  DateTime? created,
  String? link,
  String location = '',
  String assignee = '',
}) => {
  'id': id,
  'content': content,
  'priority': priority,
  'dueDate': due,
  'is_completed': done,
  'created_at': created ?? DateTime(2026, 10, 1),
  'linkedScheduleId': link,
  'location': location,
  'assignee': assignee,
  if (done) 'resolved_at': DateTime(2026, 10, 10),
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('셈', () {
    test('순서: 기한 초과 → 긴급 → 기한 빠른 것 → 최근 등록, 완료는 끝', () {
      final list = [
        _p('done', done: true),
        _p('normal_new', created: DateTime(2026, 10, 12)),
        _p('normal_old', created: DateTime(2026, 10, 2)),
        _p('normal_due', due: DateTime(2026, 10, 20)),
        _p('urgent', priority: '긴급'),
        _p('overdue', due: DateTime(2026, 10, 11), priority: '여유'),
      ];
      expect(sortIssues(list, now: _now).map((e) => e['id']), [
        'overdue',
        'urgent',
        'normal_due',
        'normal_new',
        'normal_old',
        'done',
      ]);
    });

    test('기한 글과 상태, 검사일정에 연결하면 그 날이 기한', () {
      expect(
        issueDueLabel(_p('a', due: DateTime(2026, 10, 11)), now: _now),
        '기한 초과 3일',
      );
      expect(
        issueDueLabel(_p('a', due: DateTime(2026, 10, 14, 18)), now: _now),
        '오늘까지',
      );
      expect(
        issueDueLabel(_p('a', due: DateTime(2026, 10, 15)), now: _now),
        '내일까지',
      );
      expect(
        issueDueLabel(_p('a', due: DateTime(2026, 10, 16)), now: _now),
        '2일 남음',
      );
      expect(
        issueDueLabel(_p('a', due: DateTime(2026, 11, 30)), now: _now),
        '11/30까지',
      );
      expect(issueDueLabel(_p('a'), now: _now), '');
      expect(
        issueStateOf(_p('a', due: DateTime(2026, 10, 15)), now: _now),
        IssueState.dueSoon,
      );
      final schedules = [
        {'id': 's1', 'title': '파이널 검사', 'dateTime': DateTime(2026, 10, 12)},
      ];
      final linked = _p('a', link: 's1', due: DateTime(2026, 12, 1));
      expect(issueDueOf(linked, schedules), DateTime(2026, 10, 12));
      expect(
        issueStateOf(linked, schedules: schedules, now: _now),
        IssueState.overdue,
      );
    });

    test('찾기: 띄어쓰기·대소문자 무시, 위치·담당자도', () {
      final p = _p(
        'a',
        content: 'TT-101 극성 오결선',
        location: '2층 A구역',
        assignee: '홍길동',
      );
      expect(issueMatches(p, 'tt-101'), isTrue);
      expect(issueMatches(p, '2 층'), isTrue);
      expect(issueMatches(p, '홍길'), isTrue);
      expect(issueMatches(p, '누수'), isFalse);
    });
  });

  group('목록', () {
    Future<List<Map<String, dynamic>>> pumpList(
      WidgetTester tester,
      List<Map<String, dynamic>> list,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      final deleted = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setS) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  IssueListSection(
                    punches: list,
                    now: () => _now,
                    onOpen: (_) {},
                    onDelete: (p) => setS(() {
                      list.remove(p);
                      deleted.add(p);
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return deleted;
    }

    testWidgets('집계 숫자, 긴급만 보기, 처리 완료 보기', (tester) async {
      await pumpList(tester, [
        _p('1', content: '긴급 누수', priority: '긴급'),
        _p('2', content: '기한 넘김', due: DateTime(2026, 10, 10)),
        _p('3', content: '보통 일'),
        _p('4', content: '끝난 일', done: true),
      ]);
      expect(find.text('긴급 누수'), findsOneWidget);
      expect(find.text('끝난 일'), findsNothing);
      expect(find.text('기한 초과 4일'), findsOneWidget);

      await tester.tap(find.byKey(const Key('issue_stat_urgent')));
      await tester.pumpAndSettle();
      expect(find.text('긴급 누수'), findsOneWidget);
      expect(find.text('보통 일'), findsNothing);

      await tester.tap(find.byKey(const Key('issue_filter_done')));
      await tester.pumpAndSettle();
      expect(find.text('끝난 일'), findsOneWidget);
      expect(find.text('긴급 누수'), findsNothing);
    });

    testWidgets('6개 넘으면 찾기 칸, 찾으면 맞는 것만', (tester) async {
      await pumpList(tester, [
        for (var i = 0; i < 6; i++) _p('$i', content: '일반 $i'),
        _p('x', content: '센서 극성 오결선'),
      ]);
      await tester.enterText(find.byKey(const Key('issue_search')), '극성');
      await tester.pumpAndSettle();
      expect(find.text('센서 극성 오결선'), findsOneWidget);
      expect(find.text('일반 0'), findsNothing);
    });

    testWidgets('밀면 지운다', (tester) async {
      final deleted = await pumpList(tester, [
        _p('1', content: '지울 이슈'),
        _p('2', content: '남길 이슈'),
      ]);
      await tester.drag(find.text('지울 이슈'), const Offset(-900, 0));
      await tester.pumpAndSettle();
      expect(deleted.single['id'], '1');
      expect(find.text('지울 이슈'), findsNothing);
      expect(find.text('남길 이슈'), findsOneWidget);
    });
  });

  group('상세', () {
    testWidgets('고치기: 등록 화면이 값으로 채워지고, 저장하면 고친 이슈로 돌아온다', (tester) async {
      Map<String, dynamic>? popped;
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      final punch = _p('a', content: '볼트 풀림', location: '2층', priority: '긴급');
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  popped = await Navigator.push<Map<String, dynamic>>(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => PunchDetailPage(punch: punch),
                    ),
                  );
                },
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      expect(find.text('볼트 풀림'), findsOneWidget);

      await tester.tap(find.byKey(const Key('punch_edit')));
      await tester.pumpAndSettle();
      expect(find.text('이슈 고치기'), findsOneWidget);
      expect(find.text('2층'), findsOneWidget);
      await tester.enterText(find.text('볼트 풀림'), '볼트 풀림 — 토크 재확인');
      final submit = find.byKey(const Key('punch_submit'));
      await tester.tap(submit);
      await tester.pumpAndSettle();
      // 고친 것은 바로 돌려줘 저장한다.
      expect(popped?['content'], '볼트 풀림 — 토크 재확인');
      expect(popped?['id'], 'a');
      expect(popped?['priority'], '긴급');
      expect(popped?['location'], '2층');
    });

    testWidgets('지우기: 확인 창 뒤 지운 표시로 돌아온다', (tester) async {
      Map<String, dynamic>? popped;
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  popped = await Navigator.push<Map<String, dynamic>>(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) =>
                          PunchDetailPage(punch: _p('a', content: '잘못 넣음')),
                    ),
                  );
                },
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('punch_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('이슈 지우기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('지우기'));
      await tester.pumpAndSettle();
      expect(popped?[kIssueDeletedKey], isTrue);
      expect(popped?['id'], 'a');
    });

    testWidgets('처리 완료로 저장하면 바로 닫히며 완료로 돌아온다', (tester) async {
      Map<String, dynamic>? popped;
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  popped = await Navigator.push<Map<String, dynamic>>(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) =>
                          PunchDetailPage(punch: _p('a', content: '누수')),
                    ),
                  );
                },
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('punch_resolution_note')),
        '패킹 교체',
      );
      final resolve = find.byKey(const Key('punch_resolve'));
      await tester.ensureVisible(resolve);
      await tester.tap(resolve);
      await tester.pumpAndSettle();
      expect(find.byType(PunchDetailPage), findsNothing);
      expect(popped?['is_completed'], isTrue);
      expect(popped?['resolution_note'], '패킹 교체');
    });

    testWidgets('처리 기한: 없애기를 고르면 기한이 사라진다', (tester) async {
      Map<String, dynamic>? popped;
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  popped = await Navigator.push<Map<String, dynamic>>(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => PunchDetailPage(
                        punch: _p(
                          'a',
                          content: '기한 있음',
                          due: DateTime(2030, 1, 5),
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      expect(find.text('2030.01.05'), findsOneWidget);
      await tester.tap(find.byKey(const Key('punch_due_change')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('punch_due_clear')));
      await tester.pumpAndSettle();
      expect(find.text('2030.01.05'), findsNothing);
      await tester.tap(find.byIcon(AppIcons.back));
      await tester.pumpAndSettle();
      expect(popped, isNotNull);
      expect(popped!['dueDate'], isNull);
    });
  });
}
