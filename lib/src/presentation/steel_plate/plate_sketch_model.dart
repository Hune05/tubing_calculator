// 손그림 읽어 만들기(10-10)의 그림 자료와 고치는 계산. 화면 없이 시험할 수 있게 따로 둔다.
// 좌표는 "그림 단위"(y는 위가 +): 사진 위에 따라 찍을 때 치수를 넣기 전에는 사진 점 크기 그대로이고,
// 변 하나에 치수를 넣으면 전체를 그 비율로 늘이거나 줄여 mm가 된다. AI가 읽은 것은 처음부터 mm다.
import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import '../../core/utils/ai_plate_sketch.dart';
import 'plate_calc.dart';

String _f(double v) {
  var s = v.toStringAsFixed(1);
  if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
  return s == '-0' ? '0' : s;
}

class PlateSketch {
  PlateSketch({
    List<Offset>? pts,
    List<PlateCorner>? corners,
    List<int>? ids,
    List<PlateHoleSpec>? holes,
    Map<int, double>? dims,
    this.frame = const Rect.fromLTWH(0, 0, 400, 300),
    this.scaled = false,
    this.closed = false,
    this.photoAligned = true,
    this.nextId = 0,
    this.thickness,
    List<String>? unclear,
  }) : pts = List.of(pts ?? const []),
       corners = List.of(corners ?? const []),
       ids = List.of(ids ?? const []),
       holes = List.of(holes ?? const []),
       dims = Map.of(dims ?? const {}),
       unclear = List.of(unclear ?? const []) {
    while (this.corners.length < this.pts.length) {
      this.corners.add(PlateCorner.square);
    }
    while (this.ids.length < this.pts.length) {
      this.ids.add(nextId++);
    }
  }

  /// 외곽 꼭짓점(차례대로, 마지막은 첫 점과 이어짐)과 꼭짓점마다 귀 처리.
  final List<Offset> pts;
  final List<PlateCorner> corners;

  /// 꼭짓점마다 붙인 번호(넣은 변 길이를 꼭짓점이 늘거나 줄어도 따라가게).
  final List<int> ids;
  final List<PlateHoleSpec> holes;

  /// 넣은 변 길이(mm). 열쇠는 변 시작 꼭짓점의 번호.
  final Map<int, double> dims;

  /// 사진(또는 빈 종이)이 차지하는 자리. 화면은 이 자리를 맞춰 보여 준다.
  Rect frame;

  /// 치수를 넣어 mm가 정해졌는지.
  bool scaled;

  /// 1번 점을 다시 눌러(또는 AI가 읽어) 모양을 닫았는지. 닫기 전에는 빈 곳을 누르면 점이 더해진다.
  bool closed;

  /// 사진이 그림과 같은 자리에 겹쳐 있는지(AI가 읽은 것은 겹치지 않는다).
  bool photoAligned;
  int nextId;
  double? thickness;
  List<String> unclear;

  int get n => pts.length;

  /// 변 개수. 닫기 전에는 찍은 차례대로 이은 변만(마지막 → 첫 변은 없음).
  int get edgeCount => n < 2 ? 0 : (closed && n >= 3 ? n : n - 1);

  Offset edgeVec(int i) => edgeEnd(i) - pts[i];

  /// 넣은 치수가 있는 변(잠김: 다른 변을 고쳐도 이 길이는 그대로 둔다).
  bool isLocked(int i) => i < n && dims.containsKey(ids[i]);
  void unlock(int i) => dims.remove(ids[i]);

  Offset edgeEnd(int i) => pts[(i + 1) % n];
  double edgeLen(int i) => (edgeEnd(i) - pts[i]).distance;
  double? dimOf(int i) => i < n ? dims[ids[i]] : null;

  /// 넣은 길이와 지금 길이가 맞는지(0.5mm 안). 넣은 적 없으면 null.
  bool? edgeMatches(int i) {
    final d = dimOf(i);
    return d == null ? null : (edgeLen(i) - d).abs() <= 0.5;
  }

