// 현장 계산기 네 개(단위 환산·전기·압력 시험·4-20mA)의 화면 글에 지은 말·AI투가 다시 들어오지 않게 막는다.
// 기준: docs/계산기_용어_기준.md. 주석 줄은 보지 않고, 따옴표가 든 줄(화면 글)만 본다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _dirs = [
  'lib/src/presentation/unit_converter',
  'lib/src/presentation/electrical',
  'lib/src/presentation/pressure_test',
  'lib/src/presentation/instrument',
  'lib/src/presentation/flow',
];

/// 쓰지 않을 말 → 쓸 말.
const _banned = <String, String>{
  '셉니다': '계산합니다',
  '셈합니다': '계산합니다',
  '셈하면': '계산하면',
  '셀 때': '계산할 때',
  '셀 수 있': '계산할 수 있',
  '넣은 값': '입력값',
  '읽은 값': '측정값·지시값',
  '읽은 mA': '측정값(mA)',
  '가장 큰 오차': '최대 오차',
  '바뀐 몫': '영향',
  '어림하': '대략',
  '바깥지름': '외경',
  '안지름': '내경',
  '허용 오차': '허용오차',
  '기준기': '표준기',
  '반 안 ': '반 내부',
  '땅속': '지중',
  '무구멍': '바닥밀폐형',
};

/// 4-20mA 계산기에만 막는 말(전기 계산기에서는 '흐르는 전류'가 자연스럽다).
const _bannedInstrument = <String, String>{
  '흐르는 전류': '환산 mA·출력 전류',
  '흐르는 mA': '환산 mA',
};

void main() {
  test('계산기 화면 글에 지은 말·줄표가 없다', () {
    final problems = <String>[];
    for (final d in _dirs) {
      for (final f in Directory(d).listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final t = lines[i].trimLeft();
          if (t.startsWith('//')) continue;
          if (!t.contains("'") && !t.contains('"')) continue;
          // 줄 끝 주석은 떼고 본다(따옴표 밖의 //만). 간단히: " // " 뒤를 자른다.
          final code = t.split(' // ').first;
          final bans = {
            ..._banned,
            if (d.endsWith('instrument')) ..._bannedInstrument,
          };
          for (final e in bans.entries) {
            if (code.contains(e.key)) {
              problems.add('${f.path}:${i + 1} "${e.key}" → "${e.value}"');
            }
          }
          if (code.contains(' — ')) {
            problems.add('${f.path}:${i + 1} 줄표(" — ") → ": " 또는 마침표');
          }
        }
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}
