// 철판 전개도 그림(10-10): 외곽·구멍·장공(흰색), 꺾기선(주황 점선 + 번호·방향·각도), 전체 치수·꺾기선 위치 치수.
// 화면과 가공 지시서 PDF(PNG로 떠서)가 같은 그림을 쓴다. 좌표는 plate_calc.dart(왼쪽 아래 원점, y 위)를 화면으로 뒤집는다.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/field_view.dart';
import 'plate_calc.dart';

const Color kPlateFill = Color(0xFFC9D3DA);
const Color kPlateEdge = Color(0xFF4B5A64);
const Color kPlateBend = Color(0xFFE08A1E);

/// 꺾은 모양(옆모습) 철 색: 밝은 쪽, 어두운 쪽.
const List<Color> kPlateSteelShade = [Color(0xFFCBD5DC), Color(0xFF6F7E88)];

/// 판 색 묶음(10-11): 야간 보기에서는 어두운 철 색으로(어두운 화면 한가운데 밝은 판이 눈부셨다).
/// 가공 도면 PDF는 늘 [light].
class PlateTone {
  final Color fill, edge;

  /// 입체(측면도·3D) 철 색: 밝은 쪽, 어두운 쪽.
  final List<Color> shade;
  const PlateTone(this.fill, this.edge, this.shade);

  static const light = PlateTone(kPlateFill, kPlateEdge, kPlateSteelShade);
  static const night = PlateTone(Color(0xFF4A5761), Color(0xFFAEBCC6), [
    Color(0xFF66747E),
    Color(0xFF3B464E),
  ]);

  /// 지금 화면 보기 방식의 색.
  static PlateTone get now => FieldColors.isNight ? night : light;
}

String _f(double v) {
  var s = v.toStringAsFixed(1);
  if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
  return s;
}