  PlateSketch copy() => PlateSketch(
    pts: List.of(pts),
    corners: List.of(corners),
    ids: List.of(ids),
    holes: List.of(holes),
    dims: Map.of(dims),
    frame: frame,
    scaled: scaled,
    closed: closed,
    photoAligned: photoAligned,
    nextId: nextId,
    thickness: thickness,
    unclear: List.of(unclear),
  );

  // ── 꼭짓점 ──

  void addPoint(Offset p) {
    // 닫는 변(마지막 → 첫)이 둘로 나뉘므로 그 변에 넣은 길이는 뺀다.
    if (n >= 1) dims.remove(ids[n - 1]);
    pts.add(p);
    corners.add(PlateCorner.square);
    ids.add(nextId++);
  }

  /// 변 [i] 가운데에 꼭짓점을 끼운다(변 i가 둘로 나뉜다).
  void insertOnEdge(int i, Offset p) {
    dims.remove(ids[i]);
    pts.insert(i + 1, p);
    corners.insert(i + 1, PlateCorner.square);
    ids.insert(i + 1, nextId++);
  }

  void removePoint(int k) {
    dims.remove(ids[k]);
    dims.remove(ids[(k - 1 + n) % n]);
    pts.removeAt(k);
    corners.removeAt(k);
    ids.removeAt(k);
    if (n < 3) closed = false;
  }

  /// 모양 닫기(점이 셋 이상일 때).
  bool close() {
    if (n < 3) return false;
    closed = true;
    return true;
  }

  // ── 치수 ──

  /// 전체를 [f]배(꼭짓점·구멍 자리·사진 자리, 넣은 길이는 그대로).
  void scaleAll(double f) {
    for (var k = 0; k < n; k++) {
      pts[k] = pts[k] * f;
    }
    for (var k = 0; k < holes.length; k++) {
      final h = holes[k];
      holes[k] = PlateHoleSpec(
        u: h.u * f,
        v: h.v * f,
        dia: h.dia,
        slot: h.slot,
        angle: h.angle,
      );
    }
    frame = Rect.fromLTRB(
      frame.left * f,
      frame.top * f,
      frame.right * f,
      frame.bottom * f,
    );
  }

  static const _axisTol = 0.0175; // 약 1°
  static bool _isH(Offset v) =>
      v.distance > 1e-9 && (v.dy / v.distance).abs() < _axisTol;
  static bool _isV(Offset v) =>
      v.distance > 1e-9 && (v.dx / v.distance).abs() < _axisTol;

  /// 변 [i]의 차이를 받을 수 있는 변들: [want]에 맞는 것 중 잠기지 않은 변 먼저, 그다음 잠긴 변
  /// (각각 [i] 다음부터 도는 차례).
  List<int> _candidates(int i, bool Function(Offset v) want) => [
    for (final locked in const [false, true])
      for (var s = 1; s < edgeCount; s++)
        if (isLocked((i + s) % edgeCount) == locked &&
            want(edgeVec((i + s) % edgeCount)))
          (i + s) % edgeCount,
  ];

  /// 변 k가 [d]만큼 줄어도(벡터 − d) 0.5mm 넘게 남고 뒤집히지 않는지.
  bool _canAbsorb(int k, Offset d) {
    final v = edgeVec(k), nv = v - d;
    return nv.distance >= 0.5 && v.dx * nv.dx + v.dy * nv.dy > 0;
  }

  /// 꼭짓점 i+1 … k(돌아서)를 [d]만큼 옮긴다: 변 i는 d만큼 늘고 변 k는 d만큼 준다(나머지 변은 그대로).
  void _shiftBetween(int i, int k, Offset d) {
    var j = (i + 1) % n;
    while (true) {
      pts[j] += d;
      if (j == k) break;
      j = (j + 1) % n;
    }
  }

