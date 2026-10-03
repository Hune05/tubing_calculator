import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/reference/search/knowledge_entry.dart';

List<KnowledgeEntry> _data() => const [
  KnowledgeEntry(
    id: 'a',
    category: '계기 알람·고장 코드',
    title: 'GD402 ALM.07 압력 입력 범위 이상',
    lines: ['조치: 시료가스 압력·압력 범위 확인'],
    keywords: ['밀도계', 'gd402'],
  ),
  KnowledgeEntry(
    id: 'b',
    category: '장비 고장 조치',
    title: 'REMS 아미고 — 나사가 찢어짐',
    lines: ['원인: 다이 마모, 절삭유 부족', '조치: 다이 교체, 절삭유 보충'],
    keywords: ['나사', '파이프 나사기'],
  ),
  KnowledgeEntry(
    id: 'c',
    category: '장비 고장 조치',
    title: 'DEWALT 밴드쏘 — 날이 휨',
    lines: ['원인: 절삭유 부족', '조치: 날 교체'],
  ),
];

void main() {
  test('코드 표기가 달라도 같다(ALM.07 = alm07 = alm 07)', () {
    final all = _data();
    for (final q in ['ALM.07', 'alm07', 'alm 07', 'ALM-07']) {
      expect(searchKnowledge(all, q).map((h) => h.entry.id), ['a'], reason: q);
    }
  });

  test('낱말이 모두 들어 있어야 하고 제목 > 찾기용 말 > 내용 순으로 점수', () {
    final all = _data();
    final h = searchKnowledge(all, '절삭유');
    expect(h.map((e) => e.entry.id), ['b', 'c']); // 둘 다 내용에만 있어 같은 점수 → 원래 순서
    expect(searchKnowledge(all, '절삭유 교체').map((e) => e.entry.id), ['b', 'c']);
    expect(searchKnowledge(all, '절삭유 휨').map((e) => e.entry.id), ['c']);
    // 제목에 있는 쪽이 앞
    final t = searchKnowledge(all, '나사');
    expect(t.first.entry.id, 'b');
    expect(t.first.score, 3);
  });

  test('분류로 좁히고, 검색어 없이 분류만 고르면 그 분류 전체', () {
    final all = _data();
    expect(searchKnowledge(all, '교체', category: '장비 고장 조치').length, 2);
    expect(searchKnowledge(all, '교체', category: '계기 알람·고장 코드'), isEmpty);
    expect(searchKnowledge(all, '', category: '장비 고장 조치').length, 2);
    expect(searchKnowledge(all, ''), isEmpty);
    expect(searchKnowledge(all, '   '), isEmpty);
  });

  test('없는 말은 결과 없음, 분류 목록은 처음 나온 순서와 개수', () {
    final all = _data();
    expect(searchKnowledge(all, '펌프'), isEmpty);
    expect(knowledgeCategories(all), [('계기 알람·고장 코드', 1), ('장비 고장 조치', 2)]);
  });

  test('문제해결 자료(priority 1)가 점수와 상관없이 먼저 나온다', () {
    const all = [
      KnowledgeEntry(
        id: 'm',
        category: '장비 작업 순서',
        title: '나사 절삭 — 작업 순서',
        lines: ['절삭유 주면서'],
      ),
      KnowledgeEntry(
        id: 't',
        category: '장비 고장 조치',
        title: '나사기 — 날 무뎌짐',
        lines: ['조치: 절삭유 보충'],
        priority: 1,
      ),
    ];
    final h = searchKnowledge(all, '나사');
    expect(h.map((e) => e.entry.id), ['t', 'm']);
  });
}
