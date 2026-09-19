// 한글은 Flutter에서 글자 단위로 줄이 바뀌어 "처/리하시겠습니까?"처럼 단어 중간이 끊긴다.
// 단어(띄어쓰기로 나뉜 덩어리) 안의 글자 사이에 "끊지 않는 문자"(U+2060)를 넣어, 줄바꿈이
// 띄어쓰기 자리에서만 일어나게 한다. 화면에는 보이지 않는 문자다.
const String kWordJoiner = '⁠';

String keepWords(String text) {
  if (text.isEmpty) return text;
  final b = StringBuffer();
  final runes = text.runes.toList();
  for (var i = 0; i < runes.length; i++) {
    final c = String.fromCharCode(runes[i]);
    b.write(c);
    if (i + 1 >= runes.length) break;
    final next = String.fromCharCode(runes[i + 1]);
    final isSpace =
        c.trim().isEmpty || next.trim().isEmpty; // 공백·줄바꿈 자리는 그대로 둔다
    if (!isSpace && c != kWordJoiner && next != kWordJoiner)
      b.write(kWordJoiner);
  }
  return b.toString();
}