  String _edgeName(int k) => '${k + 1}→${(k + 1) % n + 1}';

  /// 변 [i]의 길이를 [mm]로 넣고 잠근다(방금 넣은 값이 이긴다, 10-10 사용자 결정).
  /// 처음 넣는 치수면 전체 크기(축척)를 정한다. 그다음부터는 같은 방향의 잠기지 않은 변이 차이를 받고,
  /// 없으면 가장 가까운 같은 방향의 잠긴 변이 따라 바뀐다(그 변의 넣은 값도 새 길이로, [note]로 알림).
  /// 가로·세로가 지켜져 직각이 안 풀린다. 받는 변이 뒤집히거나 0이 되면 바꾸지 않는다.
  /// 닫기 전에는 그 변 뒤 꼭짓점들을 같이 옮긴다.
  ({bool ok, String? note}) setEdge(int i, double mm) {
    if (i >= edgeCount || mm <= 0) return (ok: false, note: null);
    final cur = edgeLen(i);
    if (cur < 1e-9) return (ok: false, note: null);
    final changedLocked = <String>[];
    String? note;
    // 받은 변이 잠긴 변이면 그 값도 새 길이로 바꾸고 알릴 글을 모은다
    void absorbed(int k, double before) {
      if (!isLocked(k)) return;
      final after = edgeLen(k);
      dims[ids[k]] = after;
      changedLocked.add('${_edgeName(k)} (${_f(before)} → ${_f(after)})');
    }

    if (!scaled) {
      scaleAll(mm / cur);
      scaled = true;
    } else {
      final v = edgeVec(i);
      final delta = v / cur * (mm - cur);
      if (!closed || n < 3) {
        for (var k = i + 1; k < n; k++) {
          pts[k] += delta;
        }
      } else if (delta.distance > 1e-9) {
        int? pick(bool Function(Offset v) want, Offset d) {
          for (final k in _candidates(i, want)) {
            if (_canAbsorb(k, d)) return k;
          }
          return null;
        }

        if (_isH(v) || _isV(v)) {
          final k = pick(_isH(v) ? _isH : _isV, delta);
          if (k == null) {
            return (
              ok: false,
              note: '그 길이로는 같은 방향 변이 0보다 짧아져 모양이 뒤집힙니다. 다른 변 길이를 먼저 고치십시오.',
            );
          }
          final before = edgeLen(k);
          _shiftBetween(i, k, delta);
          absorbed(k, before);
        } else {
          // 기운 변: 가로 몫은 가로 변이, 세로 몫은 세로 변이 받는다
          final dx = Offset(delta.dx, 0), dy = Offset(0, delta.dy);
          final kx = dx.distance > 1e-9 ? pick(_isH, dx) : -1;
          final ky = dy.distance > 1e-9 ? pick(_isV, dy) : -1;
          if (kx != null && ky != null) {
            if (kx >= 0) {
              final b = edgeLen(kx);
              _shiftBetween(i, kx, dx);
              absorbed(kx, b);
            }
            if (ky >= 0) {
              final b = edgeLen(ky);
              _shiftBetween(i, ky, dy);
              absorbed(ky, b);
            }
          } else {
            final k = pick((_) => true, delta);
            if (k == null) {
              return (
                ok: false,
                note: '그 길이로는 다른 변이 0보다 짧아져 모양이 뒤집힙니다. 다른 변 길이를 먼저 고치십시오.',
              );
            }
            final b = edgeLen(k);
            _shiftBetween(i, k, delta);
            absorbed(k, b);
            note = '맞출 가로·세로 변이 없어 변 ${_edgeName(k)} 기울기가 바뀌었습니다.';
          }
        }
      }
    }
    dims[ids[i]] = mm;
    if (changedLocked.isNotEmpty) {
      final t = '같이 바뀐 변: ${changedLocked.join(', ')}.';
      note = note == null ? t : '$note $t';
    }
    return (ok: true, note: note);
  }

