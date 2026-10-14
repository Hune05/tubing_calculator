// 10-14 현장 탭 원자재 길이·잔재: 보기 창에서 원자재 길이를 넣으면 위 막대에 "잔재 N",
// 절단이 더 길면 빨갛게 "원자재보다 N 깁니다". 튜브·전선관 따로 기억한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/field/field_marking.dart';
import 'package:tubing_calculator/src/presentation/field/field_marking_screen.dart';

FieldMarkingData data() => const FieldMarkingData(
  totalCut: 1762,
  marks: [
    FieldMark(number: 1, position: 1007, angle: 90, rotation: 0, gap: 1007),
  ],
);

Future<void> open(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  String progressKey = 'field_progress_conduit_v1',
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1006, 600);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: FieldMarkingScreen(
        listenable: ValueNotifier(0),
        compute: data,
        isActive: false,
        progressKey: progressKey,
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
  testWidgets('보기 창에서 3 m를 고르면 잔재 1238, 닫은 뒤에도 남고 폰에 기억된다', (tester) async {
    await open(tester);
    expect(key('field_remnant'), findsNothing);
    await tester.tap(key('field_view_menu'));
    await tester.pumpAndSettle();
    await tester.tap(key('field_stock_3000'));
    await tester.pumpAndSettle();
    await tester.tap(key('field_view_close'));
    await tester.pumpAndSettle();
    expect(find.text('잔재 1238'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('field_progress_conduit_v1_stock'), 3000);
  });

  testWidgets('다른 길이 1500을 넣으면 절단이 더 길어 빨갛게 알린다', (tester) async {
    await open(tester);
    await tester.tap(key('field_view_menu'));
    await tester.pumpAndSettle();
    await tester.enterText(key('field_stock_input'), '1500');
    await tester.pumpAndSettle();
    await tester.tap(key('field_view_close'));
    await tester.pumpAndSettle();
    final t = tester.widget<Text>(key('field_remnant'));
    expect(t.data, '원자재보다 262 깁니다');
    expect(t.style?.color, isNot(equals(const Color(0xFF5F6B78))));
  });

  testWidgets('기억된 원자재 길이는 바로 보이고, "안 씀"이면 사라진다', (tester) async {
    await open(tester, prefs: {'field_progress_conduit_v1_stock': 6000.0});
    expect(find.text('잔재 4238'), findsOneWidget);
    await tester.tap(key('field_view_menu'));
    await tester.pumpAndSettle();
    await tester.tap(key('field_stock_0'));
    await tester.pumpAndSettle();
    await tester.tap(key('field_view_close'));
    await tester.pumpAndSettle();
    expect(key('field_remnant'), findsNothing);
  });

  testWidgets('튜브 쪽 기억(다른 진행 칸)은 전선관에 안 끼어든다', (tester) async {
    await open(
      tester,
      prefs: {'field_progress_v1_stock': 6000.0},
      progressKey: 'field_progress_conduit_v1',
    );
    expect(key('field_remnant'), findsNothing);
  });
}
