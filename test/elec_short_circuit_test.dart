// 단락 전류 계산과 탭 화면 시험. 손계산 값은 각 시험 위에 식과 함께 적었다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/theme/field_view.dart';
import 'package:tubing_calculator/src/presentation/electrical/elec_short_circuit.dart';
import 'package:tubing_calculator/src/presentation/electrical/elec_short_circuit_tab.dart';
import 'package:tubing_calculator/src/presentation/electrical/elec_tables.dart';
import 'formula_flat.dart';

void main() {
  setUpAll(expandFormulaCards);
  group('순수 계산', () {
    // 예 A: 1000kVA, %Z 5.5, 380V, 무한 전원, 케이블 없음, 부하손 없음.
    //  In = 1000000 / (√3 × 380) = 1519.34 A
    //  %임피던스법: Ik = In / 0.055 = 27,624 A
    //  IEC 60909: KT = 0.95×1.05 / (1 + 0.6×0.055) = 0.96563, ZT = 0.055 × 380² / 1e6 = 7.942 mΩ
    //   Ik″ = 1.05 × 380 / (√3 × 0.96563 × 0.007942) = 30,038 A
    //  R = 0 이라 κ = 1.02 + 0.98 = 2.0, ip = 2.0 × √2 × 30,038 = 84,960 A
    test('예 A: 1000kVA 5.5%Z 380V 무한 전원', () {
      final r = calcShortCircuit(
        const ScInput(kva: 1000, volts: 380, zPercent: 5.5),
      );
      expect(r.ok, isTrue);
      expect(r.ikPercentZA, closeTo(27624, 2));
      expect(r.kT, closeTo(0.96563, 1e-4));
      expect(r.ikMaxA, closeTo(30038, 3));
      expect(r.kappa, closeTo(2.0, 1e-9));
      expect(r.ipA, closeTo(84960, 20));
      expect(r.infiniteSource, isTrue);
      expect(r.startIkMaxA.length, 1);
      expect(r.notes.any((n) => n.contains('무한 전원')), isTrue);
      expect(r.notes.any((n) => n.contains('부하손을 넣지 않아')), isTrue);
    });

    // 예 B: 예 A + 240mm² 50m 한 가닥. 20°C 저항 0.0754 Ω/km → R = 3.77 mΩ, X = 0.096 × 0.05 = 4.8 mΩ.
    //  %임피던스법: Z = √(3.77² + (7.942 + 4.8)²) = 13.288 mΩ → Ik = 380 / (√3 × 0.013288) = 16,511 A
    //  IEC: Z = √(3.77² + (0.96563×7.942 + 4.8)²) = 12.51 mΩ → Ik″ = 399 / √3 / 0.01251 = 17,684 A
    //  최소 단락(IEC 909 = IS 13234 9.3.1 식 32: R = R20 × [1 + 0.004 × (θe − 20)], θe = 단락 종료 온도):
    //   XLPE θe 250°C: R = 3.77 × (1 + 0.004 × 230) = 3.77 × 1.92 = 7.238 mΩ,
    //   X = 0.96563 × 7.942 + 4.8 = 12.469 mΩ, Z = √(7.238² + 12.469²) = 14.418 mΩ
    //   3상 = 0.95 × 380 ÷ (√3 × 0.014418) = 14,456 A, 2상 = 14,456 × √3/2 = 12,519 A
    //   (예전 90°C·0.00393 값 15,596 A보다 작다. 보호 감도 확인에서 안전 쪽)
    //   PVC θe 160°C: R = 3.77 × 1.56 = 5.881 mΩ, Z = 13.786 mΩ → 3상 15,118 A, 2상 13,093 A
    test('예 B: 케이블 한 구간, 최대·최소', () {
      final r = calcShortCircuit(
        const ScInput(
          kva: 1000,
          volts: 380,
          zPercent: 5.5,
          insulation: Insulation.xlpe90,
          segments: [ScSegment(sizeMm2: 240, lengthM: 50)],
        ),
      );
      expect(r.ikPercentZA, closeTo(16511, 3));
      expect(r.ikMaxA, closeTo(17684, 4));
      expect(r.startIkMaxA[0], closeTo(30038, 3));
      expect(r.startIkMaxA[1], closeTo(17684, 4));
      expect(r.ikMin3A, closeTo(14456, 4));
      expect(r.ikMin2A, closeTo(12519, 4));
      expect(r.ikMin2A / r.ikMin3A, closeTo(0.8660254, 1e-6));
      expect(r.ikMaxA, greaterThan(r.ikMin3A));
      final pvc = calcShortCircuit(
        const ScInput(
          kva: 1000,
          volts: 380,
          zPercent: 5.5,
          segments: [ScSegment(sizeMm2: 240, lengthM: 50)],
        ),
      );
      expect(pvc.ikMin3A, closeTo(15118, 4));
      expect(pvc.ikMin2A, closeTo(13093, 4));
      // 최대 단락은 절연과 상관없이 20°C 저항이라 같다.
      expect(pvc.ikMaxA, closeTo(r.ikMaxA, 1e-9));
    });

    test('최소 단락 온도: 단락 종료 온도와 온도계수 0.004(IEC 909 식 32)', () {
      expect(minScConductorTemp(Insulation.pvc70), 160);
      expect(minScConductorTemp(Insulation.xlpe90), 250);
      expect(kScMinAlpha, 0.004);
      // 95mm²: 0.193 × (1 + 0.004 × 140) = 0.193 × 1.56 = 0.30108 Ω/km
      expect(minScResistance(95, 160), closeTo(0.30108, 1e-9));
      // 0.193 × (1 + 0.004 × 230) = 0.193 × 1.92 = 0.37056 Ω/km
      expect(minScResistance(95, 250), closeTo(0.37056, 1e-9));
    });

    // 예 C: 상위 500MVA, 부하손 10kW, 구간1 95mm² 30m × 2가닥 병렬, 구간2 16mm² 20m. c = 1.05.
    //  Zq = 1.05 × 380² / 500e6 = 0.3033 mΩ, Xq = 0.995 Zq, Rq = 0.1 Xq
    //  RT = 10/1000 × 0.1444 = 1.444 mΩ, XT = √(7.942² − 1.444²) = 7.810 mΩ, xT = 0.05409, KT = 0.96615
    //  구간 시작 0: 28,884 A, 구간 1 끝: 22,490 A (R/X 0.465), 구간 2 끝(고장점): 7,801 A (R/X 2.44, κ = 1.0207)
    //  %임피던스법 고장점: 7,395 A
    test('예 C: 계통·부하손·병렬·두 구간 직렬', () {
      final r = calcShortCircuit(
        const ScInput(
          kva: 1000,
          volts: 380,
          zPercent: 5.5,
          pcuKw: 10,
          upstreamMvaMax: 500,
          segments: [
            ScSegment(sizeMm2: 95, lengthM: 30, parallel: 2),
            ScSegment(sizeMm2: 16, lengthM: 20),
          ],
        ),
      );
      expect(r.startIkMaxA[0], closeTo(28884, 5));
      expect(r.startIkMaxA[1], closeTo(22490, 5));
      expect(r.startIkMaxA[2], closeTo(7801, 3));
      expect(r.ikMaxA, closeTo(7801, 3));
      expect(r.rOverX, closeTo(2.4378, 1e-3));
      expect(r.kappa, closeTo(1.0207, 1e-4));
      expect(r.ikPercentZA, closeTo(7395, 3));
      expect(r.infiniteSource, isFalse);
      expect(r.hasLoss, isTrue);
      // 값이 아래로 내려가야 한다: 케이블이 길수록 단락전류는 줄어든다.
      expect(r.startIkMaxA[0], greaterThan(r.startIkMaxA[1]));
      expect(r.startIkMaxA[1], greaterThan(r.startIkMaxA[2]));
    });

    test('같은 케이블을 둘로 나눠도 합이 같다', () {
      final one = calcShortCircuit(
        const ScInput(
          kva: 500,
          volts: 380,
          zPercent: 5,
          segments: [ScSegment(sizeMm2: 95, lengthM: 50)],
        ),
      );
      final two = calcShortCircuit(
        const ScInput(
          kva: 500,
          volts: 380,
          zPercent: 5,
          segments: [
            ScSegment(sizeMm2: 95, lengthM: 20),
            ScSegment(sizeMm2: 95, lengthM: 30),
          ],
        ),
      );
      expect(two.ikMaxA, closeTo(one.ikMaxA, 1e-6));
      expect(two.ikMin3A, closeTo(one.ikMin3A, 1e-6));
    });

    // 전동기: 200kW, 효율×역률 0.8, 배수 5, 380V → IrM = 200000 / (√3 × 380 × 0.8) = 379.84 A
    //  |ZM| = 380 ÷ (√3 × 5 × 379.84) = 115.52 mΩ. RM/XM = 0.42(IEC 909 8.3.2.5):
    //  XM = 115.52 ÷ √(1 + 0.42²) = 106.51 mΩ, RM = 0.42 × 106.51 = 44.73 mΩ (크기는 그대로 115.52 mΩ)
    //  변압기 2차(구간 0)에서 전동기 기여 = c × 배수 × IrM = 1.05 × 5 × 379.84 = 1,994.1 A
    //  피크: κ = 2.0(무한 전원·RT 0) × √2 × 30,038 + κM 1.3 × √2 × 1,994.1 = 84,960 + 3,666 = 88,626 A
    test('전동기 기여와 최소 단락에서 빠짐', () {
      final base = calcShortCircuit(
        const ScInput(kva: 1000, volts: 380, zPercent: 5.5),
      );
      final r = calcShortCircuit(
        const ScInput(
          kva: 1000,
          volts: 380,
          zPercent: 5.5,
          motorKw: 200,
          motorEffPf: 0.8,
          motorMultiple: 5,
        ),
      );
      expect(r.motorRatedA, closeTo(379.9, 0.2));
      expect(r.ikMotorA, closeTo(1994.5, 1.5));
      expect(r.ikMaxA, closeTo(base.ikMaxA + r.ikMotorA, 1e-6));
      expect(r.ikMin3A, closeTo(base.ikMin3A, 1e-9));
      expect(r.ipA, greaterThan(base.ipA));
      expect(r.ipA, closeTo(88626, 20));
      final m = motorImpedance(0.11552);
      expect(m.x, closeTo(0.106507, 1e-6));
      expect(m.r, closeTo(0.044733, 1e-6));
      expect(m.abs, closeTo(0.11552, 1e-12));
      expect(kScMotorKappa, 1.3);
    });

    test('전동기 세 칸이 덜 차면 반영하지 않고 알림', () {
      final r = calcShortCircuit(
        const ScInput(
          kva: 1000,
          volts: 380,
          zPercent: 5.5,
          motorKw: 200,
          motorEffPf: 0.8,
        ),
      );
      expect(r.motorsIncluded, isFalse);
      expect(r.ikMotorA, 0);
      expect(r.notes.any((n) => n.contains('세 칸')), isTrue);
    });

    test('부하손을 모르면 값이 크게 나온다(최대는 안전 쪽, 최소는 안전 쪽 아님)', () {
      final withR = calcShortCircuit(
        const ScInput(
          kva: 100,
          volts: 380,
          zPercent: 4,
          pcuKw: 2,
          segments: [ScSegment(sizeMm2: 35, lengthM: 20)],
        ),
      );
      final noR = calcShortCircuit(
        const ScInput(
          kva: 100,
          volts: 380,
          zPercent: 4,
          segments: [ScSegment(sizeMm2: 35, lengthM: 20)],
        ),
      );
      expect(noR.ikMaxA, greaterThan(withR.ikMaxA));
      expect(noR.ikMin3A, greaterThan(withR.ikMin3A));
      expect(noR.ipA, greaterThan(withR.ipA));
      expect(noR.notes.any((n) => n.contains('최소 단락도 실제보다 크게')), isTrue);
    });

    test('c 1.10은 1.05보다 크다', () {
      final a = calcShortCircuit(
        const ScInput(kva: 1000, volts: 380, zPercent: 5.5),
      );
      final b = calcShortCircuit(
        const ScInput(kva: 1000, volts: 380, zPercent: 5.5, cMax: kScCMax10),
      );
      // KT도 cmax에 비례하므로 무한 전원 변압기 단독에서는 c가 상쇄되어 거의 같다.
      expect(b.ikMaxA / a.ikMaxA, closeTo(1.0, 0.02));
      final c = calcShortCircuit(
        const ScInput(
          kva: 1000,
          volts: 380,
          zPercent: 5.5,
          segments: [ScSegment(sizeMm2: 95, lengthM: 30)],
        ),
      );
      final d = calcShortCircuit(
        const ScInput(
          kva: 1000,
          volts: 380,
          zPercent: 5.5,
          cMax: kScCMax10,
          segments: [ScSegment(sizeMm2: 95, lengthM: 30)],
        ),
      );
      expect(d.ikMaxA, greaterThan(c.ikMaxA));
    });

    test('식 함수: KT와 κ', () {
      // KT = 0.95 × 1.05 / (1 + 0.6 × 0.06) = 0.9975 / 1.036 = 0.96284
      expect(transformerKt(1.05, 0.06), closeTo(0.96284, 1e-5));
      expect(peakKappa(0), closeTo(2.0, 1e-12));
      // R/X = 0.1 → κ = 1.02 + 0.98 × e^-0.3 = 1.7460
      expect(peakKappa(0.1), closeTo(1.7460, 1e-4));
      expect(peakKappa(10), closeTo(1.02, 1e-6));
    });

    test('입력 오류는 조용히 잘라 내지 않고 오류를 돌려준다', () {
      ScResult r(ScInput i) => calcShortCircuit(i);
      expect(
        r(const ScInput(kva: 0, volts: 380, zPercent: 5)).errors,
        isNotEmpty,
      );
      expect(
        r(const ScInput(kva: 500, volts: -1, zPercent: 5)).errors,
        isNotEmpty,
      );
      expect(
        r(const ScInput(kva: 500, volts: 380, zPercent: 100)).errors,
        isNotEmpty,
      );
      expect(
        r(const ScInput(kva: 500, volts: 380, zPercent: 0)).errors,
        isNotEmpty,
      );
      // 부하손이 %Z 가 허용하는 값(500 × 5% = 25kW) 이상이면 오류.
      final loss = r(
        const ScInput(kva: 500, volts: 380, zPercent: 5, pcuKw: 25),
      );
      expect(loss.errors.single, contains('부하손'));
      expect(
        r(const ScInput(kva: 500, volts: 380, zPercent: 5, pcuKw: -1)).errors,
        isNotEmpty,
      );
      expect(
        r(
          const ScInput(
            kva: 500,
            volts: 380,
            zPercent: 5,
            upstreamMvaMax: 100,
            upstreamMvaMin: 200,
          ),
        ).errors,
        isNotEmpty,
      );
      expect(
        r(
          const ScInput(
            kva: 500,
            volts: 380,
            zPercent: 5,
            motorKw: 100,
            motorEffPf: 1.2,
            motorMultiple: 5,
          ),
        ).errors,
        isNotEmpty,
      );
      expect(
        r(
          const ScInput(
            kva: 500,
            volts: 380,
            zPercent: 5,
            segments: [ScSegment(sizeMm2: 95, lengthM: 0)],
          ),
        ).errors,
        isNotEmpty,
      );
      expect(
        r(
          const ScInput(
            kva: 500,
            volts: 380,
            zPercent: 5,
            segments: [ScSegment(sizeMm2: 95, lengthM: 10, parallel: 0)],
          ),
        ).errors,
        isNotEmpty,
      );
      expect(
        r(
          const ScInput(
            kva: 500,
            volts: 380,
            zPercent: 5,
            segments: [ScSegment(sizeMm2: 7, lengthM: 10)],
          ),
        ).errors,
        isNotEmpty,
      );
      final bad = r(const ScInput(kva: 0, volts: 380, zPercent: 5));
      expect(bad.ikMaxA, 0);
      expect(bad.startIkMaxA, isEmpty);
    });

    test('차단용량 비교: 같으면 합격', () {
      expect(breakingOk(30, 30), isTrue);
      expect(breakingOk(30, 30.01), isFalse);
      expect(breakingOk(35, 30.04), isTrue);
    });
  });

  group('케이블 열 견딤 I²t', () {
    // PVC k=115, 95mm², Ik 10kA: t = (115 × 95 / 10000)² = 1.19356초, 1초에 필요한 S = 10000 / 115 = 86.96mm²
    test('PVC 경계', () {
      final atLimit = cableWithstand(
        sizeMm2: 95,
        insulation: Insulation.pvc70,
        ikA: 10000,
        tSec: 1.19355625,
      )!;
      expect(atLimit.ok, isTrue);
      expect(atLimit.tMaxSec, closeTo(1.19355625, 1e-9));
      expect(atLimit.k, 115);
      final over = cableWithstand(
        sizeMm2: 95,
        insulation: Insulation.pvc70,
        ikA: 10000,
        tSec: 1.1936,
      )!;
      expect(over.ok, isFalse);
      final one = cableWithstand(
        sizeMm2: 95,
        insulation: Insulation.pvc70,
        ikA: 10000,
        tSec: 1,
      )!;
      expect(one.sMinMm2, closeTo(86.9565, 1e-3));
      expect(one.ok, isTrue);
      final small = cableWithstand(
        sizeMm2: 70,
        insulation: Insulation.pvc70,
        ikA: 10000,
        tSec: 1,
      )!;
      expect(small.ok, isFalse);
    });

    // XLPE k=143: 95mm² Ik 10kA → t = (143 × 95 / 10000)² = 1.8456초
    test('XLPE와 병렬 가닥', () {
      final x = cableWithstand(
        sizeMm2: 95,
        insulation: Insulation.xlpe90,
        ikA: 10000,
        tSec: 1,
      )!;
      expect(x.k, 143);
      expect(x.tMaxSec, closeTo(1.84562, 1e-4));
      final par = cableWithstand(
        sizeMm2: 95,
        insulation: Insulation.xlpe90,
        ikA: 10000,
        tSec: 1,
        parallel: 2,
      )!;
      expect(par.ikPerConductorA, 5000);
      expect(par.tMaxSec, closeTo(x.tMaxSec * 4, 1e-9));
    });

    // 통과 에너지: 허용 k²S² = 13225 × 9025 = 119,355,625 A²s
    test('통과 에너지 비교', () {
      final ok = cableWithstand(
        sizeMm2: 95,
        insulation: Insulation.pvc70,
        ikA: 10000,
        tSec: 0.05,
        letThroughA2s: 1.19e8,
      )!;
      expect(ok.allowedA2s, closeTo(119355625, 1));
      expect(ok.letThroughOk, isTrue);
      final bad = cableWithstand(
        sizeMm2: 95,
        insulation: Insulation.pvc70,
        ikA: 10000,
        tSec: 0.05,
        letThroughA2s: 1.2e8,
      )!;
      expect(bad.letThroughOk, isFalse);
      // 병렬 2가닥이면 회로 전체 허용이 4배.
      final par = cableWithstand(
        sizeMm2: 95,
        insulation: Insulation.pvc70,
        ikA: 10000,
        tSec: 0.05,
        parallel: 2,
        letThroughA2s: 4.7e8,
      )!;
      expect(par.letThroughOk, isTrue);
      expect(
        cableWithstand(
          sizeMm2: 95,
          insulation: Insulation.pvc70,
          ikA: 10000,
          tSec: 0.05,
        )!.letThroughOk,
        isNull,
      );
    });

    test('잘못된 입력은 null', () {
      expect(
        cableWithstand(
          sizeMm2: 95,
          insulation: Insulation.pvc70,
          ikA: 0,
          tSec: 1,
        ),
        isNull,
      );
      expect(
        cableWithstand(
          sizeMm2: 95,
          insulation: Insulation.pvc70,
          ikA: 1000,
          tSec: -1,
        ),
        isNull,
      );
      expect(
        cableWithstand(
          sizeMm2: 95,
          insulation: Insulation.pvc70,
          ikA: 1000,
          tSec: 1,
          letThroughA2s: 0,
        ),
        isNull,
      );
    });
  });

  group('탭 화면', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> pumpTab(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: FieldViewTheme(child: ElecShortCircuitTab())),
        ),
      );
      await tester.pumpAndSettle();
    }

    // 목록은 화면 밖 칸을 만들지 않으므로 먼저 그 칸까지 내려 간다.
    Future<void> reveal(WidgetTester tester, Finder f) async {
      if (f.evaluate().isEmpty) {
        final scrollable = find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first;
        tester.state<ScrollableState>(scrollable).position.jumpTo(0);
        await tester.pump();
        await tester.scrollUntilVisible(
          f,
          300,
          scrollable: scrollable,
          maxScrolls: 200,
        );
      }
      await tester.ensureVisible(f);
      await tester.pump();
    }

    Future<void> enter(WidgetTester tester, String key, String text) async {
      final f = find.byKey(Key(key));
      await reveal(tester, f);
      await tester.enterText(f, text);
      await tester.pump();
    }

    Future<void> finish(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }

    String textOf(WidgetTester tester, String key) {
      final f = find.byKey(Key(key), skipOffstage: false);
      return tester
          .widgetList<Text>(
            find.descendant(
              of: f,
              matching: find.byType(Text),
              skipOffstage: false,
            ),
          )
          .map((t) => t.data ?? '')
          .join('\n');
    }

    testWidgets('빈 화면: 계산하지 않고 무엇을 넣을지 알린다', (tester) async {
      await pumpTab(tester);
      expect(find.byKey(const Key('ec_sc_result')), findsOneWidget);
      final t = textOf(tester, 'ec_sc_result');
      expect(t, contains('변압기 용량'));
      expect(t, contains('2차 전압'));
      expect(t, contains('%Z'));
      expect(find.byKey(const Key('ec_sc_min_result')), findsNothing);
      await reveal(tester, find.byKey(const Key('ec_sc_basis')));
      expect(find.text('근거 보기'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('예 A를 화면에 넣으면 Ik″ 최대와 비교값이 나온다', (tester) async {
      await pumpTab(tester);
      await enter(tester, 'ec_sc_kva', '1000');
      await enter(tester, 'ec_sc_volts', '380');
      await enter(tester, 'ec_sc_z', '5.5');
      final t = textOf(tester, 'ec_sc_result');
      expect(t, contains('30.04 kA'));
      expect(t, contains('27.62 kA'));
      expect(flat(t), contains(flat('c = 1.05')));
      expect(flat(t), contains(flat('= 84.96 kA (κ = 1.02 + 0.98·e^(−3R/X), R/X = 0)')));
      final sum = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('ec_sc_sum')),
          matching: find.byType(Text),
        ),
      );
      expect(sum.data, contains('30.04'));
      // 결과 상자가 길어져 아래 상자는 목록을 내려야 그려진다.
      await reveal(tester, find.byKey(const Key('ec_sc_min_result')));
      final min = textOf(tester, 'ec_sc_min_result');
      expect(min, contains('지락(1선) 단락은 포함하지 않음'));
      expect(textOf(tester, 'ec_sc_notes'), contains('무한 전원'));
      await finish(tester);
    });

    // 예 A(무한 전원, 케이블 없음): ZT = 5.5 ÷ 100 × 380² ÷ (1000 × 1000) = 7.94 mΩ, KT = 0.966.
    //  X = 7.942 × 0.96563 = 7.67 mΩ, R = 0, Z = 7.67 mΩ → Ik″ = 1.05 × 380 ÷ (√3 × 7.67 mΩ) = 30.04 kA.
    testWidgets('최대 단락 풀이가 ①~⑤ 단계 번호와 식·숫자로 나온다 (예 A)', (tester) async {
      await pumpTab(tester);
      await enter(tester, 'ec_sc_kva', '1000');
      await enter(tester, 'ec_sc_volts', '380');
      await enter(tester, 'ec_sc_z', '5.5');
      final t = textOf(tester, 'ec_sc_result');
      expect(t, contains('① 전원: 상위 계통 단락용량을 넣지 않아 무한 전원'));
      expect(flat(t), contains(flat('② 변압기: ZT = %Z ÷ 100 × U² ÷ S = 5.5 ÷ 100 × 380² ÷ (1000 × 1000) = 7.94 mΩ.')));
      expect(flat(t), contains(flat('KT = 0.95 × cmax ÷ (1 + 0.6 × xT) = 0.95 × 1.05 ÷ (1 + 0.6 × 0.055) = 0.966')));
      expect(t, contains('③ 케이블 구간 없음'));
      expect(flat(t), contains(flat('④ 합계: R = 0 + 0 + 0 = 0 mΩ, X = 0 + 7.67 + 0 = 7.67 mΩ.')));
      expect(flat(t), contains(flat('⑤ Ik″ = c × Un ÷ (√3 × Z) = 1.05 × 380 ÷ (√3 × 7.67 mΩ) = 30.04 kA.')));
      await finish(tester);
    });

    // 화면에서 다시 구한 임피던스가 계산 함수의 결과와 같은지: 부하손·상위 계통·케이블·전동기를 모두 넣는다.
    testWidgets('풀이의 kA가 계산 함수의 결과와 같다 (부하손·계통·케이블·전동기)', (tester) async {
      final calc = calcShortCircuit(
        const ScInput(
          kva: 1000,
          volts: 380,
          zPercent: 5.5,
          pcuKw: 10,
          upstreamMvaMax: 500,
          motorKw: 200,
          motorEffPf: 0.8,
          motorMultiple: 5,
          segments: [ScSegment(sizeMm2: 50, lengthM: 30, parallel: 2)],
        ),
      );
      // 화면은 끝의 0을 떼어 적는다(16.70 → 16.7).
      String ka(double a) => (a / 1000)
          .toStringAsFixed(2)
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');
      await pumpTab(tester);
      await enter(tester, 'ec_sc_kva', '1000');
      await enter(tester, 'ec_sc_volts', '380');
      await enter(tester, 'ec_sc_z', '5.5');
      await enter(tester, 'ec_sc_pcu', '10');
      await enter(tester, 'ec_sc_up_max', '500');
      await enter(tester, 'ec_sc_mkw', '200');
      await enter(tester, 'ec_sc_meff', '0.8');
      await enter(tester, 'ec_sc_mmult', '5');
      await reveal(tester, find.byKey(const Key('ec_sc_add')));
      await tester.tap(find.byKey(const Key('ec_sc_add')));
      await tester.pump();
      await enter(tester, 'ec_sc_seg_0_len', '30');
      await reveal(tester, find.byKey(const Key('ec_sc_seg_0_p2')));
      await tester.tap(find.byKey(const Key('ec_sc_seg_0_p2')));
      await tester.pump();
      final t = textOf(tester, 'ec_sc_result');
      expect(flat(t), contains(flat('① 전원: Zq = c × U² ÷ S″k = 1.05 × 380² ÷ (500 × 10⁶) = 0.303 mΩ.')));
      expect(flat(t), contains(flat('RT = 부하손 ÷ 용량 × U² ÷ S = 10 ÷ 1000 × 144.4 mΩ = 1.44 mΩ.')));
      expect(flat(t), contains(flat('구간 1 (50 mm², 30 m, 2가닥): R = 0.387 × 30 ÷ 1000 ÷ 2 = 5.8 mΩ')));
      expect(flat(t), contains(flat('⑤ Ik″ = c × Un ÷ (√3 × Z)')));
      expect(flat(t), contains(flat('= ${ka(calc.ikNetA)} kA(변압기·계통분).')));
      expect(flat(t), contains(flat('⑥ 전동기 기여: 정격전류 IrM')));
      expect(flat(t), contains(flat('= ${ka(calc.ikMotorA)} kA. 합계 Ik″ = ${ka(calc.ikNetA)} + ${ka(calc.ikMotorA)} = ${ka(calc.ikMaxA)} kA.')));
      expect(flat(t), contains(flat('= ${ka(calc.ipA)} kA (R/X =')));
      // 전동기 RM/XM 0.42: |ZM| = 380 ÷ (√3 × 5 × 379.84) = 115.52 mΩ → XM 106.51, RM 44.73 mΩ.
      expect(flat(t), contains(flat('RM/XM = 0.42(IEC 909 8.3.2.5 저압 전동기 묶음): XM = ZM ÷ √(1 + 0.42²) = 106.51 mΩ, RM = 0.42 × XM = 44.73 mΩ.')));
      expect(flat(t), contains(flat('저압 전동기 묶음 κM = 1.3)')));
      await reveal(tester, find.byKey(const Key('ec_sc_min_result')));
      final min = textOf(tester, 'ec_sc_min_result');
      // PVC(처음 값): θe 160°C → 1 + 0.004 × 140 = 1.56.
      expect(flat(min), contains(flat('케이블 저항(IEC 909 9.3.1 식 32): R = R20 × [1 + 0.004 × (θe − 20)] = R20 × [1 + 0.004 × (160 − 20)] = R20 × 1.56.')));
      expect(flat(min), contains(flat('PVC 단락 최종 온도 160°C(KEC 표 212.5-1)')));
      expect(flat(min), contains(flat('② 3상 최소 = c × Un ÷ (√3 × Z)')));
      expect(flat(min), contains(flat('= ${ka(calc.ikMin3A)} kA.')));
      expect(flat(min), contains(flat('③ 2상 최소 = 3상 × √3 ÷ 2 = ${ka(calc.ikMin3A)} × 0.866 = ${ka(calc.ikMin2A)} kA.')));
      await finish(tester);
    });

    testWidgets('케이블 열 견딤 풀이: ② 최소 굵기 ③ 허용 시간 ④ 허용 통과 에너지', (tester) async {
      await pumpTab(tester);
      await enter(tester, 'ec_sc_kva', '1000');
      await enter(tester, 'ec_sc_volts', '380');
      await enter(tester, 'ec_sc_z', '5.5');
      await reveal(tester, find.byKey(const Key('ec_sc_add')));
      await tester.tap(find.byKey(const Key('ec_sc_add')));
      await tester.pump();
      await enter(tester, 'ec_sc_seg_0_len', '50');
      await enter(tester, 'ec_sc_t', '1');
      await enter(tester, 'ec_sc_ik_manual', '10');
      await enter(tester, 'ec_sc_i2t', '5000000');
      final c = textOf(tester, 'ec_sc_cable_result');
      // 직접 입력 10 kA = 10000 A, PVC k = 115, 50 mm²: S = 10000 × √1 ÷ 115 = 87 mm², t = (115 × 50 ÷ 10000)² = 0.331초.
      expect(flat(c), contains(flat('② 필요한 최소 굵기 S = Ik × √t ÷ k = 10000 A × √1 ÷ 115 = 87 mm²')));
      expect(flat(c), contains(flat('③ 이 전류에서 허용 최대 시간 t = (k × S ÷ Ik)² = (115 × 50 ÷ 10000)² = 0.331초.')));
      // 허용 = 1² × 115² × 50² = 33,062,500 A²s. 5,000,000 이하라 통과.
      expect(flat(c), contains(flat('④ 허용 통과 에너지 = (병렬 수)² × k² × S² = 1² × 115² × 50² = 33062500 A²s.')));
      await finish(tester);
    });

    testWidgets('숫자가 아닌 글과 음수는 입력 확인으로 보인다', (tester) async {
      await pumpTab(tester);
      await enter(tester, 'ec_sc_kva', 'abc');
      await enter(tester, 'ec_sc_volts', '380');
      await enter(tester, 'ec_sc_z', '5.5');
      var t = textOf(tester, 'ec_sc_result');
      expect(t, contains('입력 확인'));
      expect(t, contains('변압기 용량: 숫자가 아닙니다.'));
      await enter(tester, 'ec_sc_kva', '-5');
      t = textOf(tester, 'ec_sc_result');
      expect(t, contains('입력 확인'));
      expect(t, contains('변압기 용량(kVA)은 0보다 커야 합니다.'));
      await finish(tester);
    });

    testWidgets('구간 길이가 비면 입력 확인, 차단용량과 열 견딤 판정', (tester) async {
      await pumpTab(tester);
      await enter(tester, 'ec_sc_kva', '1000');
      await enter(tester, 'ec_sc_volts', '380');
      await enter(tester, 'ec_sc_z', '5.5');
      await reveal(tester, find.byKey(const Key('ec_sc_add')));
      await tester.tap(find.byKey(const Key('ec_sc_add')));
      await tester.pump();
      expect(textOf(tester, 'ec_sc_result'), contains('구간 1: 편도 길이(m)를 넣으십시오'));
      await enter(tester, 'ec_sc_seg_0_len', '50');
      // 50mm² 50m: 고장점 값이 30.04kA보다 작아진다.
      final t = textOf(tester, 'ec_sc_result');
      expect(t, isNot(contains('입력 확인')));
      // 차단기 위치 기본은 고장점. 10kA는 불합격, 100kA는 합격.
      await enter(tester, 'ec_sc_rating', '10');
      expect(textOf(tester, 'ec_sc_breaker_result'), contains('불합격'));
      await enter(tester, 'ec_sc_rating', '100');
      expect(textOf(tester, 'ec_sc_breaker_result'), contains('합격'));
      expect(
        textOf(tester, 'ec_sc_breaker_result'),
        contains('투입(피크) 확인은 정격 투입용량을 넣을 때만 합니다.'),
      );
      // 열 견딤: 구간 시작점은 30.04kA, 50mm² PVC 1초 → 필요 261mm², 불합격.
      await enter(tester, 'ec_sc_t', '1');
      var c = textOf(tester, 'ec_sc_cable_result');
      expect(c, contains('불합격'));
      expect(c, contains('30.04 kA'));
      expect(c, contains('261'));
      // 0.05초, 통과 에너지 없음: 짧은 시간 경고.
      await enter(tester, 'ec_sc_t', '0.05');
      c = textOf(tester, 'ec_sc_cable_result');
      expect(c, contains('제조사 통과 에너지'));
      // 직접 입력 5kA, 1초: 필요 43.5mm² 이하라 합격.
      await enter(tester, 'ec_sc_t', '1');
      await enter(tester, 'ec_sc_ik_manual', '5');
      c = textOf(tester, 'ec_sc_cable_result');
      expect(c, contains('직접 입력값'));
      expect(c, contains('합격'));
      await finish(tester);
    });

    testWidgets('입력값을 저장 칸에 남기고 다시 열면 복원한다', (tester) async {
      await pumpTab(tester);
      await enter(tester, 'ec_sc_kva', '750');
      await enter(tester, 'ec_sc_z', '6');
      await reveal(tester, find.byKey(const Key('ec_sc_add')));
      await tester.tap(find.byKey(const Key('ec_sc_add')));
      await tester.pump();
      await enter(tester, 'ec_sc_seg_0_len', '25');
      await tester.pump(const Duration(milliseconds: 600));
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('elec_short_draft_v1');
      expect(raw, isNotNull);
      expect(raw, contains('"kva":"750"'));
      expect(raw, contains('"len":"25"'));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await pumpTab(tester);
      final kva = tester.widget<TextField>(find.byKey(const Key('ec_sc_kva')));
      expect(kva.controller!.text, '750');
      final len = tester.widget<TextField>(
        find.byKey(const Key('ec_sc_seg_0_len')),
      );
      expect(len.controller!.text, '25');
      await finish(tester);
    });

    testWidgets('근거 보기를 펴면 원문 대조한 것·못 본 것과 뺀 것이 있다', (tester) async {
      await pumpTab(tester);
      await reveal(tester, find.byKey(const Key('ec_sc_basis')));
      await tester.tap(find.text('근거 보기'));
      await tester.pumpAndSettle();
      expect(find.textContaining('원문 대조 전'), findsNothing);
      expect(find.textContaining('원문 대조함'), findsOneWidget);
      expect(find.textContaining('IS 13234:1992'), findsOneWidget);
      expect(find.textContaining('원문 못 봄(2016판 유료)'), findsOneWidget);
      expect(find.textContaining('식 (13)'), findsOneWidget);
      expect(find.textContaining('계산에서 뺀 것'), findsOneWidget);
      expect(find.textContaining('지락(1선) 단락'), findsWidgets);
      await finish(tester);
    });
  });
}
