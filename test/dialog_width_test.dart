import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/widgets/work_theme.dart';

// 폰 화면 폭(411dp)에서 팝업이 좁아 글이 억지로 줄바꿈되지 않는지 확인한다.
const _titles = [
  '미해결 이슈가 남아 있습니다',
  '남은 이슈를 모두 완료하시겠습니까?',
  '일정을 완료로 표시하시겠습니까?',
  '작성 중이던 작업 일지가 있습니다',
  '마무리 보고서를 만드시겠습니까?',
];

Future<double> titleHeight(
  WidgetTester tester,
  ThemeData theme,
  String t,
) async {
  tester.view.physicalSize = const Size(411 * 3, 900 * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Builder(
        builder: (ctx) => Scaffold(
          body: TextButton(
            onPressed: () => showDialog(
              context: ctx,
              builder: (_) => AlertDialog(
                title: Text(t),
                content: const Text('이슈 1건이 아직 해결되지 않았습니다. 그래도 완료 처리하시겠습니까?'),
                actions: [
                  TextButton(onPressed: () {}, child: const Text('취소')),
                  TextButton(onPressed: () {}, child: const Text('이슈 보기')),
                  TextButton(onPressed: () {}, child: const Text('그래도 완료')),
                ],
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
  final h = tester.getSize(find.text(t)).height;
  return h;
}

void main() {
  test('work theme widens dialogs', () {
    final d = workThemeData().dialogTheme;
    expect(d.insetPadding!.horizontal / 2 <= 12, true);
  });

  testWidgets('short titles stay on one line in the work theme', (
    tester,
  ) async {
    for (final t in _titles) {
      // 이전 반복의 팝업/화면을 비우고 새로 그린다.
      await tester.pumpWidget(const SizedBox());
      final h = await titleHeight(tester, workThemeData(), t);
      // 20sp 한 줄 높이는 약 24~28dp, 두 줄이면 50dp 안팎이다.
      expect(h < 34, true, reason: '$t → 높이 $h');
    }
  });

  testWidgets('buttons of a 3-action dialog fit in one row', (tester) async {
    await titleHeight(tester, workThemeData(), _titles.first);
    final a = tester.getTopLeft(find.text('취소')).dy;
    final b = tester.getTopLeft(find.text('이슈 보기')).dy;
    final c = tester.getTopLeft(find.text('그래도 완료')).dy;
    expect(a == b && b == c, true, reason: '세로로 쌓임: $a $b $c');
  });
}
