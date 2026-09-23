/// 튜브 수동 벤더 기준 셈. 앱 코드를 보지 않고 공개된 방식대로 다시 쓴 것.
///
/// 출처
/// - Swagelok MS-13-43 「Hand Tube Bender」 사용 설명서: 90° 벤드는 "다리 치수 −
///   벤더 반경(테이크업)" 자리에 금을 긋고 0 기준선에 맞춘다. 90°가 아닌 각은
///   접점 위치(R·tan(θ/2))로 잡는다.
/// - Swagelok 「Tube Fitter's Manual」 벤드 허용량·게인 표: 호 길이 = R·θ(rad),
///   게인 = 2·R·tan(θ/2) − R·θ. 총 절단 길이 = 교차점 치수 합 − 게인 합.
/// - 오프셋 삼각형(배관 공통): 빗변 = H / sin θ, 전진 = H / tan θ,
///   수축 = 빗변 − 전진 = H·tan(θ/2).
///
/// 여기 길이는 모두 mm, 각도는 도(°)다. 앱 코드는 참고하지 않았다.
library;

import 'dart:math' as math;

double _rad(double deg) => deg * math.pi / 180.0;

/// 셋백 = R·tan(θ/2). 교차점에서 관이 휘기 시작하는 접점까지.
double refSetback(double radius, double angleDeg) {
  if (radius <= 0 || angleDeg <= 0 || angleDeg >= 180) return 0.0;
  return radius * math.tan(_rad(angleDeg) / 2);
}

/// 벤드 허용량(bend allowance) = R·θ(rad). 휘는 구간에서 관 중심선이 지나는 길이.
double refBendAllowance(double radius, double angleDeg) {
  if (radius <= 0 || angleDeg <= 0) return 0.0;
  return radius * _rad(angleDeg);
}

/// 게인 = 2·R·tan(θ/2) − R·θ. 교차점 치수 합에서 실제 관 길이를 뺀 값.
double refGain(double radius, double angleDeg) =>
    2 * refSetback(radius, angleDeg) - refBendAllowance(radius, angleDeg);

/// 90°에서 잰 게인을 낸 "실효 반경". 게인90 = R·(2 − π/2)이므로 거꾸로 푼다.
double refRadiusFromGain90(double gain90) => gain90 / (2 - math.pi / 2);

/// 실측 게인(90°)이 있으면 그 실효 반경으로 각도별 게인을 낸다. 없으면 반경으로.
/// (원호의 게인 모양은 반경에 관계없이 같으므로, 90° 값에 비율을 곱한 것과 같다.)
double refGainMeasured(double radius, double angleDeg, double gain90) =>
    gain90 > 0
    ? refGain(refRadiusFromGain90(gain90), angleDeg)
    : refGain(radius, angleDeg);

/// 한 구간: 앞 교차점(또는 관 시작)에서 이 교차점까지의 치수와, 이 교차점에서 꺾을 각.
/// 각이 0이면 꺾지 않는 직관이다.
class RefBend {
  final double length;
  final double angle;
  const RefBend(this.length, this.angle);
}

class RefTubeResult {
  /// 벤드마다(각 > 0인 구간만) 줄자 0점에서 금 그을 자리.
  final List<double> marks;

  /// 벤드마다 앞뒤 접점 사이에 실제로 남는 곧은 길이.
  final List<double> straights;

  /// 총 절단 길이.
  final double cutLength;

  /// 이상한 점.
  final List<String> notes;

  const RefTubeResult({
    required this.marks,
    required this.straights,
    required this.cutLength,
    required this.notes,
  });
}

