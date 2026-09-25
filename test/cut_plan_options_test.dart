// 재단 계획: 조각 이름표, 끝 다듬기, 남길 잔재 최소 길이, 가진 본수, CSV(점검 37번).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_leftovers.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_optimizer.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_plan_rows.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_plan_settings.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/widgets/cutting_optimization_sheet.dart';

void main() {
  group('셈', () {
    test('끝 다듬기만큼 짧은 원자재로 배치하고, 남는 길이에서도 뺀다', () {
      final plain = optimizeCutting(pieces: [3000, 2980], stockLength: 6000);
      expect(plain.barCount, 1);
      final trimmed = optimizeCutting(
        pieces: [3000, 2980],
        stockLength: 6000,
        endTrim: 50,
      );
      expect(trimmed.barCount, 2); // 5980 > 5950
      final one = optimizeCutting(
        pieces: [1000],
        stockLength: 6000,
        endTrim: 50,
      );
      expect(one.bars.single.stockLength, 6000);
      expect(one.bars.single.remainderWithKerf(0), 4950);
      // 섞어 쓰기에서도
      final mixed = optimizeCuttingMixed(
        pieces: [2980],
        stockLengths: [3000, 6000],
        endTrim: 50,
      );
      expect(mixed.bars.single.stockLength, 6000); // 3000은 2980+50이 안 들어감
    });

    test('남길 잔재 최소 길이', () {
      final r = optimizeCutting(pieces: [5800], stockLength: 6000);
      expect(r.keepableScraps(), isEmpty); // 기본 300
      expect(r.keepableScraps(minLength: 150), [200]);
    });

    test('이름표는 같은 길이끼리 하나씩, 표·CSV에 붙는다', () {
      final pieces = [1200.0, 800.0, 1200.0];
      final labels = ['PT1→PT2', 'PT2→PT3', 'PT3→PT4'];
      final r = optimizeCutting(pieces: pieces, stockLength: 6000);
      final l = labelsForBars(r.bars, pieces, labels);
      expect([...l.single]..sort(), ['PT1→PT2', 'PT2→PT3', 'PT3→PT4']);
      final row = planRows(r, labels: l).single;
      expect(row[1], contains('PT2→PT3 800'));
      final csv = planCsv({'튜브 1/2"': r}, labels: {'튜브 1/2"': l});
      expect(csv.startsWith('﻿'), isTrue); // 엑셀 한글
      expect(csv, contains('PT1→PT2'));
      expect(csv, contains('튜브 1/2"'));
    });

    test('가진 본수보다 더 필요하면 알린다', () {
      expect(ownedShortage({'A': 3, 'B': 1}, {'A': 2, 'B': 5}), [
        'A: 3본 필요 · 가진 2본 → 1본 모자람',
      ]);
      expect(ownedShortage({'A': 3}, {}), isEmpty);
    });
  });

  testWidgets('창: 이름표가 보이고, 가진 본수가 모자라면 알리고, 끝 다듬기가 본수에 반영된다', (tester) async {
    leftoverStore = PrefsLeftoverStore();
    SharedPreferences.setMockInitialValues({
      kCutOwnedBarsKey: jsonEncode({'앵글': 1}),
      kCutEndTrimKey: 50.0,
    });
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showCuttingOptimizationSheet(
                context,
                groupedPieces: {
                  '앵글': [3000, 2980],
                },
                pieceLabels: {
                  '앵글': ['기둥', '보'],
                },
                initialStockLength: 6000,
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    // 창의 배치 목록(글 칸 안의 스크롤은 빼고).
    Finder list() => find
        .descendant(
          of: find.byType(ListView).last,
          matching: find.byType(Scrollable),
        )
        .first;
    // 끝 다듬기 50 → 두 본(3000+2980 > 5950), 가진 1본보다 모자람
    expect(find.text('앵글: 2본 필요 · 가진 1본 → 1본 모자람'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('기둥 3000mm'),
      200,
      scrollable: list(),
    );
    await tester.scrollUntilVisible(
      find.textContaining('보 2980mm'),
      200,
      scrollable: list(),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('plan_csv')),
      300,
      scrollable: list(),
    );
    expect(find.byKey(const Key('plan_settings_card')), findsOneWidget);
  });
}
