// 발전기 용량 GP 방식(KDS 32 20 20:2024 식 4.1-1~4.1-5, 표 4.1-1) 순수 계산과 화면.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/theme/field_view.dart';
import 'package:tubing_calculator/src/presentation/electrical/elec_generator_gp.dart';
import 'package:tubing_calculator/src/presentation/electrical/elec_generator_tab.dart';

import 'formula_flat.dart';

void main() {
  setUpAll(expandFormulaCards);

  group('표 4.1-1 k', () {
    test('원문 2024판 값(2021판 오타 세 칸을 바로잡은 값)', () {
      expect(gpKFromTable(15, 20), 1.13);
      expect(gpKFromTable(15, 25), 1.42);
      expect(gpKFromTable(20, 25), 1.00);
      expect(gpKFromTable(20, 20), 0.80);
      // 2021판 오타 칸: 19 %·20 = 0.95→0.85, 19 %·21 = 0.09→0.90, 16 %·23 = 1.20→1.21
      expect(gpKFromTable(19, 20), 0.85);
      expect(gpKFromTable(19, 21), 0.90);
      expect(gpKFromTable(16, 23), 1.21);
    });

    test('표에 없는 조합은 null(원문에 보간 규칙이 없다)', () {
      expect(gpKFromTable(14, 20), isNull);
      expect(gpKFromTable(20, 26), isNull);
    });

    test('표는 행마다 x″d가 커질수록, 열마다 강하율이 클수록 단조', () {
      for (final row in kGpKTable) {
        for (var c = 1; c < row.length; c++) {
          expect(row[c], greaterThan(row[c - 1]));
        }
      }
      for (var c = 0; c < 6; c++) {
        for (var r = 1; r < kGpKTable.length; r++) {
          expect(kGpKTable[r][c], lessThan(kGpKTable[r - 1][c]));
        }
      }
    });
  });

  group('PL 고르기(기동용량 kW × c가 가장 큰 전동기)', () {
    test('kW가 가장 큰 전동기가 아니어도 기동용량이 크면 PL', () {
      // 10 kW 직입 c 7 → 70, 30 kW Y-Δ c 2 → 60
      expect(gpLargestStartIndex([(10, 7), (30, 2)]), 0);
      expect(gpLargestStartIndex([(10, 5), (30, 2)]), 1);
    });

    test('같으면 앞 줄, 빈 줄·c 없는 줄은 건너뛰고 없으면 null', () {
      expect(gpLargestStartIndex([(20, 3), (30, 2)]), 0);
      expect(gpLargestStartIndex([(null, null), (5, null), (5, 6)]), 2);
      expect(gpLargestStartIndex([(null, null)]), isNull);
    });
  });

  group('식 4.1-1 손계산', () {
    // 일반 100 kW(효율 0.85·역률 0.8) → 147.06 kVA
    // UPS 50 kVA ÷ 0.9 × 2.5 + 충전 10 % 5 = 143.89 kVA
    // 전동기 합 75 kW, 가장 큰 30 kW 직입: (75 − 30) × 1.45 = 65.25, 30 × 1.45 × 6 = 261
    // GP = (147.06 + 143.89 + 65.25 + 261) × 1.00 = 617.20 kVA
    test('일반 + UPS + 전동기 직입, k 1.00', () {
      final r = calcGp(
        const GpInput(
          loads: [
            GpLoad(kind: GpLoadKind.general, kw: 100, eff: 0.85, pf: 0.8),
          ],
          upsKva: 50,
          upsEff: 0.9,
          upsChargePct: 10,
          lambda: 2.5,
          motorsKw: 75,
          largestKw: 30,
          a: 1.45,
          c: 6,
          k: 1.0,
        ),
      );
      expect(r.errors, isEmpty);
      expect(r.pGeneral, closeTo(147.0588, 1e-3));
      expect(r.pUps, closeTo(143.8889, 1e-3));
      expect(r.upsCharge, closeTo(5, 1e-12));
      expect(r.motorRest, closeTo(65.25, 1e-9));
      expect(r.motorStart, closeTo(261, 1e-9));
      expect(r.gp, closeTo(617.198, 1e-2));
    });

    test('VVVF·LED는 λ를 곱해 ΣP에 넣고, k를 곱한다', () {
      final r = calcGp(
        const GpInput(
          loads: [
            GpLoad(kind: GpLoadKind.vvvf, kw: 30, eff: 0.9, pf: 0.9),
            GpLoad(kind: GpLoadKind.harmonic, kw: 10, eff: 0.9, pf: 0.9),
          ],
          lambda: 2.5,
          a: 1.38,
          c: 0,
          k: 1.13,
        ),
      );
      // 30 ÷ 0.81 × 2.5 = 92.59, 10 ÷ 0.81 × 2.5 = 30.86, 합 123.46 × 1.13 = 139.51
      expect(r.pVvvf, closeTo(92.5926, 1e-3));
      expect(r.pLed, closeTo(30.8642, 1e-3));
      expect(r.gp, closeTo(139.506, 1e-2));
      expect(r.loadP, [closeTo(92.5926, 1e-3), closeTo(30.8642, 1e-3)]);
    });

    test('부하마다 효율·역률이 달라도 줄마다 따로 나눠 더한다', () {
      final r = calcGp(
        const GpInput(
          loads: [
            GpLoad(kind: GpLoadKind.general, kw: 100, eff: 0.85, pf: 0.8),
            GpLoad(kind: GpLoadKind.general, kw: 20, eff: 0.95, pf: 1),
            GpLoad(kind: GpLoadKind.general),
          ],
          a: 1.45,
          c: 6,
          k: 1,
        ),
      );
      // 100 ÷ 0.68 = 147.06, 20 ÷ 0.95 = 21.05, 빈 줄은 0
      expect(r.errors, isEmpty);
      expect(r.loadP[1], closeTo(21.0526, 1e-3));
      expect(r.loadP[2], 0);
      expect(r.gp, closeTo(168.111, 1e-2));
    });

    test('용량이 있는 줄에 효율·역률이 없으면 줄 번호로 알린다', () {
      final r = calcGp(
        const GpInput(
          loads: [
            GpLoad(kind: GpLoadKind.general, kw: 10, eff: 0.9, pf: 0.9),
            GpLoad(kind: GpLoadKind.general, kw: 5, eff: 0.9),
          ],
          a: 1.45,
          c: 6,
          k: 1,
        ),
      );
      expect(r.errors, ['부하 2: 역률을 0 초과 100% 이하로 넣으십시오.']);
    });

    test('입력 확인: λ 없음, PL > ΣPm, k 없음, 부하 없음', () {
      expect(
        calcGp(
          const GpInput(upsKva: 10, upsEff: 0.9, a: 1.45, c: 6, k: 1),
        ).errors,
        contains(contains('λ')),
      );
      expect(
        calcGp(
          const GpInput(motorsKw: 10, largestKw: 20, a: 1.45, c: 6, k: 1),
        ).errors,
        contains(contains('PL')),
      );
      expect(
        calcGp(
          const GpInput(
            loads: [
              GpLoad(kind: GpLoadKind.general, kw: 10, eff: 0.9, pf: 0.9),
            ],
            a: 1.45,
            c: 6,
          ),
        ).errors,
        contains(contains('k')),
      );
      expect(
        calcGp(const GpInput(a: 1.45, c: 6, k: 1)).errors,
        contains('부하를 하나 이상 넣으십시오.'),
      );
    });
  });

  group('화면', () {
    Future<void> pumpTab(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(
          home: FieldViewTheme(child: Scaffold(body: ElecGeneratorTab())),
        ),
      );
      await tester.pumpAndSettle();
    }

    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> type(WidgetTester tester, String key, String text) async {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.enterText(find.byKey(Key(key)), text);
      await tester.pump();
    }

    testWidgets('기본은 GP 방식, 표 칸을 누르면 k가 들어가고 결과가 나온다', (tester) async {
      await pumpTab(tester);
      expect(
        tester.widget<ChoiceChip>(find.byKey(const Key('eg_mode_gp'))).selected,
        isTrue,
      );
      await type(tester, 'eg_row_kw_0', '100');
      await type(tester, 'eg_row_eff_0', '85');
      await type(tester, 'eg_row_pf_0', '80');
      // 전동기 30 kW 직입, 45 kW Y-Δ: 기동용량 30 × 6 = 180 > 45 × 2 = 90이라 PL = 30
      await type(tester, 'eg_m_kw_0', '30');
      await tester.ensureVisible(find.byKey(const Key('eg_m_start_0_direct')));
      await tester.tap(find.byKey(const Key('eg_m_start_0_direct')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('eg_m_add')));
      await tester.tap(find.byKey(const Key('eg_m_add')));
      await tester.pump();
      await type(tester, 'eg_m_kw_1', '45');
      await tester.ensureVisible(
        find.byKey(const Key('eg_m_start_1_starDelta')),
      );
      await tester.tap(find.byKey(const Key('eg_m_start_1_starDelta')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('eg_k_20_25')));
      await tester.tap(find.byKey(const Key('eg_k_20_25')));
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('eg_g_k')))
            .controller!
            .text,
        '1.00',
      );
      // 147.06 + 65.25 + 261 = 473.31 kVA
      expect(find.text('473.3 kVA'), findsOneWidget);
      expect(
        allFlat(tester),
        contains(flat('PL × a × c = 30 × 1.45 × 6 = 261 kVA')),
      );
      expect(allFlat(tester), contains(flat('ΣPm = 30 + 45 = 75 kW')));
      expect(
        allFlat(tester),
        contains(flat('PL: 전동기 1 (30 kW × c 6 = 기동용량 180, 가장 큼)')),
      );
      expect(
        allFlat(tester),
        contains(flat('k 1.00: 표 4.1-1에서 허용 전압강하 20 %, x″d 25 % 칸을 고른 값입니다.')),
      );
    });

    testWidgets('부하 줄마다 효율·역률이 다르게 들어가고, 줄 추가는 위 줄 효율·역률을 가져온다', (
      tester,
    ) async {
      await pumpTab(tester);
      await type(tester, 'eg_row_kw_0', '100');
      await type(tester, 'eg_row_eff_0', '85');
      await type(tester, 'eg_row_pf_0', '80');
      await tester.ensureVisible(find.byKey(const Key('eg_add')));
      await tester.tap(find.byKey(const Key('eg_add')));
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('eg_row_eff_1')))
            .controller!
            .text,
        '85',
      );
      await tester.ensureVisible(find.byKey(const Key('eg_kind_1_vvvf')));
      await tester.tap(find.byKey(const Key('eg_kind_1_vvvf')));
      await tester.pump();
      await type(tester, 'eg_row_kw_1', '30');
      await type(tester, 'eg_row_eff_1', '90');
      await type(tester, 'eg_row_pf_1', '90');
      await type(tester, 'eg_g_lambda', '2.5');
      await type(tester, 'eg_g_k', '1.1');
      // 100 ÷ 0.68 = 147.06, 30 ÷ 0.81 × 2.5 = 92.59, (147.06 + 92.59) × 1.1 = 263.6
      expect(find.textContaining('263.6 kVA'), findsWidgets);
      expect(
        allFlat(tester),
        contains(flat('② GP = [ΣP + (ΣPm − PL) × a + PL × a × c] × k')),
      );
      final all = allFlat(tester);
      expect(
        all,
        contains(
          flat(
            '부하 2 VVVF 전동기 P = kW ÷ (효율 × 역률) × λ = 30 ÷ (0.9 × 0.9) × 2.5 = 92.6 kVA',
          ),
        ),
      );
      expect(all, contains(flat('k 1.10: 직접 입력한 값입니다.')));
    });

    testWidgets('예전 저장값(일반·VVVF·LED 칸 + 같이 쓰는 효율·역률)은 줄로 옮긴다', (tester) async {
      SharedPreferences.setMockInitialValues({
        ElecGeneratorTab.draftKey:
            '{"mode":"gp","gGeneral":"100","gLed":"10","gEff":"85","gPf":"80"}',
      });
      await pumpTab(tester);
      String text(String key) =>
          tester.widget<TextField>(find.byKey(Key(key))).controller!.text;
      expect(text('eg_row_kw_0'), '100');
      expect(text('eg_row_eff_0'), '85');
      expect(text('eg_row_kw_1'), '10');
      expect(text('eg_row_pf_1'), '80');
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const Key('eg_kind_1_harmonic')))
            .selected,
        isTrue,
      );
    });

    testWidgets('예전 전동기 저장값(합계·가장 큰 전동기·c)은 줄 둘로 옮기고, 나머지 줄 기동 방식은 고르라고 알린다', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        ElecGeneratorTab.draftKey:
            '{"mode":"gp","gMotors":"75","gLargest":"30","gC":"6","gK":"1"}',
      });
      await pumpTab(tester);
      String text(String key) =>
          tester.widget<TextField>(find.byKey(Key(key))).controller!.text;
      expect(text('eg_m_kw_0'), '30');
      expect(text('eg_m_c_0'), '6');
      expect(text('eg_m_kw_1'), '45');
      expect(text('eg_m_c_1'), '');
      expect(
        allFlat(tester),
        contains(flat('전동기 2: 기동 방식을 고르거나 기동계수 c를 넣으십시오.')),
      );
    });

    testWidgets('줄 목록과 표에서 누른 k 칸은 다시 열어도 남는다', (tester) async {
      await pumpTab(tester);
      await type(tester, 'eg_row_kw_0', '50');
      await type(tester, 'eg_row_eff_0', '90');
      await type(tester, 'eg_row_pf_0', '90');
      await tester.ensureVisible(find.byKey(const Key('eg_kind_0_harmonic')));
      await tester.tap(find.byKey(const Key('eg_kind_0_harmonic')));
      await tester.ensureVisible(find.byKey(const Key('eg_k_17_22')));
      await tester.tap(find.byKey(const Key('eg_k_17_22')));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox());
      await pumpTab(tester);
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const Key('eg_kind_0_harmonic')))
            .selected,
        isTrue,
      );
      await type(tester, 'eg_g_lambda', '2.5');
      expect(
        allFlat(tester),
        contains(flat('k 1.07: 표 4.1-1에서 허용 전압강하 17 %, x″d 22 % 칸을 고른 값입니다.')),
      );
    });

    testWidgets('좁은 폰(344)·큰 글씨(1.3)에서 부하 줄·k 표·결과가 넘치지 않는다', (tester) async {
      tester.view.physicalSize = const Size(344, 6000);
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
          home: const FieldViewTheme(child: Scaffold(body: ElecGeneratorTab())),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '처음 화면');
      await type(tester, 'eg_row_kw_0', '1250.5');
      await type(tester, 'eg_row_eff_0', '85');
      await type(tester, 'eg_row_pf_0', '80');
      await tester.ensureVisible(find.byKey(const Key('eg_add')));
      await tester.tap(find.byKey(const Key('eg_add')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('eg_kind_1_harmonic')));
      await tester.tap(find.byKey(const Key('eg_kind_1_harmonic')));
      await type(tester, 'eg_row_kw_1', '30');
      await type(tester, 'eg_g_lambda', '2.5');
      await tester.ensureVisible(find.byKey(const Key('eg_k_15_25')));
      await tester.tap(find.byKey(const Key('eg_k_15_25')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '값을 넣은 뒤');
      // 칩 세 개는 좁아도 한 줄 안에 들어가거나 줄을 바꿔 들어가고, 칸 이름표는 잘리지 않는다.
      final kw = tester.getRect(find.byKey(const Key('eg_row_kw_0')));
      final pf = tester.getRect(find.byKey(const Key('eg_row_pf_0')));
      expect(pf.right, lessThanOrEqualTo(344));
      expect(kw.width, greaterThan(60));
    });

    testWidgets('PG 방식으로 바꾸면 옛 칸이 나오고, 방식은 다시 열어도 남는다', (tester) async {
      await pumpTab(tester);
      await tester.tap(find.byKey(const Key('eg_mode_pg')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('eg_load')), findsOneWidget);
      expect(find.byKey(const Key('eg_row_kw_0')), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox());
      await pumpTab(tester);
      expect(find.byKey(const Key('eg_load')), findsOneWidget);
    });
  });
}
