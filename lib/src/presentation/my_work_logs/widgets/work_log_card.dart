import 'package:flutter/material.dart';
import 'photo_detail_modal.dart';

const Color tossBlue = Color(0xFF3182F6);
const Color tossText = Color(0xFF191F28);
const Color tossSubText = Color(0xFF8B95A1);
const Color tossBg = Color(0xFFF2F4F6);
const Color pureWhite = Color(0xFFFFFFFF);
const Color warningRed = Color(0xFFF04438);

class WorkLogCard extends StatelessWidget {
  final Map<String, dynamic> log;
  final bool isExpanded;
  final VoidCallback onToggleExpand;

  final VoidCallback onOpenCalculator;
  final VoidCallback onAddDailyReport;
  final VoidCallback onAddPunchList;
  final VoidCallback onDelete;

  const WorkLogCard({
    super.key,
    required this.log,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onOpenCalculator,
    required this.onAddDailyReport,
    required this.onAddPunchList,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    double progress = (log['progress'] ?? 0.0).toDouble();
    bool isCompleted = progress >= 1.0;

    List<dynamic> dailyReports = log['daily_reports'] ?? [];
    List<dynamic> punchLists = log['punch_lists'] ?? [];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(20),
        // 토스 스타일의 아주 옅은 그림자
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. 헤더 영역 (클릭 시 토글)
          InkWell(
            onTap: onToggleExpand,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Row(
                children: [
                  // 아이콘
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? Colors.green.withValues(alpha: 0.1)
                          : tossBlue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isCompleted ? Icons.check_rounded : Icons.build_rounded,
                      color: isCompleted ? Colors.green : tossBlue,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          log['name'] ?? '이름 없음',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: tossText,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${log['date']} · ${log['revision']}",
                          style: const TextStyle(
                            fontSize: 13,
                            color: tossSubText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: tossSubText,
                    size: 28,
                  ),
                ],
              ),
            ),
          ),

          // 2. 확장 영역
          if (isExpanded)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: tossBg, thickness: 1, height: 1),
                  const SizedBox(height: 20),

                  // 토스 스타일 바로가기 버튼들 (가로로 꽉 차게)
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickButton(
                          "계산기",
                          Icons.calculate_rounded,
                          tossBlue,
                          onOpenCalculator,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildQuickButton(
                          "일보 작성",
                          Icons.edit_document,
                          tossText,
                          onAddDailyReport,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildQuickButton(
                          "펀치 추가",
                          Icons.error_outline_rounded,
                          Colors.orange.shade700,
                          onAddPunchList,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 📝 작업 일보 목록
                  if (dailyReports.isNotEmpty) ...[
                    const Text(
                      "작업 일보",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: tossText,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...dailyReports.map(
                      (report) => _buildRecordItem(
                        context: context,
                        title: "${report['date']} (${report['points']} pt)",
                        content: report['note'],
                        itemData: report,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ⚠️ 펀치 리스트 목록
                  if (punchLists.isNotEmpty) ...[
                    const Text(
                      "펀치 리스트",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: warningRed,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...punchLists.map(
                      (punch) => _buildRecordItem(
                        context: context,
                        title: "수정/보완 요망",
                        content: punch['content'],
                        itemData: punch,
                        isWarning: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 삭제 버튼 (맨 아래)
                  Center(
                    child: TextButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text(
                        "이 기록 삭제하기",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: TextButton.styleFrom(foregroundColor: tossSubText),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // 토스 스타일 빠른 액션 버튼 (회색 배경에 텍스트)
  Widget _buildQuickButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: tossBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 내부 리스트 아이템 (토스 내역 스타일)
  Widget _buildRecordItem({
    required BuildContext context,
    required String title,
    required String content,
    required Map<String, dynamic> itemData,
    bool isWarning = false,
  }) {
    bool hasImg = itemData['has_image'] == true;

    return InkWell(
      onTap: () {
        PhotoDetailModal.show(
          context: context,
          title: title,
          content: content,
          imagePaths:
              itemData['image_paths'] ??
              (itemData['image_path'] != null ? [itemData['image_path']] : []),
          isAsBuilt: itemData['is_as_built'] ?? false,
          asBuiltReason: itemData['as_built_reason'],
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 36,
              decoration: BoxDecoration(
                color: isWarning ? warningRed : tossBg,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isWarning ? warningRed : tossText,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: tossSubText, fontSize: 13),
                  ),
                ],
              ),
            ),
            if (hasImg)
              Icon(
                Icons.image_rounded,
                size: 20,
                color: tossSubText.withValues(alpha: 0.5),
              ),
          ],
        ),
      ),
    );
  }
}
