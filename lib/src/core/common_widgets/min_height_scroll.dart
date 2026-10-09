// 가로 화면 대비(10-09): 세로 기준으로 짠 "위 고정 칸 + 아래 목록(Expanded)" 화면이 가로로 눕힌 폰처럼
// 높이가 아주 낮으면 위 칸이 자리를 다 먹어 넘쳤다. 받은 높이가 [minHeight]보다 낮으면 안쪽을
// [minHeight] 높이로 그리고 바깥에서 통째로 스크롤한다. 높이가 넉넉하면 아무것도 바꾸지 않는다.
import 'package:flutter/material.dart';

class MinHeightScroll extends StatelessWidget {
  /// 안쪽이 제 모양을 지키는 가장 낮은 높이.
  final double minHeight;
  final Widget child;
  const MinHeightScroll({super.key, required this.minHeight, required this.child});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      if (!box.hasBoundedHeight || box.maxHeight >= minHeight) return child;
      return SingleChildScrollView(
        key: const Key('min_height_scroll'),
        child: SizedBox(height: minHeight, child: child),
      );
    },
  );
}
