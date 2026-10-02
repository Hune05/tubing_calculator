// 접지바 구멍 계산기(10-03): 구리 평강에 볼트 구멍을 한 줄로 뚫어 접지바를 만들 때
// 자르는 길이와 구멍 위치. 화면 없이 계산만 한다.
//  · 구멍은 폭 가운데 한 줄, 피치 p로 늘어선다. 위치는 한쪽 끝에서 구멍 중심까지.
//  · 구멍 수로 정하면 길이 = 2e + (n−1)p. 길이로 정하면 n = ⌊(L − 2e) ÷ p⌋ + 1이고,
//    남는 길이는 양 끝 여유에 똑같이 나눈다.
//  · 무게는 구리 밀도 8.9 g/cm³로 구멍 뺀 부피를 곱한 근사값이다.
library;

import 'dart:math' as math;

/// 구리 밀도(kg/mm³): 8.9 g/cm³.
const double kCopperKgPerMm3 = 8.9e-6;

/// 구멍 지름 칩(mm). NEMA 접지바 7/16"(3/8" 볼트용), 통신 접지바 5/16"(1/4" 볼트용).
const List<double> kGroundHoleDias = [7.9, 11.1];

/// 구멍 피치 칩(mm). 5/8"(통신 5/16" 구멍 줄), 3/4"·1"(NEMA 2구멍 러그), 1-3/4"(NEMA 러그 패드).
const List<double> kGroundPitches = [15.875, 19.05, 25.4, 44.45];

/// 가장 많이 뚫는 구멍 수(화면·그림이 감당하는 한도).
const int kGroundMaxHoles = 60;

class GroundBarPlan {
  /// 자르는 길이(mm).
  final double length;

  /// 구멍 수.
  final int holes;

  /// 한쪽 끝에서 구멍 중심까지 거리(mm).
  final List<double> positions;

  /// 양 끝에서 첫·마지막 구멍 중심까지(mm).
  final double endLeft, endRight;

  /// 구멍 중심선: 폭 가운데(mm).
  final double centerLine;

  /// 대략 무게(kg, 구멍 뺌).
  final double weightKg;

  /// 만들 수 없는 이유들(비어 있으면 가능).
  final List<String> problems;

  bool get ok => problems.isEmpty;

  const GroundBarPlan({
    required this.length,
    required this.holes,
    required this.positions,
    required this.endLeft,
    required this.endRight,
    required this.centerLine,
    required this.weightKg,
    required this.problems,
  });
}

/// [t]·[w] 두께·폭, [holeDia] 구멍 지름, [pitch] 구멍 피치, [endDist] 끝 여유(끝 면에서 구멍 중심까지).
/// [count]를 주면 구멍 수로, [length]를 주면 막대 길이로 정한다(둘 다 있으면 [count]).
GroundBarPlan groundBar({
  required double t,
  required double w,
  required double holeDia,
  required double pitch,
  required double endDist,
  int? count,
  double? length,
}) {
  final problems = <String>[];
  var n = 0;
  var len = 0.0;
  if (count != null) {
    n = count;
    len = n < 1 ? 0 : 2 * endDist + (n - 1) * pitch;
  } else if (length != null) {
    len = length;
    n = len < 2 * endDist || pitch <= 0
        ? 0
        : ((len - 2 * endDist) / pitch + 1e-9).floor() + 1;
  }
  if (n > kGroundMaxHoles) {
    problems.add('구멍이 $kGroundMaxHoles개를 넘어 계산하지 않습니다.');
    n = 0;
  }
  if (n < 1) problems.add('구멍이 들어갈 자리가 없습니다. 길이나 구멍 수를 늘리십시오.');
  if (holeDia >= w) {
    problems.add('구멍 지름이 부스바 폭보다 크거나 같습니다.');
  }
  if (n > 1 && pitch <= holeDia) {
    problems.add('구멍 피치가 구멍 지름 이하라 구멍이 서로 겹칩니다.');
  }
  if (endDist < holeDia / 2) {
    problems.add('끝 여유가 구멍 반지름보다 작아 구멍이 끝 면을 뚫습니다.');
  }
  final rest = n < 1 ? 0.0 : len - (2 * endDist + (n - 1) * pitch);
  final first = endDist + rest / 2;
  final pos = [for (var i = 0; i < n; i++) first + i * pitch];
  final hole = n * math.pi / 4 * holeDia * holeDia * t;
  final kg = math.max(0.0, t * w * len - hole) * kCopperKgPerMm3;
  return GroundBarPlan(
    length: len,
    holes: n,
    positions: pos,
    endLeft: n < 1 ? 0 : first,
    endRight: n < 1 ? 0 : len - pos.last,
    centerLine: w / 2,
    weightKg: kg,
    problems: problems,
  );
}
