// 배치도 전기 부품: 단자대 묶음 폭, 깊이, 모두 그려지는지, 폰 "전기" 단추로 놓기.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/layout_board_page.dart';

ModulePreset preset(String n) =>
    kElecPresets.values.expand((l) => l).firstWhere((p) => p.name == n);

void main() {
  test('단자대 묶음 폭 = 극 수 × 한 극 폭 + 끝판, 깊이는 제조사 값', () {
    expect(preset('UK 2.5N 단자대 10P').width, 53.8); // 10 × 5.2 + 1.8
    expect(preset('UT 4 단자대 10P').width, 64.2); // 10 × 6.2 + 2.2
    expect(preset('BKN 소형 차단기 3P').width, 53.4);
    expect(preset('UK 2.5N 단자대 10P').depth, 47);
    expect(preset('DR-60-24 전원 (민웰)').depth, 63.5);
  });

  test('전기 부품은 모두 크기가 있고 원래 크기·작은 그림으로 그려진다', () {
    final names = <String>{};
    for (final p in kElecPresets.values.expand((l) => l)) {
      expect(names.add(p.name), isTrue, reason: p.name);
      expect(p.depth, isNotNull, reason: p.name);
      for (final s in [Size(p.width, p.height), const Size(40, 40)]) {
        final rec = ui.PictureRecorder();
        InstrumentShapePainter(shape: p.shape!).paint(Canvas(rec), s);
        rec.endRecording();
      }
    }
  });

  testWidgets('폰: 전기 단추로 단자대를 놓으면 깊이가 붙는다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'layout_board_onboarding_shown_v1': true,
    });
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: LayoutBoardPage()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('elec_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('elec_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('UK 2.5N 단자대 10P'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(InteractiveViewer),
        matching: find.textContaining('UK 2.5N 단자대 10P'),
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
