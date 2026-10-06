// 계산 결과 상자 안의 "풀이" 카드: 식은 크게(나눗셈은 분수 모양으로), 숫자 대입은 그 아래, 결과는 굵게.
// 계산 화면이 결과 줄에 "A = B × C = 1 × 2 = 2 kW"처럼 한 줄로 쓴 풀이를 splitFormulaLines가 식·대입·결과로 나눈다.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/field_view.dart';

/// 풀이 한 단계. 식 → 숫자 대입 → 결과를 따로 보여 준다.
/// [formula]가 없으면 [text] 한 줄만 보인다(한도 판정처럼 식 모양이 아닌 설명).
class FormulaRow {
  const FormulaRow({
    this.label,
    this.formula,
    this.sub,
    this.result,
    this.text,
    this.note,
  });

  /// "정격전류"처럼 이 단계가 무엇인지.
  final String? label;

  /// "I = P ÷ (√3 × V × 역률 × 효율)".
  final String? formula;

  /// 식에 숫자를 넣은 모양("11 × 1000 ÷ (√3 × 380 × 0.85 × 0.9)").
  final String? sub;

  /// "21.8 A".
  final String? result;

  /// 식 모양이 아닌 한 줄 설명.
  final String? text;

  /// 결과 옆에 붙는 짧은 덧말("50A 이하라 1.25배").
  final String? note;
}

/// [splitFormulaLines]의 결과: 카드로 간 줄과 결과 상자에 그대로 남는 줄.
class FormulaSplit {
  const FormulaSplit(this.rows, this.rest);
  final List<FormulaRow> rows;
  final List<String> rest;
}