/// 마킹 자리와 총 절단 길이.
///
/// - [bends] 교차점 치수 목록. 직관(각 0)은 다음 벤드 치수에 합친다.
/// - [tail] 마지막 교차점에서 관 끝까지의 치수(교차점 기준). 0이면 관이
///   마지막 벤드의 호가 끝나는 자리에서 끝나는 것으로 본다(호를 다 만들 수
///   있는 가장 짧은 관).
/// - [takeUp90] 90°에서 쓸 테이크업. 0이면 반경(설명서: 테이크업 = 반경).
/// - [gain90] 90°로 한 번 꺾어 잰 게인. 0이면 반경으로 셈한다.
/// - [zero] 줄자 0점을 관 끝에서 얼마나 옮겨 놓았는지(벤더 원점 보정).
/// - [startInsert]·[endInsert] 양 끝 피팅 삽입 깊이. 첫 치수와 끝 치수에 더한다.
RefTubeResult refTubeMarks(
  List<RefBend> bends, {
  required double radius,
  double takeUp90 = 0.0,
  double gain90 = 0.0,
  double zero = 0.0,
  double tail = 0.0,
  double startInsert = 0.0,
  double endInsert = 0.0,
}) {
  final notes = <String>[];
  // 직관을 다음 벤드에 합친다. 끝에 남은 직관은 꼬리에 더한다.
  final merged = <RefBend>[];
  double carry = startInsert;
  for (final b in bends) {
    if (b.angle <= 0) {
      carry += b.length;
      continue;
    }
    merged.add(RefBend(b.length + carry, b.angle));
    carry = 0.0;
  }
  double tailLen = tail + carry + endInsert;
  if (merged.isEmpty) {
    return RefTubeResult(
      marks: const [],
      straights: const [],
      cutLength: zero + tailLen,
      notes: notes,
    );
  }

  final marks = <double>[];
  final straights = <double>[];
  double tangentIn = zero; // 이번 벤드 접점의 줄자 눈금
  double prevSb = 0.0;
  double totalGain = 0.0;

  for (var i = 0; i < merged.length; i++) {
    final b = merged[i];
    if (b.angle >= 180) {
      notes.add('${i + 1}번: 180° 이상은 교차점이 없어 셈할 수 없다(U벤드 셈으로).');
    }
    final sb = refSetback(radius, b.angle);
    final straight = b.length - prevSb - sb;
    if (straight < 0) {
      notes.add(
        '${i + 1}번: 곧은 부분 ${straight.toStringAsFixed(1)}mm — 앞뒤 벤드가 겹친다.',
      );
    }
    tangentIn += straight;
    final takeUp = ((b.angle - 90).abs() < 1e-9 && takeUp90 > 0)
        ? takeUp90
        : sb;
    // 마킹 = 교차점 눈금 − 테이크업. 테이크업이 셋백이면 곧 접점 자리다.
    marks.add(tangentIn + sb - takeUp);
    straights.add(straight);

    final gain = refGainMeasured(radius, b.angle, gain90);
    final allowance = 2 * sb - gain; // 실측 게인이 있으면 호 대신 이 값을 먹는다
    totalGain += gain;
    tangentIn += allowance;
    prevSb = sb;
  }

  double cut;
  if (tailLen > 0) {
    if (tailLen < prevSb) {
      notes.add(
        '꼬리 ${tailLen.toStringAsFixed(1)}mm가 마지막 셋백 ${prevSb.toStringAsFixed(1)}mm보다 짧다.',
      );
    }
    // 총 절단 = 교차점 치수 합 + 꼬리 − 게인 합
    cut = zero +
        merged.fold(0.0, (s, b) => s + b.length) +
        tailLen -
        totalGain;
  } else {
    // 꼬리가 없으면 마지막 호가 끝나는 자리까지.
    cut = tangentIn;
    notes.add('꼬리 0: 관이 마지막 벤드의 호 끝에서 끝난다고 봤다.');
  }
  return RefTubeResult(
    marks: marks,
    straights: straights,
    cutLength: cut,
    notes: notes,
  );
}

/// 오프셋(같은 각 두 번). 높이 H, 각 θ.
class RefOffset {
  final double travel; // 빗변(교차점 사이)
  final double run; // 전진(바닥을 따라)
  final double shrink; // 수축 = 빗변 − 전진 = H·tan(θ/2)
  const RefOffset(this.travel, this.run, this.shrink);
}

RefOffset refOffset(double height, double angleDeg) {
  if (height <= 0 || angleDeg <= 0 || angleDeg >= 90) {
    return const RefOffset(0, 0, 0);
  }
  final travel = height / math.sin(_rad(angleDeg));
  final run = height / math.tan(_rad(angleDeg));
  return RefOffset(travel, run, height * math.tan(_rad(angleDeg) / 2));
}

/// 오프셋 높이와 빗변으로 각을 되짚는다. 빗변이 높이보다 짧으면 null.
double? refOffsetAngleFromTravel(double height, double travel) {
  if (height <= 0 || travel <= 0 || height > travel) return null;
  return math.asin(height / travel) * 180 / math.pi;
}

