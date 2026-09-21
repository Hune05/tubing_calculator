import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_action_bar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/models/steel_cutting_project_model.dart';
import 'package:tubing_calculator/src/data/models/steel_shape_db.dart';
import 'package:tubing_calculator/src/presentation/steel_cutting/screens/steel_cutting_detail_screen.dart';
import 'package:tubing_calculator/src/presentation/steel_cutting/screens/steel_cutting_history_page.dart';
import 'package:tubing_calculator/src/presentation/steel_cutting/screens/steel_pdf_preview_page.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_leftover_log.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_optimizer.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_leftovers.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/widgets/leftover_log_page.dart';
import 'package:tubing_calculator/src/presentation/steel_cutting/steel_custom_shapes.dart';
import 'package:tubing_calculator/src/presentation/steel_cutting/steel_group_ops.dart';
import 'package:tubing_calculator/src/presentation/steel_cutting/steel_multi_input.dart';
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
  // 잔재는 앱에서는 서버에 두지만, 테스트에서는 폰(prefs) 저장소로 바꿔 쓴다.
  leftoverStore = PrefsLeftoverStore();

  group('이론 중량', () {
    test('표에 있는 앵글·찬넬은 KS 단위중량 그대로', () {
      expect(steelKgPerM('앵글 40x40x3'), 1.83);
      expect(steelKgPerM('앵글 50x50x5'), 3.77);
      expect(steelKgPerM('찬넬 100x50x5'), 9.36);
      expect(steelKgPerM('찬넬 300x90x10'), 43.8);
    });

    test('규격을 ×·X·*·띄어쓰기로 적어도 같은 표를 찾는다', () {
      expect(steelKgPerM('찬넬 100×50×5'), 9.36);
      expect(steelKgPerM('찬넬 100X50X5'), 9.36);
      expect(steelKgPerM('찬넬 100 x 50 x 5'), 9.36);
      expect(steelKgPerM('앵글 40×40×3'), 1.83);
      expect(steelKgPerM('강관 25a'), 2.43);
      expect(steelShapeNote('찬넬 100×50×5'), '');
      expect(steelShapeNote('찬넬 100×50×3.2'), '립 없는 ㄷ형 (립 있으면 립C형강)');
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
      expect(steelKgPerM('각파이프 50x50x2.3')!, closeTo(3.34, 0.02));
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
        expect(kg! > 0.15 && kg < 150, true, reason: '${s.label} $kg');
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

  group('모두 잘랐음과 잔재 저장', () {
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

    testWidgets('전부 잘랐으면 "모두 잘랐습니다."만, 잔재 이야기는 없다', (tester) async {
      SharedPreferences.setMockInitialValues({
        'steel_done_sp3': ['steel:앵글 40x40x3:500.0:2'],
      });
      await open(tester);
      expect(progress(tester), '모두 잘랐습니다.');
      // 잔재 저장은 재단 계획 창에서만 한다 — 결과 탭에는 단추도, 저장 문구도 없다.
      expect(find.byKey(const Key('result_done_action')), findsNothing);
      expect(findTextContaining('잔재'), findsNothing);
    });

    testWidgets('전부 자르지 않았으면 진행 글만', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await open(tester);
      expect(progress(tester), '잘랐음 0/2개');
      expect(find.byKey(const Key('result_done_action')), findsNothing);
    });

    testWidgets('재단 계획 창에 재고에서 빼기 단추가 있다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await open(tester);
      await tester.tap(find.byKey(const Key('steel_btn_optimize')));
      await tester.pumpAndSettle();
      final btn = find.byKey(const Key('stock_deduct'));
      expect(btn, findsOneWidget);
      await tester.ensureVisible(btn);
      expect(find.text('재고에서 빼기'), findsOneWidget);
      // 누르지는 않는다 — 실제 창고 재고를 건드리는 동작이다.
    });

    testWidgets('이미 뺀 본수면 창을 다시 열어도 "뺐습니다"로 나온다', (tester) async {
      SharedPreferences.setMockInitialValues({
        'steel_stock_deducted_sp3': '앵글 40x40x3=1',
      });
      await open(tester);
      await tester.tap(find.byKey(const Key('steel_btn_optimize')));
      await tester.pumpAndSettle();
      // 같은 본수를 두 번 빼지 못하게 단추 대신 "뺐습니다"가 보인다.
      expect(find.byKey(const Key('stock_deduct')), findsNothing);
      expect(find.text('재고에서 뺐습니다'), findsOneWidget);
    });

    testWidgets('이미 뺐으면 되돌리기 단추가 같이 보인다', (tester) async {
      SharedPreferences.setMockInitialValues({
        'steel_stock_deducted_sp3': '앵글 40x40x3=1',
      });
      await open(tester);
      await tester.tap(find.byKey(const Key('steel_btn_optimize')));
      await tester.pumpAndSettle();
      final undo = find.byKey(const Key('stock_deduct_undo'));
      expect(undo, findsOneWidget);
      await tester.ensureVisible(undo);
      // 누르지는 않는다 — 실제 창고 재고를 건드리는 동작이다.
    });

    testWidgets('아직 안 뺐으면 되돌리기 단추가 없다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await open(tester);
      await tester.tap(find.byKey(const Key('steel_btn_optimize')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('stock_deduct_undo')), findsNothing);
    });

    testWidgets('본수가 다르면 다시 뺄 수 있다', (tester) async {
      SharedPreferences.setMockInitialValues({
        'steel_stock_deducted_sp3': '앵글 40x40x3=9',
      });
      await open(tester);
      await tester.tap(find.byKey(const Key('steel_btn_optimize')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('stock_deduct')), findsOneWidget);
    });

    testWidgets('재단 계획 창에서 저장하면 저장 표시가 남는다', (tester) async {
      SharedPreferences.setMockInitialValues({
        'steel_done_sp3': ['steel:앵글 40x40x3:500.0:2'],
      });
      await open(tester);
      await tester.tap(find.byKey(const Key('steel_btn_optimize')));
      await tester.pumpAndSettle();
      expect(find.text('재단 계획 (원자재 몇 본 드는지)'), findsOneWidget);
      final save = find.text('잘랐습니다 (잔재 저장)');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      // 창을 닫는다.
      await tester.tapAt(const Offset(180, 20));
      await tester.pumpAndSettle();
      // 결과 탭 글은 그대로("모두 잘랐습니다."), 저장 사실은 기억한다.
      expect(progress(tester), '모두 잘랐습니다.');
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('steel_leftover_saved_sp3'),
        'steel:앵글 40x40x3:500.0:2',
      );
    });

    testWidgets('재단 계획에서 잘랐습니다를 누르면 결과의 모든 줄이 잘랐음이 된다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await open(tester);
      await tester.tap(find.byKey(const Key('steel_btn_optimize')));
      await tester.pumpAndSettle();
      final save = find.text('잘랐습니다 (잔재 저장)');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(180, 20));
      await tester.pumpAndSettle();
      expect(progress(tester), '모두 잘랐습니다.');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('steel_done_sp3'), [
        'steel:앵글 40x40x3:500.0:2',
      ]);
    });
  });

  group('아이콘 줄·잔재 중복 저장·립C 규격', () {
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

    testWidgets('이미 저장한 결과는 재단 계획에서 저장 버튼 대신 "저장했습니다"', (tester) async {
      SharedPreferences.setMockInitialValues({
        'steel_done_sp4': ['steel:앵글 40x40x3:500.0:2'],
        'steel_leftover_saved_sp4': 'steel:앵글 40x40x3:500.0:2',
      });
      await open(tester);
      await tester.tap(find.byKey(const Key('steel_btn_optimize')));
      await tester.pumpAndSettle();
      expect(find.text('저장했습니다'), findsOneWidget);
      expect(find.text('잘랐습니다 (잔재 저장)'), findsNothing);
    });

    testWidgets('저장하지 않은 결과는 저장 버튼이 있다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await open(tester);
      await tester.tap(find.byKey(const Key('steel_btn_optimize')));
      await tester.pumpAndSettle();
      expect(find.text('잘랐습니다 (잔재 저장)'), findsOneWidget);
    });

    test('립C형강 규격은 41종이고 모두 무게가 계산되며 옛 규격 이름은 그대로다', () {
      final lip = SteelShapeDB.byCategory('LIPC');
      expect(lip.length, 41);
      expect(lip.map((e) => e.label).toSet().length, 41);
      for (final s in lip) {
        expect(steelKgPerM(s.label), isNotNull, reason: s.label);
      }
      // 예전부터 있던 여섯 규격(저장된 항목·즐겨찾기가 이 이름을 쓴다)
      for (final v in [
        '100x50x20x2.3',
        '100x50x20x3.2',
        '125x50x20x2.3',
        '150x50x20x2.3',
        '150x65x20x3.2',
        '200x75x20x3.2',
      ]) {
        expect(lip.any((e) => e.label == '립C형강 $v'), true, reason: v);
        expect(lip.any((e) => e.id == 'lipc_$v'), true, reason: v);
      }
    });

    test('립C 무게식이 시판 규격표(미주철근철강·부현철강) 값과 1% 안쪽으로 맞는다', () {
      const catalog = {
        '60x30x10x1.6': 1.63,
        '60x30x10x1.8': 1.81,
        '60x30x10x2.0': 1.99,
        '60x30x10x2.3': 2.25,
        '75x45x15x1.6': 2.32,
        '75x45x15x1.8': 2.59,
        '75x45x15x2.0': 2.86,
        '75x45x15x2.1': 2.99,
        '75x45x15x2.3': 3.25,
        '100x50x20x1.6': 2.88,
        '100x50x20x1.8': 3.22,
        '100x50x20x2.0': 3.56,
        '100x50x20x2.1': 3.73,
        '100x50x20x2.3': 4.06,
        '100x50x20x2.6': 4.55,
        '100x50x20x3.0': 5.19,
        '100x50x20x3.2': 5.50,
        '125x50x20x2.0': 3.95,
        '125x50x20x2.1': 4.14,
        '125x50x20x3.0': 5.78,
        '125x50x20x3.2': 6.13,
        '150x50x20x2.1': 4.55,
        '150x50x20x3.0': 6.37,
        '150x50x20x3.2': 6.76,
        '150x65x20x3.0': 7.07,
        '150x65x20x3.2': 7.51,
        '150x65x20x4.5': 10.30,
        '150x75x25x3.0': 7.78,
        '150x75x25x3.2': 8.27,
        '200x75x20x5.0': 14.0,
        '200x75x25x3.0': 8.96,
        '200x75x25x4.5': 13.1,
        '250x80x20x4.5': 14.9,
      };
      for (final e in catalog.entries) {
        final kg = steelKgPerM('립C형강 ${e.key}')!;
        expect((kg - e.value).abs() / e.value, lessThan(0.01), reason: e.key);
      }
    });

    testWidgets('되돌리기: 방금 저장한 잔재와 잘랐음 표시를 저장 전으로', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await open(tester);
      await tester.tap(find.byKey(const Key('steel_btn_optimize')));
      await tester.pumpAndSettle();
      final save = find.text('잘랐습니다 (잔재 저장)');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect((await loadLeftovers()).isNotEmpty, true);
      final undo = find.byKey(const Key('leftover_undo'));
      await tester.ensureVisible(undo);
      await tester.tap(undo);
      await tester.pumpAndSettle();
      expect(await loadLeftovers(), isEmpty);
      // 저장 버튼이 다시 나온다
      expect(find.text('잘랐습니다 (잔재 저장)'), findsOneWidget);
      await tester.tapAt(const Offset(180, 20));
      await tester.pumpAndSettle();
      final progress = tester
          .widget<Text>(find.byKey(const Key('result_progress')))
          .data;
      expect(progress, '잘랐음 0/2개');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('steel_leftover_saved_sp4'), isNull);
    });

    testWidgets('이미 저장한 결과를 다시 열면 되돌리기는 없다', (tester) async {
      SharedPreferences.setMockInitialValues({
        'steel_done_sp4': ['steel:앵글 40x40x3:500.0:2'],
        'steel_leftover_saved_sp4': 'steel:앵글 40x40x3:500.0:2',
      });
      await open(tester);
      await tester.tap(find.byKey(const Key('steel_btn_optimize')));
      await tester.pumpAndSettle();
      expect(find.text('저장했습니다'), findsOneWidget);
      expect(find.byKey(const Key('leftover_undo')), findsNothing);
    });

    testWidgets('PDF는 바로 공유하지 않고 미리보기가 먼저 열린다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final old = pdfPreviewBuilder;
      addTearDown(() => pdfPreviewBuilder = old);
      pdfPreviewBuilder = (bytes, name) =>
          Text('미리보기 ${bytes.length > 1000} $name');
      await open(tester);
      await tester.tap(find.byKey(const Key('steel_btn_export')));
      await tester.pumpAndSettle();
      expect(find.text('지시서 미리보기'), findsOneWidget);
      expect(findTextContaining('미리보기 true 루마_형강컷팅지시서.pdf'), findsOneWidget);
      expect(find.byKey(const Key('pdf_preview_share')), findsOneWidget);
    });

    testWidgets('물음표 버튼은 아이콘들의 오른쪽 끝에 있다', (tester) async {
      SharedPreferences.setMockInitialValues({
        'cutting_result_icons_used': true,
      });
      await open(tester);
      final help = tester.getCenter(find.byKey(const Key('action_help')));
      for (final k in [
        'steel_btn_optimize',
        'steel_btn_export',
        'steel_btn_kakao',
        'steel_btn_copy',
      ]) {
        expect(
          tester.getCenter(find.byKey(Key(k))).dx < help.dx,
          true,
          reason: k,
        );
      }
    });
  });

  group('무게순 보기', () {
    test('무게가 큰 규격부터, 모르는 규격은 뒤로, 규격 안의 줄 순서는 그대로', () {
      final lines = buildSteelResultLines([
        item('내 규격 하나', 500, 1, cat: 'CUSTOM', id: 'u'),
        item('앵글 40x40x3', 500, 3, id: 'a1'),
        item('앵글 40x40x3', 800, 1, id: 'a2'),
        item('스트럿 41x41x2.5', 1000, 3, cat: 'STRUT', id: 's'),
      ], 1);
      // 앵글 2300mm=4.2kg, 스트럿 3000mm=7.8kg
      final sorted = sortLinesByWeight(lines);
      expect(sorted.map((l) => l.spec).toSet().toList(), [
        '스트럿 41x41x2.5',
        '앵글 40x40x3',
        '내 규격 하나',
      ]);
      // 앵글 안에서는 긴 것부터(원래 순서)
      final angle = sorted.where((l) => l.spec == '앵글 40x40x3').toList();
      expect(angle.map((l) => l.cutMm), [800, 500]);
      expect(sorted.length, lines.length);
    });

    test('규격이 하나면 그대로', () {
      final lines = buildSteelResultLines([item('앵글 40x40x3', 500, 2)], 1);
      expect(
        sortLinesByWeight(lines).map((l) => l.key),
        lines.map((l) => l.key),
      );
    });

    testWidgets('버튼을 누르면 무거운 규격이 위로 오고 기억한다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      final p = SteelCuttingProject(
        id: 'sp5',
        name: '루마',
        createdAt: DateTime(2026, 9, 20),
        items: [
          item('앵글 40x40x3', 500, 3, id: 'a'),
          item('스트럿 41x41x2.5', 1000, 3, cat: 'STRUT', id: 'c'),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(home: SteelCuttingDetailScreen(project: p)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('결과'));
      await tester.pumpAndSettle();
      double y(String spec) =>
          tester.getTopLeft(find.byKey(Key('spec_header_$spec'))).dy;
      expect(y('앵글 40x40x3') < y('스트럿 41x41x2.5'), true);
      await tester.tap(find.byKey(const Key('steel_sort_weight')));
      await tester.pumpAndSettle();
      expect(y('스트럿 41x41x2.5') < y('앵글 40x40x3'), true);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('steel_result_sort_weight'), true);
      await tester.tap(find.byKey(const Key('steel_sort_weight')));
      await tester.pumpAndSettle();
      expect(y('앵글 40x40x3') < y('스트럿 41x41x2.5'), true);
    });

    testWidgets('규격이 하나뿐이면 정렬 버튼이 없다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      final p = SteelCuttingProject(
        id: 'sp6',
        name: '루마',
        createdAt: DateTime(2026, 9, 20),
        items: [item('앵글 40x40x3', 500, 3, id: 'a')],
      );
      await tester.pumpWidget(
        MaterialApp(home: SteelCuttingDetailScreen(project: p)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('결과'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('steel_sort_weight')), findsNothing);
    });
  });

  group('잔재 기록·규격별 잔재', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('기록: 최신이 앞, 쓴 것·새로 생긴 것이 없으면 적지 않는다', () async {
      expect(
        await appendLeftoverLog(source: 'x', used: const [], added: const []),
        isNull,
      );
      final a = await appendLeftoverLog(
        source: '형강 컷팅 · 루마',
        used: const [Leftover('앵글 40x40x3', 3000)],
        added: const [Leftover('앵글 40x40x3', 5400)],
        now: DateTime(2026, 9, 20, 9),
      );
      await appendLeftoverLog(
        source: '튜브 컷팅 · H2',
        used: const [],
        added: const [Leftover('튜브 1/2"', 800)],
        now: DateTime(2026, 9, 21, 10, 30),
      );
      final log = await loadLeftoverLog();
      expect(log.length, 2);
      expect(log.first.source, '튜브 컷팅 · H2');
      expect(log.last.used.single.length, 3000);
      await removeLeftoverLog(a!);
      expect((await loadLeftoverLog()).map((e) => e.source), ['튜브 컷팅 · H2']);
    });

    test('기록은 최근 100건만 남긴다', () async {
      for (var i = 0; i < kMaxLeftoverLog + 5; i++) {
        await appendLeftoverLog(
          source: 'n$i',
          used: const [],
          added: [Leftover('a', 300.0 + i)],
          now: DateTime(2026, 1, 1).add(Duration(minutes: i)),
        );
      }
      final log = await loadLeftoverLog();
      expect(log.length, kMaxLeftoverLog);
      expect(log.first.source, 'n${kMaxLeftoverLog + 4}');
    });

    test('기록 글: 같은 길이는 × 개수로 묶고 규격별로 적는다', () {
      expect(describeLeftovers(const []), '없음');
      expect(
        describeLeftovers(const [
          Leftover('앵글 40x40x3', 5400),
          Leftover('앵글 40x40x3', 5400),
          Leftover('앵글 40x40x3', 3000),
          Leftover('스트럿 41x41x2.5', 5000),
        ]),
        '앵글 40x40x3 5400mm × 2, 3000mm / 스트럿 41x41x2.5 5000mm',
      );
    });

    test('규격별 묶기: 규격은 처음 나온 순서, 안에서는 긴 것부터, 위치를 알려 준다', () {
      final list = const [
        Leftover('앵글', 1000),
        Leftover('스트럿', 500),
        Leftover('앵글', 3000),
        Leftover('스트럿', 900),
      ];
      final g = groupLeftoversByLabel(list);
      expect(g.map((e) => e.label), ['앵글', '스트럿']);
      expect(g[0].indices, [2, 0]);
      expect(g[0].totalMm, 4000);
      expect(g[1].indices, [3, 1]);
      expect(groupLeftoversByLabel(const []), isEmpty);
    });

    testWidgets('잔재 기록 화면: 카드에 쓴 잔재·새 잔재, 없으면 안내', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LeftoverLogPage(
            entries: [
              LeftoverLogEntry(
                id: '1',
                at: DateTime(2026, 9, 20, 9, 5),
                source: '형강 컷팅 · 루마',
                used: const [Leftover('앵글 40x40x3', 3000)],
                added: const [Leftover('앵글 40x40x3', 5400)],
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('잔재 기록'), findsOneWidget);
      expect(find.text('9월 20일(일) 09:05'), findsOneWidget);
      expect(find.text('형강 컷팅 · 루마'), findsOneWidget);
      expect(find.text('앵글 40x40x3 3000mm'), findsOneWidget);
      expect(find.text('앵글 40x40x3 5400mm'), findsOneWidget);
      await tester.pumpWidget(
        const MaterialApp(home: LeftoverLogPage(entries: [])),
      );
      await tester.pumpAndSettle();
      expect(findTextContaining('아직 잔재 기록이 없습니다'), findsOneWidget);
    });

    SteelCuttingProject proj() => SteelCuttingProject(
      id: 'sp7',
      name: '루마',
      createdAt: DateTime(2026, 9, 20),
      items: [item('앵글 40x40x3', 500, 2, id: 'a')],
    );

    Future<void> openOptimize(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(home: SteelCuttingDetailScreen(project: proj())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('결과'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('steel_btn_optimize')));
      await tester.pumpAndSettle();
    }

    testWidgets('저장하면 기록이 남고 되돌리면 기록도 지워지며, 기록 버튼으로 볼 수 있다', (tester) async {
      await openOptimize(tester);
      final save = find.text('잘랐습니다 (잔재 저장)');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      var log = await loadLeftoverLog();
      expect(log.length, 1);
      expect(log.single.source, '형강 컷팅 · 루마');
      expect(log.single.added.single.label, '앵글 40x40x3');

      // 기록 화면
      final open = find.byKey(const Key('leftover_log_open'));
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(find.text('형강 컷팅 · 루마'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      final undo = find.byKey(const Key('leftover_undo'));
      await tester.ensureVisible(undo);
      await tester.tap(undo);
      await tester.pumpAndSettle();
      log = await loadLeftoverLog();
      expect(log, isEmpty);
    });

    testWidgets('잔재 관리 창은 규격별 머리글로 묶는다', (tester) async {
      SharedPreferences.setMockInitialValues({
        kLeftoversPrefsKey: [
          const Leftover('앵글 40x40x3', 1000).encode(),
          const Leftover('스트럿 41x41x2.5', 500).encode(),
          const Leftover('앵글 40x40x3', 3000).encode(),
        ],
      });
      await openOptimize(tester);
      final manage = find.text('잔재 관리');
      await tester.ensureVisible(manage);
      await tester.tap(manage);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('leftover_group_앵글 40x40x3')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('leftover_group_앵글 40x40x3')))
            .data,
        contains('2개 · 합계 4000mm'),
      );
      expect(
        find.byKey(const Key('leftover_group_스트럿 41x41x2.5')),
        findsOneWidget,
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('leftover_total'))).data,
        '전체 3개 · 합계 4500mm · 규격 2종',
      );
    });
  });

  group('잔재 기록 걸러내기', () {
    final now = DateTime(2026, 9, 30, 12);
    final entries = [
      LeftoverLogEntry(
        id: '3',
        at: DateTime(2026, 9, 29, 10),
        source: '형강 컷팅 · 루마',
        used: const [Leftover('앵글 40x40x3', 3000)],
        added: const [
          Leftover('앵글 40x40x3', 5400),
          Leftover('스트럿 41x41x2.5', 5000),
        ],
      ),
      LeftoverLogEntry(
        id: '2',
        at: DateTime(2026, 9, 15, 10),
        source: '튜브 컷팅 · H2',
        used: const [],
        added: const [Leftover('튜브 1/2"', 800)],
      ),
      LeftoverLogEntry(
        id: '1',
        at: DateTime(2026, 7, 1, 10),
        source: '형강 컷팅 · 루마',
        used: const [],
        added: const [Leftover('앵글 40x40x3', 2000)],
      ),
    ];

    test('기간: 최근 7일·30일만', () {
      expect(filterLeftoverLog(entries, now: now).length, 3);
      expect(filterLeftoverLog(entries, days: 30, now: now).map((e) => e.id), [
        '3',
        '2',
      ]);
      expect(filterLeftoverLog(entries, days: 7, now: now).map((e) => e.id), [
        '3',
      ]);
    });

    test('규격: 그 규격의 잔재만 남기고 없는 기록은 뺀다', () {
      final r = filterLeftoverLog(entries, label: '앵글 40x40x3', now: now);
      expect(r.map((e) => e.id), ['3', '1']);
      expect(r.first.used.length, 1);
      expect(r.first.added.map((l) => l.length), [5400]); // 스트럿은 빠진다
      final both = filterLeftoverLog(
        entries,
        days: 30,
        label: '튜브 1/2"',
        now: now,
      );
      expect(both.map((e) => e.id), ['2']);
      expect(leftoverLogLabels(entries), [
        '앵글 40x40x3',
        '스트럿 41x41x2.5',
        '튜브 1/2"',
      ]);
    });

    testWidgets('기록 화면 칩으로 기간과 규격을 고른다', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: LeftoverLogPage(entries: entries, now: now),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('leftover_log_list')), findsOneWidget);
      expect(find.text('9월 15일(화) 10:00'), findsOneWidget);
      await tester.tap(find.byKey(const Key('log_days_7')));
      await tester.pumpAndSettle();
      expect(find.text('9월 15일(화) 10:00'), findsNothing);
      expect(find.text('9월 29일(화) 10:00'), findsOneWidget);
      // 규격 칩: 튜브만 → 최근 7일엔 없음 안내
      final tube = find.byKey(const Key('log_label_튜브 1/2"'));
      await tester.ensureVisible(tube);
      await tester.tap(tube);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('leftover_log_none')), findsOneWidget);
      await tester.tap(find.byKey(const Key('log_days_all')));
      await tester.pumpAndSettle();
      expect(find.text('9월 15일(화) 10:00'), findsOneWidget);
      expect(find.text('9월 29일(화) 10:00'), findsNothing);
    });
  });

  group('시판 규격표 대조', () {
    test('각파이프 무게식이 시판 표(미주철근철강 SPSR) 값과 1.5% 안쪽', () {
      const table = {
        '각파이프 20x20x1.6': 0.87,
        '각파이프 25x25x3.2': 1.98,
        '각파이프 30x30x2.3': 1.89,
        '각파이프 50x50x3.2': 4.50,
        '각파이프 50x50x4.5': 6.02,
        '각파이프 60x60x6': 9.45,
        '각파이프 100x100x4.5': 13.1,
        '각파이프 150x150x9': 38.2,
        '각파이프 200x200x12': 67.9,
        '각파이프 60x30x3.2': 3.99,
        '각파이프 100x50x6': 12.3,
        '각파이프 150x100x9': 31.1,
        '각파이프 75x45x4.5': 7.43,
      };
      for (final e in table.entries) {
        expect(
          (steelKgPerM(e.key)! - e.value).abs() / e.value,
          lessThan(0.015),
          reason: e.key,
        );
      }
    });

    test('앵글·찬넬 표 값(부현·미주 표)과 새로 넣은 규격', () {
      expect(steelKgPerM('앵글 250x250x35'), 128.0);
      expect(steelKgPerM('앵글 200x200x25'), 73.6);
      expect(steelKgPerM('앵글 50x50x6'), 4.43);
      expect(steelKgPerM('찬넬 200x90x8'), 30.3);
      expect(steelKgPerM('찬넬 380x100x13'), 67.3);
    });

    test('규격 종류별 개수와 겹침 없음', () {
      expect(SteelShapeDB.byCategory('SQUARE').length, 98);
      expect(SteelShapeDB.byCategory('STRUT').length, 12);
      final all = SteelShapeDB.all;
      expect(all.map((s) => s.id).toSet().length, all.length);
      expect(all.map((s) => s.label).toSet().length, all.length);
    });
  });

  group('잔재 기록 글 복사·카톡', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    final now = DateTime(2026, 9, 30, 12);
    final entries = [
      LeftoverLogEntry(
        id: '3',
        at: DateTime(2026, 9, 29, 10),
        source: '형강 컷팅 · 루마',
        used: const [Leftover('앵글 40x40x3', 3000)],
        added: const [
          Leftover('앵글 40x40x3', 5400),
          Leftover('스트럿 41x41x2.5', 5000),
        ],
      ),
      LeftoverLogEntry(
        id: '2',
        at: DateTime(2026, 9, 15, 10),
        source: '튜브 컷팅 · H2',
        used: const [],
        added: const [Leftover('튜브 1/2"', 800)],
      ),
    ];

    test('글: 조건, 기록, 지금 남은 잔재', () {
      final t = buildLeftoverLogText(
        entries: [entries.first],
        filterText: '최근 7일',
        current: const [
          Leftover('앵글 40x40x3', 5400),
          Leftover('앵글 40x40x3', 3000),
          Leftover('스트럿 41x41x2.5', 5000),
        ],
      );
      expect(t, '''[잔재 기록] (최근 7일)
9월 29일(화) 10:00 · 형강 컷팅 · 루마
  쓴 잔재: 앵글 40x40x3 3000mm
  새 잔재: 앵글 40x40x3 5400mm / 스트럿 41x41x2.5 5000mm

[지금 남은 잔재] 전체 3개 · 합계 13400mm
앵글 40x40x3 5400mm, 3000mm / 스트럿 41x41x2.5 5000mm''');
      expect(buildLeftoverLogText(entries: const []), '[잔재 기록]\n기록이 없습니다.');
    });

    testWidgets('버튼: 보이는 기록만 글로 복사하고, 카톡이 없으면 공유창으로', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      final oldK = kakaoSender;
      final oldS = textSharer;
      addTearDown(() {
        kakaoSender = oldK;
        textSharer = oldS;
      });
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: LeftoverLogPage(
            entries: entries,
            now: now,
            currentLeftovers: const [Leftover('앵글 40x40x3', 5400)],
          ),
        ),
      );
      await tester.pumpAndSettle();
      // 최근 7일로 거르면 9월 15일 기록은 글에서도 빠진다.
      await tester.tap(find.byKey(const Key('log_days_7')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('leftover_log_copy')));
      await tester.pumpAndSettle();
      expect(copied, contains('[잔재 기록] (최근 7일)'));
      expect(copied, contains('9월 29일(화) 10:00'));
      expect(copied, isNot(contains('9월 15일')));
      expect(copied, contains('[지금 남은 잔재] 전체 1개 · 합계 5400mm'));

      String? shared;
      kakaoSender = (t) async => false;
      textSharer = (t) async => shared = t;
      await tester.tap(find.byKey(const Key('leftover_log_kakao')));
      await tester.pumpAndSettle();
      expect(shared, copied);
      expect(find.textContaining('카카오톡을 찾지 못해'), findsOneWidget);
    });
  });

  group('입력 고도화: 여러 길이·자주 쓰는 길이·요약 줄', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('여러 길이 읽기: 쉼표·줄바꿈·x·×·*·개·mm', () {
      final p = parseMultiLengths('500x3, 800×2; 1200\n300 * 4개, 700mm x 2');
      expect(p.bad, isEmpty);
      expect(p.entries.map((e) => (e.length, e.qty)), [
        (500.0, 3),
        (800.0, 2),
        (1200.0, 1),
        (300.0, 4),
        (700.0, 2),
      ]);
      expect(p.pieces, 12);
      expect(p.totalMm, 1500 + 1600 + 1200 + 1200 + 1400);
      expect(multiPreviewText(p), '5건 · 총 12개 · 6900mm');
    });

    test('여러 길이 읽기: 소수 길이, 못 읽는 값·0은 따로 알려 준다', () {
      final p = parseMultiLengths('1200.5x2, abc, 0x3, 500x0, 600 x');
      expect(p.entries.map((e) => (e.length, e.qty)), [(1200.5, 2)]);
      expect(p.bad, ['abc', '0x3', '500x0', '600 x']);
      expect(parseMultiLengths('  ').isEmpty, true);
      expect(multiPreviewText(parseMultiLengths('')), '');
    });

    test('여러 길이 읽기: 아주 큰 개수·아주 긴 길이는 오류 없이 못 읽는 값으로', () {
      final big = parseMultiLengths('500x99999999999999999999, 800x2');
      expect(big.entries.map((e) => (e.length, e.qty)), [(800.0, 2)]);
      expect(big.bad, ['500x99999999999999999999']);
      final inf = parseMultiLengths('9' * 400);
      expect(inf.entries, isEmpty);
      expect(inf.bad.length, 1);
      final tooLong = parseMultiLengths('100001x2, 100000');
      expect(tooLong.entries.map((e) => e.length), [100000.0]);
      expect(tooLong.bad, ['100001x2']);
    });

    test('자주 쓰는 길이: 두 번 이상 쓴 것만, 많이 쓴 순서', () async {
      expect(await loadTopSteelLengths(), isEmpty);
      await bumpSteelLengthUse([500]);
      expect(await loadTopSteelLengths(), isEmpty); // 한 번은 우연일 수 있다
      await bumpSteelLengthUse([500, 800]);
      await bumpSteelLengthUse([800, 800.5]);
      await bumpSteelLengthUse([800]);
      expect(await loadTopSteelLengths(), [800, 500]);
      expect(await loadTopSteelLengths(n: 1), [800]);
    });

    test('자주 쓰는 길이: 규격을 주면 그 규격 것이 먼저, 모자라면 전체에서 채운다', () async {
      // 전체로만 쌓인 옛 기록(규격 없이 센 것).
      await bumpSteelLengthUse([300]);
      await bumpSteelLengthUse([300]);
      // 앵글에서는 500을, 찬넬에서는 200을 자주 쓴다.
      await bumpSteelLengthUse([500], shapeLabel: '앵글 50x50x5');
      await bumpSteelLengthUse([500], shapeLabel: '앵글 50x50x5');
      await bumpSteelLengthUse([200], shapeLabel: '찬넬 75x40x5');
      await bumpSteelLengthUse([200], shapeLabel: '찬넬 75x40x5');
      expect(await loadTopSteelLengths(shapeLabel: '앵글 50x50x5'), [
        500,
        200,
        300,
      ]);
      expect(await loadTopSteelLengths(shapeLabel: '찬넬 75x40x5'), [
        200,
        300,
        500,
      ]);
      // 규격을 주지 않으면 예전처럼 전체에서 많이 쓴 순서.
      expect(await loadTopSteelLengths(), [200, 300, 500]);
      // 처음 쓰는 규격은 전체 목록으로 채운다.
      expect(await loadTopSteelLengths(shapeLabel: '스트럿 41x41x2.5'), [
        200,
        300,
        500,
      ]);
      expect(await loadTopSteelLengths(shapeLabel: '앵글 50x50x5', n: 1), [500]);
    });

    test('자주 쓰는 길이에서 빼기: 전체와 그 규격 기록에서 지운다', () async {
      await bumpSteelLengthUse([500], shapeLabel: '앵글 50x50x5');
      await bumpSteelLengthUse([500], shapeLabel: '앵글 50x50x5');
      await bumpSteelLengthUse([800], shapeLabel: '찬넬 75x40x5');
      await bumpSteelLengthUse([800], shapeLabel: '찬넬 75x40x5');
      expect(await loadTopSteelLengths(), [500, 800]);
      await forgetSteelLength(500, shapeLabel: '앵글 50x50x5');
      expect(await loadTopSteelLengths(), [800]);
      expect(await loadTopSteelLengths(shapeLabel: '앵글 50x50x5'), [800]);
      // 규격을 주지 않으면 모든 규격 기록에서 뺀다.
      await forgetSteelLength(800);
      expect(await loadTopSteelLengths(), isEmpty);
      expect(await loadTopSteelLengths(shapeLabel: '찬넬 75x40x5'), isEmpty);
    });

    test('자주 쓰는 길이는 최대 개수를 넘으면 적게 쓴 것부터 버린다', () async {
      for (var i = 1; i <= kMaxSteelLengthFreq + 5; i++) {
        await bumpSteelLengthUse([i * 10.0]);
      }
      await bumpSteelLengthUse([10]); // 10은 두 번
      final top = await loadTopSteelLengths(n: 50);
      expect(top.first, 10);
    });

    Future<List<SteelCutItem>> openSheet(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 4200);
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
      return saved;
    }

    Future<void> pick(WidgetTester tester, String q, String label) async {
      await tester.tap(find.text('탭해서 규격 선택'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, q);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).first);
      await tester.pumpAndSettle();
    }

    testWidgets('한 번에 입력: 미리보기, 오류 표시, 모두 추가', (tester) async {
      final saved = await openSheet(tester);
      // 규격을 안 골랐으면 알려 준다
      await tester.tap(find.byKey(const Key('steel_multi_toggle')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('steel_multi_field')),
        '500x3, 800x2, 1200',
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('steel_multi_preview'))).data,
        '3건 · 총 6개 · 4300mm',
      );
      await tester.ensureVisible(find.byKey(const Key('steel_multi_add')));
      await tester.tap(find.byKey(const Key('steel_multi_add')));
      await tester.pumpAndSettle();
      expect(find.text('규격을 선택해 주십시오.'), findsOneWidget);
      expect(saved, isEmpty);

      // 규격을 고르고 오류가 섞이면 추가 버튼이 꺼진다
      await pick(tester, '40x40x3', '앵글 40x40x3');
      await tester.enterText(
        find.byKey(const Key('steel_multi_field')),
        '500x3, abc',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('steel_multi_bad')), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('steel_multi_add')))
            .onPressed,
        isNull,
      );

      await tester.enterText(
        find.byKey(const Key('steel_multi_field')),
        '500x3, 800x2, 1200',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('steel_multi_add')));
      await tester.tap(find.byKey(const Key('steel_multi_add')));
      await tester.pumpAndSettle();
      expect(saved.length, 3);
      expect(saved.map((e) => (e.shapeLabel, e.length, e.qty)), [
        ('앵글 40x40x3', 500.0, 3),
        ('앵글 40x40x3', 800.0, 2),
        ('앵글 40x40x3', 1200.0, 1),
      ]);
      expect(saved.map((e) => e.id).toSet().length, 3);
      // 입력칸은 비워지고 시트는 그대로 열려 있다
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('steel_multi_field')))
            .controller!
            .text,
        '',
      );
      expect(find.text('절단 항목 추가'), findsOneWidget);
    });

    testWidgets('칩을 길게 누르면 자주 쓰는 길이에서 뺀다', (tester) async {
      SharedPreferences.setMockInitialValues({
        kSteelLengthFreqPrefsKey: '{"500":3,"800":2}',
      });
      await openSheet(tester);
      await tester.longPress(find.byKey(const Key('freq_len_500')));
      await tester.pumpAndSettle();
      expect(find.text('자주 쓰는 길이에서 빼기'), findsOneWidget);
      await tester.tap(find.text('빼기'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('freq_len_500')), findsNothing);
      expect(find.byKey(const Key('freq_len_800')), findsOneWidget);
      expect(await loadTopSteelLengths(), [800]);
    });

    testWidgets('저장한 길이는 세어 두었다가 자주 쓰는 길이 칩으로 나온다', (tester) async {
      SharedPreferences.setMockInitialValues({
        kSteelLengthFreqPrefsKey: '{"500":3,"800":2,"1200":1}',
      });
      await openSheet(tester);
      expect(find.byKey(const Key('freq_len_500')), findsOneWidget);
      expect(find.byKey(const Key('freq_len_800')), findsOneWidget);
      expect(find.byKey(const Key('freq_len_1200')), findsNothing);
      await tester.tap(find.byKey(const Key('freq_len_800')));
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('steel_length_field')))
            .controller!
            .text,
        '800',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('steel_item_preview'))).data,
        '800mm × 1개 = 800mm',
      );
    });

    testWidgets('항목을 저장하면 그 길이가 센다', (tester) async {
      final saved = await openSheet(tester);
      await pick(tester, '40x40x3', '앵글 40x40x3');
      await tester.enterText(
        find.byKey(const Key('steel_length_field')),
        '500',
      );
      await tester.pump();
      await tester.tap(find.text('추가하고 계속'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('steel_length_field')),
        '500',
      );
      await tester.pump();
      await tester.tap(find.text('추가하고 계속'));
      await tester.pumpAndSettle();
      expect(saved.length, 2);
      expect(await loadTopSteelLengths(), [500]);
    });

    testWidgets('입력 탭 아래 요약 줄: 건수·개수·길이·무게, 세트를 곱한다', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      SteelCuttingProject proj(int sets) => SteelCuttingProject(
        id: 'sp8',
        name: '루마',
        createdAt: DateTime(2026, 9, 20),
        setMultiplier: sets,
        items: [
          item('앵글 40x40x3', 500, 3, id: 'a'),
          item('앵글 40x40x3', 800, 1, id: 'b'),
          item('스트럿 41x41x2.5', 1000, 3, cat: 'STRUT', id: 'c'),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(home: SteelCuttingDetailScreen(project: proj(1))),
      );
      await tester.pumpAndSettle();
      expect(findTextContaining('항목 3건 · 총 7개'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('steel_input_summary_len')))
            .data,
        '5.30m',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('steel_input_summary_kg')))
            .data,
        '약 12.0kg',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SteelCuttingDetailScreen(
            key: const ValueKey('sets3'),
            project: proj(3),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(findTextContaining('항목 3건 · 총 21개 (3세트)'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('steel_input_summary_len')))
            .data,
        '15.90m',
      );
    });

    testWidgets('항목이 없으면 요약 줄이 없다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SteelCuttingDetailScreen(
            project: SteelCuttingProject(
              id: 'e',
              name: '루마',
              createdAt: DateTime(2026, 9, 20),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('steel_input_summary')), findsNothing);
    });
  });

  group('묶음 작업·긴 항목 경고·합치기', () {
    SteelShapeItem shape(String label, String cat) =>
        SteelShapeItem(id: label, category: cat, label: label);

    test('규격 바꾸기: 그 묶음만 바뀌고 길이·개수·id·순서는 그대로', () {
      final items = [
        item('앵글 40x40x3', 500, 2, id: 'a'),
        item('스트럿 41x41x2.5', 1000, 3, cat: 'STRUT', id: 'b'),
        item('앵글 40x40x3', 800, 1, id: 'c'),
      ];
      final r = changeShapeOfGroup(
        items,
        '앵글 40x40x3',
        shape('앵글 50x50x5', 'ANGLE'),
      );
      expect(r.map((e) => e.id), ['a', 'b', 'c']);
      expect(r.map((e) => e.shapeLabel), [
        '앵글 50x50x5',
        '스트럿 41x41x2.5',
        '앵글 50x50x5',
      ]);
      expect(r.map((e) => e.length), [500, 1000, 800]);
      expect(r.map((e) => e.qty), [2, 3, 1]);
      expect(items.first.shapeLabel, '앵글 40x40x3');
    });

    test('다른 규격으로 복제: 새 id, 길이·개수 그대로', () {
      final items = [
        item('앵글 40x40x3', 500, 2, id: 'a'),
        item('스트럿 41x41x2.5', 1000, 3, cat: 'STRUT', id: 'b'),
        item('앵글 40x40x3', 800, 1, id: 'c'),
      ];
      final c = duplicateGroupTo(
        items,
        '앵글 40x40x3',
        shape('찬넬 75x40x5', 'CHANNEL'),
        idPrefix: 'g',
      );
      expect(c.map((e) => e.id), ['g_0', 'g_1']);
      expect(c.map((e) => (e.shapeLabel, e.length, e.qty)), [
        ('찬넬 75x40x5', 500.0, 2),
        ('찬넬 75x40x5', 800.0, 1),
      ]);
      expect(c.every((e) => e.category == 'CHANNEL'), true);
      expect(
        duplicateGroupTo(items, '없는 규격', shape('x', 'X'), idPrefix: 'g'),
        isEmpty,
      );
    });

    test('합치기: 같은 규격·같은 길이만, 개수 합산, 자리 유지', () {
      final items = [
        item('앵글 40x40x3', 500, 2, id: 'a'),
        item('스트럿 41x41x2.5', 500, 1, cat: 'STRUT', id: 'b'),
        item('앵글 40x40x3', 500, 3, id: 'c'),
        item('앵글 40x40x3', 800, 1, id: 'd'),
        item('앵글 40x40x3', 500.04, 1, id: 'e'),
      ];
      expect(findMergeGroups(items).length, 1);
      expect(findMergeGroups(items).single.ids, ['a', 'c', 'e']);
      final r = mergeSameItems(items);
      expect(r.items.map((e) => e.id), ['a', 'b', 'd']);
      expect(r.items.first.qty, 6);
      expect(r.kept.single.id, 'a');
      expect(r.removed.map((e) => e.id), ['c', 'e']);
      final none = mergeSameItems([item('앵글 40x40x3', 500, 2, id: 'a')]);
      expect(none.removed, isEmpty);
      expect(none.items.length, 1);
    });

    test('합치기: 비고는 겹치지 않게 이어 붙인다', () {
      SteelCutItem n(String id, String note) => SteelCutItem(
        id: id,
        category: 'ANGLE',
        shapeLabel: '앵글 40x40x3',
        length: 500,
        qty: 1,
        note: note,
      );
      final r = mergeSameItems([n('a', 'A구역'), n('b', 'B구역'), n('c', 'A구역')]);
      expect(r.items.single.note, 'A구역 · B구역');
      expect(r.items.single.qty, 3);
    });

    test('긴 항목: 원자재보다 긴 것만', () {
      final items = [
        item('앵글 40x40x3', 6000, 1, id: 'a'),
        item('앵글 40x40x3', 6001, 1, id: 'b'),
        item('앵글 40x40x3', 9000, 1, id: 'c'),
      ];
      expect(overLengthItems(items, 6000).map((e) => e.id), ['b', 'c']);
      expect(overLengthItems(items, 9000), isEmpty);
      expect(overLengthItems(items, 0), isEmpty);
    });

    test('긴 항목 경고와 재단 계획이 같은 조각을 뺀다(톱날이 있어도 한 본 통째 조각은 넣는다)', () {
      final items = [
        item('앵글 40x40x3', 5998, 1, id: 'a'),
        item('앵글 40x40x3', 6000, 1, id: 'b'),
        item('앵글 40x40x3', 1000, 1, id: 'c'),
        item('앵글 40x40x3', 7000, 1, id: 'd'),
      ];
      final r = optimizeCutting(
        pieces: [for (final i in items) i.length],
        stockLength: 6000,
        kerf: 3,
      );
      expect(overLengthItems(items, 6000).map((e) => e.id), ['d']);
      expect(r.oversizedPieces, [7000.0]);
      expect(r.barCount, 3);
    });

    SteelCuttingProject proj({
      List<SteelCutItem>? items,
      double stock = 6000,
    }) => SteelCuttingProject(
      id: 'sp9',
      name: '루마',
      createdAt: DateTime(2026, 9, 20),
      stockLength: stock,
      items:
          items ??
          [
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
    }

    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('머리글을 누르면 그 묶음의 카드가 접히고 기억한다', (tester) async {
      await open(tester, proj());
      expect(find.byKey(const Key('steel_item_a')), findsOneWidget);
      await tester.tap(find.byKey(const Key('steel_group_toggle_앵글 40x40x3')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('steel_item_a')), findsNothing);
      expect(find.byKey(const Key('steel_item_b')), findsNothing);
      expect(find.byKey(const Key('steel_item_c')), findsOneWidget);
      expect(findTextContaining('2건 · 2300mm'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('steel_collapsed_sp9'), ['앵글 40x40x3']);
      await tester.tap(find.byKey(const Key('steel_group_toggle_앵글 40x40x3')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('steel_item_a')), findsOneWidget);
    });

    testWidgets('접어 둔 묶음은 다시 열어도 접혀 있다', (tester) async {
      SharedPreferences.setMockInitialValues({
        'steel_collapsed_sp9': ['스트럿 41x41x2.5'],
      });
      await open(tester, proj());
      expect(find.byKey(const Key('steel_item_c')), findsNothing);
      expect(find.byKey(const Key('steel_item_a')), findsOneWidget);
    });

    testWidgets('머리글 ⋮ 메뉴에 규격 바꾸기·다른 규격으로 복제·순서 바꾸기가 있다', (tester) async {
      await open(tester, proj());
      await tester.tap(find.byKey(const Key('steel_group_menu_앵글 40x40x3')));
      await tester.pumpAndSettle();
      expect(find.text('규격 바꾸기 (길이 그대로)'), findsOneWidget);
      expect(find.text('다른 규격으로 복제'), findsOneWidget);
      expect(find.text('순서 바꾸기'), findsOneWidget);
    });

    testWidgets('순서 바꾸기 창이 열리고 저장하면 닫힌다', (tester) async {
      await open(tester, proj());
      await tester.tap(find.byKey(const Key('steel_group_menu_앵글 40x40x3')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('순서 바꾸기'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('steel_reorder_list')), findsOneWidget);
      expect(find.text('행을 길게 눌러 끌면 자르는 순서가 바뀝니다.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('steel_reorder_save')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('steel_reorder_list')), findsNothing);
      // 순서를 건드리지 않았으니 카드 순서도 그대로.
      expect(
        tester.getTopLeft(find.byKey(const Key('steel_item_a'))).dy <
            tester.getTopLeft(find.byKey(const Key('steel_item_b'))).dy,
        true,
      );
    });

    testWidgets('항목이 하나뿐인 묶음은 순서를 바꿀 수 없다고 알린다', (tester) async {
      await open(
        tester,
        proj(
          items: [item('스트럿 41x41x2.5', 1000, 1, cat: 'STRUT', id: 'c')],
        ),
      );
      await tester.tap(find.byKey(const Key('steel_group_menu_스트럿 41x41x2.5')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('순서 바꾸기'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('steel_reorder_list')), findsNothing);
      expect(findTextContaining('항목이 둘 이상이어야'), findsOneWidget);
    });

    testWidgets('아이콘을 써 본 뒤에는 칩이 아이콘만 남고, ?를 누르면 이름이 다시 보인다', (tester) async {
      SharedPreferences.setMockInitialValues({
        'cutting_result_icons_used': true,
      });
      await open(tester, proj());
      await tester.tap(find.text('결과'));
      await tester.pumpAndSettle();
      // 칩은 그대로 있지만 이름은 감춘다(툴팁·길게 누르면 이름).
      expect(find.byKey(const Key('steel_hide_done')), findsOneWidget);
      expect(find.text('자른 줄 감추기'), findsNothing);
      await tester.tap(find.byKey(const Key('action_help')));
      await tester.pumpAndSettle();
      expect(find.text('자른 줄 감추기'), findsOneWidget);
    });

    testWidgets('다 자르고 잔재까지 저장한 작업은 다시 열면 스스로 새로 시작한다', (tester) async {
      final p = proj();
      final lines = buildSteelResultLines(p.items, 1);
      SharedPreferences.setMockInitialValues({
        'steel_done_sp9': lines.map((l) => l.key).toList(),
        'steel_leftover_saved_sp9': lines.map((l) => l.key).join('|'),
        'steel_result_folded_sp9': ['앵글 40x40x3'],
      });
      await open(tester, p);
      await tester.tap(find.text('결과'));
      await tester.pumpAndSettle();
      expect(findTextContaining('잘랐음 표시를 새로 시작합니다'), findsOneWidget);
      expect(findTextContaining('잘랐음 0/7개'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('steel_done_sp9'), isEmpty);
      expect(prefs.getStringList('steel_result_folded_sp9'), isEmpty);
      // 잔재 저장 기록은 남긴다(같은 잔재를 두 번 저장하지 않게).
      expect(prefs.getString('steel_leftover_saved_sp9'), isNotNull);
    });

    testWidgets('아직 다 자르지 않은 작업은 잘랐음 표시를 그대로 둔다', (tester) async {
      final p = proj();
      final lines = buildSteelResultLines(p.items, 1);
      SharedPreferences.setMockInitialValues({
        'steel_done_sp9': [lines.first.key],
        'steel_leftover_saved_sp9': lines.map((l) => l.key).join('|'),
      });
      await open(tester, p);
      await tester.tap(find.text('결과'));
      await tester.pumpAndSettle();
      expect(findTextContaining('새로 시작합니다'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('steel_done_sp9'), [lines.first.key]);
    });

    testWidgets('총계 카드에 새 원자재 본수가 보인다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      // 앵글 2000mm 4개 = 8000mm → 6000 자재로 2본, 스트럿 1000mm 1개 → 1본.
      await open(
        tester,
        proj(
          items: [
            item('앵글 40x40x3', 2000, 4, id: 'a'),
            item('스트럿 41x41x2.5', 1000, 1, cat: 'STRUT', id: 'c'),
          ],
        ),
      );
      await tester.tap(find.text('결과'));
      await tester.pumpAndSettle();
      expect(findTextContaining('새 원자재 6000 3본'), findsOneWidget);
    });

    testWidgets('원자재보다 긴 조각이 있으면 본수 옆에 뺀 개수를 적는다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await open(
        tester,
        proj(
          items: [
            item('앵글 40x40x3', 7000, 2, id: 'a'),
            item('앵글 40x40x3', 1000, 1, id: 'b'),
          ],
        ),
      );
      await tester.tap(find.text('결과'));
      await tester.pumpAndSettle();
      expect(
        findTextContaining('새 원자재 6000 1본 · 원자재보다 긴 조각 2개는 뺐습니다'),
        findsOneWidget,
      );
    });

    testWidgets('자른 줄 감추기 칩', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await open(tester, proj());
      await tester.tap(find.text('결과'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('800.0 mm'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('steel_hide_done')));
      await tester.pumpAndSettle();
      expect(find.text('800.0 mm'), findsNothing); // 자른 줄은 감춘다
      expect(find.text('500.0 mm'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('steel_result_hide_done'), true);
      await tester.tap(find.byKey(const Key('steel_hide_done')));
      await tester.pumpAndSettle();
      expect(find.text('800.0 mm'), findsOneWidget);
    });

    testWidgets('이 규격만 보기와 전체 보기', (tester) async {
      await open(tester, proj());
      await tester.tap(find.byKey(const Key('steel_group_menu_앵글 40x40x3')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('이 규격만 보기'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('steel_spec_filter')), findsOneWidget);
      expect(find.byKey(const Key('steel_item_c')), findsNothing);
      expect(find.byKey(const Key('steel_item_a')), findsOneWidget);
      await tester.tap(find.byKey(const Key('steel_spec_filter_clear')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('steel_item_c')), findsOneWidget);
    });

    testWidgets('여러 항목 고르기: 고른 것만 지운다', (tester) async {
      await open(tester, proj());
      await tester.tap(find.byKey(const Key('steel_group_menu_앵글 40x40x3')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('여러 항목 고르기'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('steel_pick_a')), findsOneWidget);
      expect(find.byKey(const Key('steel_pick_b')), findsOneWidget);
      await tester.tap(find.byKey(const Key('steel_pick_b')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('steel_pick_delete')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('steel_item_b')), findsNothing);
      expect(find.byKey(const Key('steel_item_a')), findsOneWidget);
      expect(find.byKey(const Key('steel_item_c')), findsOneWidget);
    });

    test('순서 바꾸기: 그 규격 자리에만 새 순서로 넣는다', () {
      final items = [
        item('앵글 40x40x3', 500, 1, id: 'a'),
        item('스트럿 41x41x2.5', 1000, 1, cat: 'STRUT', id: 'c'),
        item('앵글 40x40x3', 800, 1, id: 'b'),
      ];
      final group = [items[2], items[0]]; // 800을 먼저
      final out = applyShapeOrder(items, '앵글 40x40x3', group);
      expect(out.map((e) => e.id), ['b', 'c', 'a']); // 스트럿은 가운데 그대로
      // 개수가 맞지 않으면 아무것도 바꾸지 않는다.
      expect(
        applyShapeOrder(items, '앵글 40x40x3', [items[0]]).map((e) => e.id),
        ['a', 'c', 'b'],
      );
    });

    testWidgets('카드를 길게 누르면 길이만 고친다', (tester) async {
      await open(tester, proj());
      await tester.longPress(find.byKey(const Key('steel_item_a')));
      await tester.pumpAndSettle();
      expect(find.text('길이 고치기'), findsOneWidget);
      expect(findTextContaining('앵글 40x40x3 · 3개'), findsOneWidget);
      await tester.tap(find.byKey(const Key('steel_len_step_100')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('steel_len_save')));
      await tester.pumpAndSettle();
      // 500 + 100 = 600, 개수 3개는 그대로.
      expect(find.text('600 mm'), findsOneWidget);
      expect(find.text('500 mm'), findsNothing);
      expect(findTextContaining('= 1800 mm'), findsOneWidget);
    });

    testWidgets('길이 고치기에서 취소하면 그대로다', (tester) async {
      await open(tester, proj());
      await tester.longPress(find.byKey(const Key('steel_item_a')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(find.text('500 mm'), findsOneWidget);
    });

    testWidgets('원자재보다 긴 항목은 위에 경고, 카드에 표시', (tester) async {
      await open(
        tester,
        proj(
          items: [
            item('앵글 40x40x3', 6500, 1, id: 'a'),
            item('앵글 40x40x3', 800, 1, id: 'b'),
          ],
        ),
      );
      expect(find.byKey(const Key('steel_over_banner')), findsOneWidget);
      expect(findTextContaining('6000mm)보다 긴 항목 1건'), findsOneWidget);
      expect(find.byKey(const Key('steel_over_a')), findsOneWidget);
      expect(find.byKey(const Key('steel_over_b')), findsNothing);
    });

    testWidgets('긴 항목 경고에서 원자재 길이를 바로 바꾼다', (tester) async {
      await open(tester, proj(items: [item('앵글 40x40x3', 6500, 1, id: 'a')]));
      expect(find.byKey(const Key('steel_over_banner')), findsOneWidget);
      await tester.tap(find.byKey(const Key('steel_edit_stock')));
      await tester.pumpAndSettle();
      expect(find.text('원자재 기준 길이'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('steel_stock_field')),
        '7000',
      );
      await tester.tap(find.byKey(const Key('steel_stock_save')));
      await tester.pumpAndSettle();
      // 7000mm가 되면 6500mm 항목은 더 이상 길지 않다 → 경고가 사라진다.
      expect(find.byKey(const Key('steel_over_banner')), findsNothing);
      expect(find.byKey(const Key('steel_over_a')), findsNothing);
    });

    testWidgets('원자재 길이 창: 잘못 적으면 창을 닫지 않고 까닭을 보여 준다', (tester) async {
      await open(tester, proj(items: [item('앵글 40x40x3', 6500, 1, id: 'a')]));
      await tester.tap(find.byKey(const Key('steel_edit_stock')));
      await tester.pumpAndSettle();
      final field = find.byKey(const Key('steel_stock_field'));
      final save = find.byKey(const Key('steel_stock_save'));
      for (final (text, msg) in [
        ('1.2.3', '숫자로 적어 주십시오.'),
        ('', '숫자로 적어 주십시오.'),
        ('0', '0보다 큰 길이를 적어 주십시오.'),
        ('-5', '0보다 큰 길이를 적어 주십시오.'),
        ('99999999', '20000mm 이하로 적어 주십시오.'),
      ]) {
        await tester.enterText(field, text);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(find.text('원자재 기준 길이'), findsOneWidget, reason: text);
        expect(find.text(msg), findsOneWidget, reason: text);
      }
      await tester.enterText(field, '7000');
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('원자재 기준 길이'), findsNothing);
      expect(find.byKey(const Key('steel_over_banner')), findsNothing);
    });

    test('원자재 길이 검사', () {
      expect(stockLengthError('6000'), isNull);
      expect(stockLengthError(' 6000.5 '), isNull);
      expect(stockLengthError('20000'), isNull);
      expect(stockLengthError('20001'), '20000mm 이하로 적어 주십시오.');
      expect(stockLengthError('abc'), '숫자로 적어 주십시오.');
      expect(stockLengthError('0'), '0보다 큰 길이를 적어 주십시오.');
    });

    testWidgets('원자재 길이 창에서 취소하면 그대로다', (tester) async {
      await open(tester, proj(items: [item('앵글 40x40x3', 6500, 1, id: 'a')]));
      await tester.tap(find.byKey(const Key('steel_edit_stock')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('steel_over_banner')), findsOneWidget);
      expect(findTextContaining('6000mm)보다 긴 항목 1건'), findsOneWidget);
    });

    testWidgets('긴 항목이 없으면 경고가 없다', (tester) async {
      await open(tester, proj());
      expect(find.byKey(const Key('steel_over_banner')), findsNothing);
    });

    testWidgets('같은 규격·길이가 나뉘어 있으면 합치기 안내', (tester) async {
      await open(
        tester,
        proj(
          items: [
            item('앵글 40x40x3', 500, 2, id: 'a'),
            item('앵글 40x40x3', 500, 3, id: 'b'),
          ],
        ),
      );
      expect(find.byKey(const Key('steel_merge_banner')), findsOneWidget);
      expect(findTextContaining('1묶음'), findsOneWidget);
    });

    testWidgets('카드의 −/+: 화면은 바로 바뀌고 1 아래로는 내려가지 않는다', (tester) async {
      await open(tester, proj());
      String qty(String id) =>
          tester.widget<Text>(find.byKey(Key('qty_text_$id'))).data!;
      expect(qty('a'), '3개');
      await tester.tap(find.byKey(const Key('qty_inc_a')));
      await tester.pump();
      expect(qty('a'), '4개');
      await tester.tap(find.byKey(const Key('qty_dec_a')));
      await tester.tap(find.byKey(const Key('qty_dec_a')));
      await tester.pump();
      expect(qty('a'), '2개');
      expect(qty('b'), '1개');
      await tester.tap(find.byKey(const Key('qty_dec_b')));
      await tester.pump();
      expect(qty('b'), '1개');
      // 요약 줄도 따라 바뀐다: 2 + 1 + 3 = 6개
      expect(findTextContaining('총 6개'), findsOneWidget);
      // 손을 뗀 뒤에 저장이 한 번 일어난다(테스트에는 저장소가 없어 실패 알림이 뜬다)
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(findTextContaining('저장하지 못했습니다'), findsOneWidget);
    });

    testWidgets('글자를 크게 키워도 카드가 넘치지 않는다', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: SteelCuttingDetailScreen(
            project: proj(
              items: [
                item('앵글 40x40x3', 6500, 12, id: 'a'),
                item('앵글 40x40x3', 6500, 1, id: 'b'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('결과 탭 규격 접기', () {
    SteelCuttingProject proj() => SteelCuttingProject(
      id: 'sp10',
      name: '루마',
      createdAt: DateTime(2026, 9, 20),
      items: [
        item('앵글 40x40x3', 500, 3, id: 'a'),
        item('앵글 40x40x3', 800, 1, id: 'b'),
        item('스트럿 41x41x2.5', 1000, 3, cat: 'STRUT', id: 'c'),
      ],
    );

    Future<void> openResult(WidgetTester tester) async {
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

    testWidgets('머리글을 누르면 그 규격 줄이 접히고 기억한다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await openResult(tester);
      expect(find.text('800.0 mm'), findsOneWidget);
      await tester.tap(find.byKey(const Key('spec_fold_앵글 40x40x3')));
      await tester.pumpAndSettle();
      // 접은 규격은 머리글만 남고, 다른 규격 줄은 그대로다.
      expect(find.text('800.0 mm'), findsNothing);
      expect(find.text('500.0 mm'), findsNothing);
      expect(find.text('1000.0 mm'), findsOneWidget);
      expect(find.byKey(const Key('spec_header_앵글 40x40x3')), findsOneWidget);
      expect(findTextContaining('4개 · 2300mm'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('steel_result_folded_sp10'), ['앵글 40x40x3']);
      await tester.tap(find.byKey(const Key('spec_fold_앵글 40x40x3')));
      await tester.pumpAndSettle();
      expect(find.text('800.0 mm'), findsOneWidget);
    });

    test('다 자른 규격 고르기: 규격이 둘 이상이고 그 규격 줄이 모두 잘랐음일 때만', () {
      final lines = buildSteelResultLines([
        item('앵글 40x40x3', 500, 3, id: 'a'),
        item('앵글 40x40x3', 800, 1, id: 'b'),
        item('스트럿 41x41x2.5', 1000, 3, cat: 'STRUT', id: 'c'),
      ], 1);
      final angle = lines
          .where((l) => l.spec == '앵글 40x40x3')
          .map((l) => l.key);
      expect(fullyDoneSpecs(lines, {}), isEmpty);
      expect(fullyDoneSpecs(lines, {angle.first}), isEmpty); // 한 줄만 잘랐음
      expect(fullyDoneSpecs(lines, angle.toSet()), {'앵글 40x40x3'});
      expect(fullyDoneSpecs(lines, lines.map((l) => l.key).toSet()), {
        '앵글 40x40x3',
        '스트럿 41x41x2.5',
      });
      // 규격이 하나뿐이면 접을 것이 없다.
      final one = buildSteelResultLines([item('앵글 40x40x3', 500, 3)], 1);
      expect(fullyDoneSpecs(one, one.map((l) => l.key).toSet()), isEmpty);
    });

    testWidgets('마지막 줄을 잘랐음으로 표시하면 그 규격이 접힌다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await openResult(tester);
      // 앵글 두 줄을 모두 잘랐음으로: 첫 줄에서는 접히지 않고, 둘째 줄에서 접힌다.
      await tester.tap(find.text('800.0 mm'));
      await tester.pumpAndSettle();
      expect(find.text('500.0 mm'), findsOneWidget);
      await tester.tap(find.text('500.0 mm'));
      await tester.pumpAndSettle();
      expect(find.text('800.0 mm'), findsNothing);
      expect(find.text('500.0 mm'), findsNothing);
      expect(findTextContaining('완료 · 4개'), findsOneWidget);
      expect(find.text('1000.0 mm'), findsOneWidget); // 스트럿은 그대로
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('steel_result_folded_sp10'), ['앵글 40x40x3']);
      // 다시 펴 두면 그대로 펴져 있다(제멋대로 닫히지 않는다).
      await tester.tap(find.byKey(const Key('spec_fold_앵글 40x40x3')));
      await tester.pumpAndSettle();
      expect(find.text('800.0 mm'), findsOneWidget);
    });

    testWidgets('칩을 끄면 다 잘라도 접히지 않는다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await openResult(tester);
      await tester.tap(find.byKey(const Key('steel_fold_done')));
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('steel_result_fold_done'), false);
      await tester.tap(find.text('800.0 mm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('500.0 mm'));
      await tester.pumpAndSettle();
      expect(find.text('800.0 mm'), findsOneWidget);
      expect(
        prefs.getStringList('steel_result_folded_sp10'),
        anyOf(isNull, isEmpty),
      );
    });

    testWidgets('칩을 다시 켜면 이미 다 자른 규격을 바로 접는다', (tester) async {
      SharedPreferences.setMockInitialValues({'steel_result_fold_done': false});
      await openResult(tester);
      await tester.tap(find.text('800.0 mm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('500.0 mm'));
      await tester.pumpAndSettle();
      expect(find.text('800.0 mm'), findsOneWidget);
      await tester.tap(find.byKey(const Key('steel_fold_done')));
      await tester.pumpAndSettle();
      expect(find.text('800.0 mm'), findsNothing);
      expect(find.text('1000.0 mm'), findsOneWidget);
    });

    testWidgets('접어 둔 규격은 다시 열어도 접혀 있고, 입력 탭은 그대로다', (tester) async {
      SharedPreferences.setMockInitialValues({
        'steel_result_folded_sp10': ['앵글 40x40x3'],
      });
      await openResult(tester);
      expect(find.text('800.0 mm'), findsNothing);
      expect(find.text('1000.0 mm'), findsOneWidget);
      await tester.tap(find.text('입력'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('steel_item_a')), findsOneWidget);
      expect(find.byKey(const Key('steel_item_b')), findsOneWidget);
    });
  });
}
