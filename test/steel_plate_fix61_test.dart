// 철판 가공 점검 61~71(10-11, 사용자: "전부 진행해"): 내보내는 글·PDF·DXF의 값과 기준, 스케치 넘김, AI 문구.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/utils/ai_polish.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_calc.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_dxf.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_page.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_sketch_model.dart';

String _f1(double v) {
  var s = v.toStringAsFixed(1);
  if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
  return s;
}

void main() {
  group('계산·파일', () {
    test('61: 코너·홀 글은 소수 둘째 자리까지', () {
      expect(const PlateCorner(PlateCornerKind.round, 1.25).label, 'R1.25');
      final p = platePlan(
        const PlateInput(
          shape: PlateShape.flat,
          t: 3,
          length: 100,
          width: 50,
          holes: [PlateHoleSpec(u: 20, v: 20, dia: 6.35)],
        ),
      );
      expect(plateHoleKind(p.holes.single), 'φ6.35');
    });

    test('62: DXF에서 판 밖 홀은 뺀다', () {
      final p = platePlan(
        const PlateInput(
          shape: PlateShape.flat,
          t: 3,
          length: 200,
          width: 100,
          holes: [
            PlateHoleSpec(u: 50, v: 50, dia: 10),
            PlateHoleSpec(u: 250, v: 50, dia: 10),
            PlateHoleSpec(u: 198, v: 50, dia: 10),
          ],
        ),
      );
      final circles = RegExp(
        r'\nCIRCLE\n',
      ).allMatches(plateDxf(p, thickness: 3));
      expect(circles.length, 1);
    });

    test('67: DXF 층 정의(CUT 흰 실선, BEND 빨간 파선, DIM 초록 일점 쇄선), 센터선은 설정 따라', () {
      final p = platePlan(
        const PlateInput(shape: PlateShape.l, t: 3, legs: [50, 50], width: 100),
      );
      final d = plateDxf(p, thickness: 3);
      expect(d, contains('TABLES'));
      expect(d, contains('LAYER\n2\nBEND\n70\n0\n62\n1\n6\nDASHED'));
      expect(d, contains('LAYER\n2\nDIM\n70\n0\n62\n3\n6\nCENTER'));
      expect(d, contains('\nCL\n'));
      expect(
        plateDxf(p, thickness: 3, centerLines: false),
        isNot(contains('\nCL\n')),
      );
    });

    test('63: 스케치 두께 1.25는 1.25 그대로 넘긴다', () {
      final s = PlateSketch(
        pts: const [
          Offset(0, 0),
          Offset(200, 0),
          Offset(200, 100),
          Offset(0, 100),
        ],
        ids: const [0, 1, 2, 3],
        nextId: 4,
        dims: const {0: 200, 1: 100},
        frame: const Rect.fromLTWH(-20, -20, 240, 140),
        scaled: true,
        closed: true,
        thickness: 1.25,
      );
      expect(s.toPlateMap()!['t'], '1.25');
    });

    test('70: 통신이 없을 때(unavailable) AI 문구는 통신 확인', () {
      expect(aiPolishErrorMessage('unavailable', null), contains('통신을 확인'));
      expect(
        aiPolishErrorMessage('deadline-exceeded', null),
        contains('통신을 확인'),
      );
    });
  });

  group('화면', () {
    Future<String?> kakao(
      WidgetTester tester, {
      bool bend = true,
      Map<String, Object?>? initial,
      Map<String, Object> prefs = const {},
      bool anyway = false,
    }) async {
      SharedPreferences.setMockInitialValues(prefs);
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      String? sent;
      await tester.pumpWidget(
        MaterialApp(
          home: PlatePage(
            bend: bend,
            share: (s) async => sent = s,
            initial: initial,
          ),
        ),
      );
      await tester.pumpAndSettle();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      });
      await tester.tap(find.byKey(const Key('pl_tab_send')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('pl_send_kakao')));
      await tester.tap(find.byKey(const Key('pl_send_kakao')));
      await tester.pumpAndSettle();
      if (anyway) {
        await tester.tap(find.byKey(const Key('pl_send_anyway')));
        await tester.pumpAndSettle();
      }
      return sent;
    }

    testWidgets('61: 1.25T·1면 50.25·내R은 반올림하지 않고 보낸다', (tester) async {
      final s = await kakao(
        tester,
        initial: {
          'sh': 'l',
          't': '1.25',
          'l1': '50.25',
          'l2': '50',
          'wid': '100',
        },
      );
      expect(s, contains('철판 1.25T'));
      expect(s, contains('1면 50.25'));
      expect(s, contains('내R 1.25'));
      // 69·71: UP/DOWN 뜻, ㄱ자 각도 말, 절곡선은 전개도 자리라고
      expect(s, contains('UP·DOWN은 전개도·DXF를 위에서 본 쪽'));
      expect(s, contains('절곡 각도 90°'));
      expect(s, contains('절곡 1: 전개도 왼쪽 끝에서'));
    });

    testWidgets('62: 만들 수 없는 곳이 있으면 보내기 전에 묻는다', (tester) async {
      final s = await kakao(
        tester,
        bend: false,
        initial: {
          'sh': 'flat',
          't': '3',
          'len': '200',
          'wid': '100',
          'holes': [const PlateHoleSpec(u: 250, v: 50, dia: 10).toJson()],
        },
      );
      expect(s, isNull);
      expect(find.text('만들 수 없는 곳이 있습니다'), findsOneWidget);
      await tester.tap(find.byKey(const Key('pl_send_anyway')));
      await tester.pumpAndSettle();
    });

    testWidgets('64: 돌린 좌표 입력은 꼭짓점·홀을 같은(돌린) 기준으로, 돌렸다고 쓴다', (tester) async {
      const pts = [
        Offset(0, 0),
        Offset(200, 0),
        Offset(200, 80),
        Offset(120, 150),
        Offset(0, 150),
      ];
      final p = platePlan(
        const PlateInput(
          shape: PlateShape.free,
          t: 3,
          points: pts,
          rotQ: 1,
          holes: [PlateHoleSpec(u: 20, v: 20, dia: 9)],
        ),
      );
      final s = await kakao(
        tester,
        bend: false,
        prefs: {
          PlatePage.draftKeyOf(false): jsonEncode({
            'sh': 'free',
            't': '3',
            'pts': '0,0\n200,0\n200,80\n120,150\n0,150',
            'rot': 1,
            'holes': [const PlateHoleSpec(u: 20, v: 20, dia: 9).toJson()],
          }),
        },
      );
      expect(s, contains('판을 90° 돌린 모양으로 보냅니다'));
      String xy(Offset q) {
        final d = p.toDisplay(q) - Offset(p.minX, p.minY);
        return '${_f1(d.dx)},${_f1(d.dy)}';
      }

      expect(s, contains('꼭짓점(판 왼쪽 아래에서 가로,세로): ${pts.map(xy).join(' / ')}'));
      final h = p.holes.single.c - Offset(p.minX, p.minY);
      expect(s, contains('홀 1 φ9: ${_f1(h.dx)} · ${_f1(h.dy)}'));
      expect(s, contains('홀 1개(판 왼쪽 아래에서 가로 · 세로)'));
    });

    testWidgets('65: 직접 절곡 가로선은 전개도가 돌린 모양이라고 쓴다', (tester) async {
      final s = await kakao(
        tester,
        initial: {
          'sh': 'custom',
          't': '3',
          'pts': '0,0\n200,0\n200,100\n0,100',
          'blh': true,
          'bl': [const PlateBendSpec(at: 40).toJson()],
        },
      );
      expect(s, contains('절곡선 자리(바깥 치수, 아래 끝에서) 40 UP 90°'));
      expect(s, contains('전개도·DXF: 그린 판을 시계 방향 90° 돌린 모양'));
    });

    testWidgets('66: 스케치에서 넘기면 앞 작업 품명·수량은 비우고 재질·두께는 알린다', (tester) async {
      final s = await kakao(
        tester,
        bend: false,
        prefs: {
          PlatePage.draftKeyOf(false): jsonEncode({
            'sh': 'flat',
            'mat': 'aluminum',
            't': '6',
            'jn': 'A동 브라켓',
            'n': '20',
          }),
        },
        initial: {'sh': 'free', 'pts': '0,0\n200,0\n200,100\n0,100'},
      );
      expect(s, startsWith('[철판 가공] 좌표 입력 · 알루미늄 6T · 1장'));
      expect(s, isNot(contains('A동 브라켓')));
    });

    testWidgets('66: 넘겨 받은 알림에 앞 값 재질·두께', (tester) async {
      SharedPreferences.setMockInitialValues({
        PlatePage.draftKeyOf(false): jsonEncode({
          'sh': 'flat',
          'mat': 'aluminum',
          't': '6',
        }),
      });
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: PlatePage(
            bend: false,
            share: (_) async {},
            initial: const {'sh': 'free', 'pts': '0,0\n200,0\n200,100\n0,100'},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('재질·두께는 앞 값(알루미늄 6T)'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('71: 레이저 절단은 "판 왼쪽 아래", 원형은 외경 사각 기준, 좌표 따내기는 앞 변·다음 변', (
      tester,
    ) async {
      final s = await kakao(
        tester,
        bend: false,
        initial: {
          'sh': 'free',
          't': '3',
          'pts': '0,0\n200,0,n20x15\n200,100\n0,100',
          'holes': [const PlateHoleSpec(u: 50, v: 50, dia: 9).toJson()],
        },
      );
      expect(s, contains('홀 1개(판 왼쪽 아래에서 가로 · 세로)'));
      expect(s, isNot(contains('전개도')));
      expect(s, contains('따내기 앞 변 20 × 다음 변 15'));
    });

    testWidgets('71: 원형 홀 기준', (tester) async {
      final s = await kakao(
        tester,
        bend: false,
        initial: {
          'sh': 'circle',
          't': '3',
          'cd': '150',
          'holes': [const PlateHoleSpec(u: 75, v: 120, dia: 9).toJson()],
        },
      );
      expect(s, contains('홀 1개(외경을 감싸는 사각의 왼쪽 아래에서 가로 · 세로)'));
    });
  });
}
