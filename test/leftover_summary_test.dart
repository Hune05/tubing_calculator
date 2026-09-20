// 잔재를 규격별로 묶어 재고 줄에 같이 보여 주는 셈.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_leftovers.dart';

void main() {
  group('규격별로 묶기', () {
    test('같은 규격은 하나로 묶고 개수·합·가장 긴 것을 센다', () {
      final by = leftoverSummaryBySpec(const [
        Leftover('튜브 3/8"', 400),
        Leftover('튜브 3/8"', 1200),
        Leftover('튜브 3/8"', 250),
      ]);
      expect(by.length, 1);
      final s = by.values.first;
      expect(s.count, 3);
      expect(s.totalMm, 1850);
      expect(s.longestMm, 1200);
    });

    test('규격이 다르면 따로 센다', () {
      final by = leftoverSummaryBySpec(const [
        Leftover('튜브 3/8"', 400),
        Leftover('튜브 1/2"', 900),
      ]);
      expect(by.length, 2);
    });

    test('빈칸·따옴표 모양이 달라도 같은 규격으로 본다', () {
      final by = leftoverSummaryBySpec(const [
        Leftover('튜브  3/8"', 400),
        Leftover('튜브 3/8”', 600),
      ]);
      expect(by.length, 1);
      expect(by.values.first.count, 2);
    });

    test('길이가 0 이하이거나 규격이 없으면 세지 않는다', () {
      final by = leftoverSummaryBySpec(const [
        Leftover('튜브 3/8"', 0),
        Leftover('', 500),
      ]);
      expect(by, isEmpty);
    });
  });

  group('자재 이름으로 잔재 찾기', () {
    final by = leftoverSummaryBySpec(const [
      Leftover('튜브 3/8"', 400),
      Leftover('튜브 3/8"', 1200),
      Leftover('앵글 40x40x3', 700),
    ]);

    test('자재 이름이 규격 그대로면 찾는다', () {
      expect(leftoverFor('튜브 3/8"', by)!.count, 2);
    });

    test('자재 이름 안에 규격이 들어 있어도 찾는다', () {
      expect(leftoverFor('[세아] 앵글 40x40x3', by)!.count, 1);
    });

    test('따옴표 모양이 달라도 찾는다', () {
      expect(leftoverFor('튜브 3/8”', by)!.count, 2);
    });

    test('맞는 잔재가 없으면 아무것도 안 준다', () {
      expect(leftoverFor('[HY-LOK] 3/8" Union', by), isNull);
      expect(leftoverFor('', by), isNull);
    });
  });

  group('보여 줄 규격 이름', () {
    test('다듬기 전 이름을 그대로 들고 있는다', () {
      final by = leftoverSummaryBySpec(const [
        Leftover('찬넬 75x40x5', 2000),
      ]);
      expect(by.values.first.label, '찬넬 75x40x5');
    });

    test('같은 규격이 여러 번 나오면 처음 이름을 쓴다', () {
      final by = leftoverSummaryBySpec(const [
        Leftover('TUBE 3/8"', 400),
        Leftover('tube 3/8"', 600),
      ]);
      expect(by.values.first.label, 'TUBE 3/8"');
      expect(by.values.first.count, 2);
    });
  });

  group('자재 줄에 붙일 글', () {
    test('개수와 가장 긴 것을 적는다', () {
      const s = LeftoverSummary(count: 3, totalMm: 1850, longestMm: 1200);
      expect(s.short, '잔재 3개 · 가장 긴 것 1200mm');
    });
  });
}
