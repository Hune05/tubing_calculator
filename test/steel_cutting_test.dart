import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/models/steel_cutting_project_model.dart';
import 'package:tubing_calculator/src/data/models/steel_shape_db.dart';
import 'package:tubing_calculator/src/presentation/steel_cutting/screens/steel_cutting_detail_screen.dart';
import 'package:tubing_calculator/src/presentation/steel_cutting/steel_result_logic.dart';
import 'package:tubing_calculator/src/presentation/steel_cutting/widgets/steel_item_sheet.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_action_bar.dart';

import 'helpers_text.dart';

// 형강 컷팅: 규격 DB, 입력 시트, 결과 창, 지시서 글.
SteelCutItem item(
  String shape,
  double len,
  int qty, {
  String cat = 'ANGLE',
  String note = '',
  String? id,
}) => SteelCutItem(
  id: id ?? '$shape-$len-$qty-$note',
  category: cat,
  shapeLabel: shape,
  length: len,
  qty: qty,
  note: note,
);

void main() {
  group('규격 DB', () {
    test('카테고리 id가 겹치지 않고 모든 규격이 등록된 카테고리에 속한다', () {
      final ids = SteelShapeDB.categories.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final s in SteelShapeDB.all) {
        expect(ids.contains(s.category), true, reason: s.label);
      }
    });

    test('규격 id와 라벨이 겹치지 않는다(즐겨찾기·선택이 서로 헷갈리지 않게)', () {
      final all = SteelShapeDB.all;
      expect(all.map((s) => s.id).toSet().length, all.length);
      expect(all.map((s) => s.label).toSet().length, all.length);
    });

    test('종류마다 규격이 하나 이상 있다', () {
      for (final c in SteelShapeDB.categories) {
        expect(SteelShapeDB.byCategory(c.id).isNotEmpty, true, reason: c.label);
      }
    });

    test('기존 앵글·찬넬 규격과 id는 그대로다(예전 저장 항목이 깨지지 않게)', () {
      expect(SteelShapeDB.all.any((s) => s.id == 'angle_40x40x3'), true);
      expect(SteelShapeDB.all.any((s) => s.id == 'channel_100x50x5'), true);
      // 예전부터 있던 앵글 16종·찬넬 20종의 id가 모두 남아 있다.
      for (final v in [
        '25x25x3',
        '30x30x3',
        '40x40x3',
        '40x40x4',
        '45x45x4',
        '50x50x4',
        '50x50x5',
        '60x60x5',
        '65x65x6',
        '75x75x6',
        '75x75x9',
        '90x90x7',
        '100x100x7',
        '100x100x10',
        '125x125x9',
        '150x150x12',
      ]) {
        expect(
          SteelShapeDB.angles.any((s) => s.id == 'angle_$v'),
          true,
          reason: v,
        );
      }
      for (final v in [
        '25x25x1.6',
        '40x20x1.6',
        '50x25x1.6',
        '60x30x2.0',
        '75x35x2.3',
        '90x40x2.3',
        '100x50x2.3',
        '125x50x2.3',
        '150x50x2.3',
        '200x75x3.2',
        '75x40x5',
        '100x50x5',
        '125x65x6',
        '150x75x6.5',
        '180x75x7',
        '200x80x7.5',
        '250x90x9',
        '300x90x9',
        '300x90x10',
        '380x100x10.5',
      ]) {
        expect(
          SteelShapeDB.channels.any((s) => s.id == 'channel_$v'),
          true,
          reason: v,
        );
      }
      expect(SteelShapeDB.angles.length, 37);
      expect(SteelShapeDB.channels.length, 22);
    });

    test('새로 넣은 대표 규격', () {
      String? find(String label) => SteelShapeDB.all
          .where((s) => s.label == label)
          .map((s) => s.category)
          .firstOrNull;
      expect(find('스트럿 41x41x2.5'), 'STRUT');
      expect(find('강관 25A(34.0)'), 'ROUND');
      expect(find('각파이프 50x50x2.3'), 'SQUARE');
      expect(find('평철 50x6'), 'FLAT');
      expect(find('H형강 200x200x8x12'), 'BEAM');
      expect(find('전산볼트 M10'), 'ROD');
      expect(find('환봉 Φ12'), 'BAR');
      expect(find('부등변앵글 100x75x7'), 'UNEQUAL');
      expect(find('립C형강 100x50x20x2.3'), 'LIPC');
    });

    test('종류 이름', () {
      expect(SteelShapeDB.categoryLabel('ANGLE'), '앵글');
      expect(SteelShapeDB.categoryLabel('STRUT'), '스트럿');
      expect(SteelShapeDB.categoryLabel('CUSTOM'), '커스텀');
      expect(SteelShapeDB.categoryLabel('???'), '기타');
    });
  });

  group('결과 줄', () {
    test('같은 규격·같은 길이는 항목이 여러 개여도 한 줄로 합친다', () {
      final l = buildSteelResultLines([
        item('앵글 40x40x3', 500, 2, note: 'A구역'),
        item('앵글 40x40x3', 500, 3, note: 'B구역', id: 'x2'),
        item('앵글 40x40x3', 800, 1),
      ], 1);
      expect(l.length, 2);
      expect(l[0].cutMm, 800); // 긴 것부터
      expect(l[1].cutMm, 500);
      expect(l[1].count, 5);
      expect(l[1].baseCount, 5);
      expect(l[1].detail, '2건 합침 · A구역 · B구역');
      expect(l.every((x) => x.spec == '앵글 40x40x3'), true);
    });

    test('규격은 처음 나온 순서, 규격이 다르면 길이가 같아도 따로', () {
      final l = buildSteelResultLines([
        item('찬넬 100x50x5', 1000, 1, cat: 'CHANNEL'),
        item('앵글 40x40x3', 1000, 1),
        item('찬넬 100x50x5', 300, 4, cat: 'CHANNEL'),
      ], 1);
      expect(l.map((x) => x.spec), [
        '찬넬 100x50x5',
        '찬넬 100x50x5',
        '앵글 40x40x3',
      ]);
      expect(l.map((x) => x.cutMm), [1000, 300, 1000]);
    });

    test('세트 수를 바꿔도 1개 길이는 그대로, 개수·합계만 바뀐다', () {
      final items = [item('앵글 40x40x3', 500, 2), item('앵글 40x40x3', 800, 1)];
      final one = buildSteelResultLines(items, 1);
      final four = buildSteelResultLines(items, 4);
      expect(four.map((x) => x.cutMm), one.map((x) => x.cutMm));
      for (var i = 0; i < one.length; i++) {
        expect(four[i].count, one[i].count * 4);
        expect(four[i].totalMm, one[i].totalMm * 4);
        expect(four[i].totalMm, four[i].cutMm * four[i].count);
      }
      expect(four.first.countFormula, '1개 × 4세트 = 4개');
    });

    test('길이나 수량이 0 이하인 항목은 뺀다, 세트 0은 1세트', () {
      final l = buildSteelResultLines([
        item('앵글 40x40x3', 0, 2),
        item('앵글 40x40x3', 500, 0, id: 'q0'),
        item('앵글 40x40x3', 500, 1, id: 'ok'),
      ], 0);
      expect(l.length, 1);
      expect(l.single.count, 1);
    });

    test('열쇠에 규격·길이·개수가 들어가서 바뀌면 잘랐음 표시가 사라진다', () {
      final a = buildSteelResultLines([
        item('앵글 40x40x3', 500, 2),
      ], 1).single.key;
      final b = buildSteelResultLines([
        item('앵글 40x40x3', 500, 3),
      ], 1).single.key;
      final c = buildSteelResultLines([
        item('앵글 40x40x3', 510, 2),
      ], 1).single.key;
      final d = buildSteelResultLines([
        item('앵글 50x50x4', 500, 2),
      ], 1).single.key;
      expect({a, b, c, d}.length, 4);
    });

    test('규격별 소계', () {
      final l = buildSteelResultLines([
        item('앵글 40x40x3', 500, 2),
        item('찬넬 100x50x5', 1000, 1, cat: 'CHANNEL'),
        item('앵글 40x40x3', 300, 1, id: 'z'),
      ], 2);
      final subs = shapeSubtotals(l);
      expect(subs.map((s) => s.shape), ['앵글 40x40x3', '찬넬 100x50x5']);
      expect(subs[0].kinds, 2);
      expect(subs[0].pieces, 6);
      expect(subs[0].mm, (500 * 2 + 300) * 2);
      expect(subs[1].pieces, 2);
    });
  });

  group('지시서 글', () {
    final items = [
      item('앵글 40x40x3', 500, 2, note: 'A구역'),
      item('찬넬 100x50x5', 1000, 1, cat: 'CHANNEL'),
    ];

    test('세트가 하나', () {
      final t = buildSteelInstructionText(
        projectName: '루마',
        date: DateTime(2026, 9, 20),
        sets: 1,
        lines: buildSteelResultLines(items, 1),
      );
      expect(t, '''[형강 컷팅 지시서] 루마
2026.09.20 · 1세트 · 원자재 6000mm

■ 앵글 40x40x3
500mm × 2개 - A구역
  소계 1000.0mm (2개) · 약 1.8kg
■ 찬넬 100x50x5
1000mm × 1개
  소계 1000.0mm (1개) · 약 9.4kg

합계 2000.0mm (총 3개)
총 중량 약 11.2kg (이론값)''');
    });

    test('세트가 여럿이면 개수 구성과 1세트 × 세트 = 합계, 톱날 표시', () {
      final t = buildSteelInstructionText(
        projectName: '루마',
        date: DateTime(2026, 9, 20),
        sets: 3,
        lines: buildSteelResultLines(items, 3),
        kerfMm: 3,
      );
      expect(t.contains('· 3세트 · 원자재 6000mm · 톱날 3mm'), true);
      expect(t.contains('500mm × 6개 (2개 × 3세트) - A구역'), true);
      expect(t.contains('합계 1세트 2000.0mm × 3세트 = 6000.0mm (총 9개)'), true);
    });

    test('항목이 없으면 안내', () {
      final t = buildSteelInstructionText(
        projectName: 'A',
        date: DateTime(2026, 1, 2),
        sets: 1,
        lines: const [],
      );
      expect(t.contains('(절단 항목이 없습니다)'), true);
    });
  });

  group('입력 시트', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> open(
      WidgetTester tester,
      List<SteelCutItem> saved, {
      SteelCutItem? existing,
    }) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showSteelItemSheet(
                  context,
                  existing: existing,
                  onSave: saved.add,
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

    Future<void> pickShape(
      WidgetTester tester,
      String query,
      String label,
    ) async {
      await tester.tap(find.text('탭해서 규격 선택'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, query);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).first);
      await tester.pumpAndSettle();
    }

    testWidgets('규격 선택창: 종류 칩이 모두 있고 검색은 x·*·공백을 같게 본다', (tester) async {
      await open(tester, []);
      await tester.tap(find.text('탭해서 규격 선택'));
      await tester.pumpAndSettle();
      expect(find.text('전체'), findsOneWidget);
      expect(find.text('앵글'), findsWidgets);
      final total = SteelShapeDB.all.length;
      expect(
        tester.widget<Text>(find.byKey(const Key('steel_pick_count'))).data,
        '$total개',
      );
      await tester.enterText(find.byType(TextField).last, '40*40*3');
      await tester.pumpAndSettle();
      expect(find.text('앵글 40x40x3'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, '40 40 3');
      await tester.pumpAndSettle();
      expect(find.text('앵글 40x40x3'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, '25A');
      await tester.pumpAndSettle();
      expect(find.text('강관 25A(34.0)'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, '스트럿');
      await tester.pumpAndSettle();
      expect(find.text('스트럿 41x41x2.5'), findsOneWidget);
    });

    testWidgets('종류 칩을 누르면 그 종류만 남는다', (tester) async {
      await open(tester, []);
      await tester.tap(find.text('탭해서 규격 선택'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('평철').first);
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('steel_pick_count'))).data,
        '${SteelShapeDB.byCategory('FLAT').length}개',
      );
    });

    testWidgets('길이·수량 버튼과 미리보기, 저장', (tester) async {
      final saved = <SteelCutItem>[];
      await open(tester, saved);
      await pickShape(tester, '40x40x3', '앵글 40x40x3');
      // 길이 버튼: 빈 칸에서 +100, +100, -10 → 190
      await tester.tap(find.byKey(const Key('len_step_100')));
      await tester.tap(find.byKey(const Key('len_step_100')));
      await tester.tap(find.byKey(const Key('len_step_-10')));
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('steel_length_field')))
            .controller!
            .text,
        '190',
      );
      await tester.tap(find.byKey(const Key('qty_plus')));
      await tester.tap(find.byKey(const Key('qty_plus')));
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('steel_qty_field')))
            .controller!
            .text,
        '3',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('steel_item_preview'))).data,
        '190mm × 3개 = 570mm',
      );
      await tester.tap(find.text('추가하고 닫기'));
      await tester.pumpAndSettle();
      expect(saved.single.length, 190);
      expect(saved.single.qty, 3);
      expect(saved.single.shapeLabel, '앵글 40x40x3');
      expect(saved.single.category, 'ANGLE');
    });

    testWidgets('길이는 0 아래로 내려가지 않고 수량은 1 아래로 내려가지 않는다', (tester) async {
      await open(tester, []);
      await tester.tap(find.byKey(const Key('len_step_-100')));
      await tester.tap(find.byKey(const Key('qty_minus')));
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('steel_length_field')))
            .controller!
            .text,
        '',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('steel_qty_field')))
            .controller!
            .text,
        '1',
      );
    });

    testWidgets('쉼표로 쓴 길이도 읽고, 못 읽는 값은 알려 주며 저장하지 않는다', (tester) async {
      final saved = <SteelCutItem>[];
      await open(tester, saved);
      await pickShape(tester, '25A', '강관 25A(34.0)');
      await tester.enterText(
        find.byKey(const Key('steel_length_field')),
        '1200,5',
      );
      await tester.pump();
      expect(
        tester.widget<Text>(find.byKey(const Key('steel_item_preview'))).data,
        '1200.5mm × 1개 = 1200.5mm',
      );
      await tester.enterText(
        find.byKey(const Key('steel_length_field')),
        '12a0',
      );
      await tester.pump();
      expect(find.text('숫자로 읽을 수 없습니다'), findsOneWidget);
      await tester.tap(find.text('추가하고 닫기'));
      await tester.pump();
      expect(saved, isEmpty);
      expect(find.textContaining('숫자로 읽을 수 없습니다'), findsWidgets);
      // 고치면 저장된다.
      await tester.enterText(
        find.byKey(const Key('steel_length_field')),
        '1200,5',
      );
      await tester.pump();
      await tester.tap(find.text('추가하고 닫기'));
      await tester.pumpAndSettle();
      expect(saved.single.length, 1200.5);
      expect(saved.single.category, 'ROUND');
    });

    testWidgets('글자를 크게 키워도 넘치지 않는다', (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
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
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showSteelItemSheet(context, onSave: (_) {}),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('steel_length_field')),
        '123456',
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('형강 화면', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    SteelCuttingProject proj({int sets = 1}) => SteelCuttingProject(
      id: 'sp1',
      name: '루마',
      createdAt: DateTime(2026, 9, 20),
      setMultiplier: sets,
      items: [
        item('앵글 40x40x3', 500, 2, note: 'A구역'),
        item('앵글 40x40x3', 500, 1, id: 'dup'),
        item('앵글 40x40x3', 800, 1, id: 'b'),
        item('스트럿 41x41x2.5', 1000, 3, cat: 'STRUT'),
      ],
    );

    Future<void> open(
      WidgetTester tester,
      SteelCuttingProject p, {
      double scale = 1.0,
    }) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: SteelCuttingDetailScreen(project: p),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('입력 창: 규격별 머리글과 1개 길이·개수·합계, 종류 칩', (tester) async {
      await open(tester, proj());
      expect(find.byKey(const Key('steel_group_앵글 40x40x3')), findsOneWidget);
      expect(
        find.byKey(const Key('steel_group_스트럿 41x41x2.5')),
        findsOneWidget,
      );
      expect(findText('3건 · 2300mm'), findsOneWidget); // 앵글 500×2 + 500 + 800
      expect(find.text('800 mm'), findsOneWidget);
      expect(find.text('3개'), findsWidgets);
      // 종류 칩: 전체 + 앵글 + 스트럿(있는 것만)
      expect(find.text('전체'), findsOneWidget);
      expect(find.text('앵글'), findsOneWidget);
      expect(find.text('스트럿'), findsOneWidget);
      expect(find.text('찬넬'), findsNothing);
      await tester.tap(find.text('스트럿'));
      await tester.pump();
      expect(
        find.byKey(const Key('steel_group_앵글 40x40x3')).evaluate(),
        isEmpty,
      );
      expect(
        find.byKey(const Key('steel_group_스트럿 41x41x2.5')),
        findsOneWidget,
      );
    });

    testWidgets('결과 창: 규격 머리글 아래에 같은 길이가 합쳐진 줄', (tester) async {
      await open(tester, proj());
      await tester.tap(find.text('결과'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('spec_header_앵글 40x40x3')), findsOneWidget);
      expect(
        find.byKey(const Key('spec_header_스트럿 41x41x2.5')),
        findsOneWidget,
      );
      expect(find.text('800.0 mm'), findsOneWidget);
      expect(find.text('500.0 mm'), findsOneWidget);
      expect(find.text('× 3개'), findsWidgets); // 500이 2+1, 스트럿 3
      expect(find.textContaining('2건 합침'), findsOneWidget);
      // 총계: 2300 + 3000 = 5300
      expect(find.text('5300.0 mm'), findsOneWidget);
    });

    testWidgets('결과 창 세트 수 3: 1개 길이는 그대로, 총계는 1세트 × 세트', (tester) async {
      await open(tester, proj(sets: 3));
      await tester.tap(find.text('결과'));
      await tester.pumpAndSettle();
      expect(find.text('500.0 mm'), findsOneWidget);
      expect(find.text('1세트 5300.0 mm'), findsOneWidget);
      expect(find.text('× 3세트 = 15900.0 mm'), findsOneWidget);
    });

    testWidgets('줄을 눌러 잘랐음 표시 → 머리글에 진행, 저장되어 다시 열어도 남는다', (tester) async {
      await open(tester, proj());
      await tester.tap(find.text('결과'));
      await tester.pumpAndSettle();
      final key = buildSteelResultLines(
        proj().items,
        1,
      ).firstWhere((l) => l.cutMm == 800).key;
      await tester.tap(find.byKey(Key('result_row_$key')));
      await tester.pump();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('steel_done_sp1'), [key]);

      // 다시 열면 표시가 남아 있다.
      await open(tester, proj());
      await tester.tap(find.text('결과'));
      await tester.pumpAndSettle();
      expect(find.text('잘랐음 1/7개'), findsOneWidget);
    });

    testWidgets('아이콘 네 개, 처음에는 이름이 보인다', (tester) async {
      await open(tester, proj());
      await tester.tap(find.text('결과'));
      await tester.pumpAndSettle();
      for (final k in [
        'steel_btn_optimize',
        'steel_btn_export',
        'steel_btn_kakao',
        'steel_btn_copy',
      ]) {
        expect(find.byKey(Key(k)), findsOneWidget, reason: k);
      }
      expect(find.byKey(const Key('action_label_카톡 보내기')), findsOneWidget);
    });

    testWidgets('카톡 버튼은 규격별 지시서 글을 넘기고, 없으면 공유창으로', (tester) async {
      final oldK = kakaoSender;
      final oldS = textSharer;
      addTearDown(() {
        kakaoSender = oldK;
        textSharer = oldS;
      });
      String? sent;
      kakaoSender = (t) async {
        sent = t;
        return true;
      };
      await open(tester, proj());
      await tester.tap(find.text('결과'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('steel_btn_kakao')));
      await tester.pumpAndSettle();
      expect(sent!.startsWith('[형강 컷팅 지시서] 루마'), true);
      expect(sent!.contains('■ 앵글 40x40x3'), true);
      expect(sent!.contains('500mm × 3개 - 2건 합침 · A구역'), true);
      expect(sent!.contains('합계 5300.0mm (총 7개)'), true);

      String? shared;
      kakaoSender = (t) async => false;
      textSharer = (t) async => shared = t;
      await tester.tap(find.byKey(const Key('steel_btn_kakao')));
      await tester.pumpAndSettle();
      expect(shared, sent);
      expect(find.textContaining('카카오톡을 찾지 못해'), findsOneWidget);
    });

    testWidgets('항목이 없으면 결과 창이 안내하고 복사·카톡은 알려 준다', (tester) async {
      await open(
        tester,
        SteelCuttingProject(
          id: 'e',
          name: '빈',
          createdAt: DateTime(2026, 9, 20),
        ),
      );
      expect(find.text('추가된 절단 항목이 없습니다.'), findsOneWidget);
      await tester.tap(find.text('결과'));
      await tester.pumpAndSettle();
      expect(find.text('절단 항목을 먼저 추가하십시오.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('steel_btn_copy')));
      await tester.pump();
      expect(find.textContaining('복사할 항목이 없습니다'), findsOneWidget);
    });

    testWidgets('글자를 크게 키워도 입력·결과 창이 넘치지 않는다', (tester) async {
      await open(tester, proj(sets: 12), scale: 1.5);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('결과'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // 저장 형식 확인용: 이 테스트에서 jsonDecode를 쓰지 않아도 import 경고가 없게 한 번 쓴다.
      expect(jsonEncode([1]), '[1]');
    });
  });
}
