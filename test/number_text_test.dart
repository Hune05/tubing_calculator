// 숫자 칸 글 읽기: 쉼표를 한 규칙으로(천 단위 / 소수점).
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/common/number_text.dart';

void main() {
  test('점 소수와 정수', () {
    expect(parseNumberText('12.5'), 12.5);
    expect(parseNumberText(' 380 '), 380);
    expect(parseNumberText('-5'), -5);
  });

  test('쉼표 하나·뒤가 세 자리가 아니면 소수점', () {
    expect(parseNumberText('1,5'), 1.5);
    expect(parseNumberText('0,85'), 0.85);
    expect(parseNumberText('12,25'), 12.25);
  });

  test('천 단위 쉼표는 지운다', () {
    expect(parseNumberText('1,500'), 1500);
    expect(parseNumberText('1,500.5'), 1500.5);
    expect(parseNumberText('12,345,678'), 12345678);
  });

  test('유럽식 1.500,5는 1500.5', () {
    expect(parseNumberText('1.500,5'), 1500.5);
  });

  test('읽을 수 없으면 null', () {
    expect(parseNumberText(''), isNull);
    expect(parseNumberText('abc'), isNull);
    expect(parseNumberText('1,2,3x'), isNull);
  });
}
