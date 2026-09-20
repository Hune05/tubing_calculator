import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/models/cutting_project_model.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_leftovers.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_record_export.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/widgets/cutting_optimization_sheet.dart';

import 'helpers_text.dart';

// 컷팅 기록 내보내기 표, 그리고 재단 계획 화면의 "여러 길이 섞어 쓰기".
CutRecord rec(
  String id,
  DateTime at, {
  String size = '1/2"',
  String start = '직관',
  String end = '유니온',
  double cut = 500,
  int mult = 1,
}) => CutRecord(
  id: id,
  projectId: 'p',
  timestamp: at,
  tubeSize: size,
  originalLength: cut + 10,
  startFitting: start,
  endFitting: end,
  cutLength: cut,
  multiplier: mult,
);

void main() {
  // 잔재는 앱에서는 서버에 두지만, 테스트에서는 폰(prefs) 저장소로 바꿔 쓴다.
  leftoverStore = PrefsLeftoverStore();

  specGroups();
  group('컷팅 기록 표', () {
    test('날짜 오름차순으로 나오고 합계는 수량을 곱한다', () {
      final e = buildRecordExport([
        rec('b', DateTime(2026, 9, 14), cut: 300, mult: 2),
        rec('a', DateTime(2026, 9, 13), cut: 500.5),
      ]);
      expect(e.rows, [
        ['9/13', '1/2"', '직관 → 유니온', '500.5', '1', '500.5'],
        ['9/14', '1/2"', '직관 → 유니온', '300.0', '2', '600.0'],
      ]);
      expect(e.totalCount, 3);
      expect(e.totalMm, 1100.5);
      expect(recordPeriodText(e), '9/13 ~ 9/14');
    });

    test('규격별 합계, 규격이 비면 규격 미지정', () {
      final e = buildRecordExport([
        rec('1', DateTime(2026, 9, 13), size: '1/2"', cut: 100, mult: 2),
        rec('2', DateTime(2026, 9, 13), size: '3/4"', cut: 200),
        rec('3', DateTime(2026, 9, 13), size: '1/2"', cut: 50),
        rec('4', DateTime(2026, 9, 13), size: '', cut: 10),
      ]);
      expect(e.byTubeSize['1/2"'], (count: 3, mm: 250.0));
      expect(e.byTubeSize['3/4"'], (count: 1, mm: 200.0));
      expect(e.byTubeSize['규격 미지정'], (count: 1, mm: 10.0));
      // 규격별 합계를 더하면 전체와 같다.
      final sum = e.byTubeSize.values.fold(0.0, (s, v) => s + v.mm);
      expect(sum, e.totalMm);
    });

    test('수량이 0 이하로 저장돼도 1개로 센다, 부속 이름이 비면 직관', () {
      final e = buildRecordExport([
        rec('1', DateTime(2026, 9, 13), mult: 0, start: '', end: ''),
      ]);
      expect(e.rows.single[2], '직관 → 직관');
      expect(e.rows.single[4], '1');
      expect(e.totalCount, 1);
    });

    test('기록이 없으면 빈 표', () {
      final e = buildRecordExport([]);
      expect(e.rows, isEmpty);
      expect(e.totalMm, 0);
      expect(recordPeriodText(e), '');
    });

    test('하루만 있으면 기간에 그 날짜 하나', () {
      final e = buildRecordExport([rec('1', DateTime(2026, 9, 13))]);
      expect(recordPeriodText(e), '9/13');
    });
  });

  group('섞어 쓰기 설정 저장', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('저장한 길이를 다시 읽고, 꺼져 있으면 빈 목록', () async {
      expect(await loadMixLengths(), isEmpty);
      SharedPreferences.setMockInitialValues({
        kTubeMixPrefsKey: ['3000', '6000', 'x', '-5'],
      });
      expect(await loadMixLengths(), [3000.0, 6000.0]);
    });
  });

  group('재단 계획 화면: 여러 길이 섞어 쓰기', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> open(WidgetTester tester, List<double> pieces) async {
      tester.view.physicalSize = const Size(1080, 2600);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showCuttingOptimizationSheet(
                  context,
                  pieces: pieces,
                  initialStockLength: 6000,
                  mixPrefsKey: kTubeMixPrefsKey,
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

    testWidgets('켜면 짧은 조각은 3m로 줄어들고 설정이 저장된다', (tester) async {
      await open(tester, [5900, 2900]);
      expect(find.text('2본'), findsOneWidget);
      expect(find.text('3200mm'), findsOneWidget); // (6000-5900) + (6000-2900)

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      // 6m 한 본 + 3m 한 본, 남는 길이는 100mm+100mm
      expect(find.text('2본'), findsOneWidget);
      expect(find.text('200mm'), findsOneWidget);
      expect(find.textContaining('3000mm 원자재'), findsOneWidget);
      expect(await loadMixLengths(), [3000.0, 6000.0, 8000.0]);

      // 다시 끄면 저장도 지워진다.
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(await loadMixLengths(), isEmpty);
    });

    testWidgets('길이 칩을 눌러 빼고, 마지막 하나는 뺄 수 없다', (tester) async {
      await open(tester, [5900, 2900]);
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('3m'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('8m'));
      await tester.pumpAndSettle();
      expect(await loadMixLengths(), [6000.0]);
      await tester.tap(find.text('6m'));
      await tester.pumpAndSettle();
      expect(await loadMixLengths(), [6000.0]); // 마지막 하나는 그대로
      expect(findTextContaining('여러 길이'), findsWidgets);
    });

    testWidgets('저장해 둔 설정은 다음에 열 때 켜진 채로 나온다', (tester) async {
      SharedPreferences.setMockInitialValues({
        kTubeMixPrefsKey: ['3000', '6000'],
      });
      await open(tester, [5900, 2900]);
      final sw = tester.widget<Switch>(find.byType(Switch).first);
      expect(sw.value, true);
      expect(find.textContaining('3000mm 원자재'), findsOneWidget);
    });
  });
}

