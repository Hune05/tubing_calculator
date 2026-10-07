// 공식 계산 목록·상세 화면. 공식을 고르면 칸마다 이름·단위·"?" 도움말이 있는 입력
// 칸이 뜨고, 다 넣으면 바로 결과가 나온다(formula_defs.dart의 공식들).
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/common_widgets/recent_calc_history.dart';
import '../../core/theme/app_icon_set.dart';
import '../../core/theme/field_view.dart';
import '../common/calc_form_parts.dart';
import '../unit_converter/unit_defs.dart' show formatNumber;
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

  /// 기록을 누르면 그때 입력값으로 되돌린다.
  @override
  String? calcRestoreSnapshot() =>
      jsonEncode({for (final e in _ctrl.entries) e.key: e.value.text});

  @override
  void calcRestoreApply(String raw) {
    final m = jsonDecode(raw) as Map<String, dynamic>;
    for (final e in _ctrl.entries) {
      final v = m[e.key];
      if (v is String) e.value.text = v;
    }
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) {
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
    for (final v in def.inputs) {
      final n = _num(_ctrl[v.key]!);
      if (n == null) {
        complete = false;
      } else {
        values[v.key] = n;
      }
    }
    double? result;
    String? error;
    if (complete) {
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
    if (result != null) {
      final inputsText = def.inputs
          .map(
            (v) =>
                '${v.label} ${formatNumber(values[v.key]!)}${v.unit}',
          )
          .join(', ');
      logCalc(
        def.name,
        '$inputsText → ${formatNumber(result)}'
        '${def.resultUnit.isEmpty ? '' : ' ${def.resultUnit}'}',
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
                      : Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text(
                            v.unit,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: fc.textSub,
                            ),
                          ),
                        ),
                ),
              const SizedBox(height: 8),
              if (error != null)
                calcResult(
                  key: const Key('formula_result'),
                  big: '오류',
                  caption: error,
                  lines: const [],
                  warn: true,
                )
              else if (result != null)
                calcResult(
                  key: const Key('formula_result'),
                  big:
                      '${formatNumber(result)}${def.resultUnit.isEmpty ? '' : ' ${def.resultUnit}'}',
                  caption: def.resultLabel,
                  lines: const [],
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
