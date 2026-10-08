// 튜브 게인 AUTO 값이 반경을 따라가게 하는 셈.
//
// 제원표의 AUTO 게인은 재 본 값이 아니라 표 반경으로 셈한 값이다(90° 게인 = 2·R − π·R/2
// ≈ 0.4292·R: 38.1 → 16.3, 57.2 → 24.5, 76.2 → 32.6). 10-09 점검: 반경만 MAN으로 바꾸면
// 게인은 옛 반경 값으로 남아, 1/2"에 R50을 넣으면 90° 벤드마다 약 5 mm 길게 마킹했다
// (엔진은 게인이 0보다 크면 그 값을 그대로 쓴다). 사용자 결정 10-09: "맞으면 따라가게".
// 표 반경 그대로면 표 게인 그대로라(1/2" 16.3) 지금 쓰는 값은 바뀌지 않는다.
library;

/// 게인이 AUTO일 때 쓸 값. 표 게인을 표 반경 대비 지금 반경 비율로 맞춘다.
/// 반경을 모르거나 0이면 표 게인 그대로.
double autoGainForRadius({
  required double tableGain,
  required double tableRadius,
  required double radius,
}) {
  if (tableRadius <= 0 || radius <= 0) return tableGain;
  if ((radius - tableRadius).abs() < 1e-9) return tableGain;
  return tableGain * radius / tableRadius;
}

/// 칸에 넣을 글(소수 한 자리, 표 값과 같은 모양).
String autoGainText({
  required double tableGain,
  required double tableRadius,
  required double radius,
}) {
  final g = autoGainForRadius(
    tableGain: tableGain,
    tableRadius: tableRadius,
    radius: radius,
  );
  if ((radius - tableRadius).abs() < 1e-9 || radius <= 0) return tableGain.toString();
  return g.toStringAsFixed(1);
}
