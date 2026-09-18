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
  double _bladeKerf = 0.0;

  // 🚀 톱날 손실은 어차피 같은 톱으로 자르는 같은 물리 현상이라, 튜브
  // 컷팅 화면(cutting_main_screen.dart)과 같은 SharedPreferences 키를
  // 그대로 공유한다 - 톱을 바꾸지 않는 한 두 화면에서 각각 새로 입력할
  // 필요가 없다.
  static const String _kerfPrefsKey = 'cutting_blade_kerf';

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.project.items);
    _stockLength = widget.project.stockLength;
    _loadBladeKerf();
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

  List<double> _collectPieces() {
    final List<double> pieces = [];
    for (final item in _items) {
      for (int k = 0; k < item.qty; k++) {
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
              "${i.qty}",
              i.totalLength.toStringAsFixed(0),
              i.note,
            ],
          )
          .toList();
      final grandTotal = _items.fold(0.0, (sum, i) => sum + i.totalLength);

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
              "원자재 기준 길이: ${_stockLength.toStringAsFixed(0)}mm"
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
    final totalPieces = _items.fold(0, (sum, i) => sum + i.qty);
    final totalLength = _items.fold(0.0, (sum, i) => sum + i.totalLength);

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
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
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
                        confirmDismiss: (_) async {
                          final confirmed = await showCuttingConfirmDialog(
                            context,
                            title: "항목 삭제",
                            message:
                                "'${item.shapeLabel}' ${item.length.toStringAsFixed(0)}mm 항목을 삭제할까요?",
                            confirmLabel: "삭제",
                            danger: true,
                            icon: Icons.delete_outline_rounded,
                          );
                          return confirmed;
                        },
                        onDismissed: (_) {
                          setState(
                            () => _items.removeWhere((e) => e.id == item.id),
                          );
                          _persistItems();
                        },
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
                                      color: CuttingColors.primary.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
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
                                            color: CuttingColors.textPrimary,
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
                                            color: CuttingColors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: CuttingColors.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
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
