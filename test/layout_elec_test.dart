// 배치도 전기 부품: 단자대 묶음 폭, 깊이, 카탈로그 값(용성 FT·건흥·하니웰 GCP·문짝 부품), 그려지는지, 폰 "전기" 단추로 놓기.
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

  test('용성 FT·건흥 KH-6020 고정식 단자대는 카탈로그에 있는 극수만, 길이는 표 값', () {
    final ys = kElecPresets["고정식 단자대 (용성 FT)"]!;
    // 20A는 3·4·6·10·12·15·20P, 30A는 3·4·6·10P만 나온다(5·7·8P 같은 것은 없다).
    expect(
      ys.map((p) => p.name),
      containsAllInOrder([
        'YS FT020-03 단자대 20A 3P',
        'YS FT020-04 단자대 20A 4P',
        'YS FT020-20 단자대 20A 20P',
        'YS FT030-10 단자대 30A 10P',
      ]),
    );
    expect(
      ys.any((p) => p.name.contains(' 5P') || p.name.contains(' 8P')),
      isFalse,
    );
    expect(
      [
        preset('YS FT020-10 단자대 20A 10P').width,
        preset('YS FT020-10 단자대 20A 10P').height,
      ],
      [136, 30.2],
    );
    expect(preset('YS FT020-20 단자대 20A 20P').width, 257);
    expect(preset('YS FT020-04 단자대 20A 4P').depth, 22.9); // H 19 + 커버 3.9
    expect(preset('YS FT030-06 단자대 30A 6P').width, 102.5);
    expect(preset('YS FT020-04 단자대 20A 4P').shape, '${ElecShape.ft}:4');
    // 8P는 건흥 KH-6020-8(L 112)이 있다.
    expect(
      [
        preset('KH-6020-8 단자대 20A 8P').width,
        preset('KH-6020-8 단자대 20A 8P').height,
      ],
      [112, 30],
    );
    // 피닉스 항목은 그대로.
    final phoenix = kElecPresets["단자대 (피닉스)"]!;
    expect(phoenix.any((e) => e.name == 'UK 2.5N 단자대 10P'), isTrue);
    expect(phoenix.any((e) => e.name == 'UK 5-HESI 퓨즈 단자대 5P'), isTrue);
  });

  test('하니웰 GCP 서킷 프로텍터는 데이터시트 크기, 사진 어림 항목은 목록에서 빠졌다', () {
    expect(
      [
        preset('GCP-32AN 서킷 프로텍터 2P').width,
        preset('GCP-32AN 서킷 프로텍터 2P').height,
      ],
      [35, 73],
    );
    expect(preset('GCP-31AN 서킷 프로텍터 1P').width, 17.5);
    expect(preset('GCP-32AN 서킷 프로텍터 2P').depth, 72.5); // 65 + 레일 7.5
    expect(preset('GCP-32AN 서킷 프로텍터 2P').shape, '${ElecShape.mcb}:2');
    final names = kElecPresets.values.expand((l) => l).map((p) => p.name);
    expect(names.any((n) => n.contains('대략값') || n.contains('추정')), isFalse);
    expect(kElecPresets.keys.any((k) => k.contains('하이웰')), isFalse);
    // 예전에 놓은 사진 어림 압력 스위치도 그림은 그대로 그려진다.
    final rec = ui.PictureRecorder();
    InstrumentShapePainter(
      shape: ElecShape.pswitch,
    ).paint(Canvas(rec), const Size(92, 92));
    rec.endRecording();
  });

  test('용성 문짝 부품: 정면은 베젤 지름, 깊이는 패널 뒤', () {
    expect(
      [preset('APL22 표시등 Ø22').width, preset('APL22 표시등 Ø22').depth],
      [31, 71],
    );
    expect(preset('EP22 비상 누름버튼 Ø22').width, 40.3);
    expect(preset('PL3 표시등 Ø30').width, 34);
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

  testWidgets('폰: 전기 단추 시트에서 용성 고정식 단자대가 놓인다', (tester) async {
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
    const name = 'YS FT020-10 단자대 20A 10P';
    await tester.scrollUntilVisible(
      find.text(name),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(find.text(name));
    await tester.pumpAndSettle();
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(InteractiveViewer),
        matching: find.textContaining(name),
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
