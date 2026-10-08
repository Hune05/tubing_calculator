// 공식 계산 목록·상세 화면. 공식을 고르면 칸마다 이름·단위·"?" 도움말이 있는 입력
// 칸이 뜨고, 다 넣으면 바로 결과가 나온다(formula_defs.dart의 공식들).
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/common_widgets/recent_calc_history.dart';
import '../../core/theme/app_icon_set.dart';
import '../../core/theme/field_view.dart';
import '../common/calc_form_parts.dart';
import '../unit_converter/unit_defs.dart' show formatNumber, formatNumberGrouped;
import 'formula_defs.dart';
import '../common/number_text.dart';

class FormulaCalcPage extends StatelessWidget {
  const FormulaCalcPage({super.key});

  @override
  Widget build(BuildContext context) => FieldViewTheme(
    child: Builder(
      builder: (context) {
        final byCategory = <String, List<FormulaDef>>{};
        for (final f in kFormulas) {
          byCategory.putIfAbsent(f.category, () => []).add(f);
        }
        return Scaffold(
          backgroundColor: fc.surface,
          appBar: AppBar(
            backgroundColor: fc.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            foregroundColor: fc.text,
            title: Text(
              "공식 계산",
              style: TextStyle(fontWeight: FontWeight.w800, color: fc.text),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              for (final cat in byCategory.keys) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cat,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: fc.textSub,
                        ),
                      ),
                      if (kFormulaCategoryIntro[cat] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          kFormulaCategoryIntro[cat]!,
                          style: TextStyle(
                            fontSize: 12,
                            color: fc.textSub,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                for (final f in byCategory[cat]!)
                  Card(
                    key: Key('formula_${f.id}'),
                    margin: const EdgeInsets.only(bottom: 8),
                    color: fc.surface,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: fc.line),
                    ),
                    child: ListTile(
                      title: Text(
                        f.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: fc.text,
                        ),
                      ),
                      subtitle: Text(
                        f.formulaText,
                        style: TextStyle(color: fc.textSub),
                      ),
                      trailing: Icon(AppIcons.forward, color: fc.textSub),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FormulaDetailPage(def: f),
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    ),
  );
}

class FormulaDetailPage extends StatefulWidget {
  final FormulaDef def;
  const FormulaDetailPage({super.key, required this.def});

  @override
  State<FormulaDetailPage> createState() => _FormulaDetailPageState();
}

class _FormulaDetailPageState extends State<FormulaDetailPage>
    with CalcFormParts<FormulaDetailPage>, RecentCalcHistoryMixin<FormulaDetailPage> {
  /// 최근 계산 기록을 폰에 이틀 동안 남기는 칸.
  @override
  String? get calcHistoryStorageKey => 'calc_history_formula_${widget.def.id}';

  late final Map<String, TextEditingController> _ctrl = {
    for (final v in widget.def.inputs) v.key: TextEditingController(),
  };

  /// 칸마다 고른 단위(처음은 현장에서 흔한 단위, 예: 압력 bar)와 결과 단위.
  late final Map<String, FormulaUnit> _units = {
    for (final v in widget.def.inputs) v.key: formulaUnitChoices(v.unit).first,
  };
  late FormulaUnit _resultUnit = formulaUnitChoices(widget.def.resultUnit).first;

  static const _unitsKey = '__units';
  static const _resultUnitKey = '__result';

  Map<String, String> _unitLabels() => {
    for (final e in _units.entries) e.key: e.value.label,
    _resultUnitKey: _resultUnit.label,
  };

  /// 저장된 단위 이름을 되살린다. 단위가 안 적힌 옛 값은 그때 받던 기준 단위(Pa·m³/s 등)로 넣은 것.
  void _applyUnits(Object? raw) {
    final m = raw is Map ? raw : const {};
    for (final v in widget.def.inputs) {
      _units[v.key] = formulaUnitByLabel(v.unit, m[v.key]?.toString());
    }
    _resultUnit = formulaUnitByLabel(
      widget.def.resultUnit,
      m[_resultUnitKey]?.toString(),
    );
  }

  /// 기록을 누르면 그때 입력값으로 되돌린다.
  @override
  String? calcRestoreSnapshot() => _draftText();

  @override
  void calcRestoreApply(String raw) {
    final m = jsonDecode(raw) as Map<String, dynamic>;
    for (final e in _ctrl.entries) {
      final v = m[e.key];
      if (v is String) e.value.text = v;
    }
    _applyUnits(m[_unitsKey]);
  }

  // 넣은 값은 공식마다 폰에 남겨 다시 열면 되살린다(10-07: 뒤로 가면 모두 사라졌다. 유량·전기 화면처럼).
  String get _draftKey => 'formula_draft_${widget.def.id}';
  Timer? _draftTimer;

  @override
  void initState() {
    super.initState();
    _loadDraft();
    for (final c in _ctrl.values) {
      c.addListener(_saveDraftSoon);
    }
  }

  Future<void> _loadDraft() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_draftKey);
      if (raw == null || !mounted) return;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      // 그새 칸에 뭔가 넣었으면 덮지 않는다.
      if (_ctrl.values.any((c) => c.text.isNotEmpty)) return;
      setState(() {
        for (final e in _ctrl.entries) {
          final v = m[e.key];
          if (v is String) e.value.text = v;
        }
        _applyUnits(m[_unitsKey]);
      });
    } catch (_) {}
  }

