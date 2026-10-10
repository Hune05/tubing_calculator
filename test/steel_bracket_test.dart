// 형강 브라켓 제작도(10-10): 모양·이음별 자를 길이, 가새 긴 변·짧은 변·각도, 구멍 위치, 베이스 판,
// 무게·볼트·원자재 본수, 화면(모양 바꾸기·카톡 글·입력 남기기), 지시서 그림·PDF.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/steel_bracket/bracket_calc.dart';
import 'package:tubing_calculator/src/presentation/steel_bracket/bracket_page.dart';
import 'package:tubing_calculator/src/presentation/steel_bracket/bracket_painter.dart';
import 'package:tubing_calculator/src/presentation/steel_bracket/bracket_pdf.dart';
import 'formula_flat.dart';

BracketPlan _l({
  BracketJoint joint = BracketJoint.postThrough,
  HoleRow post = const HoleRow(),
  HoleRow arm = const HoleRow(),
  int sets = 1,
}) => bracketPlan(
  BracketInput(
    shape: BracketShape.l,
    spec: '앵글 50x50x5',
    d: 50,
    a: 300,
    b: 300,
    joint: joint,
    postHoles: post,
    armHoles: arm,
    sets: sets,
  ),
);

double _len(BracketPlan p, String name) =>
    p.pieces.firstWhere((x) => x.name == name).length;

