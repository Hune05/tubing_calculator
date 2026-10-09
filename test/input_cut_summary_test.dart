// 10-09 사용자: 입력 탭 머리에 총 절단 길이(와 경고 수)를 띄운다 — 마킹 탭과 같은 셈.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';
import 'package:tubing_calculator/src/data/models/conduit_data_manager.dart';
import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_input_tab.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_result_tabs.dart';
import 'package:tubing_calculator/src/presentation/conduit/conduit_marking_logic.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_input_tab.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_settings_page.dart';

String _plain(WidgetTester t) {
  final w = t.widget<Text>(find.byKey(const Key('input_cut_summary')));
  return w.textSpan!.toPlainText();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pump(WidgetTester tester, Widget tab) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: tab)));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('튜브: 머리에 마킹 탭과 같은 총 절단 길이', (tester) async {
    SharedPreferences.setMockInitialValues({});
    MachineSpecs().resetForTest();
    MachineSpecs().update(radius: 38.1, gain90: 16.3, springback: 0, tail: 300, startFit: false, endFit: false);
    MobileBendDataManager().bendList
      ..clear()
      ..add({'length': 500.0, 'angle': 90.0, 'rotation': 0.0});
    await pump(tester, const MobileInputTab());
    final cut = computeTubeFieldData().totalCut.round();
    expect(_plain(tester), startsWith('총 절단 ${cut}mm'));
  });

  testWidgets('전선관: 첫 마킹이 관 끝보다 앞이면 경고 수가 붙는다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    globalBenderSettings.value = {
      ...globalBenderSettings.value,
      'benderType': 'hand',
      'takeUp': 152.4,
      'gain': 81.2,
      'clr': 114.3,
    };
    ConduitDataManager().bendList
      ..clear()
      ..addAll([
        {'length': 120.0, 'angle': 90.0, 'rotation': 0.0},
        {'length': 300.0, 'angle': 0.0, 'rotation': 0.0},
      ]);
    await pump(tester, const ConduitInputTab());
    final cut = conduitTotalCut(ConduitDataManager().bendList, globalBenderSettings.value).round();
    expect(_plain(tester), startsWith('총 절단 ${cut}mm'));
    expect(_plain(tester), contains('경고 1'));
  });

  testWidgets('목록이 비면 예전처럼 "총 조립 구간"', (tester) async {
    SharedPreferences.setMockInitialValues({});
    MobileBendDataManager().bendList.clear();
    await pump(tester, const MobileInputTab());
    expect(find.byKey(const Key('input_cut_summary')), findsNothing);
    expect(find.text('총 조립 구간'), findsOneWidget);
  });
}
