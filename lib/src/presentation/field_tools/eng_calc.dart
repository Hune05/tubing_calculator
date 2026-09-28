// 공학용 계산기 셈(화면 없음). 문자열 수식(사칙연산·괄호·거듭제곱·공학 함수)을 계산한다.
//
// 사칙연산(+ − × ÷)·정수 거듭제곱(^)·계승(!)·퍼센트(%)만 쓰면 결과가 "정확한 분수"로도
// 같이 나온다(BigInt로 약분까지 하는 Fraction). sin·sqrt(제곱수가 아닌 것)·ln 같은
// 무리수 함수를 한 번이라도 거치면 그 뒤로는 소수만 나온다(수학적으로 분수로 못 쓰니까).
//
// 인치 분수·피트 입력("1' 3-1/2"" 같은 글)은 이 식에 직접 넣지 않는다. 화면 쪽에서
// parseInches(unit_defs.dart)로 소수(예: 15.5)로 먼저 바꾼 뒤, 그 소수를 이 식의 숫자로
// 쓴다. 3/8처럼 "/"만 있는 것은 나눗셈으로 계산해도 같은 값(정확히 3/8)이라 따로 다루지
// 않는다.
//
// 지원: + − × ÷ ^(거듭제곱) !(계승) %(퍼센트, 뒤에 온 값 ÷100) 괄호,
//   sin cos tan asin acos atan sqrt ln log abs exp, 상수 π e.
// 안 되는 것(범위 밖): 암묵 곱셈("2π"는 안 되고 "2×π"로 넣는다), 나머지 연산자(mod).
library;

import 'dart:math' as math;

import '../unit_converter/unit_defs.dart';

/// 계산할 수 없을 때(괄호가 안 맞다, 0으로 나눔, 정의역 밖 등).
class CalcError implements Exception {
  final String message;
  const CalcError(this.message);
  @override
  String toString() => message;
}

enum AngleUnit { degree, radian }

// ─────────────────────────── 정확한 분수(Fraction) ───────────────────────────

BigInt _gcdBig(BigInt a, BigInt b) {
  while (b != BigInt.zero) {
    final t = b;
    b = a % b;
    a = t;
  }
  return a == BigInt.zero ? BigInt.one : a;
}

/// 정확한 분수. 분모는 항상 양수로, 약분한 채로 둔다.
/// 사칙연산·정수 거듭제곱·계승 안에서는 오차 없이 그대로 간다(소수로 안 거친다).
class Fraction {
  final BigInt num;
  final BigInt den;
  const Fraction._(this.num, this.den);

  factory Fraction(BigInt n, BigInt d) {
    if (d == BigInt.zero) throw const CalcError('0으로 나눌 수 없습니다');
    if (d.isNegative) {
      n = -n;
      d = -d;
    }
    final g = _gcdBig(n.abs(), d);
    return Fraction._(n ~/ g, d ~/ g);
  }

  factory Fraction.fromInt(int i) => Fraction(BigInt.from(i), BigInt.one);

  /// "123", "123.456", "-0.5" 같은 소수 글을 오차 없이 분수로(123456/1000 약분).
  factory Fraction.fromDecimalString(String s) {
    final neg = s.startsWith('-');
    final body = neg ? s.substring(1) : s;
    final dot = body.indexOf('.');
    BigInt n;
    BigInt d;
    if (dot < 0) {
      n = BigInt.parse(body.isEmpty ? '0' : body);
      d = BigInt.one;
    } else {
      final whole = body.substring(0, dot);
      final frac = body.substring(dot + 1);
      n = BigInt.parse(
        (whole.isEmpty ? '0' : whole) + (frac.isEmpty ? '0' : frac),
      );
      d = BigInt.from(10).pow(frac.isEmpty ? 1 : frac.length);
    }
    return Fraction(neg ? -n : n, d);
  }

  bool get isNegative => num.isNegative;
  bool get isZero => num == BigInt.zero;
  bool get isInteger => den == BigInt.one;

