// 단위 환산 화면(홈 "단위 환산" · 현장 자료 "단위 환산" 탭).
//
// 평 좋은 환산 앱들처럼: 분류를 고르면 그 분류의 모든 단위가 한 목록으로 나오고, 아무 칸에나
// 숫자를 넣으면 나머지가 바로 바뀐다(칸에 "1"을 미리 넣지 않는다). 마지막 분류·값을 기억하고,
// 단위마다 ⋮ 메뉴로 값 복사·맨 위에 두기·숨기기, 위쪽에서 모든 단위를 찾는다. 길이는 인치 분수
// (1/16·1/32·1/64)와 오차, 피트·인치를 같이 보이고, 전선 굵기(SQ↔AWG)·배관 호칭은 표로 둔다.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_icon_set.dart';
import '../../core/theme/field_view.dart';
import '../my_work_logs/models/skid_presets.dart'
    show kThickConduitOd, kThinConduitOd;
import '../reference/page/reference_widgets.dart' show refTable;
import 'unit_defs.dart';

const String kUnitConvCatKey = 'unit_conv_cat_v1';
const String kUnitConvLastKey = 'unit_conv_last_v1'; // {분류: [단위, 글]}
const String kUnitConvFavKey = 'unit_conv_fav_v1'; // ["분류/단위", …] 맨 위에 둔 차례
const String kUnitConvHiddenKey = 'unit_conv_hidden_v1';
const String kUnitConvDenKey = 'unit_conv_frac_den_v1';

class UnitConverterPage extends StatelessWidget {
  /// 처음 열 분류(예: 'pressure'). 없으면 마지막에 본 분류.
  final String? initialCategory;
  const UnitConverterPage({super.key, this.initialCategory});

  @override
  Widget build(BuildContext context) => FieldViewTheme(
    child: Builder(
      builder: (context) => Scaffold(
        backgroundColor: fc.background,
        appBar: AppBar(
          backgroundColor: fc.surface,
          foregroundColor: fc.text,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Text(
            "단위 환산",
            style: TextStyle(fontWeight: FontWeight.w800, color: fc.text),
          ),
        ),
        body: SafeArea(
          child: UnitConverterView(initialCategory: initialCategory),
        ),
      ),
    ),
  );
}

class UnitConverterView extends StatefulWidget {
  /// 현장 자료 탭 안: 그 화면 위에 찾기 칸이 있어 여기 찾기 칸은 뺀다.
  final bool embedded;
  final String? initialCategory;
  const UnitConverterView({
    super.key,
    this.embedded = false,
    this.initialCategory,
  });

  @override
  State<UnitConverterView> createState() => _UnitConverterViewState();
}

class _UnitConverterViewState extends State<UnitConverterView> {
  String _cat = kLength.id;
  final Map<String, ({String unit, String text})> _last = {};
  final List<String> _fav = [];
  final Set<String> _hidden = {};
  int _den = 16;

  final Map<String, TextEditingController> _ctrl = {};
  final Map<String, FocusNode> _focus = {};
  final Map<String, GlobalKey> _rowKey = {};

  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  String _q = '';

  final _awg = TextEditingController();
  final _sq = TextEditingController();

  Timer? _saveTimer;

  UnitCategory get _c => unitCategory(_cat);

