// 10-09: 전선관 마킹 탭 "가로 도면 보기"로 따로 띄운 현장 화면은 닫기·뒤로에서
// "닫기 → 막힘 → 다시 닫기"가 끝없이 돌아 앱이 멈췄다(onCloseTab 없이 띄움).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/field/field_marking.dart';
import 'package:tubing_calculator/src/presentation/field/field_marking_screen.dart';

void main() {
  Future<void> openPushed(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(882, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                key: const Key('open_field'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => FieldMarkingScreen(
                      listenable: ValueNotifier(0),
                      compute: () => FieldMarkingData.empty,
                    ),
                  ),
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open_field')));
    await tester.pumpAndSettle();
    expect(find.byType(FieldMarkingScreen), findsOneWidget);
  }

  testWidgets('따로 띄운 현장 화면은 뒤로가기 한 번에 닫힌다(멈추지 않는다)', (tester) async {
    await openPushed(tester);
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    await nav.maybePop();
    await tester.pumpAndSettle();
    expect(find.byType(FieldMarkingScreen), findsNothing);
    expect(find.byKey(const Key('open_field')), findsOneWidget);
  });
}
