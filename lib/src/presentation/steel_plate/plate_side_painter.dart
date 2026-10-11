// 절곡 판 측면도(10-11, 사용자: "최고의 상용 앱 수준으로"): 부스바 그림을 빌려 쓰던 것을 철판 전용으로 새로 그렸다.
// 실제 두께·내R로 단면을 그리고, 면마다 입력한 바깥 치수(바깥면 ~ 바깥면)를 치수선으로, 절곡마다 안쪽에 번호 동그라미를 단다
// (방향·각도는 아래 절곡선 표에. 글을 달면 세운 면을 가렸다).
// 치수 기준은 계산과 같다: 면 n의 치수는 앞 절곡 바깥쪽 면에서 다음 절곡 바깥쪽 면까지(끝 면은 판 끝까지).
// 10-11 사용자("측면도에서 홀이 있으면 홀 표현도 해줘 캐드처럼"): 면을 뚫은 홀은 도면처럼 두께를 가로지르는
// 숨은선(파선) 두 줄(홀 양 끝)과 중심선(일점 쇄선)으로 그린다. 폭 방향으로 같은 자리의 홀은 겹쳐 한 번만.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'plate_calc.dart';
import 'plate_painter.dart';

String _f(double v) {
  var s = v.toStringAsFixed(1);
  if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
  return s;
}

/// 치수 글 각도(화면, y 아래): 글은 왼쪽→오른쪽, 세로 치수는 아래→위로 읽게(도면 관례, 10-11 실기기에서 거꾸로 나왔다).
double plateReadableAngle(Offset along) {
  var a = math.atan2(along.dy, along.dx);
  if (a > math.pi / 2 - 1e-6) {
    a -= math.pi;
  } else if (a < -math.pi / 2 - 1e-6) {
    a += math.pi;
  }
  return a;
}

/// 측면도 모양 계산(그리기·시험이 같이 쓴다). 좌표는 mm, y 위가 +.
class PlateSideGeometry {
  /// 단면 외곽(두께를 가진 띠, 닫힌 다각형).
  final List<Offset> outline;

  /// 면마다 치수 시작·끝(바깥 기준면 위)과 치수선을 낼 쪽(단위 벡터).
  final List<(Offset, Offset, Offset)> dims;

  /// 절곡마다 호 가운데(두께 가운데)와 안쪽 방향(단위 벡터).
  final List<(Offset, Offset)> bends;

  const PlateSideGeometry(this.outline, this.dims, this.bends);

  static Offset _dir(double deg) {
    final a = deg * math.pi / 180;
    return Offset(math.cos(a), math.sin(a));
  }

  static Offset _nrm(double deg) {
    final a = deg * math.pi / 180;
    return Offset(-math.sin(a), math.cos(a));
  }

  static double _dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;

  /// n1·x = a, n2·x = b 인 점(평행이면 null).
  static Offset? _meet(Offset n1, double a, Offset n2, double b) {
    final det = n1.dx * n2.dy - n1.dy * n2.dx;
    if (det.abs() < 1e-9) return null;
    return Offset((a * n2.dy - b * n1.dy) / det, (n1.dx * b - n2.dx * a) / det);
  }

