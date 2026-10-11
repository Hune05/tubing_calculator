// 형강 브라켓 개편(10-11, 상용 앱 비교 1~19): 단면·도면 표기·방향, 구멍 면·게이지·두 줄·장공·끝 거리, 가로대·가새 규격 따로,
// 벽 붙임 판·리브·2단·천장 매달기, 품번·용접, 하중 확인(참고), 입체, 부재도, 입력 지도, 형강 컷팅·철판 가공으로 넘기기, 묶음 합.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/steel_bracket/bracket_3d.dart';
import 'package:tubing_calculator/src/presentation/steel_bracket/bracket_bundle.dart';
import 'package:tubing_calculator/src/presentation/steel_bracket/bracket_calc.dart';
import 'package:tubing_calculator/src/presentation/steel_bracket/bracket_export.dart';
import 'package:tubing_calculator/src/presentation/steel_bracket/bracket_form.dart';
import 'package:tubing_calculator/src/presentation/steel_bracket/bracket_load.dart';
import 'package:tubing_calculator/src/presentation/steel_bracket/bracket_piece_drawing.dart';
import 'package:tubing_calculator/src/presentation/steel_bracket/bracket_settings.dart';

BracketPiece _p(BracketPlan p, String name) =>
    p.pieces.firstWhere((x) => x.name == name);