/// 3벤드 새들(옆 θ/2 · 가운데 θ · 옆 θ/2). 높이 H.
/// 옆 빗변 = H / sin(θ/2), 옆 전진 = H / tan(θ/2). 총 수축 = 2·(빗변 − 전진).
class RefSaddle3 {
  final double sideAngle;
  final double travel;
  final double run;
  final double totalShrink;
  const RefSaddle3(this.sideAngle, this.travel, this.run, this.totalShrink);
}

RefSaddle3 refSaddle3(double height, double centerAngleDeg) {
  final side = centerAngleDeg / 2;
  final o = refOffset(height, side);
  return RefSaddle3(side, o.travel, o.run, 2 * o.shrink);
}

/// 4벤드 새들(θ 네 번, 가운데 폭 W). 옆 빗변 = H / sin θ.
class RefSaddle4 {
  final double travel;
  final double run;
  final double totalShrink;
  const RefSaddle4(this.travel, this.run, this.totalShrink);
}

RefSaddle4 refSaddle4(double height, double width, double angleDeg) {
  final o = refOffset(height, angleDeg);
  return RefSaddle4(o.travel, o.run, 2 * o.shrink);
}

/// 킥(한 번 꺾어 H만큼 올리기). 빗변 = H / sin θ, 전진 = H / tan θ.
/// 빗변 끝(교차점)까지 치수를 잡았을 때 금 그을 자리 = 빗변 − R·tan(θ/2).
class RefKick {
  final double travel;
  final double run;
  final double mark;
  const RefKick(this.travel, this.run, this.mark);
}

RefKick refKick(double height, double angleDeg, double radius) {
  final o = refOffset(height, angleDeg);
  return RefKick(o.travel, o.run, o.travel - refSetback(radius, angleDeg));
}

/// 롤링 오프셋. 참 오프셋 = √(수직² + 수평²), 굴릴 각 = atan2(수평, 수직).
class RefRolling {
  final double trueOffset;
  final double rollDeg;
  final double travel;
  final double advance;
  const RefRolling(this.trueOffset, this.rollDeg, this.travel, this.advance);
}

RefRolling refRolling(double rise, double roll, double angleDeg) {
  final t = math.sqrt(rise * rise + roll * roll);
  double rollDeg = 0;
  if (rise > 0 || roll > 0) {
    rollDeg = math.atan2(roll, rise) * 180 / math.pi;
  }
  if (t <= 0 || angleDeg <= 0 || angleDeg >= 180) {
    return RefRolling(t, rollDeg, 0, 0);
  }
  final travel = t / math.sin(_rad(angleDeg));
  final advance = angleDeg == 90 ? 0.0 : t / math.tan(_rad(angleDeg));
  return RefRolling(t, rollDeg, travel, advance);
}

/// U벤드(180°). 중심 간 폭 = 2R, 호 길이 = πR.
/// 절단 = 앞 직관 + πR + 뒤 직관 (+ 피팅 삽입 깊이).
/// 실측 게인이 있으면 실효 반경의 호(π·R실효)를 쓴다.
class RefUBend {
  final double centerWidth;
  final double arc;
  final double cutLength;
  const RefUBend(this.centerWidth, this.arc, this.cutLength);
}

RefUBend refUBend({
  required double radius,
  required double startStraight,
  required double returnStraight,
  double gain90 = 0.0,
  double startInsert = 0.0,
  double endInsert = 0.0,
}) {
  final rEff = gain90 > 0 ? refRadiusFromGain90(gain90) : radius;
  final arc = math.pi * rEff;
  return RefUBend(
    2 * radius,
    arc,
    startStraight + returnStraight + arc + startInsert + endInsert,
  );
}

/// 평행 배관(같은 벤더로 나란히 꺾을 때) 옆 가닥의 마킹 보정 = 간격 × n × tan(θ/2).
/// 90°면 tan 45° = 1이라 간격 그대로다.
double refParallelStagger(double spacing, int index, double angleDeg) {
  if (spacing <= 0 || index <= 0 || angleDeg <= 0 || angleDeg > 90) return 0;
  return spacing * index * math.tan(_rad(angleDeg) / 2);
}
