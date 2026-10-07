// 이슈 상세: 처리 메모를 쓰고 '처리 완료'를 안 누른 채 나가면 한 번 묻는다(10-07: 묻지 않고 사라졌다).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/theme/app_icon_set.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/punch_detail_page.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('처리 메모를 쓰고 뒤로 가면 묻고, 취소하면 남고, 버리면 나간다', (tester) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () async {
                await Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => PunchDetailPage(
                      punch: {
                        'content': '볼트 풀림',
                        'location': '2층',
                        'is_completed': false,
                        'created_at': DateTime(2026, 10, 7),
                      },
                    ),
                  ),
                );
                closed = true;
              },
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    // 아무것도 안 쓰면 묻지 않고 나간다.
    await tester.tap(find.byIcon(AppIcons.back));
    await tester.pumpAndSettle();
    expect(closed, isTrue);

    closed = false;
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '토크 다시 잡음');
    await tester.pump();
    await tester.tap(find.byIcon(AppIcons.back));
    await tester.pumpAndSettle();
    expect(find.text('버리기'), findsOneWidget); // 확인 창(제목은 줄바꿈 막는 글자가 섞여 단추로 본다)
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(closed, isFalse);
    expect(find.text('토크 다시 잡음'), findsOneWidget);

    await tester.tap(find.byIcon(AppIcons.back));
    await tester.pumpAndSettle();
    await tester.tap(find.text('버리기'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
  });
}
