// 폴드를 펼치거나 접어도 전선관 탭들의 상태(입력 중인 칸, 저장 안 한 설정)가
// 남는지. 예전에는 좁은/넓은 배치에서 탭을 놓는 자리가 달라 새로 만들어졌다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/models/conduit_data_manager.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_input_tab.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_settings_page.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/main_navigation_page.dart';

void main() {
  late Map<String, dynamic> defaults;
  setUp(() {
    defaults = Map<String, dynamic>.from(globalBenderSettings.value);
    SharedPreferences.setMockInitialValues({});
    ConduitDataManager().bendList.clear();
  });
  tearDown(() => globalBenderSettings.value = defaults);

  testWidgets('좁은 화면 → 넓은 화면 → 좁은 화면에서 같은 State', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.reset);
    final errors = <String>[];
    final old = FlutterError.onError;
    FlutterError.onError = (d) => errors.add(d.exceptionAsString());
    State input0, settings0;
    try {
      await tester.pumpWidget(const MaterialApp(home: ConduitMainNavigation()));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      // 좁은 화면이면 입력 탭이 화면 폭을 다 쓴다.
      expect(
        tester.getSize(find.byType(ConduitInputTab, skipOffstage: false)).width,
        360,
      );
      input0 = tester.state(find.byType(ConduitInputTab, skipOffstage: false));
      settings0 = tester.state(
        find.byType(ConduitSettingsPage, skipOffstage: false),
      );

      tester.view.physicalSize = const Size(900, 800);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        tester.state(find.byType(ConduitInputTab, skipOffstage: false)),
        same(input0),
      );
      expect(
        tester.state(find.byType(ConduitSettingsPage, skipOffstage: false)),
        same(settings0),
      );

      tester.view.physicalSize = const Size(360, 800);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        tester.state(find.byType(ConduitInputTab, skipOffstage: false)),
        same(input0),
      );
    } finally {
      FlutterError.onError = old;
    }
    expect(errors, isEmpty);
  });
}
