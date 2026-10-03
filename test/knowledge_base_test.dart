import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/reference/search/knowledge_base.dart';
import 'package:tubing_calculator/src/presentation/reference/search/knowledge_entry.dart';
import 'package:tubing_calculator/src/presentation/reference/search/knowledge_search_page.dart';

void main() {
  test('실제 자료 모음: 분류별로 항목이 들어 있고 번호가 겹치지 않는다', () {
    resetKnowledgeBaseCache();
    final all = knowledgeBase();
    final cats = {for (final (n, c) in knowledgeCategories(all)) n: c};
    expect(cats['장비 고장 조치'], greaterThanOrEqualTo(70));
    expect(cats['계기 알람·고장 코드'], 15); // ALM 10 + Err 5
    expect(cats['계기 신호 이상'], 6);
    expect(cats['축 정렬 지침'], greaterThanOrEqualTo(30));
    expect(cats['현장 자료'], greaterThanOrEqualTo(30));
    expect(cats['접지·전동기 점검'], 8);
    final ids = all.map((e) => e.id).toList();
    expect(ids.toSet().length, ids.length);
    expect(ids, containsAll(["press.drop.notleak", "sig.loop.ranges"]));
    for (final e in all) {
      expect(e.title.trim(), isNotEmpty, reason: e.id);
      expect(e.category.trim(), isNotEmpty, reason: e.id);
    }
  });

  test('증상·코드·장비 이름으로 찾아진다', () {
    final all = knowledgeBase();
    List<String> ids(String q) =>
        searchKnowledge(all, q).map((h) => h.entry.id).toList();
    // 코드: 표기가 달라도
    expect(ids('ALM.07'), contains('gd402.ALM.07'));
    expect(ids('alm07').first, 'gd402.ALM.07');
    expect(ids('Err.03'), contains('gd402.Err.03'));
    // 루프 값
    expect(ids('0mA'), contains('loop.0 mA'));
    expect(ids('접지저항 측정'), contains('elec.ground.measure'));
    expect(ids('과부하계전기 트립'), contains('elec.motor.trip'));
    expect(ids('EOCR'), contains('elec.motor.eocr'));
    // 장비 증상
    expect(ids('튜브 찌그러짐'), isNotEmpty);
    expect(ids('각도 부족'), isNotEmpty);
    // 결과는 제목 일치가 먼저
    final r = searchKnowledge(all, '스프링백');
    expect(r, isNotEmpty);
    expect(r.first.score, greaterThanOrEqualTo(r.last.score));
  });

  testWidgets('자료 검색 화면: 검색어로 목록이 걸러지고 누르면 내용이 보인다', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: KnowledgeSearchPage(
          entries: const [
            KnowledgeEntry(
              id: 'x1',
              category: '계기 알람·고장 코드',
              title: 'GD402 ALM.07 압력 입력 범위 이상',
              lines: ['조치: 시료가스 압력 확인', '알람 코드입니다.'],
              keywords: ['GD402'],
              sourceLabel: 'GD402 화면',
            ),
            KnowledgeEntry(
              id: 'x2',
              category: '장비 고장 조치',
              title: 'REMS 아미고 — 나사가 찢어짐',
              lines: ['원인: 다이 마모', '조치: 다이 교체'],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    // 첫 화면: 안내와 분류
    expect(find.text('들어 있는 자료 (2건)'), findsOneWidget);
    expect(find.byKey(const Key('ks_hit_x1')), findsNothing);
    await tester.enterText(find.byKey(const Key('ks_field')), 'alm 07');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ks_hit_x1')), findsOneWidget);
    expect(find.byKey(const Key('ks_hit_x2')), findsNothing);
    expect(find.byKey(const Key('ks_count')), findsOneWidget);
    // 내용 보기
    await tester.tap(find.byKey(const Key('ks_hit_x1')));
    await tester.pumpAndSettle();
    expect(find.text('조치: 시료가스 압력 확인'), findsOneWidget);
    expect(find.text('출처 화면: GD402 화면'), findsOneWidget);
    expect(find.byKey(const Key('ks_open_source')), findsNothing); // 열 화면 없음
    // 닫고 없는 말
    Navigator.of(tester.element(find.byKey(const Key('ks_sheet')))).pop();
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('ks_field')), '펌프');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ks_empty')), findsOneWidget);
    // 분류로 좁히기(검색어 지우고 분류만)
    await tester.tap(find.byKey(const Key('ks_clear')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('ks_cat_장비 고장 조치')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ks_cat_장비 고장 조치')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ks_hit_x2')), findsOneWidget);
    expect(find.byKey(const Key('ks_hit_x1')), findsNothing);
  });
}
