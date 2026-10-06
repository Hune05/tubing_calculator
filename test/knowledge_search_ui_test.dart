// 자료 검색 화면 고도화(10-07): 찾은 말 굵게·맞는 줄 미리보기·일부만 맞음·분류별 결과 수·최근 검색어.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/utils/ai_ask.dart';
import 'package:tubing_calculator/src/presentation/reference/search/knowledge_entry.dart';
import 'package:tubing_calculator/src/presentation/reference/search/knowledge_search_page.dart';

const _data = [
  KnowledgeEntry(
    id: 'a',
    category: '장비 고장 조치',
    title: '나사 절삭기: 절삭유가 안 나옴',
    lines: ['원인: 필터 막힘', '조치: 절삭유 통·필터 청소'],
  ),
  KnowledgeEntry(
    id: 'b',
    category: '압력시험 누설',
    title: '누설 위치 찾는 순서',
    lines: ['비눗물을 바릅니다', '압력이 떨어지면 이음부부터 봅니다'],
  ),
  KnowledgeEntry(
    id: 'c',
    category: '계기 알람·고장 코드',
    title: 'GD402 ALM.07',
    lines: ['압력 입력 범위 이상'],
  ),
];

Future<AiAskResult> _noAi(String q) async => const AiAskResult.fail('x');

Future<void> _open(WidgetTester t) async {
  t.view.physicalSize = const Size(800, 2400);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    const MaterialApp(
      home: KnowledgeSearchPage(entries: _data, askAi: _noAi),
    ),
  );
  await t.pumpAndSettle();
}

String _plain(InlineSpan s) => s.toPlainText();

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('찾은 말 칠하기: 띄어쓰기·대소문자·기호가 달라도 원래 글자에 칠한다', () {
    const hi = TextStyle(fontWeight: FontWeight.w900);
    final s = highlightSpans('GD402 ALM.07 이상', ['alm07'], hi);
    final marked = [for (final x in s) if (x.style == hi) x.text].join();
    expect(marked, 'ALM.07');
    expect(s.map((x) => x.text).join(), 'GD402 ALM.07 이상');
    expect(highlightSpans('절삭유 보충', const [], hi).single.text, '절삭유 보충');
  });

  testWidgets('미리보기는 찾은 말이 든 줄을 보이고, 리크로 찾아도 누설 자료가 나온다', (t) async {
    await _open(t);
    await t.enterText(find.byKey(const Key('ks_field')), '이음부');
    await t.pump();
    final texts = t
        .widgetList<RichText>(find.descendant(of: find.byKey(const Key('ks_hit_b')), matching: find.byType(RichText)))
        .map((r) => _plain(r.text))
        .toList();
    expect(texts, contains('압력이 떨어지면 이음부부터 봅니다'));
    await t.enterText(find.byKey(const Key('ks_field')), '리크');
    await t.pump();
    expect(find.byKey(const Key('ks_hit_b')), findsOneWidget);
  });

  testWidgets('다 맞는 자료가 없으면 일부만 맞음 안내가 붙는다', (t) async {
    await _open(t);
    await t.enterText(find.byKey(const Key('ks_field')), '절삭유 펌프');
    await t.pump();
    expect(find.byKey(const Key('ks_partial')), findsOneWidget);
    expect(find.text('1건 (일부만 맞음)'), findsOneWidget);
  });

  testWidgets('검색어가 있으면 분류 칩에 결과 수가 나오고 결과 없는 분류는 숨는다', (t) async {
    await _open(t);
    await t.enterText(find.byKey(const Key('ks_field')), '절삭유');
    await t.pump();
    expect(find.text('장비 고장 조치 1'), findsOneWidget);
    expect(find.byKey(const Key('ks_cat_압력시험 누설')), findsNothing);
  });

  testWidgets('결과를 열면 최근 검색어에 남고, 다시 열어도 보이며 모두 지울 수 있다', (t) async {
    await _open(t);
    await t.enterText(find.byKey(const Key('ks_field')), '절삭유');
    await t.pump();
    await t.tap(find.byKey(const Key('ks_hit_a')));
    await t.pumpAndSettle();
    await t.tapAt(const Offset(10, 10));
    await t.pumpAndSettle();
    await t.pumpWidget(const SizedBox());
    await _open(t);
    expect(find.byKey(const Key('ks_recent_절삭유')), findsOneWidget);
    await t.tap(find.byKey(const Key('ks_recent_절삭유')));
    await t.pump();
    expect(find.byKey(const Key('ks_hit_a')), findsOneWidget);
    await t.tap(find.byKey(const Key('ks_clear')));
    await t.pump();
    await t.tap(find.byKey(const Key('ks_recent_clear')));
    await t.pump();
    expect(find.byKey(const Key('ks_recent_절삭유')), findsNothing);
  });

  testWidgets('바로가기는 누르면 내용 창 없이 곧바로 열리고, 일반 항목은 내용 창의 단추 이름을 쓴다', (t) async {
    var opened = 0;
    final data = [
      KnowledgeEntry(
        id: 'tool',
        category: '계산기 바로가기',
        title: '전압강하 계산기',
        open: (_) => opened++,
        direct: true,
      ),
      KnowledgeEntry(
        id: 'diag',
        category: '전기 고장 진단',
        title: '전압강하 진단',
        open: (_) => opened += 10,
        openLabel: '고장 진단 시작',
      ),
    ];
    t.view.physicalSize = const Size(800, 2400);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(home: KnowledgeSearchPage(entries: data, askAi: _noAi)));
    await t.enterText(find.byKey(const Key('ks_field')), '전압강하');
    await t.pump();
    expect(find.text('계산기 바로가기 · 누르면 바로 열림'), findsOneWidget);
    await t.tap(find.byKey(const Key('ks_hit_tool')));
    await t.pumpAndSettle();
    expect(opened, 1);
    expect(find.byKey(const Key('ks_sheet')), findsNothing);
    await t.tap(find.byKey(const Key('ks_hit_diag')));
    await t.pumpAndSettle();
    expect(find.text('고장 진단 시작'), findsOneWidget);
    await t.tap(find.text('고장 진단 시작'));
    await t.pumpAndSettle();
    expect(opened, 11);
  });
}
