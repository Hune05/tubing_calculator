import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/models/cutting_project_model.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_result_logic.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_result_view.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/screens/cutting_main_screen.dart';

import 'helpers_text.dart';

// 튜브 컷팅 결과 탭: 줄 만들기, 잘랐음 표시, 총계, 부속 목록, 지시서 글, 화면.
void main() {
  group('자를 길이 줄', () {
    test('묶지 않으면 구간마다 한 줄, 계산 못 하는 구간은 뺀다', () {
      final l = buildResultLines(
        [2600.0, null, 1400.5, -5, 0],
        2,
        grouped: false,
      );
      expect(l.map((e) => e.title), ['PT1 → PT2', 'PT3 → PT4']);
      expect(l.map((e) => e.count), [2, 2]);
      expect(l[1].totalMm, 2801.0);
      expect(l[0].detail, '구간 길이 2600.0 mm');
      expect(l[0].segments, [0]);
    });

    test('같은 길이는 하나로 묶고 처음 나온 순서를 지킨다', () {
      final l = buildResultLines(
        [500.0, 300.0, 500.04, 500.0],
        3,
        grouped: true,
      );
      expect(l.length, 2);
      expect(l[0].title, '500.0 mm');
      expect(l[0].count, 9); // 3구간 × 3세트
      expect(l[0].detail, 'PT1→2 · PT3→4 · PT4→5');
      expect(l[0].segments, [0, 2, 3]);
      expect(l[1].title, '300.0 mm');
      expect(l[1].count, 3);
    });

    test('세트 수가 0 이하여도 1세트로 센다', () {
      final l = buildResultLines([100.0], 0, grouped: false);
      expect(l.single.count, 1);
    });

    test('길이나 개수가 바뀌면 잘랐음 열쇠도 바뀐다', () {
      final a = buildResultLines([500.0], 1, grouped: true).single.key;
      final b = buildResultLines([500.0], 2, grouped: true).single.key;
      final c = buildResultLines([510.0], 1, grouped: true).single.key;
      expect({a, b, c}.length, 3);
      final s1 = buildResultLines([500.0], 1, grouped: false).single.key;
      expect(s1 == a, false); // 묶음 방식이 다르면 표시도 따로
    });

    test('빈 입력', () {
      expect(buildResultLines([], 1, grouped: true), isEmpty);
      expect(buildResultLines([null, null], 1, grouped: false), isEmpty);
    });
  });

  group('총계와 진행', () {
    final lines = buildResultLines([1000.0, 500.0, 500.0], 2, grouped: true);

    test('총 개수·길이', () {
      final s = summarizeResult(lines, {});
      expect(s.lineCount, 2);
      expect(s.totalPieces, 6);
      expect(s.totalMm, 2000 + 2000);
      expect(s.anyDone, false);
      expect(s.progress, 0);
    });

    test('잘랐음 표시는 개수 기준으로 진행률을 낸다', () {
      final s = summarizeResult(lines, {lines[1].key});
      expect(s.donePieces, 4);
      expect(s.doneLines, 1);
      expect(s.progress, closeTo(4 / 6, 1e-9));
      expect(s.allDone, false);
      final all = summarizeResult(lines, {lines[0].key, lines[1].key});
      expect(all.allDone, true);
      expect(all.progress, 1);
    });

    test('없어진 줄의 표시는 버린다', () {
      final kept = pruneDone({
        lines[0].key,
        'len:999.0:1',
        'seg:0:1.0:1',
      }, lines);
      expect(kept, {lines[0].key});
    });
  });

  group('필요한 부속', () {
    test('같은 것끼리 세고 세트 수를 곱하며 많은 것부터', () {
      final o = fittingOrderList(const [
        FittingUse(maker: 'Swagelok', spec: '1/2"', name: 'Tube Adapter'),
        FittingUse(maker: 'Swagelok', spec: '1/2"', name: 'Union Cross'),
        FittingUse(maker: 'Swagelok', spec: '1/2"', name: 'Union Cross'),
        FittingUse(maker: 'Swagelok', spec: '3/4"', name: 'Union Cross'),
      ], 2);
      expect(o.map((e) => '${e.label}=${e.qty}'), [
        'Union Cross 1/2"=4',
        'Tube Adapter 1/2"=2',
        'Union Cross 3/4"=2',
      ]);
    });

    test('제조사가 다르면 따로 센다, 규격을 모르면 이름만', () {
      final o = fittingOrderList(const [
        FittingUse(maker: 'Swagelok', spec: '1/2"', name: 'X'),
        FittingUse(maker: 'CUSTOM', spec: '미지정', name: 'X'),
      ], 1);
      expect(o.length, 2);
      expect(o.map((e) => e.label).toSet(), {'X 1/2"', 'X'});
    });

    test('없으면 빈 목록', () {
      expect(fittingOrderList(const [], 3), isEmpty);
    });
  });

  group('지시서 글', () {
    test('묶지 않은 목록과 부속', () {
      final lines = buildResultLines([2555.3, 1177.1], 2, grouped: false);
      final t = buildInstructionText(
        projectName: '루마 라인',
        date: DateTime(2026, 9, 20),
        maker: 'Swagelok',
        setMultiplier: 2,
        lines: lines,
        orders: fittingOrderList(const [
          FittingUse(maker: 'Swagelok', spec: '1/2"', name: 'Union Cross'),
        ], 2),
        kerfMm: 3,
      );
      expect(t, '''[컷팅 지시서] 루마 라인
2026.09.20 · Swagelok · 2세트 · 톱날 3mm

■ 자를 길이
1) PT1 → PT2 2555.3mm × 2개
2) PT2 → PT3 1177.1mm × 2개
합계 7464.8mm (총 4개)

■ 필요한 부속
Union Cross 1/2" × 2''');
    });

    test('묶은 목록은 길이가 앞에 나오고, 부속이 없으면 그 부분이 없다', () {
      final t = buildInstructionText(
        projectName: 'A',
        date: DateTime(2026, 1, 2),
        maker: 'Parker',
        setMultiplier: 1,
        lines: buildResultLines([600.0, 600.0], 1, grouped: true),
        orders: const [],
      );
      expect(t, '''[컷팅 지시서] A
2026.01.02 · Parker · 1세트

■ 자를 길이
1) 600.0mm × 2개
합계 1200.0mm (총 2개)''');
    });

    test('계산된 구간이 없으면 안내', () {
      final t = buildInstructionText(
        projectName: 'A',
        date: DateTime(2026, 1, 2),
        maker: 'Parker',
        setMultiplier: 1,
        lines: const [],
        orders: const [],
      );
      expect(t.contains('(계산된 구간이 없습니다)'), true);
    });
  });

  group('결과 목록 그림', () {
    Future<void> show(
      WidgetTester tester, {
      required List<ResultLine> lines,
      Set<String> done = const {},
      List<FittingOrder> orders = const [],
      ValueChanged<String>? onToggle,
      double scale = 1.0,
      int sets = 1,
      String warning = '',
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
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
          home: Scaffold(
            body: CuttingResultView(
              lines: lines,
              summary: summarizeResult(lines, done),
              orders: orders,
              done: done,
              onToggle: onToggle ?? (_) {},
              setMultiplier: sets,
              warning: warning,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('총계와 줄이 나오고 줄을 누르면 열쇠를 알려 준다', (tester) async {
      final lines = buildResultLines([2600.0, 1400.0], 1, grouped: false);
      final toggled = <String>[];
      await show(tester, lines: lines, onToggle: toggled.add);
      expect(find.text('4000.0 mm'), findsOneWidget);
      expect(find.text('총 2개 · 2종류'), findsOneWidget);
      expect(find.text('PT1 → PT2'), findsOneWidget);
      expect(find.text('잘랐음 0/2개'), findsOneWidget);
      await tester.tap(find.byKey(Key('result_row_${lines[1].key}')));
      expect(toggled, [lines[1].key]);
    });

    testWidgets('잘랐음 표시하면 진행 줄이 나오고 다 하면 저장 안내', (tester) async {
      final lines = buildResultLines([2600.0, 1400.0], 1, grouped: false);
      await show(tester, lines: lines, done: {lines[0].key});
      expect(find.text('잘랐음 1/2개'), findsOneWidget);
      expect(
        tester
            .widget<Icon>(find.byKey(Key('result_check_${lines[0].key}')))
            .icon,
        Icons.check_circle_rounded,
      );
      expect(
        tester
            .widget<Icon>(find.byKey(Key('result_check_${lines[1].key}')))
            .icon,
        Icons.radio_button_unchecked_rounded,
      );
      await show(tester, lines: lines, done: {lines[0].key, lines[1].key});
      expect(find.textContaining('모두 잘랐습니다'), findsOneWidget);
    });

    testWidgets('표시를 해도 줄 위치가 밀리지 않는다(잘못 누르지 않게)', (tester) async {
      final lines = buildResultLines([2600.0, 1400.0], 1, grouped: false);
      await show(tester, lines: lines);
      final before = tester.getTopLeft(
        find.byKey(Key('result_row_${lines[1].key}')),
      );
      await show(tester, lines: lines, done: {lines[0].key});
      expect(
        tester.getTopLeft(find.byKey(Key('result_row_${lines[1].key}'))),
        before,
      );
      await show(tester, lines: lines, done: {lines[0].key, lines[1].key});
      expect(
        tester.getTopLeft(find.byKey(Key('result_row_${lines[1].key}'))),
        before,
      );
    });

    testWidgets('부속 목록과 경고, 세트 수', (tester) async {
      final lines = buildResultLines([100.0], 3, grouped: false);
      await show(
        tester,
        lines: lines,
        sets: 3,
        warning: '목록에서 뺀 구간: 간섭 1곳',
        orders: fittingOrderList(const [
          FittingUse(maker: 'CUSTOM', spec: '미지정', name: '볼밸브'),
        ], 3),
      );
      expect(find.text('총 3개 · 1종류 · 3세트'), findsOneWidget);
      expect(find.text('필요한 부속'), findsOneWidget);
      expect(find.text('볼밸브'), findsOneWidget);
      expect(find.text('직접 입력'), findsOneWidget);
      expect(find.text('× 3'), findsOneWidget);
      expect(find.textContaining('간섭 1곳'), findsOneWidget);
    });

    testWidgets('줄이 없으면 안내 글', (tester) async {
      await show(tester, lines: const []);
      expect(find.text('치수를 입력하십시오.'), findsOneWidget);
    });

    testWidgets('글자를 크게 키워도 넘치지 않는다', (tester) async {
      final lines = buildResultLines(
        [2600.0, 1400.0, 2600.0, 123456.7],
        12,
        grouped: true,
      );
      await show(
        tester,
        lines: lines,
        done: {lines[0].key},
        scale: 1.6,
        sets: 12,
        warning: '목록에서 뺀 구간: 읽을 수 없는 값 2곳 · 간섭 3곳',
        orders: fittingOrderList(const [
          FittingUse(
            maker: 'Swagelok',
            spec: '1/2"',
            name: 'Adjustable Branch Tee Long Name',
          ),
        ], 12),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('결과 탭 화면', () {
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

    Future<void> fill(WidgetTester tester, List<String> values) async {
      for (var i = 0; i < values.length - 1; i++) {
        await tester.tap(find.text('포인트 추가'));
        await tester.pump();
      }
      for (var i = 0; i < values.length; i++) {
        await tester.enterText(lengthField(i), values[i]);
      }
      await tester.pump();
    }

    testWidgets('처음에는 같은 길이 합산이 켜져 있어 같은 길이가 한 줄로 묶인다', (tester) async {
      await open(tester);
      await fill(tester, ['600', '600', '900']);
      await tester.tap(find.text('결과'));
      await tester.pumpAndSettle();
      expect(find.text('2100.0 mm'), findsOneWidget); // 총계
      expect(find.text('총 3개 · 2종류'), findsOneWidget);
      expect(find.text('600.0 mm'), findsOneWidget);
      expect(find.text('× 2개'), findsOneWidget);
      expect(find.textContaining('PT1→2 · PT2→3'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, true);

      // 끄면 구간마다 한 줄.
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.text('PT1 → PT2'), findsOneWidget);
      expect(find.text('PT2 → PT3'), findsOneWidget);
      expect(find.text('PT3 → PT4'), findsOneWidget);
    });

    testWidgets('줄을 눌러 잘랐음 표시를 하고, 값을 바꾸면 그 표시가 사라진다', (tester) async {
      await open(tester);
      await fill(tester, ['600', '900']);
      await tester.tap(find.text('결과'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('result_row_len:600.0:1')));
      await tester.pump();
      expect(find.text('잘랐음 1/2개'), findsOneWidget);

      // 임시 저장에도 남는다.
      final prefs = await SharedPreferences.getInstance();
      final draft = jsonDecode(
        prefs.getString('cutting_draft_standalone_absolute_fixed_key')!,
      );
      expect(draft['doneKeys'], ['len:600.0:1']);

      // 길이를 고치면 표시가 사라진다.
      await tester.tap(find.text('입력'));
      await tester.pumpAndSettle();
      await tester.enterText(lengthField(0), '610');
      await tester.pump();
      await tester.tap(find.text('결과'));
      await tester.pumpAndSettle();
      expect(find.text('잘랐음 0/2개'), findsOneWidget);
    });

    testWidgets('저장하면 잘랐음 표시도 함께 지워진다', (tester) async {
      await open(tester);
      await fill(tester, ['600', '900']);
      await tester.tap(find.text('결과'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('result_row_len:600.0:1')));
      await tester.tap(find.byKey(const Key('result_row_len:900.0:1')));
      await tester.pump();
      expect(find.textContaining('모두 잘랐습니다'), findsOneWidget);
      await tester.tap(find.text('저장하기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('저장')); // 확인 창
      await tester.pumpAndSettle();
      expect(find.text('치수를 입력하십시오.'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      final draft = jsonDecode(
        prefs.getString('cutting_draft_standalone_absolute_fixed_key')!,
      );
      expect(draft['doneKeys'], isEmpty);
    });

    testWidgets('간섭·못 읽는 구간은 목록에서 빼고 이유를 알려 준다', (tester) async {
      await open(tester);
      await fill(tester, ['600', '12a', '-']);
      await tester.tap(find.text('결과'));
      await tester.pumpAndSettle();
      expect(find.text('600.0 mm'), findsWidgets);
      expect(find.textContaining('읽을 수 없는 값 2곳'), findsOneWidget);
    });

    testWidgets('글로 복사를 누르면 지시서가 복사된다', (tester) async {
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
      await fill(tester, ['600', '900']);
      await tester.tap(find.text('결과'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('result_btn_copy')));
      await tester.pumpAndSettle();
      expect(copied, isNotNull);
      expect(copied!.startsWith('[컷팅 지시서] 루마'), true);
      expect(copied!.contains('1) 600.0mm × 1개'), true);
      expect(copied!.contains('합계 1500.0mm (총 2개)'), true);
      expect(findTextContaining('글로 복사했습니다'), findsOneWidget);
    });

    testWidgets('치수가 없으면 복사할 것이 없다고 알려 준다', (tester) async {
      await open(tester);
      await tester.tap(find.text('결과'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('result_btn_copy')));
      await tester.pump();
      expect(find.textContaining('복사할 치수가 없습니다'), findsOneWidget);
    });

    testWidgets('세 버튼이 좁은 화면에서 넘치지 않는다', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
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
      await tester.tap(find.text('결과'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('result_btn_optimize')), findsOneWidget);
      expect(find.byKey(const Key('result_btn_export')), findsOneWidget);
      expect(find.byKey(const Key('result_btn_copy')), findsOneWidget);
    });
  });
}
