import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'package:tubing_calculator/src/core/engine/bend_path.dart';

import 'layout_board_models.dart';
import 'skid_part_painter.dart' show SkidFace;
import 'skid_presets.dart';

// 🚀 스키드 전선관 경로. 전선관 벤딩 계산기 입력 목록과 같은 모양(길이·각도·방향값)으로
// 적어 두고, 계산기가 쓰는 공간 걷기(buildBendPath, 모서리 반경 0)로 꺾이는 점을 낸다.
//
// 좌표(mm)
//  - 스키드: x = 평면 왼쪽에서 오른쪽(길이), y = 평면 위에서 아래(앞 쪽), z = 바닥에서 위.
//  - 계산기 공간: 오른쪽 +x, 위 +y, 앞 +z. → 스키드 (x, y, z) = (계산 x, 계산 z, 계산 y).
//  - 방향값: 0 위, 90 오른쪽, 180 아래, 270 왼쪽, 360 앞(평면 아래쪽), 450 뒤.

/// 방향값과 화면에 쓰는 이름. 계산기 방향 칸과 같은 값이다.
const List<(double, String, String)> kRouteDirections = [
  (0, 'UP', '위'),
  (180, 'DOWN', '아래'),
  (270, 'LEFT', '왼쪽'),
  (90, 'RIGHT', '오른쪽'),
  (360, 'FRONT', '앞'),
  (450, 'BACK', '뒤'),
];

String routeDirLabel(double rot) => kRouteDirections
    .firstWhere((d) => d.$1 == rot, orElse: () => kRouteDirections[3])
    .$3;

String routeDirName(double rot) => kRouteDirections
    .firstWhere((d) => d.$1 == rot, orElse: () => kRouteDirections[3])
    .$2;

/// 반대 방향값(오프셋 두 번째 벤드).
double oppositeRouteDir(double rot) => switch (rot) {
  0 => 180,
  180 => 0,
  90 => 270,
  270 => 90,
  360 => 450,
  450 => 360,
  _ => rot,
};

class ConduitRoute {
  String id;
  String name;

  /// 후강 호칭(16·22·…).
  int size;

  /// 시작 모듈 id(평면). 없거나 지워졌으면 (x, y, z)에서 시작한다.
  String? startItemId;
  double x, y, z;

  /// 처음 나가는 방향값.
  double startDir;

  /// 계산기 입력 목록과 같은 줄들: {length, angle, rotation}.
  List<Map<String, dynamic>> bends;

  /// 끝 부품 id(평면). 있으면 마지막 꺾이는 점에서 나가는 방향으로 그 부품 가운데까지
  /// 곧게 이어, 마지막 줄 길이를 손으로 안 넣어도 된다. 없거나 지워졌으면 마지막 꺾이는 점에서 끝.
  String? endItemId;

