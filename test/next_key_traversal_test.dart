// 앱 전체 "다음" 키 규칙: 다른 계산기(압력시험)에서도 "?" 도움말을 건너뛰고 다음 글자 칸으로 간다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/common_widgets/text_fields_traversal.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/pressure_test_page.dart';

bool _focused(WidgetTester tester, String key) => tester
    .widget<EditableText>(
      find.descendant(of: find.byKey(Key(key)), matching: find.byType(EditableText)),
    )
    .focusNode
    .hasFocus;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('압력시험: 설계압력 → "다음" → 실제 시험압력(도움말 창 없음)', (tester) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // main.dart와 같이 MaterialApp builder에서 규칙을 건다(화면은 Navigator 안).
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => FocusTraversalGroup(
          policy: TextFieldsOnlyTraversalPolicy(),
          child: child!,
        ),
        home: const PressureTestPage(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('pt_design')));
    await tester.tap(find.byKey(const Key('pt_design')));
    await tester.pump();
    expect(_focused(tester, 'pt_design'), isTrue);
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    final keys = ['pt_ratio', 'pt_actual'];
    expect(keys.any((k) => find.byKey(Key(k)).evaluate().isNotEmpty && _focused(tester, k)), isTrue);
  });
}
