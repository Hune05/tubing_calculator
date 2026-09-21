// 길이 0 직관만 있는 목록은 빈 목록처럼 안내 글을 보인다.
// 예전에는 숨김 줄 하나 때문에 '마킹 위치' 머리만 보이고 아래가 비었다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';
import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_result_tabs.dart';

void main() {
  testWidgets('길이 0 직관만 있으면 안내 글', (tester) async {
    SharedPreferences.setMockInitialValues({});
    MachineSpecs().resetForTest();
    MachineSpecs().update(radius: 38.1);
    MobileBendDataManager().bendList
      ..clear()
      ..add({'length': 0.0, 'angle': 0.0, 'rotation': 0.0});
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MobileResultTab(startDir: 'RIGHT')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('입력 탭에서 치수를 넣어 주십시오.'), findsOneWidget);
    expect(find.text('마킹 위치 (줄자 0점 기준)'), findsNothing);
    expect(find.byKey(const Key('tube_save_drawing')), findsNothing);
    expect(find.byKey(const Key('tube_marking_sheet')), findsNothing);
  });
}
