// 폰 연락처에서 고른 한 명의 값을 칸에 넣을 모양으로 다듬는다(이름·전화번호·이메일).
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/phone_contact_import.dart';

void main() {
  test('이름·번호·이메일의 앞뒤 공백을 걷고 하이픈은 그대로 둔다', () {
    final c = parsePickedContact({
      'name': '  홍길동 ',
      'phones': [' 010-1234-5678 '],
      'emails': [' gil@example.com '],
    });
    expect(c?.name, '홍길동');
    expect(c?.phones, ['010-1234-5678']);
    expect(c?.emails, ['gil@example.com']);
  });

  test('번호·이메일이 여러 개면 목록으로 남기고 빈 글·중복은 뺀다', () {
    final c = parsePickedContact({
      'name': '김반장',
      'phones': ['010-1111-2222', '', '010-1111-2222', '02-333-4444'],
      'emails': ['a@x.com', ' ', 'b@x.com'],
    });
    expect(c?.phones, ['010-1111-2222', '02-333-4444']);
    expect(c?.emails, ['a@x.com', 'b@x.com']);
  });

  test('이름만 있거나 번호만 있어도 가져온다', () {
    expect(parsePickedContact({'name': '홍길동'})?.phones, isEmpty);
    expect(parsePickedContact({'name': '홍길동'})?.emails, isEmpty);
    final c = parsePickedContact({
      'name': '',
      'phones': ['010-1111-2222'],
    });
    expect(c?.name, '');
    expect(c?.phones, ['010-1111-2222']);
  });

  test('아무것도 없으면(또는 취소) 가져오지 않는다', () {
    expect(parsePickedContact(null), isNull);
    expect(parsePickedContact({'name': ' ', 'phones': [], 'emails': []}), isNull);
  });

  test('cleanContactValues: 문자가 아닌 값도 글로 바꿔 다듬는다', () {
    expect(cleanContactValues([1, ' 2 ', '2', null]), ['1', '2']);
    expect(cleanContactValues(null), isEmpty);
  });
}
