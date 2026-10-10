// 철판 가공 DXF(10-10): 레이저 업체에 보내는 전개도 파일. AutoCAD R12(AC1009) 글 형식, 단위 mm.
//  · 층(레이어): CUT = 외곽·구멍·장공(자를 선), BEND = 꺾기선(가운데 선, 자르지 않음), NOTE = 꺾는 방향 글(영문).
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

  void text(String layer, double x, double y, double h, String s) {
    pair(0, 'TEXT');
    pair(8, layer);
    pair(10, _n(x));
    pair(20, _n(y));
    pair(30, 0);
    pair(40, _n(h));
    pair(1, s);
  }
}

double _norm(double deg) {
  var d = deg % 360;
  if (d < 0) d += 360;
  return d;
}

/// 전개도 DXF 글.
String plateDxf(PlatePlan p, {required double thickness}) {
  final d = _Dxf();
  d.pair(0, 'SECTION');
  d.pair(2, 'HEADER');
  d.pair(9, r'$ACADVER');
  d.pair(1, 'AC1009');
  d.pair(9, r'$INSUNITS');
  d.pair(70, 4); // mm
  d.pair(0, 'ENDSEC');
  d.pair(0, 'SECTION');
  d.pair(2, 'ENTITIES');

  for (final s in p.outline) {
    switch (s) {
      case PlateLine(:final a, :final b):
        d.line('CUT', a.dx, a.dy, b.dx, b.dy);
      case PlateArc(:final c, :final r, :final start, :final sweep):
        final a0 = sweep >= 0 ? start : start + sweep;
        final a1 = sweep >= 0 ? start + sweep : start;
        d.arc('CUT', c.dx, c.dy, r, _norm(a0), _norm(a1));
    }
  }
  for (final h in p.holes) {
    if (h.slot <= 0) {
      d.circle('CUT', h.c.dx, h.c.dy, h.dia / 2);
      continue;
    }
    // 장공: 두 반원 + 두 직선
    final r = h.dia / 2, half = (h.slot - h.dia) / 2;
    final ux = h.slotAlongX ? 1.0 : 0.0, uy = h.slotAlongX ? 0.0 : 1.0;
    final c1x = h.c.dx - ux * half, c1y = h.c.dy - uy * half;
    final c2x = h.c.dx + ux * half, c2y = h.c.dy + uy * half;
    final nx = -uy * r, ny = ux * r;
    d.line('CUT', c1x + nx, c1y + ny, c2x + nx, c2y + ny);
    d.line('CUT', c1x - nx, c1y - ny, c2x - nx, c2y - ny);
    final base = math.atan2(uy, ux) * 180 / math.pi;
    d.arc('CUT', c2x, c2y, r, _norm(base - 90), _norm(base + 90));
    d.arc('CUT', c1x, c1y, r, _norm(base + 90), _norm(base + 270));
  }
  var n = 0;
  for (final b in p.bends) {
    n++;
    d.line('BEND', b.center, p.minY, b.center, p.maxY);
    final dir = b.turn >= 0 ? 'UP' : 'DOWN';
    d.text(
      'NOTE',
      b.center + 2,
      p.minY + (p.maxY - p.minY) / 2,
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
}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/${plateFileStem(title, DateTime.now())}.dxf');
  await file.writeAsString(plateDxf(p, thickness: thickness));
  // ignore: deprecated_member_use
  await Share.shareXFiles([XFile(file.path)], text: message);
}
