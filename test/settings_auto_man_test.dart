// 튜브 벤더 설정 AUTO/MAN·게인만 저장(10-07 2차 점검).
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
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MobileSettingsTab())),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  final key = machineSpecKey(
    benderBrand: 'Swagelok',
    benderType: '수동 (Hand)',
    tubeSize: '0.5',
  );

  testWidgets('저장본이 있어도 MAN을 누르면 AUTO로 바뀐다(곧바로 MAN으로 돌아가지 않는다)', (tester) async {
    SharedPreferences.setMockInitialValues({
      'isInch': true,
      'tubeOD': 0.5,
      'gain': 18.0,
      'auto_gain': false,
      kMachineSpecSetsPrefsKey: jsonEncode({
        key: {
          'bendRadius': 38.1,
          'gain': 18.0,
          'auto': ['radius', 'takeUp', 'minStraight', 'offset', 'fittingDepth'],
        },
      }),
    });
    MachineSpecs().resetForTest();
    await AppSettingsController().load();
    await openTab(tester);
    final chip = find.byKey(const ValueKey('auto_gain'));
    await tester.ensureVisible(chip);
    expect(find.descendant(of: chip, matching: find.text('MAN')), findsOneWidget);
    await tester.tap(chip);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.descendant(of: chip, matching: find.text('AUTO')), findsOneWidget);
  });

  testWidgets('저장본의 AUTO 칸은 지금 제원표 값을 쓴다(옛 게인 20이 남지 않는다)', (tester) async {
    SharedPreferences.setMockInitialValues({
      'isInch': true,
      'tubeOD': 0.5,
      kMachineSpecSetsPrefsKey: jsonEncode({
        key: {
          'bendRadius': 38.1,
          'gain': 20.0, // 예전 표 값으로 저장된 AUTO 게인
          'auto': ['radius', 'takeUp', 'gain', 'minStraight', 'offset', 'fittingDepth'],
        },
      }),
    });
    MachineSpecs().resetForTest();
    await AppSettingsController().load();
    await openTab(tester);
    expect(MachineSpecs().gain90, isNot(20.0));
  });
}
