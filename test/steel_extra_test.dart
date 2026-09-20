import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/models/steel_cutting_project_model.dart';
import 'package:tubing_calculator/src/data/models/steel_shape_db.dart';
import 'package:tubing_calculator/src/presentation/steel_cutting/screens/steel_cutting_detail_screen.dart';
import 'package:tubing_calculator/src/presentation/steel_cutting/screens/steel_cutting_history_page.dart';
import 'package:tubing_calculator/src/presentation/steel_cutting/steel_custom_shapes.dart';
import 'package:tubing_calculator/src/presentation/steel_cutting/steel_result_logic.dart';
import 'package:tubing_calculator/src/presentation/steel_cutting/steel_weight.dart';
import 'package:tubing_calculator/src/presentation/steel_cutting/widgets/steel_item_sheet.dart';
import 'package:tubing_calculator/src/presentation/steel_cutting/widgets/steel_shape_picker_sheet.dart';

import 'helpers_text.dart';

// 형강 컷팅 2차: 이론 중량, 내 규격(직접 입력한 규격 저장), 변경 기록 규격 칩.
SteelCutItem item(
  String shape,
  double len,
  int qty, {
  String cat = 'ANGLE',
  String? id,
}) => SteelCutItem(
  id: id ?? '$shape-$len-$qty',
  category: cat,
  shapeLabel: shape,
  length: len,
  qty: qty,
);

