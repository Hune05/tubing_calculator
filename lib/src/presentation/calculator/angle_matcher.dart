// 각도 역산(Field Matcher): 이미 꺾어 놓은 관에서 잰 높이(Rise)와 Travel(꺾이는 점 사이를 관 따라 잰 거리)
// 또는 Run(수평 거리)으로 실제 각도를 거꾸로 구하고, 가장 가까운 표준 각도를 찾는다.
//   Travel로 잰 경우  sin(각) = Rise ÷ Travel
//   Run으로 잰 경우   tan(각) = Rise ÷ Run
// 기존 관과 똑같이 꺾어야 할 때(맞춰 잇기, 병렬 배관) 쓴다. 엔진(벤딩 경로)은 건드리지 않는다.
import 'dart:math' as math;

enum MatchBasis { travel, run }

/// 현장 벤더에 흔히 있는 각도(표준 각도).
const List<double> kStandardAngles = [10, 15, 22.5, 30, 45, 60];

class StdAngleRow {
  final double angle;

  /// 실제 각도와의 차이(표준 − 실제, °).
  final double diff;

  /// 같은 높이를 이 표준 각도로 꺾으면 나오는 Travel·Run.
  final double travel;
  final double run;

  /// 잰 값을 그대로 두고 이 표준 각도로 꺾으면 높이가 얼마나 달라지는지(표준으로 얻는 높이 − 잰 높이, mm).
  final double riseError;

  const StdAngleRow({
    required this.angle,
    required this.diff,
    required this.travel,
    required this.run,
    required this.riseError,
  });
}

class AngleMatch {
  /// 실제 각도(°).
  final double angle;
  final double rise;
  final double travel;
  final double run;

  /// 표준 각도 표(작은 각도부터). 가장 가까운 줄은 [nearest].
  final List<StdAngleRow> rows;
  final StdAngleRow nearest;

  const AngleMatch({
    required this.angle,
    required this.rise,
    required this.travel,
    required this.run,
    required this.rows,
    required this.nearest,
  });

  /// 줄어드는 길이(Travel − Run). 이 각도로 꺾으면 직진 거리가 이만큼 줄어든다.
  double get shrink => travel - run;

  /// 배수(Travel ÷ Rise = 1 ÷ sin).
  double get multiplier => travel / rise;

  /// 표준 각도와 사실상 같은지(0.5° 이내).
  bool get isStandard => nearest.diff.abs() <= 0.5;
}

/// 오류 이유. [matchAngle]이 null을 돌려줄 때 화면에 쓸 문장을 고른다.
enum MatchProblem { missing, travelShorter, tooFlat }

MatchProblem? matchProblem({
  required double? rise,
  required double? measure,
  required MatchBasis basis,
}) {
  if (rise == null || measure == null || rise <= 0 || measure <= 0) {
    return MatchProblem.missing;
  }
  if (basis == MatchBasis.travel && measure < rise) {
    return MatchProblem.travelShorter;
  }
  return null;
}

/// 실제 각도와 표준 각도 비교. 값이 모자라거나 Travel이 높이보다 짧으면 null.
AngleMatch? matchAngle({
  required double? rise,
  required double? measure,
  required MatchBasis basis,
}) {
  if (matchProblem(rise: rise, measure: measure, basis: basis) != null) {
    return null;
  }
  final double h = rise!, m = measure!;
  final double rad = basis == MatchBasis.travel
      ? math.asin((h / m).clamp(0.0, 1.0))
      : math.atan2(h, m);
  final double deg = rad * 180 / math.pi;
  final double travel = basis == MatchBasis.travel ? m : h / math.sin(rad);
  final double run = basis == MatchBasis.run
      ? m
      : (deg >= 89.999 ? 0.0 : math.sqrt(math.max(0.0, m * m - h * h)));

  final rows = <StdAngleRow>[];
  for (final a in kStandardAngles) {
    final double r = a * math.pi / 180;
    final double sinA = math.sin(r), tanA = math.tan(r);
    // 잰 값(Travel이면 Travel, Run이면 Run)을 그대로 두고 표준 각도로 꺾었을 때의 높이.
    final double riseWithStd = basis == MatchBasis.travel ? m * sinA : m * tanA;
    rows.add(
      StdAngleRow(
        angle: a,
        diff: a - deg,
        travel: h / sinA,
        run: h / tanA,
        riseError: riseWithStd - h,
      ),
    );
  }
  var best = rows.first;
  for (final r in rows) {
    if (r.diff.abs() < best.diff.abs()) best = r;
  }
  return AngleMatch(
    angle: deg,
    rise: h,
    travel: travel,
    run: run,
    rows: rows,
    nearest: best,
  );
}
