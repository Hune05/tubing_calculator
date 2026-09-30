// 축 정렬 결과 그림 둘: (1) 펌프·커플링·모터·받침판을 입체로 그리고 모터 네 발 밑에 심을 표시한 그림,
// (2) 위에서 본 그림(네 발마다 심 값과 옆으로 밀 방향). 실제 크기 그림이 아니라 방향과 크기 비율을 보이는 그림이다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import 'alignment_math.dart';

const Color _caution = AppColors.caution; // 넣기(호박색)
const Color _remove = Color(0xFFE5484D); // 빼기(빨강)
const Color _ok = AppColors.ok;

Color _shimColor(double mm) => mm.abs() < 0.005 ? _ok : (mm > 0 ? _caution : _remove);

Color _shade(Color c, double t) => t >= 0
    ? Color.lerp(c, Colors.white, t)!
    : Color.lerp(c, Colors.black, -t)!;

void _label(Canvas canvas, String text, Offset at, Color color, {double size = 11, double minWidth = 0}) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: TextStyle(fontSize: size, color: color, fontWeight: FontWeight.w900, height: 1.2)),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: 130);
  final r = Rect.fromCenter(center: at, width: math.max(tp.width + 12, minWidth), height: tp.height + 6);
  final rr = RRect.fromRectAndRadius(r, const Radius.circular(8));
  canvas.drawRRect(rr.shift(const Offset(0, 1.5)), Paint()..color = Colors.black.withValues(alpha: 0.14));
  canvas.drawRRect(rr, Paint()..color = Colors.white);
  canvas.drawRRect(rr, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.4..color = color);
  tp.paint(canvas, Offset(at.dx - tp.width / 2, at.dy - tp.height / 2));
}

String _shimShort(double mm) {
  if (mm.abs() < 0.005) return '그대로';
  return '${mm > 0 ? '넣기' : '빼기'} ${mm.abs().toStringAsFixed(2)}';
}

String _moveShort(double mm) {
  if (mm.abs() < 0.005) return '옆 그대로';
  return '${mm > 0 ? '오른쪽' : '왼쪽'} ${mm.abs().toStringAsFixed(2)}';
}

// ─────────────────────────── 입체 그림 ───────────────────────────

class AlignIsoPainter extends CustomPainter {
  final double shimFront;
  final double shimRear;
  final double moveFront;
  final double moveRear;
  AlignIsoPainter({
    required this.shimFront,
    required this.shimRear,
    required this.moveFront,
    required this.moveRear,
  });

  // 모델 좌표: x = 펌프 → 모터(축 방향), y = 위, z = 오른쪽(고정 쪽에서 모터를 볼 때).
  static const double _ux = 0.88, _uxy = -0.30; // x가 늘면 화면 오른쪽·위로
  static const double _uz = 0.46, _uzy = 0.36; // z가 늘면 화면 오른쪽·아래로(가까워짐)

  late double _s;
  late double _ox, _oy;

  Offset _p(double x, double y, double z) =>
      Offset(_ox + _s * (_ux * x + _uz * z), _oy + _s * (_uxy * x + _uzy * z - y));

