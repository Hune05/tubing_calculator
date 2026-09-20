import 'dart:io';

import '../../../core/utils/pdf_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/models/steel_cutting_project_model.dart';
import '../../tube_cutting/cutting_optimizer.dart';
import '../../tube_cutting/cutting_theme.dart';
import '../../tube_cutting/widgets/cutting_optimization_sheet.dart';
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
  static const List<String> _categories = ['전체', '앵글', '찬넬', '커스텀'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _items = List.of(widget.project.items);
    _stockLength = widget.project.stockLength;
    _setMultiplier = widget.project.setMultiplier;
    _loadBladeKerf();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<SteelCutItem> get _filteredItems {
    switch (_categoryFilter) {
      case '앵글':
        return _items.where((i) => i.category == 'ANGLE').toList();
      case '찬넬':
        return _items.where((i) => i.category == 'CHANNEL').toList();
      case '커스텀':
        return _items.where((i) => i.category == 'CUSTOM').toList();
      default:
        return _items;
    }
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
    await _docRef.update({'items': _items.map((e) => e.toMap()).toList()});
  }

  Future<void> _persistStockLength(double v) async {
    await _docRef.update({'stockLength': v});
  }

  Future<void> _persistSetMultiplier(int v) async {
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

  Future<void> _showOptimization() async {
    await showCuttingOptimizationSheet(
      context,
      groupedPieces: _collectPiecesByShape(),
      initialStockLength: _stockLength,
      kerf: _bladeKerf,
      title: "재단 최적화 (원자재 소요 계산)",
      onStockLengthChanged: (v) {
        setState(() => _stockLength = v);
        _persistStockLength(v);
      },
    );
  }

  // 🚀 [지시서 고도화] 그냥 절단 목록만 나열하면 현장에서 "그럼 원자재
  // 몇 본을 어떻게 잘라야 하는지"는 결국 다시 계산해야 한다. 재단
  // 최적화 결과(원자재별 배치)까지 같은 PDF에 담아서, 지시서 한 장으로
  // 바로 작업이 가능하게 했다.
  Future<void> _exportInstructionSheet() async {
    if (_items.isEmpty) {
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

      final itemRows = _items
          .map(
            (i) => [
              i.shapeLabel,
              i.length.toStringAsFixed(0),
              "${i.qty * _setMultiplier}",
              (i.totalLength * _setMultiplier).toStringAsFixed(0),
              i.note,
            ],
          )
          .toList();
      final grandTotal = _items.fold(
        0.0,
        (acc, i) => acc + i.totalLength * _setMultiplier,
      );

      // 🚀 [규격별 분리] 앵글/찬넬처럼 서로 다른 규격은 같은 원자재에서
      // 나올 수 없으니, 규격별로 각각 최적화해서 규격마다 별도 표로
      // 보여준다 - 한 표에 섞으면 실제로는 불가능한 배치가 나온다.
      final piecesByShape = _collectPiecesByShape();
      final optResultsByShape = {
        for (final e in piecesByShape.entries)
          e.key: optimizeCutting(
            pieces: e.value,
            stockLength: _stockLength,
            kerf: _bladeKerf,
          ),
      };
      final int totalBarCount = optResultsByShape.values.fold(
        0,
        (acc, r) => acc + r.barCount,
      );
      final double totalWasteAll = optResultsByShape.values.fold(
        0.0,
        (acc, r) => acc + r.totalWaste,
      );
      final int totalOversized = optResultsByShape.values.fold(
        0,
        (acc, r) => acc + r.oversizedPieces.length,
      );

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
              "1. 절단 목록",
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ["규격", "길이(mm)", "수량", "합계 길이(mm)", "비고"],
              data: itemRows,
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
            pw.SizedBox(height: 8),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                "총 소요 길이: ${grandTotal.toStringAsFixed(0)} mm",
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              "2. 원자재별 배치 (재단 최적화, 총 $totalBarCount본 - 규격별로 각각 계산됨)",
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            for (final entry in optResultsByShape.entries) ...[
              pw.SizedBox(height: 12),
              pw.Text(
                "${entry.key} (${entry.value.barCount}본, 로스 ${entry.value.totalWaste.toStringAsFixed(0)}mm, "
                "사용률 ${entry.value.totalStock > 0 ? (entry.value.totalUsed / entry.value.totalStock * 100).toStringAsFixed(1) : '0.0'}%)",
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  font: koreanBold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headers: ["원자재 #", "배치 구성", "사용(mm)", "잔여(mm)"],
                data: entry.value.bars
                    .asMap()
                    .entries
                    .map(
                      (e) => [
                        "${e.key + 1}",
                        e.value.pieces
                            .map((p) => "${p.toStringAsFixed(0)}mm")
                            .join(" + "),
                        e.value.usedLength.toStringAsFixed(0),
                        e.value.wasteLength.toStringAsFixed(0),
                      ],
                    )
                    .toList(),
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
              if (entry.value.oversizedPieces.isNotEmpty)
                pw.Text(
                  "⚠ 원자재보다 긴 항목 ${entry.value.oversizedPieces.length}건은 배치에서 제외됨",
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.red),
                ),
            ],
            if (totalOversized > 0) ...[
              pw.SizedBox(height: 8),
              pw.Text(
                "⚠ 원자재보다 긴 항목 총 $totalOversized건은 배치에서 제외됨 - 원자재 기준 길이를 확인하십시오.",
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.red),
              ),
            ],
            pw.SizedBox(height: 8),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                "총 로스: ${totalWasteAll.toStringAsFixed(0)} mm",
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

  // 🚀 "1. 절단 항목 입력" - 항목 추가 버튼 + 카테고리 필터 + 목록.
  // 튜브 컷팅의 "포인트 추가" 전체 폭 버튼 자리를 그대로 가져왔다 - 예전엔
  // 이 자리 대신 floatingActionButton("+")을 썼는데, 화면 우측 하단에서
  // 결과 버튼과 겹쳐 보이는 문제가 있었다. 인라인 버튼으로 바꾸면서 그
  // 문제 자체가 없어졌다.
  Widget _buildInputPane() {
    final filteredItems = _filteredItems;
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "1. 절단 항목 입력",
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
          if (_items.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: _categories
                  .map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildCategoryFilterChip(c),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Padding(
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
                      : ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
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
                                child: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.white,
                                ),
                              ),
                              onDismissed: (_) => _deleteItem(item),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: CuttingColors.surface,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => _editItem(item),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: CuttingColors.primary
                                                .withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Icon(
                                            item.category == 'ANGLE'
                                                ? Icons.change_history_rounded
                                                : Icons.view_week_rounded,
                                            color: CuttingColors.primary,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.shapeLabel,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      CuttingColors.textPrimary,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                "${item.length.toStringAsFixed(0)}mm × ${item.qty}개  =  ${item.totalLength.toStringAsFixed(0)}mm"
                                                "${item.note.isNotEmpty ? '  ·  ${item.note}' : ''}",
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: CuttingColors
                                                      .textSecondary,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        InkWell(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          onTap: () => _duplicateItem(item),
                                          child: const Padding(
                                            padding: EdgeInsets.all(6),
                                            child: Icon(
                                              Icons.copy_rounded,
                                              size: 18,
                                              color:
                                                  CuttingColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        )),
          ),
        ],
      ),
    );
  }

  // 🚀 "2. 재단 결과" - 세트 수 조절 + 요약 통계 + 재단 최적화/지시서
  // 버튼. 튜브 컷팅의 "2. 컷팅 지시서" 결과 패널(회색 배경, SET 스테퍼를
  // 우측에 두는 spaceBetween 레이아웃, 아웃라인 버튼 2개 나란히)과 같은
  // 구성으로 맞췄다.
  Widget _buildResultPane() {
    final totalPieces =
        _items.fold(0, (acc, i) => acc + i.qty) * _setMultiplier;
    final totalLength =
        _items.fold(0.0, (acc, i) => acc + i.totalLength) * _setMultiplier;

    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "2. 재단 결과",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: CuttingColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "세트 수 (전체 수량 배수)",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: CuttingColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: CuttingColors.primary),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.remove,
                        color: CuttingColors.primary,
                      ),
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
                      icon: const Icon(Icons.add, color: CuttingColors.primary),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => _setMultiplier++);
                        _persistSetMultiplier(_setMultiplier);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CuttingColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CuttingColors.border),
            ),
            child: Row(
              children: [
                _buildSummaryStat("항목 수", "${_items.length}건"),
                _buildSummaryStat("총 수량", "$totalPieces개"),
                _buildSummaryStat(
                  "총 길이",
                  "${(totalLength / 1000).toStringAsFixed(1)}m",
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _items.isEmpty ? null : _showOptimization,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: CuttingColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(
                    Icons.view_column_outlined,
                    size: 18,
                    color: CuttingColors.primary,
                  ),
                  label: const Text(
                    "재단 최적화",
                    style: TextStyle(
                      color: CuttingColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _items.isEmpty ? null : _exportInstructionSheet,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: CuttingColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(
                    Icons.picture_as_pdf_outlined,
                    size: 18,
                    color: CuttingColors.primary,
                  ),
                  label: const Text(
                    "지시서 PDF",
                    style: TextStyle(
                      color: CuttingColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_items.isEmpty) ...[
            const SizedBox(height: 10),
            Text(
              "절단 항목을 먼저 추가하면 재단 최적화와 지시서를 만들 수 있습니다.",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
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

  Widget _buildSummaryStat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: CuttingColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