/// 홀 크기 글(소수 둘째 자리까지, φ6.35).
String _f2(double v) {
  var s = v.toStringAsFixed(2);
  while (s.contains('.') && (s.endsWith('0') || s.endsWith('.'))) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

/// 전개도 그림의 자리 잡기(그리기와 화면 누름 찾기가 같이 쓴다).
class PlatePainterLayout {
  final PlatePlan plan;
  final double s, ox, oy, fontScale;
  const PlatePainterLayout._(
    this.plan,
    this.s,
    this.ox,
    this.oy,
    this.fontScale,
  );

  /// 그릴 수 없으면(크기 0 등) null.
  static PlatePainterLayout? of(
    PlatePlan p,
    Size size, {
    double fontScale = 1,
    bool holeDims = false,
  }) {
    final bw = math.max(p.maxX - p.minX, 1.0);
    final bh = math.max(p.maxY - p.minY, 1.0);
    final hd = holeDims && p.holes.isNotEmpty;
    final ml = 58.0 * fontScale, mt = 44.0 * fontScale;
    final mr = (hd ? 54.0 : 16.0) * fontScale;
    final mb = ((p.bends.isEmpty ? 16.0 : 44.0) + (hd ? 30.0 : 0)) * fontScale;
    final s = math.min(
      (size.width - ml - mr) / bw,
      (size.height - mt - mb) / bh,
    );
    if (s <= 0 || !s.isFinite) return null;
    final ox = ml + (size.width - ml - mr - bw * s) / 2;
    final oy = mt + (size.height - mt - mb - bh * s) / 2;
    return PlatePainterLayout._(p, s, ox, oy, fontScale);
  }

  /// 전개도 (x, y위) → 화면 (x, y아래).
  Offset toScreen(Offset q) =>
      Offset(ox + (q.dx - plan.minX) * s, oy + (plan.maxY - q.dy) * s);

  Offset toModel(Offset sc) =>
      Offset(plan.minX + (sc.dx - ox) / s, plan.maxY - (sc.dy - oy) / s);

  /// 판 왼쪽 위·오른쪽 아래(화면).
  Offset get topLeft => toScreen(Offset(plan.minX, plan.maxY));
  Offset get bottomRight => toScreen(Offset(plan.maxX, plan.minY));

  /// 전체 길이 치수선(위)의 y, 전체 폭 치수선(왼쪽)의 x.
  double get widthDimY => topLeft.dy - 24 * fontScale;
  double get heightDimX => topLeft.dx - 26 * fontScale;
}

class PlatePainter extends CustomPainter {
  final PlatePlan plan;
  final Color text, sub, bg;
  final double fontScale;

  PlatePainter({
    required this.plan,
    required this.text,
    required this.sub,
    required this.bg,
    this.fontScale = 1,
    this.showCenter = true,
    this.showIssues = true,
    this.holeDims = false,
    this.tone = PlateTone.light,
    this.holeSizes = false,
  });

  /// 홀 크기 글(10-11 사용자: "홀 크기 도면에 넣고 장공은 길이까지, 적용·미적용 버튼으로"): 같은 크기끼리 묶어
  /// 도면처럼 한 번만("4-φ13.5", "2-장공 13.5×40" = 폭 × 전체 길이), 홀에서 지시선을 뽑아 단다.
  final bool holeSizes;

  /// 홀 위치 치수(10-11): 판 왼쪽 끝·아래 끝에서 잰 홀 가운데 자리를 아래·오른쪽 줄에 단다(좌표 치수).
  final bool holeDims;

  /// 판 색(야간 보기는 어두운 철 색).
  final PlateTone tone;

  /// 만들 수 없는 홀은 빨강, 확인할 홀은 노랑 테두리(가공 도면 PDF에서는 끈다).
  final bool showIssues;

  /// 판 가운데 십자 중심선(켜고 끄기).
  final bool showCenter;

  @override
  void paint(Canvas canvas, Size size) {
    final p = plan;
    final lay = PlatePainterLayout.of(
      p,
      size,
      fontScale: fontScale,
      holeDims: holeDims,
    );
    if (lay == null) return;
    final s = lay.s;
    // 전개도 (x, y위) → 화면 (x, y아래)
    Offset m(Offset q) => lay.toScreen(q);

    final pts = plateOutlinePoints(p.outline);
    if (pts.length >= 3) {
      final path = Path()..moveTo(m(pts.first).dx, m(pts.first).dy);
      for (final q in pts.skip(1)) {
        path.lineTo(m(q).dx, m(q).dy);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = tone.fill);
      canvas.drawPath(
        path,
        Paint()
          ..color = tone.edge
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4 * fontScale,
      );
    }

    // 구멍·장공(뚫린 곳이라 바탕색)
    final holeEdge = Paint()
      ..color = tone.edge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1 * fontScale;
    for (final h in p.cutouts) {
      plateDrawHole(
        canvas,
        h,
        m(h.c),
        s,
        fill: bg,
        edgePaint: holeEdge,
        minR: 2.5 * fontScale,
      );
    }
    for (final h in p.holes) {
      plateDrawHole(
        canvas,
        h,
        m(h.c),
        s,
        fill: bg,
        edge: !showIssues
            ? null
            : (h.bad
                  ? const Color(0xFFD64545)
                  : (h.caution ? const Color(0xFFE0A21E) : null)),
        edgePaint: holeEdge,
        minR: 2.5 * fontScale,
      );
    }

    // 판 가운데 십자 중심선
    if (showCenter) {
      final cx = (p.minX + p.maxX) / 2;
      plateDrawCenterLines(
        canvas,
        toScreen: m,
        minX: p.minX,
        minY: p.minY,
        maxX: p.maxX,
        maxY: p.maxY,
        fontScale: fontScale,
        ext: 8,
        faintVertical: p.bends.any((b) => (b.center - cx).abs() < 1),
      );
    }

    // 꺾기선: 점선 + 위에 번호·방향
    final bendPaint = Paint()
      ..color = kPlateBend
      ..strokeWidth = 1.6 * fontScale;
    for (var n = 0; n < p.bends.length; n++) {
      final b = p.bends[n];
      var spans = plateBendSpans(pts, b.center);
      if (spans.isEmpty) spans = [(p.minY, p.maxY)];
      var label = spans.first;
      final dash = 6.0 * fontScale, gap = 4.0 * fontScale;
      for (final sp in spans) {
        if (sp.$2 - sp.$1 > label.$2 - label.$1) label = sp;
        final top = m(Offset(b.center, sp.$2)),
            bot = m(Offset(b.center, sp.$1));
        for (var y = top.dy; y < bot.dy; y += dash + gap) {
          canvas.drawLine(
            Offset(top.dx, y),
            Offset(top.dx, math.min(y + dash, bot.dy)),
            bendPaint,
          );
        }
      }
      _text(
        canvas,
        '${n + 1} ${b.turn >= 0 ? "UP" : "DOWN"} ${_f(b.turn.abs())}°',
        m(Offset(b.center, (label.$1 + label.$2) / 2)),
        -math.pi / 2,
        color: kPlateBend,
        bold: true,
      );
    }

    // 치수: 전체 길이(위), 전체 폭(왼쪽), 꺾기선 위치(아래, 왼쪽 끝에서)
    final dimPaint = Paint()
      ..color = sub
      ..strokeWidth = 1 * fontScale;
    void hDim(double x1, double x2, double y, String t) {
      final a = Offset(x1, y), b = Offset(x2, y);
      canvas.drawLine(a, b, dimPaint);
      final k = 4.0 * fontScale;
      for (final q in [a, b]) {
        canvas.drawLine(q + Offset(-k, k), q + Offset(k, -k), dimPaint);
      }
      _text(canvas, t, (a + b) / 2, 0, color: text, bold: true);
    }

    final left = lay.topLeft, right = lay.bottomRight;
    final topY = lay.widthDimY;
    canvas.drawLine(left, Offset(left.dx, topY - 4), dimPaint);
    canvas.drawLine(
      Offset(right.dx, left.dy),
      Offset(right.dx, topY - 4),
      dimPaint,
    );
    hDim(left.dx, right.dx, topY, _f(p.flatLength));
    final lx = lay.heightDimX;
    canvas.drawLine(
      Offset(left.dx, left.dy),
      Offset(lx - 4, left.dy),
      dimPaint,
    );
    canvas.drawLine(
      Offset(left.dx, right.dy),
      Offset(lx - 4, right.dy),
      dimPaint,
    );
    canvas.drawLine(Offset(lx, left.dy), Offset(lx, right.dy), dimPaint);
    final k = 4.0 * fontScale;
    for (final y in [left.dy, right.dy]) {
      canvas.drawLine(Offset(lx - k, y + k), Offset(lx + k, y - k), dimPaint);
    }
    _text(
      canvas,
      _f(p.flatWidth),
      Offset(lx, (left.dy + right.dy) / 2),
      -math.pi / 2,
      color: text,
      bold: true,
    );
    if (p.bends.isNotEmpty) {
      final by = right.dy + 24 * fontScale;
      var prev = left.dx;
      var prevMm = p.minX;
      for (final b in p.bends) {
        final x = m(Offset(b.center, 0)).dx;
        canvas.drawLine(Offset(x, right.dy), Offset(x, by + 4), dimPaint);
        hDim(prev, x, by, _f(b.center - prevMm));
        prev = x;
        prevMm = b.center;
      }
      canvas.drawLine(
        Offset(left.dx, right.dy),
        Offset(left.dx, by + 4),
        dimPaint,
      );
      canvas.drawLine(
        Offset(right.dx, right.dy),
        Offset(right.dx, by + 4),
        dimPaint,
      );
      hDim(prev, right.dx, by, _f(p.maxX - prevMm));
    }
    if (holeDims && p.holes.isNotEmpty) {
      _holeDims(
        canvas,
        lay,
        right.dy + (p.bends.isEmpty ? 24 : 52) * fontScale,
        right.dx + 20 * fontScale,
      );
    }
    if (holeSizes && p.holes.isNotEmpty) {
      _holeSizes(canvas, lay, size, pts, right.dx + 20 * fontScale);
    }
  }

  /// 홀 크기 글: 크기마다 묶어 한 홀에서 지시선(사선 + 짧은 가로선) 끝에 "n-φd" 글. 다른 글·홀·그림 밖과
  /// 겹치지 않는 홀·방향(오른쪽 위 → 왼쪽 위 → 오른쪽 아래 → 왼쪽 아래)을 차례로 찾는다.
  void _holeSizes(
    Canvas canvas,
    PlatePainterLayout lay,
    Size size,
    List<Offset> pts,
    double holeDimX,
  ) {
    final p = plan;
    final fsz = fontScale;
    final groups = plateHoleSizeGroups(p);
    double rOf(PlateHole h) => math.max(h.r * lay.s, 2.5 * fsz);
    final taken = <Rect>[
      for (final h in p.holes)
        Rect.fromPoints(lay.toScreen(h.p1), lay.toScreen(h.p2)).inflate(rOf(h)),
    ];
    // 글 자리: 전체 치수선(위·왼쪽) 안쪽, 판 아래 끝 위, 홀 위치 치수 줄(오른쪽) 왼쪽 — 치수 글과 안 겹치게
    final bounds = Rect.fromLTRB(
      lay.heightDimX + 9 * fsz,
      lay.widthDimY + 9 * fsz,
      holeDims ? holeDimX - 6 * fsz : size.width,
      lay.bottomRight.dy,
    );
    // 절곡 번호 글은 피한다(절곡선 점선은 지시선·글이 지나가도 된다)
    for (final b in p.bends) {
      var spans = plateBendSpans(pts, b.center);
      if (spans.isEmpty) spans = [(p.minY, p.maxY)];
      final sp = spans.reduce((a, c) => c.$2 - c.$1 > a.$2 - a.$1 ? c : a);
      taken.add(
        Rect.fromCenter(
          center: lay.toScreen(Offset(b.center, (sp.$1 + sp.$2) / 2)),
          width: 18 * fsz,
          height: 80 * fsz,
        ),
      );
    }
    final pen = Paint()
      ..color = text
      ..strokeWidth = 1 * fsz;
    const dirs = [Offset(1, -1), Offset(-1, -1), Offset(1, 1), Offset(-1, 1)];
    for (final (label, g) in groups) {
      final tp = _tp(label, text, bold: true);
      // 위쪽 홀부터(글이 판 위쪽 빈 곳으로 나가기 쉽게)
      final order = [...g]..sort((a, b) => b.c.dy.compareTo(a.c.dy));
      Rect? box;
      Offset? from, elbow, end;
      for (final h in order) {
        final r = rOf(h);
        for (final (d, lead) in [
          for (final l in const [14.0, 30.0, 48.0])
            for (final d in dirs) (d, l),
        ]) {
          final u = d / math.sqrt2;
          // 장공은 그쪽 끝 반원에서 뽑는다
          final q1 = lay.toScreen(h.p1), q2 = lay.toScreen(h.p2);
          final c = (q1.dx - q2.dx) * d.dx >= 0 ? q1 : q2;
          final a = c + u * r;
          final e = c + u * (r + lead * fsz);
          final sx = d.dx > 0 ? 1.0 : -1.0;
          final t = e + Offset(sx * 6 * fsz, 0);
          final rect = Rect.fromLTWH(
            sx > 0 ? t.dx + 2 * fsz : t.dx - 2 * fsz - tp.width - 6 * fsz,
            t.dy - tp.height / 2 - 1 * fsz,
            tp.width + 6 * fsz,
            tp.height + 2 * fsz,
          );
          if (!bounds.contains(rect.topLeft) ||
              !bounds.contains(rect.bottomRight)) {
            continue;
          }
          if (taken.any((q) => q.overlaps(rect))) continue;
          (box, from, elbow, end) = (rect, a, e, t);
          break;
        }
        if (box != null) break;
      }
      if (box == null) continue; // 둘 곳이 없으면 뺀다(크기는 홀 표에)
      taken.add(box);
      canvas.drawLine(from!, elbow!, pen);
      canvas.drawLine(elbow, end!, pen);
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, Radius.circular(3 * fsz)),
        Paint()..color = bg.withValues(alpha: 0.9),
      );
      tp.paint(canvas, box.topLeft + Offset(3 * fsz, 1 * fsz));
    }
  }

  /// 홀 좌표 치수: 아래 줄(판 왼쪽 끝에서 가로), 오른쪽 줄(판 아래 끝에서 세로). 같은 자리는 한 번만,
  /// 글이 겹치면 글만 뺀다(눈금은 남김, 값은 홀 표에). 홀에서 줄까지 옅은 점선.
  void _holeDims(Canvas canvas, PlatePainterLayout lay, double by, double rx) {
    final p = plan;
    final fsz = fontScale;
    double r1(double v) => (v * 10).roundToDouble() / 10;
    final xs = {for (final h in p.holes) r1(h.c.dx - p.minX)}.toList()..sort();
    final ys = {for (final h in p.holes) r1(h.c.dy - p.minY)}.toList()..sort();
    final line = Paint()
      ..color = sub
      ..strokeWidth = 1 * fsz;
    final faint = Paint()
      ..color = sub.withValues(alpha: 0.35)
      ..strokeWidth = 0.8 * fsz;
    void dashed(Offset a, Offset b) {
      final d = b - a, len = d.distance;
      if (len < 1) return;
      final u = d / len;
      for (var t = 0.0; t < len; t += 7 * fsz) {
        canvas.drawLine(a + u * t, a + u * math.min(t + 3.5 * fsz, len), faint);
      }
    }

    final tl = lay.topLeft, br = lay.bottomRight;
    // 홀 → 줄 점선
    for (final h in p.holes) {
      final c = lay.toScreen(h.c);
      dashed(Offset(c.dx, c.dy + 4 * fsz), Offset(c.dx, by));
      dashed(Offset(c.dx + 4 * fsz, c.dy), Offset(rx, c.dy));
    }
    // 아래 줄(가로)
    final xEnd = lay.toScreen(Offset(p.minX + xs.last, 0)).dx;
    canvas.drawLine(Offset(tl.dx, by), Offset(math.max(xEnd, tl.dx), by), line);
    var rowRight = -double.infinity;
    void xLabel(double mm, double x) {
      canvas.drawLine(Offset(x, by - 4 * fsz), Offset(x, by + 4 * fsz), line);
      final tp = _tp(_f(mm), sub, bold: true);
      final left = x - tp.width / 2;
      if (left > rowRight + 3 * fsz) {
        tp.paint(canvas, Offset(left, by + 5 * fsz));
        rowRight = left + tp.width;
      }
    }

    xLabel(0, tl.dx);
    for (final x in xs) {
      if (x.abs() < 0.05) continue;
      xLabel(x, lay.toScreen(Offset(p.minX + x, 0)).dx);
    }
    // 오른쪽 줄(세로)
    final yTop = lay.toScreen(Offset(0, p.minY + ys.last)).dy;
    canvas.drawLine(Offset(rx, br.dy), Offset(rx, math.min(yTop, br.dy)), line);
    var lastTop = double.infinity;
    void yLabel(double mm, double y) {
      canvas.drawLine(Offset(rx - 4 * fsz, y), Offset(rx + 4 * fsz, y), line);
      final tp = _tp(_f(mm), sub, bold: true);
      final top = y - tp.height / 2;
      if (top + tp.height + 1 * fsz < lastTop) {
        tp.paint(canvas, Offset(rx + 6 * fsz, top));
        lastTop = top;
      }
    }

    yLabel(0, br.dy);
    for (final y in ys) {
      if (y.abs() < 0.05) continue;
      yLabel(y, lay.toScreen(Offset(0, p.minY + y)).dy);
    }
  }

  TextPainter _tp(String s, Color color, {bool bold = false}) => TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(
        fontSize: 10.5 * fontScale,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        color: color,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  void _text(
    Canvas canvas,
    String s,
    Offset at,
    double angle, {
    bool bold = false,
    required Color color,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: 11.5 * fontScale,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset.zero,
        width: tp.width + 6,
        height: tp.height + 2,
      ),
      Paint()..color = bg.withValues(alpha: 0.85),
    );
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(PlatePainter old) =>
      old.holeSizes != holeSizes ||
      old.plan != plan ||
      old.text != text ||
      old.sub != sub ||
      old.bg != bg ||
      old.fontScale != fontScale ||
      old.showCenter != showCenter ||
      old.holeDims != holeDims ||
      old.tone != tone;
}