  /// [legs] 면 바깥 치수, [turns] 절곡 각(+ 왼쪽으로 꺾음), [t] 두께, [r] 내R. 못 그리면 null.
  static PlateSideGeometry? of(
    List<double> legs,
    List<double> turns,
    double t,
    double r,
  ) {
    final n = legs.length;
    if (n == 0 || turns.length != n - 1 || t <= 0) return null;
    final rr = math.max(r, 0.0);
    final head = <double>[0];
    for (final a in turns) {
      head.add(head.last + a);
    }
    // 절곡 j의 바깥쪽: 왼쪽으로 꺾으면 오른쪽 면(−), 오른쪽으로 꺾으면 왼쪽 면(+)
    double sg(int j) => turns[j] > 0 ? -1.0 : 1.0;
    double ref(int k) => k < turns.length ? sg(k) : (k > 0 ? sg(k - 1) : -1);
    final c = List<double>.filled(n, 0); // 면 두께 가운데 선: n_k·x = c_k
    final s = <Offset>[], e = <Offset>[];
    for (var k = 0; k < n; k++) {
      final nk = _nrm(head[k]), dk = _dir(head[k]);
      final a = c[k] + ref(k) * t / 2;
      Offset start;
      if (k == 0) {
        start = nk * a;
      } else {
        final m = _meet(nk, a, _nrm(head[k - 1]), c[k - 1] + sg(k - 1) * t / 2);
        if (m == null) return null;
        start = m;
      }
      final end = start + dk * legs[k];
      s.add(start);
      e.add(end);
      if (k + 1 < n) c[k + 1] = _dot(_nrm(head[k + 1]), end) - sg(k) * t / 2;
    }
    // 두께 가운데 선을 점으로(직선 + 호), 점마다 진행 방향(°)
    final pts = <(Offset, double)>[
      (s[0] - _nrm(head[0]) * (ref(0) * t / 2), head[0]),
    ];
    final bends = <(Offset, Offset)>[];
    final rc = rr + t / 2;
    for (var j = 0; j < turns.length; j++) {
      final nj = _nrm(head[j]), nj1 = _nrm(head[j + 1]);
      final ctr = _meet(nj, c[j] - sg(j) * rc, nj1, c[j + 1] - sg(j) * rc);
      if (ctr == null) return null;
      final ta = ctr + nj * (sg(j) * rc);
      final a0 = math.atan2(ta.dy - ctr.dy, ta.dx - ctr.dx);
      final sweep = turns[j] * math.pi / 180;
      final steps = math.max(4, (turns[j].abs() / 6).ceil());
      for (var i = 0; i <= steps; i++) {
        final a = a0 + sweep * i / steps;
        final p = ctr + Offset(math.cos(a), math.sin(a)) * rc;
        final h =
            (a + (sweep >= 0 ? math.pi / 2 : -math.pi / 2)) * 180 / math.pi;
        pts.add((p, h));
      }
      final mid = a0 + sweep / 2;
      final pm = ctr + Offset(math.cos(mid), math.sin(mid)) * rc;
      final inward = ctr - pm;
      bends.add((pm, inward.distance < 1e-9 ? nj : inward / inward.distance));
    }
    pts.add((e[n - 1] - _nrm(head[n - 1]) * (ref(n - 1) * t / 2), head[n - 1]));
    final left = [for (final (p, h) in pts) p + _nrm(h) * (t / 2)];
    final right = [for (final (p, h) in pts) p - _nrm(h) * (t / 2)];
    final outline = [...left, ...right.reversed];
    if (outline.any((p) => !p.dx.isFinite || !p.dy.isFinite)) return null;
    return PlateSideGeometry(outline, [
      for (var k = 0; k < n; k++) (s[k], e[k], _nrm(head[k]) * ref(k)),
    ], bends);
  }
}

/// 측면도에 그릴 홀 하나: 면 번호, 면 시작(바깥 치수 기준면)에서 홀 가운데까지, 면 방향 반 길이(장공은 길이 방향 몫).
typedef PlateSideHole = (int face, double u, double half);

/// 측면도 그림. [dimFaces]는 치수를 그릴 면(null이면 모두).
class PlateSidePainter extends CustomPainter {
  PlateSidePainter({
    required this.legs,
    required this.turns,
    required this.t,
    required this.r,
    required this.text,
    required this.sub,
    required this.bg,
    this.tone = PlateTone.light,
    this.fontScale = 1,
    this.topInset = 0,
    this.dimFaces,
    this.holes = const [],
  });

