// 화면 구성: 이제 화면 크기와 상관없이 앱 전체가 폰 화면(한 칸)만 쓴다.
// 2026-09-27: 8.7인치 탭까지는 폰 화면, 태블릿(두 칸) 화면은 10인치대 이상에서만 쓰도록 기준을 뒀었다.
// 2026-09-29: 기준값(600→800dp)을 올려도 기기마다 애매한 경계가 계속 헷갈려서("태블릿으로 가면
// 헷갈리고 폰으로 오면 또 헷갈린다"), 사용자가 두 칸 화면 자체를 없애고 어떤 화면에서든 늘 쓰던
// 폰 화면 하나로 통일하기로 함(기능 개발에 집중하는 쪽이 낫다고 판단). 남은 건 큰 화면(태블릿·PC)에서
// 내용이 너무 넓게 늘어나지 않게 폭만 좁혀 가운데 두는 것뿐이다.
library;

import 'package:flutter/material.dart';

class ScreenLayout {
  ScreenLayout._();

  /// 이 값(dp) 이상인 화면(짧은 변 기준)에서만 폭을 좁힌다. 가로로 든 폰(짧은 변이 작음)은
  /// 좁히지 않아 현장 탭 같은 가로 화면은 그대로 넓게 나온다.
  static const double wideScreenShortSide = 800;

  /// 위 크기 이상인 화면에서 내용의 가장 넓은 폭(dp).
  static const double phoneMaxWidth = 600;
}

/// 태블릿·PC처럼 큰 화면(짧은 변이 [ScreenLayout.wideScreenShortSide] 이상)에서는 내용을
/// [ScreenLayout.phoneMaxWidth]로 좁혀 가운데에 둔다. 폰을 가로로 든 경우는 좁히지 않는다.
class ScreenLayoutHost extends StatelessWidget {
  final Widget child;
  const ScreenLayoutHost({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bool narrow =
        mq.size.shortestSide >= ScreenLayout.wideScreenShortSide &&
        mq.size.width > ScreenLayout.phoneMaxWidth;
    if (!narrow) return child;
    // 자식이 보는 화면 폭도 좁힌 폭으로 알려 준다(MediaQuery 폭으로 셈하는 화면이 어긋나지 않게).
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: ScreenLayout.phoneMaxWidth,
        child: MediaQuery(
          data: mq.copyWith(
            size: Size(ScreenLayout.phoneMaxWidth, mq.size.height),
          ),
          child: child,
        ),
      ),
    );
  }
}
