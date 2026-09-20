import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/inventory/material_catalog.dart';

void main() {
  final list = builtinMaterialCatalog();

  group('기본 자재 목록', () {
    test('전선관·후렉시블·부속이 모두 들어 있다', () {
      final cats = {for (final i in list) i.category};
      expect(cats.contains('CONDUIT'), isTrue);
      expect(cats.contains('FLEX'), isTrue);
      expect(cats.contains('ACC'), isTrue);
    });

    test('아이디가 겹치지 않는다', () {
      final ids = <String>{};
      for (final i in list) {
        expect(ids.add(i.id), isTrue, reason: '겹친 아이디: ${i.id}');
      }
    });

    test('이름과 단위가 비어 있지 않다', () {
      for (final i in list) {
        expect(i.name.trim(), isNotEmpty);
        expect(i.unit.trim(), isNotEmpty);
      }
    });

    test('전선관은 본, 후렉시블은 m, 부속은 EA로 센다', () {
      for (final i in list) {
        if (i.category == 'CONDUIT') expect(i.unit, '본');
        if (i.category == 'FLEX') expect(i.unit, 'm');
        if (i.category == 'ACC') expect(i.unit, 'EA');
      }
    });

    test('후강 전선관 22mm가 있다', () {
      final it = list.firstWhere((i) => i.id == 'conduit_rigid_22');
      expect(it.name, '후강 전선관 22mm');
      expect(it.spec, '22mm');
      expect(it.category, 'CONDUIT');
    });

    test('금속 후렉시블과 PF관·CD관이 있다', () {
      expect(list.any((i) => i.id == 'flex_metal_24'), isTrue);
      expect(list.any((i) => i.id == 'flex_pf_16'), isTrue);
      expect(list.any((i) => i.id == 'flex_cd_16'), isTrue);
    });

    test('곤질레다(컨듈렛)가 부속에 들어 있다', () {
      final it = list.firstWhere((i) => i.id == 'acc_condulet_lb_22');
      expect(it.name, '곤질레다 LB형 22mm');
      expect(it.category, 'ACC');
      expect(it.kind, '곤질레다');
      expect(list.where((i) => i.kind == '곤질레다').length, 36);
    });

    test('곤질레다는 제조사 목록에 없다', () {
      expect(kCommonMaterialMakers.contains('곤질레다'), isFalse);
    });

    test('커플링·커넥터·박스 같은 부속이 있다', () {
      expect(list.any((i) => i.id == 'acc_coupling_22'), isTrue);
      expect(list.any((i) => i.id == 'acc_box_connector_22'), isTrue);
      expect(list.any((i) => i.id == 'acc_flex_conn_st_24'), isTrue);
      expect(list.any((i) => i.id == 'acc_box_octa'), isTrue);
    });

    test('순서가 겹치지 않고 커진다', () {
      for (var i = 1; i < list.length; i++) {
        expect(list[i].order > list[i - 1].order, isTrue);
      }
    });
  });

  group('분류 이름', () {
    test('영문 아이디를 한글로 바꿔 준다', () {
      expect(materialCategoryLabel('CONDUIT'), '전선관');
      expect(materialCategoryLabel('FLEX'), '후렉시블');
      expect(materialCategoryLabel('ACC'), '부속·악세사리');
    });

    test('모르는 분류는 그대로 두고, 비면 기타로 본다', () {
      expect(materialCategoryLabel('XYZ'), 'XYZ');
      expect(materialCategoryLabel(''), '기타');
      expect(materialCategoryLabel(null), '기타');
    });
  });

  group('카탈로그 한 줄', () {
    test('서버에 담았다가 읽어도 그대로다', () {
      final it = list.first;
      final back = CatalogItem.fromMap(it.id, it.toMap());
      expect(back.name, it.name);
      expect(back.category, it.category);
      expect(back.spec, it.spec);
      expect(back.unit, it.unit);
      expect(back.order, it.order);
    });

    test('찾기 글에 이름·규격·분류가 들어간다', () {
      final it = list.firstWhere((i) => i.id == 'conduit_rigid_22');
      expect(it.searchText.contains('후강'), isTrue);
      expect(it.searchText.contains('22mm'), isTrue);
      expect(it.searchText.contains('전선관'), isTrue);
    });
  });

  group('제조사', () {
    test('많이 쓰는 곳이 먼저 온다', () {
      expect(kCommonMaterialMakers, ['삼화', '동아산전']);
    });

    test('앱이 기억한 곳을 뒤에 붙이고 겹치면 뺀다', () {
      expect(mergeMakers(['우진', '삼화']), ['삼화', '동아산전', '우진']);
      expect(mergeMakers(['', '  ']), kCommonMaterialMakers);
    });
  });
}
