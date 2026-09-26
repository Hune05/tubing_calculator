// 전선관 탭 2차(2026-09-26): 케이블 2본 이상 1/3 규칙, HIV·F-GV 외경, 경질 비닐 100, 줄별 단면적, 최소 전선관 눌러 바꾸기.
// 값의 출처는 docs/전기계산기_근거.md "전선관 굵기 탭".
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/electrical/conduit_tables.dart';

import 'electric_calculator_awg_conduit_test.dart'
    show
        pumpPage,
        pumpNarrow,
        openTab,
        tapKey,
        type,
        pickDropdown,
        resultOf,
        chipOn;

/// 줄 단면적 글(키가 Text 자체에 있다).
String areaText(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).data ?? '';

void main() {
  group('HIV·F-GV 외경', () {
    test(
      'HIV 300/500V(60227 KS IEC 07): 1.5sq 3.2, 2.5sq 3.9만 있다(KC 60227-3 표 9 = LS)',
      () {
        expect(cableSizes(CableKind.hiv), [1.5, 2.5]);
        expect(cableOd(CableKind.hiv, 1.5), 3.2);
        expect(cableOd(CableKind.hiv, 2.5), 3.9);
        expect(cableOd(CableKind.hiv, 4), isNull);
        expect(isInsulatedWire(CableKind.hiv), isTrue);
        expect(cableKindLabel(CableKind.hiv), 'HIV 300/500V');
      },
    );

    test('F-GV 0.6/1kV 접지선: LS·넥상스 표(1.5 6.5 … 16 10 … 300 30)', () {
      expect(cableSizes(CableKind.fgv).length, 16);
      expect(cableOd(CableKind.fgv, 1.5), 6.5);
      expect(cableOd(CableKind.fgv, 6), 8.5);
      expect(cableOd(CableKind.fgv, 16), 10.0);
      expect(cableOd(CableKind.fgv, 185), 25.0);
      expect(cableOd(CableKind.fgv, 300), 30.0);
      expect(isInsulatedWire(CableKind.fgv), isTrue);
      expect(cableKindLabel(CableKind.fgv), 'F-GV 접지선');
    });

    test('같은 굵기 HIV만 넣으면 48% 스위치를 쓸 수 있다', () {
      const w = [ConduitWire(CableKind.hiv, 2.5, 6)];
      expect(easyPullApplies(w), isTrue);
      expect(fillLimit(FillRule.naesun, w, easyPull: true).pct, 48);
    });
  });

  group('케이블 여러 본', () {
    test('케이블 3본은 1/3, 외경 합 참고 줄은 2본일 때만', () {
      const w = [
        ConduitWire(CableKind.fcv4, 16, 2),
        ConduitWire(CableKind.fcv1, 10, 1),
      ];
      final l = fillLimit(FillRule.naesun, w);
      expect(l.pct, closeTo(100 / 3, 1e-9));
      expect(l.reason, contains('케이블 3본'));
      expect(cablePairSumId(w), isNull);
      expect(l.notes, isEmpty);
    });

    test('서로 다른 케이블 2본: 1.5 × (22 + 9.4) = 47.1mm', () {
      const w = [
        ConduitWire(CableKind.fcv4, 16, 1),
        ConduitWire(CableKind.fcv1, 10, 1),
      ];
      expect(cablePairSumId(w), closeTo(47.1, 1e-9));
      expect(fillLimit(FillRule.naesun, w).notes.join(), contains('47.1mm'));
    });

    test('케이블과 절연전선(F-GV)을 같이 넣으면 32%', () {
      const w = [
        ConduitWire(CableKind.fcv4, 16, 1),
        ConduitWire(CableKind.fgv, 16, 1),
      ];
      final l = fillLimit(FillRule.naesun, w);
      expect(l.pct, 32);
      expect(l.reason, contains('케이블과 절연전선'));
      expect(cablePairSumId(w), isNull);
      expect(easyPullApplies(w), isFalse);
    });

    test('F-CV 3심 4sq 2본: 1/3이면 후강 36, NEC 31%도 후강 36', () {
      const w = [ConduitWire(CableKind.fcv3, 4, 2)];
      // 2 × π/4 × 14² = 307.9mm² → 내 단면적 923.6mm² 이상 → 내경 34.3mm 이상
      expect(minConduit(ConduitKind.thick, w, FillRule.naesun)!.size, 36);
      expect(minConduit(ConduitKind.thick, w, FillRule.nec)!.size, 36);
    });

    test('NEC는 그대로: 케이블 2본 31%, 3본 40%', () {
      expect(
        fillLimit(FillRule.nec, const [ConduitWire(CableKind.fcv3, 4, 2)]).pct,
        31,
      );
      expect(
        fillLimit(FillRule.nec, const [ConduitWire(CableKind.fcv3, 4, 3)]).pct,
        40,
      );
    });

    test('경질 비닐 100: F-CV 4심 70sq 2본(외경 36)은 경질 비닐 100, 후강 92', () {
      const w = [ConduitWire(CableKind.fcv4, 70, 2)];
      // 2 × π/4 × 36² = 2035.8mm² ÷ (1/3) = 6107mm² → 내경 88.2mm 이상
      expect(minConduit(ConduitKind.pvc, w, FillRule.naesun)!.size, 100);
      expect(minConduit(ConduitKind.thick, w, FillRule.naesun)!.size, 92);
    });
  });

  test('줄별 단면적 합이 전체와 같다', () {
    const w = [
      ConduitWire(CableKind.hfix, 2.5, 3),
      ConduitWire(CableKind.fgv, 4, 1),
    ];
    expect(wireArea(w[0]), closeTo(3 * math.pi / 4 * 4.1 * 4.1, 1e-9));
    expect(wireArea(w[1]), closeTo(math.pi / 4 * 8 * 8, 1e-9));
    expect(wiresArea(w), closeTo(wireArea(w[0]) + wireArea(w[1]), 1e-9));
  });

  group('화면', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('줄마다 단면적과 합에서의 비율이 보인다', (tester) async {
      await pumpPage(tester);
      await openTab(tester, 'ec_tab_conduit');
      expect(
        areaText(tester, const Key('ec_cd_area_0')),
        '단면적 39.6 mm² (합의 100%)',
      );
      await tapKey(tester, 'ec_cd_add');
      await pickDropdown(tester, 'ec_cd_kind_1', 'F-GV 접지선');
      await tester.pumpAndSettle();
      // 39.6 + π/4 × 7² = 38.5 → 합 78.1, 첫 줄 51%, 둘째 줄 49%
      expect(areaText(tester, const Key('ec_cd_area_1')), contains('38.5 mm²'));
      expect(areaText(tester, const Key('ec_cd_area_0')), contains('합의 51%'));
      await type(tester, 'ec_cd_n_1', '');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ec_cd_area_1')), findsNothing);
    });

    testWidgets('최소 전선관을 누르면 그 종류·굵기로 바뀐다', (tester) async {
      await pumpPage(tester);
      await openTab(tester, 'ec_tab_conduit');
      expect(chipOn(tester, 'ec_cd_min_thick'), isFalse); // 기본은 후강 22, 최소는 16
      await tapKey(tester, 'ec_cd_min_thin');
      expect(chipOn(tester, 'ec_cd_type_thin'), isTrue);
      expect(chipOn(tester, 'ec_cd_min_thin'), isTrue);
      expect(
        await resultOf(tester, 'ec_cd_result'),
        contains('박강 19 (내경 15.9mm)'),
      );
      await tapKey(tester, 'ec_cd_min_thick');
      expect(
        await resultOf(tester, 'ec_cd_result'),
        contains('후강 16 (내경 16.4mm)'),
      );
    });

    testWidgets('케이블 2본은 1/3 한도와 외경 합 참고가 결과에 보인다', (tester) async {
      await pumpPage(tester);
      await openTab(tester, 'ec_tab_conduit');
      await pickDropdown(tester, 'ec_cd_kind_0', 'F-CV 3심');
      await pickDropdown(tester, 'ec_cd_size_0', '4sq (외경 14)');
      await type(tester, 'ec_cd_n_0', '2');
      await tester.pumpAndSettle();
      final r = await resultOf(tester, 'ec_cd_result');
      expect(r, contains('한도 33.3%'));
      expect(r, contains('1/3'));
      expect(r, contains('관 내경 42.0mm 이상'));
      expect(await resultOf(tester, 'ec_cd_min'), contains('후강 36 · '));
    });

    testWidgets('HIV를 고르면 1.5·2.5sq만 나온다, 표에 없는 관은 한 줄로 알린다', (tester) async {
      await pumpPage(tester);
      await openTab(tester, 'ec_tab_conduit');
      await pickDropdown(tester, 'ec_cd_kind_0', 'HIV 300/500V');
      await tapKey(tester, 'ec_cd_size_0');
      expect(find.text('1.5sq (외경 3.2)'), findsWidgets);
      expect(find.text('2.5sq (외경 3.9)'), findsWidgets);
      expect(find.text('4sq (외경 4.7)'), findsNothing);
      await tester.tap(find.text('2.5sq (외경 3.9)').last);
      await tester.pumpAndSettle();
      await pickDropdown(tester, 'ec_cd_kind_0', 'F-CV 4심');
      await pickDropdown(tester, 'ec_cd_size_0', '300sq (외경 70)');
      await type(tester, 'ec_cd_n_0', '4');
      await tester.pumpAndSettle();
      expect(
        await resultOf(tester, 'ec_cd_min'),
        contains('표 안에 맞는 규격이 없습니다: 후강, 박강'),
      );
    });

    testWidgets('좁은 폰·큰 글씨에서 최소 전선관·줄 단면적이 넘치지 않는다', (tester) async {
      await pumpNarrow(tester);
      await openTab(tester, 'ec_tab_conduit');
      await tapKey(tester, 'ec_cd_add');
      await pickDropdown(tester, 'ec_cd_kind_1', 'F-GV 접지선');
      await type(tester, 'ec_cd_n_1', '12');
      await tester.pumpAndSettle();
      await resultOf(tester, 'ec_cd_min');
      expect(tester.takeException(), isNull);
    });
  });
}
