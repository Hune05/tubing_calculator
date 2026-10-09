// 10-09: 야간 보기에서 현장 탭 아래 단계 띠는 흰 바탕 고정에 밝은 글씨라 숫자가 안 보였다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/theme/field_view.dart';
import 'package:tubing_calculator/src/presentation/field/field_marking.dart';
import 'package:tubing_calculator/src/presentation/field/field_marking_screen.dart';

void main() {
  testWidgets('야간 보기: 단계 띠 칸 바탕이 흰색이 아니다(밝은 글씨가 보인다)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    FieldColors.mode.value = FieldViewMode.night;
    addTearDown(() => FieldColors.mode.value = FieldViewMode.normal);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1006, 600);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: FieldMarkingScreen(
          listenable: ValueNotifier(0),
          compute: () => const FieldMarkingData(
            totalCut: 900,
            marks: [
              FieldMark(number: 1, position: 300, angle: 90, rotation: 0, gap: 300),
              FieldMark(number: 2, position: 600, angle: 90, rotation: 90, gap: 300),
            ],
          ),
          isActive: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final boxes = tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.borderRadius == BorderRadius.circular(10))
        .toList();
    expect(boxes, isNotEmpty);
    for (final d in boxes) {
      expect(d.color, isNot(Colors.white));
    }
  });
}
