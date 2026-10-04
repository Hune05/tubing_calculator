// 라인 컷팅 입력 화면의 새 부품들: 제조사 칩, 설정 줄(단위·규격·톱날), 아래 고정 요약 바, 처음 안내.
//
// 화면(cutting_main_screen.dart)이 4,000줄이 넘어서 새로 만드는 모양은 여기에 두고, 값과 동작은 모두
// 화면이 넘겨 준다(이 파일은 그리기만 한다). 계산은 cutting_diagram_view.dart의 요약을 그대로 쓴다.
import 'package:flutter/material.dart';

import 'cutting_diagram_view.dart' show DiagramSummary;
import 'cutting_math.dart' show fmtMm;
import 'cutting_theme.dart';

/// 제조사 고르는 칩 한 줄. 예전의 큰 단추 넷과 "메이커 고정" 제목줄을 한 줄로 줄였다.
class CuttingMakerChips extends StatelessWidget {
  final List<String> makers;
  final String selected;
  final ValueChanged<String> onSelected;

  const CuttingMakerChips({
    super.key,
    required this.makers,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: const BoxDecoration(
        color: CuttingColors.surface,
        border: Border(bottom: BorderSide(color: CuttingColors.border)),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Text(
              '제조사',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: CuttingColors.textSecondary,
              ),
            ),
          ),
          for (final m in makers)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Material(
                  color: m == selected
                      ? CuttingColors.primary
                      : CuttingColors.background,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    key: Key('maker_$m'),
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => onSelected(m),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Center(
                        child: Text(
                          m,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            color: m == selected
                                ? Colors.white
                                : CuttingColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 알약 모양 설정 단추(예: 튜브 규격, 톱날). 눌러서 바꾼다.
class CuttingSettingPill extends StatelessWidget {
  final Key? pillKey;
  final Key? labelKey;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool emphasized;

  const CuttingSettingPill({
    super.key,
    this.pillKey,
    this.labelKey,
    required this.icon,
    required this.label,
    required this.onTap,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: emphasized ? CuttingColors.primarySoft : CuttingColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        key: pillKey,
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: emphasized
                  ? CuttingColors.primary.withValues(alpha: 0.5)
                  : CuttingColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: CuttingColors.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  key: labelKey,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: CuttingColors.textPrimary,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_drop_down_rounded,
                size: 18,
                color: CuttingColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 처음 열었을 때(아무것도 안 넣었을 때) 순서를 알려 주는 짧은 글.
class CuttingFirstHint extends StatelessWidget {
  const CuttingFirstHint({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('cut_first_hint'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: CuttingColors.primarySoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        '① 지점마다 부속 고르기  ② 지점 사이 중심 간 거리 넣기  ③ 아래 합계 확인',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: CuttingColors.primary,
          height: 1.35,
        ),
      ),
    );
  }
}

/// 입력·배치도 탭 아래에 붙는 얇은 요약 바(한 줄): 절단 길이 합계, 계산된 구간 수, 문제, "결과 보기".
/// 예전에 입력 탭 아래 요약 줄이 화면을 가린다는 까닭으로 뺐으므로 높이를 한 줄로 줄였다.
class CuttingSummaryBar extends StatelessWidget {
  final DiagramSummary summary;
  final int setMultiplier;
  final VoidCallback onOpenResult;

  const CuttingSummaryBar({
    super.key,
    required this.summary,
    required this.setMultiplier,
    required this.onOpenResult,
  });

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final bool hasAny = s.cutCount > 0;
    final bool multi = setMultiplier > 1;
    final double shown = multi ? s.totalCutMm : s.oneSetCutMm;
    final int problems = s.unreadableCount + s.interferenceCount;
    final notes = <String>[
      '${s.cutCount}구간',
      if (multi) '$setMultiplier세트',
      if (s.emptyCount > 0) '입력 필요 ${s.emptyCount}',
      if (problems > 0) '확인 필요 $problems',
    ];
    return Container(
      key: const Key('cut_summary_bar'),
      padding: const EdgeInsets.fromLTRB(16, 6, 10, 6),
      decoration: const BoxDecoration(
        color: CuttingColors.surface,
        border: Border(top: BorderSide(color: CuttingColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      hasAny ? '${fmtMm(shown)} mm' : '- mm',
                      key: const Key('cut_summary_total'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: hasAny
                            ? CuttingColors.primary
                            : CuttingColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    notes.join(' · '),
                    key: const Key('cut_summary_notes'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: problems > 0
                          ? CuttingColors.danger
                          : CuttingColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const Key('cut_summary_open_result'),
              onPressed: onOpenResult,
              style: FilledButton.styleFrom(
                backgroundColor: CuttingColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                '결과 보기',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 결과 탭의 작은 칩 단추(예: "자른 줄 감추기", "잘랐음 지우기"). 켜진 상태는 틸 바탕.
/// [showLabel]이 거짓이면 아이콘만 보인다(형강 컷팅 결과 탭과 같은 규칙).
class CuttingResultChip extends StatelessWidget {
  final Key chipKey;
  final IconData icon;
  final String label;
  final bool on;
  final bool showLabel;
  final VoidCallback onTap;

  const CuttingResultChip({
    super.key,
    required this.chipKey,
    required this.icon,
    required this.label,
    required this.on,
    required this.onTap,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final fg = on ? Colors.white : Colors.grey.shade700;
    return Tooltip(
      message: label,
      child: InkWell(
        key: chipKey,
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: showLabel
              ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
              : const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: on ? CuttingColors.primary : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: showLabel ? 16 : 20, color: fg),
              if (showLabel) ...[
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