  /// 계산 결과에서. [hat]이면 같은 치수가 되풀이되는 오른쪽 다리·발 치수를 뺀다.
  factory PlateSidePainter.of(
    PlatePlan p, {
    required double t,
    required Color text,
    required Color sub,
    required Color bg,
    PlateTone tone = PlateTone.light,
    double fontScale = 1,
    double topInset = 0,
    bool hat = false,
  }) => PlateSidePainter(
    legs: p.faceLengths,
    turns: [for (final b in p.bends) b.turn],
    t: t,
    r: p.rUsed,
    text: text,
    sub: sub,
    bg: bg,
    tone: tone,
    fontScale: fontScale,
    topInset: topInset,
    dimFaces: hat ? const [0, 1, 2] : null,
    holes: plateSideHoles(p),
  );

  final List<double> legs, turns;
  final double t, r;
  final Color text, sub, bg;
  final PlateTone tone;
  final double fontScale;

  /// 위쪽에 비워 둘 높이(그림 위 단추 줄).
  final double topInset;
  final List<int>? dimFaces;

  /// 면을 뚫은 홀(숨은선·중심선으로 그린다).
  final List<PlateSideHole> holes;

  @override
  void paint(Canvas canvas, Size size) {
    final g = PlateSideGeometry.of(legs, turns, t, r);
    if (g == null) return;
    var x0 = double.infinity, y0 = double.infinity;
    var x1 = -double.infinity, y1 = -double.infinity;
    for (final p in g.outline) {
      x0 = math.min(x0, p.dx);
      x1 = math.max(x1, p.dx);
      y0 = math.min(y0, p.dy);
      y1 = math.max(y1, p.dy);
    }
    final fs = fontScale;
    // 둘레: 치수선(면에서 20 + 글 반)과 아래 안내 한 줄이 들어갈 만큼
    final pad = 50.0 * fs;
    final w = math.max(x1 - x0, 1.0), h = math.max(y1 - y0, 1.0);
    final top = topInset + 34 * fs;
    final bottom = 56.0 * fs;
    final s = math.min(
      (size.width - 2 * pad) / w,
      (size.height - top - bottom) / h,
    );
    if (s <= 0 || !s.isFinite) return;
    final ox = (size.width - w * s) / 2;
    final oy = top + (size.height - top - bottom - h * s) / 2;
    Offset m(Offset q) => Offset(ox + (q.dx - x0) * s, oy + (y1 - q.dy) * s);
    Offset v(Offset d) => Offset(d.dx, -d.dy); // 방향(화면은 y 아래)

    // 단면(그림자 → 철 색 → 테두리)
    final path = Path()..addPolygon([for (final p in g.outline) m(p)], true);
    canvas.drawPath(
      path.shift(Offset(0, 2.5 * fs)),
      Paint()..color = const Color(0x22000000),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: tone.shade,
        ).createShader(path.getBounds()),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = tone.edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * fs
        ..strokeJoin = StrokeJoin.round,
    );

    // 홀(도면 관례): 숨은선(파선) = 홀 양 끝이 두께를 지나는 자리, 중심선(일점 쇄선) = 홀 가운데, 판 밖으로 조금
    final hidden = Paint()
      ..color = tone.edge
      ..strokeWidth = 1.4 * fs;
    final center = Paint()
      ..color = kPlateCenter
      ..strokeWidth = 0.9 * fs;
    void dashed(Offset a, Offset b, Paint p, {bool dot = false}) {
      final d = b - a, len = d.distance;
      if (len < 0.5) return;
      final u = d / len;
      final dash = (dot ? 9.0 : 4.0) * fs, gap = 2.5 * fs;
      var x = 0.0;
      while (x < len) {
        canvas.drawLine(a + u * x, a + u * math.min(x + dash, len), p);
        x += dash + gap;
        if (dot && x < len) {
          canvas.drawLine(a + u * x, a + u * math.min(x + 1.5 * fs, len), p);
          x += 1.5 * fs + gap;
        }
      }
    }