  ConduitRoute({
    required this.id,
    required this.name,
    this.size = 22,
    this.startItemId,
    this.x = 0,
    this.y = 0,
    this.z = 0,
    this.startDir = 90,
    List<Map<String, dynamic>>? bends,
    this.endItemId,
  }) : bends = bends ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'size': size,
    if (startItemId != null) 'start': startItemId,
    'x': x,
    'y': y,
    'z': z,
    'dir': startDir,
    'bends': bends,
    if (endItemId != null) 'end': endItemId,
  };

  factory ConduitRoute.fromJson(Map<String, dynamic> j) => ConduitRoute(
    id: j['id']?.toString() ?? 'r',
    name: j['name']?.toString() ?? '경로',
    size: (j['size'] as num?)?.toInt() ?? 22,
    startItemId: j['start'] as String?,
    x: (j['x'] as num?)?.toDouble() ?? 0,
    y: (j['y'] as num?)?.toDouble() ?? 0,
    z: (j['z'] as num?)?.toDouble() ?? 0,
    startDir: (j['dir'] as num?)?.toDouble() ?? 90,
    bends: [
      for (final b in (j['bends'] as List?) ?? const [])
        if (b is Map) Map<String, dynamic>.from(b),
    ],
    endItemId: j['end'] as String?,
  );

  double get od => kThickConduitOd[size] ?? 26.5;

  /// 계산기 공간 걷기(반경 0). 꺾이는 점과 끝 방향을 쓴다.
  BendPath _path() => buildBendPath(
    [
      for (final b in bends)
        PathSegment(
          length: (b['length'] as num?)?.toDouble() ?? 0,
          angle: (b['angle'] as num?)?.toDouble() ?? 0,
          rotation: (b['rotation'] as num?)?.toDouble() ?? 0,
        ),
    ],
    radius: 0,
    startDirection: directionForName(routeDirName(startDir)),
  );

  /// 계산기 공간 벡터를 스키드 좌표로: (계산 x, 계산 z, 계산 y).
  static vm.Vector3 _toSkid(vm.Vector3 c) => vm.Vector3(c.x, c.z, c.y);

  /// 끝 부품까지 마지막 줄. [length]는 마지막 꺾이는 점에서 끝 방향으로 부품 가운데까지,
  /// [miss]는 그 방향에서 부품 가운데가 비켜 난 거리(0이면 정확히 닿는다). 끝 부품이 없으면 null.
  ({double length, double miss, PlacedItem item})? endRun(
    List<PlacedItem> planItems,
  ) {
    if (endItemId == null) return null;
    PlacedItem? it;
    for (final e in planItems) {
      if (e.id == endItemId) it = e;
    }
    if (it == null) return null;
    final path = _path();
    final s = startPoint(planItems);
    final vm.Vector3 last = path.corners.isEmpty
        ? s
        : s + _toSkid(path.corners.last);
    final vm.Vector3 dir = _toSkid(path.endDirection).normalized();
    final target = vm.Vector3(
      it.position.dx + it.width / 2,
      it.position.dy + it.height / 2,
      it.elevation ?? last.z,
    );
    final d = target - last;
    final double len = d.dot(dir);
    final double miss = (d - dir * len).length;
    return (length: len < 0 ? 0 : len, miss: miss, item: it);
  }

  /// 꺾이는 점 사이 합 + 끝 부품까지 마지막 줄.
  double totalLengthWith(List<PlacedItem> planItems) =>
      totalLength + (endRun(planItems)?.length ?? 0);

  /// 끝 부품 관련 경고: 끝 부품이 사라졌거나, 마지막 줄 방향에서 부품이 관 굵기보다 비켜 나 있다.
  List<String> endWarnings(List<PlacedItem> planItems) {
    if (endItemId == null) return const [];
    final r = endRun(planItems);
    if (r == null) return const ["끝 부품이 평면에 없습니다(지워졌거나 다른 도면)."];
    if (r.miss > od) {
      return [
        "마지막 줄이 끝 부품 '${r.item.name}' 가운데에서 ${r.miss.round()}mm 비켜 갑니다. 방향이나 앞 줄 길이를 고치십시오.",
      ];
    }
    if (r.length <= 0) {
      return ["끝 부품 '${r.item.name}'이(가) 마지막 줄 방향 뒤에 있습니다."];
    }
    return const [];
  }

  /// 시작점(스키드 좌표). 시작 모듈이 있으면 그 가운데·바닥에서 높이.
  vm.Vector3 startPoint(List<PlacedItem> planItems) {
    for (final it in planItems) {
      if (it.id == startItemId) {
        return vm.Vector3(
          it.position.dx + it.width / 2,
          it.position.dy + it.height / 2,
          it.elevation ?? z,
        );
      }
    }
    return vm.Vector3(x, y, z);
  }

  /// 시작점과 꺾이는 점들(스키드 좌표). 끝 부품이 있으면 마지막 줄 끝점도 붙는다.
  List<vm.Vector3> points(List<PlacedItem> planItems) {
    final s = startPoint(planItems);
    final path = _path();
    final pts = [
      s,
      for (final c in path.corners) vm.Vector3(s.x + c.x, s.y + c.z, s.z + c.y),
    ];
    final end = endRun(planItems);
    if (end != null && end.length > 0) {
      pts.add(pts.last + _toSkid(path.endDirection).normalized() * end.length);
    }
    return pts;
  }

  /// 계산기가 알려 주는 경고(꺾을 수 없는 방향·짧은 구간 등, 반경 0 기준).
  List<String> warnings() => buildBendPath(
    [
      for (final b in bends)
        PathSegment(
          length: (b['length'] as num?)?.toDouble() ?? 0,
          angle: (b['angle'] as num?)?.toDouble() ?? 0,
          rotation: (b['rotation'] as num?)?.toDouble() ?? 0,
        ),
    ],
    radius: 0,
    startDirection: directionForName(routeDirName(startDir)),
  ).warnings;

  /// 전선관 길이 합(꺾이는 점 사이 길이의 합, 벤드 게인은 계산기가 뺀다).
  double get totalLength => bends.fold<double>(
    0,
    (a, b) => a + ((b['length'] as num?)?.toDouble() ?? 0),
  );
}

