// 자료 검색에 넣은 고장 진단 판정과 계산기 바로가기(10-07).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/electrical/electric_calculator_page.dart';
import 'package:tubing_calculator/src/presentation/electrical/troubleshoot_flows.dart';
import 'package:tubing_calculator/src/presentation/electrical/troubleshoot_page.dart';
import 'package:tubing_calculator/src/presentation/reference/search/knowledge_base.dart';
import 'package:tubing_calculator/src/presentation/reference/search/knowledge_entry.dart';
import 'package:tubing_calculator/src/presentation/reference/search/knowledge_tools.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('고장 진단: 흐름마다 시작 항목, 판정마다 원인·조치 항목이 있고 번호가 겹치지 않는다', () {
    final d = diagnosisKnowledge();
    final flows = troubleshootFlows();
    var ends = 0;
    for (final f in flows) {
      expect(d.any((e) => e.id == 'diag.${f.id}'), isTrue, reason: f.id);
      ends += f.steps.values.whereType<WizEnd>().length;
    }
    expect(d.length, flows.length + ends);
    expect(d.map((e) => e.id).toSet().length, d.length);
    expect(d.every((e) => e.open != null && e.priority == 1), isTrue);
    expect(
      d.where((e) => e.id.split('.').length == 3).every((e) => e.lines.any((l) => l.startsWith('조치: '))),
      isTrue,
    );
  });

  test('전체 자료 번호가 겹치지 않고, 검색어가 제목에 그대로 있는 바로가기가 먼저 나온다', () {
    resetKnowledgeBaseCache();
    final all = knowledgeBase();
    expect(all.map((e) => e.id).toSet().length, all.length);
    expect(searchKnowledge(all, '전압강하').first.entry.title, '전기 설비 계산 · 전압강하');
    expect(searchKnowledge(all, '차단기 트립').map((h) => h.entry.id), contains('diag.trip'));
    final heat = searchKnowledge(all, '모터 과열').map((h) => h.entry.id).toList();
    expect(heat, containsAll(['tool.e12', 'tool.e17']));
  });

  testWidgets('바로가기를 열면 그 계산기 탭이, 진단 항목을 열면 그 흐름이 열린다', (t) async {
    t.view.physicalSize = const Size(800, 4000);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    final tool = toolKnowledge().firstWhere((e) => e.id == 'tool.e4');
    final diag = diagnosisKnowledge().firstWhere((e) => e.id == 'diag.trip');
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) => Column(
            children: [
              TextButton(onPressed: () => tool.open!(c), child: const Text('tool')),
              TextButton(onPressed: () => diag.open!(c), child: const Text('diag')),
            ],
          ),
        ),
      ),
    );
    await t.tap(find.text('tool'));
    await t.pumpAndSettle();
    expect(find.byType(ElectricCalculatorPage), findsOneWidget);
    expect(find.text('전압강하'), findsWidgets);
    Navigator.of(t.element(find.byType(ElectricCalculatorPage))).pop();
    await t.pumpAndSettle();
    await t.tap(find.text('diag'));
    await t.pumpAndSettle();
    expect(find.byType(TroubleshootFlowPage), findsOneWidget);
  });

  test('작은 장비 분류는 장비 사용 요령으로 묶고, 원래 분류 이름으로도 찾아진다', () {
    const all = [
      KnowledgeEntry(id: '1', category: '장비 펜스 직각', title: '펜스 맞추기'),
      KnowledgeEntry(id: '2', category: '장비 고장 조치', title: 'a'),
      KnowledgeEntry(id: '3', category: '계기 신호 이상', title: 'b'),
    ];
    final m = mergeSmallCategories(all);
    expect(m.first.category, kEquipmentMiscCategory);
    expect(searchKnowledge(m, '펜스 직각').single.entry.id, '1');
    // 장비로 시작하지 않는 분류는 작아도 그대로
    expect(m.last.category, '계기 신호 이상');
  });

  test('분류는 고장·알람·진단이 먼저 보인다', () {
    resetKnowledgeBaseCache();
    final cats = knowledgeCategories(knowledgeBase(), order: kKnowledgeCategoryOrder)
        .map((c) => c.$1)
        .toList();
    expect(cats.take(4), ['장비 고장 조치', '계기 알람·고장 코드', '계기 신호 이상', '전기 고장 진단']);
    expect(cats.length, lessThanOrEqualTo(20));
  });

  test('배관·전선관·형강 바로가기: 킥·채널·앵글로도 찾는다', () {
    resetKnowledgeBaseCache();
    final all = knowledgeBase();
    expect(searchKnowledge(all, '킥').first.entry.id, 'tool.conduit');
    expect(searchKnowledge(all, '채널').first.entry.id, 'tool.steel');
    expect(searchKnowledge(all, '앵글 규격').first.entry.id, 'tool.steel');
    expect(searchKnowledge(all, '드릴 클러치'), isNotEmpty);
  });

  test('같은 진단의 다른 판정은 이어 보이고, 진단 시작 항목끼리는 묶이지 않는다', () {
    resetKnowledgeBaseCache();
    final all = knowledgeBase();
    final start = all.firstWhere((e) => e.id == 'diag.trip');
    expect(relatedKnowledge(all, start), isEmpty);
    final end = all.firstWhere((e) => e.id.startsWith('diag.trip.'));
    final rel = relatedKnowledge(all, end);
    expect(rel, isNotEmpty);
    expect(rel.every((e) => e.id.startsWith('diag.trip.')), isTrue);
  });
}
