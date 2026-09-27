// 공학용 계산기 셈(화면 없음). 문자열 수식(사칙연산·괄호·거듭제곱·공학 함수)을 계산한다.
//
// 인치 분수·피트 입력("1' 3-1/2"" 같은 글)은 이 식에 직접 넣지 않는다. 화면 쪽에서
// parseInches(unit_defs.dart)로 소수(예: 15.5)로 먼저 바꾼 뒤, 그 소수를 이 식의 숫자로
// 쓴다. 3/8처럼 "/"만 있는 것은 나눗셈으로 계산해도 같은 값(0.375)이라 따로 다루지 않는다.
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

/// 수식 글을 계산한다. 각도 함수는 [angle] 단위로 읽고 돌려준다(기본 도).
double evaluateExpr(String expr, {AngleUnit angle = AngleUnit.degree}) {
  final p = _Parser(expr, angle);
  final v = p._parseExpr();
  p._skipWs();
  if (p._pos != p._src.length) {
    throw CalcError('식을 끝까지 읽지 못했습니다("${p._src.substring(p._pos)}" 앞에서 막힘)');
  }
  if (v.isNaN) throw CalcError('계산할 수 없습니다');
  if (v.isInfinite) throw CalcError('결과가 너무 큽니다');
  return v;
}

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
  double _parseExpr() {
    var v = _parseTerm();
    while (true) {
      _skipWs();
      if (_pos < _src.length && (_src[_pos] == '+' || _src[_pos] == '-')) {
        final op = _src[_pos];
        _pos++;
        final rhs = _parseTerm();
        v = op == '+' ? v + rhs : v - rhs;
      } else {
        break;
      }
    }
    return v;
  }

  // term := unary (('×'|'*'|'÷'|'/') unary)*
  double _parseTerm() {
    var v = _parseUnary();
    while (true) {
      _skipWs();
      if (_pos >= _src.length) break;
      final c = _src[_pos];
      if (c == '*' || c == '×') {
        _pos++;
        v *= _parseUnary();
      } else if (c == '/' || c == '÷') {
        _pos++;
        final rhs = _parseUnary();
        if (rhs == 0) throw const CalcError('0으로 나눌 수 없습니다');
        v /= rhs;
      } else {
        break;
      }
    }
    return v;
  }

  // unary := ('-'|'+') unary | power
  double _parseUnary() {
    _skipWs();
    if (_pos < _src.length && _src[_pos] == '-') {
      _pos++;
      return -_parseUnary();
    }
    if (_pos < _src.length && _src[_pos] == '+') {
      _pos++;
      return _parseUnary();
    }
    return _parsePower();
  }

  // power := factor ('^' unary)?   (오른쪽 결합: 2^3^2 = 2^(3^2))
  double _parsePower() {
    final v = _parseFactor();
    _skipWs();
    if (_pos < _src.length && _src[_pos] == '^') {
      _pos++;
      final rhs = _parseUnary();
      final r = math.pow(v, rhs).toDouble();
      return _maybeFactorial(_maybePercent(r));
    }
    return v;
  }

  double _parseFactor() {
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
      return _maybeFactorial(_maybePercent(math.pi));
    }
    if (_isAlpha(c)) {
      final name = _parseIdent();
      if (name == 'pi') return _maybeFactorial(_maybePercent(math.pi));
      if (name == 'e') return _maybeFactorial(_maybePercent(math.e));
      if (kCalcFunctions.contains(name)) {
        _skipWs();
        double arg;
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

  /// 뒤에 오는 "!"(계승)를 적용한다. 0 이상 정수에만 된다.
  double _maybeFactorial(double v) {
    _skipWs();
    if (_pos < _src.length && _src[_pos] == '!') {
      _pos++;
      if (v < 0 || v != v.roundToDouble() || v > 170) {
        throw const CalcError('!(계승)은 0~170의 정수에만 됩니다');
      }
      double r = 1;
      for (int i = 2; i <= v.round(); i++) {
        r *= i;
      }
      return _maybePercent(r);
    }
    return v;
  }

  /// 뒤에 오는 "%"를 적용한다(÷100). 계승보다 먼저 붙을 수도 있어 factorial 쪽에서도 부른다.
  double _maybePercent(double v) {
    _skipWs();
    if (_pos < _src.length && _src[_pos] == '%') {
      _pos++;
      return v / 100;
    }
    return v;
  }

  double _applyFn(String name, double arg) {
    double rad(double d) => angle == AngleUnit.degree ? d * math.pi / 180 : d;
    double deg(double r) => angle == AngleUnit.degree ? r * 180 / math.pi : r;
    switch (name) {
      case 'sin':
        return math.sin(rad(arg));
      case 'cos':
        return math.cos(rad(arg));
      case 'tan':
        return math.tan(rad(arg));
      case 'asin':
        if (arg < -1 || arg > 1) throw const CalcError('asin은 -1~1 값에만 됩니다');
        return deg(math.asin(arg));
      case 'acos':
        if (arg < -1 || arg > 1) throw const CalcError('acos는 -1~1 값에만 됩니다');
        return deg(math.acos(arg));
      case 'atan':
        return deg(math.atan(arg));
      case 'sqrt':
        if (arg < 0) throw const CalcError('음수의 제곱근은 없습니다');
        return math.sqrt(arg);
      case 'ln':
        if (arg <= 0) throw const CalcError('ln은 양수에만 됩니다');
        return math.log(arg);
      case 'log':
        if (arg <= 0) throw const CalcError('log는 양수에만 됩니다');
        return math.log(arg) / math.ln10;
      case 'abs':
        return arg.abs();
      case 'exp':
        return math.exp(arg);
    }
    throw CalcError('모르는 함수입니다: $name');
  }

  double _parseNumber() {
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
    return v;
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
