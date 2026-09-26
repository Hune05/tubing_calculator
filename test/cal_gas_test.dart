// 교정 가스 소모량: NIST 압축 계수 표, 용기 가스량, 교정 1회 사용량·남은 횟수, 공기 눈금 보정, 이산화탄소 무게.
// 손 계산 값은 같은 식을 따로 계산한 것(20°C, 47L, 수소 150→10bar abs, 0.6L/min × 10분).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/theme/field_view.dart';
import 'package:tubing_calculator/src/presentation/instrument/cal_gas.dart';
import 'package:tubing_calculator/src/presentation/instrument/cal_gas_tab.dart';

void main() {
  group('압축 계수 Z(NIST)', () {
    test('표 값: 20°C 150bar abs 수소 1.0924, 질소 1.0205', () {
      expect(zOf(CalGas.h2, 150, 20), closeTo(1.0924, 1e-9));
      expect(zOf(CalGas.n2, 150, 20), closeTo(1.0205, 1e-9));
    });
    test('사이 값은 선형 보간', () {
      expect(zOf(CalGas.h2, 137.5, 20), closeTo((1.0765 + 1.0924) / 2, 1e-9));
      expect(zOf(CalGas.h2, 150, 10), closeTo((1.0973 + 1.0924) / 2, 1e-9));
    });
    test('표 밖(250bar abs 초과, 0~40°C 밖)과 이산화탄소는 null', () {
      expect(zOf(CalGas.h2, 251, 20), isNull);
      expect(zOf(CalGas.h2, 100, 41), isNull);
      expect(zOf(CalGas.h2, 100, -1), isNull);
      expect(zOf(CalGas.co2, 50, 20), isNull);
    });
  });

  group('용기·교정 1회', () {
    test('수소 47L 150→10bar abs, 20°C: 쓸 수 있는 양 5.505Nm³', () {
      final r = calGasUse(
        gas: CalGas.h2,
        tC: 20,
        pGaugeBar: 150 - kAtmBar,
        residualGaugeBar: 10 - kAtmBar,
        lpm: 0.6,
        minutes: 10,
      )!;
      expect(r.totalNm3, closeTo(5.9347, 1e-3));
      expect(r.availableNm3, closeTo(5.5051, 1e-3));
      expect(r.perCalNL, closeTo(5.5907, 1e-3));
      expect(r.calsLeft, 984);
      expect(r.dropPerCalBar, closeTo(0.1413, 1e-3));
      expect(r.flowMinutes! / 60, closeTo(164.12, 0.05));
    });

    test('수소를 이상기체로 보면 150bar에서 약 9% 많게 나온다', () {
      final real = cylinderNm3(
        gas: CalGas.h2,
        waterL: 47,
        pGaugeBar: 150 - kAtmBar,
        tC: 20,
      )!;
      final ideal = 0.047 * 150 / kAtmBar * kT0 / (20 + kT0);
      expect(ideal / real, closeTo(1.0924, 1e-9));
    });

    test('공기 눈금 유량계로 수소: 실제 유량은 약 3.79배(Brooks 표 3.78)', () {
      expect(airScaleFactor(CalGas.h2), closeTo(3.79, 0.01));
      expect(airScaleFactor(CalGas.co2), closeTo(0.81, 0.01));
      expect(airScaleFactor(CalGas.n2), closeTo(1.02, 0.01));
      final r = calGasUse(
        gas: CalGas.h2,
        tC: 20,
        pGaugeBar: 140,
        residualGaugeBar: 10,
        lpm: 0.6,
        airScale: true,
        minutes: 10,
      )!;
      expect(r.actualLpm, closeTo(0.6 * 3.7923, 1e-3));
    });

    test('이산화탄소는 무게로: 32kg = 16.19Nm³', () {
      final r = calGasUse(gas: CalGas.co2, tC: 20, netKg: 32)!;
      expect(r.availableNm3, closeTo(16.185, 1e-3));
      expect(r.totalNm3, isNull);
      expect(r.dropPerCalBar, isNull);
      expect(47 / kCo2FillConstant, closeTo(32.0, 0.05)); // 법정 충전량
    });

    test('입력이 모자라거나 남길 압력이 더 높으면 null', () {
      expect(calGasUse(gas: CalGas.h2, tC: 20, pGaugeBar: 100), isNull);
      expect(
        calGasUse(gas: CalGas.h2, tC: 20, pGaugeBar: 5, residualGaugeBar: 10),
        isNull,
      );
      expect(calGasUse(gas: CalGas.co2, tC: 20), isNull);
    });
  });

  group('화면', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> pump(
      WidgetTester tester, {
      Size size = const Size(390, 2600),
      double scale = 1,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const FieldViewTheme(child: Scaffold(body: CalGasTab())),
        ),
      );
      await tester.pumpAndSettle();
    }

    String result(WidgetTester tester) => tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(const Key('cg_result')),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data ?? '')
        .join('\n');

    testWidgets('수소 14.7MPa → 1MPa, 0.6L/min 10분: 남은 교정 횟수', (tester) async {
      await pump(tester);
      await tester.enterText(find.byKey(const Key('cg_p')), '14.7');
      await tester.enterText(find.byKey(const Key('cg_rest')), '1');
      await tester.pump();
      expect(result(tester), contains('Nm³'));
      await tester.enterText(find.byKey(const Key('cg_min')), '10');
      await tester.pump();
      final r = result(tester);
      expect(r, contains('회'));
      expect(r, contains('교정 1회 사용량: 5.6 NL'));
      expect(r, contains('MPa쯤 내려갑니다'));
    });

    testWidgets('이산화탄소는 무게 칸, 압력 칸이 없다', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('cg_gas_co2')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cg_p')), findsNothing);
      await tester.enterText(find.byKey(const Key('cg_kg')), '32');
      await tester.pump();
      expect(result(tester), contains('16.19 Nm³'));
    });

    testWidgets('좁은 폰(344)·글씨 1.3배에서 넘치지 않는다', (tester) async {
      await pump(tester, size: const Size(344, 3200), scale: 1.3);
      await tester.enterText(find.byKey(const Key('cg_p')), '14.7');
      await tester.enterText(find.byKey(const Key('cg_rest')), '0.5');
      await tester.enterText(find.byKey(const Key('cg_min')), '15');
      await tester.tap(find.byKey(const Key('cg_scale_air')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
