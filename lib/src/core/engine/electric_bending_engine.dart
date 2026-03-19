import 'dart:math' as math;

class ElectricBendInstruction {
  final double length; // 도면상 C-to-C 직선 거리
  final double angle; // 벤딩 각도 (C)
  final double rotation; // 회전 각도 (B)

  ElectricBendInstruction({
    required this.length,
    required this.angle,
    required this.rotation,
  });
}

class ElectricBendingEngine {
  final double clr; // 금형 센터라인 반경 (Centerline Radius)

  ElectricBendingEngine({required this.clr});

  Map<String, dynamic> calculateYBC(
    List<ElectricBendInstruction> instructions,
    double minClampLength,
  ) {
    List<Map<String, dynamic>> ybcTable = [];
    double totalCutLength = 0.0;

    // 첫 번째 클램프 물림을 위한 여유 마진 (필요 시)
    // 현장 상황에 따라 시작점에만 클램프 여유를 주거나 아예 0으로 세팅합니다.
    totalCutLength += minClampLength;

    double previousSetback = 0.0;

    for (int i = 0; i < instructions.length; i++) {
      double rawLength = instructions[i].length;
      double bendAngle = instructions[i].angle;
      double rotation = instructions[i].rotation;

      // 마지막 직관 구간 등 각도가 없는 경우
      if (bendAngle == 0.0) {
        double straightFeed = rawLength - previousSetback;
        totalCutLength += straightFeed;
        // YBC 테이블에는 벤딩이 없으므로 추가하지 않거나 직관 거리만 표시합니다.
        continue;
      }

      // 1. 후퇴량(Setback) 및 호의 길이(Arc Length) 계산
      double setback = clr * math.tan((bendAngle / 2) * (math.pi / 180));
      double arcLength = 2 * math.pi * clr * (bendAngle / 360);

      // 2. Y(Feed) 이송 거리 계산
      // 도면상 거리에서 이전 벤딩의 절반(prev setback)과 현재 벤딩의 절반(curr setback)을 뺌
      double feedY = rawLength - previousSetback - setback;

      ybcTable.add({
        'step': i + 1,
        'Y_feed': feedY, // 파이프 밀어넣는 거리
        'B_rotate': rotation, // 파이프 돌리는 각도
        'C_bend': bendAngle, // 벤딩기가 꺾는 각도
        'arc_length': arcLength, // 참고용
      });

      // 전체 컷팅 기장 누적: 순수 직선 이송 거리 + 구부러진 호의 길이
      totalCutLength += feedY + arcLength;

      // 다음 계산을 위해 현재 setback 저장
      previousSetback = setback;
    }

    return {'totalCutLength': totalCutLength, 'ybcTable': ybcTable};
  }
}
