// 설정 화면이 열려 있는 동안 다른 곳에서 설정이 바뀌면(저장 도면 "저장 때 설정으로", 서버에서 받기 등)
// 화면 칸도 새 값을 보여 줘야 한다. 안 그러면 옛 값이 보이고, 저장을 누르면 옛 값이 되살아난다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_settings_page.dart';

void main() {
  late Map<String, dynamic> original;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    original = Map<String, dynamic>.from(globalBenderSettings.value);
    globalBenderSettings.value = {...original, 'benderType': 'ram', 'gain': 40.0};
  });
  tearDown(() => globalBenderSettings.value = original);

  testWidgets('바깥에서 게인이 바뀌면 설정 화면 칸이 따라 바뀐다', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(420, 2400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: ConduitSettingsPage()));
    await tester.pumpAndSettle();
    expect(find.text('40.0'), findsWidgets);

    globalBenderSettings.value = {...globalBenderSettings.value, 'gain': 77.5};
    await tester.pumpAndSettle();
    expect(find.text('77.5'), findsWidgets);
    expect(find.text('40.0'), findsNothing);
  });
}
