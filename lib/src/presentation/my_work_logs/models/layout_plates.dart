import 'dart:math' as math;

import 'layout_board_models.dart';

// 🚀 캐비닛 좌·우 측판. 중판(뒤판)과 따로 도면을 가지고, 모듈마다 깊이(앞으로 튀어나오는
// 길이)를 넣으면 중판 부품과 측판 부품이 캐비닛 안에서 서로 부딪히는지 상자끼리 견준다.
//
// 좌표(mm)
//  - 캐비닛 안: 가로 x = 왼쪽 벽에서, 세로 y = 바닥(중판 아래 끝)에서, 깊이 z = 중판 면에서 문 쪽으로.
//  - 도면: 모듈 위치는 판의 왼쪽 위 기준(세로는 아래로 늘어난다).
//  - 측판은 캐비닛 전개도처럼 놓는다: 좌측판의 오른쪽 끝, 우측판의 왼쪽 끝이 중판 쪽(z = 0).

const String kPlateMain = 'main';
const String kPlateLeft = 'left';
const String kPlateRight = 'right';

const List<String> kPlateOrder = [kPlateLeft, kPlateMain, kPlateRight];

String plateLabel(String id) => switch (id) {
  kPlateLeft => '좌측판',
  kPlateRight => '우측판',
  _ => '중판',
};

/// 판 하나(중판 또는 측판).
class PlateData {
  final double width;
  final double height;
  final List<PlacedItem> items;

  /// 측판 바닥이 중판 바닥보다 높은 만큼(mm, 낮으면 음수).
  final double bottomOffset;

  /// 중판 옆 끝에서 그 쪽 벽(측판 면)까지 틈(mm).
  final double gap;

  const PlateData({
    required this.width,
    required this.height,
    required this.items,
    this.bottomOffset = 0,
    this.gap = 0,
  });

  factory PlateData.fromJson(Map<String, dynamic> j) => PlateData(
    width: (j['panelWidth'] as num?)?.toDouble() ?? 300,
    height: (j['panelHeight'] as num?)?.toDouble() ?? 800,
    items: layoutItemsFromData(j),
    bottomOffset: (j['bottomOffset'] as num?)?.toDouble() ?? 0,
    gap: (j['gap'] as num?)?.toDouble() ?? 0,
  );
}

/// 캐비닛 안의 상자 하나.
class CabinetBox {
  final String plate;
  final PlacedItem item;
  final double x0, x1, y0, y1, z0, z1;
  const CabinetBox(
    this.plate,
    this.item,
    this.x0,
    this.x1,
    this.y0,
    this.y1,
    this.z0,
    this.z1,
  );

  bool overlaps(CabinetBox o) =>
      math.min(x1, o.x1) - math.max(x0, o.x0) > 0.01 &&
      math.min(y1, o.y1) - math.max(y0, o.y0) > 0.01 &&
      math.min(z1, o.z1) - math.max(z0, o.z0) > 0.01;
}

/// 부딪히는 두 부품.
class PlateClash {
  final String plateA;
  final PlacedItem a;
  final String plateB;
  final PlacedItem b;
  const PlateClash(this.plateA, this.a, this.plateB, this.b);
}

/// 간섭 확인 결과.
class ClashReport {
  final List<PlateClash> clashes;

  /// 문까지 깊이보다 깊은 중판 부품.
  final List<PlacedItem> tooDeep;

  /// 깊이를 안 넣어서 견주지 못한 부품 수(판별).
  final Map<String, int> noDepth;

  const ClashReport(this.clashes, this.tooDeep, this.noDepth);

  /// 판 [plate]에서 문제가 있는 모듈 id.
  Set<String> problemIds(String plate) => {
    for (final c in clashes) ...[
      if (c.plateA == plate) c.a.id,
      if (c.plateB == plate) c.b.id,
    ],
    if (plate == kPlateMain) ...tooDeep.map((e) => e.id),
  };
}

/// 캐비닛 안쪽 폭(왼쪽 벽~오른쪽 벽).
double cabinetInnerWidth(PlateData main, PlateData? left, PlateData? right) =>
    (left?.gap ?? 0) + main.width + (right?.gap ?? 0);

List<CabinetBox> cabinetBoxes(
  PlateData main,
  PlateData? left,
  PlateData? right,
) {
  final out = <CabinetBox>[];
  final double gapL = left?.gap ?? 0;
  final double innerW = cabinetInnerWidth(main, left, right);
  for (final it in main.items) {
    final d = it.depth;
    if (d == null || d <= 0) continue;
    final double x = gapL + it.position.dx;
    final double yTop = main.height - it.position.dy;
    out.add(
      CabinetBox(kPlateMain, it, x, x + it.width, yTop - it.height, yTop, 0, d),
    );
  }
  void side(String id, PlateData? p) {
    if (p == null) return;
    for (final it in p.items) {
      final d = it.depth;
      if (d == null || d <= 0) continue;
      final double yTop = p.bottomOffset + p.height - it.position.dy;
      // 좌측판: 오른쪽 끝이 중판(z = 0). 우측판: 왼쪽 끝이 중판.
      final double z0 = id == kPlateLeft
          ? p.width - it.position.dx - it.width
          : it.position.dx;
      final double x0 = id == kPlateLeft ? 0 : innerW - d;
      out.add(
        CabinetBox(
          id,
          it,
          x0,
          x0 + d,
          yTop - it.height,
          yTop,
          z0,
          z0 + it.width,
        ),
      );
    }
  }

  side(kPlateLeft, left);
  side(kPlateRight, right);
  return out;
}

/// 판 사이(중판↔측판, 좌↔우 측판) 부품 간섭과 문 깊이 초과를 찾는다.
/// 같은 판 안에서 겹치는 것은 도면에서 눈으로 보이므로 따로 세지 않는다.
ClashReport checkCabinetClashes({
  required PlateData main,
  PlateData? left,
  PlateData? right,
  double? cabinetDepth,
}) {
  final boxes = cabinetBoxes(main, left, right);
  final clashes = <PlateClash>[];
  for (int i = 0; i < boxes.length; i++) {
    for (int j = i + 1; j < boxes.length; j++) {
      final a = boxes[i], b = boxes[j];
      if (a.plate == b.plate) continue;
      if (a.overlaps(b)) {
        clashes.add(PlateClash(a.plate, a.item, b.plate, b.item));
      }
    }
  }
  final tooDeep = <PlacedItem>[
    if (cabinetDepth != null && cabinetDepth > 0)
      for (final it in main.items)
        if ((it.depth ?? 0) > cabinetDepth) it,
  ];
  int missing(PlateData? p) =>
      p == null ? 0 : p.items.where((e) => (e.depth ?? 0) <= 0).length;
  return ClashReport(clashes, tooDeep, {
    kPlateMain: missing(main),
    if (left != null) kPlateLeft: missing(left),
    if (right != null) kPlateRight: missing(right),
  });
}
