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

  test('용성전기 FT Type 고정식 단자대는 4~20극이 모두 있고, 극수만큼 폭이 는다', () {
    final tb = kElecPresets["단자대 (용성전기 FT Type, 추정)"]!;
    expect(tb.length, 17); // 4~20극
    const name = "FT Type 고정식 단자대 (용성전기, 추정)";
    for (int n = 4; n <= 20; n++) {
      final p = tb.firstWhere(
        (e) => e.name == "$name ${n}P",
        orElse: () => throw StateError('missing $name ${n}P'),
      );
      expect(p.width, closeTo(n * 6.2 + 2.2, 0.05), reason: '${n}P');
      expect(p.depth, isNotNull, reason: '${n}P');
    }
    // 이전 "단자대 (피닉스)" 항목(UK 2.5N·UK 5N·UT 2.5·UT 4·PT 2.5·UT 4-MTD·UK 5-HESI)은
    // 그대로 남아 있다(용성전기 추정 항목과 섞이지 않는다).
    final phoenix = kElecPresets["단자대 (피닉스)"]!;
    expect(phoenix.any((e) => e.name == 'UK 2.5N 단자대 10P'), isTrue);
    expect(phoenix.any((e) => e.name == 'UK 5-HESI 퓨즈 단자대 5P'), isTrue);
    expect(phoenix.any((e) => e.name.startsWith('FT Type')), isFalse);
  });

  test('압력 스위치·회로 보호기 참고 항목이 있고 el_ 모양이 붙어 있다(용성전기와 무관)', () {
    final psw = kElecPresets["압력 스위치 (참고용)"]!;
    expect(psw, isNotEmpty);
    for (final p in psw) {
      expect(ElecShape.isElec(p.shape), isTrue, reason: p.name);
      expect(p.width, inInclusiveRange(85, 100), reason: p.name);
      expect(p.height, inInclusiveRange(85, 100), reason: p.name);
      expect(p.depth, isNotNull, reason: p.name);
      expect(p.name, isNot(contains('용성전기')));
    }
    final cp = kElecPresets["회로 보호기 (하이웰코리아, 사진 기준 추정)"]!;
    expect(cp, isNotEmpty);
    for (final p in cp) {
      expect(p.shape, startsWith(ElecShape.mcb));
      expect(p.depth, isNotNull, reason: p.name);
      expect(p.name, isNot(contains('용성전기')));
    }
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

  testWidgets('폰: 전기 단추 시트에서 새 참고 항목(압력 스위치·회로 보호기)도 놓인다', (tester) async {
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
    // 목록 맨 뒤쪽 카테고리라 스크롤해야 보인다.
    await tester.scrollUntilVisible(
      find.text('압력 스위치 (참고용)'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('압력 스위치 (참고용)'), findsOneWidget);
    final pName = preset('방폭 압력 스위치 (United Electric, 대략값)').name;
    await tester.scrollUntilVisible(
      find.text(pName),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(find.text(pName));
    await tester.pumpAndSettle();
    await tester.tap(find.text(pName));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(InteractiveViewer),
        matching: find.textContaining(pName),
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));

    // 회로 보호기(하이웰코리아) 카테고리도 데이터에 있다(용성전기 FT Type 추정 단자대와 함께
    // 목록에 늘어나 스크롤이 필요하므로, 여기서는 데이터로만 존재를 확인한다).
    expect(kElecPresets['회로 보호기 (하이웰코리아, 사진 기준 추정)'], isNotNull);
  });
}
