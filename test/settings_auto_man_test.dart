// 튜브 벤더 설정 AUTO/MAN·게인만 저장(10-07 2차 점검).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/utils/app_settings_controller.dart';
import 'package:tubing_calculator/src/core/utils/fitting_data.dart';
import 'package:tubing_calculator/src/data/machine_spec_sets.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';
import 'package:tubing_calculator/src/core/engine/bend_geometry.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_settings_tab.dart';
import 'package:tubing_calculator/src/presentation/calculator/tube_auto_gain.dart';

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

  testWidgets('저장본 없는 규격으로 바꾸면 앞 규격의 MAN 게인이 남지 않고 표 값(AUTO)으로 시작한다(10-08)', (tester) async {
    SharedPreferences.setMockInitialValues({
      'isInch': true,
      'tubeOD': 0.5,
      'gain': 21.5,
      'auto_gain': false,
    });
    MachineSpecs().resetForTest();
    await AppSettingsController().load();
    await openTab(tester);
    final chip = find.byKey(const ValueKey('auto_gain'));
    await tester.ensureVisible(chip);
    expect(find.descendant(of: chip, matching: find.text('MAN')), findsOneWidget);
    // 외경을 3/8"로 바꾼다.
    final dd = find.byWidgetPredicate((w) => w is DropdownButton<String> && w.value == '0.5');
    await tester.ensureVisible(dd.first);
    await tester.tap(dd.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('3/8"').last);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.ensureVisible(chip);
    expect(find.descendant(of: chip, matching: find.text('AUTO')), findsOneWidget);
  });

  test('mm로 적은 12.7(=1/2")도 제원표를 찾는다(AUTO 칸이 비지 않게)', () {
    final mm = FittingData.getBenderSpec('Swagelok', '12.7');
    final inch = FittingData.getBenderSpec('Swagelok', '0.5');
    expect(mm, isNotNull);
    expect(mm!.bendRadius, inch!.bendRadius);
    expect(FittingData.getInsertionDepth('Swagelok', '12.7'), FittingData.getInsertionDepth('Swagelok', '0.5'));
    expect(FittingData.getBenderSpec('Swagelok', '13.3'), isNull);
  });

  // 10-09 사용자 결정: AUTO 게인은 표 반경으로 셈한 값이라 반경을 MAN으로 바꾸면 따라간다.
  test('AUTO 게인은 반경 비율로 따라가고, 표 반경이면 표 값 그대로', () {
    expect(autoGainForRadius(tableGain: 16.3, tableRadius: 38.1, radius: 38.1), 16.3);
    expect(autoGainText(tableGain: 16.3, tableRadius: 38.1, radius: 38.1), '16.3');
    expect(autoGainForRadius(tableGain: 16.3, tableRadius: 38.1, radius: 50), closeTo(21.39, 0.01));
    expect(autoGainText(tableGain: 16.3, tableRadius: 38.1, radius: 50), '21.4');
    // 기하 게인(2R − πR/2)과 거의 같다(표 값이 그 셈이다).
    expect(autoGainForRadius(tableGain: 16.3, tableRadius: 38.1, radius: 50),
        closeTo(geometricGain(50, 90), 0.1));
    expect(autoGainForRadius(tableGain: 16.3, tableRadius: 38.1, radius: 0), 16.3);
  });

  testWidgets('반경 MAN 50 + 게인 AUTO면 엔진에 가는 게인이 21.4(옛 16.3이 남지 않는다)', (tester) async {
    SharedPreferences.setMockInitialValues({
      'isInch': true,
      'tubeOD': 0.5,
      kMachineSpecSetsPrefsKey: jsonEncode({
        key: {
          'bendRadius': 50.0,
          'gain': 16.3, // 예전에는 반경을 바꿔도 이 값이 남았다
          'auto': ['takeUp', 'gain', 'minStraight', 'offset', 'fittingDepth'],
        },
      }),
    });
    MachineSpecs().resetForTest();
    await AppSettingsController().load();
    await openTab(tester);
    expect(MachineSpecs().radius, 50.0);
    expect(MachineSpecs().gain90, 21.4);
  });

  testWidgets('반경 MAN에서 게인을 MAN으로 넣은 값은 반경을 따라가지 않는다(실측값 우선)', (tester) async {
    SharedPreferences.setMockInitialValues({
      'isInch': true,
      'tubeOD': 0.5,
      kMachineSpecSetsPrefsKey: jsonEncode({
        key: {
          'bendRadius': 50.0,
          'gain': 18.0,
          'auto': ['takeUp', 'minStraight', 'offset', 'fittingDepth'],
        },
      }),
    });
    MachineSpecs().resetForTest();
    await AppSettingsController().load();
    await openTab(tester);
    expect(MachineSpecs().gain90, 18.0);
  });
}