  /// 손으로 찍어 조금 비뚤어진 변을 가로·세로로 바로 세운다([tolDeg]도 안). 길이는 그대로 두고
  /// 뒤 꼭짓점들을 같이 옮긴다. 닫는 변은 마지막 꼭짓점만 옮긴다. 바로 세운 변 수를 돌려준다.
  int squareUp({double tolDeg = 10}) {
    if (n < 2) return 0;
    final tol = math.sin(tolDeg * math.pi / 180);
    var fixed = 0;
    for (var i = 0; i < n - 1; i++) {
      final a = pts[i], b = pts[i + 1];
      final v = b - a, len = v.distance;
      if (len < 1e-9) continue;
      Offset? nb;
      if ((v.dy / len).abs() <= tol && v.dy.abs() > 1e-9) {
        nb = a + Offset(v.dx.sign * len, 0);
      } else if ((v.dx / len).abs() <= tol && v.dx.abs() > 1e-9) {
        nb = a + Offset(0, v.dy.sign * len);
      }
      if (nb == null) continue;
      final delta = nb - b;
      for (var k = i + 1; k < n; k++) {
        pts[k] += delta;
      }
      fixed++;
    }
    if (closed && n >= 3) {
      final a = pts[n - 1], b = pts[0];
      final v = b - a, len = v.distance;
      if (len > 1e-9) {
        if ((v.dy / len).abs() <= tol && v.dy.abs() > 1e-9) {
          pts[n - 1] = Offset(a.dx, b.dy);
          fixed++;
        } else if ((v.dx / len).abs() <= tol && v.dx.abs() > 1e-9) {
          pts[n - 1] = Offset(b.dx, a.dy);
          fixed++;
        }
      }
    }
    return fixed;
  }

  // ── 찾기 ──

  int? hitPoint(Offset p, double tol) {
    int? best;
    var bd = tol;
    for (var k = 0; k < n; k++) {
      final d = (pts[k] - p).distance;
      if (d <= bd) {
        bd = d;
        best = k;
      }
    }
    return best;
  }

  int? hitEdge(Offset p, double tol) {
    int? best;
    var bd = tol;
    for (var i = 0; i < edgeCount; i++) {
      final d = _segDist(p, pts[i], edgeEnd(i));
      if (d <= bd) {
        bd = d;
        best = i;
      }
    }
    return best;
  }

  int? hitHole(Offset p, double tol) {
    int? best;
    var bd = double.infinity;
    for (var k = 0; k < holes.length; k++) {
      final h = holes[k];
      final half = h.slot > h.dia ? (h.slot - h.dia) / 2 : 0.0;
      final a = h.angle * math.pi / 180;
      final ax = Offset(math.cos(a), math.sin(a)) * half;
      final c = Offset(h.u, h.v);
      final d = _segDist(p, c - ax, c + ax) - (scaled ? h.dia / 2 : 0);
      if (d <= tol && d < bd) {
        bd = d;
        best = k;
      }
    }
    return best;
  }

  /// 꼭짓점을 감싸는 사각형(꼭짓점이 없으면 null).
  Rect? get bounds {
    if (pts.isEmpty) return null;
    var r = Rect.fromPoints(pts.first, pts.first);
    for (final p in pts) {
      r = r.expandToInclude(Rect.fromPoints(p, p));
    }
    return r;
  }

  // ── 옮기기 ──

  /// 레이저 절단 화면에 넣을 자료(자유 모양, 왼쪽 아래를 0,0으로). 치수가 정해지지 않았거나 점이 셋 안 되면 null.
  Map<String, Object?>? toPlateMap() {
    final b = bounds;
    if (!scaled || n < 3 || b == null) return null;
    final o = b.topLeft; // y 위가 +라 topLeft = (가장 왼쪽, 가장 아래)
    return {
      'sh': 'free',
      'pts': platePointsText([for (final p in pts) p - o], corners),
      'holes': [
        for (final h in holes)
          PlateHoleSpec(
            u: double.parse(_f(h.u - o.dx)),
            v: double.parse(_f(h.v - o.dy)),
            dia: h.dia,
            slot: h.slot,
            angle: h.angle,
          ).toJson(),
      ],
      'rot': 0,
      if (thickness != null) 't': _f(thickness!),
    };
  }

