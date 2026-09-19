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
//
// 🚀 [형강 컷팅 - 규격별 분리] 튜브는 프로젝트 전체가 같은 원자재(한 종류
// 튜브)라 모든 구간을 섞어서 최적화해도 됐지만, 형강은 프로젝트 안에
// 앵글/찬넬 등 서로 다른 규격이 섞일 수 있다 - 다른 규격은 물리적으로
// 같은 원자재에서 나올 수 없으니 한 원자재(본) 안에 섞어 배치하면 실제로
// 불가능한 지시서가 나온다. [groupedPieces]를 넘기면 규격(라벨)별로 각각
// 독립적으로 최적화하고, 결과도 규격별 섹션으로 나눠 보여준다. 넘기지
// 않으면(튜브처럼 규격이 하나뿐이면) 기존처럼 구분 없이 하나로 보여준다.
Future<void> showCuttingOptimizationSheet(
  BuildContext context, {
  List<double> pieces = const [],
  Map<String, List<double>>? groupedPieces,
  required double initialStockLength,
  double kerf = 0.0,
  String title = "재단 최적화 (원자재 소요 계산)",
  ValueChanged<double>? onStockLengthChanged,
}) async {
  final Map<String, List<double>> groups =
      (groupedPieces != null && groupedPieces.isNotEmpty)
      ? groupedPieces
      : {'': pieces};
  final bool isGroupedView = groups.length > 1 || !groups.containsKey('');

  if (groups.values.every((p) => p.isEmpty)) {
    showCuttingSnack(context, "치수를 먼저 입력하십시오.", isError: true);
    return;
  }

  final ctrl = TextEditingController(
    text: initialStockLength.toStringAsFixed(0),
  );
  Map<String, CuttingOptimizationResult> results = {
    for (final e in groups.entries)
      e.key: optimizeCutting(
        pieces: e.value,
        stockLength: initialStockLength,
        kerf: kerf,
      ),
  };

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
            results = {
              for (final e in groups.entries)
                e.key: optimizeCutting(
                  pieces: e.value,
                  stockLength: parsed,
                  kerf: kerf,
                ),
            };
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

        final int totalBarCount = results.values.fold(
          0,
          (sum, r) => sum + r.barCount,
        );
        final double totalWaste = results.values.fold(
          0.0,
          (sum, r) => sum + r.totalWaste,
        );
        final double totalUsed = results.values.fold(
          0.0,
          (sum, r) => sum + r.totalUsed,
        );
        final double totalStock = results.values.fold(
          0.0,
          (sum, r) => sum + r.totalStock,
        );
        final int totalOversized = results.values.fold(
          0,
          (sum, r) => sum + r.oversizedPieces.length,
        );

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
            if (isGroupedView) ...[
              const SizedBox(height: 8),
              Text(
                "규격이 다르면 같은 원자재를 함께 쓸 수 없어 규격별로 따로 계산합니다.",
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
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
                  isGroupedView ? "전체 필요 원자재" : "필요 원자재",
                  "$totalBarCount본",
                ),
                const SizedBox(width: 8),
                _buildOptStat(
                  Icons.delete_sweep_outlined,
                  isGroupedView ? "전체 로스" : "총 로스",
                  "${totalWaste.toStringAsFixed(0)}mm",
                  accent: CuttingColors.warning,
                ),
                const SizedBox(width: 8),
                _buildOptStat(
                  Icons.percent_rounded,
                  isGroupedView ? "전체 사용률" : "사용률",
                  totalStock > 0
                      ? "${(totalUsed / totalStock * 100).toStringAsFixed(1)}%"
                      : "-",
                  accent: CuttingColors.success,
                ),
              ],
            ),
            if (isGroupedView) ...[
              const SizedBox(height: 4),
              Text(
                "규격별 상세 수치는 아래 각 섹션에서 확인하십시오.",
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
            if (totalOversized > 0) ...[
              const SizedBox(height: 10),
              Text(
                "⚠ 원자재보다 긴 구간 $totalOversized개는 계산에서 제외됨",
                style: const TextStyle(
                  color: CuttingColors.danger,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        );

        final List<Widget> barWidgets = [];
        if (!isGroupedView) {
          final bars = results['']!.bars;
          for (int i = 0; i < bars.length; i++) {
            barWidgets.add(_buildOptBarCard(bars[i], i));
          }
        } else {
          for (final entry in groups.entries) {
            final r = results[entry.key]!;
            barWidgets.add(_buildGroupSummaryHeader(entry.key, r));
            for (int i = 0; i < r.bars.length; i++) {
              barWidgets.add(_buildOptBarCard(r.bars[i], i));
            }
            if (r.bars.isEmpty) {
              barWidgets.add(
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    "배치할 원자재가 없습니다.",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ),
              );
            }
          }
        }

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

        Widget barsList(ScrollController controller) =>
            ListView(controller: controller, children: barWidgets);

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
                                      if (!isGroupedView) barsHeader(),
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
                                if (!isGroupedView) barsHeader(),
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

// 🚀 [규격별 상세 수치] 상단 요약은 전체 규격을 합산한 값이라, 규격별로
// "본수는 이만큼인데 로스/사용률은 어떤지"를 알 수 없었다. 각 규격
// 섹션 머리에 그 규격만의 본수·로스·사용률을 작은 배지로 보여준다.
Widget _buildGroupSummaryHeader(String label, CuttingOptimizationResult r) {
  final double usageRatio = r.totalStock > 0
      ? (r.totalUsed / r.totalStock * 100)
      : 0.0;
  final bool highWaste =
      r.totalStock > 0 && (r.totalWaste / r.totalStock) > 0.15;

  return Container(
    margin: const EdgeInsets.only(top: 10, bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: CuttingColors.primarySoft,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.isEmpty ? "규격 미지정" : label,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: CuttingColors.primaryDark,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            _miniStat(Icons.inventory_2_outlined, "${r.barCount}본"),
            _miniStat(
              Icons.delete_sweep_outlined,
              "로스 ${r.totalWaste.toStringAsFixed(0)}mm",
              color: highWaste ? CuttingColors.warning : null,
            ),
            _miniStat(
              Icons.percent_rounded,
              "사용률 ${usageRatio.toStringAsFixed(1)}%",
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _miniStat(IconData icon, String text, {Color? color}) {
  final Color c = color ?? CuttingColors.primaryDark;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: c),
      const SizedBox(width: 4),
      Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c),
      ),
    ],
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
