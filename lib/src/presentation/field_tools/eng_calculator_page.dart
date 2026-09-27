// 공학용 계산기 화면. 사칙연산·괄호·거듭제곱·퍼센트·삼각함수 등(eng_calc.dart)을 누름판으로
// 계산한다.
//
// 분수: "a/b" 단추를 누르면 분수 모양(분자 위·분모 아래)이 생긴다. 분자·분모를 각각
// 눌러 그 칸을 고쳐 쓸 수 있다. 다른 단추(연산자·=·괄호 등)를 누르면 그 분수를 식에
// 끼워 넣고 이어서 계산한다. 계산 결과가 사칙연산·정수 거듭제곱만 거쳤으면 "S⇔D"로
// 소수↔정확한 분수를 바꿔 볼 수 있다(무리수 함수를 거치면 분수가 없어 소수만 나온다).
//
// 피트·인치: 따로 칸을 두지 않고 "FT" 단추가 지금까지 친 수를 "×12+"로 바꿔 준다
// (3' 3-1/2" → 3 FT 3 + 1/2 로 눌러 39.5가 나온다). 결과 아래에 가장 가까운 인치
// 분수(예: ≈ 3' 3-1/2")도 같이 보여 준다(설정에서 켜고 끈다).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/field_view.dart';
import 'eng_calc.dart';
import 'formula_calc_page.dart';

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

/// 화면에 보일 연산자 글자(뒤에 또 연산자가 오면 안 되는 자리를 가린다).
const _opChars = '+-−×÷^*/';

enum _FracField { whole, num, den }

/// 지금 치고 있는 분수(자연수 부분은 선택). 다른 단추를 누르면 [_commitFraction]이
/// 이 값을 식 글자로 바꿔 [_expr]에 붙인다.
class _FracEntry {
  String whole = '';
  String num = '';
  String den = '';
  _FracField active = _FracField.num;
}

class EngCalculatorPage extends StatefulWidget {
  const EngCalculatorPage({super.key});

  @override
  State<EngCalculatorPage> createState() => _EngCalculatorPageState();
}

class _EngCalculatorPageState extends State<EngCalculatorPage> {
  String _expr = '';
  CalcValue? _live;
  String? _error;
  bool _justEvaluated = false;
  _FracEntry? _frac;

  /// "="를 누를 때마다 그 식과 결과를 한 줄로 쌓아 둔다("2+3 = 5"). 새 줄이 늘 때마다
  /// 지난 줄들이 위로 밀려 올라가 보이게(스크롤을 맨 아래로 붙인다).
  final List<String> _history = [];
  final ScrollController _historyScroll = ScrollController();

  /// 결과를 소수 대신 정확한 분수로 보일지(S⇔D). 분수가 없으면(무리수 등) 소수로 보인다.
  bool _showExact = false;

  AngleUnit _angle = AngleUnit.degree;
  bool _showFraction = true;
  bool _asFeetInch = true;
  int _denom = 16;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _historyScroll.dispose();
    super.dispose();
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
      _live = evaluateExprValue(t, angle: _angle);
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

  /// 지금 치는 중인 분수를 "(whole+num/den)" 글자로 바꿔 [_expr]에 붙이고 지운다.
  /// 분모가 비었거나 0이면 분수 없이 그냥 (whole+num)으로 붙인다(계산이 막히지 않게).
  void _commitFraction() {
    final f = _frac;
    if (f == null) return;
    final whole = f.whole.isEmpty ? null : f.whole;
    final num = f.num.isEmpty ? '0' : f.num;
    final den = f.den.isEmpty || f.den == '0' ? null : f.den;
    final body = den == null
        ? (whole == null ? num : '($whole+$num)')
        : (whole == null ? '($num/$den)' : '($whole+$num/$den)');
    if (_endsWithDigitOrClose) _expr += '×';
    _expr += body;
    _frac = null;
  }

