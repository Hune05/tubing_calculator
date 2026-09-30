// 실물 모양 다이얼 게이지 그림: 무늬 낸 베젤, 흰 눈금판(100칸, 한 칸 0.01 mm), 큰 바늘, 바퀴 수 작은 바늘,
// 스템·스핀들·접촉점. 측정 그림 위에 올리는 작은 다이얼과 "다이얼 보는 법" 안내의 큰 다이얼이 같은 그림을 쓴다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

const Color _edge = Color(0xFF232A31);

void _t(Canvas c, String s, Offset at, double size, Color color, {FontWeight w = FontWeight.w800}) {
  final tp = TextPainter(
    text: TextSpan(text: s, style: TextStyle(fontSize: size, color: color, fontWeight: w, height: 1.1)),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(c, at - Offset(tp.width / 2, tp.height / 2));
}

/// 다이얼 게이지 하나를 [center]에 반지름 [r]로 그린다.
/// [value]는 읽음(mm, 시계 방향 = + = 눌림). [stemTo]가 있으면 스핀들을 그 점까지 뻗어 접촉점을 그린다.
/// [tag]는 테두리 색 띠(다이얼 A·B 구분), [bezelArrow]는 베젤을 돌리는 화살표.
void paintDialGauge(
  Canvas canvas,
  Offset center,
  double r, {
  double value = 0,
  Offset? stemTo,
  Color? tag,
  bool bezelArrow = false,
  bool numbers = true,
}) {
  // ── 스템과 스핀들(눈금판 아래로)
  final to = stemTo ?? center + Offset(0, r * 1.9);
  final dir = to - center;
  final ang = math.atan2(dir.dy, dir.dx);
  final len = dir.distance;
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.rotate(ang - math.pi / 2); // 아래(+y)가 스템 방향이 되게
  final stemW = r * 0.30, spW = r * 0.12;
  final stemL = math.min(len * 0.55, r * 1.45);
  final stem = Rect.fromLTRB(-stemW / 2, r * 0.7, stemW / 2, stemL);
  canvas.drawRect(stem.shift(const Offset(1.2, 1.5)), Paint()..color = Colors.black.withValues(alpha: 0.18));
  canvas.drawRect(
    stem,
    Paint()
      ..shader = const LinearGradient(colors: [Color(0xFF7D8791), Color(0xFFF1F3F5), Color(0xFFA9B1BA), Color(0xFF6D7680)], stops: [0, 0.35, 0.7, 1]).createShader(stem),
  );
  canvas.drawRect(stem, Paint()..style = PaintingStyle.stroke..strokeWidth = 0.9..color = _edge.withValues(alpha: 0.7));
  final sp = Rect.fromLTRB(-spW / 2, stemL, spW / 2, math.max(stemL + 2, len - r * 0.1));
  canvas.drawRect(
    sp,
    Paint()
      ..shader = const LinearGradient(colors: [Color(0xFF8A939C), Color(0xFFF6F7F8), Color(0xFF7A838C)], stops: [0, 0.4, 1]).createShader(sp),
  );
  canvas.drawRect(sp, Paint()..style = PaintingStyle.stroke..strokeWidth = 0.8..color = _edge.withValues(alpha: 0.6));
  final tip = Offset(0, len - r * 0.06);
  canvas.drawCircle(tip, spW * 0.75, Paint()..color = const Color(0xFF2E353C));
  canvas.drawCircle(tip.translate(-spW * 0.2, -spW * 0.2), spW * 0.28, Paint()..color = Colors.white.withValues(alpha: 0.6));
  canvas.restore();

  // ── 뒤 러그(윗쪽)
  final lug = Rect.fromCenter(center: center.translate(0, -r * 1.02), width: r * 0.34, height: r * 0.26);
  canvas.drawRRect(RRect.fromRectAndRadius(lug, Radius.circular(r * 0.08)), Paint()..color = const Color(0xFF8F98A1));
  canvas.drawRRect(RRect.fromRectAndRadius(lug, Radius.circular(r * 0.08)), Paint()..style = PaintingStyle.stroke..strokeWidth = 0.9..color = _edge.withValues(alpha: 0.7));

  // ── 베젤(무늬 낸 은색 테)
  canvas.drawCircle(center.translate(1.5, 2.5), r, Paint()..color = Colors.black.withValues(alpha: 0.25)..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.08));
  final outer = Rect.fromCircle(center: center, radius: r);
  canvas.drawCircle(
    center,
    r,
    Paint()
      ..shader = const SweepGradient(
        colors: [Color(0xFFE9ECEF), Color(0xFF8C959E), Color(0xFFD8DDE2), Color(0xFF7B848D), Color(0xFFE9ECEF)],
      ).createShader(outer),
  );
  if (r > 18) {
    final knurl = Paint()..color = _edge.withValues(alpha: 0.28)..strokeWidth = 1;
    final n = (r * 1.1).clamp(24, 90).round();
    for (var k = 0; k < n; k++) {
      final a = 2 * math.pi * k / n;
      final u = Offset(math.sin(a), -math.cos(a));
      canvas.drawLine(center + u * (r * 0.93), center + u * (r * 0.995), knurl);
    }
  }
  if (tag != null) {
    canvas.drawCircle(center, r * 0.955, Paint()..style = PaintingStyle.stroke..strokeWidth = math.max(2, r * 0.07)..color = tag);
  }
  canvas.drawCircle(center, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.1..color = _edge.withValues(alpha: 0.8));
  canvas.drawCircle(center, r * 0.88, Paint()..color = const Color(0xFF6F7881));

  // ── 눈금판
  final faceR = r * 0.85;
  canvas.drawCircle(
    center,
    faceR,
    Paint()..shader = const RadialGradient(center: Alignment(-0.25, -0.3), colors: [Colors.white, Color(0xFFEDEFF1)]).createShader(Rect.fromCircle(center: center, radius: faceR)),
  );
  final big = r > 36;
  for (var k = 0; k < 100; k++) {
    if (!big && k % 5 != 0) continue;
    final a = 2 * math.pi * k / 100;
    final u = Offset(math.sin(a), -math.cos(a));
    final long = k % 10 == 0, mid = k % 5 == 0;
    final l = long ? r * 0.15 : (mid ? r * 0.10 : r * 0.06);
    canvas.drawLine(
      center + u * (faceR * 0.97),
      center + u * (faceR * 0.97 - l),
      Paint()..color = const Color(0xFF15191D)..strokeWidth = long ? math.max(1.4, r * 0.022) : math.max(0.8, r * 0.012),
    );
  }
  if (numbers && big) {
    for (var k = 0; k < 10; k++) {
      final a = 2 * math.pi * k / 10;
      final u = Offset(math.sin(a), -math.cos(a));
      _t(canvas, '${k * 10}', center + u * (faceR * 0.66), r * 0.13, const Color(0xFF15191D));
    }
    _t(canvas, '0.01mm', center.translate(0, -faceR * 0.34), r * 0.085, const Color(0xFF4A535C), w: FontWeight.w700);
  }

  // ── 바퀴 수 작은 눈금판과 작은 바늘(1 mm = 한 칸)
  final sc = center.translate(0, faceR * 0.36);
  final sr = faceR * 0.22;
  if (r > 18) {
    canvas.drawCircle(sc, sr, Paint()..color = const Color(0xFFF7F8F9));
    canvas.drawCircle(sc, sr, Paint()..style = PaintingStyle.stroke..strokeWidth = 0.8..color = const Color(0xFF15191D));
    if (big) {
      for (var k = 0; k < 10; k++) {
        final a = 2 * math.pi * k / 10;
        final u = Offset(math.sin(a), -math.cos(a));
        canvas.drawLine(sc + u * sr, sc + u * (sr * 0.72), Paint()..color = const Color(0xFF15191D)..strokeWidth = 0.8);
      }
    }
    final ra = 2 * math.pi * (value / 10);
    final ru = Offset(math.sin(ra), -math.cos(ra));
    canvas.drawLine(sc, sc + ru * (sr * 0.85), Paint()..color = const Color(0xFF15191D)..strokeWidth = math.max(1.2, r * 0.02)..strokeCap = StrokeCap.round);
    canvas.drawCircle(sc, math.max(1.2, r * 0.025), Paint()..color = const Color(0xFF15191D));
  }

  // ── 큰 바늘(한 바퀴 1 mm, 시계 방향 +)
  final na = 2 * math.pi * value;
  final nu = Offset(math.sin(na), -math.cos(na));
  final nn = Offset(-nu.dy, nu.dx);
  final nw = math.max(1.2, r * 0.035);
  final needle = Path()
    ..moveTo((center + nu * (faceR * 0.92)).dx, (center + nu * (faceR * 0.92)).dy)
    ..lineTo((center + nn * nw).dx, (center + nn * nw).dy)
    ..lineTo((center - nu * (faceR * 0.25) + nn * nw * 1.3).dx, (center - nu * (faceR * 0.25) + nn * nw * 1.3).dy)
    ..lineTo((center - nu * (faceR * 0.25) - nn * nw * 1.3).dx, (center - nu * (faceR * 0.25) - nn * nw * 1.3).dy)
    ..lineTo((center - nn * nw).dx, (center - nn * nw).dy)
    ..close();
  canvas.drawPath(needle.shift(const Offset(1, 1.5)), Paint()..color = Colors.black.withValues(alpha: 0.2));
  canvas.drawPath(needle, Paint()..color = const Color(0xFFC62828));
  canvas.drawCircle(center, math.max(2, r * 0.08), Paint()..shader = const RadialGradient(center: Alignment(-0.4, -0.4), colors: [Color(0xFFECEFF1), Color(0xFF59626B)]).createShader(Rect.fromCircle(center: center, radius: math.max(2, r * 0.08))));

  // ── 유리 반사
  canvas.drawArc(Rect.fromCircle(center: center, radius: faceR * 0.9), math.pi * 1.1, math.pi * 0.55, false, Paint()..style = PaintingStyle.stroke..strokeWidth = math.max(1.5, r * 0.05)..color = Colors.white.withValues(alpha: 0.55));

  if (bezelArrow) {
    final p = Paint()..style = PaintingStyle.stroke..strokeWidth = math.max(2, r * 0.05)..color = AppColors.brand..strokeCap = StrokeCap.round;
    final ar = Rect.fromCircle(center: center, radius: r * 1.14);
    canvas.drawArc(ar, -math.pi * 0.95, math.pi * 0.5, false, p);
    final end = -math.pi * 0.45;
    final e = center + Offset(math.cos(end), math.sin(end)) * (r * 1.14);
    final t = Offset(-math.sin(end), math.cos(end));
    final n2 = Offset(math.cos(end), math.sin(end));
    canvas.drawLine(e, e - t * (r * 0.14) + n2 * (r * 0.09), p);
    canvas.drawLine(e, e - t * (r * 0.14) - n2 * (r * 0.09), p);
  }
}

