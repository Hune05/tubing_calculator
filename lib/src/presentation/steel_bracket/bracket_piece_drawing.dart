// 형강 브라켓 부재도(10-11, 상용 앱 비교 5번): 토막 하나마다 자르는 사람이 그림만 보고 마킹할 수 있게 그린다.
//  · 형강: 위 = 옆에서 본 모양(길이·끝 각도·그림 폭, 붙는 면은 위쪽 가장자리), 아래 = 붙는 면(구멍 뚫는 면)에서 본 모양
//    (구멍 원·장공, 기준 끝에서 이어 잰 구멍 자리, 게이지). 기준 끝은 왼쪽.
//  · 판: 판 모양·구멍·기둥 자리(점선)·리브 자리, 가로·세로 구멍 자리. 리브: 삼각. 전산볼트: 길이.
//  · 화면 그림(BracketPainter)으로 그리고, 지시서 PDF에는 토막마다 한 장씩 들어간다.
library;

import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'bracket_calc.dart';

String _f(double v) {
  var s = v.toStringAsFixed(1);
  if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
  return s == '-0' ? '0' : s;
}

List<Offset> _rect(double x0, double y0, double x1, double y1) => [
  Offset(x0, y0),
  Offset(x1, y0),
  Offset(x1, y1),
  Offset(x0, y1),
];

/// 구멍 크기 글: "2-φ13.5", "2-장공 13.5×30".
String bracketHoleSizeText(List<PieceHole> hs) {
  final groups = <String, int>{};
  for (final h in hs) {
    final k = h.slotted ? '장공 ${_f(h.dia)}×${_f(h.slot)}' : 'φ${_f(h.dia)}';
    groups[k] = (groups[k] ?? 0) + 1;
  }
  return groups.entries.map((e) => '${e.value}-${e.key}').join(' · ');
}

/// 이어 재는 치수 줄: [xs](자리)를 차례로 이은 토막 치수들.
List<BracketDim> _chain(List<double> xs, double y, double off) {
  final out = <BracketDim>[];
  for (var k = 0; k + 1 < xs.length; k++) {
    if (xs[k + 1] - xs[k] < 0.05) continue;
    out.add(
      BracketDim(
        Offset(xs[k], y),
        Offset(xs[k + 1], y),
        off,
        _f(xs[k + 1] - xs[k]),
      ),
    );
  }
  return out;
}

List<BracketDim> _chainV(List<double> ys, double x, double off) {
  final out = <BracketDim>[];
  for (var k = 0; k + 1 < ys.length; k++) {
    if (ys[k + 1] - ys[k] < 0.05) continue;
    out.add(
      BracketDim(
        Offset(x, ys[k]),
        Offset(x, ys[k + 1]),
        off,
        _f(ys[k + 1] - ys[k]),
        vertical: true,
      ),
    );
  }
  return out;
}

/// 토막 하나의 부재도. [plate]는 판 토막일 때 판 정보(구멍·기둥 자리).
BracketDrawing bracketPieceDrawing(BracketPiece pc, {BracketPlate? plate}) {
  switch (pc.kind) {
    case BracketPieceKind.plate:
      return _plateDrawing(pc, plate);
    case BracketPieceKind.rib:
      final l = pc.length, h = pc.width;
      return BracketDrawing(
        polys: [
          BracketPoly([
            const Offset(0, 0),
            Offset(0, h),
            Offset(l, h),
          ], BracketFill.plate),
        ],
        dims: [
          BracketDim(Offset(0, h), Offset(l, h), 24, _f(l)),
          BracketDim(
            const Offset(0, 0),
            Offset(0, h),
            -24,
            _f(h),
            vertical: true,
          ),
        ],
        labels: [
          BracketLabel(
            Offset(l / 2, h),
            '두께 ${_f(pc.thick)} · 직각 쪽을 기둥·판에 붙임',
            shift: const Offset(0, 50),
          ),
        ],
      );
    case BracketPieceKind.rod:
      final m = pc.member;
      final d = m?.depth ?? 12;
      final l = pc.length;
      return BracketDrawing(
        polys: [BracketPoly(_rect(0, 0, l, d), BracketFill.rod)],
        lines: [
          BracketLine(
            Offset(-4, d / 2),
            Offset(l + 4, d / 2),
            BracketLineStyle.center,
          ),
        ],
        dims: [BracketDim(const Offset(0, 0), Offset(l, 0), -24, _f(l))],
        labels: [
          BracketLabel(
            Offset(l / 2, d),
            '${pc.ks} 전체 나사 · 가로대 위아래 너트·와셔',
            shift: const Offset(0, 30),
          ),
        ],
      );
    case BracketPieceKind.member:
      return _memberDrawing(pc);
  }
}

