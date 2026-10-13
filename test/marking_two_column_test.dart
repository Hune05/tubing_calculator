// 마킹 카드: 넓은 화면(세로로 든 태블릿·가로 화면)에서도 늘 한 줄(10-13).
// 10-09에 폭 700 이상이면 두 줄로 나란히 놓았는데, 세로 태블릿(폭 약 800)에서 카드가 반쪽 폭으로 짜부라졌다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/models/conduit_data_manager.dart';
import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_result_tabs.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_result_tab.dart';

Future<List<String>> _pump(WidgetTester tester, Size size, Widget tab) async {
  final errors = <String>[];
  final old = FlutterError.onError;
  FlutterError.onError = (d) =>
      errors.add(d.exceptionAsString().split('\n').first);
  try {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: tab)));
    await tester.pumpAndSettle();
  } finally {
    FlutterError.onError = old;
  }
  addTearDown(() => tester.binding.setSurfaceSize(null));
  return errors;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final rows = [
    {'length': 300.0, 'angle': 0.0, 'rotation': 0.0},
    {'length': 400.0, 'angle': 90.0, 'rotation': 0.0},
    {'length': 500.0, 'angle': 90.0, 'rotation': 90.0},
    {'length': 300.0, 'angle': 0.0, 'rotation': 0.0},
  ];

  for (final e in <String, Widget Function()>{
    '튜브': () => const MobileResultTab(startDir: 'RIGHT'),
    '전선관': () => const ConduitResultTab(),
  }.entries) {
    for (final size in const [
      Size(800, 1280), // 세로로 든 태블릿(A9+)
      Size(1280, 800), // 가로 태블릿
      Size(640, 1400),
      Size(412, 2400),
    ]) {
      testWidgets(
        '${e.key}: ${size.width.toInt()}×${size.height.toInt()}에서 카드는 한 줄, 넘침 없음',
        (tester) async {
          MobileBendDataManager().bendList
            ..clear()
            ..addAll([for (final r in rows) Map<String, dynamic>.of(r)]);
          ConduitDataManager().bendList
            ..clear()
            ..addAll([for (final r in rows) Map<String, dynamic>.of(r)]);
          final errors = await _pump(tester, size, e.value());
          expect(errors, isEmpty);
          expect(find.byKey(const ValueKey('mark_row_0')), findsNothing);
        },
      );
    }
  }
}
