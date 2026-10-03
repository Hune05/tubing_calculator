// DXF(글자 형식) 도면 읽기: 선·폴리선·원·호·타원·글자·블록(INSERT)·치수(DIMENSION 블록)를 모아
// 평면 선 목록으로 바꾼다. 그림으로 그리는 것은 drawing_render.dart가 한다.
// DWG는 오토데스크 비공개 형식이라 읽지 않는다(보낸 사람에게 PDF·DXF로 받거나 PC에서 바꿔 받는다).
// 해치·솔리드·3차원 요소·이미지 붙임은 건너뛴다(도면 확인에는 선과 글자가 핵심이다).
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

class DxfError implements Exception {
  final String message;
  const DxfError(this.message);
  @override
  String toString() => message;
}

/// 2차원 변환(a c e / b d f).
class Affine {
  final double a, b, c, d, e, f;
  const Affine(this.a, this.b, this.c, this.d, this.e, this.f);
  static const identity = Affine(1, 0, 0, 1, 0, 0);

  factory Affine.translate(double x, double y) => Affine(1, 0, 0, 1, x, y);
  factory Affine.scale(double sx, double sy) => Affine(sx, 0, 0, sy, 0, 0);
  factory Affine.rotate(double rad) => Affine(math.cos(rad), math.sin(rad), -math.sin(rad), math.cos(rad), 0, 0);

  /// this × o (o를 먼저 하고 this를 한다).
  Affine times(Affine o) => Affine(
    a * o.a + c * o.b,
    b * o.a + d * o.b,
    a * o.c + c * o.d,
    b * o.c + d * o.d,
    a * o.e + c * o.f + e,
    b * o.e + d * o.f + f,
  );

  (double, double) apply(double x, double y) => (a * x + c * y + e, b * x + d * y + f);
  double get scaleGuess => math.sqrt((a * d - b * c).abs());
  double get angle => math.atan2(b, a);
}

class DxfPath {
  final List<(double, double)> points;
  final bool closed;
  final int color; // 0xRRGGBB
  const DxfPath(this.points, this.closed, this.color);
}

class DxfText {
  final double x, y, height, rotation; // rotation: 라디안
  final String text;
  final int color;
  const DxfText(this.x, this.y, this.height, this.rotation, this.text, this.color);
}

class DxfDrawing {
  final List<DxfPath> paths;
  final List<DxfText> texts;
  final double minX, minY, maxX, maxY;
  final int skipped; // 건너뛴 요소 수(해치 등)
  const DxfDrawing(this.paths, this.texts, this.minX, this.minY, this.maxX, this.maxY, this.skipped);

  double get width => maxX - minX;
  double get height => maxY - minY;
  bool get isEmpty => paths.isEmpty && texts.isEmpty;
}

/// AutoCAD 색 번호(ACI) 중 흔한 것. 7(흰/검)은 흰 바탕에서 검게 그린다.
int aciColor(int i) {
  const base = {
    1: 0xE53935, 2: 0xC9A800, 3: 0x2E9E3E, 4: 0x0097A7, 5: 0x1E4FD8, 6: 0xB0229B, 7: 0x111111, 8: 0x6B6B6B, 9: 0x9E9E9E,
  };
  final v = base[i.abs()];
  if (v != null) return v;
  if (i.abs() >= 250) return 0x555555; // 회색 계열
  return 0x333333;
}

class _Pair {
  final int code;
  final String value;
  const _Pair(this.code, this.value);
  double get d => double.tryParse(value.trim()) ?? 0;
  int get i => int.tryParse(value.trim()) ?? 0;
}

class _Entity {
  final String type;
  final List<_Pair> pairs;
  _Entity(this.type, this.pairs);

  String? str(int code) {
    for (final p in pairs) {
      if (p.code == code) return p.value;
    }
    return null;
  }

  double num(int code, [double def = 0]) {
    for (final p in pairs) {
      if (p.code == code) return p.d;
    }
    return def;
  }

  int integer(int code, [int def = 0]) {
    for (final p in pairs) {
      if (p.code == code) return p.i;
    }
    return def;
  }
}

class _Block {
  final double bx, by;
  final List<_Entity> entities;
  _Block(this.bx, this.by, this.entities);
}

/// 바이트를 글로 바꾼다. UTF-8이 아니면 한 바이트 글자로 읽는다(옛 한글 DXF는 글자가 깨질 수 있다).
String dxfDecode(Uint8List bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return latin1.decode(bytes);
  }
}

