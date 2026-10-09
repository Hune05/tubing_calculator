// 10-09: 튜브 계산기를 목록이 빈 채로 켜면 시작 방향이 저장값이 아닌 "RIGHT"로 시작했다
// (아이소 그림이 만들어질 때만 저장값을 읽었다). 입력 탭은 그 방향으로 "못 꺾는 방향"을 본다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';
import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/history_card_info.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_calculator_page.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_input_tab.dart';

void main() {
  testWidgets('목록이 비어 있어도 저장해 둔 시작 방향(UP)으로 시작한다', (tester) async {
    SharedPreferences.setMockInitialValues({'mobile_saved_start_dir': 'UP'});
    MachineSpecs().resetForTest();
    MobileBendDataManager().bendList.clear();
    TubeHistoryDb.load = () async => [];
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: MobileCalculatorPage()));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tester.widget<MobileInputTab>(find.byType(MobileInputTab)).startDir, 'UP');
  });
}
