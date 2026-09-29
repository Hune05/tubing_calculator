// 화면 구성(폰 화면 / 태블릿 화면 / 자동): 앱 전체가 같은 기준을 본다.
// 2026-09-27 사용자 요청: 8.7인치 탭까지는 폰 화면으로, 태블릿 화면은 10인치대 이상에서만.
// 2026-09-29: 갤럭시 탭 A9+(11인치)를 자동 모드로 켜 보니 짧은 변이 800dp라 태블릿 화면이 됐고,
// 9인치급(약 764dp)으로 화면 크기를 흉내 내 봐도 600dp 기준을 넘어 태블릿 화면으로 바뀌는 것을
// 확인했다 — "8.7인치까지는 폰 화면" 의도와 어긋나 기준을 800으로 올렸다. 폴더블 안쪽 화면도
// 이 기준을 같이 쓰므로, 이제 폴더블 안쪽 화면도 태블릿이 아닌 폰 화면으로 나온다(사용자 확인·동의함).
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ScreenLayoutMode {
  auto('자동', '화면 크기로 정합니다.'),
  phone('폰 화면', '큰 화면에서도 폰 화면 하나로 씁니다.'),
  tablet('태블릿 화면', '큰 화면의 두 칸 화면을 씁니다.');

  final String label;
  final String description;
  const ScreenLayoutMode(this.label, this.description);
}

class ScreenLayout {
  ScreenLayout._();

  /// 자동일 때 이 값(dp) 이상이면 태블릿 화면. 폴더블 안쪽 화면이 이 기준을 쓴다.
  /// 2026-09-29: 600 → 800(8.7~9인치 태블릿은 폰 화면, 10인치대부터 태블릿 화면이 되도록).
  static const double tabletMinShortSide = 800;

  /// 폰 화면을 큰 화면(짧은 변이 태블릿 기준 이상)에서 쓸 때 내용의 가장 넓은 폭(dp).
  static const double phoneMaxWidth = 600;

  static const String prefKey = 'screen_layout_mode_v1';

  static final ValueNotifier<ScreenLayoutMode> mode = ValueNotifier(
    ScreenLayoutMode.auto,
  );

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(prefKey);
      if (saved != null) {
        mode.value = ScreenLayoutMode.values.firstWhere(
          (m) => m.name == saved,
          orElse: () => ScreenLayoutMode.auto,
        );
      }
    } catch (_) {}
  }

  static Future<void> set(ScreenLayoutMode m) async {
    mode.value = m;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefKey, m.name);
    } catch (_) {}
  }

  /// [size]가 태블릿 화면인지(모드 반영).
  static bool isTabletSize(Size size) => switch (mode.value) {
    ScreenLayoutMode.phone => false,
    ScreenLayoutMode.tablet => true,
    ScreenLayoutMode.auto => size.shortestSide >= tabletMinShortSide,
  };

  static bool isTablet(BuildContext context) =>
      isTabletSize(MediaQuery.of(context).size);
}

/// 화면 구성을 바꾸면 화면을 모두 다시 그리고, "폰 화면"으로 큰 화면(짧은 변이 태블릿 기준 이상)을
/// 쓸 때는 내용을 [ScreenLayout.phoneMaxWidth]로 좁혀 가운데에 둔다. 폰을 가로로 든 경우(짧은 변이
/// 작음)는 좁히지 않는다: 현장 탭 같은 가로 화면이 그대로 넓게 나온다.
class ScreenLayoutHost extends StatefulWidget {
  final Widget child;
  const ScreenLayoutHost({super.key, required this.child});

  @override
  State<ScreenLayoutHost> createState() => _ScreenLayoutHostState();
}

class _ScreenLayoutHostState extends State<ScreenLayoutHost> {
  @override
  void initState() {
    super.initState();
    ScreenLayout.mode.addListener(_changed);
  }

  @override
  void dispose() {
    ScreenLayout.mode.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    void rebuild(Element e) {
      e.markNeedsBuild();
      e.visitChildren(rebuild);
    }

    setState(() {});
    (context as Element).visitChildren(rebuild);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bool narrow =
        ScreenLayout.mode.value == ScreenLayoutMode.phone &&
        mq.size.shortestSide >= ScreenLayout.tabletMinShortSide &&
        mq.size.width > ScreenLayout.phoneMaxWidth;
    if (!narrow) return widget.child;
    // 자식이 보는 화면 폭도 좁힌 폭으로 알려 준다(MediaQuery 폭으로 셈하는 화면이 어긋나지 않게).
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: ScreenLayout.phoneMaxWidth,
        child: MediaQuery(
          data: mq.copyWith(
            size: Size(ScreenLayout.phoneMaxWidth, mq.size.height),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
