// 통신이 없을 때도 멈추지 않는 쓰기 기다림(10-08 공용 함수).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/core/utils/quick_firestore.dart';

void main() {
  test('서버 답이 끝내 안 와도 정해진 시간 뒤 넘어간다', () async {
    final sw = Stopwatch()..start();
    await writeQuick(Completer<void>().future, wait: const Duration(milliseconds: 100));
    expect(sw.elapsedMilliseconds, lessThan(2000));
  });

  test('서버가 거절한 오류는 그대로 알린다', () async {
    await expectLater(writeQuick(Future<void>.error(StateError('권한 없음'))), throwsStateError);
  });
}