  void _poly(Canvas canvas, List<Offset> pts, Color fill, {double outline = 0.22}) {
    final path = Path()..addPolygon(pts, true);
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = Colors.black.withValues(alpha: outline)..strokeJoin = StrokeJoin.round);
  }

  /// 직육면체: 보이는 세 면(위·앞(+z)·왼(−x))을 다른 밝기로.
  void _box(Canvas canvas, double x0, double y0, double z0, double x1, double y1, double z1, Color base) {
    _poly(canvas, [_p(x0, y0, z1), _p(x1, y0, z1), _p(x1, y1, z1), _p(x0, y1, z1)], base); // 앞
    _poly(canvas, [_p(x0, y0, z0), _p(x0, y0, z1), _p(x0, y1, z1), _p(x0, y1, z0)], _shade(base, -0.3)); // 왼
    _poly(canvas, [_p(x0, y1, z0), _p(x1, y1, z0), _p(x1, y1, z1), _p(x0, y1, z1)], _shade(base, 0.28)); // 위
  }

  /// x축 방향 원통: 옆면 그라데이션 + 보이는 끝(−x쪽) 원판.
  void _cylX(Canvas canvas, double x0, double x1, double ya, double zc, double r, Color base, {bool rings = false}) {
    final a = _p(x0, ya, zc), b = _p(x1, ya, zc);
    final d = b - a;
    final len = d.distance;
    final ang = math.atan2(d.dy, d.dx);
    final rw = r * _s * 1.03;
    canvas.save();
    canvas.translate(a.dx, a.dy);
    canvas.rotate(ang);
    final body = Rect.fromLTRB(0, -rw, len, rw);
    // 그림자
    canvas.drawRect(body.shift(const Offset(0, 4)), Paint()..color = Colors.black.withValues(alpha: 0.12)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawRect(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_shade(base, 0.45), _shade(base, 0.1), base, _shade(base, -0.35)],
          stops: const [0, 0.25, 0.55, 1],
        ).createShader(body),
    );
    if (rings) {
      // 방열 핀(모터 몸통 둘레의 얇은 줄)
      final n = math.max(3, (len / (rw * 0.42)).floor());
      for (var i = 1; i < n; i++) {
        final x = len * i / n;
        canvas.drawLine(Offset(x, -rw + 2), Offset(x, rw - 2), Paint()..color = Colors.black.withValues(alpha: 0.16)..strokeWidth = 1.4);
        canvas.drawLine(Offset(x + 1.6, -rw + 2), Offset(x + 1.6, rw - 2), Paint()..color = Colors.white.withValues(alpha: 0.22)..strokeWidth = 1);
      }
    }
    // 윗선 하이라이트
    canvas.drawLine(Offset(3, -rw * 0.62), Offset(len - 3, -rw * 0.62), Paint()..color = Colors.white.withValues(alpha: 0.35)..strokeWidth = 2..strokeCap = StrokeCap.round);
    // 보이는 끝 원판(타원)
    final cap = Rect.fromCenter(center: Offset.zero, width: r * _s * 0.9, height: rw * 2);
    canvas.drawOval(cap, Paint()..shader = RadialGradient(colors: [_shade(base, 0.5), _shade(base, 0.05)], center: const Alignment(-0.3, -0.4)).createShader(cap));
    canvas.drawOval(cap, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = Colors.black.withValues(alpha: 0.3));
    canvas.restore();
  }

  /// 발 밑 심: 넣기는 호박색 판, 빼기는 빨간 점선 판, 그대로는 초록 얇은 선.
  void _shim(Canvas canvas, double x0, double x1, double z0, double z1, double yBase, double mm) {
    final t = mm.abs() < 0.005 ? 0.02 : 0.05 + math.min(mm.abs(), 1.0) * 0.3;
    final c = _shimColor(mm);
    if (mm < -0.005) {
      // 빼기: 발 밑에 이만큼 얇아진다는 뜻으로 빨간 점선 상자
      final pts = [_p(x0, yBase, z1), _p(x1, yBase, z1), _p(x1, yBase + t, z1), _p(x0, yBase + t, z1)];
      final path = Path()..addPolygon(pts, true);
      canvas.drawPath(path, Paint()..color = c.withValues(alpha: 0.28));
      final dash = Paint()..color = c..style = PaintingStyle.stroke..strokeWidth = 1.6;
      canvas.drawPath(path, dash);
    } else {
      _box(canvas, x0, yBase, z0, x1, yBase + t, z1, c);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    const mx = 10.6; // 화면에 쓰는 모델 폭(단위)
    const my = 8.3;
    const labelRow = 66.0;
    final avail = size.height - 16 - labelRow;
    _s = math.min((size.width - 16) / mx, avail / my);
    _ox = 8 + (size.width - 16 - _s * mx) / 2;
    _oy = 8 + _s * 6.9 + (avail - _s * my) / 2;

    const baseTop = 0.35;
    const footBottom = 0.72, footTop = 1.12;
    const ya = 2.25, zc = 1.8; // 축 높이·가운데
    const zL = 0.65, zR = 2.95; // 모터 왼쪽·오른쪽 발 위치
    const dark = Color(0xFF3B4048);
    const steel = Color(0xFF9AA5B1);
    const teal = Color(0xFF14A0AB);

    // 받침판(I빔 두 줄 + 가로대)
    for (final z in [0.30, 2.62]) {
      _box(canvas, 0.0, 0, z, 10.0, baseTop, z + 0.70, dark);
    }
    for (final x in [0.35, 3.9, 5.55, 9.35]) {
      _box(canvas, x, 0.05, 0.30, x + 0.4, baseTop - 0.02, 3.32, _shade(dark, 0.08));
    }

    const xFront = 6.55, xRear = 8.75; // 모터 앞발·뒷발 자리
    const fdx = 0.85, fdz = 0.5;

    // 모터 뒤쪽(왼쪽 발, z 작은 쪽) 발: 몸통보다 먼저
    for (final (x, mm) in [(xFront, shimFront), (xRear, shimRear)]) {
      _shim(canvas, x, x + fdx, zL - fdz / 2, zL + fdz / 2, baseTop, mm);
      _box(canvas, x, footBottom, zL - fdz / 2, x + fdx, footTop, zL + fdz / 2, steel);
    }

    // 모터 몸통·앞판·팬 덮개·단자함
    _cylX(canvas, 6.05, 6.25, ya, zc, 1.16, _shade(steel, 0.05));
    _cylX(canvas, 6.25, 9.45, ya, zc, 1.05, steel, rings: true);
    _cylX(canvas, 9.45, 10.05, ya, zc, 1.0, _shade(steel, 0.15));
    _box(canvas, 7.35, ya + 0.95, zc - 0.45, 8.35, ya + 1.42, zc + 0.45, _shade(steel, -0.05));

    // 모터 앞쪽(오른쪽 발, z 큰 쪽) 발: 몸통 위에 겹쳐 그려 보이게
    for (final (x, mm) in [(xFront, shimFront), (xRear, shimRear)]) {
      _shim(canvas, x, x + fdx, zR - fdz / 2, zR + fdz / 2, baseTop, mm);
      _box(canvas, x, footBottom, zR - fdz / 2, x + fdx, footTop, zR + fdz / 2, steel);
      // 볼트
      final bolt = _p(x + fdx / 2, footTop, zR);
      canvas.drawCircle(bolt, _s * 0.11, Paint()..color = Colors.black.withValues(alpha: 0.55));
      canvas.drawCircle(bolt.translate(-1, -1), _s * 0.07, Paint()..color = Colors.white.withValues(alpha: 0.4));
    }

    // 축·커플링
    _cylX(canvas, 5.0, 6.05, ya, zc, 0.20, _shade(steel, 0.25));
    _cylX(canvas, 4.75, 5.35, ya, zc, 0.55, _shade(steel, 0.05));
    _cylX(canvas, 5.35, 5.95, ya, zc, 0.55, teal);

    // 펌프: 받침 → 베어링 하우징 → 케이싱 → 플랜지
    _box(canvas, 2.2, baseTop, zc - 0.55, 3.0, 1.05, zc + 0.55, _shade(steel, -0.1));
    _box(canvas, 3.3, 1.25, zc - 0.62, 4.75, ya + 0.62, zc + 0.62, steel);
    _cylX(canvas, 0.55, 3.3, ya, zc, 1.28, steel);
    _cylX(canvas, 0.30, 0.62, ya, zc, 1.50, _shade(steel, 0.15)); // 흡입 플랜지
    final hole = Rect.fromCenter(center: _p(0.30, ya, zc), width: 0.62 * _s * 0.9, height: 1.5 * _s * 1.03 * 1.02 * 0.9);
    canvas.drawOval(hole, Paint()..color = const Color(0xFF2B3138));
    // 토출 플랜지(위로)
    final top = _p(1.9, ya + 1.55, zc);
    _box(canvas, 1.5, ya + 1.0, zc - 0.32, 2.3, ya + 1.55, zc + 0.32, _shade(steel, 0.1));
    canvas.drawOval(Rect.fromCenter(center: top, width: _s * 0.85, height: _s * 0.32), Paint()..color = const Color(0xFF2B3138));

    // 이름표
    void name(String t, Offset at) {
      final tp = TextPainter(
        text: TextSpan(text: t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.textSub)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    }

    name('펌프 (고정)', _p(1.4, ya + 2.3, zc));
    name('모터 (이동)', _p(7.6, ya + 2.5, zc - 0.4));
    name('커플링', _p(5.4, ya + 1.0, zc));

    // 발 라벨(앞·뒷줄, 왼쪽·오른쪽 발이 같은 값)
    void footLabel(double x, double mm, double moveMm, String row, Offset at) {
      final anchor = _p(x + fdx / 2, baseTop, zR + fdz / 2);
      final c = _shimColor(mm);
      canvas.drawLine(anchor, at - const Offset(0, 24), Paint()..color = c..strokeWidth = 1.2);
      canvas.drawCircle(anchor, 2.5, Paint()..color = c);
      _label(canvas, '$row\n심 ${_shimShort(mm)}\n${_moveShort(moveMm)}', at, c, minWidth: 104);
    }

    final rowY = size.height - 8 - 24.0;
    final rearAt = Offset(size.width - 8 - 52, rowY);
    final frontAt = Offset(rearAt.dx - 114, rowY);
    footLabel(xFront, shimFront, moveFront, '앞발', frontAt);
    footLabel(xRear, shimRear, moveRear, '뒷발', rearAt);

    // 옆으로 미는 화살표(오른쪽 = +z 방향 = 화면 오른쪽 아래)
    void moveArrow(double x, double mm) {
      if (mm.abs() < 0.005) return;
      final c = _p(x + fdx / 2, baseTop + 0.02, zR + fdz / 2 + 0.05);
      final dir = Offset(_uz, _uzy) / math.sqrt(_uz * _uz + _uzy * _uzy) * (mm > 0 ? 1 : -1);
      final a = c - dir * (_s * 0.5);
      final b = c + dir * (_s * 0.5);
      final p = Paint()..color = AppColors.brand..strokeWidth = 3..strokeCap = StrokeCap.round;
      canvas.drawLine(a, b, p);
      final n = Offset(-dir.dy, dir.dx);
      canvas.drawLine(b, b - dir * 8 + n * 5, p);
      canvas.drawLine(b, b - dir * 8 - n * 5, p);
    }

    moveArrow(xFront, moveFront);
    moveArrow(xRear, moveRear);
  }

  @override
  bool shouldRepaint(covariant AlignIsoPainter old) =>
      old.shimFront != shimFront || old.shimRear != shimRear || old.moveFront != moveFront || old.moveRear != moveRear;
}

// ─────────────────────────── 위에서 본 그림 ───────────────────────────

/// 위에서 본 그림: 위쪽이 왼쪽, 아래쪽이 오른쪽(고정 쪽에서 모터를 바라볼 때).
class AlignPlanPainter extends CustomPainter {
  final AxisLine horizontal; // 모터 축의 옆 어긋남(+ 오른쪽)
  final double xFront;
  final double xRear;
  final double shimFront;
  final double shimRear;
  final double moveFront;
  final double moveRear;
  AlignPlanPainter({
    required this.horizontal,
    required this.xFront,
    required this.xRear,
    required this.shimFront,
    required this.shimRear,
    required this.moveFront,
    required this.moveRear,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final midY = h * 0.5;
    const steel = Color(0xFF9AA5B1);
    const dark = Color(0xFF3B4048);
    const teal = Color(0xFF14A0AB);

    // 받침판
    final plate = RRect.fromRectAndRadius(Rect.fromLTRB(w * 0.02, h * 0.10, w * 0.98, h * 0.90), const Radius.circular(8));
    canvas.drawRRect(plate, Paint()..color = const Color(0xFFEFF2F5));
    canvas.drawRRect(plate, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = dark.withValues(alpha: 0.55));
    for (final y in [h * 0.155, h * 0.845]) {
      canvas.drawRect(Rect.fromLTRB(w * 0.03, y - 5, w * 0.97, y + 5), Paint()..color = dark.withValues(alpha: 0.4));
    }

    void metal(Rect r, Color base, {double radius = 8}) {
      final rr = RRect.fromRectAndRadius(r, Radius.circular(radius));
      canvas.drawRRect(rr.shift(const Offset(0, 3)), Paint()..color = Colors.black.withValues(alpha: 0.15)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      canvas.drawRRect(
        rr,
        Paint()
          ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_shade(base, 0.35), base, _shade(base, -0.25)]).createShader(r),
      );
      canvas.drawRRect(rr, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = Colors.black26);
    }

    // 펌프(왼쪽) — 케이싱 원 + 몸체
    final pump = Rect.fromLTRB(w * 0.06, h * 0.30, w * 0.30, h * 0.70);
    metal(pump, steel, radius: 14);
    canvas.drawCircle(Offset(w * 0.15, midY), h * 0.13, Paint()..color = _shade(steel, -0.18));
    canvas.drawCircle(Offset(w * 0.15, midY), h * 0.06, Paint()..color = const Color(0xFF2B3138));
    // 펌프 발 네 개는 작게
    for (final y in [h * 0.26, h * 0.74]) {
      metal(Rect.fromCenter(center: Offset(w * 0.13, y), width: w * 0.06, height: h * 0.08), _shade(steel, -0.1), radius: 3);
      metal(Rect.fromCenter(center: Offset(w * 0.24, y), width: w * 0.06, height: h * 0.08), _shade(steel, -0.1), radius: 3);
    }

    // 축·커플링
    metal(Rect.fromLTRB(w * 0.30, midY - 6, w * 0.60, midY + 6), _shade(steel, 0.25), radius: 3);
    metal(Rect.fromLTRB(w * 0.40, midY - h * 0.075, w * 0.455, midY + h * 0.075), _shade(steel, 0.05), radius: 4);
    metal(Rect.fromLTRB(w * 0.462, midY - h * 0.075, w * 0.52, midY + h * 0.075), teal, radius: 4);

    // 모터(오른쪽, 목표 위치) + 방열 핀
    final motor = Rect.fromLTRB(w * 0.56, h * 0.29, w * 0.95, h * 0.71);
    metal(motor, steel, radius: 16);
    for (var x = w * 0.60; x < w * 0.91; x += w * 0.025) {
      canvas.drawLine(Offset(x, h * 0.32), Offset(x, h * 0.68), Paint()..color = Colors.black.withValues(alpha: 0.13)..strokeWidth = 1.2);
    }
    metal(Rect.fromLTRB(w * 0.72, h * 0.40, w * 0.82, h * 0.60), _shade(steel, 0.05), radius: 5); // 단자함

    // 모터 지금 위치(옆 어긋남을 부풀린 점선 틀): 커플링 쪽과 뒤끝의 어긋남
    final zc = horizontal.at(0), zEnd = horizontal.at(xRear);
    final zMax = math.max(math.max(zc.abs(), zEnd.abs()), math.max(moveFront.abs(), moveRear.abs()));
    final zScale = zMax < 1e-6 ? 0.0 : (h * 0.11) / zMax;
    // 화면에서 아래 = 오른쪽(+)
    final yl = motor.left, yr = motor.right;
    final ghost = Path()
      ..moveTo(yl, motor.top + zc * zScale)
      ..lineTo(yr, motor.top + zEnd * zScale)
      ..lineTo(yr, motor.bottom + zEnd * zScale)
      ..lineTo(yl, motor.bottom + zc * zScale)
      ..close();
    final dashPaint = Paint()
      ..color = _caution
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    _dashPath(canvas, ghost, dashPaint);

    // 목표 중심선(펌프 축)
    final target = Paint()..color = AppColors.text.withValues(alpha: 0.55)..strokeWidth = 1.4;
    for (var x = w * 0.04; x < w * 0.96; x += 12) {
      canvas.drawLine(Offset(x, midY), Offset(x + 6, midY), target);
    }

    // 모터 네 발(위쪽 = 왼쪽 발, 아래쪽 = 오른쪽 발)
    final frontCx = w * 0.64, rearCx = w * 0.87;
    void foot(double cx, double cy, double mm, String tag, bool top) {
      final r = Rect.fromCenter(center: Offset(cx, cy), width: w * 0.095, height: h * 0.11);
      final c = _shimColor(mm);
      metal(r, _shade(steel, -0.05), radius: 4);
      canvas.drawCircle(r.center, 3.6, Paint()..color = Colors.black54);
      // 심 표시(발 바깥쪽 가장자리에 색 띠)
      final bar = Rect.fromLTWH(r.left, top ? r.top - 6 : r.bottom + 1, r.width, 5);
      canvas.drawRRect(RRect.fromRectAndRadius(bar, const Radius.circular(2)), Paint()..color = c.withValues(alpha: mm < -0.005 ? 0.35 : 1));
      if (mm < -0.005) {
        _dashPath(canvas, Path()..addRRect(RRect.fromRectAndRadius(bar, const Radius.circular(2))), Paint()..color = c..style = PaintingStyle.stroke..strokeWidth = 1.4);
      }
      _label(canvas, '$tag\n${_shimShort(mm)}', Offset(cx, top ? r.top - 24 : r.bottom + 24), c, size: 10);
    }

    foot(frontCx, h * 0.245, shimFront, '앞·왼', true);
    foot(rearCx, h * 0.245, shimRear, '뒤·왼', true);
    foot(frontCx, h * 0.755, shimFront, '앞·오른', false);
    foot(rearCx, h * 0.755, shimRear, '뒤·오른', false);

    // 옆으로 미는 화살표(앞·뒤, 몸통 가운데 높이): 오른쪽 = 아래
    void arrow(double cx, double mm) {
      if (mm.abs() < 0.005) {
        _label(canvas, '옆 그대로', Offset(cx, midY + 42), _ok, size: 10);
        return;
      }
      final dir = mm > 0 ? 1.0 : -1.0;
      final p = Paint()..color = AppColors.brand..strokeWidth = 3.2..strokeCap = StrokeCap.round;
      final a = Offset(cx, midY - dir * 14), b = Offset(cx, midY + dir * 14);
      canvas.drawLine(a, b, p);
      canvas.drawLine(b, b + Offset(-6, -dir * 8), p);
      canvas.drawLine(b, b + Offset(6, -dir * 8), p);
      _label(canvas, '옆 밀기\n${mm > 0 ? '오른쪽' : '왼쪽'} ${mm.abs().toStringAsFixed(2)}', Offset(cx, midY + 42), AppColors.brand, size: 10);
    }

    arrow(frontCx, moveFront);
    arrow(rearCx, moveRear);

    // 방향 표시와 이름
    void txt(String t, Offset at, Color c) {
      final tp = TextPainter(
        text: TextSpan(text: t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    }

    txt('왼쪽 ▲', Offset(w * 0.075, h * 0.045), AppColors.textSub);
    txt('오른쪽 ▼', Offset(w * 0.08, h * 0.955), AppColors.textSub);
    txt('펌프 (고정)', Offset(w * 0.18, midY + h * 0.27), AppColors.textSub);
    txt('모터', Offset(w * 0.76, h * 0.335), Colors.white);
    txt('점선 = 지금 모터 위치(부풀림)', Offset(w * 0.73, h * 0.035), _caution);
  }

  void _dashPath(Canvas canvas, Path path, Paint paint) {
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, math.min(d + 7, m.length)), paint);
        d += 12;
      }
    }
  }

  @override
  bool shouldRepaint(covariant AlignPlanPainter old) =>
      old.horizontal.v0 != horizontal.v0 ||
      old.horizontal.slope != horizontal.slope ||
      old.shimFront != shimFront ||
      old.shimRear != shimRear ||
      old.moveFront != moveFront ||
      old.moveRear != moveRear;
}
