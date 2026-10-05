// 현장 탭: 줄자가 지금 할 마킹으로 저절로 가고, 두 손가락·단추로 늘리고 줄이고, 한 단계씩에서 실측을 남긴다.
// 배경: A11(가로 1340×800)에서 1762mm 도면의 첫 마킹(1007mm)과 말풍선이 화면 밖에 있어 안 보였다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/bend_check/bend_check_model.dart';
import 'package:tubing_calculator/src/presentation/field/field_marking.dart';
import 'package:tubing_calculator/src/presentation/field/field_marking_screen.dart';

FieldMarkingData longData() => const FieldMarkingData(
  totalCut: 1762,
  marks: [
    FieldMark(
      number: 1,
      position: 1007,
      angle: 90,
      targetAngle: 93,
      rotation: 0,
      gap: 1007,
    ),
    FieldMark(
      number: 2,
      position: 1301,
      angle: 45,
      targetAngle: 48,
      rotation: 450,
      gap: 294,
    ),
    FieldMark(
      number: 3,
      position: 1439,
      angle: 45,
      targetAngle: 48,
      rotation: 360,
      gap: 138,
    ),
  ],
);

Future<void> pumpField(
  WidgetTester tester, {
  String Function()? measureGroup,
  Size size = const Size(1006, 600), // A11 가로(dp)
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: FieldMarkingScreen(
        listenable: ValueNotifier(0),
        compute: longData,
        isActive: false,
        measureGroup: measureGroup,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ScrollPosition tapePosition(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(
        of: find.byKey(const Key('field_tape_pinch')),
        matching: find.byType(Scrollable),
      ),
    )
    .position;

void main() {
  rotateTests();
  testWidgets('처음 열면 줄자가 첫 마킹(1007mm) 쪽으로 가 있다(0에 머물지 않는다)', (tester) async {
    await pumpField(tester);
    final p = tapePosition(tester);
    // 2px/mm: 첫 마킹은 48+1007×2 = 2062px. 화면 가운데(약 503)에 오게 → 오프셋 ≈ 1559.
    expect(p.pixels, greaterThan(1000));
    expect(p.pixels, closeTo(2062 - 1006 / 2, 3));
  });

  testWidgets('키우기·줄이기 단추가 줄자 길이를 바꾼다', (tester) async {
    await pumpField(tester);
    final before = tapePosition(tester).maxScrollExtent;
    await tester.tap(find.byKey(const Key('field_zoom_in')));
    await tester.pumpAndSettle();
    final bigger = tapePosition(tester).maxScrollExtent;
    expect(bigger, greaterThan(before));
    await tester.tap(find.byKey(const Key('field_zoom_out')));
    await tester.tap(find.byKey(const Key('field_zoom_out')));
    await tester.pumpAndSettle();
    expect(tapePosition(tester).maxScrollExtent, lessThan(before));
  });

  testWidgets('전체 보기 단추를 누르면 관 전체가 한 화면에 들어온다', (tester) async {
    await pumpField(tester);
    expect(tapePosition(tester).maxScrollExtent, greaterThan(1000));
    await tester.tap(find.byKey(const Key('field_zoom_fit')));
    await tester.pumpAndSettle();
    final p = tapePosition(tester);
    expect(p.maxScrollExtent, lessThan(2)); // 다 들어와서 밀 데가 없다
    expect(p.pixels, 0);
  });

  testWidgets('두 손가락을 벌리면 줄자가 늘어난다', (tester) async {
    await pumpField(tester);
    final before = tapePosition(tester).maxScrollExtent;
    final a = await tester.startGesture(const Offset(400, 300), pointer: 1);
    final b = await tester.startGesture(const Offset(500, 300), pointer: 2);
    await b.moveTo(const Offset(700, 300));
    await tester.pump();
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    expect(tapePosition(tester).maxScrollExtent, greaterThan(before * 1.3));
  });

  testWidgets('두 손가락을 모으면 줄자가 줄어든다', (tester) async {
    await pumpField(tester);
    final before = tapePosition(tester).maxScrollExtent;
    final a = await tester.startGesture(const Offset(300, 300), pointer: 1);
    final b = await tester.startGesture(const Offset(700, 300), pointer: 2);
    await b.moveTo(const Offset(450, 300));
    await tester.pump();
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    expect(tapePosition(tester).maxScrollExtent, lessThan(before * 0.8));
  });

  testWidgets('확대 비율은 폰에 기억된다', (tester) async {
    await pumpField(tester);
    await tester.tap(find.byKey(const Key('field_zoom_in')));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('field_tape_scale'), closeTo(2.8, 0.01));
  });

  testWidgets('실측 묶음 이름을 안 주면 한 단계씩에 실측 단추가 없다', (tester) async {
    await pumpField(tester);
    await tester.tap(find.byKey(const Key('field_mode_toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('field_measure')), findsNothing);
  });

  testWidgets('한 단계씩에서 실측을 적으면 벤딩 실측 기록에 남는다', (tester) async {
    await pumpField(tester, measureGroup: () => '시험 묶음');
    await tester.tap(find.byKey(const Key('field_mode_toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('field_measure')));
    await tester.pumpAndSettle();
    expect(find.textContaining('계산 1007 mm'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('field_measure_input')),
      '1010.5',
    );
    await tester.tap(find.byKey(const Key('field_measure_save')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    // 저장 직후 알림이 뜬다(차이 +3.5 mm).
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('+3.5 mm'), findsOneWidget);

    final all = (await tester.runAsync(loadBendChecks))!;
    expect(all, hasLength(1));
    expect(all.single.group, '시험 묶음');
    expect(all.single.what, '90° 1번 마킹');
    expect(all.single.calc, 1007);
    expect(all.single.actual, 1010.5);
  });

  testWidgets('숫자가 아니면 저장 안 된다', (tester) async {
    await pumpField(tester, measureGroup: () => '시험 묶음');
    await tester.tap(find.byKey(const Key('field_mode_toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('field_measure')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('field_measure_input')), 'abc');
    await tester.tap(find.byKey(const Key('field_measure_save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('field_measure_input')), findsOneWidget);
  });
}

// 처음엔 세로 폭으로 셈한 뒤 화면이 가로로 돌아도 첫 마킹이 가운데에 온다(A11에서 왼쪽에 치우쳤던 것).
void rotateTests() {
  testWidgets('세로로 열렸다가 가로로 돌면 다시 가운데로 맞춘다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(600, 1005); // 세로
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: FieldMarkingScreen(
          listenable: ValueNotifier(0),
          compute: longData,
          isActive: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(1006, 600); // 가로로 돎
    await tester.pumpAndSettle();
    final p = tapePosition(tester);
    expect(p.pixels, closeTo(2062 - 1006 / 2, 3));
  });
}
