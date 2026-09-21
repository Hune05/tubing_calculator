// 튜브 설정 탭을 전선관 모양(한 줄씩, 오른쪽 값)으로 바꾼 뒤:
// 좁은 폰·가로에서 넘치지 않고, 이름표("튜브")가 붙고, AUTO 칸은 잠겨 있는지.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/utils/app_settings_controller.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_settings_tab.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'benderBrand': 'Swagelok',
      'benderType': '수동 (Hand)',
    });
    MachineSpecs().resetForTest();
  });

  Future<List<String>> open(WidgetTester tester, Size size) async {
    await AppSettingsController().load();
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final errors = <String>[];
    final old = FlutterError.onError;
    FlutterError.onError = (d) => errors.add(d.exceptionAsString());
    try {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: MobileSettingsTab())),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      // 끝까지 내려 본다.
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -3000),
      );
      await tester.pump();
    } finally {
      FlutterError.onError = old;
    }
    return errors;
  }

  for (final size in const [Size(320, 700), Size(390, 844), Size(800, 360)]) {
    testWidgets('넘치지 않는다 ${size.width.toInt()}×${size.height.toInt()}', (
      tester,
    ) async {
      expect(await open(tester, size), isEmpty);
    });
  }

  testWidgets('제목에 "튜브" 이름표, 묶음 제목, AUTO 칸은 눌러도 숫자판이 안 뜬다', (tester) async {
    await open(tester, const Size(420, 3000));
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, 3000),
    );
    await tester.pump();
    expect(find.text('장비 세팅 가이드'), findsOneWidget);
    expect(find.byKey(const ValueKey('calc_tag_tube')), findsOneWidget);
    expect(find.text('튜브 기본 제원'), findsOneWidget);
    expect(find.text('제원 수치 (수동)'), findsOneWidget);

    // 반경은 AUTO(제원으로 셈) → 잠김.
    expect(find.byKey(const ValueKey('auto_radius')), findsOneWidget);
    // AUTO를 누르면 MAN으로 바뀐다.
    await tester.tap(find.byKey(const ValueKey('auto_radius')));
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('auto_radius')),
        matching: find.text('MAN'),
      ),
      findsOneWidget,
    );
  });
}
