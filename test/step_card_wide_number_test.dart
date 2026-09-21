// 마킹 값이 6자리가 되어도 320 폭에서 STEP 카드가 넘치지 않는다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';
import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_result_tabs.dart';

void main() {
  testWidgets('320 폭, 98765mm 구간', (tester) async {
    SharedPreferences.setMockInitialValues({});
    MachineSpecs().resetForTest();
    MachineSpecs().update(radius: 38.1);
    MobileBendDataManager().bendList
      ..clear()
      ..addAll([
        {'length': 1234.5, 'angle': 90.0, 'rotation': 0.0},
        {'length': 98765.4, 'angle': 45.0, 'rotation': 360.0},
      ]);
    await tester.binding.setSurfaceSize(const Size(320, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final errors = <String>[];
    final old = FlutterError.onError;
    FlutterError.onError = (d) => errors.add(d.exceptionAsString());
    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MobileResultTab(startDir: 'RIGHT')),
        ),
      );
      await tester.pumpAndSettle();
    } finally {
      FlutterError.onError = old;
    }
    expect(errors, isEmpty);
  });
}
