// 앱 로고 마크(청록 바탕 + 흰 파이프 엘보). 런처 아이콘(android/app/.../ic_launcher.png)과
// 같은 그림을 화면 안에서도 쓸 수 있게 CustomPainter로 옮겨 둔 것 — 로딩 화면 등에서 쓴다.
// 아이콘 파일을 다시 만들 때(예: 색을 바꿀 때)는 여기 도형도 같이 맞출 것.
import 'package:flutter/material.dart';

import 'app_tokens.dart';

class _AppLogoPainter extends CustomPainter {
  final Color background;
  final Color foreground;
  const _AppLogoPainter({required this.background, required this.foreground});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, s, s),
      Radius.circular(s * 0.22),
    );
    canvas.drawRRect(rrect, Paint()..color = background);

    final stroke = s * 0.20;
    final bendR = stroke * 0.9;
    final left = s * 0.26;
    final top = s * 0.28;
    final right = s * 0.80;
    final bendY = s * 0.68;

    final path = Path()
      ..moveTo(left, top)
      ..lineTo(left, bendY - bendR)
      ..quadraticBezierTo(left, bendY, left + bendR, bendY)
      ..lineTo(right, bendY);
    canvas.drawPath(
      path,
      Paint()
        ..color = foreground
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _AppLogoPainter oldDelegate) =>
      oldDelegate.background != background ||
      oldDelegate.foreground != foreground;
}

/// 앱 로고 마크(정사각형). [size]는 한 변 길이(논리 픽셀).
class AppLogoMark extends StatelessWidget {
  final double size;
  final Color? background;
  final Color? foreground;
  const AppLogoMark({
    super.key,
    required this.size,
    this.background,
    this.foreground,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: _AppLogoPainter(
        background: background ?? AppColors.brand,
        foreground: foreground ?? Colors.white,
      ),
    ),
  );
}
