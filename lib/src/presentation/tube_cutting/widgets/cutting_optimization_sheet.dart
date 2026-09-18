import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../cutting_optimizer.dart';
import '../cutting_theme.dart';

// 🚀 [형강 컷팅 신규 기능 대비 리팩터링] 원래 이 "재단 최적화" 시트는
// CuttingMainScreen 안에 300줄 가까이 박혀 있어서, 튜브 라인이 아니라
// 그냥 "길이 목록"만 있는 다른 화면(형강/찬넬/앵글 컷팅)에서는 똑같은
// 계산·화면을 다시 통째로 베껴야 했다. 여기로 빼서 "필요한 절단 길이
// 목록 + 원자재 기준 길이"만 넘기면 어떤 화면에서든 똑같은 다중 규격
// 조합 최적화(FFD 빈 패킹 - cutting_optimizer.dart) 결과를 보여주도록
// 공용화했다. 원자재 기준 길이가 바뀌면 [onStockLengthChanged]로 호출한
// 쪽에 알려줘서, 화면마다 다른 저장 방식(SharedPreferences vs Firestore)에
// 맡긴다.
Future<void> showCuttingOptimizationSheet(
  BuildContext context, {
  required List<double> pieces,
  required double initialStockLength,
  double kerf = 0.0,
  String title = "재단 최적화 (원자재 소요 계산)",
  ValueChanged<double>? onStockLengthChanged,
}) async {
  if (pieces.isEmpty) {
    showCuttingSnack(context, "치수를 먼저 입력하세요.", isError: true);
    return;
  }

  final ctrl = TextEditingController(
    text: initialStockLength.toStringAsFixed(0),
  );
  CuttingOptimizationResult result = optimizeCutting(
    pieces: pieces,
    stockLength: initialStockLength,
    kerf: kerf,
  );

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        void recalc([double? presetValue]) {
          final parsed = presetValue ?? double.tryParse(ctrl.text);
          if (parsed == null || parsed <= 0) return;
          HapticFeedback.selectionClick();
          ctrl.text = parsed.toStringAsFixed(0);
          setSheetState(() {
            result = optimizeCutting(
              pieces: pieces,
              stockLength: parsed,
              kerf: kerf,
            );
          });
          onStockLengthChanged?.call(parsed);
        }

        Widget presetChip(String label, double value) {
          return InkWell(
            onTap: () => recalc(value),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          );
        }

        final inputAndStats = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onSubmitted: (_) => recalc(),
                    decoration: InputDecoration(
                      labelText: "원자재 기준 길이",
                      suffixText: "mm",
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CuttingColors.primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => recalc(),
                  child: const Text(
                    "계산",
                    style: TextStyle(
                      color: CuttingColors.surface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                presetChip("3m", 3000),
                presetChip("6m", 6000),
                presetChip("8m", 8000),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildOptStat(
                  Icons.inventory_2_outlined,
                  "필요 원자재",
                  "${result.barCount}본",
                ),
                const SizedBox(width: 8),
                _buildOptStat(
                  Icons.delete_sweep_outlined,
                  "총 로스",
                  "${result.totalWaste.toStringAsFixed(0)}mm",
                  accent: CuttingColors.warning,
                ),
                const SizedBox(width: 8),
                _buildOptStat(
                  Icons.percent_rounded,
                  "사용률",
                  result.totalStock > 0
                      ? "${(result.totalUsed / result.totalStock * 100).toStringAsFixed(1)}%"
                      : "-",
                  accent: CuttingColors.success,
                ),
              ],
            ),
            if (result.oversizedPieces.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                "⚠ 원자재보다 긴 구간 ${result.oversizedPieces.length}개는 계산에서 제외됨",
                style: const TextStyle(
                  color: CuttingColors.danger,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        );

        Widget barsHeader() => const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            "원자재별 배치",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: CuttingColors.textPrimary,
            ),
          ),
        );

        Widget barsList(ScrollController controller) => ListView.builder(
          controller: controller,
          itemCount: result.bars.length,
          itemBuilder: (context, i) => _buildOptBarCard(result.bars[i], i),
        );

        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (ctx, scrollController) {
            final bool isWide = MediaQuery.of(ctx).size.width >= 700;
            return Container(
              decoration: const BoxDecoration(
                color: CuttingColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                    child: Row(
                      children: [
                        cuttingDialogIcon(Icons.view_column_outlined),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: CuttingColors.textPrimary,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.grey,
                          ),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 320,
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(20),
                                  child: inputAndStats,
                                ),
                              ),
                              const VerticalDivider(width: 1),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      barsHeader(),
                                      Expanded(
                                        child: barsList(scrollController),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                inputAndStats,
                                const SizedBox(height: 16),
                                barsHeader(),
                                Expanded(child: barsList(scrollController)),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ),
  );
}

Widget _buildOptStat(
  IconData icon,
  String label,
  String value, {
  Color? accent,
}) {
  final Color c = accent ?? CuttingColors.primary;
  return Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: c, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: c,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildOptBarCard(StockBarPlan bar, int index) {
  final double ratio = bar.stockLength > 0
      ? (bar.usedLength / bar.stockLength).clamp(0.0, 1.0)
      : 0.0;
  final bool highWaste = bar.wasteLength > bar.stockLength * 0.15;
  final Color accent = highWaste
      ? CuttingColors.warning
      : CuttingColors.primary;

  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: CuttingColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: CuttingColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: CuttingColors.primaryDark,
                shape: BoxShape.circle,
              ),
              child: Text(
                "${index + 1}",
                style: const TextStyle(
                  color: CuttingColors.surface,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                bar.pieces
                    .map((p) => "${p.toStringAsFixed(0)}mm")
                    .join("  +  "),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: CuttingColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 10,
            backgroundColor: Colors.grey.shade200,
            color: accent,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "사용 ${bar.usedLength.toStringAsFixed(0)}mm",
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            Text(
              "잔여 ${bar.wasteLength.toStringAsFixed(0)}mm",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: accent,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
