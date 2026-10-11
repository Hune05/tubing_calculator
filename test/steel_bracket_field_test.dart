// 형강 브라켓 현장 방식(10-11 사용자: "앵글 형태 때문에 구멍이 뻥뻥 뚫리는데 현업에서는 가공하거나 그라인더로 잘라내서
// 작업", "가새는 웬만하면 평철"): 맞대기 따내기, V컷 꺾기(한 본), 가새 평철 맞춤, 저장 값 판 2.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/steel_bracket/bracket_3d.dart';
import 'package:tubing_calculator/src/presentation/steel_bracket/bracket_calc.dart';
import 'package:tubing_calculator/src/presentation/steel_bracket/bracket_form.dart';
import 'package:tubing_calculator/src/presentation/steel_bracket/bracket_piece_drawing.dart';

BracketPiece _p(BracketPlan p, String name) =>
    p.pieces.firstWhere((x) => x.name == name);

void main() {
  group('맞대기 따내기', () {
    test('앵글끼리: 날개 쪽만 상대 벽 쪽 변까지 들어간다(깊이 구간)', () {
      final a = BracketProfile.parse('앵글 50x50x5');
      final post = a.view(0, BracketRole.wall),
          arm = a.view(0, BracketRole.top);
      // 앵글 세운 변(두께 5) 자리는 그대로, 그 뒤 45는 상대 벽 쪽 변(5)까지 45 더
      expect(bracketNotchExt(post, arm), [(z0: 5.0, z1: 50.0, ext: 45.0)]);
      // 평철·각파이프는 따내기 없음
      final fb = BracketProfile.parse('평철 50x6').view(1, BracketRole.top);
      expect(bracketNotchExt(post, fb), isEmpty);
      final pipe = BracketProfile.parse(
        '각파이프 50x50x2.3',
      ).view(0, BracketRole.wall);
      expect(bracketNotchExt(pipe, arm), isEmpty);
    });

    test('ㄱ자 기둥 통과: 가로대 자를 길이 295(혀 45), 부재도 붙는 면은 따낸 계단, 입체도 혀', () {
      final p = bracketPlan(
        const BracketInput(
          shape: BracketShape.l,
          spec: '앵글 50x50x5',
          a: 300,
          b: 300,
          armHoles: HoleRow(count: 1, dia: 13.5, first: 50),
        ),
      );
      final arm = _p(p, '가로대');
      expect(arm.length, 295);
      expect(arm.short, isNull);
      expect(arm.ends, '양 끝 직각 · 기둥 쪽 끝 45 따냄(부재도)');
      // 구멍은 가로대 끝(혀 반대쪽)에서 그대로
      expect(arm.holes.single.fromEnd, 50);
      final m = arm.member!;
      expect(m.extEndMax, 45);
      expect(m.farLength, 250); // 세운 변은 250
      // 부재도: 붙는 면 모양에 따낸 계단, 이어 잰 치수에 45
      // 옆 모양 = 따내기 전 모양 + 남는 혀(앵글은 띠 하나), 그 아래 붙는 면
      final d = bracketPieceDrawing(arm);
      expect(d.polys.length, 3);
      final tongue = d.polys[1].pts;
      final tx = tongue.map((q) => q.dx);
      expect(tx.reduce(math.max) - tx.reduce(math.min), closeTo(45, 1e-6));
      expect(d.polys[2].pts.length, greaterThan(4));
      expect(d.dims.any((x) => x.text == '45'), isTrue);
      // 조립도: 혀 숨은선 셋 + 가로대 위 면 구멍 숨은선 둘
      final hidden = p.drawing.lines.where(
        (l) => l.style == BracketLineStyle.hidden,
      );
      expect(hidden.length, 5);
      // 입체: 앵글 둘이면 조각 4 + 혀 나눔 1 → 면 6 × 5
      expect(bracket3dMesh(p).length, 30);
    });

    test('가로대 통과·문형·2단: 기둥·가로대에 혀, 혀 끝에서 구멍', () {
      final a = bracketPlan(
        const BracketInput(
          shape: BracketShape.l,
          spec: '앵글 50x50x5',
          a: 300,
          b: 300,
          joint: BracketJoint.armThrough,
          postHoles: HoleRow(count: 1, dia: 13.5, first: 100),
        ),
      );
      final post = _p(a, '기둥');
      expect(post.length, 295);
      expect(post.ends, contains('위 끝 45 따냄'));
      expect(post.holes.single.fromEnd, 95); // 위 바깥 100 − 혀 끝 5
      final f = bracketPlan(
        const BracketInput(
          shape: BracketShape.frame,
          spec: '앵글 50x50x5',
          a: 600,
          b: 600,
          armHoles: HoleRow(count: 1, dia: 13.5, first: 300),
        ),
      );
      final arm = _p(f, '가로대');
      expect(arm.length, 500 + 90);
      expect(arm.holes.single.fromEnd, 300 - 5); // 왼쪽 바깥 300 − 혀 끝(기둥 벽 쪽 변 5)
    });
  });

  group('V컷 꺾기', () {
    test('ㄱ자: 한 토막, 펼친 길이 = 바깥 합 − 두께 × 2, 구멍은 가로대 끝에서 펼친 자리', () {
      final p = bracketPlan(
        const BracketInput(
          shape: BracketShape.brace,
          spec: '앵글 50x50x5',
          braceSpec: '평철 50x6',
          a: 400,
          b: 400,
          braceA: 280,
          braceB: 280,
          joint: BracketJoint.vbend,
          postHoles: HoleRow(count: 1, dia: 13.5, first: 80),
          armHoles: HoleRow(count: 1, dia: 13.5, first: 50),
        ),
      );
      expect(p.pieces.map((x) => x.title), ['① 기둥·가로대', '② 가새']);
      final v = p.pieces.first;
      expect(v.length, 400 + 400 - 10);
      expect(v.vNotches, [395]);
      expect(v.ends, contains('V컷 1곳(세운 변 90° V, 깊이 45)'));
      expect(v.holes.map((h) => h.fromEnd), [50, 400 + 80 - 10]);
      expect(p.welds.first.what, '꺾은 곳 V 이음');
      expect(p.drawing.balloons.map((b) => b.mark).toSet(), {1, 2});
      expect(p.ok, isTrue);
      // 공제값 직접
      final own = bracketPlan(
        const BracketInput(
          shape: BracketShape.l,
          spec: '앵글 50x50x5',
          a: 400,
          b: 400,
          joint: BracketJoint.vbend,
          vBend: 7,
        ),
      );
      expect(own.pieces.single.length, 793);
    });

    test('문형: 두 곳 꺾은 한 토막, 다른 규격이면 안 됨', () {
      final p = bracketPlan(
        const BracketInput(
          shape: BracketShape.frame,
          spec: '앵글 50x50x5',
          a: 600,
          b: 600,
          joint: BracketJoint.vbend,
        ),
      );
      final v = p.pieces.single;
      expect(v.length, 600 * 3 - 20);
      expect(v.vNotches, [595, 1185]);
      final bad = bracketPlan(
        const BracketInput(
          shape: BracketShape.l,
          spec: '앵글 50x50x5',
          armSpec: '앵글 40x40x5',
          a: 400,
          b: 400,
          joint: BracketJoint.vbend,
        ),
      );
      expect(bad.problems.join(), contains('같은 규격·같은 방향'));
      final flat = bracketPlan(
        const BracketInput(
          shape: BracketShape.l,
          spec: '각파이프 50x50x2.3',
          a: 400,
          b: 400,
          joint: BracketJoint.vbend,
        ),
      );
      expect(flat.problems.join(), contains('앵글·찬넬만'));
    });
  });

  group('가새 평철 맞춤·저장 값', () {
    test('기둥 그림 폭에 맞춘 평철(두께 6 먼저)', () {
      expect(bracketAutoBraceSpec('앵글 50x50x5'), '평철 50x6');
      expect(bracketAutoBraceSpec('앵글 65x65x6'), '평철 65x6');
      expect(bracketAutoBraceSpec('앵글 45x45x5'), '평철 40x4.5');
      expect(bracketAutoBraceSpec('찬넬 100x50x5'), '평철 100x6');
      expect(bracketAutoBraceSpec('찬넬 100x50x5', orient: 0), '평철 50x6');
    });

    test('입력 지도: 처음 값·판 2 전 저장 값 모두 가새 평철 맞춤', () {
      final i = bracketInputFromMap(const {'sh': 1});
      expect(i.braceSpec, '평철 50x6');
      final old = bracketUpgradeMap(const {
        'sh': 1,
        'bs': true,
        'sp': '앵글 50x50x5',
      });
      expect(old['bs'], isFalse);
      expect(bracketBraceAuto(old), isTrue);
      // 판 2에서 고른 값은 그대로
      final keep = bracketUpgradeMap(const {
        'v': 2,
        'sh': 1,
        'bs': false,
        'bsp': '평철 65x6',
      });
      expect(bracketBraceSpec(keep), '평철 65x6');
      expect(bracketInputFromMap(const {'jt': 3, 'vb': '8'}).vBend, 8);
    });
  });
}
