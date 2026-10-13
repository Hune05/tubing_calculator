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
    FieldMark(
      number: 1,
      position: 1007,
      angle: 90,
      rotation: 0,
      gap: 1007,
      leg: 1030,
    ),
    FieldMark(
      number: 2,
      position: 1301,
      angle: 45,
      rotation: 450,
      gap: 294,
      leg: 320,
    ),
    FieldMark(
      number: 3,
      position: 1439,
      angle: 45,
      rotation: 360,
      gap: 138,
      leg: 160,
    ),
  ],
);

FieldMarkingData dataB() => const FieldMarkingData(
  totalCut: 900,
  marks: [
    FieldMark(
      number: 1,
      position: 500,
      angle: 90,
      rotation: 0,
      gap: 500,
      leg: 520,
    ),
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
  tearDown(
    () => TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
        .resetPhysicalSize(),
  );

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

  testWidgets('실측 칸에 못 읽는 값을 넣으면 창을 닫지 않고 까닭을 보인다(10-08)', (tester) async {
    addTearDown(tester.view.reset);
    await open(tester, dataA);
    await tester.tap(find.byKey(const Key('field_mode_toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('field_measure')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('field_measure_input')),
      '1.234.5',
    );
    await tester.tap(find.byKey(const Key('field_measure_save')));
    await tester.pump();
    expect(find.text('0보다 큰 숫자로 넣으십시오.'), findsOneWidget);
    expect(find.byKey(const Key('field_measure_input')), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
  });

  testWidgets('실측 저장 알림의 되돌리기: 기록과 실측 표시가 사라진다', (tester) async {
    addTearDown(tester.view.reset);
    await open(tester, dataA);
    await tester.tap(find.byKey(const Key('field_mode_toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('field_measure')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('field_measure_input')),
      '1010',
    );
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
    await tester.enterText(
      find.byKey(const Key('field_measure_input')),
      '1010',
    );
    await tester.tap(find.byKey(const Key('field_measure_save')));
    await settle(tester);
    await tester.pump(const Duration(seconds: 7)); // 알림이 사라질 때까지

    await open(tester, dataA);
    // 줄자 보기(기본)의 아래 단계 띠에 첫 단계 실측됨.
    expect(find.byKey(const Key('field_measured_0')), findsOneWidget);
  });

  group('10-13 실측 고침', () {
    Future<void> record(WidgetTester tester, String value) async {
      await tester.tap(find.byKey(const Key('field_measure')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('field_measure_input')),
        value,
      );
      await tester.tap(find.byKey(const Key('field_measure_save')));
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> waitSnack(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 7));
      await tester.pumpAndSettle();
    }

    testWidgets('같은 단계를 다시 기록하면 한 건을 바꿔 적고, 되돌리기는 앞 값으로', (tester) async {
      addTearDown(tester.view.reset);
      await open(tester, dataA);
      await tester.tap(find.byKey(const Key('field_mode_toggle')));
      await tester.pumpAndSettle();
      await record(tester, '1031');
      await waitSnack(tester);
      // 되돌리기 알림도 6초 뒤 저절로 사라진다(10-13: 예전엔 계속 떠 단추를 가렸다).
      expect(find.byType(SnackBar), findsNothing);
      await record(tester, '1034');
      expect(find.textContaining('다시 기록했습니다'), findsOneWidget);
      var all = (await tester.runAsync(loadBendChecks))!;
      expect(all, hasLength(1)); // 예전엔 두 건이 쌓였다
      expect(all.single.actual, 1034);

      await tester.tap(find.text('되돌리기'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
      }
      all = (await tester.runAsync(loadBendChecks))!;
      expect(all, hasLength(1));
      expect(all.single.actual, 1031);
      expect(find.textContaining('실측 +1 mm · 다시 기록'), findsOneWidget);
    });

    testWidgets('자르기 단계는 절단 길이와 견준다', (tester) async {
      addTearDown(tester.view.reset);
      await open(tester, dataA);
      await tester.tap(find.byKey(const Key('field_mode_toggle')));
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('다음'));
        await tester.pumpAndSettle();
      }
      await record(tester, '1760');
      final c = (await tester.runAsync(loadBendChecks))!.single;
      expect(c.kind, kBendKindCut);
      expect(c.what, '절단 길이');
      expect(c.calc, 1762);
      expect(c.diff, -2);
    });

    testWidgets('보이는 대로 반올림한 값과 견준다(1030.4 → 1030)', (tester) async {
      addTearDown(tester.view.reset);
      await open(
        tester,
        () => const FieldMarkingData(
          totalCut: 1500,
          marks: [
            FieldMark(
              number: 1,
              position: 1007,
              angle: 90,
              rotation: 0,
              gap: 1007,
              leg: 1030.4,
            ),
          ],
        ),
      );
      await tester.tap(find.byKey(const Key('field_mode_toggle')));
      await tester.pumpAndSettle();
      await record(tester, '1030');
      final c = (await tester.runAsync(loadBendChecks))!.single;
      expect(c.calc, 1030);
      expect(c.diff, 0);
    });

    testWidgets('설정이 인치면 인치로도 받는다(분수 눈금과 견줌)', (tester) async {
      addTearDown(tester.view.reset);
      await open(
        tester,
        () => const FieldMarkingData(
          totalCut: 1500,
          inchMode: FieldInchMode.fraction,
          inchDenominator: 16,
          marks: [
            FieldMark(
              number: 1,
              position: 1007,
              angle: 90,
              rotation: 0,
              gap: 1007,
              leg: 1030, // 40.55" → 40 9/16"
            ),
          ],
        ),
      );
      await tester.tap(find.byKey(const Key('field_mode_toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('field_measure')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('field_measure_unit_inch')), findsOneWidget);
      expect(find.textContaining('40 9/16"'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('field_measure_input')),
        '40 5/8',
      );
      await tester.tap(find.byKey(const Key('field_measure_save')));
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      final c = (await tester.runAsync(loadBendChecks))!.single;
      expect(c.calc, closeTo(40.5625 * 25.4, 1e-9));
      expect(c.actual, closeTo(40.625 * 25.4, 1e-9));
      expect(c.diff, closeTo(25.4 / 16, 1e-9)); // 1/16"
    });
  });
}
