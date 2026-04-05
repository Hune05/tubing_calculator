import 'package:flutter/material.dart';

const Color tossBlue = Color(0xFF3182F6);
const Color tossGrey = Color(0xFFF2F4F6);
const Color slate900 = Color(0xFF191F28);
const Color slate600 = Color(0xFF8B95A1);
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

  // 💡 일정 변경 로그 더미 데이터
  final List<Map<String, dynamic>> _logs = [
    {
      "date": "2026-04-03 14:20",
      "user": "이소장",
      "target": "Main Engine (ME-101)",
      "type": "자재",
      "change": "입고일 변경: 04-10 → 04-15",
      "reason": "협력사 제작 지연",
      "status": "입고 지연",
    },
    {
      "date": "2026-04-03 10:05",
      "user": "박공무",
      "target": "A동 3층 메인 배관",
      "type": "공정",
      "change": "단계 변경: 자재 검사 → 작업 진행",
      "reason": "검사 합격 완료",
      "status": "정상",
    },
  ];

  @override
  Widget build(BuildContext context) {
    final filteredLogs = _logs.where((log) {
      bool matchesSearch =
          log['target'].contains(_searchQuery) ||
          log['user'].contains(_searchQuery);
      bool matchesFilter =
          _selectedFilter == "전체" ||
          log['status'] == _selectedFilter ||
          log['type'] == _selectedFilter;
      return matchesSearch && matchesFilter;
    }).toList();

    return Scaffold(
      backgroundColor: tossGrey,
      appBar: AppBar(
        backgroundColor: pureWhite,
        elevation: 0,
        title: const Text(
          "일정 변경 히스토리",
          style: TextStyle(color: slate900, fontWeight: FontWeight.bold),
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
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredLogs.length,
              itemBuilder: (context, index) {
                final log = filteredLogs[index];
                return _buildLogCard(log);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      color: pureWhite,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: "자재명 또는 수정자 검색",
              prefixIcon: const Icon(Icons.search, color: slate600),
              filled: true,
              fillColor: tossGrey,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ["전체", "자재", "공정", "입고 지연"].map((filter) {
                bool isSelected = _selectedFilter == filter;
                return GestureDetector(
                  onTap: () => setState(() => _selectedFilter = filter),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? slate900 : pureWhite,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? slate900 : Colors.black12,
                      ),
                    ),
                    child: Text(
                      filter,
                      style: TextStyle(
                        color: isSelected ? pureWhite : slate600,
                        fontWeight: FontWeight.bold,
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

  Widget _buildLogCard(Map<String, dynamic> log) {
    bool isUrgent = log['status'] == "입고 지연";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUrgent
              ? warningRed.withValues(alpha: 0.3)
              : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                log['date'],
                style: const TextStyle(color: slate600, fontSize: 12),
              ),
              Text(
                log['user'],
                style: const TextStyle(
                  color: tossBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            log['target'],
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: slate900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            log['change'],
            style: TextStyle(
              color: isUrgent ? warningRed : slate900,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          if (log['reason'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: tossGrey,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "사유: ${log['reason']}",
                style: const TextStyle(color: slate600, fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
