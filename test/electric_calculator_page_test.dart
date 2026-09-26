// 전기 계산기 화면: 부하 전류 → 전선 굵기 넘기기, 결과 글, 안내 창, 좁은 폰.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/electrical/electric_calculator_page.dart';

Future<void> pumpPage(
  WidgetTester tester, {
  Size size = const Size(390, 3000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: ElectricCalculatorPage()));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('ec_tab_load')));
  await tester.pumpAndSettle();
}

String textIn(WidgetTester tester, Key key) {
  final texts = tester.widgetList<Text>(
    find.descendant(of: find.byKey(key), matching: find.byType(Text)),
  );
  return texts.map((t) => t.data ?? '').join('\n');
}

/// "근거 보기"를 펴고 글을 읽는다.
Future<String> basisText(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.text('근거 보기'));
  await tester.pumpAndSettle();
  return textIn(tester, Key(key));
}

Future<void> openTab(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('380V 삼상 11kW 효율 90 역률 85 → 21.8A, 1.25배 27.3A를 전선 탭으로', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.enterText(find.byKey(const Key('ec_kw')), '11');
    await tester.pump();
    final load = textIn(tester, const Key('ec_load_result'));
    expect(load, contains('21.8 A'));
    expect(load, contains('27.3 A (×1.25) 기준'));
    expect(load, contains('명판 정격전류가 있으면 그 값을 우선 적용하십시오.'));

    await tester.tap(find.byKey(const Key('ec_to_cable')));
    await tester.pumpAndSettle();
    final ib = tester.widget<TextField>(find.byKey(const Key('ec_ib')));
    expect(ib.controller!.text, '21.8');
    final r = textIn(tester, const Key('ec_cable_result'));
    // 설계 21.8×1.25 = 27.3A → 차단기 하한 30A, F-CV 트레이(E) 3가닥 2.5sq 32A ≥ 30A.
    // 상한: 250% 54.6A → 50A. 전압강하는 실제 21.8A로: 50m 2.5sq 90°C ≈ 4.0% < 5%.
    expect(r, contains('차단기 30A ~ 50A (전동기 회로)'));
    expect(r, contains('허용전류 32A (보정 후) ≥ 차단기 30A'));
    expect(r, contains('한도 5% 이내입니다.'));
    expect(r, contains('과부하는 열동형 과부하 계전기(THR)로 보호합니다'));
    expect(
      r,
      contains('보호도체(접지선): 케이블 안 2.5sq / 따로 포설할 때 최소 2.5sq(기계적 보호)·4sq'),
    );
    final b = await basisText(tester, 'ec_cable_basis');
    expect(b, contains('설계전류 27.3A = 부하 21.8A × 1.25'));
    expect(b, contains('허용전류 기준 2.5sq'));
    expect(b, contains('온도 보정 1 × 다조 포설 보정 1'));
    expect(b, contains('NEC 430.52'));
    expect(
      textIn(tester, const Key('ec_sum_cable')),
      contains('2.5sq · 차단기 30~50A'),
    );
  });

  testWidgets('HP로 바꾸면 480V 15HP → 전류 계산', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byKey(const Key('ec_v_480')));
    await tester.tap(find.byKey(const Key('ec_hp')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('ec_kw')), '15');
    await tester.pump();
    // 15HP = 11.19kW ÷ (√3·480·0.85·0.9) = 17.6A
    final t = textIn(tester, const Key('ec_load_result'));
    expect(t, contains('17.6 A'));
    expect(t, contains('NEC 430.250 표 (460V) 21 A'));
    expect(find.text('출력 (HP)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ec_unit_kw')));
    await tester.pump();
    expect(find.text('출력 (kW)'), findsOneWidget);
  });

  testWidgets('380V 11kW면 HD현대일렉트릭 IE3 전동기 22.2A를 참고로 보인다', (tester) async {
    await pumpPage(tester);
    await tester.enterText(find.byKey(const Key('ec_kw')), '11');
    await tester.pump();
    expect(
      textIn(tester, const Key('ec_load_result')),
      contains('참고: HD현대일렉트릭 IE3 4극 380V 전동기 22.2 A (효율 92.4%, 역률 81.4%)'),
    );
  });

  testWidgets('? 를 누르면 무슨 값을 넣는지 안내 창이 뜬다', (tester) async {
    await pumpPage(tester);
    final row = find
        .ancestor(
          of: find.byKey(const Key('ec_kw')),
          matching: find.byType(Row),
        )
        .first;
    await tester.tap(
      find.descendant(
        of: row,
        matching: find.byIcon(Icons.help_outline_rounded),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('명판의 정격 출력'), findsOneWidget);
  });

  testWidgets('전압강하 탭: 4sq 20A 100m 삼상 380V → 4.6%, 한도 이내·최대 길이', (
    tester,
  ) async {
    await pumpPage(tester);
    await openTab(tester, 'ec_tab_vd');
    await tester.enterText(find.byKey(const Key('ec_vd_i')), '20');
    await tester.enterText(find.byKey(const Key('ec_vd_len')), '100');
    await tester.pump();
    final r = textIn(tester, const Key('ec_vd_result'));
    // √3·20·0.1·(5.878·0.85 + 0.096·0.527) = 17.48V → 4.6%
    expect(r, contains('4.6 %'));
    expect(r, contains('한도 5% 이내입니다.'));
    expect(r, contains('한도 이내 최대 편도 길이 약'));
    final b = await basisText(tester, 'ec_vd_basis');
    expect(b, contains('X = 0.096 Ω/km(60Hz'));
  });

  testWidgets('역률 탭: 100kW 80→95% → 42.1 kvar, 774 μF, 전류 189.9 → 159.9A', (
    tester,
  ) async {
    await pumpPage(tester);
    await openTab(tester, 'ec_tab_pf');
    await tester.enterText(find.byKey(const Key('ec_pc_kw')), '100');
    await tester.pump();
    final r = textIn(tester, const Key('ec_pf_result'));
    expect(r, contains('42.1 kvar'));
    expect(r, contains('정전용량 약 774 μF (380V, 60Hz)'));
    expect(r, contains('부하 전류 개선 전 189.9 A → 개선 후 159.9 A'));
    expect(r, contains('콘덴서 전류 약 64 A'));
    expect(textIn(tester, const Key('ec_sum_pf')), '42.1 kvar · 774 μF');
    expect(find.text('개선 전 역률 (%)'), findsOneWidget);
  });

  testWidgets('좁은 폰(344)·큰 글씨에서 네 탭 모두 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(344, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: const ElectricCalculatorPage(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ec_tab_load')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('ec_kw')), '75');
    await tester.pump();
    expect(tester.takeException(), isNull);
    for (final t in ['ec_tab_cable', 'ec_tab_vd', 'ec_tab_pf', 'ec_tab_load']) {
      await openTab(tester, t);
      expect(tester.takeException(), isNull, reason: t);
      expect(
        tester.widget<TabBar>(find.byType(TabBar)).controller!.index,
        [
          'ec_tab_basic',
          'ec_tab_load',
          'ec_tab_cable',
          'ec_tab_vd',
          'ec_tab_conduit',
          'ec_tab_bus',
          'ec_tab_pf',
        ].indexOf(t),
      );
    }
  });
}