/// 결과 상자 키별 기호 뜻. 풀이 카드 맨 아래에 붙는다(식에 나온 기호를 모르는 사람을 위해).
const Map<String, List<String>> kSymbolLegend = {
  'ec_ohm_result': ['V 전압(V)  ·  I 전류(A)  ·  R 저항(Ω)  ·  P 전력(W)'],
  'ec_ac_result': [
    'S 피상전력  ·  P 유효전력  ·  Q 무효전력  ·  cosφ 역률  ·  V 전압  ·  I 전류',
  ],
  'ec_yd_result': ['V선·I선 선간 전압·선전류  ·  V상·I상 상 전압·상전류'],
  'ec_conv_result': ['S 피상전력(kVA)  ·  P 유효전력(kW)  ·  V 전압(V)  ·  I 전류(A)'],
  'ec_cable_result': [
    'IB 설계전류  ·  In 차단기 정격전류  ·  IZ 전선의 허용전류  ·  ΔU 전압강하',
  ],
  'ec_pf_result': [
    'Qc 콘덴서 용량(kvar)  ·  tanφ 무효분÷유효분  ·  P 유효전력(kW)  ·  C 정전용량  ·  V 선간 전압',
  ],
  'ec_sc_result': [
    'Ik″ 초기 단락전류  ·  c 전압 계수  ·  Un 정격 전압  ·  Z 단락점까지의 임피던스',
  ],
  'ec_sc_min_result': [
    'Ik″ 초기 단락전류(최소는 2상 단락)  ·  c 전압 계수  ·  Z 단락점까지의 임피던스',
  ],
  'ec_sc_cable_result': [
    'S 도체 단면적(mm²)  ·  Ik 단락전류(A)  ·  t 단락 지속시간(초)  ·  k 도체·절연 재질 계수',
  ],
  'ec_hz_result': ['T 주기  ·  f 주파수(Hz)  ·  ω 각주파수(rad/s)'],
  'ec_hz_speed_result': [
    'ns 동기속도(rpm)  ·  n 회전수(rpm)  ·  s 슬립  ·  p 극수  ·  f 주파수(Hz)',
  ],
  'ec_hz_x_result': [
    'XL 유도 리액턴스  ·  XC 용량 리액턴스  ·  f0 공진 주파수  ·  L 인덕턴스  ·  C 정전용량',
  ],
  'ec_rs_result': [
    'R 저항(Ω)  ·  ρ20 20℃ 고유저항  ·  L 길이  ·  A 단면적  ·  α 온도계수  ·  θ 도체 온도',
  ],
  'ec_rs_sp_result': ['R1·R2·R3 각 저항(Ω)'],
  'ec_en_result': ['kWh 전력량  ·  kW 사용 전력'],
  'ec_as_result': ['P 유효전력  ·  S 피상전력  ·  cosφ 역률  ·  V 전압  ·  I 전류'],
  'ec_zi_result': [
    'Z 임피던스(Ω)  ·  R 저항  ·  XL·XC 유도·용량 리액턴스  ·  V 전압  ·  I 전류',
  ],
  'ec_cv_result': [
    'Qn 명판 출력  ·  Vn 명판 정격 전압  ·  V 실제 운전 전압  ·  f 주파수',
  ],
  'els_result': [
    'P 유효전력(kW)  ·  Q 무효전력(kvar)  ·  S 피상전력(kVA)  ·  cosφ 역률  ·  Σ 합',
  ],
  'eg_result': [
    'PG1 정상 운전  ·  PG2 가장 큰 전동기 기동 시 전압강하  ·  PG3 마지막 전동기 기동  ·  Pm 가장 큰 전동기 출력  ·  β 기동 kVA/kW  ·  C 시동방식 계수  ·  X″d 발전기 리액턴스  ·  ΔV 허용 전압강하',
  ],
  'eb_result': [
    'K 용량 환산 시간(제조사 방전 특성표)  ·  A 단계 전류(A)  ·  L 보수율',
  ],
  'gr_result': [
    'S 단면적(mm²)  ·  I 고장전류 실효값(A)  ·  t 차단시간(초)  ·  k 재질 계수  ·  RA 접지저항  ·  IΔn 누전차단기 정격 감도전류',
  ],
  'emp_result': ['FLC 전부하 전류(NEC 표 430.250 값)  ·  FLA 명판 정격전류'],
  'mf_result': [
    'Ns 동기속도  ·  N 회전수(rpm)  ·  f 주파수(Hz)  ·  s 슬립  ·  f2 회전자 전류 주파수  ·  η 효율  ·  T 토크(N·m)  ·  P 극수(속도 식) 또는 출력 kW(토크·전류 식)',
  ],
  'mc_ir_result': [
    'R40 40 ℃로 환산한 절연저항(MΩ)  ·  R 측정한 1분값(MΩ)  ·  T 측정 때 권선 온도(℃)',
  ],
  'mm_result': [
    'T 권선 온도(℃)  ·  ΔT 온도 상승(K)  ·  R1·R2 차가울 때·운전 직후 저항  ·  T1 R1을 잰 때 온도  ·  k 재질 상수(구리 234.5·알루미늄 225)  ·  i 감속비  ·  η 효율  ·  m 질량  ·  v 속도  ·  μ 마찰 계수  ·  θ 경사각',
  ],
  'mc2_result': [
    'Qc 콘덴서 용량(kvar)  ·  Un 정격 전압(kV)  ·  C 정전용량(μF)  ·  f 주파수(Hz)  ·  V·U 전압  ·  P 전동기 출력(kW)  ·  I0 무부하 전류(A)',
  ],
};

