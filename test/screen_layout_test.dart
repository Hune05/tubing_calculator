// 화면 구성(2026-09-29): 태블릿 모드를 없애고 폰 화면 하나로 통일.
// 큰 화면(짧은 변 800dp 이상)에서는 내용 폭만 600dp로 좁혀 가운데 둔다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/core/utils/screen_layout.dart';

void main() {
  Future<void> pumpHost(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: ScreenLayoutHost(
          child: LayoutBuilder(
            builder: (context, c) => Text(
              'w=${c.maxWidth.toInt()} mq=${MediaQuery.of(context).size.width.toInt()}',
              key: const Key('probe'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String probe(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('probe'))).data!;

  testWidgets('큰 화면(800×1280): 내용 폭 600으로 좁히고 화면 폭도 600으로 알려 준다', (
    tester,
  ) async {
    await pumpHost(tester, const Size(800, 1280));
    expect(probe(tester), 'w=600 mq=600');
    final r = tester.getRect(find.byKey(const Key('probe')));
    expect(r.left, greaterThanOrEqualTo(100)); // 가운데에 모임
  });

  testWidgets('진짜 폰(390 폭)과 가로로 든 폰(800×360)은 좁히지 않는다', (tester) async {
    await pumpHost(tester, const Size(390, 844));
    expect(probe(tester), 'w=390 mq=390');
    await pumpHost(tester, const Size(800, 360));
    expect(probe(tester), 'w=800 mq=800');
  });

  testWidgets('짧은 변이 800dp보다 작으면 좁히지 않는다', (tester) async {
    await pumpHost(tester, const Size(799, 1200));
    expect(probe(tester), 'w=799 mq=799');
  });
}
