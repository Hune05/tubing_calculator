// 공학용 계산기 화면. 사칙연산·괄호·거듭제곱·계승·퍼센트·삼각함수 등(eng_calc.dart)을
// 누름판으로 계산한다. 피트·인치 분수는 따로 칸을 두지 않고, "FT" 단추가 "×12+"를
// 넣어 준다(3' 3-1/2" → 3 FT 3 + 3 / 8 로 눌러 36.375가 나온다. 3+3/8=3.375를 12를
// 곱한 자리에 더하는 셈과 같다). 결과 아래에 가장 가까운 인치 분수도 같이 보여 준다.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/field_view.dart';
import 'eng_calc.dart';

Color get _ink => fc.text;
Color get _sub => fc.textSub;
Color get _teal => fc.brand;
Color get _danger => fc.danger;
Color get _orange =>
    fieldPick(const Color(0xFFEA580C), sunlight: fc.caution, night: fc.caution);

const String kEngCalcAngleKey = 'field_eng_calc_angle_v1'; // 'deg' | 'rad'
const String kEngCalcFractionKey = 'field_eng_calc_fraction_v1';
const String kEngCalcFeetKey = 'field_eng_calc_feet_v1';
const String kEngCalcDenomKey = 'field_eng_calc_denom_v1';

const List<int> kEngCalcDenoms = [8, 16, 32, 64];

/// 뒤에 덧셈·뺄셈·곱셈·나눗셈·거듭제곱 기호가 오면 안 되는 자리(닫는 여러 뜻 방지용)는
/// 아니고, 그냥 화면에 보일 연산자 글자.
const _opChars = '+-−×÷^*/';

class EngCalculatorPage extends StatefulWidget {
  const EngCalculatorPage({super.key});

  @override
  State<EngCalculatorPage> createState() => _EngCalculatorPageState();
}

class _EngCalculatorPageState extends State<EngCalculatorPage> {
  String _expr = '';
  double? _live;
  String? _error;
  bool _justEvaluated = false;

