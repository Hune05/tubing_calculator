// 현장 자료 화면: 통합 검색(현장자료_보충제안 2번)과 현장 보기 테마(1번).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/core/theme/field_view.dart';
import 'package:tubing_calculator/src/presentation/reference/page/reference_search_index.dart';
import 'package:tubing_calculator/src/presentation/reference/page/tube_reference_page.dart';

Widget app(Widget home) => MaterialApp(
  builder: (context, child) => FieldViewHost(child: child!),
  home: home,
);

void main() {
  setUp(() => FieldColors.mode.value = FieldViewMode.normal);
  tearDown(() => FieldColors.mode.value = FieldViewMode.normal);

  group('RefSearchEntry.matches', () {
    test('제목에 들어 있으면 찾는다(대소문자 안 가림)', () {
      const e = RefSearchEntry(0, 'NPT 나사 규격');
      expect(e.matches('npt'), isTrue);
      expect(e.matches('나사'), isTrue);
      expect(e.matches('벤드'), isFalse);
    });

    test('키워드로도 찾는다', () {
      const e = RefSearchEntry(1, '곤질레다·커플링 (삼화기전 F-7)', ['LB', 'LL']);
      expect(e.matches('lb'), isTrue);
      expect(e.matches('LL'), isTrue);
      expect(e.matches('없는말'), isFalse);
    });

    test('색인 항목마다 탭 번호가 0~5 안이다', () {
      for (final e in refSearchIndex) {
        expect(e.tab, inInclusiveRange(0, 5));
        expect(e.title, isNotEmpty);
      }
    });
  });

  testWidgets('검색어를 넣으면 탭 대신 결과 목록이 뜬다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(const TubeReferencePage()));
    await tester.pumpAndSettle();

    expect(find.byType(TabBarView), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'NPT');
    await tester.pumpAndSettle();

    expect(find.byType(TabBarView), findsNothing);
    expect(find.textContaining('NPT 나사 규격'), findsOneWidget);
    expect(find.textContaining('튜브 탭'), findsOneWidget);
  });

  testWidgets('결과가 없으면 안내 글이 나온다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(const TubeReferencePage()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '없는규격이름123');
    await tester.pumpAndSettle();

    expect(find.textContaining('맞는 자료가 없습니다'), findsOneWidget);
  });

  testWidgets('검색 결과를 누르면 그 탭으로 넘어가고 검색은 닫힌다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(const TubeReferencePage()));
    await tester.pumpAndSettle();

    // 형강 탭에만 있는 "H형강 이론 중량표"로 찾는다.
    await tester.enterText(find.byType(TextField), 'H형강');
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('H형강 이론 중량표'));
    await tester.pumpAndSettle();

    // 검색창이 비어 다시 탭 화면(TabBarView)으로 돌아온다.
    expect(find.byType(TabBarView), findsOneWidget);
    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.controller!.index, 2); // 0=튜브 1=전선관 2=형강
  });

  testWidgets('현장 보기(야간)로 바꾸면 배경이 어두워진다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(const TubeReferencePage()));
    await tester.pumpAndSettle();

    Color scaffoldBg() => tester
        .widget<Scaffold>(find.byType(Scaffold).first)
        .backgroundColor!;

    expect(scaffoldBg(), FieldPalette.normal.background);

    FieldColors.mode.value = FieldViewMode.night;
    await tester.pumpAndSettle();

    expect(scaffoldBg(), FieldPalette.night.background);
  });
}
