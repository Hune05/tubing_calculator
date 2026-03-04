import 'dart:math';

class BendingCalculator {
  // 1. 90도 계산 (Stub-up)
  static Map<String, double> calculate90Degree({
    required double r,
    required double l1,
    required double l2,
  }) {
    double gain = (2 * r) - (pi * r / 2);
    double totalLength = l1 + l2 - gain;
    double markingPoint = l1 - r;

    return {
      'totalLength': totalLength,
      'gain': gain,
      'markingPoint': markingPoint,
    };
  }

  // 2. 일반 오프셋 계산 (Offset - 정산)
  static Map<String, double> calculateOffset(double height, double angle) {
    if (height <= 0 || angle <= 0) return {'height': 0, 'travel': 0};
    double radians = angle * (pi / 180);
    double travel = height / sin(radians);
    return {'height': height, 'travel': travel};
  }

  // 💡 [새로 추가] 일반 오프셋 계산 (Offset - 역산: 트래블 알고 높이 구하기)
  static Map<String, double> calculateReverseOffset(
    double travel,
    double angle,
  ) {
    if (travel <= 0 || angle <= 0) return {'height': 0, 'travel': 0};
    double radians = angle * (pi / 180);
    // 높이(Height) = 트래블(Travel) * sin(각도)
    double height = travel * sin(radians);
    return {'height': height, 'travel': travel};
  }

  // 3. 3포인트 새들 계산 (3-Point Saddle)
  static Map<String, double> calculate3Point(
    double height,
    double distance,
    double centerAngle,
  ) {
    // 45도일 때 2.6배, 60도일 때 2.0배 (현장 표준)
    double multiplier = (centerAngle == 60) ? 2.0 : 2.6;
    double offsetDistance = height * multiplier;
    return {
      'height': height,
      'mark1': distance - offsetDistance,
      'mark2': distance,
      'mark3': distance + offsetDistance,
    };
  }

  // 4. 4포인트 새들 계산 (4-Point Saddle) - 💡 이번에 추가된 공식!
  static Map<String, double> calculate4Point(
    double height,
    double width,
    double angle,
  ) {
    if (height <= 0 || angle <= 0)
      return {'height': 0, 'width': 0, 'travel': 0};

    // 각도를 라디안으로 변환
    double radians = angle * (pi / 180);

    // 트래블(Travel) 계산 공식: 높이 / sin(각도)
    // 장애물을 넘어가기 위해 꺾여서 올라가는 대각선 길이를 구합니다.
    double travel = height / sin(radians);

    return {'height': height, 'width': width, 'travel': travel};
  }

  // 5. 롤링 오프셋 계산 (Rolling Offset) - 미리 넣어둠!
  static Map<String, double> calculateRolling(
    double vertical,
    double horizontal,
    double angle,
  ) {
    if (angle <= 0) return {'travel': 0, 'trueOffset': 0};

    // 피타고라스 정리로 실제 오프셋(True Offset) 대각선 계산
    double trueOffset = sqrt(pow(vertical, 2) + pow(horizontal, 2));
    double radians = angle * (pi / 180);

    // 실제 트래블 계산
    double travel = trueOffset / sin(radians);

    return {'trueOffset': trueOffset, 'travel': travel};
  }
}
