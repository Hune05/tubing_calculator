import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 🔥 파이어베이스 연동

const Color tossBlue = Color(0xFF3182F6);
const Color tossGrey = Color(0xFFF2F4F6);
const Color slate900 = Color(0xFF191F28);
const Color slate600 = Color(0xFF8B95A1);
const Color slate100 = Color(0xFFE5E8EB);
const Color pureWhite = Color(0xFFFFFFFF);
const Color warningRed = Color(0xFFF04438);

class MobileScheduleLogPage extends StatefulWidget {
  const MobileScheduleLogPage({super.key});

  @override
  State<MobileScheduleLogPage> createState() => _MobileScheduleLogPageState();
}

class _MobileScheduleLogPageState extends State<MobileScheduleLogPage> {
  String _searchQuery = "";
  String _selectedFilter = "전체";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pureWhite, // 💡 배경을 완전 흰색으로 하여 타임라인 느낌 강조
      appBar: AppBar(
        backgroundColor: pureWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          "일정 및 상태 변경 이력",
          style: TextStyle(
            color: slate900,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: slate900),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: Container(
              color: tossGrey, // 리스트 부분만 살짝 톤다운된 배경
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('schedule_logs')
                    .orderBy('date', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: tossBlue),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyState("아직 변경 이력이 없습니다.");
                  }

                  // 검색 및 필터 적용
                  final filteredLogs = snapshot.data!.docs
                      .map((doc) => doc.data() as Map<String, dynamic>)
                      .where((log) {
                        bool matchesSearch =
                            (log['target'] ?? "").contains(_searchQuery) ||
                            (log['user'] ?? "").contains(_searchQuery);
                        bool matchesFilter =
                            _selectedFilter == "전체" ||
                            log['status'] == _selectedFilter ||
                            log['type'] == _selectedFilter;
                        return matchesSearch && matchesFilter;
                      })
                      .toList();

                  if (filteredLogs.isEmpty) {
                    return _buildEmptyState("검색 조건에 맞는 이력이 없습니다.");
                  }

                  return ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 16,
                    ),
                    itemCount: filteredLogs.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _buildCleanLogItem(filteredLogs[index]);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🚀 빈 상태일 때 깔끔한 UI
  Widget _buildEmptyState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.inbox, size: 48, color: slate100),
          const SizedBox(height: 16),
          Text(msg, style: const TextStyle(color: slate600, fontSize: 15)),
        ],
      ),
    );
  }

  // 🚀 검색 및 필터 UI (더 얇고 세련되게 변경)
  Widget _buildSearchAndFilter() {
    return Container(
      color: pureWhite,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        children: [
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: tossGrey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(fontSize: 15),
              decoration: const InputDecoration(
                hintText: "자재명, 프로젝트명, 수정자 검색",
                hintStyle: TextStyle(color: Colors.black26),
                prefixIcon: Icon(LucideIcons.search, color: slate600, size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ["전체", "자재", "공정", "입고 지연", "조치 완료"].map((filter) {
                bool isSelected = _selectedFilter == filter;
                return GestureDetector(
                  onTap: () => setState(() => _selectedFilter = filter),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? slate900 : pureWhite,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? slate900 : slate100,
                      ),
                    ),
                    child: Text(
                      filter,
                      style: TextStyle(
                        color: isSelected ? pureWhite : slate600,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // 🚀 리뉴얼된 타임라인 스타일의 로그 카드
  Widget _buildCleanLogItem(Map<String, dynamic> log) {
    bool isWarning = log['status'] == "입고 지연" || log['status'] == "미해결";
    IconData typeIcon = LucideIcons.activity;
    Color iconColor = tossBlue;

    if (log['type'] == '자재') {
      typeIcon = LucideIcons.package;
      iconColor = const Color(0xFFF59E0B); // 주황색 포인트
    } else if (log['type'] == '펀치') {
      typeIcon = LucideIcons.alertCircle;
      iconColor = warningRed;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(16),
        // 💡 테두리를 없애고 아주 옅은 그림자로 대체하여 깔끔함 극대화
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단: 타입 뱃지 & 날짜
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(typeIcon, size: 16, color: iconColor),
                  const SizedBox(width: 6),
                  Text(
                    log['type'] ?? '시스템',
                    style: TextStyle(
                      color: iconColor,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                log['date'] ?? '-',
                style: const TextStyle(color: slate600, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 메인 내용: 어디서 무엇이 바뀌었는가?
          Text(
            log['target'] ?? '-',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: slate900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            log['change'] ?? '-',
            style: TextStyle(
              color: isWarning ? warningRed : slate600,
              fontSize: 14,
              height: 1.4,
              fontWeight: isWarning ? FontWeight.bold : FontWeight.w500,
            ),
          ),

          // 하단: 수정자 & (선택) 사유 박스
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: tossGrey,
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.user, size: 12, color: slate600),
              ),
              const SizedBox(width: 8),
              Text(
                log['user'] ?? '시스템',
                style: const TextStyle(
                  color: slate900,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          // 사유가 있을 경우에만 회색 인용구 박스 표시
          if (log['reason'] != null && log['reason'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: tossGrey,
                borderRadius: BorderRadius.circular(8),
                // 💡 왼쪽 포인트 선으로 '인용구' 느낌 주기
                border: const Border(
                  left: BorderSide(color: slate100, width: 3),
                ),
              ),
              child: Text(
                log['reason'],
                style: const TextStyle(
                  color: slate600,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