BracketDrawing _memberDrawing(BracketPiece pc) {
  final m = pc.member!;
  final v = m.view;
  final d = m.depth;
  // 따내기 전 모양 + 혀(단면에서 남는 띠마다 따로, 점검 39: 찬넬·H는 위아래 날개가 따로 남는다)
  // V컷 토막은 V 따내기가 든 펼친 모양
  final shape = m.local;
  final polys = <BracketPoly>[BracketPoly(shape, BracketFill.member)];
  for (final start in [true, false]) {
    for (final e in start ? m.extStart : m.extEnd) {
      if (e.ext <= 0) continue;
      for (final (ua, ub) in m.extStrips([e])) {
        final sp = bracketSpanAt(shape, (ua + ub) / 2);
        if (sp == null) continue;
        final x = start ? sp.$1 : sp.$2;
        polys.add(
          BracketPoly(
            start ? _rect(x - e.ext, ua, x, ub) : _rect(x, ua, x + e.ext, ub),
            BracketFill.member,
          ),
        );
      }
    }
  }
  final lines = <BracketLine>[];
  final holes = <BracketHoleMark>[];
  final dims = <BracketDim>[];
  final labels = <BracketLabel>[];
  final (ax0, ax1) = m.nearSpan;
  final (fx0, fx1) = m.farSpan;
  // 옆에서 본 모양: 길이 방향 선
  for (final u in v.lines) {
    final s = bracketSpanAt(shape, u);
    if (s == null) continue;
    lines.add(
      BracketLine(
        Offset(s.$1, u),
        Offset(s.$2, u),
        v.hollow ? BracketLineStyle.hidden : BracketLineStyle.solid,
      ),
    );
  }
  // V컷 꺾기: V 꼭짓점 자리(위 둘째 줄)와 표시
  if (pc.vNotches.isNotEmpty) {
    final ap = [...pc.vNotches]..sort();
    final (n0, n1) = m.nearSpan;
    final pts = [n0, ...ap, n1];
    for (var k = 0; k + 1 < pts.length; k++) {
      dims.add(
        BracketDim(
          Offset(pts[k], 0),
          Offset(pts[k + 1], 0),
          -50,
          _f(pts[k + 1] - pts[k]),
        ),
      );
    }
    for (final x in ap) {
      labels.add(
        BracketLabel(
          Offset(x, d - (d - v.attachT) * 0.3),
          'V 90°',
          shift: Offset.zero,
          bold: true,
        ),
      );
    }
  }
  final xs = <double>{for (final h in pc.holes) h.fromEnd}.toList()..sort();
  if (v.holesFront) {
    for (final h in pc.holes) {
      holes.add(BracketHoleMark(Offset(h.fromEnd, h.z), h.dia, slot: h.slot));
    }
  } else {
    for (final h in pc.holes) {
      if (h.z != pc.holes.firstWhere((q) => q.fromEnd == h.fromEnd).z) continue;
      for (final s in [-h.along / 2, h.along / 2]) {
        lines.add(
          BracketLine(
            Offset(h.fromEnd + s, 0),
            Offset(h.fromEnd + s, v.attachT),
            BracketLineStyle.hidden,
          ),
        );
      }
    }
  }
  // 길이: 붙는 쪽(위)이 위 줄, 반대쪽이 다르면 그 위 줄
  dims.add(BracketDim(Offset(ax0, 0), Offset(ax1, 0), -24, _f(ax1 - ax0)));
  if (((fx1 - fx0) - (ax1 - ax0)).abs() > 0.05) {
    dims.add(
      BracketDim(Offset(fx0, d), Offset(fx1, d), -50, _f(fx1 - fx0), base: 0),
    );
  }
  dims.add(
    BracketDim(
      Offset(math.min(ax0, fx0), 0),
      Offset(math.min(ax0, fx0), d),
      -22,
      _f(d),
      vertical: true,
    ),
  );
  // 끝 각도
  for (final start in [true, false]) {
    final a = m.endAngle(start);
    if (a < 0.05) continue;
    final x = start ? (ax0 + fx0) / 2 : (ax1 + fx1) / 2;
    labels.add(
      BracketLabel(
        Offset(x, d / 2),
        '${_f(a)}°',
        shift: Offset(start ? -40 : 40, 0),
        bold: true,
      ),
    );
  }
  if (v.holesFront && pc.holes.isNotEmpty) {
    final g = pc.holes.first.z;
    dims.add(
      BracketDim(Offset(ax1, 0), Offset(ax1, g), 22, _f(g), vertical: true),
    );
    dims.addAll(_chain([ax0, ...xs, ax1], d, 24));
    labels.add(
      BracketLabel(
        Offset((ax0 + ax1) / 2, d),
        '${bracketHoleSizeText(pc.holes)} (기준: ${pc.holeFrom})',
        shift: const Offset(0, 54),
      ),
    );
  }
  // 붙는 면에서 본 모양(구멍이 있거나 벽·위에 붙는 부재, 따내기가 있는 부재, 점검 38)
  final face =
      !v.holesFront &&
      !v.round &&
      (pc.holes.isNotEmpty ||
          m.role != BracketRole.none ||
          m.extStart.isNotEmpty ||
          m.extEnd.isNotEmpty);
  if (face) {
    final w = v.width;
    final gap = math.max(d * 0.6, 24.0);
    final y0 = d + gap;
    if (m.extStart.isEmpty && m.extEnd.isEmpty) {
      polys.add(BracketPoly(_rect(ax0, y0, ax1, y0 + w), BracketFill.member));
    } else {
      // 깊이 구간마다 끝 자리가 다르다(따낸 곳은 짧게)
      final (b0, b1) = m.baseNear;
      final zs = <double>{
        0,
        w,
        for (final e in [...m.extStart, ...m.extEnd]) ...[e.z0, e.z1],
      }.where((z) => z >= 0 && z <= w).toList()..sort();
      final right = <Offset>[], left = <Offset>[];
      for (var k = 0; k + 1 < zs.length; k++) {
        final zm = (zs[k] + zs[k + 1]) / 2;
        final xr = b1 + bracketExtAt(m.extEnd, zm);
        final xl = b0 - bracketExtAt(m.extStart, zm);
        right.addAll([Offset(xr, y0 + zs[k]), Offset(xr, y0 + zs[k + 1])]);
        left.addAll([Offset(xl, y0 + zs[k]), Offset(xl, y0 + zs[k + 1])]);
      }
      polys.add(BracketPoly([...right, ...left.reversed], BracketFill.member));
      final txt = [
        if (m.extStartMax > 0) '${m.endNames.$1} ${_f(m.extStartMax)}',
        if (m.extEndMax > 0) '${m.endNames.$2} ${_f(m.extEndMax)}',
      ].join(' · ');
      labels.add(
        BracketLabel(
          Offset((ax0 + ax1) / 2, y0),
          '따냄: $txt (그림에 그린 혀만 남기고 나머지는 잘라 냄)',
          shift: const Offset(0, -12),
        ),
      );
    }
    final zl = <double>{
      if (v.twoLines) ...[(w - v.web) / 2, (w + v.web) / 2],
      if (!v.twoLines) ...[v.zone.$1, v.zone.$2],
    }.where((z) => z > 0.05 && z < w - 0.05);
    for (final z in zl) {
      lines.add(
        BracketLine(
          Offset(ax0, y0 + z),
          Offset(ax1, y0 + z),
          BracketLineStyle.hidden,
        ),
      );
    }
    for (final h in pc.holes) {
      holes.add(
        BracketHoleMark(Offset(h.fromEnd, y0 + h.z), h.dia, slot: h.slot),
      );
      lines.add(
        BracketLine(
          Offset(h.fromEnd, y0 + h.z - h.dia / 2 - 3),
          Offset(h.fromEnd, y0 + h.z + h.dia / 2 + 3),
          BracketLineStyle.center,
        ),
      );
    }
    dims.add(
      BracketDim(
        Offset(ax0, y0),
        Offset(ax0, y0 + w),
        -22,
        _f(w),
        vertical: true,
      ),
    );
    final (nb0, nb1) = m.baseNear;
    final marks = <double>[
      ax0,
      if (m.extStartMax > 0) nb0,
      ...xs,
      if (m.extEndMax > 0) nb1,
      ax1,
    ]..sort();
    if (pc.holes.isEmpty && (m.extStartMax > 0 || m.extEndMax > 0)) {
      dims.addAll(_chain(marks, y0 + w, 24));
    }
    if (pc.holes.isNotEmpty) {
      dims.addAll(_chain(marks, y0 + w, 24));
      // U볼트 구멍: 관 중심에 가운데 선과 관 이름(구멍 한 쌍이 그 관 자리)
      final pipeSeen = <double>{};
      for (final h in pc.holes) {
        final at = h.pipeAt;
        if (at == null || !pipeSeen.add((at * 10).roundToDouble())) continue;
        lines.add(
          BracketLine(
            Offset(at, y0 - 6),
            Offset(at, y0 + w + 6),
            BracketLineStyle.center,
          ),
        );
        labels.add(
          // 관 이름은 붙는 면 아래쪽 안(위쪽은 따냄 글 자리)
          BracketLabel(
            Offset(at, y0 + w),
            h.pipe ?? '',
            shift: const Offset(0, -11),
            minor: true,
          ),
        );
      }
      final zs = <double>{for (final h in pc.holes) h.z}.toList()..sort();
      dims.add(
        BracketDim(
          Offset(ax1, y0),
          Offset(ax1, y0 + zs.first),
          22,
          _f(zs.first),
          vertical: true,
        ),
      );
      if (zs.length > 1) {
        dims.add(
          BracketDim(
            Offset(ax1, y0 + zs.last),
            Offset(ax1, y0 + w),
            22,
            _f(w - zs.last),
            vertical: true,
          ),
        );
      }
      labels.add(
        BracketLabel(
          Offset((ax0 + ax1) / 2, y0 + w),
          '${bracketHoleSizeText(pc.holes)} · ${pc.holeFace} · 기준 ${pc.holeFrom}(왼쪽)',
          shift: const Offset(0, 54),
        ),
      );
    } else {
      labels.add(
        BracketLabel(
          Offset((ax0 + ax1) / 2, y0 + w),
          '${pc.holeFace} (홀 없음)',
          shift: const Offset(0, 22),
        ),
      );
    }
  }
  return BracketDrawing(
    polys: polys,
    lines: lines,
    holes: holes,
    dims: dims,
    labels: labels,
  );
}

