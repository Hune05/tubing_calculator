// 전동 벤딩 계산기: 장비 목록(MS-BTB 슈 반경), 엔진 그대로 부른 마킹·자를 길이, 넣을 각도(스프링백),
// 클램프·마지막 다리·최대 각 경고, 시험 굽힘 스프링백 환산, 금형 값 저장, 화면.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/electric_bender/electric_bend_plan.dart';
import 'package:tubing_calculator/src/presentation/electric_bender/electric_bender_page.dart';
import 'package:tubing_calculator/src/presentation/electric_bender/electric_machines.dart';

Tooling btb(String id) =>
    machineById(MachineId.msBtb).tooling.firstWhere((t) => t.id == 'btb_$id');

void main() {
  group('장비 목록', () {
    test('MS-BTB 슈 반경은 매뉴얼 값(1/2" 36·56, 3/4" 56, 1" 82, 1-1/4" 112)', () {
      expect(btb('i8').radius, 36);
      expect(btb('i8_56').radius, 56);
      expect(btb('i12').radius, 56);
      expect(btb('i16').radius, 82);
      expect(btb('i20').radius, 112);
      expect(btb('m25').radius, 82);
      expect(btb('i12').radiusSource, contains('MS-13-145'));
      // 매뉴얼 표를 옮기지 않았으므로 게인·클램프는 비어 있다
      expect(btb('i12').gain90, 0);
      expect(btb('i12').clampLen, 0);
    });

    test('TB20D는 금형이 비어 있고 최대 각을 모른다', () {
      final m = machineById(MachineId.tb20d);
      expect(m.tooling, isEmpty);
      expect(m.maxAngle, isNull);
      expect(m.manualFeed, isTrue);
    });
  });

  group('계산(엔진 그대로)', () {
    final m = machineById(MachineId.msBtb);

    test('3/4" R56 한 번 90°: 마킹 = 300 − 56, 자를 길이 = 다리 합 − 이론 게인', () {
      final p = planElectricBends(
        tooling: btb('i12'),
        machine: m,
        bends: [
          {'length': 300, 'angle': 90, 'rotation': 90},
        ],
        tail: 200,
      );
      expect(p.error, isNull);
      expect(p.rows.single.mark, closeTo(244, 1e-9));
      expect(p.pureCut, closeTo(500 - 0.4292 * 56, 0.05));
      expect(p.afterLast, closeTo(144, 1e-6));
      expect(p.rows.single.setAngle, 90);
    });

    test('실측 게인 26이면 자를 길이 474, 톱날 손실은 자를 길이에만', () {
      final p = planElectricBends(
        tooling: btb('i12').copyWith(gain90: 26),
        machine: m,
        bends: [
          {'length': 300, 'angle': 90, 'rotation': 90},
        ],
        tail: 200,
        kerf: 2,
      );
      expect(p.pureCut, closeTo(474, 1e-6));
      expect(p.totalCut, closeTo(476, 1e-6));
      expect(p.rows.single.mark, closeTo(244, 1e-9)); // 마킹은 게인과 상관없음
    });

    test('스프링백 90°에 4°면 90°는 94°, 45°는 47°', () {
      final p = planElectricBends(
        tooling: btb('i12').copyWith(springback90: 4),
        machine: m,
        bends: [
          {'length': 300, 'angle': 90, 'rotation': 90},
          {'length': 400, 'angle': 45, 'rotation': 0},
        ],
        tail: 200,
      );
      expect(p.rows[0].setAngle, closeTo(94, 1e-9));
      expect(p.rows[1].setAngle, closeTo(47, 1e-9));
      expect(p.rows[1].springback, closeTo(2, 1e-9));
    });

    test('두 벤드 사이 곧은 부분 = 400 − 셋백 두 개', () {
      final p = planElectricBends(
        tooling: btb('i12'),
        machine: m,
        bends: [
          {'length': 300, 'angle': 90, 'rotation': 90},
          {'length': 400, 'angle': 90, 'rotation': 0},
        ],
        tail: 200,
      );
      expect(p.rows[0].straight, closeTo(244, 1e-6));
      expect(p.rows[1].straight, closeTo(400 - 56 - 56, 1e-6));
    });

    test('클램프·마지막 다리·최대 각 경고', () {
      final p = planElectricBends(
        tooling: btb(
          'i12',
        ).copyWith(clampLen: 250, lastLegMin: 157, springback90: 10),
        machine: m,
        bends: [
          {'length': 1000, 'angle': 170, 'rotation': 90},
        ],
        tail: 1000,
      );
      final w = p.warnings.join('\n');
      // 170° + 스프링백 18.9° = 188.9° > 180°
      expect(w, contains('최대 180°를 넘습니다'));
      final q = planElectricBends(
        tooling: btb('i12').copyWith(clampLen: 250, lastLegMin: 157),
        machine: m,
        bends: [
          {'length': 300, 'angle': 90, 'rotation': 90},
        ],
        tail: 200,
      );
      final w2 = q.warnings.join('\n');
      expect(w2, contains('여유장 6mm')); // 250 − 244
      expect(w2, contains('마지막 다리 144mm')); // 200 − 56
    });

    test('엔진이 못 하는 각(180°)은 계산할 수 없다고 알린다', () {
      final p = planElectricBends(
        tooling: btb('i12'),
        machine: m,
        bends: [
          {'length': 300, 'angle': 180, 'rotation': 90},
        ],
      );
      expect(p.error, isNotNull);
    });

    test('시험 굽힘: 90을 넣어 86이 나오면 90° 기준 스프링백 4.19°', () {
      expect(
        springback90FromTrial(set: 90, got: 86),
        closeTo(4 * 90 / 86, 1e-9),
      );
      expect(springback90FromTrial(set: 86, got: 90), 0);
    });
  });

  group('금형 값 저장', () {
    test('내장 금형의 실측 값과 사용자가 더한 금형이 되살아난다', () {
      final s = ElectricBenderStore();
      s.put(btb('i12').copyWith(gain90: 26, gainSource: '시험 굽힘'));
      s.machine = MachineId.tb20d;
      s.put(
        const Tooling(
          id: 'user_1',
          label: '1/2" · R35',
          odMm: 12.7,
          radius: 35,
        ),
      );
      final r = ElectricBenderStore()..applyJson(s.toJsonString());
      expect(r.machine, MachineId.tb20d);
      expect(r.toolingOf(MachineId.tb20d).single.radius, 35);
      final t = r
          .toolingOf(MachineId.msBtb)
          .firstWhere((x) => x.id == 'btb_i12');
      expect(t.gain90, 26);
      expect(t.radius, 56); // 반경은 목록 값 그대로
      r.removeCustom('user_1');
      expect(r.toolingOf(MachineId.tb20d), isEmpty);
    });

    test('깨진 저장 값은 무시한다', () {
      final r = ElectricBenderStore()
        ..applyJson('{"machine":"x","custom":{"tb20d":[{"id":1}]}}');
      expect(r.machine, MachineId.msBtb);
      expect(r.toolingOf(MachineId.tb20d), isEmpty);
    });
  });

  group('화면', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> pump(
      WidgetTester tester, {
      Size size = const Size(390, 3000),
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
          home: const ElectricBenderPage(),
        ),
      );
      await tester.pumpAndSettle();
    }

    String textIn(WidgetTester tester, Key key) => tester
        .widgetList<Text>(
          find.descendant(of: find.byKey(key), matching: find.byType(Text)),
        )
        .map((t) => t.data ?? '')
        .join('\n');

    testWidgets('MS-BTB 1/4" R36 기본, 300·90° + 마지막 다리 200 → 마킹 264', (
      tester,
    ) async {
      await pump(tester);
      expect(find.byKey(const Key('eb_tooling_card')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('eb_len_0')), '300');
      await tester.enterText(find.byKey(const Key('eb_ang_0')), '90');
      await tester.enterText(find.byKey(const Key('eb_tail')), '200');
      await tester.pump();
      expect(textIn(tester, const Key('eb_bend_1')), contains('관 끝에서 264mm'));
      expect(textIn(tester, const Key('eb_result')), contains('mm'));
    });

    testWidgets('TB20D는 금형이 없다고 알리고, 금형을 더하면 계산한다', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('eb_machine_tb20d')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('eb_no_tooling')), findsOneWidget);
      await tester.tap(find.byKey(const Key('eb_addtool')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('eb_e_label')), '1/2 R35');
      await tester.enterText(find.byKey(const Key('eb_e_od')), '12.7');
      await tester.enterText(find.byKey(const Key('eb_e_r')), '35');
      await tester.tap(find.byKey(const Key('eb_e_save')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('eb_no_tooling')), findsNothing);
      await tester.enterText(find.byKey(const Key('eb_len_0')), '300');
      await tester.enterText(find.byKey(const Key('eb_ang_0')), '90');
      await tester.pump();
      final b = textIn(tester, const Key('eb_bend_1'));
      expect(b, contains('관 끝에서 265mm'));
      expect(b, contains('손 이송')); // 이송·회전을 손으로 하는 장비
    });

    testWidgets('시험 굽힘 창: 게인·스프링백을 구해 금형에 저장', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('eb_trial')));
      await tester.pumpAndSettle();
      // R36 90°: 다리 200+200, 자른 길이 380 → 게인 20
      await tester.enterText(find.byKey(const Key('eb_t_cut')), '380');
      await tester.enterText(find.byKey(const Key('eb_t_a')), '200');
      await tester.enterText(find.byKey(const Key('eb_t_b')), '200');
      await tester.enterText(find.byKey(const Key('eb_t_got')), '86');
      await tester.pump();
      expect(textIn(tester, const Key('eb_t_result')), contains('스프링백'));
      await tester.tap(find.byKey(const Key('eb_t_save')));
      await tester.pumpAndSettle();
      final card = textIn(tester, const Key('eb_tooling_card'));
      expect(card, contains('시험 굽힘'));
    });

    testWidgets('좁은 폰(344)·글씨 1.3배에서 넘치지 않는다', (tester) async {
      await pump(tester, size: const Size(344, 3600), scale: 1.3);
      await tester.enterText(find.byKey(const Key('eb_len_0')), '12345.6');
      await tester.enterText(find.byKey(const Key('eb_ang_0')), '135');
      await tester.tap(find.byKey(const Key('eb_add')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('eb_len_1')), '500');
      await tester.enterText(find.byKey(const Key('eb_ang_1')), '45');
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
