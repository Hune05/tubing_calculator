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
        ),
        const SizedBox(height: 10),
        for (final l in lines) ...[
          _Row(
            line: l,
            isDone: done.contains(l.key),
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

  const _Header({
    required this.summary,
    required this.setMultiplier,
    required this.warning,
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
          const Text(
            '총 절단 길이',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: CuttingColors.textSecondary,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${s.totalMm.toStringAsFixed(1)} mm',
              key: const Key('result_total_mm'),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: CuttingColors.primary,
              ),
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
  final VoidCallback onTap;

  const _Row({required this.line, required this.isDone, required this.onTap});

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
                    Text(
                      line.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: isDone ? grey : CuttingColors.textPrimary,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    Text(
                      line.detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: grey),
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
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isDone ? grey : CuttingColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${line.totalMm.toStringAsFixed(1)} mm',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: isDone ? grey : CuttingColors.primary,
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
