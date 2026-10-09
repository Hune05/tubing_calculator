// 배관 플랜지 볼트 표·조임 순서(10-10): ASME B16.5 값 몇 줄을 원표와 대조하고, 조임 순서가
// 모든 볼트를 한 번씩, 마주 보는 볼트를 잇달아 조이는지 본다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/reference/flange_bolt_data.dart';
import 'package:tubing_calculator/src/presentation/reference/page/ref_tube_tab.dart';

FlangeBoltRow _row(int cls, String nps) =>
    kFlangeBolts[cls]!.firstWhere((r) => r.nps == nps);

void main() {
  test('ASME B16.5 표 대조(원표 값)', () {
    expect(_row(150, '4"').bolts, 8);
    expect(_row(150, '4"').dia, '5/8"');
    expect(_row(150, '4"').circleMm, 190.5); // 7-1/2"
    expect(_row(150, '3"').bolts, 4);
    expect(_row(150, '24"').dia, '1-1/4"');
    expect(_row(300, '2"').bolts, 8);
    expect(_row(300, '6"').bolts, 12);
    expect(_row(300, '12"').dia, '1-1/8"');
    expect(_row(600, '12"').bolts, 20);
    expect(_row(600, '24"').dia, '1-7/8"');
    for (final rows in kFlangeBolts.values) {
      expect(rows.length, 20);
      for (final r in rows) {
        expect(kFlangeTightenOrder.containsKey(r.bolts), isTrue,
            reason: '${r.nps} ${r.bolts}개 순서가 있어야 한다');
      }
    }
  });

  test('조임 순서: 모든 볼트를 한 번씩, 네 개 묶음마다 마주 보는 두 쌍(90° 간격)', () {
    kFlangeTightenOrder.forEach((n, o) {
      expect(o.toSet(), {for (int i = 1; i <= n; i++) i}, reason: '$n개');
      expect(o.length, n);
      final half = n ~/ 2;
      final quarter = n ~/ 4;
      for (int i = 0; i < n; i += 4) {
        final g = o.sublist(i, i + 4);
        expect(g[1] - g[0], half, reason: '$n개 $g 첫 쌍은 마주 보기');
        expect(g[3] - g[2], half, reason: '$n개 $g 둘째 쌍은 마주 보기');
        expect(g[2] - g[0], quarter, reason: '$n개 $g 둘째 쌍은 90° 옆');
      }
    });
    expect(flangeOrderText(8), '1-5-3-7 · 2-6-4-8');
  });

  testWidgets('현장 자료 튜브 탭: 클래스·볼트 수를 고르면 표와 순서가 바뀐다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: RefTubeTab())),
    );
    await tester.pumpAndSettle();
    final order = find.byKey(const Key('flange_order_text'));
    await tester.scrollUntilVisible(
      order,
      600,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(order).data, '1-5-3-7 · 2-6-4-8');
    await tester.tap(find.text('16개'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(order).data,
      '1-9-5-13 · 3-11-7-15 · 2-10-6-14 · 4-12-8-16',
    );
    expect(find.text('6" (150A)'), findsOneWidget);
    await tester.ensureVisible(find.text('Class 600'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Class 600'));
    await tester.pumpAndSettle();
    expect(find.text('1-7/8"'), findsOneWidget);
  });
}
