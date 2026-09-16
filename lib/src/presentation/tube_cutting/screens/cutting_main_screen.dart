import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, HapticFeedback;
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../data/models/cutting_project_model.dart';
import '../../../data/models/fitting_item.dart';
import '../../../data/models/smart_fitting_db.dart';
import '../widgets/smart_fitting_selector_sheet.dart';
import 'cutting_history_page.dart';
import '../cutting_optimizer.dart';
import '../cutting_theme.dart';
import '../../inventory/pages/mobile_inventory_ocr.dart';
import '../cutting_fitting_favorites.dart';

// 🚀 [입력 고도화] 라인 템플릿(자주 쓰는 부속 구성)을 저장하는 컬렉션.
// 프로젝트와 무관하게 공유되는 참고 데이터라 fittings 컬렉션과 같은
// 성격으로, 이 화면에서 바로 Firestore를 쓴다.
const String kCuttingLineTemplatesCollection = 'cutting_line_templates';

// 🚀 [UI 고도화] 이 화면만 미묘하게 다른 검정(0xFF1A1A1A)을 따로 쓰고
// 있어서, 목록/기록 화면의 텍스트 색(CuttingColors.textPrimary)과 놓고
// 비교하면 아주 살짝 달랐다. 한 팔레트(cutting_theme.dart)를 그대로
// 참조하도록 바꿔서 컷팅 계산기 전체가 정확히 같은 색을 쓰게 했다.
const Color lightBg = CuttingColors.background;
const Color whiteCard = CuttingColors.surface;
const Color makitaTeal = CuttingColors.primary;
const Color makitaDark = CuttingColors.primaryDark;
const Color textPrimary = CuttingColors.textPrimary;

class CutPoint {
  final String id = UniqueKey().toString();
  FittingItem fitting;
  TextEditingController c2cController;
  // 🚀 [입력 고도화] 길이 입력 후 엔터/완료를 누르면 다음 구간의 길이
  // 필드로 자동으로 넘어가도록 포커스 체인을 걸기 위한 노드.
  final FocusNode c2cFocusNode = FocusNode();
  double calculatedCut;

  CutPoint({required this.fitting})
    : c2cController = TextEditingController(),
      calculatedCut = 0.0;

  void dispose() {
    c2cController.dispose();
    c2cFocusNode.dispose();
  }
}

class CuttingMainScreen extends StatefulWidget {
  final CuttingProject project;

  // 🚀 [자재 관리 연동 핵심] 부모(ProjectManagementPage)로부터 받는 콜백.
  // 🚀 [추가] cutRecords는 선택 인자로 추가했다 - 기존 데스크톱
  // ProjectManagementPage가 넘기는 2개짜리 콜백은 그대로 유효하고,
  // 새 모바일 기록 기능을 쓰는 콜백만 3번째 인자를 받으면 된다.
  final Function(
    double totalTubeLength,
    List<Map<String, dynamic>> fittingsList, [
    List<CutRecord> cutRecords,
  ])?
  onSaveCallback;

  const CuttingMainScreen({
    super.key,
    required this.project,
    this.onSaveCallback,
  });

  @override
  State<CuttingMainScreen> createState() => _CuttingMainScreenState();
}

