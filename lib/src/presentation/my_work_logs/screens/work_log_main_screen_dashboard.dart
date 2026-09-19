// ignore_for_file: invalid_use_of_protected_member
part of 'work_log_main_screen.dart';

// 🚀 dashboard 부분(화면 클래스에서 옮겨 온 메서드들, 동작은 그대로).
extension _WorkLogMainScreenState_dashboard on _WorkLogMainScreenState {
  Widget _buildWeeklyReportCard() {
    final active = _activeLogs;
    if (active.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: tossBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: _openWeeklyReport,
              borderRadius: BorderRadius.circular(10),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.summarize_rounded, color: tossBlue, size: 18),
                    SizedBox(width: 8),
                    Text(
                      "주간 보고",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: tossBlue,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: tossBlue,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: _shareOverviewImage,
            style: TextButton.styleFrom(
              foregroundColor: tossBlue,
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text(
              "현황 이미지",
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final missingReports = _projectsMissingTodayReport;
    final schedules = _allUpcomingSchedules;
    final issues = _allUnresolvedIssues;

    if (missingReports.isEmpty && schedules.isEmpty && issues.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayedSchedules = schedules.take(5).toList();
    final displayedIssues = issues.take(5).toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.dashboard_rounded, color: tossBlue, size: 18),
              SizedBox(width: 6),
              Text(
                "오늘 할 일",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: tossText,
                ),
              ),
            ],
          ),
          if (missingReports.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.edit_document,
                  size: 14,
                  color: Color(0xFFF04438),
                ),
                const SizedBox(width: 4),
                Text(
                  keepWords("오늘 일지 안 쓴 것 ${missingReports.length}건"),
                  style: const TextStyle(
                    color: tossSubText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: missingReports.map((log) {
                return ActionChip(
                  backgroundColor: tossBg,
                  side: BorderSide.none,
                  label: Text(
                    log['name'] ?? '이름 없음',
                    style: const TextStyle(
                      color: tossText,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  onPressed: () => _addDailyReportFor(log),
                );
              }).toList(),
            ),
          ],
          if (schedules.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.event_note_rounded, size: 14, color: tossBlue),
                const SizedBox(width: 4),
                Text(
                  keepWords("다가오는 일정 (미완료 ${schedules.length}건)"),
                  style: const TextStyle(
                    color: tossSubText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            ...displayedSchedules.map(_buildUpcomingRow),
            if (schedules.length > displayedSchedules.length)
              Text(
                keepWords(
                  "외 ${schedules.length - displayedSchedules.length}건 더",
                ),
                style: const TextStyle(color: tossSubText, fontSize: 12),
              ),
          ],
          if (issues.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 14,
                  color: Color(0xFFF04438),
                ),
                const SizedBox(width: 4),
                Text(
                  keepWords("미해결 이슈 (${issues.length}건)"),
                  style: const TextStyle(
                    color: tossSubText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            ...displayedIssues.map(_buildIssueRow),
            if (issues.length > displayedIssues.length)
              Text(
                keepWords("외 ${issues.length - displayedIssues.length}건 더"),
                style: const TextStyle(color: tossSubText, fontSize: 12),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildIssueRow(Map<String, dynamic> item) {
    final String priority = item['priority'] ?? '보통';
    final Color badgeColor = priority == '긴급'
        ? const Color(0xFFF04438)
        : (priority == '여유' ? tossSubText : tossBlue);

    return InkWell(
      onTap: () => _openPunchDetail(item['_projectRef'], item),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${item['_projectName']} · ${item['location'] ?? ''}",
                    style: const TextStyle(
                      color: tossSubText,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    item['content'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: tossText,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                priority,
                style: TextStyle(
                  color: badgeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingRow(Map<String, dynamic> item) {
    final DateTime? dt = item['dateTime'] == null
        ? null
        : _asDateTime(item['dateTime']);
    final bool isPending = dt == null;
    final bool isOverdue = !isPending && dt.isBefore(DateTime.now());
    final Color badgeColor = (isPending || isOverdue)
        ? const Color(0xFFF04438)
        : tossBlue;

    String badgeText;
    if (isPending) {
      badgeText = "미정";
    } else if (isOverdue) {
      final days = DateTime.now().difference(dt).inDays;
      badgeText = days > 0 ? "$days일 지남" : "기한 초과";
    } else {
      final days = dt.difference(DateTime.now()).inDays;
      badgeText = days > 0 ? "D-$days" : "오늘";
    }

    return InkWell(
      onTap: () => _openSchedule(item['_projectRef']),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${item['_projectName']} · ${item['type'] ?? ''}",
                    style: const TextStyle(
                      color: tossSubText,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    item['title'] ?? item['type'] ?? '',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: tossText,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  color: badgeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
