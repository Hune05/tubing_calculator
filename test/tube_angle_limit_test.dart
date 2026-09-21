// 튜브 각도 상한과 쓸 수 없는 절단 길이.
// 엔진은 179.9° 이상만 막아서 179.8°는 절단 길이가 −56482mm로 나왔고,
// 180°를 넣으면 마킹 탭에 'Invalid argument(s):' 영어 머리말이 보였다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';
import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_input_tab.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_result_tabs.dart';
import 'package:tubing_calculator/src/presentation/calculator/tube_marking_rules.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MachineSpecs().resetForTest();
    MachineSpecs().update(
      radius: 100,
      gain90: 0,
      springback: 0,
      fittingDepth: 0,
      benderOffset: 0,
      cutMargin: 0,
      tail: 0,
      startFit: false,
      endFit: false,
    );
    MobileBendDataManager().bendList.clear();
  });

  test('쓸 수 없는 절단 길이', () {
    expect(badCutLengthText(500), isNull);
    expect(badCutLengthText(-56482), contains('-56482mm'));
    expect(badCutLengthText(double.nan), isNotNull);
    expect(badCutLengthText(double.infinity), isNotNull);
  });

  Future<void> pumpResult(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MobileResultTab(startDir: 'RIGHT')),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('179.8°: 음수 절단 길이 대신 까닭을 보여 준다', (tester) async {
    MobileBendDataManager().bendList.add({
      'length': 500.0,
      'angle': 179.8,
      'rotation': 0.0,
    });
    await pumpResult(tester);
    expect(find.text('이 도면은 계산할 수 없습니다.'), findsOneWidget);
    expect(find.textContaining('-56482'), findsOneWidget); // 까닭 글 안에만
    expect(find.text('총 절단 길이'), findsNothing);
    expect(computeTubeFieldData().error, isNotNull);
  });

  testWidgets('180°: 영어 머리말 없이', (tester) async {
    MobileBendDataManager().bendList.add({
      'length': 500.0,
      'angle': 180.0,
      'rotation': 0.0,
    });
    await pumpResult(tester);
    expect(find.text('이 도면은 계산할 수 없습니다.'), findsOneWidget);
    expect(find.textContaining('Invalid argument'), findsNothing);
    expect(find.textContaining('벤딩 각도'), findsOneWidget);
  });

  testWidgets('입력 탭: 175를 넣으면 170으로 묶고 U-Bend 계산기로 안내', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MobileInputTab())),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('직관+각도'));
    await tester.pump();
    final angle = find.byWidgetPredicate(
      (w) =>
          w is TextField && (w.decoration?.hintText ?? '').contains('원하는 각도'),
    );
    await tester.tap(angle);
    await tester.pumpAndSettle();
    tester.widget<TextField>(angle).controller!.text = '175';
    await tester.tap(find.text('적용'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(angle).controller!.text, '170');
    expect(find.textContaining('U-Bend 계산기'), findsOneWidget);
  });
}
