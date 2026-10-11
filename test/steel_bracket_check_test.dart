// 형강 브라켓 점검 20~46(10-11, 사용자 "더 찾아봐" → "전부 진행 해"): 하중 NaN, 매달기 규격, V컷 구멍·용접,
// 매달기 전산볼트 길이, 리브 자리·개수·표기, 판 크기 자동, 저장 값 판 3, 구멍 알림, 부재도 따냄.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/steel_bracket/bracket_calc.dart';
import 'package:tubing_calculator/src/presentation/steel_bracket/bracket_form.dart';
import 'package:tubing_calculator/src/presentation/steel_bracket/bracket_load.dart';
import 'package:tubing_calculator/src/presentation/steel_bracket/bracket_piece_drawing.dart';

BracketPiece _p(BracketPlan p, String name) =>
    p.pieces.firstWhere((x) => x.name == name);

bool _finite(BracketLoadResult r) =>
    r.checks.every((c) => c.ratio.isFinite && c.ratio >= 0);

void main() {
  group('하중 확인', () {
    test('20: 받침 사이가 0이어도 NaN 줄 없이 알림(문형 폭 = 기둥 폭, 매달기 볼트 자리 둘이 겹침)', () {
      final frame = bracketPlan(
        const BracketInput(
          shape: BracketShape.frame,
          spec: '앵글 50x50x5',
          a: 50,
          b: 300,
        ),
      );
      final r1 = bracketLoad(frame, kg: 100);
      expect(_finite(r1), isTrue);
      expect(r1.notes.join(), contains('기둥 사이가 없어'));
      final hanger = bracketPlan(
        const BracketInput(
          shape: BracketShape.hanger,
          spec: '찬넬 100x50x5',
          a: 100,
          b: 500,
        ),
      );
      final r2 = bracketLoad(hanger, kg: 100);
      expect(_finite(r2), isTrue);
      expect(r2.notes.join(), contains('전산볼트 사이가 없어'));
      // 가새가 기둥 면에 붙은 삼각
      final brace = bracketPlan(
        const BracketInput(
          shape: BracketShape.brace,
          spec: '앵글 50x50x5',
          a: 300,
          b: 300,
          braceA: 50,
          braceB: 210,
        ),
      );
      expect(_finite(bracketLoad(brace, kg: 100)), isTrue);
    });

    test('32: 벽 앵커 볼트 줄은 기둥 구멍 실제 자리(가로대 통과 혀 포함)', () {
      BracketPlan plan(BracketJoint j) => bracketPlan(
        BracketInput(
          shape: BracketShape.l,
          spec: '앵글 50x50x5',
          a: 300,
          b: 300,
          joint: j,
          postHoles: const HoleRow(count: 2, dia: 13.5, first: 80, pitch: 180),
        ),
      );
      final p = plan(BracketJoint.armThrough);
      final post = p.members.firstWhere((m) => m.name == '기둥');
      // 혀 끝(그림 y 5)에서 75 = 바깥 위에서 80
      expect(post.origin.dy, 5);
      expect(post.origin.dy + post.holes.first.fromEnd, closeTo(80, 1e-6));
      // 구멍 자리가 같으니 기둥 통과와 앵커 힘이 같다(전에는 50 더 내려 잡아 달랐다)
      final r = bracketLoad(p, kg: 100);
      expect(_finite(r), isTrue);
      expect(
        r.forces,
        bracketLoad(plan(BracketJoint.postThrough), kg: 100).forces,
      );
      // 손 계산: 고르게 100kg, 모멘트 980.7N × (250/2 + 50), 받침 300 → 줄 220·40
      final t = 980.665 * 175 * 220 / (220 * 220 + 40 * 40) / 1000;
      expect(r.forces.join(), contains('당김 약 ${t.toStringAsFixed(2)}kN'));
    });
  });

  group('규격·이음', () {
    test('21: 천장 매달기는 숨은 "가로대 따로" 규격을 쓰지 않는다', () {
      final m = <String, dynamic>{
        'sh': 4,
        'sp': '찬넬 100x50x5',
        'as': false,
        'asp': '앵글 50x50x5',
      };
      expect(bracketShapeOf(m), BracketShape.hanger);
      expect(bracketArmSpec(m), '찬넬 100x50x5');
      final p = bracketPlan(bracketInputFromMap(m));
      expect(_p(p, '가로대').spec, '찬넬 100x50x5');
    });

    test('22·24: V컷 ㄱ자 가로대 구멍은 가로대 구멍, 꺾은 곳은 V 홈 맞대기', () {
      final p = bracketPlan(
        const BracketInput(
          shape: BracketShape.l,
          spec: '앵글 50x50x5',
          a: 300,
          b: 300,
          joint: BracketJoint.vbend,
          postHoles: HoleRow(count: 2, dia: 13.5, first: 100, pitch: 150),
          armHoles: HoleRow(count: 1, dia: 11, first: 50),
        ),
      );
      expect(p.wallHoles, {13.5: 2});
      expect(p.armHoles, {11.0: 1});
      expect(p.welds.any((w) => w.groove), isTrue);
    });

    test('37: ㄱ자 가로대 통과에서 가로대 구멍이 기둥 바로 위면 알림', () {
      final p = bracketPlan(
        const BracketInput(
          shape: BracketShape.l,
          spec: '앵글 50x50x5',
          a: 300,
          b: 300,
          joint: BracketJoint.armThrough,
          armHoles: HoleRow(count: 1, dia: 13.5, first: 280),
        ),
      );
      expect(p.problems.join(), contains('기둥 바로 위'));
      final ok = bracketPlan(
        const BracketInput(
          shape: BracketShape.l,
          spec: '앵글 50x50x5',
          a: 300,
          b: 300,
          joint: BracketJoint.armThrough,
          armHoles: HoleRow(count: 1, dia: 13.5, first: 100),
        ),
      );
      expect(ok.problems.join(), isNot(contains('기둥 바로 위')));
    });
  });

  group('천장 매달기', () {
    test('25: 각파이프는 위아래 두 면을 관통한 길이, 세운 평철은 알림', () {
      final pipe = bracketPlan(
        const BracketInput(
          shape: BracketShape.hanger,
          spec: '각파이프 50x50x2.3',
          a: 600,
          b: 500,
        ),
      );
      // 25(천장 위) + 500 + 50(관 높이) + 30(아래)
      expect(_p(pipe, '전산볼트').length, 605);
      expect(pipe.notes.join(), contains('두 면'));
      final ch = bracketPlan(
        const BracketInput(
          shape: BracketShape.hanger,
          spec: '찬넬 100x50x5',
          a: 600,
          b: 500,
        ),
      );
      final armT = ch.members.firstWhere((m) => m.name == '가로대').view.attachT;
      expect(_p(ch, '전산볼트').length, closeTo(25 + 500 + armT + 30, 1e-6));
      final flat = bracketPlan(
        const BracketInput(
          shape: BracketShape.hanger,
          spec: '평철 50x6',
          armOrient: 1,
          a: 600,
          b: 500,
        ),
      );
      expect(flat.problems.join(), contains('구멍을 낼 수 없는 방향'));
      // 전산볼트 표기는 M 지름만(카톡 "전산볼트 전산볼트 M12" 겹침, 점검 45)
      expect(_p(ch, '전산볼트').ks, 'M12');
    });
  });

  group('베이스 판·벽 붙임 판', () {
    test('26: 앵글 기둥 리브는 기둥 살이 있는 자리에서 뻗는다', () {
      for (final ribs in [2, 4]) {
        final p = bracketPlan(
          BracketInput(
            shape: BracketShape.tee,
            spec: '앵글 50x50x5',
            a: 400,
            b: 300,
            basePlate: true,
            base: BracketPlateInput(ribs: ribs),
          ),
        );
        final v = p.members.firstWhere((m) => m.name == '기둥').view;
        final specs = p.plate!.ribSpecs;
        expect(specs.length, ribs);
        for (final rb in specs) {
          // 리브가 붙는 면 바로 안쪽에 기둥 살이 있다
          final inside = Offset(rb.u - rb.du * 0.5, rb.z - rb.dz * 0.5);
          expect(
            v.rects.any((r) => r.inflate(1e-6).contains(inside)),
            isTrue,
            reason: 'rib at (${rb.u}, ${rb.z})',
          );
        }
        // 35: 리브 용접 줄 수 = 리브 장수
        expect(p.welds.where((w) => w.what == '리브(양면)').length, ribs);
      }
    });

    test('33·34: 판 크기 비우면 기둥에 맞춰 자동, 리브 표기에 크기', () {
      final h = bracketPlan(
        const BracketInput(
          shape: BracketShape.tee,
          spec: 'H형강 150x150x7x10',
          a: 600,
          b: 400,
          basePlate: true,
          base: BracketPlateInput(w: 0, l: 0, ribs: 2),
        ),
      );
      expect(h.plate!.w, greaterThan(150));
      expect(h.problems.join(), isNot(contains('베이스 판')));
      final rib = h.pieces.firstWhere((x) => x.kind == BracketPieceKind.rib);
      expect(rib.ks, 'PL-6×40×80 삼각');
      // 작은 기둥은 자동이어도 150
      expect(bracketAutoPlate(50), 150);
    });

    test('36: 벽 붙임 판이 기둥 아래 끝보다 짧으면 알림(가로대 통과)', () {
      final p = bracketPlan(
        const BracketInput(
          shape: BracketShape.l,
          spec: '앵글 50x50x5',
          a: 300,
          b: 300,
          joint: BracketJoint.armThrough,
          wallPlate: true,
          wall: BracketPlateInput(l: 250),
        ),
      );
      expect(p.notes.join(), contains('벽 붙임 판 높이'));
    });
  });

  group('저장 값', () {
    test('30: 판 2 전 저장 값에서 직접 고른 가새 규격은 그대로', () {
      final m = bracketUpgradeMap(const {
        'sh': 1,
        'sp': '앵글 50x50x5',
        'bs': false,
        'bsp': '평철 65x6',
      });
      expect(bracketBraceSpec(m), '평철 65x6');
      expect(m['v'], 4);
    });

    test('31: 10-10 저장 값은 그때 부재 폭이 되는 방향으로', () {
      // 평철 50x6 ㄱ자: 그때는 그림 폭 50(첫 숫자) → 세움
      final f = bracketUpgradeMap(const {'sh': 0, 'cs': '평철 50x6'});
      final pf = bracketPlan(bracketInputFromMap(f));
      expect(_p(pf, '가로대').length, 250);
      // 찬넬 w=50 → 그림 폭 50 방향
      final c = bracketUpgradeMap(const {
        'sh': 0,
        'sp': '찬넬 100x50x5',
        'w': '50',
      });
      final pc = bracketPlan(bracketInputFromMap(c));
      expect(
        pc.members.firstWhere((m) => m.name == '기둥').view.depth,
        closeTo(50, 1e-6),
      );
      // 판 3 전 처음 값 150은 비움(자동)
      final o = bracketUpgradeMap(const {'v': 2, 'pw': '150', 'pll': '200'});
      expect(o['pw'], '');
      expect(o['pll'], '200');
    });
  });

  group('부재도', () {
    test('38·39: 찬넬 가로대를 앵글 기둥에 맞대면 혀는 날개 띠마다, 문형 기둥도 붙는 면 그림', () {
      final p = bracketPlan(
        const BracketInput(
          shape: BracketShape.l,
          spec: '앵글 50x50x5',
          armSpec: '찬넬 100x50x5',
          a: 300,
          b: 300,
        ),
      );
      final arm = p.members.firstWhere((m) => m.name == '가로대');
      final strips = arm.extStrips(arm.extEnd);
      expect(strips.length, 2); // 위아래 날개
      final d = bracketPieceDrawing(_p(p, '가로대'));
      // 옆 모양 하나 + 혀 띠 수 + 붙는 면 하나
      expect(d.polys.length, 1 + strips.length + 1);
      expect(d.labels.any((l) => l.text.contains('그림에 그린 혀만')), isTrue);
      final f = bracketPlan(
        const BracketInput(
          shape: BracketShape.frame,
          spec: '앵글 50x50x5',
          a: 600,
          b: 400,
          joint: BracketJoint.armThrough,
        ),
      );
      final post = _p(f, '기둥');
      expect(post.member!.extStart, isNotEmpty);
      final fd = bracketPieceDrawing(post);
      expect(fd.labels.any((l) => l.text.startsWith('따냄')), isTrue);
    });
  });
}
