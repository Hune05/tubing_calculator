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

/// 🚀 정밀 3D 튜빙 연산 엔진 (줄자 누적 추적 방식 + 실측 연신율 반영)
class TubeBendingEngine {
  final double radius; // 벤더기 곡률 반경
  final double userGain90; // 💡 사용자가 입력한 90도 기준 연신율 (추가됨)

  TubeBendingEngine({
    required this.radius,
    this.userGain90 = 0.0, // 기본값 처리
  });

  /// 각 노드별 마킹 지점과 총 절단 기장 계산
  Map<String, dynamic> calculate(
    List<BendInstruction> instructions,
    double startFitting,
  ) {
    if (instructions.isEmpty) {
      return {'totalCutLength': 0.0, 'steps': <StepResult>[]};
    }

    double currentTapePos = startFitting;
    double prevSetBack = 0.0;
    double prevMarkPoint = 0.0;
    double totalGain = 0.0;

    List<StepResult> steps = [];

    for (int i = 0; i < instructions.length; i++) {
      final inst = instructions[i];

      if (inst.isStraight) {
        // 직관(0도) 모드: 순수 물리적 연장선
        double markPoint = currentTapePos + inst.length;
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

        currentTapePos = markPoint;
        prevSetBack = 0.0;
        prevMarkPoint = markPoint;
      } else {
        // 💡 벤딩 모드: C-to-C (교차점) 기준 계산
        final double thetaRad = inst.angle * (math.pi / 180.0);

        // 1. 기하학적 셋백 (SetBack) - 탄젠트 시작점 찾기 (이건 R값 기반이 맞음)
        double setBack = radius * math.tan(thetaRad / 2.0);

        // 2. 직선 파이프 물리량 및 마킹 포인트
        double straightPart = inst.length - prevSetBack - setBack;
        double markPoint = currentTapePos + straightPart;
        double incremental = steps.isEmpty
            ? markPoint
            : (markPoint - prevMarkPoint);

        // 3. 🚀 [핵심 수정] 연신율(Gain) 적용
        double appliedGain;
        if (userGain90 > 0) {
          // 사용자가 입력한 게인이 있으면 각도 비례로 환산 적용 (실무 방식)
          appliedGain = userGain90 * (inst.angle / 90.0);
        } else {
          // 입력된 게인이 없으면 이론상 중심선 게인으로 대체 (Fallback)
          double theoreticalBA = (math.pi * radius * inst.angle) / 180.0;
          appliedGain = (2 * setBack) - theoreticalBA;
        }

        // 4. 🚀 파이프가 굽혀지며 실제로 소모하는 길이 (Real Bend Allowance)
        // 공식: Gain = 2*SetBack - Real_BA  =>  Real_BA = 2*SetBack - Gain
        double realBendAllowance = (2 * setBack) - appliedGain;

        steps.add(
          StepResult(
            markingPoint: markPoint,
            incrementalMark: incremental,
            sectionGain: appliedGain,
          ),
        );

        // 곡선을 접었으므로, 파이프의 끝단(줄자 눈금)은 '실제 곡선 소모량'만큼 전진
        currentTapePos = markPoint + realBendAllowance;

        totalGain += appliedGain;
        prevSetBack = setBack;
        prevMarkPoint = markPoint;
      }
    }

    return {
      'totalCutLength': currentTapePos,
      'steps': steps,
      'totalGain': totalGain,
    };
  }
}
