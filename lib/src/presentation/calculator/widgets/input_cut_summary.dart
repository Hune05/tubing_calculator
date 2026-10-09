// 입력 탭 머리 둘째 줄: 총 절단 길이와 경고 수.
// 10-09 사용자: "입력 탭 머리에 총 절단 길이" — 한 손으로 줄을 넣으면서 마킹 탭을 오가지 않고 보게.
// 값은 마킹·현장 탭과 같은 셈(현장 자료)에서 가져온다.
library;

import 'package:flutter/material.dart';

import 'package:tubing_calculator/src/core/theme/app_tokens.dart';

class InputCutSummary extends StatelessWidget {
  /// 총 절단 길이(mm). 0 이하면 [emptyLabel]을 보인다.
  final double totalCut;

  /// 마킹 탭 위 띠의 경고 수.
  final int warnings;

  /// 줄이 없을 때 글.
  final String emptyLabel;

  final Color textColor;
  final Color valueColor;

  const InputCutSummary({
    super.key,
    required this.totalCut,
    required this.warnings,
    required this.textColor,
    required this.valueColor,
    this.emptyLabel = "총 조립 구간",
  });

  @override
  Widget build(BuildContext context) {
    if (totalCut <= 0) {
      return Text(
        emptyLabel,
        style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold),
      );
    }
    return Text.rich(
      key: const Key('input_cut_summary'),
      TextSpan(
        style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold),
        children: [
          const TextSpan(text: "총 절단 "),
          TextSpan(
            text: "${totalCut.round()}mm",
            style: TextStyle(color: valueColor, fontWeight: FontWeight.w900),
          ),
          if (warnings > 0)
            TextSpan(
              text: " · 경고 $warnings",
              style: const TextStyle(color: AppColors.caution, fontWeight: FontWeight.w900),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
