import 'dart:math' as math;
import 'dart:ui' show Color, Offset, Size;

import 'package:vector_math/vector_math_64.dart' as vm;

import 'instrument_shape_painter.dart' show InstrumentShape;
import 'layout_board_models.dart';
import 'skid_presets.dart';
import 'skid_route.dart';

// 🚀 스키드 입체 보기(보기 전용): 평면 부품과 전선관 경로를 상자·관 토막으로 바꿔 놓는다.
// 좌표는 스키드 평면 그대로(mm): x = 길이, y = 폭(평면 아래쪽, 정면에서 보는 쪽이 큼), z = 바닥에서 위.
// 부품마다 평면 자리(position·width·height)와 바닥에서 높이(elevation, 가운데까지)·세로 크기(skidVerticalSize)만
// 쓰므로 부품 크기가 실제 mm 그대로면 구조물이 아무리 커도 같은 식으로 나온다.

/// 입체 보기에서 그리는 상자 하나.
class IsoBox {
  final double x0, y0, z0, x1, y1, z1;
  final Color color;

  /// 이 상자가 속한 평면 부품 id(눌러서 고르는 데 쓴다). 없으면 부품이 아님.
  final String? partId;

  /// 긴 상자를 길이 방향으로 잘랐을 때 잘린 쪽 면(안쪽 이음 자리)이면 true. 그릴 때 이 자리의 테두리는 안 긋는다.
  /// [cutAlongX]가 참이면 x0·x1 쪽, 아니면 y0·y1 쪽 면이다.
  final bool cutLo;
  final bool cutHi;
  final bool cutAlongX;

  const IsoBox(
    this.x0,
    this.y0,
    this.z0,
    this.x1,
    this.y1,
    this.z1,
    this.color, {
    this.partId,
    this.cutLo = false,
    this.cutHi = false,
    this.cutAlongX = true,
  });

  double get cx => (x0 + x1) / 2;
  double get cy => (y0 + y1) / 2;
  double get cz => (z0 + z1) / 2;
}

/// 입체 보기에서 그리는 관(전선관 부품 또는 전선관 경로의 한 줄).
class IsoPipe {
  final vm.Vector3 a, b;

  /// 바깥지름(mm).
  final double od;
  final Color color;
  final String? partId;

  /// 끝이 둥근 관(전선관 경로·이음)이면 true, 잘린 끝(허브·커플링)이면 false.
  final bool round;

  const IsoPipe(
    this.a,
    this.b,
    this.od,
    this.color, {
    this.partId,
    this.round = true,
  });
}

/// 입체 보기에 그릴 것 전부와 둘러싸는 상자.
class IsoScene {
  final List<IsoBox> boxes;
  final List<IsoPipe> pipes;

  /// 스키드 바닥 크기(길이 × 폭). 바닥 격자를 그릴 때 쓴다.
  final double floorLength, floorWidth;

  /// 부품 개수(메모 제외)와 경로 줄 수.
  final int partCount;
  final int routeCount;

  /// 바닥에서 높이를 안 넣어 바닥에 놓은 것으로 그린 부품 수.
  final int noHeightCount;

  const IsoScene({
    required this.boxes,
    required this.pipes,
    required this.floorLength,
    required this.floorWidth,
    required this.partCount,
    required this.routeCount,
    this.noHeightCount = 0,
  });

  bool get isEmpty => boxes.isEmpty && pipes.isEmpty;

  /// 모든 것을 감싸는 상자(최소·최대). 바닥도 포함한다.
  ({vm.Vector3 min, vm.Vector3 max}) get bounds {
    double x0 = 0, y0 = 0, z0 = 0;
    double x1 = floorLength, y1 = floorWidth, z1 = 0;
    for (final b in boxes) {
      x0 = math.min(x0, b.x0);
      y0 = math.min(y0, b.y0);
      z0 = math.min(z0, b.z0);
      x1 = math.max(x1, b.x1);
      y1 = math.max(y1, b.y1);
      z1 = math.max(z1, b.z1);
    }
    for (final p in pipes) {
      final h = p.od / 2;
      for (final v in [p.a, p.b]) {
        x0 = math.min(x0, v.x - h);
        y0 = math.min(y0, v.y - h);
        z0 = math.min(z0, v.z - h);
        x1 = math.max(x1, v.x + h);
        y1 = math.max(y1, v.y + h);
        z1 = math.max(z1, v.z + h);
      }
    }
    return (min: vm.Vector3(x0, y0, z0), max: vm.Vector3(x1, y1, z1));
  }
}

