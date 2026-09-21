/// 입력 카드를 밀어서 지우기(튜브·전선관 입력 탭 공용).
///
/// 🚀 [바꿈] 예전에는 카드마다 X 단추가 있었다. 밀어서 지우고, 잘못 밀었을
/// 때를 위해 잠깐 "되돌리기"를 띄운다.
library;

import 'package:flutter/material.dart';

/// 카드를 왼쪽으로 밀 때 뒤에 보이는 빨간 바탕.
Widget swipeDeleteBackground({double radius = 12, double bottomMargin = 8}) {
  return Container(
    margin: EdgeInsets.only(bottom: bottomMargin),
    padding: const EdgeInsets.only(right: 24),
    alignment: Alignment.centerRight,
    decoration: BoxDecoration(
      color: Colors.redAccent,
      borderRadius: BorderRadius.circular(radius),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.delete_outline_rounded, color: Colors.white),
        SizedBox(width: 6),
        Text(
          '삭제',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}

/// 지운 뒤 아래에 "N번 줄을 지웠습니다 · 되돌리기"를 띄운다.
void showDeletedSnackBar(
  BuildContext context, {
  required int number,
  required VoidCallback onUndo,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text('$number번 줄을 지웠습니다.'),
      duration: const Duration(seconds: 4),
      action: SnackBarAction(label: '되돌리기', onPressed: onUndo),
    ),
  );
}

/// 목록에서 [from] 자리를 [to]로 옮겼을 때, [index]에 있던 줄이 가는 자리.
/// 고치고 있던 줄 번호를 따라가게 할 때 쓴다. [to]는 옮긴 뒤 자리(빼고 넣은 자리).
int movedIndex(int index, int from, int to) {
  if (index == from) return to;
  if (from < index && index <= to) return index - 1;
  if (to <= index && index < from) return index + 1;
  return index;
}

/// [removed] 줄을 지운 뒤, 고치고 있던 줄 번호를 맞춘다. 지운 줄을 고치고
/// 있었으면 null(고치기를 그만둔다).
int? indexAfterRemove(int? editing, int removed) {
  if (editing == null) return null;
  if (editing == removed) return null;
  return editing > removed ? editing - 1 : editing;
}
