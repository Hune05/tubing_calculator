// 키보드 "다음"이 글자 칸끼리만 옮겨 가게 하는 순서 규칙(앱 전체).
// 기본 순서는 "?" 도움말·칩·스위치도 거쳐서, "다음"을 누르면 도움말 창이 열리거나 키보드가 닫혔다.
import 'package:flutter/widgets.dart';

class TextFieldsOnlyTraversalPolicy extends ReadingOrderTraversalPolicy {
  TextFieldsOnlyTraversalPolicy();

  static bool _isText(FocusNode n) =>
      n.context?.findAncestorStateOfType<EditableTextState>() != null;

  /// 지금 글자 칸에 있을 때만 글자 칸끼리 옮긴다. 단추 등에서 Tab으로 옮길 때는 원래 순서 그대로다.
  @override
  Iterable<FocusNode> sortDescendants(
    Iterable<FocusNode> descendants,
    FocusNode currentNode,
  ) {
    if (!_isText(currentNode)) {
      return super.sortDescendants(descendants, currentNode);
    }
    final texts = descendants.where(_isText).toList();
    if (texts.isEmpty) return super.sortDescendants(descendants, currentNode);
    return super.sortDescendants(texts, currentNode);
  }
}
