import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/models/cutting_project_model.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_firestore_helper.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_result_logic.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/screens/cutting_main_screen.dart';

import 'helpers_text.dart';

// 저장하기: 저장 전 확인 창, 저장 직후 실행 취소, 되돌릴 때 자재 사용량 빼기.
void main() {
  group('저장 확인 글', () {
    String msg({
      double kerf = 0,
      List<FittingOrder> orders = const [],
      int notDone = 0,
      bool anyDone = false,
      bool toProject = false,
      bool canUndo = true,
      int sets = 2,
    }) => buildSaveConfirmMessage(
      baseMm: 5110.6,
      cutCount: 3,
      setMultiplier: sets,
      kerfLossMm: kerf,
      orders: orders,
      notDoneLines: notDone,
      anyDone: anyDone,
      recordsToProject: toProject,
      canUndo: canUndo,
    );

    test('길이와 구간·세트 수, 되돌릴 수 있다는 안내', () {
      final t = msg();
      expect(t.contains('총 5110.6mm입니다 (구간 3개 × 2세트)'), true);
      expect(t.contains('저장하면 누적 사용량에 더해지고, 입력이 비워집니다.'), true);
      expect(t.contains('저장한 뒤 10초 동안은 "실행 취소"로 되돌릴 수 있습니다.'), true);
      expect(t.contains('톱날'), false);
      expect(t.contains('부속'), false);
      expect(t.contains('표시를 하지 않은'), false);
    });

    test('톱날 손실이 있으면 더한 값을 보여 준다', () {
      final t = msg(kerf: 12);
      expect(t.contains('톱날 손실 12.0mm가 더해져 5122.6mm로 기록됩니다.'), true);
    });

    test('프로젝트에 저장하는 화면은 컷팅 기록·재고 차감 대기를 알려 준다', () {
      final t = msg(toProject: true);
      expect(t.contains('컷팅 기록과 자재 사용량(재고 차감 대기)'), true);
    });

    test('되돌릴 수 없는 화면은 실행 취소 문구가 없다', () {
      expect(msg(canUndo: false).contains('실행 취소'), false);
    });

    test('부속은 세 종류까지 보이고 나머지는 개수로', () {
      final orders = [
        for (var i = 1; i <= 5; i++)
          FittingOrder(maker: 'S', spec: '1/2"', name: '부속$i', qty: 6 - i),
      ];
      final t = msg(orders: orders);
      expect(
        t.contains('사용한 부속: 부속1 1/2" ×5 · 부속2 1/2" ×4 · 부속3 1/2" ×3 외 2종.'),
        true,
      );
    });

    test('표시를 일부만 했을 때만 안 한 줄을 알려 준다', () {
      expect(msg(anyDone: true, notDone: 2).contains('표시를 하지 않은 줄이 2개'), true);
      expect(msg(anyDone: false, notDone: 2).contains('표시를 하지 않은'), false);
      expect(msg(anyDone: true, notDone: 0).contains('표시를 하지 않은'), false);
    });
  });

  group('자재 사용량 되돌리기', () {
    const fits = [
      {
        'db_name': '[S] 1/2" Union',
        'maker': 'S',
        'spec': '1/2"',
        'name': 'Union',
        'qty': 2,
      },
    ];

    test('더했다가 빼면 원래대로', () {
      final original = <dynamic>[
        {'db_name': 'TUBE (기본)', 'type': 'TUBE', 'qty_mm': 3000.0},
        {'db_name': '[S] 1/2" Union', 'type': 'FITTING', 'qty_ea': 1},
      ];
      final added = mergeMaterialsUsage(original, 1500, fits);
      expect(added.firstWhere((m) => m['type'] == 'TUBE')['qty_mm'], 4500);
      final back = subtractMaterialsUsage(added, 1500, fits);
      expect(back.length, 2);
      expect(back.firstWhere((m) => m['type'] == 'TUBE')['qty_mm'], 3000);
      expect(back.firstWhere((m) => m['type'] == 'FITTING')['qty_ea'], 1);
    });

    test('이번에 처음 생긴 항목은 빼면 사라진다', () {
      final added = mergeMaterialsUsage([], 900, fits);
      expect(added.length, 2);
      expect(subtractMaterialsUsage(added, 900, fits), isEmpty);
    });

    test('그 사이 재고 차감으로 비워졌다면 아무 일도 없다', () {
      expect(subtractMaterialsUsage([], 900, fits), isEmpty);
    });

    test('남은 값보다 많이 빼도 음수가 되지 않고 사라진다', () {
      final cur = <dynamic>[
        {'db_name': 'TUBE (기본)', 'type': 'TUBE', 'qty_mm': 400.0},
      ];
      expect(subtractMaterialsUsage(cur, 900, const []), isEmpty);
    });
  });

  group('저장하기 화면', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Finder lengthField(int i) => find
        .byWidgetPredicate(
          (w) =>
              w is TextField &&
              (w.decoration?.labelText ?? '').startsWith('전체 길이'),
        )
        .at(i);

    Future<void> open(
      WidgetTester tester,
      CuttingProject project, {
      Function(double, List<Map<String, dynamic>>, [List<CutRecord>])? onSave,
      Function(double, List<Map<String, dynamic>>, List<CutRecord>)? onUndo,
    }) async {
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CuttingMainScreen(
              project: project,
              onSaveCallback: onSave,
              onUndoCallback: onUndo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('포인트 추가'));
      await tester.pump();
      await tester.enterText(lengthField(0), '600');
      await tester.enterText(lengthField(1), '900');
      await tester.pump();
      await tester.tap(find.text('결과'));
      await tester.pumpAndSettle();
    }

    CuttingProject proj() =>
        CuttingProject(id: 'p1', name: '루마', createdAt: DateTime(2026, 9, 20));

    testWidgets('저장하기를 누르면 확인 창이 먼저 뜨고 취소하면 그대로다', (tester) async {
      final p = proj();
      await open(tester, p);
      await tester.tap(find.text('저장하기'));
      await tester.pumpAndSettle();
      expect(find.text('저장하시겠습니까?'), findsOneWidget);
      expect(
        find.textContaining('총 1500.0mm입니다 (구간 2개 × 1세트)'),
        findsOneWidget,
      );
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(p.totalTubeUsed, 0);
      expect(find.textContaining('1500.0 mm'), findsWidgets);
    });

    testWidgets('저장하면 누적에 더해지고 입력이 비워지고 실행 취소가 나온다', (tester) async {
      final p = proj();
      await open(tester, p);
      await tester.tap(find.text('저장하기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(p.totalTubeUsed, 1500);
      expect(p.cutCount, 1);
      expect(find.text('치수를 입력하십시오.'), findsOneWidget);
      expect(find.text('실행 취소'), findsOneWidget);
    });

    testWidgets('실행 취소를 누르면 입력과 누적이 원래대로 돌아온다', (tester) async {
      final p = proj();
      await open(tester, p);
      // 세트 수와 표시도 함께 돌아오는지 보려고 표시를 하나 해 둔다.
      await tester.tap(find.byKey(const Key('result_row_len:600.0:1')));
      await tester.pump();
      await tester.tap(find.text('저장하기'));
      await tester.pumpAndSettle();
      expect(find.textContaining('아직 잘랐음 표시를 하지 않은 줄이 1개'), findsOneWidget);
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('실행 취소'));
      await tester.pumpAndSettle();
      expect(p.totalTubeUsed, 0);
      expect(p.cutCount, 0);
      expect(find.text('잘랐음 1/2개'), findsOneWidget);
      expect(find.text('1500.0 mm'), findsOneWidget);
      expect(findTextContaining('저장을 취소하고 입력을 되돌렸습니다'), findsOneWidget);
      // 입력 탭에도 값이 되돌아와 있다.
      await tester.tap(find.text('입력'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(lengthField(0)).controller!.text, '600');
      expect(tester.widget<TextField>(lengthField(1)).controller!.text, '900');
    });

    testWidgets('바깥에 저장하는 화면은 저장 값을 넘기고, 취소하면 같은 값으로 되돌리기를 부른다', (
      tester,
    ) async {
      final saved = <double>[];
      final undone = <double>[];
      final savedRecords = <int>[];
      final undoneRecords = <int>[];
      final p = proj();
      await open(
        tester,
        p,
        onSave: (t, f, [r = const <CutRecord>[]]) {
          saved.add(t);
          savedRecords.add(r.length);
        },
        onUndo: (t, f, r) {
          undone.add(t);
          undoneRecords.add(r.length);
        },
      );
      await tester.tap(find.text('저장하기'));
      await tester.pumpAndSettle();
      expect(find.textContaining('재고 차감 대기'), findsOneWidget);
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(saved, [1500]);
      expect(savedRecords, [2]);
      await tester.tap(find.text('실행 취소'));
      await tester.pumpAndSettle();
      expect(undone, [1500]);
      expect(undoneRecords, [2]);
      expect(p.totalTubeUsed, 0);
    });

    testWidgets('되돌릴 콜백이 없는 화면은 실행 취소를 주지 않는다', (tester) async {
      final p = proj();
      await open(tester, p, onSave: (t, f, [r = const <CutRecord>[]]) {});
      await tester.tap(find.text('저장하기'));
      await tester.pumpAndSettle();
      expect(find.textContaining('실행 취소'), findsNothing);
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(find.text('실행 취소'), findsNothing);
      expect(find.textContaining('작업 완료'), findsOneWidget);
    });

    testWidgets('저장 뒤 새로 입력한 값이 있으면 되돌리기 전에 한 번 더 묻는다', (tester) async {
      final p = proj();
      await open(tester, p);
      await tester.tap(find.text('저장하기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('입력'));
      await tester.pumpAndSettle();
      await tester.enterText(lengthField(0), '111');
      await tester.pump();
      await tester.tap(find.text('실행 취소'));
      await tester.pumpAndSettle();
      expect(find.text('저장을 되돌리시겠습니까?'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(p.totalTubeUsed, 1500); // 취소하면 저장은 그대로
      expect(tester.widget<TextField>(lengthField(0)).controller!.text, '111');
    });
  });
}
