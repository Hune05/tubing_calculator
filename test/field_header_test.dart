// 현장 탭 헤더 정리: 누적|간격은 한 덩어리, 햇빛·소리는 "보기" 단추 하나로.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/theme/field_view.dart';
import 'package:tubing_calculator/src/presentation/field/field_marking.dart';
import 'package:tubing_calculator/src/presentation/field/field_marking_screen.dart';

FieldMarkingData data() => const FieldMarkingData(
  totalCut: 900,
  marks: [FieldMark(number: 1, position: 500, angle: 90, rotation: 0, gap: 500)],
);

Future<void> open(WidgetTester tester, {Size size = const Size(1006, 600)}) async {
  SharedPreferences.setMockInitialValues({});
  FieldColors.mode.value = FieldViewMode.normal;
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: FieldMarkingScreen(
        listenable: ValueNotifier(0),
        compute: data,
        isActive: false,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> openMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('field_view_menu')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('헤더에 햇빛·소리 단추가 따로 없고 "보기" 하나뿐이다', (tester) async {
    await open(tester);
    expect(find.byKey(const Key('field_contrast_toggle')), findsNothing);
    expect(find.byKey(const Key('field_sound_toggle')), findsNothing);
    expect(find.byKey(const Key('field_view_menu')), findsOneWidget);
    expect(find.text('보기'), findsOneWidget);
    expect(find.text('햇빛'), findsNothing); // 헤더에는 글자가 안 보인다
    expect(find.text('소리'), findsNothing);
  });

  testWidgets('누적|간격은 한 덩어리 안에 둘 다 있다', (tester) async {
    await open(tester);
    final box = find.byKey(const Key('field_gap_toggle'));
    expect(find.descendant(of: box, matching: find.byKey(const Key('field_cumulative'))), findsOneWidget);
    expect(find.descendant(of: box, matching: find.byKey(const Key('field_gap'))), findsOneWidget);
    // 두 칸이 붙어 있다(한 덩어리 상자 폭 = 두 칸 + 구분선).
    final r = tester.getRect(box);
    expect(r.width, closeTo(54 * 2 + 1 + 2, 2));
  });

  testWidgets('누적↔간격 전환이 그대로 된다', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('field_gap')));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('field_show_gap'), isTrue);
    await tester.tap(find.byKey(const Key('field_cumulative')));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    expect(prefs.getBool('field_show_gap'), isFalse);
  });

  testWidgets('"보기" 창: 보통·햇빛·야간과 소리가 들어 있다', (tester) async {
    await open(tester);
    await openMenu(tester);
    expect(find.byKey(const Key('field_view_normal')), findsOneWidget);
    expect(find.byKey(const Key('field_view_sunlight')), findsOneWidget);
    expect(find.byKey(const Key('field_view_night')), findsOneWidget);
    expect(find.byKey(const Key('field_view_sound')), findsOneWidget);
  });

  testWidgets('"보기" 창에서 야간을 고르면 바로 바뀌고 폰에 기억된다(예전엔 헤더에서 못 골랐다)', (tester) async {
    await open(tester);
    await openMenu(tester);
    await tester.tap(find.byKey(const Key('field_view_night')));
    await tester.pumpAndSettle();
    expect(FieldColors.mode.value, FieldViewMode.night);
    await tester.tap(find.byKey(const Key('field_view_close')));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(FieldColors.prefKey), 'night');
  });

  testWidgets('"보기" 단추는 보통이 아니거나 소리가 켜져 있으면 켜진 모양이다', (tester) async {
    await open(tester);
    bool selected() => tester
        .widget<Semantics>(find.ancestor(
          of: find.byKey(const Key('field_view_menu')),
          matching: find.byType(Semantics),
        ).first)
        .properties
        .selected == true;
    expect(selected(), isFalse);
    await openMenu(tester);
    await tester.tap(find.byKey(const Key('field_view_sunlight')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('field_view_close')));
    await tester.pumpAndSettle();
    expect(selected(), isTrue);
  });

  testWidgets('"보기" 창에서 소리를 켜면 폰에 기억된다', (tester) async {
    await open(tester);
    await openMenu(tester);
    await tester.tap(find.byKey(const Key('field_view_sound')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('field_view_close')));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('field_step_sound'), isTrue);
  });

  testWidgets('헤더 단추가 줄어 좁은 폭에서도 넘치지 않고 닫기가 보인다', (tester) async {
    for (final size in [const Size(344, 700), const Size(600, 1005), const Size(882, 344)]) {
      final errors = <String>[];
      final old = FlutterError.onError;
      FlutterError.onError = (d) => errors.add(d.exceptionAsString());
      await open(tester, size: size);
      FlutterError.onError = old;
      expect(errors, isEmpty, reason: '$size');
      final close = tester.getRect(find.byKey(const Key('field_close')));
      expect(close.right, lessThanOrEqualTo(size.width + 1), reason: '$size');
    }
  });

  testWidgets('한 단계씩 상태에서도 좁은 폭(344)에서 닫기가 보인다', (tester) async {
    final errors = <String>[];
    final old = FlutterError.onError;
    FlutterError.onError = (d) => errors.add(d.exceptionAsString());
    await open(tester, size: const Size(344, 700));
    await tester.tap(find.byKey(const Key('field_mode_toggle')));
    await tester.pumpAndSettle();
    FlutterError.onError = old;
    expect(errors, isEmpty);
    expect(find.text('1/2'), findsOneWidget);
    final close = tester.getRect(find.byKey(const Key('field_close')));
    expect(close.right, lessThanOrEqualTo(345));
  });
}
