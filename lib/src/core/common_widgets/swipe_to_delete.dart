/// 앱 공통 "밀어서 지우기"(10-02).
///
/// 목록 줄마다 휴지통·X 단추를 두면 잘못 눌러 바로 지워진다. 그래서 줄을 왼쪽으로
/// 끝까지 밀어야 지우고, 지운 뒤에는 "되돌리기"를 띄운다.
/// - 다시 넣기 쉬운 것(폰에 저장된 줄·기록): [SwipeToDelete] + [showDeleteUndo].
/// - 다시 넣기 어려운 것(하위 기록이 딸린 프로젝트, 파일): [SwipeToDelete.confirm]으로
///   끝까지 밀었을 때 이름이 적힌 확인창을 먼저 띄운다.
///
/// 주의: [Dismissible]은 밀린 줄이 화면에서 바로 빠져야 한다. [SwipeToDelete.onDelete]
/// 안에서 화면이 쓰는 목록에서 그 줄을 곧바로(setState) 빼야 한다. 서버 스트림이
/// 늦게 따라오면 "dismissed Dismissible is still part of the tree" 오류가 난다.
library;

import 'package:flutter/material.dart';

import 'app_components.dart';

/// 줄을 왼쪽으로 밀 때 뒤에 보이는 빨간 바탕.
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

/// 왼쪽으로 밀어서 지우는 줄.
class SwipeToDelete extends StatelessWidget {
  /// 줄마다 다른 열쇠(보통 `ValueKey(id)`).
  final Key itemKey;
  final Widget child;

  /// 지울 때 할 일. 화면 목록에서 그 줄을 곧바로 빼야 한다.
  final VoidCallback onDelete;

  /// 주면 끝까지 밀었을 때 먼저 묻는다. false면 줄이 제자리로 돌아온다.
  final Future<bool> Function()? confirm;

  /// 빨간 바탕 모서리·아래 간격(줄 모양에 맞춘다).
  final double radius;
  final double bottomMargin;

  /// false면 밀리지 않는다(예: 폐기한 장비, 마지막 남은 한 줄).
  final bool enabled;

  const SwipeToDelete({
    super.key,
    required this.itemKey,
    required this.child,
    required this.onDelete,
    this.confirm,
    this.radius = 12,
    this.bottomMargin = 8,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: itemKey,
      direction: enabled ? DismissDirection.endToStart : DismissDirection.none,
      // 실수로 살짝 밀린 것은 지우지 않게 절반 넘게 밀어야 한다.
      dismissThresholds: const {DismissDirection.endToStart: 0.5},
      background: swipeDeleteBackground(radius: radius, bottomMargin: bottomMargin),
      confirmDismiss: confirm == null ? null : (_) => confirm!(),
      onDismissed: (_) => onDelete(),
      child: child,
    );
  }
}

/// 지운 뒤 아래에 "삭제했습니다: 이름 · 되돌리기"를 띄운다(6초).
void showDeleteUndo(BuildContext context, String name, {required VoidCallback onUndo}) {
  if (ScaffoldMessenger.maybeOf(context) == null) return;
  final n = name.trim();
  showAppSnack(
    context,
    n.isEmpty ? '삭제했습니다' : '삭제했습니다: $n',
    kind: AppSnackKind.undo,
    onUndo: onUndo,
  );
}
