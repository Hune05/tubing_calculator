// 아래 시트 안에서 띄우는 알림(10-09): 시트 밑 화면이 아니라 시트 위에 보여야 한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/core/common_widgets/app_components.dart';

void main() {
  testWidgets('시트를 연 채로 띄운 알림이 시트 위에 보이고, 시간이 지나면 사라진다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (sheet) => SizedBox(
                  height: 600,
                  child: Center(
                    child: TextButton(
                      onPressed: () => showSheetSnack(
                        sheet,
                        '넣을 수 없습니다. 각도를 넣으십시오.',
                        key: const Key('t_missing'),
                      ),
                      child: const Text('넣기'),
                    ),
                  ),
                ),
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('넣기'));
    await tester.pump();

    final toast = find.byKey(const Key('t_missing'));
    expect(toast, findsOneWidget);
    // 알림 가운데를 누르면 시트가 아니라 알림이 맞는다(가려지지 않았다).
    final center = tester.getCenter(toast);
    final hit = tester.hitTestOnBinding(center);
    final toastBox = tester.renderObject(toast);
    expect(hit.path.any((e) => e.target == toastBox), isTrue);

    // 같은 알림을 또 띄워도 하나만.
    await tester.tap(find.text('넣기'));
    await tester.pump();
    expect(find.byKey(const Key('t_missing')), findsOneWidget);

    await tester.pump(kAppSnackDuration + const Duration(milliseconds: 100));
    await tester.pump();
    expect(find.byKey(const Key('t_missing')), findsNothing);
  });
}
