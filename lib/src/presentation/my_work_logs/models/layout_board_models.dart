import 'package:flutter/material.dart';

// 🚀 배치도(모바일·태블릿 두 화면)가 함께 쓰는 데이터 모양과 치수 계산.
// 예전에는 두 화면 파일에 똑같은 코드가 각각 들어 있었다. 저장 형식이나 치수 계산 규칙을
// 바꿀 때는 이 파일 하나만 고치면 되고, test/layout_board_models_test.dart가 규칙을 지킨다.

// ---------------------------------------------------------
// 1. 데이터 모델
// ---------------------------------------------------------
enum DimensionType { center, edge }

// 🚀 [정리] 정밀 튜빙 라인 모드는 폰 화면에서 점을 하나하나 정밀하게
// 찍어야 해서 부담이 크다는 판단으로 제거. 모듈 배치/이동, 고정 치수
// 측정 두 가지만 남긴다.
enum BoardMode { placeModule, measureDimension }

// 🚀 [추가] 드래그로 도면에 놓을 모듈의 기본값(이름+가로/세로)을 함께
// 실어 나르기 위한 드래그 페이로드. 예전엔 이름(String)만 옮기고 크기는
// 무조건 80×80으로 고정되어 있어서, ABS 덕트처럼 폭이 정해진 자재를
// 매번 배치 후 수동으로 크기를 고쳐야 했다.
class ModulePreset {
  final String name;
  final double width;
  final double height;
  const ModulePreset(this.name, this.width, this.height);
}

// 🚀 [수정] 실제 현장에서 쓰는 폭(40/60/80/100mm)만 남김.
// 세로(길이)는 배선 경로에 따라 달라지므로 기본값만 두고, 배치 후
// "모듈 속성 편집"에서 실제 길이에 맞게 조정하면 된다.
const List<ModulePreset> kDuctPresets = [
  ModulePreset("ABS덕트 40mm", 40, 200),
  ModulePreset("ABS덕트 60mm", 60, 200),
  ModulePreset("ABS덕트 80mm", 80, 200),
  ModulePreset("ABS덕트 100mm", 100, 200),
];

abstract class MeasurePoint {
  Offset get center;
  Rect get boundingBox;
  String get id;
  Map<String, dynamic> toJson();
}

class PlacedItem implements MeasurePoint {
  @override
  final String id;
  String name;
  Offset position;
  double width;
  double height;
  bool isSelected;
  // 🚀 [신규] 위치가 확정된 모듈을 잠가서 드래그해도 실수로 옮겨지지
  // 않게 하는 기능.
  bool isLocked;

  PlacedItem({
    required this.id,
    required this.name,
    required this.position,
    this.width = 80.0,
    this.height = 80.0,
    this.isSelected = false,
    this.isLocked = false,
  });

  @override
  Offset get center =>
      Offset(position.dx + width / 2, position.dy + height / 2);

  @override
  Rect get boundingBox =>
      Rect.fromLTWH(position.dx, position.dy, width, height);

  @override
  Map<String, dynamic> toJson() => {
    'type': 'item',
    'id': id,
    'name': name,
    'x': position.dx,
    'y': position.dy,
    'w': width,
    'h': height,
    'locked': isLocked,
  };

  factory PlacedItem.fromJson(Map<String, dynamic> j) => PlacedItem(
    id: j['id'] as String,
    name: j['name'] as String? ?? "이름 없음",
    position: Offset((j['x'] as num).toDouble(), (j['y'] as num).toDouble()),
    width: (j['w'] as num?)?.toDouble() ?? 80.0,
    height: (j['h'] as num?)?.toDouble() ?? 80.0,
    isLocked: j['locked'] as bool? ?? false,
  );
}

class WallPoint implements MeasurePoint {
  @override
  final String id;
  final Offset position;

  WallPoint({required this.position})
    : id = "wall_${position.dx}_${position.dy}";

  @override
  Offset get center => position;

  @override
  Rect get boundingBox => Rect.fromLTWH(position.dx, position.dy, 0, 0);

  @override
  Map<String, dynamic> toJson() => {
    'type': 'wall',
    'id': id,
    'x': position.dx,
    'y': position.dy,
  };

  factory WallPoint.fromJson(Map<String, dynamic> j) => WallPoint(
    position: Offset((j['x'] as num).toDouble(), (j['y'] as num).toDouble()),
  );
}

