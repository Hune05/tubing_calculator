import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/presentation/common/app_icons.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/inventory/pages/mobile_inventory_logs_page.dart';

import '../cutting_leftover_log.dart';
import '../cutting_leftovers.dart';
import '../cutting_optimizer.dart';
import '../cutting_stock_deduct.dart';
import '../cutting_theme.dart';
import 'leftover_log_page.dart';

// 🚀 [형강 컷팅 신규 기능 대비 리팩터링] 원래 이 "재단 계획" 시트는
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
  String title = "재단 계획 (원자재 몇 본 드는지)",
  ValueChanged<double>? onStockLengthChanged,
  // 여러 길이 섞어 쓰기 설정을 저장할 곳. 없으면 저장하지 않는다.
  String? mixPrefsKey,
  // "잘랐습니다(잔재 저장)"를 눌러 저장이 끝난 뒤 부른다(호출한 화면이 결과의 "잘랐음" 표시를 맞추는 데 쓴다).
  VoidCallback? onLeftoversSaved,
  // 같은 창에서 방금 한 저장을 "되돌리기"로 취소했을 때 부른다(호출한 화면이 잘랐음 표시를 원래대로 돌리는 데 쓴다).
  VoidCallback? onLeftoversSaveUndone,
  // 이 결과의 잔재를 이미 저장했으면 true — 저장 버튼 자리에 "저장했습니다"를 보여 같은 컷팅을 두 번 저장하지 않게 한다.
  // (기준 길이·잔재 사용 설정을 바꿔 다시 계산하면 다른 컷팅이 되므로 다시 저장할 수 있다.)
  bool leftoversAlreadySaved = false,
  // 잔재 기록에 적을 작업 이름("튜브 컷팅 · 루마" 등).
  String leftoverLogSource = '',
  // 새 원자재를 창고 재고에서 뺄 수 있게 할 때 넘긴다(튜브·형강). 아직 안 뺀
  // 규격별 새 원자재(본마다 길이)를 받아서 빼고, 실제로 뺀 것만 돌려준다
  // (재고에 이름이 없어 못 뺀 규격은 빼고). 하나도 못 뺐으면 null이나 빈 것.
  Future<BarsBySpec?> Function(BarsBySpec bars)? onDeductStock,
  // 이 작업에서 이미 재고에서 뺀 본. 지금 계산과 견줘 남은 것만 뺄 수 있게 해서
  // 창을 닫았다 다시 열어도 같은 것을 두 번 빼지 않는다.
  BarsBySpec deductedBars = const {},
  // 빼거나 되돌린 뒤 이제까지 뺀 본 전체를 화면에 돌려준다(화면이 서버에 적어 둔다).
  void Function(BarsBySpec deducted)? onStockDeducted,
  // 잘못 뺐을 때 이제까지 뺀 것을 도로 넣는다. 돌려놓았으면 true.
  Future<bool> Function(BarsBySpec bars)? onUndoDeductStock,
  // 이 작업에 쓴 자재 기록을 볼 때 걸러 쓸 작업 이름(비우면 단추를 안 보인다).
  String jobLogName = '',
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
  // 잔재(이전에 자르고 남겨 둔 것). 켜 두면 같은 규격의 잔재부터 먼저 쓴다.
  var leftovers = await loadLeftovers();
  if (!context.mounted) return;
  bool useLeftovers = true;
  bool leftoversSaved = leftoversAlreadySaved;
  bool leftoversSaving = false;
  // 이 작업에서 이미 재고에서 뺀 본(같은 것을 두 번 빼지 않게). 지금 계산과 견줘
  // 남은 본만 뺄 수 있다. 기준 길이·섞어 쓰기를 바꿔 본이 늘면 는 만큼만 뺀다.
  BarsBySpec deducted = {
    for (final e in deductedBars.entries) e.key: [...e.value],
  };
  bool deducting = false;
  // 이 창에서 방금 저장한 것(되돌리기용): 쓴 잔재와 새로 더한 잔재. 저장하지 않았거나
  // 되돌린 뒤에는 null. 되돌릴 때도 이것만 도로 넣고 빼서, 그사이 다른 곳에서 바꾼
  // 잔재를 건드리지 않는다.
  ({List<Leftover> used, List<Leftover> added})? lastSaved;
  // 방금 저장하면서 적은 잔재 기록의 id(되돌리기에서 그 기록을 지운다).
  String? lastLogId;
  double stockNow = initialStockLength;

  // 여러 길이 섞어 쓰기: 켜면 고른 길이들만 섞어서 계산한다(위 기준 길이는 쓰지 않는다).
  bool mix = false;
  Set<double> mixSel = {3000, 6000, 8000};
  if (mixPrefsKey != null) {
    try {
      final saved = (await SharedPreferences.getInstance()).getStringList(
        mixPrefsKey,
      );
      final parsed = {
        for (final v in saved ?? const <String>[])
          if (double.tryParse(v) != null) double.parse(v),
      };
      if (parsed.isNotEmpty) {
        mix = true;
        mixSel = parsed;
      }
    } catch (_) {}
    if (!context.mounted) return;
  }
  Future<void> saveMix() async {
    if (mixPrefsKey == null) return;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(mixPrefsKey, [
        if (mix)
          for (final v in mixSel) v.toStringAsFixed(0),
      ]);
    } catch (_) {}
  }

  Map<String, CuttingOptimizationResult> compute(double stock) => {
    for (final e in groups.entries)
      e.key: (mix && mixSel.isNotEmpty)
          ? optimizeCuttingMixed(
              pieces: e.value,
              stockLengths: mixSel.toList(),
              kerf: kerf,
              leftovers: useLeftovers
                  ? [
                      for (final l in leftovers)
                        if (l.label == e.key) l.length,
                    ]
                  : const [],
            )
          : optimizeCutting(
              pieces: e.value,
              stockLength: stock,
              kerf: kerf,
              leftovers: useLeftovers
                  ? [
                      for (final l in leftovers)
                        if (l.label == e.key) l.length,
                    ]
                  : const [],
            ),
  };
  Map<String, CuttingOptimizationResult> results = compute(stockNow);

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
            stockNow = parsed;
            leftoversSaved = false;
            results = compute(parsed);
          });
          onStockLengthChanged?.call(parsed);
        }

        Widget presetChip(String label, double value) {
          final bool picked = mix && mixSel.contains(value);
          return InkWell(
            onTap: () {
              if (!mix) {
                recalc(value);
                return;
              }
              // 섞어 쓰기: 눌러서 켜고 끈다(마지막 하나는 끌 수 없다).
              setSheetState(() {
                if (mixSel.contains(value)) {
                  if (mixSel.length > 1) mixSel.remove(value);
                } else {
                  mixSel.add(value);
                }
                leftoversSaved = false;
                results = compute(stockNow);
              });
              saveMix();
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: picked ? CuttingColors.primary : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: picked ? CuttingColors.surface : Colors.grey.shade700,
                ),
              ),
            ),
          );
        }

        // 규격별 새 원자재(본마다 길이). 재고에서 뺄 때 쓴다. 잔재에서 자른 것은 들어가지 않는다.
        final BarsBySpec needBars = {
          for (final e in results.entries)
            if (e.value.barCount > 0)
              e.key: [for (final b in e.value.bars) b.stockLength],
        };
        final BarsBySpec toDeduct = barsStillToDeduct(needBars, deducted);

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
                    style: const TextStyle(
                      color: CuttingColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      labelText: "원자재 기준 길이",
                      labelStyle: const TextStyle(
                        color: CuttingColors.textSecondary,
                      ),
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
            _tealTheme(
              context,
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text(
                  "여러 길이 섞어 쓰기",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  mix
                      ? "위에서 고른 길이만 섞어서, 원자재를 가장 아끼는 조합으로 계산합니다."
                      : "켜면 3m·6m·8m 중 갖고 있는 길이를 골라 섞어서 계산합니다.",
                  style: const TextStyle(fontSize: 11),
                ),
                value: mix,
                activeThumbColor: CuttingColors.primary,
                onChanged: (v) {
                  setSheetState(() {
                    mix = v;
                    leftoversSaved = false;
                    results = compute(stockNow);
                  });
                  saveMix();
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildOptStat(
                  AppGlyph.rawBars,
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
                "규격별 값은 아래에 규격마다 따로 나옵니다.",
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
            if (totalOversized > 0) ...[
              const SizedBox(height: 10),
              Text(
                "원자재보다 긴 구간 $totalOversized개는 계산에서 뺐습니다.",
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
        barWidgets.add(
          _buildLeftoverCard(
            leftovers: leftovers,
            useLeftovers: useLeftovers,
            usedCount: results.values.fold(
              0,
              (sum, r) => sum + r.leftoverBars.length,
            ),
            savedBars: results.values.fold(0, (sum, r) => sum + r.savedBars),
            saved: leftoversSaved,
            remainingBars: barCountOf(toDeduct),
            anyDeducted: deducted.isNotEmpty,
            onDeduct: onDeductStock == null
                ? null
                : () async {
                    if (deducting || toDeduct.isEmpty) return;
                    deducting = true;
                    try {
                      final got = await onDeductStock(toDeduct);
                      if (got != null && got.isNotEmpty) {
                        setSheetState(() => deducted = addBars(deducted, got));
                        onStockDeducted?.call(deducted);
                      }
                    } finally {
                      deducting = false;
                    }
                  },
            jobLogName: jobLogName,
            onUndoDeductStock: onUndoDeductStock == null || deducted.isEmpty
                ? null
                : () async {
                    final ok = await onUndoDeductStock(deducted);
                    if (ok) {
                      setSheetState(() => deducted = {});
                      onStockDeducted?.call(const {});
                    }
                  },
            onToggle: (v) => setSheetState(() {
              useLeftovers = v;
              leftoversSaved = false;
              results = compute(stockNow);
            }),
            onSave: () async {
              // 통신이 느릴 때 두 번 누르면 잔재가 두 번 빠지고 두 번 더해졌다.
              if (leftoversSaving || leftoversSaved) return;
              leftoversSaving = true;
              // 계획에서 쓴 잔재를 목록의 잔재 한 개씩에 맞춘다(이름표로 그것만 뺀다).
              final used = pickLeftovers(leftovers, [
                for (final e in results.entries)
                  for (final b in e.value.leftoverBars)
                    Leftover(e.key, b.stockLength),
              ]);
              final added = await changeLeftovers(
                used: used,
                added: [
                  for (final e in results.entries)
                    for (final len in e.value.keepableScraps())
                      Leftover(e.key, len),
                ],
              );
              lastSaved = (used: used, added: added);
              leftovers = applyLeftoverChange(
                leftovers,
                used: used,
                added: added,
              );
              lastLogId = await appendLeftoverLog(
                source: leftoverLogSource,
                used: used,
                added: added,
              );
              onLeftoversSaved?.call();
              leftoversSaving = false;
              setSheetState(() => leftoversSaved = true);
              if (ctx.mounted) {
                showCuttingSnack(
                  ctx,
                  "잔재를 저장했습니다. 이번에 쓴 잔재 ${used.length}개는 빼고, 새 잔재 ${added.length}개를 더했습니다.",
                );
              }
            },
            onUndo: lastSaved == null
                ? null
                : () async {
                    final back = lastSaved!;
                    lastSaved = null;
                    // 더했던 잔재를 빼고 썼던 잔재를 도로 넣는다(같은 이름표로).
                    await leftoverStore.change(
                      used: back.added,
                      added: back.used,
                    );
                    leftovers = applyLeftoverChange(
                      leftovers,
                      used: back.added,
                      added: back.used,
                    );
                    if (lastLogId != null) await removeLeftoverLog(lastLogId!);
                    lastLogId = null;
                    onLeftoversSaveUndone?.call();
                    setSheetState(() {
                      leftoversSaved = false;
                      results = compute(stockNow);
                    });
                    if (ctx.mounted) {
                      showCuttingSnack(ctx, "저장을 되돌렸습니다.");
                    }
                  },
            onLog: () => Navigator.of(
              ctx,
            ).push(MaterialPageRoute(builder: (_) => const LeftoverLogPage())),
            onManage: () async {
              final changed = await _manageLeftovers(
                ctx,
                leftovers,
                groups.keys.toList(),
              );
              if (changed != null) {
                // 지우거나 더한 것만 적는다(통째로 덮으면 다른 곳에서 바꾼 잔재가 사라진다).
                final d = diffLeftovers(leftovers, changed);
                final added = await changeLeftovers(
                  used: d.removed,
                  added: d.added,
                );
                leftovers = applyLeftoverChange(
                  leftovers,
                  used: d.removed,
                  added: added,
                );
                setSheetState(() {
                  leftoversSaved = false;
                  results = compute(stockNow);
                });
              }
            },
          ),
        );
        if (!isGroupedView) {
          final r = results['']!;
          for (int i = 0; i < r.leftoverBars.length; i++) {
            barWidgets.add(
              _buildOptBarCard(
                r.leftoverBars[i],
                i,
                showLength: mix,
                kerf: kerf,
              ),
            );
          }
          for (int i = 0; i < r.bars.length; i++) {
            barWidgets.add(
              _buildOptBarCard(r.bars[i], i, showLength: mix, kerf: kerf),
            );
          }
        } else {
          for (final entry in groups.entries) {
            final r = results[entry.key]!;
            barWidgets.add(_buildGroupSummaryHeader(entry.key, r));
            for (int i = 0; i < r.leftoverBars.length; i++) {
              barWidgets.add(
                _buildOptBarCard(
                  r.leftoverBars[i],
                  i,
                  showLength: mix,
                  kerf: kerf,
                ),
              );
            }
            for (int i = 0; i < r.bars.length; i++) {
              barWidgets.add(
                _buildOptBarCard(r.bars[i], i, showLength: mix, kerf: kerf),
              );
            }
            if (r.bars.isEmpty && r.leftoverBars.isEmpty) {
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
                        : ListView(
                            // 좁은 화면(폰)에서는 위쪽 입력·요약도 배치 목록과 함께 밀려 올라가게 한다
                            // (글자가 크거나 화면이 작으면 위쪽이 고정돼 목록이 안 보이는 문제가 있었다).
                            controller: scrollController,
                            padding: const EdgeInsets.all(20),
                            children: [
                              inputAndStats,
                              const SizedBox(height: 16),
                              if (!isGroupedView) barsHeader(),
                              ...barWidgets,
                            ],
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

Widget _buildOptStat(Object icon, String label, String value, {Color? accent}) {
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
          anyIcon(icon, color: c, size: 18),
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
            _miniStat(AppGlyph.rawBars, "${r.barCount}본"),
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

Widget _miniStat(Object icon, String text, {Color? color}) {
  final Color c = color ?? CuttingColors.primaryDark;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      anyIcon(icon, size: 13, color: c),
      const SizedBox(width: 4),
      Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c),
      ),
    ],
  );
}

Widget _buildOptBarCard(
  StockBarPlan bar,
  int index, {
  bool showLength = false,
  double kerf = 0.0,
}) {
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
                bar.isLeftover ? "잔" : "${index + 1}",
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
            Flexible(
              child: Text(
                bar.isLeftover
                    ? "잔재 ${bar.stockLength.toStringAsFixed(0)}mm · 사용 ${bar.usedLength.toStringAsFixed(0)}mm"
                    : showLength
                    ? "${bar.stockLength.toStringAsFixed(0)}mm 원자재 · 사용 ${bar.usedLength.toStringAsFixed(0)}mm"
                    : "사용 ${bar.usedLength.toStringAsFixed(0)}mm",
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ),
            Text(
              // 🚀 [고침] 톱날 손실을 빼지 않아 PDF·저장되는 잔재(994)와 달리
              // 1000으로 보였다. 저장·PDF와 같은 값을 보인다.
              "잔여 ${bar.remainderWithKerf(kerf).toStringAsFixed(0)}mm",
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

// 잔재 카드: 쓸지 말지, 이번 계산대로 잘랐을 때 저장, 목록 관리.
// 이 앱 기본 색(보라)이 아니라 컷팅 화면의 틸 색으로 버튼이 보이게 한다.
Widget _tealTheme(BuildContext context, Widget child) {
  final t = Theme.of(context);
  return Theme(
    data: t.copyWith(
      colorScheme: t.colorScheme.copyWith(
        primary: CuttingColors.primary,
        onPrimary: CuttingColors.surface,
        surface: CuttingColors.surface,
        onSurface: CuttingColors.textPrimary,
        onSurfaceVariant: CuttingColors.textSecondary,
      ),
      textTheme: t.textTheme.apply(
        bodyColor: CuttingColors.textPrimary,
        displayColor: CuttingColors.textPrimary,
      ),
    ),
    child: child,
  );
}

Widget _buildLeftoverCard({
  required List<Leftover> leftovers,
  required bool useLeftovers,
  required int usedCount,
  required int savedBars,
  required bool saved,
  required ValueChanged<bool> onToggle,
  required VoidCallback onSave,
  required VoidCallback onManage,
  VoidCallback? onUndo,
  VoidCallback? onLog,
  // 새 원자재를 재고에서 뺄 수 있는 화면에서만 넘긴다.
  VoidCallback? onDeduct,
  // 아직 안 뺀 본수. 이미 뺀 것이 있고 이것이 0이면 "뺐습니다".
  int remainingBars = 0,
  bool anyDeducted = false,
  VoidCallback? onUndoDeductStock,
  String jobLogName = '',
}) {
  return Builder(
    builder: (context) => _tealTheme(
      context,
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: CuttingColors.primarySoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (savedBars > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  "촘촘하게 다시 배치해서 원자재 $savedBars본을 아꼈습니다.",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: CuttingColors.success,
                  ),
                ),
              ),
            if (leftovers.isNotEmpty)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  "잔재 먼저 쓰기 (${leftovers.length}개)",
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  useLeftovers
                      ? "이번 계산에서 잔재 $usedCount개를 씁니다."
                      : "꺼 두어서 새 원자재만으로 계산합니다.",
                  style: const TextStyle(fontSize: 11),
                ),
                value: useLeftovers,
                activeThumbColor: CuttingColors.primary,
                onChanged: onToggle,
              ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (saved) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    child: Text(
                      "저장했습니다",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: CuttingColors.success,
                      ),
                    ),
                  ),
                  if (onUndo != null)
                    TextButton(
                      key: const Key('leftover_undo'),
                      onPressed: onUndo,
                      child: const Text("되돌리기"),
                    ),
                ] else
                  OutlinedButton(
                    onPressed: onSave,
                    child: const Text("잘랐습니다 (잔재 저장)"),
                  ),
                if (onDeduct != null)
                  if (anyDeducted && remainingBars == 0) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                      child: Text(
                        "재고에서 뺐습니다",
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: CuttingColors.success,
                        ),
                      ),
                    ),
                    if (onUndoDeductStock != null)
                      TextButton(
                        key: const Key('stock_deduct_undo'),
                        onPressed: onUndoDeductStock,
                        child: const Text("되돌리기"),
                      ),
                  ] else ...[
                    OutlinedButton(
                      key: const Key('stock_deduct'),
                      onPressed: remainingBars == 0 ? null : onDeduct,
                      child: Text(
                        anyDeducted ? "남은 $remainingBars본 재고에서 빼기" : "재고에서 빼기",
                      ),
                    ),
                    // 일부만 뺐을 때도 뺀 것을 도로 넣을 수 있다.
                    if (anyDeducted && onUndoDeductStock != null)
                      TextButton(
                        key: const Key('stock_deduct_undo'),
                        onPressed: onUndoDeductStock,
                        child: const Text("뺀 것 되돌리기"),
                      ),
                  ],
                if (jobLogName.isNotEmpty)
                  TextButton(
                    key: const Key('job_material_log'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            MobileInventoryLogsPage(projectName: jobLogName),
                      ),
                    ),
                    child: const Text("이 작업 자재 기록"),
                  ),
                TextButton(onPressed: onManage, child: const Text("잔재 관리")),
                if (onLog != null)
                  TextButton(
                    key: const Key('leftover_log_open'),
                    onPressed: onLog,
                    child: const Text("잔재 기록"),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

// 잔재 목록을 보고, 지우거나 직접 더한다. 바꾼 목록을 돌려주고, 닫기만 하면 null.
Future<List<Leftover>?> _manageLeftovers(
  BuildContext context,
  List<Leftover> current,
  List<String> labels,
) {
  final list = [...current];
  final ctrl = TextEditingController();
  String label = labels.first;
  bool changed = false;
  return showDialog<List<Leftover>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => _tealTheme(
        ctx,
        Dialog(
          backgroundColor: CuttingColors.surface,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "잔재",
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${kMinLeftoverMm.toStringAsFixed(0)}mm보다 짧은 잔재는 남겨 두지 않습니다.",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  if (list.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      "전체 ${list.length}개 · 합계 ${list.fold<double>(0, (s, l) => s + l.length).toStringAsFixed(0)}mm · 규격 ${groupLeftoversByLabel(list).length}종",
                      key: const Key('leftover_total'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: CuttingColors.primaryDark,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Flexible(
                    child: list.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text("저장된 잔재가 없습니다."),
                          )
                        : ListView(
                            shrinkWrap: true,
                            children: [
                              // 규격별로 묶고, 규격 안에서는 긴 잔재부터.
                              for (final g in groupLeftoversByLabel(list)) ...[
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    "${g.label.isEmpty ? '규격 미지정' : g.label}  ·  ${g.indices.length}개 · 합계 ${g.totalMm.toStringAsFixed(0)}mm",
                                    key: Key('leftover_group_${g.label}'),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                for (final i in g.indices)
                                  ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      "${list[i].length.toStringAsFixed(0)}mm",
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      tooltip: "삭제",
                                      onPressed: () => setD(() {
                                        list.removeAt(i);
                                        changed = true;
                                      }),
                                    ),
                                  ),
                              ],
                            ],
                          ),
                  ),
                  const Divider(),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (labels.length > 1)
                        DropdownButton<String>(
                          dropdownColor: Colors.white,
                          value: label,
                          items: [
                            for (final l in labels)
                              DropdownMenuItem(
                                value: l,
                                child: Text(l.isEmpty ? '규격 미지정' : l),
                              ),
                          ],
                          onChanged: (v) => setD(() => label = v ?? label),
                        ),
                      SizedBox(
                        width: 140,
                        child: TextField(
                          controller: ctrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: "길이",
                            suffixText: "mm",
                            isDense: true,
                          ),
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          final v = double.tryParse(ctrl.text.trim());
                          if (v == null || v < kMinLeftoverMm) return;
                          setD(() {
                            list.add(Leftover(label, v.floorToDouble()));
                            ctrl.clear();
                            changed = true;
                          });
                        },
                        child: const Text("추가"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        // 지운 것은 저장을 눌러야 남는다. 그냥 닫으면 버려진다는 것을 보여 준다.
                        child: Text(changed ? "저장 안 하고 닫기" : "닫기"),
                      ),
                      FilledButton(
                        onPressed: () =>
                            Navigator.pop(ctx, changed ? list : null),
                        child: const Text("저장"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
