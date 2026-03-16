import 'dart:math' as math;

/// 연산용 입력 데이터 클래스
class BendInstruction {
  final double length;
  final double angle;
  final double rotation;
  final bool isStraight;

  BendInstruction({
    required this.length,
    required this.angle,
    required this.rotation,
  }) : isStraight = angle == 0.0;
}

/// 단일 구간 연산 결과 클래스
class StepResult {
  final double markingPoint; // 누적 마킹 포인트 (시작점 기준)
  final double incrementalMark; // 이전 마킹 포인트와의 차이
  final double sectionGain; // 이 구간에서 발생한 게인(연신율 늘어남)

  StepResult({
    required this.markingPoint,
    required this.incrementalMark,
    required this.sectionGain,
  });
}

/// 🚀 정밀 3D 튜빙 연산 엔진
class TubeBendingEngine {
  final double radius; // 벤더기 곡률 반경 (TakeUp90과 동일한 개념)

  TubeBendingEngine({required this.radius});

  /// 각 노드별 마킹 지점과 총 절단 기장 계산
  Map<String, dynamic> calculate(
    List<BendInstruction> instructions,
    double startFitting,
  ) {
    if (instructions.isEmpty) {
      return {'totalCutLength': 0.0, 'steps': <StepResult>[]};
    }

    double currentRealLength = startFitting; // 시작 부속 삽입 깊이부터 출발
    double totalGain = 0.0;
    double prevMarkPoint = 0.0;

    List<StepResult> steps = [];

    for (int i = 0; i < instructions.length; i++) {
      final inst = instructions[i];
      final double thetaRad = inst.angle * (math.pi / 180.0);

      // 도면상 치수를 실제 길이에 누적
      currentRealLength += inst.length;

      if (inst.isStraight) {
        // 직관(0도)일 경우: 벤딩이 없으므로 누적 게인만 빼서 현재 끝점 위치 계산
        double markPoint = currentRealLength - totalGain;
        double incremental = steps.isEmpty
            ? markPoint
            : (markPoint - prevMarkPoint);

        steps.add(
          StepResult(
            markingPoint: markPoint,
            incrementalMark: incremental,
            sectionGain: 0.0,
          ),
        );
        prevMarkPoint = markPoint;
      } else {
        // 정밀 연신율 보정 공식 적용
        // 1. 셋백(Setback) = R * tan(각도/2)
        double setBack = radius * math.tan(thetaRad / 2.0);
        // 2. 벤드 얼로언스(Bend Allowance) = (pi * R * 각도) / 180
        double bendAllowance = (math.pi * radius * inst.angle) / 180.0;
        // 3. 현재 벤딩의 게인(Gain) = (2 * 셋백) - 벤드 얼로언스
        double currentGain = (2 * setBack) - bendAllowance;

        // 정밀 마킹 포인트: (현재 누적 실제 길이) - (이전까지 누적된 게인) - (현재 벤딩의 셋백)
        double markPoint = currentRealLength - totalGain - setBack;
        double incremental = steps.isEmpty
            ? markPoint
            : (markPoint - prevMarkPoint);

        steps.add(
          StepResult(
            markingPoint: markPoint,
            incrementalMark: incremental,
            sectionGain: currentGain, // 나중에 쓰기 위해 저장
          ),
        );

        // 다음 계산을 위해 총 게인에 누적
        totalGain += currentGain;
        prevMarkPoint = markPoint;
      }
    }

    // 최종 절단 기장: (도면 치수 총합) + (시작 삽입) - (총 발생한 게인)
    // * 종료 삽입(endFitting)과 꼬리(tail)는 밖에서 더해줍니다.
    double totalIsoLength = instructions.fold(
      0.0,
      (sum, item) => sum + item.length,
    );
    double cutLength = totalIsoLength + startFitting - totalGain;

    return {
      'totalCutLength': cutLength,
      'steps': steps,
      'totalGain': totalGain, // 참고용
    };
  }
}
