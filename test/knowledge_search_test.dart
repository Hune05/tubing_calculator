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
    expect(t.first.score, 6);
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

  group('말 바꿔 찾기(10-07)', () {
    test('조사·말끝을 떼고 찾는다(그대로 맞는 말은 떼지 않는다)', () {
      final all = _data();
      expect(searchKnowledge(all, '절삭유가').map((h) => h.entry.id), ['b', 'c']);
      expect(searchKnowledge(all, '나사가 찢어짐').first.entry.id, 'b');
      expect(searchVariants('온도'), contains('온도'));
      expect(searchVariants('진동이'), contains('진동'));
      expect(searchVariants('나와요'), contains('나와'));
    });

    test('현장에서 쓰는 다른 말로도 찾는다(리크 → 누설, 모터 → 전동기, 메가 → 메거)', () {
      const all = [
        KnowledgeEntry(id: 'l', category: '압력', title: '누설 위치 찾기'),
        KnowledgeEntry(id: 'm', category: '전기', title: '전동기 절연저항(메거)'),
      ];
      for (final q in ['리크', 'leak', '새요']) {
        expect(searchKnowledge(all, q).map((h) => h.entry.id), ['l'], reason: q);
      }
      expect(searchKnowledge(all, '모터 메가').map((h) => h.entry.id), ['m']);
    });

    test('초성으로 찾는다(ㅈㅅㅇ → 절삭유)', () {
      const all = [
        KnowledgeEntry(id: 'x', category: 'a', title: '절삭유 보충'),
        KnowledgeEntry(id: 'y', category: 'a', title: '날 교체'),
      ];
      expect(searchKnowledge(all, 'ㅈㅅㅇ').map((h) => h.entry.id), ['x']);
    });

    test('다 맞는 항목이 없으면 일부만 맞는 항목을 표시해 돌려준다', () {
      final all = _data();
      final h = searchKnowledge(all, '절삭유 펌프');
      expect(h, isNotEmpty);
      expect(h.every((e) => e.partial), isTrue);
      expect(h.first.matched, 1);
      expect(h.first.total, 2);
      // 다 맞는 항목이 있으면 일부만 맞는 항목은 섞지 않는다.
      expect(searchKnowledge(all, '절삭유 휨').map((e) => e.entry.id), ['c']);
      // 낱말의 절반도 못 찾으면 안 보인다.
      expect(searchKnowledge(all, '절삭유 펌프 모터 밸브'), isEmpty);
    });

    test('맞는 줄: 찾은 낱말이 든 첫 내용 줄', () {
      final b = _data()[1];
      final h = searchKnowledge([b], '보충');
      expect(matchingLine(b, h.single.terms), '조치: 다이 교체, 절삭유 보충');
    });
  });

  group('오타·단위(10-07)', () {
    test('한 글자 틀린 말은 자료에 있는 말로 바꾼 검색어를 제안한다', () {
      final all = _data();
      expect(searchKnowledge(all, '절사유'), isEmpty);
      expect(spellingSuggestions(all, '절사유'), contains('절삭유'));
      // 결과가 있으면 제안하지 않고, 두 글자 이하도 제안하지 않는다.
      expect(spellingSuggestions(all, '절삭유'), isEmpty);
      expect(spellingSuggestions(all, '절사'), isEmpty);
    });

    test('옴은 떼고 숫자로 찾는다(250옴 → 250 Ω)', () {
      const all = [
        KnowledgeEntry(id: 'h', category: 'a', title: 'HART 통신', lines: ['루프 저항 250 Ω 이상']),
      ];
      expect(searchKnowledge(all, '250옴').single.entry.id, 'h');
    });
  });
}