/// 구멍 하나 그리기: 둥근 구멍은 원, 장공은 [PlateHole.angle]만큼 돈 긴 구멍(화면은 y가 아래라 각을 뒤집는다).
void plateDrawHole(
  Canvas canvas,
  PlateHole h,
  Offset c,
  double s, {
  required Color fill,
  Color? edge,
  required Paint edgePaint,
  double minR = 2.5,
}) {
  final paint = edge == null
      ? edgePaint
      : (Paint()
          ..color = edge
          ..style = PaintingStyle.stroke
          ..strokeWidth = edgePaint.strokeWidth * 1.6);
  final r = math.max(h.dia / 2 * s, minR);
  if (h.slot <= 0) {
    canvas.drawCircle(c, r, Paint()..color = fill);
    canvas.drawCircle(c, r, paint);
    return;
  }
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(-h.angle * math.pi / 180);
  final rr = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: Offset.zero,
      width: math.max(h.slot * s, 2 * r),
      height: 2 * r,
    ),
    Radius.circular(r),
  );
  canvas.drawRRect(rr, Paint()..color = fill);
  canvas.drawRRect(rr, paint);
  canvas.restore();
}

/// 아무 그림이나 흰 바탕 PNG로(지시서 PDF에 넣는다).
Future<Uint8List> renderPainterPng(
  CustomPainter painter, {
  double width = 1400,
  double height = 800,
}) async {
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  canvas.drawRect(
    Offset.zero & Size(width, height),
    Paint()..color = Colors.white,
  );
  painter.paint(canvas, Size(width, height));
  final img = await rec.endRecording().toImage(width.toInt(), height.toInt());
  final bd = await img.toByteData(format: ui.ImageByteFormat.png);
  return bd!.buffer.asUint8List();
}

