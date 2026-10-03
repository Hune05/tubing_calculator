// 전선 굵기·전압강하 탭: 도체 재질(구리/알루미늄)과 3고조파 칸.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/electrical/electric_calculator_page.dart';

Future<void> _open(WidgetTester tester, String tab) async {
  tester.view.physicalSize = const Size(800, 6000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: ElectricCalculatorPage()));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(Key(tab)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(tab)));
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

String _all(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text, skipOffstage: false))
    .map((t) => t.data ?? '')
    .join('\n');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('전선 굵기: 100 A 삼상 F-CV 트레이 → 구리 16sq, 알루미늄 35sq', (tester) async {
    await _open(tester, 'ec_tab_cable');
    await _type(tester, 'ec_ib', '100');
    expect(_all(tester), contains('16sq'));
    await _tap(tester, 'ec_cable_al');
    final t = _all(tester);
    expect(t, contains('35sq'));
    expect(t, contains('알루미늄 도체'));
    // 구리로 되돌리면 16sq
    await _tap(tester, 'ec_cable_cu');
    expect(find.byKey(const Key('ec_cable_result')), findsOneWidget);
    expect(_all(tester), contains('16sq'));
  });

  testWidgets('3고조파 칸은 삼상에서만 보이고, 40 %를 넣으면 중성선 전류 안내가 나온다', (tester) async {
    await _open(tester, 'ec_tab_cable');
    expect(find.byKey(const Key('ec_h3')), findsOneWidget);
    await _type(tester, 'ec_ib', '39');
    await _type(tester, 'ec_h3', '40');
    final t = _all(tester);
    expect(t, contains('중성선 전류 46.8 A'));
    expect(t, contains('저감계수 0.86'));
    // 단상으로 바꾸면 칸이 사라진다.
    await tester.tap(find.byKey(const Key('ec_v_220')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ec_h3')), findsNothing);
  });

  testWidgets('전압강하: 알루미늄을 고르면 굵기 목록이 10 mm²부터로 바뀐다', (tester) async {
    await _open(tester, 'ec_tab_vd');
    await _type(tester, 'ec_vd_i', '50');
    await _type(tester, 'ec_vd_len', '100');
    DropdownButton<double> dd() =>
        tester.widget<DropdownButton<double>>(find.byKey(const Key('ec_vd_size')));
    expect(dd().value, 4);
    expect(dd().items!.first.value, 0.75);
    await _tap(tester, 'ec_vd_al');
    expect(dd().value, 10, reason: '4 mm²는 알루미늄 목록에 없어 가까운 큰 굵기로 맞춘다');
    expect(dd().items!.first.value, 10);
    expect(dd().items!.last.value, 300);
    expect(_all(tester), contains('R20 × (1 + 0.00403'));
    await _tap(tester, 'ec_vd_cu');
    expect(dd().items!.first.value, 0.75);
  });

  testWidgets('도체 재질은 저장했다 다시 열면 남는다', (tester) async {
    await _open(tester, 'ec_tab_cable');
    await _tap(tester, 'ec_cable_al');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(const MaterialApp(home: ElectricCalculatorPage()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('ec_tab_cable')));
    await tester.tap(find.byKey(const Key('ec_tab_cable')));
    await tester.pumpAndSettle();
    final chip = tester.widget<ChoiceChip>(find.byKey(const Key('ec_cable_al')));
    expect(chip.selected, isTrue);
  });
}
