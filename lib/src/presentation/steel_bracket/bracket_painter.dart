// 형강 브라켓 그림(10-10, 10-11 개편): bracket_calc.dart(조립도)·bracket_piece_drawing.dart(부재도)가 만든 모양·선·구멍·
// 치수·용접 기호·품번 풍선·단면 표시를 실제 비율로 그린다. 화면과 가공 지시서 PDF(그림을 PNG로 떠서 넣음)가 같은 그림을 쓴다.
//  · 선: 실선(외형·다른 변), 숨은선(그림 면과 직각인 면의 구멍·판 속), 중심선(구멍 중심·전산볼트).
//  · 용접 기호(KS B 0052·ISO 2553 꼴): 화살표 → 기준선, 기준선 아래 필릿 삼각(화살표 쪽), 앞에 각장 "z5", 꺾이는 곳 원은 전둘레.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart' show kAppFontFamily;
import 'bracket_calc.dart';

const Color kBracketSteel = Color(0xFFB8C4CC);
const Color kBracketSteelEdge = Color(0xFF55636D);
const Color kBracketPlate = Color(0xFF94A3AE);
const Color kBracketWeld = Color(0xFFE08A1E);

/// 철 색(밝은 화면·야간).
class BracketTone {
  final Color steel, plate, edge, rod;
  const BracketTone(this.steel, this.plate, this.edge, this.rod);
  static const light = BracketTone(
    kBracketSteel,
    kBracketPlate,
    kBracketSteelEdge,
    Color(0xFF8C979F),
  );
  static const night = BracketTone(
    Color(0xFF4A5761),
    Color(0xFF3B464E),
    Color(0xFFAEBCC6),
    Color(0xFF5E6C76),
  );
}

class BracketPainter extends CustomPainter {
  final BracketDrawing drawing;
  final Color text, sub, bg;
  final BracketTone tone;

  /// 글씨 크기 배수(PDF용 큰 그림에서 키운다).
  final double fontScale;

  /// 그림 여백 위쪽 더(그림 칸 위 단추 자리).
  final double topInset;

  BracketPainter({
    required this.drawing,
    required this.text,
    required this.sub,
    required this.bg,
    this.tone = BracketTone.light,
    this.fontScale = 1,
    this.topInset = 0,
    this.bottomInset = 0,
  });

  /// 그림 여백 아래쪽 더(그림 칸 아래 안내 글 자리).
  final double bottomInset;

