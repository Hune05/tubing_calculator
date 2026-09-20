import 'dart:io';

import '../../../core/utils/pdf_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, HapticFeedback;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/models/steel_cutting_project_model.dart';
import '../../../data/models/steel_shape_db.dart';
import '../../tube_cutting/cutting_action_bar.dart';
import '../../tube_cutting/cutting_diagram_pdf.dart' show keepTogether;
import '../../tube_cutting/cutting_leftovers.dart';
import '../../tube_cutting/cutting_math.dart' show fmtMm;
import '../../tube_cutting/cutting_optimizer.dart';
import '../../tube_cutting/cutting_plan_rows.dart';
import '../../tube_cutting/cutting_result_logic.dart';
import '../../tube_cutting/cutting_result_view.dart';
import '../../tube_cutting/cutting_theme.dart';
import '../../tube_cutting/widgets/cutting_optimization_sheet.dart';
import '../steel_result_logic.dart';
import '../steel_weight.dart';
import '../steel_shape_icons.dart';
import '../widgets/steel_item_sheet.dart';
import 'steel_cutting_history_page.dart';

// 🚀 [형강 컷팅 신규] 찬넬/앵글처럼 피팅 없이 그냥 "규격 - 길이 - 수량"만
// 있는 단순 절단 작업 전용 화면. 튜브 컷팅 계산기와 달리 라인(구간)을
// 조립할 필요가 없어서, 목록에 항목을 추가하고 바로 재단 최적화·지시서
// 출력으로 넘어가는 훨씬 짧은 흐름으로 만들었다. 재단 최적화는 튜브
// 컷팅과 완전히 같은 다중 규격 조합 FFD 빈 패킹(cutting_optimizer.dart)을
// 공용 시트(cutting_optimization_sheet.dart)로 그대로 재사용한다.
class SteelCuttingDetailScreen extends StatefulWidget {
  final SteelCuttingProject project;

  const SteelCuttingDetailScreen({super.key, required this.project});

  @override
  State<SteelCuttingDetailScreen> createState() =>
      _SteelCuttingDetailScreenState();
}

