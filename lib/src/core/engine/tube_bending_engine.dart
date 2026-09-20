import 'bend_geometry.dart';

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
  final double targetAngle; // 스프링백을 더해 "실제로 꺾을" 각도 (표시용)
  // 🚀 [추가] 이 구간에서 실제로 남는 곧은 부분. 앞뒤 셋백을 뺀 값이라
  // 이 값이 벤더에 물릴 수 있는 길이다. 음수면 만들 수 없는 형상이다.
  final double straightPart;
  final double setback; // 이 벤드의 셋백

  StepResult({
    required this.markingPoint,
    required this.incrementalMark,
    required this.sectionGain,
    double? targetAngle,
    this.straightPart = 0.0,
    this.setback = 0.0,
  }) : targetAngle = targetAngle ?? 0.0;
}

/// 🚀 정밀 3D 튜빙 연산 엔진 (줄자 누적 추적 방식 + 실측 연신율 반영)
class TubeBendingEngine {
  final double radius; // 벤더기 곡률 반경
  final double userGain90; // 현장에서 90°로 한 번 꺾어 잰 게인
  // 스프링백 보상. 소재가 탄성으로 되돌아오므로 "이만큼 더 꺾으라"는 지시다.
  // 🚀 [고침] 예전에는 이 값을 더한 각도로 셋백·게인·마킹까지 계산해서,
  // 스프링백을 넣을수록 마킹이 앞으로 당겨지고 완성 치수가 짧아졌다
  // (2°에 3.5mm, 5°에 9.1mm). 완성 형상은 설계 각도이므로 기하 계산은
  // 설계 각도로 하고, 이 값은 "꺾을 각도" 표시에만 쓴다.
  final double springbackDeg;

  // 🚀 [추가] 180°에 근접한 각도 (setBack = R*tan(θ/2) 가 발산하는 지점) 방어용 상한.
  // 180°는 진입/진출 접선이 평행해져 "C-to-C(교차점)" 방식 자체가 정의되지 않으므로,
  // 이 임계값 이상은 계산하지 않고 명확한 에러를 던진다 (전용 U-Bend 계산기 사용 유도).
  static const double _maxSafeAngle = 179.9;

  TubeBendingEngine({
    required this.radius,
    this.userGain90 = 0.0, // 기본값 처리
    this.springbackDeg = 0.0,
  });