// 🚀 [추가] 저장된 p1/p2는 "item"/"wall" 중 하나라 type 필드로 구분해서
// 복원한다. item 쪽은 저장 당시 좌표를 담은 별개의 PlacedItem이라, 불러온
// 뒤 실제 모듈을 옮겨도 이미 찍힌 치수선은 저장 시점 위치에 고정된다.
MeasurePoint _measurePointFromJson(Map<String, dynamic> j) {
  return j['type'] == 'wall' ? WallPoint.fromJson(j) : PlacedItem.fromJson(j);
}

class PlacedDimension {
  final String id;
  final MeasurePoint p1;
  final MeasurePoint p2;
  // 🚀 [수정] 기존 치수의 기준(센터/측면)을 그 자리에서 바꿀 수 있도록
  // final을 뗐다.
  DimensionType type;
  // 🚀 [신규] 이 치수선에 대한 짧은 메모(예: "케이블 트레이 통과 구간").
  String? note;
  // 🚀 [신규] 최소 유지 간격(mm). 설정해두면 실제 거리가 이 값보다
  // 좁아지는 순간 치수선이 경고색으로 바뀐다(전기 패널 이격거리 확인용).
  double? minGapMm;
  // 🚀 [신규] 대각선 모드 - 켜면 축(가로/세로)에 맞춰 정렬하지 않고
  // 두 중심점을 직선으로 그대로 잇는 실제 직선거리+각도를 측정한다.
  bool isDiagonal;
  // 🚀 [신규] 안전 이격거리처럼 규정과 관련된 중요한 치수선을 표시해
  // 두께/아이콘으로 다른 치수와 구분되게 한다.
  bool isSafetyCritical;

  PlacedDimension({
    required this.id,
    required this.p1,
    required this.p2,
    required this.type,
    this.note,
    this.minGapMm,
    this.isDiagonal = false,
    this.isSafetyCritical = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'p1': p1.toJson(),
    'p2': p2.toJson(),
    'type': type.name,
    'note': note,
    'minGapMm': minGapMm,
    'isDiagonal': isDiagonal,
    'isSafetyCritical': isSafetyCritical,
  };

  factory PlacedDimension.fromJson(Map<String, dynamic> j) => PlacedDimension(
    id: j['id'] as String,
    p1: _measurePointFromJson(Map<String, dynamic>.from(j['p1'] as Map)),
    p2: _measurePointFromJson(Map<String, dynamic>.from(j['p2'] as Map)),
    type: DimensionType.values.byName(j['type'] as String),
    note: j['note'] as String?,
    minGapMm: (j['minGapMm'] as num?)?.toDouble(),
    isDiagonal: j['isDiagonal'] as bool? ?? false,
    isSafetyCritical: j['isSafetyCritical'] as bool? ?? false,
  );
}

// 🚀 [정리] 손으로 앵커를 옮기는 기능은 폰에서 쓰기 부담스럽다는 판단으로
// 제거하고, 센터/측면 자동 계산만 남겼다.
({Offset p1, Offset p2, double distance}) computeDimensionEndpoints(
  PlacedDimension dim,
) {
  final Rect r1 = dim.p1.boundingBox;
  final Rect r2 = dim.p2.boundingBox;

  // 🚀 [신규] 대각선 모드면 축 정렬 없이 두 중심점을 직선 그대로 잇는다.
  if (dim.isDiagonal) {
    final Offset p1 = r1.center;
    final Offset p2 = r2.center;
    return (p1: p1, p2: p2, distance: (p1 - p2).distance);
  }

  final double dxCenter = (r1.center.dx - r2.center.dx).abs();
  final double dyCenter = (r1.center.dy - r2.center.dy).abs();

  if (dim.type == DimensionType.center) {
    Offset p1 = r1.center;
    Offset p2 = r2.center;
    p2 = dxCenter > dyCenter ? Offset(p2.dx, p1.dy) : Offset(p1.dx, p2.dy);
    return (p1: p1, p2: p2, distance: (p1 - p2).distance);
  }

  if (dxCenter > dyCenter) {
    final bool isR1Left = r1.center.dx < r2.center.dx;
    final double x1 = isR1Left ? r1.right : r1.left;
    final double x2 = isR1Left ? r2.left : r2.right;
    final double y = (r1.center.dy + r2.center.dy) / 2;
    return (p1: Offset(x1, y), p2: Offset(x2, y), distance: (x1 - x2).abs());
  } else {
    final bool isR1Top = r1.center.dy < r2.center.dy;
    final double y1 = isR1Top ? r1.bottom : r1.top;
    final double y2 = isR1Top ? r2.top : r2.bottom;
    final double x = (r1.center.dx + r2.center.dx) / 2;
    return (p1: Offset(x, y1), p2: Offset(x, y2), distance: (y1 - y2).abs());
  }
}
