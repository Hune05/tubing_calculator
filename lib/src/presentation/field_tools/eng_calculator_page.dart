// 공학용 계산기 화면. 사칙연산·괄호·거듭제곱·퍼센트·삼각함수 등(eng_calc.dart)을 누름판으로
// 계산한다.
//
// 분수: "a/b" 단추를 누르면 분수 모양(분자 위·분모 아래)이 생긴다. 분자·분모를 각각
// 눌러 그 칸을 고쳐 쓸 수 있다. 다른 단추(연산자·=·괄호 등)를 누르면 그 분수를 식에
// 끼워 넣고 이어서 계산한다. 계산 결과가 사칙연산·정수 거듭제곱만 거쳤으면 "S⇔D"로
// 소수↔정확한 분수를 바꿔 볼 수 있다(무리수 함수를 거치면 분수가 없어 소수만 나온다).
//
// 피트·인치: 따로 칸을 두지 않고 "FT" 단추가 지금까지 친 수를 "(N×12+"로 바꿔 준다(다음 연산자·=에서 닫힘)
// (3' 3-1/2" → 3 FT 3 + 1/2 로 눌러 39.5가 나온다). 결과 아래에 가장 가까운 인치
// 분수(예: ≈ 3' 3-1/2")도 같이 보여 준다(설정에서 켜고 끈다).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/field_view.dart';
import 'eng_calc.dart';
import 'eng_tools_page.dart';
import 'formula_calc_page.dart';
import 'mini_unit_converter_page.dart';

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
const String kEngCalcAdvancedKey = 'field_eng_calc_advanced_v1';
const String kEngCalcHistoryKey = 'field_eng_calc_history_v1';

const List<int> kEngCalcDenoms = [8, 16, 32, 64];

/// 자판(숫자판) 칸의 최대 높이(dp). 폰에서는 원래도 이 값 아래라 그대로고,
/// 태블릿처럼 세로로 긴 화면에서만 이 값에서 잘려 단추가 풍선처럼 안 커진다.
const double _kKeypadMaxHeight = 560;

