// 메뉴 카드처럼 눌러서 들어가는 줄에 붙이는 눌림 반응: 누르는 동안 살짝 작아졌다가
// 떼면 돌아온다(전환이 시작되기 전에 손끝에 바로 반응이 오게).
import 'package:flutter/material.dart';

class PressFeedback extends StatefulWidget {
  final Widget child;
  const PressFeedback({super.key, required this.child});

  @override
  State<PressFeedback> createState() => _PressFeedbackState();
}

class _PressFeedbackState extends State<PressFeedback> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
