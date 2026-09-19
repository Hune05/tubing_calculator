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
  final VoidCallback onOpenDailyReportCalendar;
  final VoidCallback onAddPunchList;
  final void Function(Map<String, dynamic> punch) onOpenPunchDetail;
  final VoidCallback onDelete;
  // 🚀 [추가] 프로젝트 완료/보관 처리.
  final VoidCallback onToggleProjectStatus;
  final bool isProjectActive;

  const WorkLogCard({
    super.key,
    required this.log,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onOpenSchedule,
    required this.onAddDailyReport,
    required this.onOpenDailyReport,
    required this.onOpenDailyReportCalendar,
    required this.onAddPunchList,
    required this.onOpenPunchDetail,
    required this.onDelete,
    required this.onToggleProjectStatus,
    required this.isProjectActive,
  });

  @override
  Widget build(BuildContext context) {
    double progress = (log['progress'] ?? 0.0).toDouble();
    bool isCompleted = progress >= 1.0;

    List<dynamic> dailyReports = log['daily_reports'] ?? [];
    List<dynamic> punchLists = log['punch_lists'] ?? [];
    // 🚀 [추가] "일정 관리"에 등록된 것 중 아직 완료 안 된 것만 카드에서
    // 미리 보여준다 (완료된 건 일정 관리 화면에서만 확인).
    List<dynamic> upcomingSchedules = (log['schedules'] as List<dynamic>? ?? [])
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
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                log['name'] ?? '이름 없음',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: tossText,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            if (!isProjectActive) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: tossSubText.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  "완료됨",
                                  style: TextStyle(
                                    color: tossSubText,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ],
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "작업 일지",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: tossSubText,
                            fontSize: 14,
                          ),
                        ),
                        // 🚀 [추가] 달력으로 빠진 날 확인 + 기간 통계/내보내기
                        InkWell(
                          onTap: onOpenDailyReportCalendar,
                          borderRadius: BorderRadius.circular(8),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_month_rounded,
                                size: 15,
                                color: tossBlue,
                              ),
                              SizedBox(width: 4),
                              Text(
                                "달력/통계",
                                style: TextStyle(
                                  color: tossBlue,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 🚀 [추가] 매일 하나씩 쌓이는 목록이라 오래 진행되는
                    // 현장은 카드 하나가 한없이 길어진다 - 5개씩 페이지로
                    // 나눠서 보여준다.
                    DailyReportPager(
                      reports: dailyReports,
                      onOpenReport: onOpenDailyReport,
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ⚠️ 이슈 리스트 목록
                  if (punchLists.isNotEmpty) ...[
                    PunchListSection(
                      punchLists: punchLists,
                      onOpenPunchDetail: onOpenPunchDetail,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 🚀 [추가] 프로젝트 완료/보관 처리 버튼
                  Center(
                    child: TextButton.icon(
                      onPressed: onToggleProjectStatus,
                      icon: Icon(
                        isProjectActive
                            ? Icons.check_circle_outline_rounded
                            : Icons.replay_rounded,
                        size: 18,
                      ),
                      label: Text(isProjectActive ? "프로젝트 완료 처리" : "다시 진행중으로"),
                      style: TextButton.styleFrom(
                        foregroundColor: isProjectActive
                            ? Colors.green
                            : tossBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
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
}

// 리스트 아이템 (WorkLogCard와 아래 DailyReportPager가 함께 쓰므로
// 최상위 함수로 뺐다)
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
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
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

// 🚀 [신규] 이슈 목록도 시간이 지나면 계속 쌓이므로, 일정 관리와
// 동일하게 "완료 숨김"(기본 켜짐) 필터와 5개씩 페이지네이션을 둔다.
class PunchListSection extends StatefulWidget {
  final List<dynamic> punchLists;
  final void Function(Map<String, dynamic> punch) onOpenPunchDetail;

  const PunchListSection({
    required this.punchLists,
    required this.onOpenPunchDetail,
  });

  @override
  State<PunchListSection> createState() => PunchListSectionState();
}

class PunchListSectionState extends State<PunchListSection> {
  static const int _pageSize = 5;
  bool _hideCompleted = true;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final List<dynamic> visible = _hideCompleted
        ? widget.punchLists.where((p) => p['is_completed'] != true).toList()
        : widget.punchLists;

    final int totalPages = (visible.length / _pageSize).ceil().clamp(
      1,
      1 << 30,
    );
    final int page = _page.clamp(0, totalPages - 1);
    final int start = page * _pageSize;
    final int end = (start + _pageSize).clamp(0, visible.length);
    final List<dynamic> pageItems = visible.sublist(
      start.clamp(0, visible.length),
      end,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "이슈 목록",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: tossSubText,
                fontSize: 14,
              ),
            ),
            InkWell(
              onTap: () => setState(() {
                _hideCompleted = !_hideCompleted;
                _page = 0;
              }),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _hideCompleted
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 14,
                    color: tossBlue,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _hideCompleted ? "완료 숨김" : "전체 보기",
                    style: const TextStyle(
                      color: tossBlue,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          Text(
            _hideCompleted && widget.punchLists.isNotEmpty
                ? "미해결 이슈가 없습니다. 처리 완료한 ${widget.punchLists.length}건은 '완료 숨김'을 눌러 '전체 보기'로 확인하세요."
                : "미해결 이슈가 없습니다.",
            style: const TextStyle(
              color: tossSubText,
              fontSize: 13,
              height: 1.4,
            ),
          )
        else ...[
          ...pageItems.map((punch) {
            final bool isPunchDone = punch['is_completed'] == true;
            return _buildUnifiedRecordItem(
              context: context,
              // 위치를 제목에 보여줘서 어느 곳 이슈인지 목록에서 바로 알 수 있게 한다.
              title:
                  "${(punch['location']?.toString() ?? '').isEmpty || punch['location'] == '위치 미상' ? '' : '${punch['location']} · '}${isPunchDone ? '처리 완료' : '확인 요망'}",
              content: punch['priority'] == '긴급'
                  ? "[긴급] ${punch['content'] ?? ''}"
                  : (punch['content'] ?? '').toString(),
              itemData: punch,
              icon: Icons.priority_high_rounded,
              isWarning: true,
              isCompleted: isPunchDone,
              // 🚀 탭하면 언제 발생했고 어떻게 처리했는지 정리할 수 있는
              // 이슈 상세 화면으로 들어간다.
              onTap: () => widget.onOpenPunchDetail(punch),
            );
          }),
          if (totalPages > 1)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: page > 0
                        ? () => setState(() => _page = page - 1)
                        : null,
                    icon: const Icon(Icons.chevron_left_rounded),
                    color: page > 0
                        ? tossText
                        : tossSubText.withValues(alpha: 0.4),
                    splashRadius: 20,
                  ),
                  Text(
                    "${page + 1} / $totalPages",
                    style: const TextStyle(
                      color: tossSubText,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  IconButton(
                    onPressed: page < totalPages - 1
                        ? () => setState(() => _page = page + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                    color: page < totalPages - 1
                        ? tossText
                        : tossSubText.withValues(alpha: 0.4),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

// 🚀 [신규] 작업 일지가 매일 쌓이는 걸 고려해, 5개씩 페이지로 나눠서
// 보여주는 위젯. WorkLogCard는 setState가 잦아서(펼침/접힘 등) 페이지
// 상태를 카드 안에 그냥 두면 리렌더 때마다 흔들릴 수 있어, 별도
// StatefulWidget으로 분리해 페이지 번호를 독립적으로 기억한다.
class DailyReportPager extends StatefulWidget {
  final List<dynamic> reports;
  final void Function(Map<String, dynamic> report) onOpenReport;

  const DailyReportPager({required this.reports, required this.onOpenReport});

  @override
  State<DailyReportPager> createState() => DailyReportPagerState();
}

class DailyReportPagerState extends State<DailyReportPager> {
  static const int _pageSize = 5;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final int totalPages = (widget.reports.length / _pageSize).ceil();
    // 🚀 목록 길이가 줄어들 수도 있으니(항목 삭제 등) 범위를 벗어나지
    // 않게 보정한다.
    final int page = _page.clamp(0, totalPages - 1);
    final int start = page * _pageSize;
    final int end = (start + _pageSize).clamp(0, widget.reports.length);
    final List<dynamic> pageItems = widget.reports.sublist(start, end);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...pageItems.map(
          (report) => _buildUnifiedRecordItem(
            context: context,
            title: "${report['date']} (${report['points']} pt)",
            content: report['note'],
            itemData: report,
            icon: Icons.article_rounded,
            isWarning: false,
            // 🚀 탭하면 그날 작업 일보 전체(작업유형/인원/포인트/메모/
            // 사진)를 볼 수 있는 화면으로 들어간다.
            onTap: () => widget.onOpenReport(report),
          ),
        ),
        if (totalPages > 1)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: page > 0
                      ? () => setState(() => _page = page - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                  color: page > 0
                      ? tossText
                      : tossSubText.withValues(alpha: 0.4),
                  splashRadius: 20,
                ),
                Text(
                  "${page + 1} / $totalPages",
                  style: const TextStyle(
                    color: tossSubText,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                IconButton(
                  onPressed: page < totalPages - 1
                      ? () => setState(() => _page = page + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                  color: page < totalPages - 1
                      ? tossText
                      : tossSubText.withValues(alpha: 0.4),
                  splashRadius: 20,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
