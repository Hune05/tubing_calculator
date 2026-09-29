// 눌림 반응: 누르는 동안 작아지고, 떼면 원래 크기로 돌아온다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/core/common_widgets/press_feedback.dart';

void main() {
  testWidgets('누르면 0.97배로 작아졌다가 떼면 돌아온다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: PressFeedback(
            child: SizedBox(
              width: 200,
              height: 100,
              child: ColoredBox(color: Colors.red),
            ),
          ),
        ),
      ),
    );
    double scale() =>
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;
    expect(scale(), 1.0);
    final g = await tester.startGesture(
      tester.getCenter(find.byType(PressFeedback)),
    );
    await tester.pump();
    expect(scale(), 0.97);
    await g.up();
    await tester.pump();
    expect(scale(), 1.0);
  });
}