  @override
  void paint(Canvas canvas, Size size) {
    final fs = fontScale;
    // 휴대폰 그림 칸처럼 작으면 용접은 작은 삼각만, 풍선은 작게(기호·각장은 PDF·큰 화면에)
    final compact = fs == 1 && size.width < 520;
    final (x0, y0, x1, y1) = drawing.bounds();
    final secW = drawing.sections.isEmpty ? 0.0 : 84.0 * fs;
    // 여백: 왼쪽·위는 치수선 두 줄과 글, 아래는 치수·글, 오른쪽은 단면 칸.
    final ml = 84.0 * fs, mt = 70.0 * fs + topInset;
    final mr = 44.0 * fs + secW, mb = 72.0 * fs + bottomInset;
    final bw = math.max(x1 - x0, 1.0), bh = math.max(y1 - y0, 1.0);
    final s = math.min(
      (size.width - ml - mr) / bw,
      (size.height - mt - mb) / bh,
    );
    if (s <= 0 || !s.isFinite) return;
    final ox = ml + (size.width - ml - mr - bw * s) / 2 - x0 * s;
    final oy = mt + (size.height - mt - mb - bh * s) / 2 - y0 * s;
    Offset m(Offset p) => Offset(ox + p.dx * s, oy + p.dy * s);

    Path poly(List<Offset> pts) {
      final path = Path()..moveTo(m(pts.first).dx, m(pts.first).dy);
      for (final p in pts.skip(1)) {
        path.lineTo(m(p).dx, m(p).dy);
      }
      return path..close();
    }

    final edge = Paint()
      ..color = tone.edge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * fs;
    // 천장(빗금)
    for (final p in drawing.polys.where((p) => p.fill == BracketFill.ceiling)) {
      final r = poly(p.pts).getBounds();
      canvas.drawLine(r.bottomLeft, r.bottomRight, edge);
      final hatch = Paint()
        ..color = sub
        ..strokeWidth = 1 * fs;
      for (var x = r.left; x < r.right; x += 9 * fs) {
        canvas.drawLine(
          Offset(x, r.bottom),
          Offset(x + 7 * fs, r.bottom - 7 * fs),
          hatch,
        );
      }
    }
    for (final fill in [
      BracketFill.plate,
      BracketFill.member,
      BracketFill.rod,
      BracketFill.nut,
    ]) {
      for (final p in drawing.polys.where((p) => p.fill == fill)) {
        final path = poly(p.pts);
        canvas.drawPath(
          path,
          Paint()
            ..color = switch (fill) {
              BracketFill.plate => tone.plate,
              BracketFill.rod || BracketFill.nut => tone.rod,
              _ => tone.steel,
            },
        );
        canvas.drawPath(path, edge);
      }
    }

    // 선
    final thin = Paint()
      ..color = tone.edge
      ..strokeWidth = 1.0 * fs;
    final dash = Paint()
      ..color = tone.edge.withValues(alpha: 0.85)
      ..strokeWidth = 1.0 * fs;
    final center = Paint()
      ..color = const Color(0xFF3B82C4).withValues(alpha: 0.85)
      ..strokeWidth = 0.8 * fs;
    for (final l in drawing.lines) {
      final a = m(l.a), b = m(l.b);
      switch (l.style) {
        case BracketLineStyle.solid:
          canvas.drawLine(a, b, thin);
        case BracketLineStyle.hidden:
          _dashed(canvas, a, b, dash, [4 * fs, 3 * fs]);
        case BracketLineStyle.center:
          _dashed(canvas, a, b, center, [9 * fs, 2.5 * fs, 2 * fs, 2.5 * fs]);
      }
    }

    // 보이는 구멍: 흰 원(장공은 길쭉) + 가운데 십자
    for (final h in drawing.holes) {
      final c = m(h.at);
      final r = math.max(h.dia / 2 * s, 3.0 * fs);
      final hole = Paint()..color = bg;
      if (h.slot > h.dia) {
        final u = h.dir / math.max(h.dir.distance, 1e-9);
        final half = (h.slot - h.dia) / 2 * s;
        final path = Path();
        final ang = math.atan2(u.dy, u.dx);
        final c1 = c - u * half, c2 = c + u * half;
        path.addArc(
          Rect.fromCircle(center: c2, radius: r),
          ang - math.pi / 2,
          math.pi,
        );
        path.arcTo(
          Rect.fromCircle(center: c1, radius: r),
          ang + math.pi / 2,
          math.pi,
          false,
        );
        path.close();
        canvas.drawPath(path, hole);
        canvas.drawPath(path, edge);
      } else {
        canvas.drawCircle(c, r, hole);
        canvas.drawCircle(c, r, edge);
      }
      final cross = Paint()
        ..color = tone.edge
        ..strokeWidth = 0.8 * fs;
      canvas.drawLine(c - Offset(r + 3, 0), c + Offset(r + 3, 0), cross);
      canvas.drawLine(c - Offset(0, r + 3), c + Offset(0, r + 3), cross);
    }

    // 치수선: 가로 치수는 위·아래, 세로 치수는 왼쪽·오른쪽에 화면 점으로 띄운다(작은 화면에서도 같은 간격).
    final dimPaint = Paint()
      ..color = sub
      ..strokeWidth = 1 * fs;
    void ext(Offset from, Offset to) {
      final v = to - from;
      final len = v.distance;
      if (len < 1) return;
      final u = v / len;
      canvas.drawLine(from + u * 3, to + u * 4, dimPaint);
    }

    for (final dm in drawing.dims) {
      final a = m(dm.a), b = m(dm.b);
      final o = dm.offset * fs;
      final Offset pa, pb;
      if (dm.vertical) {
        final bx = dm.base == null
            ? (o < 0 ? math.min(a.dx, b.dx) : math.max(a.dx, b.dx))
            : m(Offset(dm.base!, 0)).dx;
        pa = Offset(bx + o, a.dy);
        pb = Offset(bx + o, b.dy);
      } else {
        final by = dm.base == null
            ? (o < 0 ? math.min(a.dy, b.dy) : math.max(a.dy, b.dy))
            : m(Offset(0, dm.base!)).dy;
        pa = Offset(a.dx, by + o);
        pb = Offset(b.dx, by + o);
      }
      if ((pb - pa).distance < 1) continue;
      ext(a, pa);
      ext(b, pb);
      canvas.drawLine(pa, pb, dimPaint);
      final u = (pb - pa) / (pb - pa).distance;
      final n = Offset(-u.dy, u.dx);
      final t = 4.0 * fs;
      for (final p in [pa, pb]) {
        canvas.drawLine(p - (u + n) * t, p + (u + n) * t, dimPaint);
      }
      _text(
        canvas,
        dm.text,
        (pa + pb) / 2,
        dm.vertical ? -math.pi / 2 : 0,
        bold: true,
        color: text,
      );
    }

    // 용접 기호
    final wp = Paint()
      ..color = kBracketWeld
      ..strokeWidth = 1.3 * fs
      ..style = PaintingStyle.stroke;
    final weldCount = <String, int>{};
    for (final w in drawing.welds) {
      weldCount[w.what] = (weldCount[w.what] ?? 0) + 1;
    }
    for (final w in drawing.welds) {
      if (!w.show && !compact) continue;
      final at = m(w.at);
      if (compact) {
        const k = 4.5;
        canvas.drawPath(
          Path()
            ..moveTo(at.dx, at.dy - k)
            ..lineTo(at.dx + k, at.dy + k * 0.8)
            ..lineTo(at.dx - k, at.dy + k * 0.8)
            ..close(),
          Paint()..color = kBracketWeld,
        );
        continue;
      }
      final dl = w.dir.distance;
      if (dl < 1e-9) continue;
      final u = w.dir / dl;
      final knee = at + u * (26 * fs);
      final sx = u.dx >= 0 ? 1.0 : -1.0;
      final end = knee + Offset(sx * 40 * fs, 0);
      canvas.drawLine(at, knee, wp);
      canvas.drawLine(knee, end, wp);
      // 화살촉
      final ah = 6 * fs;
      final nrm = Offset(-u.dy, u.dx);
      canvas.drawPath(
        Path()
          ..moveTo(at.dx, at.dy)
          ..lineTo(
            (at + u * ah + nrm * ah * 0.45).dx,
            (at + u * ah + nrm * ah * 0.45).dy,
          )
          ..lineTo(
            (at + u * ah - nrm * ah * 0.45).dx,
            (at + u * ah - nrm * ah * 0.45).dy,
          )
          ..close(),
        Paint()..color = kBracketWeld,
      );
      final tx = math.min(knee.dx, end.dx) + 18 * fs;
      final k = 7 * fs;
      if (w.groove) {
        // V 홈 맞대기(기준선 아래 V, 점검 24)
        canvas.drawPath(
          Path()
            ..moveTo(tx, knee.dy + k)
            ..lineTo(tx + k / 2, knee.dy)
            ..lineTo(tx + k, knee.dy + k),
          wp,
        );
      } else {
        // 필릿 삼각(기준선 아래, 세운 변이 왼쪽)
        canvas.drawPath(
          Path()
            ..moveTo(tx, knee.dy)
            ..lineTo(tx, knee.dy + k)
            ..lineTo(tx + k, knee.dy)
            ..close(),
          wp,
        );
      }
      if (w.allAround) canvas.drawCircle(knee, 3.5 * fs, wp);
      final n = weldCount[w.what] ?? 1;
      if (!w.groove) {
        _text(
          canvas,
          'z${_fmt(w.size)}',
          Offset(tx - 9 * fs, knee.dy + 7 * fs),
          0,
          bold: true,
          color: kBracketWeld,
          size: 10.5,
          box: false,
        );
      }
      // 같은 이음이 여러 곳이면 기준선 끝 위에 "2곳"
      if (n > 1) {
        _text(
          canvas,
          '$n곳',
          Offset(math.max(knee.dx, end.dx) - 10 * fs, knee.dy - 7 * fs),
          0,
          bold: true,
          color: kBracketWeld,
          size: 10.5,
          box: false,
        );
      }
    }

    // 품번 풍선: 앞 풍선과 겹치거나 그림 밖이면 방향을 돌리고 지시선을 늘려 비킨다(점검 42)
    final placed = <Offset>[];
    for (final b in drawing.balloons) {
      final at = m(b.at);
      final dl = b.dir.distance;
      final u0 = dl < 1e-9 ? const Offset(1, 0) : b.dir / dl;
      final r = (compact ? 9.0 : 11.0) * fs;
      final lead = (compact ? 18 : 30) * fs;
      final a0 = math.atan2(u0.dy, u0.dx);
      var u = u0;
      var c = at + u0 * (lead + r);
      bool clear(Offset q) =>
          placed.every((p) => (p - q).distance > 2 * r + 4 * fs) &&
          q.dx > r &&
          q.dy > topInset + r &&
          q.dx < size.width - secW - r &&
          q.dy < size.height - bottomInset - r;
      search:
      for (final grow in const [1.0, 1.6, 2.2]) {
        for (final da in const [0.0, 0.45, -0.45, 0.9, -0.9, 1.35, -1.35]) {
          final uu = Offset(math.cos(a0 + da), math.sin(a0 + da));
          final cc = at + uu * (lead * grow + r);
          if (clear(cc)) {
            u = uu;
            c = cc;
            break search;
          }
        }
      }
      placed.add(c);
      final lp = Paint()
        ..color = text
        ..strokeWidth = 1 * fs;
      canvas.drawCircle(at, 2.2 * fs, Paint()..color = text);
      canvas.drawLine(at, c - u * r, lp);
      canvas.drawCircle(c, r, Paint()..color = bg);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = text
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4 * fs,
      );
      _text(canvas, '${b.mark}', c, 0, bold: true, color: text, box: false);
    }

