// 10-14 작업 일지 하위 모음 나누기: 읽을 때 합치기(joinReports)와 저장할 때 쓸 것 고르기(planReportWrites).
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/project_merge.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/project_reports_split.dart';

Map<String, dynamic> r(String id, String iso, {String? at, String memo = ''}) =>
    {
      'id': id,
      'dateISO': iso,
      'date': '${iso.substring(5, 7)}/${iso.substring(8, 10)}',
      'memo': memo,
      'updatedAt': ?at,
    };

void main() {
  group('joinReports', () {
    test('옛 문서 안 목록과 하위 모음을 아이디로 합치고 최신 날짜가 앞', () {
      final out = joinReports(
        embedded: [r('a', '2026-10-01'), r('b', '2026-10-03')],
        sub: [r('c', '2026-10-02'), r('b', '2026-10-03')],
      );
      expect(out.map((e) => e['id']), ['b', 'c', 'a']);
    });

    test('같은 아이디는 updatedAt이 늦은 쪽, 모르면 하위 모음 것', () {
      final out = joinReports(
        embedded: [
          r('a', '2026-10-01', at: '2026-10-05T10:00:00', memo: '옛 기기'),
          r('b', '2026-10-01', memo: '문서 안'),
        ],
        sub: [
          r('a', '2026-10-01', at: '2026-10-04T10:00:00', memo: '하위'),
          r('b', '2026-10-01', memo: '하위 b'),
        ],
      );
      expect(out.firstWhere((e) => e['id'] == 'a')['memo'], '옛 기기');
      expect(out.firstWhere((e) => e['id'] == 'b')['memo'], '하위 b');
    });

    test('지운 아이디는 어느 쪽에 있어도 뺀다, 아이디 없는 옛 일지는 남긴다', () {
      final out = joinReports(
        embedded: [
          r('a', '2026-10-01'),
          {'date': '10/02', 'memo': '아이디 없음'},
        ],
        sub: [r('b', '2026-10-03')],
        deleted: ['a', 'b'],
      );
      expect(out.length, 1);
      expect(out.single['memo'], '아이디 없음');
    });

    test('같은 날이면 나중에 쓴 것(authoredAt)이 앞', () {
      final out = joinReports(
        sub: [
          {...r('x', '2026-10-01'), 'authoredAt': '2026-10-01T08:00:00'},
          {...r('y', '2026-10-01'), 'authoredAt': '2026-10-01T17:00:00'},
        ],
      );
      expect(out.map((e) => e['id']), ['y', 'x']);
    });
  });

  group('planReportWrites', () {
    test('처음 옮길 때(하위 모음 비었음)는 일지를 다 쓰고 지울 것은 없다', () {
      final plan = planReportWrites(
        merged: [r('a', '2026-10-01'), r('b', '2026-10-02')],
        serverSub: const {},
      );
      expect(plan.toSet.keys, unorderedEquals(['a', 'b']));
      expect(plan.toDelete, isEmpty);
    });

    test('바뀐 일지만 쓰고, 칸 순서·1과 1.0 차이는 바뀐 것으로 안 본다', () {
      final plan = planReportWrites(
        merged: [
          {'id': 'a', 'worker_count': 3, 'memo': '그대로'},
          {'id': 'b', 'memo': '고침'},
        ],
        serverSub: {
          'a': {'memo': '그대로', 'worker_count': 3.0, 'id': 'a'},
          'b': {'id': 'b', 'memo': '전'},
        },
      );
      expect(plan.toSet.keys, ['b']);
    });

    test('목록에서 빠진 것은 지우되, 서버 것을 못 읽었으면 지우지 않는다', () {
      final sub = {'a': r('a', '2026-10-01'), 'gone': r('gone', '2026-09-30')};
      final plan = planReportWrites(
        merged: [r('a', '2026-10-01')],
        serverSub: sub,
      );
      expect(plan.toDelete, ['gone']);
      expect(plan.toSet, isEmpty);
      final safe = planReportWrites(
        merged: [r('a', '2026-10-01')],
        serverSub: sub,
        deleteMissing: false,
      );
      expect(safe.toDelete, isEmpty);
    });

    test("아이디의 '/'는 문서 아이디에서 바꾼다(일지 아이디는 그대로)", () {
      final rep = {'id': 'a/b', 'memo': 'x'};
      final plan = planReportWrites(merged: [rep], serverSub: const {});
      expect(plan.toSet.keys, ['a_b']);
      expect(plan.toSet['a_b']!['id'], 'a/b');
    });
  });

  test('합치기(mergeProjectDocs)에 합친 서버 것을 넣으면 다른 기기 일지가 남는다', () {
    // 이 폰은 a만, 서버는 문서 안 b + 하위 모음 c. 합치면 셋 다.
    final server = {
      'id': 'p',
      kReportsSubcollection: joinReports(
        embedded: [r('b', '2026-10-02')],
        sub: [r('c', '2026-10-03')],
      ),
    };
    final local = {
      'id': 'p',
      kReportsSubcollection: [r('a', '2026-10-04')],
    };
    final merged = mergeProjectDocs(local: local, server: server);
    final ids = (merged[kReportsSubcollection] as List).map((e) => e['id']);
    expect(ids, containsAll(['a', 'b', 'c']));
  });
}
