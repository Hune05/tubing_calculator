// 빠른 도구 막대를 앱 전체에 얹었을 때: 어느 화면에서나 손잡이가 있고, 창·시트가 뜨거나 화면이 빼 달라고
// 하거나 가로로 눕히면 숨으며, 도구를 누르면 앱의 화면 위에 열린다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/common/app_icons.dart';
import 'package:tubing_calculator/src/presentation/common/quick_tool_bar.dart';

final _key = GlobalKey<NavigatorState>();
final _tools = [
  QuickToolDef('a', '도구A', AppGlyph.engCalc, (_) => const _Page('A화면')),
];

class _Page extends StatelessWidget {
  final String name;
  final bool suppress;
  const _Page(this.name, {this.suppress = false});
  @override
  Widget build(BuildContext context) {
    final body = Scaffold(
      appBar: AppBar(title: Text(name)),
      body: Column(
        children: [
          TextButton(
            key: const Key('open_page'),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const _Page('둘째'))),
            child: const Text('다음'),
          ),
          TextButton(
            key: const Key('open_suppressed'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const _Page('도면', suppress: true),
              ),
            ),
            child: const Text('도면'),
          ),
          TextButton(
            key: const Key('open_dialog'),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const AlertDialog(title: Text('창')),
            ),
            child: const Text('창 열기'),
          ),
        ],
      ),
    );
    return suppress ? QuickBarSuppress(child: body) : body;
  }
}

Future<void> _mount(WidgetTester tester, {Size size = const Size(400, 800)}) async {
  SharedPreferences.setMockInitialValues({
    kQuickToolIdsKey: ['a'],
  });
  QuickBarGate.tracker.reset();
  QuickBarGate.suppressed.value = 0;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: _key,
      navigatorObservers: [QuickBarGate.tracker],
      builder: (context, child) => GlobalQuickToolBar(
        navigatorKey: _key,
        tools: _tools,
        child: child ?? const SizedBox(),
      ),
      home: const _Page('첫째'),
    ),
  );
  await tester.pumpAndSettle();
}

final _handle = find.byKey(const Key('quick_tool_handle'));

void main() {
  testWidgets('첫 화면에도 다음 화면에도 손잡이가 있다', (tester) async {
    await _mount(tester);
    expect(_handle, findsOneWidget);
    await tester.tap(find.byKey(const Key('open_page')));
    await tester.pumpAndSettle();
    expect(find.text('둘째'), findsWidgets);
    expect(_handle, findsOneWidget);
  });

  testWidgets('손잡이로 열고 도구를 누르면 앱의 화면 위에 열리고, 뒤로 가면 그 화면 그대로', (tester) async {
    await _mount(tester);
    await tester.tap(find.byKey(const Key('open_page')));
    await tester.pumpAndSettle();
    await tester.tap(_handle);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick_tool_a')));
    await tester.pumpAndSettle();
    expect(find.text('A화면'), findsWidgets);
    _key.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('둘째'), findsWidgets);
  });

  testWidgets('전체·편집 창도 앱의 화면 위에 열린다', (tester) async {
    await _mount(tester);
    await tester.tap(_handle);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick_tool_all')));
    await tester.pumpAndSettle();
    expect(find.text('전체 기능'), findsWidgets);
    _key.currentState!.pop();
    await tester.pumpAndSettle();

    await tester.tap(_handle);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick_tool_edit')));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('창이 떠 있는 동안은 숨고, 닫으면 돌아온다', (tester) async {
    await _mount(tester);
    await tester.tap(find.byKey(const Key('open_dialog')));
    await tester.pumpAndSettle();
    expect(find.text('창'), findsOneWidget);
    expect(_handle, findsNothing);
    _key.currentState!.pop();
    await tester.pumpAndSettle();
    expect(_handle, findsOneWidget);
  });

  testWidgets('빼 달라는 화면에서는 숨고, 나오면 돌아온다', (tester) async {
    await _mount(tester);
    await tester.tap(find.byKey(const Key('open_suppressed')));
    await tester.pumpAndSettle();
    expect(_handle, findsNothing);
    expect(QuickBarGate.suppressed.value, 1);
    _key.currentState!.pop();
    await tester.pumpAndSettle();
    expect(_handle, findsOneWidget);
    expect(QuickBarGate.suppressed.value, 0);
  });

  testWidgets('열린 막대는 그 화면이 빼 달라고 하면 접힌다', (tester) async {
    await _mount(tester);
    await tester.tap(_handle);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quick_tool_panel')), findsOneWidget);
    // 열린 채로 빼는 화면으로 넘어간다(막대 밖 도구가 아닌 경로)
    _key.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const _Page('도면', suppress: true)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quick_tool_panel')), findsNothing);
    expect(_handle, findsNothing);
  });

  testWidgets('가로로 눕히면 숨는다', (tester) async {
    await _mount(tester, size: const Size(800, 400));
    expect(_handle, findsNothing);
  });
}