/// 기호 뜻 목록에서 지금 풀이에 실제로 나온 기호만 남긴다(한 탭에 계산 항목이 여럿이면 다른 항목 기호가 섞여 보였다).
/// 항목은 "기호 뜻" 꼴이고 "  ·  "로 이어져 있다. "V·U"처럼 기호가 여럿이면 하나라도 나오면 남긴다.
List<String> legendFor(List<String> legend, List<FormulaRow> rows) {
  final text = [
    for (final r in rows) ...[r.formula ?? '', r.sub ?? '', r.text ?? ''],
  ].join('\n');
  bool appears(String sym) {
    if (sym.isEmpty) return false;
    final re = RegExp(
      '(?<![A-Za-z0-9가-힣])${RegExp.escape(sym)}(?![A-Za-z0-9가-힣])',
    );
    return re.hasMatch(text);
  }

  final out = <String>[];
  for (final line in legend) {
    final kept = line.split('  ·  ').where((item) {
      final sym = item.trim().split(' ').first;
      return sym.split('·').any(appears);
    }).toList();
    if (kept.isNotEmpty) out.add(kept.join('  ·  '));
  }
  return out;
}

// ───────────── 줄 나누기 ─────────────

/// 괄호 밖(깊이 0)에서 [sep]로 자른다.
List<String> _splitTop(String s, String sep) {
  final out = <String>[];
  var depth = 0;
  var start = 0;
  var i = 0;
  while (i < s.length) {
    final c = s[i];
    if (c == '(') depth++;
    if (c == ')') depth = depth > 0 ? depth - 1 : 0;
    if (depth == 0 && s.startsWith(sep, i)) {
      out.add(s.substring(start, i));
      i += sep.length;
      start = i;
      continue;
    }
    i++;
  }
  out.add(s.substring(start));
  return out;
}

final RegExp _operator = RegExp(r'[×÷√²Σ]| [+−/] ');

/// 결과 줄 중 "식 = 대입 = 결과" 꼴을 찾아 풀이 행으로 바꾼다. 문장 같은 줄은 그대로 둔다.
FormulaSplit splitFormulaLines(List<String> lines) {
  // 줄마다 (풀이 행들 | 남는 줄)을 순서대로 모은다.
  final parts = <(List<FormulaRow>?, String)>[];
  for (final raw in lines) {
    final l = raw.trim();
    if (l.startsWith('식:') || l.startsWith('식 :')) {
      final body = l.substring(l.indexOf(':') + 1).trim();
      parts.add(([
        for (final piece in _splitTop(body, ', '))
          if (piece.trim().isNotEmpty) FormulaRow(formula: piece.trim()),
      ], raw));
      continue;
    }
    parts.add((_parseLine(l), raw));
  }
  final anyRow = parts.any((p) => p.$1 != null && p.$1!.isNotEmpty);
  final rows = <FormulaRow>[];
  final rest = <String>[];
  for (final (parsed, raw) in parts) {
    if (parsed != null) {
      rows.addAll(parsed);
    } else if (anyRow && _stepMark.hasMatch(raw.trim())) {
      // ① ② ③ 단계 번호가 붙은 줄은 식이 아니어도 카드로 옮겨, 단계가 결과 상자와 카드로 갈라지지 않게 한다.
      rows.add(FormulaRow(text: raw.trim()));
    } else {
      rest.add(raw);
    }
  }
  return FormulaSplit(rows, rest);
}

final RegExp _stepMark = RegExp(r'^[①②③④⑤⑥⑦⑧⑨⑩]');

/// 한 줄을 문장(". " 기준)으로 나눠, 식 꼴인 문장은 식 행으로, 아닌 문장은 설명 행으로 만든다.
/// 식 꼴 문장이 하나도 없으면 null(줄을 결과 상자에 그대로 둔다).
List<FormulaRow>? _parseLine(String l) {
  final sentences = _splitTop(l, '. ')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .map((e) => e.endsWith('.') ? e.substring(0, e.length - 1) : e)
      .toList();
  final rows = <FormulaRow>[];
  var any = false;
  for (final s in sentences) {
    final eq = _parseSentence(s);
    if (eq != null) {
      rows.addAll(eq);
      any = true;
    } else {
      rows.add(FormulaRow(text: s));
    }
  }
  return any ? rows : null;
}