/// 오프셋 한 번 = 벤드 두 줄. [before]는 앞 꺾이는 점에서 첫 벤드까지,
/// [offset]은 비켜 가는 거리, [angle]은 오프셋 각도, [dir]은 비켜 가는 방향값.
/// 두 번째 줄 길이 = offset ÷ sin(angle)(두 꺾이는 점 사이).
List<Map<String, dynamic>> offsetBends({
  required double before,
  required double offset,
  required double angle,
  required double dir,
}) {
  final double travel = offset / math.sin(angle * math.pi / 180);
  double r1(double v) => (v * 10).roundToDouble() / 10;
  return [
    {'length': r1(before), 'angle': angle, 'rotation': dir},
    {'length': r1(travel), 'angle': angle, 'rotation': oppositeRouteDir(dir)},
  ];
}

/// 스키드 도면 탭(평면·정면·좌측면·우측면)에 3D 점을 옮긴다.
/// [planW]·[planH]는 평면 크기(길이·폭), [viewH]는 그 탭 도면의 세로(높이).
Offset projectToView(
  vm.Vector3 p,
  String view, {
  required double planW,
  required double planH,
  required double viewH,
}) => switch (view) {
  kSkidViewFront => Offset(p.x, viewH - p.z),
  'left' => Offset(p.y, viewH - p.z),
  'right' => Offset(planH - p.y, viewH - p.z),
  _ => Offset(p.x, p.y),
};

/// 평면 부품을 정면·측면에 옮길 때 높이 방향 크기(어림).
/// 형강 = 단면 높이(규격 이름 첫 숫자, 각파이프는 둘째), 전선관 = 바깥지름, 그 밖 = 평면 세로.
double skidVerticalSize(PlacedItem it) {
  // 전선관 부속은 깊이 칸에 바닥에서 본 높이를 넣어 둔다.
  if (SkidShape.isFitting(it.shape) && it.depth != null && it.depth! > 0) {
    return it.depth!;
  }
  final nums = RegExp(
    r'(\d+(?:\.\d+)?)',
  ).allMatches(it.name).map((m) => double.parse(m.group(1)!)).toList();
  switch (it.shape) {
    case SkidShape.beam:
    case SkidShape.channel:
    case SkidShape.angle:
    case SkidShape.strut:
      return nums.isNotEmpty ? nums[0] : it.height;
    case SkidShape.square:
      return nums.length > 1 ? nums[1] : it.height;
    default:
      return math.min(it.width, it.height);
  }
}

/// 평면 부품이 정면·좌측면·우측면 탭에서 차지하는 자리(그 탭 mm, 위가 0).
/// 바닥에서 높이를 안 넣은 부품은 바닥에 놓인 것으로 본다.
Rect skidViewRect(
  PlacedItem it,
  String view, {
  required double planH,
  required double viewH,
}) {
  final double v = skidVerticalSize(it);
  final double elev = it.elevation ?? v / 2;
  final double top = viewH - (elev + v / 2);
  final (double l, double w) = switch (view) {
    kSkidViewFront => (it.position.dx, it.width),
    'left' => (it.position.dy, it.height),
    _ => (planH - it.position.dy - it.height, it.height),
  };
  return Rect.fromLTWH(l, top, w, v);
}

/// 그 탭에서 보는 사람과 가까운 정도(클수록 가깝다). 정면은 평면 아래쪽(y 큰 쪽)에서,
/// 좌측면은 x=0 쪽에서, 우측면은 x 큰 쪽에서 본다.
double skidViewNearness(PlacedItem it, String view) => switch (view) {
  kSkidViewFront => it.position.dy + it.height,
  'left' => -it.position.dx,
  _ => it.position.dx + it.width,
};

/// 정면·측면에 그릴 평면 부품 차례(먼 것부터 — 가까운 것이 위에 그려지고 먼저 잡힌다)와
/// 가려진 정도(0~1: 더 가까운 부품에 덮인 넓이 비율, 겹친 넓이를 더해 1에서 자른다).
List<({PlacedItem it, Rect rect, SkidFace face, double covered})>
skidViewLayout(
  List<PlacedItem> plan,
  String view, {
  required double planH,
  required double viewH,
}) {
  final items = [
    for (final it in plan)
      (
        it: it,
        rect: skidViewRect(it, view, planH: planH, viewH: viewH),
        face: skidViewFace(it, view),
        near: skidViewNearness(it, view),
      ),
  ]..sort((a, b) => a.near.compareTo(b.near));
  return [
    for (int i = 0; i < items.length; i++)
      (
        it: items[i].it,
        rect: items[i].rect,
        face: items[i].face,
        covered: () {
          final Rect r = items[i].rect;
          final double area = r.width * r.height;
          if (area <= 0) return 0.0;
          double sum = 0;
          for (int j = i + 1; j < items.length; j++) {
            // 같은 깊이(나란히 놓인 것)는 가리지 않는다.
            if (items[j].near <= items[i].near) continue;
            final Rect x = r.intersect(items[j].rect);
            if (x.width > 0 && x.height > 0) sum += x.width * x.height;
          }
          return math.min(1.0, sum / area);
        }(),
      ),
  ];
}

