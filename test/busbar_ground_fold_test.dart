// 접지바 화면의 접기·펴기(10-12 위 그림 + 아래 탭): "자세히"는 모양 탭(끝 L자·오른쪽 발·꺾기 보정)과
// 구멍 탭(두 줄·러그·구멍 크기·내 금형)에 나눠 접어 두고, 결과 탭의 꺾기·구멍 위치는 펼쳐 둔다.
// 판넬 취부·러그·작업 순서는 접어 둔다.
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

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('자세히는 모양·구멍 탭에 접혀 있고, 결과 탭 위치는 펼쳐 있고 취부·작업 순서는 접혀 있다', (
    tester,
  ) async {
    await _open(tester);
    ExpansionTile tile(String k) =>
        tester.widget<ExpansionTile>(find.byKey(Key(k)));
    // 모양 탭: 끝 L자는 자세히 안
    expect(tile('gb_fold_shape').initiallyExpanded, isFalse);
    expect(find.byKey(const Key('gb_tab_1')), findsNothing);
    // 구멍 탭: 두 줄은 자세히 안, 러그 종류와 일자 취부 구멍 칸은 겉에(10-10)
    await _tap(tester, 'gb_nav_holes');
    expect(tile('gb_fold_more').initiallyExpanded, isFalse);
    expect(find.byKey(const Key('gb_rm_1')), findsNothing);
    expect(find.byKey(const Key('gb_lug_1')), findsOneWidget);
    expect(find.byKey(const Key('gb_mend')), findsOneWidget);
    expect(find.byKey(const Key('gb_mgap')), findsOneWidget);
    await _tap(tester, 'gb_lug_2');
    expect(find.byKey(const Key('gb_lugdia')), findsOneWidget);
    expect(find.byKey(const Key('gb_lugsp')), findsNothing); // 간격은 자세히 안
    await _tap(tester, 'gb_lug_0');
    // 모자로 바꾸고 결과 탭: 꺾기·구멍 위치는 펼쳐 보이고, 판넬 취부·작업 순서는 접혀 있다
    await _tap(tester, 'gb_nav_shape');
    await _tap(tester, 'gb_tab_4');
    await _tap(tester, 'gb_nav_result');
    expect(find.byKey(const Key('gb_rule')), findsOneWidget);
    expect(find.byKey(const Key('gb_bends')), findsOneWidget);
    expect(find.byKey(const Key('gb_tab_holes')), findsOneWidget);
    for (final k in const ['gb_fold_mount', 'gb_fold_notes']) {
      expect(tile(k).initiallyExpanded, isFalse, reason: k);
    }
    // 접힌 작업 순서는 화면에 안 그려지고, 누르면 나온다.
    expect(find.byKey(const Key('gb_notes')), findsNothing);
    await _tap(tester, 'gb_fold_notes');
    expect(find.byKey(const Key('gb_notes')), findsOneWidget);
  });

  testWidgets('펴고 접은 상태를 폰에 적어 다시 열어도 그대로 둔다', (tester) async {
    await _open(tester);
    await _tap(tester, 'gb_tab_4');
    await _tap(tester, 'gb_nav_result');
    // 접힌 "작업 순서"를 펴면 적힌다.
    await _tap(tester, 'gb_fold_notes');
    var prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('fold_v1_gb_fold_notes'), isTrue);
    // 접힌 "판넬 취부"를 펴면 그것도 적힌다.
    await _tap(tester, 'gb_fold_mount');
    prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('fold_v1_gb_fold_mount'), isTrue);

    // 화면을 닫았다 다시 열면 적힌 대로(작업 순서·판넬 취부 펼침).
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await _open(tester);
    await _tap(tester, 'gb_nav_result');
    expect(find.byKey(const Key('gb_notes')), findsOneWidget);
    expect(find.byKey(const Key('gb_mount_result')), findsOneWidget);
  });
}
