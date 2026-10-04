import 'package:flutter/material.dart';

import 'package:tubing_calculator/src/presentation/calculator/angle_matcher.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/angle_match_guide.dart';
import 'package:tubing_calculator/src/presentation/conduit/widgets/conduit_special_ui.dart';

// 각도 역산(Field Matcher) 시트. 이미 꺾어 놓은 관에서 잰 높이와 Travel(또는 Run)로 실제 각도를 거꾸로
// 구하고, 가장 가까운 표준 각도와 그 차이를 보여 준다. 튜브·전선관 특수 벤딩 목록에서 같이 쓴다.
// 틀은 오프셋 시트와 같은 공용 부품(conduit_special_ui.dart), 셈은 angle_matcher.dart.
class AngleMatcherSheet extends StatefulWidget {
  /// 있으면 결과 상자에 "오프셋 계산" 단추가 생긴다. 누르면 이 시트를 닫고 (높이, 표준 각도)를 넘겨 준다.
  final void Function(double rise, double angle)? onUseInOffset;

  const AngleMatcherSheet({super.key, this.onUseInOffset});

  static void show(
    BuildContext context, {
    void Function(double rise, double angle)? onUseInOffset,
  }) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AngleMatcherSheet(onUseInOffset: onUseInOffset),
  );

  @override
  State<AngleMatcherSheet> createState() => _AngleMatcherSheetState();
}

class _AngleMatcherSheetState extends State<AngleMatcherSheet> {
  final _rise = TextEditingController();
  final _measure = TextEditingController();
  MatchBasis _basis = MatchBasis.travel;

  @override
  void initState() {
    super.initState();
    _rise.addListener(() => setState(() {}));
    _measure.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _rise.dispose();
    _measure.dispose();
    super.dispose();
  }

  String _sign(double v) => '${v >= 0 ? '+' : '-'}${csFmt(v.abs())}';

