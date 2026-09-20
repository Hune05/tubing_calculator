import 'package:flutter/material.dart';
import '../../../core/utils/pdf_fonts.dart';
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, HapticFeedback;
import 'dart:async' show Timer;
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
import '../widgets/cutting_optimization_sheet.dart';
import '../cutting_action_bar.dart';
import '../cutting_diagram_pdf.dart';
import '../cutting_diagram_view.dart';
import '../cutting_result_logic.dart';
import '../cutting_result_view.dart';
import '../cutting_leftovers.dart'
    show loadLeftovers, loadMixLengths, kTubeMixPrefsKey;
import '../cutting_math.dart'
    show cutBreakdownText, cutLengthMm, parseLengthInput;
import '../cutting_optimizer.dart';
import '../cutting_plan_rows.dart';
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
  // 길이 칸의 글자를 숫자로 읽지 못했는지, 읽은 길이(mm).
  bool unreadable = false;
  double c2cMm = 0.0;

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

  // "저장" 직후 실행 취소를 눌렀을 때 저장한 것을 되돌리는 콜백(저장할 때 넘긴 값과 같은 값을 받는다).
  // onSaveCallback으로 바깥에 저장하는 화면은 이것도 넘겨야 "실행 취소"가 나온다 — 없으면 바깥에
  // 저장된 것을 되돌릴 방법이 없으므로 실행 취소를 보여 주지 않는다.
  final Function(
    double totalTubeLength,
    List<Map<String, dynamic>> fittingsList,
    List<CutRecord> cutRecords,
  )?
  onUndoCallback;

  const CuttingMainScreen({
    super.key,
    required this.project,
    this.onSaveCallback,
    this.onUndoCallback,
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
  // 같은 길이끼리 묶어 보기. 처음 만드는 작업은 켜 둔다(이미 저장된 작업은 예전에 고른 값을 그대로 쓴다).
  bool _groupSameLengths = true;
  // 결과 탭에서 "잘랐음"으로 표시한 줄(열쇠는 cutting_result_logic.dart 참고). 임시 저장에 함께 남긴다.
  final Set<String> _doneKeys = {};
  // 사용자가 직접 지정한 튜브 규격(제원). 부속에서 규격을 알 수 없는 구간에만 쓴다. 빈 글자 = 지정 안 함.
  String _tubeSpec = '';
  // 저장 직후 띄운 "실행 취소" 스낵바를 화면을 떠날 때 함께 없애기 위해 잡아 둔다.
  ScaffoldMessengerState? _undoMessenger;
  // 지금 떠 있는 실행 취소가 어느 저장의 것인지(다른 저장·화면 이동 뒤에는 자동으로 걷지 않게 구분한다).
  Object? _undoToken;
  Timer? _undoTimer;
  // 결과 탭 아이콘 버튼은 처음 쓰는 동안 이름을 아래에 보여 주고, 한 번이라도 누르면 숨긴다.
  static const String _kIconsUsedKey = 'cutting_result_icons_used';
  bool _iconsUsed = true; // 읽어 오기 전에는 숨긴 상태로 시작해서 깜빡이지 않게 한다
  // "?" 버튼으로 이름을 잠깐 다시 보는 중인지(저장하지 않는다. 아이콘을 쓰거나 다시 누르면 숨는다).
  bool _labelsPinned = false;

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
  // 입력 탭 목록. 배치도에서 지점을 눌러 넘어올 때 그 지점 쪽으로 스크롤하는 데 쓴다.
  final ScrollController _inputScrollController = ScrollController();
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
    _loadIconsUsed();
  }

  Future<void> _loadIconsUsed() async {
    try {
      final used =
          (await SharedPreferences.getInstance()).getBool(_kIconsUsedKey) ??
          false;
      if (mounted && !used) setState(() => _iconsUsed = false);
    } catch (_) {}
  }

  // 아이콘 버튼을 한 번이라도 쓰면 이름 표시를 끈다.
  void _markIconsUsed() {
    if (_labelsPinned) setState(() => _labelsPinned = false);
    if (_iconsUsed) return;
    setState(() => _iconsUsed = true);
    SharedPreferences.getInstance()
        .then((p) => p.setBool(_kIconsUsedKey, true))
        .catchError((_) => false);
  }

  void _scrollDiagramToFocused() {
    final idx = _focusedPointIndex;
    if (idx == null || !_diagramScrollController.hasClients) return;
    final scale = (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(
      1.0,
      1.8,
    );
    final target = CuttingDiagramView.offsetOf(
      idx,
      _diagramData().$2,
      scale: scale,
    ).clamp(0.0, _diagramScrollController.position.maxScrollExtent);
    _diagramScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  void _setFocusedPoint(int index) {
    if (_focusedPointIndex == index) return;
    setState(() => _focusedPointIndex = index);
    if (_tabController.index == 1 || _isWideLayout) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollDiagramToFocused();
      });
    }
  }

  // 배치도가 입력과 나란히 늘 보이는 넓은 화면인지(탭 대신 여러 칸으로 보여 줄 때).
  bool get _isWideLayout => MediaQuery.of(context).size.shortestSide >= 600;

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
    final result = await showBladeKerfDialog(context, _bladeKerf);
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
  // 🚀 [규격별 분리] 리듀서로 규격이 바뀌는 라인은 구간마다 실제로 잘리는
  // 튜브 규격이 다를 수 있다 - 다른 규격은 같은 원자재 한 본에서 나올 수
  // 없으니, 형강 컷팅과 같은 이유로 규격별로 나눠 최적화해야 한다. 구간의
  // 규격은 CutRecord 저장 때 쓰는 것과 같은 규칙(시작 쪽 피팅이 있으면
  // 그 규격, 없으면(직관) 끝 쪽 피팅 규격)을 그대로 따른다.
  Map<String, List<double>> _collectRequiredPiecesByTubeSize() {
    final Map<String, List<double>> byTubeSize = {};
    final specs = _segmentSpecs();
    for (int i = 0; i < _points.length - 1; i++) {
      final p = _points[i];
      if (p.c2cController.text.isEmpty || p.calculatedCut <= 0) continue;
      final key = specs[i].isEmpty ? "" : "튜브 ${specs[i]}";
      final list = byTubeSize.putIfAbsent(key, () => []);
      for (int k = 0; k < _setMultiplier; k++) {
        list.add(p.calculatedCut);
      }
    }
    return byTubeSize;
  }

  // 🚀 [형강 컷팅 신규 기능 대비 리팩터링] 이 시트 자체는 이제 공용
  // widgets/cutting_optimization_sheet.dart로 옮겼다 - 튜브 라인이 아니라
  // 단순 길이 목록만 있는 화면(형강/찬넬/앵글 컷팅)에서도 똑같은 다중
  // 규격 조합 최적화를 재사용하기 위해서다. 이 화면은 "필요한 절단 길이
  // 목록"을 뽑아서 넘기고, 원자재 기준 길이가 바뀌면 기존처럼
  // SharedPreferences에 저장하는 역할만 담당한다.
  // 재단 최적화에서 "잘랐습니다"(잔재 저장)를 눌렀을 때: 결과의 모든 줄을 "잘랐음"으로 맞춘다.
  // 기록으로 남기는 것은 결과 탭의 "저장하기"다. 창에서 저장을 되돌리면 표시도 저장 전으로 돌린다.
  Set<String>? _doneBeforeLeftoverSave;

  void _onLeftoversSaved() {
    if (!mounted) return;
    setState(() {
      _doneBeforeLeftoverSave = {..._doneKeys};
      _doneKeys.addAll(_resultLines().map((l) => l.key));
    });
    _saveDraftState();
  }

  void _onLeftoversSaveUndone() {
    if (!mounted) return;
    setState(() {
      _doneKeys
        ..clear()
        ..addAll(_doneBeforeLeftoverSave ?? const <String>{});
      _doneBeforeLeftoverSave = null;
    });
    _saveDraftState();
  }

  Future<void> _showOptimizationDialog() async {
    await showCuttingOptimizationSheet(
      context,
      groupedPieces: _collectRequiredPiecesByTubeSize(),
      initialStockLength: _stockLength,
      mixPrefsKey: kTubeMixPrefsKey,
      onLeftoversSaved: _onLeftoversSaved,
      onLeftoversSaveUndone: _onLeftoversSaveUndone,
      leftoverLogSource: '튜브 컷팅 · ${widget.project.name}',
      kerf: _bladeKerf,
      onStockLengthChanged: (parsed) {
        setState(() => _stockLength = parsed);
        SharedPreferences.getInstance().then(
          (prefs) => prefs.setDouble(_stockLengthPrefsKey, parsed),
        );
      },
    );
  }

  // 🚀 [4번 강화, 신규] 컷팅 지시서를 PDF로 만들어 공유한다. 예전엔 이
  // 계산기에 내보내기/공유 기능이 아예 없어서, 화면을 캡처하거나 손으로
  // 옮겨 적어야 현장에 지시서를 들고 나갈 수 있었다.
  Future<void> _exportCuttingList() async {
    final List<int> visibleIndices = [];
    for (int i = 0; i < _points.length - 1; i++) {
      if (_points[i].c2cController.text.isEmpty) continue;
      if (_points[i].calculatedCut <= 0) continue;
      visibleIndices.add(i);
    }
    if (visibleIndices.isEmpty) {
      showCuttingSnack(context, "내보낼 치수가 없습니다. 먼저 치수를 입력하십시오.", isError: true);
      return;
    }

    try {
      final pdfFonts = await loadKoreanPdfFonts();
      final koreanFont = pdfFonts.regular;
      final koreanBold = pdfFonts.bold;
      final pdf = pw.Document(theme: pdfFonts.theme);

      final now = DateTime.now();
      final dateStr =
          "${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')} "
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

      // 결과 탭과 같은 줄(같은 규격·같은 길이끼리 묶음)로 표를 만든다. 규격을 아는 줄이 있으면 규격 칸을 넣는다.
      final resultLines = _resultLines();
      final bool showSpec = resultLines.any((l) => l.spec.isNotEmpty);
      final double grandTotal = resultLines.fold(0.0, (a, l) => a + l.totalMm);
      String specCell(ResultLine l) => l.spec.isEmpty ? "-" : l.spec;
      final List<String> headers;
      final List<List<String>> rows;
      // 세트가 여럿이면 개수가 어디서 나왔는지("구간 2개 × 3세트") 열을 넣는다.
      final bool showHow = _setMultiplier > 1;
      if (_groupSameLengths) {
        headers = [
          if (showSpec) "규격",
          "1개 길이(mm)",
          "개수",
          if (showHow) "개수 구성",
          "합계 길이(mm)",
        ];
        rows = [
          for (final l in resultLines)
            [
              if (showSpec) specCell(l),
              l.cutMm.toStringAsFixed(1),
              "${l.count}",
              if (showHow) l.countFormula.split(' = ').first,
              l.totalMm.toStringAsFixed(1),
            ],
        ];
      } else {
        headers = [
          "구간",
          if (showSpec) "규격",
          "1개 길이(mm)",
          "수량",
          if (showHow) "개수 구성",
          "합계 길이(mm)",
        ];
        rows = [
          for (final l in resultLines)
            [
              "PT${l.segments.first + 1} -> PT${l.segments.first + 2}",
              if (showSpec) specCell(l),
              l.cutMm.toStringAsFixed(1),
              "${l.count}",
              if (showHow) l.countFormula.split(' = ').first,
              l.totalMm.toStringAsFixed(1),
            ],
        ];
      }

      // 필요한 부속 표(부속을 쓴 경우만).
      final fittingOrders = _fittingOrders();
      final List<pw.Widget> fittingWidgets = fittingOrders.isEmpty
          ? const []
          : keepTogether([
              pw.SizedBox(height: 20),
              pw.Text(
                "필요한 부속",
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headers: kFittingHeaders,
                data: fittingTableRows(fittingOrders),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  font: koreanBold,
                ),
                cellStyle: pw.TextStyle(font: koreanFont),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                cellAlignment: pw.Alignment.centerLeft,
                border: pw.TableBorder.all(
                  color: PdfColors.grey400,
                  width: 0.5,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(fittingTableTotal(fittingOrders)),
              ),
            ], rows: fittingOrders.length);

      // 원자재 배치: 재단 최적화 화면과 같은 방식(저장해 둔 잔재 먼저 사용)으로 계산해서
      // 어느 원자재에서 어떤 길이를 자를지까지 지시서에 넣는다.
      final leftovers = await loadLeftovers();
      final mixLengths = await loadMixLengths();
      final groups = _collectRequiredPiecesByTubeSize();
      // 라인 모양(배치도)을 지시서에도 그려 넣는다.
      final diagramData = _diagramData();
      final diagramBody = buildDiagramPdfWidgets(
        points: diagramData.$1,
        segments: diagramData.$2,
        setMultiplier: _setMultiplier,
      );
      // "배치도" 제목이 쪽 맨 아래에 혼자 남지 않게 첫 지점과 묶는다.
      final List<pw.Widget> diagramWidgets = [
        ...keepTogether([
          pw.SizedBox(height: 20),
          pw.Text(
            "배치도",
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          if (diagramBody.isNotEmpty) diagramBody.first,
        ], rows: 0),
        ...diagramBody.skip(1),
      ];
      final List<pw.Widget> planWidgets = [];
      for (final e in groups.entries) {
        final groupLeftovers = [
          for (final l in leftovers)
            if (l.label == e.key) l.length,
        ];
        final r = mixLengths.isNotEmpty
            ? optimizeCuttingMixed(
                pieces: e.value,
                stockLengths: mixLengths,
                kerf: _bladeKerf,
                leftovers: groupLeftovers,
              )
            : optimizeCutting(
                pieces: e.value,
                stockLength: _stockLength,
                kerf: _bladeKerf,
                leftovers: groupLeftovers,
              );
        // 제목·요약·표를 한 덩어리로 묶어 쪽 경계에서 표 머리만 따로 남지 않게 한다.
        planWidgets.addAll(
          keepTogether([
            pw.SizedBox(height: 20),
            pw.Text(
              groups.length > 1 || e.key.isNotEmpty
                  ? "원자재 배치 - ${e.key.isEmpty ? '규격 미지정' : e.key}"
                  : "원자재 배치",
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(planSummary(r)),
            pw.SizedBox(height: 6),
            if (r.bars.isNotEmpty || r.leftoverBars.isNotEmpty)
              pw.TableHelper.fromTextArray(
                headers: kPlanHeaders,
                data: planRows(r),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  font: koreanBold,
                ),
                cellStyle: pw.TextStyle(font: koreanFont),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                cellAlignment: pw.Alignment.centerLeft,
                border: pw.TableBorder.all(
                  color: PdfColors.grey400,
                  width: 0.5,
                ),
              ),
            if (r.oversizedPieces.isNotEmpty)
              pw.Text(
                "원자재(${r.stockLength.toStringAsFixed(0)}mm)보다 길어 배치하지 못한 구간이 ${r.oversizedPieces.length}개 있습니다.",
              ),
          ], rows: r.bars.length + r.leftoverBars.length),
        );
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
                font: koreanBold,
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
                _setMultiplier > 1
                    ? "총 소요 길이: 1세트 ${(grandTotal / _setMultiplier).toStringAsFixed(1)} mm × $_setMultiplier세트 = ${grandTotal.toStringAsFixed(1)} mm"
                    : "총 소요 길이: ${grandTotal.toStringAsFixed(1)} mm",
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            ...fittingWidgets,
            ...diagramWidgets,
            ...planWidgets,
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

  // 배치도만 한 장짜리 PDF로 만들어 공유한다(현장에 라인 모양을 보여 줄 때).
  Future<void> _exportDiagramPdf() async {
    final data = _diagramData();
    if (!data.$2.any((s) => s.hasLength)) {
      showCuttingSnack(context, "내보낼 치수가 없습니다. 먼저 치수를 입력하십시오.", isError: true);
      return;
    }
    try {
      final pdfFonts = await loadKoreanPdfFonts();
      final pdf = pw.Document(theme: pdfFonts.theme);
      final now = DateTime.now();
      final dateStr =
          "${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}";
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Text(
              "배치도",
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text("프로젝트: ${widget.project.name}    작성일: $dateStr"),
            pw.SizedBox(height: 14),
            ...buildDiagramPdfWidgets(
              points: data.$1,
              segments: data.$2,
              setMultiplier: _setMultiplier,
            ),
          ],
        ),
      );
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/${widget.project.name}_배치도.pdf");
      await file.writeAsBytes(await pdf.save());
      if (!mounted) return;
      // ignore: deprecated_member_use
      await Share.shareXFiles([
        XFile(file.path),
      ], text: "${widget.project.name} 배치도입니다.");
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
    // 화면을 떠나면 실행 취소를 더는 할 수 없으니 스낵바도 걷는다.
    _undoToken = null;
    _undoTimer?.cancel();
    _undoMessenger?.clearSnackBars();
    WidgetsBinding.instance.removeObserver(this);
    _saveDraftState();
    for (var point in _points) {
      point.dispose();
    }
    _tabController.dispose();
    _diagramScrollController.dispose();
    _inputScrollController.dispose();
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
        'doneKeys': _doneKeys.toList(),
        'tubeSpec': _tubeSpec,
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
          _groupSameLengths = stateData['groupSameLengths'] ?? true;
          _tubeSpec = (stateData['tubeSpec'] as String?) ?? '';
          _doneKeys
            ..clear()
            ..addAll(
              ((stateData['doneKeys'] as List?) ?? const []).map(
                (e) => e.toString(),
              ),
            );
          _lengthUnit = stateData['lengthUnit'] ?? "mm";

          if (stateData['points'] != null) {
            for (var p in _points) {
              p.dispose();
            }

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
        final parsed = parseLengthInput(_points[i].c2cController.text);
        _points[i].unreadable = parsed.unreadable;
        if (parsed.value == null) {
          // 비었거나 숫자로 읽지 못한 칸은 계산에서 뺀다(예전에는 못 읽으면 조용히 0으로 계산했다).
          _points[i].calculatedCut = 0.0;
          _points[i].c2cMm = 0.0;
          continue;
        }

        final double c2cRaw = parsed.value!;
        // 🚀 [4번 강화] 공제값(deduction)은 항상 mm 기준(부속 DB)이라,
        // 입력값이 인치 모드면 계산 전에 먼저 mm로 환산한다. 계산/저장/
        // PDF/재단 최적화 등 이후 모든 로직은 계속 mm만 다루면 된다.
        _points[i].c2cMm = _lengthUnit == 'in' ? c2cRaw * kInchToMm : c2cRaw;
        _points[i].calculatedCut = cutLengthMm(
          c2cInput: c2cRaw,
          inputIsInch: _lengthUnit == 'in',
          startDeduction: _points[i].fitting.deduction,
          endDeduction: _points[i + 1].fitting.deduction,
        );
      }
      // 길이나 개수가 바뀌어 더는 목록에 없는 "잘랐음" 표시는 지운다.
      final live = {for (final l in _resultLines()) l.key};
      _doneKeys.removeWhere((k) => !live.contains(k));
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
      showCuttingSnack(context, "숫자를 인식하지 못했습니다. 다시 촬영해 주십시오.", isError: true);
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
        message: "현재 입력 중인 라인 구성이 템플릿 내용으로 바뀝니다. 계속하시겠습니까?",
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
      message: "이 템플릿을 삭제하시겠습니까? 되돌릴 수 없습니다.",
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
      message: "'$name' 세트를 삭제하시겠습니까?",
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
        "먼저 부속 검색 팝업에서 자주 쓰는 부속을 별표(즐겨찾기)해 주십시오.",
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
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
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
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
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

  // 🚀 [팝업 통일감] 부속 검색 팝업(SmartFittingSelectorSheet)과 똑같은
  // 흰 배경 + 원형 아이콘 헤더 + 닫기 버튼 형식으로 바꿨다. 예전엔 이
  // 팝업만 작은 중앙 Dialog 박스라 다른 부속 관련 팝업들과 인상이 달랐다.
  // 겸사겸사 (1) 이미 커스텀 부속이 적용된 구간을 다시 열면 값이 그대로
  // 채워지도록(예전엔 매번 빈 칸으로 초기화됨), (2) 자주 쓰는 품명을
  // 칩으로 바로 고르고, (3) 최근 입력한 커스텀 부속을 기기에 기억해뒀다가
  // 한 번 탭으로 재사용하도록, (4) 공제값 입력 단위를 계산기 화면의
  // mm/인치 토글과 맞춰 보여주도록 강화했다.
  static const List<String> _customFittingPresets = [
    "볼밸브",
    "니들밸브",
    "체크밸브",
    "유니온",
    "니플",
    "용접 소켓",
  ];

  Future<void> _showCustomFittingDialog(int index) async {
    final existing = _points[index].fitting;
    final bool isEditing = existing.category == "CUSTOM";
    final double existingDedInUnit = !isEditing
        ? 0.0
        : (_lengthUnit == 'in'
              ? existing.deduction / kInchToMm
              : existing.deduction);

    final nameCtrl = TextEditingController(
      text: isEditing ? existing.name : "커스텀 부속",
    );
    final specCtrl = TextEditingController(
      text: isEditing && existing.tubeOD != "미지정" ? existing.tubeOD : "",
    );
    final deductionCtrl = TextEditingController(
      text: isEditing && existing.deduction != 0
          ? _formatLocalLength(existingDedInUnit)
          : "",
    );

    final recents = await loadRecentCustomFittings();
    if (!mounted) return;

    Widget buildInputField({
      required String label,
      required String hint,
      required TextEditingController controller,
      bool isNumber = false,
      String? suffix,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: isNumber
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
            cursorColor: makitaTeal,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
              suffixText: suffix,
              suffixStyle: const TextStyle(
                color: makitaTeal,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: makitaTeal, width: 1.5),
              ),
            ),
          ),
        ],
      );
    }

    Widget buildChip(String label, VoidCallback onTap) {
      return Material(
        color: CuttingColors.primarySoft,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Text(
              label,
              style: const TextStyle(
                color: makitaDark,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      );
    }

    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(
              color: whiteCard,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        cuttingDialogIcon(Icons.extension_rounded),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            isEditing ? "커스텀 부속 수정" : "커스텀 부속 설정",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
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
                    if (recents.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        "최근 사용한 커스텀 부속",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 34,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: recents.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final r = recents[i];
                            final label = r.spec.isEmpty
                                ? r.name
                                : "${r.name} (${r.spec})";
                            return buildChip(label, () {
                              nameCtrl.text = r.name;
                              specCtrl.text = r.spec;
                              deductionCtrl.text = _formatLocalLength(
                                _lengthUnit == 'in'
                                    ? r.deduction / kInchToMm
                                    : r.deduction,
                              );
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else
                      const SizedBox(height: 12),
                    buildInputField(
                      label: "품명 (예: 볼 밸브, 체크 밸브)",
                      hint: "품명 입력",
                      controller: nameCtrl,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _customFittingPresets
                          .map((p) => buildChip(p, () => nameCtrl.text = p))
                          .toList(),
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
                      suffix: _lengthUnit,
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
                                borderRadius: BorderRadius.circular(10),
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
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () async {
                              final trimmedName = nameCtrl.text.trim();
                              final rawDed = deductionCtrl.text.trim();
                              final parsedDed = double.tryParse(rawDed);
                              if (trimmedName.isEmpty) {
                                showCuttingSnack(
                                  context,
                                  "품명을 입력해 주십시오.",
                                  isError: true,
                                );
                                return;
                              }
                              if (rawDed.isNotEmpty && parsedDed == null) {
                                showCuttingSnack(
                                  context,
                                  "공제값 숫자를 확인해 주십시오.",
                                  isError: true,
                                );
                                return;
                              }
                              final double dedInUnit = parsedDed ?? 0.0;
                              final double dedMm = _lengthUnit == 'in'
                                  ? dedInUnit * kInchToMm
                                  : dedInUnit;
                              final specStr = specCtrl.text.trim().isEmpty
                                  ? "미지정"
                                  : specCtrl.text.trim();

                              setState(() {
                                _points[index].fitting = FittingItem(
                                  id: "custom_${DateTime.now().millisecondsSinceEpoch}",
                                  category: "CUSTOM",
                                  name: trimmedName,
                                  tubeOD: specStr, // 🚀 규격 정확히 저장
                                  maker: "CUSTOM",
                                  deduction: dedMm,
                                  icon: Icons.extension,
                                );
                                _calculate();
                              });
                              await saveRecentCustomFitting(
                                RecentCustomFitting(
                                  name: trimmedName,
                                  spec: specStr == "미지정" ? "" : specStr,
                                  deduction: dedMm,
                                ),
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                            child: const Text(
                              "적용하기",
                              style: TextStyle(
                                color: whiteCard,
                                fontSize: 16,
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
        ),
      ),
    );
  }

  // 저장할 내용을 미리 계산한다(확인 창과 실제 저장이 같은 계산을 쓴다). 저장할 것이 없으면 null.
  _SavePlan? _buildSavePlan() {
    final double totalOneSet = _points
        .sublist(0, _points.length - 1)
        .fold(
          0.0,
          (acc, point) =>
              acc + (point.calculatedCut > 0 ? point.calculatedCut : 0.0),
        );
    final double baseMm = totalOneSet * _setMultiplier;
    if (baseMm <= 0) return null;

    // 🚀 [자재 관리용 완벽 분리] 제조사, 규격, 품명, 수량을 담을 객체 리스트
    final Map<String, Map<String, dynamic>> groupedFittings = {};
    for (var point in _points) {
      if (point.fitting.id != "none") {
        final String maker = point.fitting.category == "CUSTOM"
            ? "CUSTOM"
            : _globalMaker;
        final String spec = point.fitting.tubeOD;
        final String name = point.fitting.name;
        // 고유 식별 키 (제조사_규격_이름)
        final String uniqueKey = "${maker}_${spec}_$name";
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

    int totalFittingCount = 0;
    final List<Map<String, dynamic>> finalFittingsList = [];
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
    final List<CutRecord> cutRecords = [];
    final segSpecs = _segmentSpecs();
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
          tubeSize: segSpecs[i].isNotEmpty
              ? segSpecs[i]
              : (point.fitting.id != "none"
                    ? point.fitting.tubeOD
                    : nextFitting.tubeOD),
          // 쉼표(1200,5) 등으로 쓴 값도 읽은 값 그대로 남긴다.
          originalLength:
              parseLengthInput(point.c2cController.text).value ?? 0.0,
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
    return _SavePlan(
      baseMm: baseMm,
      kerfLossMm: kerfLoss,
      finalTotalMm: baseMm + kerfLoss,
      fittings: finalFittingsList,
      fittingCount: totalFittingCount,
      records: cutRecords,
    );
  }

  // "저장하기": 먼저 무엇이 저장되는지 확인을 받고, 승인하면 저장한다.
  Future<void> _saveRecord() async {
    if (_points.any(
      (p) => p.c2cController.text.isNotEmpty && p.calculatedCut < 0,
    )) {
      showCuttingSnack(
        context,
        "간섭이 발생한 구간이 있습니다. 치수를 확인해 주십시오!",
        isError: true,
      );
      return;
    }
    final plan = _buildSavePlan();
    if (plan == null) return;
    FocusScope.of(context).unfocus();

    final lines = _resultLines();
    final sum = summarizeResult(lines, _doneKeys);
    // 바깥(프로젝트)에 저장하는 화면은 되돌리는 콜백까지 있어야 실행 취소를 줄 수 있다.
    final bool canUndo =
        widget.onSaveCallback == null || widget.onUndoCallback != null;
    final ok = await showCuttingConfirmDialog(
      context,
      title: "저장하시겠습니까?",
      message: buildSaveConfirmMessage(
        baseMm: plan.baseMm,
        cutCount: plan.records.length,
        setMultiplier: _setMultiplier,
        kerfLossMm: plan.kerfLossMm,
        orders: _fittingOrders(),
        notDoneLines: sum.lineCount - sum.doneLines,
        anyDone: sum.anyDone,
        recordsToProject: widget.onSaveCallback != null,
        canUndo: canUndo,
        specs: specTotals(lines),
        unknownSpecLines: unknownSpecLineCount(lines),
      ),
      confirmLabel: "저장",
      icon: Icons.save_outlined,
    );
    if (!ok || !mounted) return;
    _commitSave(plan, canUndo);
  }

  void _commitSave(_SavePlan plan, bool canUndo) {
    // 되돌릴 때 입력을 그대로 살리기 위해, 지우기 전의 값을 붙잡아 둔다.
    final snapshot = _SavedSnapshot(
      plan: plan,
      texts: [for (final p in _points) p.c2cController.text],
      setMultiplier: _setMultiplier,
      doneKeys: {..._doneKeys},
    );

    setState(() {
      try {
        widget.project.recordUsage(
          tubeLengthMm: plan.finalTotalMm,
          fittings: {},
          multiplier: _setMultiplier,
        );
      } catch (e) {
        debugPrint("단독 모드 에러 무시: $e");
      }

      // 🚀 부모(ProjectManagementPage)의 바구니로 완벽하게 규격화된 데이터를 쏩니다!
      if (widget.onSaveCallback != null) {
        widget.onSaveCallback!(plan.finalTotalMm, plan.fittings, plan.records);
      }

      for (var point in _points) {
        point.c2cController.clear();
        point.calculatedCut = 0.0;
      }
      _setMultiplier = 1;
      _doneKeys.clear();
      _calculate();
    });

    final kerfNote = plan.kerfLossMm > 0
        ? " (커프 손실 +${plan.kerfLossMm.toStringAsFixed(1)}mm 포함)"
        : "";
    final msg =
        "튜브 총 ${plan.finalTotalMm.toStringAsFixed(1)}mm$kerfNote 및 피팅 ${plan.fittingCount}개 작업 완료!";
    if (canUndo) {
      final messenger = ScaffoldMessenger.of(context);
      _undoMessenger = messenger;
      final token = Object();
      _undoToken = token;
      showCuttingUndoSnack(
        context,
        msg,
        duration: const Duration(seconds: 10),
        onUndo: () => _undoSave(snapshot),
      );
      // 일부 폰(접근성 기능을 켠 경우)은 버튼이 달린 알림을 자동으로 걷지 않는다. 그러면 저장하기 버튼을
      // 계속 가리므로, 안내한 대로 10초 뒤에 직접 걷는다.
      _undoTimer?.cancel();
      _undoTimer = Timer(const Duration(seconds: 10), () {
        if (_undoToken == token) messenger.hideCurrentSnackBar();
      });
    } else {
      showCuttingSnack(context, msg);
    }
  }

  // 저장 직후 "실행 취소": 저장한 사용량·기록을 되돌리고 입력을 원래대로 채운다.
  Future<void> _undoSave(_SavedSnapshot s) async {
    if (!mounted) return;
    _undoToken = null;
    // 그 사이에 새로 입력한 값이 있으면 덮어쓰기 전에 한 번 더 묻는다.
    if (_points.any((p) => p.c2cController.text.trim().isNotEmpty)) {
      final ok = await showCuttingConfirmDialog(
        context,
        title: "저장을 되돌리시겠습니까?",
        message: "지금 입력한 값은 지워지고, 방금 저장한 내용이 입력 화면으로 돌아옵니다.",
        confirmLabel: "되돌리기",
        icon: Icons.undo_rounded,
      );
      if (!ok || !mounted) return;
    }

    setState(() {
      // 저장하며 더했던 값을 뺀다(메모리). 바깥에 저장한 것은 아래 콜백이 뺀다.
      try {
        widget.project.recordUsage(
          tubeLengthMm: -s.plan.finalTotalMm,
          fittings: {},
          multiplier: -s.setMultiplier,
        );
      } catch (e) {
        debugPrint("단독 모드 에러 무시: $e");
      }
      widget.onUndoCallback?.call(
        s.plan.finalTotalMm,
        s.plan.fittings,
        s.plan.records,
      );

      for (var i = 0; i < _points.length && i < s.texts.length; i++) {
        _points[i].c2cController.text = s.texts[i];
      }
      _setMultiplier = s.setMultiplier;
      _doneKeys
        ..clear()
        ..addAll(s.doneKeys);
      _calculate();
    });
    showCuttingSnack(context, "저장을 취소하고 입력을 되돌렸습니다.");
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
    // 아주 넓은 화면(가로로 놓은 태블릿·펼친 폴더블)은 입력 | 배치도 | 결과를 세 칸으로 나란히 둔다.
    // 그보다 좁으면 배치도와 결과를 위아래로 쌓아 오른쪽 한 칸에 둔다.
    if (MediaQuery.of(context).size.width >= 1000) {
      return Expanded(
        child: Row(
          children: [
            Expanded(flex: 4, child: _buildPointListPane()),
            Container(width: 1, color: Colors.black12),
            Expanded(flex: 4, child: _buildDiagramPane()),
            Container(width: 1, color: Colors.black12),
            Expanded(flex: 4, child: _buildInstructionsPane()),
          ],
        ),
      );
    }
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
  // 세트 수(× N SET) 조절. 입력 탭 아래 요약 줄과 결과 탭이 같은 값을 함께 쓴다.
  Widget _buildSetStepper() {
    return Container(
      decoration: BoxDecoration(
        color: whiteCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: makitaTeal),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const Key('set_minus'),
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
            key: const Key('set_plus'),
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
    );
  }

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
                      "카드를 길게 눌러 드래그하면 순서를 바꿀 수 있습니다",
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
          const SizedBox(height: 8),
          // 자를 튜브 규격. 결과 탭의 규격 버튼과 같은 값(같은 고르는 창)을 함께 쓴다.
          InkWell(
            key: const Key('input_spec_picker'),
            borderRadius: BorderRadius.circular(10),
            onTap: _pickTubeSpec,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: whiteCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.straighten_rounded,
                    size: 18,
                    color: makitaTeal,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _tubeSpec.isEmpty
                          ? "튜브 규격: 부속 기준(자동)"
                          : "튜브 규격: $_tubeSpec",
                      key: const Key('input_spec_label'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down_rounded, color: makitaTeal),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ReorderableListView.builder(
              scrollController: _inputScrollController,
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
  // 화면의 지점·구간 값을 배치도 그림에 넘길 목록으로 옮긴다.
  (List<DiagramPoint>, List<DiagramSegment>) _diagramData() {
    final pts = [for (final p in _points) DiagramPoint.fromFitting(p.fitting)];
    final segs = <DiagramSegment>[];
    for (int i = 0; i < _points.length - 1; i++) {
      final p = _points[i];
      final text = p.c2cController.text.trim();
      final SegmentState state = text.isEmpty
          ? SegmentState.empty
          : p.unreadable
          ? SegmentState.unreadable
          : (p.calculatedCut < 0 ? SegmentState.interference : SegmentState.ok);
      segs.add(
        DiagramSegment(
          state: state,
          c2cMm: p.c2cMm,
          cutMm: p.calculatedCut,
          startDeduction: p.fitting.deduction,
          endDeduction: _points[i + 1].fitting.deduction,
        ),
      );
    }
    return (pts, segs);
  }

  // 배치도에서 지점을 누르면 입력 탭으로 넘어가서 그 지점의 길이 칸에 커서를 둔다(마지막 지점은
  // 뒤에 이어지는 구간이 없어서 목록 끝으로만 넘어간다). 목록이 아직 그려지지 않았으면 위치를
  // 어림해서 스크롤한 뒤 몇 번 다시 시도한다.
  Future<void> _jumpToInputPoint(int index) async {
    HapticFeedback.selectionClick();
    setState(() => _focusedPointIndex = index);
    _tabController.animateTo(0);
    final bool hasField = index < _points.length - 1;
    final node = _points[index].c2cFocusNode;
    for (int attempt = 0; attempt < 8; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 60));
      if (!mounted) return;
      final ctx = hasField ? node.context : null;
      if (ctx != null && ctx.mounted) {
        await Scrollable.ensureVisible(
          ctx,
          alignment: 0.25,
          duration: const Duration(milliseconds: 250),
        );
        if (!mounted) return;
        FocusScope.of(context).requestFocus(node);
        return;
      }
      if (_inputScrollController.hasClients) {
        final pos = _inputScrollController.position;
        final n = _points.length - 1;
        final target = n <= 0 ? 0.0 : pos.maxScrollExtent * (index / n);
        _inputScrollController.jumpTo(target.clamp(0.0, pos.maxScrollExtent));
        if (!hasField) return;
      }
    }
  }

  Widget _buildDiagramPane() {
    final data = _diagramData();
    return Container(
      color: whiteCard,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "배치도",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
                  ),
                ),
              ),
              IconButton(
                key: const Key('diagram_share'),
                tooltip: "배치도 PDF로 공유",
                icon: const Icon(Icons.ios_share_rounded, color: makitaTeal),
                onPressed: _exportDiagramPdf,
              ),
            ],
          ),
          Text(
            "지점을 누르면 입력 화면에서 바로 고치고, 길게 누르면 부속을 바꿀 수 있습니다",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: CuttingDiagramView(
              points: data.$1,
              segments: data.$2,
              focusedIndex: _focusedPointIndex,
              controller: _diagramScrollController,
              setMultiplier: _setMultiplier,
              onTapPoint: _jumpToInputPoint,
              onLongPressPoint: (i) {
                HapticFeedback.mediumImpact();
                setState(() => _focusedPointIndex = i);
                _openFittingSelector(i);
              },
            ),
          ),
        ],
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
          Row(
            children: [
              const Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "컷팅 지시서",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                    ),
                  ),
                ),
              ),
              // 재단 최적화, PDF 만들어 공유, 카카오톡으로 글 보내기, 글로 복사. 길게 누르면 이름이 뜬다.
              CutActionBar(
                showLabels: !_iconsUsed || _labelsPinned,
                // 처음 쓰기 전에는 이름이 이미 보이니 "?" 버튼을 두지 않는다.
                onToggleLabels: _iconsUsed
                    ? () {
                        HapticFeedback.selectionClick();
                        setState(() => _labelsPinned = !_labelsPinned);
                      }
                    : null,
                actions: [
                  CutActionSpec(
                    key: const Key('result_btn_optimize'),
                    label: "재단 최적화",
                    icon: const CutBarIcon(size: 21),
                    onPressed: () {
                      _markIconsUsed();
                      _showOptimizationDialog();
                    },
                  ),
                  CutActionSpec(
                    key: const Key('result_btn_export'),
                    label: "PDF 공유",
                    icon: const Icon(
                      Icons.picture_as_pdf_rounded,
                      size: 19,
                      color: makitaTeal,
                    ),
                    onPressed: () {
                      _markIconsUsed();
                      _exportCuttingList();
                    },
                  ),
                  CutActionSpec(
                    key: const Key('result_btn_kakao'),
                    label: "카톡 보내기",
                    icon: const Icon(
                      Icons.chat_bubble_rounded,
                      size: 19,
                      color: makitaTeal,
                    ),
                    onPressed: () {
                      _markIconsUsed();
                      _sendToKakao();
                    },
                  ),
                  CutActionSpec(
                    key: const Key('result_btn_copy'),
                    label: "글 복사",
                    icon: const Icon(
                      Icons.copy_rounded,
                      size: 19,
                      color: makitaTeal,
                    ),
                    onPressed: () {
                      _markIconsUsed();
                      _copyInstruction();
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
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
              _buildSetStepper(),
            ],
          ),
          const SizedBox(height: 10),
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
    final bool unreadable = hasInput && _points[index].unreadable;
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
                              color: (isInterference || unreadable)
                                  ? Colors.red
                                  : Colors.grey.shade300,
                              width: (isInterference || unreadable) ? 2 : 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: (isInterference || unreadable)
                                  ? Colors.red
                                  : makitaTeal,
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
              // 어떻게 나온 절단 길이인지(중심 간 거리 − 양쪽 공제값) 바로 보여 준다.
              if (hasInput &&
                  !unreadable &&
                  !isInterference &&
                  _points[index].calculatedCut > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    cutBreakdownText(
                      c2cMm: _points[index].c2cMm,
                      startDeduction: startItem.deduction,
                      endDeduction: endItem.deduction,
                    ),
                    key: Key('cut_breakdown_$index'),
                    style: const TextStyle(
                      color: makitaTeal,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              if (unreadable)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Colors.red,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          "숫자로 읽을 수 없습니다. 예: 1200 또는 1200.5",
                          key: Key('unreadable_$index'),
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
                          "절단 길이가 매우 짧습니다. 치수를 다시 확인해 주십시오.",
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

  // 구간별 튜브 규격: 양쪽 부속에서 알 수 있으면 그 규격, 모르면 사용자가 지정한 규격.
  List<String> _segmentSpecs() => [
    for (int i = 0; i < _points.length - 1; i++)
      tubeSpecFor(
        startIsFitting: _points[i].fitting.id != "none",
        startOD: _points[i].fitting.tubeOD,
        endIsFitting: _points[i + 1].fitting.id != "none",
        endOD: _points[i + 1].fitting.tubeOD,
        fallback: _tubeSpec,
      ),
  ];

  // 결과 탭에 보여 줄 줄들(같은 길이 합산 여부에 따라 묶음이 달라진다).
  List<ResultLine> _resultLines() => buildResultLines(
    [
      for (int i = 0; i < _points.length - 1; i++)
        (_points[i].c2cController.text.trim().isNotEmpty &&
                !_points[i].unreadable &&
                _points[i].calculatedCut > 0)
            ? _points[i].calculatedCut
            : null,
    ],
    _setMultiplier,
    grouped: _groupSameLengths,
    specs: _segmentSpecs(),
  );

  List<FittingOrder> _fittingOrders() => fittingOrderList([
    for (final p in _points)
      if (p.fitting.id != "none")
        FittingUse(
          maker: p.fitting.category == "CUSTOM" ? "CUSTOM" : _globalMaker,
          spec: p.fitting.tubeOD,
          name: p.fitting.name,
        ),
  ], _setMultiplier);

  void _toggleDone(String key) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_doneKeys.remove(key)) _doneKeys.add(key);
    });
    _saveDraftState();
  }

  // 튜브 규격(제원) 고르기. 부속에서 규격을 알 수 없는 구간에만 적용된다.
  Future<void> _pickTubeSpec() async {
    final sizes = SmartFittingDB.tubeSizes;
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      // 다른 컷팅 팝업처럼 흰 바탕에 진한 글씨로 보이게 한다.
      backgroundColor: CuttingColors.surface,
      builder: (ctx) => Theme(
        data: Theme.of(ctx).copyWith(
          listTileTheme: const ListTileThemeData(
            textColor: CuttingColors.textPrimary,
            subtitleTextStyle: TextStyle(
              fontSize: 12,
              color: CuttingColors.textSecondary,
            ),
          ),
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: CuttingColors.textPrimary),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text(
                      "자를 튜브 규격",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text(
                      "부속에서 규격을 알 수 있는 구간은 그 규격을 따르고, 나머지 구간에만 여기서 고른 규격을 씁니다.",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  ListTile(
                    key: const Key('spec_option_auto'),
                    title: const Text("부속 기준 (자동)"),
                    trailing: _tubeSpec.isEmpty
                        ? const Icon(Icons.check_rounded, color: makitaTeal)
                        : null,
                    onTap: () => Navigator.pop(ctx, ''),
                  ),
                  for (final size in sizes)
                    ListTile(
                      key: Key('spec_option_$size'),
                      title: Text("튜브 $size"),
                      trailing: _tubeSpec == size
                          ? const Icon(Icons.check_rounded, color: makitaTeal)
                          : null,
                      onTap: () => Navigator.pop(ctx, size),
                    ),
                  ListTile(
                    key: const Key('spec_option_custom'),
                    leading: const Icon(Icons.edit_rounded, color: makitaTeal),
                    title: const Text("직접 입력"),
                    subtitle: const Text("예: 12mm, 1/2\" × 0.049T"),
                    onTap: () => Navigator.pop(ctx, '\u0000custom'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    var value = picked;
    if (picked == '\u0000custom') {
      final ctrl = TextEditingController(text: _tubeSpec);
      final typed = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16),
          title: const Text("튜브 규격 직접 입력"),
          content: TextField(
            key: const Key('spec_custom_field'),
            controller: ctrl,
            autofocus: true,
            maxLength: 24,
            decoration: const InputDecoration(
              hintText: "예: 12mm, 1/2\" × 0.049T",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("취소"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text("확인"),
            ),
          ],
        ),
      );
      if (typed == null || !mounted) return;
      value = typed;
    }
    setState(() => _tubeSpec = value);
    _calculate(); // 규격이 바뀌면 잘랐음 표시도 정리하고 임시 저장한다.
  }

  // 지시서 글을 만든다(복사·카카오톡 보내기가 같은 글을 쓴다). 치수가 없으면 null.
  String? _instructionText() {
    final lines = _resultLines();
    if (lines.isEmpty) return null;
    return buildInstructionText(
      projectName: widget.project.name,
      date: DateTime.now(),
      maker: _globalMaker,
      setMultiplier: _setMultiplier,
      lines: lines,
      orders: _fittingOrders(),
      kerfMm: _bladeKerf,
    );
  }

  // 지시서 글을 카카오톡으로 바로 보낸다(대화방 고르는 화면으로 넘어간다). 카카오톡이 없으면 일반 공유창으로 보낸다.
  Future<void> _sendToKakao() async {
    final text = _instructionText();
    if (text == null) {
      showCuttingSnack(context, "보낼 치수가 없습니다. 먼저 치수를 입력하십시오.", isError: true);
      return;
    }
    if (await kakaoSender(text)) return;
    if (!mounted) return;
    try {
      await textSharer(text);
      if (!mounted) return;
      showCuttingSnack(context, "카카오톡을 찾지 못해 공유창으로 보냈습니다.");
    } catch (e) {
      if (!mounted) return;
      showCuttingSnack(context, "보내기 실패: $e", isError: true);
    }
  }

  // 지시서를 글로 복사한다(카카오톡 등에 바로 붙여넣기).
  Future<void> _copyInstruction() async {
    final text = _instructionText();
    if (text == null) {
      showCuttingSnack(context, "복사할 치수가 없습니다. 먼저 치수를 입력하십시오.", isError: true);
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    showCuttingSnack(context, "지시서를 글로 복사했습니다. 메신저에 붙여넣으십시오.");
  }

  Widget _buildCuttingListRenderer() {
    final lines = _resultLines();
    final diag = _diagramData();
    final d = summarizeDiagram(diag.$1, diag.$2, _setMultiplier);
    final issues = [
      if (d.unreadableCount > 0) '읽을 수 없는 값 ${d.unreadableCount}곳',
      if (d.interferenceCount > 0) '간섭 ${d.interferenceCount}곳',
    ];
    return CuttingResultView(
      lines: lines,
      summary: summarizeResult(lines, _doneKeys),
      orders: _fittingOrders(),
      done: _doneKeys,
      onToggle: _toggleDone,
      setMultiplier: _setMultiplier,
      warning: issues.isEmpty ? '' : '목록에서 뺀 구간: ${issues.join(' · ')}',
      emptyMessage: d.interferenceCount > 0
          ? "간섭이 발생한 구간을 수정하십시오."
          : "치수를 입력하십시오.",
      emptyIsError: d.interferenceCount > 0,
      tubeSpec: _tubeSpec,
      onPickSpec: _pickTubeSpec,
    );
  }
}

// 저장할 내용(확인 창과 실제 저장이 함께 쓴다).
class _SavePlan {
  final double baseMm; // 톱날 손실을 뺀 길이
  final double kerfLossMm;
  final double finalTotalMm; // 기록되는 총 길이(톱날 손실 포함)
  final List<Map<String, dynamic>> fittings;
  final int fittingCount;
  final List<CutRecord> records;

  const _SavePlan({
    required this.baseMm,
    required this.kerfLossMm,
    required this.finalTotalMm,
    required this.fittings,
    required this.fittingCount,
    required this.records,
  });
}

// 저장 직전의 입력 상태(실행 취소로 되살릴 때 쓴다).
class _SavedSnapshot {
  final _SavePlan plan;
  final List<String> texts;
  final int setMultiplier;
  final Set<String> doneKeys;

  const _SavedSnapshot({
    required this.plan,
    required this.texts,
    required this.setMultiplier,
    required this.doneKeys,
  });
}