/// 그 탭에서 부품이 보이는 방향: 부품 길이가 보는 면과 나란하면 옆모습, 보는 쪽으로
/// 뻗어 있으면 끝모습(형강은 단면). 정션박스는 늘 옆모습.
SkidFace skidViewFace(PlacedItem it, String view) {
  if (it.shape == SkidShape.jb || !SkidShape.isSkid(it.shape)) {
    return SkidFace.side;
  }
  // 커플링·유니온은 지름이 길이보다 클 수 있어, 칸 비율 대신 돌린 횟수로 길이 방향을 본다.
  final bool alongX = skidTurnsOnly(it.shape)
      ? (it.quarterTurns ?? 0).isEven
      : it.width >= it.height;
  final bool viewSeesX = view == kSkidViewFront;
  return alongX == viewSeesX ? SkidFace.side : SkidFace.end;
}

/// 정면·측면 탭에 연하게 보여 줄 평면 부품(바닥에서 높이를 넣은 것만).
class SkidGhost {
  final String name;
  final Rect rect;
  const SkidGhost(this.name, this.rect);
}

List<SkidGhost> skidGhosts(
  List<PlacedItem> planItems,
  String view, {
  required double planH,
  required double viewH,
}) {
  if (view == kPlateMainId) return const [];
  final out = <SkidGhost>[];
  for (final it in planItems) {
    final double? elev = it.elevation;
    if (elev == null) continue;
    final double v = skidVerticalSize(it);
    final double top = viewH - (elev + v / 2);
    final (double l, double w) = switch (view) {
      kSkidViewFront => (it.position.dx, it.width),
      'left' => (it.position.dy, it.height),
      _ => (planH - it.position.dy - it.height, it.height),
    };
    out.add(SkidGhost(it.name, Rect.fromLTWH(l, top, w, v)));
  }
  return out;
}

/// 평면 탭 id(layout_plates.dart의 kPlateMain과 같다).
const String kPlateMainId = 'main';

/// 스키드 탭 위에 전선관 경로(굵기 = 후강 바깥지름)와 평면 부품 그림자를 그린다.
class SkidOverlayPainter extends CustomPainter {
  final List<(String, List<Offset>, double)> routes;
  final List<SkidGhost> ghosts;
  final String version;

  /// 이름 글씨·점·가는 선 배율([dimensionMarkScale]과 같은 값).
  final double markScale;

  const SkidOverlayPainter({
    required this.routes,
    required this.ghosts,
    required this.version,
    this.markScale = 1,
  });

  static const Color _route = Color(0xFF0E7490);

  @override
  void paint(Canvas canvas, Size size) {
    final ghostFill = Paint()..color = const Color(0x2294A3B8);
    final ghostLine = Paint()
      ..color = const Color(0xFF94A3B8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 * markScale;
    for (final g in ghosts) {
      canvas.drawRect(g.rect, ghostFill);
      _dashRect(canvas, g.rect, ghostLine);
      _label(
        canvas,
        g.name,
        g.rect.center,
        const Color(0xFF64748B),
        10 * markScale,
      );
    }
    for (final (name, pts, od) in routes) {
      if (pts.length < 2) continue;
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = _route.withValues(alpha: 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = od
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = _route
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * markScale,
      );
      for (final p in pts) {
        canvas.drawCircle(p, 3 * markScale, Paint()..color = _route);
      }
      _label(
        canvas,
        name,
        pts.first + Offset(0, -14 * markScale),
        _route,
        11 * markScale,
      );
    }
  }

  void _dashRect(Canvas c, Rect r, Paint p) {
    void dash(Offset a, Offset b) {
      final double len = (b - a).distance;
      if (len <= 0) return;
      final Offset d = (b - a) / len;
      for (double t = 0; t < len; t += 12 * markScale) {
        c.drawLine(a + d * t, a + d * math.min(t + 7 * markScale, len), p);
      }
    }

    dash(r.topLeft, r.topRight);
    dash(r.topRight, r.bottomRight);
    dash(r.bottomRight, r.bottomLeft);
    dash(r.bottomLeft, r.topLeft);
  }

  void _label(Canvas c, String text, Offset at, Color color, double size) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w800,
          backgroundColor: const Color(0xCCFFFFFF),
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 400 * markScale);
    tp.paint(c, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant SkidOverlayPainter old) =>
      old.version != version || old.markScale != markScale;
}
