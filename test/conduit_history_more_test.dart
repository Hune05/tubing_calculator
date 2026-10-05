// 전선관 보관함: 검색·폴더 접기, 불러올 때 장비 설정 비교, 도면 이름·메모 고치기.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/conduit_drawings.dart';
import 'package:tubing_calculator/src/data/models/conduit_data_manager.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_history_tab.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_settings_diff.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_settings_page.dart'
    show globalBenderSettings;

Map<String, dynamic> b(double len, double angle, [double rot = 0]) => {
  'length': len,
  'angle': angle,
  'rotation': rot,
};

void main() {
  late Map<String, dynamic> originalSettings;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    originalSettings = Map<String, dynamic>.from(globalBenderSettings.value);
    final m = ConduitDataManager();
    m.bendList
      ..clear()
      ..add(b(100, 0));
    m.clearHistory();
    m.clearSource();
  });
  tearDown(() => globalBenderSettings.value = originalSettings);

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openTab(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(420, 2400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: ConduitHistoryTab()));
    await settle(tester);
  }

  Future<ConduitDrawing> seed(
    String folder,
    String title, {
    String notes = '',
    Map<String, dynamic> settings = const {},
  }) async {
    final d = await saveConduitDrawing(
      folderName: folder,
      title: title,
      totalCut: 500,
      bends: [b(300, 90)],
      notes: notes,
      settings: settings,
    );
    await Future<void>.delayed(const Duration(milliseconds: 2));
    return d;
  }

  Future<ConduitDrawing> seedW(
    WidgetTester tester,
    String folder,
    String title, {
    String notes = '',
    Map<String, dynamic> settings = const {},
  }) async => (await tester.runAsync(
    () => seed(folder, title, notes: notes, settings: settings),
  ))!;

  group('설정 비교', () {
    test('다른 항목만 글로, 같거나 저장 때 없던 항목은 건너뛴다', () {
      final diffs = conduitSettingDiffs(
        {'benderType': 'hand', 'gain': 70.0, 'clr': 114.3, 'conduitSize': '22mm'},
        {
          'benderType': 'ram',
          'gain': 81.2,
          'clr': 114.31,
          'conduitSize': '22mm',
          'takeUp': 152.4,
        },
      );
      expect(diffs, ['벤더 종류: 저장 때 수동 → 지금 유압식', '게인: 저장 때 70 → 지금 81.2']);
      expect(conduitSettingDiffs({}, {'gain': 1.0}), isEmpty);
    });
  });

  group('저장소', () {
    test('이름·메모만 고치고 이전 도면을 돌려준다', () async {
      final d = await seed('A', 'a', notes: 'n', settings: {'gain': 70.0});
      final before = await updateConduitDrawingInfo(
        id: d.id,
        folderName: 'B',
        title: ' 새 ',
        notes: '',
      );
      expect(before!.folderName, 'A');
      final after = (await loadConduitDrawings()).single;
      expect(
        [after.folderName, after.title, after.notes],
        ['B', '새', ''],
      );
      expect(after.date, d.date);
      expect(after.settings['gain'], 70.0);
      expect(after.bends.length, 1);
      await replaceConduitDrawing(before);
      expect((await loadConduitDrawings()).single.title, 'a');
      expect(
        await updateConduitDrawingInfo(
          id: 'none',
          folderName: 'x',
          title: 'x',
          notes: '',
        ),
        isNull,
      );
    });
  });

  group('화면', () {
    testWidgets('검색은 작업·도면 이름·메모로 거르고 모두 펼친다', (tester) async {
      await seedW(tester, 'A동', '보일러 배관', notes: '엘보 교체');
      await seedW(tester, 'B동', '펌프실');
      await openTab(tester);
      expect(find.text('보일러 배관'), findsOneWidget);
      expect(find.text('펌프실'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('conduit_search_field')), '엘보');
      await tester.pumpAndSettle();
      expect(find.text('보일러 배관'), findsOneWidget);
      expect(find.text('펌프실'), findsNothing);

      await tester.enterText(find.byKey(const Key('conduit_search_field')), '없는말');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('conduit_search_empty')), findsOneWidget);

      await tester.tap(find.byKey(const Key('conduit_search_clear')));
      await tester.pumpAndSettle();
      expect(find.text('펌프실'), findsOneWidget);
    });

    testWidgets('작업 줄을 누르면 접고 다시 누르면 펼친다', (tester) async {
      await seedW(tester, 'A동', '보일러 배관');
      await seedW(tester, 'B동', '펌프실');
      await openTab(tester);
      await tester.tap(find.byKey(const ValueKey('conduit_folder_toggle_A동')));
      await tester.pumpAndSettle();
      expect(find.text('보일러 배관'), findsNothing);
      expect(find.text('펌프실'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('conduit_folder_toggle_A동')));
      await tester.pumpAndSettle();
      expect(find.text('보일러 배관'), findsOneWidget);
    });

    testWidgets('불러올 때 다른 설정을 알리지만 설정은 안 바꾼다', (tester) async {
      globalBenderSettings.value = {
        ...globalBenderSettings.value,
        'gain': 81.2,
        'conduitSize': '22mm',
      };
      await seedW(tester, 'A', 'a', settings: {'gain': 70.0, 'conduitSize': '16mm'});
      await openTab(tester);
      await tester.tap(find.text('계산기로 불러오기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('불러오기'));
      await tester.pumpAndSettle();
      expect(find.text('장비 설정이 다릅니다'), findsOneWidget);
      expect(find.text('규격: 저장 때 16mm → 지금 22mm'), findsOneWidget);
      expect(find.text('게인: 저장 때 70 → 지금 81.2'), findsOneWidget);
      await tester.tap(find.byKey(const Key('conduit_diff_ok')));
      await tester.pumpAndSettle();
      expect(globalBenderSettings.value['gain'], 81.2);
      expect(ConduitDataManager().bendList.length, 1);
    });

    testWidgets('설정이 같으면 알림 창 없이 불러온다', (tester) async {
      await seedW(tester, 'A', 'a', settings: Map.of(globalBenderSettings.value));
      await openTab(tester);
      await tester.tap(find.text('계산기로 불러오기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('불러오기'));
      await tester.pumpAndSettle();
      expect(find.text('장비 설정이 다릅니다'), findsNothing);
    });

    testWidgets('연필로 이름·메모를 고치고 되돌린다', (tester) async {
      final d = await seedW(tester, 'A동', '옛 이름', notes: '옛 메모');
      await openTab(tester);
      await tester.tap(find.byKey(ValueKey('conduit_edit_${d.id}')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('conduit_edit_title')), '새 이름');
      await tester.enterText(find.byKey(const Key('conduit_edit_notes')), '새 메모');
      await tester.enterText(find.byKey(const Key('conduit_edit_folder')), 'C동');
      await tester.tap(find.byKey(const Key('conduit_edit_ok')));
      await settle(tester);
      expect(find.text('새 이름'), findsOneWidget);
      expect(find.text('새 메모'), findsOneWidget);
      var saved = (await tester.runAsync(loadConduitDrawings))!.single;
      expect(saved.folderName, 'C동');

      await tester.tap(find.text('되돌리기'));
      await settle(tester);
      saved = (await tester.runAsync(loadConduitDrawings))!.single;
      expect([saved.folderName, saved.title, saved.notes], ['A동', '옛 이름', '옛 메모']);
    });

    testWidgets('도면 이름을 비우면 저장되지 않는다', (tester) async {
      final d = await seedW(tester, 'A', 'a');
      await openTab(tester);
      await tester.tap(find.byKey(ValueKey('conduit_edit_${d.id}')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('conduit_edit_title')), '  ');
      await tester.tap(find.byKey(const Key('conduit_edit_ok')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('conduit_edit_title')), findsOneWidget);
    });
  });
}
