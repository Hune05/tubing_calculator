// 그림 설명 칸은 폰에서는 그대로, 태블릿(짧은 변 600dp 이상)에서만 1.3배로 커진다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/angle_match_guide.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/offset_guide.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/quick_u_bend_guide.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/rolling_offset_guide.dart';
import 'package:tubing_calculator/src/presentation/common/guide_paint_kit.dart';

Future<double> heightOf(WidgetTester tester, Size size, Widget guide) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: guide)),
    ),
  );
  await tester.pump();
  return tester.getSize(find.byType(guide.runtimeType)).height;
}

void main() {
  const phone = Size(360, 780);
  const tablet = Size(800, 1280);
  const offset = OffsetGuide(heightMm: 100, runMm: 173, travelMm: 200, shrinkMm: 27, angleDeg: 30);
  const rolling = RollingOffsetGuide(rise: 150, roll: 200, trueOffset: 250, rollAngle: 53, bendAngle: 45);
  const match = AngleMatchGuide(angle: 31.8, riseLabel: '100mm', travelLabel: '190mm', runLabel: '161mm', angleLabel: '31.8°');
  const ubend = QuickUBendGuide(startMm: 300, returnMm: 300, cToCWidthMm: 80, apexMm: 340);

  testWidgets('폰: 기본 높이 그대로', (tester) async {
    expect(await heightOf(tester, phone, offset), 172);
    expect(await heightOf(tester, phone, rolling), 272);
    expect(await heightOf(tester, phone, match), 188);
    expect(await heightOf(tester, phone, ubend), 204);
  });

  testWidgets('태블릿: 1.3배', (tester) async {
    expect(await heightOf(tester, tablet, offset), closeTo(172 * kTabletGuideScale, 0.01));
    expect(await heightOf(tester, tablet, rolling), closeTo(272 * kTabletGuideScale, 0.01));
    expect(await heightOf(tester, tablet, match), closeTo(188 * kTabletGuideScale, 0.01));
    expect(await heightOf(tester, tablet, ubend), closeTo(204 * kTabletGuideScale, 0.01));
  });

  testWidgets('폭 600 경계: 짧은 변 600이면 태블릿, 599면 폰', (tester) async {
    expect(await heightOf(tester, const Size(600, 900), offset), closeTo(172 * kTabletGuideScale, 0.01));
    expect(await heightOf(tester, const Size(599, 900), offset), 172);
  });
}
