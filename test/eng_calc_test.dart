// 공학용 계산기 셈: 사칙연산·괄호·거듭제곱·계승·퍼센트·공학 함수, 오류 처리, 결과 글.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/field_tools/eng_calc.dart';
import 'package:tubing_calculator/src/presentation/unit_converter/unit_defs.dart';

void main() {
  group('사칙연산·우선순위·괄호', () {
    test('더하기·빼기·곱하기·나누기', () {
      expect(evaluateExpr('2+3'), 5);
      expect(evaluateExpr('10-4'), 6);
      expect(evaluateExpr('3*4'), 12);
      expect(evaluateExpr('3×4'), 12);
      expect(evaluateExpr('10/4'), 2.5);
      expect(evaluateExpr('10÷4'), 2.5);
    });

    test('곱셈·나눗셈이 덧셈·뺄셈보다 먼저', () {
      expect(evaluateExpr('2+3*4'), 14);
      expect(evaluateExpr('2*3+4'), 10);
      expect(evaluateExpr('20-4/2'), 18);
    });

    test('괄호가 우선순위를 바꾼다', () {
      expect(evaluateExpr('(2+3)*4'), 20);
      expect(evaluateExpr('2*(3+4)'), 14);
      expect(evaluateExpr('((1+2)*(3+4))'), 21);
    });

    test('중첩·짝 안 맞는 괄호는 오류', () {
      expect(() => evaluateExpr('(1+2'), throwsA(isA<CalcError>()));
      expect(() => evaluateExpr('1+2)'), throwsA(isA<CalcError>()));
    });

    test('단항 부호', () {
      expect(evaluateExpr('-5+3'), -2);
      expect(evaluateExpr('3*-2'), -6);
      expect(evaluateExpr('-(2+3)'), -5);
      expect(evaluateExpr('--5'), 5);
    });

    test('0으로 나누면 오류', () {
      expect(() => evaluateExpr('1/0'), throwsA(isA<CalcError>()));
      expect(() => evaluateExpr('5/(2-2)'), throwsA(isA<CalcError>()));
    });

    test('빈 식·읽을 수 없는 글자는 오류', () {
      expect(() => evaluateExpr(''), throwsA(isA<CalcError>()));
      expect(() => evaluateExpr('1@2'), throwsA(isA<CalcError>()));
      expect(() => evaluateExpr('1 2'), throwsA(isA<CalcError>()));
    });
  });

  group('거듭제곱·계승·퍼센트', () {
    test('거듭제곱은 오른쪽 결합, 단항 부호보다 세다', () {
      expect(evaluateExpr('2^3'), 8);
      expect(evaluateExpr('2^3^2'), 512); // 2^(3^2) = 2^9
      expect(evaluateExpr('-2^2'), -4); // -(2^2)
      expect(evaluateExpr('2^-2'), 0.25);
    });

    test('계승', () {
      expect(evaluateExpr('5!'), 120);
      expect(evaluateExpr('0!'), 1);
      expect(evaluateExpr('3!+1'), 7);
      expect(() => evaluateExpr('(-1)!'), throwsA(isA<CalcError>()));
      expect(() => evaluateExpr('2.5!'), throwsA(isA<CalcError>()));
    });

    test('퍼센트는 ÷100(뒤쪽 값에만 붙는다)', () {
      expect(evaluateExpr('50%'), 0.5);
      expect(evaluateExpr('100+50%'), 100.5);
      expect(evaluateExpr('200*15%'), closeTo(30, 1e-9));
    });
  });

  group('공학 함수(기본 도, degree)', () {
    test('sin·cos·tan', () {
      expect(evaluateExpr('sin(30)'), closeTo(0.5, 1e-9));
      expect(evaluateExpr('sin30'), closeTo(0.5, 1e-9)); // 괄호 없이도
      expect(evaluateExpr('cos(60)'), closeTo(0.5, 1e-9));
      expect(evaluateExpr('tan(45)'), closeTo(1, 1e-9));
    });

    test('역삼각함수는 도로 돌아온다', () {
      expect(evaluateExpr('asin(0.5)'), closeTo(30, 1e-9));
      expect(evaluateExpr('acos(0.5)'), closeTo(60, 1e-9));
      expect(evaluateExpr('atan(1)'), closeTo(45, 1e-9));
      expect(() => evaluateExpr('asin(2)'), throwsA(isA<CalcError>()));
    });

    test('라디안 단위로도 계산된다', () {
      expect(
        evaluateExpr('sin(90)', angle: AngleUnit.radian),
        closeTo(0.8940, 1e-3),
      );
    });

    test('sqrt·ln·log·abs·exp', () {
      expect(evaluateExpr('sqrt(9)'), 3);
      expect(evaluateExpr('sqrt9'), 3);
      expect(() => evaluateExpr('sqrt(-1)'), throwsA(isA<CalcError>()));
      expect(evaluateExpr('ln(1)'), 0);
      expect(() => evaluateExpr('ln(0)'), throwsA(isA<CalcError>()));
      expect(evaluateExpr('log(100)'), closeTo(2, 1e-9));
      expect(evaluateExpr('abs(-7)'), 7);
      expect(evaluateExpr('exp(0)'), 1);
    });

    test('식 안에 함수를 섞어 쓴다', () {
      expect(evaluateExpr('2*sin(30)+1'), closeTo(2, 1e-9));
      expect(evaluateExpr('sqrt(3^2+4^2)'), closeTo(5, 1e-9));
    });

    test('모르는 함수·이름은 오류', () {
      expect(() => evaluateExpr('foo(1)'), throwsA(isA<CalcError>()));
    });
  });

  group('상수', () {
    test('π·pi·e', () {
      expect(evaluateExpr('π'), closeTo(3.14159265, 1e-6));
      expect(evaluateExpr('pi'), closeTo(3.14159265, 1e-6));
      expect(evaluateExpr('e'), closeTo(2.71828182, 1e-6));
      expect(evaluateExpr('2*π'), closeTo(6.28318530, 1e-6));
    });
  });

  group('인치 분수 입력은 화면 쪽에서 소수로 바꿔 넣는다', () {
    test('parseInches로 바꾼 값을 식에 그대로 쓴다', () {
      final v = parseInches("1' 3-1/2\"")!; // 15.5
      expect(evaluateExpr('$v+0.5'), 16.0);
    });

    test('단순 분수(3/8)는 나눗셈으로도 같은 값', () {
      expect(evaluateExpr('3/8'), closeTo(0.375, 1e-9));
    });
  });

  group('정확한 분수(Fraction)로 그대로 간다', () {
    Fraction ex(String expr) => evaluateExprValue(expr).exact!;

    test('사칙연산은 오차 없이 분수로 남는다', () {
      expect(ex('1/3').toDisplayString(), '1/3');
      expect(ex('1/3+1/6').toDisplayString(), '1/2'); // 약분까지
      expect(ex('2/3*3/4').toDisplayString(), '1/2');
      expect(ex('(1/3)/(2/9)').toDisplayString(), '3/2');
      expect(ex('7/2-3').toDisplayString(), '1/2');
    });

    test('소수 입력도 오차 없이 분수로 더해진다("0.1+0.2"가 진짜 0.3)', () {
      final v = evaluateExprValue('0.1+0.2');
      expect(v.exact!.toDisplayString(), '3/10');
      // 분수(3/10)를 거쳐 나온 소수라 보통 부동소수 덧셈(0.1+0.2=0.30000000000000004)과
      // 달리 딱 0.3이다 — 분수로 계산한 덕에 그 오차가 없다.
      expect(v.decimal, 0.3);
      expect(0.1 + 0.2, isNot(0.3));
    });

    test('정수 거듭제곱·계승·퍼센트도 분수로', () {
      expect(ex('(1/2)^3').toDisplayString(), '1/8');
      expect(ex('2^-2').toDisplayString(), '1/4');
      expect(ex('5!').toDisplayString(), '120');
      expect(ex('50%').toDisplayString(), '1/2');
    });

    test('제곱수의 제곱근은 분수로 남는다', () {
      expect(ex('sqrt(4/9)').toDisplayString(), '2/3');
      expect(ex('sqrt(9)').toDisplayString(), '3');
    });

    test('abs·단항 부호도 분수를 지킨다', () {
      expect(ex('abs(-3/4)').toDisplayString(), '3/4');
      expect(ex('-(1/4)').toDisplayString(), '-1/4');
    });

    test('대분수 글', () {
      expect(
        evaluateExprValue('11/8').exact!.toDisplayString(mixed: true),
        '1 3/8',
      );
      expect(
        evaluateExprValue('3/8').exact!.toDisplayString(mixed: true),
        '3/8',
      );
    });

    test('무리수를 거치면 그 뒤로는 분수가 없다(null)', () {
      expect(
        evaluateExprValue('sin(30)').exact,
        isNull,
      ); // 0.5인데도 sin을 거쳤으니 소수만
      expect(evaluateExprValue('sqrt(2)').exact, isNull);
      expect(evaluateExprValue('ln(2)').exact, isNull);
      expect(evaluateExprValue('π').exact, isNull);
      expect(
        evaluateExprValue('1+sqrt(2)').exact,
        isNull,
      ); // 한 번이라도 섞이면 전체가 null
    });

    test('0으로 나누기·0의 음수 제곱은 분수 쪽에서도 막는다', () {
      expect(() => evaluateExprValue('1/0'), throwsA(isA<CalcError>()));
      expect(() => evaluateExprValue('0^-1'), throwsA(isA<CalcError>()));
    });
  });

  group('결과 글(소수·분수)', () {
    test('showFraction이 아니면 분수 글이 없다', () {
      final r = formatCalcResult(0.375);
      expect(r.decimal, '0.375');
      expect(r.fraction, isNull);
    });

    test('showFraction이면 가장 가까운 인치 분수도 같이', () {
      final r = formatCalcResult(0.375, showFraction: true, denom: 16);
      expect(r.decimal, '0.375');
      expect(r.fraction, '3/8"');
    });

    test('asFeetInch면 12를 넘을 때 피트도', () {
      final r = formatCalcResult(15.5, showFraction: true, asFeetInch: true);
      expect(r.fraction, "1' 3-1/2\"");
    });

    test('NaN·무한대는 "오류"', () {
      expect(formatCalcResult(double.nan).decimal, '오류');
      expect(formatCalcResult(double.infinity).decimal, '오류');
    });
  });
}
