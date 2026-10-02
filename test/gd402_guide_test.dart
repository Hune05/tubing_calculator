// GD402 수소 순도계 가이드(10-01): 탭 10장이 다 열리고 끝까지 넘겨도 예외가 없고,
// 교정 화면 따라하기가 처음부터 끝까지 넘어가며 표시창·밸브 그림이 단계대로 바뀐다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/instrument/gd402_guide_page.dart';
import 'package:tubing_calculator/src/presentation/instrument/gd402_panel.dart';

void main() {
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  testWidgets('탭 16장을 하나씩 열고 끝까지 넘겨도 예외가 없다', (tester) async {
    phone(tester);
    await tester.pumpWidget(const MaterialApp(home: Gd402GuidePage()));
    await tester.pumpAndSettle();
    const ids = ['overview', 'principle', 'keys', 'install', 'setup', 'output', 'alarm', 'display', 'cal', 'op', 'codes', 'maint', 'dens_setup', 'dens_cal', 'calo_setup', 'calo_cal'];
    for (var i = 0; i < ids.length; i++) {
      final tab = find.byKey(Key('gdg_tab_$i'));
      await tester.ensureVisible(tab);
      await tester.pumpAndSettle();
      await tester.tap(tab);
      await tester.pumpAndSettle();
      final list = find.byKey(Key('gdg_list_${ids[i]}'));
      expect(list, findsOneWidget, reason: ids[i]);
      for (var k = 0; k < 15; k++) {
        await tester.drag(list, const Offset(0, -900));
        await tester.pump();
      }
      expect(tester.takeException(), isNull, reason: ids[i]);
    }
  });

  testWidgets('교정 따라하기: 11단계를 넘기며 ZERO → 0.0899 H2 → CAL.SET → SPAN → 1.9771 CO2 순서', (tester) async {
    phone(tester);
    await tester.pumpWidget(const MaterialApp(home: Gd402GuidePage(initialTab: 8)));
    await tester.pumpAndSettle();
    final list = find.byKey(const Key('gdg_list_cal'));
    final next = find.byKey(const Key('gdw_next_mancal'));
    final nextAll = find.byKey(const Key('gdw_next_mancal'), skipOffstage: false);
    await tester.dragUntilVisible(next, list, const Offset(0, -300));
    await tester.pumpAndSettle();
    final msgs = <String>[];
    for (var i = 0; i < 11; i++) {
      final panel = tester.widget<CustomPaint>(find.byKey(const Key('gdw_panel_mancal'), skipOffstage: false));
      msgs.add((panel.painter! as Gd402PanelPainter).step.msg);
      await tester.ensureVisible(nextAll);
      await tester.pumpAndSettle();
      await tester.tap(nextAll);
      await tester.pumpAndSettle();
    }
    expect(msgs, ['H2_AIR', 'S_GAS', 'DISP', 'MAN.CAL', 'ZERO', 'H2', 'CAL.SET', 'SPAN', 'CO2', 'CAL.SET', 'H2_AIR']);
    // 마지막 다음 = 처음부터
    expect(find.text('1 / 11'), findsOneWidget);
  });

  testWidgets('서비스 코드 50 따라하기는 * → *RANGE … *SERVC → 50 → *MODEL 2', (tester) async {
    phone(tester);
    await tester.pumpWidget(const MaterialApp(home: Gd402GuidePage(initialTab: 4)));
    await tester.pumpAndSettle();
    final list = find.byKey(const Key('gdg_list_setup'));
    final next = find.byKey(const Key('gdw_next_code50'));
    final nextAll = find.byKey(const Key('gdw_next_code50'), skipOffstage: false);
    await tester.dragUntilVisible(next, list, const Offset(0, -300));
    final seen = <String>[];
    for (var i = 0; i < 10; i++) {
      final p = tester.widget<CustomPaint>(find.byKey(const Key('gdw_panel_code50'), skipOffstage: false)).painter! as Gd402PanelPainter;
      seen.add('${p.step.data}|${p.step.msg}');
      await tester.ensureVisible(nextAll);
      await tester.pumpAndSettle();
      await tester.tap(nextAll);
      await tester.pumpAndSettle();
    }
    expect(seen.contains('2|*MODEL'), isTrue);
    expect(seen.contains('50|*CODE'), isTrue);
    expect(seen.indexOf('|*SERVC') < seen.indexOf('00|*CODE'), isTrue);
  });

  testWidgets('밀도계 수동 교정 따라하기: ZERO → Z_DNS → CAL.SET → SPAN → S_DNS → CAL.SET → WAIT', (tester) async {
    phone(tester);
    await tester.pumpWidget(const MaterialApp(home: Gd402GuidePage(initialTab: 13)));
    await tester.pumpAndSettle();
    final list = find.byKey(const Key('gdg_list_dens_cal'));
    final next = find.byKey(const Key('gdw_next_d_man'));
    final nextAll = find.byKey(const Key('gdw_next_d_man'), skipOffstage: false);
    await tester.dragUntilVisible(next, list, const Offset(0, -300));
    final msgs = <String>[];
    for (var i = 0; i < 13; i++) {
      final p = tester.widget<CustomPaint>(find.byKey(const Key('gdw_panel_d_man'), skipOffstage: false)).painter! as Gd402PanelPainter;
      msgs.add(p.step.msg);
      await tester.ensureVisible(nextAll);
      await tester.pumpAndSettle();
      await tester.tap(nextAll);
      await tester.pumpAndSettle();
    }
    expect(msgs, ['KG/M3', 'DISP', 'SEM.CAL', 'MAN.CAL', 'ZERO', 'Z_DNS', 'CAL.SET', 'SPAN', 'S_DNS', 'CAL.SET', 'WAIT', 'KG/M3', 'KG/M3']);
  });
}
