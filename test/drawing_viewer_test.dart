// 도면 보기: DXF 읽기, 표시 자료, 보관함 가져오기, 보기 화면에서 체크·문제 목록.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/drawing_viewer/drawing_export.dart';
import 'package:tubing_calculator/src/presentation/drawing_viewer/drawing_library_page.dart';
import 'package:tubing_calculator/src/presentation/drawing_viewer/drawing_mark_painter.dart';
import 'package:tubing_calculator/src/presentation/drawing_viewer/drawing_models.dart';
import 'package:tubing_calculator/src/presentation/drawing_viewer/drawing_store.dart';
import 'package:tubing_calculator/src/presentation/drawing_viewer/drawing_viewer_page.dart';
import 'package:tubing_calculator/src/presentation/drawing_viewer/dxf_reader.dart';
import 'package:tubing_calculator/src/presentation/trash/trash_kinds.dart';

String _dxf(List<String> pairs) => '${pairs.join('\n')}\n';

final String _sample = _dxf([
  '0', 'SECTION', '2', 'TABLES',
  '0', 'LAYER', '2', 'WALL', '62', '1',
  '0', 'LAYER', '2', 'HIDE', '62', '-3',
  '0', 'ENDSEC',
  '0', 'SECTION', '2', 'BLOCKS',
  '0', 'BLOCK', '2', 'BOX', '10', '0', '20', '0',
  '0', 'LINE', '8', '0', '10', '0', '20', '0', '11', '10', '21', '0',
  '0', 'ENDBLK',
  '0', 'ENDSEC',
  '0', 'SECTION', '2', 'ENTITIES',
  '0', 'LINE', '8', 'WALL', '10', '0', '20', '0', '11', '100', '21', '0',
  '0', 'LINE', '8', 'HIDE', '10', '0', '20', '0', '11', '999', '21', '999',
  '0', 'LWPOLYLINE', '8', '0', '62', '5', '90', '2', '70', '0', '10', '0', '20', '10', '42', '1', '10', '20', '20', '10',
  '0', 'CIRCLE', '8', '0', '10', '50', '20', '50', '40', '10',
  '0', 'ARC', '8', '0', '10', '0', '20', '0', '40', '5', '50', '0', '51', '90',
  '0', 'TEXT', '8', '0', '10', '5', '20', '5', '40', '2.5', '1', '%%c20 PIPE',
  '0', 'MTEXT', '8', '0', '10', '5', '20', '30', '40', '3', '1', '{\\fArial;첫줄}\\P둘째줄',
  '0', 'INSERT', '8', '0', '2', 'BOX', '10', '200', '20', '0', '41', '2', '42', '2', '50', '90',
  '0', 'HATCH', '8', '0',
  '0', 'ENDSEC',
  '0', 'EOF',
]);

