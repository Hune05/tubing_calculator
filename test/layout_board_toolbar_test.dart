import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/layout_board_page.dart';

// 작업 배치도 위 막대·더보기·도구 칸.
// - 위 막대에는 자주 쓰는 것(되돌리기·다시 실행·저장·더보기)만 있다.
// - 전체 지우기는 더보기 안의 빨간 칸에 따로 있고, 한 번 더 묻는다.
// - 길게 눌러야만 되던 것(되돌리기 기록, 프리셋 지우기)을 단추로도 연다.
// - 장갑 끼고도 누르게: 누르는 곳 48dp 이상, 글씨 14 이상.

const Size kPhone = Size(390, 844);
const Size kTablet = Size(1024, 768);

void setSize(WidgetTester tester, Size s) {
  tester.view.physicalSize = s * 2;
  tester.view.devicePixelRatio = 2;
}

Map<String, dynamic> draft() => {
  'projectId': null,
  'projectName': '1호기 분전반',
  'panelWidth': 600,
  'panelHeight': 800,
  'items': [
    {'type': 'item', 'id': 'a', 'name': '차단기 A', 'x': 40, 'y': 40},
    {
      'type': 'item',
      'id': 'd',
      'name': '단자대',
      'x': 200,
      'y': 200,
      'w': 160,
      'h': 60,
    },
  ],
  'dimensions': [
    {
      'id': 'd1',
      'p1': {'type': 'item', 'id': 'a', 'name': '차단기 A', 'x': 40, 'y': 40},
      'p2': {'type': 'wall', 'id': 'wall_600_80', 'x': 600, 'y': 80},
      'type': 'center',
    },
  ],
};

const String presetsJson =
    '[{"name":"차단기 3P","width":90,"height":130},{"name":"SMPS","width":60,"height":120}]';

Future<void> openWithDraft(
  WidgetTester tester,
  Size size, {
  bool presets = false,
}) async {
  SharedPreferences.setMockInitialValues({
    'layout_board_onboarding_shown_v1': true,
    'layout_board_draft_v1': jsonEncode(draft()),
    if (presets) 'layout_board_custom_presets': presetsJson,
  });
  setSize(tester, size);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: LayoutBoardPage()));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pumpAndSettle();
  await tester.tap(find.text('이어하기'));
  await tester.pumpAndSettle();
}

