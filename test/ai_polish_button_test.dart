import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/core/utils/ai_polish.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/widgets/ai_polish_button.dart';

Widget _host(TextEditingController c, AiPolishCall polish) => MaterialApp(
  home: Scaffold(body: Center(child: AiPolishButton(controller: c, polish: polish))),
);

void main() {
  test('오류 코드 → 한글 안내', () {
    expect(aiPolishErrorMessage('unauthenticated', null), contains('로그인'));
    expect(aiPolishErrorMessage('resource-exhausted', '오늘 30번까지'), '오늘 30번까지');
    expect(aiPolishErrorMessage('unavailable', null), contains('응답'));
    expect(aiPolishErrorMessage('x', null), contains('처리하지 못했습니다'));
    expect(aiPolishErrorMessage('permission-denied', null), contains('사용 승인'));
  });

  testWidgets('바꾸기를 눌러야만 글이 바뀐다', (tester) async {
    final c = TextEditingController(text: '센서3 결선');
    String? sent;
    await tester.pumpWidget(_host(c, (t) async {
      sent = t;
      return const AiPolishResult.ok('센서 3개소 결선 완료', remaining: 29);
    }));
    await tester.tap(find.text('AI로 다듬기'));
    await tester.pumpAndSettle();
    expect(sent, '센서3 결선');
    expect(find.text('센서 3개소 결선 완료'), findsOneWidget);
    expect(c.text, '센서3 결선'); // 아직 안 바뀜
    await tester.tap(find.text('그대로 두기'));
    await tester.pumpAndSettle();
    expect(c.text, '센서3 결선');

    await tester.tap(find.text('AI로 다듬기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('바꾸기'));
    await tester.pumpAndSettle();
    expect(c.text, '센서 3개소 결선 완료');
  });

  testWidgets('다듬는 사이 글을 더 썼으면 바꾸기를 눌러도 덮지 않는다(10-08)', (tester) async {
    final c = TextEditingController(text: '센서3 결선');
    await tester.pumpWidget(_host(c, (t) async {
      c.text = '센서3 결선, 내일 루프 시험'; // 기다리는 사이 더 씀
      return const AiPolishResult.ok('센서 3개소 결선 완료', remaining: 29);
    }));
    await tester.tap(find.text('AI로 다듬기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('바꾸기'));
    await tester.pumpAndSettle();
    expect(c.text, '센서3 결선, 내일 루프 시험');
    expect(find.textContaining('글이 바뀌어'), findsOneWidget);
  });

  testWidgets('실패하면 글은 그대로, 안내만 뜬다', (tester) async {
    final c = TextEditingController(text: '튜브 연결');
    await tester.pumpWidget(_host(c, (t) async => const AiPolishResult.fail('AI가 지금 응답하지 않습니다')));
    await tester.tap(find.text('AI로 다듬기'));
    await tester.pumpAndSettle();
    expect(find.text('AI가 지금 응답하지 않습니다'), findsOneWidget);
    expect(c.text, '튜브 연결');
  });

  testWidgets('빈 글이면 서버를 부르지 않는다', (tester) async {
    final c = TextEditingController();
    var called = false;
    await tester.pumpWidget(_host(c, (t) async {
      called = true;
      return const AiPolishResult.ok('x');
    }));
    await tester.tap(find.text('AI로 다듬기'));
    await tester.pump();
    expect(called, false);
    expect(find.textContaining('먼저 적어'), findsOneWidget);
  });
}
