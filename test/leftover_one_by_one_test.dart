// 잔재를 통째로 덮어쓰지 않고 한 개씩 빼고 더하는지(점검 9번).
// 재단 계획 창을 연 뒤 다른 폰·형강 화면에서 잔재를 바꿔도 사라지지 않아야 한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_leftovers.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/widgets/cutting_optimization_sheet.dart';

void main() {
  setUp(() {
    leftoverStore = PrefsLeftoverStore();
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> open(WidgetTester tester, List<double> pieces) async {
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

  List<double> lengths(List<Leftover> l) =>
      [for (final x in l) x.length]..sort();

  testWidgets('창을 연 뒤 다른 곳에서 더한 잔재가 저장·되돌리기 뒤에도 남는다', (tester) async {
    await saveLeftovers([const Leftover('', 5500, id: 'a')]);
    await open(tester, [5000]); // 5500 잔재에서 자르고 500이 남는다

    // 창이 열려 있는 동안 다른 폰(또는 형강 화면)이 잔재 1200을 더함
    await leftoverStore.change(added: [const Leftover('', 1200, id: 'b')]);

    await tester.tap(find.textContaining('잘랐습니다'));
    await tester.pumpAndSettle();
    // 예전: 열 때 목록으로 계산해 통째로 덮어 [500]만 남았다(1200이 사라짐).
    expect(lengths(await loadLeftovers()), [500, 1200]);

    await tester.tap(find.byKey(const Key('leftover_undo')));
    await tester.pumpAndSettle();
    // 예전: 열 때 목록 [5500]으로 되돌려 1200이 사라졌다.
    final back = await loadLeftovers();
    expect(lengths(back), [1200, 5500]);
    expect(back.firstWhere((l) => l.length == 5500).id, 'a');
  });

  test('다른 곳에서 이미 쓴 잔재는 되살리지 않는다', () async {
    await saveLeftovers([
      const Leftover('', 800, id: 'x'),
      const Leftover('', 800, id: 'y'),
    ]);
    // 이 폰은 x를 썼다고 알고 있는데, 다른 폰이 먼저 x를 썼다.
    await leftoverStore.change(used: [const Leftover('', 800, id: 'x')]);
    await leftoverStore.change(used: [const Leftover('', 800, id: 'x')]);
    final l = await loadLeftovers();
    expect(l.map((e) => e.id), ['y']);
  });

  test('이름표 없는 예전 잔재도 길이로 한 개만 뺀다', () async {
    SharedPreferences.setMockInitialValues({
      kLeftoversPrefsKey: ['800\u001F튜브', '800\u001F튜브'],
    });
    await leftoverStore.change(used: [const Leftover('튜브', 800, id: 'new')]);
    expect(await loadLeftovers(), [const Leftover('튜브', 800)]);
  });

  test('잔재 관리: 지운 것·더한 것만 찾는다', () {
    const a = Leftover('', 800, id: 'a');
    const b = Leftover('', 800, id: 'b');
    final d = diffLeftovers([a, b], [b, const Leftover('', 1500)]);
    expect(d.removed.map((e) => e.id), ['a']);
    expect(d.added, [const Leftover('', 1500)]);
  });

  test('저장 형식에 이름표가 같이 남는다', () {
    const l = Leftover('튜브 1/2"', 850, id: 'k1');
    final back = Leftover.decode(l.encode())!;
    expect(back.id, 'k1');
    expect(back.label, '튜브 1/2"');
    expect(back.length, 850);
  });
}
