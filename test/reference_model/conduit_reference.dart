/// 전선관 수동 벤더 기준 셈. 앱 코드를 보지 않고 공개된 방식대로 다시 쓴 것.
///
/// 출처
/// - Greenlee 「Bending Guide」·Klein 「Conduit Bending Guide」(수동 벤더 벤딩 차트):
///   90° 스텁 = 스텁 높이(바깥면까지) − 테이크업, 화살표에 맞춘다.
///   백투백 = 첫 90° 등(바깥면)에서 잰 길이 자리, 별표(★)에 맞춘다.
///   오프셋 = 높이 × 배수(10° 6.0 · 22.5° 2.6 · 30° 2.0 · 45° 1.414 · 60° 1.2),
///   수축 = 높이 × (10° 1/16 · 22.5° 3/16 · 30° 1/4 · 45° 3/8 · 60° 1/2), 1번
///   마킹 = 장애물까지 거리 + 수축, 2번 마킹 = 1번 + 높이×배수.
///   3벤드 새들 45° 가운데: 가운데 마킹 = 장애물 중심까지 + 높이×3/16,
///   양옆 = 가운데 ± 높이×2.5 (60° 가운데는 1/4 · 2.0).
///   4벤드 새들 = 오프셋 두 개를 마주 놓은 것.
/// - 수동 벤더 테이크업(EMT): 1/2" 5" · 3/4" 6" · 1" 8" · 1-1/4" 11".
///   90° 게인(Klein 차트, EMT): 1/2" 2-5/8" · 3/4" 3-1/4" · 1" 4" · 1-1/4" 5-5/8".
///   후강(Rigid)은 한 치수 큰 EMT 벤더를 쓰므로 그 값을 따른다.
/// - 유압(램) 벤더·시카고(회전) 벤더는 제조사 표(각도별 셋백·램 이동·노치)를
///   그대로 쓰는 방식이라, 여기서는 개념만 둔다.
///
/// 길이는 mm, 각도는 도(°). 인치 값은 25.4를 곱해 두었다.
library;

import 'dart:math' as math;

double _rad(double deg) => deg * math.pi / 180.0;

/// 수동 벤더 테이크업(mm). KS 호칭(16·22·28·36) → 1/2"·3/4"·1"·1-1/4" EMT 벤더.
const Map<int, double> refEmtTakeUpMm = {
  16: 5 * 25.4, // 127.0
  22: 6 * 25.4, // 152.4
  28: 8 * 25.4, // 203.2
  36: 11 * 25.4, // 279.4
};

/// 후강은 한 치수 큰 EMT 벤더(1/2" 후강 = 3/4" EMT 벤더 …).
const Map<int, double> refRigidTakeUpMm = {
  16: 6 * 25.4,
  22: 8 * 25.4,
  28: 11 * 25.4,
};

/// 90° 게인(mm), Klein 차트 EMT.
const Map<int, double> refEmtGain90Mm = {
  16: 2.625 * 25.4, // 66.675
  22: 3.25 * 25.4, // 82.55
  28: 4 * 25.4, // 101.6
  36: 5.625 * 25.4, // 142.875
};

/// 벤더 슈 중심선 반경(CLR, mm). Greenlee 수동 벤더 표기값.
const Map<int, double> refEmtClrMm = {
  16: 4 * 25.4, // 101.6
  22: 4.5 * 25.4, // 114.3
  28: 5.75 * 25.4, // 146.05
  36: 7.25 * 25.4, // 184.15
};

/// 오프셋 배수(관행값). 높이 × 배수 = 두 마킹 사이.
final Map<double, double> refOffsetMultiplier = {
  10: 6.0,
  22.5: 2.6,
  30: 2.0,
  45: 1.414,
  60: 1.2,
};

/// 수축 배수(관행값). 높이 × 배수 = 수축.
final Map<double, double> refOffsetShrinkPerUnit = {
  10: 1 / 16,
  22.5: 3 / 16,
  30: 1 / 4,
  45: 3 / 8,
  60: 1 / 2,
};

/// 정확한 오프셋 배수 = 1 / sin θ.
double refOffsetMultiplierExact(double angleDeg) => 1 / math.sin(_rad(angleDeg));

/// 정확한 수축 배수 = 1/sin θ − 1/tan θ = tan(θ/2).
double refOffsetShrinkExact(double angleDeg) => math.tan(_rad(angleDeg) / 2);

/// 90° 스텁: 마킹 = 스텁 높이(등까지) − 테이크업. 화살표에 맞춘다.
double refStubMark(double stubToBack, double takeUp) => stubToBack - takeUp;

/// 90° 스텁 두 개(백투백). 첫 마킹은 화살표, 둘째 마킹은 별표.
/// - 둘째 마킹(별표) = 첫 스텁 높이 + 등에서 등까지 길이. 별표는 "이 자리가
///   90°의 등이 된다"는 표시라 테이크업을 빼지 않는다.
/// - 화살표로 하려면 여기서 테이크업을 뺀다.
({double first, double secondStar, double secondArrow}) refBackToBackMarks({
  required double stub1ToBack,
  required double backToBack,
  required double takeUp,
}) => (
  first: stub1ToBack - takeUp,
  secondStar: stub1ToBack + backToBack,
  secondArrow: stub1ToBack + backToBack - takeUp,
);

