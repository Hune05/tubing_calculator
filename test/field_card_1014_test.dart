// 10-14 현장 탭 보강: 위 막대 규격·장비 줄, 줄자 위 "지금 할 단계" 카드(관 모양 그림·벤더 값),
// 한 단계씩 화면의 그림·벤더 값. 폰 가로(높이 344)에서는 전처럼 줄자만.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/field/field_marking.dart';
import 'package:tubing_calculator/src/presentation/field/field_marking_screen.dart';

const String kSpec = 'Rigid 22mm · 유압 · 관 중심 · 게인 40';

FieldMarkingData data() => const FieldMarkingData(
  totalCut: 1762,
  specLine: kSpec,
  startDir: 'RIGHT',
  radius: 114.3,
  segments: [
    FieldSegment(length: 1030, angle: 90, rotation: 0),
    FieldSegment(length: 320, angle: 45, rotation: 450),
    FieldSegment(length: 160, angle: 45, rotation: 360),
    FieldSegment(length: 300, angle: 0, rotation: 0),
  ],
  marks: [
    FieldMark(
      number: 1,
      position: 1007,
      angle: 90,
      targetAngle: 93,
      rotation: 0,
      gap: 1007,
      leg: 1030,
      bender: '슈 가운데 -20 · 램 약 120 mm',
    ),
    FieldMark(
      number: 2,
      position: 1301,
      angle: 45,
      rotation: 450,
      gap: 294,
      leg: 320,
      bender: '슈 가운데 -5.6 · 램 약 65 mm',
    ),
    FieldMark(
      number: 3,
      position: 1439,
      angle: 45,
      rotation: 360,
      gap: 138,
      leg: 160,
      bender: '슈 가운데 -5.6 · 램 약 65 mm',
    ),
  ],
);

Future<void> open(WidgetTester tester, Size size) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: FieldMarkingScreen(
        listenable: ValueNotifier(0),
        compute: data,
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

Finder key(String k) => find.byKey(Key(k));

void main() {
  testWidgets('태블릿: 위 막대에 규격 줄, 줄자 위에 카드(그림·벤더 값)', (tester) async {
    await open(tester, const Size(1200, 1600));
    expect(key('field_spec_line'), findsOneWidget);
    expect(key('field_step_card'), findsOneWidget);
    expect(key('field_path_thumb'), findsOneWidget);
    expect(find.text('1번 마킹'), findsWidgets);
    expect(find.text('1007 mm'), findsWidgets);
    expect(find.text('90° (실제 93°) · UP (위)'), findsOneWidget);
    expect(find.text('벤더: 슈 가운데 -20 · 램 약 120 mm'), findsOneWidget);
    // 카드는 넓은 화면에서는 규격 줄을 되풀이하지 않는다(위 막대에 있다).
    expect(find.text(kSpec), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('폰 가로(높이 344): 카드 없이 줄자만, 규격 줄은 위 막대에', (tester) async {
    await open(tester, const Size(800, 344));
    expect(key('field_spec_line'), findsOneWidget);
    expect(key('field_step_card'), findsNothing);
    expect(key('field_path_thumb'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('폰 세로(390×844): 카드는 보이고 규격 줄은 카드 안에', (tester) async {
    await open(tester, const Size(390, 844));
    expect(key('field_spec_line'), findsNothing);
    expect(key('field_step_card'), findsOneWidget);
    expect(find.text(kSpec), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('한 단계씩: 그림과 벤더 값이 붙고, 자르기 단계는 그림만', (tester) async {
    await open(tester, const Size(1200, 1600));
    await tester.tap(find.text('한 단계씩'));
    await tester.pumpAndSettle();
    expect(key('field_path_thumb'), findsOneWidget);
    expect(key('field_step_bender'), findsOneWidget);
    expect(find.text('벤더: 슈 가운데 -20 · 램 약 120 mm'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
    }
    expect(find.text('여기서 자릅니다'), findsOneWidget);
    expect(key('field_path_thumb'), findsOneWidget);
    expect(key('field_step_bender'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('그림 재료가 없으면(옛 자료) 카드·그림 없이 전처럼', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 1600);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: FieldMarkingScreen(
          listenable: ValueNotifier(0),
          compute: () => const FieldMarkingData(
            totalCut: 900,
            marks: [
              FieldMark(
                number: 1,
                position: 500,
                angle: 90,
                rotation: 0,
                gap: 500,
              ),
            ],
          ),
          isActive: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(key('field_step_card'), findsNothing);
    expect(key('field_path_thumb'), findsNothing);
    expect(key('field_spec_line'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
