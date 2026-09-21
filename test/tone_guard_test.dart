import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// 앱 화면들의 안내·팝업 문구는 "~습니다/~십시오" 체로 통일했다.
// 나중에 "~요"로 끝나는 문구가 다시 들어오면 이 검사가 알려 준다.

// 문장 끝의 "요"가 아닌 단어(필요, 중요, 요약 …)는 검사에서 뺀다.
final RegExp _okWords = RegExp('(필요|중요|주요|개요|요약|요청|요일|요소|수요|소요|요구)');

// 큰따옴표·작은따옴표·역슬래시(\n 앞) 직전에서 끝나는 "...요" 문장.
final RegExp _endsWithYo = RegExp('[가-힣]요[.!?)~ ]*(?=["\'\\\\])');

List<String> findYoEndings(String line) {
  final out = <String>[];
  for (final m in _endsWithYo.allMatches(line)) {
    final start = m.start >= 3 ? m.start - 2 : 0;
    final around = line.substring(start, m.end);
    if (_okWords.hasMatch(around)) continue;
    out.add(m.group(0)!);
  }
  return out;
}

void main() {
  test('the guard catches a 요 ending and ignores allowed words', () {
    expect(findYoEndings('"저장했어요."'), isNotEmpty);
    expect(findYoEndings("'확인해 보세요'"), isNotEmpty);
    expect(findYoEndings('"첫 줄이에요.\\n다음"'), isNotEmpty);
    expect(findYoEndings('"저장했습니다."'), isEmpty);
    expect(findYoEndings('"확인하십시오"'), isEmpty);
    expect(findYoEndings('"필요"'), isEmpty);
    expect(findYoEndings('"중요"'), isEmpty);
    expect(findYoEndings('"요약"'), isEmpty);
  });

  test('no user-facing string in the app ends with 요', () {
    final root = Directory('lib');
    final bad = <String>[];
    for (final f in root.listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].trimLeft().startsWith('//')) continue; // 주석은 검사하지 않는다
        if (findYoEndings(lines[i]).isNotEmpty) {
          final name = f.path.split(RegExp(r'[\\/]')).last;
          bad.add('$name:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  test('속어·반말투·과장 문구가 화면 글에 없다', () {
    // 2026-09-22 점검에서 고친 말들. 다시 들어오면 알려 준다.
    const banned = ['고인물', '커야함', '강제로 추가', '완벽한 원형', '쾌속으로', '제외됨', '작업 완료!'];
    final bad = <String>[];
    for (final f in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].trimLeft().startsWith('//')) continue;
        for (final w in banned) {
          if (lines[i].contains(w)) {
            final name = f.path.split(RegExp(r'[\\/]')).last;
            bad.add('$name:${i + 1}: $w');
          }
        }
      }
    }
    expect(bad, isEmpty, reason: bad.join('\n'));
  });
}
