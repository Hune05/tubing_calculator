/// 입력 카드를 밀어서 지우기(튜브·전선관 입력 탭 공용).
///
/// 🚀 [바꿈] 예전에는 카드마다 X 단추가 있었다. 밀어서 지우고, 잘못 밀었을
/// 때를 위해 잠깐 "되돌리기"를 띄운다.
library;

import 'package:flutter/material.dart';

// 빨간 바탕은 앱 공통 밀어서 지우기와 같은 것을 쓴다.
export '../../../core/common_widgets/swipe_to_delete.dart' show swipeDeleteBackground;

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

/// 세로 배치에서 입력판이 차지할 수 있는 가장 큰 높이(화면의 60%). 넘치면 입력판 안에서 스크롤한다.
/// 가로 배치에서는 입력판이 오른쪽에 전체 높이로 서므로 쓰지 않는다([bendInputLandscape]).
double inputPanelMaxHeight(BuildContext context) =>
    MediaQuery.sizeOf(context).height * 0.6;

/// 튜브·전선관 입력 탭을 가로 배치(왼쪽 목록, 오른쪽 입력판)로 그리는지(10-09). 탭이 받은 자리로
/// 정한다(화면 나누기에서도 맞게). 예전에는 가로에서도 입력판을 아래에 두고 높이 30%만 줘서
/// 숫자·방향 칸이 잘렸다.
bool bendInputLandscape(BoxConstraints box) => box.maxWidth > box.maxHeight;

/// 아래 탭 막대를 얇게 쓸지(10-09): 폰을 가로로 눕혀 화면 높이가 낮으면 위아래 여백을 뺀다.
bool calcNavCompact(BuildContext context) =>
    MediaQuery.sizeOf(context).height < 500;

/// 가로 배치에서 오른쪽 입력판 폭.
double bendInputPanelWidth(BoxConstraints box) =>
    (box.maxWidth * 0.48).clamp(300.0, 560.0);

/// 입력판 모서리: 세로는 위쪽, 가로는 왼쪽을 둥글게.
BorderRadius bendInputPanelRadius(bool landscape) => landscape
    ? const BorderRadius.horizontal(left: Radius.circular(24))
    : const BorderRadius.vertical(top: Radius.circular(24));
