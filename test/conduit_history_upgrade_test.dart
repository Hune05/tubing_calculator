// 전선관 보관함: 폴더(작업 이름) 바꾸기·합치기, 불러와 고친 도면 덮어쓰기, 카드의 굽힘 요약.
import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/presentation/conduit/conduit_field_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/conduit_drawings.dart';
import 'package:tubing_calculator/src/data/models/conduit_data_manager.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/history_card_info.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_history_tab.dart';
import 'package:tubing_calculator/src/presentation/conduit/widgets/conduit_save_dialog.dart';

Map<String, dynamic> b(double len, double angle, [double rot = 0]) => {
  'length': len,
  'angle': angle,
  'rotation': rot,
};

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final m = ConduitDataManager();
    m.bendList
      ..clear()
      ..add(b(100, 0));
    m.clearHistory();
    m.clearSource();
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  group('굽힘 요약', () {
    test('각도 목록을 한 줄로', () {
      expect(bendShapeSummary([0, 90, 45]), '굽힘 2개 (90°, 45°)');
      expect(bendShapeSummary([0, 0]), '직관만');
      expect(bendShapeSummary([22.5]), '굽힘 1개 (22.5°)');
      expect(
        bendShapeSummary([10, 20, 30, 40, 50, 60, 70]),
        '굽힘 7개 (10°, 20°, 30°, 40°, 50°, 60° …)',
      );
    });
  });

  group('저장소', () {
    test('작업 이름을 한 번에 바꾸고 되돌린다(빈 이름은 미분류)', () async {
      final a = await saveConduitDrawing(
        folderName: 'A구역',
        title: 'a',
        totalCut: 1,
        bends: [b(1, 0)],
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final c = await saveConduitDrawing(
        folderName: 'B구역',
        title: 'c',
        totalCut: 1,
        bends: [b(1, 0)],
      );
      await setConduitFolders({a.id: 'B구역'});
      var list = await loadConduitDrawings();
      expect(list.map((d) => d.folderName), ['B구역', 'B구역']);
      expect(list.firstWhere((d) => d.id == a.id).title, 'a'); // 다른 칸은 그대로

      await setConduitFolders({a.id: 'A구역', c.id: '  '});
      list = await loadConduitDrawings();
      expect(list.firstWhere((d) => d.id == a.id).folderName, 'A구역');
      expect(list.firstWhere((d) => d.id == c.id).folderName, '미분류 도면');
    });

    test('덮어쓰기는 번호를 그대로 두고 이전 도면을 돌려주며, 되돌려 쓸 수 있다', () async {
      final a = await saveConduitDrawing(
        folderName: 'A구역',
        title: '원본',
        totalCut: 100,
        bends: [b(100, 0)],
        notes: '원본 메모',
        settings: {'conduitSize': '3/4"'},
      );
      final before = await overwriteConduitDrawing(
        id: a.id,
        folderName: 'A구역',
        title: '고친 도면',
        totalCut: 250,
        bends: [b(100, 90), b(150, 0)],
        notes: '고친 메모',
        settings: {'conduitSize': '1"'},
      );
      expect(before!.title, '원본');
      var list = await loadConduitDrawings();
      expect(list.length, 1);
      expect(list.single.id, a.id);
      expect(list.single.title, '고친 도면');
      expect(list.single.totalCut, 250);
      expect(list.single.bends.length, 2);
      expect(list.single.notes, '고친 메모');
      expect(list.single.settings['conduitSize'], '1"');

      await replaceConduitDrawing(before);
      list = await loadConduitDrawings();
      expect(list.single.title, '원본');
      expect(list.single.notes, '원본 메모');
      expect(list.single.bends.length, 1);
    });

    test('없는 도면에 덮어쓰면 아무것도 바꾸지 않고 null', () async {
      final a = await saveConduitDrawing(
        folderName: 'A구역',
        title: '원본',
        totalCut: 1,
        bends: [b(1, 0)],
      );
      final r = await overwriteConduitDrawing(
        id: 'nope',
        folderName: 'X',
        title: 'X',
        totalCut: 1,
        bends: const [],
      );
      expect(r, isNull);
      expect((await loadConduitDrawings()).single.id, a.id);
    });
  });

  group('불러온 도면 기억', () {
    test('불러온 뒤 고쳐도 기억하고, 불러오기를 되돌리거나 목록을 지우면 잊는다', () {
      final m = ConduitDataManager();
      m.replaceAll([b(100, 0), b(50, 90)]);
      m.setSource('abc');
      expect(m.sourceDrawingId, 'abc');

      m.addBend(b(30, 45));
      expect(m.undo(), isTrue);
      expect(m.sourceDrawingId, 'abc');

      expect(m.undo(), isTrue); // 불러오기 자체를 되돌림
      expect(m.sourceDrawingId, isNull);

      m.replaceAll([b(100, 0)]);
      m.setSource('def');
      m.clearBends();
      expect(m.sourceDrawingId, isNull);
    });
  });

  group('저장 창 덮어쓰기', () {
    Widget host() => MaterialApp(
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
    );

    Future<ConduitDrawing> seed(WidgetTester tester) async {
      final saved = await tester.runAsync(
        () => saveConduitDrawing(
          folderName: 'EPS실',
          title: '원본 도면',
          totalCut: 600,
          bends: [b(200, 45), b(300, 0)],
          notes: '원본 메모',
        ),
      );
      ConduitDataManager().replaceAll([b(300, 90), b(400, 0)]);
      ConduitDataManager().setSource(saved!.id);
      return saved;
    }

    Future<void> open(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(host());
      await tester.tap(find.text('열기'));
      await settle(tester);
    }

    testWidgets('불러온 도면이 있으면 덮어쓰기가 먼저 골라져 있고 그 값이 채워진다', (tester) async {
      final saved = await seed(tester);
      await open(tester);
      expect(find.byKey(const Key('save_mode_overwrite')), findsOneWidget);
      expect(find.text('덮어쓸 도면: 원본 도면 · ${saved.date}'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'EPS실'), findsOneWidget);
      expect(find.widgetWithText(TextField, '원본 도면'), findsOneWidget);
      expect(find.widgetWithText(TextField, '원본 메모'), findsOneWidget);
      expect(find.text('덮어쓰기'), findsOneWidget); // 단추 글자
    });

    testWidgets('덮어쓰면 그 도면만 고치고, 되돌리기로 이전 도면이 돌아온다', (tester) async {
      final saved = await seed(tester);
      await open(tester);
      await tester.enterText(
        find.byKey(const Key('conduit_save_title')),
        '수정한 도면',
      );
      await tester.tap(find.byKey(const Key('conduit_save_ok')));
      await settle(tester);

      var list = (await tester.runAsync(loadConduitDrawings))!;
      expect(list.length, 1);
      expect(list.single.id, saved.id);
      expect(list.single.title, '수정한 도면');
      expect(list.single.totalCut, 617.5);
      expect(list.single.bends.first['angle'], 90.0);
      expect(find.text('도면을 덮어썼습니다: 수정한 도면'), findsOneWidget);
      expect(find.text('보관함 보기'), findsNothing);

      await tester.tap(find.text('되돌리기'));
      await settle(tester);
      list = (await tester.runAsync(loadConduitDrawings))!;
      expect(list.single.title, '원본 도면');
      expect(list.single.bends.first['angle'], 45.0);
    });

    testWidgets('앱이 붙인 도면 이름이면 덮어쓸 때 새 길이로 갱신하고, 지은 이름은 그대로 둔다', (
      tester,
    ) async {
      final saved = await tester.runAsync(
        () => saveConduitDrawing(
          folderName: 'EPS실',
          title: '벤드 1개 · 600mm',
          totalCut: 600,
          bends: [b(200, 45), b(300, 0)],
        ),
      );
      ConduitDataManager().replaceAll([b(300, 90), b(400, 0)]);
      ConduitDataManager().setSource(saved!.id);
      await open(tester);
      // 현재 목록은 벤드 1개 · 618mm
      expect(find.widgetWithText(TextField, '벤드 1개 · 618mm'), findsOneWidget);
      await tester.tap(find.byKey(const Key('conduit_save_ok')));
      await settle(tester);
      final list = (await tester.runAsync(loadConduitDrawings))!;
      expect(list.single.title, '벤드 1개 · 618mm');
      expect(list.single.id, saved.id);
    });

    testWidgets('"새 도면으로 저장"을 고르면 덮어쓰지 않고 새 줄을 더하며 옛 이름은 쓰지 않는다', (
      tester,
    ) async {
      await seed(tester);
      await open(tester);
      await tester.tap(find.byKey(const Key('save_mode_new')));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, '벤드 1개 · 618mm'), findsOneWidget);
      expect(find.text('저장'), findsOneWidget);
      await tester.tap(find.byKey(const Key('conduit_save_ok')));
      await settle(tester);

      final list = (await tester.runAsync(loadConduitDrawings))!;
      expect(list.length, 2);
      expect(list.map((d) => d.title).toSet(), {'원본 도면', '벤드 1개 · 618mm'});
      expect(find.text('보관함에 저장했습니다.'), findsOneWidget);
      // 다음 저장의 덮어쓰기 대상은 방금 새로 저장한 도면(원본이 아니다).
      final fresh = list.firstWhere((d) => d.title == '벤드 1개 · 618mm');
      expect(ConduitDataManager().sourceDrawingId, fresh.id);
    });

    testWidgets('원본이 보관함에서 지워졌으면 기억을 버리고 새로 저장한다', (tester) async {
      final saved = await seed(tester);
      await tester.runAsync(() => deleteConduitDrawing(saved.id));
      await open(tester);
      expect(find.byKey(const Key('save_mode_overwrite')), findsNothing);
      expect(ConduitDataManager().sourceDrawingId, isNull);
    });

    testWidgets('저장을 두 번 눌러도 한 건만 덮어쓴다', (tester) async {
      await seed(tester);
      await open(tester);
      await tester.tap(find.byKey(const Key('conduit_save_ok')));
      await tester.tap(
        find.byKey(const Key('conduit_save_ok')),
        warnIfMissed: false,
      );
      await settle(tester);
      expect((await tester.runAsync(loadConduitDrawings))!.length, 1);
    });
  });

  group('보관함 탭', () {
    late ConduitDrawing a;

    Future<void> openTab(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      a = (await tester.runAsync(
        () => saveConduitDrawing(
          folderName: 'A구역',
          title: '첫 도면',
          totalCut: 600,
          bends: [b(200, 90), b(100, 45), b(50, 0)],
        ),
      ))!;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 3)),
      );
      await tester.runAsync(
        () => saveConduitDrawing(
          folderName: 'B구역',
          title: '직관 도면',
          totalCut: 300,
          bends: [b(300, 0)],
        ),
      );
      await tester.pumpWidget(const MaterialApp(home: ConduitHistoryTab()));
      await settle(tester);
    }

    Future<List<String>> folders(WidgetTester tester) async => [
      for (final d in (await tester.runAsync(loadConduitDrawings))!)
        d.folderName,
    ];

    testWidgets('카드에 굽힘 요약이 보인다', (tester) async {
      await openTab(tester);
      expect(find.text('굽힘 2개 (90°, 45°)'), findsOneWidget);
      expect(find.text('직관만'), findsOneWidget);
    });

    testWidgets('작업 이름을 바꾸면 그 폴더의 도면이 모두 바뀌고, 되돌리기로 돌아온다', (tester) async {
      await openTab(tester);
      await tester.tap(find.byKey(const ValueKey('conduit_folder_menu_A구역')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('folder_rename_field')),
        '신규구역',
      );
      await tester.tap(find.byKey(const Key('folder_rename_ok')));
      await settle(tester);
      expect((await folders(tester)).toSet(), {'신규구역', 'B구역'});
      expect(find.textContaining('작업 이름을 바꿨습니다: 신규구역 (1개)'), findsOneWidget);

      await tester.tap(find.text('되돌리기'));
      await settle(tester);
      expect((await folders(tester)).toSet(), {'A구역', 'B구역'});
    });

    testWidgets('이미 있는 이름으로 바꾸면 합쳐진다(칩으로 고른다)', (tester) async {
      await openTab(tester);
      await tester.tap(find.byKey(const ValueKey('conduit_folder_menu_A구역')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'B구역'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('folder_rename_ok')));
      await settle(tester);
      expect(await folders(tester), ['B구역', 'B구역']);
      expect(
        find.byKey(const ValueKey('conduit_folder_menu_A구역')),
        findsNothing,
      );
      expect(find.textContaining('작업을 합쳤습니다: B구역 (1개)'), findsOneWidget);
    });

    testWidgets('이름을 그대로 두면 아무 일도 없다', (tester) async {
      await openTab(tester);
      await tester.tap(find.byKey(const ValueKey('conduit_folder_menu_A구역')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('folder_rename_ok')));
      await settle(tester);
      expect((await folders(tester)).toSet(), {'A구역', 'B구역'});
    });

    testWidgets('계산기로 불러오면 그 도면을 기억한다', (tester) async {
      await openTab(tester);
      // 새것(B구역 도면)이 먼저, 첫 도면이 두 번째 카드
      await tester.tap(find.text('계산기로 불러오기').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('이 도면에 덮어쓸 수도 있습니다'), findsOneWidget);
      await tester.tap(find.text('불러오기'));
      await tester.pumpAndSettle();
      expect(ConduitDataManager().sourceDrawingId, a.id);
    });

    testWidgets('저장 때 시작 방향·커플링 체결을 남기고, 불러오면 되살린다', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(() {
        conduitStartDir.value = 'RIGHT';
        conduitUseCoupling.value = false;
      });
      final d = (await tester.runAsync(
        () => saveConduitDrawing(
          folderName: 'C구역',
          title: '위로 시작',
          totalCut: 400,
          bends: [b(200, 90), b(200, 0)],
          settings: const {'start_dir': 'UP', 'use_coupling': true},
        ),
      ))!;
      expect(d.settings['start_dir'], 'UP');
      conduitStartDir.value = 'RIGHT';
      conduitUseCoupling.value = false;
      await tester.pumpWidget(const MaterialApp(home: ConduitHistoryTab()));
      await settle(tester);
      await tester.tap(find.text('계산기로 불러오기').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('불러오기'));
      await tester.pumpAndSettle();
      expect(conduitStartDir.value, 'UP');
      expect(conduitUseCoupling.value, isTrue);
    });
  });
}
