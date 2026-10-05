// 한 단계씩 진행을 같은 도면이면 앱을 나갔다 와도 이어 하고, 실측은 저장 직후 되돌릴 수 있다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/bend_check/bend_check_model.dart';
import 'package:tubing_calculator/src/presentation/field/field_marking.dart';
import 'package:tubing_calculator/src/presentation/field/field_marking_screen.dart';

FieldMarkingData dataA() => const FieldMarkingData(
  totalCut: 1762,
  marks: [
    FieldMark(number: 1, position: 1007, angle: 90, rotation: 0, gap: 1007),
    FieldMark(number: 2, position: 1301, angle: 45, rotation: 450, gap: 294),
    FieldMark(number: 3, position: 1439, angle: 45, rotation: 360, gap: 138),
  ],
);

FieldMarkingData dataB() => const FieldMarkingData(
  totalCut: 900,
  marks: [
    FieldMark(number: 1, position: 500, angle: 90, rotation: 0, gap: 500),
  ],
);

Future<void> open(
  WidgetTester tester,
  FieldMarkingData Function() compute,
) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1006, 600);
  await tester.pumpWidget(const SizedBox()); // 앞 화면의 상태를 버린다(앱을 나갔다 온 것과 같다)
  await tester.pumpWidget(
    MaterialApp(
      home: FieldMarkingScreen(
        listenable: ValueNotifier(0),
        compute: compute,
        isActive: false,
        measureGroup: () => '묶음',
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 60)),
  );
  await tester.pumpAndSettle();
}

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 60)),
  );
  await tester.pumpAndSettle();
}

String number(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('field_step_number'))).data!;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.resetPhysicalSize());

  testWidgets('같은 도면이면 다시 열어도 하던 단계에서 이어 한다', (tester) async {
    addTearDown(tester.view.reset);
    await open(tester, dataA);
    await tester.tap(find.byKey(const Key('field_mode_toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(number(tester), '1439'); // 3번 마킹
    await settle(tester);

    await open(tester, dataA); // 앱을 나갔다 다시 열기
    await tester.tap(find.byKey(const Key('field_mode_toggle')));
    await tester.pumpAndSettle();
    expect(number(tester), '1439');
    expect(find.byKey(const Key('field_progress_reset')), findsOneWidget);
  });

  testWidgets('다른 도면이면 처음부터 시작한다', (tester) async {
    addTearDown(tester.view.reset);
    await open(tester, dataA);
    await tester.tap(find.byKey(const Key('field_mode_toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    await settle(tester);

    await open(tester, dataB);
    await tester.tap(find.byKey(const Key('field_mode_toggle')));
    await tester.pumpAndSettle();
    expect(number(tester), '500'); // B의 첫 단계
    expect(find.byKey(const Key('field_progress_reset')), findsNothing);
  });

  testWidgets('처음부터 단추: 확인하면 1번 단계로, 저장된 진행도 비운다', (tester) async {
    addTearDown(tester.view.reset);
    await open(tester, dataA);
    await tester.tap(find.byKey(const Key('field_mode_toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('field_progress_reset')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('field_progress_reset_ok')));
    await tester.pumpAndSettle();
    expect(number(tester), '1007');
    expect(find.byKey(const Key('field_progress_reset')), findsNothing);
    await settle(tester);

    await open(tester, dataA);
    await tester.tap(find.byKey(const Key('field_mode_toggle')));
    await tester.pumpAndSettle();
    expect(number(tester), '1007'); // 다시 열어도 처음
  });

  testWidgets('처음부터 단추에서 취소하면 그대로다', (tester) async {
    addTearDown(tester.view.reset);
    await open(tester, dataA);
    await tester.tap(find.byKey(const Key('field_mode_toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('field_progress_reset')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(number(tester), '1301');
  });

  testWidgets('실측 저장 알림의 되돌리기: 기록과 실측 표시가 사라진다', (tester) async {
    addTearDown(tester.view.reset);
    await open(tester, dataA);
    await tester.tap(find.byKey(const Key('field_mode_toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('field_measure')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('field_measure_input')), '1010');
    await tester.tap(find.byKey(const Key('field_measure_save')));
    // 창이 완전히 닫히고(알림이 눌릴 수 있게) 저장이 끝날 때까지.
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('되돌리기'), findsOneWidget);
    expect((await tester.runAsync(loadBendChecks))!, hasLength(1));

    await tester.tap(find.text('되돌리기'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
    }
    expect((await tester.runAsync(loadBendChecks))!, isEmpty);
    expect(find.textContaining('다시 기록'), findsNothing); // 단추 글자도 처음으로
    expect(find.text('실측 기록'), findsOneWidget);
  });

  testWidgets('실측 표시도 다시 열면 이어진다', (tester) async {
    addTearDown(tester.view.reset);
    await open(tester, dataA);
    await tester.tap(find.byKey(const Key('field_mode_toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('field_measure')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('field_measure_input')), '1010');
    await tester.tap(find.byKey(const Key('field_measure_save')));
    await settle(tester);
    await tester.pump(const Duration(seconds: 7)); // 알림이 사라질 때까지

    await open(tester, dataA);
    // 줄자 보기(기본)의 아래 단계 띠에 첫 단계 실측됨.
    expect(find.byKey(const Key('field_measured_0')), findsOneWidget);
  });
}
