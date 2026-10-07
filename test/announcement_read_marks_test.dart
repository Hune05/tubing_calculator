// 공지 읽음 표시(10-08): 이름과 사용자 번호를 같이 적고, 둘 중 하나라도 있으면 읽은 것으로 본다.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/notification/pages/mobile_notification_page.dart';

void main() {
  test('읽을 때 이름과 uid를 같이 적는다(uid가 없으면 이름만)', () {
    expect(announcementReadMarks('홍길동', uid: 'abc'), ['홍길동', 'uid:abc']);
    expect(announcementReadMarks('홍길동'), ['홍길동']);
  });

  test('이름을 바꿔도 uid로 읽은 공지는 읽은 채로 남는다', () {
    final data = {'readBy': ['홍길동', 'uid:abc']};
    expect(announcementIsRead(data, '홍길순', uid: 'abc'), isTrue);
    expect(announcementIsRead(data, '김철수', uid: 'zzz'), isFalse);
  });

  test('예전 공지(이름만 적힘)도 이름이 같으면 읽음, readBy가 없으면 안 읽음', () {
    expect(announcementIsRead({'readBy': ['홍길동']}, '홍길동', uid: 'abc'), isTrue);
    expect(announcementIsRead({}, '홍길동', uid: 'abc'), isFalse);
  });
}
