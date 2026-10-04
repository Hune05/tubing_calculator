// 폰 연락처에서 가져온 한 건을 칸에 넣을 모양으로 다듬는다.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/phone_contact_import.dart';

void main() {
  test('이름과 번호의 앞뒤 공백을 걷고 하이픈은 그대로 둔다', () {
    final c = normalizePickedContact('  홍길동 ', ' 010-1234-5678 ');
    expect(c?.name, '홍길동');
    expect(c?.phone, '010-1234-5678');
  });

  test('이름만 있거나 번호만 있어도 가져온다', () {
    expect(normalizePickedContact('홍길동', null)?.name, '홍길동');
    expect(normalizePickedContact('홍길동', null)?.phone, '');
    expect(normalizePickedContact(null, '010-1111-2222')?.name, '');
    expect(normalizePickedContact('', '010-1111-2222')?.phone, '010-1111-2222');
  });

  test('둘 다 비면 아무것도 가져오지 않는다', () {
    expect(normalizePickedContact(null, null), isNull);
    expect(normalizePickedContact('  ', ' '), isNull);
  });
}
