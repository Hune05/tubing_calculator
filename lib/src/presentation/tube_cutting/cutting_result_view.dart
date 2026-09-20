import 'package:flutter/material.dart';

import 'cutting_result_logic.dart';
import 'cutting_theme.dart';

// 튜브 컷팅 "결과" 탭의 목록. 맨 위에 총계와 진행 상황, 그 아래 자를 길이를 한 줄씩(눌러서 "잘랐음"
// 표시), 맨 아래에 필요한 부속을 보여 준다. 계산은 cutting_result_logic.dart가 하고 여기서는 그리기만 한다.
class CuttingResultView extends StatelessWidget {
  final List<ResultLine> lines;
  final ResultSummary summary;
  final List<FittingOrder> orders;
  final Set<String> done;
  final ValueChanged<String> onToggle;
  final int setMultiplier;
  // 계산에서 빠진 구간 안내(간섭·못 읽음). 없으면 빈 글자.
  final String warning;
  // 표시할 줄이 없을 때 보여 줄 글과 오류 여부.
  final String emptyMessage;
  final bool emptyIsError;
  // 튜브 규격: 사용자가 지정한 값(없으면 빈 글자 = 부속 기준 자동)과 고르는 창을 여는 동작.
  final String tubeSpec;
  final VoidCallback? onPickSpec;