  void _tapFracKey() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_frac != null) {
        _commitFraction(); // 이미 치던 분수가 있으면 마무리하고 새로 시작.
      }
      if (_justEvaluated) {
        _expr = '';
        _justEvaluated = false;
      }
      // 방금 친 숫자 토막이 있으면 그걸 자연수 부분으로 가져온다(예: "3" 다음 a/b → 3 _/_).
      final m = RegExp(r'(\d+(?:\.\d+)?)$').firstMatch(_expr);
      String whole = '';
      if (m != null) {
        whole = m.group(1)!;
        _expr = _expr.substring(0, _expr.length - whole.length);
      }
      _frac = _FracEntry()
        ..whole = whole
        ..active = _FracField.num;
      _recalcWithFrac();
    });
  }

  /// 분수를 치는 중에도 결과를 미리 보여준다(분모가 아직 비었으면 분모=1로 어림).
  void _recalcWithFrac() {
    final f = _frac;
    if (f == null) {
      _recalc();
      return;
    }
    final whole = f.whole.isEmpty ? '0' : f.whole;
    final num = f.num.isEmpty ? '0' : f.num;
    final den = f.den.isEmpty ? '1' : f.den;
    final saved = _expr;
    _expr = '$saved+($whole+$num/$den)';
    _recalc();
    _expr = saved;
  }

  void _tapFracDigit(String d) {
    HapticFeedback.selectionClick();
    setState(() {
      final f = _frac!;
      switch (f.active) {
        case _FracField.whole:
          f.whole += d;
        case _FracField.num:
          f.num += d;
        case _FracField.den:
          f.den += d;
      }
      _recalcWithFrac();
    });
  }

  void _tapFracField(_FracField field) {
    HapticFeedback.selectionClick();
    setState(() => _frac!.active = field);
  }

  void _tapDigit(String d) {
    HapticFeedback.selectionClick();
    if (_frac != null) {
      _tapFracDigit(d);
      return;
    }
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
      _commitFraction();
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
      _commitFraction();
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
      _commitFraction();
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
      _commitFraction();
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
      _commitFraction();
      _justEvaluated = false;
      if (_expr.isEmpty) return;
      _expr += s;
      _recalc();
    });
  }

  /// 피트: 지금까지 친 수(맨 뒤 숫자 토막)를 "×12+"로 바꾼다.
  /// 예: "3" 다음 FT → "3×12+", 이어서 "3+1/2" → 3'-3 1/2"(39.5)와 같은 값.
  void _tapFeet() {
    HapticFeedback.selectionClick();
    setState(() {
      _commitFraction();
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
      _frac = null;
      _showExact = false;
    });
  }

  void _tapBack() {
    HapticFeedback.selectionClick();
    setState(() {
      _justEvaluated = false;
      final f = _frac;
      if (f != null) {
        switch (f.active) {
          case _FracField.whole:
            if (f.whole.isNotEmpty) {
              f.whole = f.whole.substring(0, f.whole.length - 1);
            }
          case _FracField.num:
            if (f.num.isNotEmpty) f.num = f.num.substring(0, f.num.length - 1);
          case _FracField.den:
            if (f.den.isNotEmpty) f.den = f.den.substring(0, f.den.length - 1);
        }
        _recalcWithFrac();
        return;
      }
      if (_expr.isNotEmpty) _expr = _expr.substring(0, _expr.length - 1);
      _recalc();
    });
  }

  void _tapEquals() {
    HapticFeedback.mediumImpact();
    setState(() {
      _commitFraction();
      final exprBefore = _expr;
      _recalc();
      if (_live != null) {
        final resultText = _showExact && _live!.exact != null
            ? _live!.exact!.toDisplayString()
            : _fmtDecimal(_live!.decimal);
        // "="를 다시 눌러도 식이 그대로면(예: 이미 계산된 값에 또 =) 기록에 안 쌓는다.
        if (exprBefore != resultText) {
          _history.add('$exprBefore = $resultText');
          if (_history.length > 50) _history.removeAt(0);
        }
        _expr = resultText;
        _justEvaluated = true;
      }
    });
    _scrollHistoryToEnd();
  }

  void _scrollHistoryToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_historyScroll.hasClients) return;
      _historyScroll.jumpTo(_historyScroll.position.maxScrollExtent);
    });
  }

  void _tapSD() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_live?.exact == null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('정확한 분수가 없습니다(무리수 등을 거쳤습니다).')),
          );
        return;
      }
      _showExact = !_showExact;
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
            _live!.decimal,
            showFraction: _showFraction,
            denom: _denom,
            asFeetInch: _asFeetInch,
          );
    final big = _error != null
        ? _error!
        : _live == null
        ? (_expr.isEmpty && _frac == null ? '0' : '')
        : (_showExact && _live!.exact != null
              ? _live!.exact!.toDisplayString(mixed: true)
              : result!.decimal);
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
            key: const Key('calc_formulas'),
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: '공식으로 계산',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FormulaCalcPage()),
            ),
          ),
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
            // 계산 값 창을 화면 높이에 맞춰 키운다(태블릿처럼 위아래로 긴 화면일수록
            // 결과가 커 보이게). 키패드는 상대적으로 덜 키운다.
            Expanded(flex: 4, child: _display(big, result)),
            const Divider(height: 1),
            Expanded(flex: 5, child: _keypad()),
          ],
        ),
      ),
    );
  }

  Widget _display(String big, ({String decimal, String? fraction})? result) {
    final showHistory = _history.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 지난 계산 기록: "="를 누를 때마다 한 줄씩 쌓이고, 새 줄이 생기면 위쪽
          // 줄들이 위로 밀려 올라간다(맨 아래에 최근 줄이 남게 스크롤한다). 기록이
          // 없으면(아직 한 번도 "="를 안 눌렀으면) 이 자리를 안 만들어, 지금 계산
          // 중인 식·결과가 전처럼 자리를 다 쓴다.
          if (showHistory) Expanded(flex: 3, child: _historyList()),
          Expanded(
            flex: showHistory ? 6 : 9,
            child: _currentEntry(big, result),
          ),
        ],
      ),
    );
  }

  Widget _historyList() => ListView.builder(
    key: const Key('calc_history'),
    controller: _historyScroll,
    padding: EdgeInsets.zero,
    itemCount: _history.length,
    itemBuilder: (context, i) => Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        _history[i],
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: 15,
          color: _sub,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );

  Widget _currentEntry(
    String big,
    ({String decimal, String? fraction})? result,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              _expr.isEmpty && _frac == null ? '0' : _expr,
              key: const Key('calc_expr'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 20,
                color: _sub,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (_frac != null) _fracTile(_frac!),
        ],
      ),
      const SizedBox(height: 6),
      // 결과 줄이 남는 세로 공간을 다 차지하게 한다 — 태블릿처럼 위아래로 긴
      // 화면일수록 숫자가 그만큼 커 보인다(스마트폰은 자리가 적어 그만큼 작게).
      Expanded(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (_live?.exact != null)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  key: const Key('calc_sd'),
                  onTap: _tapSD,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: fc.brandSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'S⇔D',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _teal,
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => Align(
                  alignment: Alignment.centerRight,
                  // 남는 세로 자리만큼 키우되, 120을 넘지는 않는다(태블릿에서도
                  // 숫자가 과하게 커지지 않게).
                  child: SizedBox(
                    height: box.maxHeight.clamp(0, 120),
                    child: FittedBox(
                      fit: BoxFit.contain,
                      alignment: Alignment.centerRight,
                      child: Text(
                        big,
                        key: const Key('calc_display_result'),
                        style: TextStyle(
                          fontSize: 68,
                          fontWeight: FontWeight.w900,
                          color: _error != null ? _danger : _ink,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      if (_error == null && !_showExact && result?.fraction != null) ...[
        const SizedBox(height: 4),
        Text(
          '≈ ${result!.fraction}',
          key: const Key('calc_display_fraction'),
          style: TextStyle(
            fontSize: 22,
            color: _teal,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ],
  );

  /// 지금 치는 중인 분수 모양(자연수 [whole 있으면] + 분자/분모). 각 칸을 누르면 그 칸이
  /// 활성이 되어 이어서 치는 숫자가 그 칸에 들어간다(활성 칸은 테두리로 표시).
  Widget _fracTile(_FracEntry f) {
    Widget cell(String text, _FracField field, {double minWidth = 18}) {
      final active = f.active == field;
      return GestureDetector(
        key: Key('calc_frac_${field.name}'),
        onTap: () => _tapFracField(field),
        child: Container(
          constraints: BoxConstraints(minWidth: minWidth),
          margin: const EdgeInsets.symmetric(horizontal: 1),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            border: Border.all(
              color: active ? _teal : Colors.transparent,
              width: 1.4,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            text.isEmpty ? ' ' : text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              color: _ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (f.whole.isNotEmpty || f.active == _FracField.whole)
            cell(f.whole, _FracField.whole),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              cell(f.num, _FracField.num),
              Container(height: 1.4, width: 20, color: _ink),
              cell(f.den, _FracField.den),
            ],
          ),
        ],
      ),
    );
  }

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
            _util('S⇔D', _tapSD, key: 'calc_sd_key'),
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
                    child: _fracKey(key: 'calc_frac_key'),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: _feet(key: 'calc_ft'),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: _postfix('%', key: 'calc_pct'),
                  ),
                ),
                Expanded(
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

  Widget _fracKey({required String key}) => ElevatedButton(
    key: Key(key),
    style: _style(fc.brandSoft, _teal),
    onPressed: _tapFracKey,
    child: const Text(
      'a/b',
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
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
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
