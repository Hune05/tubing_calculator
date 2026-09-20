// 전선관 규격 이름에서 바깥지름을 뽑는 셈(3D에서 관 굵기를 그릴 때 쓴다).
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/conduit/conduit_marking_logic.dart';

void main() {
  group('전선관 규격에서 바깥지름', () {
    test('22mm 같은 표기', () {
      expect(conduitOuterDiameterMm('22mm'), 22);
      expect(conduitOuterDiameterMm('28 mm'), 28);
    });

    test('G22·E25 같은 표기', () {
      expect(conduitOuterDiameterMm('G22'), 22);
      expect(conduitOuterDiameterMm('E25'), 25);
      expect(conduitOuterDiameterMm('G104'), 104);
    });

    test('숫자만 적힌 것', () {
      expect(conduitOuterDiameterMm('36'), 36);
    });

    test('인치 표기는 mm로 바꾼다', () {
      expect(conduitOuterDiameterMm('1/2"'), closeTo(12.7, 0.01));
      expect(conduitOuterDiameterMm('3/4"'), closeTo(19.05, 0.01));
    });

    test('소수점도 읽는다', () {
      expect(conduitOuterDiameterMm('12.7mm'), closeTo(12.7, 0.001));
    });

    test('못 읽으면 0', () {
      expect(conduitOuterDiameterMm(''), 0);
      expect(conduitOuterDiameterMm('   '), 0);
      expect(conduitOuterDiameterMm('알 수 없음'), 0);
    });
  });
}
