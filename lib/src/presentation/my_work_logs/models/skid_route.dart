import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'package:tubing_calculator/src/core/engine/bend_path.dart';

import 'layout_board_models.dart';
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
  );

  double get od => kThickConduitOd[size] ?? 26.5;

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

  /// 시작점과 꺾이는 점들(스키드 좌표).
  List<vm.Vector3> points(List<PlacedItem> planItems) {
    final s = startPoint(planItems);
    final path = buildBendPath(
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
    return [
      s,
      for (final c in path.corners) vm.Vector3(s.x + c.x, s.y + c.z, s.z + c.y),
    ];
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

  const SkidOverlayPainter({
    required this.routes,
    required this.ghosts,
    required this.version,
  });

  static const Color _route = Color(0xFF0E7490);

  @override
  void paint(Canvas canvas, Size size) {
    final ghostFill = Paint()..color = const Color(0x2294A3B8);
    final ghostLine = Paint()
      ..color = const Color(0xFF94A3B8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final g in ghosts) {
      canvas.drawRect(g.rect, ghostFill);
      _dashRect(canvas, g.rect, ghostLine);
      _label(canvas, g.name, g.rect.center, const Color(0xFF64748B), 10);
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
          ..strokeWidth = 1.5,
      );
      for (final p in pts) {
        canvas.drawCircle(p, 3, Paint()..color = _route);
      }
      _label(canvas, name, pts.first + const Offset(0, -14), _route, 11);
    }
  }

  void _dashRect(Canvas c, Rect r, Paint p) {
    void dash(Offset a, Offset b) {
      final double len = (b - a).distance;
      if (len <= 0) return;
      final Offset d = (b - a) / len;
      for (double t = 0; t < len; t += 12) {
        c.drawLine(a + d * t, a + d * math.min(t + 7, len), p);
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
    )..layout(maxWidth: 400);
    tp.paint(c, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant SkidOverlayPainter old) =>
      old.version != version;
}
