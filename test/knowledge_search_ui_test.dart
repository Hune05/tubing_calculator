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

  test('보내기 글: 분류·제목·내용·출처', () {
    const e = KnowledgeEntry(
      id: 'z',
      category: '장비 고장 조치',
      title: '절삭유가 안 나옴',
      lines: ['원인: 필터 막힘', '조치: 필터 청소'],
      sourceLabel: '장비 사용법',
    );
    expect(
      knowledgeShareText(e),
      '[장비 고장 조치] 절삭유가 안 나옴\n원인: 필터 막힘\n조치: 필터 청소\n(출처: 필드 헬퍼 장비 사용법)',
    );
  });

  testWidgets('내용 창의 보내기를 누르면 그 글을 보낸다', (t) async {
    final sent = <String>[];
    t.view.physicalSize = const Size(800, 2400);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        home: KnowledgeSearchPage(
          entries: _data,
          askAi: _noAi,
          share: (s) async => sent.add(s),
        ),
      ),
    );
    await t.enterText(find.byKey(const Key('ks_field')), '절삭유');
    await t.pump();
    await t.tap(find.byKey(const Key('ks_hit_a')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('ks_share')));
    await t.pump();
    expect(sent.single, startsWith('[장비 고장 조치] 나사 절삭기: 절삭유가 안 나옴'));
  });

  testWidgets('결과가 없으면 혹시 이 말을 찾으십니까 칩이 나오고 누르면 그 말로 찾는다', (t) async {
    await _open(t);
    await t.enterText(find.byKey(const Key('ks_field')), '절사유');
    await t.pump();
    expect(find.text('혹시 이 말을 찾으십니까?'), findsOneWidget);
    await t.tap(find.byKey(const Key('ks_spell_절삭유')));
    await t.pump();
    expect(find.byKey(const Key('ks_hit_a')), findsOneWidget);
  });

  testWidgets('같은 장비의 다른 자료를 내용 창 아래에서 바로 열 수 있다', (t) async {
    const data = [
      KnowledgeEntry(id: 'k1', category: '장비 고장 조치', title: '고속절단기: 진동 심함', lines: ['a']),
      KnowledgeEntry(id: 'k2', category: '장비 고장 조치', title: '고속절단기: 절단석 끼임', lines: ['b']),
      KnowledgeEntry(id: 'k3', category: '장비 고장 조치', title: '밴드쏘: 진동', lines: ['c']),
    ];
    expect(relatedKnowledge(data, data[0]).map((e) => e.id), ['k2']);
    t.view.physicalSize = const Size(800, 2400);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: KnowledgeSearchPage(entries: data, askAi: _noAi)));
    await t.enterText(find.byKey(const Key('ks_field')), '진동');
    await t.pump();
    await t.tap(find.byKey(const Key('ks_hit_k1')));
    await t.pumpAndSettle();
    expect(find.text('같은 묶음의 다른 자료'), findsOneWidget);
    await t.tap(find.byKey(const Key('ks_related_k2')));
    await t.pumpAndSettle();
    expect(find.text('b'), findsOneWidget);
  });

  testWidgets('일부만 맞으면 AI 카드가 안내 바로 아래에 온다', (t) async {
    await _open(t);
    await t.enterText(find.byKey(const Key('ks_field')), '절삭유 펌프');
    await t.pump();
    final notice = t.getTopLeft(find.byKey(const Key('ks_partial'))).dy;
    final ai = t.getTopLeft(find.byKey(const Key('ks_ai_card'))).dy;
    final hit = t.getTopLeft(find.byKey(const Key('ks_hit_a'))).dy;
    expect(notice < ai && ai < hit, isTrue);
  });

  testWidgets('AI 답도 보낼 수 있고, 보내는 글 앞에 AI 답이라고 적는다', (t) async {
    final sent = <String>[];
    t.view.physicalSize = const Size(800, 2400);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        home: KnowledgeSearchPage(
          entries: _data,
          askAi: (q) async => const AiAskResult.ok('필터를 청소합니다.'),
          share: (s) async => sent.add(s),
        ),
      ),
    );
    await t.enterText(find.byKey(const Key('ks_field')), '볼펜 잉크');
    await t.pump();
    await t.tap(find.byKey(const Key('ks_ask_ai')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('ks_ai_share')));
    await t.pump();
    expect(sent.single, '질문: 볼펜 잉크\nAI 답변(앱 자료가 아니며 틀릴 수 있음):\n필터를 청소합니다.');
  });

  testWidgets('첫 화면의 분류 목록은 접혀 있고, 펴서 누르면 그 분류만 보인다', (t) async {
    await _open(t);
    expect(find.byKey(const Key('ks_catrow_압력시험 누설')), findsNothing);
    await t.tap(find.byKey(const Key('ks_catlist')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('ks_catrow_압력시험 누설')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('ks_hit_b')), findsOneWidget);
    expect(find.byKey(const Key('ks_hit_a')), findsNothing);
  });
}