// ── 규격별 보기(기록 화면) ──
void specGroups() {
  group('기록의 규격', () {
    test('ALL·미지정·빈 값은 규격 미지정으로 본다', () {
      expect(normalizeSpec('ALL'), kUnknownSpecLabel);
      expect(normalizeSpec('미지정'), kUnknownSpecLabel);
      expect(normalizeSpec('  '), kUnknownSpecLabel);
      expect(normalizeSpec('1/2"'), '1/2"');
    });

    final recs = [
      rec('1', DateTime(2026, 9, 13), size: '1/2"', cut: 100, mult: 2),
      rec('2', DateTime(2026, 9, 13), size: 'ALL', cut: 50),
      rec('3', DateTime(2026, 9, 14), size: '3/4"', cut: 200),
      rec('4', DateTime(2026, 9, 14), size: '1/2"', cut: 30),
      rec('5', DateTime(2026, 9, 14), size: '', cut: 10),
    ];

    test('나오는 규격 목록(처음 나온 순서, 미지정은 하나로)', () {
      expect(recordSpecs(recs), ['1/2"', kUnknownSpecLabel, '3/4"']);
    });

    test('규격 하나만 남기기', () {
      expect(filterBySpec(recs, null).length, 5);
      expect(filterBySpec(recs, '1/2"').map((r) => r.id), ['1', '4']);
      expect(filterBySpec(recs, kUnknownSpecLabel).map((r) => r.id), [
        '2',
        '5',
      ]);
      expect(filterBySpec(recs, '1"'), isEmpty);
    });

    test('규격별 합계는 수량을 곱한다', () {
      final t = recordSpecTotals(recs);
      expect(t.map((e) => e.spec), ['1/2"', kUnknownSpecLabel, '3/4"']);
      expect(t[0].count, 3);
      expect(t[0].mm, 230);
      expect(t[1].count, 2);
      expect(t[1].mm, 60);
      expect(t.fold(0.0, (s, e) => s + e.mm), buildRecordExport(recs).totalMm);
    });

    test('내보내는 표에도 같은 이름으로 나온다', () {
      final e = buildRecordExport(filterBySpec(recs, kUnknownSpecLabel));
      expect(e.rows.map((r) => r[1]).toSet(), {kUnknownSpecLabel});
    });
  });
}
