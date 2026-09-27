import 'package:tubing_calculator/src/core/utils/shared_drawing_inbox.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// 폰 메뉴는 폭 [kHomeMenuMaxWidth]까지만 넓히고 그 이상은 가운데에 둔다(큰 화면·PC).
  static const double kHomeMenuMaxWidth = 720;

  static Widget _fit(Widget child) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: kHomeMenuMaxWidth),
      child: child,
    ),
  );

  const HomeMenuRouter({super.key, this.currentWorker = "로그인 필요"});

  @override
  Widget build(BuildContext context) {
    // 카톡 등에서 공유로 받아 둔 도면은 홈이 뜬 뒤에 연다(shared_drawing_inbox.dart).
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => SharedDrawingInbox.markHomeReady(),
    );
    // 2026-09-27: 예전엔 큰 화면(짧은 변 600dp 이상)에서 옛 격자 메뉴(MenuScreen)를 보여 줬는데, 폰 메뉴에 있는
    // 전기 설계 계산·압력 시험·유량·계기 교정·단위 환산·자재 현황 등이 없어서 큰 화면에서 새 기능을 열 수 없었다.
    // 폰 메뉴 하나를 어느 크기에서든 쓴다(넓으면 ScreenLayoutHost·아래 폭 제한이 가운데에 모은다).
    if (currentWorker != "로그인 필요") {
      return _fit(MobileMenuPage(currentWorker: currentWorker));
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
        return _fit(
          MobileMenuPage(
            currentWorker: name == null || name.isEmpty ? currentWorker : name,
          ),
        );
      },
    );
  }
}