/// 문장 하나. "이름: 식" 꼴이면 이름을 식 행의 이름표로 쓴다.
List<FormulaRow>? _parseSentence(String s) {
  final colon = _splitTop(s, ': ');
  final label = colon.first.trim();
  final labelled =
      colon.length >= 2 && !label.contains('=') && !_operator.hasMatch(label);
  if (!labelled) return _parseOne(s);
  final eq = _parseOne(colon.sublist(1).join(': ').trim());
  if (eq == null) return _parseOne(s);
  final first = eq.first;
  return [
    FormulaRow(
      label: label,
      formula: first.formula,
      sub: first.sub,
      result: first.result,
      text: first.text,
      note: first.note,
    ),
    ...eq.skip(1),
  ];
}

List<FormulaRow>? _parseOne(String l) {
  if (!l.contains(' = ')) return null;
  if (!_operator.hasMatch(l)) return null;
  var pieces = _splitTop(l, ', ');
  if (pieces.length > 1 && !pieces.every((p) => p.contains(' = '))) {
    pieces = [l];
  }
  final rows = <FormulaRow>[];
  for (final p in pieces) {
    final r = _parsePiece(p.trim());
    if (r == null) return null;
    rows.add(r);
  }
  return rows;
}

/// 결과 조각을 (값, 덧말)로 나눈다. 값은 숫자로 시작해 짧은 단위까지, 뒤에 "(…)"나 ", …"가 붙으면 덧말.
/// 숫자로 시작하지 않거나 다른 글이 붙으면 null(결과가 아님).
({String value, String? note})? _resultParts(String last) {
  final m = RegExp(
    r'^([−-]?\d[\d.,]*\s*[^\s=×÷0-9(),]{0,9})(.*)$',
  ).firstMatch(last);
  if (m == null) return null;
  final head = m.group(1)!.trim();
  final rest = m.group(2)!.trim();
  if (rest.isEmpty) return (value: head, note: null);
  if (rest.startsWith('(') || rest.startsWith(',')) {
    final note = rest.startsWith(',') ? rest.substring(1).trim() : rest;
    return (value: head, note: note);
  }
  return null;
}

FormulaRow? _parsePiece(String p) {
  final parts = _splitTop(p, ' = ');
  if (parts.length < 2) return null;
  // 결과 끝의 "입니다" 같은 서술어는 뗀다("25 mm²입니다" → "25 mm²").
  final last = parts.last
      .trim()
      .replaceFirst(RegExp(r'(입니다|합니다|됩니다|습니다)$'), '')
      .trim();
  final res = _resultParts(last);
  if (res == null) {
    // 마지막이 숫자가 아니면 식만 이어진 줄(P = V × I = I² × R)이다.
    return FormulaRow(formula: p);
  }
  if (parts.length == 2) {
    // "A = 12 kW"는 식이 아니다. 앞쪽에 연산이 있어야 식으로 본다.
    if (!_operator.hasMatch(parts.first)) return null;
    return FormulaRow(
      formula: parts.first.trim(),
      result: res.value,
      note: res.note,
    );
  }
  if (parts.length == 3) {
    // 앞이 기호 하나(R)뿐이면 식이 아니라 "R = 0 + 0 + 0"이 식이다.
    if (!_operator.hasMatch(parts[0])) {
      return FormulaRow(
        formula: '${parts[0].trim()} = ${parts[1].trim()}',
        result: res.value,
        note: res.note,
      );
    }
    return FormulaRow(
      formula: parts[0].trim(),
      sub: parts[1].trim(),
      result: res.value,
      note: res.note,
    );
  }
  return FormulaRow(
    formula: '${parts[0].trim()} = ${parts[1].trim()}',
    sub: parts.sublist(2, parts.length - 1).map((e) => e.trim()).join(' = '),
    result: res.value,
    note: res.note,
  );
}

// ───────────── 분수 ─────────────

class _Frac {
  const _Frac(this.prefix, this.num, this.den, this.suffix);
  final String prefix;
  final String num;
  final String den;
  final String suffix;
}

