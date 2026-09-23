// 배치도 P1(2026-09-23): 치수 점 다시 잇기, 길이 부품 판별, 메모 글자 모양.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/instrument_shape_painter.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/layout_board_models.dart';

void main() {
  group('치수 점 다시 잇기', () {
    test('저장본에서 읽은 사본을 실제 부품 객체로 바꿔 끼운다', () {
      final a = PlacedItem(
        id: 'a',
        name: 'A',
        position: Offset.zero,
        width: 100,
        height: 50,
      );
      final b = PlacedItem(
        id: 'b',
        name: 'B',
        position: const Offset(300, 0),
        width: 100,
        height: 50,
      );
      // 저장본에서 읽은 치수: 같은 아이디지만 별개 객체(옛 좌표).
      final dim = PlacedDimension.fromJson({
        'id': 'd1',
        'p1': {
          'type': 'item',
          'id': 'a',
          'name': 'A',
          'x': 0,
          'y': 0,
          'w': 100,
          'h': 50,
        },
        'p2': {
          'type': 'item',
          'id': 'b',
          'name': 'B',
          'x': 300,
          'y': 0,
          'w': 100,
          'h': 50,
        },
        'type': 'center',
      });
      expect(identical(dim.p1, a), isFalse);
      expect(relinkDimensions([dim], [a, b]), 2);
      expect(identical(dim.p1, a), isTrue);
      expect(identical(dim.p2, b), isTrue);
      // 이제 부품을 옮기면 치수도 따라온다.
      b.position = const Offset(500, 0);
      expect(computeDimensionEndpoints(dim).distance, 500);
      // 두 번 불러도 더 이을 것이 없다.
      expect(relinkDimensions([dim], [a, b]), 0);
    });

    test('벽 점·정면 view_ 점·없는 부품은 건드리지 않는다', () {
      final a = PlacedItem(
        id: 'a',
        name: 'A',
        position: Offset.zero,
        width: 10,
        height: 10,
      );
      final dim = PlacedDimension.fromJson({
        'id': 'd',
        'p1': {'type': 'wall', 'id': 'wall_0_0', 'x': 0, 'y': 0},
        'p2': {
          'type': 'item',
          'id': 'view_a',
          'name': 'A',
          'x': 5,
          'y': 5,
          'w': 1,
          'h': 1,
        },
        'type': 'edge',
      });
      final gone = PlacedDimension.fromJson({
        'id': 'g',
        'p1': {
          'type': 'item',
          'id': 'zzz',
          'name': 'Z',
          'x': 0,
          'y': 0,
          'w': 1,
          'h': 1,
        },
        'p2': {'type': 'wall', 'id': 'wall_1_1', 'x': 1, 'y': 1},
        'type': 'edge',
      });
      expect(relinkDimensions([dim, gone], [a]), 0);
      expect(dim.p2.id, 'view_a');
    });
  });

  test('길이 부품: 덕트·레일·형강·전선관은 길이, 곤질레다·JB·메모는 아님', () {
    PlacedItem it(
      String name, {
      String? shape,
      double w = 1000,
      double h = 40,
    }) => PlacedItem(
      id: name,
      name: name,
      position: Offset.zero,
      width: w,
      height: h,
      shape: shape,
    );
    expect(
      isLengthItem(it('ABS덕트 25×40', shape: InstrumentShape.duct)),
      isTrue,
    );
    expect(isLengthItem(it('DIN 레일 35')), isTrue);
    expect(isLengthItem(it('H형강 200x100', shape: 'sk_beam')), isTrue);
    expect(isLengthItem(it('후강 전선관 22', shape: 'sk_conduit')), isTrue);
    expect(isLengthItem(it('정션박스', shape: 'sk_jb')), isFalse);
    expect(isLengthItem(it('곤질레다 LB 22', shape: 'sk_cd_lb')), isFalse);
    expect(isLengthItem(it('메모', shape: InstrumentShape.note)), isFalse);
    expect(isLengthItem(it('차단기')), isFalse);
    expect(itemLengthMm(it('x', w: 40, h: 1200)), 1200);
  });

  test('메모 글자 모양 이름', () {
    expect(InstrumentShape.note, 'note');
    final m = PlacedItem(
      id: 'm',
      name: '여기 트레이',
      position: Offset.zero,
      shape: InstrumentShape.note,
    );
    expect(PlacedItem.fromJson(m.toJson()).shape, InstrumentShape.note);
  });
}
