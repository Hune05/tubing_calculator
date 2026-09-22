// 카톡으로 받은 도면 밑그림: 모서리 두 곳 + 실제 가로·세로로 도면을 실제 mm에 맞춰 깐다.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/drawing_scale.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/drawing_scale_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/layout_board_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/widgets/korean_text.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/widgets/shared_drawing_sheet.dart';

void main() {
  test('모서리 두 곳과 실제 크기로 사진 자리(mm)를 정한다', () {
    // 사진 1000×600 px, 판이 (100,50)~(900,450) px에 찍혔고 실제 2400×1200 mm.
    final r = drawingRectFromCorners(
      topLeft: const Offset(100, 50),
      bottomRight: const Offset(900, 450),
      image: const Size(1000, 600),
      widthMm: 2400,
      heightMm: 1200,
    )!;
    // 가로 3 mm/px, 세로 3 mm/px.
    expect(r.left, -300);
    expect(r.top, -150);
    expect(r.width, 3000);
    expect(r.height, 1800);
    // 판 모서리 px를 mm로 옮기면 (0,0), (2400,1200)이 된다.
    Offset toMm(Offset px) =>
        Offset(r.left + px.dx * r.width / 1000, r.top + px.dy * r.height / 600);
    expect(toMm(const Offset(100, 50)), Offset.zero);
    expect(toMm(const Offset(900, 450)), const Offset(2400, 1200));
  });

  test('비스듬한 사진: 가로·세로 배율을 따로 잡는다, 거꾸로 찍으면 null', () {
    final r = drawingRectFromCorners(
      topLeft: Offset.zero,
      bottomRight: const Offset(400, 100),
      image: const Size(400, 100),
      widthMm: 800,
      heightMm: 600,
    )!;
    expect(r.width, 800);
    expect(r.height, 600);
    expect(
      drawingRectFromCorners(
        topLeft: const Offset(400, 100),
        bottomRight: Offset.zero,
        image: const Size(400, 100),
        widthMm: 800,
        heightMm: 600,
      ),
      isNull,
    );
  });

  test('저장 칸은 [l,t,w,h], 없거나 틀리면 null', () {
    const r = Rect.fromLTWH(-10, 20, 300, 400);
    expect(drawingRectFromJson(drawingRectToJson(r)), r);
    expect(drawingRectFromJson(null), isNull);
    expect(drawingRectFromJson([1, 2, 3]), isNull);
    expect(drawingRectFromJson([1, 2, 0, 4]), isNull);
  });

  testWidgets('축척 맞추기 화면: 왼쪽 위·오른쪽 아래를 찍고 크기를 넣으면 자리를 돌려준다', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    DrawingScaleResult? got;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                got = await Navigator.of(context).push<DrawingScaleResult>(
                  MaterialPageRoute(
                    builder: (_) => const DrawingScalePage(
                      imagePath: 'no_such_file.png',
                      initialWidthMm: 600,
                      initialHeightMm: 800,
                      targetName: '스키드',
                      imageSize: Size(1000, 500),
                    ),
                  ),
                );
              },
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.text(keepWords('도면에서 스키드 왼쪽 위 모서리를 누르십시오.')), findsOneWidget);

    final img = find.byKey(const ValueKey('scale_image'));
    final Rect box = tester.getRect(img);
    final double k = box.width / 1000;
    // 사진 (100,50) px, (900,450) px 자리를 누른다.
    await tester.tapAt(box.topLeft + const Offset(100, 50) * k);
    await tester.pumpAndSettle();
    expect(find.text(keepWords('이제 스키드 오른쪽 아래 모서리를 누르십시오.')), findsOneWidget);
    await tester.tapAt(box.topLeft + const Offset(900, 450) * k);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('scale_width')), '2400');
    await tester.enterText(find.byKey(const ValueKey('scale_height')), '1200');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('scale_apply')));
    await tester.pumpAndSettle();

    expect(got, isNotNull);
    expect(got!.widthMm, 2400);
    expect(got!.heightMm, 1200);
    expect(got!.rect.left, closeTo(-300, 1));
    expect(got!.rect.top, closeTo(-150, 1));
    expect(got!.rect.width, closeTo(3000, 3));
    expect(got!.rect.height, closeTo(1500, 3));
  });

  testWidgets('공유로 받은 도면: 새 스키드로 열면 묻지 않고 배경에 깔고 축척 맞추기를 띄운다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'layout_board_onboarding_shown_v1': true,
      'layout_board_draft_v1': jsonEncode({'panelWidth': 600, 'items': []}),
    });
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: LayoutBoardPage(
          initialKind: kLayoutKindSkid,
          sharedDrawingPath: 'no_such_drawing.png',
          resumeDraft: false,
        ),
      ),
    );
    // 사진을 읽는 동안 도는 표시가 있어 pumpAndSettle 대신 시간만 흘린다.
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('이어서 작업하시겠습니까?'), findsNothing);
    expect(find.byType(DrawingScalePage), findsOneWidget);
    expect(find.text('축척 맞추기'), findsOneWidget);
  });

  testWidgets('축척을 맞춘 배경은 그 자리(mm)에 깔리고, 임시 저장했다 열어도 남는다', (tester) async {
    final String path = (await tester.runAsync(() async {
      final f = File(
        '${Directory.systemTemp.path}/layout_scale_test_${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await f.writeAsBytes(const [0x89, 0x50, 0x4E, 0x47]);
      return f.path;
    }))!;
    SharedPreferences.setMockInitialValues({
      'layout_board_onboarding_shown_v1': true,
      'layout_board_draft_v1': jsonEncode({
        'panelWidth': 2400,
        'panelHeight': 1200,
        'kind': kLayoutKindSkid,
        'items': [],
        'backgroundImagePath': path,
        'backgroundRect': [-300, -150, 3000, 1800],
      }),
    });
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: LayoutBoardPage(initialKind: kLayoutKindSkid, resumeDraft: true),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    final bg = tester.widget<Positioned>(
      find.byKey(const ValueKey('board_background')),
    );
    expect(bg.left, -300);
    expect(bg.top, -150);
    expect(bg.width, 3000);
    expect(bg.height, 1800);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(prefs.getString('layout_board_draft_v1')!) as Map;
    expect(saved['backgroundRect'], [-300, -150, 3000, 1800]);
    await tester.runAsync(() => File(path).delete());
  });
  testWidgets('받은 도면 창: 이어서 하던 배치도는 임시 저장이 있을 때만, 고르면 그 배치도가 열린다', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    Future<void> open() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => openSharedDrawing(context, 'no_such.png'),
                child: const Text('받기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('받기'));
      await tester.pumpAndSettle();
    }

    SharedPreferences.setMockInitialValues({});
    await open();
    expect(find.text('받은 도면을 어느 배치도에 깔겠습니까?'), findsOneWidget);
    expect(find.byKey(const ValueKey('shared_to_cabinet')), findsOneWidget);
    expect(find.byKey(const ValueKey('shared_to_skid')), findsOneWidget);
    expect(find.byKey(const ValueKey('shared_to_draft')), findsNothing);

    SharedPreferences.setMockInitialValues({
      'layout_board_onboarding_shown_v1': true,
      'layout_board_draft_v1': jsonEncode({'panelWidth': 600, 'items': []}),
    });
    await tester.pumpWidget(const SizedBox());
    await open();
    expect(find.byKey(const ValueKey('shared_to_draft')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('shared_to_skid')));
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final page = tester.widget<LayoutBoardPage>(
      find.byType(LayoutBoardPage, skipOffstage: false),
    );
    expect(page.initialKind, kLayoutKindSkid);
    expect(page.resumeDraft, isFalse);
    expect(page.sharedDrawingPath, 'no_such.png');
    expect(find.byType(DrawingScalePage), findsOneWidget);
  });
}
