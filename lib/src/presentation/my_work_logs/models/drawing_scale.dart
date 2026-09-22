import 'dart:ui';

// 배경 사진(카톡으로 받은 도면 등)을 실제 mm에 맞춰 까는 셈.
// 도면 사진에서 판(캐비닛·스키드) 왼쪽 위·오른쪽 아래 모서리를 찍고 실제 가로·세로(mm)를
// 넣으면, 사진 전체를 배치도(mm) 어디에 얼마 크기로 깔지 정한다. 가로·세로 배율을 따로 잡아
// 비스듬히 찍은 사진의 가로·세로 늘어남도 맞춘다.

/// [topLeft]·[bottomRight]는 사진 픽셀 자리, [image]는 사진 픽셀 크기.
/// 돌려주는 값은 배치도 mm 좌표에서 사진이 차지할 네모(판 왼쪽 위가 0,0).
/// 두 점이 거꾸로(오른쪽 아래가 왼쪽 위보다 위·왼쪽)이거나 크기가 0이면 null.
Rect? drawingRectFromCorners({
  required Offset topLeft,
  required Offset bottomRight,
  required Size image,
  required double widthMm,
  required double heightMm,
}) {
  final double dx = bottomRight.dx - topLeft.dx;
  final double dy = bottomRight.dy - topLeft.dy;
  if (dx <= 0 || dy <= 0 || widthMm <= 0 || heightMm <= 0) return null;
  final double sx = widthMm / dx, sy = heightMm / dy;
  return Rect.fromLTWH(
    -topLeft.dx * sx,
    -topLeft.dy * sy,
    image.width * sx,
    image.height * sy,
  );
}

/// 저장용: [l, t, w, h].
List<double> drawingRectToJson(Rect r) => [r.left, r.top, r.width, r.height];

/// 저장된 칸을 읽는다. 없거나 모양이 틀리면 null(예전처럼 판에 맞춰 깐다).
Rect? drawingRectFromJson(Object? v) {
  if (v is! List || v.length != 4) return null;
  final n = [for (final e in v) (e is num) ? e.toDouble() : null];
  if (n.contains(null)) return null;
  if (n[2]! <= 0 || n[3]! <= 0) return null;
  return Rect.fromLTWH(n[0]!, n[1]!, n[2]!, n[3]!);
}
