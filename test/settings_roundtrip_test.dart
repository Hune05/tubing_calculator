// 튜브 설정을 바꿔 저장하고, 앱을 다시 켠 것처럼 불러와도 그대로인지 본다.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/utils/app_settings_controller.dart';
import 'package:tubing_calculator/src/data/machine_spec_sets.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_settings_tab.dart';

Finder fieldWithText(String text) => find.byWidgetPredicate(
  (w) => w is TextField && w.controller?.text == text,
);

Future<void> openTab(WidgetTester tester, Key key) async {
  await tester.binding.setSurfaceSize(const Size(900, 4000));
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: MobileSettingsTab(key: key))),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// 앱을 다시 켠 것처럼: 메모리에 든 것을 비우고 폰 저장값에서 다시 읽는다.
Future<void> restartApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  final saved = <String, Object>{};
  final prefs = await SharedPreferences.getInstance();
  for (final k in prefs.getKeys()) {
    saved[k] = prefs.get(k)!;
  }
  SharedPreferences.setMockInitialValues(saved);
  MachineSpecs().resetForTest();
  await AppSettingsController().load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('손으로 넣은 테이크업·게인이 다시 켜도 그대로다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'isInch': true,
      'tubeOD': 0.5,
      'benderBrand': 'Swagelok',
      'benderType': '수동 (Hand)',
      'takeUp': 25.0,
      'gain': 12.0,
      'springback': 2.0,
      'auto_radius': true,
      'auto_fittingDepth': true,
      'auto_takeUp': false,
      'auto_gain': false,
    });
    MachineSpecs().resetForTest();
    await AppSettingsController().load();
    await openTab(tester, const Key('a'));

    await tester.enterText(fieldWithText('25.0'), '26.5');
    await tester.enterText(fieldWithText('12.0'), '13.5');
    await tester.pump();
    // 바꾼 값이 있으면 글이 "바꾼 값 저장하고 적용"으로 바뀌므로 키로 찾는다.
    final save = find.byKey(const Key('settings_save'));
    await tester.ensureVisible(save);
    await tester.pump();
    await tester.tap(save);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    await restartApp(tester);
    expect(AppSettingsController().takeUp, 26.5);
    expect(AppSettingsController().gain, 13.5);

    await openTab(tester, const Key('b'));
    expect(fieldWithText('26.5'), findsOneWidget);
    expect(fieldWithText('13.5'), findsOneWidget);
    expect(MachineSpecs().takeUp90, 26.5);
    expect(MachineSpecs().gain90, 13.5);
    expect(MachineSpecs().radius, greaterThan(0));

    // 규격 묶음에도 같은 값이 적혀 있다.
    final prefs = await SharedPreferences.getInstance();
    final sets = jsonDecode(prefs.getString(kMachineSpecSetsPrefsKey)!) as Map;
    final set = sets.values.first as Map;
    expect(set['takeUp'], 26.5);
    expect(set['gain'], 13.5);
  });
}
