// 빠른 도구 막대: 손잡이로 열고, 도구를 누르면 작업 화면 위에 덮여 열리고 닫으면 작업 화면 그대로,
// 편집(도구 고르기·좌우)이 폰에 저장되는지.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/common/app_icons.dart';
import 'package:tubing_calculator/src/presentation/common/quick_tool_bar.dart';

final _tools = [
  QuickToolDef('a', '도구A', AppGlyph.engCalc, (_) => const _ToolPage('A화면')),
  QuickToolDef('b', '도구B', AppGlyph.level, (_) => const _ToolPage('B화면')),
  QuickToolDef('c', '도구C', AppGlyph.protractor, (_) => const _ToolPage('C화면')),
];

class _ToolPage extends StatelessWidget {
  final String name;
  const _ToolPage(this.name);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(name)),
    body: Text(name),
  );
}

Future<void> _mount(
  WidgetTester tester, {
  bool enabled = true,
  Widget? work,
}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: QuickToolBarHost(
          enabled: enabled,
          tools: _tools,
          child: work ?? const _Work(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _Work extends StatefulWidget {
  const _Work();
  @override
  State<_Work> createState() => _WorkState();
}

class _WorkState extends State<_Work> {
  final c = TextEditingController();
  @override
  Widget build(BuildContext context) => Center(
    child: TextField(key: const Key('work_field'), controller: c),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('저장된 도구를 막대 순서대로 고르고, 없으면 기본', () {
    expect(resolveQuickTools(['c', 'a'], _tools).map((t) => t.id), ['a', 'c']);
    expect(resolveQuickTools(['zz'], _tools), isEmpty);
    expect(
      resolveQuickTools(null, kQuickTools).map((t) => t.id),
      kQuickToolDefaultIds,
    );
  });

  testWidgets('손잡이를 탭하면 막대가 열리고, 바깥을 누르면 닫힌다', (tester) async {
    await _mount(tester);
    expect(find.byKey(const Key('quick_tool_panel')), findsNothing);
    await tester.tap(find.byKey(const Key('quick_tool_handle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quick_tool_panel')), findsOneWidget);
    await tester.tapAt(const Offset(40, 400));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quick_tool_panel')), findsNothing);
    expect(find.byKey(const Key('quick_tool_handle')), findsOneWidget);
  });

  testWidgets('안쪽으로 밀어도 열린다(오른쪽 손잡이는 왼쪽으로)', (tester) async {
    SharedPreferences.setMockInitialValues({
      kQuickToolIdsKey: ['a', 'b'],
    });
    await _mount(tester);
    await tester.drag(
      find.byKey(const Key('quick_tool_handle')),
      const Offset(-60, 0),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quick_tool_a')), findsOneWidget);
    expect(find.byKey(const Key('quick_tool_b')), findsOneWidget);
    expect(find.byKey(const Key('quick_tool_c')), findsNothing);
  });

  testWidgets('도구를 누르면 작업 화면 위에 열리고, 돌아오면 입력한 값이 그대로', (tester) async {
    SharedPreferences.setMockInitialValues({
      kQuickToolIdsKey: ['a', 'b'],
    });
    await _mount(tester);
    await tester.enterText(find.byKey(const Key('work_field')), '123.4');
    await tester.tap(find.byKey(const Key('quick_tool_handle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick_tool_a')));
    await tester.pumpAndSettle();
    expect(find.text('A화면'), findsWidgets);
    expect(find.byKey(const Key('quick_tool_panel')), findsNothing);

    // 뒤로 가기(닫기) → 작업 화면 그대로.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('A화면'), findsNothing);
    final tf = tester.widget<TextField>(find.byKey(const Key('work_field')));
    expect(tf.controller!.text, '123.4');
  });

  testWidgets('enabled가 false면 손잡이가 없고, 켰다 꺼도 작업 화면 상태가 유지된다', (tester) async {
    await _mount(tester, enabled: false);
    expect(find.byKey(const Key('quick_tool_handle')), findsNothing);
    expect(find.byKey(const Key('work_field')), findsOneWidget);
  });

  testWidgets('편집: 도구를 끄고 왼쪽으로 옮기면 폰에 저장된다', (tester) async {
    SharedPreferences.setMockInitialValues({
      kQuickToolIdsKey: ['a', 'b'],
    });
    await _mount(tester);
    await tester.tap(find.byKey(const Key('quick_tool_handle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick_tool_edit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quick_tool_edit_sheet')), findsOneWidget);

    await tester.tap(find.byKey(const Key('quick_tool_pick_b')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick_tool_pick_c')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick_tool_side_left')));
    await tester.pumpAndSettle();

    final p = await SharedPreferences.getInstance();
    expect(p.getStringList(kQuickToolIdsKey), ['a', 'c']);
    expect(p.getString(kQuickToolSideKey), 'left');
  });

  testWidgets('저장된 왼쪽 위치로 열린다', (tester) async {
    SharedPreferences.setMockInitialValues({kQuickToolSideKey: 'left'});
    await _mount(tester);
    final handle = tester.getCenter(find.byKey(const Key('quick_tool_handle')));
    expect(handle.dx, lessThan(200));
  });
}
