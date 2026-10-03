// 전선관 특수 벤딩 시트(킥·분할 90°·백투백 90°·스터브업): 입력 → 결과 글 → 목록에 줄이 들어가는지.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/bend_sheet_specs.dart';
import 'package:tubing_calculator/src/presentation/conduit/widgets/conduit_special_sheets.dart';

final specs = BendSheetSpecs.conduit({
  'benderType': 'hand',
  'clr': 114.3,
  'takeUp': 152.4,
  'gain': 20.0,
  'applyShrink': true,
});

typedef Opener = void Function(
  BuildContext context,
  void Function(List<Map<String, dynamic>>) add,
);

Future<List<List<Map<String, dynamic>>>> open(
  WidgetTester tester,
  Opener opener,
) async {
  tester.view.physicalSize = const Size(400, 900) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final added = <List<Map<String, dynamic>>>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const Key('open'),
              onPressed: () => opener(context, added.add),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
  return added;
}

Future<void> type(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pumpAndSettle();
}

String allText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text, skipOffstage: false))
    .map((t) => t.data ?? '')
    .join('\n');

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('킥: H 100·30° → 200·173.2·26.8·배수 2, 방향 고르면 한 줄이 들어간다', (tester) async {
    final added = await open(
      tester,
      (c, add) => ConduitSpecialSheets.showKick(
        c,
        currentRotation: 90,
        onAddBends: add,
        specs: specs,
      ),
    );
    await type(tester, 'cs_height', '100');
    await type(tester, 'cs_start', '500');
    final t = allText(tester);
    expect(t, contains('200 mm'));
    expect(t, contains('173.2 mm'));
    expect(t, contains('26.8 mm'));
    expect(t, contains('2'));
    // 방향을 고르기 전에는 추가 단추가 꺼져 있다.
    expect(tester.widget<ElevatedButton>(find.byKey(const Key('cs_add'))).onPressed, isNull);
    await tapKey(tester, 'cs_dir_0');
    await tapKey(tester, 'cs_add');
    expect(added.length, 1);
    final b = added.single.single;
    expect(b['angle'], 30);
    expect(b['rotation'], 0.0);
    // 1번 마킹 500 + 테이크업(30°로 줄인 값) = 꺾이는 점 길이
    expect(b['length'], closeTo(500 + specs.markOffset(30), 0.06));
  });

  testWidgets('킥: 지금 진행 방향(오른쪽)과 같은 쪽·반대 쪽은 막는다', (tester) async {
    final added = await open(
      tester,
      (c, add) => ConduitSpecialSheets.showKick(c, currentRotation: 90, onAddBends: add, specs: specs),
    );
    await type(tester, 'cs_height', '100');
    await tapKey(tester, 'cs_dir_90');
    expect(allText(tester), contains('꺾을 수 없습니다'));
    expect(tester.widget<ElevatedButton>(find.byKey(const Key('cs_add'))).onPressed, isNull);
    expect(added, isEmpty);
  });

  testWidgets('분할 90°: R 300·5번 → 각 18°, 간격 2R·tan9° = 95.0, 목록에 5줄', (tester) async {
    final added = await open(
      tester,
      (c, add) => ConduitSpecialSheets.showSegmented(c, currentRotation: 90, onAddBends: add, specs: specs),
    );
    await type(tester, 'cs_corner', '1000');
    final t = allText(tester);
    expect(t, contains('18°'));
    expect(t, contains('95.0 mm'.replaceAll('.0', '')) , reason: '간격 95 (95.03)');
    await tapKey(tester, 'cs_dir_0');
    await tapKey(tester, 'cs_add');
    final list = added.single;
    expect(list.length, 5);
    expect(list.every((e) => e['angle'] == 18), true);
    expect(list.every((e) => e['rotation'] == 0.0), true);
    expect(list[1]['length'], closeTo(95.0, 0.06));
  });

  testWidgets('분할 90°: 반경이 모서리 거리보다 크면 경고하고 추가 못 한다', (tester) async {
    final added = await open(
      tester,
      (c, add) => ConduitSpecialSheets.showSegmented(c, currentRotation: 90, onAddBends: add, specs: specs),
    );
    await type(tester, 'cs_corner', '100');
    await tapKey(tester, 'cs_dir_0');
    expect(allText(tester), contains('너무 큽니다'));
    expect(tester.widget<ElevatedButton>(find.byKey(const Key('cs_add'))).onPressed, isNull);
    expect(added, isEmpty);
  });

  testWidgets('백투백 90°: 바깥~바깥 300·관 26.5 → 간격 273.5, 두 줄(첫 방향, 처음 진행의 반대)', (tester) async {
    final added = await open(
      tester,
      (c, add) => ConduitSpecialSheets.showBackToBack(
        c,
        currentRotation: 90, // 지금 오른쪽으로 가는 중
        onAddBends: add,
        specs: specs,
        conduitOd: 26.5,
      ),
    );
    await type(tester, 'cs_first', '400');
    await type(tester, 'cs_dist', '300');
    expect(allText(tester), contains('273.5 mm'));
    await tapKey(tester, 'cs_dir_0'); // 첫 90°는 위로
    await tapKey(tester, 'cs_add');
    final list = added.single;
    expect(list.length, 2);
    expect(list[0], {'length': 400.0, 'angle': 90.0, 'rotation': 0.0});
    expect(list[1], {'length': 273.5, 'angle': 90.0, 'rotation': 270.0});
    // 안쪽~안쪽으로 바꾸면 간격이 326.5
  });

  testWidgets('백투백 90°: 안쪽~안쪽이면 간격 = 거리 + 관 지름', (tester) async {
    await open(
      tester,
      (c, add) => ConduitSpecialSheets.showBackToBack(
        c,
        currentRotation: 90,
        onAddBends: add,
        specs: specs,
        conduitOd: 26.5,
      ),
    );
    await type(tester, 'cs_dist', '300');
    await tapKey(tester, 'cs_inside');
    expect(allText(tester), contains('326.5 mm'));
  });

  testWidgets('백투백 90°: 진행 방향에 수직이 아니면(앞으로 꺾음은 수직이지만 대각선 없음) 위로만 허용 — 같은 쪽은 막는다', (tester) async {
    await open(
      tester,
      (c, add) => ConduitSpecialSheets.showBackToBack(c, currentRotation: 90, onAddBends: add, specs: specs, conduitOd: 26.5),
    );
    await type(tester, 'cs_first', '400');
    await type(tester, 'cs_dist', '300');
    await tapKey(tester, 'cs_dir_270'); // 왼쪽 = 진행 방향의 반대
    expect(allText(tester), contains('꺾을 수 없습니다'));
    expect(tester.widget<ElevatedButton>(find.byKey(const Key('cs_add'))).onPressed, isNull);
  });

  testWidgets('스터브업: 길이 300 → 마킹 = 300 − 테이크업(90°), 한 줄', (tester) async {
    final added = await open(
      tester,
      (c, add) => ConduitSpecialSheets.showStubUp(c, currentRotation: 90, onAddBends: add, specs: specs),
    );
    await type(tester, 'cs_stub', '300');
    expect(allText(tester), contains('147.6 mm'));
    await tapKey(tester, 'cs_dir_0');
    await tapKey(tester, 'cs_add');
    expect(added.single, [
      {'length': 300.0, 'angle': 90.0, 'rotation': 0.0},
    ]);
  });
  for (final (name, opener) in <(String, Opener)>[
    ('킥', (c, add) => ConduitSpecialSheets.showKick(c, currentRotation: 90, onAddBends: add, specs: specs)),
    ('분할 90°', (c, add) => ConduitSpecialSheets.showSegmented(c, currentRotation: 90, onAddBends: add, specs: specs)),
    ('백투백 90°', (c, add) => ConduitSpecialSheets.showBackToBack(c, currentRotation: 90, onAddBends: add, specs: specs, conduitOd: 26.5)),
    ('스터브업', (c, add) => ConduitSpecialSheets.showStubUp(c, currentRotation: 90, onAddBends: add, specs: specs)),
  ]) {
    testWidgets('좁은 폰(320)·큰 글씨에서 $name 시트가 넘치지 않는다', (tester) async {
      tester.view.physicalSize = const Size(320, 700) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(320, 700), textScaler: TextScaler.linear(1.4)),
            child: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  key: const Key('open'),
                  onPressed: () => opener(context, (_) {}),
                  child: const Text('열기'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      // 입력을 채워 결과 줄까지 그려 본다.
      for (final k in ['cs_height', 'cs_corner', 'cs_first', 'cs_dist', 'cs_stub']) {
        if (find.byKey(Key(k)).evaluate().isNotEmpty) {
          await tester.enterText(find.byKey(Key(k)), '300');
        }
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
