// 보관함 저장 창(튜브·전선관): 마지막 작업 이름 미리 채우기, 이미 쓴 이름 칩, 한 줄 요약,
// 두 번 눌러도 한 번만 저장, 저장 실패 안내, "보관함 보기" 단추.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/common_widgets/save_name_chips.dart';
import 'package:tubing_calculator/src/core/common_widgets/smart_save_pad.dart';
import 'package:tubing_calculator/src/data/conduit_drawings.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';
import 'package:tubing_calculator/src/presentation/conduit/widgets/conduit_save_dialog.dart';

Map<String, dynamic> _row(String project) => {
  'id': 1,
  'p_to_p': '{"project":"$project"}',
};

Widget _tubeHost(List<Map<String, dynamic>> bends) => MaterialApp(
  home: Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => SmartSavePad(
            totalCut: 617.5,
            bendList: bends,
            includeStart: true,
            includeEnd: false,
            tailLength: 25,
            startDir: 'RIGHT',
          ),
        ),
        child: const Text('열기'),
      ),
    ),
  ),
);

void main() {
  group('순수 함수', () {
    test('최근 작업 이름: 빈 것·자동 이름·중복을 빼고 처음 나온 순서로 최대 개수', () {
      expect(
        recentDistinctNames([
          'B동 ',
          '',
          '프로젝트 미지정',
          'A동',
          'B동',
          '미분류 도면',
          '미지정 프로젝트',
          'C동',
        ]),
        ['B동', 'A동', 'C동'],
      );
      expect(recentDistinctNames(['1', '2', '3', '4'], max: 2), ['1', '2']);
    });

    test('한 줄 요약: 굽힘 수·총 길이·꼬리·피팅', () {
      final bends = [
        {'angle': 0.0},
        {'angle': 90.0},
        {'angle': '45'},
      ];
      expect(
        saveSummaryText(
          bends: bends,
          totalCut: 617.5,
          tail: 25,
          startFit: true,
          endFit: true,
        ),
        '굽힘 2개 · 총 618mm · 꼬리 25mm · 피팅 시작·끝',
      );
      expect(saveSummaryText(bends: bends, totalCut: 600), '굽힘 2개 · 총 600mm');
      expect(
        saveSummaryText(bends: bends, totalCut: 600, endFit: true),
        '굽힘 2개 · 총 600mm · 피팅 끝',
      );
    });
  });

  group('튜브 저장 창', () {
    late List<Map<String, dynamic>> saved;
    late Future<int> Function(Map<String, dynamic>) saver;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      MachineSpecs().resetForTest();
      saved = [];
      saver = (row) async {
        saved.add(row);
        return 1;
      };
      tubeHistoryLoader = () async => [_row('B동'), _row('A동'), _row('B동')];
      tubeHistorySaver = (row) => saver(row);
    });

    final bends = [
      {'length': 100.0, 'angle': 0.0},
      {'length': 50.0, 'angle': 90.0},
    ];

    testWidgets('마지막 작업 이름을 미리 채우고, 보관함의 이름을 칩으로 보여 주고, 요약이 보인다', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({kTubeLastProjectKey: 'A동'});
      await tester.binding.setSurfaceSize(const Size(420, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_tubeHost(bends));
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'A동'))
            .controller!
            .text,
        'A동',
      );
      expect(find.text('굽힘 1개 · 총 618mm · 꼬리 25mm · 피팅 시작'), findsOneWidget);
      // 같은 이름 중복은 한 번만, 최근 것 먼저
      expect(find.widgetWithText(ChoiceChip, 'B동'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'A동'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'B동'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'B동'))
            .selected,
        isTrue,
      );
    });

    testWidgets('저장하면 이름을 기억하고, 알림에 보관함 보기 단추가 붙는다', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_tubeHost(bends));
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, '프로젝트 이름 (예: A동 보일러실)'),
        '신규 배관',
      );
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();

      expect(saved.single['pipe_size'], isNotEmpty);
      expect(find.text('보관함에 저장했습니다.'), findsOneWidget);
      expect(find.text('보관함 보기'), findsOneWidget);
      expect(find.text('굽힘 1개 · 총 618mm · 꼬리 25mm · 피팅 시작'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kTubeLastProjectKey), '신규 배관');
    });

    testWidgets('저장이 끝나기 전에 또 눌러도 한 건만 저장된다', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final gate = Completer<void>();
      saver = (row) async {
        saved.add(row);
        await gate.future;
        return 1;
      };
      await tester.pumpWidget(_tubeHost(bends));
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('저장'));
      await tester.pump();
      await tester.tap(find.text('저장'), warnIfMissed: false);
      await tester.pump();
      gate.complete();
      await tester.pumpAndSettle();

      expect(saved.length, 1);
      expect(find.text('보관함에 저장했습니다.'), findsOneWidget);
    });

    testWidgets('저장이 실패하면 창을 그대로 두고 알려 주며, 다시 누르면 저장된다', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var fail = true;
      saver = (row) async {
        if (fail) throw Exception('디스크 가득');
        saved.add(row);
        return 1;
      };
      await tester.pumpWidget(_tubeHost(bends));
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(find.text('저장하지 못했습니다. 다시 시도하십시오.'), findsOneWidget);
      expect(find.text('보관함에 저장'), findsOneWidget); // 창이 그대로 있다
      expect(saved, isEmpty);

      fail = false;
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(saved.length, 1);
      expect(find.text('보관함에 저장'), findsNothing);
    });
  });

  group('전선관 저장 창', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    Widget host({VoidCallback? onOpenArchive}) => MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showConduitSaveDialog(
              context,
              bends: [
                {'length': 300.0, 'angle': 90.0, 'rotation': 0.0},
                {'length': 400.0, 'angle': 0.0, 'rotation': 0.0},
              ],
              totalCut: 617.5,
              settings: const {'benderType': 'hand'},
              onOpenArchive: onOpenArchive,
            ),
            child: const Text('열기'),
          ),
        ),
      ),
    );

    testWidgets('보관함에 이미 있는 작업 이름이 칩으로 나오고 누르면 들어간다', (tester) async {
      await tester.runAsync(() async {
        await saveConduitDrawing(
          folderName: 'EPS실',
          title: 'a',
          totalCut: 1,
          bends: const [],
        );
        await saveConduitDrawing(
          folderName: 'A구역',
          title: 'b',
          totalCut: 1,
          bends: const [],
        );
      });
      await tester.pumpWidget(host());
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      expect(find.text('굽힘 1개 · 총 618mm'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'EPS실'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'A구역'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'A구역'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('conduit_save_folder')))
            .controller!
            .text,
        'A구역',
      );
    });

    testWidgets('저장을 두 번 눌러도 한 건만 저장되고, 보관함 보기 단추가 붙는다', (tester) async {
      var opened = 0;
      await tester.pumpWidget(host(onOpenArchive: () => opened++));
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('conduit_save_folder')),
        'EPS실',
      );
      await tester.tap(find.byKey(const Key('conduit_save_ok')));
      await tester.tap(
        find.byKey(const Key('conduit_save_ok')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      final list = await tester.runAsync(loadConduitDrawings);
      expect(list!.length, 1);
      expect(find.text('보관함에 저장했습니다.'), findsOneWidget);
      await tester.tap(find.text('보관함 보기'));
      expect(opened, 1);
    });
  });
}