Future<void> disposeBoard(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void expectTouchable(WidgetTester tester, Finder f) {
  final Size s = tester.getSize(f);
  expect(s.width, greaterThanOrEqualTo(48), reason: '$f 폭 $s');
  expect(s.height, greaterThanOrEqualTo(48), reason: '$f 높이 $s');
}

// 도면(확대·이동 안의 모듈 이름, 치수 글씨)은 mm 비율로 그리는 그림이라 빼고,
// 화면에 있는 글씨가 모두 14 이상인지 본다.
void expectNoSmallText(WidgetTester tester) {
  final Finder texts = find.byWidgetPredicate(
    (w) => w is RichText,
    skipOffstage: true,
  );
  final Finder inBoard = find.descendant(
    of: find.byType(InteractiveViewer),
    matching: find.byType(RichText),
  );
  final Set<Element> boardEls = inBoard.evaluate().toSet();
  final List<String> small = [];
  for (final el in texts.evaluate()) {
    if (boardEls.contains(el)) continue;
    final RichText rt = el.widget as RichText;
    // 아이콘 글자(MaterialIcons)는 빼고 본다.
    final TextStyle? st = rt.text.style;
    if (st?.fontFamily == 'MaterialIcons') continue;
    final double size = st?.fontSize ?? 14;
    if (size < 14) small.add('${rt.text.toPlainText()}($size)');
  }
  expect(small, isEmpty, reason: '14보다 작은 글씨: $small');
}

// keepWords가 글자 사이에 넣는 보이지 않는 이음표(U+2060)를 빼고 찾는다.
Finder findPlain(String part) => find.byWidgetPredicate(
  (w) => w is Text && (w.data ?? '').replaceAll('\u2060', '').contains(part),
);

// 글씨를 둘러싼 누르는 곳(InkWell).
Finder buttonOf(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first;

// 도면 위에 그려진 모듈 이름만(오른쪽 칸 이름 입력 칸은 빼고).
Finder onBoard(String name) => find.descendant(
  of: find.byType(InteractiveViewer),
  matching: find.text(name),
);

void main() {
  testWidgets('위 막대에는 되돌리기·다시 실행·저장·더보기만 있고 모두 48 이상', (tester) async {
    await openWithDraft(tester, kPhone);
    final Finder bar = find.byType(AppBar);
    for (final tip in ['뒤로', '되돌리기', '다시 실행', '저장·공유', '더보기']) {
      expect(
        find.descendant(of: bar, matching: find.byTooltip(tip)),
        findsOneWidget,
        reason: tip,
      );
      expectTouchable(
        tester,
        find.descendant(of: bar, matching: find.byTooltip(tip)),
      );
    }
    // 예전에 위 막대에 있던 다중 선택은 아래 칸으로 옮겼다.
    expect(
      find.descendant(of: bar, matching: find.byTooltip('다중 선택')),
      findsNothing,
    );
    expect(find.text('여러 개 선택'), findsOneWidget);
    // 폰 폭에서 제목(배치도 이름)이 잘리지 않는다. 저장은 아이콘 단추.
    final Finder name = find.descendant(
      of: bar,
      matching: find.text('1호기 분전반'),
    );
    expect(name, findsOneWidget);
    final RenderParagraph p = tester.renderObject(name);
    expect(p.didExceedMaxLines, isFalse);
    expect(find.descendant(of: bar, matching: find.text('저장')), findsNothing);
    await disposeBoard(tester);
  });

  testWidgets('폰 폭에서 미니맵은 접혀 있고, 눌러서 펴고 접는다', (tester) async {
    await openWithDraft(tester, kPhone);
    expect(find.byTooltip('미니맵 펴기'), findsOneWidget);
    expect(find.byTooltip('미니맵 접기'), findsNothing);
    await tester.tap(find.byTooltip('미니맵 펴기'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('미니맵 접기'), findsOneWidget);
    await tester.tap(find.byTooltip('미니맵 접기'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('미니맵 펴기'), findsOneWidget);
    await disposeBoard(tester);
  });

  testWidgets('도면 전체 지우기는 더보기의 빨간 칸에 있고, 묻고 나서 지운다', (tester) async {
    await openWithDraft(tester, kPhone);
    expect(find.text('차단기 A'), findsOneWidget);

    await tester.tap(find.byTooltip('더보기'));
    await tester.pumpAndSettle();
    expect(find.text('도면 전체 지우기'), findsOneWidget);
    expect(find.text('치수선 전체 지우기'), findsOneWidget);
    await tester.ensureVisible(find.text('도면 전체 지우기'));
    await tester.tap(find.text('도면 전체 지우기'));
    await tester.pumpAndSettle();

    // 확인 창: 취소하면 그대로다.
    expect(find.text('전체 지우기'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.text('차단기 A'), findsOneWidget);

    // 다시 열어 지운다.
    await tester.tap(find.byTooltip('더보기'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('도면 전체 지우기'));
    await tester.tap(find.text('도면 전체 지우기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('전체 지우기'));
    await tester.pumpAndSettle();
    expect(find.text('차단기 A'), findsNothing);

    // 되돌리기로 돌아온다.
    await tester.tap(find.byTooltip('되돌리기'));
    await tester.pumpAndSettle();
    expect(find.text('차단기 A'), findsOneWidget);
    await disposeBoard(tester);
  });

  testWidgets('치수선 전체 지우기도 묻고 나서 지우고, 모듈은 남는다', (tester) async {
    await openWithDraft(tester, kPhone);
    await tester.tap(find.byTooltip('더보기'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('치수선 전체 지우기'));
    await tester.tap(find.text('치수선 전체 지우기'));
    await tester.pumpAndSettle();
    expect(findPlain('치수선 1개를 모두 지웁니다'), findsOneWidget);
    await tester.tap(find.text('전체 지우기'));
    await tester.pumpAndSettle();
    expect(find.text('차단기 A'), findsOneWidget);

    // 치수선이 없으면 더보기의 치수선 지우기는 누를 수 없다.
    await tester.tap(find.byTooltip('더보기'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('치수선 전체 지우기'));
    await tester.tap(find.text('치수선 전체 지우기'));
    await tester.pumpAndSettle();
    expect(find.text('전체 지우기'), findsNothing);
    await disposeBoard(tester);
  });

  testWidgets('되돌리기 기록은 길게 누르지 않아도 더보기에서 연다', (tester) async {
    await openWithDraft(tester, kPhone);
    // 모듈 배치 → 치수 모드로 바꿔도 되돌리기 기록은 안 생기므로, 전체 지우기로 한 단계 만든다.
    await tester.tap(find.byTooltip('더보기'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('도면 전체 지우기'));
    await tester.tap(find.text('도면 전체 지우기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('전체 지우기'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('더보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('되돌리기 기록'));
    await tester.pumpAndSettle();
    expect(find.text('1단계 전으로 되돌리기'), findsOneWidget);
    await tester.tap(find.text('1단계 전으로 되돌리기'));
    await tester.pumpAndSettle();
    expect(find.text('차단기 A'), findsOneWidget);
    await disposeBoard(tester);
  });

  testWidgets('내 프리셋은 관리 단추에서 줄마다 지우기 단추로 지운다', (tester) async {
    await openWithDraft(tester, kPhone, presets: true);
    expect(find.text('차단기 3P'), findsOneWidget);
    await tester.tap(find.text('관리'));
    await tester.pumpAndSettle();
    expect(find.text('내 프리셋 관리'), findsOneWidget);
    expect(find.byTooltip('프리셋 삭제'), findsNWidgets(2));
    expectTouchable(tester, find.byTooltip('프리셋 삭제').first);
    await tester.tap(find.byTooltip('프리셋 삭제').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('프리셋 삭제'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('layout_board_custom_presets'), contains('SMPS'));
    expect(
      prefs.getString('layout_board_custom_presets'),
      isNot(contains('차단기 3P')),
    );
    await disposeBoard(tester);
  });

  testWidgets('폰 폭: 도구 칸의 글씨는 14 이상, 단추는 48 이상', (tester) async {
    await openWithDraft(tester, kPhone, presets: true);
    expectNoSmallText(tester);
    expectTouchable(tester, buttonOf('여러 개 선택'));
    for (final t in ['모듈 배치/이동', '고정 치수 측정']) {
      final Size s = tester.getSize(
        find.ancestor(
          of: find.text(t),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(s.height, greaterThanOrEqualTo(48), reason: t);
    }

    // 치수 모드 도구 칸도 같다.
    await tester.tap(find.text('고정 치수 측정'));
    await tester.pumpAndSettle();
    expectNoSmallText(tester);
    expectTouchable(tester, buttonOf('체인'));
    expectTouchable(tester, buttonOf('대각선'));
    await disposeBoard(tester);
  });

  testWidgets('태블릿 폭: 양옆 칸의 글씨는 14 이상이고, 오른쪽 칸에서 복제·회전을 한다', (tester) async {
    await openWithDraft(tester, kTablet, presets: true);
    expectNoSmallText(tester);
    await tester.tap(find.text('단자대'));
    await tester.pumpAndSettle();
    expect(find.text('모듈 이름'), findsOneWidget);
    expectNoSmallText(tester);

    // 회전: 160×60 → 60×160
    await tester.tap(find.text('90° 회전'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '60'), findsWidgets);

    // 복제: 같은 이름 모듈이 하나 더 생긴다.
    await tester.tap(find.text('복제'));
    await tester.pumpAndSettle();
    expect(onBoard('단자대'), findsNWidgets(2));

    // 되돌리면 복제 전으로.
    await tester.tap(find.byTooltip('되돌리기'));
    await tester.pumpAndSettle();
    expect(onBoard('단자대'), findsOneWidget);

    // 치수 모드 오른쪽 칸
    await tester.tap(find.text('고정 치수 측정'));
    await tester.pumpAndSettle();
    expect(find.text('치수 재기'), findsOneWidget);
    expectNoSmallText(tester);
    await disposeBoard(tester);
  });

  testWidgets('알약 모양 칩(FilterChip·ChoiceChip)을 쓰지 않는다', (tester) async {
    await openWithDraft(tester, kTablet);
    expect(find.byType(FilterChip), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
    await tester.tap(find.text('고정 치수 측정'));
    await tester.pumpAndSettle();
    expect(find.byType(FilterChip), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
    await disposeBoard(tester);
  });

  testWidgets('폰 폭: 아래 칸의 신규 모듈을 위로 끌어 도면에 놓는다', (tester) async {
    await openWithDraft(tester, kPhone);
    expect(onBoard('신규 모듈'), findsNothing);
    final Offset from = tester.getCenter(find.text('신규 모듈'));
    final g = await tester.startGesture(from);
    for (int i = 0; i < 12; i++) {
      await g.moveBy(const Offset(0, -40));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle();
    // 놓으면 좁은 화면에서는 편집 바텀시트가 열린다.
    expect(onBoard('신규 모듈'), findsOneWidget);
    await disposeBoard(tester);
  });

  testWidgets('태블릿 폭: 왼쪽 칸의 덕트를 옆으로 끌어 도면에 놓는다', (tester) async {
    await openWithDraft(tester, kTablet);
    expect(onBoard('ABS덕트 80mm'), findsNothing);
    final Offset from = tester.getCenter(find.text('80'));
    final g = await tester.startGesture(from);
    for (int i = 0; i < 12; i++) {
      await g.moveBy(const Offset(40, -10));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle();
    expect(onBoard('ABS덕트 80mm'), findsOneWidget);
    await disposeBoard(tester);
  });

  // 폰 가로, 작은 폰, 폴드 편 화면에서도 아래 칸이 넘치지 않는다.
  for (final size in const [Size(844, 390), Size(360, 640), Size(673, 841)]) {
    testWidgets('화면 ${size.width.toInt()}x${size.height.toInt()}에서도 넘치지 않는다', (
      tester,
    ) async {
      await openWithDraft(tester, size, presets: true);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('고정 치수 측정'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await disposeBoard(tester);
    });
  }
}
