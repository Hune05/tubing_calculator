import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, HapticFeedback;
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

class _SteelCuttingDetailScreenState extends State<SteelCuttingDetailScreen> {
  late List<SteelCutItem> _items;
  late double _stockLength;
  late int _setMultiplier;
  double _bladeKerf = 0.0;
  String _categoryFilter = '전체';

  // 🚀 톱날 손실은 어차피 같은 톱으로 자르는 같은 물리 현상이라, 튜브
  // 컷팅 화면(cutting_main_screen.dart)과 같은 SharedPreferences 키를
  // 그대로 공유한다 - 톱을 바꾸지 않는 한 두 화면에서 각각 새로 입력할
  // 필요가 없다.
  static const String _kerfPrefsKey = 'cutting_blade_kerf';
  static const List<String> _categories = ['전체', '앵글', '찬넬', '커스텀'];

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.project.items);
    _stockLength = widget.project.stockLength;
    _setMultiplier = widget.project.setMultiplier;
    _loadBladeKerf();
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

  List<double> _collectPieces() {
    final List<double> pieces = [];
    for (final item in _items) {
      for (int k = 0; k < item.qty * _setMultiplier; k++) {
        pieces.add(item.length);
      }
    }
    return pieces;
  }

  void _addItem() {
    showSteelItemSheet(
      context,
      onSave: (item) {
        setState(() => _items.add(item));
        _persistItems();
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
    final pieces = _collectPieces();
    await showCuttingOptimizationSheet(
      context,
      pieces: pieces,
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
        "내보낼 항목이 없습니다. 먼저 절단 항목을 추가하세요.",
        isError: true,
      );
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
        (sum, i) => sum + i.totalLength * _setMultiplier,
      );

      final pieces = _collectPieces();
      final optResult = optimizeCutting(
        pieces: pieces,
        stockLength: _stockLength,
        kerf: _bladeKerf,
      );
      final barRows = optResult.bars
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
          .toList();

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
                font: koreanFont,
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
              "2. 원자재별 배치 (재단 최적화, 총 ${optResult.barCount}본)",
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ["원자재 #", "배치 구성", "사용(mm)", "잔여(mm)"],
              data: barRows,
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
            if (optResult.oversizedPieces.isNotEmpty) ...[
              pw.SizedBox(height: 8),
              pw.Text(
                "⚠ 원자재보다 긴 항목 ${optResult.oversizedPieces.length}건은 배치에서 제외됨 - 원자재 기준 길이를 확인하세요.",
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.red),
              ),
            ],
            pw.SizedBox(height: 8),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                "총 로스: ${optResult.totalWaste.toStringAsFixed(0)} mm",
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

  @override
  Widget build(BuildContext context) {
    final totalPieces =
        _items.fold(0, (sum, i) => sum + i.qty) * _setMultiplier;
    final totalLength =
        _items.fold(0.0, (sum, i) => sum + i.totalLength) * _setMultiplier;
    final filteredItems = _filteredItems;

    return Scaffold(
      backgroundColor: CuttingColors.background,
      appBar: AppBar(
        backgroundColor: CuttingColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Text(
          widget.project.name,
          style: const TextStyle(
            color: CuttingColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: CuttingColors.textPrimary),
        actions: [
          IconButton(
            tooltip: "톱날 손실(커프) 설정",
            icon: const Icon(
              Icons.content_cut_rounded,
              color: CuttingColors.textSecondary,
            ),
            onPressed: _showKerfDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CuttingColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildSummaryStat("항목 수", "${_items.length}건"),
                    _buildSummaryStat("총 수량", "$totalPieces개"),
                    _buildSummaryStat(
                      "총 길이",
                      "${(totalLength / 1000).toStringAsFixed(1)}m",
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
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
                            visualDensity: VisualDensity.compact,
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
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: CuttingColors.textPrimary,
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.add,
                              color: CuttingColors.primary,
                            ),
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
              ],
            ),
          ),
          if (_items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
                            "우측 하단 + 버튼으로 규격과 길이를 추가해보세요.",
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
                            "'$_categoryFilter'에 해당하는 항목이 없습니다.",
                            style: const TextStyle(
                              color: CuttingColors.textSecondary,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
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
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: CuttingColors.surface,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showOptimization,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(
                          color: CuttingColors.primary,
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(
                        Icons.view_column_outlined,
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
                    child: ElevatedButton.icon(
                      onPressed: _exportInstructionSheet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CuttingColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(
                        Icons.picture_as_pdf_outlined,
                        color: CuttingColors.surface,
                      ),
                      label: const Text(
                        "지시서 PDF",
                        style: TextStyle(
                          color: CuttingColors.surface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          _addItem();
        },
        backgroundColor: CuttingColors.primary,
        child: const Icon(Icons.add, color: CuttingColors.surface),
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
