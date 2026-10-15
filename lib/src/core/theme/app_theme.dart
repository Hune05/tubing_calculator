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

  // 10-15 새 칸·단추 모양(사용자 결정): 테두리는 옅은 나눔선보다 한 단계 진하게, 고른 것은
  // 옅은 청록 바탕 + ✓ + 짙은 청록 글자(꽉 찬 청록에 흰 글자는 주 단추에만).
  final strong = Color.lerp(p.line, p.textFaint, 0.45)!;
  final picked = p.brightness == Brightness.dark
      ? p.brand
      : Color.lerp(p.brand, Colors.black, 0.25)!;
  OutlineInputBorder box(Color c, double w) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.small),
    borderSide: BorderSide(color: c, width: w),
  );
  const btnText = TextStyle(
    fontFamily: kAppFontFamily,
    fontSize: 15,
    fontWeight: AppText.bold,
  );
  const btnMin = Size(64, 48);

  return base.copyWith(
    extensions: [p],
    // 화면 이동: 새 화면이 아래에서 살짝 떠오르며 서서히 나타나고, 이전 화면은
    // 뒤로 물러난다(뚝 열리던 기본 전환 대신). 앱의 모든 화면 이동에 한꺼번에 적용.
    // 오른쪽에서 밀려 들어오는 방식은 안드로이드 가장자리 뒤로 제스처와 겹쳐 뺐다.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
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
      // 그림자 없이 얇은 테두리
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        side: BorderSide(color: p.line),
      ),
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
        minimumSize: btnMin,
        shape: rounded(AppRadius.medium),
        textStyle: btnText,
      ),
    ),
    // 주 단추: 청록으로 꽉 차고 흰 글자
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.brand,
        foregroundColor: p.onBrand,
        minimumSize: btnMin,
        shape: rounded(AppRadius.medium),
        textStyle: btnText,
      ),
    ),
    // 보조 단추: 흰 바탕·회색 테두리·짙은 글자
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.text,
        backgroundColor: p.surface,
        side: BorderSide(color: strong, width: 1.2),
        minimumSize: btnMin,
        shape: rounded(AppRadius.medium),
        textStyle: btnText,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(rounded(AppRadius.small)),
        side: WidgetStatePropertyAll(BorderSide(color: strong, width: 1.2)),
        minimumSize: const WidgetStatePropertyAll(Size(48, 40)),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.brandSoft : p.surface,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? picked : p.text,
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontFamily: kAppFontFamily, fontSize: 14, fontWeight: AppText.medium),
        ),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: p.brand),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.brand,
      foregroundColor: p.onBrand,
      elevation: 2,
    ),
    // 10-15: 칸 모양을 앱 전체 한 가지로 — 네모(모서리 4) 테두리, 누르는 중 청록 2, 잘못 빨강,
    // 잠김 회색 바탕. 칸마다 따로 정한 것(바탕 채우기 등)은 그대로 그것을 따른다.
    inputDecorationTheme: InputDecorationTheme(
      hintStyle: TextStyle(color: p.textFaint),
      labelStyle: TextStyle(color: p.textSub),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith(
        (s) => TextStyle(
          color: s.contains(WidgetState.error)
              ? p.danger
              : (s.contains(WidgetState.focused) ? p.brand : p.textSub),
        ),
      ),
      helperStyle: TextStyle(color: p.textSub, fontSize: 12),
      errorMaxLines: 3,
      border: box(strong, 1.2),
      enabledBorder: box(strong, 1.2),
      focusedBorder: box(p.brand, 2),
      errorBorder: box(p.danger, 1.5),
      focusedErrorBorder: box(p.danger, 2),
      disabledBorder: box(p.line, 1),
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
    // 고르기 칩: 네모(4), 고르면 옅은 청록 + ✓ + 짙은 청록 글자(10-15, 압력 타이머 방식).
    chipTheme: ChipThemeData(
      backgroundColor: p.surface,
      selectedColor: p.brandSoft,
      checkmarkColor: picked,
      showCheckmark: true,
      side: WidgetStateBorderSide.resolveWith(
        (s) => BorderSide(
          color: s.contains(WidgetState.selected)
              ? Color.lerp(p.brandSoft, p.brand, 0.45)!
              : strong,
          width: 1.2,
        ),
      ),
      labelStyle: TextStyle(
        fontFamily: kAppFontFamily,
        fontWeight: AppText.medium,
        color: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected) ? picked : p.text,
        ),
      ),
      shape: rounded(AppRadius.small),
    ),
  );
}