  // ── 저장 ──

  Map<String, Object?> toJson() => {
    'pts': [
      for (final p in pts) [p.dx, p.dy],
    ],
    'corners': [for (final c in corners) c.toJson()],
    'ids': ids,
    'holes': [for (final h in holes) h.toJson()],
    'dims': {for (final e in dims.entries) '${e.key}': e.value},
    'frame': [frame.left, frame.top, frame.right, frame.bottom],
    'scaled': scaled,
    'closed': closed,
    'aligned': photoAligned,
    'next': nextId,
    't': thickness,
    'unclear': unclear,
  };

  static PlateSketch? fromJson(Object? o) {
    if (o is! Map) return null;
    double? d(Object? v) => v is num ? v.toDouble() : null;
    final pts = <Offset>[];
    for (final p in (o['pts'] is List ? o['pts'] as List : const [])) {
      if (p is List && p.length == 2 && d(p[0]) != null && d(p[1]) != null) {
        pts.add(Offset(d(p[0])!, d(p[1])!));
      }
    }
    final cs = o['corners'] is List ? o['corners'] as List : const [];
    final ids = o['ids'] is List
        ? [
            for (final v in o['ids'] as List)
              if (v is int) v,
          ]
        : <int>[];
    final fr = o['frame'] is List ? o['frame'] as List : const [];
    final dims = <int, double>{};
    if (o['dims'] is Map) {
      (o['dims'] as Map).forEach((k, v) {
        final key = int.tryParse('$k');
        if (key != null && v is num) dims[key] = v.toDouble();
      });
    }
    final next = o['next'] is int ? o['next'] as int : 0;
    return PlateSketch(
      pts: pts,
      corners: [
        for (var k = 0; k < pts.length; k++)
          k < cs.length ? PlateCorner.fromJson(cs[k]) : PlateCorner.square,
      ],
      ids: ids.length == pts.length ? ids : null,
      holes: [
        for (final h in (o['holes'] is List ? o['holes'] as List : const []))
          ?PlateHoleSpec.fromJson(h),
      ],
      dims: dims,
      frame: fr.length == 4 && fr.every((v) => v is num)
          ? Rect.fromLTRB(d(fr[0])!, d(fr[1])!, d(fr[2])!, d(fr[3])!)
          : const Rect.fromLTWH(0, 0, 400, 300),
      scaled: o['scaled'] == true,
      closed: o['closed'] == true && pts.length >= 3,
      photoAligned: o['aligned'] != false,
      nextId: math.max(next, ids.isEmpty ? 0 : ids.reduce(math.max) + 1),
      thickness: d(o['t']),
      unclear: [
        for (final s
            in (o['unclear'] is List ? o['unclear'] as List : const []))
          if (s is String) s,
      ],
    );
  }

  /// AI가 읽은 것으로 새 그림(mm, 사진과 겹치지 않음).
  static PlateSketch fromAi(PlateSketchResult r) {
    final pts = [for (final p in r.outline) Offset(p.x, p.y)];
    final s = PlateSketch(
      pts: pts,
      corners: [
        for (final p in r.outline)
          switch (p.corner) {
            'round' => PlateCorner(PlateCornerKind.round, p.size),
            'chamfer' => PlateCorner(PlateCornerKind.chamfer, p.size),
            _ => PlateCorner.square,
          },
      ],
      holes: [
        for (final h in r.holes)
          PlateHoleSpec(
            u: h.x,
            v: h.y,
            dia: h.dia,
            slot: h.slot > h.dia ? h.slot : 0,
            angle: h.angle,
          ),
      ],
      scaled: true,
      closed: true,
      photoAligned: false,
      thickness: r.thickness,
      unclear: List.of(r.unclear),
    );
    final b = s.bounds!;
    final m = math.max(20.0, math.max(b.width, b.height) * 0.08);
    s.frame = b.inflate(m);
    return s;
  }
}