  void _saveDraftSoon() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 400), () => _writeDraft(_draftText()));
  }

  String _draftText() => jsonEncode({
    for (final e in _ctrl.entries) e.key: e.value.text,
    _unitsKey: _unitLabels(),
  });

  /// 단위 이름을 누르면 고르는 목록. 넣은 숫자는 그대로 두고 단위만 바꾼다.
  Widget _unitButton(
    Key key,
    String baseUnit,
    FormulaUnit current,
    ValueChanged<FormulaUnit> onPick,
  ) {
    final choices = formulaUnitChoices(baseUnit);
    final label = Text(
      current.label,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: choices.length > 1 ? fc.brand : fc.textSub,
      ),
    );
    if (choices.length < 2) {
      return Padding(padding: const EdgeInsets.only(left: 6), child: label);
    }
    return PopupMenuButton<FormulaUnit>(
      key: key,
      tooltip: '단위 바꾸기',
      initialValue: current,
      onSelected: (u) {
        setState(() => onPick(u));
        _saveDraftSoon();
      },
      itemBuilder: (_) => [
        for (final u in choices)
          PopupMenuItem(value: u, child: Text(u.label)),
      ],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 8, 0, 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            label,
            Icon(Icons.arrow_drop_down, size: 20, color: fc.brand),
          ],
        ),
      ),
    );
  }

  Future<void> _writeDraft(String text) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_draftKey, text);
    } catch (_) {}
  }

  @override
  void dispose() {
    // 0.4초 안에 나가도 마지막 입력을 남긴다(10-07: 타이머만 끄고 저장을 빠뜨렸다).
    if (_draftTimer?.isActive ?? false) _writeDraft(_draftText());
    _draftTimer?.cancel();
    for (final c in _ctrl.values) {
      c.removeListener(_saveDraftSoon);
      c.dispose();
    }
    super.dispose();
  }

  double? _num(TextEditingController c) => parseNumberText(c.text);

  @override
  Widget build(BuildContext context) {
    final def = widget.def;
    final values = <String, double>{};
    var complete = true;
    String? error;
    final pctNotes = <String>[];
    final entered = <String, double>{};
    for (final v in def.inputs) {
      var n = _num(_ctrl[v.key]!);
      if (n == null) {
        complete = false;
        continue;
      }
      // 역률·효율 칸: 1을 넘으면 %로 넣은 것으로 보고 ÷100, 0 이하나 100 초과는 입력 확인.
      if (v.ratio) {
        if (n <= 0 || n > 100) {
          error ??= '${v.label}은 0~1(또는 0~100%)로 넣으십시오.';
        } else if (n > 1) {
          pctNotes.add('${v.label} ${formatNumber(n)}를 ${formatNumber(n)}%(${formatNumber(n / 100)})로 계산했습니다.');
          n = n / 100;
        }
      }
      entered[v.key] = n;
      values[v.key] = n * _units[v.key]!.factor;
    }
    double? result;
    if (complete && error == null) {
      try {
        result = def.compute(values);
        if (result.isNaN || result.isInfinite) {
          error = '계산할 수 없습니다(0으로 나누거나 값이 맞지 않습니다).';
          result = null;
        }
      } catch (_) {
        error = '계산할 수 없습니다.';
      }
    }
    // 결과는 고른 결과 단위로 바꿔 보인다.
    final shown = result == null ? null : result / _resultUnit.factor;
    final resultUnitText = _resultUnit.label.isEmpty ? '' : ' ${_resultUnit.label}';
    if (shown != null) {
      final inputsText = def.inputs
          .map(
            (v) =>
                '${v.label} ${formatNumberGrouped(entered[v.key]!)}${_units[v.key]!.label}',
          )
          .join(', ');
      logCalc(
        def.name,
        '$inputsText → ${formatNumberGrouped(shown)}$resultUnitText',
      );
    }
    return FieldViewTheme(
      child: Scaffold(
        backgroundColor: fc.surface,
        appBar: AppBar(
          backgroundColor: fc.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          foregroundColor: fc.text,
          title: Text(
            def.name,
            style: TextStyle(fontWeight: FontWeight.w800, color: fc.text),
          ),
          actions: [calcHistoryButton()],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              calcBox(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        def.formulaText,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: fc.brand,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        def.description,
                        style: TextStyle(
                          fontSize: 13,
                          color: fc.textSub,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              for (final v in def.inputs)
                calcField(
                  'formula_in_${v.key}',
                  v.label,
                  _ctrl[v.key]!,
                  v.hint,
                  signed: true,
                  trailing: v.unit.isEmpty
                      ? null
                      : _unitButton(
                          Key('formula_unit_${v.key}'),
                          v.unit,
                          _units[v.key]!,
                          (u) => _units[v.key] = u,
                        ),
                ),
              const SizedBox(height: 8),
              if (formulaUnitChoices(def.resultUnit).length > 1)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '결과 단위',
                      style: TextStyle(fontSize: 13, color: fc.textSub),
                    ),
                    _unitButton(
                      const Key('formula_result_unit'),
                      def.resultUnit,
                      _resultUnit,
                      (u) => _resultUnit = u,
                    ),
                  ],
                ),
              if (error != null)
                calcResult(
                  key: const Key('formula_result'),
                  big: '오류',
                  caption: error,
                  lines: const [],
                  warn: true,
                )
              else if (shown != null)
                calcResult(
                  key: const Key('formula_result'),
                  big: '${formatNumberGrouped(shown)}$resultUnitText',
                  caption: def.resultLabel,
                  lines: pctNotes,
                )
              else
                calcResult(big: '—', caption: '위 칸에 값을 모두 넣으십시오', lines: const []),
            ],
          ),
        ),
      ),
    );
  }
}
