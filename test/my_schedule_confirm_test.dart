import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_schedule/mobile_my_schedule_page.dart';

void main() {
  Future<List<bool>> run(WidgetTester tester, String tap) async {
    final results = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => results.add(
                await confirmScheduleDelete(
                  context,
                  title: '템플릿 삭제',
                  message: "'주간 점검' 템플릿을 삭제하시겠습니까? 되돌릴 수 없습니다.",
                ),
              ),
              child: const Text('지우기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('지우기'));
    await tester.pumpAndSettle();
    expect(find.text('템플릿 삭제'), findsOneWidget);
    expect(find.textContaining('주간 점검'), findsOneWidget);
    await tester.tap(find.text(tap));
    await tester.pumpAndSettle();
    return results;
  }

  testWidgets('템플릿 삭제는 묻고, 취소하면 지우지 않는다', (tester) async {
    expect(await run(tester, '취소'), [false]);
  });

  testWidgets('템플릿 삭제 창에서 삭제를 누르면 지운다', (tester) async {
    expect(await run(tester, '삭제'), [true]);
  });
}
