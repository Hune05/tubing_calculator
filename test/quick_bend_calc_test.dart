// 벤딩 간단 계산(예전 "벤딩 리모컨" 자리, 10-07): 오프셋·롤링 오프셋·킥.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/quick_bend_calc_page.dart';

String _texts(WidgetTester t, String key) => t
    .widgetList<Text>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)))
    .map((w) => w.data ?? '')
    .join(' | ');

Future<void> _type(WidgetTester t, String key, String text) async {
  await t.ensureVisible(find.byKey(Key(key)));
  await t.enterText(find.byKey(Key(key)), text);
  await t.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('식: 오프셋 100mm 45° → 빗변 141.4, 진행 100, 수축 41.4 / 롤링 300·400 → 실제 단차 500', () {
    final o = quickOffset(100, 45)!;
    expect(o.travel, closeTo(141.42, 0.01));
    expect(o.run, closeTo(100, 1e-9));
    expect(o.shrink, closeTo(41.42, 0.01));
    expect(o.shrink, closeTo(o.travel - o.run, 1e-9)); // 수축 = 빗변 − 진행
    expect(quickOffset(100, 90), isNull);
    expect(quickOffset(0, 45), isNull);
    final r = quickRolling(300, 400)!;
    expect(r.trueOffset, closeTo(500, 1e-9));
    expect(r.rollAngle, closeTo(53.13, 0.01));
    expect(quickRolling(0, 0), isNull);
  });

  Future<void> open(WidgetTester t) async {
    t.view.physicalSize = const Size(390, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: QuickBendCalcPage()));
    await t.pumpAndSettle();
  }

  testWidgets('오프셋 탭: 높이를 넣으면 빗변·진행·수축, 각도 칩으로 바꾼다', (t) async {
    await open(t);
    expect(find.text('벤딩 간단 계산'), findsOneWidget);
    await _type(t, 'qb_off_h', '100');
    expect(_texts(t, 'qb_offset_result'), contains('141.4 mm'));
    expect(_texts(t, 'qb_offset_result'), contains('41.4 mm'));
    await t.tap(find.byKey(const Key('qb_off_chip_30')));
    await t.pump();
    expect(_texts(t, 'qb_offset_result'), contains('200 mm'));
  });

  testWidgets('롤링 오프셋 탭과 킥 탭', (t) async {
    await open(t);
    await t.tap(find.byKey(const Key('qb_tab_rolling')));
    await t.pumpAndSettle();
    await _type(t, 'qb_roll_rise', '300');
    await _type(t, 'qb_roll_roll', '400');
    final roll = _texts(t, 'qb_rolling_result');
    expect(roll, contains('707.1 mm')); // 500 ÷ sin45°
    expect(roll, contains('53.1°'));
    await t.tap(find.byKey(const Key('qb_tab_kick')));
    await t.pumpAndSettle();
    await _type(t, 'qb_kick_h', '100');
    final kick = _texts(t, 'qb_kick_result');
    expect(kick, contains('200 mm')); // 100 ÷ sin30°
    expect(kick, contains('173.2 mm'));
    expect(kick, contains('26.8 mm'));
  });

  testWidgets('각도가 90° 이상이면 입력 확인', (t) async {
    await open(t);
    await _type(t, 'qb_off_h', '100');
    await _type(t, 'qb_off_angle', '90');
    expect(find.text('입력 확인'), findsOneWidget);
  });
}
