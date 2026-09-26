// 배치도 전기 부품: 단자대 묶음 폭, 깊이, 카탈로그 값(용성 FT·건흥·하니웰 GCP·문짝 부품), 그려지는지, 폰 "전기" 단추로 놓기.
import 'dart:convert';
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
    // "GCP-33AN … (단종 표기, 어림값)" 하나만 이름에 그 사실을 밝히고 남긴 예외다.
    expect(names.where((n) => n.contains('대략값') || n.contains('추정')), isEmpty);
    expect(kElecPresets.keys.any((k) => k.contains('하이웰')), isFalse);
    // 예전에 놓은 사진 어림 압력 스위치도 그림은 그대로 그려진다.
    final rec = ui.PictureRecorder();
    InstrumentShapePainter(
      shape: ElecShape.pswitch,
    ).paint(Canvas(rec), const Size(92, 92));
    rec.endRecording();
  });

  test('ABB S200 소형 차단기·옴론 소켓 단품·하니웰 GCP-33AN (2026-09-26 추가)', () {
    expect(
      [
        preset('S201 소형 차단기 1P (ABB)').width,
        preset('S202 소형 차단기 2P (ABB)').width,
        preset('S203 소형 차단기 3P (ABB)').width,
      ],
      [17.5, 35, 52.5],
    );
    expect(preset('S201 소형 차단기 1P (ABB)').height, 88);
    expect(preset('S201 소형 차단기 1P (ABB)').depth, 69);
    expect(preset('S203 소형 차단기 3P (ABB)').shape, '${ElecShape.mcb}:3');

    // 소켓 단품은 "릴레이+소켓" 항목과 정면은 같고, 깊이만 소켓 몸통만큼 얕다.
    expect(preset('PYF08A 소켓 단품 (옴론, 8핀)').width, 23);
    expect(preset('PYF08A 소켓 단품 (옴론, 8핀)').height, 72);
    expect(preset('PYF08A 소켓 단품 (옴론, 8핀)').depth, 31);
    expect(
      preset('PYF08A 소켓 단품 (옴론, 8핀)').width,
      preset('MY2N 릴레이+PYF08A 소켓 (옴론)').width,
    );
    expect(
      preset('PYF08A 소켓 단품 (옴론, 8핀)').depth,
      lessThan(preset('MY2N 릴레이+PYF08A 소켓 (옴론)').depth!),
    );
    expect(preset('PYF14A 소켓 단품 (옴론, 14핀)').width, 29.5);

    // GCP-33AN은 이름에 단종·어림값임을 밝혀 뒀다.
    final gcp3 = preset('GCP-33AN 서킷 프로텍터 3P (단종 표기, 어림값)');
    expect(gcp3.width, 52.5);
    expect(gcp3.height, 73);
    expect(gcp3.shape, '${ElecShape.mcb}:3');
  });

  test('슈나이더 Acti9·지멘스 5SY 차단기 (2026-09-26 저녁 추가)', () {
    expect(preset('iC60N 소형 차단기 1P (슈나이더)').width, 18);
    expect(preset('iC60N 소형 차단기 1P (슈나이더)').height, 85);
    expect(preset('iC60N 소형 차단기 1P (슈나이더)').depth, 78.5);
    // 3P+N은 4모듈폭이라 1P와 폭·높이가 다르다(오타가 아니라 실제 그렇다).
    final threeN = preset('iC60N 소형 차단기 3P+N (슈나이더)');
    expect(threeN.width, 72);
    expect(threeN.height, 91);
    expect(threeN.depth, 78.5);

    expect(preset('5SY6 소형 차단기 1P (지멘스)').width, 18);
    expect(preset('5SY6 소형 차단기 1P (지멘스)').height, 90);
    expect(preset('5SY6 소형 차단기 1P (지멘스)').depth, 76);

    // 이번에 안 넣기로 한 항목은 목록에 없다.
    final names = kElecPresets.values.expand((l) => l).map((p) => p.name);
    expect(names.any((n) => n.contains('대륙')), isFalse);
    expect(names.any((n) => n.contains('ABN203')), isFalse);
    expect(names.any((n) => n.contains('ABN403')), isFalse);
  });

  test('성호 SHT-TB 조립식 단자대(15A·25A), CY MAX는 출처 없어 안 넣음', () {
    expect(preset('SHT-TB-15 단자대 15A 10P').width, 85); // 10 × 8.5
    expect(preset('SHT-TB-15 단자대 15A 10P').height, 37.0);
    expect(preset('SHT-TB-15 단자대 15A 10P').depth, 39.0);
    expect(preset('SHT-TB-15 단자대 15A 20P').width, 170);
    expect(preset('SHT-TB-25 단자대 25A 10P').width, 105); // 10 × 10.5
    expect(preset('SHT-TB-25 단자대 25A 20P').width, 210);
    expect(preset('SHT-TB-15 단자대 15A 10P').shape, '${ElecShape.tb}:10');

    final names = kElecPresets.values.expand((l) => l).map((p) => p.name);
    expect(names.any((n) => n.contains('CY') && n.contains('히터')), isFalse);
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

  group('90° 회전(2026-09-26 버그 수정)', () {
    test('단자대·고정식 단자대·DIN 레일은 가로가 긴 모양, 차단기·전원·릴레이는 아니다', () {
      expect(InstrumentShape.isLandscape('${ElecShape.tb}:10'), isTrue);
      expect(InstrumentShape.isLandscape('${ElecShape.ft}:6'), isTrue);
      expect(InstrumentShape.isLandscape(ElecShape.rail), isTrue);
      expect(InstrumentShape.isLandscape('${ElecShape.mcb}:1'), isFalse);
      expect(InstrumentShape.isLandscape('${ElecShape.mcb}:3'), isFalse);
      expect(InstrumentShape.isLandscape(ElecShape.mccb), isFalse);
      expect(InstrumentShape.isLandscape(ElecShape.psu), isFalse);
      expect(InstrumentShape.isLandscape(ElecShape.relay), isFalse);
      expect(InstrumentShape.isLandscape(ElecShape.spd), isFalse);
    });

    test('가로가 긴 단자대는 "이미 90° 돌아간 것"으로 잘못 짐작하지 않는다', () {
      // UK 2.5N 단자대 10P 크기(53.8×42.5, 가로가 긴 실제 모습) 그대로.
      expect(
        InstrumentShape.inferredQuarterTurns(
          '${ElecShape.tb}:10',
          const Size(53.8, 42.5),
        ),
        0,
      );
      // 실제로 한 번 돌려 세로로 선 상태(42.5×53.8)는 1로 본다.
      expect(
        InstrumentShape.inferredQuarterTurns(
          '${ElecShape.tb}:10',
          const Size(42.5, 53.8),
        ),
        1,
      );
    });

    testWidgets('폰: 전기 단추로 새로 놓은 단자대는 각도 칸이 곧바로 0으로 박힌다', (tester) async {
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

      final state = tester.state(find.byType(LayoutBoardPage)) as dynamic;
      final items = (state.debugPlates()['main']!['items'] as List).cast<Map>();
      expect(items.single['rot'], 0);
      expect(items.single['w'], 53.8);
      expect(items.single['h'], 42.5);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('옛 저장 자료(각도 칸 없음)의 단자대를 처음 돌려도 90°만 돌고 찌그러지지 않는다', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'layout_board_onboarding_shown_v1': true,
        'layout_board_draft_v1': jsonEncode({
          'kind': kLayoutKindCabinet,
          'projectName': 'TEST',
          'panelWidth': 600.0,
          'panelHeight': 400.0,
          'items': [
            {
              'type': 'item',
              'id': 'tb1',
              'name': 'UK 2.5N 단자대 10P',
              'x': 100,
              'y': 50,
              'w': 53.8,
              'h': 42.5,
              'shape': '${ElecShape.tb}:10',
              // 'rot' 칸이 아예 없다 — 각도 칸이 생기기 전에 놓았던 부품.
            },
          ],
          'dimensions': <Map<String, dynamic>>[],
        }),
      });
      tester.view.physicalSize = const Size(390, 844) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(
          home: LayoutBoardPage(
            initialKind: kLayoutKindCabinet,
            resumeDraft: true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tb1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('90° 회전'));
      await tester.pumpAndSettle();

      final state = tester.state(find.byType(LayoutBoardPage)) as dynamic;
      final items = (state.debugPlates()['main']!['items'] as List).cast<Map>();
      // 고치기 전에는 180으로 뛰어 42.5×53.8 자리에 53.8×42.5 그림이 눌려 그려졌다.
      expect(items.single['rot'], 90);
      expect(items.single['w'], 42.5);
      expect(items.single['h'], 53.8);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
