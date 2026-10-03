// 고장 진단 흐름 화면(10-03): 증상을 고르고, 질문에 답하고, 측정값을 넣으면 판정과 원인·조치가 이어서 나온다.
// 흐름 내용은 troubleshoot_flows.dart. 이 화면은 입력에 따라 단계를 처음부터 다시 따라가며 그린다(저장하지 않는다).
import 'package:flutter/material.dart';

import '../../core/theme/app_icon_set.dart';
import '../../core/theme/field_view.dart';
import '../common/calc_form_parts.dart';
import 'electric_calculator_page.dart';
import 'troubleshoot_flows.dart';

/// 진단 흐름 목록.
class TroubleshootPage extends StatelessWidget {
  const TroubleshootPage({super.key});

  @override
  Widget build(BuildContext context) {
    final flows = troubleshootFlows();
    return Scaffold(
      backgroundColor: fc.background,
      appBar: AppBar(title: const Text('고장 진단')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
            child: Text(
              '증상을 고르면 질문과 측정값 입력으로 원인을 좁혀 갑니다. 판정 기준은 앱 안 계산기와 같은 값을 씁니다.',
              style: TextStyle(fontSize: 14, height: 1.45, color: fc.textSub),
            ),
          ),
          for (final f in flows)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: fc.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: fc.line),
              ),
              child: ListTile(
                key: Key('ts_flow_${f.id}'),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                title: Text(
                  f.title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: fc.text,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    f.subtitle,
                    style: TextStyle(fontSize: 13, color: fc.textSub),
                  ),
                ),
                trailing: Icon(AppIcons.forward, color: fc.textSub),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => TroubleshootFlowPage(flow: f),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 흐름 하나를 따라가는 화면.
class TroubleshootFlowPage extends StatefulWidget {
  const TroubleshootFlowPage({super.key, required this.flow});
  final WizFlow flow;

  @override
  State<TroubleshootFlowPage> createState() => _TroubleshootFlowPageState();
}

class _TroubleshootFlowPageState extends State<TroubleshootFlowPage>
    with CalcFormParts {
  /// 고르는 질문에서 고른 번호(단계 id → 선택 번호).
  final Map<String, int> _picked = {};

  /// 입력 칸(단계 id.칸 key).
  final Map<String, TextEditingController> _ctl = {};

  /// 고르는 칸 값(단계 id.칸 key).
  final Map<String, String> _sel = {};

  @override
  void dispose() {
    for (final c in _ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _c(String step, WizField f) =>
      _ctl.putIfAbsent('$step.${f.key}', () {
        return TextEditingController(text: f.initial ?? '');
      });

  Widget _card(List<Widget> children, {Color? color, Key? key}) => Container(
    key: key,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color ?? fc.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: fc.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );

  Widget _title(int n, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$n',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: fc.brand,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: fc.text,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _help(String? t) => t == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            t,
            style: TextStyle(fontSize: 13, height: 1.45, color: fc.textSub),
          ),
        );

  /// 처음부터 따라가며 보이는 단계 위젯을 만든다.
  List<Widget> _trail() {
    final flow = widget.flow;
    final out = <Widget>[];
    var n = 0;
    final seen = <String>{};
    var cur0 = flow.start;
    while (seen.add(cur0)) {
      final id = cur0;
      final step = flow.steps[id]!;
      n++;
      switch (step) {
        case WizChoice():
          final p = _picked[id];
          out.add(
            _card(
              key: Key('ts_step_$id'),
              [
                _title(n, step.title),
                _help(step.help),
                for (var i = 0; i < step.options.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        key: Key('ts_opt_${id}_$i'),
                        style: OutlinedButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          backgroundColor: p == i ? fc.brand : null,
                          side: BorderSide(color: p == i ? fc.brand : fc.line),
                        ),
                        onPressed: () => setState(() => _picked[id] = i),
                        child: Text(
                          step.options[i].$1,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: p == i ? fc.onBrand : fc.text,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
          if (p == null) return out;
          cur0 = step.options[p].$2;
        case WizMeasure():
          final vals = <String, double?>{};
          final sel = <String, String>{};
          var ready = true;
          final fieldsW = <Widget>[];
          for (final f in step.fields) {
            if (f.choices != null) {
              final cur = _sel['$id.${f.key}'] ?? f.initial ?? f.choices!.first.$1;
              sel[f.key] = cur;
              fieldsW.add(
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: fc.text,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final (v, name) in f.choices!)
                            calcChip(
                              'ts_sel_${id}_${f.key}_$v',
                              name,
                              cur == v,
                              () => setState(() => _sel['$id.${f.key}'] = v),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            } else {
              final c = _c(id, f);
              final v = double.tryParse(c.text.trim().replaceAll(',', '.'));
              vals[f.key] = v;
              if (v == null && !f.optional) ready = false;
              fieldsW.add(
                calcField(
                  'ts_in_${id}_${f.key}',
                  f.unit.isEmpty ? f.label : '${f.label} (${f.unit})',
                  c,
                  f.hint,
                ),
              );
            }
          }
          final j = ready ? step.judge(vals, sel) : null;
          out.add(
            _card(
              key: Key('ts_step_$id'),
              [
                _title(n, step.title),
                _help(step.help),
                ...fieldsW,
                if (j != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    key: Key('ts_judge_$id'),
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: j.warn
                          ? fieldSoft(Colors.red.shade50, (p) => p.danger)
                          : fc.fill,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '판정',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: j.warn ? fc.danger : fc.textSub,
                          ),
                        ),
                        const SizedBox(height: 4),
                        for (final l in j.lines)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(
                              l,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.45,
                                color: fc.text,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
          if (j == null || j.next == null) return out;
          cur0 = j.next!;
        case WizEnd():
          out.add(_endCard(n, step));
          return out;
      }
    }
    return out;
  }

  Widget _endCard(int n, WizEnd e) => _card(
    key: Key('ts_end_${e.id}'),
    color: fc.fill,
    [
      _title(n, e.title),
      Text(
        '원인 후보',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: fc.textSub,
        ),
      ),
      const SizedBox(height: 4),
      for (final c in e.causes)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            '· $c',
            style: TextStyle(fontSize: 14, height: 1.45, color: fc.text),
          ),
        ),
      const SizedBox(height: 8),
      Text(
        '조치 순서',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: fc.textSub,
        ),
      ),
      const SizedBox(height: 4),
      for (var i = 0; i < e.actions.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            '${i + 1}. ${e.actions[i]}',
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w700,
              color: fc.text,
            ),
          ),
        ),
      if (e.note != null) ...[
        const SizedBox(height: 4),
        Text(
          e.note!,
          style: TextStyle(fontSize: 13, height: 1.45, color: fc.textSub),
        ),
      ],
      if (e.links.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (name, tab) in e.links)
              OutlinedButton(
                key: Key('ts_link_$tab'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ElectricCalculatorPage(initialTab: tab),
                  ),
                ),
                child: Text(name),
              ),
          ],
        ),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: fc.background,
    appBar: AppBar(title: Text(widget.flow.title)),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
      children: [
        ..._trail(),
        TextButton(
          key: const Key('ts_reset'),
          onPressed: () => setState(() {
            _picked.clear();
            _sel.clear();
            _ctl.clear();
          }),
          child: const Text('처음부터 다시'),
        ),
      ],
    ),
  );
}
