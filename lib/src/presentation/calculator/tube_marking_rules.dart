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
