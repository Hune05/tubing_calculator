// 원인 확인 화면(10-03): 계산기가 "한도 초과·불합격"을 낼 때 입력값을 그대로 가지고 넘어와,
// 원인 후보와 확인 방법, 고치면 얼마가 되는지를 계산해 보여 준다. 원인 후보는 diagnosis_causes.dart가 만든다.
// 확인한 항목은 체크해 두면 남은 것만 보인다(이 화면에서만, 저장하지 않는다).
import 'package:flutter/material.dart';

import '../../core/theme/app_icon_set.dart';
import '../../core/theme/field_view.dart';

/// 원인 후보 하나.
class DiagCause {
  const DiagCause({
    required this.title,
    required this.check,
    this.effect,
    this.basis,
  });

  /// 한 줄 제목(예: "입력한 전류가 실제 값과 다르다").
  final String title;

  /// 확인하는 방법.
  final String check;

  /// 이 원인을 고치면 어떻게 되는지(계산 결과). 없으면 확인만 하는 항목.
  final String? effect;

  /// 근거(식·조문). 없으면 생략.
  final String? basis;
}

/// 원인 확인에 넘기는 묶음: 계산기가 본 입력과 결과, 원인 후보.
class DiagCase {
  const DiagCase({
    required this.title,
    required this.symptom,
    required this.inputs,
    required this.causes,
    this.footer,
  });

  final String title;

  /// 한 줄 증상(예: "전압강하율 5.32 %, 한도 5 % 초과").
  final String symptom;

  /// 계산기에서 넘어온 입력값 목록(칸 이름: 값).
  final List<(String, String)> inputs;
  final List<DiagCause> causes;
  final String? footer;
}

class DiagnosisPage extends StatefulWidget {
  const DiagnosisPage({super.key, required this.diag});
  final DiagCase diag;

  @override
  State<DiagnosisPage> createState() => _DiagnosisPageState();
}

class _DiagnosisPageState extends State<DiagnosisPage> {
  final Set<int> _done = {};

  Widget _card({required List<Widget> children, Color? color, Key? key}) =>
      Container(
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

  @override
  Widget build(BuildContext context) {
    final d = widget.diag;
    final left = d.causes.length - _done.length;
    return Scaffold(
      backgroundColor: fc.background,
      appBar: AppBar(title: Text(d.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
        children: [
          _card(
            key: const Key('dg_symptom'),
            color: fieldSoft(Colors.red.shade50, (p) => p.danger),
            children: [
              Text(
                '증상',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: fc.danger,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                d.symptom,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: fc.text,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '계산기에서 넘어온 값',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: fc.textSub,
                ),
              ),
              const SizedBox(height: 4),
              for (final (k, v) in d.inputs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '$k: $v',
                    style: TextStyle(fontSize: 14, color: fc.text),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, 8),
            child: Text(
              '원인 후보 · 확인하기 쉬운 순서 (남은 것 $left개)',
              key: const Key('dg_left'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: fc.text,
              ),
            ),
          ),
          for (var i = 0; i < d.causes.length; i++)
            _card(
              key: Key('dg_cause_$i'),
              color: _done.contains(i) ? fc.fill : null,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: fc.brand,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        d.causes[i].title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: _done.contains(i) ? fc.textSub : fc.text,
                          decoration: _done.contains(i)
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '확인: ${d.causes[i].check}',
                  style: TextStyle(fontSize: 14, height: 1.45, color: fc.text),
                ),
                if (d.causes[i].effect != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '고치면: ${d.causes[i].effect}',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w800,
                      color: fc.brand,
                    ),
                  ),
                ],
                if (d.causes[i].basis != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    d.causes[i].basis!,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: fc.textSub,
                    ),
                  ),
                ],
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    key: Key('dg_done_$i'),
                    onPressed: () => setState(() {
                      if (!_done.remove(i)) _done.add(i);
                    }),
                    child: Text(_done.contains(i) ? '다시 보기' : '확인함'),
                  ),
                ),
              ],
            ),
          if (d.footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
              child: Text(
                d.footer!,
                style: TextStyle(fontSize: 13, height: 1.45, color: fc.textSub),
              ),
            ),
          OutlinedButton.icon(
            key: const Key('dg_back'),
            onPressed: () => Navigator.pop(context),
            icon: const Icon(AppIcons.back),
            label: const Text('계산기로 돌아가기'),
          ),
        ],
      ),
    );
  }
}
