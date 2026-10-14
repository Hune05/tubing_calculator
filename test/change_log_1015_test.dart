// 10-15 프로젝트 변경 기록: 앞 모습과 견줘 넣음·고침·처리 완료·지움·프로젝트 상태를 한 줄씩 남기고,
// 사진 주소만 바뀐 것은 고침으로 치지 않으며, 여러 기기 기록은 아이디로 합친다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/change_log.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/project_merge.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/change_log_page.dart';

Map<String, dynamic> _log() => {
  'id': 'p1',
  'name': '시험',
  'status': 'ACTIVE',
  'punch_lists': [
    {'id': 'i1', 'content': '볼트 풀림', 'is_completed': false},
    {'id': 'i2', 'content': '라벨 누락', 'is_completed': false},
  ],
  'schedules': [
    <String, dynamic>{'id': 's1', 'title': '파이널 검사', 'isCompleted': false},
  ],
  'daily_reports': [
    <String, dynamic>{'id': 'r1', 'date': '10/14', 'note': '결선'},
  ],
};

void main() {
  final t = DateTime(2026, 10, 15, 9, 30);

  test('넣음·고침·처리 완료·지움·확정·프로젝트 상태를 글로 남긴다', () {
    final log = _log();
    final before = projectSnapshot(log);
    final punches = log['punch_lists'] as List;
    (punches[0] as Map)['is_completed'] = true;
    punches.removeAt(1);
    punches.add({'id': 'i3', 'content': '누수', 'is_completed': false});
    ((log['schedules'] as List)[0] as Map)['title'] = '파이널 검사(감리)';
    ((log['daily_reports'] as List)[0] as Map)['locked'] = true;
    log['status'] = 'DONE';
    final out = diffChanges(before, projectSnapshot(log), who: '홍길동', now: t);
    final texts = out.map((e) => e['text']).toList();
    expect(
      texts,
      containsAll([
        '이슈 처리 완료: 볼트 풀림',
        '이슈 지움: 라벨 누락',
        '이슈 추가: 누수',
        '일정 고침: 파이널 검사(감리)',
        '작업 일지 확정: 10/14',
        '프로젝트 완료 처리',
      ]),
    );
    expect(out.every((e) => e['who'] == '홍길동'), isTrue);
    expect(out.map((e) => e['id']).toSet().length, out.length);
  });

  test('사진 주소·고친 시각만 바뀌면 기록하지 않는다', () {
    final log = _log();
    final before = projectSnapshot(log);
    final r = (log['daily_reports'] as List)[0] as Map;
    r['image_paths'] = ['https://x/1.jpg'];
    r['updatedAt'] = '2026-10-15T09:00:00';
    r['updatedBy'] = '김철수';
    expect(diffChanges(before, projectSnapshot(log), now: t), isEmpty);
  });

  test('최근 300건만 남기고, 두 기기 기록은 아이디로 합친다', () {
    final log = <String, dynamic>{};
    appendChanges(log, [
      for (var i = 0; i < 310; i++)
        {
          'id': 'c$i',
          'at': t.add(Duration(minutes: i)).toIso8601String(),
          'text': '$i',
        },
    ]);
    expect((log[kChangeLogKey] as List).length, kChangeLogMax);
    expect(changeLogOf(log).first['id'], 'c309');

    final a = <String, dynamic>{
      kChangeLogKey: [
        {'id': 'a1', 'at': '2026-10-15T09:00:00', 'text': 'A'},
      ],
    };
    final b = <String, dynamic>{
      kChangeLogKey: [
        {'id': 'b1', 'at': '2026-10-15T09:01:00', 'text': 'B'},
      ],
    };
    final merged = mergeProjectDocs(local: a, server: b);
    expect(
      (merged[kChangeLogKey] as List).map((e) => (e as Map)['id']).toSet(),
      {'a1', 'b1'},
    );
  });

  testWidgets('변경 기록 화면: 최근 것이 위, 종류로 거른다', (tester) async {
    final log = _log()
      ..[kChangeLogKey] = [
        {
          'id': '1',
          'at': '2026-10-14T08:00:00',
          'kind': 'punch_lists',
          'text': '이슈 추가: 볼트 풀림',
          'who': '홍길동',
        },
        {
          'id': '2',
          'at': '2026-10-15T09:00:00',
          'kind': 'schedules',
          'text': '일정 고침: 파이널 검사',
        },
      ];
    await tester.pumpWidget(MaterialApp(home: ChangeLogPage(log: log)));
    await tester.pumpAndSettle();
    final y1 = tester.getTopLeft(find.text('일정 고침: 파이널 검사')).dy;
    final y2 = tester.getTopLeft(find.text('이슈 추가: 볼트 풀림')).dy;
    expect(y1, lessThan(y2));
    await tester.tap(find.byKey(const Key('change_kind_punch_lists')));
    await tester.pumpAndSettle();
    expect(find.text('일정 고침: 파이널 검사'), findsNothing);
    expect(find.text('이슈 추가: 볼트 풀림'), findsOneWidget);
  });
}
