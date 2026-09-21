// 퀵 U-Bend 시트: 인치 설정 관 굵기, 최고점, 폰 폭 넘침.
// 예전에는 인치 설정에서 관 굵기 0.5(인치)를 mm처럼 써서 최고점이 6mm쯤
// 틀렸고, 시작 피팅을 켜면 피팅 깊이를 한 번 더 빼서 23mm 낮게 나왔다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_quick_u_bend_bottom_sheet.dart';

void main() {
  test('최고점 = 시작 직관 + R + OD/2', () {
    expect(
      uBendApex(startStraight: 200, radius: 38.1, odMm: 12.7),
      closeTo(244.45, 1e-9),
    );
    expect(uBendApex(startStraight: 0, radius: 38.1, odMm: 12.7), 0);
  });

  Future<List<String>> pumpSheet(
    WidgetTester tester,
    Size size,
    Map<String, Object> prefs,
  ) async {
    SharedPreferences.setMockInitialValues(prefs);
    MachineSpecs().resetForTest();
    MachineSpecs().update(radius: 38.1, fittingDepth: 23.0, startFit: true);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final errors = <String>[];
    final old = FlutterError.onError;
    FlutterError.onError = (d) => errors.add(d.exceptionAsString());
    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: MobileQuickUBendBottomSheet()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final start = find.byType(TextField).first;
      tester.widget<TextField>(start).controller!.text = '200';
      await tester.pumpAndSettle();
    } finally {
      FlutterError.onError = old;
    }
    return errors;
  }

  testWidgets('인치 설정(1/4")·시작 피팅 켬: 최고점 200 + 38.1 + 3.175', (tester) async {
    final errors = await pumpSheet(tester, const Size(800, 1600), {
      'isInch': true,
      'tubeOD': 0.25,
      'bendRadius': 38.1,
    });
    expect(errors, isEmpty);
    final t = find.textContaining('튀어나오는 최고점');
    expect(t, findsOneWidget, reason: 'none');
    expect(tester.widget<Text>(t).data, contains('241.3 mm'));
  });

  for (final w in [320.0, 360.0, 390.0]) {
    testWidgets('폭 $w에서 넘치지 않는다', (tester) async {
      final errors = await pumpSheet(tester, Size(w, 1600), {
        'tubeOD': 12.7,
        'bendRadius': 38.1,
      });
      expect(errors, isEmpty);
    });
  }
}
