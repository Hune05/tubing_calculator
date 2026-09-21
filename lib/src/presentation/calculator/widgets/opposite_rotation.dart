/// 오프셋·새들·굴림 오프셋 시트가 두 번째 벤드 방향을 정할 때 쓰는 규칙.
///
/// 방향값은 0 위 · 90 우 · 180 아래 · 270 좌 · 360 앞 · 450 뒤다.
/// 앞(360)과 뒤(450)는 +180을 하면 아래·좌가 되어 형상이 틀어지므로
/// 따로 짝을 지어 준다.
library;

/// [rotation]의 반대 방향.
double oppositeRotation(double rotation) {
  if (rotation == 360.0) return 450.0;
  if (rotation == 450.0) return 360.0;
  return (rotation + 180.0) % 360.0;
}

/// 오프셋 두 벤드의 방향(1번, 2번). [inverted]이면 서로 바꾼다.
(double, double) offsetRotations(double selected, {bool inverted = false}) {
  final double opposite = oppositeRotation(selected);
  return inverted ? (opposite, selected) : (selected, opposite);
}