    final drawn = <String>{};
    for (final (f, u, half) in holes) {
      if (f < 0 || f >= g.dims.length) continue;
      final key = '$f|${u.toStringAsFixed(2)}|${half.toStringAsFixed(2)}';
      if (!drawn.add(key)) continue;
      final (a, b, out) = g.dims[f];
      final len = (b - a).distance;
      if (len < 1e-6) continue;
      final dir = (b - a) / len;
      // 바깥 치수 기준면 위 자리 → 반대 면(두께만큼 안쪽)
      Offset onRef(double x) => a + dir * x;
      Offset across(double x) => onRef(x) - out * t;
      for (final x in [u - half, u + half]) {
        dashed(m(onRef(x)), m(across(x)), hidden);
      }
      final ext = 6.0 * fs / s; // 판 밖으로 6점
      dashed(
        m(onRef(u) + out * ext),
        m(across(u) - out * ext),
        center,
        dot: true,
      );
    }

    // 치수선: 기준면에서 바깥쪽으로 띄워, 양 끝 보조선 + 사선 끝 + 값
    final dimPaint = Paint()
      ..color = sub
      ..strokeWidth = 1 * fs;
    final gap = 20.0 * fs, over = 4.0 * fs, k = 4.0 * fs;
    for (var i = 0; i < g.dims.length; i++) {
      if (dimFaces != null && !dimFaces!.contains(i)) continue;
      final (a, b, out) = g.dims[i];
      if ((b - a).distance < 1e-6) continue;
      final o = v(out);
      final pa = m(a), pb = m(b);
      final da = pa + o * gap, db = pb + o * gap;
      canvas.drawLine(pa + o * 3 * fs, da + o * over, dimPaint);
      canvas.drawLine(pb + o * 3 * fs, db + o * over, dimPaint);
      canvas.drawLine(da, db, dimPaint);
      final along = (db - da) / (db - da).distance;
      final tick = (along + o) * (k / math.sqrt2);
      for (final q in [da, db]) {
        canvas.drawLine(q - tick, q + tick, dimPaint);
      }
      _label(
        canvas,
        _f(legs[i]),
        (da + db) / 2,
        plateReadableAngle(along),
        text,
        bold: true,
      );
    }

    // 절곡 번호 동그라미(절곡 안쪽)
    for (var j = 0; j < g.bends.length; j++) {
      final (p, inward) = g.bends[j];
      final r = 10.0 * fs;
      final at = m(p) + v(inward) * (t * s / 2 + r + 4 * fs);
      canvas.drawCircle(
        at + Offset(0, 1.5 * fs),
        r,
        Paint()..color = const Color(0x33000000),
      );
      canvas.drawCircle(at, r, Paint()..color = kPlateBend);
      final tp = TextPainter(
        text: TextSpan(
          text: '${j + 1}',
          style: TextStyle(
            fontSize: 12 * fs,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    }
  }

  void _label(
    Canvas canvas,
    String s,
    Offset at,
    double angle,
    Color color, {
    bool bold = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: 12 * fontScale,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    final box = Rect.fromCenter(
      center: Offset.zero,
      width: tp.width + 8 * fontScale,
      height: tp.height + 3 * fontScale,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, Radius.circular(4 * fontScale)),
      Paint()..color = bg.withValues(alpha: 0.85),
    );
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(PlateSidePainter o) =>
      o.t != t ||
      o.r != r ||
      o.text != text ||
      o.bg != bg ||
      o.tone != tone ||
      o.topInset != topInset ||
      o.legs.join(',') != legs.join(',') ||
      o.turns.join(',') != turns.join(',') ||
      o.holes.join(';') != holes.join(';');
}

/// 계산 결과의 홀 중 측면도에 그릴 것: 자기 면 안의 곧은 부분에 있는 홀(절곡부·판 밖·없는 면은 뺀다).
List<PlateSideHole> plateSideHoles(PlatePlan p) => [
  for (final h in p.holes)
    if (!h.out &&
        h.face >= 0 &&
        h.face < p.faceLengths.length &&
        h.u - h.halfX >= -1e-6 &&
        h.u + h.halfX <= p.faceLengths[h.face] + 1e-6 &&
        !p.bends.any(
          (b) => h.c.dx + h.halfX > b.start && h.c.dx - h.halfX < b.end,
        ))
      (h.face, h.u, h.halfX),
];
