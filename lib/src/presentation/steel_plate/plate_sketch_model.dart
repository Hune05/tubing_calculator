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

  /// 변 [i] 다음부터 돌며 [want]에 맞는 잠기지 않은 변 하나([i] 빼고).
  int? _nextFree(int i, bool Function(Offset v) want) {
    for (var s = 1; s < edgeCount; s++) {
      final k = (i + s) % edgeCount;
      if (!isLocked(k) && want(edgeVec(k))) return k;
    }
    return null;
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

  /// 변 [i]의 길이를 [mm]로 넣고 잠근다. 처음 넣는 치수면 전체 크기(축척)를 정한다.
  /// 그다음부터는 넣은(잠긴) 길이와 가로·세로를 지키며, 같은 방향의 잠기지 않은 변 하나가 차이를 받는다
  /// (평면도 앱의 치수 잠금과 같은 방식). 받을 변이 없으면 바꾸지 않고 [note]로 차이를 알린다.
  /// 닫기 전에는 그 변 뒤 꼭짓점들을 같이 옮긴다.
  ({bool ok, String? note}) setEdge(int i, double mm) {
    if (i >= edgeCount || mm <= 0) return (ok: false, note: null);
    final cur = edgeLen(i);
    if (cur < 1e-9) return (ok: false, note: null);
    String? note;
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
        if (_isH(v) || _isV(v)) {
          final h = _isH(v);
          final k = _nextFree(i, h ? _isH : _isV);
          if (k == null) {
            final dir = h ? '가로' : '세로';
            return (
              ok: false,
              note:
                  '$dir 변이 모두 잠겨 있어 맞출 곳이 없습니다(${_f((mm - cur).abs())}mm 차이). 잠긴 $dir 치수 하나를 고치거나 잠금을 푸십시오.',
            );
          }
          _shiftBetween(i, k, delta);
        } else {
          // 기운 변: 가로 몫은 가로 변이, 세로 몫은 세로 변이 받는다
          final kx = delta.dx.abs() > 1e-9 ? _nextFree(i, _isH) : -1;
          final ky = delta.dy.abs() > 1e-9 ? _nextFree(i, _isV) : -1;
          if (kx != null && ky != null) {
            if (kx >= 0) _shiftBetween(i, kx, Offset(delta.dx, 0));
            if (ky >= 0) _shiftBetween(i, ky, Offset(0, delta.dy));
          } else {
            final k = _nextFree(i, (_) => true);
            if (k == null) {
              return (
                ok: false,
                note: '다른 변이 모두 잠겨 있어 이 길이로 맞출 수 없습니다. 잠긴 치수 하나를 푸십시오.',
              );
            }
            _shiftBetween(i, k, delta);
            note = '맞출 가로·세로 변이 없어 변 ${k + 1} 기울기가 바뀌었습니다.';
          }
        }
      }
    }
    dims[ids[i]] = mm;
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
