// 현장 보기 세 가지(보통·햇빛·야간, UI 디자인 제안 D-D).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/common_widgets/app_components.dart';
import 'package:tubing_calculator/src/core/common_widgets/field_view_picker.dart';
import 'package:tubing_calculator/src/core/theme/app_theme.dart';
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:tubing_calculator/src/core/theme/field_view.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_input_tab.dart';

double _lum(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// 보기가 바뀌면 다시 그려지는지 보는 상수 위젯(자기 스스로는 보기를 듣지 않는다).
class _Probe extends StatelessWidget {
  const _Probe();
  @override
  Widget build(BuildContext context) =>
      ColoredBox(key: const Key('probe'), color: fc.surface);
}

void main() {
  setUp(() {
    FieldColors.mode.value = FieldViewMode.normal;
    SharedPreferences.setMockInitialValues({});
  });

  group('색 대비', () {
    test('본문 글: 햇빛은 7:1 이상(AAA), 야간·보통은 4.5:1 이상', () {
      for (final m in FieldViewMode.values) {
        final p = FieldPalette.of(m);
        final need = m == FieldViewMode.sunlight ? 7.0 : 4.5;
        for (final bg in [p.background, p.surface, p.fill]) {
          expect(
            contrast(p.text, bg),
            greaterThanOrEqualTo(need),
            reason: '$m',
          );
          expect(
            contrast(p.textSub, bg),
            greaterThanOrEqualTo(4.5),
            reason: '$m 보조 글',
          );
        }
      }
    });

    test('청록 단추 위 글과 청록 글도 4.5:1 이상', () {
      for (final m in FieldViewMode.values) {
        final p = FieldPalette.of(m);
        expect(
          contrast(p.onBrand, p.brand),
          greaterThanOrEqualTo(4.5),
          reason: '$m',
        );
        expect(
          contrast(p.brand, p.surface),
          greaterThanOrEqualTo(3),
          reason: '$m',
        );
        expect(
          contrast(p.danger, p.surface),
          greaterThanOrEqualTo(3),
          reason: '$m',
        );
      }
    });

    test('보통 보기는 앱 토큰 그대로(예전 화면과 같음)', () {
      const p = FieldPalette.normal;
      expect(p.brand, AppColors.brand);
      expect(p.text, AppColors.text);
      expect(p.surface, AppColors.surface);
      expect(buildAppTheme().extension<FieldPalette>(), FieldPalette.normal);
      expect(
        buildAppTheme(FieldPalette.night).colorScheme.brightness,
        Brightness.dark,
      );
    });
  });

  group('기억', () {
    test('예전 현장 탭 햇빛 단추 값을 옮긴다', () async {
      SharedPreferences.setMockInitialValues({'field_high_contrast': true});
      await FieldColors.load();
      expect(FieldColors.mode.value, FieldViewMode.sunlight);
    });

    test('고른 보기를 기억하고 다시 읽는다', () async {
      await FieldColors.set(FieldViewMode.night);
      FieldColors.mode.value = FieldViewMode.normal;
      await FieldColors.load();
      expect(FieldColors.mode.value, FieldViewMode.night);
    });
  });

  testWidgets('설정에서 야간을 누르면 바로 바뀌고 기억한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: FieldViewModePicker(),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('field_view_night')));
    await tester.pumpAndSettle();
    expect(FieldColors.mode.value, FieldViewMode.night);
    expect(find.text(FieldViewMode.night.description), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(FieldColors.prefKey), 'night');
  });

  testWidgets('보기를 바꾸면 상수로 만든 위젯까지 다시 그려진다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => FieldViewHost(child: child!),
        home: const _Probe(),
      ),
    );
    ColoredBox box() =>
        tester.widget<ColoredBox>(find.byKey(const Key('probe')));
    expect(box().color, FieldPalette.normal.surface);
    FieldColors.mode.value = FieldViewMode.night;
    await tester.pump();
    expect(box().color, FieldPalette.night.surface);
  });

  testWidgets('야간: 튜브 입력 탭이 어둡고, 빈 화면 글·보조 단추도 야간 색, 넘치지 않음', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    FieldColors.mode.value = FieldViewMode.night;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(body: MobileInputTab()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);

    final title = tester.widget<Text>(find.text('설계된 배관이 없습니다'));
    expect(title.style?.color, FieldPalette.night.text);
    final special = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('특수 벤딩 툴 (오프셋/새들 등)'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(
      special.style?.backgroundColor?.resolve({}),
      FieldPalette.night.surface,
    );
    // 탭 바탕(흰 카드가 남지 않았는지): 입력판 바탕이 야간 표면색.
    final boxes = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .map((d) => d.color)
        .whereType<Color>()
        .toSet();
    expect(boxes.contains(Colors.white), isFalse, reason: '흰 칸이 남았다');
    // 보통으로 돌려 두기.
    FieldColors.mode.value = FieldViewMode.normal;
  });

  testWidgets('현장 화면 안의 설정 탭은 보통 보기로 남는다', (tester) async {
    FieldColors.mode.value = FieldViewMode.night;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const FieldViewTheme(
          child: NormalViewTheme(child: Scaffold(body: Text('설정 글'))),
        ),
      ),
    );
    final ctx = tester.element(find.text('설정 글'));
    expect(FieldPalette.ofContext(ctx), FieldPalette.normal);
    expect(DefaultTextStyle.of(ctx).style.color, AppColors.text);
    FieldColors.mode.value = FieldViewMode.normal;
  });

  testWidgets('공용 부품은 자리의 보기 색을 따른다(바깥은 보통)', (tester) async {
    Future<Color?> titleColor(Widget Function(Widget c) wrap) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: wrap(const EmptyState(icon: Icons.add, title: '비었음')),
          ),
        ),
      );
      return tester.widget<Text>(find.text('비었음')).style?.color;
    }

    FieldColors.mode.value = FieldViewMode.night;
    expect(await titleColor((c) => c), AppColors.text);
    expect(
      await titleColor((c) => FieldViewTheme(child: c)),
      FieldPalette.night.text,
    );
    FieldColors.mode.value = FieldViewMode.normal;
  });
}
