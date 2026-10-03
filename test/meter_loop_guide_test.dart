// 멀티미터로 4-20 mA 재는 법 화면(10-01): 그림 세 장이 뜨고, %로 보기·출력 밀대가 동작하고,
// 전류 흐름 그림은 몇 번 돌고 멈춘다(계속 돌면 pumpAndSettle이 끝나지 않는다).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/instrument/meter_loop_guide_page.dart';

void main() {
  testWidgets('그림 세 장, 순서, 틀린 연결 경고가 있고 끝까지 넘겨도 예외가 없다', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: MeterLoopGuidePage()));
    await tester.pumpAndSettle(); // 흐름 그림이 멈추므로 끝난다
    expect(find.byKey(const Key('mlg_meter')), findsOneWidget);
    expect(find.text('멀티미터로 4-20 mA 측정'), findsOneWidget);
    // %로 보기
    await tester.ensureVisible(find.text('4-20mA %로 보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('4-20mA %로 보기'));
    await tester.pumpAndSettle();
    expect(find.text('전송기 출력 12.0 mA (50.0%)'), findsOneWidget);
    // 밀대를 끝까지 → 20 mA
    await tester.ensureVisible(find.byKey(const Key('mlg_slider')));
    await tester.pumpAndSettle();
    final sl = tester.getRect(find.byKey(const Key('mlg_slider')));
    await tester.tapAt(Offset(sl.right - 4, sl.center.dy));
    await tester.pumpAndSettle();
    await tester.drag(find.byKey(const Key('mlg_list')), const Offset(0, 200));
    await tester.pumpAndSettle();
    expect(find.text('전송기 출력 20.0 mA (100.0%)'), findsOneWidget);
    final list = find.byKey(const Key('mlg_list'));
    await tester.dragUntilVisible(find.byKey(const Key('mlg_loop')), list, const Offset(0, -300));
    await tester.dragUntilVisible(find.byKey(const Key('mlg_wrong')), list, const Offset(0, -300));
    expect(find.textContaining('전원이 바로 합선'), findsOneWidget);
    await tester.dragUntilVisible(find.text('5. 값이 이상할 때'), list, const Offset(0, -300));
    await tester.dragUntilVisible(find.textContaining('약 1.2 Ω 이하가 정상'), list, const Offset(0, -300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('흐름 다시 보기를 누르면 다시 돌고 또 멈춘다', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: MeterLoopGuidePage()));
    await tester.pumpAndSettle();
    final replay = find.byKey(const Key('mlg_replay'));
    await tester.dragUntilVisible(replay, find.byKey(const Key('mlg_list')), const Offset(0, -300));
    await tester.tap(replay);
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });
}