double _segDist(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final l2 = ab.dx * ab.dx + ab.dy * ab.dy;
  if (l2 < 1e-12) return (p - a).distance;
  final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / l2).clamp(0.0, 1.0);
  return (p - (a + ab * t)).distance;
}

// ── 손가락으로 그은 선(10-10, 사용자: "손그림을 앱에서 바로 못 그리나") ──
// 빈 칸에 그은 외곽선은 꺾인 곳만 남겨 꼭짓점으로, 판 안에 그은 작은 고리는 구멍·장공으로 바꾼다.

//// 꺾은선 줄이기(Ramer–Douglas–Peucker): 남길 점의 번호(처음·끝 포함).
List<int> _rdpIdx(List<Offset> p, int i0, int i1, double eps) {
  if (i1 - i0 < 2) return [i0, i1];
  var idx = -1;
  var dmax = 0.0;
  for (var i = i0 + 1; i < i1; i++) {
    final d = _segDist(p[i], p[i0], p[i1]);
    if (d > dmax) {
      dmax = d;
      idx = i;
    }
  }
  if (dmax <= eps) return [i0, i1];
  final a = _rdpIdx(p, i0, idx, eps);
  final b = _rdpIdx(p, idx, i1, eps);
  return [...a.sublist(0, a.length - 1), ...b];
}

/// 점들에 가장 잘 맞는 직선(가운데·방향). 방향은 [hint] 쪽으로 맞춘다.
(Offset, Offset) _fitLine(List<Offset> pts, Offset hint) {
  var c = Offset.zero;
  for (final p in pts) {
    c += p;
  }
  c = c / pts.length.toDouble();
  if (pts.length < 2) return (c, hint);
  var sxx = 0.0, syy = 0.0, sxy = 0.0;
  for (final p in pts) {
    final d = p - c;
    sxx += d.dx * d.dx;
    syy += d.dy * d.dy;
    sxy += d.dx * d.dy;
  }
  final ang = 0.5 * math.atan2(2 * sxy, sxx - syy);
  var dir = Offset(math.cos(ang), math.sin(ang));
  if (dir.dx * hint.dx + dir.dy * hint.dy < 0) dir = -dir;
  return (c, dir);
}

/// 두 직선(점 a·방향 u, 점 b·방향 v)이 만나는 점. 거의 나란하면(약 3° 안) null.
Offset? _cross(Offset a, Offset u, Offset b, Offset v) {
  final den = u.dx * v.dy - u.dy * v.dx;
  if (den.abs() < 0.05) return null;
  final t = ((b - a).dx * v.dy - (b - a).dy * v.dx) / den;
  return a + u * t;
}

double _dirDiffDeg(Offset u, Offset v) {
  final cos = (u.dx * v.dx + u.dy * v.dy).clamp(-1.0, 1.0);
  return math.acos(cos) * 180 / math.pi;
}