class _CuttingMainScreenState extends State<CuttingMainScreen>
    with
        AutomaticKeepAliveClientMixin,
        WidgetsBindingObserver,
        SingleTickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  String _globalMaker = "Swagelok";
  List<CutPoint> _points = [];
  int _setMultiplier = 1;
  bool _groupSameLengths = false;

  // 🚀 [4번 강화] 현장에 따라 인치로 측정하는 경우가 있어서 mm/in 단위를
  // 고를 수 있게 한다. 저장/계산은 항상 mm 기준이고, 사용자가 지금 고른
  // 단위로 화면에 입력/표시만 다르게 한다.
  String _lengthUnit = 'mm';
  static const double kInchToMm = 25.4;

  // 🚀 [3번 강화] 입력 탭에서 지금 만지고 있는 구간을 배치도 탭에서도
  // 자동으로 스크롤/강조해서, 탭을 넘나들 때마다 어디까지 봤는지 다시
  // 찾을 필요가 없게 한다.
  int? _focusedPointIndex;
  final ScrollController _diagramScrollController = ScrollController();
  late final TabController _tabController;

  // 🚀 [추가] 톱날 손실(커프) - 원자재를 여러 구간으로 자를 때마다
  // 톱날 두께만큼 소재가 갈려 없어진다. 구간별 설치 길이(calculatedCut)
  // 자체는 정확해야 하니 건드리지 않고, "총 소모량" 누적에만 절단
  // 횟수만큼 더해서 원자재 발주량이 실제와 어긋나지 않게 한다.
  double _bladeKerf = 0.0;
  static const String _kerfPrefsKey = 'cutting_blade_kerf';

  // 🚀 [5번 강화, 추가] 재단 최적화(원자재 소요 계산)에 쓸 원자재 기준
  // 길이. 커프처럼 기기에 저장해두고 다음에 또 쓸 수 있게 한다.
  double _stockLength = 6000.0;
  static const String _stockLengthPrefsKey = 'cutting_stock_length';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      // 🚀 [3번 강화] 배치도 탭(index 1)으로 넘어오면, 입력 탭에서 마지막
      // 으로 만지던 구간으로 자동 스크롤한다.
      if (_tabController.indexIsChanging) return;
      if (_tabController.index == 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollDiagramToFocused();
        });
      }
    });
    _initializeSequence();
    _loadDraftState();
    _loadBladeKerf();
    _loadStockLength();
  }

  void _scrollDiagramToFocused() {
    final idx = _focusedPointIndex;
    if (idx == null || !_diagramScrollController.hasClients) return;
    const approxItemHeight = 132.0;
    final target = (idx * approxItemHeight).clamp(
      0.0,
      _diagramScrollController.position.maxScrollExtent,
    );
    _diagramScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  void _setFocusedPoint(int index) {
    if (_focusedPointIndex == index) return;
    setState(() => _focusedPointIndex = index);
    if (_tabController.index == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollDiagramToFocused();
      });
    }
  }

  Future<void> _loadBladeKerf() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_kerfPrefsKey);
    if (saved != null && mounted) {
      setState(() => _bladeKerf = saved);
    }
  }

  Future<void> _loadStockLength() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_stockLengthPrefsKey);
    if (saved != null && mounted) {
      setState(() => _stockLength = saved);
    }
  }

  Future<void> _showBladeKerfDialog() async {
    final ctrl = TextEditingController(
      text: _bladeKerf == 0.0 ? '' : _bladeKerf.toString(),
    );
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: whiteCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            cuttingDialogIcon(Icons.content_cut_rounded),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                "톱날 손실(커프) 설정",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "원자재를 여러 구간으로 자를 때 톱날 두께만큼 소재가 갈려 없어집니다. "
              "절단 1회당 손실량을 넣어두면 프로젝트 총 소모량 계산에 자동으로 더해집니다.\n"
              "(구간별 설치 길이 자체엔 영향 없습니다)",
              style: TextStyle(
                fontSize: 13,
                color: CuttingColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
              decoration: InputDecoration(
                suffixText: "mm / 회",
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("취소", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: makitaTeal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx, double.tryParse(ctrl.text) ?? 0.0);
            },
            child: const Text(
              "저장",
              style: TextStyle(color: whiteCard, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() => _bladeKerf = result);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kerfPrefsKey, result);
    }
  }

  // 🚀 [5번 강화] 현재 입력된 구간들로 실제 필요한 절단 조각 목록을 만든다.
  // 그룹 표시(_groupSameLengths)는 화면에 "보여주는" 방식일 뿐이라, 실제
  // 필요한 조각 수는 항상 "구간마다 세트 수만큼"이 정답이라 여기서
  // 통일해서 뽑는다.
  List<double> _collectRequiredPieces() {
    final List<double> pieces = [];
    for (int i = 0; i < _points.length - 1; i++) {
      final p = _points[i];
      if (p.c2cController.text.isEmpty || p.calculatedCut <= 0) continue;
      for (int k = 0; k < _setMultiplier; k++) {
        pieces.add(p.calculatedCut);
      }
    }
    return pieces;
  }

  // 🚀 [재단 최적화 고도화] 예전엔 폭 360짜리 작은 AlertDialog에 결과
  // 리스트를 220px로 눌러 담아서, 원자재가 몇 본만 넘어가도 스크롤이
  // 답답했다. 화면 대부분을 쓰는 DraggableScrollableSheet로 바꾸고,
  // 태블릿처럼 넓은 화면에서는 입력/통계와 결과 목록을 좌우로 나눠
  // 보여줘서 공간을 실제로 넓게 쓴다.
  Future<void> _showOptimizationDialog() async {
    final pieces = _collectRequiredPieces();
    if (pieces.isEmpty) {
      showCuttingSnack(context, "치수를 먼저 입력하세요.", isError: true);
      return;
    }

    final ctrl = TextEditingController(text: _stockLength.toStringAsFixed(0));
    CuttingOptimizationResult result = optimizeCutting(
      pieces: pieces,
      stockLength: _stockLength,
      kerf: _bladeKerf,
    );

    if (!mounted) return;
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
                kerf: _bladeKerf,
              );
            });
            setState(() => _stockLength = parsed);
            SharedPreferences.getInstance().then(
              (prefs) => prefs.setDouble(_stockLengthPrefsKey, parsed),
            );
          }

          Widget presetChip(String label, double value) {
            return InkWell(
              onTap: () => recalc(value),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
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
                      backgroundColor: makitaTeal,
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
                        color: whiteCard,
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
                color: textPrimary,
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
                  color: whiteCard,
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
                          const Expanded(
                            child: Text(
                              "재단 최적화 (원자재 소요 계산)",
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
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
    final Color c = accent ?? makitaTeal;
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

  // 🚀 [재단 최적화 고도화] 텍스트 한 줄로 "잔여 Nmm"만 보여주던 걸,
  // 원자재 안에서 실제로 얼마나 채워졌는지 한눈에 보이는 사용률 막대로
  // 바꿨다. 로스가 큰 원자재는 막대 색을 주황으로 바꿔 바로 눈에 띄게
  // 했다.
  Widget _buildOptBarCard(StockBarPlan bar, int index) {
    final double ratio = bar.stockLength > 0
        ? (bar.usedLength / bar.stockLength).clamp(0.0, 1.0)
        : 0.0;
    final bool highWaste = bar.wasteLength > bar.stockLength * 0.15;
    final Color accent = highWaste ? CuttingColors.warning : makitaTeal;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: whiteCard,
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
                  color: makitaDark,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  "${index + 1}",
                  style: const TextStyle(
                    color: whiteCard,
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
                    color: textPrimary,
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

  // 🚀 [4번 강화, 신규] 컷팅 지시서를 PDF로 만들어 공유한다. 예전엔 이
  // 계산기에 내보내기/공유 기능이 아예 없어서, 화면을 캡처하거나 손으로
  // 옮겨 적어야 현장에 지시서를 들고 나갈 수 있었다.
  Future<void> _exportCuttingList() async {
    final List<int> visibleIndices = [];
    for (int i = 0; i < _points.length - 1; i++) {
      if (_points[i].c2cController.text.isEmpty) continue;
      if (_points[i].calculatedCut < 0) continue;
      visibleIndices.add(i);
    }
    if (visibleIndices.isEmpty) {
      showCuttingSnack(context, "내보낼 치수가 없습니다. 먼저 치수를 입력하세요.", isError: true);
      return;
    }

    try {
      final fontData = await rootBundle.load(
        'assets/fonts/NotoSansKR-VariableFont_wght.ttf',
      );
      final koreanFont = pw.Font.ttf(fontData);
      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(base: koreanFont, bold: koreanFont),
      );

      final now = DateTime.now();
      final dateStr =
          "${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')} "
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

      List<String> headers;
      List<List<String>> rows;
      double grandTotal = 0;

      if (_groupSameLengths) {
        headers = ["길이(mm)", "개수", "합계 길이(mm)"];
        final Map<double, int> grouped = {};
        for (final i in visibleIndices) {
          grouped[_points[i].calculatedCut] =
              (grouped[_points[i].calculatedCut] ?? 0) + 1;
        }
        rows = grouped.entries.map((e) {
          final totalCount = e.value * _setMultiplier;
          final total = e.key * totalCount;
          grandTotal += total;
          return [
            e.key.toStringAsFixed(1),
            "$totalCount",
            total.toStringAsFixed(1),
          ];
        }).toList();
      } else {
        headers = ["구간", "구간 길이(mm)", "수량", "합계 길이(mm)"];
        rows = visibleIndices.map((i) {
          final cutLen = _points[i].calculatedCut;
          final total = cutLen * _setMultiplier;
          grandTotal += total;
          return [
            "PT${i + 1} -> PT${i + 2}",
            cutLen.toStringAsFixed(1),
            "$_setMultiplier",
            total.toStringAsFixed(1),
          ];
        }).toList();
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Text(
              "컷팅 지시서",
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text("프로젝트: ${widget.project.name}"),
            pw.Text("작성일시: $dateStr"),
            pw.Text(
              "메이커 고정: $_globalMaker    세트 수: $_setMultiplier SET"
              "${_bladeKerf > 0 ? '    톱날 손실: ${_bladeKerf.toStringAsFixed(1)}mm/회' : ''}",
            ),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: rows,
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                font: koreanFont,
              ),
              cellStyle: pw.TextStyle(font: koreanFont),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellAlignment: pw.Alignment.centerLeft,
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            ),
            pw.SizedBox(height: 16),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                "총 소요 길이: ${grandTotal.toStringAsFixed(1)} mm",
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File("${output.path}/${widget.project.name}_컷팅지시서.pdf");
      await file.writeAsBytes(await pdf.save());

      if (!mounted) return;
      // ignore: deprecated_member_use
      await Share.shareXFiles([
        XFile(file.path),
      ], text: "${widget.project.name} 컷팅 지시서입니다.");
    } catch (e) {
      if (!mounted) return;
      showCuttingSnack(context, "내보내기 실패: $e", isError: true);
    }
  }

  void _initializeSequence() {
    _points = [
      CutPoint(fitting: SmartFittingDB.getById("none")),
      CutPoint(fitting: SmartFittingDB.getById("none")),
    ];
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveDraftState();
    for (var point in _points) {
      point.dispose();
    }
    _tabController.dispose();
    _diagramScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _saveDraftState();
    }
  }

  String get _draftKey {
    if (widget.onSaveCallback == null) {
      return 'cutting_draft_standalone_absolute_fixed_key';
    }
    String idStr = widget.project.id.toString();
    if (idStr.isEmpty || idStr == 'null') {
      return 'cutting_draft_fallback_${widget.project.name}';
    }
    return 'cutting_draft_$idStr';
  }

  Future<void> _saveDraftState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stateData = {
        'globalMaker': _globalMaker,
        'setMultiplier': _setMultiplier,
        'groupSameLengths': _groupSameLengths,
        'lengthUnit': _lengthUnit,
        'points': _points.map((p) {
          return {
            'fittingId': p.fitting.id,
            'c2c': p.c2cController.text,
            'isCustom': p.fitting.category == 'CUSTOM',
            'customName': p.fitting.name,
            'customDed': p.fitting.deduction,
            'customOD': p.fitting.tubeOD,
          };
        }).toList(),
      };
      await prefs.setString(_draftKey, jsonEncode(stateData));
    } catch (e) {
      debugPrint("임시 저장 실패: $e");
    }
  }

  Future<void> _loadDraftState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_draftKey);

      if (jsonStr != null) {
        final stateData = jsonDecode(jsonStr);
        setState(() {
          _globalMaker = stateData['globalMaker'] ?? "Swagelok";
          _setMultiplier = stateData['setMultiplier'] ?? 1;
          _groupSameLengths = stateData['groupSameLengths'] ?? false;
          _lengthUnit = stateData['lengthUnit'] ?? "mm";

          if (stateData['points'] != null) {
            for (var p in _points) p.dispose();

            _points = (stateData['points'] as List).map((pData) {
              CutPoint p = CutPoint(fitting: SmartFittingDB.getById("none"));
              if (pData['isCustom'] == true) {
                p.fitting = FittingItem(
                  id: pData['fittingId'] ?? "custom",
                  category: "CUSTOM",
                  name: pData['customName'] ?? "커스텀 부속",
                  tubeOD: pData['customOD'] ?? "미지정",
                  maker: "CUSTOM",
                  deduction: (pData['customDed'] as num?)?.toDouble() ?? 0.0,
                  icon: Icons.extension,
                );
              } else {
                p.fitting = SmartFittingDB.getById(
                  pData['fittingId'] ?? "none",
                );
              }
              p.c2cController.text = pData['c2c'] ?? "";
              return p;
            }).toList();
          }
        });
        _calculate();
      }
    } catch (e) {
      debugPrint("불러오기 실패: $e");
    }
  }

  void _calculate() {
    setState(() {
      for (int i = 0; i < _points.length - 1; i++) {
        if (_points[i].c2cController.text.trim().isEmpty) {
          _points[i].calculatedCut = 0.0;
          continue;
        }

        double c2cRaw = double.tryParse(_points[i].c2cController.text) ?? 0.0;
        // 🚀 [4번 강화] 공제값(deduction)은 항상 mm 기준(부속 DB)이라,
        // 입력값이 인치 모드면 계산 전에 먼저 mm로 환산한다. 계산/저장/
        // PDF/재단 최적화 등 이후 모든 로직은 계속 mm만 다루면 된다.
        double c2c = _lengthUnit == 'in' ? c2cRaw * kInchToMm : c2cRaw;
        double deduction1 = _points[i].fitting.deduction;
        double deduction2 = _points[i + 1].fitting.deduction;

        _points[i].calculatedCut = c2c - deduction1 - deduction2;
      }
    });
    _saveDraftState();
  }

  void _addPoint() {
    setState(() {
      _points.add(CutPoint(fitting: SmartFittingDB.getById("none")));
      _calculate();
    });
  }

  // 🚀 [입력 고도화 4번] 예전엔 "포인트 추가"가 항상 맨 끝에만 붙어서,
  // 중간에 구간을 하나 끼워넣으려면 그 뒤 구간들을 전부 다시 만들어야
  // 했다. 카드 사이의 "여기에 추가" 버튼으로 원하는 위치에 바로
  // 끼워넣을 수 있게 한다.
  void _insertPointAt(int index) {
    setState(() {
      _points.insert(index, CutPoint(fitting: SmartFittingDB.getById("none")));
      _calculate();
    });
  }

  // 🚀 [입력 고도화 4번] 같은 부속·같은 길이의 구간이 반복되는 경우
  // (예: 동일 규격 지지대 여러 개)가 흔해서, 바로 다음 자리에 복제해
  // 넣고 필요하면 길이만 살짝 바꿔 쓸 수 있게 한다.
  void _duplicatePoint(int index) {
    final insertAt = index + 1;
    setState(() {
      final source = _points[index];
      final copy = CutPoint(fitting: source.fitting);
      copy.c2cController.text = source.c2cController.text;
      _points.insert(insertAt, copy);
      _calculate();
    });
    // 🚀 [2번 강화] 실수로 복제했을 때 바로 되돌릴 수 있게 한다.
    showCuttingUndoSnack(
      context,
      "구간을 복제했습니다.",
      onUndo: () {
        if (insertAt >= _points.length) return;
        setState(() {
          _points[insertAt].dispose();
          _points.removeAt(insertAt);
          _calculate();
        });
      },
    );
  }

  void _removePoint(int index) {
    if (_points.length <= 2) return;
    final removedFitting = _points[index].fitting;
    final removedText = _points[index].c2cController.text;
    setState(() {
      _points[index].dispose();
      _points.removeAt(index);
      _calculate();
    });
    // 🚀 [2번 강화] 예전엔 삭제 확인 없이 바로 지워져서 실수로 지우면
    // 되돌릴 방법이 없었다. 확인창 대신 "실행 취소"가 있는 스낵바로,
    // 매번 확인창을 누르는 번거로움 없이도 실수를 되돌릴 수 있게 했다.
    showCuttingUndoSnack(
      context,
      "구간을 삭제했습니다.",
      onUndo: () {
        setState(() {
          final restored = CutPoint(fitting: removedFitting);
          restored.c2cController.text = removedText;
          final insertAt = index.clamp(0, _points.length);
          _points.insert(insertAt, restored);
          _calculate();
        });
      },
    );
  }

  // 🚀 [입력 고도화 2번] 줄자를 눈으로 읽어 손으로 입력하는 대신, 카메라로
  // 찍으면 인벤토리 라벨 스캔에 이미 쓰던 OCR(OcrService)로 숫자를 읽어
  // 길이 필드에 바로 채워준다. 인식된 텍스트에서 첫 번째 숫자만 뽑는다.
  Future<void> _scanLengthWithCamera(int index) async {
    final text = await OcrService.scanLabelText(context);
    if (text == null || !mounted) return;

    final match = RegExp(r'\d+(\.\d+)?').firstMatch(text.replaceAll(',', ''));
    if (match == null) {
      showCuttingSnack(context, "숫자를 인식하지 못했습니다. 다시 촬영해주세요.", isError: true);
      return;
    }

    setState(() {
      _points[index].c2cController.text = match.group(0)!;
      _calculate();
    });
  }

  // 🚀 [입력 고도화 6번] 자주 쓰는 부속 구성(라인)을 저장해뒀다가 다른
  // 작업에서 바로 불러와 쓰는 기능. 프로젝트에 종속되지 않는 공용
  // 데이터라 fittings 컬렉션처럼 별도 Firestore 컬렉션에 저장한다.
  List<Map<String, dynamic>> _serializePointsForTemplate() {
    return _points.map((p) {
      return {
        'fittingId': p.fitting.id,
        'c2c': p.c2cController.text,
        'isCustom': p.fitting.category == 'CUSTOM',
        'customName': p.fitting.name,
        'customDed': p.fitting.deduction,
        'customOD': p.fitting.tubeOD,
      };
    }).toList();
  }

  Future<void> _promptSaveTemplate() async {
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: whiteCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            cuttingDialogIcon(Icons.bookmark_add_outlined),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                "템플릿으로 저장",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: "템플릿 이름 (예: 3단 선반 다리)",
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("취소", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: makitaTeal),
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            child: const Text("저장", style: TextStyle(color: whiteCard)),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    await FirebaseFirestore.instance
        .collection(kCuttingLineTemplatesCollection)
        .add({
          'name': name,
          'createdAt': DateTime.now().toIso8601String(),
          'points': _serializePointsForTemplate(),
        });
    if (mounted) showCuttingSnack(context, "'$name' 템플릿으로 저장했습니다.");
  }

  Future<void> _applyTemplateData(
    BuildContext sheetContext,
    Map<String, dynamic> data,
  ) async {
    final pointsData = (data['points'] as List?) ?? [];
    if (pointsData.isEmpty) return;

    final bool hasExistingInput = _points.any(
      (p) => p.fitting.id != 'none' || p.c2cController.text.isNotEmpty,
    );
    if (hasExistingInput) {
      final confirmed = await showCuttingConfirmDialog(
        context,
        title: "템플릿 불러오기",
        message: "현재 입력 중인 라인 구성이 템플릿 내용으로 바뀝니다. 계속할까요?",
        confirmLabel: "불러오기",
        icon: Icons.download_outlined,
      );
      if (!confirmed) return;
    }

    setState(() {
      for (var p in _points) {
        p.dispose();
      }
      _points = pointsData.map((pData) {
        final m = pData as Map;
        CutPoint p = CutPoint(fitting: SmartFittingDB.getById("none"));
        if (m['isCustom'] == true) {
          p.fitting = FittingItem(
            id: m['fittingId'] ?? "custom",
            category: "CUSTOM",
            name: m['customName'] ?? "커스텀 부속",
            tubeOD: m['customOD'] ?? "미지정",
            maker: "CUSTOM",
            deduction: (m['customDed'] as num?)?.toDouble() ?? 0.0,
            icon: Icons.extension,
          );
        } else {
          p.fitting = SmartFittingDB.getById(m['fittingId'] ?? "none");
        }
        p.c2cController.text = m['c2c'] ?? "";
        return p;
      }).toList();
    });
    _calculate();
    if (sheetContext.mounted) Navigator.pop(sheetContext);
    if (mounted) showCuttingSnack(context, "템플릿을 불러왔습니다.");
  }

  Future<void> _deleteTemplate(String docId) async {
    final confirmed = await showCuttingConfirmDialog(
      context,
      title: "템플릿 삭제",
      message: "이 템플릿을 삭제할까요? 되돌릴 수 없습니다.",
      confirmLabel: "삭제",
      danger: true,
      icon: Icons.delete_outline_rounded,
    );
    if (confirmed) {
      await FirebaseFirestore.instance
          .collection(kCuttingLineTemplatesCollection)
          .doc(docId)
          .delete();
    }
  }

  // 🚀 [6번 강화] 낱개 부속 즐겨찾기(부속 검색 팝업의 별표) 중 몇 개를
  // 묶어 이름 붙인 "부속 세트"로 저장해두고, 라인 맨 끝에 한 번에
  // 추가할 수 있게 한다. 매번 같은 3~4개 조합을 하나씩 검색해 넣던
  // 반복 작업을 줄인다.
  void _insertFittingSet(FittingSetGroup set) {
    setState(() {
      for (final item in set.items) {
        _points.add(CutPoint(fitting: item));
      }
      _calculate();
    });
    showCuttingSnack(
      context,
      "'${set.name}' 세트 ${set.items.length}개 구간을 추가했습니다.",
    );
  }

  Future<void> _deleteFittingSet(String name) async {
    final confirmed = await showCuttingConfirmDialog(
      context,
      title: "부속 세트 삭제",
      message: "'$name' 세트를 삭제할까요?",
      confirmLabel: "삭제",
      danger: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed) return;
    final sets = await loadFittingSets();
    sets.removeWhere((s) => s.name == name);
    await saveFittingSets(sets);
    if (mounted) setState(() {});
  }

  Future<void> _promptCreateFittingSet() async {
    final favorites = await loadFavoriteFittings();
    if (!mounted) return;
    if (favorites.isEmpty) {
      showCuttingSnack(
        context,
        "먼저 부속 검색 팝업에서 자주 쓰는 부속을 별표(즐겨찾기)해주세요.",
        isError: true,
      );
      return;
    }

    final nameCtrl = TextEditingController();
    final Set<int> selected = {};

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.4,
            maxChildSize: 0.92,
            expand: false,
            builder: (ctx, scrollController) => Container(
              decoration: const BoxDecoration(
                color: whiteCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text(
                      "새 부속 세트 만들기",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        hintText: "세트 이름 (예: 3way 밸브 조합)",
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "묶을 즐겨찾기 부속 선택 (2개 이상)",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: favorites.length,
                      itemBuilder: (context, i) {
                        final item = favorites[i];
                        final isChecked = selected.contains(i);
                        return CheckboxListTile(
                          value: isChecked,
                          activeColor: makitaTeal,
                          title: Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text("${item.maker} · ${item.tubeOD}"),
                          onChanged: (v) {
                            setSheetState(() {
                              if (v == true) {
                                selected.add(i);
                              } else {
                                selected.remove(i);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: selected.length < 2
                            ? null
                            : () async {
                                final name = nameCtrl.text.trim().isEmpty
                                    ? "이름 없는 세트"
                                    : nameCtrl.text.trim();
                                final items = selected
                                    .map((i) => favorites[i])
                                    .toList();
                                final sets = await loadFittingSets();
                                sets.add(
                                  FittingSetGroup(name: name, items: items),
                                );
                                await saveFittingSets(sets);
                                if (ctx.mounted) Navigator.pop(ctx, true);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: makitaTeal,
                          elevation: 0,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          "세트 저장",
                          style: TextStyle(
                            color: whiteCard,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (created == true && mounted) {
      showCuttingSnack(context, "부속 세트를 저장했습니다.");
      setState(() {});
    }
  }

  void _showFittingSetSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => Container(
          decoration: const BoxDecoration(
            color: whiteCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        "부속 세트",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.grey),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _promptCreateFittingSet();
                    },
                    icon: const Icon(Icons.add, color: makitaTeal),
                    label: const Text(
                      "새 세트 만들기",
                      style: TextStyle(
                        color: makitaTeal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: makitaTeal),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<FittingSetGroup>>(
                  future: loadFittingSets(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: makitaTeal),
                      );
                    }
                    final sets = snapshot.data!;
                    if (sets.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            "저장된 부속 세트가 없습니다.",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      itemCount: sets.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final set = sets[i];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: lightBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      set.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: textPrimary,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: CuttingColors.danger,
                                      size: 20,
                                    ),
                                    onPressed: () async {
                                      await _deleteFittingSet(set.name);
                                      if (ctx.mounted) Navigator.pop(ctx);
                                    },
                                  ),
                                ],
                              ),
                              Text(
                                set.items.map((e) => e.name).join(' · '),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _insertFittingSet(set);
                                  },
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: makitaTeal),
                                  ),
                                  child: const Text(
                                    "라인에 추가",
                                    style: TextStyle(color: makitaTeal),
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTemplateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (ctx, scrollController) => Container(
          decoration: const BoxDecoration(
            color: whiteCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        "라인 템플릿",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.grey),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await _promptSaveTemplate();
                    },
                    icon: const Icon(
                      Icons.bookmark_add_outlined,
                      color: makitaTeal,
                    ),
                    label: const Text(
                      "현재 구성을 템플릿으로 저장",
                      style: TextStyle(
                        color: makitaTeal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: makitaTeal),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "저장된 템플릿",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection(kCuttingLineTemplatesCollection)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: makitaTeal),
                      );
                    }
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text(
                          "저장된 템플릿이 없습니다.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }
                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final doc = docs[i];
                        final data = doc.data() as Map<String, dynamic>;
                        final name = (data['name'] as String?) ?? "이름 없음";
                        final count = (data['points'] as List?)?.length ?? 0;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: lightBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.view_list_outlined,
                                color: makitaTeal,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: textPrimary,
                                      ),
                                    ),
                                    Text(
                                      "포인트 $count개",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () => _applyTemplateData(ctx, data),
                                child: const Text("불러오기"),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: CuttingColors.danger,
                                  size: 20,
                                ),
                                onPressed: () => _deleteTemplate(doc.id),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openFittingSelector(int index) async {
    FittingItem? selectedItem = await SmartFittingSelectorSheet.show(
      context,
      _globalMaker,
    );
    if (selectedItem == null) return;
    // 🚀 [부속 검색 팝업 고도화] 팝업 안의 "커스텀으로 직접 입력" 버튼이
    // 반환하는 신호값. 예전엔 DB에서 아무 부속이나 먼저 고른 뒤 연필
    // 아이콘으로 바꿔야만 커스텀 입력이 가능해 흐름이 어색했다.
    if (selectedItem.id == kCustomFittingRequestId) {
      _showCustomFittingDialog(index);
      return;
    }
    setState(() => _points[index].fitting = selectedItem);
    _calculate();
  }

  void _showCustomFittingDialog(int index) {
    TextEditingController nameCtrl = TextEditingController(text: "커스텀 부속");
    TextEditingController specCtrl = TextEditingController();
    TextEditingController deductionCtrl = TextEditingController();

    Widget buildInputField({
      required String label,
      required String hint,
      required TextEditingController controller,
      bool isNumber = false,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: makitaDark,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: isNumber
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: textPrimary,
            ),
            cursorColor: makitaTeal,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 16),
              suffixText: isNumber ? "mm" : null,
              suffixStyle: const TextStyle(
                color: makitaTeal,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: makitaTeal, width: 2.5),
              ),
            ),
          ),
        ],
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: whiteCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: makitaTeal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.extension,
                        color: makitaTeal,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "커스텀 부속 설정",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                buildInputField(
                  label: "품명 (예: 볼 밸브, 체크 밸브)",
                  hint: "품명 입력",
                  controller: nameCtrl,
                ),
                const SizedBox(height: 16),
                buildInputField(
                  label: "규격 (예: 1/2, 3/8, 12mm)",
                  hint: "규격 입력",
                  controller: specCtrl,
                ),
                const SizedBox(height: 16),
                buildInputField(
                  label: "적용할 공제값 (Deduction)",
                  hint: "0.0",
                  controller: deductionCtrl,
                  isNumber: true,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(
                            color: Colors.grey.shade300,
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          "취소",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: makitaTeal,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          double customDed =
                              double.tryParse(deductionCtrl.text) ?? 0.0;
                          String specStr = specCtrl.text.trim().isEmpty
                              ? "미지정"
                              : specCtrl.text.trim();

                          setState(() {
                            _points[index].fitting = FittingItem(
                              id: "custom_${DateTime.now().millisecondsSinceEpoch}",
                              category: "CUSTOM",
                              name: nameCtrl.text.trim().isEmpty
                                  ? "커스텀 부속"
                                  : nameCtrl.text.trim(),
                              tubeOD: specStr, // 🚀 규격 정확히 저장
                              maker: "CUSTOM",
                              deduction: customDed,
                              icon: Icons.extension,
                            );
                            _calculate();
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text(
                          "적용하기",
                          style: TextStyle(
                            color: whiteCard,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _saveRecord() {
    if (_points.any(
      (p) => p.c2cController.text.isNotEmpty && p.calculatedCut < 0,
    )) {
      showCuttingSnack(context, "간섭이 발생한 구간이 있습니다. 치수를 확인해주세요!", isError: true);
      return;
    }

    double totalOneSet = _points
        .sublist(0, _points.length - 1)
        .fold(
          0.0,
          (sum, point) =>
              sum + (point.calculatedCut > 0 ? point.calculatedCut : 0.0),
        );

    double finalTotal = totalOneSet * _setMultiplier;

    if (finalTotal <= 0) return;

    FocusScope.of(context).unfocus();

    // 🚀 [자재 관리용 완벽 분리] 제조사, 규격, 품명, 수량을 담을 객체 리스트
    Map<String, Map<String, dynamic>> groupedFittings = {};
    int totalFittingCount = 0;

    for (var point in _points) {
      if (point.fitting.id != "none") {
        String maker = point.fitting.category == "CUSTOM"
            ? "CUSTOM"
            : _globalMaker;
        String spec = point.fitting.tubeOD;
        String name = point.fitting.name;

        // 고유 식별 키 (제조사_규격_이름)
        String uniqueKey = "${maker}_${spec}_$name";

        if (groupedFittings.containsKey(uniqueKey)) {
          groupedFittings[uniqueKey]!['qty'] += 1;
        } else {
          groupedFittings[uniqueKey] = {
            'maker': maker,
            'spec': spec,
            'name': name,
            'qty': 1,
            'type': 'FITTING',
          };
        }
      }
    }

    List<Map<String, dynamic>> finalFittingsList = [];
    groupedFittings.forEach((key, data) {
      data['qty'] = (data['qty'] as int) * _setMultiplier;
      totalFittingCount += data['qty'] as int;
      // 🚀 [핵심] InventoryPage에서 필터링하는 방식과 100% 동일하게 db_name 생성!
      data['db_name'] = "[${data['maker']}] ${data['spec']} ${data['name']}";
      finalFittingsList.add(data);
    });

    // 🚀 [추가] "완료" 한 번에 실제로 잘린 구간들을 하나씩 CutRecord로
    // 남겨서, 프로젝트 안의 "기록" 탭에서 날짜/요일별로 되짚어볼 수
    // 있게 한다 (예전엔 총합만 쌓이고 언제 뭘 잘랐는지가 안 남았음).
    final now = DateTime.now();
    List<CutRecord> cutRecords = [];
    for (int i = 0; i < _points.length - 1; i++) {
      final point = _points[i];
      if (point.c2cController.text.isEmpty || point.calculatedCut <= 0) {
        continue;
      }
      final nextFitting = _points[i + 1].fitting;
      cutRecords.add(
        CutRecord(
          id: '',
          projectId: widget.project.id,
          timestamp: now,
          tubeSize: point.fitting.id != "none"
              ? point.fitting.tubeOD
              : nextFitting.tubeOD,
          originalLength: double.tryParse(point.c2cController.text) ?? 0.0,
          startFitting: point.fitting.id == "none" ? "직관" : point.fitting.name,
          endFitting: nextFitting.id == "none" ? "직관" : nextFitting.name,
          cutLength: point.calculatedCut,
          multiplier: _setMultiplier,
          // 🚀 [추가] 나중에 똑같이 재현할 수 있도록 제조사와 양쪽
          // 공제값도 같이 남긴다.
          maker: _globalMaker,
          startDeduction: point.fitting.deduction,
          endDeduction: nextFitting.deduction,
        ),
      );
    }

    // 🚀 [추가] 톱날 손실(커프) 반영 - 구간별 설치 길이(cutRecords에 남긴
    // cutLength)는 정확해야 하니 그대로 두고, "총 소모량" 쪽에만 이번에
    // 실제로 자른 횟수(구간 수 × 세트 수)만큼 커프 손실을 더한다.
    final int cutsThisSave = cutRecords.length * _setMultiplier;
    final double kerfLoss = _bladeKerf * cutsThisSave;
    finalTotal += kerfLoss;

    setState(() {
      try {
        widget.project.recordUsage(
          tubeLengthMm: finalTotal,
          fittings: {},
          multiplier: _setMultiplier,
        );
      } catch (e) {
        debugPrint("단독 모드 에러 무시: $e");
      }

      // 🚀 부모(ProjectManagementPage)의 바구니로 완벽하게 규격화된 데이터를 쏩니다!
      if (widget.onSaveCallback != null) {
        widget.onSaveCallback!(finalTotal, finalFittingsList, cutRecords);
      }

      for (var point in _points) {
        point.c2cController.clear();
        point.calculatedCut = 0.0;
      }
      _setMultiplier = 1;
      _calculate();
    });

    final kerfNote = kerfLoss > 0
        ? " (커프 손실 +${kerfLoss.toStringAsFixed(1)}mm 포함)"
        : "";
    showCuttingSnack(
      context,
      "튜브 총 ${finalTotal.toStringAsFixed(1)}mm$kerfNote 및 피팅 ${totalFittingCount}개 작업 완료!",
    );
  }

  Widget _buildFittingBadge(FittingItem item, bool isNone) {
    bool isCustom = item.category == "CUSTOM";
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isNone
            ? Colors.grey.shade100
            : (isCustom
                  ? Colors.orange.shade50
                  : makitaTeal.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isNone
              ? Colors.grey.shade300
              : (isCustom ? Colors.orange : makitaTeal.withValues(alpha: 0.5)),
        ),
      ),
      child: Text(
        isNone ? "-" : item.category.replaceAll('_', '\n'),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: item.category.length > 4 ? 9 : 12,
          fontWeight: FontWeight.w900,
          color: isNone
              ? Colors.grey
              : (isCustom ? Colors.orange.shade800 : makitaTeal),
          height: 1.1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: lightBg,
      appBar: AppBar(
        backgroundColor: makitaTeal,
        foregroundColor: whiteCard,
        elevation: 0,
        title: Text(
          "프로젝트: ${widget.project.name}",
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        actions: [
          IconButton(
            tooltip: "톱날 손실(커프) 설정",
            icon: const Icon(Icons.content_cut_rounded),
            onPressed: _showBladeKerfDialog,
          ),
          IconButton(
            tooltip: "컷팅 기록",
            icon: const Icon(Icons.history_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CuttingHistoryPage(project: widget.project),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Builder(
            builder: (context) {
              final bool isWide =
                  MediaQuery.of(context).size.shortestSide >= 600;
              return _buildMakerHeader(isWide);
            },
          ),

          // 🚀 [수정] 이 화면은 원래 데스크톱 프로젝트 관리 화면 안에서만
          // 쓰던 고정 좌우 2단(Row flex:4/5) 레이아웃이라, 좁은 폰 화면에서는
          // 각 칸이 짓눌려 못 쓸 정도였다. 폴더블 대응을 하면서 화면
          // 크기(shortestSide)를 실시간으로 봐서, 넓을 땐 기존 좌우 2단
          // 레이아웃을 그대로 쓰고 좁을 땐 탭으로 나눠 1칼럼으로 보여준다.
          Builder(
            builder: (context) {
              final bool isWide =
                  MediaQuery.of(context).size.shortestSide >= 600;
              return isWide ? _buildWideBody() : _buildNarrowBody();
            },
          ),
        ],
      ),
    );
  }

  // 🚀 [추가] 좁은 화면에서는 "메이커 고정" 라벨과 버튼 3개를 한 줄에
  // 욱여넣으면 넘칠 수 있어서, 좁을 땐 라벨을 위에, 버튼을 아래 줄로 뺀다.
  Widget _buildMakerHeader(bool isWide) {
    // 🚀 [피팅 고도화] 국내 현장에서 많이 쓰는 DK-Lok을 추가했다(피팅
    // 데이터도 db_seeder.dart에 DK-Lok 항목을 함께 시드해뒀다). 버튼이
    // 3개에서 4개로 늘어난 만큼 글자가 넘치지 않게 폰트를 살짝 줄이고
    // 말줄임을 넣었다.
    final makerButtons = Row(
      children: ["Swagelok", "Parker", "Hy-Lok", "DK-Lok"].map((maker) {
        bool isSelected = _globalMaker == maker;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() => _globalMaker = maker);
              _saveDraftState();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? makitaTeal : lightBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? makitaTeal : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                maker,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: isSelected ? whiteCard : textPrimary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );

    final label = Row(
      children: [
        const Icon(Icons.precision_manufacturing, size: 24, color: makitaTeal),
        const SizedBox(width: 8),
        Text(
          "메이커 고정",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isWide ? 12 : 10,
        horizontal: isWide ? 24 : 16,
      ),
      decoration: BoxDecoration(
        color: whiteCard,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: isWide
          ? Row(
              children: [
                label,
                const SizedBox(width: 24),
                Expanded(child: makerButtons),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [label, const SizedBox(height: 8), makerButtons],
            ),
    );
  }

  // 🚀 [추가] 넓은 화면(태블릿/폴더블 펼침) - 예전부터 있던 좌우 2단
  // 레이아웃 그대로. 왼쪽엔 포인트 리스트, 오른쪽엔 배치도+컷팅 지시서.
  Widget _buildWideBody() {
    return Expanded(
      child: Row(
        children: [
          Expanded(flex: 4, child: _buildPointListPane()),
          Container(width: 1, color: Colors.black12),
          Expanded(
            flex: 5,
            child: Column(
              children: [
                Expanded(flex: 1, child: _buildDiagramPane()),
                const Divider(height: 1, color: Colors.black12, thickness: 2),
                Expanded(flex: 1, child: _buildInstructionsPane()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🚀 [추가] 좁은 화면(폰/폴더블 접힘) - 좌우로 욱여넣는 대신 탭으로
  // 나눠서 한 화면에 한 섹션씩 전체 폭을 다 쓰게 한다.
  Widget _buildNarrowBody() {
    return Expanded(
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: makitaTeal,
            unselectedLabelColor: Colors.grey.shade600,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            indicatorColor: makitaTeal,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: "입력"),
              Tab(text: "배치도"),
              Tab(text: "결과"),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPointListPane(),
                _buildDiagramPane(),
                _buildInstructionsPane(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🚀 [추가] "배관 라인 구축" - 포인트 추가 버튼 + 드래그 정렬 리스트.
  // 🚀 [입력 UI 고도화] 예전엔 제목·부제(괄호 설명)·템플릿 버튼·"포인트
  // 추가" 버튼이 한 줄에 다 몰려 있어서, 화면이 좁으면 제목이 줄바꿈되며
  // 버튼들과 균형이 깨졌다. 제목/부제를 세로로 분리해 위계를 주고,
  // "포인트 추가"는 엄지로 누르기 쉬운 전체 폭 버튼으로 아래에 뒀다.
  Widget _buildPointListPane() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "배관 라인 구축",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "카드를 길게 눌러 드래그하면 순서를 바꿀 수 있어요",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 🚀 [6번 강화] 즐겨찾기해둔 부속 몇 개를 묶어 이름 붙인
              // "부속 세트"를 한 번에 라인에 추가한다.
              Tooltip(
                message: "부속 세트",
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _showFittingSetSheet();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: makitaDark.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.dataset_outlined,
                      color: makitaDark,
                      size: 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: "라인 템플릿",
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _showTemplateSheet();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: makitaDark.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.bookmark_outline,
                      color: makitaDark,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // 🚀 [4번 강화] 현장에 따라 인치로 측정하는 경우가 있어서,
              // mm/in을 눌러 바꾸면 이미 입력된 값도 같은 실제 길이로
              // 자동 환산되고, 이후 입력도 선택한 단위로 해석된다.
              _buildUnitToggle(),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    _addPoint();
                  },
                  icon: const Icon(Icons.add, color: whiteCard, size: 18),
                  label: const Text(
                    "포인트 추가",
                    style: TextStyle(
                      color: whiteCard,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: makitaDark,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ReorderableListView.builder(
              itemCount: _points.length,
              proxyDecorator:
                  (Widget child, int index, Animation<double> animation) {
                    return Material(
                      color: Colors.transparent,
                      elevation: 0,
                      child: _buildFittingCard(index),
                    );
                  },
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }
                  List<FittingItem> currentFittings = _points
                      .map((p) => p.fitting)
                      .toList();
                  final movedFitting = currentFittings.removeAt(oldIndex);
                  currentFittings.insert(newIndex, movedFitting);

                  for (int i = 0; i < _points.length; i++) {
                    _points[i].fitting = currentFittings[i];
                  }
                  _calculate();
                  _saveDraftState();
                });
              },
              itemBuilder: (context, index) {
                return Container(
                  key: ValueKey(_points[index].id),
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    children: [
                      _buildFittingCard(index),
                      if (index < _points.length - 1) ...[
                        _buildLengthInputCard(index),
                        _buildInsertHereButton(index + 1),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 🚀 [입력 UI 고도화] 예전엔 회색 글자 하나만 덩그러니 있어서 존재감이
  // 너무 흐려 눈에 잘 안 띄었다. 좌우 구분선 사이에 놓인 알약(pill)
  // 버튼 형태로 바꿔서, 잔잔하되 "여기 누르면 뭔가 생긴다"는 게 한눈에
  // 보이게 했다.
  Widget _buildInsertHereButton(int insertIndex) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: Colors.grey.shade200)),
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              _insertPointAt(insertIndex);
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: makitaTeal.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: makitaTeal.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, size: 14, color: makitaTeal),
                  const SizedBox(width: 3),
                  const Text(
                    "구간 추가",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: makitaTeal,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: Container(height: 1, color: Colors.grey.shade200)),
        ],
      ),
    );
  }

  // 🚀 [추가] "1. 배치도" - 현재 라인 구성의 가로 스크롤 시각화.
  // 🚀 [재구성] 예전엔 아이콘+선을 가로로 이어붙여 스크롤해서 봐야 했는데,
  // 전선관 계산기의 마킹 결과 카드처럼 STEP 번호가 붙은 카드를 세로로
  // 쌓는 형태로 바꿨다. 한 화면에 순서대로 쭉 보이고, 카드 안에 다음
  // 구간까지의 길이도 같이 표시돼서 가로 스크롤 없이 전체 라인을
  // 한눈에 파악할 수 있다.
  Widget _buildDiagramPane() {
    return Container(
      color: whiteCard,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "1. 배치도",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              controller: _diagramScrollController,
              padding: const EdgeInsets.only(bottom: 12),
              itemCount: _points.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) => _buildDiagramStepCard(index),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagramStepCard(int index) {
    final item = _points[index].fitting;
    final isNone = item.id == "none";
    final isLast = index == _points.length - 1;
    final hasNext = !isLast;
    final cutLength = hasNext ? _points[index].calculatedCut : 0.0;
    final hasInput = hasNext && _points[index].c2cController.text.isNotEmpty;
    final isInterference = hasInput && cutLength < 0;
    // 🚀 [3번 강화] 입력 탭에서 지금 만지고 있던 구간이면 테두리를 굵은
    // 틸 색으로 강조해서, 탭을 넘어와도 "아까 그 구간"을 바로 찾을 수
    // 있게 한다(간섭 경고가 있으면 그쪽이 더 급하니 빨간색이 우선).
    final bool isFocused = index == _focusedPointIndex;

    // 🚀 [UI 고도화, 가시성] 간섭이 생긴 구간은 카드 테두리와 왼쪽 번호
    // 배지를 빨간색으로 바꿔서, 전체 배치도를 쭉 훑어볼 때 어느 구간이
    // 문제인지 숫자를 하나하나 읽지 않고도 색으로 바로 짚어낼 수 있게 한다.
    final Color badgeColor = isInterference
        ? CuttingColors.danger
        : (isNone ? Colors.grey.shade200 : makitaDark);
    final Color cardBorderColor = isInterference
        ? CuttingColors.danger
        : (isFocused
              ? makitaTeal
              : (isNone
                    ? Colors.grey.shade300
                    : makitaTeal.withValues(alpha: 0.4)));
    final double cardBorderWidth = isInterference ? 1.5 : (isFocused ? 2.5 : 1);

    return Container(
      decoration: BoxDecoration(
        color: isFocused && !isInterference
            ? CuttingColors.primarySoft.withValues(alpha: 0.3)
            : whiteCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorderColor, width: cardBorderWidth),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 52,
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(11),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "PT",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: isNone
                          ? Colors.grey.shade500
                          : whiteCard.withValues(alpha: 0.7),
                    ),
                  ),
                  Text(
                    "${index + 1}",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: isNone ? Colors.grey.shade600 : whiteCard,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildFittingBadge(item, isNone),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isNone)
                                Text(
                                  "${item.tubeOD} 규격",
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              Text(
                                isNone ? "직관 (부속 없음)" : item.name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isNone ? Colors.grey : textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (hasNext) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isInterference
                              ? Colors.red.shade50
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.arrow_downward_rounded,
                              size: 14,
                              color: isInterference
                                  ? Colors.red
                                  : Colors.grey.shade500,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                isInterference ? "간섭 발생! 치수를 확인하세요" : "다음 지점까지",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isInterference
                                      ? Colors.red.shade700
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ),
                            Text(
                              hasInput
                                  ? "${cutLength.toStringAsFixed(1)} mm"
                                  : "치수 미입력",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: isInterference
                                    ? Colors.red
                                    : (hasInput
                                          ? Colors.redAccent
                                          : Colors.grey.shade600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🚀 [추가] "2. 컷팅 지시서" - 세트 수량 조절 + 결과 리스트 + 저장 버튼.
  // 🚀 [UI 고도화] 제목·토글·SET 스테퍼가 Wrap 한 줄에 다 몰려 있어서
  // 좁은 화면에서 줄바꿈되면 균형이 깨졌다. 제목을 독립된 줄로 빼고,
  // 토글과 SET 스테퍼는 spaceBetween으로 좌우에 분리해 항상 정돈되게
  // 했다.
  Widget _buildInstructionsPane() {
    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "2. 컷팅 지시서",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "같은 길이 합산",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Switch(
                    value: _groupSameLengths,
                    activeThumbColor: makitaTeal,
                    onChanged: (val) {
                      HapticFeedback.selectionClick();
                      setState(() => _groupSameLengths = val);
                      _saveDraftState();
                    },
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: whiteCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: makitaTeal),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, color: makitaTeal),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          if (_setMultiplier > 1) {
                            _setMultiplier--;
                            _saveDraftState();
                          }
                        });
                      },
                    ),
                    Text(
                      "$_setMultiplier SET",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, color: makitaTeal),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _setMultiplier++;
                          _saveDraftState();
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 🚀 [4·5번 강화] 재단 최적화(원자재 소요 계산)와 컷팅 지시서
          // 내보내기(PDF 공유) - 예전엔 둘 다 이 계산기에 없던 기능이라
          // 화면 캡처나 수기 메모에 의존해야 했다.
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showOptimizationDialog,
                  icon: const Icon(
                    Icons.view_column_outlined,
                    size: 18,
                    color: makitaTeal,
                  ),
                  label: const Text(
                    "재단 최적화",
                    style: TextStyle(
                      color: makitaTeal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: makitaTeal),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _exportCuttingList,
                  icon: const Icon(
                    Icons.ios_share_rounded,
                    size: 18,
                    color: makitaTeal,
                  ),
                  label: const Text(
                    "내보내기",
                    style: TextStyle(
                      color: makitaTeal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: makitaTeal),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: whiteCard,
                border: Border.all(color: CuttingColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _buildCuttingListRenderer(),
            ),
          ),
          const SizedBox(height: 16),
          // 🚀 [간소화] "N 세트 작업 완료 (저장 및 초기화)"는 글자 수가
          // 많아 좁은 화면에서 부담스러웠다. 세트 수는 바로 위 카운터에
          // 이미 보이므로 버튼엔 짧은 동작 문구만, 무슨 일이 일어나는지는
          // 작은 글씨로 한 줄 덧붙였다.
          ElevatedButton(
            onPressed: _points.any((p) => p.c2cController.text.isNotEmpty)
                ? _saveRecord
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: makitaTeal,
              elevation: 0,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "저장하기",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: whiteCard,
                  ),
                ),
                Text(
                  "$_setMultiplier세트 기록 후 새로 입력",
                  style: TextStyle(
                    fontSize: 11,
                    color: whiteCard.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🚀 [재구성] 예전엔 드래그핸들+순번배지+부속선택+수동입력+삭제가
  // 전부 한 줄에 몰려있어서, 좁은 폰 화면에서 각 요소가 짓눌려 글자가
  // 작아지고 터치하기도 힘들었다. 상단(순번/드래그/삭제)·본문(부속
  // 선택, 카드 전체 너비 사용)·하단(공제값/수동입력) 3단으로 나눠서
  // 요소마다 충분한 터치 영역과 가로 공간을 확보했다.
  Widget _buildFittingCard(int index) {
    FittingItem item = _points[index].fitting;
    bool isNone = item.id == "none";
    bool isCustom = item.category == "CUSTOM";

    return Container(
      decoration: BoxDecoration(
        color: whiteCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isNone ? Colors.grey.shade300 : makitaTeal,
          width: isNone ? 1 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단: 드래그 핸들 + 순번 배지 + 삭제
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 4, 0),
            child: Row(
              children: [
                const Icon(Icons.drag_handle, color: Colors.grey, size: 20),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isNone ? Colors.grey.shade200 : makitaDark,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "PT${index + 1}",
                    style: TextStyle(
                      color: isNone ? Colors.grey.shade600 : whiteCard,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Spacer(),
                // 🚀 [입력 UI 고도화] 복제 아이콘은 배경 없이 흐릿하게,
                // 삭제 아이콘은 진한 빨강으로 따로 놀아서 두 버튼의 무게가
                // 안 맞았다. 같은 크기의 원형 배경 버튼으로 맞춰 균형을
                // 잡았다.
                Tooltip(
                  message: "이 구간 복제",
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _duplicatePoint(index);
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.copy_all_outlined,
                        color: Colors.grey.shade600,
                        size: 16,
                      ),
                    ),
                  ),
                ),
                if (_points.length > 2) ...[
                  const SizedBox(width: 6),
                  Tooltip(
                    message: "이 구간 삭제",
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _removePoint(index),
                      child: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: CuttingColors.dangerSoft,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: CuttingColors.danger,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // 본문: 부속 선택 - 카드 전체 너비를 다 쓰는 큰 터치 영역
          InkWell(
            onTap: () {
              _setFocusedPoint(index);
              _openFittingSelector(index);
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Row(
                children: [
                  _buildFittingBadge(item, isNone),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isNone)
                          Text(
                            "${item.tubeOD} 규격",
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        Text(
                          isNone ? "탭해서 부속 고르기" : item.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isNone ? Colors.grey.shade600 : textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                ],
              ),
            ),
          ),
          // 하단: 공제값 표시 + 수동 입력 버튼 (부속이 선택된 경우만)
          if (!isNone)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(11),
                ),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isCustom ? "수동 입력값" : "공제값",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isCustom
                            ? "${item.deduction}mm (수동)"
                            : "- ${item.deduction}mm",
                        style: TextStyle(
                          color: isCustom ? Colors.orange.shade800 : makitaDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => _showCustomFittingDialog(index),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.edit_rounded,
                            color: Colors.grey.shade500,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // 🚀 [4번 강화] mm는 소수점 1자리, 인치는 1/8" 단위 작업이 흔해
  // 소수점이 더 필요해서 3자리까지 보여주되 불필요한 0은 정리한다.
  String _formatLocalLength(double v) {
    if (_lengthUnit == 'in') {
      String s = v.toStringAsFixed(3);
      if (s.contains('.')) {
        s = s.replaceFirst(RegExp(r'0+$'), '');
        s = s.replaceFirst(RegExp(r'\.$'), '');
      }
      return s;
    }
    return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  }

  // 🚀 [4번 강화] mm/인치 단위를 바꾸면, 이미 입력된 값들을 같은 실제
  // 길이가 유지되도록 자동 환산한다(예: 25.4mm → 1in). 이렇게 안 하면
  // 단위를 바꾸는 순간 숫자는 그대로인데 의미만 바뀌어서 값이 25.4배
  // 어긋나 버린다.
  void _setLengthUnit(String unit) {
    if (unit == _lengthUnit) return;
    HapticFeedback.selectionClick();
    final oldUnit = _lengthUnit;
    final List<double?> mmValues = _points.map((p) {
      final raw = double.tryParse(p.c2cController.text);
      if (raw == null) return null;
      return oldUnit == 'in' ? raw * kInchToMm : raw;
    }).toList();

    setState(() {
      _lengthUnit = unit;
      for (int i = 0; i < _points.length; i++) {
        final mm = mmValues[i];
        if (mm == null) continue;
        final newRaw = unit == 'in' ? mm / kInchToMm : mm;
        _points[i].c2cController.text = _formatLocalLength(newRaw);
      }
      _calculate();
    });
  }

  Widget _buildUnitToggle() {
    Widget segment(String label, String unit) {
      final bool isSelected = _lengthUnit == unit;
      return InkWell(
        onTap: () => _setLengthUnit(unit),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            color: isSelected ? makitaTeal : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isSelected ? whiteCard : Colors.grey.shade600,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [segment("mm", "mm"), segment("in", "in")],
      ),
    );
  }

  // 🚀 [입력 고도화 1·5번] 길이 입력 한 칸 - 카메라 인식 버튼, 스텝 버튼,
  // "이전 구간과 동일" 복사, 엔터로 다음 칸 자동 이동, 규격 불일치/짧은
  // 절단 길이 주의 안내를 한데 모았다.
  void _stepLength(int index, double delta) {
    final current = double.tryParse(_points[index].c2cController.text) ?? 0.0;
    final next = (current + delta).clamp(0.0, double.infinity);
    setState(() {
      _points[index].c2cController.text = _formatLocalLength(next);
      _calculate();
    });
  }

  // 🚀 [입력 UI 고도화] 낱개 칩 대신 하나의 알약 안에 이어붙인 세그먼트
  // 스테퍼. [4번 강화] mm에서 ±10을 그대로 인치에 쓰면 10인치씩
  // 뛰어버리므로, 인치일 땐 더 작은 단위(±0.1/±1)로 바꾼다.
  Widget _buildStepStepper(int index) {
    Widget segment(String label, double delta, {bool isFirst = false}) {
      return InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          _stepLength(index, delta);
        },
        child: Container(
          decoration: BoxDecoration(
            border: isFirst
                ? null
                : Border(left: BorderSide(color: Colors.grey.shade300)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

    final steps = _lengthUnit == 'in'
        ? const [('-1', -1.0), ('-.1', -0.1), ('+.1', 0.1), ('+1', 1.0)]
        : const [('-10', -10.0), ('-1', -1.0), ('+1', 1.0), ('+10', 10.0)];

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < steps.length; i++)
            segment(steps[i].$1, steps[i].$2, isFirst: i == 0),
        ],
      ),
    );
  }

  Widget _buildLengthInputCard(int index) {
    bool hasInput = _points[index].c2cController.text.trim().isNotEmpty;
    bool isInterference = hasInput && _points[index].calculatedCut < 0;
    bool isSuspiciouslyShort =
        hasInput &&
        !isInterference &&
        _points[index].calculatedCut > 0 &&
        _points[index].calculatedCut < 5;

    final startItem = _points[index].fitting;
    final endItem = _points[index + 1].fitting;
    final bool specMismatch =
        startItem.id != "none" &&
        endItem.id != "none" &&
        startItem.tubeOD.isNotEmpty &&
        endItem.tubeOD.isNotEmpty &&
        startItem.tubeOD != "미지정" &&
        endItem.tubeOD != "미지정" &&
        startItem.tubeOD != endItem.tubeOD;

    final bool canCopyPrevious =
        index > 0 && _points[index - 1].c2cController.text.trim().isNotEmpty;
    final bool isLastSegment = index == _points.length - 2;

    // 🚀 [입력 UI 고도화] 카메라/스테퍼/경고문구까지 들어가며 내용이
    // 많아진 만큼, 가는 연결선 하나로는 내용이 붕 떠 보였다. 부속
    // 카드(흰 배경+굵은 테두리)와는 다른 톤 - 옅은 회색 배경 - 으로
    // 카드화해서 담음새를 줬다. (왼쪽 색 띠는 포인트가 과했다는 피드백에
    // 따라 제거)
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: isInterference
              ? CuttingColors.dangerSoft
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isInterference
                ? CuttingColors.danger.withValues(alpha: 0.4)
                : Colors.grey.shade200,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🚀 [입력 UI 고도화] 카메라 버튼이 Row 맨 위(start)에
              // 붙어서 라벨 있는 TextField보다 위쪽에 붕 떠 보였다.
              // IntrinsicHeight + stretch로 필드와 정확히 같은 높이를
              // 갖도록 맞춰서 하나의 입력 그룹처럼 보이게 했다.
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _points[index].c2cController,
                        focusNode: _points[index].c2cFocusNode,
                        onTap: () => _setFocusedPoint(index),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: isLastSegment
                            ? TextInputAction.done
                            : TextInputAction.next,
                        onSubmitted: (_) {
                          if (!isLastSegment) {
                            _setFocusedPoint(index + 1);
                            FocusScope.of(
                              context,
                            ).requestFocus(_points[index + 1].c2cFocusNode);
                          } else {
                            FocusScope.of(context).unfocus();
                          }
                        },
                        onChanged: (_) => _calculate(),
                        cursorColor: makitaTeal,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: textPrimary,
                        ),
                        decoration: InputDecoration(
                          labelText: "전체 길이 (C to C / End to End)",
                          labelStyle: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: whiteCard,
                          suffixText: _lengthUnit,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: isInterference
                                  ? Colors.red
                                  : Colors.grey.shade300,
                              width: isInterference ? 2 : 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: isInterference ? Colors.red : makitaTeal,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: "카메라로 치수 인식",
                      child: InkWell(
                        onTap: () => _scanLengthWithCamera(index),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: makitaTeal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.camera_alt_outlined,
                            color: makitaTeal,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // 🚀 [입력 UI 고도화] 낱개 칩 4개가 따로 떠 있어 간격이
                  // 들쭉날쭉해 보였다. 하나로 이어붙인 세그먼트 스테퍼로
                  // 바꿔서 정렬된 하나의 컨트롤처럼 보이게 했다.
                  _buildStepStepper(index),
                  if (canCopyPrevious)
                    InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _points[index].c2cController.text =
                              _points[index - 1].c2cController.text;
                          _calculate();
                        });
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.content_copy_rounded,
                              size: 12,
                              color: makitaTeal,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              "이전 구간과 동일",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: makitaTeal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              if (isInterference)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_rounded,
                        color: Colors.red,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          "간섭 발생! 입력값이 양쪽 피팅 공제값의 합보다 작습니다.",
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              // 🚀 [입력 고도화 5번] 서로 다른 규격(OD)의 부속을 이어 붙인
              // 경우, 실수인지 확인할 수 있게 막지는 않고 알려만 준다.
              if (!isInterference && specMismatch)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: CuttingColors.warning,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          "규격이 다른 부속끼리 연결됨: ${startItem.tubeOD} → ${endItem.tubeOD}",
                          style: const TextStyle(
                            color: CuttingColors.warning,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (!isInterference && !specMismatch && isSuspiciouslyShort)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: CuttingColors.warning,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Text(
                          "절단 길이가 매우 짧습니다. 치수를 다시 확인해주세요.",
                          style: TextStyle(
                            color: CuttingColors.warning,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCuttingListRenderer() {
    List<double> validCuts = _points
        .sublist(0, _points.length - 1)
        .where((p) => p.c2cController.text.isNotEmpty && p.calculatedCut > 0)
        .map((p) => p.calculatedCut)
        .toList();

    if (validCuts.isEmpty) {
      bool hasError = _points.any(
        (p) => p.c2cController.text.isNotEmpty && p.calculatedCut < 0,
      );
      return Center(
        child: Text(
          hasError ? "간섭이 발생한 구간을 수정하세요." : "치수를 입력하세요.",
          style: TextStyle(
            color: hasError ? Colors.red : Colors.grey.shade600,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    // 🚀 [재구성] 예전엔 항목 하나에 텍스트 4개를 spaceBetween Row 한
    // 줄에 다 욱여넣어서, 실제 작업대에서 보는 이 화면이 좁은 폰에서
    // 넘치거나 글자가 짓눌릴 위험이 제일 컸다. 카드 형태로 바꿔서
    // 가장 중요한 "최종 필요 길이"를 크고 명확하게, 나머지 정보는
    // 위아래로 배치해 절대 겹치거나 넘치지 않게 했다.
    if (_groupSameLengths) {
      Map<double, int> grouped = {};
      for (var cut in validCuts) {
        grouped[cut] = (grouped[cut] ?? 0) + 1;
      }
      return ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: grouped.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          double length = grouped.keys.elementAt(index);
          int count = grouped[length]!;
          int totalCount = count * _setMultiplier;
          return _buildCutResultCard(
            topLeft: "${length.toStringAsFixed(1)} mm",
            topRight: "총 $totalCount 개",
            subtitle: "기본 $count개 × $_setMultiplier SET",
            totalLabel: "합계 소요 길이",
            totalValue: "${(length * totalCount).toStringAsFixed(1)} mm",
          );
        },
      );
    } else {
      final visibleIndices = List.generate(_points.length - 1, (i) => i).where((
        index,
      ) {
        if (_points[index].c2cController.text.isEmpty) return false;
        return _points[index].calculatedCut >= 0;
      }).toList();

      return ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: visibleIndices.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, listIndex) {
          final index = visibleIndices[listIndex];
          double cutLen = _points[index].calculatedCut;
          return _buildCutResultCard(
            topLeft: "PT${index + 1} → PT${index + 2}",
            topRight: "× $_setMultiplier 개",
            subtitle: "구간 길이 ${cutLen.toStringAsFixed(1)} mm",
            totalLabel: "합계 소요 길이",
            totalValue: "${(cutLen * _setMultiplier).toStringAsFixed(1)} mm",
          );
        },
      );
    }
  }

  // 🚀 [추가] 컷팅 결과 카드 - 가장 중요한 "합계 소요 길이"를 크고
  // 명확하게 강조하고, 나머지 부가 정보는 작게 위아래로 배치한다.
  Widget _buildCutResultCard({
    required String topLeft,
    required String topRight,
    required String subtitle,
    required String totalLabel,
    required String totalValue,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: whiteCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  topLeft,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: makitaTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  topRight,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: makitaTeal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                totalLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                totalValue,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
