// 숫자 칸에 들어가면 들어 있던 값 전체를 골라 둔다(앱 전체, 10-13).
// 새로 치면 바로 바뀌고, 이미 들어가 있는 칸을 한 번 더 누르면 그 자리에 커서가 놓인다.
// 10-11 사용자: "수치 변경할 때 왜 기준 수치가 안 날아가고 이어 쓰기 되냐" — 철판 가공 칸(PlateNumField)에
// 먼저 넣었던 것을 폰 자판 숫자 칸 모두로 넓혔다. 튜브·전선관 마끼다 숫자판은 원래 첫 누름에 덮어쓴다.
import 'package:flutter/widgets.dart';

class NumberFieldSelectAll extends StatefulWidget {
  const NumberFieldSelectAll({super.key, required this.child});

  final Widget child;

  @override
  State<NumberFieldSelectAll> createState() => _NumberFieldSelectAllState();
}

class _NumberFieldSelectAllState extends State<NumberFieldSelectAll> {
  FocusNode? _last;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocus);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    final node = FocusManager.instance.primaryFocus;
    // 같은 칸에 머무는 동안에는 다시 고르지 않는다(치는 중에 글이 통째로 골라지면 안 된다).
    if (identical(node, _last)) return;
    _last = node;
    final field = numberFieldOf(node);
    if (node == null || field == null) return;
    // 누른 자리에 커서를 놓는 일이 끝난 뒤에 고른다(바로 고르면 누름이 다시 커서로 바꾼다).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!field.mounted || !node.hasFocus) return;
      final c = field.widget.controller;
      if (c.text.isEmpty) return;
      c.selection = TextSelection(baseOffset: 0, extentOffset: c.text.length);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// [node]가 고칠 수 있는 숫자 자판 칸이면 그 칸. 글 칸·읽기 전용 칸(숫자판·계산기 식 칸)은 null.
EditableTextState? numberFieldOf(FocusNode? node) {
  final field = node?.context?.findAncestorStateOfType<EditableTextState>();
  if (field == null) return null;
  final w = field.widget;
  if (w.readOnly) return null;
  if (w.keyboardType.index != TextInputType.number.index) return null;
  return field;
}
