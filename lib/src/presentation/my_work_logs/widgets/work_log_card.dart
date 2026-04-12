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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. 헤더 영역
          InkWell(
            onTap: onToggleExpand,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? Colors.green.withValues(alpha: 0.1)
                          : tossBlue.withValues(alpha: 0.08),
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
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${log['date']} · ${log['revision']}",
                          style: const TextStyle(
                            fontSize: 14,
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
                  const SizedBox(height: 4),

                  // 🚀 용어 수정 반영된 버튼
                  Row(
                    children: [
                      Expanded(
                        child: _buildUnifiedButton(
                          label: "계산기",
                          icon: Icons.calculate_rounded,
                          onTap: onOpenCalculator,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildUnifiedButton(
                          label: "작업 일지",
                          icon: Icons.edit_document,
                          onTap: onAddDailyReport,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildUnifiedButton(
                          label: "이슈 등록", // 현장 용어(이슈)로 변경
                          icon: Icons.error_outline_rounded,
                          onTap: onAddPunchList,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // 📝 작업 일지 목록
                  if (dailyReports.isNotEmpty) ...[
                    const Text(
                      "작업 일지",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: tossSubText,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...dailyReports.map(
                      (report) => _buildUnifiedRecordItem(
                        context: context,
                        title: "${report['date']} (${report['points']} pt)",
                        content: report['note'],
                        itemData: report,
                        icon: Icons.article_rounded,
                        isWarning: false,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ⚠️ 이슈 리스트 목록
                  if (punchLists.isNotEmpty) ...[
                    const Text(
                      "이슈 목록", // 타이틀 직관적으로 변경
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: tossSubText,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...punchLists.map(
                      (punch) => _buildUnifiedRecordItem(
                        context: context,
                        title: "이슈 확인 요망", // 타이틀 직관적으로 변경
                        content: punch['content'],
                        itemData: punch,
                        icon: Icons.priority_high_rounded,
                        isWarning: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 삭제 버튼
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: TextButton(
                        onPressed: onDelete,
                        style: TextButton.styleFrom(
                          foregroundColor: tossSubText,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        child: const Text(
                          "이 작업 삭제하기",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // 액션 버튼
  Widget _buildUnifiedButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: tossBg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: tossText),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  color: tossText,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 리스트 아이템
  Widget _buildUnifiedRecordItem({
    required BuildContext context,
    required String title,
    required String content,
    required Map<String, dynamic> itemData,
    required IconData icon,
    required bool isWarning,
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
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: tossBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: tossText, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isWarning ? warningRed : tossText,
                      fontSize: 15,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: tossBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.image_rounded,
                  size: 16,
                  color: tossSubText,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
