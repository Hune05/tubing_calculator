// 철판 가공 › 손그림 읽어 만들기(10-10): 따라 찍은 꼭짓점에 치수 넣기(처음은 축척, 그다음은 잠금 —
// 같은 방향의 잠기지 않은 변이 차이를 받고, 없으면 바꾸지 않고 차이를 알림), 직각 맞추기, 닫기,
// 꼭짓점 끼우기·지우기와 넣은 치수 따라가기, AI 결과 옮기기, 레이저 절단으로 넘길 자료, 저장·읽기,
// 화면(모드 없이: 빈 칸에 찍고 1번 점으로 닫고 변을 눌러 치수, 구멍 놓기 5mm 칸, AI 읽기 성공·실패), 첫 화면.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/utils/ai_plate_sketch.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_calc.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_home_page.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_page.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_sketch_model.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_sketch_page.dart';

void main() {
  group('그림 자료', () {
    PlateSketch traced() {
      // 사진 점 크기로 비뚤게 찍은 사각(가로 약 400, 세로 약 200), 닫음
      final s = PlateSketch(frame: const Rect.fromLTWH(0, 0, 600, 400));
      for (final p in const [
        Offset(100, 100),
        Offset(500, 104),
        Offset(497, 300),
        Offset(102, 297),
      ]) {
        s.addPoint(p);
      }
      s.close();
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

    test('닫기 전에는 찍은 차례대로 이은 변만, 1번 점으로 닫으면 닫는 변이 생긴다', () {
      final s = PlateSketch();
      for (final p in const [Offset(0, 0), Offset(10, 0), Offset(10, 10)]) {
        s.addPoint(p);
      }
      expect(s.closed, isFalse);
      expect(s.edgeCount, 2);
      expect(s.squareUp(), 0); // 이미 바름
      expect(s.close(), isTrue);
      expect(s.edgeCount, 3);
      s.removePoint(2);
      expect(s.closed, isFalse); // 점이 셋 안 되면 다시 열림
    });

    test('처음 치수는 축척, 그다음은 방금 넣은 값이 이김: 맞은편 변이 받고 직사각형 그대로', () {
      final s = traced()..squareUp();
      final h = s.edgeLen(1);
      s.holes.add(PlateHoleSpec(u: 150, v: 150, dia: 13.5));
      expect(s.scaled, isFalse);
      expect(s.toPlateMap(), isNull); // 치수 없으면 못 넘긴다
      final f = 200 / s.edgeLen(0);
      expect(s.setEdge(0, 200).ok, isTrue);
      expect(s.scaled, isTrue);
      expect(s.edgeLen(0), closeTo(200, 1e-9));
      expect(s.edgeLen(1), closeTo(h * f, 1e-9));
      expect(s.holes.first.u, closeTo(150 * f, 1e-9));
      expect(s.holes.first.dia, 13.5); // 지름은 mm 그대로
      expect(s.frame.width, closeTo(600 * f, 1e-9));
      // 오른쪽 세로 변 120 → 왼쪽 세로 변이 받는다(기울지 않음)
      expect(s.setEdge(1, 120).ok, isTrue);
      expect(s.edgeLen(1), closeTo(120, 1e-9));
      expect(s.edgeLen(3), closeTo(120, 1e-9));
      expect(s.edgeLen(0), closeTo(200, 1e-9));
      expect(s.edgeLen(2), closeTo(200, 1e-9));
      expect(s.pts[3].dx, closeTo(s.pts[0].dx, 1e-9));
      expect(
        [s.isLocked(0), s.isLocked(1), s.isLocked(2)],
        [true, true, false],
      );
      expect(s.edgeMatches(0), isTrue);
      expect(s.edgeMatches(2), isNull);
      // 위 변도 넣어 잠근 뒤 아래를 다르게 넣으면: 방금 넣은 값이 이기고 잠긴 위 변이 따라 바뀜(알림)
      expect(s.setEdge(2, 200).ok, isTrue);
      final r = s.setEdge(0, 220);
      expect(r.ok, isTrue);
      expect(r.note, '같이 바뀐 변: 3→4 (200 → 220).');
      expect(s.edgeLen(0), closeTo(220, 1e-9));
      expect(s.edgeLen(2), closeTo(220, 1e-9));
      expect(s.dimOf(2), closeTo(220, 1e-9)); // 넣은 값도 새 길이로(✓ 그대로)
      expect(s.edgeMatches(2), isTrue);
      expect(s.edgeLen(1), closeTo(120, 1e-9));
      // 저절로 맞춰진 변(잠기지 않음)이 있으면 그 변이 먼저 받는다
      s.unlock(2);
      expect(s.setEdge(0, 240).note, isNull);
      expect(s.edgeLen(2), closeTo(240, 1e-9));
      // ㄱ자: 넣은 넷이 다 잠겨 있어도 어느 변이든 고쳐진다(같은 방향의 잠긴 변이 따라 바뀜)
      final l = PlateSketch(
        pts: const [
          Offset(0, 0),
          Offset(300, 0),
          Offset(300, 80),
          Offset(150, 80),
          Offset(150, 180),
          Offset(0, 180),
        ],
        scaled: true,
        closed: true,
      );
      for (final (k, mm) in const [
        (0, 300.0),
        (1, 80.0),
        (2, 150.0),
        (3, 100.0),
        (4, 150.0),
        (5, 180.0),
      ]) {
        expect(l.setEdge(k, mm).ok, isTrue);
      }
      final top = l.setEdge(4, 170); // 위 170 → 아래가 320으로
      expect(top.ok, isTrue);
      expect(top.note, contains('같이 바뀐 변: 1→2 (300 → 320)'));
      final left = l.setEdge(5, 200); // 왼쪽 200 → 오른쪽 세로(80)가 100으로
      expect(left.ok, isTrue);
      expect(
        l.toPlateMap()!['pts'],
        ['0,0', '320,0', '320,100', '170,100', '170,200', '0,200'].join('\n'),
      );
      // 길이 0·없는 변은 못 넣는다
      expect(s.setEdge(0, 0).ok, isFalse);
      expect(s.setEdge(9, 10).ok, isFalse);
    });

    test('ㄱ자: 가로·세로 변을 차례로 넣으면 남은 변이 저절로 맞는다', () {
      final s = PlateSketch(
        pts: const [
          Offset(0, 0),
          Offset(500, 0),
          Offset(500, 140),
          Offset(200, 140),
          Offset(200, 330),
          Offset(0, 330),
        ],
        scaled: true,
        closed: true,
      );
      for (final (i, mm) in const [
        (0, 300.0),
        (1, 80.0),
        (2, 150.0),
        (3, 100.0),
      ]) {
        expect(s.setEdge(i, mm).ok, isTrue);
      }
      expect(
        s.toPlateMap()!['pts'],
        '0,0\n300,0\n300,80\n150,80\n150,180\n0,180',
      );
    });

    test('기운 변: 가로 몫·세로 몫을 가로·세로 변이 받고, 가로·세로 변이 없으면 한 변이 기운다고 알림', () {
      // 오른쪽 위 귀를 빗긴 오각형(빗변 3번)
      final s = PlateSketch(
        pts: const [
          Offset(0, 0),
          Offset(200, 0),
          Offset(200, 60),
          Offset(160, 100),
          Offset(0, 100),
        ],
        scaled: true,
        closed: true,
      );
      final r = s.setEdge(2, 50 * 1.4142135623730951); // 빗변 40√2 → 50√2
      expect(r.ok, isTrue);
      expect(r.note, isNull);
      expect(s.edgeVec(0).dy, closeTo(0, 1e-9));
      expect(s.edgeVec(4).dx, closeTo(0, 1e-9));
      // 가로·세로 변이 없는 모양(삼각)은 다른 변 하나가 기운다고 알림
      final t = PlateSketch(
        pts: const [Offset(0, 0), Offset(100, 30), Offset(30, 100)],
        scaled: true,
        closed: true,
      );
      final r2 = t.setEdge(0, t.edgeLen(0) + 10);
      expect(r2.ok, isTrue);
      expect(r2.note, contains('기울기가 바뀌었습니다'));
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
      expect(back.closed, isTrue);
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

    /// 손으로 그은 것처럼: 꼭짓점 사이를 4씩 걸으며 옆으로 조금 흔들리고, 귀는 조금 둥글게(짧게 빗겨) 돈다.
    List<Offset> handStroke(
      List<Offset> poly, {
      bool close = true,
      double jitter = 2,
      double cut = 8,
    }) {
      final pts = <Offset>[];
      final n = poly.length;
      final path = <Offset>[];
      for (var i = 0; i < n; i++) {
        final a = poly[(i - 1 + n) % n], b = poly[i], c = poly[(i + 1) % n];
        if (!close && (i == 0 || i == n - 1)) {
          path.add(b);
          continue;
        }
        final u = (a - b) / (a - b).distance, v = (c - b) / (c - b).distance;
        path
          ..add(b + u * cut)
          ..add(b + v * cut);
      }
      // 닫힌 것은 첫 변 가운데에서 시작해 한 바퀴 돌고 시작점 조금 옆에서 끝낸다
      final seq = close
          ? [
              (path[0] + path.last) / 2,
              ...path,
              (path[0] + path.last) / 2 + const Offset(3, 4),
            ]
          : path;
      var k = 0;
      for (var i = 1; i < seq.length; i++) {
        final a = seq[i - 1], b = seq[i];
        final d = b - a, len = d.distance;
        if (len < 1e-9) continue;
        final nrm = Offset(-d.dy, d.dx) / len;
        for (var t = 0.0; t < len; t += 4) {
          pts.add(a + d * (t / len) + nrm * (math.sin(k++ * 1.7) * jitter));
        }
      }
      pts.add(seq.last);
      return pts;
    }

    bool near(List<Offset> got, Offset want, double tol) =>
        got.any((p) => (p - want).distance <= tol);

    test('그은 사각: 둥글게 돈 귀를 뾰족하게, 닫힘, 꼭짓점 넷', () {
      const rect = [
        Offset(0, 0),
        Offset(240, 0),
        Offset(240, 120),
        Offset(0, 120),
      ];
      final r = sketchStrokeToPolygon(handStroke(rect), tol: 14, closeTol: 44);
      expect(r.closed, isTrue);
      expect(r.pts.length, 4);
      for (final c in rect) {
        expect(near(r.pts, c, 6), isTrue, reason: '$c ← ${r.pts}');
      }
      // 닫힌 그림으로 만들고 직각 맞추기까지 하면 가로·세로가 정확
      final s = PlateSketch(pts: r.pts, closed: true);
      s.squareUp(tolDeg: 12);
      for (var i = 0; i < 4; i++) {
        final v = s.edgeVec(i);
        expect(v.dx.abs() < 1e-9 || v.dy.abs() < 1e-9, isTrue);
      }
    });

    test('그은 ㄱ자는 꼭짓점 여섯, 끝을 떼어 두면 열린 채로', () {
      const l = [
        Offset(0, 0),
        Offset(300, 0),
        Offset(300, 80),
        Offset(150, 80),
        Offset(150, 180),
        Offset(0, 180),
      ];
      final r = sketchStrokeToPolygon(handStroke(l), tol: 14, closeTol: 44);
      expect(r.closed, isTrue);
      expect(r.pts.length, 6);
      for (final c in l) {
        expect(near(r.pts, c, 6), isTrue, reason: '$c ← ${r.pts}');
      }
      const open = [Offset(0, 0), Offset(200, 0), Offset(200, 150)];
      final o = sketchStrokeToPolygon(
        handStroke(open, close: false),
        tol: 14,
        closeTol: 44,
      );
      expect(o.closed, isFalse);
      expect(o.pts.length, 3);
      // 너무 짧거나 점 하나면 빈 것
      expect(
        sketchStrokeToPolygon(const [Offset(1, 1)], tol: 14, closeTol: 44).pts,
        isEmpty,
      );
    });

    test('판 안에 그린 고리: 동그라미는 지름, 길쭉하면 장공 방향', () {
      List<Offset> ellipse(Offset c, double a, double b, double deg) => [
        for (var k = 0; k <= 48; k++)
          () {
            final t = k / 48 * 2 * math.pi;
            final r = deg * math.pi / 180;
            final x = a * math.cos(t), y = b * math.sin(t);
            return c +
                Offset(
                  x * math.cos(r) - y * math.sin(r),
                  x * math.sin(r) + y * math.cos(r),
                ) +
                Offset(math.sin(k * 2.3) * 0.6, math.cos(k * 1.9) * 0.6);
          }(),
      ];
      final round = sketchLoopShape(
        ellipse(const Offset(100, 50), 20, 20, 0),
        closeTol: 10,
      )!;
      expect((round.c - const Offset(100, 50)).distance, lessThan(2));
      expect(round.major, closeTo(40, 3));
      expect(round.minor / round.major, greaterThan(0.85));
      final slot = sketchLoopShape(
        ellipse(const Offset(60, 60), 30, 8, 90),
        closeTol: 10,
      )!;
      expect(slot.minor / slot.major, lessThan(0.4));
      expect(slot.angleDeg, closeTo(90, 3));
      // 고리가 아닌 선(끝이 멀다)은 null
      expect(
        sketchLoopShape([
          for (var i = 0; i < 20; i++) Offset(i * 5.0, 0),
        ], closeTol: 10),
        isNull,
      );
      // 시계 방향·중간 귀부터여도 반시계·왼쪽 아래부터로
      expect(
        sketchNormalizeLoop(const [
          Offset(10, 10),
          Offset(10, 0),
          Offset(0, 0),
          Offset(0, 10),
        ]),
        const [Offset(0, 0), Offset(10, 0), Offset(10, 10), Offset(0, 10)],
      );
      const sq = [Offset(0, 0), Offset(10, 0), Offset(10, 10), Offset(0, 10)];
      expect(sketchContains(sq, const Offset(5, 5)), isTrue);
      expect(sketchContains(sq, const Offset(15, 5)), isFalse);
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

    Future<void> enterLength(WidgetTester tester, String mm) async {
      await tester.enterText(find.byKey(const Key('sk_len')), mm);
      await tester.tap(find.byKey(const Key('sk_len_ok')));
      await tester.pumpAndSettle();
    }

    /// 빈 칸에 사각 넷을 찍고 1번 점으로 닫는다. 화면 점 넷을 돌려준다.
    Future<List<Offset>> drawRect(WidgetTester tester) async {
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
      expect(
        status(tester),
        startsWith('꼭짓점 4개. 다음 귀퉁이를 누르고, 다 찍었으면 1번 점을 눌러 닫습니다'),
      );
      await tester.tapAt(pts[0]);
      await tester.pumpAndSettle();
      return pts;
    }

    /// 화면 점들을 따라 한 손가락으로 긋는다.
    Future<void> stroke(WidgetTester tester, List<Offset> pts) async {
      final g = await tester.startGesture(pts.first);
      for (final p in pts.skip(1)) {
        await g.moveTo(p);
        await tester.pump(const Duration(milliseconds: 8));
      }
      await g.up();
      await tester.pumpAndSettle();
    }

    /// 화면 위 사각 외곽(가운데 기준)을 손으로 긋듯: 아래 변 가운데에서 시작해 한 바퀴.
    List<Offset> rectPath(Offset c, double w, double h) {
      final corners = [
        c + Offset(w / 2, h / 2),
        c + Offset(w / 2, -h / 2),
        c + Offset(-w / 2, -h / 2),
        c + Offset(-w / 2, h / 2),
        c + Offset(2, h / 2 + 2),
      ];
      final out = <Offset>[c + Offset(0, h / 2)];
      var k = 0;
      for (final t in corners) {
        final a = out.last, d = t - a;
        final n = (d.distance / 6).ceil();
        for (var i = 1; i <= n; i++) {
          out.add(a + d * (i / n) + Offset(0, math.sin(k++ * 1.3) * 1.5));
        }
      }
      return out;
    }

    testWidgets('손가락으로 그어 그리기: 외곽 → 치수 → 판 안 동그라미는 구멍', (tester) async {
      await open(tester);
      expect(status(tester), startsWith('빈 칸에 판 모양을 손가락으로 그으십시오'));
      final r = tester.getRect(find.byKey(const Key('sk_canvas')));
      await stroke(tester, rectPath(r.center, 240, 140));
      expect(find.textContaining('그은 선을 꼭짓점 4개로 바꿨습니다'), findsOneWidget);
      expect(status(tester), startsWith('변 이름(변 1…)을 눌러'));
      // 아래 변 300
      await tester.tapAt(r.center + const Offset(0, 70));
      await tester.pumpAndSettle();
      await enterLength(tester, '300');
      // 판 안에 작은 동그라미 → 구멍(5mm 칸)
      final c = r.center + const Offset(-60, 20);
      await stroke(tester, [
        for (var k = 0; k <= 24; k++)
          c +
              Offset(
                    math.cos(k / 24 * 2 * math.pi),
                    math.sin(k / 24 * 2 * math.pi),
                  ) *
                  24,
      ]);
      expect(find.textContaining('구멍으로 바꿨습니다'), findsOneWidget);
      await tap(tester, 'sk_send');
      // 그은 시작 자리와 상관없이 왼쪽 아래 귀부터 반시계로
      expect(sent!['pts'], startsWith('0,0\n300,0\n'));
      expect((sent!['pts'] as String).split('\n').length, 4);
      final h = PlateHoleSpec.fromJson((sent!['holes'] as List).single)!;
      expect(h.dia, 13.5); // 그린 크기가 아니라 고른 펀치 지름
      expect(h.u % 5, closeTo(0, 1e-6));
      // 판 안에서 길게 그은 선(고리가 아님)은 구멍이 안 되고 안내만
      await stroke(tester, [
        for (var k = 0; k <= 20; k++) r.center + Offset(-80 + k * 8.0, -20),
      ]);
      expect(find.textContaining('판 안에 작은 동그라미를 그리면 구멍이 됩니다'), findsOneWidget);
      await tap(tester, 'sk_send');
      expect((sent!['holes'] as List).length, 1);
    });

    testWidgets('모드 없이: 찍고 → 1번 점으로 닫고 → 직각 → 변을 눌러 치수 → 보내기', (tester) async {
      await open(tester);
      expect(status(tester), startsWith('빈 칸에 판 모양을 손가락으로 그으십시오'));
      final pts = await drawRect(tester);
      expect(
        find.text('모양을 닫았습니다. 변 이름(변 1…)을 눌러 길이(mm)를 넣으십시오.'),
        findsOneWidget,
      );
      // 닫은 뒤에는 빈 곳을 눌러도 점이 안 생긴다
      final r = tester.getRect(find.byKey(const Key('sk_canvas')));
      await tester.tapAt(r.topLeft + const Offset(30, 30));
      await tester.pumpAndSettle();
      expect(status(tester), startsWith('변 이름(변 1…)을 눌러 길이(mm)를 넣습니다'));
      await tap(tester, 'sk_square');
      expect(find.text('변 4개를 가로·세로로 바로 세웠습니다'), findsOneWidget);
      // 치수 없이 보내면 알림만
      await tap(tester, 'sk_send');
      expect(find.text('변 하나에 치수를 넣어야 크기가 정해집니다'), findsOneWidget);
      expect(sent, isNull);
      // 아래 변(1→2)을 누른다
      await tester.tapAt((pts[0] + pts[1]) / 2);
      await tester.pumpAndSettle();
      expect(find.text('변 1→2 길이'), findsOneWidget);
      await enterLength(tester, '300');
      expect(
        find.text('이 치수로 전체 크기를 맞췄습니다. 나머지 변의 숫자도 눌러 넣으십시오.'),
        findsOneWidget,
      );
      // 오른쪽 변 150 → 왼쪽 변이 받아 직사각형 그대로
      await tester.tapAt((pts[1] + pts[2]) / 2);
      await tester.pumpAndSettle();
      expect(find.text('변 2→3 길이'), findsOneWidget);
      await enterLength(tester, '150');
      expect(status(tester), contains('넣은 치수 2곳'));
      await tap(tester, 'sk_send');
      expect(sent!['sh'], 'free');
      expect(sent!['pts'], '0,0\n300,0\n300,150\n0,150');
      // 잠긴 변을 다시 누르면 잠금 풀기가 있다
      await tester.tapAt((pts[1] + pts[2]) / 2);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sk_len_unlock')));
      await tester.pumpAndSettle();
      expect(status(tester), contains('넣은 치수 1곳'));
      // 되돌리기
      await tap(tester, 'sk_undo');
      expect(status(tester), contains('넣은 치수 2곳'));
    });

    testWidgets('구멍 놓기: 5mm 칸에 붙고, 눌러 고르고 지운다', (tester) async {
      await open(tester);
      final pts = await drawRect(tester);
      await tap(tester, 'sk_square');
      await tester.tapAt((pts[0] + pts[1]) / 2);
      await tester.pumpAndSettle();
      await enterLength(tester, '300');
      await tap(tester, 'sk_hole_add');
      expect(status(tester), startsWith('빈 곳을 누르면 φ13.5 구멍을 놓습니다(5mm 칸에 붙음)'));
      await tap(tester, 'sk_dia_110');
      final at = pts[0] + const Offset(37, -29);
      await tester.tapAt(at);
      await tester.pumpAndSettle();
      await tap(tester, 'sk_send');
      final h = PlateHoleSpec.fromJson((sent!['holes'] as List).single)!;
      expect(h.dia, 11);
      expect(h.u % 5, closeTo(0, 1e-6));
      expect(h.v % 5, closeTo(0, 1e-6));
      // 구멍 놓기를 끄고 구멍을 누르면 고르기 → 지우기
      await tap(tester, 'sk_hole_add');
      await tester.tapAt(at);
      await tester.pumpAndSettle();
      expect(status(tester), startsWith('구멍 1: φ11'));
      await tap(tester, 'sk_hole_del');
      await tap(tester, 'sk_send');
      expect(sent!['holes'], isEmpty);
    });

    testWidgets('꼭짓점 고르기 → 귀 처리 R10 → 지우기', (tester) async {
      await open(tester);
      final r = tester.getRect(find.byKey(const Key('sk_canvas')));
      final b = r.center + const Offset(100, 50);
      for (final p in [
        r.center + const Offset(-100, 50),
        b,
        r.center + const Offset(0, -60),
      ]) {
        await tester.tapAt(p);
        await tester.pumpAndSettle();
      }
      await tester.tapAt(b);
      await tester.pumpAndSettle();
      expect(status(tester), startsWith('꼭짓점 2: 직각'));
      await tap(tester, 'sk_corner');
      await tester.tap(find.byKey(const Key('cd_kind_round')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('cd_a')), '10');
      await tester.tap(find.byKey(const Key('cd_ok')));
      await tester.pumpAndSettle();
      expect(status(tester), startsWith('꼭짓점 2: R10'));
      await tap(tester, 'sk_del');
      expect(status(tester), startsWith('꼭짓점 2개. 다음 귀퉁이를 누릅니다'));
    });

    testWidgets('AI로 읽기: 짐작한 곳·사진 작게, 바로 보낼 수 있다', (tester) async {
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
      expect(status(tester), startsWith('변의 숫자를 눌러 길이를 넣습니다'));
      expect(find.byKey(const Key('sk_thumb')), findsOneWidget);
      // 사진 단추는 다 그린 뒤에는 아래 칸에서 빠지고 위 메뉴로
      expect(find.byKey(const Key('sk_gallery')), findsNothing);
      await tap(tester, 'sk_send');
      expect(sent!['pts'], '0,0\n250,0\n250,120,r20\n0,120');
      expect(sent!['t'], '4');
      expect((sent!['holes'] as List).length, 1);
      // 위 메뉴 → 사진 위에 직접 따라 찍기 → 빈 그림(되돌리기로 살린다)
      await tap(tester, 'sk_menu');
      await tap(tester, 'sk_m_trace');
      expect(status(tester), startsWith('"AI로 읽기"를 눌러 보십시오'));
      await tap(tester, 'sk_undo');
      expect(status(tester), startsWith('변의 숫자를 눌러 길이를 넣습니다'));
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

    testWidgets('그린 것은 다시 열어도 남는다(닫은 것까지)', (tester) async {
      await open(tester);
      await drawRect(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      await open(tester);
      expect(status(tester), startsWith('변 이름(변 1…)을 눌러'));
    });
  });

  testWidgets('철판 가공 첫 화면: 세 갈래, 마지막에 하던 것 "이어서"', (tester) async {
    SharedPreferences.setMockInitialValues({
      PlatePage.draftKeyOf(true): '{"sh":"z","lbl":"Z자 3t · 138.5 × 100"}',
      PlateSketchPage.draftKey:
          '{"pts":[[0,0],[300,0],[300,150],[0,150]],"scaled":true,"closed":true}',
    });
    await tester.pumpWidget(const MaterialApp(home: PlateHomePage()));
    await tester.pumpAndSettle();
    expect(find.text('레이저 절단'), findsOneWidget);
    expect(find.text('절단 + 절곡'), findsOneWidget);
    expect(find.text('손그림 읽어 만들기'), findsOneWidget);
    expect(find.byKey(const Key('ph_cut_last')), findsNothing);
    expect(find.text('이어서: Z자 3t · 138.5 × 100'), findsOneWidget);
    expect(find.text('이어서: 300 × 150 · 꼭짓점 4개'), findsOneWidget);
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
    // 들어갔다 나오면 레이저 절단도 "이어서"가 생긴다
    expect(find.text('이어서: 평판 3t · 200 × 100'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ph_sketch')));
    await tester.pumpAndSettle();
    expect(find.text('손그림 읽어 만들기'), findsOneWidget);
    expect(find.byKey(const Key('sk_canvas')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