void main() {
  group('단면·표기·방향', () {
    test('규격 이름 → 도면 표기', () {
      String ks(String s) => BracketProfile.parse(s).ks;
      expect(ks('앵글 50x50x5'), 'L-50×50×5');
      expect(ks('부등변앵글 100x75x7'), 'L-100×75×7');
      expect(ks('찬넬 100x50x5'), 'ㄷ-100×50×5');
      expect(ks('평철 50x6'), 'FB-50×6');
      expect(ks('각파이프 50x50x2.3'), '□-50×50×2.3');
      expect(ks('H형강 100x100x6x8'), 'H-100×100×6×8');
      expect(ks('립C형강 100x50x20x2.3'), 'C-100×50×20×2.3');
      expect(ks('전산볼트 M12'), '전산볼트 M12');
      expect(BracketProfile.parse('스텐 50x50').known, isFalse);
      // 두께가 변보다 크면 모르는 규격
      expect(BracketProfile.parse('앵글 5x5x50').known, isFalse);
      expect(plateKs(9, 150, 200), 'PL-9×150×200');
    });

    test('방향에 따라 그림 폭·붙는 면·구멍 면이 바뀐다', () {
      final ch = BracketProfile.parse('찬넬 100x50x5');
      expect(ch.orientCount, 2);
      expect(ch.view(0, BracketRole.wall).depth, 50); // 등이 벽에
      expect(ch.view(1, BracketRole.wall).depth, 100); // 날개가 벽에
      expect(ch.orientName(0, BracketRole.wall), '등이 벽에 (그림 폭 50)');
      expect(ch.orientName(1, BracketRole.top), '날개가 위로 (그림 폭 100)');
      // 열간압연 찬넬 날개 두께는 KS 단위 중량에서(KS 표 7.5, 모서리 둥글림 몫이 더해짐)
      expect(ch.view(1, BracketRole.wall).attachT, inInclusiveRange(7, 8.5));
      final fb = BracketProfile.parse('평철 50x6');
      expect(fb.view(0, BracketRole.wall).depth, 6);
      expect(fb.view(1, BracketRole.top).depth, 50);
      expect(fb.view(1, BracketRole.top).holesFront, isTrue);
      expect(fb.defaultOrient(BracketRole.wall), 0);
      expect(fb.defaultOrient(BracketRole.top), 1);
      final un = BracketProfile.parse('부등변앵글 100x75x7');
      expect(un.view(0, BracketRole.wall).depth, 75);
      expect(un.view(1, BracketRole.wall).depth, 100);
      expect(BracketProfile.parse('앵글 50x50x5').orientCount, 1);
      // 스트럿 슬롯 쪽은 구멍을 못 낸다
      expect(
        BracketProfile.parse('스트럿 41x41x2.5').view(1, BracketRole.top).canHole,
        isFalse,
      );
    });

    test('단면 성능: 앵글 50x50x5 (KS 표 Ix 11.1cm⁴, 최소 회전 반경 0.98cm 안팎)', () {
      final v = BracketProfile.parse('앵글 50x50x5').view(0, BracketRole.top);
      final pr = v.props;
      expect(pr.area, 475);
      expect(pr.inertia, closeTo(11.1e4, 11.1e4 * 0.03));
      expect(pr.rMin, closeTo(9.8, 1.0));
      // 평철 세움: I = t·w³/12
      final fb = BracketProfile.parse('평철 50x6').view(1, BracketRole.top).props;
      expect(fb.inertia, closeTo(6 * math.pow(50, 3) / 12, 1e-6));
      expect(fb.rMin, closeTo(6 / math.sqrt(12), 1e-9));
    });
  });

  group('구멍', () {
    test('두 줄·H형강 두 줄·장공·끝 거리·게이지', () {
      final two = bracketPlan(
        const BracketInput(
          shape: BracketShape.l,
          spec: '찬넬 100x50x5',
          postOrient: 0, // 등(웨브 100)이 벽에
          a: 300,
          b: 400,
          postHoles: HoleRow(
            count: 2,
            dia: 13.5,
            first: 80,
            pitch: 200,
            two: true,
            gauge: 25,
          ),
        ),
      );
      final post = _p(two, '기둥');
      expect(post.holes.length, 4);
      expect(post.holes.map((h) => h.z).toSet(), {25, 75});
      expect(two.wallHoles, {13.5: 4});
      expect(two.ok, isTrue);

      final h = bracketPlan(
        const BracketInput(
          shape: BracketShape.tee,
          spec: 'H형강 100x100x6x8',
          a: 600,
          b: 800,
          armHoles: HoleRow(count: 2, dia: 13.5, first: 150, pitch: 300),
        ),
      );
      // H형강은 웨브 양쪽 두 줄, 기본 게이지 (100 − 6) / 4
      expect(_p(h, '가로대').holes.map((x) => x.z).toSet(), {23.5, 76.5});

      final slot = bracketPlan(
        const BracketInput(
          shape: BracketShape.l,
          spec: '앵글 50x50x5',
          a: 300,
          b: 300,
          armHoles: HoleRow(
            count: 2,
            dia: 13.5,
            first: 10,
            pitch: 150,
            slot: 30,
          ),
        ),
      );
      final arm = _p(slot, '가로대');
      expect(arm.holes.first.slot, 30);
      expect(bracketHoleSizeText(arm.holes), '2-장공 13.5×30');
      // 장공 길이 30이 끝에서 10에 있으면 부재 밖
      expect(slot.problems.join(), contains('가로대 구멍 1번이 부재 밖으로'));
      final near = bracketPlan(
        const BracketInput(
          shape: BracketShape.l,
          spec: '앵글 50x50x5',
          a: 300,
          b: 300,
          armHoles: HoleRow(count: 1, dia: 13.5, first: 12),
        ),
      );
      expect(near.notes.join(), contains('구멍 1번이 끝에서 12mm입니다'));
      final wide = bracketPlan(
        const BracketInput(
          shape: BracketShape.l,
          spec: '앵글 50x50x5',
          a: 300,
          b: 300,
          armHoles: HoleRow(count: 1, dia: 13.5, first: 50, gauge: 8),
        ),
      );
      expect(wide.problems.join(), contains('붙는 면에 다 들어가지 않습니다'));
      final strut = bracketPlan(
        const BracketInput(
          shape: BracketShape.l,
          spec: '스트럿 41x41x2.5',
          armOrient: 1,
          a: 300,
          b: 300,
          armHoles: HoleRow(count: 1, dia: 11, first: 50),
        ),
      );
      expect(strut.problems.join(), contains('채널 너트'));
    });

    test('평철을 세우면 구멍이 그림 면에 원으로 보이고, 붙는 면 구멍은 숨은선', () {
      final p = bracketPlan(
        const BracketInput(
          shape: BracketShape.l,
          spec: '앵글 50x50x5',
          armSpec: '평철 50x6',
          a: 300,
          b: 300,
          postHoles: HoleRow(count: 2, dia: 13.5, first: 80, pitch: 150),
          armHoles: HoleRow(count: 1, dia: 11, first: 60),
        ),
      );
      // 가로대(평철 세움) 구멍만 원, 기둥(앵글 벽 쪽) 구멍은 숨은선 둘 + 중심선
      expect(p.drawing.holes.length, 1);
      expect(
        p.drawing.lines.where((l) => l.style == BracketLineStyle.hidden).length,
        4,
      );
      expect(_p(p, '가로대').holeFace, '넓은 면');
    });
  });

  group('부재·판·모양', () {
    test('가로대·가새 규격 따로: 표기·길이·원자재가 규격마다', () {
      final p = bracketPlan(
        const BracketInput(
          shape: BracketShape.brace,
          spec: '찬넬 100x50x5',
          armSpec: '앵글 50x50x5',
          braceSpec: '평철 50x6',
          a: 400,
          b: 400,
          braceA: 290,
          braceB: 240,
        ),
      );
      expect(_p(p, '기둥').ks, 'ㄷ-100×50×5');
      expect(_p(p, '가로대').ks, 'L-50×50×5');
      expect(_p(p, '가새').ks, 'FB-50×6');
      expect(_p(p, '가로대').length, 300); // 400 − 찬넬 춤 100
      expect(p.stock.keys.toSet(), {'찬넬 100x50x5', '앵글 50x50x5', '평철 50x6'});
      // 가새는 가로대 밑면(50)과 기둥 면(100)에서: 290 − 100 = 190, 240 − 50 = 190 → 45°
      expect(p.braceAngle, closeTo(45, 1e-9));
    });

    test('벽 붙임 판: 기둥 구멍 대신 판 구멍, 가로대는 판 두께만큼 짧아짐', () {
      final p = bracketPlan(
        const BracketInput(
          shape: BracketShape.l,
          spec: '앵글 50x50x5',
          a: 300,
          b: 300,
          wallPlate: true,
          wall: BracketPlateInput(
            w: 150,
            l: 0,
            t: 9,
            holes: 4,
            dia: 13.5,
            edge: 25,
          ),
          postHoles: HoleRow(count: 2, dia: 13.5, first: 80, pitch: 150),
        ),
      );
      expect(_p(p, '가로대').length, 300 - 9 - 50);
      expect(_p(p, '기둥').holes, isEmpty);
      final pl = _p(p, '벽 붙임 판');
      expect(pl.ks, 'PL-9×150×300');
      expect(pl.holes.length, 4);
      expect(p.wallHoles, {13.5: 4});
      expect(p.welds.map((w) => w.what), contains('기둥–벽 판'));
      // 판이 좁아 구멍이 기둥에 걸리면
      final narrow = bracketPlan(
        const BracketInput(
          shape: BracketShape.l,
          spec: '앵글 50x50x5',
          a: 300,
          b: 300,
          wallPlate: true,
          wall: BracketPlateInput(
            w: 60,
            l: 0,
            t: 9,
            holes: 4,
            dia: 13.5,
            edge: 10,
          ),
        ),
      );
      expect(narrow.problems.join(), contains('기둥 자리와 겹칩니다'));
    });

    test('리브: 기둥마다 2·4장, 판 밖이면 알림', () {
      BracketPlan f(int ribs, double rl) => bracketPlan(
        BracketInput(
          shape: BracketShape.frame,
          spec: '앵글 50x50x5',
          a: 600,
          b: 800,
          basePlate: true,
          base: BracketPlateInput(
            w: 200,
            l: 200,
            ribs: ribs,
            ribL: rl,
            holes: 4,
            edge: 20,
          ),
        ),
      );
      final four = f(4, 40);
      final rib = _p(four, '리브');
      expect(rib.qty, 8);
      expect(rib.length, 40);
      expect(four.ok, isTrue);
      expect(f(2, 90).problems.join(), contains('리브 길이가 판 밖으로'));
    });

    test('문형 2단: 아래 가로대 품번 ③, 길이 = 폭 − 기둥 둘, 구멍 같이', () {
      final p = bracketPlan(
        const BracketInput(
          shape: BracketShape.frame,
          spec: '앵글 50x50x5',
          a: 800,
          b: 900,
          lowerAt: 400,
          lowerHoles: true,
          armHoles: HoleRow(count: 2, dia: 13.5, first: 200, pitch: 400),
        ),
      );
      final low = _p(p, '아래 가로대');
      expect(low.mark, 3);
      expect(low.length, 700);
      expect(low.holes.map((h) => h.fromEnd), [150, 550]);
      expect(
        bracketPlan(
          const BracketInput(
            shape: BracketShape.frame,
            spec: '앵글 50x50x5',
            a: 800,
            b: 900,
            lowerAt: 20,
          ),
        ).problems.join(),
        contains('아래 가로대 높이'),
      );
    });

    test('천장 매달기: 전산볼트 길이·개수, 가로대 볼트 구멍, 용접 없음', () {
      final p = bracketPlan(
        const BracketInput(
          shape: BracketShape.hanger,
          spec: '앵글 50x50x5',
          a: 600,
          b: 500,
          rodSpec: '전산볼트 M12',
          armHoles: HoleRow(count: 1, dia: 11, first: 300),
        ),
      );
      final rod = _p(p, '전산볼트');
      expect(rod.qty, 2);
      expect(rod.length, 25 + 500 + 5 + 30);
      expect(rod.kind, BracketPieceKind.rod);
      final arm = _p(p, '가로대');
      expect(
        arm.holes
            .where((h) => h.label.startsWith('볼트'))
            .map((h) => (h.fromEnd, h.dia)),
        [(50, 13.5), (550, 13.5)],
      );
      expect(p.armHoles, {11: 1}); // 볼트 구멍은 U볼트 수에 안 넣음
      expect(p.welds, isEmpty);
      expect(p.ok, isTrue);
    });
  });

  group('품번·용접', () {
    test('품번은 있는 것만 차례로, 풍선·단면이 같은 번호', () {
      final p = bracketPlan(
        const BracketInput(
          shape: BracketShape.brace,
          spec: '앵글 50x50x5',
          a: 300,
          b: 300,
          braceA: 210,
          braceB: 210,
          wallPlate: true,
        ),
      );
      expect(p.pieces.map((x) => x.title), [
        '① 기둥',
        '② 가로대',
        '③ 가새',
        '④ 벽 붙임 판',
      ]);
      expect(p.drawing.balloons.map((b) => b.mark).toSet(), {1, 2, 3, 4});
      expect(p.drawing.sections.map((s) => s.mark), [1, 2]);
      expect(bracketMarkText(21), '(21)');
    });

    test('각장: 비우면 얇은 쪽 두께(6 넘으면 6), 넣으면 그 값·두께보다 크면 알림', () {
      final a = bracketPlan(
        const BracketInput(
          shape: BracketShape.l,
          spec: '앵글 50x50x5',
          a: 300,
          b: 300,
        ),
      );
      expect(a.welds.single.size, 5);
      final h = bracketPlan(
        const BracketInput(
          shape: BracketShape.tee,
          spec: 'H형강 100x100x6x8',
          a: 600,
          b: 800,
          basePlate: true,
          base: BracketPlateInput(t: 12),
        ),
      );
      expect(h.welds.map((w) => w.size).toSet(), {6});
      final big = bracketPlan(
        const BracketInput(
          shape: BracketShape.l,
          spec: '앵글 50x50x5',
          a: 300,
          b: 300,
          weld: 8,
        ),
      );
      expect(big.welds.single.size, 8);
      expect(big.notes.join(), contains('각장 8이 기둥 두께(5)보다 큽니다'));
      // 문형 기둥 통과: 두 곳 중 하나만 그린다
      final f = bracketPlan(
        const BracketInput(
          shape: BracketShape.frame,
          spec: '앵글 50x50x5',
          a: 600,
          b: 800,
        ),
      );
      final joints = f.welds.where((w) => w.what == '가로대–기둥');
      expect(joints.length, 2);
      expect(joints.where((w) => w.show).length, 1);
    });
  });

  group('하중 확인(참고)', () {
    test('ㄱ자 캔틸레버: 휨 = 무게 × 길이 / (0.8·Fy·S/1.67), 처짐 = PL³/3EI', () {
      final p = bracketPlan(
        const BracketInput(
          shape: BracketShape.l,
          spec: '앵글 50x50x5',
          a: 300,
          b: 300,
        ),
      );
      final r = bracketLoad(p, kg: 100, mode: BracketLoadMode.point);
      final v = p.members.firstWhere((m) => m.name == '가로대').view.props;
      final pN = 100 * 9.80665, len = 250.0;
      final ratio = pN * len / (0.8 * 275 * v.modulus / 1.67);
      expect(
        r.checks.firstWhere((c) => c.name == '가로대 휨').ratio,
        closeTo(ratio, 1e-6),
      );
      final d = pN * math.pow(len, 3) / (3 * 200000 * v.inertia);
      final defl = r.checks.firstWhere((c) => c.name == '가로대 끝 처짐');
      expect(defl.ratio, closeTo(d / (len / 180), 0.01));
      expect(r.forces.join(), contains('벽 고정 구멍이 없거나'));
      // 무게를 안 넣으면 비어 있다
      expect(bracketLoad(p, kg: 0).checks, isEmpty);
    });

    test('매달기 전산볼트 당김 = 반력 / (0.75·400·몸통 넓이 / 2)', () {
      final p = bracketPlan(
        const BracketInput(
          shape: BracketShape.hanger,
          spec: '앵글 50x50x5',
          a: 600,
          b: 500,
        ),
      );
      final r = bracketLoad(p, kg: 200, mode: BracketLoadMode.uniform);
      final t = 200 * 9.80665 / 2;
      final allow = 0.75 * 400 * math.pi / 4 * 144 / 2;
      expect(
        r.checks.firstWhere((c) => c.name == '전산볼트 당김').ratio,
        closeTo(t / allow, 1e-6),
      );
    });

    test('삼각 가새 누름: 반력 / sin θ, AISC E3 허용', () {
      final p = bracketPlan(
        const BracketInput(
          shape: BracketShape.brace,
          spec: '앵글 50x50x5',
          braceSpec: '평철 50x6',
          a: 400,
          b: 400,
          braceA: 280,
          braceB: 280,
        ),
      );
      final r = bracketLoad(p, kg: 100, mode: BracketLoadMode.point);
      // 가로대 핀(기둥 면 0)·가새(230) 받침, 끝(350)에 981N: 가새 반력 = 981 × 350 / 230
      final r2 = 100 * 9.80665 * 350 / 230;
      final c = r2 / math.sin(math.pi / 4);
      final lam = math.sqrt(2) * 230 / (6 / math.sqrt(12));
      final fe = math.pi * math.pi * 200000 / (lam * lam);
      final fcr = 0.877 * fe; // 가늘어 탄성 좌굴
      final pa = fcr * 300 / 1.67;
      expect(
        r.checks.firstWhere((x) => x.name == '가새 누름').ratio,
        closeTo(c / pa, 1e-6),
      );
    });
  });

  group('입체·부재도·입력·넘기기', () {
    test('입체 면: 바깥 크기가 치수와 같고 법선은 단위 벡터', () {
      final p = bracketPlan(
        const BracketInput(
          shape: BracketShape.frame,
          spec: '찬넬 100x50x5',
          a: 800,
          b: 900,
          basePlate: true,
          base: BracketPlateInput(w: 200, l: 150, ribs: 4),
        ),
      );
      final faces = bracket3dMesh(p);
      expect(faces, isNotEmpty);
      var x0 = double.infinity,
          x1 = -double.infinity,
          z0 = double.infinity,
          z1 = -double.infinity;
      for (final f in faces) {
        expect(f.normal.length, closeTo(1, 1e-9));
        for (final q in f.loop) {
          x0 = math.min(x0, q.x);
          x1 = math.max(x1, q.x);
          z0 = math.min(z0, q.z);
          z1 = math.max(z1, q.z);
        }
      }
      // 기둥 바깥 0~800, 베이스 판이 양옆으로 (200 − 100) / 2 = 50씩
      expect(x0, closeTo(-50, 1e-6));
      expect(x1, closeTo(850, 1e-6));
      expect(z1, closeTo(0, 1e-6));
      expect(z0, closeTo(-900, 1e-6));
    });

    test('부재도: 구멍 원 수 = 구멍 수, 이어 잰 치수 합 = 붙는 면 길이', () {
      final p = bracketPlan(
        const BracketInput(
          shape: BracketShape.l,
          spec: '앵글 50x50x5',
          a: 300,
          b: 300,
          postHoles: HoleRow(count: 2, dia: 13.5, first: 80, pitch: 150),
        ),
      );
      final d = bracketPieceDrawing(_p(p, '기둥'));
      expect(d.holes.length, 2);
      final chain = d.dims.where((x) => !x.vertical && x.offset == 24);
      expect(
        chain.fold(0.0, (s, x) => s + double.parse(x.text)),
        closeTo(300, 1e-9),
      );
      final plate = bracketPlan(
        const BracketInput(
          shape: BracketShape.frame,
          spec: '앵글 50x50x5',
          a: 600,
          b: 800,
          basePlate: true,
        ),
      );
      final pd = bracketPieceDrawing(_p(plate, '베이스 판'), plate: plate.plate);
      expect(pd.holes.length, 4);
    });

    test('입력 지도: 10-10 저장 값(cs·ps)을 새 열쇠로, 처음 값으로 계산이 된다', () {
      final m = bracketUpgradeMap({
        'sh': 2,
        'cs': '찬넬 100x50x5',
        'ps': '200',
        'pt': '12',
        'pl': true,
      });
      expect(m['sp'], '찬넬 100x50x5');
      expect(m['pw'], '200');
      expect(m['pll'], '200');
      expect(m.containsKey('cs'), isFalse);
      final i = bracketInputFromMap(m);
      expect(i.shape, BracketShape.frame);
      expect(i.base.w, 200);
      expect(i.base.t, 12);
      expect(i.basePlate, isTrue);
      final p = bracketPlan(bracketInputFromMap(const {}));
      expect(p.ok, isTrue);
      expect(p.pieces.map((x) => x.name), ['기둥', '가로대']);
      expect(bracketSummaryOf(const {}), 'ㄱ자 · 앵글 50x50x5 · 300 × 300');
    });

    test('형강 컷팅 줄: 같은 규격·길이는 합치고 종류·메모, 판은 철판 가공 처음 값(왼쪽 아래 기준)', () {
      final a = bracketPlan(
        const BracketInput(
          shape: BracketShape.frame,
          spec: '앵글 50x50x5',
          a: 600,
          b: 800,
          basePlate: true,
        ),
      );
      final items = bracketCutItems([('A', a, 2), ('B', a, 1)]);
      final post = items.firstWhere((x) => x.length == 791);
      expect(post.qty, 6); // 기둥 2 × (2 + 1)
      expect(post.category, 'ANGLE');
      expect(post.note, contains('A ① 기둥'));
      expect(post.note, contains('B ① 기둥'));
      expect(items.any((x) => x.shapeLabel.isEmpty), isFalse);
      expect(bracketSteelCategory('H형강 100x100x6x8'), 'BEAM');
      expect(bracketSteelCategory('전산볼트 M12'), 'ROD');
      final init = bracketPlateToPlateInitial(
        a.plate!,
        job: '1층',
        qty: 4,
        material: 'SUS304',
      );
      expect(init['sh'], 'flat');
      expect(init['mat'], 'stainless');
      expect(init['len'], '150');
      expect(init['n'], '4');
      final hs = init['holes'] as List;
      expect(hs.length, 4);
      // 판 왼쪽 위 (25, 25) → 왼쪽 아래 기준 (25, 125)
      expect((hs.first as Map)['v'], 125);
    });

    test('묶음 합: 규격별 자를 것을 합치고 원자재 본수', () {
      final e1 = BracketBundleEntry(id: '1', name: 'ㄱ', qty: 10, map: const {});
      final e2 = BracketBundleEntry(
        id: '2',
        name: '문형',
        qty: 2,
        map: const {'sh': 2, 'pl': false},
      );
      final t = bracketBundleTotal([e1, e2], BracketSettings.defaults);
      final cuts = t.cuts['앵글 50x50x5']!;
      expect(cuts[300], 14); // ㄱ자 기둥 10 + 문형 기둥 2 × 2
      expect(cuts[250], 10); // ㄱ자 가로대
      expect(cuts[200], 2); // 문형 가로대 300 − 2 × 50
      expect(t.stock['앵글 50x50x5']!.barCount, greaterThanOrEqualTo(2));
      expect(t.kg, greaterThan(0));
    });
  });
}
