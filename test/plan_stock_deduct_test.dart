// 재단 계획의 새 원자재를 재고에서 뺄 때(튜브·형강 같이, 점검 4·13번).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_leftovers.dart';
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