  double toDouble() => num.toDouble() / den.toDouble();

  Fraction operator +(Fraction o) =>
      Fraction(num * o.den + o.num * den, den * o.den);
  Fraction operator -(Fraction o) =>
      Fraction(num * o.den - o.num * den, den * o.den);
  Fraction operator *(Fraction o) => Fraction(num * o.num, den * o.den);
  Fraction operator /(Fraction o) {
    if (o.num == BigInt.zero) throw const CalcError('0으로 나눌 수 없습니다');
    return Fraction(num * o.den, den * o.num);
  }

  Fraction operator -() => Fraction(-num, den);
  Fraction abs() => Fraction(num.abs(), den);

  /// 정수 거듭제곱만(음수 지수는 역수). [e]가 너무 크면(자릿수 폭발) null(소수로 넘긴다).
  Fraction? powInt(int e) {
    if (e.abs() > 64) return null;
    if (e == 0) return Fraction.fromInt(1);
    if (num == BigInt.zero) {
      return e > 0 ? Fraction.fromInt(0) : null; // 0의 음수 거듭제곱은 안 된다.
    }
    if (e > 0) return Fraction(num.pow(e), den.pow(e));
    return Fraction(den.pow(-e), num.pow(-e));
  }

  /// 정확히 제곱수(분자·분모 둘 다)면 그 제곱근을 분수로, 아니면 null(소수로 넘긴다).
  Fraction? exactSqrt() {
    if (isNegative) return null;
    final sn = _bigSqrtExact(num);
    final sd = _bigSqrtExact(den);
    if (sn == null || sd == null) return null;
    return Fraction(sn, sd);
  }

  /// 결과(정수면 "7", 아니면 "num/den". [mixed]면 대분수 "1 3/8").
  String toDisplayString({bool mixed = false}) {
    if (den == BigInt.one) return num.toString();
    if (!mixed || num.abs() < den) return '$num/$den';
    final neg = isNegative;
    final a = num.abs();
    final whole = a ~/ den;
    final rest = a % den;
    final body = rest == BigInt.zero ? '$whole' : '$whole $rest/$den';
    return neg ? '-$body' : body;
  }

  @override
  bool operator ==(Object other) =>
      other is Fraction && other.num == num && other.den == den;
  @override
  int get hashCode => Object.hash(num, den);
  @override
  String toString() => toDisplayString();
}

/// 음이 아닌 정수의 정확한 제곱근(정수일 때만). 아니면 null.
BigInt? _bigSqrtExact(BigInt n) {
  if (n == BigInt.zero) return BigInt.zero;
  // 대략적인 시작값(double로) 뒤 뉴턴법으로 다듬는다.
  var x = BigInt.from(math.sqrt(n.toDouble()).round());
  for (var i = 0; i < 6; i++) {
    if (x == BigInt.zero) break;
    x = (x + n ~/ x) ~/ BigInt.two;
  }
  for (final c in [x - BigInt.one, x, x + BigInt.one]) {
    if (c.isNegative) continue;
    if (c * c == n) return c;
  }
  return null;
}

/// 계산 결과 하나. [exact]가 있으면(사칙연산·정수 거듭제곱·계승만 거쳤으면) 그 분수와
/// 소수가 정확히 같다. 없으면(무리수 함수를 거쳤으면) 소수만 믿을 수 있다.
class CalcValue {
  final double decimal;
  final Fraction? exact;
  const CalcValue(this.decimal, this.exact);
  factory CalcValue.fromFraction(Fraction f) => CalcValue(f.toDouble(), f);
  factory CalcValue.decimalOnly(double d) => CalcValue(d, null);
}