    for (final l in drawing.labels) {
      if (compact && l.minor) continue;
      _text(
        canvas,
        l.text,
        m(l.at) + l.shift * fs,
        0,
        color: l.bold ? text : sub,
        bold: l.bold,
      );
    }

    // 단면 칸(오른쪽): 품번 단면을 실제 방향으로, 붙는 쪽은 굵은 선
    if (drawing.sections.isNotEmpty) {
      final bx = size.width - secW - 8 * fs;
      var by = mt;
      for (final sm in drawing.sections) {
        final box = Rect.fromLTWH(bx, by + 16 * fs, secW - 4 * fs, 60 * fs);
        if (box.bottom > size.height) break;
        _text(
          canvas,
          '${bracketMarkText(sm.mark)} 단면',
          Offset(box.center.dx, by + 7 * fs),
          0,
          bold: true,
          color: text,
          box: false,
          size: 11,
        );
        _section(canvas, sm, box.deflate(10 * fs));
        by += 92 * fs;
      }
    }
  }

  void _section(Canvas canvas, BracketSectionMark sm, Rect box) {
    final v = sm.view;
    // 세로 부재(기둥): u → 오른쪽, z → 아래. 가로 부재(가로대): u → 아래, z → 오른쪽.
    final du = v.depth, dz = v.width;
    final w = sm.vertical ? du : dz, h = sm.vertical ? dz : du;
    final sc = math.min(box.width / w, box.height / h);
    if (!sc.isFinite || sc <= 0) return;
    final o = box.center - Offset(w * sc / 2, h * sc / 2);
    Offset map(double u, double z) => sm.vertical
        ? o + Offset((sm.flip ? du - u : u) * sc, z * sc)
        : o + Offset(z * sc, u * sc);
    final fill = Paint()..color = tone.steel;
    final line = Paint()
      ..color = tone.edge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 * fontScale;
    if (v.round) {
      canvas.drawCircle(box.center, du * sc / 2, fill);
      canvas.drawCircle(box.center, du * sc / 2, line);
      return;
    }
    for (final r in v.rects) {
      final a = map(r.left, r.top), b = map(r.right, r.bottom);
      final rr = Rect.fromPoints(a, b);
      canvas.drawRect(rr, fill);
      canvas.drawRect(rr, line);
    }
    // 붙는 쪽: 굵은 선 + 이름
    final a = map(0, -dz * 0.08), b = map(0, dz * 1.08);
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = kBracketWeld
        ..strokeWidth = 2.4 * fontScale,
    );
    final mid = (a + b) / 2;
    // 가로 부재(위가 붙는 쪽)는 선 왼쪽 끝 옆에(위에 두면 "단면" 제목과 겹쳤다, 10-11 실기기)
    final off = sm.vertical
        ? Offset(-12 * fontScale, 0)
        : a - mid + Offset(-10 * fontScale, 0);
    _text(
      canvas,
      sm.side,
      mid + off,
      0,
      color: kBracketWeld,
      bold: true,
      box: false,
      size: 10,
    );
  }

  void _dashed(Canvas canvas, Offset a, Offset b, Paint p, List<double> pat) {
    final len = (b - a).distance;
    if (len < 0.5) return;
    final u = (b - a) / len;
    var d = 0.0;
    var k = 0;
    while (d < len) {
      final seg = pat[k % pat.length];
      if (k.isEven) {
        canvas.drawLine(a + u * d, a + u * math.min(d + seg, len), p);
      }
      d += seg;
      k++;
    }
  }

  void _text(
    Canvas canvas,
    String s,
    Offset at,
    double angle, {
    bool bold = false,
    required Color color,
    bool box = true,
    double size = 12,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontFamily: kAppFontFamily,
          fontSize: size * fontScale,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    // 글이 거꾸로 서지 않게(오른쪽에서 왼쪽·아래에서 위로 가는 선)
    var a = angle;
    if (a > math.pi / 2) a -= math.pi;
    if (a < -math.pi / 2) a += math.pi;
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(a);
    if (box) {
      final r = Rect.fromCenter(
        center: Offset.zero,
        width: tp.width + 6,
        height: tp.height + 2,
      );
      canvas.drawRect(r, Paint()..color = bg.withValues(alpha: 0.85));
    }
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(BracketPainter old) =>
      old.drawing != drawing ||
      old.text != text ||
      old.sub != sub ||
      old.bg != bg ||
      old.tone != tone ||
      old.fontScale != fontScale ||
      old.topInset != topInset ||
      old.bottomInset != bottomInset;
}

String _fmt(double v) {
  var s = v.toStringAsFixed(1);
  if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
  return s;
}

/// 지시서 PDF에 넣을 그림(흰 바탕 PNG).
Future<Uint8List> renderBracketPng(
  BracketDrawing drawing, {
  double width = 1400,
  double height = 900,
}) async {
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  canvas.drawRect(
    Offset.zero & Size(width, height),
    Paint()..color = Colors.white,
  );
  BracketPainter(
    drawing: drawing,
    text: const Color(0xFF1F2933),
    sub: const Color(0xFF55636D),
    bg: Colors.white,
    fontScale: 2.2,
  ).paint(canvas, Size(width, height));
  final img = await rec.endRecording().toImage(width.toInt(), height.toInt());
  final bd = await img.toByteData(format: ui.ImageByteFormat.png);
  return bd!.buffer.asUint8List();
}