// 색(부품 종류별). 위·옆면 밝기는 그릴 때 곱한다.
const Color _cBeam = Color(0xFF5B7C99);
const Color _cChannel = Color(0xFF4F8A8B);
const Color _cAngle = Color(0xFF7C8FA3);
const Color _cSquare = Color(0xFF8897A8);
const Color _cStrut = Color(0xFFA0AEC0);
const Color _cJb = Color(0xFFF59E0B);
const Color _cFitting = Color(0xFFE0A526);
const Color _cConduit = Color(0xFF0F766E);
const Color _cRoute = Color(0xFF14B8A6);
const Color _cOther = Color(0xFF94A3B8);
const Color _cHub = Color(0xFFA9B4C2); // 곤질레다 허브·커플링 쇠
const Color _cCover = Color(0xFFF1D58A); // 곤질레다 뚜껑
const Color _cLid = Color(0xFFFFB84D); // 정션박스 뚜껑

List<double> _nums(String name) => [
  for (final m in RegExp(r'(\d+(?:\.\d+)?)').allMatches(name))
    double.parse(m.group(1)!),
];

double _clamp(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);


/// 부속처럼 길이 방향·옆 방향이 있는 부품의 "자기 좌표"(u = 길이, v = 옆)를 평면 자리로 옮긴다.
/// 평면 그림(SkidPartPainter)과 같은 규칙: 먼저 길이 방향으로 뒤집고(flipped), 시계 방향으로 [q]번 90° 돌린다.
/// 자기 좌표에서 허브 하나는 u = 0(왼쪽 끝), 옆 허브 A는 v 작은 쪽(평면 위), B는 v 큰 쪽이다.
class _Frame {
  final double x0, y0, w, h;
  final int q;
  final bool flip;
  const _Frame(this.x0, this.y0, this.w, this.h, this.q, this.flip);

  /// 자기 좌표 길이(u 범위)와 옆 길이(v 범위).
  double get len => q.isOdd ? h : w;
  double get span => q.isOdd ? w : h;

  (double, double) plan(double u, double v) {
    final double uu = flip ? len - u : u;
    return switch (q) {
      0 => (x0 + uu, y0 + v),
      1 => (x0 + w - v, y0 + uu),
      2 => (x0 + w - uu, y0 + h - v),
      _ => (x0 + v, y0 + h - uu),
    };
  }

  vm.Vector3 p3(double u, double v, double z) {
    final (x, y) = plan(u, v);
    return vm.Vector3(x, y, z);
  }

  /// 자기 좌표의 직육면체 [u0,u1]×[v0,v1]×[zl,zh]를 평면 축에 맞춘 상자로.
  IsoBox box(
    double u0,
    double u1,
    double v0,
    double v1,
    double zl,
    double zh,
    Color col,
    String id,
  ) {
    final (xa, ya) = plan(u0, v0);
    final (xb, yb) = plan(u1, v1);
    return IsoBox(
      math.min(xa, xb),
      math.min(ya, yb),
      zl,
      math.max(xa, xb),
      math.max(yb, ya),
      zh,
      col,
      partId: id,
    );
  }
}

