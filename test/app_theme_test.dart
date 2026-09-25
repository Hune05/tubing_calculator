// 앱 테마·토큰(UI 디자인 제안 D-A).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/core/theme/app_theme.dart';
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';

void main() {
  test('밝은 테마, 주 색 청록, 앱 글꼴', () {
    final t = buildAppTheme();
    // 예전: ThemeData.dark()라 색을 안 준 기본 위젯이 어둡게 나왔다.
    expect(t.brightness, Brightness.light);
    expect(t.colorScheme.primary, AppColors.brand);
    expect(t.colorScheme.error, AppColors.danger);
    expect(t.scaffoldBackgroundColor, AppColors.surface);
    expect(t.textTheme.bodyMedium?.fontFamily, kAppFontFamily);
    expect(t.textTheme.titleLarge?.fontFamily, kAppFontFamily);
  });

  test('글자 단계는 모두 앱 글꼴, 숫자 표시는 자리 맞춤', () {
    for (final s in [
      AppText.numberLarge,
      AppText.number,
      AppText.title,
      AppText.subtitle,
      AppText.body,
      AppText.sub,
      AppText.caption,
    ]) {
      expect(s.fontFamily, kAppFontFamily);
    }
    expect(
      AppText.number.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });

  testWidgets('기본 창도 흰 바탕·청록 단추로 나온다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('확인'),
                actions: [TextButton(onPressed: () {}, child: const Text('예'))],
              ),
            ),
            child: const Text('열기'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    final dialogMaterial = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(dialogMaterial.color, AppColors.surface);
    final btn = tester.widget<TextButton>(find.widgetWithText(TextButton, '예'));
    final fg =
        btn.style?.foregroundColor?.resolve({}) ??
        Theme.of(
          tester.element(find.text('예')),
        ).textButtonTheme.style?.foregroundColor?.resolve({});
    expect(fg, AppColors.brand);
  });
}
