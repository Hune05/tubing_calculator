// 10-09: 자재 관리 관리자 확인이 앱 전체 사용자 이름(user_real_name)을 구글 표시 이름으로
// 덮어써서, 이름을 바꾼 사람이 다음에 켤 때 옛 이름(일정·프로필이 안 보이는 이름)으로 돌아가던 것.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/inventory/pages/mobile_inventory_login.dart';

void main() {
  test('관리자 확인은 앱 사용자 이름을 건드리지 않는다', () async {
    SharedPreferences.setMockInitialValues({'user_real_name': '김현장'});
    final p = await SharedPreferences.getInstance();
    await rememberInventoryAdmin(p, 'Hune Kim');
    expect(p.getString('user_real_name'), '김현장');
    expect(p.getBool(kInventoryAdminOkPrefsKey), isTrue);
    expect(inventoryAdminOfflineName(p), 'Hune Kim');
  });

  test('통신 없을 때 이름: 확인된 계정 이름 → 앱 이름 → 관리자', () async {
    SharedPreferences.setMockInitialValues({'user_real_name': '김현장'});
    final p = await SharedPreferences.getInstance();
    expect(inventoryAdminOfflineName(p), '김현장');
    SharedPreferences.setMockInitialValues({});
    final q = await SharedPreferences.getInstance();
    expect(inventoryAdminOfflineName(q), '관리자');
    expect(inventoryAdminOfflineName(null), '관리자');
  });
}
