import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// 팝업 글에는 보이지 않는 "끊김 방지 문자"(U+2060)가 들어 있어 find.text가 그대로는 못 찾는다.
// 이 문자를 뺀 글자가 같은 Text 위젯을 찾는다.
Finder findText(String text) => find.byWidgetPredicate(
  (w) =>
      w is Text &&
      (w.data ?? w.textSpan?.toPlainText() ?? '').replaceAll('⁠', '') == text,
);

Finder findTextContaining(String text) => find.byWidgetPredicate(
  (w) =>
      w is Text &&
      (w.data ?? w.textSpan?.toPlainText() ?? '')
          .replaceAll('⁠', '')
          .contains(text),
);