/// "다이얼 보는 법" 큰 그림: 다이얼 하나와 각 부분 이름.
class AlignDialGuidePainter extends CustomPainter {
  final double value;
  AlignDialGuidePainter({this.value = -0.12});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final r = math.min(h * 0.30, w * 0.20);
    final c = Offset(math.max(r * 1.25, w * 0.26), h * 0.40);
    final tip = c + Offset(0, r * 2.35);
    paintDialGauge(canvas, c, r, value: value, stemTo: tip, bezelArrow: true);

    // 이름표와 지시선
    final lx = c.dx + r * 1.55;
    void callout(Offset from, double y, String title, String sub) {
      final to = Offset(lx - 6, y);
      final p = Paint()..color = AppColors.textSub..strokeWidth = 1.2;
      canvas.drawLine(from, Offset(from.dx + (to.dx - from.dx) * 0.4, y), p);
      canvas.drawLine(Offset(from.dx + (to.dx - from.dx) * 0.4, y), to, p);
      canvas.drawCircle(from, 2.6, Paint()..color = AppColors.text);
      final tp = TextPainter(
        text: TextSpan(children: [
          TextSpan(text: '$title\n', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: AppColors.text, height: 1.3)),
          TextSpan(text: sub, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSub, height: 1.3)),
        ]),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: math.max(80, w - lx - 4));
      tp.paint(canvas, Offset(lx, y - 9));
    }

    final na = 2 * math.pi * value;
    final needleTip = c + Offset(math.sin(na), -math.cos(na)) * (r * 0.62);
    final small = c.translate(0, r * 0.85 * 0.36);
    final gap = (h - 16) / 5;
    callout(c + Offset(r * 0.7, -r * 0.72), 8 + gap * 0.35, '베젤 (바깥 테)', '돌려서 큰 바늘을 0에 맞춥니다');
    callout(needleTip, 8 + gap * 1.35, '큰 바늘', '한 칸 0.01 mm, 한 바퀴 1 mm');
    callout(small, 8 + gap * 2.35, '작은 바늘', '큰 바늘이 몇 바퀴 돌았는지(1 mm씩)');
    callout(c + Offset(0, r * 1.55), 8 + gap * 3.35, '스핀들', '눌려 들어가면 +, 나오면 −');
    callout(tip, 8 + gap * 4.35, '접촉점', '상대 축의 림(바깥 둘레)에 댑니다');

    // 지금 읽음
    final label = '${value >= 0 ? '+' : '−'}${value.abs().toStringAsFixed(2)} mm';
    final tp = TextPainter(
      text: TextSpan(children: [
        const TextSpan(text: '이 바늘의 읽음  ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSub)),
        TextSpan(text: label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFFC62828))),
      ]),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(math.max(4, c.dx - tp.width / 2), h - tp.height - 2));
  }

  @override
  bool shouldRepaint(covariant AlignDialGuidePainter old) => old.value != value;
}

/// 작은 다이얼 하나(읽는 순서 줄에 쓰는 것).
class AlignSmallDialPainter extends CustomPainter {
  final double value;
  final bool bezelArrow;
  AlignSmallDialPainter(this.value, {this.bezelArrow = false});

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(size.width * 0.40, size.height * 0.30);
    final c = Offset(size.width / 2, size.height * 0.36);
    paintDialGauge(canvas, c, r, value: value, stemTo: c + Offset(0, r * 1.9), bezelArrow: bezelArrow);
  }

  @override
  bool shouldRepaint(covariant AlignSmallDialPainter old) => old.value != value || old.bezelArrow != bezelArrow;
}
