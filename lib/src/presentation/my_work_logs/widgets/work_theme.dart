import 'package:flutter/material.dart';

// 🚀 앱 전체 테마가 다크(ThemeData.dark)라서, "내 프로젝트" 화면들(흰 배경 디자인)에서
// 색을 따로 지정하지 않은 위젯(텍스트 버튼, 칩, 대화상자, 시트 등)이 어두운 테마 색으로
// 나왔다(연보라 버튼, 거의 안 보이는 칩 글자 등). 이 화면들만 밝은 마키타 틸 테마로
// 감싸서 해결한다. 페이지를 [WorkRoute]로 열면 그 안의 대화상자/시트도 같은 테마를 쓴다.
const Color _kTeal = Color(0xFF007580);

ThemeData workThemeData() {
  final base = ThemeData.light(useMaterial3: true);
  final scheme = ColorScheme.fromSeed(
    seedColor: _kTeal,
    brightness: Brightness.light,
  ).copyWith(primary: _kTeal, secondary: _kTeal);
  return base.copyWith(
    colorScheme: scheme,
    primaryColor: _kTeal,
    scaffoldBackgroundColor: const Color(0xFFF2F4F6),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: _kTeal),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(foregroundColor: _kTeal),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: const Color(0xFFF2F4F6),
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
