// 익명 로그인을 동시에 여러 번 불러도 계정은 하나만 만든다(8차, 10-09).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/profile/profile_tools.dart';

void main() {
  tearDown(() => debugAnonSignIn = null);

  test('동시에 부르면 진행 중인 로그인 하나를 같이 기다린다', () async {
    var calls = 0;
    final done = Completer<String?>();
    debugAnonSignIn = () {
      calls++;
      return done.future;
    };
    final a = ensureSignedIn();
    final b = ensureSignedIn();
    done.complete('uid-1');
    expect(await a, 'uid-1');
    expect(await b, 'uid-1');
    expect(calls, 1);
  });

  testWidgets('시간 제한으로 먼저 돌아와도, 그 로그인이 끝나기 전에는 새로 만들지 않는다', (tester) async {
    var calls = 0;
    final slow = Completer<String?>();
    debugAnonSignIn = () {
      calls++;
      return slow.future;
    };
    String? first = 'x';
    ensureSignedIn().then((v) => first = v);
    await tester.pump(const Duration(seconds: 5));
    expect(first, isNull); // 4초 넘어 넘어감
    ensureSignedIn();
    expect(calls, 1);
    slow.complete('uid-2');
    await tester.pump();
    // 끝난 뒤에는(여기서는 로그인 상태를 못 읽으니) 다시 시도할 수 있다.
    ensureSignedIn();
    expect(calls, 2);
    await tester.pump(const Duration(seconds: 5));
  });
}
