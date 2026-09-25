import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';

// 🚀 앱 전체 테마가 다크(ThemeData.dark)라서, "내 프로젝트" 화면들(흰 배경 디자인)에서
// 색을 따로 지정하지 않은 위젯(텍스트 버튼, 칩, 대화상자, 시트 등)이 어두운 테마 색으로
// 나왔다(연보라 버튼, 거의 안 보이는 칩 글자 등). 이 화면들만 밝은 마키타 틸 테마로
// 감싸서 해결한다. 페이지를 [WorkRoute]로 열면 그 안의 대화상자/시트도 같은 테마를 쓴다.
const Color _kTeal = AppColors.brand;

ThemeData workThemeData() {
  final base = ThemeData.light(useMaterial3: true);
  final scheme = ColorScheme.fromSeed(
    seedColor: _kTeal,
    brightness: Brightness.light,
  ).copyWith(primary: _kTeal, secondary: _kTeal);
  return base.copyWith(
    colorScheme: scheme,
    primaryColor: _kTeal,
    scaffoldBackgroundColor: AppColors.background,
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: _kTeal),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(foregroundColor: _kTeal),
    ),
    // 팝업이 좁아 짧은 제목·안내가 억지로 두 줄이 되던 문제: 좌우 여백을 줄여 폭을 넓히고,
    // 제목·본문 글자를 조금 줄였다. 글이 정말 길어서 넘어가는 줄바꿈은 그대로 둔다.
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 24),
      actionsPadding: EdgeInsets.fromLTRB(12, 0, 12, 10),
      titleTextStyle: TextStyle(
        color: AppColors.text,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: TextStyle(
        color: Color(0xFF4E5968),
        fontSize: 15,
        height: 1.45,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppColors.background,
      selectedColor: const Color(0xFFD5E9EB),
      side: BorderSide.none,
      labelStyle: const TextStyle(
        color: Color(0xFF4E5968),
        fontWeight: FontWeight.w600,
      ),
      secondaryLabelStyle: const TextStyle(
        color: _kTeal,
        fontWeight: FontWeight.w700,
      ),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
  );
}

class WorkTheme extends StatelessWidget {
  final Widget child;
  const WorkTheme({super.key, required this.child});

  @override
  Widget build(BuildContext context) =>
      Theme(data: workThemeData(), child: child);
}

class WorkRoute<T> extends MaterialPageRoute<T> {
  WorkRoute({required WidgetBuilder builder, super.settings})
    : super(builder: (context) => WorkTheme(child: builder(context)));
}