String _stripParens(String s) {
  var t = s.trim();
  while (t.startsWith('(') && t.endsWith(')')) {
    var depth = 0;
    var wraps = true;
    for (var i = 0; i < t.length; i++) {
      if (t[i] == '(') depth++;
      if (t[i] == ')') depth--;
      if (depth == 0 && i < t.length - 1) {
        wraps = false;
        break;
      }
    }
    if (!wraps) break;
    t = t.substring(1, t.length - 1).trim();
  }
  return t;
}

/// 마지막 "= " 오른쪽에서 괄호 밖 "÷"가 하나뿐이면 분수로 나눈다. 아니면 null.
_Frac? _splitFraction(String text) {
  final eq = _splitTop(text, ' = ');
  final head = eq.length > 1 ? '${eq.sublist(0, eq.length - 1).join(' = ')} = ' : '';
  final rhs = eq.last;
  final divs = _splitTop(rhs, ' ÷ ');
  if (divs.length != 2) return null;
  // 분자: ÷ 바로 앞의 항(괄호 밖 + − 뒤부터). 분모: ÷ 바로 뒤 피연산자 하나.
  var left = divs[0];
  var prefix = '';
  for (final op in [' + ', ' − ', ' ± ', ' ≥ ', ' ≤ ', ' < ', ' > ']) {
    final cut = _splitTop(left, op);
    if (cut.length > 1) {
      final tail = cut.last;
      prefix = left.substring(0, left.length - tail.length);
      left = tail;
    }
  }
  final right = divs[1];
  String den;
  var suffix = '';
  final r = right.trimLeft();
  if (r.startsWith('(')) {
    var depth = 0;
    var end = r.length;
    for (var i = 0; i < r.length; i++) {
      if (r[i] == '(') depth++;
      if (r[i] == ')') {
        depth--;
        if (depth == 0) {
          end = i + 1;
          break;
        }
      }
    }
    den = r.substring(0, end);
    suffix = r.substring(end);
  } else {
    final sp = r.indexOf(' ');
    den = sp < 0 ? r : r.substring(0, sp);
    suffix = sp < 0 ? '' : r.substring(sp);
  }
  final n = _stripParens(left);
  final d = _stripParens(den);
  if (n.isEmpty || d.isEmpty || n.length > 36 || d.length > 36) return null;
  // 말(한글)이 낀 식은 분수로 그리면 읽기 어렵다. 기호·숫자만 분수로 그린다.
  if (RegExp(r'[가-힣]').hasMatch(n) || RegExp(r'[가-힣]').hasMatch(d)) {
    return null;
  }
  return _Frac('$head$prefix', n, d, suffix);
}

/// 식·대입 한 줄. 나눗셈이 하나뿐이면 분수 모양으로, 아니면 그냥 글자로 보인다.
class MathText extends StatelessWidget {
  const MathText(this.text, {super.key, required this.style, this.fit = false});

  final String text;
  final TextStyle style;

  /// true면 폭이 모자랄 때 글자를 줄여 한 줄로 둔다.
  final bool fit;

  @override
  Widget build(BuildContext context) {
    final f = text.length > 70 ? null : _splitFraction(text);
    if (f == null) {
      if (!fit || text.length > 40) return Text(text, style: style);
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(text, maxLines: 1, style: style),
      );
    }
    final bar = Container(
      height: 1.6,
      margin: const EdgeInsets.symmetric(vertical: 2),
      color: style.color ?? fc.text,
    );
    final frac = IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(f.num, style: style),
          bar,
          Text(f.den, style: style),
        ],
      ),
    );
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (f.prefix.isNotEmpty) Text(f.prefix, style: style),
        frac,
        if (f.suffix.trim().isNotEmpty) Text(f.suffix, style: style),
      ],
    );
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: row,
    );
  }
}

