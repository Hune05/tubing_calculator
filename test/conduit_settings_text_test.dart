// 전선관 설정 화면: 게인 칸(유압·시카고), 단위는 현장 탭 표시용(칸 값은 늘 mm),
// 셈에 안 쓰는 칸 안내, 램 이동 거리 도움말.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_settings_page.dart';

void main() {
  late Map<String, dynamic> defaults;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    defaults = Map<String, dynamic>.from(globalBenderSettings.value);
  });
  tearDown(() => globalBenderSettings.value = defaults);

  Future<void> pump(WidgetTester tester, String type, {String? unit}) async {
    globalBenderSettings.value = {
      ...globalBenderSettings.value,
      'benderType': type,
      'unitSystem': ?unit,
    };
    await tester.binding.setSurfaceSize(const Size(400, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ConduitSettingsPage())),
    );
    await tester.pumpAndSettle();
  }

  for (final type in ['hand', 'ram', 'chicago']) {
    testWidgets('$type: 게인 칸이 있고 단위 칸은 현장 탭 단위', (tester) async {
      await pump(tester, type, unit: '인치 (분수)');
      expect(find.text('벤딩 게인 (Gain)'), findsOneWidget);
      expect(find.text('현장 탭 단위'), findsOneWidget);
      // 인치를 골라도 제원 칸 뒤 글자는 mm(셈이 mm이므로).
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is TextField && (w.decoration?.suffixText ?? '').contains('"'),
        ),
        findsNothing,
      );
    });
  }

  testWidgets('유압: 램 이동 거리는 90° 기준이라고 알려 준다', (tester) async {
    await pump(tester, 'ram');
    final help = find.descendant(
      of: find
          .ancestor(of: find.text('램 이동 거리'), matching: find.byType(Row))
          .first,
      matching: find.byIcon(Icons.help_outline),
    );
    await tester.tap(help);
    await tester.pumpAndSettle();
    expect(find.textContaining('90°로 꺾을 때 램이 나가는 거리'), findsOneWidget);
  });
}
