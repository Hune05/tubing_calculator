import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/inventory/material_catalog.dart';

void main() {
  final list = allMaterialCatalog();

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
        if (i.category == 'FLEX') expect(i.unit, 'm');
        if (i.category == 'ACC') expect(i.unit, 'EA');
      }
    });

    test('업체 자료에 강제전선관과 나사없는 전선관이 있다', () {
      final g22 = list.firstWhere(
        (i) => i.name.contains('강제전선관') && i.spec == 'G22',
      );
      expect(g22.category, 'CONDUIT');
      expect(g22.unit, '본');
      expect(g22.source, '경진전기');
      expect(
        list.any((i) => i.name.contains('나사없는 전선관') && i.spec == 'E19'),
        isTrue,
      );
    });

    test('업체 자료에 후렉시블 GW·SW·SF가 있다', () {
      expect(
        list.any((i) => i.category == 'FLEX' && i.name.contains('GW')),
        isTrue,
      );
      expect(
        list.any((i) => i.category == 'FLEX' && i.name.contains('SW')),
        isTrue,
      );
      expect(
        list.any((i) => i.category == 'FLEX' && i.name.contains('SF')),
        isTrue,
      );
    });

    test('업체 자료에 현장에서 부르는 부속 이름이 그대로 있다', () {
      for (final word in ['카프링', '부싱', '로크너트', '새들', '레듀샤', '엔트런스']) {
        expect(list.any((i) => i.name.contains(word)), isTrue, reason: ' 없음');
      }
    });

    test('업체 자료는 어디서 왔는지 남아 있다', () {
      final fromVendor = list.where((i) => i.source == '경진전기').length;
      expect(fromVendor, greaterThan(500));
    });

    test('업체 자료 이름에 규격 범위나 재고 메모가 남아 있지 않다', () {
      for (final i in list.where((i) => i.source == '경진전기')) {
        expect(i.name.contains('~'), isFalse, reason: i.name);
        expect(i.name.contains('재고'), isFalse, reason: i.name);
      }
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

    test('순서가 겹치지 않고 커진다(업체 자료 안에서)', () {
      final v = list.where((i) => i.source == '경진전기').toList();
      for (var i = 1; i < v.length; i++) {
        expect(v[i].order > v[i - 1].order, isTrue);
      }
    });
  });

  group('분류 이름', () {
    test('영문 아이디를 한글로 바꿔 준다', () {
      expect(materialCategoryLabel('CONDUIT'), '전선관');
      expect(materialCategoryLabel('FLEX'), '후렉시블');
      expect(materialCategoryLabel('ACC'), '부속');
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

    test('찾기 글에 이름·규격·갈래가 들어간다', () {
      final it = list.firstWhere((i) => i.id == 'acc_condulet_lb_22');
      expect(it.searchText.contains('lb'), isTrue);
      expect(it.searchText.contains('22mm'), isTrue);
      expect(it.searchText.contains('곤질레다'), isTrue);
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
