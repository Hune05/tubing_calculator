import 'package:tubing_calculator/src/core/utils/shared_drawing_inbox.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tubing_calculator/src/presentation/menu/page/menu_screen.dart';
import 'package:tubing_calculator/src/presentation/menu/page/mobile_menu_page.dart';

/// 🚀 [신규] 폴더블(Z Fold4 등) 대응 - 앱을 쓰는 도중 화면을 펴거나 접어도
/// 그 순간의 화면 크기에 맞는 홈 화면을 실시간으로 보여준다.
///
/// 예전엔 앱을 처음 켰을 때의 화면 크기(DeviceRouter)로 딱 한 번만
/// MobileMenuPage/MenuScreen 중 하나를 골라서 push했고, 그 뒤로는 화면을
/// 펴도 최초에 고른 쪽(예: 좁은 모바일 메뉴)에 계속 갇혀 있었다.
/// MediaQuery는 화면 크기가 바뀔 때마다 이 위젯을 다시 빌드해주므로,
/// 이 라우터를 홈 진입점으로 쓰면 펴고 접을 때마다 즉시 반영된다.
class HomeMenuRouter extends StatelessWidget {
  final String currentWorker;

  const HomeMenuRouter({super.key, this.currentWorker = "로그인 필요"});

  @override
  Widget build(BuildContext context) {
    // 카톡 등에서 공유로 받아 둔 도면은 홈이 뜬 뒤에 연다(shared_drawing_inbox.dart).
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => SharedDrawingInbox.markHomeReady(),
    );
    final bool isWide = MediaQuery.of(context).size.shortestSide >= 600;
    if (isWide) return const MenuScreen();
    if (currentWorker != "로그인 필요") {
      return MobileMenuPage(currentWorker: currentWorker);
    }
    // 이름 없이 열렸으면(/menu 경로) 폰에 적어 둔 이름을 쓴다. 예전엔 로그인이 풀린 것처럼 보였다.
    return FutureBuilder<String?>(
      future: SharedPreferences.getInstance().then(
        (p) => p.getString('user_real_name'),
      ),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: SizedBox.shrink());
        }
        final name = snap.data;
        return MobileMenuPage(
          currentWorker: name == null || name.isEmpty ? currentWorker : name,
        );
      },
    );
  }
}
