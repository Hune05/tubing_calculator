// 알림(SnackBar)을 줄 세우지 않고 띄운다(10-09).
// Flutter는 알림을 띄울 때마다 앞 알림 뒤에 줄을 세운다. 그래서 같은 단추를 다섯 번 누르면 4초짜리
// 알림이 다섯 번 차례로 떠 20초 동안 화면 아래를 가렸다(벤딩 "못 꺾는 방향"이 대표적이다).
// - 같은 알림이 떠 있으면 다시 띄우지 않는다.
// - 다른 알림이면 앞 알림을 바로 바꾼다(줄 세우지 않는다).
// - 단, 되돌리기처럼 단추가 달린 알림이 떠 있으면 그 알림은 지우지 않고 뒤에 세운다(되돌릴 틈을 뺏지 않게).
import 'package:flutter/material.dart';

class _Shown {
  final String? key;
  final bool hasAction;
  final DateTime at;
  final Duration duration;
  final ScaffoldFeatureController<SnackBar, SnackBarClosedReason> controller;
  _Shown(this.key, this.hasAction, this.at, this.duration, this.controller);
}

final Expando<_Shown> _shown = Expando<_Shown>('snackOnce');

/// 지금 떠 있는 단추 달린 알림(되돌리기 등). 닫히면 비운다.
final Expando<Object> _actionOpen = Expando<Object>('snackOnceAction');

/// 알림 글(같은 알림인지 견줄 때). [SnackBar.content]가 글 하나면 그 글, 아니면 null(견주지 않음).
String? _keyOf(SnackBar bar) {
  final c = bar.content;
  if (c is Text) return c.data ?? c.textSpan?.toPlainText();
  return null;
}

/// [messenger]에 [bar]를 띄운다. 같은 알림이 이미 떠 있으면 그 알림을 돌려준다.
/// [key]를 주면 그것으로 같은 알림인지 본다(글 하나가 아닌 알림용). [messenger]가 null이면 null.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showSnackOnce(
  ScaffoldMessengerState? messenger,
  SnackBar bar, {
  String? key,
}) {
  if (messenger == null) return null;
  final k = key ?? _keyOf(bar);
  final hasAction = bar.action != null;
  final now = DateTime.now();
  final shown = _shown[messenger];
  // 다른 곳에서 알림을 지웠으면 닫힘 소식이 안 올 수 있어, 떠 있을 시간이 지났으면 없는 것으로 본다.
  final live =
      shown != null &&
      now.difference(shown.at) <
          shown.duration + const Duration(milliseconds: 800);
  if (live && k != null && shown.key == k && !hasAction) {
    return shown.controller;
  }
  // 단추 달린 알림이 떠 있으면 지우지 않고 뒤에 세운다. 새 알림에 단추가 있으면 앞 것을 바꾼다.
  if (hasAction || _actionOpen[messenger] == null) messenger.clearSnackBars();
  final controller = messenger.showSnackBar(bar);
  final mine = _Shown(k, hasAction, now, bar.duration, controller);
  _shown[messenger] = mine;
  controller.closed.then((_) {
    if (identical(_shown[messenger], mine)) _shown[messenger] = null;
  });
  if (hasAction) {
    _actionOpen[messenger] = controller;
    controller.closed.then((_) {
      if (identical(_actionOpen[messenger], controller)) {
        _actionOpen[messenger] = null;
      }
    });
  }
  return controller;
}
