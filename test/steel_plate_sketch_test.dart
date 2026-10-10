// 철판 가공 › 손그림 읽어 만들기(10-10): 따라 찍은 꼭짓점에 치수 넣기(처음은 축척, 그다음은 변 길이),
// 직각 맞추기, 꼭짓점 끼우기·지우기와 넣은 치수 따라가기, AI 결과 옮기기, 레이저 절단으로 넘길 자료,
// 저장·읽기, 화면(빈 칸에 찍고 치수 넣고 보내기, AI 읽기 성공·실패), 첫 화면 세 갈래.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/utils/ai_plate_sketch.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_calc.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_home_page.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_sketch_model.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_sketch_page.dart';

void main() {
  group('그림 자료', () {
    PlateSketch traced() {
      // 사진 점 크기로 비뚤게 찍은 사각(가로 약 400, 세로 약 200)
      final s = PlateSketch(frame: const Rect.fromLTWH(0, 0, 600, 400));
      for (final p in const [
        Offset(100, 100),
        Offset(500, 104),
        Offset(497, 300),
        Offset(102, 297),
      ]) {
        s.addPoint(p);
      }
      return s;
    }

    test('직각 맞추기: 변 길이는 그대로 두고 가로·세로로 세운다', () {
      final s = traced();
      final l0 = s.edgeLen(0);
      expect(s.squareUp(), 4);
      expect(s.pts[1].dy, closeTo(100, 1e-9));
      expect(s.edgeLen(0), closeTo(l0, 1e-9));
      expect(s.pts[2].dx, closeTo(s.pts[1].dx, 1e-9));
      expect(s.pts[3].dy, closeTo(s.pts[2].dy, 1e-9));
      expect(s.pts[3].dx, closeTo(s.pts[0].dx, 1e-9)); // 닫는 변도 세로
    });

    test('처음 넣는 치수는 축척, 그다음은 그 변 길이(닫는 변이 차이를 받음)', () {
      final s = traced()..squareUp();
      final h = s.edgeLen(1);
      s.holes.add(PlateHoleSpec(u: 150, v: 150, dia: 13.5));
      expect(s.scaled, isFalse);
      expect(s.toPlateMap(), isNull); // 치수 없으면 못 넘긴다
      final f = 200 / s.edgeLen(0);
      expect(s.setEdge(0, 200), isTrue);
      expect(s.scaled, isTrue);
      expect(s.edgeLen(0), closeTo(200, 1e-9));
      expect(s.edgeLen(1), closeTo(h * f, 1e-9));
      expect(s.holes.first.u, closeTo(150 * f, 1e-9));
      expect(s.holes.first.dia, 13.5); // 지름은 mm 그대로
      expect(s.frame.width, closeTo(600 * f, 1e-9));
      // 오른쪽 세로 변을 120으로 → 뒤 꼭짓점이 위로 옮겨지고 첫 변은 그대로
      s.setEdge(1, 120);
      expect(s.edgeLen(1), closeTo(120, 1e-9));
      expect(s.edgeLen(0), closeTo(200, 1e-9));
      expect(s.edgeLen(2), closeTo(200, 1e-9));
      expect(s.edgeMatches(0), isTrue);
      expect(s.edgeMatches(1), isTrue);
      expect(s.edgeMatches(2), isNull);
      // 닫는 변: 마지막 꼭짓점만 옮긴다
      s.setEdge(3, 100);
      expect(s.edgeLen(3), closeTo(100, 1e-9));
      expect(s.edgeMatches(1), isTrue);
      expect(s.edgeMatches(2), isNull);
      // 길이 0인 변·잘못된 값은 못 넣는다
      expect(s.setEdge(0, 0), isFalse);
      expect(s.setEdge(9, 10), isFalse);
    });

    test('꼭짓점을 끼우거나 지우면 바뀐 변의 넣은 치수만 빠진다', () {
      final s = traced()..squareUp();
      s.setEdge(0, 200);
      s.setEdge(1, 100);
      s.setEdge(2, 200);
      s.insertOnEdge(1, (s.pts[1] + s.pts[2]) / 2 + const Offset(20, 0));
      expect(s.n, 5);
      expect(s.dimOf(0), 200);
      expect(s.dimOf(1), isNull);
      expect(s.dimOf(2), isNull);
      expect(s.dimOf(3), 200); // 원래 변 2
      s.removePoint(2);
      expect(s.n, 4);
      expect(s.dimOf(0), 200);
      expect(s.dimOf(2), 200);
      // 끝에 더하면 닫는 변이 나뉘므로 그 치수는 빠진다
      s.setEdge(3, 100);
      s.addPoint(const Offset(-10, 50));
      expect(s.dimOf(3), isNull);
    });

    test('레이저 절단으로 넘길 자료: 왼쪽 아래를 0,0으로, 귀 처리·구멍·두께', () {
      final s = PlateSketch(
        pts: const [
          Offset(50, 20),
          Offset(250, 20),
          Offset(250, 120),
          Offset(50, 120),
        ],
        corners: const [
          PlateCorner.square,
          PlateCorner(PlateCornerKind.round, 10),
          PlateCorner.square,
          PlateCorner(PlateCornerKind.chamfer, 5),
        ],
        holes: [const PlateHoleSpec(u: 70, v: 40, dia: 11, slot: 30)],
        scaled: true,
        thickness: 4,
      );
      final m = s.toPlateMap()!;
      expect(m['sh'], 'free');
      expect(m['pts'], '0,0\n200,0,r10\n200,100\n0,100,c5');
      expect(m['t'], '4');
      final h = PlateHoleSpec.fromJson((m['holes'] as List).first)!;
      expect([h.u, h.v, h.dia, h.slot], [20, 20, 11, 30]);
    });

    test('AI 결과 옮기기와 저장·읽기', () {
      const r = PlateSketchResult.ok(
        outline: [
          PlateSketchPoint(0, 0, corner: 'round', size: 15),
          PlateSketchPoint(300, 0),
          PlateSketchPoint(300, 150, corner: 'chamfer', size: 10),
          PlateSketchPoint(0, 150),
        ],
        holes: [
          PlateSketchHole(25, 25, 13.5),
          PlateSketchHole(150, 75, 11, slot: 8),
        ],
        thickness: 3,
        unclear: ['위 변 길이는 짐작했습니다'],
      );
      final s = PlateSketch.fromAi(r);
      expect(s.scaled, isTrue);
      expect(s.photoAligned, isFalse);
      expect(s.corners[0].label, 'R15');
      expect(s.corners[2].label, 'C10');
      expect(s.holes[1].slot, 0); // 장공 길이가 지름보다 짧으면 둥근 구멍
      expect(s.frame.contains(const Offset(300, 150)), isTrue);
      final back = PlateSketch.fromJson(s.toJson())!;
      expect(back.pts, s.pts);
      expect(back.corners.map((c) => c.label), s.corners.map((c) => c.label));
      expect(back.holes.length, 2);
      expect(back.thickness, 3);
      expect(back.unclear, ['위 변 길이는 짐작했습니다']);
      expect(back.scaled, isTrue);
      expect(back.photoAligned, isFalse);
      // 번호는 이어서 붙는다
      back.addPoint(const Offset(1, 1));
      expect(back.ids.toSet().length, 5);
    });

    test('서버 자료 읽기: 못 읽음·이상한 값', () {
      expect(readPlateSketch(null).ok, isFalse);
      expect(
        readPlateSketch({'readable': false, 'reason': '사진이 흐립니다'}).error,
        '사진이 흐립니다',
      );
      final r = readPlateSketch({
        'readable': true,
        'outline': [
          {'x': 0, 'y': 0, 'corner': 'round', 'size': 5},
          {'x': 100, 'y': 0, 'corner': 'round', 'size': -1},
          {'x': 'a', 'y': 0},
          {'x': 100, 'y': 50, 'corner': 'none', 'size': 0},
        ],
        'holes': [
          {'x': 10, 'y': 10, 'dia': 0},
          {'x': 20, 'y': 20, 'dia': 9},
        ],
        'thickness': null,
        'unclear': ['', ' 짐작 '],
      }, remaining: 7);
      expect(r.ok, isTrue);
      expect(r.outline.length, 3);
      expect(r.outline[1].corner, 'none');
      expect(r.holes.length, 1);
      expect(r.unclear, ['짐작']);
      expect(r.remaining, 7);
      expect(readPlateSketch({'readable': true, 'outline': []}).ok, isFalse);
    });
  });

  group('화면', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Map<String, Object?>? sent;

    Future<void> open(
      WidgetTester tester, {
      PlateSketchCall? parse,
      Uint8List? photo,
    }) async {
      sent = null;
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: PlateSketchPage(
            parse: parse ?? (_) async => const PlateSketchResult.fail('없음'),
            pickPhoto: (_) async => photo,
            loadPhoto: () async => null,
            savePhoto: (_) async {},
            openCut: (_, m) => sent = m,
          ),
        ),
      );
      await tester.pumpAndSettle();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      });
    }

    String status(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(const Key('sk_status'))).data!;

    Future<void> tap(WidgetTester tester, String key) async {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
    }

    testWidgets('빈 칸에 꼭짓점 넷 → 직각 맞추기 → 치수 둘 → 레이저 절단으로', (tester) async {
      await open(tester);
      expect(status(tester), startsWith('사진을 찍거나 고르십시오'));
      final r = tester.getRect(find.byKey(const Key('sk_canvas')));
      final pts = [
        r.center + const Offset(-120, 60),
        r.center + const Offset(120, 58),
        r.center + const Offset(118, -60),
        r.center + const Offset(-121, -58),
      ];
      for (final p in pts) {
        await tester.tapAt(p);
        await tester.pumpAndSettle();
      }
      expect(status(tester), startsWith('꼭짓점 4개'));
      await tap(tester, 'sk_square');
      expect(find.text('변 4개를 가로·세로로 바로 세웠습니다'), findsOneWidget);
      // 치수 없이 보내면 알림만
      await tap(tester, 'sk_send');
      expect(find.text('변 하나에 치수를 넣어야 크기가 정해집니다'), findsOneWidget);
      expect(sent, isNull);
      await tap(tester, 'sk_mode_dim');
      expect(status(tester), startsWith('변을 눌러 길이(mm)를 넣습니다'));
      // 아래 변(꼭짓점 1→2) 가운데를 누른다
      await tester.tapAt((pts[0] + pts[1]) / 2);
      await tester.pumpAndSettle();
      expect(find.text('변 1→2 길이'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('ed_num_0')), '300');
      await tester.tap(find.byKey(const Key('ed_num_ok')));
      await tester.pumpAndSettle();
      expect(find.text('이 치수로 전체 크기를 맞췄습니다. 나머지 변도 눌러 넣으십시오.'), findsOneWidget);
      // 화면은 그대로 보이므로 같은 자리의 오른쪽 변을 누른다
      await tester.tapAt((pts[1] + pts[2]) / 2);
      await tester.pumpAndSettle();
      expect(find.text('변 2→3 길이'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('ed_num_0')), '150');
      await tester.tap(find.byKey(const Key('ed_num_ok')));
      await tester.pumpAndSettle();
      expect(status(tester), contains('넣은 치수 2곳'));
      await tap(tester, 'sk_send');
      expect(sent, isNotNull);
      expect(sent!['sh'], 'free');
      expect(sent!['pts'], '0,0\n300,0\n300,150\n0,150');
      // 되돌리기: 마지막 치수 전으로
      await tap(tester, 'sk_undo');
      expect(status(tester), contains('넣은 치수 1곳'));
    });

    testWidgets('꼭짓점 고르기 → 귀 처리 R10 → 지우기', (tester) async {
      await open(tester);
      final r = tester.getRect(find.byKey(const Key('sk_canvas')));
      final a = r.center + const Offset(-100, 50);
      for (final p in [
        a,
        r.center + const Offset(100, 50),
        r.center + const Offset(0, -60),
      ]) {
        await tester.tapAt(p);
        await tester.pumpAndSettle();
      }
      await tester.tapAt(a);
      await tester.pumpAndSettle();
      expect(status(tester), startsWith('꼭짓점 1: 직각'));
      await tap(tester, 'sk_corner');
      await tester.tap(find.byKey(const Key('sk_ck_round')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('sk_ca')), '10');
      await tester.tap(find.byKey(const Key('sk_corner_ok')));
      await tester.pumpAndSettle();
      expect(status(tester), startsWith('꼭짓점 1: R10'));
      await tap(tester, 'sk_del');
      expect(status(tester), startsWith('꼭짓점 2개'));
    });

    testWidgets('AI로 읽기: 짐작한 곳을 보여 주고 바로 보낼 수 있다', (tester) async {
      await open(
        tester,
        photo: Uint8List.fromList(List.filled(64, 1)),
        parse: (_) async => const PlateSketchResult.ok(
          outline: [
            PlateSketchPoint(0, 0),
            PlateSketchPoint(250, 0),
            PlateSketchPoint(250, 120, corner: 'round', size: 20),
            PlateSketchPoint(0, 120),
          ],
          holes: [PlateSketchHole(30, 30, 13.5)],
          thickness: 4,
          unclear: ['위쪽 구멍 자리는 짐작했습니다'],
          remaining: 19,
        ),
      );
      expect(find.byKey(const Key('sk_ai')), findsNothing); // 사진 전
      await tap(tester, 'sk_gallery');
      expect(status(tester), startsWith('"AI로 읽기"를 눌러 보십시오'));
      await tap(tester, 'sk_ai');
      expect(find.textContaining('오늘 남은 횟수 19번'), findsOneWidget);
      expect(find.text('AI가 짐작한 곳: 위쪽 구멍 자리는 짐작했습니다'), findsOneWidget);
      expect(status(tester), startsWith('변을 누르면 길이를'));
      expect(find.byKey(const Key('sk_trace')), findsOneWidget);
      await tap(tester, 'sk_send');
      expect(sent!['pts'], '0,0\n250,0\n250,120,r20\n0,120');
      expect(sent!['t'], '4');
      expect((sent!['holes'] as List).length, 1);
      // 직접 따라 찍기로 바꾸면 빈 그림(되돌리기로 살린다)
      await tap(tester, 'sk_trace');
      expect(status(tester), startsWith('"AI로 읽기"를 눌러 보십시오'));
      await tap(tester, 'sk_undo');
      expect(status(tester), startsWith('꼭짓점 4개')); // AI가 읽은 넷이 돌아온다
    });

    testWidgets('AI가 안 되면 이유와 따라 찍기 안내', (tester) async {
      await open(
        tester,
        photo: Uint8List.fromList(List.filled(64, 1)),
        parse: (_) async => const PlateSketchResult.fail('통신이 되는지 확인해 주십시오'),
      );
      await tap(tester, 'sk_camera');
      await tap(tester, 'sk_ai');
      expect(
        find.text('통신이 되는지 확인해 주십시오. 사진 위에 직접 따라 찍을 수 있습니다.'),
        findsOneWidget,
      );
      // 그래도 사진 위에 찍을 수 있다
      final r = tester.getRect(find.byKey(const Key('sk_canvas')));
      await tester.tapAt(r.center);
      await tester.pumpAndSettle();
      expect(status(tester), startsWith('꼭짓점 1개'));
    });

    testWidgets('그린 것은 다시 열어도 남는다', (tester) async {
      await open(tester);
      final r = tester.getRect(find.byKey(const Key('sk_canvas')));
      await tester.tapAt(r.center);
      await tester.tapAt(r.center + const Offset(80, 0));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      await open(tester);
      expect(status(tester), startsWith('꼭짓점 2개'));
    });
  });

  testWidgets('철판 가공 첫 화면: 세 갈래', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: PlateHomePage()));
    await tester.pumpAndSettle();
    expect(find.text('레이저 절단'), findsOneWidget);
    expect(find.text('절단 + 절곡'), findsOneWidget);
    expect(find.text('손그림 읽어 만들기'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ph_bend')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pl_shape_hat')), findsOneWidget);
    expect(find.text('절단 + 절곡'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ph_cut')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pl_shape_flat')), findsOneWidget);
    expect(find.byKey(const Key('pl_shape_hat')), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ph_sketch')));
    await tester.pumpAndSettle();
    expect(find.text('손그림 읽어 만들기'), findsOneWidget);
    expect(find.byKey(const Key('sk_canvas')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
