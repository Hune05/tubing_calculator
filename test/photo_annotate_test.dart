// 사진 표시하기: 새로 넣은 도구(직선·사각형·글자)와 굵기·색이 그려지고, 되돌리면 빠지는지.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/photo_annotate_page.dart';

// 1x1 흰 점 PNG
const _png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

Future<String> _photo() async {
  final f = File('${Directory.systemTemp.path}/annot_test_photo.png');
  await f.writeAsBytes(base64Decode(_png));
  return f.path;
}

AnnotationPainter _painter(WidgetTester tester) {
  final cp = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byKey(const Key('annotate_canvas')),
      matching: find.byType(CustomPaint),
    ),
  );
  return cp.painter! as AnnotationPainter;
}

Future<void> _open(WidgetTester tester, {String? text}) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final path = await tester.runAsync(_photo);
  await tester.pumpWidget(
    MaterialApp(
      home: PhotoAnnotatePage(
        path: path!,
        askText: (_) async => text,
        loader: (p) => File(p).readAsBytes(),
      ),
    ),
  );
  // 사진을 읽어 들이는 동안 기다린다.
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    if (find.byKey(const Key('annotate_canvas')).evaluate().isNotEmpty) break;
  }
}

Future<void> _drag(WidgetTester tester, Offset from, Offset to) async {
  final g = await tester.startGesture(from);
  await g.moveBy((to - from) * 0.5);
  await g.moveBy((to - from) * 0.5);
  await g.up();
  await tester.pump();
}

void main() {
  testWidgets('도구 여섯 가지와 굵기 세 가지가 보인다', (tester) async {
    await _open(tester);
    for (final n in ['arrow', 'line', 'rect', 'circle', 'pen', 'text']) {
      expect(find.byKey(Key('annotate_tool_$n')), findsOneWidget);
    }
    for (var i = 0; i < 3; i++) {
      expect(find.byKey(Key('annotate_thick_$i')), findsOneWidget);
    }
  });

  testWidgets('직선·사각형을 끌어서 그리고, 되돌리면 빠진다', (tester) async {
    await _open(tester);
    final c = tester.getCenter(find.byKey(const Key('annotate_canvas')));
    await tester.tap(find.byKey(const Key('annotate_tool_line')));
    await tester.pump();
    await _drag(tester, c - const Offset(50, 0), c + const Offset(50, 0));
    await tester.tap(find.byKey(const Key('annotate_tool_rect')));
    await tester.pump();
    await _drag(tester, c - const Offset(40, 40), c + const Offset(40, 40));
    var shapes = _painter(tester).shapes;
    expect(shapes.map((s) => s.tool), [AnnotateTool.line, AnnotateTool.rect]);

    await tester.tap(find.byTooltip('되돌리기'));
    await tester.pump();
    shapes = _painter(tester).shapes;
    expect(shapes.map((s) => s.tool), [AnnotateTool.line]);
  });

  testWidgets('굵기를 바꾸면 그 굵기로 그려진다', (tester) async {
    await _open(tester);
    final c = tester.getCenter(find.byKey(const Key('annotate_canvas')));
    await tester.tap(find.byKey(const Key('annotate_thick_2')));
    await tester.pump();
    await _drag(tester, c - const Offset(30, 0), c + const Offset(30, 0));
    expect(_painter(tester).shapes.single.thickness, 1.8);
  });

  testWidgets('글자 도구: 누른 자리에 글자가 들어가고, 빈 글은 무시한다', (tester) async {
    await _open(tester, text: '150mm');
    await tester.tap(find.byKey(const Key('annotate_tool_text')));
    await tester.pump();
    await tester.tapAt(
      tester.getCenter(find.byKey(const Key('annotate_canvas'))),
    );
    await tester.pump();
    final shapes = _painter(tester).shapes;
    expect(shapes.single.tool, AnnotateTool.text);
    expect(shapes.single.text, '150mm');
    expect(shapes.single.pts.single.dx, closeTo(0.5, 0.05));
  });

  testWidgets('글자를 안 적으면 아무것도 안 들어간다', (tester) async {
    await _open(tester, text: '  ');
    await tester.tap(find.byKey(const Key('annotate_tool_text')));
    await tester.pump();
    await tester.tapAt(
      tester.getCenter(find.byKey(const Key('annotate_canvas'))),
    );
    await tester.pump();
    expect(_painter(tester).shapes, isEmpty);
  });
}
