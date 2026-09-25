// 앱 전체 틀: 상태 표시줄(시계·안테나·배터리)을 보이게 두고, 화면이 그 밑으로 들어가지 않게 한다.
//
// 🚀 [고침] 예전에는 앱 전체를 몰입 모드로 켜서 상태 표시줄이 늘 가려졌다. 통신이 없는
// 현장에서 쓰는 앱인데 안테나·시계·배터리를 보려면 화면 끝을 쓸어야 했다.
// 몰입 모드는 현장 탭(가로 줄자)처럼 화면이 넓어야 하는 곳만 따로 켠다.
// 위 틀이 없는 화면도 많아서, 앱 전체를 한 번 SafeArea로 감싸 겹치지 않게 한다.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 앱의 기본 화면 모드(상태 표시줄·아래 줄 보임).
const SystemUiMode kAppSystemUiMode = SystemUiMode.edgeToEdge;

class AppFrame extends StatelessWidget {
  final Widget child;
  const AppFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.black,
        systemNavigationBarColor: Colors.black,
      ),
      child: ColoredBox(
        color: Colors.black,
        child: SafeArea(child: child),
      ),
    );
  }
}
