// 전기 계산기를 설비 종류와 상관없이 쓰기: 기본값은 일반 부하, 전동기 여유는 꺼짐, 전압은 직접 입력, 고압은 경고.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/electrical/elec_load_sum.dart';
import 'package:tubing_calculator/src/presentation/electrical/electric_calculator_page.dart';

Future<void> _open(WidgetTester tester, String tab) async {
  tester.view.physicalSize = const Size(800, 6000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: ElectricCalculatorPage()));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(tab)));
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pumpAndSettle();
}

String _all(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text, skipOffstage: false))
    .map((t) => t.data ?? '')
    .join('\n');

void main() {
  loadSumGroup();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('처음 열면 일반 부하: 효율 100, 전동기 여유 없음', (tester) async {
    await _open(tester, 'ec_tab_load');
    await _type(tester, 'ec_kw', '11');
    final t = _all(tester);
    // I = 11 × 1000 ÷ (√3 × 380 × 0.85) = 19.7 A, 전동기 ×1.25 문구 없음
    expect(t, contains('19.7 A'));
    expect(t, isNot(contains('(×1.25) 기준')));
  });

  testWidgets('전선 굵기 탭의 전동기 부하 스위치는 꺼진 채로 시작한다', (tester) async {
    await _open(tester, 'ec_tab_cable');
    final sw = tester.widget<Switch>(find.byKey(const Key('ec_cable_motor')));
    expect(sw.value, isFalse);
  });

  testWidgets('칩에 없는 전압을 직접 넣으면 그 전압으로 계산하고, 고압이면 경고한다', (tester) async {
    await _open(tester, 'ec_tab_load');
    await _type(tester, 'ec_kw', '1000');
    expect(find.byKey(const Key('ec_hv_note')), findsNothing);
    await _type(tester, 'ec_v_custom', '6600');
    // 삼상 6600 V 역률 0.85: 1000000 ÷ (√3 × 6600 × 0.85) = 102.9 A
    expect(_all(tester), contains('102.9 A'));
    expect(find.byKey(const Key('ec_hv_note')), findsOneWidget);
    // 칩을 누르면 직접 입력 값은 지워지고 경고도 사라진다.
    await tester.tap(find.byKey(const Key('ec_v_380')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ec_hv_note')), findsNothing);
    expect(tester.widget<TextField>(find.byKey(const Key('ec_v_custom'))).controller!.text, '');
  });

  testWidgets('200 V 직접 입력: 단상·삼상은 사용자가 고른 대로 둔다', (tester) async {
    await _open(tester, 'ec_tab_load');
    await tester.tap(find.byKey(const Key('ec_v_220')));
    await tester.pumpAndSettle();
    await _type(tester, 'ec_v_custom', '200');
    await _type(tester, 'ec_kw', '2');
    // 단상 200 V, 역률 0.85: 2000 ÷ (200 × 0.85) = 11.8 A
    expect(_all(tester), contains('11.8 A'));
  });

  testWidgets('직류도 직접 입력, 1.5 kV 초과면 경고', (tester) async {
    await _open(tester, 'ec_tab_load');
    await tester.tap(find.byKey(const Key('ec_load_dc')));
    await tester.pumpAndSettle();
    await _type(tester, 'ec_dcv_custom', '600');
    expect(find.byKey(const Key('ec_hv_note_dc')), findsNothing);
    await _type(tester, 'ec_kw', '6');
    // 6000 W ÷ 600 V = 10 A
    expect(_all(tester), contains('10 A'));
    await _type(tester, 'ec_dcv_custom', '2000');
    expect(find.byKey(const Key('ec_hv_note_dc')), findsOneWidget);
  });

  testWidgets('저장했다 다시 열면 직접 입력한 전압이 남는다', (tester) async {
    await _open(tester, 'ec_tab_load');
    await _type(tester, 'ec_v_custom', '208');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(const MaterialApp(home: ElectricCalculatorPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ec_tab_load')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const Key('ec_v_custom'))).controller!.text, '208');
  });
}

// 부하 합산: 2차 전압 직접 입력과 단상 변압기
void loadSumGroup() {
  group('부하 합산 2차 전압·상', () {
    const row = LoadRowInput(name: 'A', kw: '10', pf: '100', df: '100');
    test('3상 380 V: 10 kVA → 15.2 A', () {
      final r = computeLoadSum(const LoadSumInput(rows: [row]));
      expect(r.ratedAmps, closeTo(10000 / (1.7320508 * 380), 1e-3));
      expect(r.three, isTrue);
    });
    test('단상 220 V: 10 kVA → 45.5 A (√3 없음)', () {
      final r = computeLoadSum(
        const LoadSumInput(rows: [row], volts: 220, three: false),
      );
      expect(r.ratedAmps, closeTo(10000 / 220, 1e-6));
    });
    test('직접 입력한 6600 V도 저장·복원된다', () {
      const i = LoadSumInput(rows: [row], volts: 6600);
      final back = LoadSumInput.fromJson(i.toJson());
      expect(back.volts, 6600);
      expect(back.three, isTrue);
    });
    test('옛 저장 값(상 정보 없음)은 3상으로 읽는다', () {
      final back = LoadSumInput.fromJson({'v': 440.0, 'rows': []});
      expect(back.three, isTrue);
      expect(back.volts, 440);
    });
  });
}
