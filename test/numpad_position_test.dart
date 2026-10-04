// 숫자판은 화면 아래에 붙어 위쪽 그림 설명을 가리지 않는다(특수 벤딩 시트마다 위에 그림이 있다).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/angle_match_guide.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/makita_numpad_glass.dart';
import 'package:tubing_calculator/src/presentation/conduit/widgets/angle_matcher_sheet.dart';

Future<void> open(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const Key('open'),
              onPressed: () => AngleMatcherSheet.show(context),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
}

void main() {
  test('숫자판 높이는 화면의 44%, 380~440 사이', () {
    expect(numpadHeightFor(2000), 440);
    expect(numpadHeightFor(900), closeTo(396, 1e-9));
    expect(numpadHeightFor(600), 380);
  });

  for (final size in [const Size(360, 780), const Size(412, 915), const Size(800, 1280)]) {
    testWidgets('${size.width.toInt()}×${size.height.toInt()}: 숫자판이 그림 아래에서 시작하고 화면 아래에 붙는다', (tester) async {
      await open(tester, size);
      final guideBottom = tester.getRect(find.byType(AngleMatchGuide)).bottom;
      await tester.tap(find.byKey(const Key('am_rise')));
      await tester.pumpAndSettle();
      final pad = tester.getRect(find.byType(MakitaNumpadGlass));
      expect(pad.top, greaterThanOrEqualTo(guideBottom - 0.5), reason: '숫자판이 그림을 가린다');
      expect(pad.bottom, greaterThan(size.height - 60), reason: '숫자판이 화면 아래에 붙지 않았다');
      expect(pad.bottom, lessThanOrEqualTo(size.height));
      expect(tester.takeException(), isNull);
    });
  }
}
