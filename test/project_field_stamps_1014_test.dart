// 10-14 프로젝트 맨 위 칸(상태·보관 등)은 더 늦게 고친 쪽이 이기고, "내 일정"의 일정 완료는
// scheduleDone 칸 한 항목으로 적혀 읽을 때 일정 목록에 얹힌다.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/project_merge.dart';

void main() {
  group('맨 위 칸 시각', () {
    test('다른 기기에서 늦게 "완료"로 바꿨으면, 이 폰이 다른 일로 저장해도 완료가 남는다', () {
      final local = <String, dynamic>{
        'id': 'p',
        'status': 'ONGOING',
        kFieldStampsKey: {'status': '2026-10-14T08:00:00'},
      };
      final server = <String, dynamic>{
        'id': 'p',
        'status': 'DONE',
        'completedAt': '2026-10-14T09:00:00',
        kFieldStampsKey: {
          'status': '2026-10-14T09:00:00',
          'completedAt': '2026-10-14T09:00:00',
        },
      };
      final out = mergeProjectDocs(local: local, server: server);
      expect(out['status'], 'DONE');
      expect(out['completedAt'], '2026-10-14T09:00:00');
    });

    test('이 폰이 더 늦게 고쳤으면 이 폰 값, 서버에서 지운 칸은 지운다', () {
      final out = mergeProjectDocs(
        local: {
          'status': 'DONE',
          'archived': true,
          kFieldStampsKey: {
            'status': '2026-10-14T10:00:00',
            'archived': '2026-10-14T07:00:00',
          },
        },
        server: {
          'status': 'ONGOING',
          kFieldStampsKey: {
            'status': '2026-10-14T09:00:00',
            'archived': '2026-10-14T09:30:00',
          },
        },
      );
      expect(out['status'], 'DONE');
      expect(out.containsKey('archived'), isFalse);
    });

    test('시각이 없는 칸은 예전처럼 이 폰 값', () {
      final out = mergeProjectDocs(
        local: {'name': '폰'},
        server: {'name': '서버'},
      );
      expect(out['name'], '폰');
    });

    test('stampFields는 칸마다 시각을 남긴다', () {
      final p = <String, dynamic>{};
      stampFields(p, ['status', 'completedAt']);
      expect(
        (p[kFieldStampsKey] as Map).keys,
        containsAll(['status', 'completedAt']),
      );
    });
  });

  group('일정 완료 칸', () {
    test('표시가 일정의 updatedAt보다 늦으면 얹고, 이르면 그대로', () {
      final p = <String, dynamic>{
        'schedules': [
          {'id': 'a', 'isCompleted': false, 'updatedAt': '2026-10-14T08:00:00'},
          {'id': 'b', 'isCompleted': false, 'updatedAt': '2026-10-14T12:00:00'},
        ],
        kScheduleDoneKey: {
          'a': {'done': true, 'at': '2026-10-14T09:00:00'},
          'b': {'done': true, 'at': '2026-10-14T09:00:00'},
        },
      };
      expect(applyScheduleDone(p), isTrue);
      final s = p['schedules'] as List;
      expect(s[0]['isCompleted'], isTrue);
      expect(s[1]['isCompleted'], isFalse);
    });

    test('합칠 때 두 쪽 표시를 일정마다 늦은 것으로 모으고 목록에 얹는다', () {
      final out = mergeProjectDocs(
        local: {
          'schedules': [
            {'id': 'a', 'isCompleted': false},
          ],
          kScheduleDoneKey: {
            'a': {'done': false, 'at': '2026-10-14T08:00:00'},
          },
        },
        server: {
          'schedules': [
            {'id': 'a', 'isCompleted': false},
          ],
          kScheduleDoneKey: {
            'a': {'done': true, 'at': '2026-10-14T09:00:00'},
          },
        },
      );
      expect((out[kScheduleDoneKey] as Map)['a']['done'], isTrue);
      expect((out['schedules'] as List).first['isCompleted'], isTrue);
    });
  });
}
