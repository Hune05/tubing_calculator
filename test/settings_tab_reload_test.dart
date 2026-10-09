// 튜브 설정 탭이 열려 있는 동안 서버에서 받은 설정으로 컨트롤러가 다시 읽히면 칸도 새 값을 보여야 한다.
// 안 그러면 옛 값이 보이고, 저장을 누르면 받은 값을 옛 값으로 덮는다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/utils/app_settings_controller.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_settings_tab.dart';

Map<String, Object> prefsWithGain(double gain) => {
  'isInch': false,
  'tubeOD': 12.7,
  'benderBrand': 'Swagelok',
  'benderType': '수동 (Hand)',
  'bendRadius': 30.0,
  'takeUp': 25.0,
  'gain': gain,
  'fittingDepth': 20.0,
  'auto_radius': false,
  'auto_takeUp': false,
  'auto_gain': false,
  'auto_fittingDepth': false,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('다시 읽히면 게인 칸이 새 값으로 바뀐다', (tester) async {
    SharedPreferences.setMockInitialValues(prefsWithGain(12.0));
    MachineSpecs().resetForTest();
    await AppSettingsController().load();
    await tester.binding.setSurfaceSize(const Size(900, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MobileSettingsTab())),
    );
    for (var i = 0; i < 20; i++) { // 10-09: 재질 묶음 옮기기 단계가 늘어 넉넉히
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('12.0'), findsWidgets);

    // 서버에서 받은 설정이 폰 저장소에 들어간 뒤 컨트롤러가 다시 읽히는 순서(settings_cloud_card.dart)
    SharedPreferences.setMockInitialValues(prefsWithGain(33.0));
    await tester.runAsync(() => AppSettingsController().load());
    for (var i = 0; i < 20; i++) { // 10-09: 재질 묶음 옮기기 단계가 늘어 넉넉히
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('33.0'), findsWidgets);
    expect(find.text('12.0'), findsNothing);
  });
}
