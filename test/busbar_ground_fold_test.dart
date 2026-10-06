// 접지바 화면의 접기·펴기: 위치 표는 펼쳐 두고, 러그·취부·구멍 크기·작업 순서는 접어 둔다.
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

  testWidgets('접지 구멍·꺾기 위치는 펼쳐 있고, 러그·취부·구멍 크기·작업 순서는 접혀 있다', (tester) async {
    await _open(tester);
    await tester.tap(find.byKey(const Key('gb_tab_1')));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1500));
    await tester.pumpAndSettle();
    ExpansionTile tile(String k) =>
        tester.widget<ExpansionTile>(find.byKey(Key(k)));
    expect(tile('gb_fold_holes').initiallyExpanded, isTrue);
    expect(tile('gb_fold_bends').initiallyExpanded, isTrue);
    for (final k in const ['gb_fold_size', 'gb_fold_notes']) {
      expect(tile(k).initiallyExpanded, isFalse, reason: k);
    }
    // 접힌 작업 순서는 화면에 안 그려지고, 누르면 나온다.
    expect(find.byKey(const Key('gb_notes')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('gb_fold_notes')));
    await tester.tap(find.byKey(const Key('gb_fold_notes')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('gb_notes')), findsOneWidget);
  });
}
