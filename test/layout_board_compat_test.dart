import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/layout_board_models.dart';

// 서버 layouts 모음에 예전 모양으로 저장된 배치도가 그대로 열리는지, 그리고
// 저장할 때 쓰는 칸 이름이 바뀌거나 빠지지 않았는지 지킨다.
void main() {
  // 가장 오래된 모양: 잠금·메모·최소 간격·대각선·안전 칸이 없고, 숫자는 정수로 들어 있다.
  final Map<String, dynamic> oldDoc = {
    'projectId': 'old1',
    'projectName': '예전 배치도',
    'panelWidth': 600,
    'panelHeight': 800,
    'items': [
      {'type': 'item', 'id': 'a', 'name': '차단기', 'x': 40, 'y': 40},
      {
        'type': 'item',
        'id': 'b',
        'name': '단자대',
        'x': 200,
        'y': 40,
        'w': 160,
        'h': 60,
      },
    ],
    'dimensions': [
      {
        'id': 'd1',
        'p1': {'type': 'item', 'id': 'a', 'name': '차단기', 'x': 40, 'y': 40},
        'p2': {'type': 'wall', 'id': 'wall_600_80', 'x': 600, 'y': 80},
        'type': 'center',
      },
    ],
  };

  test('예전 모양으로 저장된 모듈을 그대로 읽는다(없는 칸은 기본값)', () {
    final items = layoutItemsFromData(oldDoc);
    expect(items.length, 2);
    expect(items[0].name, '차단기');
    expect(items[0].position, const Offset(40, 40));
    expect(items[0].width, 80);
    expect(items[0].height, 80);
    expect(items[0].isLocked, false);
    expect(items[1].width, 160);
    expect(items[1].height, 60);
  });

  test('예전 모양으로 저장된 치수선을 그대로 읽는다', () {
    final dims = layoutDimensionsFromData(oldDoc);
    expect(dims.length, 1);
    final d = dims.single;
    expect(d.type, DimensionType.center);
    expect(d.p1, isA<PlacedItem>());
    expect(d.p2, isA<WallPoint>());
    expect(d.p2.center, const Offset(600, 80));
    expect(d.note, isNull);
    expect(d.minGapMm, isNull);
    expect(d.isDiagonal, false);
    expect(d.isSafetyCritical, false);
  });

  test('items·dimensions 칸이 아예 없는 문서도 빈 도면으로 열린다', () {
    expect(layoutItemsFromData({'projectName': 'x'}), isEmpty);
    expect(layoutDimensionsFromData({'projectName': 'x'}), isEmpty);
  });

  test('저장하는 칸 이름은 예전과 같다(바꾸거나 빼지 않는다)', () {
    final items = layoutItemsFromData(oldDoc);
    final dims = layoutDimensionsFromData(oldDoc);
    final fields = layoutSaveFields(
      projectId: 'old1',
      projectName: '예전 배치도',
      panelWidth: 600,
      panelHeight: 800,
      items: items,
      dimensions: dims,
      backgroundImagePath: null,
      backgroundOpacity: 0.5,
    );
    // 예전 저장 코드가 쓰던 칸(저장 시각 createdAt·updatedAt은 부르는 쪽에서 붙인다).
    expect(
      fields.keys.toSet(),
      containsAll(<String>{
        'projectId',
        'projectName',
        'panelWidth',
        'panelHeight',
        'items',
        'dimensions',
        'backgroundImagePath',
        'backgroundOpacity',
      }),
    );
    final item = (fields['items'] as List).first as Map<String, dynamic>;
    expect(
      item.keys.toSet(),
      containsAll(<String>{'type', 'id', 'name', 'x', 'y', 'w', 'h', 'locked'}),
    );
    final dim = (fields['dimensions'] as List).first as Map<String, dynamic>;
    expect(
      dim.keys.toSet(),
      containsAll(<String>{
        'id',
        'p1',
        'p2',
        'type',
        'note',
        'minGapMm',
        'isDiagonal',
        'isSafetyCritical',
      }),
    );
  });

  test('저장한 것을 다시 읽으면 같은 배치가 나온다', () {
    final items = layoutItemsFromData(oldDoc);
    final dims = layoutDimensionsFromData(oldDoc);
    final fields = layoutSaveFields(
      projectId: 'old1',
      projectName: '예전 배치도',
      panelWidth: 600,
      panelHeight: 800,
      items: items,
      dimensions: dims,
      backgroundImagePath: null,
      backgroundOpacity: 0.5,
    );
    final again = layoutItemsFromData(fields);
    expect(again.map((e) => e.toJson()).toList(), [
      for (final i in items) i.toJson(),
    ]);
    final againDims = layoutDimensionsFromData(fields);
    expect(againDims.map((e) => e.toJson()).toList(), [
      for (final d in dims) d.toJson(),
    ]);
  });
}