/// 손가락으로 그은 외곽선 → 꼭짓점. 꺾인 곳을 찾아(RDP, [tol]) 변마다 직선을 맞추고, 이웃 직선이 만나는 점을
/// 귀로 삼는다(손으로 둥글게 돈 귀도 뾰족한 귀로). 거의 곧게 이어지는 변([minTurnDeg] 안)은 하나로 합친다.
/// 끝이 시작에서 [closeTol] 안이면 닫는다.
({List<Offset> pts, bool closed}) sketchStrokeToPolygon(
  List<Offset> stroke, {
  required double tol,
  required double closeTol,
  double minTurnDeg = 20,
}) {
  final s = <Offset>[];
  for (final p in stroke) {
    if (s.isEmpty || (p - s.last).distance >= tol / 4) s.add(p);
  }
  if (s.length < 2) return (pts: const [], closed: false);
  var len = 0.0;
  for (var i = 1; i < s.length; i++) {
    len += (s[i] - s[i - 1]).distance;
  }
  final closed =
      s.length >= 6 &&
      (s.last - s.first).distance <= closeTol &&
      len > closeTol * 4;
  // 닫힌 것은 가운데에서 가장 먼 점(귀일 가능성이 큼)에서 다시 시작해 한 바퀴(끝 = 시작)
  var ring = s;
  if (closed) {
    var c = Offset.zero;
    for (final p in s) {
      c += p;
    }
    c = c / s.length.toDouble();
    var k = 0;
    for (var i = 1; i < s.length; i++) {
      if ((s[i] - c).distance > (s[k] - c).distance) k = i;
    }
    ring = [...s.sublist(k), ...s.sublist(0, k), s[k]];
  }
  final idx = _rdpIdx(ring, 0, ring.length - 1, tol);
  final minSeg = closed ? 3 : 1;
  // 짧은 변(둥글게 돈 귀 자리)은 안쪽 꼭짓점 하나를 빼서 없앤다(직선 맞추기가 귀를 되살린다)
  var changed = true;
  while (changed && idx.length - 1 > minSeg) {
    changed = false;
    for (var j = 0; j < idx.length - 1; j++) {
      if ((ring[idx[j + 1]] - ring[idx[j]]).distance >= tol * 2) continue;
      final drop = j + 1 < idx.length - 1 ? j + 1 : j;
      if (drop == 0 || drop == idx.length - 1) continue;
      idx.removeAt(drop);
      changed = true;
      break;
    }
  }
  // 변마다 직선 맞추기(귀 근처 점은 빼고)
  List<(Offset, Offset)> fit() => [
    for (var j = 0; j < idx.length - 1; j++)
      () {
        final a = ring[idx[j]], b = ring[idx[j + 1]];
        final margin = math.min(tol * 1.5, (b - a).distance / 4);
        final mid = [
          for (var i = idx[j]; i <= idx[j + 1]; i++)
            if ((ring[i] - a).distance > margin &&
                (ring[i] - b).distance > margin)
              ring[i],
        ];
        final d = b - a;
        return _fitLine(
          mid.length >= 2 ? mid : [a, b],
          d.distance < 1e-9 ? const Offset(1, 0) : d / d.distance,
        );
      }(),
  ];
  var lines = fit();
  // 거의 곧게 이어지는 두 변은 하나로
  changed = true;
  while (changed && lines.length > minSeg) {
    changed = false;
    for (var j = 1; j < lines.length; j++) {
      if (_dirDiffDeg(lines[j - 1].$2, lines[j].$2) >= minTurnDeg) continue;
      idx.removeAt(j);
      lines = fit();
      changed = true;
      break;
    }
  }
  // 귀 = 이웃 직선이 만나는 점(못 만나거나 너무 멀면 그 자리 점)
  final out = <Offset>[];
  final n = lines.length;
  Offset corner(int j, (Offset, Offset) a, (Offset, Offset) b) {
    final x = _cross(a.$1, a.$2, b.$1, b.$2);
    final raw = ring[idx[j]];
    return x != null && (x - raw).distance <= tol * 4 ? x : raw;
  }

  if (closed) {
    for (var j = 0; j < n; j++) {
      out.add(corner(j, lines[(j - 1 + n) % n], lines[j]));
    }
    // 첫 변과 마지막 변이 곧게 이어지면 그 사이 귀(시작점)는 귀가 아니다
    if (out.length > 3 &&
        _dirDiffDeg(lines.last.$2, lines.first.$2) < minTurnDeg) {
      out.removeAt(0);
    }
  } else {
    Offset proj(Offset p, (Offset, Offset) l) {
      final d = p - l.$1;
      return l.$1 + l.$2 * (d.dx * l.$2.dx + d.dy * l.$2.dy);
    }

    out.add(proj(ring.first, lines.first));
    for (var j = 1; j < n; j++) {
      out.add(corner(j, lines[j - 1], lines[j]));
    }
    out.add(proj(ring.last, lines.last));
  }
  if (closed && out.length < 3) return (pts: out, closed: false);
  return (pts: out, closed: closed);
}