  String _k(UnitCategory c, UnitDef u) => '${c.id}/${u.id}';
  TextEditingController _ctrlOf(UnitCategory c, UnitDef u) =>
      _ctrl.putIfAbsent(_k(c, u), TextEditingController.new);
  // 칸을 누르고 떼면 다시 그린다(피트·인치 칸의 ' " 단추가 누를 때만 보인다).
  FocusNode _focusOf(UnitCategory c, UnitDef u) => _focus.putIfAbsent(
    _k(c, u),
    () => FocusNode()..addListener(() => mounted ? setState(() {}) : null),
  );

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) _cat = widget.initialCategory!;
    _load();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _save(); // 닫을 때 남은 것
    for (final c in _ctrl.values) {
      c.dispose();
    }
    for (final f in _focus.values) {
      f.dispose();
    }
    _search.dispose();
    _searchFocus.dispose();
    _awg.dispose();
    _sq.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final cat = p.getString(kUnitConvCatKey);
      final last = p.getString(kUnitConvLastKey);
      final fav = p.getStringList(kUnitConvFavKey);
      final hidden = p.getStringList(kUnitConvHiddenKey);
      final den = p.getInt(kUnitConvDenKey);
      if (!mounted) return;
      setState(() {
        if (widget.initialCategory == null && cat != null) {
          _cat = unitCategory(cat).id;
        }
        if (last != null) {
          final m = jsonDecode(last) as Map<String, dynamic>;
          m.forEach((k, v) {
            if (v is List && v.length == 2) {
              _last[k] = (unit: v[0].toString(), text: v[1].toString());
            }
          });
        }
        if (fav != null) _fav.addAll(fav);
        if (hidden != null) _hidden.addAll(hidden);
        if (den == 16 || den == 32 || den == 64) _den = den!;
      });
    } catch (_) {}
    for (final c in kUnitCategories) {
      _refill(c);
    }
    final w = _last['wire'];
    if (w != null) {
      (w.unit == 'awg' ? _awg : _sq).text = w.text;
      if (mounted) setState(() {});
    }
  }

  void _saveSoon() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _save);
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(kUnitConvCatKey, _cat);
      await p.setString(
        kUnitConvLastKey,
        jsonEncode({
          for (final e in _last.entries) e.key: [e.value.unit, e.value.text],
        }),
      );
      await p.setStringList(kUnitConvFavKey, _fav);
      await p.setStringList(kUnitConvHiddenKey, _hidden.toList());
      await p.setInt(kUnitConvDenKey, _den);
    } catch (_) {}
  }

  // ─────────────── 환산 ───────────────

  double? _parse(UnitDef u, String t) {
    if (u.id == 'in_frac' || u.id == 'ft_in') {
      final inch = parseInches(t);
      return inch == null ? null : u.toBase(inch);
    }
    final v = parseNumber(t);
    return v == null ? null : u.toBase(v);
  }

  String _format(UnitDef u, double base) {
    if (u.id == 'in_frac') {
      return inchFraction(u.fromBase(base), denom: _den).text;
    }
    if (u.id == 'ft_in') return feetInches(u.fromBase(base), denom: _den);
    return formatNumber(u.fromBase(base));
  }

  /// 이 분류의 지금 값(기준 단위). 없으면 null.
  double? _baseOf(UnitCategory c) {
    final l = _last[c.id];
    final u = l == null ? null : c.unit(l.unit);
    return u == null ? null : _parse(u, l!.text);
  }

  /// 마지막으로 넣은 칸을 뺀 나머지 칸을 다시 채운다.
  void _refill(UnitCategory c) {
    if (c.isTable) return;
    final l = _last[c.id];
    final base = _baseOf(c);
    for (final u in c.units) {
      final ctrl = _ctrlOf(c, u);
      if (l != null && u.id == l.unit) {
        if (ctrl.text != l.text) ctrl.text = l.text;
        continue;
      }
      ctrl.text = base == null ? '' : _format(u, base);
    }
  }

  void _onChanged(UnitCategory c, UnitDef u, String text) {
    setState(() {
      _last[c.id] = (unit: u.id, text: text);
      _refill(c);
    });
    _saveSoon();
  }

  void _clear() {
    HapticFeedback.selectionClick();
    setState(() {
      _last.remove(_cat);
      if (_cat == kWire.id) {
        _awg.clear();
        _sq.clear();
      }
      _refill(_c);
    });
    _saveSoon();
  }

  void _pickCategory(String id) {
    if (id == _cat) return;
    HapticFeedback.selectionClick();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _cat = id);
    _saveSoon();
  }

  void _setDen(int d) {
    HapticFeedback.selectionClick();
    setState(() {
      _den = d;
      _refill(kLength);
    });
    _saveSoon();
  }

  // ─────────────── 메뉴 ───────────────

  Future<void> _menu(UnitCategory c, UnitDef u, String v) async {
    final key = _k(c, u);
    switch (v) {
      case 'copy':
        final t = _ctrlOf(c, u).text.trim();
        if (t.isEmpty) return;
        final withUnit = u.textInput ? t : '$t ${u.symbol}';
        await Clipboard.setData(ClipboardData(text: withUnit));
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text("$withUnit 복사했습니다."),
                duration: const Duration(seconds: 2),
              ),
            );
        }
      case 'fav':
        setState(() {
          if (_fav.contains(key)) {
            _fav.remove(key);
          } else {
            _fav.add(key);
          }
        });
      case 'hide':
        setState(() {
          _hidden.add(key);
          _fav.remove(key);
        });
    }
    _saveSoon();
  }

  void _unhideAll(UnitCategory c) {
    setState(() => _hidden.removeWhere((k) => k.startsWith('${c.id}/')));
    _saveSoon();
  }

  // ─────────────── 찾기 ───────────────

  void _jump(UnitHit h) {
    _search.clear();
    _searchFocus.unfocus();
    setState(() {
      _q = '';
      _cat = h.category.id;
      final u = h.unit;
      if (u != null) _hidden.remove(_k(h.category, u)); // 숨긴 것도 찾으면 다시 보인다
    });
    _saveSoon();
    final u = h.unit;
    if (u == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _rowKey[_k(h.category, u)]?.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, alignment: 0.2);
      _focusOf(h.category, u).requestFocus();
    });
  }

  // ─────────────── 그리기 ───────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!widget.embedded) _searchBox(),
        if (_q.isEmpty) _categoryChips(),
        // 분류마다 새 목록 — 앞 분류에서 내린 만큼 내려간 채로 열리지 않게(맨 위 칸이 가려졌다).
        Expanded(
          child: _q.isEmpty
              ? KeyedSubtree(key: ValueKey('uc_body_$_cat'), child: _body())
              : _searchResults(),
        ),
        if (_q.isEmpty) ?_symbolBarIfTyping(),
      ],
    );
  }

  Widget _searchBox() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
    child: TextField(
      key: const Key('uc_search'),
      controller: _search,
      focusNode: _searchFocus,
      onChanged: (v) => setState(() => _q = v.trim()),
      style: TextStyle(color: fc.text),
      decoration: InputDecoration(
        hintText: "단위 찾기 (예: psi, 토크, 1/16, AWG, 15A)",
        hintStyle: TextStyle(color: fc.textSub, fontSize: 13),
        prefixIcon: Icon(Icons.search_rounded, color: fc.textSub),
        suffixIcon: _q.isEmpty
            ? null
            : IconButton(
                icon: Icon(Icons.close_rounded, color: fc.textSub),
                onPressed: () => setState(() {
                  _search.clear();
                  _q = '';
                }),
              ),
        filled: true,
        fillColor: fc.surface,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    ),
  );

  Widget _searchResults() {
    final hits = searchUnits(_q);
    if (hits.isEmpty) {
      return Center(
        child: Text(
          '"$_q"에 맞는 단위가 없습니다',
          style: TextStyle(color: fc.textSub, fontSize: 14),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: hits.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        final h = hits[i];
        final u = h.unit;
        return Material(
          color: fc.surface,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            key: Key('uc_hit_${h.category.id}_${u?.id ?? ''}'),
            borderRadius: BorderRadius.circular(12),
            onTap: () => _jump(h),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          u == null
                              ? h.category.label
                              : '${u.symbol} · ${u.name}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: fc.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          u == null ? '표' : h.category.label,
                          style: TextStyle(fontSize: 12, color: fc.textSub),
                        ),
                      ],
                    ),
                  ),
                  Icon(AppIcons.forward, color: fc.textSub),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _categoryChips() => SizedBox(
    height: 52,
    child: ListView(
      key: const Key('uc_cats'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      children: [
        for (final c in kUnitCategories)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: ChoiceChip(
              key: Key('uc_cat_${c.id}'),
              label: Text(c.label),
              selected: c.id == _cat,
              onSelected: (_) => _pickCategory(c.id),
              showCheckmark: false,
              labelStyle: TextStyle(
                fontWeight: FontWeight.w800,
                color: c.id == _cat ? fc.onBrand : fc.text,
              ),
              selectedColor: fc.brand,
              backgroundColor: fc.surface,
              side: BorderSide(color: c.id == _cat ? fc.brand : fc.line),
            ),
          ),
      ],
    ),
  );

  Widget _body() {
    final c = _c;
    if (c.id == kWire.id) return _wireBody();
    if (c.id == kPipe.id) return _pipeBody();
    final shown = <UnitDef>[
      for (final key in _fav)
        if (key.startsWith('${c.id}/')) ?c.unit(key.substring(c.id.length + 1)),
      for (final u in c.units)
        if (!_fav.contains(_k(c, u)) && !_hidden.contains(_k(c, u))) u,
    ];
    final hiddenCount = c.units.where((u) => _hidden.contains(_k(c, u))).length;
    final hasValue = (_last[c.id]?.text ?? '').trim().isNotEmpty;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                hasValue ? "다른 칸은 바로 바뀝니다" : "아무 칸에나 숫자를 넣으십시오",
                style: TextStyle(fontSize: 12, color: fc.textSub),
              ),
            ),
            if (hasValue)
              TextButton.icon(
                key: const Key('uc_clear'),
                onPressed: _clear,
                icon: const Icon(Icons.backspace_outlined, size: 18),
                label: const Text("지우기"),
              ),
          ],
        ),
        if (c.id == kLength.id) _denChips(),
        for (final u in shown) _row(c, u),
        if (hiddenCount > 0)
          Align(
            alignment: Alignment.center,
            child: TextButton(
              key: const Key('uc_unhide'),
              onPressed: () => _unhideAll(c),
              child: Text("숨긴 단위 $hiddenCount개 다시 보이기"),
            ),
          ),
      ],
    );
  }

  // 좁은 폰·큰 글씨에서 넘치지 않게 줄을 바꾼다.
  Widget _denChips() => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 4,
      children: [
        Text(
          "분수 눈금",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: fc.textSub,
          ),
        ),
        const SizedBox(width: 8),
        for (final d in const [16, 32, 64])
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              key: Key('uc_den_$d'),
              label: Text("1/$d"),
              selected: _den == d,
              onSelected: (_) => _setDen(d),
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
              labelStyle: TextStyle(
                fontWeight: FontWeight.w800,
                color: _den == d ? fc.onBrand : fc.text,
              ),
              selectedColor: fc.brand,
              backgroundColor: fc.surface,
              side: BorderSide(color: _den == d ? fc.brand : fc.line),
            ),
          ),
      ],
    ),
  );

  Widget _row(UnitCategory c, UnitDef u) {
    final key = _k(c, u);
    final fav = _fav.contains(key);
    final focus = _focusOf(c, u);
    final l = _last[c.id];
    String? note;
    if (u.id == 'in_frac' && l != null && l.unit != 'in_frac') {
      final base = _baseOf(c);
      if (base != null) {
        note = fractionErrorText(
          inchFraction(u.fromBase(base), denom: _den).errMm,
        );
      }
    }
    return Container(
      key: _rowKey.putIfAbsent(key, GlobalKey.new),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 4, 0, 4),
      decoration: BoxDecoration(
        color: fc.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: l?.unit == u.id ? fc.brand : fc.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 104,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (fav) ...[
                          Icon(
                            Icons.push_pin_rounded,
                            size: 14,
                            color: fc.brand,
                          ),
                          const SizedBox(width: 2),
                        ],
                        Flexible(
                          child: Text(
                            u.symbol,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: fc.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      u.name,
                      style: TextStyle(fontSize: 11, color: fc.textSub),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TextField(
                  key: Key('uc_field_${u.id}'),
                  controller: _ctrlOf(c, u),
                  focusNode: focus,
                  textAlign: TextAlign.right,
                  // 분수·피트는 "/"·"-"·띄어쓰기가 있는 날짜 숫자판(피트 표시는 아래 단추).
                  keyboardType: u.textInput
                      ? TextInputType.datetime
                      : TextInputType.numberWithOptions(
                          decimal: true,
                          signed: u.signed,
                        ),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: fc.text,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: u.id == 'in_frac'
                        ? '예: 1-3/8'
                        : u.id == 'ft_in'
                        ? "예: 4' 1-3/8"
                        : null,
                    hintStyle: TextStyle(color: fc.textFaint, fontSize: 15),
                  ),
                  onChanged: (t) => _onChanged(c, u, t),
                ),
              ),
              PopupMenuButton<String>(
                key: Key('uc_menu_${u.id}'),
                icon: Icon(Icons.more_vert_rounded, color: fc.textSub),
                tooltip: "${u.symbol} 메뉴",
                onSelected: (v) => _menu(c, u, v),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'copy', child: Text("값 복사")),
                  PopupMenuItem(
                    value: 'fav',
                    child: Text(fav ? "맨 위에서 빼기" : "맨 위에 두기"),
                  ),
                  const PopupMenuItem(value: 'hide', child: Text("숨기기")),
                ],
              ),
            ],
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(right: 14, bottom: 4),
              child: Text(
                note,
                key: const Key('uc_frac_err'),
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 12, color: fc.textSub),
              ),
            ),
        ],
      ),
    );
  }

  /// 분수·피트 칸을 누르고 있으면 자판 바로 위에 붙는 글자 줄. 숫자판(삼성 자판의 날짜
  /// 숫자판 포함)에는 "/"·"-"·"'"·'"'가 없어 분수를 넣을 수 없었다(2026-09-26 폰).
  Widget? _symbolBarIfTyping() {
    final c = _c;
    if (c.isTable) return null;
    UnitDef? typing;
    for (final u in c.units) {
      if (u.textInput && _focus[_k(c, u)]?.hasFocus == true) typing = u;
    }
    if (typing == null) return null;
    final u = typing;
    // 줄을 눌러도 칸에서 커서가 빠지지 않게(칸의 일부로 친다).
    return TextFieldTapRegion(
      child: Container(
        key: const Key('uc_symbols'),
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        decoration: BoxDecoration(
          color: fc.surface,
          border: Border(top: BorderSide(color: fc.line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                u.id == 'ft_in' ? "예: 4' 1-3/8" : "예: 1-3/8",
                style: TextStyle(fontSize: 13, color: fc.textSub),
              ),
            ),
            for (final sym in [
              '-',
              '/',
              if (u.id == 'ft_in') ...["'", '"'],
            ])
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Material(
                  color: fc.fill,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    key: Key('uc_insert_$sym'),
                    canRequestFocus: false,
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _insert(c, u, sym);
                    },
                    child: SizedBox(
                      width: 52,
                      height: 44,
                      child: Center(
                        child: Text(
                          sym,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: fc.text,
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
    );
  }

  /// 분수·피트 칸에 - / ' " 넣기(숫자판에 없는 글자).
  void _insert(UnitCategory c, UnitDef u, String s) {
    final ctrl = _ctrlOf(c, u);
    final sel = ctrl.selection;
    final at = sel.isValid ? sel.start : ctrl.text.length;
    final text = ctrl.text.replaceRange(at, sel.isValid ? sel.end : at, s);
    ctrl.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: at + s.length),
    );
    _onChanged(c, u, text);
  }

  // ─────────────── 전선 굵기 ───────────────

  void _wireChanged(String which, String text) {
    setState(() {
      _last[kWire.id] = (unit: which, text: text);
      if (which == 'awg') {
        final n = parseAwg(text);
        _sq.text = n == null
            ? ''
            : formatNumber(double.parse(awgAreaMm2(n).toStringAsFixed(2)));
      } else {
        final v = parseNumber(text);
        final a = v == null || v <= 0 ? null : awgFor(v);
        _awg.text = a == null ? '' : awgLabel(a.nearest);
      }
    });
    _saveSoon();
  }

  Widget _wireBody() {
    final l = _last[kWire.id];
    String? result;
    if (l != null && l.unit == 'awg') {
      final n = parseAwg(l.text);
      if (n != null) {
        final a = awgAreaMm2(n);
        final s = sqFor(a);
        result =
            "AWG ${awgLabel(n)} = ${a.toStringAsFixed(2)}mm²\n"
            "가장 가까운 규격 ${sqLabel(s.nearest)}"
            "${s.atLeast == null ? '' : ' · 같거나 굵은 규격 ${sqLabel(s.atLeast!)}'}";
      }
    } else if (l != null) {
      final v = parseNumber(l.text);
      if (v != null && v > 0) {
        final a = awgFor(v);
        result =
            "${formatNumber(v)}mm²\n"
            "가장 가까운 AWG ${awgLabel(a.nearest)} (${awgAreaMm2(a.nearest).toStringAsFixed(2)}mm²)"
            "${a.atLeast == null ? ' · 4/0보다 굵습니다' : ' · 같거나 굵은 AWG ${awgLabel(a.atLeast!)} (${awgAreaMm2(a.atLeast!).toStringAsFixed(2)}mm²)'}";
      }
    }
    Widget field(
      String which,
      String label,
      String hint,
      TextEditingController c,
    ) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
      decoration: BoxDecoration(
        color: fc.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: l?.unit == which ? fc.brand : fc.line),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: fc.text,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              key: Key('uc_$which'),
              controller: c,
              textAlign: TextAlign.right,
              keyboardType: which == 'awg'
                  ? TextInputType.datetime
                  : const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: fc.text,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: TextStyle(color: fc.textFaint, fontSize: 15),
              ),
              onChanged: (t) => _wireChanged(which, t),
            ),
          ),
        ],
      ),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                "한쪽에 넣으면 가까운 규격을 찾습니다",
                style: TextStyle(fontSize: 12, color: fc.textSub),
              ),
            ),
            if ((l?.text ?? '').isNotEmpty)
              TextButton.icon(
                key: const Key('uc_clear'),
                onPressed: _clear,
                icon: const Icon(Icons.backspace_outlined, size: 18),
                label: const Text("지우기"),
              ),
          ],
        ),
        field('awg', 'AWG', '예: 10, 1/0', _awg),
        field('sq', 'SQ (mm²)', '예: 2.5', _sq),
        if (result != null)
          Container(
            key: const Key('uc_wire_result'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: fc.brandSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              result,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: fc.text,
                height: 1.5,
              ),
            ),
          ),
        const SizedBox(height: 16),
        _tableCard(
          "AWG ↔ SQ 표",
          refTable(
            headers: const ["AWG", "단면적\n(mm²)", "같거나 굵은\nSQ"],
            rows: [
              for (final n in kAwgList)
                [
                  awgLabel(n),
                  awgAreaMm2(n).toStringAsFixed(2),
                  sqFor(awgAreaMm2(n)).atLeast == null
                      ? '—'
                      : sqLabel(sqFor(awgAreaMm2(n)).atLeast!),
                ],
            ],
          ),
          "AWG와 SQ는 딱 맞지 않습니다. 바꿔 쓸 때는 같거나 굵은 규격을 고르고, 허용전류는 전선 제조사 표로 확인하십시오.",
        ),
      ],
    );
  }

  // ─────────────── 배관 호칭 ───────────────

  Widget _pipeBody() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
    children: [
      _tableCard(
        "강관 호칭 (A · B · DN · 바깥지름 mm)",
        refTable(
          headers: const ["A", "B(인치)", "DN", "KS", "ASME"],
          flex: const [5, 6, 5, 5, 5],
          rows: [
            for (final p in kPipeSizes)
              [
                p.a,
                p.b,
                '${p.dn}',
                p.ksOd.toStringAsFixed(1),
                p.asmeOd.toStringAsFixed(1),
              ],
          ],
        ),
        "표 값: KS D 3507(= JIS G 3452) · ASME B36.10M 바깥지름. 같은 15A라도 KS 21.7, ASME 21.3으로 다릅니다. 두께(스케줄)는 규격마다 다릅니다.",
      ),
      const SizedBox(height: 12),
      _tableCard(
        "튜브 (인치 → 바깥지름 mm)",
        refTable(
          headers: const ["호칭", "바깥지름 (mm)"],
          rows: [
            for (final s in kTubeInchSizes)
              ['$s"', (parseInches(s)! * kMmPerInch).toStringAsFixed(2)],
          ],
        ),
        "계산 값: 인치 × 25.4.",
      ),
      const SizedBox(height: 12),
      _tableCard(
        "전선관 바깥지름 (mm)",
        refTable(
          headers: const ["후강", "바깥지름", "박강", "바깥지름"],
          rows: [
            for (
              var i = 0;
              i <
                  [
                    kThickConduitOd.length,
                    kThinConduitOd.length,
                  ].reduce((a, b) => a > b ? a : b);
              i++
            )
              [
                i < kThickConduitOd.length
                    ? '${kThickConduitOd.keys.elementAt(i)}'
                    : '',
                i < kThickConduitOd.length
                    ? kThickConduitOd.values.elementAt(i).toStringAsFixed(1)
                    : '',
                i < kThinConduitOd.length
                    ? '${kThinConduitOd.keys.elementAt(i)}'
                    : '',
                i < kThinConduitOd.length
                    ? kThinConduitOd.values.elementAt(i).toStringAsFixed(1)
                    : '',
              ],
          ],
        ),
        "앱 전선관 자료: 후강 KS C 8401, 박강 KS C 8422.",
      ),
    ],
  );

  Widget _tableCard(String title, Widget table, String note) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: fc.surface,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: fc.text,
          ),
        ),
        const SizedBox(height: 10),
        table,
        const SizedBox(height: 8),
        Text(
          note,
          style: TextStyle(fontSize: 11, color: fc.textSub, height: 1.4),
        ),
      ],
    ),
  );
}
