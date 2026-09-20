import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/models/cutting_project_model.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_result_logic.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_result_view.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/screens/cutting_main_screen.dart';

// 세트 수를 바꿔도 1개 값은 그대로이고, 개수와 합계만 "1개 값 × 개수 = 합계"로 바뀐다.
void main() {
  group('줄 계산', () {
    test('세트 수를 바꿔도 1개 값은 같고 개수·합계만 바뀐다', () {
      final cuts = [600.0, 900.0, 600.0];
      for (final grouped in [false, true]) {
        final one = buildResultLines(cuts, 1, grouped: grouped);
        final three = buildResultLines(cuts, 3, grouped: grouped);
        expect(three.map((l) => l.cutMm), one.map((l) => l.cutMm));
        expect(three.map((l) => l.baseCount), one.map((l) => l.baseCount));
        for (var i = 0; i < one.length; i++) {
          expect(three[i].count, one[i].count * 3);
          expect(three[i].totalMm, one[i].totalMm * 3);
          expect(three[i].totalMm, three[i].cutMm * three[i].count);
        }
      }
    });

    test('개수 식: 묶은 줄은 구간 수 × 세트 수, 묶지 않은 줄은 1개 × 세트 수', () {
      final g = buildResultLines([600.0, 900.0, 600.0], 3, grouped: true);
      expect(g[0].countFormula, '구간 2개 × 3세트 = 6개');
      expect(g[1].countFormula, '구간 1개 × 3세트 = 3개');
      final u = buildResultLines([600.0], 3, grouped: false);
      expect(u.single.countFormula, '1개 × 3세트 = 3개');
    });

    test('세트가 1이면 식이 없다', () {
      expect(
        buildResultLines([600.0, 600.0], 1, grouped: true).single.countFormula,
        '',
      );
    });

    test('총합은 1세트 합계 × 세트 수', () {
      final one = summarizeResult(
        buildResultLines([600.0, 900.0], 1, grouped: true),
        {},
      );
      final four = summarizeResult(
        buildResultLines([600.0, 900.0], 4, grouped: true),
        {},
      );
      expect(four.totalMm, one.totalMm * 4);
      expect(four.totalPieces, one.totalPieces * 4);
    });
  });

  group('저장 확인 글', () {
    String m(int sets) => buildSaveConfirmMessage(
      baseMm: 1500 * sets.toDouble(),
      cutCount: 2,
      setMultiplier: sets,
      kerfLossMm: 0,
      orders: const [],
      notDoneLines: 0,
      anyDone: false,
      recordsToProject: false,
      canUndo: true,
    );

    test('세트가 여럿이면 1세트 길이 × 세트 수 = 합계, 1세트 길이는 늘 같다', () {
      for (final sets in [2, 3, 7]) {
        expect(
          m(sets).contains(
            '1세트 1500.0mm × $sets세트 = ${(1500 * sets).toStringAsFixed(1)}mm',
          ),
          true,
          reason: '$sets세트',
        );
      }
      expect(m(1).contains('총 1500.0mm입니다 (구간 2개).'), true);
    });
  });

  group('결과 목록 화면', () {
    Future<void> show(
      WidgetTester tester, {
      required List<ResultLine> lines,
      int sets = 1,
      double scale = 1.0,
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: CuttingResultView(
              lines: lines,
              summary: summarizeResult(lines, {}),
              orders: const [],
              done: const {},
              onToggle: (_) {},
              setMultiplier: sets,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    String textOf(WidgetTester tester, Key k) =>
        tester.widget<Text>(find.byKey(k)).data!;

    testWidgets('큰 글씨는 1개 값이고 세트 수를 바꿔도 그대로다(묶지 않은 줄)', (tester) async {
      for (final sets in [1, 3, 10]) {
        final lines = buildResultLines([600.0, 900.0], sets, grouped: false);
        await show(tester, lines: lines, sets: sets);
        expect(
          textOf(tester, Key('result_piece_${lines[0].key}')),
          '600.0 mm',
          reason: '$sets세트',
        );
        expect(textOf(tester, Key('result_piece_${lines[1].key}')), '900.0 mm');
        expect(textOf(tester, Key('result_count_${lines[0].key}')), '× $sets개');
        expect(
          textOf(tester, Key('result_line_total_${lines[0].key}')),
          '= ${(600.0 * sets).toStringAsFixed(1)} mm',
        );
        // 구간 이름은 작은 글씨로 내려간다.
        expect(find.text('PT1 → PT2'), findsOneWidget);
      }
    });

    testWidgets('묶은 줄도 1개 값은 그대로이고 개수 식이 나온다', (tester) async {
      final lines = buildResultLines([600.0, 900.0, 600.0], 3, grouped: true);
      await show(tester, lines: lines, sets: 3);
      expect(textOf(tester, Key('result_piece_${lines[0].key}')), '600.0 mm');
      expect(textOf(tester, Key('result_count_${lines[0].key}')), '× 6개');
      expect(
        textOf(tester, Key('result_line_total_${lines[0].key}')),
        '= 3600.0 mm',
      );
      expect(
        textOf(tester, Key('result_formula_${lines[0].key}')),
        '구간 2개 × 3세트 = 6개',
      );
    });

    testWidgets('총계 카드: 세트가 여럿이면 큰 숫자는 1세트 길이, 아래에 세트 수 곱한 합계', (tester) async {
      var lines = buildResultLines([600.0, 900.0], 1, grouped: true);
      await show(tester, lines: lines, sets: 1);
      expect(textOf(tester, const Key('result_total_mm')), '1500.0 mm');
      expect(find.byKey(const Key('result_set_mm')).evaluate(), isEmpty);

      for (final sets in [2, 5]) {
        lines = buildResultLines([600.0, 900.0], sets, grouped: true);
        await show(tester, lines: lines, sets: sets);
        expect(textOf(tester, const Key('result_set_mm')), '1세트 1500.0 mm');
        expect(
          textOf(tester, const Key('result_total_mm')),
          '× $sets세트 = ${(1500 * sets).toStringAsFixed(1)} mm',
        );
      }
    });

    testWidgets('글자를 크게 키우고 세트가 커도 넘치지 않는다', (tester) async {
      final lines = buildResultLines(
        [600.0, 900.0, 600.0, 123456.7],
        99,
        grouped: true,
      );
      await show(tester, lines: lines, sets: 99, scale: 1.6);
      expect(tester.takeException(), isNull);
      final u = buildResultLines([600.0, 900.0], 99, grouped: false);
      await show(tester, lines: u, sets: 99, scale: 1.6);
      expect(tester.takeException(), isNull);
    });
  });

  group('결과 탭 화면', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Finder lengthField(int i) => find
        .byWidgetPredicate(
          (w) =>
              w is TextField &&
              (w.decoration?.labelText ?? '').startsWith('전체 길이'),
        )
        .at(i);

    testWidgets('세트 수를 올리면 1개 값은 그대로, 개수·합계만 바뀐다', (tester) async {
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CuttingMainScreen(
              project: CuttingProject(
                id: 'p1',
                name: '루마',
                createdAt: DateTime(2026, 9, 20),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('포인트 추가'));
      await tester.pump();
      await tester.enterText(lengthField(0), '600');
      await tester.enterText(lengthField(1), '900');
      await tester.pump();
      await tester.tap(find.text('결과'));
      await tester.pumpAndSettle();
      expect(find.text('600.0 mm'), findsOneWidget);
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byKey(const Key('set_plus')));
        await tester.pump();
      }
      // 3세트: 1개 값 두 줄은 그대로
      expect(find.text('600.0 mm'), findsOneWidget);
      expect(find.text('900.0 mm'), findsOneWidget);
      expect(find.text('× 3개'), findsNWidgets(2));
      expect(find.text('= 1800.0 mm'), findsOneWidget);
      expect(find.text('= 2700.0 mm'), findsOneWidget);
      expect(find.text('1세트 1500.0 mm'), findsOneWidget);
      expect(find.text('× 3세트 = 4500.0 mm'), findsOneWidget);
    });
  });
}
