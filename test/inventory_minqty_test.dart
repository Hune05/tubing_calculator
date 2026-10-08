// 재고조사 올리기는 최소 수량을 바꿨을 때만 보낸다(10-07: 늘 보내 다른 기기에서 바꾼 값이 되돌아갔다).
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/inventory/pages/inventory_model.dart';

void main() {
  test('셀 때 값 그대로면 보내지 않고, 바꿨으면 보낸다', () {
    final d = ItemData(minQty: 5, bookMinQty: 5);
    expect(d.minQtyChanged, isFalse);
    d.minQty = 8;
    expect(d.minQtyChanged, isTrue);
    expect(ItemData(minQty: 0).minQtyChanged, isTrue); // 셀 때 값을 모르면 예전처럼 보낸다
  });

  test('셀 때 있던 위치를 비우면 빈 값으로 보내고, 원래 빈 칸은 안 보낸다(10-08)', () {
    final d = ItemData(location: '', maker: '세진')
      ..bookText = {'location': 'A-3', 'maker': '세진', 'heatNo': ''};
    final u = d.textUpdates();
    expect(u['location'], '');
    expect(u['maker'], '세진');
    expect(u.containsKey('heatNo'), isFalse);
  });

  test("새 자재 등록: 같은 이름(빈칸·따옴표·대소문자 차이 무시)이면 막는다(10-09)", () {
    final names = ["[HY-LOK] 1/2\" Tube SS316L", "볼트 M10"];
    expect(findDuplicateMaterialName("[hy-lok]  1/2” tube ss316l", names), names.first);
    expect(findDuplicateMaterialName("볼트 M10", names), "볼트 M10");
    expect(findDuplicateMaterialName("볼트 M12", names), isNull);
    expect(findDuplicateMaterialName("  ", names), isNull);
  });
}

