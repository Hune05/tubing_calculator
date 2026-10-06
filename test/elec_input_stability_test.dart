// 값을 넣는 중 칸이 움직이지 않고(요약 줄 높이 고정), 키보드 "다음"은 글자 칸끼리만 옮겨 간다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/electrical/electric_calculator_page.dart';
import 'package:tubing_calculator/src/presentation/electrical/elec_generator_tab.dart';
import 'package:tubing_calculator/src/core/theme/field_view.dart';

Future<void> _open(WidgetTester tester, Widget home, {double h = 900}) async {
  tester.view.physicalSize = Size(390, h);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: home));
  await tester.pumpAndSettle();
}

bool _focused(WidgetTester tester, String key) => tester
    .widget<EditableText>(
      find.descendant(of: find.byKey(Key(key)), matching: find.byType(EditableText)),
    )
    .focusNode
    .hasFocus;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('부하 전류: 결과 요약이 생기고 "입력 확인"으로 바뀌어도 칸 위치가 그대로다', (tester) async {
    await _open(tester, const ElectricCalculatorPage(initialTab: 1));
    final kw = find.byKey(const Key('ec_kw'));
    await tester.ensureVisible(kw);
    await tester.pumpAndSettle();
    final y0 = tester.getTopLeft(kw).dy;
    await tester.enterText(kw, '11');
    await tester.pump();
    expect(find.byKey(const Key('ec_sum_load')), findsOneWidget);
    expect(tester.getTopLeft(kw).dy, y0);
    await tester.enterText(kw, '-5');
    await tester.pump();
    expect(tester.getTopLeft(kw).dy, y0);
    await tester.enterText(kw, '');
    await tester.pump();
    expect(tester.getTopLeft(kw).dy, y0);
  });

  testWidgets('발전기: 값을 넣어 입력 확인이 떠도 아래 칸이 밀리지 않는다', (tester) async {
    await _open(
      tester,
      const FieldViewTheme(child: Scaffold(body: ElecGeneratorTab())),
      h: 2400,
    );
    await tester.tap(find.byKey(const Key('eg_mode_pg')));
    await tester.pumpAndSettle();
    final dv = find.byKey(const Key('eg_dv'));
    await tester.ensureVisible(dv);
    await tester.pumpAndSettle();
    final y0 = tester.getTopLeft(dv).dy;
    await tester.enterText(find.byKey(const Key('eg_load')), '300');
    await tester.pump();
    expect(tester.getTopLeft(dv).dy, y0);
    await tester.enterText(find.byKey(const Key('eg_motor')), '75');
    await tester.pump();
    expect(tester.getTopLeft(dv).dy, y0, reason: '입력 확인이 떠도');
  });

  testWidgets('키보드 "다음"은 "?" 도움말을 건너뛰고 다음 글자 칸으로 간다', (tester) async {
    await _open(tester, const ElectricCalculatorPage(initialTab: 1));
    await tester.tap(find.byKey(const Key('ec_kw')));
    await tester.pump();
    expect(_focused(tester, 'ec_kw'), isTrue);
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    expect(_focused(tester, 'ec_eff'), isTrue);
    expect(find.byType(BottomSheet), findsNothing);
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    expect(_focused(tester, 'ec_pf'), isTrue);
  });

  testWidgets('효율에 0.9를 넣어 "= 90%"가 붙어도 아래 역률 칸이 밀리지 않는다', (tester) async {
    await _open(tester, const ElectricCalculatorPage(initialTab: 1), h: 2400);
    final pf = find.byKey(const Key('ec_pf'));
    await tester.ensureVisible(pf);
    await tester.pumpAndSettle();
    final y0 = tester.getTopLeft(pf).dy;
    await tester.enterText(find.byKey(const Key('ec_eff')), '0.9');
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byKey(const Key('ec_eff'))).decoration!.suffixText,
      '= 90%',
    );
    expect(tester.getTopLeft(pf).dy, y0);
  });

  testWidgets('마지막 칸에서 "다음"을 누르면 맨 위로 돌아가지 않고 키보드를 닫는다', (tester) async {
    await _open(tester, const ElectricCalculatorPage(initialTab: 1), h: 4000);
    final last = find.byKey(const Key('ec_conv_val'));
    await tester.ensureVisible(last);
    await tester.tap(last);
    await tester.pump();
    expect(_focused(tester, 'ec_conv_val'), isTrue);
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    expect(_focused(tester, 'ec_conv_val'), isFalse);
    expect(_focused(tester, 'ec_kw'), isFalse, reason: '맨 위 칸으로 돌아가지 않는다');
  });

  testWidgets('접힌 구역 안 칸(전동기 기여)으로는 "다음"이 들어가지 않는다', (tester) async {
    await _open(tester, const ElectricCalculatorPage(initialTab: 5), h: 4000);
    final f = find.byKey(const Key('ec_sc_up_min'));
    await tester.ensureVisible(f);
    await tester.tap(f);
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    // 지금 초점이 간 칸의 이름(키)을 찾는다. 접힌 전동기 기여 칸(ec_sc_mkw 등)이면 안 된다.
    final ctx = FocusManager.instance.primaryFocus?.context;
    final field = ctx?.findAncestorWidgetOfExactType<TextField>();
    final k = (field?.key as ValueKey<String>?)?.value;
    // 아래쪽 칸이 모두 접힌 구역 안이라 여기서는 키보드가 닫힌다(초점 없음).
    expect(k == null || !k.startsWith('ec_sc_m'), isTrue, reason: '접힌 구역 안 칸($k)');
  });
}
