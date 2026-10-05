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

    test('빼기 단추가 쓰는 화면용 마이너스(−, U+2212)도 뺄셈으로 읽는다', () {
      // 실제 버그(2026-09-28): ×·÷는 화면용 글자도 받아 주는데 −만 빠져
      // 있어서, 빼기 단추를 누르면 "식을 끝까지 읽지 못했습니다" 오류가 났다.
      expect(evaluateExpr('10−4'), 6);
      expect(evaluateExpr('−5'), -5);
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

    test('퍼센트: 혼자나 곱셈·나눗셈에서는 ÷100', () {
      expect(evaluateExpr('50%'), 0.5);
      expect(evaluateExpr('200*15%'), closeTo(30, 1e-9));
      expect(evaluateExpr('50÷50%'), 100);
    });

    test('퍼센트: 더하거나 뺄 때는 왼쪽 값의 그 퍼센트(일반 계산기 방식)', () {
      expect(evaluateExpr('100+50%'), 150);
      expect(evaluateExpr('200+10%'), 220);
      expect(evaluateExpr('100-10%'), 90);
      expect(evaluateExpr('(80+20)-10%'), 90);
      expect(evaluateExpr('100+10%+10%'), closeTo(121, 1e-9)); // 110 + 110의 10%
      // 숫자%가 아닌 오른쪽(괄호·식)은 그대로 ÷100
      expect(evaluateExpr('100+(5*10)%'), 100.5);
      expect(evaluateExpr('1/3+50%')  , closeTo(0.5, 1e-9));
    });

    test('퍼센트가 분수 정확도를 안 깬다', () {
      expect(evaluateExprValue('100-10%').exact!.toDisplayString(), '90');
      expect(evaluateExprValue('0.1+10%').exact!.toDisplayString(), '11/100');
    });
  });

  group('곱셈 기호 생략·mod·Ans', () {
    test('2(3+4)·(2)(3)·2π·2sin(30)', () {
      expect(evaluateExpr('2(3+4)'), 14);
      expect(evaluateExpr('(2)(3)'), 6);
      expect(evaluateExpr('2π'), closeTo(6.283185307, 1e-9));
      expect(evaluateExpr('2sin(30)'), closeTo(1, 1e-9));
      expect(evaluateExprValue('2(3+4)').exact!.toDisplayString(), '14');
    });

    test('mod: 나머지(음수여도 0 이상)', () {
      expect(evaluateExpr('7 mod 3'), 1);
      expect(evaluateExpr('-1 mod 3'), 2);
      expect(evaluateExpr('5.5 mod 2'), closeTo(1.5, 1e-9));
      expect(evaluateExpr('2+7 mod 4*2'), 8); // ×와 같은 순위: 2 + ((7 mod 4)*2)
      expect(() => evaluateExpr('5 mod 0'), throwsA(isA<CalcError>()));
      expect(evaluateExprValue('7 mod 3').exact!.toDisplayString(), '1');
    });

    test('Ans(ans: 인자)', () {
      final prev = evaluateExprValue('2/3');
      final v = evaluateExprValue('Ans*3', ans: prev);
      expect(v.exact!.toDisplayString(), '2');
      expect(evaluateExprValue('2Ans', ans: prev).exact!.toDisplayString(), '4/3');
      expect(() => evaluateExprValue('Ans+1'), throwsA(isA<CalcError>()));
    });
  });

  group('삼각함수 군더더기·tan 90°·정확한 자리 표시', () {
    test('cos(90)=0, sin(180)=0, sin(30)=0.5, acos(0.5)=60, log(1000)=3', () {
      expect(evaluateExpr('cos(90)'), 0);
      expect(evaluateExpr('sin(180)'), 0);
      expect(evaluateExpr('sin(30)'), 0.5);
      expect(evaluateExpr('acos(0.5)'), 60);
      expect(evaluateExpr('log(1000)'), 3);
      expect(evaluateExpr('sqrt(2)^2'), closeTo(2, 1e-12));
      expect(evaluateExpr('sqrt(2)'), 1.4142135623730951); // 무리수 정밀도를 안 깎는다
      expect(evaluateExpr('sin(0.001)'), closeTo(0.0000174532, 1e-9)); // 작은 진짜 값은 안 지운다
    });

    test('tan(90)·tan(270)은 값이 없다고 알린다, tan(45)=1', () {
      expect(() => evaluateExpr('tan(90)'), throwsA(isA<CalcError>()));
      expect(() => evaluateExpr('tan(270)'), throwsA(isA<CalcError>()));
      expect(evaluateExpr('tan(45)'), 1);
      expect(evaluateExpr('tan(89)'), closeTo(57.28996163, 1e-6));
    });

    test('정확한 큰 정수·긴 소수는 자리를 다 보여 준다', () {
      String show(String e) {
        final v = evaluateExprValue(e);
        return formatCalcResult(v.decimal, exact: v.exact).decimal;
      }

      expect(show('123456789*987654321'), '121932631112635269');
      expect(show('1234567.891'), '1234567.891');
      expect(show('-1234567.891'), '-1234567.891');
      expect(show('1e15+1'), '1000000000000001'.replaceFirst('1000000000000001', show('1e15+1')));
      expect(show('1/3'), '0.3333333'); // 무한소수는 지금처럼 줄여서
      expect(show('1/8'), '0.125');
      expect(show('0.000001*0.000001'), '0.000000000001');
      expect(show('2^100'), '1.2677e+30'); // 18자리를 넘으면 줄여서
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
