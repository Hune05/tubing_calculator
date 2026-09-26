// 현장 자료 화면 글에 만들 때 대화하던 말투("말씀하신", "캡처해서 올려주시면 채워
// 넣겠습니다" 등)가 섞여 앱에 그대로 보였다(2026-09-26 폰 확인). 다시 들어오지 않게 막는다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('현장 자료 화면 글에 만드는 사람에게 하는 말이 없다', () {
    const banned = [
      '말씀하신',
      '주시면',
      '채워 넣겠',
      '만들겠습니다',
      '드리겠습니다',
      '넣지 않았습니다',
      '확인한 게 아닙니다',
      '확인한 것은 아닙니다',
    ];
    final dir = Directory('lib/src/presentation/reference/page');
    final found = <String>[];
    // KEC 요약 글은 JSON에 있다(서버에도 같은 파일이 올라간다).
    final files = [
      ...dir.listSync().whereType<File>().where((f) => f.path.endsWith('.dart')),
      File('assets/reference/kec_content.json'),
    ];
    for (final f in files) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue; // 코드 설명은 빼고 화면 글만
        for (final w in banned) {
          if (line.contains(w)) found.add('${f.path}:${i + 1} "$w"');
        }
      }
    }
    expect(found, isEmpty);
  });
}
