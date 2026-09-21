// 전선관 화면을 열면 설정 탭이 폰에 저장된 값(기본값이 아니라)을 보여 주는지.
// 예전에는 저장값을 읽기 전에 설정 탭이 만들어져서 게인 82.5가 81.2로 보였고,
// 그대로 저장하면 기본값으로 덮였다.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_settings_page.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/main_navigation_page.dart';

void main() {
  late Map<String, dynamic> defaults;
  setUp(() => defaults = Map<String, dynamic>.from(globalBenderSettings.value));
  tearDown(() => globalBenderSettings.value = defaults);

  testWidgets('설정 탭이 저장된 게인을 보여 준다', (tester) async {
    SharedPreferences.setMockInitialValues({
      kConduitSettingsPrefsKey: jsonEncode({
        ...globalBenderSettings.value,
        'gain': 82.5,
        'takeUp': 150.0,
      }),
    });
    await tester.binding.setSurfaceSize(const Size(400, 900));
    final errors = <String>[];
    final old = FlutterError.onError;
    FlutterError.onError = (d) => errors.add(d.exceptionAsString());
    try {
      await tester.pumpWidget(const MaterialApp(home: ConduitMainNavigation()));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
    } finally {
      FlutterError.onError = old;
    }
    final settings = tester.widget<ConduitSettingsPage>(
      find.byType(ConduitSettingsPage, skipOffstage: false),
    );
    expect(settings, isNotNull);
    final gainField = find.byWidgetPredicate(
      (w) => w is TextField && w.controller?.text == '82.5',
      skipOffstage: false,
    );
    expect(gainField, findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == '81.2',
        skipOffstage: false,
      ),
      findsNothing,
    );
  });
}
