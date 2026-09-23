// 센터 치수 기준점: 접속구가 있는 부품은 접속구 가운데(관 축이 만나는 점), 없으면 상자 가운데.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/instrument_shape_painter.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/layout_board_models.dart';

PlacedItem _it(
  String shape, {
  double w = 100,
  double h = 100,
  int? rot,
  bool flip = false,
}) => PlacedItem(
  id: shape,
  name: shape,
  position: const Offset(1000, 500),
  width: w,
  height: h,
  shape: shape,
  rotation: rot,
  flipped: flip,
);

void main() {
  test('그림 없는 네모·전기 부품·메모는 상자 가운데', () {
    final plain = PlacedItem(
      id: 'p',
      name: '차단기',
      position: const Offset(10, 20),
      width: 40,
      height: 60,
    );
    expect(plain.center, const Offset(30, 50));
    expect(plain.center, plain.boxCenter);
    expect(
      _it('el_mcb:2', w: 35, h: 81).center,
      _it('el_mcb:2', w: 35, h: 81).boxCenter,
    );
    expect(
      _it(InstrumentShape.note).center,
      _it(InstrumentShape.note).boxCenter,
    );
  });

  test('수직 배관 계기(비대칭)는 상자 가운데가 아니라 접속구 가운데', () {
    final it = _it(InstrumentShape.ykVertical, w: 175, h: 138);
    final ports = shapeConnectionPoints(
      InstrumentShape.ykVertical,
      const Size(175, 138),
    );
    expect(ports.length, 2);
    final Offset ref = it.center - it.position;
    // 접속구 둘은 아래로 나가니 기준 x는 그 평균, 상자 가운데(87.5)와 다르다.
    expect(ref.dx, closeTo((ports[0].dx + ports[1].dx) / 2, 1e-6));
    expect((ref.dx - 87.5).abs() > 10, isTrue);
  });

  test('곧은 피팅·밸브는 관 축 위 가운데, 엘보는 관 축이 만나는 모서리', () {
    // 유니언: 양 끝 관, 기준 = 상자 가운데.
    final u = _it(InstrumentShape.fitUnion, w: 41, h: 14);
    expect((u.center - u.boxCenter).distance, lessThan(1e-6));
    // 니들 밸브: 손잡이가 위라 관 축은 상자 가운데보다 아래.
    const nv = 'fv:needle;L=66.4;top=63.6;bot=14;end=n;bar=64;pipe=17.5';
    final v = _it(nv, w: 66, h: 77);
    final vp = shapeConnectionPoints(nv, const Size(66, 77));
    expect(vp.length, 2);
    expect((v.center - v.position).dy, closeTo(vp[0].dy, 1e-6));
    expect((v.center - v.position).dy > 77 / 2, isTrue);
    // 유니언 엘보(정사각): 오른쪽 관 축 y와 아래 관 축 x가 만나는 점 = 몸통 모서리.
    final e = _it(InstrumentShape.fitElbow, w: 33, h: 33);
    final ep = shapeConnectionPoints(
      InstrumentShape.fitElbow,
      const Size(33, 33),
    );
    final right = ep.firstWhere((p) => p.dx > 30);
    final down = ep.firstWhere((p) => p.dy > 30);
    final Offset er = e.center - e.position;
    expect(er.dx, closeTo(down.dx, 1e-6));
    expect(er.dy, closeTo(right.dy, 1e-6));
  });

  test('돌리거나 뒤집어도 기준점이 그림을 따라간다', () {
    final a = _it(InstrumentShape.ykVertical, w: 175, h: 138);
    final b = _it(InstrumentShape.ykVertical, w: 175, h: 138, flip: true);
    final ra = a.center - a.position, rb = b.center - b.position;
    expect(rb.dx, closeTo(175 - ra.dx, 1e-6));
    expect(rb.dy, closeTo(ra.dy, 1e-6));
    final c = _it(InstrumentShape.ykVertical, w: 138, h: 175, rot: 90);
    final rc = c.center - c.position;
    // 시계 방향 90°: 아래로 나가던 접속구가 왼쪽으로 간다 → 기준 y가 접속구 평균, x는 왼쪽 가까이.
    expect(rc.dx < 138 / 2, isTrue);
  });

  test('센터 치수는 기준점 사이를 잰다(측면 치수는 그대로 상자 끝)', () {
    final a = _it(InstrumentShape.ykVertical, w: 175, h: 138);
    final b = PlacedItem(
      id: 'b',
      name: 'B',
      position: const Offset(1600, 500),
      width: 100,
      height: 138,
    );
    final dim = PlacedDimension(
      id: 'd',
      p1: a,
      p2: b,
      type: DimensionType.center,
    );
    final r = computeDimensionEndpoints(dim);
    expect(r.distance, closeTo((b.center.dx - a.center.dx).abs(), 1e-6));
    expect(r.distance, isNot(closeTo(1650 - 1087.5, 1e-6)));
    final edge = PlacedDimension(
      id: 'e',
      p1: a,
      p2: b,
      type: DimensionType.edge,
    );
    expect(
      computeDimensionEndpoints(edge).distance,
      closeTo(1600 - 1175, 1e-6),
    );
  });
}
