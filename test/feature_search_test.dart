// 기능 검색: 이름·설명·초성 검색, 격자/목록 창, 빠른 도구 막대의 "전체".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/common/app_icons.dart';
import 'package:tubing_calculator/src/presentation/common/feature_search.dart';
import 'package:tubing_calculator/src/presentation/common/quick_sub_tools.dart';
import 'package:tubing_calculator/src/presentation/common/quick_tool_bar.dart';

FeatureItem _it(String t, String s, {String? group, VoidCallback? onTap}) =>
    FeatureItem(
      title: t,
      subtitle: s,
      glyph: AppGlyph.engCalc,
      group: group,
      onTap: onTap ?? () {},
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('검색 규칙', () {
    test('초성 뽑기: 공백은 빼고 한글만 초성으로', () {
      expect(hangulInitials('공학용 계산기'), 'ㄱㅎㅇㄱㅅㄱ');
      expect(hangulInitials('B31.3 압력'), 'b31.3ㅇㄹ');
    });

    final items = [
      _it('공학용 계산기', '사칙연산·삼각함수'),
      _it('압력 시험', '수압·공압 시험압력 · 기록서'),
      _it('단위 환산', '길이·압력·온도'),
    ];

    test('이름·설명으로 찾고, 이름이 앞에서 맞는 것을 위로', () {
      expect(searchFeatures('압력', items).map((e) => e.title), [
        '압력 시험', // 제목이 앞에서 맞음
        '단위 환산', // 설명에 압력
      ]);
      expect(searchFeatures('삼각', items).single.title, '공학용 계산기');
    });

    test('초성 검색: ㄱㅅㄱ → 공학용 계산기, ㅇㄹㅅㅎ → 압력 시험', () {
      expect(searchFeatures('ㄱㅅㄱ', items).single.title, '공학용 계산기');
      expect(searchFeatures('ㅇㄹ', items).first.title, '압력 시험');
    });

    test('공백·대소문자는 무시, 없으면 빈 목록, 빈 검색어는 그대로', () {
      expect(searchFeatures(' 공학 용 ', items).single.title, '공학용 계산기');
      expect(searchFeatures('없는말', items), isEmpty);
      expect(searchFeatures('', items).length, 3);
    });
  });

  group('검색 창', () {
    Future<void> open(
      WidgetTester tester,
      List<FeatureItem> items, {
      bool grid = false,
    }) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('open'),
                  onPressed: () => showFeatureSearchSheet(
                    ctx,
                    title: '시험',
                    items: items,
                    grid: grid,
                  ),
                  child: const Text('열기'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
    }

    testWidgets('입력하면 걸러지고, 맞는 게 없으면 안내, 누르면 닫히고 실행된다', (tester) async {
      var hit = '';
      await open(tester, [
        _it('공학용 계산기', '사칙', onTap: () => hit = 'eng'),
        _it('압력 시험', '수압', onTap: () => hit = 'pt'),
      ]);
      expect(find.byKey(const Key('feature_공학용 계산기')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('feature_search_field')),
        'ㅇㄹ',
      );
      await tester.pump();
      expect(find.byKey(const Key('feature_공학용 계산기')), findsNothing);
      await tester.enterText(
        find.byKey(const Key('feature_search_field')),
        '없음',
      );
      await tester.pump();
      expect(find.byKey(const Key('feature_search_empty')), findsOneWidget);
      await tester.tap(find.byKey(const Key('feature_search_clear')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('feature_압력 시험')));
      await tester.pumpAndSettle();
      expect(hit, 'pt');
      expect(find.byKey(const Key('feature_search_sheet')), findsNothing);
    });

    testWidgets('격자 모드: 묶음 머리글과 아이콘 칸이 나온다', (tester) async {
      await open(tester, [
        _it('A기능', '', group: '가묶음'),
        _it('B기능', '', group: '나묶음'),
      ], grid: true);
      expect(find.text('가묶음'), findsOneWidget);
      expect(find.text('나묶음'), findsOneWidget);
      expect(find.byKey(const Key('feature_A기능')), findsOneWidget);
    });
  });

  group('빠른 도구 막대 "전체"', () {
    test('세부 기능이 큰 기능 뒤에 모두 있고 id가 겹치지 않는다', () {
      final all = kQuickAllFeatures;
      expect(all.length, kQuickTools.length + kQuickSubTools.length);
      expect(all.map((t) => t.id).toSet().length, all.length);
      expect(kQuickSubTools.length, greaterThan(35));
      // 세부 기능은 모두 선 아이콘과 묶음 이름이 있다.
      for (final s in kQuickSubTools) {
        expect(s.icon, isNotNull, reason: s.id);
        expect(s.group, isNotNull, reason: s.id);
      }
    });

    testWidgets('막대의 전체 단추 → 격자 창에서 찾아 누르면 작업 화면 위에 열린다', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final tools = [
        QuickToolDef(
          'a',
          '도구A',
          AppGlyph.engCalc,
          (_) => const Text('A화면'),
          group: '묶음1',
        ),
        QuickToolDef(
          'b',
          '도구B',
          null,
          (_) => const Text('B화면'),
          icon: Icons.build,
          group: '묶음2',
          subtitle: '세부',
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickToolBarHost(
              tools: tools,
              child: const Center(child: Text('작업')),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('quick_tool_handle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quick_tool_all')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('feature_도구A')), findsOneWidget);
      expect(find.byKey(const Key('feature_도구B')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('feature_search_field')),
        '세부',
      );
      await tester.pump();
      expect(find.byKey(const Key('feature_도구A')), findsNothing);
      await tester.tap(find.byKey(const Key('feature_도구B')));
      await tester.pumpAndSettle();
      expect(find.text('B화면'), findsOneWidget);
    });
  });

  group('폴더', () {
    FeatureItem folder(List<String> kids, {VoidCallback? onKid}) => FeatureItem(
      title: '압력 시험',
      subtitle: '시험압력',
      glyph: AppGlyph.pressureGauge,
      group: '배관',
      onTap: () {},
      children: [
        for (final k in kids)
          FeatureItem(
            title: k,
            subtitle: '',
            icon: Icons.build,
            onTap: onKid ?? () {},
          ),
      ],
    );

    test('검색용으로 풀면 안의 기능이 하나씩 나오고 폴더 이름이 설명 앞에 붙는다', () {
      final flat = flattenFeatures([
        folder(['시험 기록', '압력 강하']),
      ]);
      expect(flat.map((e) => e.title), ['시험 기록', '압력 강하']);
      expect(flat.first.subtitle, '압력 시험');
      expect(searchFeatures('강하', flat).single.title, '압력 강하');
    });

    testWidgets('격자에는 폴더 하나, 누르면 안의 기능이 열리고 누르면 실행', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var hit = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                key: const Key('open'),
                onPressed: () => showFeatureSearchSheet(
                  ctx,
                  title: '전체',
                  grid: true,
                  items: [
                    folder(['시험 기록', '압력 강하'], onKid: () => hit++),
                  ],
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      // 폴더 하나만 보이고 안의 기능은 아직 안 보인다.
      expect(find.byKey(const Key('feature_folder_압력 시험')), findsOneWidget);
      expect(find.byKey(const Key('feature_시험 기록')), findsNothing);
      await tester.tap(find.byKey(const Key('feature_folder_압력 시험')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key("feature_folder_dialog")), findsOneWidget);
      // 폴더 카드는 검색 창 안쪽에 쏙 들어오고(창보다 좁고), 높이는 내용 높이(머리글 56 + 한 줄 104)에 딱 맞고, 두 줄 반을 넘으면 스크롤.
      final sheet = tester.getRect(
        find.byKey(const Key("feature_search_sheet")),
      );
      final card = tester.getRect(
        find.byKey(const Key("feature_folder_dialog")),
      );
      expect(card.width, lessThan(sheet.width));
      expect(card.left, greaterThan(sheet.left));
      expect(card.right, lessThan(sheet.right));
      expect(card.width, closeTo(sheet.width * 0.88, 1));
      expect(card.height, closeTo(56 + 104, 1)); // 한 줄이라 내용 높이 그대로
      await tester.tap(find.byKey(const Key('feature_시험 기록')));
      await tester.pumpAndSettle();
      expect(hit, 1);
      expect(find.byKey(const Key('feature_search_sheet')), findsNothing);
    });

    testWidgets('검색하면 폴더 대신 안의 기능이 바로 나온다', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                key: const Key('open'),
                onPressed: () => showFeatureSearchSheet(
                  ctx,
                  title: '전체',
                  grid: true,
                  items: [
                    folder(['시험 기록', '압력 강하']),
                  ],
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('feature_search_field')),
        '강하',
      );
      await tester.pump();
      expect(find.byKey(const Key('feature_압력 강하')), findsOneWidget);
      expect(find.byKey(const Key('feature_folder_압력 시험')), findsNothing);
    });
  });

  testWidgets('항목이 많은 폴더는 높이를 두 줄 반으로 줄이고 안에서 스크롤한다', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final many = FeatureItem(
      title: '큰 폴더',
      subtitle: '',
      glyph: AppGlyph.engCalc,
      onTap: () {},
      children: [
        for (var i = 0; i < 12; i++)
          FeatureItem(
            title: '기능$i',
            subtitle: '',
            icon: Icons.build,
            onTap: () {},
          ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: ElevatedButton(
              key: const Key('open'),
              onPressed: () => showFeatureSearchSheet(
                ctx,
                title: '전체',
                grid: true,
                items: [many],
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('feature_folder_큰 폴더')));
    await tester.pumpAndSettle();
    final card = tester.getRect(find.byKey(const Key('feature_folder_dialog')));
    expect(card.height, closeTo(56 + 2.4 * 104, 1));
    // 아래쪽 항목은 처음엔 안 보이지만 스크롤하면 보인다.
    final last = find.byKey(const Key('feature_기능11'));
    await tester.drag(
      find.descendant(
        of: find.byKey(const Key('feature_folder_dialog')),
        matching: find.byType(SingleChildScrollView),
      ),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(last).bottom, lessThanOrEqualTo(card.bottom + 1));
  });
}