/// "\U+AC00" 같은 글자 코드와 MTEXT 서식(\P 줄바꿈, {\f…;}, \A1; 등)을 걷어낸다.
String cleanDxfText(String s) {
  var t = s.replaceAllMapped(RegExp(r'\\U\+([0-9A-Fa-f]{4})'), (m) => String.fromCharCode(int.parse(m[1]!, radix: 16)));
  t = t.replaceAll(RegExp(r'\\[Pp]'), '\n');
  t = t.replaceAll(RegExp(r'\\[ACFHQTWcfhqtw][^;\\{}]*;'), '');
  t = t.replaceAll(RegExp(r'\\[LlOoKk]'), '');
  t = t.replaceAllMapped(RegExp(r'\\S([^;^/#]*)[\^/#]([^;]*);'), (m) => '${m[1]}/${m[2]}');
  t = t.replaceAll('%%c', 'Ø').replaceAll('%%C', 'Ø').replaceAll('%%d', '°').replaceAll('%%D', '°').replaceAll('%%p', '±').replaceAll('%%P', '±');
  t = t.replaceAll(RegExp(r'%%[uUoO]'), '');
  t = t.replaceAll('{', '').replaceAll('}', '');
  return t.trim();
}

DxfDrawing readDxf(String text) {
  if (text.startsWith('AutoCAD Binary DXF')) {
    throw const DxfError('바이너리 DXF는 열 수 없습니다. 보낸 사람에게 ASCII DXF나 PDF로 다시 받으십시오.');
  }
  final lines = const LineSplitter().convert(text);
  final pairs = <_Pair>[];
  for (var k = 0; k + 1 < lines.length; k += 2) {
    final code = int.tryParse(lines[k].trim());
    if (code == null) throw const DxfError('DXF 파일이 아니거나 망가졌습니다.');
    pairs.add(_Pair(code, lines[k + 1]));
  }
  if (!pairs.any((p) => p.code == 0 && p.value.trim() == 'SECTION')) {
    throw const DxfError('DXF 파일이 아닙니다.');
  }

  // 구역별로 나눈다.
  final layerColor = <String, int>{};
  final blocks = <String, _Block>{};
  final entities = <_Entity>[];

  var idx = 0;
  String? section;
  List<_Entity>? blockList;
  String? blockName;
  double bx = 0, by = 0;
  while (idx < pairs.length) {
    final p = pairs[idx];
    if (p.code == 0 && p.value.trim() == 'SECTION') {
      section = idx + 1 < pairs.length && pairs[idx + 1].code == 2 ? pairs[idx + 1].value.trim() : null;
      idx += 2;
      continue;
    }
    if (p.code == 0 && p.value.trim() == 'ENDSEC') {
      section = null;
      idx++;
      continue;
    }
    if (p.code != 0) {
      idx++;
      continue;
    }
    // 요소 하나를 모은다(다음 0 코드 전까지).
    final type = p.value.trim();
    final body = <_Pair>[];
    var j = idx + 1;
    while (j < pairs.length && pairs[j].code != 0) {
      body.add(pairs[j]);
      j++;
    }
    idx = j;
    final e = _Entity(type, body);
    if (section == 'TABLES' && type == 'LAYER') {
      final name = e.str(2)?.trim() ?? '';
      layerColor[name] = e.integer(62, 7);
    } else if (section == 'BLOCKS') {
      if (type == 'BLOCK') {
        blockName = e.str(2)?.trim();
        bx = e.num(10);
        by = e.num(20);
        blockList = [];
      } else if (type == 'ENDBLK') {
        if (blockName != null && blockList != null) blocks[blockName] = _Block(bx, by, blockList);
        blockName = null;
        blockList = null;
      } else {
        blockList?.add(e);
      }
    } else if (section == 'ENTITIES') {
      entities.add(e);
    }
  }

  final paths = <DxfPath>[];
  final texts = <DxfText>[];
  var skipped = 0;

  int colorOf(_Entity e, int inherited) {
    final c = e.integer(62, 256);
    final layer = e.str(8)?.trim() ?? '0';
    if (c == 0) return inherited; // BYBLOCK
    if (c == 256) return aciColor(layerColor[layer] ?? 7); // BYLAYER
    return aciColor(c);
  }

  bool layerOff(_Entity e) => (layerColor[e.str(8)?.trim() ?? '0'] ?? 7) < 0;

  List<(double, double)> arcPoints(double cx, double cy, double r, double a0, double a1) {
    var sweep = a1 - a0;
    while (sweep <= 0) {
      sweep += 2 * math.pi;
    }
    final n = math.max(8, (sweep / (math.pi / 36)).ceil());
    return [for (var k = 0; k <= n; k++) (cx + r * math.cos(a0 + sweep * k / n), cy + r * math.sin(a0 + sweep * k / n))];
  }

  // 볼록(bulge)이 있는 폴리선 한 칸을 점들로.
  List<(double, double)> bulgeSeg((double, double) p, (double, double) q, double bulge) {
    if (bulge.abs() < 1e-9) return [q];
    final dx = q.$1 - p.$1, dy = q.$2 - p.$2;
    final chord = math.sqrt(dx * dx + dy * dy);
    if (chord < 1e-12) return [q];
    final theta = 4 * math.atan(bulge);
    final r = chord / (2 * math.sin(theta / 2));
    final mx = (p.$1 + q.$1) / 2, my = (p.$2 + q.$2) / 2;
    final h = r * math.cos(theta / 2);
    final nx = -dy / chord, ny = dx / chord;
    final cx = mx + nx * h, cy = my + ny * h;
    final a0 = math.atan2(p.$2 - cy, p.$1 - cx);
    final n = math.max(4, (theta.abs() / (math.pi / 36)).ceil());
    final rr = r.abs();
    return [for (var k = 1; k <= n; k++) (cx + rr * math.cos(a0 + theta * k / n), cy + rr * math.sin(a0 + theta * k / n))];
  }

  void addPath(List<(double, double)> pts, bool closed, int color, Affine t) {
    if (pts.length < 2) return;
    paths.add(DxfPath([for (final q in pts) t.apply(q.$1, q.$2)], closed, color));
  }

  void walk(List<_Entity> list, Affine t, int inherited, int depth) {
    for (var k = 0; k < list.length; k++) {
      final e = list[k];
      if (layerOff(e)) continue;
      final col = colorOf(e, inherited);
      switch (e.type) {
        case 'LINE':
          addPath([(e.num(10), e.num(20)), (e.num(11), e.num(21))], false, col, t);
        case 'LWPOLYLINE':
          final pts = <(double, double)>[];
          final bulges = <double>[];
          double? x;
          for (final p in e.pairs) {
            if (p.code == 10) {
              x = p.d;
            } else if (p.code == 20 && x != null) {
              pts.add((x, p.d));
              bulges.add(0);
              x = null;
            } else if (p.code == 42 && bulges.isNotEmpty) {
              bulges[bulges.length - 1] = p.d;
            }
          }
          final closed = (e.integer(70) & 1) == 1;
          if (pts.isEmpty) break;
          final out = <(double, double)>[pts.first];
          final n = closed ? pts.length : pts.length - 1;
          for (var s = 0; s < n; s++) {
            out.addAll(bulgeSeg(pts[s], pts[(s + 1) % pts.length], bulges[s]));
          }
          addPath(out, closed && bulges.last.abs() < 1e-9, col, t);
        case 'POLYLINE':
          final closed = (e.integer(70) & 1) == 1;
          final pts = <(double, double)>[];
          final bulges = <double>[];
          var m = k + 1;
          while (m < list.length && list[m].type == 'VERTEX') {
            pts.add((list[m].num(10), list[m].num(20)));
            bulges.add(list[m].num(42));
            m++;
          }
          if (m < list.length && list[m].type == 'SEQEND') m++;
          k = m - 1;
          if (pts.isEmpty) break;
          final out = <(double, double)>[pts.first];
          final n = closed ? pts.length : pts.length - 1;
          for (var s = 0; s < n; s++) {
            out.addAll(bulgeSeg(pts[s], pts[(s + 1) % pts.length], bulges[s]));
          }
          addPath(out, closed && bulges.last.abs() < 1e-9, col, t);
        case 'CIRCLE':
          addPath(arcPoints(e.num(10), e.num(20), e.num(40), 0, 2 * math.pi), true, col, t);
        case 'ARC':
          addPath(arcPoints(e.num(10), e.num(20), e.num(40), e.num(50) * math.pi / 180, e.num(51) * math.pi / 180), false, col, t);
        case 'ELLIPSE':
          final cx = e.num(10), cy = e.num(20), mx = e.num(11), my = e.num(21), ratio = e.num(40, 1);
          final p0 = e.num(41, 0), p1 = e.num(42, 2 * math.pi);
          final ma = math.sqrt(mx * mx + my * my), rot = math.atan2(my, mx);
          var sweep = p1 - p0;
          while (sweep <= 0) {
            sweep += 2 * math.pi;
          }
          final n = math.max(12, (sweep / (math.pi / 36)).ceil());
          final pts = <(double, double)>[];
          for (var s = 0; s <= n; s++) {
            final u = p0 + sweep * s / n;
            final lx = ma * math.cos(u), ly = ma * ratio * math.sin(u);
            pts.add((cx + lx * math.cos(rot) - ly * math.sin(rot), cy + lx * math.sin(rot) + ly * math.cos(rot)));
          }
          addPath(pts, false, col, t);
        case 'TEXT':
        case 'MTEXT':
        case 'ATTRIB':
          final raw = e.type == 'MTEXT'
              ? [for (final p in e.pairs) if (p.code == 3) p.value].join() + (e.str(1) ?? '')
              : (e.str(1) ?? '');
          final s = cleanDxfText(raw);
          if (s.isEmpty) break;
          // TEXT가 가운데·오른쪽 맞춤이면 11·21이 맞춤 자리다.
          var x = e.num(10), y = e.num(20);
          if (e.type != 'MTEXT' && (e.integer(72) != 0 || e.integer(73) != 0) && e.pairs.any((p) => p.code == 11)) {
            x = e.num(11);
            y = e.num(21);
          }
          final (tx, ty) = t.apply(x, y);
          final h = e.num(40, 2.5) * t.scaleGuess;
          var rot = e.num(50) * math.pi / 180;
          if (e.type == 'MTEXT' && e.pairs.any((p) => p.code == 11)) rot = math.atan2(e.num(21), e.num(11));
          texts.add(DxfText(tx, ty, h, rot + t.angle, s, col));
        case 'INSERT':
        case 'DIMENSION':
          if (depth > 8) break;
          final name = e.str(2)?.trim() ?? '';
          final b = blocks[name];
          if (b == null) break;
          final Affine m;
          if (e.type == 'DIMENSION') {
            m = t; // 치수 블록은 도면 좌표 그대로 들어 있다
          } else {
            final sx = e.num(41, 1), sy = e.num(42, 1);
            m = t
                .times(Affine.translate(e.num(10), e.num(20)))
                .times(Affine.rotate(e.num(50) * math.pi / 180))
                .times(Affine.scale(sx, sy))
                .times(Affine.translate(-b.bx, -b.by));
          }
          walk(b.entities, m, col, depth + 1);
          // 블록에 딸린 속성 글자
          var m2 = k + 1;
          while (m2 < list.length && list[m2].type == 'ATTRIB') {
            m2++;
          }
          if (m2 > k + 1) {
            walk(list.sublist(k + 1, m2), t, col, depth + 1);
            k = m2 - 1;
          }
        case 'VERTEX':
        case 'SEQEND':
        case 'ATTDEF':
          break;
        default:
          skipped++;
      }
    }
  }

  walk(entities, Affine.identity, aciColor(7), 0);

  var minX = double.infinity, minY = double.infinity, maxX = -double.infinity, maxY = -double.infinity;
  void grow(double x, double y) {
    if (!x.isFinite || !y.isFinite) return;
    minX = math.min(minX, x);
    minY = math.min(minY, y);
    maxX = math.max(maxX, x);
    maxY = math.max(maxY, y);
  }

  for (final p in paths) {
    for (final q in p.points) {
      grow(q.$1, q.$2);
    }
  }
  for (final tx in texts) {
    grow(tx.x, tx.y);
    grow(tx.x + tx.height * tx.text.length * 0.6 * math.cos(tx.rotation), tx.y + tx.height);
  }
  if (!minX.isFinite) {
    return DxfDrawing(paths, texts, 0, 0, 1, 1, skipped);
  }
  if (maxX - minX < 1e-9) maxX = minX + 1;
  if (maxY - minY < 1e-9) maxY = minY + 1;
  return DxfDrawing(paths, texts, minX, minY, maxX, maxY, skipped);
}
