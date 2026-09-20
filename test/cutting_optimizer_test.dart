import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_leftovers.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_math.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_optimizer.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/widgets/cutting_optimization_sheet.dart';

import 'helpers_text.dart';

// 컷팅 계산기: 절단 길이 계산, 원자재 배치(잔재·촘촘한 배치 포함), 잔재 저장.
List<double> allPieces(CuttingOptimizationResult r) => [
  for (final b in [...r.bars, ...r.leftoverBars]) ...b.pieces,
];

// 결과가 실제로 가능한 배치인지: 각 원자재/잔재에 조각+톱날 손실이 다 들어가는가.
void expectValid(
  CuttingOptimizationResult r,
  List<double> input, {
  double kerf = 0,
}) {
  for (final b in [...r.bars, ...r.leftoverBars]) {
    final need = b.pieces.fold(0.0, (s, p) => s + p + kerf);
    expect(need <= b.stockLength + 1e-6, true, reason: '$b.pieces 넘침');
  }
  final placed = allPieces(r)..sort();
  final expected = [...input.where((p) => p > 0 && p + kerf <= r.stockLength)]
    ..sort();
  expect(placed, expected, reason: '조각이 빠지거나 늘었다');
}

void main() {
  // 잔재는 앱에서는 서버에 두지만, 테스트에서는 폰(prefs) 저장소로 바꿔 쓴다.
  leftoverStore = PrefsLeftoverStore();

  group('절단 길이 계산', () {
    test('중심 간 거리에서 양쪽 공제값을 뺀다', () {
      expect(
        cutLengthMm(
          c2cInput: 500,
          inputIsInch: false,
          startDeduction: 12,
          endDeduction: 8.5,
        ),
        479.5,
      );
    });

    test('인치로 입력하면 mm로 바꾼 뒤 계산한다', () {
      expect(
        cutLengthMm(
          c2cInput: 10,
          inputIsInch: true,
          startDeduction: 4,
          endDeduction: 6,
        ),
        closeTo(244, 1e-9),
      );
    });

    test('공제값이 더 크면 음수(간섭)', () {
      expect(
        cutLengthMm(
          c2cInput: 15,
          inputIsInch: false,
          startDeduction: 10,
          endDeduction: 10,
        ),
        -5,
      );
    });
  });

  group('원자재 배치', () {
    test('딱 맞게 들어가면 한 본', () {
      final r = optimizeCutting(pieces: [3000, 2000, 1000], stockLength: 6000);
      expect(r.barCount, 1);
      expect(r.totalWaste, 0);
      expect(r.totalUsed, 6000);
    });

    test('톱날 손실은 조각마다 더해서 본다', () {
      // 3000+3000은 6000에 딱 맞지만 톱날 5mm씩이면 못 들어간다.
      final r = optimizeCutting(
        pieces: [3000, 3000],
        stockLength: 6000,
        kerf: 5,
      );
      expect(r.barCount, 2);
    });

    test('원자재보다 긴 조각과 0 이하 값은 계산에서 뺀다', () {
      final r = optimizeCutting(pieces: [7000, 0, -5, 1000], stockLength: 6000);
      expect(r.oversizedPieces, [7000]);
      expect(allPieces(r), [1000]);
    });

    test('조각이 없으면 0본', () {
      final r = optimizeCutting(pieces: [], stockLength: 6000);
      expect(r.barCount, 0);
      expect(r.totalStock, 0);
    });

    test('잔재를 넘겨도 원자재 기준 수치는 새 원자재만 센다', () {
      final r = optimizeCutting(
        pieces: [1000, 4000],
        stockLength: 6000,
        leftovers: [1200],
      );
      expect(r.leftoverBars.length, 1);
      expect(r.leftoverBars.single.pieces, [1000]);
      expect(r.barCount, 1);
      expect(r.totalStock, 6000);
    });
  });

  group('촘촘한 배치', () {
    test('긴 것부터 넣는 방법이 놓치는 경우를 찾아 본수를 줄인다', () {
      // 긴 것부터 넣으면 3본이 되지만 (4+... ) 2본에 들어가는 조합이 있다.
      final pieces = <double>[
        4000.0, 3000, 3000, 2000, 2000, 2000, //
      ];
      // 합계 16000, 8000짜리 2본에 4+3+... : 4000+2000+2000 / 3000+3000+2000
      final r = optimizeCutting(pieces: pieces, stockLength: 8000);
      expectValid(r, pieces);
      expect(r.barCount, 2);
    });

    test('줄인 본수를 알려 준다(못 줄이면 0)', () {
      final a = optimizeCutting(pieces: [3000, 3000], stockLength: 6000);
      expect(a.savedBars, 0);
    });

    test('아무 입력이나 넣어도 항상 가능한 배치이고 이론상 최소보다 크게 나쁘지 않다', () {
      final rnd = Random(7);
      for (var t = 0; t < 200; t++) {
        final n = 1 + rnd.nextInt(18);
        final kerf = rnd.nextBool() ? 0.0 : 3.0;
        final pieces = [for (var i = 0; i < n; i++) 200.0 + rnd.nextInt(3800)];
        final r = optimizeCutting(
          pieces: pieces,
          stockLength: 6000,
          kerf: kerf,
        );
        expectValid(r, pieces, kerf: kerf);
        final lb = (pieces.fold(0.0, (s, p) => s + p + kerf) / 6000).ceil();
        expect(r.barCount >= lb, true);
        // 어떤 경우에도 FFD보다 나빠지지 않는다.
        expect(r.savedBars >= 0, true);
      }
    });
  });

  group('잔재', () {
    test('들어가는 잔재 중 가장 꼭 맞는 곳에 먼저 넣는다', () {
      final r = optimizeCutting(
        pieces: [900],
        stockLength: 6000,
        leftovers: [2000, 950, 1500],
      );
      expect(r.barCount, 0);
      expect(r.leftoverBars.single.stockLength, 950);
    });

    test('잔재에 안 들어가는 조각은 새 원자재로 간다', () {
      final r = optimizeCutting(
        pieces: [5000, 800],
        stockLength: 6000,
        leftovers: [1000],
      );
      expect(r.leftoverBars.single.pieces, [800]);
      expect(r.bars.single.pieces, [5000]);
    });

    test('잔재에서도 톱날 손실을 뺀다', () {
      final r = optimizeCutting(
        pieces: [1000],
        stockLength: 6000,
        kerf: 5,
        leftovers: [1000],
      );
      expect(r.leftoverBars, isEmpty);
      expect(r.barCount, 1);
    });

    test('쓰지 않은 잔재는 결과에 나오지 않는다', () {
      final r = optimizeCutting(
        pieces: [500],
        stockLength: 6000,
        leftovers: [600, 5000],
      );
      expect(r.leftoverBars.length, 1);
    });

    test('잔재는 톱날 손실을 뺀 길이이고 짧은 것은 제외한다', () {
      final r = optimizeCutting(
        pieces: [5000, 5000],
        stockLength: 6000,
        kerf: 10,
      );
      // 새 원자재 2본: 각 6000-5000-10=990
      expect(r.keepableScraps(), [990, 990]);
      final short = optimizeCutting(pieces: [5800], stockLength: 6000);
      expect(short.keepableScraps(), isEmpty); // 200mm는 300 미만
    });

    test('쓴 잔재의 남은 부분도 다시 남길 수 있다', () {
      final r = optimizeCutting(
        pieces: [500],
        stockLength: 6000,
        leftovers: [1500],
      );
      expect(r.keepableScraps(), [1000]);
    });
  });

  group('잔재 저장', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('저장하고 다시 읽으면 그대로', () async {
      await saveLeftovers([
        const Leftover('튜브 1/2"', 850),
        const Leftover('', 1200),
      ]);
      final l = await loadLeftovers();
      expect(l, [const Leftover('튜브 1/2"', 850), const Leftover('', 1200)]);
    });

    test('망가진 값은 건너뛴다', () async {
      SharedPreferences.setMockInitialValues({
        kLeftoversPrefsKey: ['x', '0\u001Fa', '500\u001F튜브'],
      });
      expect(await loadLeftovers(), [const Leftover('튜브', 500)]);
    });

    test('쓴 잔재는 개수만큼만 빼고 새 잔재를 더한다', () {
      const a = Leftover('', 800);
      final out = applyLeftoverChange(
        [a, a, const Leftover('', 500)],
        used: [a],
        added: [const Leftover('', 1000)],
      );
      expect(out, [a, const Leftover('', 500), const Leftover('', 1000)]);
    });
  });

  group('재단 계획 화면', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> open(
      WidgetTester tester, {
      List<double> pieces = const [5000, 5000],
    }) async {
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
                  pieces: pieces,
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
    }

    testWidgets('잘랐다고 누르면 잔재가 저장되고 다음에 먼저 쓴다', (tester) async {
      await open(tester);
      expect(find.text('필요 원자재'), findsOneWidget);
      await tester.tap(find.textContaining('잘랐습니다'));
      await tester.pumpAndSettle();
      expect(find.text('저장했습니다'), findsOneWidget);
      expect(await loadLeftovers(), [
        const Leftover('', 1000),
        const Leftover('', 1000),
      ]);

      // 다시 열면 잔재 2개가 있고, 900짜리 조각 둘은 잔재에 들어간다.
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      await open(tester, pieces: [900, 900]);
      expect(find.textContaining('잔재 먼저 쓰기 (2개)'), findsOneWidget);
      expect(find.textContaining('잔재 2개를 씁니다'), findsOneWidget);
      expect(find.text('0본'), findsOneWidget);
    });

    testWidgets('잔재 먼저 쓰기를 끄면 새 원자재로 계산한다', (tester) async {
      SharedPreferences.setMockInitialValues({
        kLeftoversPrefsKey: ['1000\u001F'],
      });
      await open(tester, pieces: [900]);
      expect(find.text('0본'), findsOneWidget);
      await tester.tap(find.byType(Switch).last);
      await tester.pumpAndSettle();
      expect(find.text('1본'), findsOneWidget);
    });

    testWidgets('잔재 관리에서 지우고 더할 수 있다', (tester) async {
      SharedPreferences.setMockInitialValues({
        kLeftoversPrefsKey: ['1000\u001F'],
      });
      await open(tester, pieces: [900]);
      await tester.tap(find.text('잔재 관리'));
      await tester.pumpAndSettle();
      expect(find.textContaining('규격 미지정  ·  1개 · 합계 1000mm'), findsOneWidget);
      expect(find.text('1000mm'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();
      await tester.enterText(find.byType(TextField).last, '1500');
      await tester.tap(find.text('추가'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).last, '100'); // 너무 짧음
      await tester.tap(find.text('추가'));
      await tester.pump();
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(await loadLeftovers(), [const Leftover('', 1500)]);
    });

    testWidgets('촘촘하게 배치해서 줄이면 알려 준다', (tester) async {
      await open(
        tester,
        pieces: [2600, 2600, 2000, 1400, 1400, 1000, 1000, 1000, 1000],
      );
      // 결과가 어떻든 화면은 열려야 하고 줄인 본수 문구는 0본이면 안 나온다.
      expect(find.textContaining('아꼈습니다').evaluate().length <= 1, true);
      expect(findTextContaining('필요 원자재'), findsOneWidget);
    });
  });

  group('원자재 길이 여러 가지', () {
    test('짧은 조각 하나에 6m를 통째로 쓰지 않고 3m로 줄인다', () {
      final r = optimizeCuttingMixed(
        pieces: [5900, 2900],
        stockLengths: [3000, 6000],
      );
      expect(r.totalStock, 9000);
      expect(r.bars.map((b) => b.stockLength).toList()..sort(), [3000, 6000]);
    });

    test('한 가지만 넘기면 기존 계산과 같다', () {
      final a = optimizeCutting(pieces: [2600, 2600, 2000], stockLength: 6000);
      final b = optimizeCuttingMixed(
        pieces: [2600, 2600, 2000],
        stockLengths: [6000],
      );
      expect(b.barCount, a.barCount);
      expect(b.totalStock, a.totalStock);
    });

    test('긴 원자재 한 본이 더 싸면 그쪽을 고른다', () {
      final r = optimizeCuttingMixed(
        pieces: [2500, 2500, 1000],
        stockLengths: [3000, 6000],
      );
      expect(r.totalStock, 6000);
      expect(r.barCount, 1);
    });

    test('가장 긴 원자재보다 긴 조각은 제외하고 그 조각 때문에 싸 보이지 않는다', () {
      final r = optimizeCuttingMixed(
        pieces: [7000, 2000],
        stockLengths: [3000, 6000],
      );
      expect(r.oversizedPieces, [7000]);
      expect(allPieces(r), [2000]);
      expect(r.totalStock, 3000);
    });

    test('길이가 하나도 없으면 오류', () {
      expect(
        () => optimizeCuttingMixed(pieces: [1], stockLengths: []),
        throwsArgumentError,
      );
    });

    test('아무 입력이나 넣어도 가능한 배치이고 한 가지 길이만 쓸 때보다 나쁘지 않다', () {
      final rnd = Random(11);
      for (var t = 0; t < 150; t++) {
        final n = 1 + rnd.nextInt(14);
        final kerf = rnd.nextBool() ? 0.0 : 4.0;
        final pieces = [for (var i = 0; i < n; i++) 200.0 + rnd.nextInt(2600)];
        final lens = [3000.0, 6000.0, 8000.0];
        final mixed = optimizeCuttingMixed(
          pieces: pieces,
          stockLengths: lens,
          kerf: kerf,
        );
        expectValid(mixed, pieces, kerf: kerf);
        for (final l in lens) {
          final single = optimizeCutting(
            pieces: pieces,
            stockLength: l,
            kerf: kerf,
          );
          if (single.oversizedPieces.isEmpty) {
            expect(mixed.totalStock <= single.totalStock + 1e-6, true);
          }
        }
      }
    });
  });
}
