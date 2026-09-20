import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/data/models/steel_shape_db.dart';
import 'package:tubing_calculator/src/presentation/inventory/material_catalog.dart';

void main() {
  final steel = steelMaterialCatalog();

  test('규격표에 있는 형강이 모두 자재 목록에 들어간다', () {
    expect(steel.length, SteelShapeDB.all.length);
    for (final s in steel) {
      expect(s.category, 'STEEL');
      expect(s.unit, '본');
    }
  });

  test('이름이 규격표 이름과 같아야 재고에서 찾을 수 있다', () {
    final names = {for (final s in steel) s.name};
    for (final s in SteelShapeDB.all) {
      expect(names.contains(s.label), isTrue, reason: s.label);
    }
  });

  test('찬넬 75x40x5는 갈래가 찬넬, 규격이 75x40x5', () {
    final it = steel.firstWhere((s) => s.name == '찬넬 75x40x5');
    expect(it.kind, '찬넬');
    expect(it.spec, '75x40x5');
    expect(it.source, '앱 규격표');
  });

  test('전체 목록에 형강도 들어 있고 아이디가 겹치지 않는다', () {
    final all = allMaterialCatalog();
    expect(all.any((s) => s.category == 'STEEL'), isTrue);
    final ids = <String>{};
    for (final s in all) {
      expect(ids.add(s.id), isTrue, reason: '겹친 아이디: ${s.id}');
    }
  });

  test('분류 이름이 형강으로 나온다', () {
    expect(materialCategoryLabel('STEEL'), '형강');
  });
}
