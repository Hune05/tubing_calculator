// 최근 계산 기록을 폰에 하루 동안 남기고, 앱을 다시 연 뒤에도 눌러 되돌리기(10-07).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/common_widgets/recent_calc_history.dart';
import 'package:tubing_calculator/src/presentation/electrical/electric_calculator_page.dart';

String _text(WidgetTester t, String key) =>
    t.widget<TextField>(find.byKey(Key(key))).controller!.text;

Future<void> _type(WidgetTester t, String key, String text) async {
  await t.ensureVisible(find.byKey(Key(key)));
  await t.enterText(find.byKey(Key(key)), text);
  await t.pump();
  await t.pump(const Duration(milliseconds: 800));
}

Future<void> _open(WidgetTester t, int tab) async {
  t.view.physicalSize = const Size(390, 6000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(home: ElectricCalculatorPage(initialTab: tab)));
  await t.pumpAndSettle();
}

Future<void> _close(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 1));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RecentCalcLog.now = DateTime.now;
  });

  testWidgets('부하 전류 기록이 화면을 닫았다 열어도 남고, 눌러 그때 kW로 되돌린다', (t) async {
    await _open(t, 1);
    await _type(t, 'ec_kw', '11');
    await _close(t);
    await _open(t, 1);
    await _type(t, 'ec_kw', '');
    await t.tap(find.byKey(const Key('calc_history_button')));
    await t.pumpAndSettle();
    expect(find.textContaining('19.7 A'), findsWidgets);
    await t.tap(find.textContaining('19.7 A').last);
    await t.pumpAndSettle();
    expect(_text(t, 'ec_kw'), '11');
  });

  testWidgets('다시 연 뒤 아직 그려지지 않은 탭(발전기 용량)의 기록도 그 탭을 열고 되돌린다', (t) async {
    await _open(t, 9);
    await _type(t, 'eg_row_kw_0', '100');
    await _type(t, 'eg_row_eff_0', '85');
    await _type(t, 'eg_row_pf_0', '80');
    await _type(t, 'eg_g_k', '1');
    await _type(t, 'eg_row_kw_0', '');
    await _type(t, 'eg_g_k', '');
    await _close(t);
    // 전동기 공식 탭으로 연다(발전기 탭은 아직 안 그려짐).
    await _open(t, 14);
    expect(find.byKey(const Key('eg_row_kw_0')), findsNothing);
    await t.tap(find.byKey(const Key('calc_history_button')));
    await t.pumpAndSettle();
    await t.tap(find.textContaining('필요 147 kVA'));
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 60));
    }
    await t.pumpAndSettle();
    expect(_text(t, 'eg_row_kw_0'), '100');
    expect(_text(t, 'eg_g_k'), '1');
  });

  test('하루가 지난 기록은 읽지 않는다', () async {
    final at = DateTime(2026, 10, 7, 9);
    SharedPreferences.setMockInitialValues({
      'k': jsonEncode([
        {'t': '부하 전류', 's': '새 기록', 'at': at.subtract(const Duration(hours: 2)).toIso8601String()},
        {'t': '부하 전류', 's': '옛 기록', 'at': at.subtract(const Duration(hours: 30)).toIso8601String()},
      ]),
    });
    RecentCalcLog.now = () => at;
    final log = RecentCalcLog();
    await log.attachStorage('k');
    expect(log.entries.map((e) => e.subtitle), ['새 기록']);
    // 되돌릴 입력값이 없는 기록은 누를 수 없다.
    expect(log.entries.single.onTap, isNull);
  });
}
