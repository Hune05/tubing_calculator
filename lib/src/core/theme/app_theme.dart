// 앱 전체 테마(main.dart와 UI 점검 도구가 같이 쓴다).
//
// 🚀 [바꿈] 예전에는 ThemeData.dark()(배경 #121212)였는데 화면은 모두 밝았다. 그래서 앱이
// 색을 안 준 기본 위젯(날짜 고르기·기본 창·드롭다운·배경을 안 준 화면)이 어둡게, 보라 단추로
// 나왔고, 이를 피하려고 화면마다 색을 직접 적었다. 이제 밝은 Material 3 테마를 토큰으로
// 만들어, 기본 위젯도 앱 모양(흰 바탕·청록·NotoSansKR)으로 나온다.
library;

import 'package:flutter/material.dart';

import 'app_tokens.dart';

ThemeData buildAppTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.brand,
        brightness: Brightness.light,
      ).copyWith(
        primary: AppColors.brand,
        onPrimary: AppColors.onBrand,
        primaryContainer: AppColors.brandSoft,
        onPrimaryContainer: AppColors.text,
        secondary: AppColors.brand,
        onSecondary: AppColors.onBrand,
        surface: AppColors.surface,
        onSurface: AppColors.text,
        onSurfaceVariant: AppColors.textSub,
        outline: AppColors.line,
        outlineVariant: AppColors.line,
        error: AppColors.danger,
        onError: AppColors.onBrand,
        surfaceTint: Colors.transparent,
      );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: kAppFontFamily,
  );

  RoundedRectangleBorder rounded(double r) =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(r));

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.surface,
    dividerColor: AppColors.line,
    // 모든 글자 모양에 앱 글꼴과 글자 색을 준다(빠진 것이 있으면 폰 기본 글꼴로 나온다).
    // 크기·줄 간격은 기본값 그대로 둔다(글 모양을 한꺼번에 바꾸면 화면마다 넘칠 수 있다).
    // 크기 단계(AppText)는 부품을 옮길 때 이름으로 쓴다.
    textTheme: base.textTheme.apply(
      fontFamily: kAppFontFamily,
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: kAppFontFamily,
        fontSize: 18,
        fontWeight: AppText.bold,
        color: AppColors.text,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: rounded(AppRadius.large),
      titleTextStyle: AppText.title,
      contentTextStyle: AppText.body.copyWith(color: AppColors.textSub),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.large),
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: rounded(AppRadius.large),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: rounded(AppRadius.medium),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.brand,
        foregroundColor: AppColors.onBrand,
        elevation: 0,
        shape: rounded(AppRadius.medium),
        textStyle: const TextStyle(
          fontFamily: kAppFontFamily,
          fontWeight: AppText.bold,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.brand,
        foregroundColor: AppColors.onBrand,
        shape: rounded(AppRadius.medium),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.brand,
        side: const BorderSide(color: AppColors.brand),
        shape: rounded(AppRadius.medium),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.brand),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.brand,
      foregroundColor: AppColors.onBrand,
      elevation: 2,
    ),
    // 바탕 채우기·테두리는 칸마다 정해 둔 것을 따른다(테마로 바꾸면 모든 칸 모양이 바뀐다).
    // 글 색만 맞춘다.
    inputDecorationTheme: const InputDecorationTheme(
      hintStyle: TextStyle(color: AppColors.textFaint),
      labelStyle: TextStyle(color: AppColors.textSub),
      floatingLabelStyle: TextStyle(color: AppColors.brand),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.text,
      contentTextStyle: TextStyle(
        fontFamily: kAppFontFamily,
        color: AppColors.onBrand,
        fontSize: 14,
        fontWeight: AppText.medium,
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.brand,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(AppColors.surface),
      trackColor: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.selected) ? AppColors.brand : AppColors.line,
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.fill,
      selectedColor: AppColors.brand,
      side: BorderSide.none,
      shape: rounded(AppRadius.small),
    ),
  );
}
