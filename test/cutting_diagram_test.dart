import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/presentation/common/app_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/models/cutting_project_model.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_diagram_view.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_math.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_theme.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/screens/cutting_main_screen.dart';

import 'helpers_text.dart';

// 튜브 컷팅 배치도: 선 길이·누적 위치·요약 계산, 화면 그림, 지점을 눌러 입력으로 이동.
DiagramPoint none() => const DiagramPoint(
  isNone: true,
  name: '직관',
  tubeOD: '',
  icon: AppGlyph.fitOther,
);

DiagramPoint fit(String name, {String od = '1/2"'}) =>
    DiagramPoint(isNone: false, name: name, tubeOD: od, icon: AppGlyph.fitUnion);

DiagramSegment ok(double c2c, {double sd = 0, double ed = 0}) => DiagramSegment(
  state: SegmentState.ok,
  c2cMm: c2c,
  cutMm: c2c - sd - ed,
  startDeduction: sd,
  endDeduction: ed,
);

void main() {
  group('선 길이·누적 위치 계산', () {
    test('가장 긴 구간이 최대, 없으면 최소 높이', () {
      expect(segmentHeight(1000, 1000), 128);
      expect(segmentHeight(500, 1000), 92);
      expect(segmentHeight(null, 1000), 56);
      expect(segmentHeight(0, 1000), 56);
      expect(segmentHeight(-5, 1000), 56);
      expect(segmentHeight(300, 0), 56);
    });

    test('더 긴 구간일수록 선이 길다', () {
      final a = segmentHeight(300, 2600);
      final b = segmentHeight(1400, 2600);
      final c = segmentHeight(2600, 2600);
      expect(a < b && b < c, true);
    });

    test('누적 위치는 중심 간 거리를 이어 더하고, 빠진 구간 뒤는 알 수 없다', () {
      expect(cumulativePositions([2600, 1400, 800]), [0, 2600, 4000, 4800]);
      expect(cumulativePositions([2600, null, 800]), [0, 2600, null, null]);
      expect(cumulativePositions([null]), [0, null]);
      expect(cumulativePositions([]), [0]);
    });

    test('부속 개수 글자는 많은 것부터, 같으면 이름순', () {
      expect(
        fittingCountsText(['엘보', '유니온', '유니온', '티', '엘보', '유니온']),
        '유니온 ×3 · 엘보 ×2 · 티 ×1',
      );
      expect(fittingCountsText(['B', 'A']), 'A ×1 · B ×1');
      expect(fittingCountsText([]), '');
      expect(fittingCountsText(['', '  ']), '');
    });
  });

  group('라인 요약', () {
    test('절단 길이 합계와 세트 수, 라인 전체 길이, 부속 개수', () {
      final s = summarizeDiagram(
        [none(), fit('유니온'), fit('유니온'), none()],
        [ok(2600, sd: 0, ed: 6), ok(1400, sd: 6, ed: 6), ok(800, sd: 6)],
        3,
      );
      expect(s.cutCount, 3);
      expect(s.oneSetCutMm, 2594 + 1388 + 794);
      expect(s.totalCutMm, (2594 + 1388 + 794) * 3);
      expect(s.lineLengthMm, 4800);
      expect(s.fittingText, '유니온 ×2');
      expect(s.emptyCount + s.unreadableCount + s.interferenceCount, 0);
    });

    test('미입력·읽을 수 없음·간섭은 합계에서 빼고 개수만 센다', () {
      final s = summarizeDiagram(
        [none(), none(), none(), none(), none()],
        [
          ok(1000),
          const DiagramSegment(state: SegmentState.empty),
          const DiagramSegment(state: SegmentState.unreadable),
          const DiagramSegment(
            state: SegmentState.interference,
            c2cMm: 10,
            cutMm: -5,
          ),
        ],
        1,
      );
      expect(s.cutCount, 1);
      expect(s.oneSetCutMm, 1000);
      expect(s.emptyCount, 1);
      expect(s.unreadableCount, 1);
      expect(s.interferenceCount, 1);
      expect(s.lineLengthMm, isNull); // 빠진 구간이 있어서 전체 길이를 모른다
    });

    test('세트 수가 0 이하여도 1세트로 센다', () {
      final s = summarizeDiagram([none(), none()], [ok(500)], 0);
      expect(s.totalCutMm, 500);
    });
  });

  group('배치도 그림', () {
    Future<void> show(
      WidgetTester tester,
      List<DiagramPoint> pts,
      List<DiagramSegment> segs, {
      int? focused,
      int sets = 1,
      double scale = 1.0,
      ValueChanged<int>? onTap,
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
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: CuttingDiagramView(
                points: pts,
                segments: segs,
                focusedIndex: focused,
                setMultiplier: sets,
                onTapPoint: onTap ?? (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Color? colorOf(WidgetTester tester, Key key) =>
        tester.widget<Text>(find.byKey(key)).style?.color;

    testWidgets('구간 길이와 계산 과정, 누적 위치, 요약이 나온다', (tester) async {
      await show(
        tester,
        [none(), fit('유니온'), none()],
        [ok(2600, ed: 6), ok(1400, sd: 6)],
        sets: 2,
      );
      expect(find.text('PT1'), findsOneWidget);
      expect(find.text('유니온'), findsOneWidget);
      // 직관 지점에는 "직관 (부속 없음)" 같은 반복 글자가 없다.
      expect(find.textContaining('부속 없음'), findsNothing);
      expect(find.text('절단 2594.0mm = 2600 − 6'), findsOneWidget);
      expect(find.text('절단 1394.0mm = 1400 − 6'), findsOneWidget);
      expect(find.text('시작점'), findsOneWidget);
      expect(find.text('시작에서 2600mm · 1/2"'), findsOneWidget);
      expect(find.text('시작에서 4000mm'), findsOneWidget);
      expect(find.text('3988.0mm'), findsOneWidget);
      expect(find.text('7976.0mm'), findsOneWidget); // 2세트
      expect(find.text('4000mm'), findsOneWidget);
      expect(find.text('유니온 ×1'), findsOneWidget);
    });

    testWidgets('정상 길이는 청록색, 빨강은 오류에만 쓴다', (tester) async {
      await show(
        tester,
        [none(), none(), none(), none()],
        [
          ok(1000),
          const DiagramSegment(
            state: SegmentState.interference,
            c2cMm: 10,
            cutMm: -5,
            startDeduction: 8,
            endDeduction: 7,
          ),
          const DiagramSegment(state: SegmentState.unreadable),
        ],
      );
      expect(
        colorOf(tester, const Key('diagram_seg_0')),
        CuttingColors.primary,
      );
      expect(colorOf(tester, const Key('diagram_seg_1')), CuttingColors.danger);
      expect(colorOf(tester, const Key('diagram_seg_2')), CuttingColors.danger);
      expect(find.text('간섭 발생! 치수를 확인하십시오'), findsOneWidget);
      expect(find.text('숫자로 읽을 수 없습니다'), findsOneWidget);
      expect(find.textContaining('간섭 1곳'), findsOneWidget);
    });

    testWidgets('치수가 없는 구간은 회색으로 미입력 표시', (tester) async {
      await show(
        tester,
        [none(), none()],
        [const DiagramSegment(state: SegmentState.empty)],
      );
      expect(find.text('치수 미입력'), findsOneWidget);
      expect(find.text('시작점'), findsOneWidget);
      expect(find.textContaining('치수 미입력 1곳'), findsOneWidget);
      // 누적 위치와 라인 전체 길이는 알 수 없어서 나오지 않는다.
      expect(find.byKey(const Key('diagram_pos_1')).evaluate(), isEmpty);
      expect(find.byKey(const Key('diagram_line_length')).evaluate(), isEmpty);
    });

    testWidgets('지점을 누르면 그 번호를 알려 준다', (tester) async {
      final tapped = <int>[];
      await show(
        tester,
        [none(), none(), none()],
        [ok(1000), ok(500)],
        onTap: tapped.add,
      );
      await tester.tap(find.byKey(const Key('diagram_point_1')));
      await tester.tap(find.byKey(const Key('diagram_point_2')));
      expect(tapped, [1, 2]);
    });

    testWidgets('긴 구간의 선이 더 길게 그려진다', (tester) async {
      await show(tester, [none(), none(), none()], [ok(300), ok(2600)]);
      final h0 = tester
          .getSize(find.byKey(const Key('diagram_point_0')))
          .height;
      final h1 = tester
          .getSize(find.byKey(const Key('diagram_point_1')))
          .height;
      expect(h1 > h0, true);
    });

    testWidgets('글자를 크게 키워도 넘치지 않는다', (tester) async {
      await show(
        tester,
        [none(), fit('스웨이지락 유니온 아주 긴 이름 1/2"'), none(), fit('엘보'), none()],
        [
          ok(2600, ed: 6),
          const DiagramSegment(
            state: SegmentState.interference,
            c2cMm: 10,
            cutMm: -5,
            startDeduction: 8,
            endDeduction: 7,
          ),
          const DiagramSegment(state: SegmentState.empty),
          const DiagramSegment(state: SegmentState.unreadable),
        ],
        scale: 1.5,
        focused: 1,
        sets: 3,
      );
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('부속 아이콘', () {
    AppGlyph ic(String n, [String c = '']) => iconForFitting(n, c);

    test('앱에 들어 있는 부속 이름마다 맞는 아이콘', () {
      expect(ic('Union Elbow (90도)', 'Union'), AppGlyph.fitElbow);
      expect(ic('Elbow Adapter', 'Adapter'), AppGlyph.fitElbow);
      expect(ic('Union Tee (T자)', 'Union'), AppGlyph.fitTee);
      expect(ic('Union Cross (십자)', 'Union'), AppGlyph.fitCross);
      expect(ic('Ball Valve', 'Valve'), AppGlyph.fitValve);
      expect(ic('Needle Valve', 'Valve'), AppGlyph.fitValve);
      expect(ic('Check Valve', 'Valve'), AppGlyph.fitValve);
      expect(ic('Reducing Union', 'Union'), AppGlyph.fitReducer);
      expect(ic('Bulkhead Union', 'Union'), AppGlyph.fitBulkhead);
      expect(ic('Straight Union (일자)', 'Union'), AppGlyph.fitUnion);
      expect(ic('Male Connector', 'Connector'), AppGlyph.fitAdapter);
      expect(ic('Female Adapter', 'Adapter'), AppGlyph.fitAdapter);
      expect(ic('Tube Adapter', 'Adapter'), AppGlyph.fitAdapter);
    });

    test('직접 입력한 한글 이름도 알아본다', () {
      expect(ic('볼밸브', 'CUSTOM'), AppGlyph.fitValve);
      expect(ic('유니온', 'CUSTOM'), AppGlyph.fitUnion);
      expect(ic('엘보', 'CUSTOM'), AppGlyph.fitElbow);
      expect(ic('티', 'CUSTOM'), AppGlyph.fitTee);
      expect(ic('니플', 'CUSTOM'), AppGlyph.fitAdapter);
      expect(ic('플러그', 'CUSTOM'), AppGlyph.fitCap);
      expect(ic('용접 소켓', 'CUSTOM'), AppGlyph.fitOther);
    });
  });

  group('배치도 길게 누르기·넓은 화면', () {
    testWidgets('지점을 길게 누르면 그 번호를 알려 준다', (tester) async {
      final longs = <int>[];
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CuttingDiagramView(
              points: [none(), fit('유니온'), none()],
              segments: [ok(1000), ok(500)],
              onTapPoint: (_) {},
              onLongPressPoint: longs.add,
            ),
          ),
        ),
      );
      await tester.longPress(find.byKey(const Key('diagram_point_1')));
      expect(longs, [1]);
    });

    testWidgets('길게 누르기를 안 넘기면 아무 일도 없다', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CuttingDiagramView(
              points: [none(), none()],
              segments: [ok(1000)],
              onTapPoint: (_) {},
            ),
          ),
        ),
      );
      await tester.longPress(find.byKey(const Key('diagram_point_0')));
      expect(tester.takeException(), isNull);
    });
  });

  group('배치도 → 입력 이동', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Finder lengthField(int i) => find
        .byWidgetPredicate(
          (w) =>
              w is TextField &&
              (w.decoration?.labelText ?? '').startsWith('전체 길이'),
        )
        .at(i);

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 6000); // 목록이 전부 그려지도록 세로로 길게
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CuttingMainScreen(
              project: CuttingProject(
                id: 'p1',
                name: 'TEST',
                createdAt: DateTime(2026, 9, 20),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('입력한 값이 배치도에 나오고, 지점을 누르면 그 구간 입력 칸으로 간다', (tester) async {
      await open(tester);
      await tester.tap(find.text('포인트 추가'));
      await tester.pump();
      await tester.enterText(lengthField(0), '2600');
      await tester.enterText(lengthField(1), '1400');
      await tester.pump();

      await tester.tap(find.text('배치도'));
      await tester.pumpAndSettle();
      expect(find.text('시작에서 4000mm'), findsOneWidget);
      expect(find.text('4000.0mm'), findsOneWidget); // 총 절단 길이
      expect(find.text('4000mm'), findsOneWidget); // 라인 전체 길이

      // PT2를 누르면 입력 탭으로 돌아가 두 번째 길이 칸에 커서가 간다.
      await tester.tap(find.byKey(const Key('diagram_point_1')));
      await tester.pump();
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('diagram_point_1')).evaluate(), isEmpty);
      final tf = tester.widget<TextField>(lengthField(1));
      expect(tf.focusNode!.hasFocus, true);
    });

    testWidgets('잘못 쓴 값과 미입력은 배치도에도 표시된다', (tester) async {
      await open(tester);
      await tester.enterText(lengthField(0), '12a0');
      await tester.pump();
      await tester.tap(find.text('배치도'));
      await tester.pumpAndSettle();
      expect(find.text('숫자로 읽을 수 없습니다'), findsOneWidget);
      expect(find.textContaining('읽을 수 없는 값 1곳'), findsOneWidget);
    });

    testWidgets('아주 넓은 화면에서는 입력·배치도·결과가 세 칸으로 나란히 보인다', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CuttingMainScreen(
              project: CuttingProject(
                id: 'p1',
                name: 'TEST',
                createdAt: DateTime(2026, 9, 20),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('배관 라인 구축'), findsOneWidget);
      expect(find.text('배치도'), findsOneWidget);
      expect(find.text('컷팅 지시서'), findsOneWidget);
      expect(find.byType(TabBar), findsNothing);
      expect(tester.takeException(), isNull);

      // 배치도에서 지점을 누르면 옆의 입력 칸에 커서가 간다.
      await tester.enterText(lengthField(0), '1500');
      await tester.pump();
      await tester.tap(find.byKey(const Key('diagram_point_0')));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(
        tester.widget<TextField>(lengthField(0)).focusNode!.hasFocus,
        true,
      );
    });

    testWidgets('중간 너비(세로 태블릿)는 배치도와 결과를 오른쪽에 쌓는다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CuttingMainScreen(
              project: CuttingProject(
                id: 'p1',
                name: 'TEST',
                createdAt: DateTime(2026, 9, 20),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('배관 라인 구축'), findsOneWidget);
      expect(find.text('배치도'), findsOneWidget);
      expect(find.text('컷팅 지시서'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('배치도에서 지점을 길게 누르면 부속 선택창이 열린다', (tester) async {
      await open(tester);
      await tester.tap(find.text('배치도'));
      await tester.pumpAndSettle();
      await tester.longPress(find.byKey(const Key('diagram_point_1')));
      await tester.pumpAndSettle();
      // 선택창 안의 즐겨찾기 목록은 서버(Firestore)에서 읽어서 테스트에서는 오류가 나지만, 창이 열리는 것까지만 본다.
      expect(find.byType(BottomSheet), findsOneWidget);
      tester.takeException();
    });
  });
}
