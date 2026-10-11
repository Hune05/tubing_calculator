// 철판 가공 DXF(10-10): 레이저 업체에 보내는 전개도 파일. AutoCAD R12(AC1009) 글 형식, 단위 mm.
//  · 층(레이어): CUT = 외곽·구멍·장공(자를 선), BEND = 꺾기선(가운데 선, 자르지 않음), NOTE = 꺾는 방향 글(영문),
//    DIM = 판 가운데 십자 중심선(CL, 자르지 않음, 10-10).
//  · 글은 업체 프로그램에서 깨지지 않게 영문·숫자만 쓴다("BEND 1 UP 90 R3").
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'plate_calc.dart';

String _n(double v) {
  final s = v.toStringAsFixed(4);
  return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
}

class _Dxf {
  final b = StringBuffer();
  void pair(int code, Object v) => b
    ..write(code)
    ..write('\n')
    ..write(v)
    ..write('\n');

  void line(String layer, double x1, double y1, double x2, double y2) {
    pair(0, 'LINE');
    pair(8, layer);
    pair(10, _n(x1));
    pair(20, _n(y1));
    pair(30, 0);
    pair(11, _n(x2));
    pair(21, _n(y2));
    pair(31, 0);
  }

  void circle(String layer, double x, double y, double r) {
    pair(0, 'CIRCLE');
    pair(8, layer);
    pair(10, _n(x));
    pair(20, _n(y));
    pair(30, 0);
    pair(40, _n(r));
  }

  /// 반시계로 [a0]°에서 [a1]°까지.
  void arc(String layer, double x, double y, double r, double a0, double a1) {
    pair(0, 'ARC');
    pair(8, layer);
    pair(10, _n(x));
    pair(20, _n(y));
    pair(30, 0);
    pair(40, _n(r));
    pair(50, _n(a0));
    pair(51, _n(a1));
  }

  void text(
    String layer,
    double x,
    double y,
    double h,
    String s, {
    double rot = 0,
  }) {
    pair(0, 'TEXT');
    pair(8, layer);
    pair(10, _n(x));
    pair(20, _n(y));
    pair(30, 0);
    pair(40, _n(h));
    pair(1, s);
    if (rot != 0) pair(50, _n(rot));
  }
}

double _norm(double deg) {
  var d = deg % 360;
  if (d < 0) d += 360;
  return d;
}

