// 보관함에서 불러와 고친 도면을 저장할 때 "이 도면에 덮어쓰기": 불러온 도면 기억(목록을 지우거나
// 불러오기를 되돌리면 잊음), 저장 창 덮어쓰기·새 도면 고르기·되돌리기, 마킹 탭 연결.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/common_widgets/smart_save_pad.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';
import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/data/tube_drawing_specs.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/history_card_info.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_result_tabs.dart';
import 'package:tubing_calculator/src/presentation/fabrication/screens/mobile_fabrication_detail_screen.dart';

Map<String, dynamic> b(double len, double angle, [double rot = 0]) => {
  'length': len,
  'angle': angle,
  'rotation': rot,
};

const _oldSpecs = {
  'radius': 44.0,
  'gain90': 13.5,
  'springback': 2.0,
  'benderOffset': 0.0,
  'fittingDepth': 21.0,
};

Map<String, dynamic> _row() => {
  'id': 7,
  'date': '2026-09-21 10:05',
  'pipe_size': '3/8"',
  'total_length': 500.0,
  'p_to_p': jsonEncode({
    'project': 'A동',
    'from': '1번',
    'to': '2번',
    'note': '기존 메모',
    'custom': 9,
    'start_dir': 'UP',
    'specs': _oldSpecs,
  }),
  'bend_data': jsonEncode([b(100, 0), b(50, 90)]),
};

