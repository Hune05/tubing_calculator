// 앱 전체 숫자 칸: 들어가면 값 전체를 골라 새로 친 숫자로 바뀐다(10-13, 사용자: "수치 변경할 때
// 왜 기준 수치가 안 날아가고 이어 쓰기 되냐"). 글 칸·읽기 전용 칸은 그대로.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/core/common_widgets/number_field_select_all.dart';
import 'package:tubing_calculator/src/core/common_widgets/text_fields_traversal.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/pressure_test_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

bool _all(TextEditingController c) =>
    c.selection == TextSelection(baseOffset: 0, extentOffset: c.text.length);

void main() {
  late Map<String, TextEditingController> ctrls;

  setUp(() {
    ctrls = {
      'n1': TextEditingController(text: '1200'),
      'n2': TextEditingController(text: '50'),
      'txt': TextEditingController(text: '메모 글'),
      'ro': TextEditingController(text: '30'),
      'empty': TextEditingController(),
    };
  });

  Future<void> pump(WidgetTester tester) async {
    // main.dart와 같이 MaterialApp builder에 건다(창·시트도 같이 걸린다).
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => FocusTraversalGroup(
          policy: TextFieldsOnlyTraversalPolicy(),
          child: NumberFieldSelectAll(child: child!),
        ),
        home: Scaffold(
          body: Column(
            children: [
              TextField(
                key: const Key('n1'),
                controller: ctrls['n1'],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
              ),
              TextField(
                key: const Key('n2'),
                controller: ctrls['n2'],
                keyboardType: TextInputType.number,
              ),
              TextField(key: const Key('txt'), controller: ctrls['txt']),
              TextField(
                key: const Key('ro'),
                controller: ctrls['ro'],
                readOnly: true,
                keyboardType: TextInputType.number,
              ),
              TextField(
                key: const Key('empty'),
                controller: ctrls['empty'],
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('숫자 칸을 누르면 값 전체를 고른다', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('n1')));
    await tester.pump();
    await tester.pump();
    expect(ctrls['n1']!.text, '1200');
    expect(_all(ctrls['n1']!), isTrue);
  });

  testWidgets('들어가 있는 칸을 한 번 더 누르면 고르지 않고 커서만 놓인다', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('n1')));
    await tester.pump();
    await tester.pump();
    expect(_all(ctrls['n1']!), isTrue);
    await tester.tap(find.byKey(const Key('n1')));
    await tester.pump();
    await tester.pump();
    expect(ctrls['n1']!.selection.isCollapsed, isTrue);
  });

  testWidgets('키보드 "다음"으로 옮겨 간 숫자 칸도 전체를 고른다', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('n1')));
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    await tester.pump();
    expect(_all(ctrls['n2']!), isTrue);
  });

  testWidgets('글 칸·읽기 전용 칸·빈 칸은 그대로', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('txt')));
    await tester.pump();
    await tester.pump();
    expect(ctrls['txt']!.selection.isCollapsed, isTrue);

    await tester.tap(find.byKey(const Key('ro')));
    await tester.pump();
    await tester.pump();
    expect(
      ctrls['ro']!.selection.isCollapsed || !ctrls['ro']!.selection.isValid,
      isTrue,
    );

    await tester.tap(find.byKey(const Key('empty')));
    await tester.pump();
    await tester.pump();
    expect(ctrls['empty']!.selection.isCollapsed, isTrue);
  });

  testWidgets('다른 칸에 갔다가 돌아오면 다시 전체를 고른다', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('n1')));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const Key('txt')));
    await tester.pump();
    await tester.pump();
    expect(ctrls['n1']!.text, '1200');
    await tester.tap(find.byKey(const Key('n1')));
    await tester.pump();
    await tester.pump();
    expect(_all(ctrls['n1']!), isTrue);
  });

  testWidgets('실제 화면(압력시험): 적어 둔 설계압력 칸에 다시 들어가면 값 전체를 고른다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => NumberFieldSelectAll(child: child!),
        home: const PressureTestPage(),
      ),
    );
    await tester.pumpAndSettle();
    final f = find.byKey(const Key('pt_design'));
    await tester.ensureVisible(f);
    await tester.enterText(f, '10.5');
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.tap(f);
    await tester.pump();
    await tester.pump();
    final c = tester
        .widget<EditableText>(
          find.descendant(of: f, matching: find.byType(EditableText)),
        )
        .controller;
    expect(c.text, '10.5');
    expect(_all(c), isTrue, reason: '${c.selection}');
  });
}
