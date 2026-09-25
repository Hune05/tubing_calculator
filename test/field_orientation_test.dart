// 현장 탭을 나가면 화면 방향 고정을 푸는지(점검 33번).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/field/field_marking_screen.dart';
import 'package:tubing_calculator/src/presentation/field/field_marking.dart';

void main() {
  testWidgets('현장 탭을 떠나면 가로 고정을 풀고, 세로로 묶지 않는다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final orientations = <List<dynamic>>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          orientations.add(List<dynamic>.from(call.arguments as List));
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.binding.setSurfaceSize(const Size(882, 344));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Widget screen(bool active) => MaterialApp(
      home: FieldMarkingScreen(
        listenable: ValueNotifier(0),
        compute: () => FieldMarkingData.empty,
        isActive: active,
      ),
    );
    await tester.pumpWidget(screen(true));
    await tester.pump();
    expect(orientations.last, isNotEmpty); // 켜 있을 때는 가로

    await tester.pumpWidget(screen(false)); // 다른 탭으로
    await tester.pump();
    // 예전: [portraitUp, portraitDown]로 앱 전체를 세로에 묶었다.
    expect(orientations.last, isEmpty);

    await tester.pumpWidget(const SizedBox()); // 계산기를 나감
    await tester.pump();
    expect(orientations.last, isEmpty);
  });
}