void main() {
  late List<(int, Map<String, dynamic>)> updates;
  late List<Map<String, dynamic>> inserts;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MachineSpecs().resetForTest();
    final m = MobileBendDataManager();
    m.bendList
      ..clear()
      ..addAll([b(150, 0), b(80, 90), b(200, 0)]);
    m.clearHistory();
    m.clearSource();
    updates = [];
    inserts = [];
    TubeHistoryDb.load = () async => [_row()];
    TubeHistoryDb.update = (id, row) async => updates.add((id, row));
    TubeHistoryDb.insert = (row) async {
      inserts.add(row);
      return 99;
    };
  });

  group('불러온 도면 기억', () {
    test('불러온 뒤 고쳐도 기억하고, 불러오기를 되돌리거나 목록을 지우면 잊는다', () {
      final m = MobileBendDataManager();
      m.replaceAll([b(100, 0), b(50, 90)]);
      m.setSource(7);
      expect(m.sourceHistoryId, 7);

      m.addBend(b(30, 45));
      expect(m.undo(), isTrue); // 방금 더한 줄만 되돌림
      expect(m.sourceHistoryId, 7);

      expect(m.undo(), isTrue); // 불러오기 자체를 되돌림
      expect(m.sourceHistoryId, isNull);

      m.replaceAll([b(100, 0)]);
      m.setSource(8);
      m.clearBends();
      expect(m.sourceHistoryId, isNull);
    });

    testWidgets('도면 보기에서 "계산기로 불러오기"를 하면 그 도면을 기억한다', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      MobileFabricationDetailScreen(itemData: _row()),
                ),
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('load_to_calculator')));
      await tester.pumpAndSettle();
      expect(find.textContaining('이 도면에 덮어쓸 수도 있습니다'), findsOneWidget);
      await tester.tap(find.text('불러오기'));
      await tester.pumpAndSettle();
      expect(MobileBendDataManager().sourceHistoryId, 7);
    });
  });

  group('저장 창', () {
    Widget host({HistoryOverwriteTarget? target}) => MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => SmartSavePad(
                totalCut: 617.5,
                bendList: [b(100, 0), b(50, 90)],
                includeStart: true,
                includeEnd: false,
                tailLength: 25,
                startDir: 'RIGHT',
                overwriteTarget: target,
              ),
            ),
            child: const Text('열기'),
          ),
        ),
      ),
    );

    Future<void> open(
      WidgetTester tester, {
      HistoryOverwriteTarget? target,
    }) async {
      await tester.binding.setSurfaceSize(const Size(420, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(host(target: target));
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
    }

    HistoryOverwriteTarget target() => HistoryOverwriteTarget(_row());

    testWidgets('불러온 도면이 있으면 덮어쓰기가 먼저 골라져 있고, 그 도면 값이 채워진다', (tester) async {
      SharedPreferences.setMockInitialValues({kTubeLastProjectKey: '다른 작업'});
      await open(tester, target: target());
      expect(find.byKey(const Key('save_mode_overwrite')), findsOneWidget);
      expect(find.byKey(const Key('save_mode_new')), findsOneWidget);
      expect(find.text('덮어쓸 도면: 1번 ➔ 2번 · 2026-09-21 10:05'), findsOneWidget);
      expect(find.text('덮어쓰기'), findsOneWidget); // 저장 단추 글자
      // 마지막 작업 이름("다른 작업")이 아니라 불러온 도면의 값
      expect(find.widgetWithText(TextField, 'A동'), findsOneWidget);
      expect(find.widgetWithText(TextField, '1번'), findsOneWidget);
      expect(find.widgetWithText(TextField, '2번'), findsOneWidget);
      expect(find.widgetWithText(TextField, '기존 메모'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '3/8"'))
            .selected,
        isTrue,
      );
      // 지금 설정 규격과 다르면 알린다(마킹 값은 지금 설정으로 셈한 것).
      expect(find.byKey(const Key('save_size_mismatch')), findsOneWidget);
    });

    testWidgets('덮어쓰면 그 줄만 고치고 다른 칸은 남기며, 되돌리기로 이전 값이 돌아온다', (tester) async {
      await open(tester, target: target());
      await tester.enterText(find.widgetWithText(TextField, '기존 메모'), '고친 메모');
      await tester.tap(find.text('덮어쓰기'));
      await tester.pumpAndSettle();

      expect(inserts, isEmpty);
      expect(updates.single.$1, 7);
      final row = updates.single.$2;
      final p = jsonDecode(row['p_to_p'] as String) as Map<String, dynamic>;
      expect(p['project'], 'A동');
      expect(p['from'], '1번');
      expect(p['note'], '고친 메모');
      expect(p['memo'], '고친 메모');
      expect(p['custom'], 9); // 처음 저장 때 있던 다른 칸은 그대로
      expect(p['start_dir'], 'RIGHT'); // 지금 방향으로
      expect(p['start_fit'], true);
      expect(p['tail'], 25.0);
      expect(
        p['specs'],
        tubeSpecsSnapshot(MachineSpecs()),
      ); // 지금 장비 값으로 다시 셈한 도면
      expect(row['pipe_size'], '3/8"');
      expect(row['total_length'], 617.5);
      expect(row['date'], isNot('2026-09-21 10:05'));
      expect(find.text('도면을 덮어썼습니다: 1번 ➔ 2번'), findsOneWidget);
      expect(find.text('보관함 보기'), findsNothing);

      updates.clear();
      await tester.tap(find.text('되돌리기'));
      await tester.pumpAndSettle();
      expect(updates.single.$1, 7);
      expect(updates.single.$2['p_to_p'], _row()['p_to_p']);
      expect(updates.single.$2['date'], '2026-09-21 10:05');
      expect(updates.single.$2['bend_data'], _row()['bend_data']);
      expect(updates.single.$2['total_length'], 500.0);
    });

    testWidgets('"새 도면으로 저장"을 고르면 덮어쓰지 않고 새 줄을 더한다', (tester) async {
      MobileBendDataManager().setSource(7);
      addTearDown(MobileBendDataManager().clearSource);
      await open(tester, target: target());
      await tester.tap(find.byKey(const Key('save_mode_new')));
      await tester.pumpAndSettle();
      expect(find.text('덮어쓸 도면: 1번 ➔ 2번 · 2026-09-21 10:05'), findsNothing);
      expect(find.text('저장'), findsOneWidget);
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(updates, isEmpty);
      expect(inserts.length, 1);
      expect(find.text('보관함에 저장했습니다.'), findsOneWidget);
      // 다음 저장의 덮어쓰기 대상은 방금 새로 저장한 도면(처음 불러온 7번 원본이 아니다).
      expect(MobileBendDataManager().sourceHistoryId, 99);
    });

    testWidgets('덮어쓰기가 실패하면 알리고 창을 그대로 둔다', (tester) async {
      TubeHistoryDb.update = (id, row) async => throw Exception('디스크 가득');
      await open(tester, target: target());
      await tester.tap(find.text('덮어쓰기'));
      await tester.pumpAndSettle();
      expect(find.text('저장하지 못했습니다. 다시 시도하십시오.'), findsOneWidget);
      expect(find.text('덮어쓰기'), findsOneWidget); // 창이 그대로
    });

    testWidgets('불러온 도면이 없으면 고르기 없이 늘 새 도면으로 저장한다', (tester) async {
      await open(tester);
      expect(find.byKey(const Key('save_mode_overwrite')), findsNothing);
      expect(find.text('저장'), findsOneWidget);
    });
  });

  group('마킹 탭의 저장 단추', () {
    Future<void> pumpTab(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MobileResultTab(startDir: 'RIGHT')),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('불러온 도면이 보관함에 있으면 덮어쓰기를 고를 수 있다', (tester) async {
      MobileBendDataManager().setSource(7);
      await pumpTab(tester);
      await tester.tap(find.byKey(const Key('tube_save_drawing')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('save_mode_overwrite')), findsOneWidget);
      expect(find.text('덮어쓸 도면: 1번 ➔ 2번 · 2026-09-21 10:05'), findsOneWidget);
    });

    testWidgets('불러온 도면이 보관함에서 지워졌으면 원본 기억을 버리고 새로 저장한다', (tester) async {
      TubeHistoryDb.load = () async => [];
      MobileBendDataManager().setSource(7);
      await pumpTab(tester);
      await tester.tap(find.byKey(const Key('tube_save_drawing')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('save_mode_overwrite')), findsNothing);
      expect(MobileBendDataManager().sourceHistoryId, isNull);
    });

    testWidgets('불러온 도면이 없으면 평소처럼 저장 창만 뜬다', (tester) async {
      await pumpTab(tester);
      await tester.tap(find.byKey(const Key('tube_save_drawing')));
      await tester.pumpAndSettle();
      expect(find.text('보관함에 저장'), findsOneWidget);
      expect(find.byKey(const Key('save_mode_overwrite')), findsNothing);
    });
  });
}