/// 곤질레다(삼화기전 F-7)를 몸통 + 뚜껑 + 허브(관 모양)로 세운다. 허브 자리는 평면 그림과 같다.
void _addCondulet(
  PlacedItem it,
  _Frame fr,
  double zBottom,
  double v,
  List<IsoBox> boxes,
  List<IsoPipe> pipes,
) {
  final String shape = it.shape!;
  final bool endR = shape == SkidShape.cdLT || shape == SkidShape.cdLX || shape == SkidShape.cdLC;
  final bool sideA = shape == SkidShape.cdLR || shape == SkidShape.cdLX;
  final bool sideB = shape == SkidShape.cdLL || shape == SkidShape.cdLT || shape == SkidShape.cdLX;
  final bool back = shape == SkidShape.cdLB;
  final double L = fr.len, C = fr.span;
  // 몸통이 차지하는 옆 폭 띠(평면 그림의 _bandOf와 같은 비율).
  final double bandStart = (sideA && sideB) ? C * 0.23 : (sideA ? C * 0.3 : 0);
  final double bandW = (sideA && sideB) ? C * 0.54 : ((sideA || sideB) ? C * 0.7 : C);
  final double hl = L * 0.14;
  final double bl = hl, br = endR ? L - hl : L;
  final double bodyH = back ? v * 0.7 : v;
  final double zTop = zBottom + v;
  final double zBodyBottom = zTop - bodyH;
  final double hd = math.min(bandW, bodyH) * 0.72;
  final double vc = bandStart + bandW / 2;
  final double zc = zBodyBottom + hd / 2;
  final String id = it.id;
  boxes.add(fr.box(bl, br, bandStart, bandStart + bandW, zBodyBottom, zTop, _cFitting, id));
  // 뚜껑: 위쪽 14%를 밝은 판으로(몸통보다 살짝 크게 덮는다).
  final double lid = bodyH * 0.14;
  final double inset = bandW * 0.04;
  boxes.add(
    fr.box(bl + inset, br - inset, bandStart + inset, bandStart + bandW - inset, zTop - lid, zTop, _cCover, id),
  );
  void hubAlongU(double u0, double u1) =>
      pipes.add(IsoPipe(fr.p3(u0, vc, zc), fr.p3(u1, vc, zc), hd, _cHub, partId: id, round: false));
  void hubAlongV(double u, double v0, double v1) =>
      pipes.add(IsoPipe(fr.p3(u, v0, zc), fr.p3(u, v1, zc), hd, _cHub, partId: id, round: false));
  hubAlongU(0, bl + 1);
  if (endR) hubAlongU(br - 1, L);
  final double hx = endR ? (bl + br) / 2 : br - bandW * 0.55;
  if (sideA) hubAlongV(hx, 0, bandStart + 1);
  if (sideB) hubAlongV(hx, bandStart + bandW - 1, C);
  if (back) {
    pipes.add(IsoPipe(fr.p3(hx, vc, zBottom), fr.p3(hx, vc, zBodyBottom + 1), hd, _cHub, partId: id, round: false));
  }
}

/// 커플링: 관 모양 몸통 + 양 끝 띠.
void _addCoupling(
  PlacedItem it,
  _Frame fr,
  double zc,
  List<IsoPipe> pipes,
) {
  final double od = fr.span;
  final double L = fr.len;
  final double vc = fr.span / 2;
  final id = it.id;
  pipes.add(IsoPipe(fr.p3(0, vc, zc), fr.p3(L, vc, zc), od * 0.94, _cHub, partId: id, round: false));
  pipes.add(IsoPipe(fr.p3(0, vc, zc), fr.p3(L * 0.14, vc, zc), od, _cHub, partId: id, round: false));
  pipes.add(IsoPipe(fr.p3(L * 0.86, vc, zc), fr.p3(L, vc, zc), od, _cHub, partId: id, round: false));
}

/// 유니온 커플링: 양 끝 가는 몸통 + 가운데 굵은 너트.
void _addUnion(PlacedItem it, _Frame fr, double zc, List<IsoPipe> pipes) {
  final double od = fr.span;
  final double L = fr.len;
  final double vc = fr.span / 2;
  final id = it.id;
  pipes.add(IsoPipe(fr.p3(0, vc, zc), fr.p3(L, vc, zc), od * 0.6, _cHub, partId: id, round: false));
  pipes.add(IsoPipe(fr.p3(L * 0.28, vc, zc), fr.p3(L * 0.72, vc, zc), od, const Color(0xFFB8C2CE), partId: id, round: false));
}