void main() {
  group('DXF 읽기', () {
    test('선·폴리선(볼록)·원·호·글자·블록을 읽고, 꺼진 층은 뺀다', () {
      final d = readDxf(_sample);
      // LINE(WALL) + LWPOLYLINE + CIRCLE + ARC + INSERT 안 LINE = 5, HIDE 층은 빠짐
      expect(d.paths.length, 5);
      expect(d.paths.first.color, aciColor(1)); // BYLAYER → WALL 층 빨강
      expect(d.paths[1].color, aciColor(5));
      // 볼록 1 = 반원: 가운데 점이 (10, 20)쯤까지 올라간다(시계 반대로 위)
      final poly = d.paths[1].points;
      expect(poly.length, greaterThan(5));
      final top = poly.map((p) => p.$2).reduce((a, b) => a > b ? a : b);
      final bottom = poly.map((p) => p.$2).reduce((a, b) => a < b ? a : b);
      expect(top - bottom, closeTo(10, 0.2));
      // 블록: (0,0)-(10,0) 선을 2배·90도 돌려 (200,0)에 → (200,0)-(200,20)
      final ins = d.paths.last.points;
      expect(ins.first.$1, closeTo(200, 1e-9));
      expect(ins.last.$1, closeTo(200, 1e-6));
      expect(ins.last.$2, closeTo(20, 1e-6));
      // 글자
      expect(d.texts.map((t) => t.text), containsAll(['Ø20 PIPE', '첫줄\n둘째줄']));
      expect(d.skipped, 1); // HATCH
      expect(d.minX, closeTo(-0.0, 1e-9));
      expect(d.maxX, closeTo(200, 1e-6));
      expect(d.maxY, greaterThanOrEqualTo(60));
    });

    test('글자 코드와 서식을 걷어낸다', () {
      expect(cleanDxfText(r'\U+D55C\U+AE00'), '한글');
      expect(cleanDxfText(r'{\H2.5;\C1;밸브}\P%%d45'), '밸브\n°45');
      expect(cleanDxfText(r'1\S1^2;"'), '11/2"');
    });

    test('DXF가 아니거나 이진 DXF면 알려 준다', () {
      expect(() => readDxf('hello\nworld\n'), throwsA(isA<DxfError>()));
      expect(() => readDxf('AutoCAD Binary DXF\r\n'), throwsA(isA<DxfError>()));
    });
  });

  group('표시 자료', () {
    test('저장했다 읽어도 같고, 문제 번호·목록·글이 맞다', () {
      final at = DateTime(2026, 10, 1, 9, 30);
      final a = DrawingMark(id: '1', page: 0, kind: MarkKind.wrong, color: MarkColor.red, points: const [(0.25, 0.5)], text: '사이즈 틀림', no: 1, author: '김', createdAt: at, history: [MarkEvent(at, '만듦', '김')]);
      final b = DrawingMark(id: '2', page: 1, kind: MarkKind.question, color: MarkColor.blue, points: const [(0.5, 0.5)], no: 2, done: true, createdAt: at);
      final c = DrawingMark(id: '3', page: 0, kind: MarkKind.ok, color: MarkColor.green, points: const [(0.1, 0.1)], createdAt: at);
      final back = DrawingMark.fromJson(a.toJson());
      expect(back.points.single, (0.25, 0.5));
      expect(back.history.single.what, '만듦');
      // 예전에 '다시 남음'으로 저장한 기록은 '해결 취소'로 읽는다(10-03 문구 통일).
      expect(MarkEvent.fromJson({'at': at.toIso8601String(), 'what': '다시 남음', 'who': '김'}).what, '해결 취소');
      expect(nextIssueNo([a, b, c]), 3);
      expect(issuesOf([c, b, a]).map((m) => m.id), ['1', '2']);
      expect(openIssueCount([a, b, c]), 1);
      final doc = DrawingDoc(id: 'd', name: 'P-101.pdf', kind: DrawingKind.pdf, ext: 'pdf', pages: 2, pageSizes: const [(4000, 2828), (4000, 2828)], addedAt: at, openedAt: at, drawingNo: 'P-101', rev: 'B');
      final t = buildIssueText(doc, [a, b, c]);
      expect(t, contains('도번 P-101 · REV B'));
      expect(t, contains('문제 2건 (남은 것 1건)'));
      expect(t, contains('1. [틀림] 1쪽 사이즈 틀림'));
      expect(t, contains('2. [질문·해결] 2쪽'));
      expect(t, contains('확인 표시 1곳'));
      expect(DrawingDoc.fromJson(doc.toJson()).rev, 'B');
    });

    test('파일 종류: PDF·사진·DXF는 열고, DWG는 안내', () {
      expect(kindForName('a.PDF'), DrawingKind.pdf);
      expect(kindForName('b.jpeg'), DrawingKind.image);
      expect(kindForName('c.dxf'), DrawingKind.dxf);
      expect(kindForName('d.dwg'), isNull);
      expect(isDwgName('d.DWG'), isTrue);
      expect(kindForName('e.xlsx'), isNull);
    });

    test('누른 자리의 표시를 찾는다', () {
      final m = DrawingMark(id: '1', page: 0, kind: MarkKind.ok, color: MarkColor.green, points: const [(0.5, 0.5)], createdAt: DateTime(2026));
      const size = Size(1000, 700);
      expect(hitMark([m], 0, const Offset(500, 350), size)?.id, '1');
      expect(hitMark([m], 0, const Offset(100, 100), size), isNull);
      expect(hitMark([m], 1, const Offset(500, 350), size), isNull);
    });
  });

  group('보관함', () {
    late Directory tmp;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tmp = await Directory.systemTemp.createTemp('drawings_test');
      DrawingStore.baseDir = () async => Directory('${tmp.path}/drawings');
    });
    tearDown(() async {
      try {
        await tmp.delete(recursive: true);
      } catch (_) {}
    });

    testWidgets('DXF를 가져오면 원본을 복사해 두고 쪽 그림·작은 그림을 만든다, DWG는 안내', (tester) async {
      await tester.runAsync(() async {
        final src = File('${tmp.path}/plan.dxf')..writeAsStringSync(_sample);
        final doc = await DrawingStore.importFile(src.path, now: DateTime(2026, 10, 1, 10));
        expect(doc.kind, DrawingKind.dxf);
        expect(doc.pages, 1);
        expect(doc.pageSizes.single.$1, kPageLongSide);
        expect(File(await DrawingStore.originalPath(doc)).readAsStringSync(), _sample);
        expect(File(await DrawingStore.pagePath(doc.id, 0)).existsSync(), isTrue);
        expect((await DrawingStore.load()).single.name, 'plan.dxf');

        final m = DrawingMark(id: '1', page: 0, kind: MarkKind.issue, color: MarkColor.red, points: const [(0.5, 0.5)], no: 1, createdAt: DateTime(2026));
        await DrawingStore.saveMarks(doc, [m]);
        expect((await DrawingStore.loadMarks(doc.id)).single.no, 1);
        expect((await DrawingStore.load()).single.openIssues, 1);

        // 사진(현장 사진·찍은 도면)도 같은 보기로
        final png = await renderDxfPng(readDxf(_sample), longSide: 800);
        final photo = File('${tmp.path}/site.png')..writeAsBytesSync(png.$1);
        final pdoc = await DrawingStore.importFile(photo.path, now: DateTime(2026, 10, 1, 10, 5));
        expect(pdoc.kind, DrawingKind.image);
        expect(pdoc.pageSizes.single, (png.$2, png.$3));
        expect(File(await DrawingStore.thumbPath(pdoc.id)).existsSync(), isTrue);
        await DrawingStore.delete(pdoc.id);

        final dwg = File('${tmp.path}/a.dwg')..writeAsStringSync('AC1032');
        await expectLater(DrawingStore.importFile(dwg.path), throwsA(isA<DxfError>()));

        // 표시한 PDF: 도면 쪽 + 문제 목록
        final pdf = await buildMarkedPdf(doc: doc, marks: [m], pagePath: (p) => DrawingStore.pagePath(doc.id, p), now: DateTime(2026, 10, 1, 11), author: '홍길동');
        expect(String.fromCharCodes(pdf.take(4)), '%PDF');
        expect(pdf.length, greaterThan(20000));

        await DrawingStore.delete(doc.id);
        expect(await DrawingStore.load(), isEmpty);
      });
    });

    testWidgets('도면 줄은 휴지통 단추 없이 밀어서 휴지통으로, 되돌리기로 파일까지 돌아온다', (tester) async {
      late DrawingDoc doc;
      await tester.runAsync(() async {
        final src = File('${tmp.path}/plan.dxf')..writeAsStringSync(_sample);
        doc = await DrawingStore.importFile(src.path, now: DateTime(2026, 10, 1, 10));
      });
      await tester.pumpWidget(const MaterialApp(home: DrawingLibraryPage()));
      // 보관함은 폰 파일을 읽으므로 실제 시간을 조금씩 흘려 가며 목록이 뜰 때까지 기다린다.
      Future<void> settleFiles() async {
        for (var i = 0; i < 20; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
          await tester.pump();
        }
      }

      await settleFiles();
      final row = find.byKey(Key('dl_doc_${doc.id}'));
      expect(row, findsOneWidget);
      expect(find.byKey(Key('dl_del_${doc.id}')), findsNothing);

      // 밀면 묻지 않고 휴지통으로 간다(파일은 휴지통 폴더로).
      await tester.drag(row, const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(row, findsNothing);
      expect(find.textContaining('휴지통으로 옮겼습니다'), findsOneWidget);
      await settleFiles();
      await tester.runAsync(() async {
        expect(await DrawingStore.load(), isEmpty);
        expect((await loadTrash()).single.kind, TrashKind.drawing);
      });

      // 되돌리기 → 목록과 파일이 그대로 돌아온다.
      await tester.tap(find.text('되돌리기'));
      await settleFiles();
      await tester.runAsync(() async {
        final back = await DrawingStore.load();
        expect(back.single.id, doc.id);
        expect(await loadTrash(), isEmpty);
        expect((await DrawingStore.dirOf(doc.id)).listSync(), isNotEmpty);
      });
    });

    testWidgets('보관함이 비면 안내가 나온다', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: DrawingLibraryPage()));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dl_empty')), findsOneWidget);
      expect(find.byKey(const Key('dl_add')), findsOneWidget);
    });
  });

  group('보기 화면', () {
    final at = DateTime(2026, 10, 1, 9);
    final doc = DrawingDoc(id: 'd1', name: 'ISO-01.pdf', kind: DrawingKind.pdf, ext: 'pdf', pages: 2, pageSizes: const [(1000, 700), (1000, 700)], addedAt: at, openedAt: at);
    late List<DrawingMark> saved;
    String? sent;
    var tick = 0;

    Future<void> open(WidgetTester tester, {List<DrawingMark> marks = const []}) async {
      SharedPreferences.setMockInitialValues({'user_real_name': '홍길동'});
      saved = [...marks];
      sent = null;
      tick = 0;
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: DrawingViewerPage(
            doc: doc,
            loadMarks: (_) async => [...marks],
            saveMarks: (_, m) async => saved = [...m],
            pagePath: (_, _) async => 'no_such_file.png',
            share: (t) async => sent = t,
            now: () => at.add(Duration(seconds: tick++)),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Offset center(WidgetTester tester) => tester.getCenter(find.byKey(const Key('dv_canvas')));

    testWidgets('틀림 도장을 놓고 내용을 적으면 1번 문제가 되고, 목록에서 해결·보내기', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('dv_tool_wrong')));
      await tester.pump();
      await tester.tapAt(center(tester));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('dv_text_field')), '배관 사이즈 틀림');
      await tester.tap(find.byKey(const Key('dv_text_ok')));
      await tester.pumpAndSettle();
      expect(saved.single.kind, MarkKind.wrong);
      expect(saved.single.no, 1);
      expect(saved.single.author, '홍길동');
      expect(saved.single.points.single.$1, closeTo(0.5, 0.02));
      expect(saved.single.points.single.$2, closeTo(0.5, 0.05)); // 도구 줄이 생겨 캔버스가 조금 줄어도 다시 맞추지 않는다

      // 질문도 하나 → 2번
      await tester.tap(find.byKey(const Key('dv_tool_question')));
      await tester.pump();
      await tester.tapAt(center(tester) + const Offset(100, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dv_text_ok')));
      await tester.pumpAndSettle();
      expect(saved.map((m) => m.no), [1, 2]);

      await tester.tap(find.byKey(const Key('dv_issues')));
      await tester.pumpAndSettle();
      expect(find.text('문제 목록  2건 · 남은 것 2건'), findsOneWidget);
      await tester.tap(find.byKey(const Key('dv_issue_done_1')));
      await tester.pumpAndSettle();
      expect(saved.firstWhere((m) => m.no == 1).done, isTrue);
      expect(saved.firstWhere((m) => m.no == 1).history.last.what, '해결');
      await tester.tap(find.byKey(const Key('dv_issue_share')));
      await tester.pump();
      expect(sent, contains('1. [틀림·해결] 1쪽 배관 사이즈 틀림'));
    });

    testWidgets('구름은 끌어서 그리고, 보기에서 누르면 고치거나 지운다', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('dv_tool_cloud')));
      await tester.pump();
      await tester.dragFrom(center(tester) - const Offset(60, 40), const Offset(120, 80));
      await tester.pumpAndSettle();
      expect(saved.single.kind, MarkKind.cloud);
      expect(saved.single.points.length, 2);
      expect(saved.single.color, MarkColor.red);

      // 너무 작게 끌면 버린다
      await tester.dragFrom(center(tester), const Offset(3, 3));
      await tester.pumpAndSettle();
      expect(saved.length, 1);

      await tester.tap(find.byKey(const Key('dv_tool_pan')));
      await tester.pump();
      await tester.tapAt(center(tester) + const Offset(60, 40)); // 구름 안쪽 모서리 근처
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dv_mark_delete')), findsOneWidget);
      final before = saved.single;
      await tester.tap(find.byKey(const Key('dv_mark_delete')));
      await tester.pumpAndSettle();
      expect(saved, isEmpty);
      // 되돌리기로 같은 표시(같은 id·자리)가 다시 저장된다.
      expect(find.textContaining('삭제했습니다: 구름'), findsOneWidget);
      await tester.tap(find.text('되돌리기'));
      await tester.pumpAndSettle();
      expect(saved.single.id, before.id);
      expect(saved.single.points, before.points);
    });

    testWidgets('쪽 넘기기와 도면 정보(도번·REV)', (tester) async {
      await open(tester);
      expect(find.text('1 / 2'), findsOneWidget);
      await tester.tap(find.byKey(const Key('dv_next')));
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);
      await tester.tap(find.byKey(const Key('dv_info')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('dv_info_no')), 'ISO-P-0101');
      await tester.enterText(find.byKey(const Key('dv_info_rev')), 'C');
      await tester.tap(find.byKey(const Key('dv_info_ok')));
      await tester.pumpAndSettle();
      expect(find.text('ISO-P-0101 · REV C'), findsOneWidget);
    });

    testWidgets('표시가 없는 쪽에서는 되돌리기가 꺼져 다른 쪽 표시를 지우지 않는다(10-07)', (tester) async {
      final m = DrawingMark(id: 'p1', page: 0, kind: MarkKind.wrong, color: MarkColor.red, points: const [(0.3, 0.3)], text: '문제', no: 1, createdAt: at);
      await open(tester, marks: [m]);
      await tester.tap(find.byKey(const Key('dv_next')));
      await tester.pumpAndSettle();
      final undo = tester.widget<IconButton>(find.byKey(const Key('dv_undo')));
      expect(undo.onPressed, isNull);
      await tester.tap(find.byKey(const Key('dv_undo')));
      await tester.pumpAndSettle();
      expect(saved.map((e) => e.id), ['p1']);
      // 1쪽으로 돌아가면 그 쪽 표시는 되돌릴 수 있다.
      await tester.tap(find.byKey(const Key('dv_prev')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dv_undo')));
      await tester.pumpAndSettle();
      expect(saved, isEmpty);
    });

    testWidgets('색을 고르면 그 색으로 놓는다(초록 = 삭제)', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('dv_tool_arrow')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('dv_color_green')));
      await tester.pump();
      await tester.dragFrom(center(tester), const Offset(100, -60));
      await tester.pumpAndSettle();
      expect(saved.single.kind, MarkKind.arrow);
      expect(saved.single.color, MarkColor.green);
    });
  });
}
