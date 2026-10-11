// 형강 브라켓 제작도(10-10, 10-11 개편): 모양·이음별 자를 길이, 가새 긴 변·짧은 변·각도, 구멍 위치(토막 기준 끝·게이지),
// 베이스 판, 무게·볼트·원자재 본수, 지시서 그림·PDF. 화면 시험은 steel_bracket_page_test.dart.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/steel_bracket/bracket_calc.dart';
import 'package:tubing_calculator/src/presentation/steel_bracket/bracket_painter.dart';
import 'package:tubing_calculator/src/presentation/steel_bracket/bracket_pdf.dart';
import 'package:tubing_calculator/src/presentation/steel_bracket/bracket_piece_drawing.dart';

BracketPlan _l({
  BracketJoint joint = BracketJoint.postThrough,
  HoleRow post = const HoleRow(),
  HoleRow arm = const HoleRow(),
  int sets = 1,
}) => bracketPlan(
  BracketInput(
    shape: BracketShape.l,
    spec: '앵글 50x50x5',
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
    test('ㄱ자: 이음에 따라 짧아지는 토막(맞대기는 따내기 혀까지 자를 길이)', () {
      final post = _l();
      expect(_len(post, '기둥'), 300);
      // 기둥 통과: 가로대 세운 변 250, 위 변은 기둥 벽 쪽 변(두께 5)까지 들어가 295로 자르고 세운 변 45 따냄(10-11 현장 방식)
      expect(_len(post, '가로대'), 295);
      expect(
        post.pieces.firstWhere((x) => x.name == '가로대').ends,
        contains('기둥 쪽 끝 45 따냄'),
      );
      final arm = _l(joint: BracketJoint.armThrough);
      expect(_len(arm, '기둥'), 295);
      expect(_len(arm, '가로대'), 300);
      final miter = _l(joint: BracketJoint.miter);
      expect(_len(miter, '기둥'), 300);
      expect(_len(miter, '가로대'), 300);
      // 연귀는 짧은 쪽도 적는다(바깥 300, 안쪽 250)
      expect(miter.pieces.first.short, closeTo(250, 1e-9));
      expect(miter.pieces.first.ends, contains('위 끝 45°'));
      expect(miter.pieces.first.ends, contains('아래 끝 직각'));
      // 앵글 50x50x5 = 3.77kg/m → (0.3 + 0.295) × 3.77(자를 길이로)
      expect(post.kgPerSet, closeTo(0.595 * 3.77, 1e-9));
      expect(post.ok, isTrue);
    });

    test('삼각: 가새 45°이면 긴 변 = 중심선 + 부재 폭, 짧은 변 = 중심선 − 부재 폭', () {
      final p = bracketPlan(
        const BracketInput(
          shape: BracketShape.brace,
          spec: '앵글 50x50x5',
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
          a: 300,
          b: 300,
          braceA: 80,
          braceB: 80,
        ),
      );
      expect(tight.problems.join(), contains('모서리에 너무 가깝습니다'));
    });

    test('구멍: 토막 끝에서 잰 거리·게이지, 부재 밖이면 알림', () {
      final p = _l(
        post: const HoleRow(count: 2, dia: 13.5, first: 80, pitch: 150),
        arm: const HoleRow(count: 1, dia: 11, first: 40),
        sets: 3,
      );
      final post = p.pieces.firstWhere((x) => x.name == '기둥');
      expect(post.holes.map((h) => h.fromEnd), [80, 230]);
      // 앵글 50x50x5 붙는 변: 등(두께 5)에서 평평한 곳 가운데 = (50 + 5) / 2
      expect(post.holes.first.z, 27.5);
      expect(post.holeFace, '벽 붙는 면');
      expect(
        p.pieces.firstWhere((x) => x.name == '가로대').holes.single.fromEnd,
        40,
      );
      expect(p.wallHoles, {13.5: 6});
      expect(p.armHoles, {11: 3});
      // 가로대 통과면 기둥 벽 쪽 변이 가로대 위 변 밑(위에서 5)까지 올라가 구멍은 그 끝에서 잰다(80 − 5)
      final arm = _l(
        joint: BracketJoint.armThrough,
        post: const HoleRow(count: 2, dia: 13.5, first: 80, pitch: 150),
      );
      expect(
        arm.pieces
            .firstWhere((x) => x.name == '기둥')
            .holes
            .map((h) => h.fromEnd),
        [75, 225],
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

    test('문형: 이음·베이스 판에 따라 기둥·가로대 길이, 판 구멍(판 왼쪽 위에서)', () {
      BracketPlan f(BracketJoint j, {bool plate = true}) => bracketPlan(
        BracketInput(
          shape: BracketShape.frame,
          spec: '앵글 50x50x5',
          a: 600,
          b: 800,
          joint: j,
          basePlate: plate,
        ),
      );
      final top = f(BracketJoint.armThrough);
      // 가로대 통과: 기둥 바깥 변이 가로대 위 변 밑까지(따내기 45)
      expect(_len(top, '기둥'), 800 - 9 - 50 + 45);
      expect(top.pieces.firstWhere((x) => x.name == '기둥').qty, 2);
      expect(_len(top, '가로대'), 600);
      final between = f(BracketJoint.postThrough);
      expect(_len(between, '기둥'), 791);
      // 기둥 사이 500 + 양 끝 혀 45씩
      expect(_len(between, '가로대'), 590);
      final noPlate = f(BracketJoint.armThrough, plate: false);
      expect(_len(noPlate, '기둥'), 795);
      expect(noPlate.plate, isNull);
      final pl = top.plate!;
      expect(pl.qty, 2);
      expect(pl.holes.length, 4);
      expect(pl.holes.first, const Offset(25, 25));
      expect(pl.kgEach, closeTo(150 * 150 * 9 * 7.85e-6, 1e-9));
      expect(top.anchorHoles, {13.5: 8});
      final plPiece = top.pieces.firstWhere(
        (x) => x.kind == BracketPieceKind.plate,
      );
      expect(plPiece.ks, 'PL-9×150×150');
      expect(plPiece.qty, 2);
      // 판이 작아 구멍이 기둥 자리와 겹치면 알림
      final small = bracketPlan(
        const BracketInput(
          shape: BracketShape.frame,
          spec: '앵글 50x50x5',
          a: 600,
          b: 800,
          basePlate: true,
          base: BracketPlateInput(w: 90, l: 90, edge: 20),
        ),
      );
      expect(small.problems.join(), contains('기둥 자리와 겹칩니다'));
    });

    test('T자: 가로대가 기둥 위, 가로대 0이면 기둥만', () {
      final t = bracketPlan(
        const BracketInput(
          shape: BracketShape.tee,
          spec: '각파이프 50x50x2.3',
          a: 400,
          b: 1000,
          basePlate: true,
        ),
      );
      expect(_len(t, '가로대'), 400);
      expect(_len(t, '기둥'), 1000 - 9 - 50);
      final only = bracketPlan(
        const BracketInput(
          shape: BracketShape.tee,
          spec: '각파이프 50x50x2.3',
          a: 0,
          b: 1000,
          basePlate: true,
        ),
      );
      expect(only.pieces.map((x) => x.name), ['기둥', '베이스 판']);
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
          a: 300,
          b: 7000,
        ),
      );
      expect(long.problems.join(), contains('원자재 6000mm보다 긴 토막'));
    });

    test('그림 폭은 흔한 방향의 폭, 모르는 규격은 넣은 폭으로 그리고 무게에서 뺌', () {
      expect(bracketMemberWidth('찬넬 100x50x5'), 100);
      expect(bracketMemberWidth('평철 65x6'), 65);
      expect(bracketMemberWidth('이상한것'), isNull);
      final p = bracketPlan(
        const BracketInput(
          shape: BracketShape.l,
          spec: '스텐 50x50',
          fallbackD: 50,
          a: 300,
          b: 300,
        ),
      );
      expect(p.weightKnown, isFalse);
      expect(p.notes.join(), contains('무게에서 뺐습니다'));
      expect(_len(p, '가로대'), 250);
      // 폭도 없으면 막는다
      final none = bracketPlan(
        const BracketInput(
          shape: BracketShape.l,
          spec: '스텐 50x50',
          a: 300,
          b: 300,
        ),
      );
      expect(none.problems.join(), contains('읽지 못했습니다'));
    });
  });

  group('그림·지시서', () {
    testWidgets('조립도·부재도가 PNG로 떠지고 표제란·부재도가 든 PDF가 만들어진다', (tester) async {
      final plan = bracketPlan(
        const BracketInput(
          shape: BracketShape.brace,
          spec: '앵글 50x50x5',
          a: 300,
          b: 300,
          braceA: 210,
          braceB: 210,
          postHoles: HoleRow(count: 2, dia: 13.5, first: 80, pitch: 150),
        ),
      );
      late Uint8List png;
      late Uint8List piece;
      late Uint8List pdf;
      await tester.runAsync(() async {
        png = await renderBracketPng(plan.drawing, width: 700, height: 450);
        piece = await renderBracketPng(
          bracketPieceDrawing(plan.pieces.first, plate: plan.plate),
          width: 700,
          height: 380,
        );
        pdf = await buildBracketPdf(
          BracketPdfInput(
            title: 'TEST',
            titleBlock: const [
              ('도면 번호', 'BR-01'),
              ('개정', '0'),
              ('재질', 'SS275'),
            ],
            summary: const [('모양', '삼각')],
            drawingPng: png,
            moreDrawings: [('부재도 ① 기둥', piece)],
            moreAfterSections: true,
            author: '홍길동',
            sections: const [
              BracketPdfSection('자를 것', ['기둥 300']),
            ],
            notes: const [],
          ),
        );
      });
      expect(png.sublist(1, 4), [0x50, 0x4E, 0x47]); // PNG
      expect(piece.sublist(1, 4), [0x50, 0x4E, 0x47]);
      expect(String.fromCharCodes(pdf.sublist(0, 4)), '%PDF');
    });
  });
}
