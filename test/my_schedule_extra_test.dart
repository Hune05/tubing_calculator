import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_schedule/mobile_my_schedule_page.dart'
    show kReminderOptions;
import 'package:tubing_calculator/src/presentation/my_schedule/schedule_backup.dart';
import 'package:tubing_calculator/src/presentation/my_schedule/schedule_logic.dart';
import 'package:tubing_calculator/src/presentation/my_schedule/schedule_search_dialog.dart';

SearchEntry e(
  String group,
  DateTime date,
  String title, {
  String category = '개인',
  String? project,
  String? key,
}) => SearchEntry(
  groupKey: group,
  key: key ?? '$group-${date.toIso8601String()}',
  date: date,
  title: title,
  category: category,
  projectName: project,
);

void main() {
  final now = DateTime(2026, 9, 19, 12);

  group('알림 시간 선택지', () {
    test('알림 없음이 맨 앞이고 시간 순으로 늘어난다', () {
      final keys = kReminderOptions.keys.toList();
      expect(keys.first, 0);
      expect(kReminderOptions[0], '알림 없음');
      for (var i = 1; i < keys.length; i++) {
        expect(keys[i], greaterThan(keys[i - 1]));
      }
    });

    test('10분 전·2시간 전·이틀 전이 있다', () {
      expect(kReminderOptions[10], '10분 전');
      expect(kReminderOptions[120], '2시간 전');
      expect(kReminderOptions[2880], '이틀 전');
      expect(kReminderOptions.values.every((v) => v.isNotEmpty), true);
    });

    test('모든 선택지가 알림 시각 계산에서 그만큼 앞선 시각을 만든다', () {
      final base = DateTime(2026, 10, 10, 15);
      for (final m in kReminderOptions.keys.where((k) => k > 0)) {
        final r = reminderTime(
          base: base,
          minutesBefore: m,
          recurrence: 'none',
          hasTime: true,
          now: now,
        );
        expect(r, base.subtract(Duration(minutes: m)), reason: '$m분 전');
      }
    });
  });

  group('일정 검색', () {
    final all = [
      e('a', DateTime(2026, 9, 25, 10), '거래처 미팅'),
      e('b', DateTime(2026, 9, 10, 9), '거래처 방문', category: '영업'),
      e(
        'c',
        DateTime(2026, 9, 19, 9),
        '루마 검사',
        category: '검사일정',
        project: '루마',
      ),
      e('d', DateTime(2026, 9, 30, 9), '점심'),
    ];

    test('빈 검색어는 결과가 없다', () {
      expect(searchAgenda(all, '', now: now), isEmpty);
      expect(searchAgenda(all, '   ', now: now), isEmpty);
    });

    test('제목에서 찾고 띄어쓰기·대소문자는 무시한다', () {
      final r = searchAgenda(all, '거래처', now: now);
      expect(r.map((x) => x.groupKey).toList(), [
        'a',
        'b',
      ]); // 앞으로 올 것 먼저, 지난 것 뒤
      expect(searchAgenda(all, '거 래 처', now: now).length, 2);
      expect(
        searchAgenda(
          [e('x', now, 'ABC Meeting')],
          'abc meeting',
          now: now,
        ).length,
        1,
      );
    });

    test('종류와 프로젝트 이름으로도 찾는다', () {
      expect(searchAgenda(all, '검사일정', now: now).map((x) => x.groupKey), ['c']);
      expect(searchAgenda(all, '루마', now: now).map((x) => x.groupKey), ['c']);
    });

    test('오늘 일정은 앞으로 올 것에 들어간다', () {
      final r = searchAgenda(all, '검사', now: now);
      expect(r.single.date, DateTime(2026, 9, 19, 9));
    });

    test('같은 일정의 여러 회차는 오늘에 가장 가까운 하나만', () {
      final rep = [
        for (var i = -3; i <= 3; i++)
          e('r', DateTime(2026, 9, 19 + 7 * i, 10), '주간 회의', key: 'r$i'),
      ];
      final r = searchAgenda(rep, '주간', now: now);
      expect(r.length, 1);
      expect(r.single.key, 'r0'); // 9/19가 오늘
    });

    test('맞는 것이 없으면 빈 목록, 결과는 최대 50건', () {
      expect(searchAgenda(all, '없는말', now: now), isEmpty);
      final many = [
        for (var i = 0; i < 80; i++)
          e('g$i', DateTime(2026, 10, 1 + (i % 28)), '점검 $i'),
      ];
      expect(searchAgenda(many, '점검', now: now).length, 50);
    });

    test('지난 일정은 최근 것부터', () {
      final past = [
        e('p1', DateTime(2026, 8, 1), '정기 점검'),
        e('p2', DateTime(2026, 9, 1), '정기 점검 2'),
      ];
      final r = searchAgenda(past, '점검', now: now);
      expect(r.map((x) => x.groupKey).toList(), ['p2', 'p1']);
    });
  });

  group('일정 검색 창', () {
    final all = [
      e('a', DateTime(2026, 9, 25, 10), '거래처 미팅'),
      e('b', DateTime(2026, 9, 10, 9), '거래처 방문', category: '영업'),
    ];

    Future<void> open(
      WidgetTester tester,
      void Function(SearchEntry?) onPop,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  onPop(
                    await showDialog<SearchEntry>(
                      context: ctx,
                      builder: (_) =>
                          ScheduleSearchDialog(entries: all, nowForTest: now),
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
    }

    testWidgets('처음에는 안내가 보이고, 넓은 창이다', (tester) async {
      await open(tester, (_) {});
      expect(find.text('찾을 말을 입력하십시오.'), findsOneWidget);
      expect(tester.getSize(find.byType(Dialog)).width, greaterThan(330));
    });

    testWidgets('검색하면 날짜와 함께 나오고, 지난 일정은 표시한다', (tester) async {
      await open(tester, (_) {});
      await tester.enterText(
        find.byKey(const ValueKey('schedule_search_field')),
        '거래처',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('schedule_result_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('schedule_result_1')), findsOneWidget);
      expect(find.textContaining('2026년 9월 25일 (금) 10:00'), findsOneWidget);
      expect(find.textContaining('지난 일정'), findsOneWidget);
    });

    testWidgets('결과를 누르면 그 일정을 돌려주고 닫힌다', (tester) async {
      SearchEntry? got;
      await open(tester, (v) => got = v);
      await tester.enterText(
        find.byKey(const ValueKey('schedule_search_field')),
        '미팅',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('schedule_result_0')));
      await tester.pumpAndSettle();
      expect(got?.groupKey, 'a');
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('맞는 것이 없으면 그렇게 알려 준다', (tester) async {
      await open(tester, (_) {});
      await tester.enterText(
        find.byKey(const ValueKey('schedule_search_field')),
        '없는말',
      );
      await tester.pumpAndSettle();
      expect(find.text('맞는 일정이 없습니다.'), findsOneWidget);
    });
  });

  group('내 일정 내보내기·가져오기', () {
    PersonalDoc doc(
      String id, {
      String title = '검사',
      String dt = '2026-09-25T10:00:00.000',
    }) => (
      id: id,
      data: {
        'title': title,
        'dateTime': dt,
        'category': '개인',
        'recurrence': 'none',
        'owner': '홍길동',
      },
    );

    test('내보낸 것을 다시 읽으면 그대로 돌아온다', () {
      final text = encodePersonalSchedules([
        doc('1'),
        doc('2', title: '점심'),
      ], DateTime(2026, 9, 19));
      final b = parsePersonalSchedules(text);
      expect(b.items.length, 2);
      expect(b.items[1].id, '2');
      expect(b.items[1].data['title'], '점심');
      expect(b.skipped, 0);
      expect(b.exportedAt, DateTime(2026, 9, 19));
    });

    test('서버 시간(Timestamp)은 글로 바뀌어 저장된다', () {
      final d = (
        id: 'x',
        data: <String, dynamic>{
          'title': 't',
          'dateTime': '2026-09-25T10:00:00.000',
          'createdAt': Timestamp.fromDate(DateTime(2026, 9, 1, 8)),
          'completedOccurrences': {'2026-09-25T00:00:00.000': true},
        },
      );
      final text = encodePersonalSchedules([d], DateTime(2026, 9, 19));
      final j = jsonDecode(text) as Map;
      final data = (j['items'] as List).single['data'] as Map;
      expect(data['createdAt'], isA<String>());
      expect(
        DateTime.parse(data['createdAt'] as String),
        DateTime(2026, 9, 1, 8),
      );
      expect(
        (data['completedOccurrences'] as Map)['2026-09-25T00:00:00.000'],
        true,
      );
    });

    test('이 앱의 백업이 아니면 알려 준다', () {
      expect(() => parsePersonalSchedules('안녕'), throwsFormatException);
      expect(
        () => parsePersonalSchedules('{"app":"other"}'),
        throwsFormatException,
      );
      expect(
        () => parsePersonalSchedules(
          '{"app":"tubing_calculator","kind":"projects","items":[]}',
        ),
        throwsFormatException,
      );
    });

    test('날짜가 없거나 깨진 항목은 건너뛰고 센다', () {
      final text = jsonEncode({
        'app': 'tubing_calculator',
        'kind': kPersonalBackupKind,
        'items': [
          {
            'id': 'ok',
            'data': {'title': 'a', 'dateTime': '2026-09-25T10:00:00.000'},
          },
          {
            'id': 'nodate',
            'data': {'title': 'b'},
          },
          {
            'id': 'bad',
            'data': {'title': 'c', 'dateTime': '날짜아님'},
          },
          {
            'data': {'title': 'noid'},
          },
          '이상한 값',
        ],
      });
      final b = parsePersonalSchedules(text);
      expect(b.items.map((x) => x.id).toList(), ['ok']);
      expect(b.skipped, 4);
    });

    test('새로 들어오는 것과 덮어쓰는 것을 나눈다', () {
      final b = parsePersonalSchedules(
        encodePersonalSchedules([
          doc('1', title: '있음'),
          doc('2', title: '새것'),
          doc('3', title: ' '),
        ], DateTime(2026, 9, 19)),
      );
      final p = planPersonalRestore(b, {'1', '9'});
      expect(p.overwritten, ['있음']);
      expect(p.added, ['새것', '제목 없음']);
    });

    test('가져올 때는 옛 시각을 빼고 주인을 지금 사용자로 바꾼다', () {
      final out = dataForRestore({
        'title': 't',
        'owner': '다른사람',
        'createdAt': '2026-09-01T08:00:00.000',
        'updatedAt': '2026-09-02T08:00:00.000',
      }, '홍길동');
      expect(out['owner'], '홍길동');
      expect(out.containsKey('createdAt'), false);
      expect(out.containsKey('updatedAt'), false);
      expect(out['title'], 't');
    });
  });
}