class _SteelCuttingDetailScreenState extends State<SteelCuttingDetailScreen>
    with SingleTickerProviderStateMixin {
  late List<SteelCutItem> _items;
  late double _stockLength;
  late int _setMultiplier;
  double _bladeKerf = 0.0;
  String _categoryFilter = '전체';
  // 결과 탭에서 "잘랐음"으로 표시한 줄(프로젝트마다 이 폰에 저장한다).
  final Set<String> _doneKeys = {};
  // 아이콘 이름: 처음 쓰기 전에는 보이고, 써 본 뒤에는 "?"로 다시 볼 수 있다(튜브 컷팅과 같은 설정을 함께 쓴다).
  static const String _kIconsUsedKey = 'cutting_result_icons_used';
  bool _iconsUsed = true;
  bool _labelsPinned = false;

  // 🚀 [튜브 컷팅에 준한 페이지 구성] 튜브 컷팅 계산기와 같은 방식으로
  // 넓은 화면(태블릿/폴더블 펼침)에서는 입력/결과를 좌우 2단으로 동시에
  // 보여주고, 좁은 화면(폰)에서는 "입력"/"결과" 탭으로 나눠 한 화면에
  // 하나씩 전체 폭을 쓰게 한다. 형강은 배치도(다이어그램) 개념이 없어서
  // 튜브의 3탭(입력/배치도/결과)이 아니라 2탭만 쓴다.
  late final TabController _tabController;

  // 🚀 톱날 손실은 어차피 같은 톱으로 자르는 같은 물리 현상이라, 튜브
  // 컷팅 화면(cutting_main_screen.dart)과 같은 SharedPreferences 키를
  // 그대로 공유한다 - 톱을 바꾸지 않는 한 두 화면에서 각각 새로 입력할
  // 필요가 없다.
  static const String _kerfPrefsKey = 'cutting_blade_kerf';
  // 칩: 전체 + 지금 항목에 있는 종류만(없는 종류 칩은 두지 않는다).
  List<String> get _categories {
    final present = <String>{};
    for (final i in _items) {
      present.add(SteelShapeDB.categoryLabel(i.category));
    }
    final ordered = <String>[
      for (final c in SteelShapeDB.categories)
        if (present.contains(c.label)) c.label,
      if (present.contains(SteelShapeDB.customCategory.label))
        SteelShapeDB.customCategory.label,
      if (present.contains('기타')) '기타',
    ];
    return ['전체', ...ordered];
  }

  String get _doneKey => 'steel_done_${widget.project.id}';
  // 남는 토막을 저장한 때의 결과 줄 모양(줄 열쇠를 이은 글). 지금 줄과 같으면 "이 결과의 토막은 이미 저장함".
  String get _leftoverKey => 'steel_leftover_saved_${widget.project.id}';
  String _leftoverSavedSig = '';

  String get _linesSig => _resultLines().map((l) => l.key).join('|');
  bool get _leftoversSaved =>
      _leftoverSavedSig.isNotEmpty && _leftoverSavedSig == _linesSig;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _items = List.of(widget.project.items);
    _stockLength = widget.project.stockLength;
    _setMultiplier = widget.project.setMultiplier;
    _loadBladeKerf();
    _loadDone();
    _loadIconsUsed();
  }

  Future<void> _loadDone() async {
    try {
      final p = await SharedPreferences.getInstance();
      final saved = p.getStringList(_doneKey) ?? const <String>[];
      final sig = p.getString(_leftoverKey) ?? '';
      if (!mounted) return;
      setState(() {
        _doneKeys.addAll(saved);
        _leftoverSavedSig = sig;
      });
      _pruneDone();
    } catch (_) {}
  }

  Future<void> _saveDone() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_doneKey, _doneKeys.toList());
    } catch (_) {}
  }

  // 항목을 고치거나 세트 수를 바꿔서 없어진 줄의 "잘랐음" 표시는 버린다.
  void _pruneDone() {
    final live = {for (final l in _resultLines()) l.key};
    final before = _doneKeys.length;
    _doneKeys.removeWhere((k) => !live.contains(k));
    if (_doneKeys.length != before) {
      setState(() {});
      _saveDone();
    }
  }

  Future<void> _loadIconsUsed() async {
    try {
      final used =
          (await SharedPreferences.getInstance()).getBool(_kIconsUsedKey) ??
          false;
      if (mounted && !used) setState(() => _iconsUsed = false);
    } catch (_) {}
  }

  void _markIconsUsed() {
    if (_labelsPinned) setState(() => _labelsPinned = false);
    if (_iconsUsed) return;
    setState(() => _iconsUsed = true);
    SharedPreferences.getInstance()
        .then((p) => p.setBool(_kIconsUsedKey, true))
        .catchError((_) => false);
  }

  List<ResultLine> _resultLines() =>
      buildSteelResultLines(_items, _setMultiplier);

  void _toggleDone(String key) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_doneKeys.remove(key)) _doneKeys.add(key);
    });
    _saveDone();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<SteelCutItem> get _filteredItems {
    if (_categoryFilter == '전체') return _items;
    return _items
        .where((i) => SteelShapeDB.categoryLabel(i.category) == _categoryFilter)
        .toList();
  }

  Future<void> _loadBladeKerf() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_kerfPrefsKey);
    if (saved != null && mounted) setState(() => _bladeKerf = saved);
  }

  Future<void> _showKerfDialog() async {
    final result = await showBladeKerfDialog(context, _bladeKerf);
    if (result != null) {
      setState(() => _bladeKerf = result);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kerfPrefsKey, result);
    }
  }

  DocumentReference<Map<String, dynamic>> get _docRef => FirebaseFirestore
      .instance
      .collection(kSteelCuttingProjectsCollection)
      .doc(widget.project.id);

  Future<void> _persistItems() async {
    _pruneDone();
    await _docRef.update({'items': _items.map((e) => e.toMap()).toList()});
  }

  Future<void> _persistStockLength(double v) async {
    await _docRef.update({'stockLength': v});
  }

  Future<void> _persistSetMultiplier(int v) async {
    _pruneDone();
    await _docRef.update({'setMultiplier': v});
  }

  // 🚀 [형강 컷팅 기록 신규] 항목을 추가/수정/삭제/복제할 때마다 자동으로
  // 남기는 변경 기록. 되돌리기(실행 취소)로 다시 사라지는 항목까지
  // 기록하면 노이즈만 늘어나므로, 사용자가 의도적으로 한 정방향 동작만
  // 남기고 실행 취소 자체는 별도로 기록하지 않는다.
  Future<void> _logChange(String action, SteelCutItem item) async {
    await _docRef
        .collection(kSteelChangeLogSubcollection)
        .add(
          SteelChangeLogEntry(
            id: '',
            action: action,
            category: item.category,
            shapeLabel: item.shapeLabel,
            length: item.length,
            qty: item.qty,
            note: item.note,
            timestamp: DateTime.now(),
          ).toMap(),
        );
  }

  // 🚀 [규격별 분리] 앵글과 찬넬처럼 서로 다른 규격은 같은 원자재(본)에서
  // 나올 수 없으니, 재단 최적화는 규격(shapeLabel)별로 따로 계산해야
  // 실제로 현장에서 그대로 따라 할 수 있는 지시서가 나온다.
  Map<String, List<double>> _collectPiecesByShape() {
    final Map<String, List<double>> byShape = {};
    for (final item in _items) {
      final list = byShape.putIfAbsent(item.shapeLabel, () => []);
      for (int k = 0; k < item.qty * _setMultiplier; k++) {
        list.add(item.length);
      }
    }
    return byShape;
  }

  void _addItem() {
    HapticFeedback.lightImpact();
    showSteelItemSheet(
      context,
      onSave: (item) {
        setState(() => _items.add(item));
        _persistItems();
        _logChange('ADD', item);
      },
    );
  }

  void _editItem(SteelCutItem item) {
    showSteelItemSheet(
      context,
      existing: item,
      onSave: (updated) {
        setState(() {
          final idx = _items.indexWhere((e) => e.id == item.id);
          if (idx >= 0) _items[idx] = updated;
        });
        _persistItems();
        _logChange('EDIT', updated);
      },
    );
  }

  void _duplicateItem(SteelCutItem item) {
    final copy = SteelCutItem(
      id: '${DateTime.now().millisecondsSinceEpoch}_dup',
      category: item.category,
      shapeLabel: item.shapeLabel,
      length: item.length,
      qty: item.qty,
      note: item.note,
    );
    setState(() => _items.add(copy));
    _persistItems();
    _logChange('DUPLICATE', copy);
    showCuttingUndoSnack(
      context,
      "'${item.shapeLabel}' 항목을 복제했습니다.",
      onUndo: () {
        setState(() => _items.removeWhere((e) => e.id == copy.id));
        _persistItems();
      },
    );
  }

  void _deleteItem(SteelCutItem item) {
    final index = _items.indexOf(item);
    setState(() => _items.removeWhere((e) => e.id == item.id));
    _persistItems();
    _logChange('DELETE', item);
    showCuttingUndoSnack(
      context,
      "'${item.shapeLabel}' ${item.length.toStringAsFixed(0)}mm 항목을 삭제했습니다.",
      onUndo: () {
        setState(() => _items.insert(index.clamp(0, _items.length), item));
        _persistItems();
      },
    );
  }

  // 재단 최적화에서 "잘랐습니다"를 눌러 남는 토막을 저장했을 때: 결과의 모든 줄을 "잘랐음"으로 맞추고, 이 결과의
  // 토막은 저장했다고 적어 둔다(항목이나 세트를 바꾸면 저절로 "아직 저장 안 함"으로 돌아간다).
  void _onLeftoversSaved() {
    if (!mounted) return;
    setState(() {
      _doneKeys.addAll(_resultLines().map((l) => l.key));
      _leftoverSavedSig = _linesSig;
    });
    _saveDone();
    SharedPreferences.getInstance()
        .then((p) => p.setString(_leftoverKey, _leftoverSavedSig))
        .catchError((_) => false);
  }

  Future<void> _showOptimization() async {
    await showCuttingOptimizationSheet(
      context,
      groupedPieces: _collectPiecesByShape(),
      initialStockLength: _stockLength,
      kerf: _bladeKerf,
      mixPrefsKey: kSteelMixPrefsKey,
      onLeftoversSaved: _onLeftoversSaved,
      leftoversAlreadySaved: _leftoversSaved,
      title: "재단 최적화 (원자재 소요 계산)",
      onStockLengthChanged: (v) {
        setState(() => _stockLength = v);
        _persistStockLength(v);
      },
    );
  }

  // 지시서 PDF: 자를 길이 표(1개 길이 × 개수 = 합계) + 규격별 원자재 배치. 남은 토막과 여러 길이 섞어 쓰기
  // 설정도 재단 최적화 화면과 같게 반영한다.
  Future<void> _exportInstructionSheet() async {
    final lines = _resultLines();
    if (lines.isEmpty) {
      showCuttingSnack(
        context,
        "내보낼 항목이 없습니다. 먼저 절단 항목을 추가하십시오.",
        isError: true,
      );
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

      pw.Widget table(List<String> headers, List<List<String>> data) =>
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: data,
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              font: koreanBold,
            ),
            cellStyle: pw.TextStyle(font: koreanFont),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          );

      // 1) 자를 길이 표 — 규격마다 소계 줄을 넣는다.
      final bool showHow = _setMultiplier > 1;
      final subs = shapeSubtotals(lines);
      final weights = weightTotals(lines);
      final bool weightKnown = weights.total != null;
      final headers = [
        "규격",
        "1개 길이(mm)",
        "개수",
        if (showHow) "개수 구성",
        "합계 길이(mm)",
        if (weightKnown) "중량(kg)",
        "비고",
      ];
      final rows = <List<String>>[];
      for (final sub in subs) {
        for (final l in lines.where((x) => x.spec == sub.shape)) {
          rows.add([
            l.spec,
            fmtMm(l.cutMm),
            "${l.count}",
            if (showHow) "${l.baseCount}개 × ${l.sets}세트",
            fmtMm(l.totalMm),
            if (weightKnown)
              steelWeightKg(l.spec, l.totalMm) == null
                  ? "-"
                  : "약 ${fmtKg(steelWeightKg(l.spec, l.totalMm)!)}",
            l.detail,
          ]);
        }
      }
      final grandTotal = lines.fold(0.0, (a, l) => a + l.totalMm);

      // 2) 규격별 원자재 배치(남은 토막·섞어 쓰기 반영).
      final leftovers = await loadLeftovers();
      final mixLengths = await loadMixLengths(kSteelMixPrefsKey);
      final piecesByShape = _collectPiecesByShape();
      final planWidgets = <pw.Widget>[];
      var totalBars = 0;
      var totalWaste = 0.0;
      var totalOversized = 0;
      for (final e in piecesByShape.entries) {
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
        totalBars += r.barCount;
        totalWaste += r.totalWaste;
        totalOversized += r.oversizedPieces.length;
        final usage = r.totalStock > 0
            ? (r.totalUsed / r.totalStock * 100).toStringAsFixed(1)
            : '0.0';
        // 제목·요약·표를 한 덩어리로 묶어 쪽 경계에서 표 머리만 따로 남지 않게 한다.
        planWidgets.addAll(
          keepTogether([
            pw.SizedBox(height: 12),
            pw.Text(
              e.key,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                font: koreanBold,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              "${planSummary(r)} · 로스 ${r.totalWaste.toStringAsFixed(0)}mm · 사용률 $usage%",
            ),
            pw.SizedBox(height: 6),
            if (r.bars.isNotEmpty || r.leftoverBars.isNotEmpty)
              table(kPlanHeaders, planRows(r)),
            if (r.oversizedPieces.isNotEmpty)
              pw.Text(
                "원자재(${r.stockLength.toStringAsFixed(0)}mm)보다 길어 배치하지 못한 항목 ${r.oversizedPieces.length}건",
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.red),
              ),
          ], rows: r.bars.length + r.leftoverBars.length),
        );
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Text(
              "형강 컷팅 지시서",
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text("프로젝트: ${widget.project.name}"),
            pw.Text("작성일시: $dateStr"),
            pw.Text(
              "원자재 기준 길이: ${_stockLength.toStringAsFixed(0)}mm    세트 수: $_setMultiplier SET"
              "${_bladeKerf > 0 ? '    톱날 손실: ${_bladeKerf.toStringAsFixed(1)}mm/회' : ''}",
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              "1. 자를 길이",
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            table(headers, rows),
            pw.SizedBox(height: 8),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                _setMultiplier > 1
                    ? "총 소요 길이: 1세트 ${fmtMm(grandTotal / _setMultiplier)} mm × $_setMultiplier세트 = ${fmtMm(grandTotal)} mm"
                    : "총 소요 길이: ${fmtMm(grandTotal)} mm",
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            if (weightKnown)
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  "총 중량: 약 ${fmtKg(weights.total!)} kg (이론값"
                  "${weights.unknownSpecs > 0 ? ', 중량을 모르는 규격 ${weights.unknownSpecs}종 제외' : ''}"
                  ", 실제와 다를 수 있음)",
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
            pw.SizedBox(height: 20),
            pw.Text(
              "2. 원자재별 배치 (재단 최적화, 총 $totalBars본 - 규격별로 각각 계산됨)",
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            ...planWidgets,
            if (totalOversized > 0) ...[
              pw.SizedBox(height: 8),
              pw.Text(
                "원자재보다 긴 항목 총 $totalOversized건은 배치에서 제외됨 - 원자재 기준 길이를 확인하십시오.",
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.red),
              ),
            ],
            pw.SizedBox(height: 8),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                "총 로스: ${totalWaste.toStringAsFixed(0)} mm",
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File("${output.path}/${widget.project.name}_형강컷팅지시서.pdf");
      await file.writeAsBytes(await pdf.save());

      if (!mounted) return;
      // ignore: deprecated_member_use
      await Share.shareXFiles([
        XFile(file.path),
      ], text: "${widget.project.name} 형강 컷팅 지시서입니다.");
    } catch (e) {
      if (!mounted) return;
      showCuttingSnack(context, "내보내기 실패: $e", isError: true);
    }
  }

  // 🚀 [튜브 컷팅에 준한 페이지 구성] 튜브 컷팅 계산기(cutting_main_screen.dart)의
  // AppBar와 똑같이 브랜드 틸 색 배경 + 흰 글씨, 제목은 "프로젝트: 이름"
  // 형식으로 맞췄다. 다른 컷팅 관련 화면들이 최근 흰 배경 AppBar로
  // 통일됐지만, 실제로 매일 쓰는 계산기 화면(cutting_main_screen)만은
  // 이 틸 색 헤더를 그대로 쓰고 있어서 - 사용자가 "마음에 든다"고 콕
  // 짚은 게 바로 이 화면이었다.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CuttingColors.background,
      appBar: AppBar(
        backgroundColor: CuttingColors.primary,
        foregroundColor: CuttingColors.surface,
        elevation: 0,
        title: Text(
          "프로젝트: ${widget.project.name}",
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        actions: [
          IconButton(
            tooltip: "변경 기록",
            icon: const Icon(Icons.history_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      SteelCuttingHistoryPage(project: widget.project),
                ),
              );
            },
          ),
          IconButton(
            tooltip: "톱날 손실(커프) 설정",
            icon: const Icon(Icons.content_cut_rounded),
            onPressed: _showKerfDialog,
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          final bool isWide = MediaQuery.of(context).size.shortestSide >= 600;
          return isWide ? _buildWideBody() : _buildNarrowBody();
        },
      ),
    );
  }

  // 🚀 넓은 화면(태블릿/폴더블 펼침) - 입력과 결과를 좌우 2단으로 동시에
  // 보여준다. 튜브 컷팅 계산기의 좌우 2단(flex 4/5)과 같은 비율.
  Widget _buildWideBody() {
    return Row(
      children: [
        Expanded(flex: 4, child: _buildInputPane()),
        Container(width: 1, color: Colors.black12),
        Expanded(flex: 5, child: _buildResultPane()),
      ],
    );
  }

  // 🚀 좁은 화면(폰) - 좌우로 욱여넣는 대신 "입력"/"결과" 탭으로 나눠서
  // 한 화면에 한 섹션씩 전체 폭을 다 쓴다.
  Widget _buildNarrowBody() {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: CuttingColors.primary,
          unselectedLabelColor: Colors.grey.shade600,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          indicatorColor: CuttingColors.primary,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: "입력"),
            Tab(text: "결과"),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildInputPane(), _buildResultPane()],
          ),
        ),
      ],
    );
  }

  // 입력 창: 항목 추가 버튼 + 종류 칩 + 규격별로 묶은 목록(머리글에 건수·길이 소계).
  Widget _buildInputPane() {
    final filteredItems = _filteredItems;
    // 규격이 처음 나온 순서대로 묶는다(같은 규격의 항목은 붙어 보인다).
    final shapeOrder = <String>[];
    final byShape = <String, List<SteelCutItem>>{};
    for (final it in filteredItems) {
      if (!byShape.containsKey(it.shapeLabel)) shapeOrder.add(it.shapeLabel);
      byShape.putIfAbsent(it.shapeLabel, () => []).add(it);
    }
    final rows = <Widget>[
      for (final shape in shapeOrder) ...[
        _buildShapeHeader(shape, byShape[shape]!),
        for (final it in byShape[shape]!) _buildItemCard(it),
      ],
    ];

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "절단 항목",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: CuttingColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            "규격을 선택하고 길이·수량을 입력하십시오",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('steel_add_item'),
              onPressed: _addItem,
              style: ElevatedButton.styleFrom(
                backgroundColor: CuttingColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.add, color: CuttingColors.surface),
              label: const Text(
                "항목 추가",
                style: TextStyle(
                  color: CuttingColors.surface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          if (_items.isNotEmpty && _categories.length > 2) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories
                    .map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildCategoryFilterChip(c),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.view_week_outlined,
                            size: 48,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "추가된 절단 항목이 없습니다.",
                            style: TextStyle(
                              color: CuttingColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "위 '항목 추가' 버튼으로 규격과 길이를 추가해 보십시오.",
                            style: TextStyle(
                              color: CuttingColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : (filteredItems.isEmpty
                      ? Center(
                          child: Text(
                            "'$_categoryFilter'에 맞는 항목이 없습니다.",
                            style: const TextStyle(
                              color: CuttingColors.textSecondary,
                            ),
                          ),
                        )
                      : ListView(padding: EdgeInsets.zero, children: rows)),
          ),
        ],
      ),
    );
  }

  // 규격 머리글: 종류 아이콘 + 규격 이름 + "3건 · 1250mm".
  Widget _buildShapeHeader(String shape, List<SteelCutItem> items) {
    final mm = items.fold(0.0, (a, i) => a + i.totalLength);
    return Padding(
      key: Key('steel_group_$shape'),
      padding: const EdgeInsets.only(top: 6, bottom: 6, left: 2),
      child: Row(
        children: [
          Icon(
            iconForSteel(items.first.category),
            size: 18,
            color: CuttingColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              shape,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: CuttingColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            "${items.length}건 · ${fmtMm(mm)}mm",
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: CuttingColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(SteelCutItem item) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: CuttingColors.danger,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => _deleteItem(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: CuttingColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: InkWell(
          key: Key('steel_item_${item.id}'),
          borderRadius: BorderRadius.circular(14),
          onTap: () => _editItem(item),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            child: Row(
              children: [
                // 큰 글씨는 1개 길이, 개수와 합계는 오른쪽 작은 글씨(튜브 컷팅과 같은 구조).
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${fmtMm(item.length)} mm",
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: CuttingColors.textPrimary,
                          fontSize: 18,
                        ),
                      ),
                      if (item.note.isNotEmpty)
                        Text(
                          item.note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: CuttingColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "× ${item.qty}개",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: CuttingColors.textPrimary,
                      ),
                    ),
                    Text(
                      "= ${fmtMm(item.totalLength)} mm",
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: CuttingColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _duplicateItem(item),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(
                      Icons.copy_rounded,
                      size: 20,
                      color: CuttingColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 지시서 글(복사·카카오톡이 함께 쓴다). 항목이 없으면 null.
  String? _instructionText() {
    final lines = _resultLines();
    if (lines.isEmpty) return null;
    return buildSteelInstructionText(
      projectName: widget.project.name,
      date: DateTime.now(),
      sets: _setMultiplier,
      lines: lines,
      stockLength: _stockLength,
      kerfMm: _bladeKerf,
    );
  }

  Future<void> _copyInstruction() async {
    final text = _instructionText();
    if (text == null) {
      showCuttingSnack(
        context,
        "복사할 항목이 없습니다. 먼저 절단 항목을 추가하십시오.",
        isError: true,
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    showCuttingSnack(context, "지시서를 글로 복사했습니다. 메신저에 붙여넣으십시오.");
  }

  Future<void> _sendToKakao() async {
    final text = _instructionText();
    if (text == null) {
      showCuttingSnack(
        context,
        "보낼 항목이 없습니다. 먼저 절단 항목을 추가하십시오.",
        isError: true,
      );
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

  // 결과 창: 제목줄 아이콘(재단 최적화·PDF·카톡·글 복사) + 세트 수 + 규격별로 묶은 자를 길이 목록.
  Widget _buildResultPane() {
    final lines = _resultLines();
    final weights = weightTotals(lines);
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
                    "재단 결과",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: CuttingColors.textPrimary,
                    ),
                  ),
                ),
              ),
              CutActionBar(
                showLabels: !_iconsUsed || _labelsPinned,
                onToggleLabels: _iconsUsed
                    ? () {
                        HapticFeedback.selectionClick();
                        setState(() => _labelsPinned = !_labelsPinned);
                      }
                    : null,
                actions: [
                  CutActionSpec(
                    key: const Key('steel_btn_optimize'),
                    label: "재단 최적화",
                    icon: const CutBarIcon(size: 21),
                    onPressed: () {
                      _markIconsUsed();
                      if (_items.isEmpty) {
                        showCuttingSnack(
                          context,
                          "절단 항목을 먼저 추가하십시오.",
                          isError: true,
                        );
                        return;
                      }
                      _showOptimization();
                    },
                  ),
                  CutActionSpec(
                    key: const Key('steel_btn_export'),
                    label: "PDF 공유",
                    icon: const Icon(
                      Icons.picture_as_pdf_rounded,
                      size: 19,
                      color: CuttingColors.primary,
                    ),
                    onPressed: () {
                      _markIconsUsed();
                      _exportInstructionSheet();
                    },
                  ),
                  CutActionSpec(
                    key: const Key('steel_btn_kakao'),
                    label: "카톡 보내기",
                    icon: const Icon(
                      Icons.chat_bubble_rounded,
                      size: 19,
                      color: CuttingColors.primary,
                    ),
                    onPressed: () {
                      _markIconsUsed();
                      _sendToKakao();
                    },
                  ),
                  CutActionSpec(
                    key: const Key('steel_btn_copy'),
                    label: "글 복사",
                    icon: const Icon(
                      Icons.copy_rounded,
                      size: 19,
                      color: CuttingColors.primary,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "세트 수 (전체 수량 배수)",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildSetStepper(),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: CuttingColors.surface,
                border: Border.all(color: CuttingColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: CuttingResultView(
                lines: lines,
                summary: summarizeResult(lines, _doneKeys),
                orders: const [],
                done: _doneKeys,
                onToggle: _toggleDone,
                setMultiplier: _setMultiplier,
                specHeaders: true,
                allDoneText: _leftoversSaved
                    ? "모두 잘랐습니다. 남는 토막도 저장했습니다."
                    : "모두 잘랐습니다.",
                allDoneActionLabel: _leftoversSaved ? null : "남는 토막 저장",
                onAllDoneAction: _showOptimization,
                specWeights: weights.bySpec,
                unknownWeightSpecs: weights.unknownSpecs,
                emptyMessage: "절단 항목을 먼저 추가하십시오.",
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetStepper() {
    return Container(
      decoration: BoxDecoration(
        color: CuttingColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CuttingColors.primary),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const Key('steel_set_minus'),
            icon: const Icon(Icons.remove, color: CuttingColors.primary),
            onPressed: () {
              if (_setMultiplier <= 1) return;
              HapticFeedback.selectionClick();
              setState(() => _setMultiplier--);
              _persistSetMultiplier(_setMultiplier);
            },
          ),
          Text(
            "$_setMultiplier SET",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: CuttingColors.textPrimary,
            ),
          ),
          IconButton(
            key: const Key('steel_set_plus'),
            icon: const Icon(Icons.add, color: CuttingColors.primary),
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _setMultiplier++);
              _persistSetMultiplier(_setMultiplier);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterChip(String label) {
    final bool selected = _categoryFilter == label;
    return Material(
      color: selected ? CuttingColors.primary : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _categoryFilter = label),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.grey.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
