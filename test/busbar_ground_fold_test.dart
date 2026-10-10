// 접지바 화면의 접기·펴기: 위치 표는 펼쳐 두고, "자세히"(두 줄·L자·러그·구멍 크기·꺾기 보정)와
// 판넬 취부·작업 순서는 접어 둔다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/electrical/busbar_ground_page.dart';

Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 6000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: GroundBarPage()));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('접지 구멍·꺾기·발 구멍 위치는 펼쳐 있고, 자세히·취부·작업 순서는 접혀 있다', (tester) async {
    await _open(tester);
    // 자세히는 처음에 접혀 있어 안의 칸(두 줄·L자)이 안 보인다
    ExpansionTile tile(String k) =>
        tester.widget<ExpansionTile>(find.byKey(Key(k)));
    expect(tile('gb_fold_more').initiallyExpanded, isFalse);
    expect(find.byKey(const Key('gb_rm_1')), findsNothing);
    expect(find.byKey(const Key('gb_tab_1')), findsNothing);
    // 러그 종류와 일자 취부 구멍 칸은 겉에 있다(10-10)
    expect(find.byKey(const Key('gb_lug_1')), findsOneWidget);
    expect(find.byKey(const Key('gb_mend')), findsOneWidget);
    expect(find.byKey(const Key('gb_mgap')), findsOneWidget);
    await tester.tap(find.byKey(const Key('gb_lug_2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('gb_lugdia')), findsOneWidget);
    expect(find.byKey(const Key('gb_lugsp')), findsNothing); // 간격은 자세히 안
    await tester.tap(find.byKey(const Key('gb_lug_0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('gb_tab_4')));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1500));
    await tester.pumpAndSettle();
    expect(tile('gb_fold_holes').initiallyExpanded, isTrue);
    expect(tile('gb_fold_bends').initiallyExpanded, isTrue);
    expect(tile('gb_fold_tabholes').initiallyExpanded, isTrue);
    for (final k in const ['gb_fold_mount', 'gb_fold_notes']) {
      expect(tile(k).initiallyExpanded, isFalse, reason: k);
    }
    // 접힌 작업 순서는 화면에 안 그려지고, 누르면 나온다.
    expect(find.byKey(const Key('gb_notes')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('gb_fold_notes')));
    await tester.tap(find.byKey(const Key('gb_fold_notes')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('gb_notes')), findsOneWidget);
  });

  testWidgets('펴고 접은 상태를 폰에 적어 다시 열어도 그대로 둔다', (tester) async {
    await _open(tester);
    await tester.tap(find.byKey(const Key('gb_tab_4')));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1500));
    await tester.pumpAndSettle();
    // 접힌 "작업 순서"를 펴면 적힌다.
    await tester.ensureVisible(find.byKey(const Key('gb_fold_notes')));
    await tester.tap(find.byKey(const Key('gb_fold_notes')));
    await tester.pumpAndSettle();
    var prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('fold_v1_gb_fold_notes'), isTrue);
    // 펼쳐 둔 "접지 구멍 위치"를 접으면 그것도 적힌다.
    await tester.ensureVisible(find.byKey(const Key('gb_fold_holes')));
    await tester.tap(find.text('접지 구멍 위치 (왼쪽 끝에서 중심까지)'));
    await tester.pumpAndSettle();
    prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('fold_v1_gb_fold_holes'), isFalse);

    // 화면을 닫았다 다시 열면 적힌 대로(작업 순서 펼침, 접지 구멍 위치 접힘).
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await _open(tester);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1500));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('gb_fold_notes')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('gb_notes')), findsOneWidget);
    expect(find.textContaining('첫 구멍'), findsNothing);
  });
}
