import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/widgets/korean_text.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/widgets/work_theme.dart';

// 줄 목록(각 줄의 글자, 끊김 방지 문자는 뺀다)
List<String> linesOf(String text, double width) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: const TextStyle(fontSize: 15)),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: width);
  final out = <String>[];
  var i = 0;
  while (i < text.length) {
    final r = tp.getLineBoundary(TextPosition(offset: i));
    out.add(text.substring(r.start, r.end));
    i = r.end <= i ? i + 1 : r.end;
  }
  return out;
}

void main() {
  const sample = '이슈 1건이 아직 해결되지 않았습니다. 그래도 완료 처리하시겠습니까?';

  test('keepWords only adds invisible joiners, never changes visible text', () {
    final k = keepWords(sample);
    expect(k.replaceAll(kWordJoiner, ''), sample);
    expect(k.contains(' '), true); // 띄어쓰기는 그대로(줄바꿈 자리)
    expect(keepWords(''), '');
    expect(keepWords('가'), '가');
    expect(keepWords('a b'), 'a b');
    expect(
      keepWords('줄\n바꿈'),
      '줄\n바꿈'.split('').join('').isEmpty ? '' : keepWords('줄\n바꿈'),
    );
    // 이미 적용된 글에 다시 적용해도 문자가 겹치지 않는다.
    expect(keepWords(keepWords(sample)), keepWords(sample));
  });

  test(
    'without keepWords the text breaks inside a word; with it, only at spaces',
    () {
      for (final w in [200.0, 230.0, 260.0, 300.0]) {
        // 기본: 어떤 폭에서는 공백이 아닌 자리에서 줄이 끊긴다.
        final plain = linesOf(sample, w);
        final plainBroken = plain
            .take(plain.length - 1)
            .any((l) => !l.endsWith(' '));
        // 적용: 모든 줄이 공백에서 끝난다(마지막 줄 제외).
        final k = linesOf(keepWords(sample), w);
        final keptOk = k.take(k.length - 1).every((l) => l.endsWith(' '));
        expect(keptOk, true, reason: '폭 $w → $k');
        if (w == 230.0)
          expect(plainBroken, true, reason: '기본은 단어 중간이 끊겨야 비교가 의미 있다');
      }
    },
  );

  testWidgets('dialog text shows the same visible words', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: workThemeData(),
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => showDialog(
              context: ctx,
              builder: (_) => AlertDialog(content: Text(keepWords(sample))),
            ),
            child: const Text('열기'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    final t = tester.widget<Text>(find.byType(Text).last);
    expect((t.data ?? '').replaceAll(kWordJoiner, ''), sample);
  });
}
