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
    for (final f in dir.listSync().whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
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
