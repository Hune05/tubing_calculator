// 한 번 꺾어 재 본 값으로 제원을 되짚는 셈.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/core/engine/bend_geometry.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_stock_deduct.dart';

void main() {
  group('재 본 값으로 게인 되짚기', () {
    test('90°: 도면 합에서 자른 길이를 뺀 것이 게인이다', () {
      // 도면 500 + 400 = 900, 실제로 880을 잘라 꺾었다면 게인 20.
      final g = gainFromMeasured(
        legA: 500,
        legB: 400,
        cutLength: 880,
        angleDeg: 90,
      );
      expect(g, closeTo(20.0, 0.001));
    });

    test('반경만으로 잰 것과 맞는다', () {
      // R=38, 90°면 기하 게인은 2·38 − π·38/2 = 16.31.
      const r = 38.0;
      final geo = geometricGain(r, 90);
      final cut = 500 + 400 - geo;
      final g = gainFromMeasured(
        legA: 500,
        legB: 400,
        cutLength: cut,
        angleDeg: 90,
      );
      expect(g, closeTo(geo, 0.001));
    });

    test('45°에서 잰 값은 90° 기준으로 환산한다', () {
      // 90° 게인 40인 벤더를 45°로 한 번 꺾으면 4.01만큼 줄어든다.
      final at45 = scaleMeasuredGain(40, 45);
      final g = gainFromMeasured(
        legA: 500,
        legB: 400,
        cutLength: 900 - at45,
        angleDeg: 45,
      );
      expect(g, closeTo(40.0, 0.01));
    });

    test('넣은 값을 도로 쓰면 같은 값이 나온다', () {
      for (final double deg in [22.5, 30, 45, 60, 90, 120]) {
        final at = scaleMeasuredGain(35, deg);
        final g = gainFromMeasured(
          legA: 600,
          legB: 500,
          cutLength: 1100 - at,
          angleDeg: deg,
        );
        expect(g, closeTo(35.0, 0.01), reason: '$deg°');
      }
    });

    test('자른 길이가 도면 합보다 길면(줄지 않았으면) 0', () {
      final g = gainFromMeasured(
        legA: 500,
        legB: 400,
        cutLength: 950,
        angleDeg: 90,
      );
      expect(g, 0.0);
    });

    test('꺾지 않았거나 접힌 각이면 0', () {
      expect(
        gainFromMeasured(legA: 500, legB: 400, cutLength: 880, angleDeg: 0),
        0.0,
      );
      expect(
        gainFromMeasured(legA: 500, legB: 400, cutLength: 880, angleDeg: 180),
        0.0,
      );
    });
  });

  group('재 본 값으로 테이크업 되짚기', () {
    test('90°: 바깥면까지 잰 길이에서 마킹 뒤 길이를 뺀 것', () {
      final t = takeUpFromMeasured(
        legOutside: 300,
        markToEnd: 148,
        angleDeg: 90,
      );
      expect(t, closeTo(152.0, 0.001));
    });

    test('45°에서 잰 값은 90° 기준으로 환산한다', () {
      // 90° 테이크업 152.4면 45°에서는 152.4 × tan22.5 = 63.1.
      final at45 = 152.4 * 0.4142135;
      final t = takeUpFromMeasured(
        legOutside: 300,
        markToEnd: 300 - at45,
        angleDeg: 45,
      );
      expect(t, closeTo(152.4, 0.01));
    });

    test('말이 안 되는 값이면 0', () {
      expect(
        takeUpFromMeasured(legOutside: 100, markToEnd: 150, angleDeg: 90),
        0.0,
      );
      expect(
        takeUpFromMeasured(legOutside: 300, markToEnd: 150, angleDeg: 0),
        0.0,
      );
    });
  });

  group('창고에 모자란 자재 알림', () {
    const tube = StockTake(name: '튜브 3/8"', qty: 5, unit: '본');
    const union = StockTake(name: '[HY-LOK] 3/8" Union', qty: 4, unit: 'EA');

    test('넉넉하면 아무 말도 하지 않는다', () {
      expect(
        shortStockWarning([tube, union], {
          '튜브 3/8"': 10,
          '[HY-LOK] 3/8" Union': 20,
        }),
        '',
      );
    });

    test('모자라면 얼마나 모자란지 알려 준다', () {
      final msg = shortStockWarning([tube, union], {
        '튜브 3/8"': 2,
        '[HY-LOK] 3/8" Union': 20,
      });
      expect(msg, contains('5본 필요'));
      expect(msg, contains('창고에 2본'));
      expect(msg, isNot(contains('Union')));
    });

    test('딱 맞으면 모자란 것이 아니다', () {
      expect(shortStockWarning([tube], {'튜브 3/8"': 5}), '');
    });

    test('재고에 아예 없는 자재는 여기서 말하지 않는다', () {
      // "재고에 없다"는 차감할 때 따로 알려 준다.
      expect(shortStockWarning([tube], const {}), '');
    });
  });
}
