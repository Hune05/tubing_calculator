// 프로젝트 문서 합치기·아이디 붙이기·작성자 도장.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/project_merge.dart';

void main() {
  group('합치기', () {
    test('서버에만 있는 이슈·일지는 살리고, 폰 것은 그대로', () {
      final local = {
        'id': 'p1',
        'name': '루마',
        'daily_reports': [
          {'id': 'r1', 'note': '폰에서 쓴 일지'},
        ],
        'punch_lists': [
          {'id': 'i1', 'content': '폰 이슈'},
        ],
      };
      final server = {
        'id': 'p1',
        'name': '루마(서버)',
        'daily_reports': [
          {'id': 'r2', 'note': '다른 폰이 쓴 일지'},
        ],
        'punch_lists': [
          {'id': 'i1', 'content': '옛 이슈'},
          {'id': 'i2', 'content': '다른 폰 이슈'},
        ],
      };
      final m = mergeProjectDocs(local: local, server: server);
      expect(m['name'], '루마'); // 칸 값은 폰 것
      expect((m['daily_reports'] as List).map((e) => e['id']), [
        'r2',
        'r1',
      ]); // 일지는 최신이 앞
      expect((m['punch_lists'] as List).map((e) => e['id']), ['i1', 'i2']);
      expect((m['punch_lists'] as List)[0]['content'], '폰 이슈');
    });

    test('같은 아이디는 updatedAt이 늦은 쪽', () {
      final local = {
        'punch_lists': [
          {'id': 'i1', 'content': '폰', 'updatedAt': '2026-09-23T10:00:00'},
        ],
      };
      final server = {
        'punch_lists': [
          {'id': 'i1', 'content': '서버', 'updatedAt': '2026-09-23T11:00:00'},
        ],
      };
      final m = mergeProjectDocs(local: local, server: server);
      expect((m['punch_lists'] as List)[0]['content'], '서버');
    });

    test('지운 아이디는 어느 쪽에 있어도 뺀다', () {
      final local = {
        'punch_lists': [
          {'id': 'i1'},
        ],
        kDeletedIdsKey: ['i2'],
      };
      final server = {
        'punch_lists': [
          {'id': 'i1'},
          {'id': 'i2'},
          {'id': 'i3'},
        ],
        kDeletedIdsKey: ['i3'],
      };
      final m = mergeProjectDocs(local: local, server: server);
      expect((m['punch_lists'] as List).map((e) => e['id']), ['i1']);
      expect((m[kDeletedIdsKey] as List).toSet(), {'i2', 'i3'});
    });

    test('아이디 없는 서버 항목은 예전처럼 폰 것으로 덮는다(겹치지 않게)', () {
      final local = {
        'daily_reports': [
          {'id': 'r1', 'note': '고친 것'},
        ],
      };
      final server = {
        'daily_reports': [
          {'note': '옛 것(아이디 없음)'},
        ],
      };
      final m = mergeProjectDocs(local: local, server: server);
      expect((m['daily_reports'] as List).length, 1);
    });

    test('서버 문서가 없으면 그대로', () {
      final local = {'id': 'p', 'daily_reports': []};
      expect(mergeProjectDocs(local: local, server: null)['id'], 'p');
    });

    test('자재(materials)는 합치지 않고 폰 것 그대로', () {
      final local = {
        'materials': [
          {'name': 'a'},
        ],
      };
      final server = {
        'materials': [
          {'name': 'a'},
          {'name': 'b'},
        ],
      };
      expect(
        (mergeProjectDocs(local: local, server: server)['materials'] as List)
            .length,
        1,
      );
    });
  });

  test('아이디 붙이기: 없는 것만, 서로 다르게', () {
    final p = {
      'daily_reports': [
        {'note': 'a'},
        {'id': 'keep', 'note': 'b'},
        {'note': 'c'},
      ],
    };
    expect(ensureItemIds(p), isTrue);
    final ids = (p['daily_reports'] as List)
        .map((e) => e['id'].toString())
        .toList();
    expect(ids[1], 'keep');
    expect(ids.toSet().length, 3);
    expect(ensureItemIds(p), isFalse);
  });

  test('지운 아이디 적기', () {
    final p = <String, dynamic>{};
    markItemDeleted(p, 'x');
    markItemDeleted(p, 'x');
    markItemDeleted(p, null);
    expect(p[kDeletedIdsKey], ['x']);
  });

  group('지운 항목이 되살아나지 않는다', () {
    Map<String, dynamic> server() => {
      'schedules': [
        {'id': 's1', 'title': '가'},
        {'id': 's2', 'title': '나'},
      ],
      'phases': [
        {'id': 'p1'},
        {'id': 'p2'},
      ],
    };

    test('목록을 바꿀 때 빠진 일정은 지운 것으로 적고, 합쳐도 안 돌아온다', () {
      final local = server();
      // 일정 화면에서 s2를 지우고 돌아옴
      replaceItemList(local, 'schedules', [
        {'id': 's1', 'title': '가'},
      ]);
      expect(local[kDeletedIdsKey], ['s2']);
      final merged = mergeProjectDocs(local: local, server: server());
      expect([for (final m in merged['schedules'] as List) m['id']], ['s1']);
    });

    test('예전처럼 지운 표시가 없으면 되살아난다(고치기 전 동작 확인용)', () {
      final local = server();
      local['schedules'] = [
        {'id': 's1', 'title': '가'},
      ];
      final merged = mergeProjectDocs(local: local, server: server());
      expect((merged['schedules'] as List).length, 2);
    });

    test('단계를 지우며 표시하면 합쳐도 안 돌아온다', () {
      final local = server();
      markItemDeleted(local, 'p2');
      local['phases'] = [
        {'id': 'p1'},
      ];
      final merged = mergeProjectDocs(local: local, server: server());
      expect([for (final m in merged['phases'] as List) m['id']], ['p1']);
    });

    test('새로 넣은 것·그대로 둔 것은 지운 것으로 적지 않는다', () {
      final local = server();
      replaceItemList(local, 'schedules', [
        {'id': 's1'},
        {'id': 's2'},
        {'id': 's3'},
      ]);
      expect(local[kDeletedIdsKey], isNull);
    });
  });

  group('고친 항목 자리 찾기', () {
    test('같은 객체가 있으면 그 자리', () {
      final a = {'id': 'a'};
      final list = [
        {'id': 'x'},
        a,
      ];
      expect(indexOfItem(list, a), 1);
    });

    test('목록이 새로 만들어졌어도(합치기 뒤) 아이디로 찾는다', () {
      final original = {'id': 'r1', 'text': '옛'};
      final list = [
        {'id': 'r0'},
        {'id': 'r1', 'text': '옛'}, // 같은 내용, 다른 객체
      ];
      expect(list.indexOf(original), -1); // 예전 방식은 못 찾아 고친 것을 버렸다
      expect(indexOfItem(list, original), 1);
    });

    test('아이디도 없으면 -1', () {
      expect(
        indexOfItem(
          [
            {'id': 'a'},
          ],
          {'text': '아이디 없음'},
        ),
        -1,
      );
      expect(
        indexOfItem(
          [
            {'id': 'a'},
          ],
          {'id': 'b'},
        ),
        -1,
      );
    });
  });

  group('작성자 도장', () {
    test('새로 만들면 author, 고치면 updatedBy', () {
      final r = <String, dynamic>{};
      stampAuthor(r, '차재훈', created: true);
      expect(r['author'], '차재훈');
      expect(r['authoredAt'], isNotNull);
      stampAuthor(r, '김반장', created: false);
      expect(r['author'], '차재훈');
      expect(r['updatedBy'], '김반장');
      expect(r['updatedAt'], isNotNull);
    });

    test('이름이 없으면 시각만', () {
      final r = <String, dynamic>{};
      stampAuthor(r, '', created: true);
      expect(r.containsKey('author'), isFalse);
      expect(r['authoredAt'], isNotNull);
    });

    test('줄 글', () {
      expect(authorLabel({}), '');
      expect(
        authorLabel({'author': '차재훈', 'authoredAt': '2026-09-23T18:02:00'}),
        '차재훈 9/23 18:02',
      );
      expect(
        authorLabel({
          'author': '차재훈',
          'authoredAt': '2026-09-23T18:02:00',
          'updatedBy': '김반장',
          'updatedAt': '2026-09-24T09:10:00',
        }),
        '차재훈 9/23 18:02 · 김반장 9/24 09:10 고침',
      );
    });
  });
}