/// 계산기 화면 전체(표시 칸+자판)의 최대 폭(dp). 큰 화면에서 단추 사이
/// 간격이 휑하게 벌어지지 않도록 폰 계산기 정도 폭으로 못박는다.
const double _kCalcMaxWidth = 480;

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

  /// 직전 계산 결과(식 안에서 "Ans"로 쓴다). 앱을 다시 열면 비어 있다.
  CalcValue? _lastAnswer;
  // = 뒤 식 칸에 남긴 결과 글자. 식이 이 글자로 시작하면 계산은 반올림 안 된 [_lastAnswer]로 한다
  // (10-07: 1÷3= 다음 ×3= 이 0.9999999, √2= 다음 ^2= 가 2.000001로 나왔다).
  String? _ansText;

  /// 결과를 소수 대신 정확한 분수로 보일지(S⇔D). 분수가 없으면(무리수 등) 소수로 보인다.
  bool _showExact = false;

  AngleUnit _angle = AngleUnit.degree;
  bool _showFraction = true;
  bool _asFeetInch = true;
  int _denom = 16;

  /// 갤럭시 계산기처럼: 켜면(공학 모드) 삼각함수·로그·거듭제곱 줄이 보이고,
  /// 끄면(기본 모드) 그 줄들이 없어지는 대신 남은 단추가 커진다.
  bool _advanced = true;

  /// 설정을 읽은 뒤부터만 기본↔공학 전환에 애니메이션을 준다(처음 열 때 저장된
  /// 모드로 바뀌는 것까지 움직이면 어색하다).
  bool _animateMode = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadMemory();
    // 앱 전체는 세로로 잠겨 있지만(AndroidManifest), 이 화면은 가로도 허용한다
    // (강제로 돌리지는 않는다 — 협대 화면이 돼도 원형 단추·Expanded 배치가
    // 알아서 줄어들게 되어 있다).
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]).catchError((_) {});
  }

  @override
  void dispose() {
    _historyScroll.dispose();
    SystemChrome.setPreferredOrientations(const []).catchError((_) {});
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final p = await SharedPreferences.getInstance();
      final angle = p.getString(kEngCalcAngleKey);
      final frac = p.getBool(kEngCalcFractionKey);
      final feet = p.getBool(kEngCalcFeetKey);
      final denom = p.getInt(kEngCalcDenomKey);
      final advanced = p.getBool(kEngCalcAdvancedKey);
      final saved = p.getStringList(kEngCalcHistoryKey);
      if (!mounted) return;
      setState(() {
        // 지난 계산 기록(앱을 껐다 켜도 남는다). 지금 막 쌓인 줄이 있으면 그 앞에 붙인다.
        if (saved != null && saved.isNotEmpty) {
          _history.insertAll(0, saved);
          if (_history.length > 50) {
            _history.removeRange(0, _history.length - 50);
          }
          // 앱을 다시 열어도 직전 결과(Ans)를 쓸 수 있게 기록 마지막 줄 값으로 되살린다.
          _lastAnswer ??= _answerFromHistory();
        }
        if (angle == 'rad') _angle = AngleUnit.radian;
        if (frac != null) _showFraction = frac;
        if (feet != null) _asFeetInch = feet;
        if (denom != null && kEngCalcDenoms.contains(denom)) _denom = denom;
        if (advanced != null) _advanced = advanced;
      });
    } catch (_) {}
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _animateMode = true);
    });
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
      await p.setBool(kEngCalcAdvancedKey, _advanced);
    } catch (_) {}
  }

  /// 기록 맨 아래 줄의 결과("2+3 = 5" → 5)를 "Ans" 값으로. 못 읽으면 null.
  CalcValue? _answerFromHistory() {
    if (_history.isEmpty) return null;
    final line = _history.last;
    final at = line.lastIndexOf(' = ');
    final text = (at < 0 ? line : line.substring(at + 3)).replaceAll('−', '-');
    try {
      return evaluateExprValue(text, angle: _angle);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveHistory() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(kEngCalcHistoryKey, List<String>.of(_history));
    } catch (_) {}
  }

  void _toggleAdvanced() {
    HapticFeedback.selectionClick();
    setState(() => _advanced = !_advanced);
    _saveSettings();
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
    // 🐛 [고침] 빼기 단추는 보기 좋으라고 유니코드 마이너스(−, U+2212)를 쓰는데,
    // 식 계산기(eng_calc.dart)는 자판 하이픈(-)만 뺄셈으로 알아봐서 "5−3"을
    // 끝까지 못 읽고 막혔다(더하기는 둘 다 '+'라 안 걸렸다). 계산기에 넘기기
    // 전에 자판 하이픈으로 바꿔 준다.
    final ansText = _ansText;
    final src =
        ansText != null && _lastAnswer != null && _expr.startsWith(ansText)
        ? 'Ans${_expr.substring(ansText.length)}'
        : _expr;
    final t = _stripTrailingOps(
      closeFeetGroup(src.replaceFirst(RegExp(r'\s*mod\s*$'), '')),
    ).trim().replaceAll('−', '-');
    if (t.isEmpty) {
      _live = null;
      _error = null;
      return;
    }
    try {
      _live = evaluateExprValue(t, angle: _angle, ans: _lastAnswer);
      _error = null;
    } catch (e) {
      _live = null;
      _error = e is CalcError ? e.message : '계산할 수 없습니다';
    }
  }

  bool get _endsWithDigitOrClose {
    if (_expr.isEmpty) return false;
    final c = _expr[_expr.length - 1];
    return RegExp(r'[0-9)π!%se]').hasMatch(c);
  }

  /// 지금 치는 중인 분수를 "(whole+num/den)" 글자로 바꿔 [_expr]에 붙이고 지운다.
  /// 분모가 비었거나 0이면 붙이지 않고 까닭을 띄운 뒤 false(부른 쪽은 하던 일을 멈춘다).
  /// 8차(10-09): 예전에는 분모 없이 (whole+num)으로 붙여 "3 1/□"이 4가 됐고, 분모 0도 말없이 넘어갔다.
  bool _commitFraction() {
    final f = _frac;
    if (f == null) return true;
    if (f.den.isEmpty || RegExp(r'^0*$').hasMatch(f.den)) {
      _live = null;
      _error = f.den.isEmpty ? '분모를 넣으십시오' : '0으로 나눌 수 없습니다';
      f.active = _FracField.den;
      return false;
    }
    final whole = f.whole.isEmpty ? null : f.whole;
    final num = f.num.isEmpty ? '0' : f.num;
    final den = f.den;
    final body = whole == null ? '($num/$den)' : '($whole+$num/$den)';
    if (_endsWithDigitOrClose) _expr += '×';
    _expr += body;
    _frac = null;
    return true;
  }

  void _tapFracKey() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_frac != null) {
        if (!_commitFraction()) return; // 이미 치던 분수가 있으면 마무리하고 새로 시작.
      }
      if (_justEvaluated) {
        _expr = '';
        _justEvaluated = false;
        _ansText = null;
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
    // 확정할 때(_commitFraction)와 같은 식으로 잇는다(10-07: 미리보기는 +, 확정은 ×라
    // '(2+3)' 뒤 1/2이 미리보기 5.5, = 결과 2.5로 달랐다).
    final join = _endsWithDigitOrClose ? '×' : '';
    _expr = '$saved$join($whole+$num/$den)';
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
        _ansText = null;
      }
      // π·e·Ans·)·!·% 뒤의 숫자는 곱하기로 잇는다(10-07: "π2"가 식 오류였다).
      if (_expr.isNotEmpty &&
          RegExp(r'[)πse!%]').hasMatch(_expr[_expr.length - 1])) {
        _expr += '×';
      }
      _expr += d;
      _recalc();
    });
  }

  void _tapOp(String opDisplay) {
    HapticFeedback.selectionClick();
    setState(() {
      _justEvaluated = false;
      if (!_commitFraction()) return;
      if (_expr.isEmpty) {
        if (opDisplay == '−') _expr = '-'; // 맨 앞 빼기는 음수 부호로.
        _recalc();
        return;
      }
      _expr = closeFeetGroup(_expr);
      final last = _expr[_expr.length - 1];
      if (opDisplay == '−' && (last == '×' || last == '÷' || last == '^')) {
        // 곱하기·나누기·거듭제곱 뒤 빼기는 음수 부호다(8차, 10-09: 예전에는 ×를 −로 바꿔 3×−2가 3−2가 됐다).
        _expr += '−';
      } else if (_opChars.contains(last)) {
        // 연산자를 연달아 누르면 마지막 것을 바꾼다(오타 고치기 편하게). "×−"처럼 음수 부호까지 붙어
        // 있으면 둘 다 바꾼다. 맨 앞 음수 부호만 남았으면 그대로 둔다.
        var t = _expr;
        while (t.length > 1 && _opChars.contains(t[t.length - 1])) {
          t = t.substring(0, t.length - 1);
        }
        _expr = _opChars.contains(t) ? t : t + opDisplay;
      } else {
        _expr += opDisplay;
      }
      _recalc();
    });
  }

  void _tapFn(String name) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_commitFraction()) return;
      if (_justEvaluated) {
        _expr = '';
        _justEvaluated = false;
        _ansText = null;
      }
      if (_endsWithDigitOrClose) _expr += '×';
      _expr += '$name(';
      _recalc();
    });
  }

  void _tapConst(String c) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_commitFraction()) return;
      if (_justEvaluated) {
        _expr = '';
        _justEvaluated = false;
        _ansText = null;
      }
      if (_endsWithDigitOrClose) _expr += '×';
      _expr += c;
      _recalc();
    });
  }

  void _tapParen(String p) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_commitFraction()) return;
      if (_justEvaluated) {
        _expr = '';
        _justEvaluated = false;
        _ansText = null;
      }
      if (p == '(' && _endsWithDigitOrClose) _expr += '×';
      _expr += p;
      _recalc();
    });
  }

  void _tapPostfix(String s) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_commitFraction()) return;
      _justEvaluated = false;
      if (_expr.isEmpty) return;
      _expr += s;
      _recalc();
    });
  }

  /// 피트: 지금까지 친 수(맨 뒤 숫자 토막)를 "(N×12+"로 바꾸고, 이어 치는 인치까지 한 묶음으로 둔다.
  /// 다음 연산자나 =를 누르면 묶음을 닫는다. 예: 3 FT 3 → (3×12+3) = 39.
  /// 8차(10-09): 예전에는 "×12+"만 붙여 뒤에 빼기·나누기가 오면 인치만 따로 셈했다
  /// (20′ − 3′6″ → 20×12+0−3×12+6 = 210, 맞는 값 198).
  void _tapFeet() {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_commitFraction()) return;
      _justEvaluated = false;
      final m = RegExp(r'(\d+(?:\.\d+)?)$').firstMatch(_expr);
      if (m == null) return;
      final n = m.group(1)!;
      _expr = '${_expr.substring(0, _expr.length - n.length)}($n×12+';
      _recalc();
    });
  }

  // ── 메모리 칸 A·B·C(10-09) ──
  // 중간 결과를 담아 두었다가 식에 넣는다. 비어 있는 칸을 누르면 지금 값을 넣고, 찬 칸을 누르면
  // 그 값을 식에 넣는다. 길게 누르면 담기·비우기. 폰에 남는다(앱을 껐다 켜도 그대로).
  static const String _kMemKey = 'eng_calc_memory_v1';
  static const List<String> _memNames = ['A', 'B', 'C'];
  final List<double?> _mem = [null, null, null];

  Future<void> _loadMemory() async {
    try {
      final l = (await SharedPreferences.getInstance()).getStringList(_kMemKey);
      if (l == null || !mounted) return;
      setState(() {
        for (var i = 0; i < _mem.length && i < l.length; i++) {
          _mem[i] = double.tryParse(l[i]);
        }
      });
    } catch (_) {}
  }

  void _saveMemory() {
    SharedPreferences.getInstance()
        .then(
          (p) => p.setStringList(_kMemKey, [
            for (final v in _mem) v?.toString() ?? '',
          ]),
        )
        .catchError((_) => false);
  }

  /// 지금 보이는 값(계산 중인 식의 값, 없으면 직전 결과).
  double? get _currentValue => _live?.decimal ?? _lastAnswer?.decimal;

  void _memToast(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(m), duration: const Duration(seconds: 2)),
      );
  }

  void _memStore(int i) {
    final v = _currentValue;
    if (v == null || !v.isFinite) {
      _memToast('담을 값이 없습니다. 먼저 계산하십시오.');
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _mem[i] = v);
    _saveMemory();
    _memToast(
      '${_memNames[i]}에 ${_fmtDecimal(CalcValue.decimalOnly(v))}을 담았습니다.',
    );
  }

  void _tapMemory(int i) {
    final v = _mem[i];
    if (v == null) {
      _memStore(i);
      return;
    }
    _tapConst(memExprText(v));
  }

  Future<void> _memoryMenu(int i) async {
    HapticFeedback.mediumImpact();
    final pick = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: fc.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('calc_mem_store'),
              leading: const Icon(Icons.download_rounded),
              title: Text('지금 값을 ${_memNames[i]}에 담기'),
              onTap: () => Navigator.pop(ctx, 'store'),
            ),
            if (_mem[i] != null)
              ListTile(
                key: const Key('calc_mem_clear'),
                leading: const Icon(Icons.delete_outline_rounded),
                title: Text('${_memNames[i]} 비우기'),
                onTap: () => Navigator.pop(ctx, 'clear'),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (pick == 'store') _memStore(i);
    if (pick == 'clear') {
      setState(() => _mem[i] = null);
      _saveMemory();
    }
  }

  Widget _memoryRow() => Padding(
    key: const Key('calc_memory_row'),
    padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
    child: Row(
      children: [
        for (var i = 0; i < _mem.length; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Material(
                color: _mem[i] == null ? fc.background : fc.brandSoft,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  key: Key('calc_mem_${_memNames[i]}'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _tapMemory(i),
                  onLongPress: () => _memoryMenu(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Text(
                          _memNames[i],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: _teal,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _mem[i] == null
                                ? '담기'
                                : _fmtDecimal(CalcValue.decimalOnly(_mem[i]!)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _mem[i] == null ? _sub : _ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  void _tapAC() {
    HapticFeedback.mediumImpact();
    setState(() {
      _expr = '';
      _live = null;
      _error = null;
      _justEvaluated = false;
      _ansText = null;
      _frac = null;
      _showExact = false;
    });
  }

  void _tapBack() {
    HapticFeedback.selectionClick();
    setState(() {
      _justEvaluated = false;
      _ansText = null; // 결과 글자를 지우기 시작하면 친 글자 그대로 계산한다
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
      if (!_commitFraction()) return;
      _expr = closeFeetGroup(_expr);
      final exprBefore = _expr;
      _recalc();
      if (_live != null) {
        final resultText = _showExact && _live!.exact != null
            ? _live!.exact!.toDisplayString()
            : _fmtDecimal(_live!);
        // "="를 다시 눌러도 식이 그대로면(예: 이미 계산된 값에 또 =) 기록에 안 쌓는다.
        if (exprBefore != resultText) {
          _history.add('$exprBefore = $resultText');
          if (_history.length > 50) _history.removeAt(0);
          _saveHistory();
        }
        _lastAnswer = _live;
        _expr = resultText;
        _ansText = resultText;
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
            const SnackBar(content: Text('분수로 나타낼 수 없는 값입니다(무리수가 들어간 계산).')),
          );
        return;
      }
      _showExact = !_showExact;
    });
  }

  String _fmtDecimal(CalcValue v) =>
      formatCalcResult(v.decimal, exact: v.exact).decimal;

  /// 기록 한 줄을 누르면 그 결과를 지금 식에 넣는다("2+3 = 5" → 5).
  void _tapHistory(int i) {
    final line = _history[i];
    final at = line.lastIndexOf(' = ');
    final value = at < 0 ? line : line.substring(at + 3);
    HapticFeedback.selectionClick();
    setState(() {
      if (!_commitFraction()) return;
      if (_justEvaluated) {
        _expr = '';
        _justEvaluated = false;
        _ansText = null;
      }
      if (_endsWithDigitOrClose) _expr += '×';
      // 분수·음수·지수 표기는 괄호로 감싸 붙인다(10-07: "2÷" 뒤에 1/3을 넣으면 2÷1/3 = 0.667이 나왔다).
      _expr += RegExp(r'^\d+(\.\d+)?$').hasMatch(value) ? value : '($value)';
      _recalc();
    });
  }

  void _clearHistory() {
    HapticFeedback.selectionClick();
    setState(_history.clear);
    _saveHistory();
  }

  /// 지금 큰 글씨로 보이는 결과를 클립보드에 복사한다.
  Future<void> _copyResult() async {
    final live = _live;
    if (_error != null || live == null) return;
    final text = _showExact && live.exact != null
        ? live.exact!.toDisplayString(mixed: true)
        : formatCalcResult(live.decimal, exact: live.exact).decimal;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('복사했습니다: $text'),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  /// 나머지 연산 단추: " mod "를 붙인다.
  void _tapMod() {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_commitFraction()) return;
      _justEvaluated = false;
      if (_expr.isEmpty) return;
      if (_expr.endsWith(' mod ')) return;
      if (_opChars.contains(_expr[_expr.length - 1])) {
        _expr = _expr.substring(0, _expr.length - 1);
      }
      _expr += ' mod ';
      _recalc();
    });
  }

  // ── 화면 ──

  @override
  Widget build(BuildContext context) =>
      FieldViewTheme(child: Builder(builder: _buildPage));

  Widget _buildPage(BuildContext context) {
    final result = _live == null
        ? null
        : formatCalcResult(
            _live!.decimal,
            exact: _live!.exact,
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
          // 아이콘이 네 개라 좁은 폰(약 350dp)에서 제목이 "공학…"로 잘리지 않게 작게 둔다.
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: _ink,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            key: const Key('calc_unit_convert'),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.swap_horiz),
            tooltip: '단위 환산',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MiniUnitConverterPage()),
            ),
          ),
          IconButton(
            key: const Key('calc_tools'),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.architecture),
            tooltip: '현장 도구',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EngToolsPage()),
            ),
          ),
          IconButton(
            key: const Key('calc_formulas'),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: '공식으로 계산',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FormulaCalcPage()),
            ),
          ),
          IconButton(
            key: const Key('calc_settings'),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.tune),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: SafeArea(
        // 2026-09-29: 큰 화면이라고 자판을 옆으로 넓혀 나란히 놓으면 오히려
        // 답답해서(사용자 의견) 그 일체형 자판은 없앴다. 대신 어느 화면이든
        // 폰 계산기 폭(480dp)·자판 높이(560dp)로 못박아 가운데·아래에 두고,
        // 기본↔공학 전환은 부드러운 애니메이션으로만 보완한다.
        child: _isLandscape(context)
            ? _landscapeBody(big, result)
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _kCalcMaxWidth),
                  child: Column(
                    children: [
                      // 계산 값 창을 화면 높이에 맞춰 키운다(태블릿처럼 위아래로 긴 화면일수록
                      // 결과가 커 보이게). 키패드 쪽에 자리를 더 줘서 단추가 갤럭시 계산기처럼
                      // 여유 있게 보이게 한다.
                      Expanded(flex: 3, child: _display(big, result)),
                      // 태블릿처럼 세로로 아주 긴 화면에서 이 칸을 그대로 Expanded로
                      // 두면 단추가 풍선처럼 커져 어색해 보였다(삼성 기본 계산기
                      // 참고: 자판은 늘 화면 아래에 편한 크기로 붙고, 남는 자리는
                      // 위쪽 표시 칸 쪽 빈 공간이 된다). 자판 높이를 폰 화면과
                      // 비슷한 값으로 못박고, 남는 자리는 위 표시 칸 쪽으로 가게
                      // 아래에 붙인다(폰처럼 자판이 이 칸을 넘치지 않을 땐 전과
                      // 똑같다).
                      Expanded(
                        flex: 6,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxHeight: _kKeypadMaxHeight,
                            ),
                            child: Column(
                              children: [
                                const Divider(height: 1),
                                // 가로로 눕혀 키가 낮으면(약 640dp 미만) 자판 자리가 모자라 메모리 줄은 뺀다.
                                if (MediaQuery.sizeOf(context).height >= 640)
                                  _memoryRow(),
                                Expanded(child: _keypad()),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  /// 표시창이 아주 낮아 식 글을 한 줄·작게 쓰는지(그릴 때 정한다).
  bool _compactExpr = false;

  /// 가로로 눕혔는지(폭이 높이보다 크다).
  bool _isLandscape(BuildContext context) {
    final s = MediaQuery.sizeOf(context);
    return s.width > s.height;
  }

  /// 가로 화면(10-09): 위에 표시창, 아래에 8칸 × 5줄 넓은 자판(삼성 계산기 가로처럼).
  /// 세로 자판을 그대로 두면 단추가 줄 높이에 맞춘 원이라 콩알만 해졌다. 가로에서는 공학 단추를
  /// 늘 왼쪽에 보이고(전환 단추 없음), 메모리 A·B·C도 자판 맨 아래 줄에 둔다.
  Widget _landscapeBody(
    String big,
    ({String decimal, String? fraction})? result,
  ) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1100),
      child: LayoutBuilder(
        // 태블릿처럼 높이가 넉넉하면(420 이상) 표시창을 조금 키워 기록 줄도 보이게 한다.
        builder: (context, box) => Column(
          children: [
            Expanded(
              flex: box.maxHeight >= 420 ? 3 : 2,
              child: _display(big, result),
            ),
            const Divider(height: 1),
            Expanded(flex: 7, child: _landscapeKeypad()),
          ],
        ),
      ),
    ),
  );

  Widget _landscapeKeypad() {
    Widget grid(List<List<Widget>> rows) => Column(
      children: [
        for (final r in rows)
          Expanded(
            child: Row(
              children: [
                for (final k in r)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: SizedBox.expand(child: k),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );

    final left = <List<Widget>>[
      [
        _util('AC', _tapAC, key: 'calc_ac'),
        _util('(', () => _tapParen('('), key: 'calc_lparen'),
        _util(')', () => _tapParen(')'), key: 'calc_rparen'),
        _util('', _tapBack, key: 'calc_back', icon: Icons.backspace_outlined),
      ],
      [
        _fn('sin', key: 'calc_sin'),
        _fn('cos', key: 'calc_cos'),
        _fn('tan', key: 'calc_tan'),
        _fn('√', fnName: 'sqrt', key: 'calc_sqrt'),
      ],
      [
        _fn('ln', key: 'calc_ln'),
        _fn('log', key: 'calc_log'),
        _op('^', key: 'calc_pow'),
        _postfix('!', key: 'calc_fact'),
      ],
      [
        _const('e', key: 'calc_e'),
        _modKey(key: 'calc_mod'),
        _const('Ans', key: 'calc_ans', fontSize: 15),
        _util('S⇔D', _tapSD, key: 'calc_sd_key'),
      ],
      [for (var i = 0; i < _mem.length; i++) _memKey(i), const SizedBox()],
    ];
    final right = <List<Widget>>[
      [
        _digit('7', key: 'calc_7'),
        _digit('8', key: 'calc_8'),
        _digit('9', key: 'calc_9'),
        _op('÷', key: 'calc_div'),
      ],
      [
        _digit('4', key: 'calc_4'),
        _digit('5', key: 'calc_5'),
        _digit('6', key: 'calc_6'),
        _op('×', key: 'calc_mul'),
      ],
      [
        _digit('1', key: 'calc_1'),
        _digit('2', key: 'calc_2'),
        _digit('3', key: 'calc_3'),
        _op('−', key: 'calc_sub'),
      ],
      [
        _const('π', key: 'calc_pi'),
        _digit('0', key: 'calc_0'),
        _digit('.', key: 'calc_dot'),
        _op('+', key: 'calc_add'),
      ],
      [
        _fracKey(key: 'calc_frac_key'),
        _feet(key: 'calc_ft'),
        _postfix('%', key: 'calc_pct'),
        _equals(key: 'calc_eq'),
      ],
    ];
    return Padding(
      key: const Key('calc_landscape_keypad'),
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
      child: Row(
        children: [
          Expanded(child: grid(left)),
          const SizedBox(width: 10),
          Expanded(child: grid(right)),
        ],
      ),
    );
  }

  /// 가로 자판 맨 아래 줄의 메모리 단추(세로의 메모리 줄과 같은 일: 누르면 담기·넣기, 길게 누르면 메뉴).
  Widget _memKey(int i) {
    final v = _mem[i];
    return ElevatedButton(
      key: Key('calc_mem_${_memNames[i]}'),
      style: _style(v == null ? fc.background : fc.brandSoft, _teal),
      onPressed: () => _tapMemory(i),
      onLongPress: () => _memoryMenu(i),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            v == null
                ? '${_memNames[i]} 담기'
                : '${_memNames[i]} ${_fmtDecimal(CalcValue.decimalOnly(v))}',
            maxLines: 1,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }

  Widget _display(String big, ({String decimal, String? fraction})? result) =>
      LayoutBuilder(
        // 가로로 눕힌 폰처럼 표시창이 낮으면(110 미만) 여백·식 글을 줄이고, 아주 낮으면(80 미만) 기록 줄도 뺀다.
        builder: (context, box) => _displayBody(
          big,
          result,
          compact: box.maxHeight < 110,
          noHistory: box.maxHeight < 80,
        ),
      );

  Widget _displayBody(
    String big,
    ({String decimal, String? fraction})? result, {
    required bool compact,
    bool noHistory = false,
  }) {
    final showHistory = _history.isNotEmpty && !noHistory;
    _compactExpr = compact;
    return Container(
      width: double.infinity,
      padding: compact
          ? const EdgeInsets.fromLTRB(16, 4, 16, 4)
          : const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 지난 계산 기록: "="를 누를 때마다 한 줄씩 쌓이고, 새 줄이 생기면 위쪽
          // 줄들이 위로 밀려 올라간다(맨 아래에 최근 줄이 남게 스크롤한다). 기록이
          // 없으면(아직 한 번도 "="를 안 눌렀으면) 이 자리를 안 만들어, 지금 계산
          // 중인 식·결과가 전처럼 자리를 다 쓴다.
          if (showHistory)
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  _historyList(),
                  Positioned(
                    left: 0,
                    top: 0,
                    child: GestureDetector(
                      key: const Key('calc_history_clear'),
                      onTap: _clearHistory,
                      child: Text(
                        '기록 지우기',
                        style: TextStyle(
                          fontSize: 12,
                          color: _sub,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
    itemBuilder: (context, i) => GestureDetector(
      key: Key('calc_history_item_$i'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _tapHistory(i),
      child: Padding(
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
    ),
  );

  Widget _currentEntry(
    String big,
    ({String decimal, String? fraction})? result,
  ) => LayoutBuilder(
    builder: (context, box) {
      // 가로 화면처럼 세로 자리가 아주 좁아지면(계산 기록까지 쌓인 랜드스케이프
      // 등) "≈ 분수" 보조 줄을 생략해 넘치지 않게 한다(핵심 식·숫자는 그대로 남는다).
      final tight = box.maxHeight < 130;
      return _currentEntryBody(big, result, tight: tight);
    },
  );

  Widget _currentEntryBody(
    String big,
    ({String decimal, String? fraction})? result, {
    required bool tight,
  }) => Column(
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
              maxLines: _compactExpr ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: _compactExpr ? 15 : 20,
                color: _sub,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (_frac != null) _fracTile(_frac!),
        ],
      ),
      SizedBox(height: tight ? 2 : 6),
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
                  // 남는 세로 자리만큼 키우되, 84를 넘지는 않는다. 아이폰 계산기처럼
                  // 크지만 가는(thin) 굵기라 커도 두껍고 답답해 보이지 않는다.
                  child: SizedBox(
                    height: box.maxHeight.clamp(0, 84),
                    // 복사 아이콘은 숫자 바로 왼쪽에 붙인다(숫자를 길게 눌러도 복사된다).
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (_live != null && _error == null)
                          GestureDetector(
                            key: const Key('calc_copy'),
                            behavior: HitTestBehavior.opaque,
                            onTap: _copyResult,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.copy_outlined,
                                size: 20,
                                color: _sub,
                              ),
                            ),
                          ),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.contain,
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onLongPress: _copyResult,
                              child: Text(
                                big,
                                key: const Key('calc_display_result'),
                                style: TextStyle(
                                  fontSize: 56,
                                  fontWeight: FontWeight.w300,
                                  color: _error != null ? _danger : _ink,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      if (!tight &&
          _error == null &&
          !_showExact &&
          result?.fraction != null) ...[
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

  /// 칸 안에서 정원(perfect circle) 모양이 되게 감싼다(아이폰 계산기 단추처럼) —
  /// 칸의 가로·세로 중 짧은 쪽에 맞춰 정사각형(=원)으로 줄고, 가운데로 온다.
  Widget _circleCell(Widget button) =>
      Center(child: AspectRatio(aspectRatio: 1, child: button));

  /// 자판. 공학(고급) 모드의 삼각함수·로그 두 줄은 전환할 때 뚝 나타났다 사라지는
  /// 대신, 높이·투명도가 0↔1로 부드럽게 변한다(나머지 줄 높이도 같이 서서히
  /// 바뀌어 전체가 끊김 없이 늘었다 줄어든다).
  Widget _keypad() {
    Widget cells(List<Widget> keys) => Row(
      children: [
        for (final k in keys)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: _circleCell(k),
            ),
          ),
      ],
    );

    final basicRows = <List<Widget>>[
      [
        _util('AC', _tapAC, key: 'calc_ac'),
        _util('(', () => _tapParen('('), key: 'calc_lparen'),
        _util(')', () => _tapParen(')'), key: 'calc_rparen'),
        _util('', _tapBack, key: 'calc_back', icon: Icons.backspace_outlined),
      ],
    ];
    // 공학 줄은 두 줄(여섯 칸)이다. 한 줄 더 늘리면 작은 폰에서 단추가 눌리기 힘들 만큼 작아져서
    // 한 줄에 여섯 칸을 둔다(단추는 줄 높이에 맞춘 원이라 칸을 늘려도 크기는 같다).
    final advancedRows = <List<Widget>>[
      [
        _fn('sin', key: 'calc_sin'),
        _fn('cos', key: 'calc_cos'),
        _fn('tan', key: 'calc_tan'),
        _fn('√', fnName: 'sqrt', key: 'calc_sqrt'),
        _postfix('!', key: 'calc_fact'),
        _const('e', key: 'calc_e'),
      ],
      [
        _fn('ln', key: 'calc_ln'),
        _fn('log', key: 'calc_log'),
        _op('^', key: 'calc_pow'),
        _modKey(key: 'calc_mod'),
        _const('Ans', key: 'calc_ans', fontSize: 15),
        _util('S⇔D', _tapSD, key: 'calc_sd_key'),
      ],
    ];
    final lowerRows = <List<Widget>>[
      [
        _digit('7', key: 'calc_7'),
        _digit('8', key: 'calc_8'),
        _digit('9', key: 'calc_9'),
        _op('÷', key: 'calc_div'),
      ],
      [
        _digit('4', key: 'calc_4'),
        _digit('5', key: 'calc_5'),
        _digit('6', key: 'calc_6'),
        _op('×', key: 'calc_mul'),
      ],
      [
        _digit('1', key: 'calc_1'),
        _digit('2', key: 'calc_2'),
        _digit('3', key: 'calc_3'),
        _op('−', key: 'calc_sub'),
      ],
      [
        _const('π', key: 'calc_pi'),
        _digit('0', key: 'calc_0'),
        _digit('.', key: 'calc_dot'),
        _op('+', key: 'calc_add'),
      ],
      [
        _fracKey(key: 'calc_frac_key'),
        _feet(key: 'calc_ft'),
        _postfix('%', key: 'calc_pct'),
        _equals(key: 'calc_eq'),
      ],
    ];
    const basicCount = 6; // AC 줄 + 아래 다섯 줄.

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
      child: Column(
        children: [
          _modeToggle(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) => TweenAnimationBuilder<double>(
                tween: Tween<double>(end: _advanced ? 1.0 : 0.0),
                duration: _animateMode
                    ? const Duration(milliseconds: 260)
                    : Duration.zero,
                curve: Curves.easeInOut,
                builder: (context, t, _) {
                  final rowH = box.maxHeight / (basicCount + 2 * t);
                  Widget sized(List<Widget> keys, {double factor = 1}) =>
                      SizedBox(
                        height: rowH * factor,
                        child: factor == 1
                            ? cells(keys)
                            : ClipRect(
                                child: Opacity(
                                  opacity: t,
                                  child: OverflowBox(
                                    maxHeight: rowH,
                                    alignment: Alignment.topCenter,
                                    child: SizedBox(
                                      height: rowH,
                                      child: cells(keys),
                                    ),
                                  ),
                                ),
                              ),
                      );
                  return Column(
                    children: [
                      for (final r in basicRows) sized(r),
                      if (t > 0)
                        for (final r in advancedRows) sized(r, factor: t),
                      for (final r in lowerRows) sized(r),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 기본↔공학 모드 전환 단추(갤럭시 계산기의 펼치기/접기 화살표와 같은 역할).
  Widget _modeToggle() => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Center(
      child: GestureDetector(
        key: const Key('calc_mode_toggle'),
        onTap: _toggleAdvanced,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: fc.background,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _advanced ? '기본 계산기' : '공학 계산기',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _sub,
                ),
              ),
              const SizedBox(width: 3),
              Icon(
                _advanced ? Icons.expand_less : Icons.expand_more,
                size: 16,
                color: _sub,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  ButtonStyle _style(Color bg, Color fg) => ElevatedButton.styleFrom(
    backgroundColor: bg,
    foregroundColor: fg,
    elevation: 0,
    padding: EdgeInsets.zero,
    // 아이폰 계산기처럼 완전한 원(단추가 정사각형이 되도록 [_circleCell]로 감싸고,
    // 반지름을 아주 크게 줘 항상 짧은 변의 반이 되어 원이 된다).
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(999)),
    ),
  );

  Widget _digit(String d, {required String key}) => ElevatedButton(
    key: Key(key),
    style: _style(fc.background, _ink),
    onPressed: () => _tapDigit(d),
    child: Text(
      d,
      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
    ),
  );

  Widget _op(String d, {required String key}) => ElevatedButton(
    key: Key(key),
    style: _style(fc.brandSoft, _teal),
    onPressed: () => _tapOp(d),
    child: Text(
      d,
      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
    ),
  );

  Widget _fn(String label, {String? fnName, required String key}) =>
      ElevatedButton(
        key: Key(key),
        style: _style(fc.background, _sub),
        onPressed: () => _tapFn(fnName ?? label),
        child: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      );

  Widget _const(String c, {required String key, double fontSize = 21}) =>
      ElevatedButton(
        key: Key(key),
        style: _style(fc.background, _sub),
        onPressed: () => _tapConst(c),
        child: Text(
          c,
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
        ),
      );

  Widget _modKey({required String key}) => ElevatedButton(
    key: Key(key),
    style: _style(fc.brandSoft, _teal),
    onPressed: _tapMod,
    child: const Text(
      'mod',
      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
    ),
  );

  Widget _postfix(String s, {required String key}) => ElevatedButton(
    key: Key(key),
    style: _style(fc.background, _sub),
    onPressed: () => _tapPostfix(s),
    child: Text(
      s,
      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
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
      style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
    ),
  );
}

/// 맨 안쪽의 닫히지 않은 괄호가 피트 묶음 "(N×12+…"이면 닫은 식을 돌려준다(인치를 안 쳤으면 0인치).
/// 묶음이 아니거나 인치를 치는 중(연산자로 끝남)이면 그대로(8차, 10-09).
String closeFeetGroup(String s) {
  final open = <int>[];
  for (var i = 0; i < s.length; i++) {
    if (s[i] == '(') {
      open.add(i);
    } else if (s[i] == ')' && open.isNotEmpty) {
      open.removeLast();
    }
  }
  if (open.isEmpty) return s;
  if (!RegExp(r'^\(\d+(?:\.\d+)?×12\+').hasMatch(s.substring(open.last))) {
    return s;
  }
  if (s.endsWith('+')) return '${s}0)';
  if (RegExp(r'[0-9)]$').hasMatch(s)) return '$s)';
  return s;
}

/// 메모리 칸 값을 식에 넣을 글: 반올림하지 않은 값(소수 10자리까지), 음수는 괄호로 감싼다.
String memExprText(double v) {
  if (v == 0) return '0';
  var t = v.abs() >= 1e-6 && v.abs() < 1e15
      ? v
            .toStringAsFixed(10)
            .replaceFirst(RegExp(r'0+$'), '')
            .replaceFirst(RegExp(r'\.$'), '')
      : v.toString();
  if (t == '-0') t = '0';
  return v < 0 ? '(${t.replaceFirst('-', '−')})' : t;
}