  @override
  Widget build(BuildContext context) {
    final double? rise = csRead(_rise), measure = csRead(_measure);
    final problem = matchProblem(rise: rise, measure: measure, basis: _basis);
    final m = matchAngle(rise: rise, measure: measure, basis: _basis);
    final bool byTravel = _basis == MatchBasis.travel;
    return CsFrame(
      title: '각도 역산 (Field Matcher)',
      guide: AngleMatchGuide(
        angle: m?.angle,
        riseLabel: '${csFmt(m?.rise ?? 0)}mm',
        travelLabel: '${csFmt(m?.travel ?? 0)}mm',
        runLabel: '${csFmt(m?.run ?? 0)}mm',
        angleLabel: '${csFmt(m?.angle ?? 0)}°',
      ),
      children: [
        const Text(
          '이미 꺾어 놓은 관에서 잰 값으로 꺾은 각도를 거꾸로 구합니다. 기존 관과 똑같이 꺾어 이을 때 씁니다.',
          style: TextStyle(color: csSub, fontSize: 12),
        ),
        const SizedBox(height: 16),
        const CsLabel('잰 방법'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            CsChoice(
              choiceKey: const Key('am_basis_travel'),
              label: 'Travel (관 따라 잰 거리)',
              selected: byTravel,
              onTap: () => setState(() => _basis = MatchBasis.travel),
            ),
            CsChoice(
              choiceKey: const Key('am_basis_run'),
              label: 'Run (수평 거리)',
              selected: !byTravel,
              onTap: () => setState(() => _basis = MatchBasis.run),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const CsLabel('꺾여 올라간 높이 (Rise)'),
        Row(
          children: [
            Expanded(child: CsField(fieldKey: const Key('am_rise'), ctrl: _rise, hint: '높이 mm')),
            const SizedBox(width: 12),
            CsQuickBtn(ctrl: _rise, amount: -5, label: '-5'),
            const SizedBox(width: 4),
            CsQuickBtn(ctrl: _rise, amount: 5, label: '+5'),
          ],
        ),
        const SizedBox(height: 16),
        CsLabel(byTravel ? '꺾이는 점 사이 거리 (Travel, 관 따라)' : '꺾이는 점 사이 수평 거리 (Run)'),
        Row(
          children: [
            Expanded(
              child: CsField(
                fieldKey: const Key('am_measure'),
                ctrl: _measure,
                hint: byTravel ? 'Travel mm' : 'Run mm',
              ),
            ),
            const SizedBox(width: 12),
            CsQuickBtn(ctrl: _measure, amount: -5, label: '-5'),
            const SizedBox(width: 4),
            CsQuickBtn(ctrl: _measure, amount: 5, label: '+5'),
          ],
        ),
        if (problem == MatchProblem.travelShorter) ...[
          const SizedBox(height: 8),
          const Text(
            'Travel은 높이보다 길어야 합니다. 값을 다시 확인하십시오.',
            key: Key('am_problem'),
            style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
        const SizedBox(height: 24),
        CsResultBox(
          title: '실제로 꺾은 각도',
          value: m == null ? null : '${csFmt(m.angle)}°',
          btnText: '오프셋 계산',
          onPressed: m == null || widget.onUseInOffset == null
              ? null
              : () {
                  Navigator.pop(context);
                  widget.onUseInOffset!(m.rise, m.nearest.angle);
                },
          details: m == null ? const [] : _details(m, byTravel),
        ),
      ],
    );
  }

  List<Widget> _details(AngleMatch m, bool byTravel) {
    final n = m.nearest;
    final verdict = m.isStandard
        ? '표준 각도 ${csFmt(n.angle)}°와 같습니다.'
        : '표준 각도가 아닙니다. 가장 가까운 ${csFmt(n.angle)}°와 ${csFmt(n.diff.abs())}° 차이입니다.';
    final fit = m.isStandard
        ? null
        : '잰 ${byTravel ? 'Travel' : 'Run'}을 그대로 두고 ${csFmt(n.angle)}°로 꺾으면 높이가 '
              '${csFmt(n.riseError.abs())}mm ${n.riseError < 0 ? '낮아' : '높아'}집니다.';
    return [
      Container(
        key: const Key('am_verdict'),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (m.isStandard ? Colors.green : Colors.orange).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              verdict,
              style: TextStyle(
                color: m.isStandard ? Colors.green.shade800 : Colors.orange.shade900,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            if (fit != null) ...[
              const SizedBox(height: 2),
              Text(fit, style: const TextStyle(color: csSub, fontSize: 11)),
            ],
          ],
        ),
      ),
      if (widget.onUseInOffset != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            '"오프셋 계산"을 누르면 높이 ${csFmt(m.rise)}mm, ${csFmt(n.angle)}°가 들어간 오프셋 계산이 열립니다.',
            key: const Key('am_to_offset_note'),
            style: const TextStyle(color: csSub, fontSize: 11),
          ),
        ),
      CsDetail(label: '빗변 (Travel)', value: '${csFmt(m.travel)} mm'),
      CsDetail(label: '수평 거리 (Run)', value: '${csFmt(m.run)} mm', note: '(배수 ${csFmt(m.multiplier, 3)})'),
      CsDetail(
        label: '축소값 (Shrink)',
        value: '+${csFmt(m.shrink)} mm',
        note: '(직진 거리가 이만큼 줄어듭니다)',
      ),
      const SizedBox(height: 12),
      const Text(
        '표준 각도로 꺾으면 (같은 높이)',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: csSub),
      ),
      const SizedBox(height: 6),
      for (final r in m.rows)
        Container(
          key: Key('am_row_${csFmt(r.angle)}'),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: identical(r, n) ? csTeal.withValues(alpha: 0.12) : null,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 54,
                child: Text(
                  '${csFmt(r.angle)}°',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: identical(r, n) ? csTeal : csInk,
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                ),
              ),
              SizedBox(
                width: 62,
                child: Text(
                  '${_sign(r.diff)}°',
                  style: const TextStyle(color: csSub, fontFamily: 'monospace', fontSize: 12),
                ),
              ),
              Expanded(
                child: Text(
                  'Travel ${csFmt(r.travel, 0)} · Run ${csFmt(r.run, 0)}',
                  style: const TextStyle(color: csInk, fontFamily: 'monospace', fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
    ];
  }
}
