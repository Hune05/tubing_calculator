import 'dart:io';

import '../../../core/utils/pdf_fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../../data/models/cutting_project_model.dart';
import '../cutting_firestore_helper.dart';
import '../cutting_math.dart' show safeFileName;
import '../cutting_record_export.dart';
import '../cutting_theme.dart';

const List<String> _kWeekdaysKo = ['월', '화', '수', '목', '금', '토', '일'];

// 🚀 [신규] 프로젝트 안의 "컷팅 기록" - 예전엔 CutRecord 모델만 만들어
// 놓고 어디서도 안 써서, "완료"를 눌러 저장하면 총합만 쌓이고 그날그날
// 실제로 뭘 잘랐는지는 확인할 방법이 없었다. "완료" 시점마다 남긴
// CutRecord들을 날짜별로 묶어서, 하루씩 스와이프로 넘기며 볼 수 있게
// 한다 (요일도 같이 표시).
class CuttingHistoryPage extends StatefulWidget {
  final CuttingProject project;

  const CuttingHistoryPage({super.key, required this.project});

  @override
  State<CuttingHistoryPage> createState() => _CuttingHistoryPageState();
}

class _CuttingHistoryPageState extends State<CuttingHistoryPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  // 규격 하나만 보기(null이면 전부). 화면에 보이는 기록만 내보낸다.
  String? _specFilter;
  // 화면에 불러온 기록(내보내기에 그대로 쓴다).
  List<CutRecord> _records = [];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _formatDay(DateTime day) {
    final weekday = _kWeekdaysKo[day.weekday - 1];
    return "${day.month}월 ${day.day}일 ($weekday)";
  }

  Future<void> _deleteRecord(CutRecord record) async {
    final confirmed = await showCuttingConfirmDialog(
      context,
      title: "기록 삭제",
      message: "이 컷팅 기록을 삭제하시겠습니까? 프로젝트 누적 합계에서도 이만큼 함께 빠집니다.",
      confirmLabel: "삭제",
      danger: true,
      icon: Icons.delete_outline_rounded,
    );
    if (confirmed) {
      await FirebaseFirestore.instance
          .collection(kCuttingProjectsCollection)
          .doc(widget.project.id)
          .collection(kCutRecordsSubcollection)
          .doc(record.id)
          .delete();
      // 🚀 [3번 강화] 기록 하나를 지웠으면 프로젝트 누적 합계도 그만큼
      // 원자적으로 빼서, 개별 기록 삭제가 누적 합계와 영구히 어긋나지
      // 않게 한다(예전엔 여기서 누적 합계를 전혀 건드리지 않았다).
      await reconcileProjectAfterRecordDelete(
        projectId: widget.project.id,
        deletedRecord: record,
      );
      if (mounted) {
        showCuttingSnack(context, "기록을 삭제했습니다.");
      }
    }
  }

  // 기록을 표로 만들어 PDF로 내보낸다(공유 창이 열린다).
  Future<void> _exportRecords() async {
    if (_records.isEmpty) {
      showCuttingSnack(context, "내보낼 기록이 없습니다.", isError: true);
      return;
    }
    try {
      final data = buildRecordExport(_records);
      final pdfFonts = await loadKoreanPdfFonts();
      final font = pdfFonts.regular;
      final fontBold = pdfFonts.bold;
      final pdf = pw.Document(theme: pdfFonts.theme);
      final now = DateTime.now();
      final dateStr =
          "${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}";
      pw.Widget table(List<String> headers, List<List<String>> rows) =>
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows,
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              font: fontBold,
            ),
            cellStyle: pw.TextStyle(font: font, fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          );
      final fittings = widget.project.usedFittings.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Text(
              "컷팅 기록",
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text("프로젝트: ${widget.project.name}"),
            pw.Text("기간: ${recordPeriodText(data)}    작성일: $dateStr"),
            if (_specFilter != null) pw.Text("규격: $_specFilter (이 규격의 기록만)"),
            pw.SizedBox(height: 14),
            table(kRecordHeaders, data.rows),
            pw.SizedBox(height: 14),
            pw.Text(
              "규격별 합계",
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            table(
              ['규격', '개수', '길이(mm)'],
              [
                for (final e in data.byTubeSize.entries)
                  [e.key, '${e.value.count}', e.value.mm.toStringAsFixed(1)],
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                "총 ${data.totalCount}개 · ${data.totalMm.toStringAsFixed(1)} mm",
                style: pw.TextStyle(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            if (fittings.isNotEmpty) ...[
              pw.SizedBox(height: 14),
              pw.Text(
                "사용한 부속",
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              table(
                ['피팅', '수량'],
                [
                  for (final e in fittings) [e.key, '${e.value}'],
                ],
              ),
            ],
          ],
        ),
      );
      final dir = await getTemporaryDirectory();
      final file = File(
        "${dir.path}/${safeFileName(widget.project.name)}_컷팅기록.pdf",
      );
      await file.writeAsBytes(await pdf.save());
      if (!mounted) return;
      // ignore: deprecated_member_use
      await Share.shareXFiles([
        XFile(file.path),
      ], text: "${widget.project.name} 컷팅 기록입니다.");
    } catch (e) {
      if (!mounted) return;
      showCuttingSnack(context, "내보내기 실패: $e", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CuttingTheme(
      child: Scaffold(
        backgroundColor: CuttingColors.surface,
        appBar: AppBar(
          backgroundColor: CuttingColors.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: const IconThemeData(color: CuttingColors.textPrimary),
          title: Text(
            "컷팅 기록 · ${widget.project.name}",
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: CuttingColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          actions: [
            IconButton(
              tooltip: "기록 내보내기",
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: _exportRecords,
            ),
          ],
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection(kCuttingProjectsCollection)
              .doc(widget.project.id)
              .collection(kCutRecordsSubcollection)
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  "기록을 불러오지 못했습니다.\n${snapshot.error}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: CuttingColors.textSecondary),
                ),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: CuttingColors.primary),
              );
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_rounded, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        "아직 컷팅 기록이 없습니다.",
                        style: TextStyle(
                          color: CuttingColors.textSecondary,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "계산기에서 '완료'를 누르면 여기에 남습니다.",
                        style: TextStyle(
                          color: CuttingColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final records = docs
                .map(
                  (d) =>
                      CutRecord.fromMap(d.id, d.data() as Map<String, dynamic>),
                )
                .toList();

            // 칩 순서는 오래된 기록부터 처음 나온 규격 순서로 한다(목록은 최신순이라 그대로 쓰면 거꾸로 나온다).
            final specs = recordSpecs(
              [...records]..sort((a, b) => a.timestamp.compareTo(b.timestamp)),
            );
            // 고른 규격의 기록이 더는 없으면(지웠으면) 전체로 돌아간다.
            final String? activeFilter = specs.contains(_specFilter)
                ? _specFilter
                : null;
            final shown = filterBySpec(records, activeFilter);
            _specFilter = activeFilter;
            _records = shown;
            final Map<DateTime, List<CutRecord>> grouped = {};
            for (final r in shown) {
              final day = DateTime(
                r.timestamp.year,
                r.timestamp.month,
                r.timestamp.day,
              );
              grouped.putIfAbsent(day, () => []).add(r);
            }
            final days = grouped.keys.toList()
              ..sort((a, b) => b.compareTo(a)); // 최신 날짜가 먼저

            if (_currentPage >= days.length) {
              _currentPage = 0;
            }

            return Column(
              children: [
                if (specs.length > 1) _buildSpecFilter(specs, activeFilter),
                _buildDayNavigator(days),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: days.length,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemBuilder: (context, i) {
                      final day = days[i];
                      final dayRecords = grouped[day]!;
                      return _buildDayList(day, dayRecords);
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // 규격이 둘 이상이면 위쪽에 "전체 · 1/2" · 3/4" …" 칩을 둔다(하나 누르면 그 규격만 보인다).
  Widget _buildSpecFilter(List<String> specs, String? active) {
    Widget chip(String label, String? value) {
      final selected = active == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          key: Key('history_spec_${value ?? 'all'}'),
          label: Text(label),
          selected: selected,
          onSelected: (_) => setState(() {
            _specFilter = value;
            _currentPage = 0;
          }),
          selectedColor: CuttingColors.primary,
          backgroundColor: CuttingColors.surface,
          side: BorderSide(
            color: selected ? CuttingColors.primary : CuttingColors.border,
          ),
          labelStyle: TextStyle(
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : CuttingColors.textPrimary,
          ),
          showCheckmark: false,
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [chip('전체', null), for (final s in specs) chip(s, s)],
        ),
      ),
    );
  }

  Widget _buildDayNavigator(List<DateTime> days) {
    final day = days[_currentPage];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: const BoxDecoration(
        color: CuttingColors.background,
        border: Border(bottom: BorderSide(color: CuttingColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            // 최신이 index 0이므로, "이전 날짜"는 인덱스가 커지는 방향
            onPressed: _currentPage < days.length - 1
                ? () => _pageController.nextPage(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                  )
                : null,
            icon: const Icon(Icons.chevron_left_rounded),
            color: _currentPage < days.length - 1
                ? CuttingColors.textPrimary
                : Colors.grey.shade300,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  _formatDay(day),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: CuttingColors.textPrimary,
                  ),
                ),
                Text(
                  "${_currentPage + 1} / ${days.length}일 · 좌우로 스와이프",
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _currentPage > 0
                ? () => _pageController.previousPage(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                  )
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
            color: _currentPage > 0
                ? CuttingColors.textPrimary
                : Colors.grey.shade300,
          ),
        ],
      ),
    );
  }

  Widget _buildDayList(DateTime day, List<CutRecord> dayRecords) {
    // 시간순 정렬(그 날 안에서는 오래된 순)
    final sorted = [...dayRecords]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final totalLength = sorted.fold<double>(
      0.0,
      (acc, r) => acc + (r.cutLength * r.multiplier),
    );
    final totalCount = sorted.fold<int>(0, (acc, r) => acc + r.multiplier);

    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CuttingColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "이 날 총 절단 길이",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: CuttingColors.textSecondary,
                    ),
                  ),
                  Text(
                    "${totalLength.toStringAsFixed(1)} mm",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: CuttingColors.primary,
                    ),
                  ),
                ],
              ),
              Text(
                "총 $totalCount개 절단",
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: CuttingColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        // 그 날 규격이 둘 이상이면 규격별 합계를 보여 준다.
        if (recordSpecTotals(sorted).length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                recordSpecTotals(sorted)
                    .map(
                      (e) =>
                          '${e.spec} ${e.mm.toStringAsFixed(1)}mm (${e.count}개)',
                    )
                    .join('  ·  '),
                key: const Key('history_day_specs'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: CuttingColors.textPrimary,
                ),
              ),
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: sorted.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final r = sorted[index];
              return _buildRecordCard(r);
            },
          ),
        ),
      ],
    );
  }

  // 🚀 [재구성] 예전엔 "PT1 → PT2, 시간, 규격, 절단길이"만 보여줘서
  // 나중에 똑같은 걸 다시 자르려고 해도 어느 제조사 어떤 부속인지,
  // 공제값이 얼마였는지 알 수가 없었다. 재현에 필요한 정보(제조사,
  // 양쪽 부속명+공제값, 측정값→절단값)를 카드 하나에 다 담았다.
  Widget _buildRecordCard(CutRecord r) {
    final timeStr = DateFormat('HH:mm').format(r.timestamp);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CuttingColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단: 제조사 + 규격 배지, 시간
          Row(
            children: [
              if (r.maker.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: CuttingColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    r.maker,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: CuttingColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  normalizeSpec(r.tubeSize) == kUnknownSpecLabel
                      ? kUnknownSpecLabel
                      : "규격 ${normalizeSpec(r.tubeSize)}",
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              Text(
                timeStr,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _deleteRecord(r);
                },
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1),
          ),
          // 중단: 양쪽 부속 이름 + 각자의 공제값
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildFittingSide(r.startFitting, r.startDeduction),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ),
              Expanded(child: _buildFittingSide(r.endFitting, r.endDeduction)),
            ],
          ),
          const SizedBox(height: 10),
          // 하단: 측정값 → 절단값 + 개수
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "측정 ${r.originalLength.toStringAsFixed(1)}mm",
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
                Icon(
                  Icons.arrow_right_alt_rounded,
                  size: 16,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 4),
                Text(
                  "절단 ${r.cutLength.toStringAsFixed(1)}mm",
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Colors.redAccent,
                  ),
                ),
                if (r.multiplier > 1) ...[
                  const SizedBox(width: 6),
                  Text(
                    "× ${r.multiplier}",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFittingSide(String name, double deduction) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: CuttingColors.textPrimary,
          ),
        ),
        if (deduction > 0)
          Text(
            "공제 -${deduction.toStringAsFixed(1)}mm",
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
      ],
    );
  }
}