BracketDrawing _plateDrawing(BracketPiece pc, BracketPlate? pl) {
  final w = pc.length, l = pc.width;
  final polys = <BracketPoly>[
    BracketPoly(_rect(0, 0, w, l), BracketFill.plate),
  ];
  final lines = <BracketLine>[];
  final holes = <BracketHoleMark>[];
  final dims = <BracketDim>[];
  if (pl != null) {
    for (final r in [...pl.footprint, ...pl.ribs]) {
      for (var k = 0; k < r.length; k++) {
        lines.add(
          BracketLine(r[k], r[(k + 1) % r.length], BracketLineStyle.hidden),
        );
      }
    }
  }
  for (final h in pc.holes) {
    holes.add(BracketHoleMark(Offset(h.fromEnd, h.z), h.dia));
    lines.add(
      BracketLine(
        Offset(h.fromEnd - h.dia / 2 - 3, h.z),
        Offset(h.fromEnd + h.dia / 2 + 3, h.z),
        BracketLineStyle.center,
      ),
    );
    lines.add(
      BracketLine(
        Offset(h.fromEnd, h.z - h.dia / 2 - 3),
        Offset(h.fromEnd, h.z + h.dia / 2 + 3),
        BracketLineStyle.center,
      ),
    );
  }
  dims.add(BracketDim(const Offset(0, 0), Offset(w, 0), -24, _f(w)));
  dims.add(
    BracketDim(const Offset(0, 0), Offset(0, l), -24, _f(l), vertical: true),
  );
  if (pc.holes.isNotEmpty) {
    final xs = <double>{for (final h in pc.holes) h.fromEnd}.toList()..sort();
    final ys = <double>{for (final h in pc.holes) h.z}.toList()..sort();
    dims.addAll(_chain([0, ...xs, w], l, 24));
    dims.addAll(_chainV([0, ...ys, l], w, 24));
  }
  return BracketDrawing(
    polys: polys,
    lines: lines,
    holes: holes,
    dims: dims,
    labels: [
      BracketLabel(
        Offset(w / 2, l),
        '두께 ${_f(pc.thick)}${pc.holes.isEmpty ? '' : ' · ${bracketHoleSizeText(pc.holes)}'} · 점선은 ${pl?.wall == true ? '기둥' : '기둥·리브'} 자리',
        shift: const Offset(0, 54),
      ),
    ],
  );
}
