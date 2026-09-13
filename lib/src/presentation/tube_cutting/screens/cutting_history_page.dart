import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../data/models/cutting_project_model.dart';

const Color _tossBlue = Color(0xFF007580); // 마키타 틸
const Color _slate900 = Color(0xFF191F28);
const Color _slate600 = Color(0xFF8B95A1);
const Color _tossGrey = Color(0xFFF0F3F5); // 마키타 라이트 배경
const Color _pureWhite = Colors.white;

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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "기록 삭제",
          style: TextStyle(color: _slate900, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "이 컷팅 기록을 삭제할까요? 프로젝트 누적 합계에는 영향을 주지 않습니다.",
          style: TextStyle(color: _slate600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("취소", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "삭제",
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection(kCuttingProjectsCollection)
          .doc(widget.project.id)
          .collection(kCutRecordsSubcollection)
          .doc(record.id)
          .delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pureWhite,
      appBar: AppBar(
        backgroundColor: _pureWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: _slate900),
        title: Text(
          "컷팅 기록 · ${widget.project.name}",
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _slate900,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
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
                style: const TextStyle(color: _slate600),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _tossBlue),
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
                    Icon(
                      Icons.history_rounded,
                      size: 48,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      "아직 컷팅 기록이 없습니다.",
                      style: TextStyle(color: _slate600, fontSize: 15),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "계산기에서 '완료'를 누르면 여기에 남습니다.",
                      style: TextStyle(color: _slate600, fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          }

          final records = docs
              .map(
                (d) => CutRecord.fromMap(d.id, d.data() as Map<String, dynamic>),
              )
              .toList();

          final Map<DateTime, List<CutRecord>> grouped = {};
          for (final r in records) {
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
    );
  }

  Widget _buildDayNavigator(List<DateTime> days) {
    final day = days[_currentPage];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: const BoxDecoration(
        color: _tossGrey,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E8EB))),
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
            color: _currentPage < days.length - 1 ? _slate900 : Colors.grey.shade300,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  _formatDay(day),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: _slate900,
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
            color: _currentPage > 0 ? _slate900 : Colors.grey.shade300,
          ),
        ],
      ),
    );
  }

  Widget _buildDayList(DateTime day, List<CutRecord> dayRecords) {
    // 시간순 정렬(그 날 안에서는 오래된 순)
    final sorted = [...dayRecords]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
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
            color: _tossBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "이 날 총 소요 길이",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _slate600,
                    ),
                  ),
                  Text(
                    "${totalLength.toStringAsFixed(1)} mm",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: _tossBlue,
                    ),
                  ),
                ],
              ),
              Text(
                "총 $totalCount개 절단",
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: _slate600,
                ),
              ),
            ],
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
        color: _pureWhite,
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
                    color: _tossBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    r.maker,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _tossBlue,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  r.tubeSize.isEmpty ? '규격 미지정' : "규격 ${r.tubeSize}",
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
              Expanded(child: _buildFittingSide(r.startFitting, r.startDeduction)),
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
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
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
            color: _slate900,
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