/// 수식 글을 계산해 값 하나(소수 + 있으면 정확한 분수)로.
CalcValue evaluateExprValue(String expr, {AngleUnit angle = AngleUnit.degree}) {
  final p = _Parser(expr, angle);
  final v = p._parseExpr();
  p._skipWs();
  if (p._pos != p._src.length) {
    throw CalcError('식을 끝까지 읽지 못했습니다("${p._src.substring(p._pos)}" 앞에서 막힘)');
  }
  if (v.decimal.isNaN) throw const CalcError('계산할 수 없습니다');
  if (v.decimal.isInfinite) throw const CalcError('결과가 너무 큽니다');
  return v;
}

/// 소수만 필요할 때(예전부터 쓰던 자리, 시험 다수가 이 모양을 쓴다).
double evaluateExpr(String expr, {AngleUnit angle = AngleUnit.degree}) =>
    evaluateExprValue(expr, angle: angle).decimal;

const List<String> kCalcFunctions = [
  'sin',
  'cos',
  'tan',
  'asin',
  'acos',
  'atan',
  'sqrt',
  'ln',
  'log',
  'abs',
  'exp',
];

class _Parser {
  final String _src;
  final AngleUnit angle;
  int _pos = 0;
  _Parser(this._src, this.angle);

  void _skipWs() {
    while (_pos < _src.length && _src[_pos] == ' ') {
      _pos++;
    }
  }

