// 앱 전체 테마(main.dart와 UI 점검 도구가 같이 쓴다).
//
// 🚀 [바꿈] 예전에는 ThemeData.dark()(배경 #121212)였는데 화면은 모두 밝았다. 그래서 앱이
// 색을 안 준 기본 위젯(날짜 고르기·기본 창·드롭다운·배경을 안 준 화면)이 어둡게, 보라 단추로
// 나왔고, 이를 피하려고 화면마다 색을 직접 적었다. 이제 밝은 Material 3 테마를 토큰으로
// 만들어, 기본 위젯도 앱 모양(흰 바탕·청록·NotoSansKR)으로 나온다.
library;

import 'package:flutter/material.dart';

import 'app_icon_set.dart';
import 'app_tokens.dart';
import 'field_view.dart';

/// [p]를 주면 그 색 세트로(현장 보기: 햇빛·야간). 기본은 보통.
ThemeData buildAppTheme([FieldPalette p = FieldPalette.normal]) {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: p.brand,
        brightness: p.brightness,
      ).copyWith(
        primary: p.brand,
        onPrimary: p.onBrand,
        primaryContainer: p.brandSoft,
        onPrimaryContainer: p.text,
        secondary: p.brand,
        onSecondary: p.onBrand,
        surface: p.surface,
        onSurface: p.text,
        onSurfaceVariant: p.textSub,
        outline: p.line,
        outlineVariant: p.line,
        error: p.danger,
        onError: p.onBrand,
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
    extensions: [p],
    // 기본 뒤로·닫기 단추도 앱 아이콘 한 벌(D-E).
    actionIconTheme: ActionIconThemeData(
      backButtonIconBuilder: (_) => const Icon(AppIcons.back),
      closeButtonIconBuilder: (_) => const Icon(AppIcons.close),
    ),
    scaffoldBackgroundColor: p.surface,
    dividerColor: p.line,
    // 모든 글자 모양에 앱 글꼴과 글자 색을 준다(빠진 것이 있으면 폰 기본 글꼴로 나온다).
    // 크기·줄 간격은 기본값 그대로 둔다(글 모양을 한꺼번에 바꾸면 화면마다 넘칠 수 있다).
    // 크기 단계(AppText)는 부품을 옮길 때 이름으로 쓴다.
    textTheme: base.textTheme.apply(
      fontFamily: kAppFontFamily,
      bodyColor: p.text,
      displayColor: p.text,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.surface,
      foregroundColor: p.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: kAppFontFamily,
        fontSize: 18,
        fontWeight: AppText.bold,
        color: p.text,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: rounded(AppRadius.large),
      titleTextStyle: AppText.title,
      contentTextStyle: AppText.body.copyWith(color: p.textSub),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.large),
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: rounded(AppRadius.large),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: rounded(AppRadius.medium),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: p.brand,
        foregroundColor: p.onBrand,
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
        backgroundColor: p.brand,
        foregroundColor: p.onBrand,
        shape: rounded(AppRadius.medium),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.brand,
        side: BorderSide(color: p.brand),
        shape: rounded(AppRadius.medium),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: p.brand),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.brand,
      foregroundColor: p.onBrand,
      elevation: 2,
    ),
    // 바탕 채우기·테두리는 칸마다 정해 둔 것을 따른다(테마로 바꾸면 모든 칸 모양이 바뀐다).
    // 글 색만 맞춘다.
    inputDecorationTheme: InputDecorationTheme(
      hintStyle: TextStyle(color: p.textFaint),
      labelStyle: TextStyle(color: p.textSub),
      floatingLabelStyle: TextStyle(color: p.brand),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.text,
      contentTextStyle: TextStyle(
        fontFamily: kAppFontFamily,
        color: p.onBrand,
        fontSize: 14,
        fontWeight: AppText.medium,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.brand),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(p.surface),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.brand : p.line,
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.fill,
      selectedColor: p.brand,
      side: BorderSide.none,
      shape: rounded(AppRadius.small),
    ),
  );
}