  AngleUnit _angle = AngleUnit.degree;
  bool _showFraction = true;
  bool _asFeetInch = true;
  int _denom = 16;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final p = await SharedPreferences.getInstance();
      final angle = p.getString(kEngCalcAngleKey);
      final frac = p.getBool(kEngCalcFractionKey);
      final feet = p.getBool(kEngCalcFeetKey);
      final denom = p.getInt(kEngCalcDenomKey);
      if (!mounted) return;
      setState(() {
        if (angle == 'rad') _angle = AngleUnit.radian;
        if (frac != null) _showFraction = frac;
        if (feet != null) _asFeetInch = feet;
        if (denom != null && kEngCalcDenoms.contains(denom)) _denom = denom;
      });
    } catch (_) {}
  }

  Future<void> _saveSettings() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
        kEngCalcAngleKey,
        _angle == AngleUnit.radian ? 'rad' : 'deg',
      );
      await p.setBool(kEngCalcFractionKey, _showFraction);
      await p.setBool(kEngCalcFeetKey, _asFeetInch);
      await p.setInt(kEngCalcDenomKey, _denom);
    } catch (_) {}
  }

  // ── 입력 ──

  String _stripTrailingOps(String s) {
    var t = s;
    while (t.isNotEmpty &&
        (_opChars.contains(t[t.length - 1]) || t[t.length - 1] == '(')) {
      t = t.substring(0, t.length - 1);
    }
    return t;
  }

  void _recalc() {
    final t = _stripTrailingOps(_expr).trim();
    if (t.isEmpty) {
      _live = null;
      _error = null;
      return;
    }
    try {
      _live = evaluateExpr(t, angle: _angle);
      _error = null;
    } catch (e) {
      _live = null;
      _error = e is CalcError ? e.message : '계산할 수 없습니다';
    }
  }

  bool get _endsWithDigitOrClose {
    if (_expr.isEmpty) return false;
    final c = _expr[_expr.length - 1];
    return RegExp(r'[0-9)π!%]').hasMatch(c);
  }

  void _tapDigit(String d) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_justEvaluated) {
        _expr = '';
        _justEvaluated = false;
      }
      _expr += d;
      _recalc();
    });
  }

  void _tapOp(String opDisplay) {
    HapticFeedback.selectionClick();
    setState(() {
      _justEvaluated = false;
      if (_expr.isEmpty) {
        if (opDisplay == '−') _expr = '-'; // 맨 앞 빼기는 음수 부호로.
        _recalc();
        return;
      }
      // 연산자를 연달아 누르면 마지막 것을 바꾼다(오타 고치기 편하게).
      if (_opChars.contains(_expr[_expr.length - 1])) {
        _expr = _expr.substring(0, _expr.length - 1) + opDisplay;
      } else {
        _expr += opDisplay;
      }
      _recalc();
    });
  }

  void _tapFn(String name) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_justEvaluated) {
        _expr = '';
        _justEvaluated = false;
      }
      if (_endsWithDigitOrClose) _expr += '×';
      _expr += '$name(';
      _recalc();
    });
  }

  void _tapConst(String c) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_justEvaluated) {
        _expr = '';
        _justEvaluated = false;
      }
      if (_endsWithDigitOrClose) _expr += '×';
      _expr += c;
      _recalc();
    });
  }

  void _tapParen(String p) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_justEvaluated) {
        _expr = '';
        _justEvaluated = false;
      }
      if (p == '(' && _endsWithDigitOrClose) _expr += '×';
      _expr += p;
      _recalc();
    });
  }

  void _tapPostfix(String s) {
    HapticFeedback.selectionClick();
    setState(() {
      _justEvaluated = false;
      if (_expr.isEmpty) return;
      _expr += s;
      _recalc();
    });
  }

  /// 피트: 지금까지 친 수(맨 뒤 숫자 토막)를 "×12+"로 바꾼다.
  /// 예: "3" 다음 FT → "3×12+", 이어서 "3+3/8" → 3'-3 3/8"(36.375)와 같은 값.
  void _tapFeet() {
    HapticFeedback.selectionClick();
    setState(() {
      _justEvaluated = false;
      if (_expr.isEmpty || !RegExp(r'[0-9]$').hasMatch(_expr)) return;
      _expr += '×12+';
      _recalc();
    });
  }

  void _tapAC() {
    HapticFeedback.mediumImpact();
    setState(() {
      _expr = '';
      _live = null;
      _error = null;
      _justEvaluated = false;
    });
  }

  void _tapBack() {
    HapticFeedback.selectionClick();
    setState(() {
      _justEvaluated = false;
      if (_expr.isNotEmpty) _expr = _expr.substring(0, _expr.length - 1);
      _recalc();
    });
  }

  void _tapEquals() {
    HapticFeedback.mediumImpact();
    setState(() {
      _recalc();
      if (_live != null) {
        _expr = _fmtDecimal(_live!);
        _justEvaluated = true;
      }
    });
  }

  String _fmtDecimal(double v) => formatCalcResult(v).decimal;

  // ── 화면 ──

  @override
  Widget build(BuildContext context) =>
      FieldViewTheme(child: Builder(builder: _buildPage));

  Widget _buildPage(BuildContext context) {
    final result = _live == null
        ? null
        : formatCalcResult(
            _live!,
            showFraction: _showFraction,
            denom: _denom,
            asFeetInch: _asFeetInch,
          );
    return Scaffold(
      backgroundColor: fc.surface,
      appBar: AppBar(
        backgroundColor: fc.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _ink,
        title: Text(
          "공학용 계산기",
          style: TextStyle(fontWeight: FontWeight.w800, color: _ink),
        ),
        actions: [
          IconButton(
            key: const Key('calc_settings'),
            icon: const Icon(Icons.tune),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _display(result),
            const Divider(height: 1),
            Expanded(child: _keypad()),
          ],
        ),
      ),
    );
  }

  Widget _display(({String decimal, String? fraction})? result) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          _expr.isEmpty ? '0' : _expr,
          key: const Key('calc_expr'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 16,
            color: _sub,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            _error != null
                ? _error!
                : (result?.decimal ?? (_expr.isEmpty ? '0' : '')),
            key: const Key('calc_display_result'),
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: _error != null ? _danger : _ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        if (_error == null && result?.fraction != null) ...[
          const SizedBox(height: 4),
          Text(
            '≈ ${result!.fraction}',
            key: const Key('calc_display_fraction'),
            style: TextStyle(
              fontSize: 18,
              color: _teal,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    ),
  );

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: fc.surface,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "각도 단위",
                  style: TextStyle(fontWeight: FontWeight.w800, color: _ink),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      key: const Key('calc_angle_deg'),
                      label: const Text('도(°)'),
                      selected: _angle == AngleUnit.degree,
                      onSelected: (_) => setState(() {
                        _angle = AngleUnit.degree;
                        setSheet(() {});
                        _recalc();
                        _saveSettings();
                      }),
                    ),
                    ChoiceChip(
                      key: const Key('calc_angle_rad'),
                      label: const Text('라디안'),
                      selected: _angle == AngleUnit.radian,
                      onSelected: (_) => setState(() {
                        _angle = AngleUnit.radian;
                        setSheet(() {});
                        _recalc();
                        _saveSettings();
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SwitchListTile(
                  key: const Key('calc_show_fraction'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('결과 아래에 가까운 인치 분수 보이기'),
                  value: _showFraction,
                  onChanged: (v) => setState(() {
                    _showFraction = v;
                    setSheet(() {});
                    _saveSettings();
                  }),
                ),
                SwitchListTile(
                  key: const Key('calc_show_feet'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('12인치 넘으면 피트로 보이기'),
                  value: _asFeetInch,
                  onChanged: (v) => setState(() {
                    _asFeetInch = v;
                    setSheet(() {});
                    _saveSettings();
                  }),
                ),
                const SizedBox(height: 10),
                Text(
                  "분수 눈금",
                  style: TextStyle(fontWeight: FontWeight.w800, color: _ink),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final d in kEngCalcDenoms)
                      ChoiceChip(
                        key: Key('calc_denom_$d'),
                        label: Text('1/$d"'),
                        selected: _denom == d,
                        onSelected: (_) => setState(() {
                          _denom = d;
                          setSheet(() {});
                          _saveSettings();
                        }),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _keypad() {
    Widget row(List<Widget> keys) => Expanded(
      child: Row(
        children: [
          for (final k in keys)
            Expanded(
              child: Padding(padding: const EdgeInsets.all(3), child: k),
            ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
      child: Column(
        children: [
          row([
            _util('AC', _tapAC, key: 'calc_ac'),
            _util('(', () => _tapParen('('), key: 'calc_lparen'),
            _util(')', () => _tapParen(')'), key: 'calc_rparen'),
            _util(
              '',
              _tapBack,
              key: 'calc_back',
              icon: Icons.backspace_outlined,
            ),
          ]),
          row([
            _fn('sin', key: 'calc_sin'),
            _fn('cos', key: 'calc_cos'),
            _fn('tan', key: 'calc_tan'),
            _fn('√', fnName: 'sqrt', key: 'calc_sqrt'),
          ]),
          row([
            _fn('ln', key: 'calc_ln'),
            _fn('log', key: 'calc_log'),
            _op('^', key: 'calc_pow'),
            _postfix('!', key: 'calc_fact'),
          ]),
          row([
            _digit('7', key: 'calc_7'),
            _digit('8', key: 'calc_8'),
            _digit('9', key: 'calc_9'),
            _op('÷', key: 'calc_div'),
          ]),
          row([
            _digit('4', key: 'calc_4'),
            _digit('5', key: 'calc_5'),
            _digit('6', key: 'calc_6'),
            _op('×', key: 'calc_mul'),
          ]),
          row([
            _digit('1', key: 'calc_1'),
            _digit('2', key: 'calc_2'),
            _digit('3', key: 'calc_3'),
            _op('−', key: 'calc_sub'),
          ]),
          row([
            _const('π', key: 'calc_pi'),
            _digit('0', key: 'calc_0'),
            _digit('.', key: 'calc_dot'),
            _op('+', key: 'calc_add'),
          ]),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: _postfix('%', key: 'calc_pct'),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: _feet(key: 'calc_ft'),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: _equals(key: 'calc_eq'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ButtonStyle _style(Color bg, Color fg) => ElevatedButton.styleFrom(
    backgroundColor: bg,
    foregroundColor: fg,
    elevation: 0,
    padding: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );

  Widget _digit(String d, {required String key}) => ElevatedButton(
    key: Key(key),
    style: _style(fc.background, _ink),
    onPressed: () => _tapDigit(d),
    child: Text(
      d,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
    ),
  );

  Widget _op(String d, {required String key}) => ElevatedButton(
    key: Key(key),
    style: _style(fc.brandSoft, _teal),
    onPressed: () => _tapOp(d),
    child: Text(
      d,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
    ),
  );

  Widget _fn(String label, {String? fnName, required String key}) =>
      ElevatedButton(
        key: Key(key),
        style: _style(fc.background, _sub),
        onPressed: () => _tapFn(fnName ?? label),
        child: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      );

  Widget _const(String c, {required String key}) => ElevatedButton(
    key: Key(key),
    style: _style(fc.background, _sub),
    onPressed: () => _tapConst(c),
    child: Text(
      c,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
    ),
  );

  Widget _postfix(String s, {required String key}) => ElevatedButton(
    key: Key(key),
    style: _style(fc.background, _sub),
    onPressed: () => _tapPostfix(s),
    child: Text(
      s,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
    ),
  );

  Widget _feet({required String key}) => ElevatedButton(
    key: Key(key),
    style: _style(_orange.withValues(alpha: 0.14), _orange),
    onPressed: _tapFeet,
    child: const Text(
      "FT",
      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
    ),
  );

  Widget _util(
    String d,
    VoidCallback onTap, {
    required String key,
    IconData? icon,
  }) => ElevatedButton(
    key: Key(key),
    style: _style(fc.background, _sub),
    onPressed: onTap,
    child: icon != null
        ? Icon(icon, size: 20)
        : Text(
            d,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
  );

  Widget _equals({required String key}) => ElevatedButton(
    key: Key(key),
    style: _style(_teal, fc.onBrand),
    onPressed: _tapEquals,
    child: const Text(
      '=',
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
    ),
  );
}