/// 평면 부품 하나를 입체 조각으로 바꾼다. H형강·찬넬·앵글은 단면대로 상자 둘~셋, 전선관은 관, 나머지는 한 상자.
void _addPart(PlacedItem it, List<IsoBox> boxes, List<IsoPipe> pipes) {
  final double x0 = it.position.dx, y0 = it.position.dy;
  final double x1 = x0 + it.width, y1 = y0 + it.height;
  if (x1 <= x0 || y1 <= y0) return;
  final double v = skidVerticalSize(it);
  if (v <= 0) return;
  final double zc = it.elevation ?? v / 2;
  final double z0 = zc - v / 2, z1 = zc + v / 2;
  final bool alongX = it.width >= it.height;
  final String id = it.id;
  final nums = _nums(it.name);

  // 길이(a) 방향과 단면(c) 방향 구간으로 상자를 만든다.
  IsoBox make(
    double a0,
    double a1,
    double c0,
    double c1,
    double zl,
    double zh,
    Color col,
  ) => alongX
      ? IsoBox(a0, c0, zl, a1, c1, zh, col, partId: id)
      : IsoBox(c0, a0, zl, c1, a1, zh, col, partId: id);

  final double a0 = alongX ? x0 : y0, a1 = alongX ? x1 : y1;
  final double c0 = alongX ? y0 : x0, c1 = alongX ? y1 : x1;
  final double cw = c1 - c0;

  if (SkidShape.isFitting(it.shape)) {
    final bool turnsOnly = skidTurnsOnly(it.shape);
    final int q = it.quarterTurns ?? (turnsOnly ? 0 : (it.height > it.width ? 1 : 0));
    final fr = _Frame(x0, y0, it.width, it.height, q, it.flipped);
    if (it.shape == SkidShape.coupling) {
      _addCoupling(it, fr, zc, pipes);
    } else if (it.shape == SkidShape.union) {
      _addUnion(it, fr, zc, pipes);
    } else {
      _addCondulet(it, fr, z0, v, boxes, pipes);
    }
    return;
  }
  switch (it.shape) {
    case SkidShape.beam:
      {
        final double tf = _clamp(nums.length > 3 ? nums[3] : v * 0.08, 1, v / 3);
        final double tw = _clamp(nums.length > 2 ? nums[2] : cw * 0.08, 1, cw / 2);
        final double cc = (c0 + c1) / 2;
        boxes.addAll([
          make(a0, a1, c0, c1, z0, z0 + tf, _cBeam),
          make(a0, a1, c0, c1, z1 - tf, z1, _cBeam),
          make(a0, a1, cc - tw / 2, cc + tw / 2, z0 + tf, z1 - tf, _cBeam),
        ]);
        return;
      }
    case SkidShape.channel:
      {
        final double tw = _clamp(nums.length > 2 ? nums[2] : cw * 0.1, 1, cw / 2);
        final double tf = _clamp(nums.length > 3 ? nums[3] : tw, 1, v / 3);
        boxes.addAll([
          make(a0, a1, c0, c0 + tw, z0, z1, _cChannel),
          make(a0, a1, c0, c1, z0, z0 + tf, _cChannel),
          make(a0, a1, c0, c1, z1 - tf, z1, _cChannel),
        ]);
        return;
      }
    case SkidShape.angle:
      {
        final double t = _clamp(nums.length > 2 ? nums[2] : v * 0.1, 1, math.min(v, cw) / 2);
        boxes.addAll([
          make(a0, a1, c0, c0 + t, z0, z1, _cAngle),
          make(a0, a1, c0, c1, z0, z0 + t, _cAngle),
        ]);
        return;
      }
    case SkidShape.square:
      boxes.add(make(a0, a1, c0, c1, z0, z1, _cSquare));
      return;
    case SkidShape.strut:
      boxes.add(make(a0, a1, c0, c1, z0, z1, _cStrut));
      return;
    case SkidShape.conduit:
      {
        final double od = math.min(it.width, it.height);
        final double cc = (c0 + c1) / 2;
        final vm.Vector3 pa = alongX
            ? vm.Vector3(a0, cc, zc)
            : vm.Vector3(cc, a0, zc);
        final vm.Vector3 pb = alongX
            ? vm.Vector3(a1, cc, zc)
            : vm.Vector3(cc, a1, zc);
        pipes.add(IsoPipe(pa, pb, od, _cConduit, partId: id, round: false));
        return;
      }
    case SkidShape.jb:
      boxes.add(IsoBox(x0, y0, z0, x1, y1, z1, _cJb, partId: id));
      // 뚜껑: 위쪽 10%를 밝은 판으로 덮는다.
      boxes.add(IsoBox(x0, y0, z1 - v * 0.1, x1, y1, z1, _cLid, partId: id));
      return;
    default:
      boxes.add(
        IsoBox(
          x0,
          y0,
          z0,
          x1,
          y1,
          z1,
          SkidShape.isFitting(it.shape) ? _cFitting : _cOther,
          partId: id,
        ),
      );
  }
}

/// 평면 부품과 전선관 경로로 입체 그림 재료를 만든다. [length]·[width]는 스키드 평면 크기(mm).
IsoScene buildSkidIsoScene(
  List<PlacedItem> plan,
  List<ConduitRoute> routes, {
  required double length,
  required double width,
}) {
  final boxes = <IsoBox>[];
  final pipes = <IsoPipe>[];
  int parts = 0;
  int noHeight = 0;
  for (final it in plan) {
    if (it.shape == InstrumentShape.note) continue;
    final before = boxes.length + pipes.length;
    _addPart(it, boxes, pipes);
    if (boxes.length + pipes.length > before) {
      parts++;
      if (it.elevation == null) noHeight++;
    }
  }
  int routeCount = 0;
  for (final r in routes) {
    final pts = r.points(plan);
    if (pts.length < 2) continue;
    routeCount++;
    for (var i = 0; i + 1 < pts.length; i++) {
      if ((pts[i + 1] - pts[i]).length < 1e-6) continue;
      pipes.add(IsoPipe(pts[i], pts[i + 1], r.od, _cRoute));
    }
    // 꺾이는 곳은 둥근 이음으로(길이 0인 관 = 동그란 점).
    for (var i = 1; i + 1 < pts.length; i++) {
      pipes.add(IsoPipe(pts[i], pts[i], r.od, _cRoute));
    }
  }
  return IsoScene(
    boxes: boxes,
    pipes: pipes,
    floorLength: length,
    floorWidth: width,
    partCount: parts,
    routeCount: routeCount,
    noHeightCount: noHeight,
  );
}