// ───────────── 카드 ─────────────

/// 결과 상자 안에 들어가는 "풀이" 카드.
/// [symbols]는 식에 나온 기호의 뜻("I 전류 (A)")이다.
class ElecFormulaCard extends StatefulWidget {
  const ElecFormulaCard({
    super.key,
    required this.rows,
    this.symbols = const [],
  });

  final List<FormulaRow> rows;
  final List<String> symbols;

  /// 이 단계 수를 넘는 긴 풀이는 처음엔 앞 두 단계만 보이고 "나머지 보기"로 펼친다.
  static const int collapseOver = 5;
  static const int collapsedShow = 2;

  /// 긴 풀이를 펼쳐 둘지. 한 번 펼치면 다음에도 펼친 채 둔다(폰에 저장).
  static final ValueNotifier<bool> openAll = ValueNotifier<bool>(false);
  static bool _loaded = false;
  static const String _prefKey = 'formula_card_open_v1';

  static Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final p = await SharedPreferences.getInstance();
      if (p.getBool(_prefKey) == true) openAll.value = true;
    } catch (_) {}
  }

  /// 펼침/접힘을 바꾸고 폰에 적는다.
  static Future<void> setOpen(bool v) async {
    openAll.value = v;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_prefKey, v);
    } catch (_) {}
  }

  @override
  State<ElecFormulaCard> createState() => _ElecFormulaCardState();
}

class _ElecFormulaCardState extends State<ElecFormulaCard> {
  @override
  void initState() {
    super.initState();
    ElecFormulaCard._load();
  }

  Widget _toggle(String key, String label, bool open) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton(
      key: Key(key),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: () => ElecFormulaCard.setOpen(open),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: fc.brand,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows;
    final symbols = widget.symbols;
    if (rows.isEmpty) return const SizedBox.shrink();
    return ValueListenableBuilder<bool>(
      valueListenable: ElecFormulaCard.openAll,
      builder: (context, open, _) {
        final long = rows.length > ElecFormulaCard.collapseOver;
        final collapsed = long && !open;
        final shown = collapsed
            ? rows.take(ElecFormulaCard.collapsedShow).toList()
            : rows;
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: fc.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: fc.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '풀이',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: fc.textSub,
                ),
              ),
              for (final r in shown) _row(r),
              if (collapsed)
                _toggle(
                  'formula_card_more',
                  '나머지 ${rows.length - ElecFormulaCard.collapsedShow}단계 보기',
                  true,
                ),
              if (long && open) _toggle('formula_card_less', '접기', false),
              if (symbols.isNotEmpty) ...[
                const SizedBox(height: 8),
                Divider(height: 1, color: fc.line),
                const SizedBox(height: 8),
                for (final s in symbols)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      s,
                      style: TextStyle(
                        fontSize: 12,
                        color: fc.textSub,
                        height: 1.4,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _row(FormulaRow r) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (r.label != null)
            Text(
              r.label!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: fc.textSub,
              ),
            ),
          if (r.text != null)
            Text(
              r.text!,
              style: TextStyle(fontSize: 13, color: fc.text, height: 1.45),
            ),
          if (r.formula != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: MathText(
                r.formula!,
                fit: true,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: fc.text,
                  height: 1.35,
                ),
              ),
            ),
          if (r.sub != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              // 숫자를 넣은 줄은 식보다 작은 한 줄 글자로 둔다(분수로 또 그리면 같은 모양이 두 번 크게 나온다).
              child: Text(
                '= ${r.sub!}',
                style: TextStyle(fontSize: 13, color: fc.text, height: 1.4),
              ),
            ),
          if (r.result != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '= ${r.result!}',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: fc.brand,
                ),
              ),
            ),
          if (r.note != null)
            Text(
              r.note!,
              style: TextStyle(fontSize: 12, color: fc.textSub, height: 1.4),
            ),
        ],
      ),
    );
  }
}
