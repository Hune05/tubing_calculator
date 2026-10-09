// 10-09: 전선관 설정을 바꾸고 저장을 안 누르면 마킹은 옛 설정으로 셈하고 나가면 말없이 사라졌다
// → "저장하지 않은 값이 있습니다" 표시.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_settings_page.dart';

void main() {
  testWidgets('값을 바꾸면 표시가 뜨고, 저장하면 사라진다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    globalBenderSettings.value = {...globalBenderSettings.value, 'benderType': 'ram', 'gain': 40.0};
    await tester.binding.setSurfaceSize(const Size(420, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: ConduitSettingsPage()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('conduit_settings_unsaved')), findsNothing);

    final gain = find.byWidgetPredicate(
      (w) => w is TextField && w.controller?.text == '40.0',
    );
    tester.widget<TextField>(gain.first).controller!.text = '45';
    await tester.pump();
    expect(find.byKey(const Key('conduit_settings_unsaved')), findsOneWidget);

    await tester.tap(find.text('현재 장비 설정 저장'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('conduit_settings_unsaved')), findsNothing);
    expect(globalBenderSettings.value['gain'], 45.0);
  });
}
