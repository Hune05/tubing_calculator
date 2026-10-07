// 전선관 커플링 체결은 앱을 다시 켜도 남는다(10-08).
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/conduit/conduit_field_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('남겨 둔 체결을 되살리고, 바꾸면 다시 남긴다', () async {
    SharedPreferences.setMockInitialValues({kConduitCouplingKey: true});
    conduitUseCoupling.value = false;
    resetConduitCouplingHookForTest();
    await loadConduitStartDir();
    expect(conduitUseCoupling.value, isTrue);
    conduitUseCoupling.value = false;
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    final p = await SharedPreferences.getInstance();
    expect(p.getBool(kConduitCouplingKey), isFalse);
  });
}
