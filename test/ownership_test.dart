// 자료의 주인(내 것·공용) — 점검 25·26번.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/data/ownership.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/project_merge.dart';

void main() {
  test('주인 없으면 공용, 내 것만 내 것, 남의 것은 안 보인다', () {
    const shared = <String, dynamic>{'name': 'A'};
    const emptyOwner = <String, dynamic>{'ownerUid': ''};
    const mine = <String, dynamic>{'ownerUid': 'u1'};
    const theirs = <String, dynamic>{'ownerUid': 'u2'};
    expect(isSharedDoc(shared), isTrue);
    expect(isSharedDoc(emptyOwner), isTrue); // "공용으로 돌리기"는 빈 글
    expect(canSeeDoc(mine, 'u1'), isTrue);
    expect(canSeeDoc(theirs, 'u1'), isFalse);
    expect(canSeeDoc(shared, null), isTrue);
    expect(canSeeDoc(mine, null), isFalse);
  });

  test('새 문서 주인 칸: 내 것이면 uid·이름, 공용이거나 uid를 모르면 없음', () {
    expect(ownerFieldsFor(shared: false, uid: 'u1', name: '홍길동'), {
      'ownerUid': 'u1',
      'ownerName': '홍길동',
    });
    expect(ownerFieldsFor(shared: true, uid: 'u1'), isEmpty);
    expect(ownerFieldsFor(shared: false, uid: null), isEmpty);
  });

  test('설정 문서는 사람마다 따로, uid를 모르면 예전처럼 같이 쓰는 문서', () {
    expect(mySettingsDocId('report_style', 'u1'), 'report_style__u1');
    expect(mySettingsDocId('report_style', ''), 'report_style');
  });

  test('합칠 때: 옛 사본에 주인 칸이 없으면 서버 주인을 지킨다, 공용 돌리기는 이긴다', () {
    final kept = mergeProjectDocs(
      local: {'id': '1', 'name': 'A'},
      server: {'id': '1', 'ownerUid': 'u1', 'ownerName': '홍'},
    );
    expect(kept['ownerUid'], 'u1');
    final unshared = mergeProjectDocs(
      local: {'id': '1', 'ownerUid': '', 'ownerName': ''},
      server: {'id': '1', 'ownerUid': 'u1'},
    );
    expect(unshared['ownerUid'], '');
  });
}
