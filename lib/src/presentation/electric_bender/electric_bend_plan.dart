// 전동 튜브 벤더 계산(화면 없음). 튜브 벤딩 엔진(TubeBendingEngine)과 형상 점검(checkBends)을 그대로 불러 쓰고,
// 엔진은 고치지 않는다. 여기서 더하는 것은 장비 쪽 값뿐이다:
// - 넣을 각도 = 설계각 + 스프링백. 스프링백은 90°에서 잰 값을 각도에 비례해 어림한다
//   (Swagelok MS-13-145: 작은 각은 덜 튀고 큰 각은 더 튄다. 비례는 어림이라 각마다 확인 권장).
// - 장비 최대 각, 클램프 물림 길이, 마지막 다리 최소 길이 점검.
library;

import 'package:tubing_calculator/src/core/engine/tube_bending_engine.dart';
import 'package:tubing_calculator/src/presentation/calculator/bend_check.dart';
import 'package:tubing_calculator/src/presentation/calculator/tube_marking_rules.dart';

import 'electric_machines.dart';

/// 목록 한 줄의 결과.
class ElectricBendRow {
  const ElectricBendRow({
    required this.no,
    required this.isStraight,
    required this.mark,
    required this.fromPrev,
    required this.straight,
    required this.designAngle,
    required this.setAngle,
    required this.springback,
    required this.roll,
  });

  /// 벤드 번호(1부터, 직관은 0).
  final int no;
  final bool isStraight;

  /// 관 끝에서 마킹까지(관이 휘기 시작하는 자리).
  final double mark;

  /// 앞 마킹에서 이 마킹까지.
  final double fromPrev;

  /// 이 벤드 앞 곧은 부분(앞 벤드 끝 또는 관 끝에서). 손 이송 장비의 이송 거리.
  final double straight;
  final double designAngle;

  /// 장비에 넣을 각도(설계각 + 스프링백).
  final double setAngle;
  final double springback;

  /// 앞 벤드에서 관을 굴릴 각(°).
  final double roll;
}

class ElectricPlan {
  const ElectricPlan({
    this.rows = const [],
    this.pureCut = 0,
    this.totalCut = 0,
    this.afterLast = 0,
    this.warnings = const [],
    this.error,
  });

  final List<ElectricBendRow> rows;

  /// 엔진 절단 길이(톱날 손실 전).
  final double pureCut;

  /// 자를 길이(톱날 손실 더함).
  final double totalCut;

  /// 마지막 벤드 뒤 곧은 길이.
  final double afterLast;
  final List<String> warnings;

  /// 계산할 수 없으면 까닭.
  final String? error;
}

/// 각도 [angle]에서의 스프링백 어림값.
double springbackAt(double sb90, double angle) =>
    sb90 <= 0 || angle <= 0 ? 0 : sb90 * angle / 90;

