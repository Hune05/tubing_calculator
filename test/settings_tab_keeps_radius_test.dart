// 튜브 계산기를 열면(설정 탭이 같이 만들어진다) 자동(AUTO) 반경·피팅 깊이가
// 0으로 덮이던 것. 자동 칸이 채워지기 전에 빈칸을 제원에 넣어 저장했다.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/utils/app_settings_controller.dart';
import 'package:tubing_calculator/src/data/machine_spec_sets.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_settings_tab.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> openTab(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 2400));
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MobileSettingsTab())),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('제원 묶음이 있으면 그 반경·피팅 깊이를 제원에 넣는다(0으로 덮지 않는다)', (
    tester,
  ) async {
    // 폰에 있던 것과 같은 모양: 자동 반경·자동 피팅 깊이, 저장된 값은 이미 0.
    SharedPreferences.setMockInitialValues({
      'isInch': true,
      'tubeOD': 0.5,
      'benderBrand': 'Swagelok',
      'benderType': '수동 (Hand)',
      'bendRadius': 0.0,
      'fittingDepth': 0.0,
      'takeUp': 25.0,
      'gain': 12.0,
      'auto_radius': true,
      'auto_fittingDepth': true,
      'auto_takeUp': false,
      'auto_gain': false,
      kMachineSpecSetsPrefsKey: jsonEncode({
        machineSpecKey(
          benderBrand: 'Swagelok',
          benderType: '수동 (Hand)',
          tubeSize: '0.5',
        ): {
          'bendRadius': 38.1,
          'takeUp': 25.0,
          'gain': 12.0,
          'fittingDepth': 22.9,
          'auto': ['radius', 'fittingDepth'],
        },
      }),
    });
    MachineSpecs().resetForTest();
    await AppSettingsController().load();

    await openTab(tester);

    expect(MachineSpecs().radius, 38.1);
    expect(MachineSpecs().fittingDepth, 22.9);
    expect(MachineSpecs().takeUp90, 25.0);
    expect(MachineSpecs().gain90, 12.0);
  });

  testWidgets('제원 묶음이 없으면 제원표 값으로 채워서 넣는다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'isInch': true,
      'tubeOD': 0.5,
      'benderBrand': 'Swagelok',
      'benderType': '수동 (Hand)',
      'bendRadius': 0.0,
      'fittingDepth': 0.0,
      'takeUp': 25.0,
      'gain': 12.0,
      'auto_radius': true,
      'auto_fittingDepth': true,
      'auto_takeUp': false,
      'auto_gain': false,
    });
    MachineSpecs().resetForTest();
    await AppSettingsController().load();

    await openTab(tester);

    // 예전에는 여기서 0이었다(자동 칸을 채우기 전에 넣었다).
    expect(MachineSpecs().radius, greaterThan(0));
    expect(MachineSpecs().fittingDepth, greaterThan(0));
    expect(MachineSpecs().takeUp90, 25.0);
  });
}