void main() {
  group('계산', () {
    test('ㄱ자: 이음에 따라 짧아지는 토막', () {
      final post = _l();
      expect(_len(post, '기둥'), 300);
      expect(_len(post, '가로대'), 250);
      final arm = _l(joint: BracketJoint.armThrough);
      expect(_len(arm, '기둥'), 250);
      expect(_len(arm, '가로대'), 300);
      final miter = _l(joint: BracketJoint.miter);
      expect(_len(miter, '기둥'), 300);
      expect(_len(miter, '가로대'), 300);
      expect(miter.pieces.first.ends, contains('45°'));
      // 앵글 50x50x5 = 3.77kg/m → (0.3 + 0.25) × 3.77
      expect(post.kgPerSet, closeTo(0.55 * 3.77, 1e-9));
      expect(post.ok, isTrue);
    });

    test('삼각: 가새 45°이면 긴 변 = 중심선 + 부재 폭, 짧은 변 = 중심선 − 부재 폭', () {
      final p = bracketPlan(
        const BracketInput(
          shape: BracketShape.brace,
          spec: '앵글 50x50x5',
          d: 50,
          a: 300,
          b: 300,
          braceA: 210,
          braceB: 210,
        ),
      );
      final brace = p.pieces.firstWhere((x) => x.name == '가새');
      final lc = math.sqrt(2) * 160;
      expect(p.braceAngle, closeTo(45, 1e-9));
      expect(brace.length, closeTo(lc + 50, 1e-6));
      expect(brace.short, closeTo(lc - 50, 1e-6));
      expect(brace.ends, contains('가로대 쪽 45°'));
      expect(brace.ends, contains('기둥 쪽 45°'));
      expect(p.ok, isTrue);
      expect(p.notes, isEmpty);
    });

    test('삼각: 기울기가 다르면 각도절단기 각도도 다르고, 30~60° 밖이면 알림', () {
      final p = bracketPlan(
        const BracketInput(
          shape: BracketShape.brace,
          spec: '앵글 50x50x5',
          d: 50,
          a: 400,
          b: 300,
          braceA: 350,
          braceB: 150,
        ),
      );
      // atan(100 / 300) ≈ 18.4°
      expect(p.braceAngle, closeTo(math.atan(100 / 300) * 180 / math.pi, 1e-9));
      expect(p.notes.join(), contains('보통 30~60°'));
      final brace = p.pieces.firstWhere((x) => x.name == '가새');
      final t = math.atan(100 / 300);
      final ext = 25 * (1 / math.tan(t) + math.tan(t));
      expect(
        brace.length,
        closeTo(math.sqrt(300 * 300 + 100 * 100) + ext, 1e-6),
      );
      // 가새가 모서리에 붙으면 알림
      final tight = bracketPlan(
        const BracketInput(
          shape: BracketShape.brace,
          spec: '앵글 50x50x5',
          d: 50,
          a: 300,
          b: 300,
          braceA: 80,
          braceB: 80,
        ),
      );
      expect(tight.problems.join(), contains('모서리에 너무 가깝습니다'));
    });

    test('구멍: 토막 끝에서 잰 거리, 부재 밖이면 알림', () {
      final p = _l(
        post: const HoleRow(count: 2, dia: 13.5, first: 80, pitch: 150),
        arm: const HoleRow(count: 1, dia: 11, first: 40),
        sets: 3,
      );
      final post = p.pieces.firstWhere((x) => x.name == '기둥');
      expect(post.holes.map((h) => h.fromEnd), [80, 230]);
      expect(
        p.pieces.firstWhere((x) => x.name == '가로대').holes.single.fromEnd,
        40,
      );
      expect(p.boltHoles, {13.5: 6, 11: 3});
      // 가로대 통과면 기둥 토막이 가로대 밑에서 시작해 50씩 줄어든다
      final arm = _l(
        joint: BracketJoint.armThrough,
        post: const HoleRow(count: 2, dia: 13.5, first: 80, pitch: 150),
      );
      expect(
        arm.pieces
            .firstWhere((x) => x.name == '기둥')
            .holes
            .map((h) => h.fromEnd),
        [30, 180],
      );
      final out = _l(
        post: const HoleRow(count: 2, dia: 13.5, first: 80, pitch: 250),
      );
      expect(out.problems.join(), contains('기둥 구멍 2번이 부재 밖으로'));
    });

    test('삼각: 기둥 구멍이 가새 끝 자리에 걸리면 알림', () {
      BracketPlan b(double pitch) => bracketPlan(
        BracketInput(
          shape: BracketShape.brace,
          spec: '앵글 50x50x5',
          d: 50,
          a: 300,
          b: 300,
          braceA: 210,
          braceB: 210,
          postHoles: HoleRow(count: 2, dia: 13.5, first: 80, pitch: pitch),
        ),
      );
      // 가새 끝은 위에서 210 ± 25√2(≈174.6~245.4)
      expect(
        b(150).notes.join(),
        contains('가새 끝 자리(위에서 174.6~245.4mm)에 기둥 구멍이 걸립니다(230mm)'),
      );
      expect(b(180).notes.join(), isNot(contains('가새 끝 자리')));
    });

    test('문형: 이음·베이스 판에 따라 기둥·가로대 길이, 판 구멍', () {
      BracketPlan f(BracketJoint j, {bool plate = true}) => bracketPlan(
        BracketInput(
          shape: BracketShape.frame,
          spec: '앵글 50x50x5',
          d: 50,
          a: 600,
          b: 800,
          joint: j,
          plate: plate,
        ),
      );
      final top = f(BracketJoint.armThrough);
      expect(_len(top, '기둥'), 800 - 9 - 50);
      expect(top.pieces.firstWhere((x) => x.name == '기둥').qty, 2);
      expect(_len(top, '가로대'), 600);
      final between = f(BracketJoint.postThrough);
      expect(_len(between, '기둥'), 791);
      expect(_len(between, '가로대'), 500);
      final noPlate = f(BracketJoint.armThrough, plate: false);
      expect(_len(noPlate, '기둥'), 750);
      expect(noPlate.plate, isNull);
      final pl = top.plate!;
      expect(pl.qty, 2);
      expect(pl.holes.length, 4);
      expect(pl.holes.first, const Offset(-50, -50));
      expect(pl.kgEach, closeTo(150 * 150 * 9 * 7.85e-6, 1e-9));
      expect(top.anchorHoles, {13.5: 8});
      // 판이 작아 구멍이 기둥 자리와 겹치면 알림
      final small = bracketPlan(
        const BracketInput(
          shape: BracketShape.frame,
          spec: '앵글 50x50x5',
          d: 50,
          a: 600,
          b: 800,
          plate: true,
          plateSize: 90,
          plateEdge: 20,
        ),
      );
      expect(small.problems.join(), contains('기둥 자리와 겹칩니다'));
    });

    test('T자: 가로대가 기둥 위, 가로대 0이면 기둥만', () {
      final t = bracketPlan(
        const BracketInput(
          shape: BracketShape.tee,
          spec: '각파이프 50x50x2.3',
          d: 50,
          a: 400,
          b: 1000,
          plate: true,
        ),
      );
      expect(_len(t, '가로대'), 400);
      expect(_len(t, '기둥'), 1000 - 9 - 50);
      final only = bracketPlan(
        const BracketInput(
          shape: BracketShape.tee,
          spec: '각파이프 50x50x2.3',
          d: 50,
          a: 0,
          b: 1000,
          plate: true,
        ),
      );
      expect(only.pieces.map((x) => x.name), ['기둥']);
      expect(_len(only, '기둥'), 991);
    });

    test('원자재 본수와 너무 긴 토막', () {
      final p = _l(sets: 10); // 300 × 10 + 250 × 10 + 톱날 2 × 20 = 5540 → 6m 한 본
      expect(p.stock['앵글 50x50x5']!.barCount, 1);
      final many = _l(sets: 12); // 6648 → 두 본
      expect(many.stock['앵글 50x50x5']!.barCount, 2);
      final long = bracketPlan(
        const BracketInput(
          shape: BracketShape.l,
          spec: '앵글 50x50x5',
          d: 50,
          a: 300,
          b: 7000,
        ),
      );
      expect(long.problems.join(), contains('원자재 6000mm보다 긴 토막'));
    });

    test('부재 폭은 규격 첫 치수, 모르는 규격은 무게에서 뺌', () {
      expect(bracketMemberWidth('찬넬 100x50x5'), 100);
      expect(bracketMemberWidth('평철 65x6'), 65);
      expect(bracketMemberWidth('이상한것'), isNull);
      final p = bracketPlan(
        const BracketInput(
          shape: BracketShape.l,
          spec: '스텐 50x50',
          d: 50,
          a: 300,
          b: 300,
        ),
      );
      expect(p.weightKnown, isFalse);
      expect(p.notes.join(), contains('중량을 몰라'));
    });
  });

  group('화면', () {
    setUpAll(expandFormulaCards);
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> open(
      WidgetTester tester, {
      Future<void> Function(String)? share,
    }) async {
      tester.view.physicalSize = const Size(800, 16000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: share == null ? const BracketPage() : BracketPage(share: share),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> tap(WidgetTester tester, String key) async {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
    }

    testWidgets('기본 ㄱ자 → 삼각 → 문형 → T자', (tester) async {
      await open(tester);
      expect(find.text('기둥 300 · 가로대 250'), findsOneWidget);
      expect(find.byKey(const Key('br_view')), findsOneWidget);
      // 기둥 구멍 기본 2개(80, 230)
      expect(
        find.textContaining('기둥 구멍 φ13.5 (위 끝에서): 80 · 260mm'),
        findsOneWidget,
      );
      await tap(tester, 'br_shape_1');
      expect(find.text('기둥 300 · 가로대 250 · 가새 276.3'), findsOneWidget);
      expect(find.textContaining('가새 기울기 45°'), findsOneWidget);
      await tap(tester, 'br_shape_2');
      // 폭 300 · 높이 300, 가로대 통과 아님(기둥 통과) + 판 9 → 기둥 291, 가로대 200
      expect(find.text('기둥 291 · 가로대 200'), findsOneWidget);
      expect(find.textContaining('베이스 판 150 × 150 × 9t × 2장'), findsWidgets);
      await tap(tester, 'br_joint_1');
      expect(find.text('기둥 241 · 가로대 300'), findsOneWidget);
      await tap(tester, 'br_shape_3');
      expect(find.text('기둥 241 · 가로대 300'), findsOneWidget);
      expect(find.byKey(const Key('br_joint_0')), findsNothing);
    });

    testWidgets('규격 종류를 바꾸면 그 종류 규격과 부재 폭, 카톡 글, 입력 남기기', (tester) async {
      String? sent;
      await open(tester, share: (t) async => sent = t);
      await tap(tester, 'br_cat_1'); // 찬넬
      expect(find.textContaining('찬넬 100x50x5'), findsWidgets);
      await tap(tester, 'br_cat_0'); // 앵글로 되돌림
      await tester.enterText(find.byKey(const Key('br_a')), '400');
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('br_sets')), '4');
      await tester.pumpAndSettle();
      expect(find.text('기둥 300 · 가로대 350'), findsOneWidget);
      await tap(tester, 'br_share');
      expect(sent, startsWith('[형강 브라켓] ㄱ자 · 앵글 50x50x5 · 4개'));
      expect(sent, contains('가로대 350mm × 4개'));
      expect(sent, contains('볼트 구멍 φ13.5 8개'));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      await open(tester);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('br_a')))
            .controller!
            .text,
        '400',
      );
    });

    testWidgets('지시서 그림이 PNG로 떠지고 PDF가 만들어진다', (tester) async {
      final plan = bracketPlan(
        const BracketInput(
          shape: BracketShape.brace,
          spec: '앵글 50x50x5',
          d: 50,
          a: 300,
          b: 300,
          braceA: 210,
          braceB: 210,
          postHoles: HoleRow(count: 2, dia: 13.5, first: 80, pitch: 150),
        ),
      );
      late Uint8List png;
      late Uint8List pdf;
      await tester.runAsync(() async {
        png = await renderBracketPng(plan.drawing, width: 700, height: 450);
        pdf = await buildBracketPdf(
          BracketPdfInput(
            title: 'TEST',
            summary: const [('모양', '삼각')],
            drawingPng: png,
            sections: const [
              BracketPdfSection('자를 것', ['기둥 300']),
            ],
            notes: const [],
          ),
        );
      });
      expect(png.sublist(1, 4), [0x50, 0x4E, 0x47]); // PNG
      expect(String.fromCharCodes(pdf.sublist(0, 4)), '%PDF');
    });
  });
}
