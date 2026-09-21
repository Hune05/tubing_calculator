// 보관함: 전선관 저장·목록·불러오기·지우기, 튜브 "계산기로 불러오기".
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/conduit_drawings.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';
import 'package:tubing_calculator/src/data/models/conduit_data_manager.dart';
import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_history_tab.dart';
import 'package:tubing_calculator/src/presentation/conduit/widgets/conduit_save_dialog.dart';
import 'package:tubing_calculator/src/presentation/fabrication/screens/mobile_fabrication_detail_screen.dart';

Map<String, dynamic> b(double len, double angle, [double rot = 0]) => {
  'length': len,
  'angle': angle,
  'rotation': rot,
};

List<double> lens(List<Map<String, dynamic>> l) => [
  for (final x in l) (x['length'] as num).toDouble(),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('전선관 보관함 저장소', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('저장한 순서 반대로(새것 먼저) 읽고, 지우고, 되살린다', () async {
      final a = await saveConduitDrawing(
        folderName: 'A구역',
        title: '첫 도면',
        totalCut: 616,
        bends: [b(150, 0), b(72.3, 21), b(195.3, 21, 180)],
        settings: {'benderType': 'hand', 'gain': 82.5, 'keepScreenOn': true},
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await saveConduitDrawing(
        folderName: '',
        title: '',
        totalCut: 700,
        bends: [b(300, 90)],
      );
      var list = await loadConduitDrawings();
      expect(list.map((d) => d.title).toList(), ['이름 없는 도면', '첫 도면']);
      expect(list[0].folderName, '미분류 도면');
      expect(list[1].segmentCount, 3);
      expect(lens(list[1].bends), [150, 72.3, 195.3]);
      // 장비 기록은 필요한 것만.
      expect(list[1].settings['gain'], 82.5);
      expect(list[1].settings.containsKey('keepScreenOn'), isFalse);

      await deleteConduitDrawing(a.id);
      list = await loadConduitDrawings();
      expect(list.length, 1);
      await restoreConduitDrawing(a);
      await restoreConduitDrawing(a); // 두 번 눌러도 한 번만
      list = await loadConduitDrawings();
      expect(list.length, 2);
    });

    test('깨진 저장값이면 빈 목록', () async {
      SharedPreferences.setMockInitialValues({
        kConduitDrawingsPrefsKey: '이건 JSON이 아니다',
      });
      expect(await loadConduitDrawings(), isEmpty);
    });
  });

  group('전선관 보관함 화면', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ConduitDataManager().bendList
        ..clear()
        ..addAll([b(500, 0)]);
      ConduitDataManager().clearHistory();
    });

    testWidgets('예시 도면은 없고, 저장한 도면을 불러오면 목록이 바뀌고 ↶로 되돌린다', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1600));
      var loaded = 0;
      await tester.pumpWidget(
        MaterialApp(home: ConduitHistoryTab(onLoaded: () => loaded++)),
      );
      await tester.pumpAndSettle();
      expect(find.text('보관된 도면이 없습니다'), findsOneWidget);
      expect(find.textContaining('A구역 메인 트레이'), findsNothing);

      await tester.runAsync(
        () => saveConduitDrawing(
          folderName: 'A구역',
          title: '21° 오프셋',
          totalCut: 616,
          bends: [b(150, 0), b(72.3, 21), b(195.3, 21, 180), b(200, 0)],
        ),
      );
      conduitDrawingsRevision.value++;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(find.text('21° 오프셋'), findsOneWidget);

      await tester.tap(find.text('작업창으로 불러오기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('불러오기'));
      await tester.pumpAndSettle();

      final m = ConduitDataManager();
      expect(lens(m.bendList), [150, 72.3, 195.3, 200]);
      expect(loaded, 1);
      expect(m.undo(), isTrue);
      expect(lens(m.bendList), [500]);
    });

    testWidgets('마킹 탭 저장 창: 넣은 이름으로 저장하고 작업 이름을 기억한다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showConduitSaveDialog(
                  context,
                  bends: [b(300, 90), b(400, 0)],
                  totalCut: 617.5,
                  settings: const {'benderType': 'hand'},
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      // 도면 이름은 알아보기 쉽게 미리 채워 둔다.
      expect(find.text('벤드 1개 · 618mm'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('conduit_save_folder')),
        'EPS실',
      );
      await tester.tap(find.byKey(const Key('conduit_save_ok')));
      await tester.pumpAndSettle();

      final list = await tester.runAsync(loadConduitDrawings);
      expect(list!.single.folderName, 'EPS실');
      expect(list.single.title, '벤드 1개 · 618mm');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('conduit_last_folder'), 'EPS실');
    });
  });

  group('튜브 계산기로 불러오기', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      MachineSpecs().resetForTest();
      MobileBendDataManager().bendList
        ..clear()
        ..addAll([b(999, 0)]);
      MobileBendDataManager().clearHistory();
    });

    testWidgets('목록·피팅·꼬리·시작 방향을 저장 때로, 목록은 ↶로 되돌린다', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1800));
      final item = {
        'id': 1,
        'date': '2026-09-21 10:00',
        'pipe_size': '1/2"',
        'total_length': 598.0,
        'p_to_p': jsonEncode({
          'project': 'TEST',
          'from': 'A',
          'to': 'B',
          'start_fit': true,
          'end_fit': false,
          'tail': 40.0,
          'start_dir': 'UP',
        }),
        'bend_data': jsonEncode([
          {...b(150, 0), 'start_fit_applied': true, 'start_dir': 'UP'},
          b(7.1, 21),
          b(195.3, 21, 180),
          {...b(200, 0), 'end_fit_applied': false},
        ]),
      };
      Object? popped;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                popped = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        MobileFabricationDetailScreen(itemData: item),
                  ),
                );
              },
              child: const Text('열기'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('load_to_calculator')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('불러오기'));
      await tester.pumpAndSettle();

      final m = MobileBendDataManager();
      expect(lens(m.bendList), [150, 7.1, 195.3, 200]);
      // 계산에 쓰지 않는 표시용 칸은 들어오지 않는다.
      expect(m.bendList.first.keys.toSet(), {'length', 'angle', 'rotation'});
      expect(m.startFit, isTrue);
      expect(m.endFit, isFalse);
      expect(m.tail, 40.0);
      expect(popped, {'loaded': true, 'startDir': 'UP'});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('mobile_saved_start_dir'), 'UP');

      expect(m.undo(), isTrue);
      expect(lens(m.bendList), [999]);
    });
  });
}