void main() {
  group('이론 중량', () {
    test('표에 있는 앵글·찬넬은 KS 단위중량 그대로', () {
      expect(steelKgPerM('앵글 40x40x3'), 1.83);
      expect(steelKgPerM('앵글 50x50x5'), 3.77);
      expect(steelKgPerM('찬넬 100x50x5'), 9.36);
      expect(steelKgPerM('찬넬 300x90x10'), 43.8);
    });

    test('계산식 결과가 표와 3% 안쪽으로 맞는다(직접 입력한 앵글도 계산된다)', () {
      // 표에 없는 "앵글 50x50x6": 6×(100−6)×0.00785 = 4.43(표 4.43).
      expect(steelKgPerM('앵글 50x50x6')!, closeTo(4.43, 0.05));
      // 표에 있는 값과 식 값이 3% 안쪽인지(식이 엉뚱하지 않은지 확인).
      for (final s in SteelShapeDB.angles) {
        final size = s.label.replaceFirst('앵글 ', '');
        final n = size.split('x').map(double.parse).toList();
        final formula = n[2] * (n[0] + n[1] - n[2]) * 0.00785;
        expect(
          (steelKgPerM(s.label)! - formula).abs() / formula,
          lessThan(0.03),
          reason: s.label,
        );
      }
    });

    test('각파이프·평철·환봉·강관·H형강 값', () {
      expect(steelKgPerM('각파이프 50x50x2.3')!, closeTo(3.44, 0.02));
      expect(steelKgPerM('평철 50x6')!, closeTo(2.355, 0.01));
      expect(steelKgPerM('환봉 Φ12')!, closeTo(0.888, 0.01));
      expect(steelKgPerM('강관 25A(34.0)'), 2.43);
      expect(steelKgPerM('H형강 100x100x6x8')!, closeTo(16.5, 0.3));
      expect(steelKgPerM('전산볼트 M10')!, closeTo(0.5, 0.1));
    });

    test('목록에 있는 규격은 전부 무게가 계산된다', () {
      for (final s in SteelShapeDB.all) {
        final kg = steelKgPerM(s.label);
        expect(kg, isNotNull, reason: s.label);
        expect(kg! > 0.15 && kg < 120, true, reason: '${s.label} $kg');
      }
    });

    test('모르는 이름은 null, 길이를 곱한다', () {
      expect(steelKgPerM('내 마음대로 규격'), isNull);
      expect(steelKgPerM(''), isNull);
      expect(steelKgPerM('앵글 abc'), isNull);
      expect(steelWeightKg('앵글 40x40x3', 2000)!, closeTo(3.66, 0.001));
      expect(steelWeightKg('몰라', 2000), isNull);
    });

    test('표기: 100kg 미만은 소수 한 자리, 이상은 정수', () {
      expect(fmtKg(4.209), '4.2');
      expect(fmtKg(99.94), '99.9');
      expect(fmtKg(123.4), '123');
    });

    test('규격별·전체 무게 합계와 모르는 규격 수', () {
      final lines = buildSteelResultLines([
        item('앵글 40x40x3', 1000, 2),
        item('내 규격 하나', 500, 1, cat: 'CUSTOM'),
      ], 1);
      final w = weightTotals(lines);
      expect(w.bySpec.keys, ['앵글 40x40x3']);
      expect(w.total!, closeTo(3.66, 0.001));
      expect(w.unknownSpecs, 1);
      final none = weightTotals(
        buildSteelResultLines([item('가나다', 500, 1, cat: 'CUSTOM')], 1),
      );
      expect(none.total, isNull);
    });

    test('지시서 글에 규격 소계와 총 중량이 들어간다', () {
      final lines = buildSteelResultLines([
        item('앵글 40x40x3', 1000, 2),
        item('가나다', 500, 1, cat: 'CUSTOM'),
      ], 3);
      final text = buildSteelInstructionText(
        projectName: 'P',
        date: DateTime(2026, 9, 20),
        sets: 3,
        lines: lines,
      );
      // 앵글 6000mm × 1.83 = 10.98kg
      expect(text.contains('소계 6000.0mm (6개) · 약 11.0kg'), true, reason: text);
      expect(text.contains('총 중량 약 11.0kg'), true, reason: text);
      expect(text.contains('중량을 모르는 규격 1종 제외'), true, reason: text);
    });
  });

  group('형강 화면 중량', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    SteelCuttingProject proj({int sets = 1}) => SteelCuttingProject(
      id: 'sp2',
      name: '루마',
      createdAt: DateTime(2026, 9, 20),
      setMultiplier: sets,
      items: [
        item('앵글 40x40x3', 500, 3, id: 'a'),
        item('앵글 40x40x3', 800, 1, id: 'b'),
        item('스트럿 41x41x2.5', 1000, 3, cat: 'STRUT', id: 'c'),
      ],
    );

    Future<void> open(WidgetTester tester, SteelCuttingProject p) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(home: SteelCuttingDetailScreen(project: p)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('결과'));
      await tester.pumpAndSettle();
    }

    testWidgets('결과 창에 규격별·총 중량이 보인다', (tester) async {
      await open(tester, proj());
      // 앵글 2300mm × 1.83 = 4.2kg, 스트럿 3000mm × 2.61 = 7.8kg, 합 12.0kg
      expect(findTextContaining('앵글 40x40x3  약 4.2kg'), findsOneWidget);
      expect(findTextContaining('스트럿 41x41x2.5  약 7.8kg'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('result_weight'))).data,
        '총 중량 약 12.0kg',
      );
    });

    testWidgets('세트를 늘리면 무게도 그 배수', (tester) async {
      await open(tester, proj(sets: 3));
      expect(
        tester.widget<Text>(find.byKey(const Key('result_weight'))).data,
        '총 중량 약 36.1kg',
      );
    });
  });

  group('내 규격', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('저장은 앞에 넣고 같은 이름은 하나로, 공백은 정리, 지우기', () async {
      await addCustomSteelShape('앵글 50x50x6');
      await addCustomSteelShape('  C찬넬   100x50  ');
      await addCustomSteelShape('앵글 50x50x6');
      await addCustomSteelShape('   ');
      expect(await loadCustomSteelShapes(), ['앵글 50x50x6', 'C찬넬 100x50']);
      expect(await removeCustomSteelShape('앵글 50x50x6'), ['C찬넬 100x50']);
      expect(await loadCustomSteelShapes(), ['C찬넬 100x50']);
    });

    test('최대 개수를 넘으면 오래된 것부터 버린다', () async {
      for (var i = 0; i < kMaxCustomSteelShapes + 5; i++) {
        await addCustomSteelShape('규격 $i');
      }
      final list = await loadCustomSteelShapes();
      expect(list.length, kMaxCustomSteelShapes);
      expect(list.first, '규격 ${kMaxCustomSteelShapes + 4}');
    });

    Future<void> openPicker(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => SteelShapePickerSheet.show(context),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
    }

    testWidgets('저장한 규격이 없으면 "내 규격" 칩이 없다', (tester) async {
      await openPicker(tester);
      expect(find.text('내 규격'), findsNothing);
    });

    testWidgets('저장한 규격은 "내 규격" 칩과 목록 맨 위에 나온다', (tester) async {
      SharedPreferences.setMockInitialValues({
        kCustomSteelShapesPrefsKey: ['앵글 50x50x6', '내 브래킷'],
      });
      await openPicker(tester);
      expect(find.text('내 규격'), findsOneWidget);
      expect(find.text('내 브래킷'), findsOneWidget);
      final total = SteelShapeDB.all.length + 2;
      expect(
        tester.widget<Text>(find.byKey(const Key('steel_pick_count'))).data,
        '$total개',
      );
      await tester.tap(find.text('내 규격'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('steel_pick_count'))).data,
        '2개',
      );
    });

    testWidgets('지우기는 확인을 거치고, 다 지우면 칩이 사라진다', (tester) async {
      SharedPreferences.setMockInitialValues({
        kCustomSteelShapesPrefsKey: ['내 브래킷'],
      });
      await openPicker(tester);
      await tester.tap(find.byKey(const Key('custom_remove_내 브래킷')));
      await tester.pumpAndSettle();
      // 취소하면 그대로
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(find.text('내 브래킷'), findsOneWidget);
      await tester.tap(find.byKey(const Key('custom_remove_내 브래킷')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('custom_remove_confirm')));
      await tester.pumpAndSettle();
      expect(find.text('내 브래킷'), findsNothing);
      expect(find.text('내 규격'), findsNothing);
      expect(await loadCustomSteelShapes(), isEmpty);
    });

    testWidgets('"C찬넬"로 찾으면 찬넬과 립C형강이 함께 나온다', (tester) async {
      await openPicker(tester);
      await tester.enterText(find.byType(TextField).last, 'C찬넬');
      await tester.pumpAndSettle();
      final n =
          SteelShapeDB.byCategory('CHANNEL').length +
          SteelShapeDB.byCategory('LIPC').length;
      expect(
        tester.widget<Text>(find.byKey(const Key('steel_pick_count'))).data,
        '$n개',
      );
      await tester.enterText(find.byType(TextField).last, 'c 찬넬 100');
      await tester.pumpAndSettle();
      expect(find.text('찬넬 100x50x5'), findsOneWidget);
    });

    testWidgets('직접 입력해서 항목을 추가하면 내 규격에 저장된다', (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      final saved = <SteelCutItem>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showSteelItemSheet(context, onSave: saved.add),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('탭해서 규격 선택'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('목록에 없는 규격 직접 입력'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '앵글 50x50x6');
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('steel_length_field')),
        '1200',
      );
      await tester.pump();
      await tester.tap(find.text('추가하고 닫기'));
      await tester.pumpAndSettle();
      expect(saved.single.shapeLabel, '앵글 50x50x6');
      expect(saved.single.category, 'CUSTOM');
      expect(await loadCustomSteelShapes(), ['앵글 50x50x6']);
    });
  });

  group('변경 기록', () {
    SteelChangeLogEntry e(String id, String action, String shape, DateTime t) =>
        SteelChangeLogEntry(
          id: id,
          action: action,
          category: 'ANGLE',
          shapeLabel: shape,
          length: 500,
          qty: 2,
          timestamp: t,
        );

    // 최신순(서버에서 받는 순서).
    final entries = [
      e('4', 'EDIT', '앵글 40x40x3', DateTime(2026, 9, 21, 10)),
      e('3', 'ADD', '찬넬 100x50x5', DateTime(2026, 9, 20, 15)),
      e('2', 'ADD', '앵글 40x40x3', DateTime(2026, 9, 20, 9)),
      e('1', 'ADD', '앵글 25x25x3', DateTime(2026, 9, 19, 9)),
    ];

    test('규격 목록은 오래된 것부터 처음 나온 순서, 거르기', () {
      expect(steelHistoryShapes(entries), [
        '앵글 25x25x3',
        '앵글 40x40x3',
        '찬넬 100x50x5',
      ]);
      expect(filterSteelHistory(entries, null).length, 4);
      expect(filterSteelHistory(entries, '앵글 40x40x3').map((x) => x.id), [
        '4',
        '2',
      ]);
    });

    Future<void> open(
      WidgetTester tester,
      List<SteelChangeLogEntry> list,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SteelHistoryView(entries: list)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('규격 칩을 누르면 그 규격이 있는 날만 남는다', (tester) async {
      await open(tester, entries);
      expect(findTextContaining('1 / 3일'), findsOneWidget);
      final chan = find.byKey(const Key('steel_history_shape_찬넬 100x50x5'));
      await tester.ensureVisible(chan);
      await tester.tap(chan);
      await tester.pumpAndSettle();
      expect(findTextContaining('1 / 1일'), findsOneWidget);
      expect(findText('추가 1건'), findsOneWidget);
      final all = find.byKey(const Key('steel_history_shape_all'));
      await tester.ensureVisible(all);
      await tester.tap(all);
      await tester.pumpAndSettle();
      expect(findTextContaining('1 / 3일'), findsOneWidget);
    });

    testWidgets('규격이 하나뿐이면 칩을 두지 않는다', (tester) async {
      await open(tester, [entries[0], entries[2]]);
      expect(find.byKey(const Key('steel_history_shape_all')), findsNothing);
    });

    testWidgets('기록이 없으면 안내 글', (tester) async {
      await open(tester, const []);
      expect(find.text('아직 변경 기록이 없습니다.'), findsOneWidget);
    });
  });

  group('프로젝트 무게·형태 설명', () {
    SteelCuttingProject p(List<SteelCutItem> items, {int sets = 1}) =>
        SteelCuttingProject(
          id: 'x',
          name: 'x',
          createdAt: DateTime(2026, 9, 20),
          setMultiplier: sets,
          items: items,
        );

    test('목록 줄 무게: 세트를 곱하고, 모르는 규격이 있으면 이상', () {
      expect(
        steelProjectWeightText(p([item('앵글 40x40x3', 1000, 2)])),
        '약 3.7kg',
      );
      expect(
        steelProjectWeightText(p([item('앵글 40x40x3', 1000, 2)], sets: 3)),
        '약 11.0kg',
      );
      expect(
        steelProjectWeightText(
          p([item('앵글 40x40x3', 1000, 2), item('가나다', 500, 1, cat: 'CUSTOM')]),
        ),
        '약 3.7kg 이상',
      );
      expect(
        steelProjectWeightText(p([item('가나다', 500, 1, cat: 'CUSTOM')])),
        '',
      );
      expect(steelProjectWeightText(p(const [])), '');
    });

    test('찬넬 형태 설명: 경량은 립 없음, 열간압연·앵글은 빈 글자, 립C는 립 있음', () {
      expect(steelShapeNote('찬넬 40x20x1.6'), '립 없는 ㄷ형 (립 있으면 립C형강)');
      expect(steelShapeNote('찬넬 200x75x3.2'), '립 없는 ㄷ형 (립 있으면 립C형강)');
      expect(steelShapeNote('찬넬 100x50x5'), '');
      expect(steelShapeNote('앵글 40x40x3'), '');
      expect(steelShapeNote('립C형강 100x50x20x2.3'), '립 있는 C형');
    });

    testWidgets('규격 선택창에 찬넬 형태 설명이 보인다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => SteelShapePickerSheet.show(context),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('찬넬').first);
      await tester.pumpAndSettle();
      expect(findText('찬넬 · 립 없는 ㄷ형 (립 있으면 립C형강)'), findsWidgets);
    });
  });

  group('모두 잘랐음과 남는 토막 저장', () {
    SteelCuttingProject proj() => SteelCuttingProject(
      id: 'sp3',
      name: '루마',
      createdAt: DateTime(2026, 9, 20),
      items: [item('앵글 40x40x3', 500, 2, id: 'a')],
    );

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(home: SteelCuttingDetailScreen(project: proj())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('결과'));
      await tester.pumpAndSettle();
    }

    String progress(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(const Key('result_progress'))).data!;

    testWidgets('전부 잘랐으면 튜브용 "저장하십시오" 대신 토막 안내와 버튼', (tester) async {
      SharedPreferences.setMockInitialValues({
        'steel_done_sp3': ['steel:앵글 40x40x3:500.0:2'],
      });
      await open(tester);
      expect(progress(tester), '모두 잘랐습니다.');
      expect(find.byKey(const Key('result_done_action')), findsOneWidget);
      // 다 자르지 않았으면 진행 글과 버튼이 없다.
    });

    testWidgets('전부 자르지 않았으면 진행 글만', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await open(tester);
      expect(progress(tester), '잘랐음 0/2개');
      expect(find.byKey(const Key('result_done_action')), findsNothing);
    });

    testWidgets('버튼으로 재단 최적화를 열어 저장하면 안내가 바뀌고 저장 표시가 남는다', (tester) async {
      SharedPreferences.setMockInitialValues({
        'steel_done_sp3': ['steel:앵글 40x40x3:500.0:2'],
      });
      await open(tester);
      await tester.tap(find.byKey(const Key('result_done_action')));
      await tester.pumpAndSettle();
      expect(find.text('재단 최적화 (원자재 소요 계산)'), findsOneWidget);
      final save = find.text('잘랐습니다 (남는 토막 저장)');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      // 창을 닫는다.
      await tester.tapAt(const Offset(180, 20));
      await tester.pumpAndSettle();
      expect(progress(tester), '모두 잘랐습니다. 남는 토막도 저장했습니다.');
      expect(find.byKey(const Key('result_done_action')), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('steel_leftover_saved_sp3'),
        'steel:앵글 40x40x3:500.0:2',
      );
    });

    testWidgets('재단 최적화에서 잘랐습니다를 누르면 결과의 모든 줄이 잘랐음이 된다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await open(tester);
      await tester.tap(find.byKey(const Key('steel_btn_optimize')));
      await tester.pumpAndSettle();
      final save = find.text('잘랐습니다 (남는 토막 저장)');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(180, 20));
      await tester.pumpAndSettle();
      expect(progress(tester), '모두 잘랐습니다. 남는 토막도 저장했습니다.');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('steel_done_sp3'), [
        'steel:앵글 40x40x3:500.0:2',
      ]);
    });
  });

  group('아이콘 줄·토막 중복 저장·립C 규격', () {
    SteelCuttingProject proj() => SteelCuttingProject(
      id: 'sp4',
      name: '루마',
      createdAt: DateTime(2026, 9, 20),
      items: [item('앵글 40x40x3', 500, 2, id: 'a')],
    );

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(home: SteelCuttingDetailScreen(project: proj())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('결과'));
      await tester.pumpAndSettle();
    }

    testWidgets('아이콘 버튼은 36dp로 작고 카톡도 노란색이 아니다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await open(tester);
      for (final k in [
        'steel_btn_optimize',
        'steel_btn_export',
        'steel_btn_kakao',
        'steel_btn_copy',
      ]) {
        expect(
          tester.getSize(find.byKey(Key(k))),
          const Size(36, 36),
          reason: k,
        );
      }
      expect(
        find.byWidgetPredicate(
          (w) => w is Material && w.color == const Color(0xFFFEE500),
        ),
        findsNothing,
      );
    });

    testWidgets('이미 저장한 결과는 재단 최적화에서 저장 버튼 대신 "저장했습니다"', (tester) async {
      SharedPreferences.setMockInitialValues({
        'steel_done_sp4': ['steel:앵글 40x40x3:500.0:2'],
        'steel_leftover_saved_sp4': 'steel:앵글 40x40x3:500.0:2',
      });
      await open(tester);
      await tester.tap(find.byKey(const Key('steel_btn_optimize')));
      await tester.pumpAndSettle();
      expect(find.text('저장했습니다'), findsOneWidget);
      expect(find.text('잘랐습니다 (남는 토막 저장)'), findsNothing);
    });

    testWidgets('저장하지 않은 결과는 저장 버튼이 있다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await open(tester);
      await tester.tap(find.byKey(const Key('steel_btn_optimize')));
      await tester.pumpAndSettle();
      expect(find.text('잘랐습니다 (남는 토막 저장)'), findsOneWidget);
    });

    test('립C형강 규격이 늘었고 모두 무게가 계산된다', () {
      final lip = SteelShapeDB.byCategory('LIPC');
      expect(lip.length, 10);
      expect(lip.any((s) => s.label == '립C형강 100x50x20x2.0'), true);
      // 2.0×(100+2×50+2×20−4×2)=464mm² → 3.64kg/m
      expect(steelKgPerM('립C형강 100x50x20x2.0')!, closeTo(3.64, 0.01));
      for (final s in lip) {
        expect(steelKgPerM(s.label), isNotNull, reason: s.label);
      }
    });
  });
}