  const CuttingResultView({
    super.key,
    required this.lines,
    required this.summary,
    required this.orders,
    required this.done,
    required this.onToggle,
    this.setMultiplier = 1,
    this.warning = '',
    this.emptyMessage = '치수를 입력하십시오.',
    this.emptyIsError = false,
    this.tubeSpec = '',
    this.onPickSpec,
  });

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: TextStyle(
            color: emptyIsError ? CuttingColors.danger : Colors.grey.shade600,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _Header(
          summary: summary,
          setMultiplier: setMultiplier,
          warning: warning,
          specs: specTotals(lines),
          tubeSpec: tubeSpec,
          onPickSpec: onPickSpec,
          unknownSpecLines: unknownSpecLineCount(lines),
        ),
        const SizedBox(height: 10),
        for (final l in lines) ...[
          _Row(
            line: l,
            isDone: done.contains(l.key),
            showUnknownSpec: lines.any((e) => e.spec.isNotEmpty),
            onTap: () => onToggle(l.key),
          ),
          const SizedBox(height: 6),
        ],
        if (orders.isNotEmpty) ...[
          const SizedBox(height: 10),
          _Orders(orders: orders),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final ResultSummary summary;
  final int setMultiplier;
  final String warning;
  final List<SpecTotal> specs;
  final String tubeSpec;
  final VoidCallback? onPickSpec;
  final int unknownSpecLines;

  const _Header({
    required this.summary,
    required this.setMultiplier,
    required this.warning,
    this.specs = const [],
    this.tubeSpec = '',
    this.onPickSpec,
    this.unknownSpecLines = 0,
  });

  @override
  Widget build(BuildContext context) {
    final s = summary;
    return Container(
      key: const Key('result_header'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: CuttingColors.primarySoft.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CuttingColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 자를 튜브의 규격(제원). 부속에서 알 수 있으면 자동으로 채우고, 모르면 여기서 지정한다.
          if (onPickSpec != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                key: const Key('result_spec_picker'),
                borderRadius: BorderRadius.circular(8),
                onTap: onPickSpec,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: CuttingColors.primary.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.straighten_rounded,
                        size: 16,
                        color: CuttingColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          tubeSpec.isEmpty
                              ? '튜브 규격: 부속 기준(자동)'
                              : '튜브 규격: $tubeSpec',
                          key: const Key('result_spec_label'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: CuttingColors.primary,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_drop_down_rounded,
                        color: CuttingColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // 규격을 모르는 줄이 있으면 저장하기 전에 눈에 띄게 알려 준다(누르면 규격 고르는 창).
          if (unknownSpecLines > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                key: const Key('result_spec_warning'),
                borderRadius: BorderRadius.circular(8),
                onTap: onPickSpec,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: CuttingColors.warningSoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: CuttingColors.warning.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: CuttingColors.warning,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '규격 없는 줄 $unknownSpecLines개 · 눌러서 지정',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: CuttingColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // 세트가 하나뿐일 때만 "총 절단 길이" 제목을 둔다(여럿이면 큰 숫자가 "1세트 …"라서 제목이 필요 없다).
          if (setMultiplier <= 1)
            const Text(
              '총 절단 길이',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: CuttingColors.textSecondary,
              ),
            ),
          // 세트가 둘 이상이면 큰 숫자는 1세트 길이(세트를 바꿔도 변하지 않는다)이고, 아래에 세트 수를
          // 곱한 합계를 식으로 보여 준다.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              setMultiplier > 1
                  ? '1세트 ${(s.totalMm / setMultiplier).toStringAsFixed(1)} mm'
                  : '${s.totalMm.toStringAsFixed(1)} mm',
              key: setMultiplier > 1
                  ? const Key('result_set_mm')
                  : const Key('result_total_mm'),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: CuttingColors.primary,
              ),
            ),
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [
              if (setMultiplier > 1)
                Text(
                  '× $setMultiplier세트 = ${s.totalMm.toStringAsFixed(1)} mm',
                  key: const Key('result_total_mm'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: CuttingColors.textPrimary,
                  ),
                ),
              Text(
                '총 ${s.totalPieces}개 · ${s.lineCount}종류'
                '${setMultiplier > 1 ? ' · $setMultiplier세트' : ''}',
                key: const Key('result_counts'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: CuttingColors.textPrimary,
                ),
              ),
            ],
          ),
          // 규격이 둘 이상이면 규격별 합계를 보여 준다(자를 튜브가 달라서 따로 준비해야 한다).
          if (specs.length > 1 ||
              (specs.length == 1 && specs.first.spec.isNotEmpty))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                specs
                    .map(
                      (e) =>
                          '${e.spec.isEmpty ? '규격 미지정' : e.spec} ${e.mm.toStringAsFixed(1)}mm (${e.pieces}개)',
                    )
                    .join('  ·  '),
                key: const Key('result_spec_totals'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: CuttingColors.textPrimary,
                ),
              ),
            ),
          // 진행 줄은 처음부터 자리를 잡아 둔다 — 줄을 눌러 표시할 때 목록이 아래로 밀려
          // 다음 줄을 잘못 누르는 일이 없게 한다.
          ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: s.progress,
                minHeight: 8,
                backgroundColor: Colors.white,
                color: s.allDone
                    ? CuttingColors.success
                    : CuttingColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              s.allDone
                  ? '모두 잘랐습니다. 저장하십시오.'
                  : '잘랐음 ${s.donePieces}/${s.totalPieces}개',
              key: const Key('result_progress'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: s.allDone
                    ? CuttingColors.success
                    : CuttingColors.textSecondary,
              ),
            ),
          ],
          if (warning.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              warning,
              key: const Key('result_warning'),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: CuttingColors.danger,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final ResultLine line;
  final bool isDone;
  final bool showUnknownSpec; // 다른 줄은 규격이 있는데 이 줄만 모를 때 "규격 미지정"을 보여 준다
  final VoidCallback onTap;

  const _Row({
    required this.line,
    required this.isDone,
    required this.onTap,
    this.showUnknownSpec = false,
  });

  @override
  Widget build(BuildContext context) {
    final grey = Colors.grey.shade500;
    return Material(
      color: isDone ? Colors.grey.shade100 : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        key: Key('result_row_${line.key}'),
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDone
                  ? CuttingColors.success.withValues(alpha: 0.5)
                  : Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isDone
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                key: Key('result_check_${line.key}'),
                size: 28,
                color: isDone ? CuttingColors.success : Colors.grey.shade400,
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 큰 글씨는 늘 "1개 절단 값"이다(세트 수를 바꿔도 변하지 않는다). 묶은 줄의 제목은 이미 그 값이고,
                    // 묶지 않은 줄은 제목이 "PT1 → PT2"라서 값으로 바꾸고 구간 이름은 아래 줄로 내린다.
                    Text(
                      line.grouped
                          ? line.title
                          : '${line.cutMm.toStringAsFixed(1)} mm',
                      key: Key('result_piece_${line.key}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: isDone ? grey : CuttingColors.textPrimary,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    // 규격 칩은 제목 아래 줄에 둔다(제목이 잘리지 않게).
                    Row(
                      children: [
                        if (line.spec.isNotEmpty || showUnknownSpec)
                          Flexible(
                            flex: 2,
                            child: Container(
                              key: Key('result_spec_${line.key}'),
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: line.spec.isEmpty
                                    ? Colors.grey.shade200
                                    : CuttingColors.primary.withValues(
                                        alpha: isDone ? 0.06 : 0.12,
                                      ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                line.spec.isEmpty ? '규격 미지정' : line.spec,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: line.spec.isEmpty || isDone
                                      ? grey
                                      : CuttingColors.primary,
                                ),
                              ),
                            ),
                          ),
                        Flexible(
                          flex: 3,
                          child: Text(
                            line.grouped ? line.detail : line.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: grey),
                          ),
                        ),
                      ],
                    ),
                    // 개수가 어디서 나왔는지("구간 2개 × 3세트 = 6개").
                    if (line.countFormula.isNotEmpty)
                      Text(
                        line.countFormula,
                        key: Key('result_formula_${line.key}'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: grey,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 글자가 아주 크거나 숫자가 길면 오른쪽 숫자가 줄어들어 한 줄에 들어오게 한다.
              Flexible(
                flex: 2,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '× ${line.count}개',
                        key: Key('result_count_${line.key}'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isDone ? grey : CuttingColors.textPrimary,
                        ),
                      ),
                      Text(
                        '= ${line.totalMm.toStringAsFixed(1)} mm',
                        key: Key('result_line_total_${line.key}'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isDone ? grey : CuttingColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Orders extends StatelessWidget {
  final List<FittingOrder> orders;
  const _Orders({required this.orders});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('result_orders'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '필요한 부속',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: CuttingColors.textPrimary,
            ),
          ),
          for (final o in orders)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          o.label,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: CuttingColors.textPrimary,
                          ),
                        ),
                        if (o.maker.isNotEmpty)
                          Text(
                            o.maker == 'CUSTOM' ? '직접 입력' : o.maker,
                            style: const TextStyle(
                              fontSize: 11,
                              color: CuttingColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '× ${o.qty}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: CuttingColors.primary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