/// [bends]는 {length(교차점 기준), angle, rotation(방향 코드)}. [fittingDepth]가 0보다 크면 양 끝에 붙인다.
ElectricPlan planElectricBends({
  required Tooling tooling,
  required ElectricMachine machine,
  required List<Map<String, double>> bends,
  String startDir = 'RIGHT',
  double tail = 0,
  double fittingDepth = 0,
  double kerf = 0,
}) {
  if (bends.isEmpty) return const ElectricPlan();
  final fitted = tubeFittedLengths(
    bends,
    startFit: fittingDepth > 0,
    endFit: fittingDepth > 0,
    fittingDepth: fittingDepth,
    tail: tail,
  );
  final engine = TubeBendingEngine(
    radius: tooling.radius,
    userGain90: tooling.gain90,
  );
  final instructions = [
    for (int i = 0; i < bends.length; i++)
      BendInstruction(
        length: fitted.lengths[i],
        angle: (bends[i]['angle'] ?? 0) < 0 ? 0 : (bends[i]['angle'] ?? 0),
        rotation: bends[i]['rotation'] ?? 0,
      ),
  ];
  Map<String, dynamic> result;
  try {
    result = engine.calculate(instructions, 0, tail: fitted.tail);
  } catch (e) {
    return ElectricPlan(error: tubeEngineErrorText(e));
  }
  final double pure = result['totalCutLength'];
  final bad = badCutLengthText(pure);
  if (bad != null) return ElectricPlan(error: bad);
  final steps = (result['steps'] as List).cast<StepResult>();
  final check = checkBends(
    bends,
    radius: tooling.radius,
    startDir: startDir,
    tail: tail,
    outerDiameter: tooling.odMm,
    engineWarnings: (result['warnings'] as List?)?.cast<String>() ?? const [],
  );

  final warnings = <String>[...check.warnings];
  final rows = <ElectricBendRow>[];
  int no = 0;
  double prevBendEnd = 0; // 앞 벤드가 끝나는 자리(관 끝에서)
  for (int i = 0; i < steps.length; i++) {
    final s = steps[i];
    final a = bends[i]['angle'] ?? 0;
    final straightBend = a <= 0;
    if (!straightBend) no++;
    final sb = springbackAt(tooling.springback90, a);
    final set = a + sb;
    final straight = s.markingPoint - prevBendEnd;
    rows.add(
      ElectricBendRow(
        no: straightBend ? 0 : no,
        isStraight: straightBend,
        mark: s.markingPoint,
        fromPrev: s.incrementalMark,
        straight: straight,
        designAngle: a,
        setAngle: set,
        springback: sb,
        roll: check.rollByIndex[i] ?? 0,
      ),
    );
    if (!straightBend) {
      if (machine.maxAngle != null && set > machine.maxAngle! + 1e-9) {
        warnings.add(
          '$no번 벤드: 넣을 각도 ${set.toStringAsFixed(1)}°가 이 장비의 최대 '
          '${machine.maxAngle!.toStringAsFixed(0)}°를 넘습니다.',
        );
      }
      if (tooling.clampLen > 0 && straight < tooling.clampLen - 1e-9) {
        warnings.add(
          no == 1
              ? '1번 벤드: 관 끝에서 곧은 부분 ${straight.toStringAsFixed(0)}mm가 클램프 물림 '
                    '${tooling.clampLen.toStringAsFixed(0)}mm보다 짧습니다. 여유장 '
                    '${(tooling.clampLen - straight).toStringAsFixed(0)}mm를 더 붙여 자르고, 벤딩 뒤 잘라 내십시오.'
              : '$no번 벤드: 앞 벤드와의 곧은 부분 ${straight.toStringAsFixed(0)}mm가 클램프 물림 '
                    '${tooling.clampLen.toStringAsFixed(0)}mm보다 짧아 물리지 않을 수 있습니다.',
        );
      }
      prevBendEnd = s.markingPoint + 2 * s.setback - s.sectionGain;
    }
    // 직관 줄은 곧은 부분에 이어지므로 앞 벤드 끝을 그대로 둔다.
  }
  final after = straightAfterLastBend(steps, pure);
  if (no > 0 && tooling.lastLegMin > 0 && after < tooling.lastLegMin - 1e-9) {
    warnings.add(
      '마지막 다리 ${after.toStringAsFixed(0)}mm가 최소 ${tooling.lastLegMin.toStringAsFixed(0)}mm보다 '
      '짧아 롤러가 관에서 빠질 수 있습니다. 여유장을 붙여 자르고 벤딩 뒤 잘라 내십시오.',
    );
  }
  return ElectricPlan(
    rows: rows,
    pureCut: pure,
    totalCut: pure + kerf,
    afterLast: after,
    warnings: warnings,
  );
}

/// 시험 굽힘으로 스프링백(90° 기준) 구하기: 넣은 각 [set]으로 꺾었더니 [got]이 나왔다.
/// 각도에 비례해 어림하므로 90°로 환산한다. 넣은 각이 나온 각보다 작으면 0.
double springback90FromTrial({required double set, required double got}) {
  if (set <= 0 || got <= 0 || set <= got) return 0;
  return (set - got) * 90 / got;
}
