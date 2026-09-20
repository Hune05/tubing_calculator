// 관 규격 글에서 바깥지름을 뽑는 셈.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/core/utils/pipe_size.dart';

void main() {
  group('mm 표기', () {
    test('22mm · 12.7 mm', () {
      expect(pipeSizeToMm('22mm'), 22);
      expect(pipeSizeToMm('12.7 mm'), closeTo(12.7, 0.001));
    });
  });

  group('인치 표기', () {
    test('분수 인치', () {
      expect(pipeSizeToMm('1/2"'), closeTo(12.7, 0.01));
      expect(pipeSizeToMm('3/8"'), closeTo(9.525, 0.01));
      expect(pipeSizeToMm('3/4"'), closeTo(19.05, 0.01));
    });

    test('소수 인치', () {
      expect(pipeSizeToMm('0.5"'), closeTo(12.7, 0.01));
      expect(pipeSizeToMm('1.0"'), closeTo(25.4, 0.01));
    });

    test('따옴표 모양이 달라도 읽는다', () {
      expect(pipeSizeToMm('1/2”'), closeTo(12.7, 0.01));
      expect(pipeSizeToMm('0.5″'), closeTo(12.7, 0.01));
    });
  });

  group('전선관 표기', () {
    test('G22 · E25', () {
      expect(pipeSizeToMm('G22'), 22);
      expect(pipeSizeToMm('E25'), 25);
      expect(pipeSizeToMm('G104'), 104);
    });
  });

  group('따옴표 없는 것', () {
    test('1보다 작으면 인치로 본다', () {
      expect(pipeSizeToMm('0.5'), closeTo(12.7, 0.01));
      expect(pipeSizeToMm('0.375'), closeTo(9.525, 0.01));
    });

    test('큰 숫자는 mm로 본다', () {
      expect(pipeSizeToMm('22'), 22);
      expect(pipeSizeToMm('12.7'), closeTo(12.7, 0.001));
    });

    test('따옴표 없는 분수도 인치로 본다', () {
      expect(pipeSizeToMm('1/2'), closeTo(12.7, 0.01));
    });
  });

  group('못 읽는 것', () {
    test('빈 글이나 글자만', () {
      expect(pipeSizeToMm(''), 0);
      expect(pipeSizeToMm('   '), 0);
      expect(pipeSizeToMm('알 수 없음'), 0);
      expect(pipeSizeToMm('Unknown'), 0);
    });
  });
}
