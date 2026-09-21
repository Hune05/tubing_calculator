// 꼬리 입력 숫자판 제목이 카드 이름과 같은 뜻('꼬리 길이')이고 기준점을 적는지.
// 예전 제목 '절단 여유 기장'은 관 끝에 더 붙이는 여유로 읽혀 잘못 넣게 했다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';
import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_result_tabs.dart';

void main() {
  testWidgets('꼬리 숫자판 제목', (tester) async {
    SharedPreferences.setMockInitialValues({});
    MachineSpecs().resetForTest();
    MachineSpecs().update(radius: 38.1);
    MobileBendDataManager().bendList
      ..clear()
      ..add({'length': 500.0, 'angle': 90.0, 'rotation': 0.0});
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MobileResultTab(startDir: 'RIGHT')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tube_tail')));
    await tester.pumpAndSettle();
    expect(find.text('꼬리 길이 (마지막 꺾임점에서 관 끝까지, mm)'), findsOneWidget);
    expect(find.textContaining('절단 여유'), findsNothing);
  });
}
