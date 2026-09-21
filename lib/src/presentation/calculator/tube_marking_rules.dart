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
