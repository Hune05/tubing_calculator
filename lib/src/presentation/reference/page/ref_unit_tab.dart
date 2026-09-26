// 단위 환산 탭: 홈 "단위 환산"과 같은 화면을 그대로 쓴다(2026-09-26 고도화 — 한 분류의
// 모든 단위를 한꺼번에, 인치 분수·전선 굵기·배관 호칭까지). 이 화면 위에 찾기 칸이 있어
// 환산 화면의 찾기 칸은 뺀다.
import 'package:flutter/material.dart';

import '../../unit_converter/unit_converter_page.dart';

class RefUnitTab extends StatelessWidget {
  const RefUnitTab({super.key});

  @override
  Widget build(BuildContext context) => const UnitConverterView(embedded: true);
}
