// 자료 검색의 "내 기록에서 찾음"(10-07).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/utils/ai_ask.dart';
import 'package:tubing_calculator/src/presentation/common/record_search.dart';
import 'package:tubing_calculator/src/presentation/reference/search/knowledge_entry.dart';
import 'package:tubing_calculator/src/presentation/reference/search/knowledge_records.dart';
import 'package:tubing_calculator/src/presentation/reference/search/knowledge_search_page.dart';

final _logs = <Map<String, dynamic>>[
  {
    'id': 'p1',
    'name': '루마 계장 배관',
    'daily_reports': [
      {'date': '2026-09-29', 'note': '튜브 라인 누설 점검'},
    ],
    'punch_lists': [
      {'content': '튜브 끝단 누설 확인 필요', 'location': 'B동 3층'},
    ],
  },
];

const _data = [
  KnowledgeEntry(id: 'a', category: '압력시험 누설', title: '누설 위치 찾는 순서', lines: ['비눗물']),
];

Future<AiAskResult> _noAi(String q) async => const AiAskResult.fail('x');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('찾은 기록 → 검색 항목: 일지·이슈만, 누르면 곧바로 열림', () {
    final r = recordsToKnowledge(searchRecords('누설', _logs, const []));
    expect(r, isNotEmpty);
    expect(r.every((e) => e.direct && e.open != null), isTrue);
    expect(r.map((e) => e.category), contains('내 기록 · 이슈'));
  });

  Future<void> open(WidgetTester t, KnowledgeRecordSearch fn) async {
    t.view.physicalSize = const Size(800, 2400);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        home: KnowledgeSearchPage(entries: _data, askAi: _noAi, recordSearch: fn),
      ),
    );
  }

  testWidgets('내 기록이 앱 자료 위에 따로 나오고, 기록만 맞아도 결과가 보인다', (t) async {
    final asked = <String>[];
    await open(t, (q) async {
      asked.add(q);
      return recordsToKnowledge(searchRecords(q, _logs, const []));
    });
    await t.enterText(find.byKey(const Key('ks_field')), '누설');
    await t.pump(const Duration(milliseconds: 400));
    await t.pump();
    expect(asked, ['누설']); // 잠깐 멈춘 뒤 한 번만 찾는다
    final rec = t.getTopLeft(find.byKey(const Key('ks_rec_head'))).dy;
    final app = t.getTopLeft(find.byKey(const Key('ks_app_head'))).dy;
    expect(rec < app, isTrue);
    expect(find.text('앱 자료 (1건)'), findsOneWidget);
    // 앱 자료에는 없고 내 기록에만 있는 말
    await t.enterText(find.byKey(const Key('ks_field')), '루마');
    await t.pump(const Duration(milliseconds: 400));
    await t.pump();
    expect(find.byKey(const Key('ks_empty')), findsNothing);
    expect(find.byKey(const Key('ks_rec_head')), findsOneWidget);
  });

  testWidgets('분류를 고르면 앱 자료만 본다', (t) async {
    await open(t, (q) async => recordsToKnowledge(searchRecords(q, _logs, const [])));
    await t.enterText(find.byKey(const Key('ks_field')), '누설');
    await t.pump(const Duration(milliseconds: 400));
    await t.pump();
    await t.tap(find.byKey(const Key('ks_cat_압력시험 누설')));
    await t.pump();
    expect(find.byKey(const Key('ks_rec_head')), findsNothing);
    expect(find.byKey(const Key('ks_hit_a')), findsOneWidget);
  });
}
