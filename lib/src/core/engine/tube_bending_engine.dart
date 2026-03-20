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

/// 🚀 정밀 3D 튜빙 연산 엔진 (줄자 누적 추적 방식)
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

    // 🚀 기존의 '가상 길이 누적 방식'을 버리고,
    // 현장 방식인 '실제 파이프 줄자 눈금(Tape Position) 추적 방식'으로 완전히 교체했습니다.
    double currentTapePos = startFitting;
    double prevSetBack = 0.0;
    double prevMarkPoint = 0.0;
    double totalGain = 0.0;

    List<StepResult> steps = [];

    for (int i = 0; i < instructions.length; i++) {
      final inst = instructions[i];

      if (inst.isStraight) {
        // 💡 [핵심 수술 부위] 직관(0도) 모드: 순수 물리적 연장선
        // 현장에서 새들이나 엘보 이후 직관을 추가한다는 것은,
        // 허공의 가상 교차점이 아니라 '앞서 꺾인 곡선의 실물 끝단'부터 길이를 연장한다는 뜻입니다.
        // 따라서 이전 셋백(SetBack)을 차감하지 않고, 입력한 직관 길이를 100% 그대로 더해줍니다.
        double markPoint = currentTapePos + inst.length;
        double incremental = steps.isEmpty
            ? markPoint
            : (markPoint - prevMarkPoint);

        steps.add(
          StepResult(
            markingPoint: markPoint,
            incrementalMark: incremental,
            sectionGain: 0.0, // 직관은 게인이 없습니다.
          ),
        );

        // 직관이므로 곡선이 파이프를 잡아먹지 않습니다. 현재 마킹 지점이 곧 파이프의 끝단입니다.
        currentTapePos = markPoint;

        // ★ 직관 끝에서는 다음 벤딩과 공유하는 가상 교차점이 없으므로 이전 셋백을 0으로 리셋합니다!
        prevSetBack = 0.0;
        prevMarkPoint = markPoint;
      } else {
        // 💡 벤딩 모드: C-to-C (교차점) 기준 계산
        final double thetaRad = inst.angle * (math.pi / 180.0);
        double setBack = radius * math.tan(thetaRad / 2.0);
        double bendAllowance = (math.pi * radius * inst.angle) / 180.0;
        double currentGain = (2 * setBack) - bendAllowance;

        // 순수 직선 파이프 물리량 = (도면 치수) - (앞 벤딩 셋백) - (이번 벤딩 셋백)
        double straightPart = inst.length - prevSetBack - setBack;

        // 마킹 포인트 = 현재까지 파이프가 끝난 지점 + 순수 직선 물리량
        double markPoint = currentTapePos + straightPart;
        double incremental = steps.isEmpty
            ? markPoint
            : (markPoint - prevMarkPoint);

        steps.add(
          StepResult(
            markingPoint: markPoint,
            incrementalMark: incremental,
            sectionGain: currentGain,
          ),
        );

        // 곡선을 접었으므로, 파이프의 끝단(줄자 눈금)은 곡선 길이(BA)만큼 더 전진합니다.
        currentTapePos = markPoint + bendAllowance;

        totalGain += currentGain;
        prevSetBack = setBack;
        prevMarkPoint = markPoint;
      }
    }

    // 🚀 최종 절단 기장의 혁명:
    // 복잡한 연신율 가감 수식을 다 버렸습니다. 마지막 작업이 끝난 줄자의 '최종 눈금(currentTapePos)'이
    // 곧 우리가 잘라야 할 파이프의 진짜 기장입니다. 1mm 오차도 날 수 없습니다.
    return {
      'totalCutLength': currentTapePos,
      'steps': steps,
      'totalGain': totalGain,
    };
  }
}
