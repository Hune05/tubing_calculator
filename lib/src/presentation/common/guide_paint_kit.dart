// 특수 벤딩 툴 그림 설명(롤링 오프셋·루프 전압과 같은 스타일)에서 공통으로 쓰는
// CustomPainter 조각들. 새 그림 설명을 만들 때 이 파일의 함수를 그대로 쓴다
// (롤링 오프셋·루프 전압 자체는 먼저 만들어져 있던 것이라 안 건드리고 그대로 둔다).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';

/// 애니메이션 전체 진행([0,1])에서 [a]~[b] 구간만 0→1로 늘려(ease-out) 쓴다.
/// 예: stageT(t, 0.2, 0.5)는 t가 0.2 전에는 0, 0.5 이후에는 1.
double stageT(double t, double a, double b) =>
    Curves.easeOutCubic.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

/// 그림 위에 뜨는 작은 값표(예: "Rise 100mm"). 흰 알약 배경 + 테두리.
void paintPill(
  Canvas canvas,
  String s,
  Offset center, {
  required Color color,
  double size = 10.5,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(
        color: color,
        fontSize: size,
        fontWeight: FontWeight.w800,
        fontFamily: kAppFontFamily,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final rect = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: center,
      width: tp.width + 12,
      height: tp.height + 6,
    ),
    const Radius.circular(8),
  );
  canvas.drawRRect(
    rect,
    Paint()
      ..color = AppColors.surface.withValues(alpha: 0.96)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6),
  );
  canvas.drawRRect(
    rect,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withValues(alpha: 0.35),
  );
  tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
}

/// Material 아이콘 하나를 그림 위에 직접 그린다(작은 배지·표시용).
void paintGuideIcon(
  Canvas canvas,
  IconData icon,
  Offset center,
  double size,
  Color color,
) {
  final tp = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: size,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: color,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
}

/// 굵고 입체감 있는 "관" 한 구간(그림자 + 몸통 + 밝은 하이라이트 줄).
/// [s]는 0~1(0이면 안 그림, 1이면 a→b 전부).
void paintPipeSegment(
  Canvas canvas,
  Offset a,
  Offset b,
  double s,
  Color base, {
  double width = 6.5,
}) {
  if (s <= 0) return;
  final tip = Offset.lerp(a, b, s)!;
  final shadow = Paint()
    ..color = Colors.black.withValues(alpha: 0.12)
    ..strokeWidth = width + 0.5
    ..strokeCap = StrokeCap.round
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4);
  canvas.drawLine(a + const Offset(0, 1.4), tip + const Offset(0, 1.4), shadow);
  canvas.drawLine(
    a,
    tip,
    Paint()
      ..color = base
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round,
  );
  canvas.drawLine(
    a,
    tip,
    Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = width * 0.24
      ..strokeCap = StrokeCap.round,
  );
}

/// 장애물(둥근 상자 + 그림자 + 대각 줄무늬 + 느낌표). [grow]는 0~1(위로 자라는 느낌).
void paintObstacle(
  Canvas canvas,
  Offset center,
  double grow, {
  double width = 26,
  double height = 26,
}) {
  if (grow <= 0) return;
  final rect = Rect.fromCenter(
    center: center,
    width: width,
    height: height * grow,
  );
  final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
  canvas.drawRRect(
    rrect.shift(const Offset(0, 1.6)),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
  );
  canvas.drawRRect(
    rrect,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.caution.withValues(alpha: 0.85),
          AppColors.caution.withValues(alpha: 0.55),
        ],
      ).createShader(rect),
  );
  canvas.save();
  canvas.clipRRect(rrect);
  final stripe = Paint()
    ..color = Colors.white.withValues(alpha: 0.35)
    ..strokeWidth = 3;
  for (double x = rect.left - height; x < rect.right + height; x += 7) {
    canvas.drawLine(
      Offset(x, rect.bottom),
      Offset(x + height, rect.top),
      stripe,
    );
  }
  canvas.restore();
  if (grow > 0.7) {
    paintGuideIcon(
      canvas,
      Icons.warning_amber_rounded,
      rect.center,
      12,
      Colors.white,
    );
  }
}

/// 아주 옅은 도면 느낌 점 격자(배경).
void paintDotGrid(Canvas canvas, Size size) {
  final dotPaint = Paint()..color = AppColors.textSub.withValues(alpha: 0.08);
  for (double gx = 6; gx < size.width; gx += 14) {
    for (double gy = 6; gy < size.height; gy += 14) {
      canvas.drawCircle(Offset(gx, gy), 0.7, dotPaint);
    }
  }
}

/// 그림 설명 공통 바깥 틀(옅은 그라데이션 카드 + 테두리 + 그림자) + "다시 보기" 단추.
class GuideFrame extends StatelessWidget {
  final Widget Function(BuildContext, Animation<double>) painterBuilder;
  final Animation<double> animation;
  final VoidCallback onReplay;
  final double height;
  final Key? replayKey;

  const GuideFrame({
    super.key,
    required this.painterBuilder,
    required this.animation,
    required this.onReplay,
    this.height = 172,
    this.replayKey,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    width: double.infinity,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.background, AppColors.surface],
      ),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.grey.shade200),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, _) => painterBuilder(context, animation),
            ),
          ),
        ),
        Positioned(
          right: 2,
          top: 2,
          child: IconButton(
            key: replayKey,
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            tooltip: '다시 보기',
            icon: Icon(Icons.replay, color: AppColors.brand),
            onPressed: onReplay,
          ),
        ),
      ],
    ),
  );
}

/// 회전각·롤 등에 쓰는 주황(현장 보기 테마 없이도 쓸 수 있게 고정값).
const Color kGuideOrange = Color(0xFFEA580C);

double degToRad(double d) => d * math.pi / 180;

/// 양끝에 화살촉이 달린 치수선. [s]는 0~1(그려지는 정도), 화살촉은 다 그려진 뒤에 나온다.
void paintDimLine(
  Canvas canvas,
  Offset a,
  Offset b,
  double s,
  Color color, {
  double width = 1.8,
}) {
  if (s <= 0) return;
  final tip = Offset.lerp(a, b, s)!;
  canvas.drawLine(
    a,
    tip,
    Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round,
  );
  final d = b - a;
  final len = d.distance;
  if (s < 0.96 || len < 16) return;
  final dir = d / len;
  final n = Offset(-dir.dy, dir.dx);
  void head(Offset p, Offset toward) {
    final path = Path()
      ..moveTo(p.dx, p.dy)
      ..lineTo(p.dx - toward.dx * 7 + n.dx * 3.2, p.dy - toward.dy * 7 + n.dy * 3.2)
      ..lineTo(p.dx - toward.dx * 7 - n.dx * 3.2, p.dy - toward.dy * 7 - n.dy * 3.2)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  head(b, dir);
  head(a, -dir);
}
