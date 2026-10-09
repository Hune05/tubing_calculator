// 알림을 줄 세우지 않기(10-09): 같은 알림을 여러 번 눌러도 한 번만, 다른 알림은 앞 것을 바로 바꾼다,
// 되돌리기 알림은 지우지 않는다. 예전에는 "못 꺾는 방향"을 다섯 번 누르면 4초씩 다섯 번 차례로 떴다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/core/common_widgets/app_components.dart';
import 'package:tubing_calculator/src/core/common_widgets/snack_once.dart';

Future<BuildContext> _host(WidgetTester tester) async {
  late BuildContext ctx;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox.expand();
          },
        ),
      ),
    ),
  );
  return ctx;
}

void main() {
  testWidgets('같은 알림을 다섯 번 띄워도 한 번만 뜨고, 4초 남짓 뒤에는 남은 것이 없다', (tester) async {
    final ctx = await _host(tester);
    for (var i = 0; i < 5; i++) {
      showAppSnack(ctx, "'LEFT' 쪽으로는 지금 꺾을 수 없습니다.", kind: AppSnackKind.error);
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SnackBar), findsOneWidget);
    // 4초 + 사라지는 시간 뒤: 줄 서 있던 알림이 없어야 한다(예전에는 4번 더 떴다).
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('다른 알림은 앞 알림을 바로 바꾼다(줄 서지 않는다)', (tester) async {
    final ctx = await _host(tester);
    showAppSnack(ctx, '첫째');
    await tester.pumpAndSettle();
    showAppSnack(ctx, '둘째');
    await tester.pumpAndSettle();
    expect(find.text('첫째'), findsNothing);
    expect(find.text('둘째'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('되돌리기 알림이 떠 있으면 지우지 않고, 새 알림은 그 뒤에 뜬다', (tester) async {
    final ctx = await _host(tester);
    showAppSnack(ctx, '지웠습니다', kind: AppSnackKind.undo, onUndo: () {});
    await tester.pumpAndSettle();
    showAppSnack(ctx, '다른 알림', kind: AppSnackKind.error);
    await tester.pumpAndSettle();
    expect(find.text('지웠습니다'), findsOneWidget);
    expect(find.text('되돌리기'), findsOneWidget);
    // 되돌리기 알림(6초)이 끝나면 다음 알림이 뜬다.
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(find.text('다른 알림'), findsOneWidget);
  });

  testWidgets('글 하나짜리 알림도 같은 글이면 한 번만(직접 SnackBar를 넘기는 곳)', (tester) async {
    final ctx = await _host(tester);
    final m = ScaffoldMessenger.of(ctx);
    final a = showSnackOnce(m, const SnackBar(content: Text('저장했습니다')));
    final b = showSnackOnce(m, const SnackBar(content: Text('저장했습니다')));
    expect(identical(a, b), isTrue);
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(showSnackOnce(null, const SnackBar(content: Text('x'))), isNull);
  });
}
