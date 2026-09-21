/// 튜브 마킹 화면들(폰 마킹 탭·현장 탭·태블릿 마킹·도면 보기)이 같이 쓰는
/// 규칙. 엔진 계산식은 건드리지 않고, 엔진이 돌려준 값만 읽는다.
library;

import 'package:tubing_calculator/src/core/engine/tube_bending_engine.dart';

/// 마지막 벤드가 끝난 뒤 관 끝까지 곧은 길이(톱날 손실은 빼고).
///
/// 엔진 절단 길이 − (마지막 벤드 마킹 + 그 벤드가 먹는 길이).
/// 벤드가 먹는 길이는 엔진과 같게 `2 × 셋백 − 게인`이다.
/// 벤드가 없으면 0.
///
/// 🚀 [고침] 예전에는 `절단 − 마지막 마킹 − 반경`으로 셈해서, R100·90°·꼬리
/// 300이면 200이어야 할 값을 257로, 꼬리가 없으면 0이어야 할 값을 57로
/// 보여 줬다.
double straightAfterLastBend(List<StepResult> steps, double pureCutLength) {
  for (int i = steps.length - 1; i >= 0; i--) {
    final s = steps[i];
    if (s.setback > 0) {
      final double bendEnd = s.markingPoint + 2 * s.setback - s.sectionGain;
      return pureCutLength - bendEnd;
    }
  }
  return 0.0;
}

/// 피팅 깊이를 붙인 뒤 엔진에 넘길 구간 길이와 꼬리.
///
/// 시작 피팅은 첫 구간에 붙인다. 끝 피팅은 관 끝에 붙는데, 꼬리가 있으면
/// 관 끝은 꼬리 끝이므로 꼬리에 붙인다(꼬리가 없으면 마지막 구간에).
/// 🚀 [고침] 예전에는 꼬리가 있어도 마지막 구간에 붙여서 마지막 벤드 마킹이
/// 피팅 깊이만큼 늦게 찍혔다(R100·500 90°·꼬리 300·깊이 20: 400 → 420).
({List<double> lengths, double tail, bool endFitOnTail}) tubeFittedLengths(
  List<Map<String, dynamic>> bendList, {
  required bool startFit,
  required bool endFit,
  required double fittingDepth,
  required double tail,
}) {
  final lengths = [
    for (final b in bendList) (b['length'] as num?)?.toDouble() ?? 0.0,
  ];
  final bool onTail = endFit && tail > 0;
  if (lengths.isNotEmpty) {
    if (startFit) lengths[0] += fittingDepth;
    if (endFit && !onTail) lengths[lengths.length - 1] += fittingDepth;
  }
  return (
    lengths: lengths,
    tail: onTail ? tail + fittingDepth : tail,
    endFitOnTail: onTail,
  );
}

/// 엔진 오류를 화면에 보일 글로. 'Invalid argument(s): ' 머리말을 뗀다.
/// 🚀 [고침] 마킹 탭은 이 머리말을 떼지 않고 그대로 보여 줬다.
String tubeEngineErrorText(Object e) =>
    e.toString().replaceFirst('Invalid argument(s): ', '');

/// 엔진이 돌려준 절단 길이를 쓸 수 없으면 그 까닭을, 쓸 수 있으면 null을 준다.
///
/// 엔진은 179.9° 이상만 막아서 179.8°는 통과하고 절단 길이가 음수
/// (R100·500 179.8°: −56482mm)로 나온다. 각도가 숫자가 아니면(NaN) 검사를
/// 모두 지나 절단 길이도 숫자가 아니다. 이런 값은 크게 보여 주지 않는다.
String? badCutLengthText(double pureCutLength) {
  if (!pureCutLength.isFinite) {
    return "셈 결과가 숫자가 아닙니다. 각도와 길이를 다시 확인하십시오.";
  }
  if (pureCutLength <= 0) {
    return "총 절단 길이가 ${pureCutLength.toStringAsFixed(0)}mm로 나옵니다. "
        "180°에 가까운 각이나 셋백보다 짧은 구간이 없는지 확인하십시오.";
  }
  return null;
}

/// 목록에 실제로 자를 구간이 있는지(길이 0짜리 빈 직관만 있으면 false).
bool hasRealTubeRow(List<Map<String, dynamic>> bendList) => bendList.any(
  (b) =>
      ((b['angle'] as num?)?.toDouble() ?? 0.0) > 0 ||
      ((b['length'] as num?)?.toDouble() ?? 0.0) > 0.01,
);