/// 각도별 테이크업. 표에는 90° 값뿐이다. 관행은 "90°가 아닌 벤드는 화살표를
/// 마킹에 그대로 맞춘다"이므로 테이크업을 따로 빼지 않는다(오프셋·새들이 그렇다).
/// 그래서 여기서는 기하로만 잡는다: 90°일 때 테이크업 = 반경 + 고정분으로 보고,
/// 다른 각은 반경 쪽만 tan(θ/2)로 줄인다. 반경을 모르면 전체를 tan 비율로.
double refTakeUpForAngle(double takeUp90, double clr, double angleDeg) {
  if (angleDeg <= 0 || takeUp90 <= 0) return 0;
  final t = math.tan(_rad(angleDeg) / 2);
  if (clr <= 0 || clr >= takeUp90) return takeUp90 * t;
  return clr * t + (takeUp90 - clr);
}

/// 관행 오프셋 마킹. 장애물까지 거리 D, 높이 H, 각 θ(관행 배수가 있는 각만).
/// 1번 = D + H×수축배수, 2번 = 1번 + H×배수. 둘 다 화살표에 맞춘다.
class RefConduitOffset {
  final double shrink;
  final double travel;
  final double mark1;
  final double mark2;
  const RefConduitOffset(this.shrink, this.travel, this.mark1, this.mark2);
}

RefConduitOffset refConduitOffsetTrade(
  double distance,
  double height,
  double angleDeg,
) {
  final mult = refOffsetMultiplier[angleDeg];
  final sh = refOffsetShrinkPerUnit[angleDeg];
  if (mult == null || sh == null || height <= 0) {
    return const RefConduitOffset(0, 0, 0, 0);
  }
  final shrink = height * sh;
  final travel = height * mult;
  return RefConduitOffset(shrink, travel, distance + shrink, distance + shrink + travel);
}

/// 같은 셈을 삼각함수 정확값으로.
RefConduitOffset refConduitOffsetExact(
  double distance,
  double height,
  double angleDeg,
) {
  if (height <= 0 || angleDeg <= 0 || angleDeg >= 90) {
    return const RefConduitOffset(0, 0, 0, 0);
  }
  final shrink = height * refOffsetShrinkExact(angleDeg);
  final travel = height * refOffsetMultiplierExact(angleDeg);
  return RefConduitOffset(shrink, travel, distance + shrink, distance + shrink + travel);
}

/// 관행 3벤드 새들. 가운데 각(45° 또는 60°), 장애물 중심까지 거리 C, 높이 H.
/// 가운데 마킹 = C + H×수축, 양옆 = 가운데 ∓ H×배수.
/// 45° 가운데: 수축 3/16, 배수 2.5 / 60° 가운데: 수축 1/4, 배수 2.0.
class RefConduitSaddle3 {
  final double shrink;
  final double sideDistance;
  final double mark1;
  final double markCenter;
  final double mark3;
  const RefConduitSaddle3(
    this.shrink,
    this.sideDistance,
    this.mark1,
    this.markCenter,
    this.mark3,
  );
}

RefConduitSaddle3? refConduitSaddle3Trade(
  double centerDistance,
  double height,
  double centerAngleDeg,
) {
  final double sh;
  final double mult;
  if (centerAngleDeg == 45) {
    sh = 3 / 16;
    mult = 2.5;
  } else if (centerAngleDeg == 60) {
    sh = 1 / 4;
    mult = 2.0;
  } else {
    return null;
  }
  final shrink = height * sh;
  final side = height * mult;
  final center = centerDistance + shrink;
  return RefConduitSaddle3(shrink, side, center - side, center, center + side);
}

/// 3벤드 새들을 기하로. 옆 각 θ/2: 옆 빗변 = H / sin(θ/2), 총 수축 = 2·H·tan(θ/4).
/// 가운데가 장애물 중심에 오려면 가운데 마킹 = C + 총 수축/2 (앞 옆 벤드에서
/// 줄어든 몫만 앞에 있다).
RefConduitSaddle3 refConduitSaddle3Exact(
  double centerDistance,
  double height,
  double centerAngleDeg,
) {
  final half = centerAngleDeg / 2;
  final side = height / math.sin(_rad(half));
  final run = height / math.tan(_rad(half));
  final shrinkEach = side - run;
  final center = centerDistance + shrinkEach;
  return RefConduitSaddle3(2 * shrinkEach, side, center - side, center, center + side);
}

/// 총 절단 길이(수동 벤더, 90°만): 등 기준 다리 치수 합 − 90° 게인 × 벤드 수.
double refConduitCut90(List<double> legsToBack, double gain90) =>
    legsToBack.fold(0.0, (s, l) => s + l) - gain90 * (legsToBack.length - 1);

/// 유압(램) 벤더 개념: 셋백 = 교차점에서 램(슈 중심)을 놓을 자리까지.
/// 제조사 표(각도별)를 쓰는 값이라 기하로는 R·tan(θ/2)와 같은 모양이다.
double refRamSetbackShape(double setback90, double angleDeg) =>
    setback90 * math.tan(_rad(angleDeg) / 2);

/// 시카고 벤더: 노치 수 = 각 / 노치당 각(반올림). 넘게 꺾는 것보다 모자란 쪽이 낫다.
int refChicagoNotches(double angleDeg, double degPerNotch) =>
    degPerNotch <= 0 ? 0 : (angleDeg / degPerNotch).round();