/// 판 가운데 십자 중심선 색(옅은 파랑: 빨강은 앱에서 "잘못됨" 색이라 경고처럼 보였다, 10-10 손봄).
const Color kPlateCenter = Color(0xFF4A7BD0);

/// 판 가운데 십자 중심선(10-10 사용자: "센터가 어디인지 안 보여서"): 판을 감싸는 사각의 가운데를 지나는
/// 가로·세로 1점 쇄선(긴 선·점)을 판 밖으로 [ext]점 더 내고, 오른쪽 끝에만 "C"를 단다(위쪽은 전체 치수와 겹쳐 뺌).
/// [faintVertical]이면 세로선을 옅게(꺾기선과 같은 자리일 때).
void plateDrawCenterLines(
  Canvas canvas, {
  required Offset Function(Offset mm) toScreen,
  required double minX,
  required double minY,
  required double maxX,
  required double maxY,
  Color color = kPlateCenter,
  double fontScale = 1,
  double ext = 10,
  bool faintVertical = false,
}) {
  final cx = (minX + maxX) / 2, cy = (minY + maxY) / 2;
  Paint pen(double a) => Paint()
    ..color = color.withValues(alpha: a)
    ..strokeWidth = 0.9 * fontScale;
  void dashDot(Offset a, Offset b, Paint paint) {
    final d = b - a, len = d.distance;
    if (len < 1) return;
    final u = d / len;
    final long = 12.0 * fontScale, gap = 3.0 * fontScale, dot = 2.0 * fontScale;
    var t = 0.0;
    while (t < len) {
      canvas.drawLine(a + u * t, a + u * math.min(t + long, len), paint);
      t += long + gap;
      if (t < len) {
        canvas.drawLine(a + u * t, a + u * math.min(t + dot, len), paint);
      }
      t += dot + gap;
    }
  }

  final e = ext * fontScale;
  final l = toScreen(Offset(minX, cy)) - Offset(e, 0);
  final r = toScreen(Offset(maxX, cy)) + Offset(e, 0);
  final t = toScreen(Offset(cx, maxY)) - Offset(0, e);
  final b = toScreen(Offset(cx, minY)) + Offset(0, e);
  dashDot(l, r, pen(0.8));
  dashDot(t, b, pen(faintVertical ? 0.3 : 0.8));
  final tp = TextPainter(
    text: TextSpan(
      text: 'C',
      style: TextStyle(
        fontSize: 10.5 * fontScale,
        fontWeight: FontWeight.w800,
        color: color,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, r + Offset(2, -tp.height / 2));
}

/// 홀 크기 글 묶음(그림·시험이 같이 쓴다): 같은 지름·장공 길이끼리 "4-φ13.5", "2-장공 13.5×40"(폭 × 전체 길이),
/// 하나면 "φ9". 처음 나온 차례대로.
List<(String, List<PlateHole>)> plateHoleSizeGroups(PlatePlan p) {
  final groups = <String, List<PlateHole>>{};
  for (final h in p.holes) {
    groups
        .putIfAbsent(
          '${_f2(h.dia)}|${h.slot > h.dia ? _f2(h.slot) : ''}',
          () => [],
        )
        .add(h);
  }
  return [
    for (final g in groups.values)
      () {
        final h = g.first;
        final name = h.slot > h.dia
            ? '장공 ${_f2(h.dia)}×${_f2(h.slot)}'
            : 'φ${_f2(h.dia)}';
        return (g.length > 1 ? '${g.length}-$name' : name, g);
      }(),
  ];
}
