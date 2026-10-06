import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/reference/search/knowledge_base.dart';
import 'package:tubing_calculator/src/presentation/reference/search/knowledge_entry.dart';

void main() {
  test('probe', () {
    final all = knowledgeBase();
    // ignore: avoid_print
    print('TOTAL ${all.length} ${knowledgeCategories(all)}');
    for (final q in [
      '절삭유가 안 나와요', '절삭유', '튜브가 주름', '튜브 주름', '누설', '새요', '리크', 'leak',
      '알람', '경보', '에러', '전압강하', '접지 저항', '4-20', '4~20mA', '진동이 심해요', '진동',
      '모터 과열', '전동기 과열', '차단기가 떨어져요', '차단기 트립', '누전', '절연저항', '메가',
      '수압 시험', '압력 시험', '플레어', '벤딩', '스웨지락', '토크', 'ㅈㅅㅇ', '센터링', '얼라인먼트',
    ]) {
      final h = searchKnowledge(all, q);
      // ignore: avoid_print
      print('Q "$q" -> ${h.length}: ${h.take(3).map((e) => e.entry.title).join(' | ')}');
    }
  });
}
