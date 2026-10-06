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

  group('식 4.1-1 손계산', () {
    // 일반 100 kW(효율 0.85·역률 0.8) → 147.06 kVA
    // UPS 50 kVA ÷ 0.9 × 2.5 + 충전 10 % 5 = 143.89 kVA
    // 전동기 합 75 kW, 가장 큰 30 kW 직입: (75 − 30) × 1.45 = 65.25, 30 × 1.45 × 6 = 261
    // GP = (147.06 + 143.89 + 65.25 + 261) × 1.00 = 617.20 kVA
    test('일반 + UPS + 전동기 직입, k 1.00', () {
      final r = calcGp(
        const GpInput(
          generalKw: 100,
          eff: 0.85,
          pf: 0.8,
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
          vvvfKw: 30,
          ledKw: 10,
          eff: 0.9,
          pf: 0.9,
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
    });

    test('입력 확인: λ 없음, PL > ΣPm, k 없음, 부하 없음', () {
      expect(
        calcGp(const GpInput(upsKva: 10, upsEff: 0.9, a: 1.45, c: 6, k: 1)).errors,
        contains(contains('λ')),
      );
      expect(
        calcGp(const GpInput(motorsKw: 10, largestKw: 20, a: 1.45, c: 6, k: 1)).errors,
        contains(contains('PL')),
      );
      expect(
        calcGp(const GpInput(generalKw: 10, eff: 0.9, pf: 0.9, a: 1.45, c: 6)).errors,
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
      await type(tester, 'eg_g_general', '100');
      await type(tester, 'eg_g_eff', '85');
      await type(tester, 'eg_g_pf', '80');
      await type(tester, 'eg_g_motors', '75');
      await type(tester, 'eg_g_largest', '30');
      await tester.ensureVisible(find.byKey(const Key('eg_c_direct')));
      await tester.tap(find.byKey(const Key('eg_c_direct')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('eg_k_20_25')));
      await tester.tap(find.byKey(const Key('eg_k_20_25')));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byKey(const Key('eg_g_k'))).controller!.text,
        '1.00',
      );
      // 147.06 + 65.25 + 261 = 473.31 kVA
      expect(find.text('473.3 kVA'), findsOneWidget);
      expect(allFlat(tester), contains(flat('PL × a × c = 30 × 1.45 × 6 = 261 kVA')));
    });

    testWidgets('PG 방식으로 바꾸면 옛 칸이 나오고, 방식은 다시 열어도 남는다', (tester) async {
      await pumpTab(tester);
      await tester.tap(find.byKey(const Key('eg_mode_pg')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('eg_load')), findsOneWidget);
      expect(find.byKey(const Key('eg_g_general')), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox());
      await pumpTab(tester);
      expect(find.byKey(const Key('eg_load')), findsOneWidget);
    });
  });
}
