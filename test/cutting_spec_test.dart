import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/models/cutting_project_model.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_result_logic.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_result_view.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/screens/cutting_main_screen.dart';

// 결과 탭의 튜브 규격(제원): 부속에서 알아내기, 직접 지정, 줄·합계·지시서 글에 표시.
void main() {
  group('규격 알아내기', () {
    test('부속에서 알 수 있으면 그 규격, 시작 쪽 부속이 먼저', () {
      expect(
        tubeSpecFor(
          startIsFitting: true,
          startOD: '1/2"',
          endIsFitting: true,
          endOD: '3/4"',
        ),
        '1/2"',
      );
      expect(
        tubeSpecFor(
          startIsFitting: false,
          startOD: 'ALL',
          endIsFitting: true,
          endOD: '3/4"',
        ),
        '3/4"',
      );
    });

    test('ALL·미지정·빈 값은 모르는 것으로 보고 지정한 규격을 쓴다', () {
      for (final od in ['ALL', '미지정', '', '  ']) {
        expect(
          tubeSpecFor(
            startIsFitting: true,
            startOD: od,
            endIsFitting: true,
            endOD: od,
            fallback: '12mm',
          ),
          '12mm',
          reason: od,
        );
      }
    });

    test('부속이 아니면(직관) 그 쪽 값은 무시한다', () {
      expect(
        tubeSpecFor(
          startIsFitting: false,
          startOD: '1/2"',
          endIsFitting: false,
          endOD: '1/2"',
        ),
        '',
      );
    });
  });

  group('규격을 넣은 줄', () {
    test('규격이 다르면 길이가 같아도 묶지 않는다', () {
      final l = buildResultLines(
        [600.0, 600.0, 600.0],
        1,
        grouped: true,
        specs: ['1/2"', '3/4"', '1/2"'],
      );
      expect(l.length, 2);
      expect(l[0].spec, '1/2"');
      expect(l[0].count, 2);
      expect(l[0].detail, 'PT1→2 · PT3→4');
      expect(l[1].spec, '3/4"');
      expect(l[1].count, 1);
    });

    test('규격을 안 넘기면 예전처럼 길이만으로 묶는다', () {
      final l = buildResultLines([600.0, 600.0], 1, grouped: true);
      expect(l.length, 1);
      expect(l.single.spec, '');
      expect(l.single.key, 'len:600.0:2');
    });

    test('열쇠에 규격이 들어가서 규격을 바꾸면 잘랐음 표시가 사라진다', () {
      final a = buildResultLines([600.0], 1, grouped: true, specs: ['1/2"']);
      final b = buildResultLines([600.0], 1, grouped: true, specs: ['3/4"']);
      final none = buildResultLines([600.0], 1, grouped: true);
      expect({a.single.key, b.single.key, none.single.key}.length, 3);
      final u = buildResultLines([600.0], 1, grouped: false, specs: ['1/2"']);
      expect(u.single.key.contains('1/2"'), true);
    });

    test('규격별 합계', () {
      final l = buildResultLines(
        [1000.0, 500.0, 200.0],
        2,
        grouped: false,
        specs: ['1/2"', '3/4"', '1/2"'],
      );
      final t = specTotals(l);
      expect(t.map((e) => e.spec), ['1/2"', '3/4"']);
      expect(t[0].pieces, 4);
      expect(t[0].mm, 2400);
      expect(t[1].mm, 1000);
    });

    test('지시서 글과 저장 확인 글에 규격이 나온다', () {
      final lines = buildResultLines(
        [600.0, 900.0],
        1,
        grouped: true,
        specs: ['1/2"', ''],
      );
      final t = buildInstructionText(
        projectName: 'A',
        date: DateTime(2026, 1, 2),
        maker: 'Parker',
        setMultiplier: 1,
        lines: lines,
        orders: const [],
      );
      expect(t.contains('1) 1/2" 600.0mm × 1개'), true);
      expect(t.contains('2) 900.0mm × 1개'), true);
      final m = buildSaveConfirmMessage(
        baseMm: 1500,
        cutCount: 2,
        setMultiplier: 1,
        kerfLossMm: 0,
        orders: const [],
        notDoneLines: 0,
        anyDone: false,
        recordsToProject: false,
        canUndo: true,
        specs: specTotals(lines),
      );
      expect(m.contains('튜브 규격별: 1/2" 600.0mm · 규격 미지정 900.0mm.'), true);
      final none = buildSaveConfirmMessage(
        baseMm: 1500,
        cutCount: 2,
        setMultiplier: 1,
        kerfLossMm: 0,
        orders: const [],
        notDoneLines: 0,
        anyDone: false,
        recordsToProject: false,
        canUndo: true,
        specs: specTotals(buildResultLines([600.0], 1, grouped: true)),
      );
      expect(none.contains('튜브 규격별'), false);
    });
  });

  group('결과 목록의 규격 표시', () {
    Future<void> show(
      WidgetTester tester,
      List<ResultLine> lines, {
      String tubeSpec = '',
      VoidCallback? onPick,
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CuttingResultView(
              lines: lines,
              summary: summarizeResult(lines, {}),
              orders: const [],
              done: const {},
              onToggle: (_) {},
              tubeSpec: tubeSpec,
              onPickSpec: onPick,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('줄마다 규격이 나오고 규격별 합계가 나온다', (tester) async {
      final lines = buildResultLines(
        [600.0, 900.0, 300.0],
        1,
        grouped: true,
        specs: ['1/2"', '3/4"', ''],
      );
      await show(tester, lines, onPick: () {});
      expect(find.text('1/2"'), findsOneWidget);
      expect(find.text('3/4"'), findsOneWidget);
      expect(find.text('규격 미지정'), findsWidgets);
      expect(
        tester.widget<Text>(find.byKey(const Key('result_spec_totals'))).data,
        contains('1/2" 600.0mm (1개)'),
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('result_spec_label'))).data,
        '튜브 규격: 부속 기준(자동)',
      );
    });

    testWidgets('규격을 하나도 모르면 칩을 달지 않는다', (tester) async {
      final lines = buildResultLines([600.0, 900.0], 1, grouped: true);
      await show(tester, lines, onPick: () {});
      expect(find.text('규격 미지정'), findsNothing);
      expect(find.byKey(const Key('result_spec_totals')).evaluate(), isEmpty);
    });

    testWidgets('지정한 규격이 이름표에 나오고 누르면 고르는 동작을 부른다', (tester) async {
      var picked = 0;
      final lines = buildResultLines(
        [600.0],
        1,
        grouped: true,
        specs: ['12mm'],
      );
      await show(tester, lines, tubeSpec: '12mm', onPick: () => picked++);
      expect(
        tester.widget<Text>(find.byKey(const Key('result_spec_label'))).data,
        '튜브 규격: 12mm',
      );
      await tester.tap(find.byKey(const Key('result_spec_picker')));
      expect(picked, 1);
    });

    testWidgets('고르는 동작이 없으면 이름표가 없다', (tester) async {
      await show(tester, buildResultLines([600.0], 1, grouped: true));
      expect(find.byKey(const Key('result_spec_picker')).evaluate(), isEmpty);
    });

    testWidgets('글자를 크게 키워도 넘치지 않는다', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      final lines = buildResultLines(
        [600.0, 900.0, 1234567.8],
        12,
        grouped: true,
        specs: ['1/2" × 0.049T 긴 규격 이름', '3/4"', ''],
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: Scaffold(
            body: CuttingResultView(
              lines: lines,
              summary: summarizeResult(lines, {}),
              orders: const [],
              done: const {},
              onToggle: (_) {},
              tubeSpec: '1/2" × 0.049T 긴 규격 이름',
              onPickSpec: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('규격 고르기 화면', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Finder lengthField(int i) => find
        .byWidgetPredicate(
          (w) =>
              w is TextField &&
              (w.decoration?.labelText ?? '').startsWith('전체 길이'),
        )
        .at(i);

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CuttingMainScreen(
              project: CuttingProject(
                id: 'p1',
                name: '루마',
                createdAt: DateTime(2026, 9, 20),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(lengthField(0), '600');
      await tester.pump();
      await tester.tap(find.text('결과'));
      await tester.pumpAndSettle();
    }

    Map<String, dynamic> draft(SharedPreferences p) =>
        jsonDecode(p.getString('cutting_draft_standalone_absolute_fixed_key')!)
            as Map<String, dynamic>;

    testWidgets('처음에는 자동이고, 규격을 고르면 줄에 나오고 임시 저장된다', (tester) async {
      await open(tester);
      expect(find.text('튜브 규격: 부속 기준(자동)'), findsOneWidget);
      expect(find.text('규격 미지정'), findsNothing);
      await tester.tap(find.byKey(const Key('result_spec_picker')));
      await tester.pumpAndSettle();
      expect(find.text('자를 튜브 규격'), findsOneWidget);
      await tester.tap(find.byKey(const Key('spec_option_1/2"')));
      await tester.pumpAndSettle();
      expect(find.text('튜브 규격: 1/2"'), findsOneWidget);
      expect(find.text('1/2"'), findsWidgets);
      final prefs = await SharedPreferences.getInstance();
      expect(draft(prefs)['tubeSpec'], '1/2"');

      await tester.tap(find.byKey(const Key('result_spec_picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('spec_option_auto')));
      await tester.pumpAndSettle();
      expect(find.text('튜브 규격: 부속 기준(자동)'), findsOneWidget);
      expect(draft(prefs)['tubeSpec'], '');
    });

    testWidgets('직접 입력한 규격도 쓸 수 있고 복사한 글에 들어간다', (tester) async {
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
      await open(tester);
      await tester.tap(find.byKey(const Key('result_spec_picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('spec_option_custom')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('spec_custom_field')),
        '12mm',
      );
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(find.text('튜브 규격: 12mm'), findsOneWidget);
      await tester.tap(find.byKey(const Key('result_btn_copy')));
      await tester.pumpAndSettle();
      expect(copied!.contains('1) 12mm 600.0mm × 1개'), true);
    });

    testWidgets('규격을 바꾸면 그 줄의 잘랐음 표시가 사라진다', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('result_row_len:600.0:1')));
      await tester.pump();
      expect(find.text('모두 잘랐습니다. 저장하십시오.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('result_spec_picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('spec_option_3/8"')));
      await tester.pumpAndSettle();
      expect(find.text('잘랐음 0/1개'), findsOneWidget);
    });
  });

  group('규격이 없을 때 경고', () {
    test('규격을 모르는 줄 수', () {
      final l = buildResultLines(
        [600.0, 900.0, 300.0],
        1,
        grouped: false,
        specs: ['1/2"', '', ''],
      );
      expect(unknownSpecLineCount(l), 2);
      expect(
        unknownSpecLineCount(buildResultLines([600.0], 1, grouped: true)),
        1,
      );
      expect(unknownSpecLineCount(const []), 0);
    });

    test('저장 확인 글에 규격 없는 줄 수가 나온다', () {
      String m(int n) => buildSaveConfirmMessage(
        baseMm: 1500,
        cutCount: 2,
        setMultiplier: 1,
        kerfLossMm: 0,
        orders: const [],
        notDoneLines: 0,
        anyDone: false,
        recordsToProject: false,
        canUndo: true,
        unknownSpecLines: n,
      );
      expect(m(2).contains('튜브 규격이 지정되지 않은 줄이 2개 있습니다.'), true);
      expect(m(0).contains('튜브 규격이 지정되지 않은'), false);
    });
  });

  group('규격 경고·입력 탭 규격', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Finder lengthField(int i) => find
        .byWidgetPredicate(
          (w) =>
              w is TextField &&
              (w.decoration?.labelText ?? '').startsWith('전체 길이'),
        )
        .at(i);

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CuttingMainScreen(
              project: CuttingProject(
                id: 'p1',
                name: '루마',
                createdAt: DateTime(2026, 9, 20),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('입력 탭에도 규격 버튼이 있고 결과 탭과 같은 값을 쓴다', (tester) async {
      await open(tester);
      expect(
        tester.widget<Text>(find.byKey(const Key('input_spec_label'))).data,
        '튜브 규격: 부속 기준(자동)',
      );
      await tester.tap(find.byKey(const Key('input_spec_picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('spec_option_3/4"')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('input_spec_label'))).data,
        '튜브 규격: 3/4"',
      );
      // 결과 탭에도 그대로 나온다(따로 지정할 필요가 없다).
      await tester.enterText(lengthField(0), '600');
      await tester.pump();
      await tester.tap(find.text('결과'));
      await tester.pumpAndSettle();
      expect(find.text('튜브 규격: 3/4"'), findsOneWidget);
      expect(find.byKey(const Key('result_spec_warning')).evaluate(), isEmpty);
      // 결과 탭에서 바꾸면 입력 탭에도 반영된다.
      await tester.tap(find.byKey(const Key('result_spec_picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('spec_option_1"')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('입력'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('input_spec_label'))).data,
        '튜브 규격: 1"',
      );
    });

    testWidgets('규격이 없으면 결과 탭 위에 경고가 뜨고, 지정하면 사라진다', (tester) async {
      await open(tester);
      await tester.enterText(lengthField(0), '600');
      await tester.pump();
      await tester.tap(find.text('결과'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('result_spec_warning')), findsOneWidget);
      expect(find.textContaining('규격 없는 줄 1개'), findsOneWidget);
      // 경고를 누르면 규격 고르는 창이 열린다.
      await tester.tap(find.byKey(const Key('result_spec_warning')));
      await tester.pumpAndSettle();
      expect(find.text('자를 튜브 규격'), findsOneWidget);
      await tester.tap(find.byKey(const Key('spec_option_1/2"')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('result_spec_warning')).evaluate(), isEmpty);
    });

    testWidgets('규격 없이 저장하려 하면 확인 창에 알려 준다', (tester) async {
      await open(tester);
      await tester.enterText(lengthField(0), '600');
      await tester.pump();
      await tester.tap(find.text('결과'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('저장하기'));
      await tester.pumpAndSettle();
      expect(find.textContaining('튜브 규격이 지정되지 않은 줄이 1개'), findsOneWidget);
    });
  });
}