/// 전개도 DXF 글.
/// [centerLines]가 false면 판 가운데 십자 중심선(DIM 층 CL)을 넣지 않는다(그림 "센터선"과 같게, 10-11).
String plateDxf(
  PlatePlan p, {
  required double thickness,
  bool centerLines = true,
}) {
  final d = _Dxf();
  d.pair(0, 'SECTION');
  d.pair(2, 'HEADER');
  d.pair(9, r'$ACADVER');
  d.pair(1, 'AC1009');
  // 단위 mm. R12에는 없던 항목이지만 AutoCAD·대부분의 CAM은 모르는 항목을 건너뛰고, 읽는 프로그램은
  // 단위를 바로 안다(10-11 점검 67에서 그대로 두기로 함).
  d.pair(9, r'$INSUNITS');
  d.pair(70, 4); // mm
  d.pair(0, 'ENDSEC');
  // 층 정의(점검 67): 색·선 종류가 없어 CUT·BEND·DIM이 다 같은 흰 실선이었다. 색·선으로 자를 선을 고르는
  // CAM에서 절곡선·센터선까지 잘릴 수 있어, 자르는 CUT만 흰 실선, BEND 빨간 파선, DIM 초록 일점 쇄선, NOTE 노랑.
  d.pair(0, 'SECTION');
  d.pair(2, 'TABLES');
  d.pair(0, 'TABLE');
  d.pair(2, 'LTYPE');
  d.pair(70, 3);
  for (final (name, desc, dashes) in const [
    ('CONTINUOUS', 'Solid line', <double>[]),
    ('DASHED', '__ __ __', <double>[6, -3]),
    ('CENTER', '____ _ ____', <double>[12, -3, 2, -3]),
  ]) {
    d.pair(0, 'LTYPE');
    d.pair(2, name);
    d.pair(70, 0);
    d.pair(3, desc);
    d.pair(72, 65);
    d.pair(73, dashes.length);
    d.pair(40, _n(dashes.fold(0.0, (s, v) => s + v.abs())));
    for (final v in dashes) {
      d.pair(49, _n(v));
    }
  }
  d.pair(0, 'ENDTAB');
  d.pair(0, 'TABLE');
  d.pair(2, 'LAYER');
  d.pair(70, 5);
  for (final (name, color, lt) in const [
    ('0', 7, 'CONTINUOUS'),
    ('CUT', 7, 'CONTINUOUS'),
    ('BEND', 1, 'DASHED'),
    ('NOTE', 2, 'CONTINUOUS'),
    ('DIM', 3, 'CENTER'),
  ]) {
    d.pair(0, 'LAYER');
    d.pair(2, name);
    d.pair(70, 0);
    d.pair(62, color);
    d.pair(6, lt);
  }
  d.pair(0, 'ENDTAB');
  d.pair(0, 'ENDSEC');
  d.pair(0, 'SECTION');
  d.pair(2, 'ENTITIES');

  for (final s in p.outline) {
    switch (s) {
      case PlateLine(:final a, :final b):
        d.line('CUT', a.dx, a.dy, b.dx, b.dy);
      case PlateArc(:final c, :final r, :final sweep)
          when sweep.abs() >= 359.999:
        d.circle('CUT', c.dx, c.dy, r);
      case PlateArc(:final c, :final r, :final start, :final sweep):
        final a0 = sweep >= 0 ? start : start + sweep;
        final a1 = sweep >= 0 ? start + sweep : start;
        d.arc('CUT', c.dx, c.dy, r, _norm(a0), _norm(a1));
    }
  }
  // 판 밖 홀은 뺀다(점검 62: 판 밖에 원이 남거나 외곽을 가로질러 잘렸다)
  for (final h in [...p.holes.where((h) => !h.out), ...p.cutouts]) {
    if (h.slot <= 0) {
      d.circle('CUT', h.c.dx, h.c.dy, h.dia / 2);
      continue;
    }
    // 장공: 두 반원 + 두 직선(각도 [PlateHole.angle]만큼 돈 방향)
    final r = h.r, base = h.angle;
    final a = base * math.pi / 180;
    final nx = -math.sin(a) * r, ny = math.cos(a) * r;
    final c1 = h.p1, c2 = h.p2;
    d.line('CUT', c1.dx + nx, c1.dy + ny, c2.dx + nx, c2.dy + ny);
    d.line('CUT', c1.dx - nx, c1.dy - ny, c2.dx - nx, c2.dy - ny);
    d.arc('CUT', c2.dx, c2.dy, r, _norm(base - 90), _norm(base + 90));
    d.arc('CUT', c1.dx, c1.dy, r, _norm(base + 90), _norm(base + 270));
  }
  // 판 가운데 십자 중심선(DIM 층): 판 밖으로 5mm씩
  final cx = (p.minX + p.maxX) / 2, cy = (p.minY + p.maxY) / 2;
  if (centerLines) {
    d.line('DIM', p.minX - 5, cy, p.maxX + 5, cy);
    d.line('DIM', cx, p.minY - 5, cx, p.maxY + 5);
    d.text('DIM', p.maxX + 6, cy - 1.75, 3.5, 'CL');
  }
  var n = 0;
  for (final b in p.bends) {
    n++;
    final spans = plateBendSpans(plateOutlinePoints(p.outline), b.center);
    for (final (y0, y1) in spans.isEmpty ? [(p.minY, p.maxY)] : spans) {
      d.line('BEND', b.center, y0, b.center, y1);
    }
    final dir = b.turn >= 0 ? 'UP' : 'DOWN';
    // 글은 판이 있는 가장 긴 구간 가운데(L·T자 판에서 상자 가운데에 두면 판 밖에 찍혔다, 10-11)
    final (y0, y1) = spans.isEmpty
        ? (p.minY, p.maxY)
        : spans.reduce((a, c) => c.$2 - c.$1 > a.$2 - a.$1 ? c : a);
    d.text(
      'NOTE',
      b.center + 2,
      (y0 + y1) / 2,
      math.max(2.5, thickness),
      'BEND $n $dir ${_n(b.turn.abs())} R${_n(p.rUsed)}',
    );
  }
  d.pair(0, 'ENDSEC');
  d.pair(0, 'EOF');
  return d.b.toString();
}

String plateFileStem(String title, DateTime date) {
  final t = title.trim().isEmpty
      ? 'plate'
      : title.trim().replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
  return '${t}_${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
}

/// DXF를 임시 파일로 써서 공유 창을 연다(보내기는 사람이 고른다).
Future<void> sharePlateDxf(
  PlatePlan p, {
  required double thickness,
  required String title,
  required String message,
  bool centerLines = true,
}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/${plateFileStem(title, DateTime.now())}.dxf');
  await file.writeAsString(
    plateDxf(p, thickness: thickness, centerLines: centerLines),
  );
  // ignore: deprecated_member_use
  await Share.shareXFiles([XFile(file.path)], text: message);
}