  bool _isDigit(String c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;
  bool _isAlpha(String c) => RegExp(r'^[a-zA-Z]$').hasMatch(c);

  // expr := term (('+'|'-') term)*
  CalcValue _parseExpr() {
    var v = _parseTerm();
    while (true) {
      _skipWs();
      // '-'(자판 하이픈)·'−'(U+2212, 화면용 마이너스) 둘 다 뺄셈으로 받는다.
      if (_pos < _src.length &&
          (_src[_pos] == '+' || _src[_pos] == '-' || _src[_pos] == '−')) {
        final op = _src[_pos];
        _pos++;
        final rhs = _parseTerm();
        final d = op == '+' ? v.decimal + rhs.decimal : v.decimal - rhs.decimal;
        final ex = (v.exact != null && rhs.exact != null)
            ? (op == '+' ? v.exact! + rhs.exact! : v.exact! - rhs.exact!)
            : null;
        v = ex != null ? CalcValue.fromFraction(ex) : CalcValue.decimalOnly(d);
      } else {
        break;
      }
    }
    return v;
  }

  // term := unary (('×'|'*'|'÷'|'/') unary)*
  CalcValue _parseTerm() {
    var v = _parseUnary();
    while (true) {
      _skipWs();
      if (_pos >= _src.length) break;
      final c = _src[_pos];
      if (c == '*' || c == '×') {
        _pos++;
        final rhs = _parseUnary();
        final ex = (v.exact != null && rhs.exact != null)
            ? v.exact! * rhs.exact!
            : null;
        v = ex != null
            ? CalcValue.fromFraction(ex)
            : CalcValue.decimalOnly(v.decimal * rhs.decimal);
      } else if (c == '/' || c == '÷') {
        _pos++;
        final rhs = _parseUnary();
        if (rhs.decimal == 0) throw const CalcError('0으로 나눌 수 없습니다');
        final ex = (v.exact != null && rhs.exact != null && !rhs.exact!.isZero)
            ? v.exact! / rhs.exact!
            : null;
        v = ex != null
            ? CalcValue.fromFraction(ex)
            : CalcValue.decimalOnly(v.decimal / rhs.decimal);
      } else {
        break;
      }
    }
    return v;
  }

  // unary := ('-'|'+') unary | power
  CalcValue _parseUnary() {
    _skipWs();
    if (_pos < _src.length && (_src[_pos] == '-' || _src[_pos] == '−')) {
      _pos++;
      final v = _parseUnary();
      return v.exact != null
          ? CalcValue.fromFraction(-v.exact!)
          : CalcValue.decimalOnly(-v.decimal);
    }
    if (_pos < _src.length && _src[_pos] == '+') {
      _pos++;
      return _parseUnary();
    }
    return _parsePower();
  }

  // power := factor ('^' unary)?   (오른쪽 결합: 2^3^2 = 2^(3^2))
  CalcValue _parsePower() {
    final v = _parseFactor();
    _skipWs();
    if (_pos < _src.length && _src[_pos] == '^') {
      _pos++;
      final rhs = _parseUnary();
      Fraction? ex;
      if (v.exact != null && rhs.exact != null && rhs.exact!.isInteger) {
        final e = rhs.exact!.num;
        if (e.abs() <= BigInt.from(64)) {
          ex = v.exact!.powInt(e.toInt());
        }
      }
      final r = ex != null
          ? CalcValue.fromFraction(ex)
          : CalcValue.decimalOnly(math.pow(v.decimal, rhs.decimal).toDouble());
      return _maybeFactorial(_maybePercent(r));
    }
    return v;
  }

  CalcValue _parseFactor() {
    _skipWs();
    if (_pos >= _src.length) throw const CalcError('식이 비었습니다');
    final c = _src[_pos];
    if (c == '(') {
      _pos++;
      final v = _parseExpr();
      _skipWs();
      if (_pos >= _src.length || _src[_pos] != ')') {
        throw const CalcError('괄호가 안 맞습니다');
      }
      _pos++;
      return _maybeFactorial(_maybePercent(v));
    }
    if (_isDigit(c) || c == '.') {
      return _maybeFactorial(_maybePercent(_parseNumber()));
    }
    if (c == 'π') {
      _pos++;
      return _maybeFactorial(_maybePercent(CalcValue.decimalOnly(math.pi)));
    }
    if (_isAlpha(c)) {
      final name = _parseIdent();
      if (name == 'pi') {
        return _maybeFactorial(_maybePercent(CalcValue.decimalOnly(math.pi)));
      }
      if (name == 'e') {
        return _maybeFactorial(_maybePercent(CalcValue.decimalOnly(math.e)));
      }
      if (kCalcFunctions.contains(name)) {
        _skipWs();
        CalcValue arg;
        if (_pos < _src.length && _src[_pos] == '(') {
          _pos++;
          arg = _parseExpr();
          _skipWs();
          if (_pos >= _src.length || _src[_pos] != ')') {
            throw const CalcError('괄호가 안 맞습니다');
          }
          _pos++;
        } else {
          arg = _parseUnary(); // sin30처럼 괄호 없이도 허용.
        }
        return _maybeFactorial(_maybePercent(_applyFn(name, arg)));
      }
      throw CalcError('모르는 함수입니다: $name');
    }
    throw CalcError('읽을 수 없는 글자입니다: $c');
  }

  /// 뒤에 오는 "!"(계승)를 적용한다. 0 이상 정수에만 된다. 결과는 늘 정수라 그대로 분수.
  CalcValue _maybeFactorial(CalcValue v) {
    _skipWs();
    if (_pos < _src.length && _src[_pos] == '!') {
      _pos++;
      final d = v.decimal;
      if (d < 0 || d != d.roundToDouble() || d > 170) {
        throw const CalcError('!(계승)은 0~170의 정수에만 됩니다');
      }
      BigInt r = BigInt.one;
      final n = d.round();
      for (int i = 2; i <= n; i++) {
        r *= BigInt.from(i);
      }
      return _maybePercent(CalcValue.fromFraction(Fraction(r, BigInt.one)));
    }
    return v;
  }

  /// 뒤에 오는 "%"를 적용한다(÷100). 계승보다 먼저 붙을 수도 있어 factorial 쪽에서도 부른다.
  CalcValue _maybePercent(CalcValue v) {
    _skipWs();
    if (_pos < _src.length && _src[_pos] == '%') {
      _pos++;
      final hundred = Fraction.fromInt(100);
      final ex = v.exact != null ? v.exact! / hundred : null;
      return ex != null
          ? CalcValue.fromFraction(ex)
          : CalcValue.decimalOnly(v.decimal / 100);
    }
    return v;
  }

  CalcValue _applyFn(String name, CalcValue arg) {
    final a = arg.decimal;
    double rad(double d) => angle == AngleUnit.degree ? d * math.pi / 180 : d;
    double deg(double r) => angle == AngleUnit.degree ? r * 180 / math.pi : r;
    switch (name) {
      case 'sin':
        return CalcValue.decimalOnly(math.sin(rad(a)));
      case 'cos':
        return CalcValue.decimalOnly(math.cos(rad(a)));
      case 'tan':
        return CalcValue.decimalOnly(math.tan(rad(a)));
      case 'asin':
        if (a < -1 || a > 1) throw const CalcError('asin은 -1~1 값에만 됩니다');
        return CalcValue.decimalOnly(deg(math.asin(a)));
      case 'acos':
        if (a < -1 || a > 1) throw const CalcError('acos는 -1~1 값에만 됩니다');
        return CalcValue.decimalOnly(deg(math.acos(a)));
      case 'atan':
        return CalcValue.decimalOnly(deg(math.atan(a)));
      case 'sqrt':
        if (a < 0) throw const CalcError('음수의 제곱근은 없습니다');
        final ex = arg.exact?.exactSqrt();
        return ex != null
            ? CalcValue.fromFraction(ex)
            : CalcValue.decimalOnly(math.sqrt(a));
      case 'ln':
        if (a <= 0) throw const CalcError('ln은 양수에만 됩니다');
        return CalcValue.decimalOnly(math.log(a));
      case 'log':
        if (a <= 0) throw const CalcError('log는 양수에만 됩니다');
        return CalcValue.decimalOnly(math.log(a) / math.ln10);
      case 'abs':
        return arg.exact != null
            ? CalcValue.fromFraction(arg.exact!.abs())
            : CalcValue.decimalOnly(a.abs());
      case 'exp':
        return CalcValue.decimalOnly(math.exp(a));
    }
    throw CalcError('모르는 함수입니다: $name');
  }

  CalcValue _parseNumber() {
    final start = _pos;
    while (_pos < _src.length && (_isDigit(_src[_pos]) || _src[_pos] == '.')) {
      _pos++;
    }
    // 지수 표기(예: 1.2e-9). 숫자가 안 이어지면 되돌린다.
    if (_pos < _src.length && (_src[_pos] == 'e' || _src[_pos] == 'E')) {
      final save = _pos;
      _pos++;
      if (_pos < _src.length && (_src[_pos] == '+' || _src[_pos] == '-')) {
        _pos++;
      }
      if (_pos < _src.length && _isDigit(_src[_pos])) {
        while (_pos < _src.length && _isDigit(_src[_pos])) {
          _pos++;
        }
      } else {
        _pos = save;
      }
    }
    final s = _src.substring(start, _pos);
    final v = double.tryParse(s);
    if (v == null) throw CalcError('숫자를 읽을 수 없습니다: $s');
    // 지수 표기가 있으면 정확한 분수로 바꾸기 번거로워 소수로만(드문 경우라 괜찮다).
    if (s.contains('e') || s.contains('E')) return CalcValue.decimalOnly(v);
    return CalcValue.fromFraction(Fraction.fromDecimalString(s));
  }

  String _parseIdent() {
    final start = _pos;
    while (_pos < _src.length && _isAlpha(_src[_pos])) {
      _pos++;
    }
    return _src.substring(start, _pos);
  }
}

/// 계산 결과를 소수 글과(원하면) 인치 분수 근사 글로.
/// [asFeetInch]면 12를 넘을 때 피트도 같이 보여준다(예: 1' 3-1/2").
({String decimal, String? fraction}) formatCalcResult(
  double v, {
  bool showFraction = false,
  int denom = 16,
  bool asFeetInch = false,
}) {
  if (v.isNaN || v.isInfinite) return (decimal: '오류', fraction: null);
  final dec = formatNumber(v);
  if (!showFraction) return (decimal: dec, fraction: null);
  final frac = asFeetInch
      ? feetInches(v, denom: denom)
      : inchFraction(v, denom: denom).text;
  return (decimal: dec, fraction: frac);
}