  /// 각 노드별 마킹 지점과 총 절단 기장 계산.
  ///
  /// [startFitting] 줄자를 0으로 놓는 자리(장비 원점 보정).
  /// [tail] 마지막 벤드 뒤에 남기는 구간. 다른 길이와 같은 교차점(C-to-C)
  /// 기준으로 받아서, 마지막 셋백을 빼고 더한다.
  /// 🚀 [고침] 예전에는 화면들이 총 길이에 꼬리를 그대로 더해서 마지막 셋백만큼
  /// (90°·R100이면 100mm) 길게 잘랐다.
  Map<String, dynamic> calculate(
    List<BendInstruction> instructions,
    double startFitting, {
    double tail = 0.0,
  }) {
    if (instructions.isEmpty) {
      return {
        'totalCutLength': tail > 0 ? startFitting + tail : 0.0,
        'steps': <StepResult>[],
        // 🚀 [수정] 빈 리스트일 때도 다른 경로와 동일하게 totalGain 키를 항상 포함시켜
        // result['totalGain']을 무조건 읽는 호출부가 null 캐스팅 에러를 내지 않도록 함
        'totalGain': 0.0,
        'warnings': <String>[],
      };
    }

    double currentTapePos = startFitting;
    double prevSetBack = 0.0;
    double prevMarkPoint = 0.0;
    double totalGain = 0.0;
    final warnings = <String>[];

    List<StepResult> steps = [];

    for (int i = 0; i < instructions.length; i++) {
      final inst = instructions[i];

      if (inst.isStraight) {
        // 직관(0도) 모드: 순수 물리적 연장선
        double markPoint = currentTapePos + inst.length - prevSetBack;
        double incremental = steps.isEmpty
            ? (markPoint - startFitting)
            : (markPoint - prevMarkPoint);

        steps.add(
          StepResult(
            markingPoint: markPoint,
            incrementalMark: incremental,
            sectionGain: 0.0,
            straightPart: inst.length - prevSetBack,
          ),
        );

        currentTapePos = markPoint;
        prevSetBack = 0.0;
        prevMarkPoint = markPoint;
      } else {
        // 🚀 [수정] 0° 초과 180° 근접(179.9°) 미만인지 검증.
        // 음수/0 이하 각도나 180°에 가까운(또는 그 이상) 각도가 들어오면
        // setBack = R*tan(θ/2)가 음수이거나 발산(사실상 무한대)하면서
        // 이후 모든 마킹/절단 길이 계산이 조용히 깨진 값으로 오염된다.
        if (inst.angle <= 0 || inst.angle >= _maxSafeAngle) {
          throw ArgumentError(
            '벤딩 각도(${inst.angle}°)가 유효 범위(0° 초과 ~ $_maxSafeAngle° 미만)를 벗어났습니다. '
            '180°에 가까운 U-Bend는 전용 U-Bend 계산기를 사용해 주십시오.',
          );
        }

        // 기하 계산은 설계 각도로 한다. 스프링백은 "꺾을 각도"에만 얹는다.
        final double designAngle = inst.angle;
        final double targetAngle = (designAngle + springbackDeg).clamp(
          0.0,
          _maxSafeAngle,
        );

        // 1. 기하학적 셋백 (SetBack) - 탄젠트 시작점 찾기
        final double setBack = bendSetback(radius, designAngle);

        // 2. 직선 파이프 물리량 및 마킹 포인트
        final double straightPart = inst.length - prevSetBack - setBack;
        if (straightPart < 0) {
          warnings.add(
            '${i + 1}번 구간: 앞뒤 벤드를 빼면 곧은 부분이 '
            '${straightPart.toStringAsFixed(1)}mm입니다. 이대로는 만들 수 없습니다.',
          );
        }
        final double markPoint = currentTapePos + straightPart;
        final double incremental = steps.isEmpty
            ? (markPoint - startFitting)
            : (markPoint - prevMarkPoint);

        // 3. 게인 — 실측값이 있으면 각도에 맞춰 환산해서 쓴다.
        // 🚀 [고침] 예전에는 실측 게인을 각도에 비례로(게인90 × 각/90) 환산해서
        // 45°에서 벤드당 16mm, 60°에서 17mm씩 짧게 잘랐다.
        final double appliedGain = effectiveGain(
          radius: radius,
          angleDeg: designAngle,
          measuredGain90: userGain90,
        );

        // 4. 관이 실제로 휘는 데 쓰는 길이
        final double bendAllowance = (2 * setBack) - appliedGain;

        steps.add(
          StepResult(
            markingPoint: markPoint,
            incrementalMark: incremental,
            sectionGain: appliedGain,
            targetAngle: targetAngle,
            straightPart: straightPart,
            setback: setBack,
          ),
        );

        // 곡선을 접었으므로, 파이프의 끝단(줄자 눈금)은 '실제 곡선 소모량'만큼 전진
        currentTapePos = markPoint + bendAllowance;

        totalGain += appliedGain;
        prevSetBack = setBack;
        prevMarkPoint = markPoint;
      }
    }

    // 꼬리: 교차점 기준으로 받았으므로 마지막 셋백을 빼고 더한다.
    double totalCut = currentTapePos;
    if (tail > 0) {
      final double tailStraight = tail - prevSetBack;
      if (tailStraight < 0) {
        warnings.add(
          '꼬리 구간: 마지막 벤드를 빼면 곧은 부분이 '
          '${tailStraight.toStringAsFixed(1)}mm입니다. 이대로는 만들 수 없습니다.',
        );
      }
      totalCut += tailStraight;
    }

    return {
      'totalCutLength': totalCut,
      'steps': steps,
      'totalGain': totalGain,
      'warnings': warnings,
      'lastSetback': prevSetBack,
    };
  }
}
