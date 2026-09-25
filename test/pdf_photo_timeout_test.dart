// 통신이 없을 때 사진 넣은 PDF가 오래 멈추던 것(점검 20번).
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/report_pdf.dart';

void main() {
  tearDown(resetRemotePhotoState);

  testWidgets('서버가 답을 안 하면 한 장 10초에서 끊고, 나머지 서버 사진은 바로 건너뛴다', (tester) async {
    var asked = 0;
    remotePhotoFetcher = (_) {
      asked++;
      return Completer<Uint8List?>().future; // 통신 없음: 영영 안 끝남
    };
    final results = <Uint8List?>[];
    var done = 0;
    for (final u in [
      'https://firebasestorage.googleapis.com/a.jpg',
      'https://firebasestorage.googleapis.com/b.jpg',
      'https://firebasestorage.googleapis.com/c.jpg',
    ]) {
      // PDF처럼 한 장씩 차례로 기다린다.
      results.add(await _within(tester, loadPhotoBytes(u)));
      done++;
    }
    expect(done, 3);
    expect(results, [null, null, null]);
    // 예전: 사진마다 제한 없이 기다려(48장이면 48번) 멈췄다.
    expect(asked, 1);
  });
}

/// 가짜 시계를 11초까지 돌리며 기다린다.
Future<T> _within<T>(WidgetTester tester, Future<T> f) async {
  T? out;
  var finished = false;
  f.then((v) {
    out = v;
    finished = true;
  });
  for (var i = 0; i < 11 && !finished; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
  expect(finished, isTrue, reason: '11초 안에 끝나야 한다');
  return out as T;
}
