// 전선관 마킹 탭: 좁은 폭에서 넘치지 않는지, 22.5°를 '22°'로 자르지 않는지,
// 아주 큰 길이도 카드 안에 들어가는지.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/models/conduit_data_manager.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_result_tab.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_settings_page.dart';

Future<List<String>> pumpResult(WidgetTester tester, double width) async {
  final errors = <String>[];
  final old = FlutterError.onError;
  FlutterError.onError = (d) =>
      errors.add(d.exceptionAsString().split('\n').first);
  try {
    await tester.binding.setSurfaceSize(Size(width, 3000));
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ConduitResultTab())),
    );
    await tester.pumpAndSettle();
  } finally {
    FlutterError.onError = old;
  }
  return errors;
}

void main() {
  late Map<String, dynamic> defaults;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    defaults = Map<String, dynamic>.from(globalBenderSettings.value);
  });
  tearDown(() => globalBenderSettings.value = defaults);

  final rows = [
    {'length': 1000.0, 'angle': 135.0, 'rotation': 450.0},
    {'length': 500.0, 'angle': 22.5, 'rotation': 360.0},
    {'length': 800.0, 'angle': 0.0, 'rotation': 0.0},
  ];

  for (final type in ['hand', 'ram', 'chicago']) {
    for (final w in [320.0, 360.0, 600.0]) {
      testWidgets('$type 폭 ${w.toInt()}에서 넘치지 않는다', (tester) async {
        globalBenderSettings.value = {
          ...globalBenderSettings.value,
          'benderType': type,
        };
        ConduitDataManager().bendList
          ..clear()
          ..addAll(rows);
        final errors = await pumpResult(tester, w);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        expect(errors, isEmpty);
      });
    }
  }

  testWidgets('22.5°는 22.5°로 보인다', (tester) async {
    ConduitDataManager().bendList
      ..clear()
      ..addAll(rows);
    await pumpResult(tester, 600);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    expect(find.textContaining('22.5° 벤딩'), findsOneWidget);
    expect(find.textContaining('22° 벤딩'), findsNothing);
  });

  testWidgets('아주 큰 길이도 320 폭 카드 안에 들어간다', (tester) async {
    ConduitDataManager().bendList
      ..clear()
      ..addAll([
        {'length': 99999999.0, 'angle': 90.0, 'rotation': 0.0},
        {'length': 99999999.0, 'angle': 0.0, 'rotation': 0.0},
      ]);
    final errors = await pumpResult(tester, 320);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    expect(errors, isEmpty);
  });
}
