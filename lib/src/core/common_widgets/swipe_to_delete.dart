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

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    // 줄이 좁아도 넘치지 않게 줄여서 그린다.
    child: const FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
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
    ),
  );
}

/// 왼쪽으로 밀어서 지우는 줄.
///
/// 앱을 깔고 처음 한 번은, 처음 그려진 줄이 살짝 밀렸다 돌아오며 빨간 "삭제"를 보여 주고
/// 안내 한 줄을 띄운다(상용 메일 앱의 첫 안내처럼). 본 뒤에는 다시 안 나온다.
class SwipeToDelete extends StatefulWidget {
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

  /// 첫 안내를 본 적이 있는지(폰 저장 열쇠).
  static const String hintSeenKey = 'swipe_delete_hint_seen_v1';

  /// 시험에서 첫 안내를 켤 때 true(평소 시험에서는 안 나온다).
  static bool debugForceHint = false;

  /// 이번 실행에서 이미 안내를 시도했으면 다른 줄은 안 한다.
  static bool _triedThisRun = false;

  /// 시험에서 다시 처음 상태로.
  @visibleForTesting
  static void debugResetHint() => _triedThisRun = false;

  @override
  State<SwipeToDelete> createState() => _SwipeToDeleteState();
}

class _SwipeToDeleteState extends State<SwipeToDelete> with SingleTickerProviderStateMixin {
  AnimationController? _peek;

  static bool get _inTest => Platform.environment.containsKey('FLUTTER_TEST');

  @override
  void initState() {
    super.initState();
    if (widget.enabled && !SwipeToDelete._triedThisRun && (!_inTest || SwipeToDelete.debugForceHint)) {
      SwipeToDelete._triedThisRun = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeHint());
    }
  }

  Future<void> _maybeHint() async {
    final p = await SharedPreferences.getInstance();
    if (p.getBool(SwipeToDelete.hintSeenKey) == true || !mounted) return;
    await p.setBool(SwipeToDelete.hintSeenKey, true);
    final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    setState(() => _peek = c);
    if (mounted) {
      showAppSnack(context, '줄을 왼쪽으로 밀면 지웁니다. 잘못 지웠으면 바로 뜨는 되돌리기를 누르십시오.');
    }
    try {
      await c.forward().orCancel;
    } catch (_) {}
    if (!mounted) return;
    setState(() => _peek = null);
    c.dispose();
  }

  @override
  void dispose() {
    _peek?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _peek;
    Widget child = widget.child;
    if (c != null) {
      // 0 → 왼쪽으로 72 → 0 (가운데에서 잠깐 멈춤)
      child = Stack(
        // 줄 크기는 원래 줄 그대로(안내 중에 줄이 줄어들지 않게).
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(child: swipeDeleteBackground(radius: widget.radius, bottomMargin: widget.bottomMargin)),
          AnimatedBuilder(
            animation: c,
            builder: (_, kid) {
              final t = c.value;
              final k = t < 0.35 ? Curves.easeOut.transform(t / 0.35) : (t < 0.65 ? 1.0 : 1 - Curves.easeIn.transform((t - 0.65) / 0.35));
              return Transform.translate(offset: Offset(-72 * k, 0), child: kid);
            },
            child: widget.child,
          ),
        ],
      );
    }
    return Dismissible(
      key: widget.itemKey,
      direction: widget.enabled ? DismissDirection.endToStart : DismissDirection.none,
      // 실수로 살짝 밀린 것은 지우지 않게 절반 넘게 밀어야 한다.
      dismissThresholds: const {DismissDirection.endToStart: 0.5},
      background: swipeDeleteBackground(radius: widget.radius, bottomMargin: widget.bottomMargin),
      confirmDismiss: widget.confirm == null ? null : (_) => widget.confirm!(),
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        widget.onDelete();
      },
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
