// 현장 자료·장비 사용법 화면: 탭 5개가 좁은 폰·글자 크게에서 넘치지 않고,
// 표 숫자가 계산기 자료(FittingData)와 같다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/core/utils/fitting_data.dart';
import 'package:tubing_calculator/src/presentation/reference/page/reference_widgets.dart';
import 'package:tubing_calculator/src/presentation/reference/page/tube_reference_page.dart';

const List<(Size, double)> kCases = [
  (Size(320, 568), 1.0),
  (Size(344, 760), 1.3),
  (Size(390, 844), 1.0),
];

Widget app(Widget home, double scale) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: home,
);

void main() {
  test('refNum: 끝의 0을 뗀다', () {
    expect(refNum(12.70, 2), '12.7');
    expect(refNum(38.0), '38');
    expect(refNum(23.8), '23.8');
  });

  for (final (size, scale) in kCases) {
    final String tag = '${size.width.toInt()}x${size.height.toInt()} ×$scale';

    testWidgets('$tag: 다섯 탭이 넘치지 않고 표가 자료값을 보여 준다', (tester) async {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(const TubeReferencePage(), scale));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // 튜브 탭: 3/8" 반경이 계산기 자료값(23.8)으로 나온다.
      final sp = FittingData.getBenderSpec('Swagelok', '0.375')!;
      expect(find.text(refNum(sp.bendRadius)), findsWidgets);

      for (final name in const ['전선관', '형강', '장비 사용법', '앱 사용법']) {
        await tester.tap(find.text(name));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: name);
        // 긴 탭은 끝까지 넘겨 본다.
        final list = find.byType(ListView).last;
        for (var i = 0; i < 12; i++) {
          await tester.drag(list, const Offset(0, -1500));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: '$name 스크롤 $i');
        }
      }
    });
  }

  testWidgets('형강 탭: 규격 카드를 펴면 무게 표가 나온다', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(const TubeReferencePage(), 1.0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('형강'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('앵글'),
      find.byType(ListView).last,
      const Offset(0, -300),
    );
    await tester.tap(find.text('앵글'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('40x40x3'), findsOneWidget);
  });
}
