// 설정 탭에서 mm → inch로 바꿀 때: 두께(WT)만 바뀌고 장비 값(반경·게인 등)은 [mm] 그대로.
// 예전엔 장비 값까지 25.4로 나눠 저장해서, 계산기가 R 38.1을 1.5로 썼다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/utils/app_settings_controller.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_settings_tab.dart';

bool hasField(String text) => find
    .byWidgetPredicate((w) => w is TextField && w.controller?.text == text)
    .evaluate()
    .isNotEmpty;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('inch로 바꿔도 반경·테이크업·게인·피팅 깊이는 mm 그대로, 두께만 inch로', (tester) async {
    SharedPreferences.setMockInitialValues({
      'isInch': false,
      'tubeOD': 12.7,
      'tubeWT': 1.27,
      'benderBrand': 'Swagelok',
      'benderType': '수동 (Hand)',
      'bendRadius': 38.1,
      'takeUp': 25.0,
      'gain': 12.0,
      'fittingDepth': 22.9,
      // 모두 수동: 제원표로 다시 채워지지 않고 입력한 값이 남는지 본다.
      'auto_radius': false,
      'auto_takeUp': false,
      'auto_gain': false,
      'auto_minStraight': false,
      'auto_offset': false,
      'auto_fittingDepth': false,
    });
    MachineSpecs().resetForTest();
    await AppSettingsController().load();
    await tester.binding.setSurfaceSize(const Size(900, 2400));
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MobileSettingsTab())),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(hasField('38.1'), isTrue);

    await tester.tap(find.text('inch').first);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // 장비 값은 mm 그대로
    expect(hasField('38.1'), isTrue, reason: '반경이 25.4로 나뉘면 안 된다');
    expect(hasField('25.0'), isTrue);
    expect(hasField('12.0'), isTrue);
    expect(hasField('22.9'), isTrue);
    expect(hasField('1.5'), isFalse);
    // 두께는 inch로(1.27mm = 0.05inch)
    expect(hasField('0.05'), isTrue);
  });
}
