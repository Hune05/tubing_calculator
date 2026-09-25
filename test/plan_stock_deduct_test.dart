// 재단 계획의 새 원자재를 재고에서 뺄 때(튜브·형강 같이, 점검 4·13번).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/models/cutting_project_model.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_firestore_helper.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_leftovers.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_optimizer.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_stock_deduct.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/widgets/cutting_optimization_sheet.dart';

void main() {
  group('뺄 본 셈', () {
    test('창고가 m로 세면 본 길이를 더해 m로, 본으로 세면 본수로', () {
      final takes = stockTakesForBars(
        {
          '앵글 40x40x3': [6000, 3000],
          '찬넬 75x40x5': [8000, 8000],
        },
        unitByName: {'앵글 40x40x3': 'm'},
      );
      final byName = {for (final t in takes) t.name: t};
      // 예전: 앵글 2본 → 창고(m)에서 2m만 빠졌다.
      expect(byName['앵글 40x40x3']!.qty, 9);
      expect(byName['앵글 40x40x3']!.unit, 'm');
      expect(byName['찬넬 75x40x5']!.qty, 2);
      expect(byName['찬넬 75x40x5']!.unit, '본');
    });

    test('이미 뺀 본은 같은 길이끼리 지우고 남은 것만', () {
      final left = barsStillToDeduct(
        {
          'A': [6000, 6000, 3000],
          'B': [6000],
        },
        {
          'A': [6000],
          'B': [6000],
        },
      );
      expect(left, {
        'A': [3000, 6000],
      });
    });

    test('예전 기록("규격=본수")은 길이를 모르는 본으로 읽는다', () {
      final old = decodeDeductedBars('앵글 40x40x3=2;찬넬 75x40x5=1');
      expect(old['앵글 40x40x3'], [-1, -1]);
      expect(
        barsStillToDeduct({
          '앵글 40x40x3': [6000, 3000, 3000],
        }, old),
        {
          '앵글 40x40x3': [6000],
        },
      );
      // 새 모양은 그대로 되읽힌다.
      final m = {
        '튜브 1/2"': [6000.0, 6000.0],
      };
      expect(decodeDeductedBars(encodeDeductedBars(m)), m);
    });

    test('차감 결과에서 뺀 규격만 고른다', () {
      final asked = {
        'A': [6000.0],
        'B': [3000.0],
      };
      final part = deductedPart(asked, [
        const StockTake(name: 'A', qty: 1, unit: '본', spec: 'A'),
      ]);
      expect(part, {
        'A': [6000.0],
      });
    });
  });

  group('튜브: 재단 계획 본수로 뺀다(점검 4번)', () {
    test('3500mm × 3개는 한 본에 하나씩 3본(예전 길이 합 올림은 2본)', () {
      final plan = optimizeCutting(
        pieces: [3500, 3500, 3500],
        stockLength: 6000,
      );
      final need = {
        '튜브 1/2"': [for (final b in plan.bars) b.stockLength],
      };
      expect(stockTakesForBars(need).single.qty, 3);
      // 예전 방식
      final old = stockTakesFromMaterials([
        {'type': 'TUBE', 'db_name': '튜브 1/2"', 'qty_mm': 10500},
      ]);
      expect(old.single.qty, 2);
    });

    test('잔재에서 자른 조각은 새 본으로 빼지 않는다', () {
      final plan = optimizeCutting(
        pieces: [1000],
        stockLength: 6000,
        leftovers: [5000],
      );
      expect(plan.bars, isEmpty); // 뺄 새 원자재 없음(예전: 1본 차감)
    });

    test('저장할 때 튜브 길이는 materials에 쌓지 않고 부속만', () {
      final m = materialsAfterSession(
        [
          {'type': 'TUBE', 'db_name': '튜브 1/2"', 'qty_mm': 800.0},
        ],
        [
          {'db_name': '[HY-LOK] 1/2" Union', 'qty': 2, 'spec': '1/2"'},
        ],
      );
      // 예전에 쌓인 튜브는 그대로(목록에서 전처럼 뺄 수 있다), 새 튜브는 안 더한다.
      expect(m.firstWhere((e) => e['type'] == 'TUBE')['qty_mm'], 800.0);
      expect(m.firstWhere((e) => e['type'] == 'FITTING')['qty_ea'], 2);
    });

    test('컷팅 기록: 새 기록은 튜브가 materials에 없다고 적고, 예전 기록은 있다고 읽는다', () {
      final r = CutRecord(
        id: '',
        projectId: 'p',
        timestamp: DateTime(2026, 9, 25),
        tubeSize: '1/2"',
        originalLength: 1000,
        startFitting: 'A',
        endFitting: 'B',
        cutLength: 950,
        tubeInMaterials: false,
      );
      expect(CutRecord.fromMap('x', r.toMap()).tubeInMaterials, isFalse);
      final legacy = Map<String, dynamic>.from(r.toMap())
        ..remove('tubeInMaterials');
      expect(CutRecord.fromMap('y', legacy).tubeInMaterials, isTrue);
    });
  });

  group('재단 계획 창', () {
    setUp(() {
      leftoverStore = PrefsLeftoverStore();
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('일부 규격만 빠지면 남은 것만 다시 뺄 수 있다', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      final asked = <BarsBySpec>[];
      BarsBySpec saved = {};
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showCuttingOptimizationSheet(
                  context,
                  groupedPieces: {
                    'A': [5000, 5000],
                    'B': [4000],
                  },
                  initialStockLength: 6000,
                  // A만 재고에 있어 빠지고 B는 못 뺐다.
                  onDeductStock: (bars) async {
                    asked.add(bars);
                    return {if (bars.containsKey('A')) 'A': bars['A']!};
                  },
                  onStockDeducted: (m) => saved = m,
                  onUndoDeductStock: (_) async => true,
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();

      final btn = find.byKey(const Key('stock_deduct'));
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pumpAndSettle();
      expect(asked.single, {
        'A': [6000, 6000],
        'B': [6000],
      });
      // 예전: 하나라도 빠지면 전부 "뺐습니다"가 되어 B를 다시 뺄 단추가 없었다.
      expect(find.text('재고에서 뺐습니다'), findsNothing);
      expect(find.text('남은 1본 재고에서 빼기'), findsOneWidget);
      expect(saved, {
        'A': [6000, 6000],
      });

      await tester.tap(btn);
      await tester.pumpAndSettle();
      expect(asked.last, {
        'B': [6000],
      });
    });
  });
}