/// 보는 방향. [yaw]는 위에서 본 시계 반대 방향 돌림(0이면 정면, 곧 평면 아래쪽에서 봄), [pitch]는 눈높이에서 내려다보는 각(0 = 옆, π/2 = 바로 위).
class IsoView {
  final double yaw;
  final double pitch;
  const IsoView(this.yaw, this.pitch);

  static const IsoView standard = IsoView(0.62, 0.5);
  static const IsoView front = IsoView(0, 0);
  static const IsoView right = IsoView(math.pi / 2, 0);
  static const IsoView left = IsoView(-math.pi / 2, 0);
  static const IsoView back = IsoView(math.pi, 0);
  static const IsoView top = IsoView(0, math.pi / 2);

  IsoView copyWith({double? yaw, double? pitch}) =>
      IsoView(yaw ?? this.yaw, pitch ?? this.pitch);

  /// [p]를 (옆으로, 아래로, 가까운 정도)로 옮긴다. 가까운 정도가 클수록 보는 사람과 가깝다.
  /// [c]는 돌림의 가운데.
  ({double sx, double sy, double near}) project(vm.Vector3 p, vm.Vector3 c) {
    final double dx = p.x - c.x, dy = p.y - c.y, dz = p.z - c.z;
    final double cyw = math.cos(yaw), syw = math.sin(yaw);
    final double xr = dx * cyw - dy * syw;
    final double yr = dx * syw + dy * cyw;
    final double cp = math.cos(pitch), sp = math.sin(pitch);
    return (sx: xr, sy: yr * sp - dz * cp, near: yr * cp + dz * sp);
  }
}

/// 짧게 정한 눈금 간격(바닥 격자). 값을 1·2·5 × 10ⁿ으로 맞춘다.
double niceGridStep(double span, {int lines = 10}) {
  if (span <= 0) return 100;
  final raw = span / lines;
  final double mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final double f = raw / mag;
  final double n = f < 1.5 ? 1 : (f < 3.5 ? 2 : (f < 7.5 ? 5 : 10));
  return n * mag;
}

/// 지금 시점에서 화면을 가득 채우는 크기와 가운데 맞춤.
/// [scale]은 mm → 화면 점, [shift]는 둘러싸는 상자를 화면 가운데에 놓는 이동(확대 1일 때).
class IsoFit {
  final double scale;
  final Offset shift;
  const IsoFit(this.scale, this.shift);
}

/// 둘러싸는 상자 여덟 모서리를 [view]로 옮긴 모양이 [size]에 꽉 들어가게 크기를 정한다.
/// [margin]은 가장자리 여백(0~1, 작을수록 여백이 큼). 치수선이 들어갈 자리를 위해 상자를 조금 키워 잰다.
IsoFit fitIso(IsoScene scene, IsoView view, Size size, {double margin = 0.9}) {
  final b = scene.bounds;
  final vm.Vector3 c = (b.min + b.max) * 0.5;
  final double pad = (b.max - b.min).length * 0.08;
  final xs = [b.min.x - pad, b.max.x + pad];
  final ys = [b.min.y - pad, b.max.y + pad];
  final zs = [b.min.z, b.max.z + pad];
  double minX = double.infinity, maxX = -double.infinity;
  double minY = double.infinity, maxY = -double.infinity;
  for (final x in xs) {
    for (final y in ys) {
      for (final z in zs) {
        final q = view.project(vm.Vector3(x, y, z), c);
        minX = math.min(minX, q.sx);
        maxX = math.max(maxX, q.sx);
        minY = math.min(minY, q.sy);
        maxY = math.max(maxY, q.sy);
      }
    }
  }
  final double bw = math.max(maxX - minX, 1e-6), bh = math.max(maxY - minY, 1e-6);
  final double scale = math.min(size.width * margin / bw, size.height * margin / bh);
  return IsoFit(scale, Offset(-(minX + maxX) / 2 * scale, -(minY + maxY) / 2 * scale));
}
