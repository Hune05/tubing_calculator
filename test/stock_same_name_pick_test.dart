// 이름이 같은 재고(제조사만 다른 것)가 여럿일 때 빼기 전에 묻기(10-09 자재 관리).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_stock_deduct.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/stock_pick_dialog.dart';

const _union = '[HY-LOK] 3/8" Union';

final _docs = <(String, Map<String, dynamic>)>[
  (
    'a',
    {'name': _union, 'maker': '삼화', 'location': 'A창고', 'qty': 4, 'unit': 'EA'},
  ),
  (
    'b',
    {'name': '[HY-LOK]  3/8” Union', 'maker': '동아산전', 'qty': 12, 'unit': 'EA'},
  ),
  ('c', {'name': '찬넬 75x40x5', 'maker': '삼화', 'qty': 3, 'unit': '본'}),
  // 내 것 하나와 공용 하나: 예전처럼 내 것을 먼저 쓰므로 묻지 않는다.
  ('m', {'name': '앵글 50x50x6', 'qty': 2, 'ownerUid': 'me'}),
  ('s', {'name': '앵글 50x50x6', 'qty': 9}),
  // 남의 개인 재고는 고를 것에 안 나온다.
  ('x', {'name': '찬넬 75x40x5', 'maker': '남의 것', 'qty': 7, 'ownerUid': 'other'}),
];

const _takes = [
  StockTake(name: _union, qty: 2, unit: 'EA'),
  StockTake(name: '찬넬 75x40x5', qty: 1, unit: '본'),
  StockTake(name: '앵글 50x50x6', qty: 1, unit: '본'),
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('같은 차례에 이름이 같은 재고가 둘 이상인 것만 고르게 한다(수량 많은 차례)', () {
    final c = sameNameStockChoices(_takes, _docs, 'me');
    expect(c.keys, [_union]);
    expect(c[_union]!.map((e) => e.id), ['b', 'a']);
    expect(c[_union]!.last.short, '삼화 · A창고');
    expect(c[_union]!.first.short, '동아산전');
  });

  test('고른 재고 id: 있고 내가 쓸 수 있을 때만, 아니면 예전 규칙으로', () {
    final byId = {for (final (id, d) in _docs) id: d};
    final picks = {normalizeMaterialName(_union): 'a'};
    expect(pickedStockId(picks, _union, (id) => byId[id], 'me'), 'a');
    // 빈칸·따옴표가 달라도 같은 이름
    expect(
      pickedStockId(picks, '[HY-LOK] 3/8″ union', (id) => byId[id], 'me'),
      'a',
    );
    // 지워진 재고
    expect(
      pickedStockId(
        {normalizeMaterialName(_union): 'gone'},
        _union,
        (id) => byId[id],
        'me',
      ),
      isNull,
    );
    // 남의 개인 재고는 쓰지 않는다
    expect(
      pickedStockId(
        {normalizeMaterialName('찬넬 75x40x5'): 'x'},
        '찬넬 75x40x5',
        (id) => byId[id],
        'me',
      ),
      isNull,
    );
    expect(pickedStockId(const {}, _union, (id) => byId[id], 'me'), isNull);
  });

  test('확인창 줄에 고른 재고가 붙고, 모자람은 고른 재고 수량으로 본다', () {
    const picks = StockPicks(
      ids: {},
      chosen: {
        _union: StockChoice(
          id: 'a',
          maker: '삼화',
          location: 'A창고',
          qty: 1,
          unit: 'EA',
        ),
      },
    );
    final qty = picks.applyQty({_union: 12, '찬넬 75x40x5': 3});
    expect(qty[_union], 1);
    final lines = stockTakeLines(
      _takes.take(1).toList(),
      qty,
      picked: picks.labels,
    );
    expect(lines, '• $_union 2EA → 삼화 · A창고');
    expect(
      shortStockWarning(_takes.take(1).toList(), qty),
      contains('창고에 1EA'),
    );
  });

  test('작업마다 고른 것을 기억한다', () async {
    await saveStockPicks('line:j1', {'k': 'a'});
    await saveStockPicks('line:j2', {'k': 'b'});
    await saveStockPicks('line:j1', {'k2': 'c'});
    expect(await loadStockPicks('line:j1'), {'k': 'a', 'k2': 'c'});
    expect(await loadStockPicks('line:j2'), {'k': 'b'});
    expect(await loadStockPicks('steel:j1'), isEmpty);
  });

  Future<StockPicks?> open(
    WidgetTester tester, {
    required Future<void> Function() act,
  }) async {
    StockPicks? got;
    var done = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              got = await askSameNameStock(
                context,
                _takes,
                jobKey: 'line:j1',
                load: (t) async => sameNameStockChoices(t, _docs, 'me'),
              );
              done = true;
            },
            child: const Text('빼기'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('빼기'));
    await tester.pumpAndSettle();
    await act();
    await tester.pumpAndSettle();
    expect(done, isTrue);
    return got;
  }

  testWidgets('창: 수량 많은 것이 미리 골라져 있고, 바꿔 고르면 그것으로 빼고 기억한다', (tester) async {
    final got = await open(
      tester,
      act: () async {
        expect(find.byKey(const Key('stock_pick_dialog')), findsOneWidget);
        expect(find.text(_union), findsOneWidget);
        expect(find.text('위치 A창고 · 수량 4EA'), findsOneWidget);
        await tester.tap(find.byKey(const Key('stock_pick_a')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('stock_pick_ok')));
      },
    );
    expect(got!.ids, {normalizeMaterialName(_union): 'a'});
    expect(got.labels, {_union: '삼화 · A창고'});
    expect(await loadStockPicks('line:j1'), {
      normalizeMaterialName(_union): 'a',
    });
  });

  testWidgets('창: 다음에 열면 기억한 것이 골라져 있고, 취소하면 빼지 않는다(null)', (tester) async {
    await saveStockPicks('line:j1', {normalizeMaterialName(_union): 'a'});
    final got = await open(
      tester,
      act: () async {
        final tile = tester.widget<ListTile>(
          find.byKey(const Key('stock_pick_a')),
        );
        expect((tile.leading as Icon).icon, Icons.radio_button_checked);
        await tester.tap(find.text('취소'));
      },
    );
    expect(got, isNull);
  });

  testWidgets('이름이 같은 재고가 없으면 묻지 않는다', (tester) async {
    StockPicks? got;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => got = await askSameNameStock(
              context,
              const [StockTake(name: '찬넬 75x40x5', qty: 1, unit: '본')],
              jobKey: 'steel:s1',
              load: (t) async => sameNameStockChoices(t, _docs, 'me'),
            ),
            child: const Text('빼기'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('빼기'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('stock_pick_dialog')), findsNothing);
    expect(got, isNotNull);
    expect(got!.ids, isEmpty);
  });

  test('되돌리기 확인창 이름표: 고른 재고가 있을 때만, 지워졌으면 빠진다', () {
    final picks = {normalizeMaterialName(_union): 'a'};
    expect(pickedStockLabels(_takes, picks, _docs, 'me'), {_union: '삼화 · A창고'});
    expect(pickedStockLabels(_takes, const {}, _docs, 'me'), isEmpty);
    expect(
      pickedStockLabels(
        _takes,
        {normalizeMaterialName(_union): 'gone'},
        _docs,
        'me',
      ),
      isEmpty,
    );
  });
}
