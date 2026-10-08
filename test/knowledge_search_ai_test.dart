import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/core/utils/ai_ask.dart';
import 'package:tubing_calculator/src/presentation/reference/search/knowledge_entry.dart';
import 'package:tubing_calculator/src/presentation/reference/search/knowledge_search_page.dart';

const _data = [
  KnowledgeEntry(
    id: 'b',
    category: '장비 고장 조치',
    title: 'REMS 아미고 — 나사가 찢어짐',
    lines: ['원인: 다이 마모', '조치: 다이 교체'],
    keywords: ['나사'],
  ),
];

Future<void> _open(WidgetTester t, AiAskCall ask) async {
  t.view.physicalSize = const Size(800, 1600);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(home: KnowledgeSearchPage(entries: _data, askAi: ask)),
  );
  await t.pump();
}

void main() {
  test('안전 관련 질문 판별', () {
    expect(isSafetySensitive('압력계 영점이 안 잡혀요'), isTrue);
    expect(isSafetySensitive('접지 저항 측정 방법'), isTrue);
    expect(isSafetySensitive('수소 누설 점검'), isTrue);
    expect(isSafetySensitive('볼펜 잉크 지우는 법'), isFalse);
  });

  test('영어 질문도 안전 관련으로 본다', () {
    expect(isSafetySensitive('how to calibrate a pressure gauge'), isTrue);
    expect(isSafetySensitive('hydrogen leak check'), isTrue);
    expect(isSafetySensitive('how to fix a pen'), isFalse);
  });

  test('답의 마크다운 기호를 걷어 낸다', () {
    expect(cleanAiText('1. **표준 게이지** 준비\n## 제목\n`값`'), '1. 표준 게이지 준비\n제목\n값');
    expect(cleanAiText('  평범한 글  '), '평범한 글');
  });

  test('서버 오류 코드 → 알림 글', () {
    expect(aiAskErrorMessage('unauthenticated', null), contains('로그인'));
    expect(aiAskErrorMessage('permission-denied', null), contains('사용 승인'));
    expect(aiAskErrorMessage('resource-exhausted', '오늘 이 기능은 20번까지입니다'), '오늘 이 기능은 20번까지입니다');
    expect(aiAskErrorMessage('unavailable', null), contains('응답하지'));
    expect(aiAskErrorMessage('xxx', null), contains('처리하지'));
  });

  testWidgets('자료에 없으면 AI 카드가 뜨고, 눌러 물으면 "AI 답변" 표시와 함께 답이 나온다', (t) async {
    final asked = <String>[];
    await _open(t, (q) async {
      asked.add(q);
      return const AiAskResult.ok('영점은 대기압 상태에서 맞춥니다.', remaining: 19);
    });
    await t.enterText(find.byKey(const Key('ks_field')), '볼펜 잉크 지우는 법');
    await t.pump();
    expect(find.byKey(const Key('ks_empty')), findsOneWidget);
    expect(find.byKey(const Key('ks_ai_card')), findsOneWidget);
    expect(find.text('앱 자료에 없습니다'), findsOneWidget);
    await t.tap(find.byKey(const Key('ks_ask_ai')));
    await t.pumpAndSettle();
    expect(asked, ['볼펜 잉크 지우는 법']); // 질문 글만 보낸다
    expect(find.byKey(const Key('ks_ai_banner')), findsOneWidget);
    expect(find.byKey(const Key('ks_ai_safety')), findsNothing); // 안전 질문이 아니면 없다
    expect(find.text('영점은 대기압 상태에서 맞춥니다.'), findsOneWidget);
    expect(find.text('오늘 남은 횟수 19번'), findsOneWidget);
  });

  testWidgets('안전 관련 질문에는 확인 경고가 더 붙는다', (t) async {
    await _open(t, (q) async => const AiAskResult.ok('답'));
    await t.enterText(find.byKey(const Key('ks_field')), '압력계 영점 조정');
    await t.pump();
    await t.tap(find.byKey(const Key('ks_ask_ai')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('ks_ai_banner')), findsOneWidget);
    expect(find.byKey(const Key('ks_ai_safety')), findsOneWidget);
  });

  testWidgets('결과가 있어도 목록 끝에 AI 카드가 있고, 짧은 검색어에는 없다', (t) async {
    await _open(t, (q) async => const AiAskResult.ok('답'));
    await t.enterText(find.byKey(const Key('ks_field')), '나사');
    await t.pump();
    expect(find.byKey(const Key('ks_hit_b')), findsOneWidget);
    expect(find.byKey(const Key('ks_ai_card')), findsOneWidget);
    expect(find.text('찾는 답이 없으면'), findsOneWidget);
    await t.enterText(find.byKey(const Key('ks_field')), '나');
    await t.pump();
    expect(find.byKey(const Key('ks_ai_card')), findsNothing);
  });

  testWidgets('보내는 중에는 로딩이 보이고, 실패하면 이유와 다시 묻기가 나온다', (t) async {
    final c = Completer<AiAskResult>();
    var calls = 0;
    await _open(t, (q) {
      calls++;
      return calls == 1 ? c.future : Future.value(const AiAskResult.ok('두 번째 답'));
    });
    await t.enterText(find.byKey(const Key('ks_field')), '볼펜 잉크');
    await t.pump();
    await t.tap(find.byKey(const Key('ks_ask_ai')));
    await t.pump();
    await t.pump();
    expect(find.byKey(const Key('ks_ai_loading')), findsOneWidget);
    c.complete(const AiAskResult.fail('통신이 되는지 확인해 주십시오'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('ks_ai_error')), findsOneWidget);
    expect(find.text('통신이 되는지 확인해 주십시오'), findsOneWidget);
    await t.tap(find.byKey(const Key('ks_ai_retry')));
    await t.pumpAndSettle();
    expect(find.text('두 번째 답'), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('질문이 너무 길면 단추가 막힌다', (t) async {
    await _open(t, (q) async => const AiAskResult.ok('답'));
    await t.enterText(find.byKey(const Key('ks_field')), '가' * (kAiAskMaxChars + 1));
    await t.pump();
    final btn = t.widget<OutlinedButton>(find.byKey(const Key('ks_ask_ai')));
    expect(btn.onPressed, isNull);
  });
}
