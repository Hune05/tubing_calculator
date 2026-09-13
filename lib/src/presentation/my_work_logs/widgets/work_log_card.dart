import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'photo_detail_modal.dart';

const Color tossBlue = Color(0xFF007580); // 🚀 마키타 틸로 통일
const Color tossText = Color(0xFF191F28);
const Color tossSubText = Color(0xFF8B95A1);
const Color tossBg = Color(0xFFF2F4F6);
const Color pureWhite = Color(0xFFFFFFFF);
const Color warningRed = Color(0xFFF04438);

class WorkLogCard extends StatelessWidget {
  final Map<String, dynamic> log;
  final bool isExpanded;
  final VoidCallback onToggleExpand;

  final VoidCallback onOpenSchedule;
  final VoidCallback onAddDailyReport;
  final void Function(Map<String, dynamic> report) onOpenDailyReport;
  final VoidCallback onAddPunchList;
  final void Function(Map<String, dynamic> punch) onOpenPunchDetail;
  final VoidCallback onDelete;

  const WorkLogCard({
    super.key,
    required this.log,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onOpenSchedule,
    required this.onAddDailyReport,
    required this.onOpenDailyReport,
    required this.onAddPunchList,
    required this.onOpenPunchDetail,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    double progress = (log['progress'] ?? 0.0).toDouble();
    bool isCompleted = progress >= 1.0;

    List<dynamic> dailyReports = log['daily_reports'] ?? [];
    List<dynamic> punchLists = log['punch_lists'] ?? [];
    // 🚀 [추가] "일정 관리"에 등록된 것 중 아직 완료 안 된 것만 카드에서
    // 미리 보여준다 (완료된 건 일정 관리 화면에서만 확인).
    List<dynamic> upcomingSchedules =
        (log['schedules'] as List<dynamic>? ?? [])
            .where((s) => s['isCompleted'] != true)
            .toList();

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
                          label: "일정 관리",
                          icon: Icons.event_note_rounded,
                          onTap: onOpenSchedule,
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

                  // 🗓️ 다가오는 일정 (자재 요청/입고일/납기일/검사일정)
                  if (upcomingSchedules.isNotEmpty) ...[
                    const Text(
                      "다가오는 일정",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: tossSubText,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...upcomingSchedules.map((s) {
                      final dynamic rawDt = s['dateTime'];
                      final DateTime dt = rawDt is DateTime
                          ? rawDt
                          : rawDt is Timestamp
                          ? rawDt.toDate()
                          : DateTime.tryParse(rawDt.toString()) ??
                                DateTime.now();
                      final bool isOverdue = dt.isBefore(DateTime.now());
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: tossBg,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.event_note_rounded,
                                color: isOverdue ? warningRed : tossBlue,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${s['title'] ?? s['type'] ?? ''}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: isOverdue ? warningRed : tossText,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    "${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}",
                                    style: const TextStyle(
                                      color: tossSubText,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 20),
                  ],

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
                        // 🚀 [변경] 예전엔 탭하면 사진만 뜨는 모달이 떴는데,
                        // 이제 그날 작업 일보 전체(작업유형/인원/포인트/
                        // 메모/사진)를 볼 수 있는 화면으로 들어간다.
                        onTap: () => onOpenDailyReport(report),
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
                    ...punchLists.map((punch) {
                      final bool isPunchDone = punch['is_completed'] == true;
                      return _buildUnifiedRecordItem(
                        context: context,
                        title: isPunchDone ? "이슈 처리 완료" : "이슈 확인 요망",
                        content: punch['content'],
                        itemData: punch,
                        icon: Icons.priority_high_rounded,
                        isWarning: true,
                        isCompleted: isPunchDone,
                        // 🚀 [변경] 탭하면 언제 발생했고 어떻게 처리했는지
                        // 정리할 수 있는 이슈 상세 화면으로 들어간다.
                        onTap: () => onOpenPunchDetail(punch),
                      );
                    }),
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
    bool isCompleted = false,
    VoidCallback? onTap,
  }) {
    bool hasImg = itemData['has_image'] == true;

    return InkWell(
      onTap:
          onTap ??
          () {
            PhotoDetailModal.show(
              context: context,
              title: title,
              content: content,
              imagePaths:
                  itemData['image_paths'] ??
                  (itemData['image_path'] != null
                      ? [itemData['image_path']]
                      : []),
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
              decoration: BoxDecoration(
                color: isCompleted
                    ? Colors.green.withValues(alpha: 0.12)
                    : tossBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCompleted ? Icons.check_rounded : icon,
                color: isCompleted ? Colors.green : tossText,
                size: 20,
              ),
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
                      color: isCompleted
                          ? tossSubText
                          : (isWarning ? warningRed : tossText),
                      fontSize: 15,
                      letterSpacing: -0.3,
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : null,
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
