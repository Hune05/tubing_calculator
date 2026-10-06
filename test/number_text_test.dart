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

  test('효율·역률 칸에 1 이하를 넣으면 안내 글이 나온다', () {
    expect(
      ratioHintText('역률 (%)', '0.85'),
      '0.85은 비율로 읽어 85%로 계산합니다. 퍼센트는 85처럼 넣으십시오.',
    );
    expect(ratioHintText('효율 (%)', '1'), contains('1은 비율로 읽어 100%'));
    expect(ratioHintText('역률 (%)', '85'), isNull);
    expect(ratioHintText('역률 (%)', ''), isNull);
    // 이름에 효율·역률 같은 말이 없는 % 칸은 1이 1%일 수 있어 안내하지 않는다.
    expect(ratioHintText('전원 쪽 전압강하 (%, 선택)', '0.5'), isNull);
  });
}
