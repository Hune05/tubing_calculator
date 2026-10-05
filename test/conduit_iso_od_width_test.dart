// 아이소 3D 그림의 관 굵기가 바깥지름에 비례해 그려지는지(후강 22mm: 호칭 22가 아니라 실제 26.5로 그린다).
// 같은 도면을 외경 22와 26.5로 그려 관 색 픽셀 수를 비교한다.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/main_navigation_page.dart';

void main() {
  testWidgets('관 굵기가 바깥지름에 비례해 그려진다(22 → 26.5는 약 20% 굵게)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(420, 800);
    addTearDown(tester.view.reset);

    final bends = [
      {'length': 400.0, 'angle': 90.0, 'rotation': 0.0},
      {'length': 400.0, 'angle': 0.0, 'rotation': 0.0},
    ];

    Future<int> countNonBackground(double od) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              key: key,
              child: ConduitIsoVisualizer(
                key: ValueKey('od$od'),
                bendList: bends,
                totalCutLength: 800,
                bendRadius: 93,
                outerDiameter: od,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await tester.runAsync(() => boundary.toImage());
      final data = (await tester.runAsync(
        () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
      ))!;
      final bytes = data.buffer.asUint8List();
      // 가장 많은 색 = 배경. 그것과 다른 픽셀 수를 센다(눈금·글자는 두 그림이 같다).
      final counts = <int, int>{};
      for (var i = 0; i < bytes.length; i += 4) {
        final c = (bytes[i] << 16) | (bytes[i + 1] << 8) | bytes[i + 2];
        counts[c] = (counts[c] ?? 0) + 1;
      }
      final bg = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      return bytes.length ~/ 4 - counts[bg]!;
    }

    // 관이 굵어진 만큼만 그림 픽셀이 늘어난다(눈금·글자는 같다). 관 픽셀 수가 외경에 비례하면
    // (44−22)/(26.5−22) = 4.89배로 늘어난다.
    final n22 = await countNonBackground(22.0);
    final n265 = await countNonBackground(26.5);
    final n44 = await countNonBackground(44.0);
    expect(n265, greaterThan(n22));
    final ratio = (n44 - n22) / (n265 - n22);
    expect(ratio, inInclusiveRange(4.0, 6.0));
  });
}
