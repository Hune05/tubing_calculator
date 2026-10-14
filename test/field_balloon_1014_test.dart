// 10-14 현장 탭 말풍선: 넉넉한 화면은 크게(세 줄·방향 풀어서), 폰 가로는 전처럼 두 줄. 글은 안 잘린다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/field/field_marking.dart';
import 'package:tubing_calculator/src/presentation/field/field_marking_screen.dart';

FieldMarkingData data() => const FieldMarkingData(
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
      rotation: 360,
      gap: 294,
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
      ),
    ),
  );
  await tester.pumpAndSettle();
  // 폰에 적힌 보기 설정이 늦게 읽히면 누른 뒤 덮어쓰므로, 먼저 읽히게 잠깐 기다린다.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 60)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('태블릿: 세 줄 풍선, 방향은 "FRONT (앞)"까지, 잘림 없음', (tester) async {
    await open(tester, const Size(1200, 1600));
    expect(find.text('90°→93° · UP (위)'), findsOneWidget);
    expect(find.text('45°→48° · FRONT (앞)'), findsOneWidget);
    expect(find.text('앞에서 +294'), findsOneWidget);
    expect(find.text('마지막 마킹에서 +461'), findsOneWidget);
    // 풍선 둘째·셋째 줄은 한 줄로 다 들어간다(폭을 글에 맞춘다).
    for (final t in ['45°→48° · FRONT (앞)', '마지막 마킹에서 +461']) {
      final box = tester.renderObject<RenderBox>(find.text(t));
      expect(box.size.width, greaterThan(0));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('간격 보기면 셋째 줄이 눈금', (tester) async {
    await open(tester, const Size(1200, 1600));
    await tester.tap(find.byKey(const Key('field_gap')));
    await tester.pumpAndSettle();
    expect(find.text('눈금 1301'), findsOneWidget);
    expect(find.text('눈금 1762'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('폰 가로(800×344): 두 줄 풍선, 방향은 짧게', (tester) async {
    await open(tester, const Size(800, 344));
    expect(find.text('90°→93° · UP'), findsOneWidget);
    expect(find.text('45°→48° · FRONT'), findsOneWidget);
    expect(find.text('앞에서 +294'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
