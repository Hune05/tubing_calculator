// 밀어서 지우기 첫 안내(10-02): 처음 한 번만 첫 줄이 살짝 밀렸다 돌아오고 안내가 뜬다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/common_widgets/swipe_to_delete.dart';

Widget _list() => MaterialApp(
  home: Scaffold(
    body: ListView(
      children: [
        for (final n in ['가', '나'])
          SwipeToDelete(
            itemKey: ValueKey(n),
            onDelete: () {},
            child: SizedBox(height: 60, width: double.infinity, child: Text('줄 $n')),
          ),
      ],
    ),
  ),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SwipeToDelete.debugForceHint = true;
    SwipeToDelete.debugResetHint();
  });
  tearDown(() => SwipeToDelete.debugForceHint = false);

  testWidgets('처음에는 안내가 한 번 뜨고 첫 줄만 살짝 밀린다', (tester) async {
    await tester.pumpWidget(_list());
    await tester.pump(); // 첫 그림 뒤 안내 시작
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('줄을 왼쪽으로 밀면 삭제됩니다'), findsOneWidget);
    final first = tester.getTopLeft(find.text('줄 가')).dx;
    final second = tester.getTopLeft(find.text('줄 나')).dx;
    expect(first, lessThan(second)); // 첫 줄만 왼쪽으로
    await tester.pumpAndSettle(const Duration(seconds: 8));
    expect(tester.getTopLeft(find.text('줄 가')).dx, second); // 제자리로
    final p = await SharedPreferences.getInstance();
    expect(p.getBool(SwipeToDelete.hintSeenKey), true);
  });

  testWidgets('한 번 본 뒤에는 다시 안 뜬다', (tester) async {
    SharedPreferences.setMockInitialValues({SwipeToDelete.hintSeenKey: true});
    await tester.pumpWidget(_list());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('줄을 왼쪽으로 밀면 삭제됩니다'), findsNothing);
    expect(tester.getTopLeft(find.text('줄 가')).dx, tester.getTopLeft(find.text('줄 나')).dx);
  });
}
