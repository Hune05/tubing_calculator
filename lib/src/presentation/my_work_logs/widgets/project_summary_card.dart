import 'package:flutter/material.dart';

import '../models/project_phase.dart';
import '../models/report_tools.dart' show reportDateOf;

const Color _tossBlue = Color(0xFF007580);
const Color _tossText = Color(0xFF191F28);
const Color _tossSub = Color(0xFF8B95A1);
const Color _tossBg = Color(0xFFF2F4F6);
const Color _warnRed = Color(0xFFF04438);

// 🚀 [프로젝트 목록 카드] 예전엔 이름·날짜만 있고 펼쳐야 내용을 볼 수 있었다. 카드
// 자체에 진행률, 현재 단계, 납기 D-day, 미해결 이슈 수를 보여주고, 납기가 지난
// 진행중 프로젝트는 붉게 강조한다. 색은 프로젝트 고유색(내 일정 관리와 동일).
class ProjectSummaryCard extends StatelessWidget {
  final Map<String, dynamic> log;
  final bool isActive;
  final VoidCallback onTap;

  const ProjectSummaryCard({
    super.key,
    required this.log,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final id = log['id']?.toString() ?? log['name']?.toString() ?? '';
    final color = colorForProject(id);
    final progress = projectProgress(log);
    final int? weekDelta = progressDeltaSince(log, 7);
    final due = projectDue(log);
    final cur = currentPhase(log);
    final issues = unresolvedIssueCount(log);
    final today = dayOnly(DateTime.now());
    // 마지막 일보가 며칠 전인지(진행중 프로젝트에서 일보가 끊기지 않게 눈에 띄게).
    DateTime? lastReport;
    for (final r in (log['daily_reports'] as List? ?? []).whereType<Map>()) {
      final d = reportDateOf(r);
      if (lastReport == null || d.isAfter(lastReport)) lastReport = d;
    }
    final int? sinceReport = lastReport == null
        ? null
        : today.difference(lastReport).inDays;
    final int? diff = due?.difference(today).inDays;
    final bool overdue = isActive && diff != null && diff < 0 && progress < 1;

    String? ddayText;
    Color ddayColor = _tossBlue;
    if (diff != null && isActive) {
      ddayText = diff == 0 ? "D-Day" : (diff > 0 ? "D-$diff" : "D+${-diff}");
      if (diff < 0) {
        ddayColor = _warnRed;
      } else if (diff <= 7) {
        ddayColor = const Color(0xFFC77700);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: overdue ? _warnRed.withValues(alpha: 0.5) : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 6,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(20),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              log['name']?.toString() ?? '이름 없음',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: isActive ? _tossText : _tossSub,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          if (ddayText != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: ddayColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                ddayText,
                                style: TextStyle(
                                  color: ddayColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          if (!isActive)
                            const Text(
                              "완료됨",
                              style: TextStyle(color: _tossSub, fontSize: 12),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${log['date'] ?? ''} · ${log['revision'] ?? ''}",
                        style: const TextStyle(color: _tossSub, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 6,
                                backgroundColor: _tossBg,
                                color: progress >= 1 ? Colors.green : color,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "${(progress * 100).round()}%",
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: _tossText,
                            ),
                          ),
                          if (isActive && weekDelta != null && weekDelta != 0)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Text(
                                "주간 ${weekDelta > 0 ? '+' : ''}$weekDelta%p",
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  color: weekDelta > 0
                                      ? const Color(0xFF1B9E5A)
                                      : const Color(0xFFE5484D),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          if (cur != null)
                            _chip(Icons.flag_rounded, "${cur['name']}", color),
                          if ((log['workType']?.toString() ?? '').isNotEmpty)
                            _chip(
                              Icons.category_outlined,
                              log['workType'].toString(),
                              _tossSub,
                            ),
                          if (isActive && delayedPhase(log) != null)
                            _chip(
                              Icons.warning_amber_rounded,
                              "${delayedPhase(log)!.phase['name']} ${delayedPhase(log)!.days}일 지연",
                              _warnRed,
                            ),
                          if (isActive)
                            _chip(
                              Icons.edit_note_rounded,
                              sinceReport == null
                                  ? "일보 없음"
                                  : (sinceReport <= 0
                                        ? "오늘 일보"
                                        : "일보 $sinceReport일 전"),
                              (sinceReport == null || sinceReport >= 3)
                                  ? _warnRed
                                  : (sinceReport <= 0 ? _tossBlue : _tossSub),
                            ),
                          if (issues > 0)
                            _chip(
                              Icons.error_outline_rounded,
                              "이슈 $issues",
                              _warnRed,
                            ),
                          if (overdueIssueCount(log) > 0)
                            _chip(
                              Icons.event_busy_rounded,
                              "기한 초과 ${overdueIssueCount(log)}",
                              _warnRed,
                            ),
                          if (cur == null && issues == 0)
                            _chip(
                              Icons.check_circle_outline_rounded,
                              phasesOf(log).isEmpty ? "단계 미설정" : "모든 단계 완료",
                              _tossSub,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String text, Color c) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: c),
      const SizedBox(width: 4),
      Text(
        text,
        style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    ],
  );
}