// 그은 선이 작은 고리(구멍 그림)면 가운데·긴 쪽·짧은 쪽 길이·긴 쪽 방향(°), 아니면 null.
({Offset c, double major, double minor, double angleDeg})? sketchLoopShape(
  List<Offset> stroke, {
  required double closeTol,
}) {
  if (stroke.length < 8) return null;
  var r = Rect.fromPoints(stroke.first, stroke.first);
  var c = Offset.zero;
  for (final p in stroke) {
    r = r.expandToInclude(Rect.fromPoints(p, p));
    c += p;
  }
  c = c / stroke.length.toDouble();
  final ext = math.max(r.width, r.height);
  if (ext < 1e-9) return null;
  if ((stroke.last - stroke.first).distance > math.max(closeTol, ext * 0.35)) {
    return null;
  }
  var sxx = 0.0, syy = 0.0, sxy = 0.0;
  for (final p in stroke) {
    final d = p - c;
    sxx += d.dx * d.dx;
    syy += d.dy * d.dy;
    sxy += d.dx * d.dy;
  }
  final ang = 0.5 * math.atan2(2 * sxy, sxx - syy);
  final u = Offset(math.cos(ang), math.sin(ang));
  final v = Offset(-u.dy, u.dx);
  var u0 = double.infinity, u1 = -double.infinity;
  var v0 = double.infinity, v1 = -double.infinity;
  for (final p in stroke) {
    final d = p - c;
    final pu = d.dx * u.dx + d.dy * u.dy, pv = d.dx * v.dx + d.dy * v.dy;
    u0 = math.min(u0, pu);
    u1 = math.max(u1, pu);
    v0 = math.min(v0, pv);
    v1 = math.max(v1, pv);
  }
  final center = c + u * ((u0 + u1) / 2) + v * ((v0 + v1) / 2);
  var major = u1 - u0, minor = v1 - v0, deg = ang * 180 / math.pi;
  if (minor > major) {
    final t = major;
    major = minor;
    minor = t;
    deg += 90;
  }
  deg = ((deg % 180) + 180) % 180;
  return (c: center, major: major, minor: minor, angleDeg: deg);
}

/// 점이 닫힌 꼭짓점 다각형 안에 있는지(꼭짓점 셋 이상).
bool sketchContains(List<Offset> pts, Offset p) {
  if (pts.length < 3) return false;
  var inside = false;
  for (var i = 0, j = pts.length - 1; i < pts.length; j = i++) {
    final a = pts[i], b = pts[j];
    if ((a.dy > p.dy) != (b.dy > p.dy) &&
        p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
      inside = !inside;
    }
  }
  return inside;
}

/// 닫힌 꼭짓점 차례를 앱 약속대로: 반시계 방향, 왼쪽 아래 귀부터(그은 시작 자리와 상관없이 번호가 같게).
List<Offset> sketchNormalizeLoop(List<Offset> pts) {
  if (pts.length < 3) return List.of(pts);
  var area2 = 0.0;
  for (var i = 0; i < pts.length; i++) {
    final a = pts[i], b = pts[(i + 1) % pts.length];
    area2 += a.dx * b.dy - b.dx * a.dy;
  }
  final ccw = area2 >= 0 ? List.of(pts) : pts.reversed.toList();
  var k = 0;
  for (var i = 1; i < ccw.length; i++) {
    if (ccw[i].dx + ccw[i].dy < ccw[k].dx + ccw[k].dy - 1e-9) k = i;
  }
  return [...ccw.sublist(k), ...ccw.sublist(0, k)];
}
