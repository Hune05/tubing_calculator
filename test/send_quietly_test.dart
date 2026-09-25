// 통신이 없을 때 끝나지 않던 저장(점검 19번): 서버 쓰기는 기다리지 않고 보낸다.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/utils/send_quietly.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/address_book.dart';

void main() {
  test('서버가 답을 안 해도(통신 없음) 바로 돌아온다', () {
    var called = false;
    sendQuietly(() {
      called = true;
      return Completer<void>().future; // 영영 안 끝나는 쓰기
    });
    expect(called, isTrue); // 보내기는 했다
  });

  test('실패해도 밖으로 오류를 던지지 않는다', () async {
    sendQuietly(() => Future<void>.error(StateError('서버 없음')));
    sendQuietly(() => throw StateError('부르자마자 실패'));
    await Future<void>.delayed(Duration.zero);
  });

  test('주소록 지우기는 폰 목록을 바로 바꾼다', () async {
    SharedPreferences.setMockInitialValues({});
    await saveAddress({'name': '김반장', 'phone': '010', 'role': '반장'});
    await removeAddress({'name': '김반장', 'phone': '010', 'role': '반장'});
    final list = await loadAddressBook();
    expect(list.where((e) => e['name'] == '김반장'), isEmpty);
  });
}
