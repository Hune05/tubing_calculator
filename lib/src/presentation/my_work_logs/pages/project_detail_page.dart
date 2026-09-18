import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/project_phase.dart';
import '../widgets/work_log_card.dart';

// 🚀 [프로젝트 상세 - 신규] 예전엔 프로젝트 카드를 펼치면 일정/일지/이슈가 한 카드
// 안에 길게 쌓였고, 프로젝트가 "지금 어떤 상태인지"는 한눈에 안 보였다. 프로젝트를
// 열면 진행률·D-day·현재 단계가 먼저 보이고, 아래 탭(개요/단계·일정/이슈/일지)으로
// 나눠 본다. 저장/이동 같은 실제 동작은 목록 화면(WorkLogMainScreen)이 이미 갖고
// 있던 것을 [ProjectActions]로 그대로 넘겨받아 재사용한다.
class ProjectActions {
  final Future<void> Function() addPunch;
  final Future<void> Function(Map<String, dynamic> punch) openPunch;
  final Future<void> Function() addReport;
  final Future<void> Function(Map<String, dynamic> report) openReport;
  final Future<void> Function() openReportCalendar;
  final Future<void> Function({String? phaseId, bool add}) openSchedule;
  final void Function() save;
  final void Function() toggleStatus;
  final void Function() delete;

  const ProjectActions({
    required this.addPunch,
    required this.openPunch,
    required this.addReport,
    required this.openReport,
    required this.openReportCalendar,
    required this.openSchedule,
    required this.save,
    required this.toggleStatus,
    required this.delete,
  });
}

class ProjectDetailPage extends StatefulWidget {
  final Map<String, dynamic> log;
  final ProjectActions actions;
  final int initialTab;

  const ProjectDetailPage({
    super.key,
    required this.log,
    required this.actions,
    this.initialTab = 0,
  });

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final Set<String> _expandedPhases = {};

  Map<String, dynamic> get log => widget.log;

  @override
  void initState() {
    super.initState();
    _tab = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  bool get _isActive => log['status'] != 'DONE';

  Future<void> _run(Future<void> Function() f) async {
    await f();
    if (mounted) setState(() {});
  }

  void _changed() {
    widget.actions.save();
    setState(() {});
  }

  String _md(DateTime d) => "${d.month}/${d.day}";

  String _dday(DateTime due) {
    final diff = due.difference(dayOnly(DateTime.now())).inDays;
    if (diff == 0) return "D-Day";
    return diff > 0 ? "D-$diff" : "D+${-diff}";
  }

  Color _ddayColor(DateTime due) {
    final diff = due.difference(dayOnly(DateTime.now())).inDays;
    if (diff < 0) return warningRed;
    if (diff <= 7) return const Color(0xFFC77700);
    return tossBlue;
  }

  // ───────────────────────── 요약 헤더 ─────────────────────────
  Widget _buildHeader() {
    final progress = projectProgress(log);
    final due = projectDue(log);
    final cur = currentPhase(log);
    final issues = unresolvedIssueCount(log);
    return Container(
      color: pureWhite,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "${(progress * 100).round()}%",
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: tossText,
                    letterSpacing: -1,
                  ),
                ),
              ),
              if (due != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _ddayColor(due).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "납기 ${_dday(due)}",
                    style: TextStyle(
                      color: _ddayColor(due),
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: tossBg,
              color: progress >= 1 ? Colors.green : tossBlue,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              if (cur != null)
                _miniInfo(Icons.flag_rounded, "현재 ${cur['name']}", tossBlue),
              if (due != null)
                _miniInfo(
                  Icons.event_rounded,
                  "종료 예정 ${due.year}.${due.month}.${due.day}",
                  tossSubText,
                ),
              _miniInfo(
                Icons.error_outline_rounded,
                "미해결 이슈 $issues",
                issues > 0 ? warningRed : tossSubText,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniInfo(IconData icon, String text, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 4),
      Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );

  // ───────────────────────── 개요 탭 ─────────────────────────
  Widget _buildOverviewTab() {
    final phases = phasesOf(log);
    final today = dayOnly(DateTime.now());
    final weekEnd = today.add(const Duration(days: 7));
    final upcoming =
        schedulesOf(log).where((s) {
          if (s['isCompleted'] == true) return false;
          if (s['dateTime'] == null) return true; // 입고일 미정 자재 요청
          return !dayOnly(asDate(s['dateTime'])).isAfter(weekEnd);
        }).toList()..sort((a, b) {
          if (a['dateTime'] == null) return -1;
          if (b['dateTime'] == null) return 1;
          return asDate(a['dateTime']).compareTo(asDate(b['dateTime']));
        });
    final punches =
        (log['punch_lists'] as List? ?? [])
            .whereType<Map>()
            .where((p) => p['is_completed'] != true)
            .map((p) => p as Map<String, dynamic>)
            .toList()
          ..sort((a, b) {
            const order = {'긴급': 0, '보통': 1, '여유': 2};
            return (order[a['priority']] ?? 1).compareTo(
              order[b['priority']] ?? 1,
            );
          });

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        Row(
          children: [
            Expanded(
              child: _quickButton(
                Icons.add_task_rounded,
                "일정 추가",
                () => _run(() => widget.actions.openSchedule(add: true)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _quickButton(
                Icons.edit_document,
                "일지 작성",
                () => _run(widget.actions.addReport),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _quickButton(
                Icons.error_outline_rounded,
                "이슈 등록",
                () => _run(widget.actions.addPunch),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (phases.isNotEmpty) ...[
          _sectionTitle("단계 진행"),
          const SizedBox(height: 10),
          _buildPhaseStrip(phases),
          const SizedBox(height: 22),
        ],
        _sectionTitle("이번 주 · 지연 일정 (${upcoming.length})"),
        const SizedBox(height: 8),
        if (upcoming.isEmpty)
          _emptyText("이번 주에 확인할 일정이 없습니다.")
        else
          ...upcoming.take(6).map(_scheduleRow),
        const SizedBox(height: 22),
        _sectionTitle("미해결 이슈 (${punches.length})"),
        const SizedBox(height: 8),
        if (punches.isEmpty)
          _emptyText("미해결 이슈가 없습니다.")
        else
          ...punches
              .take(4)
              .map(
                (p) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    p['content']?.toString() ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: tossText,
                    ),
                  ),
                  subtitle: Text(
                    "${p['location'] ?? ''}  ·  ${p['priority'] ?? '보통'}",
                    style: const TextStyle(fontSize: 12, color: tossSubText),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _run(() => widget.actions.openPunch(p)),
                ),
              ),
        const SizedBox(height: 28),
        Center(
          child: TextButton.icon(
            onPressed: () {
              widget.actions.toggleStatus();
              setState(() {});
            },
            icon: Icon(
              _isActive
                  ? Icons.check_circle_outline_rounded
                  : Icons.replay_rounded,
              size: 18,
            ),
            label: Text(_isActive ? "프로젝트 완료 처리" : "다시 진행중으로"),
            style: TextButton.styleFrom(
              foregroundColor: _isActive ? Colors.green : tossBlue,
            ),
          ),
        ),
        Center(
          child: TextButton(
            onPressed: _confirmDelete,
            style: TextButton.styleFrom(foregroundColor: tossSubText),
            child: const Text("이 프로젝트 삭제하기"),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("프로젝트 삭제"),
        content: const Text("일정·일지·이슈가 모두 함께 삭제됩니다. 계속할까요?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("삭제", style: TextStyle(color: warningRed)),
          ),
        ],
      ),
    );
    if (ok == true) {
      widget.actions.delete();
      if (mounted) Navigator.pop(context);
    }
  }

  Widget _quickButton(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: pureWhite,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, color: tossBlue, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: tossText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(
    t,
    style: const TextStyle(
      fontWeight: FontWeight.w800,
      fontSize: 15,
      color: tossText,
    ),
  );

  Widget _emptyText(String t) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(t, style: const TextStyle(color: tossSubText, fontSize: 13)),
  );

  Widget _buildPhaseStrip(List<Map<String, dynamic>> phases) {
    final cur = currentPhase(log);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (int i = 0; i < phases.length; i++) ...[
            InkWell(
              onTap: () => _tab.animateTo(1),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: phaseIsDone(log, phases[i])
                      ? Colors.green.withValues(alpha: 0.14)
                      : (cur != null && cur['id'] == phases[i]['id']
                            ? tossBlue
                            : tossBg),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  phases[i]['name'].toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: phaseIsDone(log, phases[i])
                        ? Colors.green.shade700
                        : (cur != null && cur['id'] == phases[i]['id']
                              ? pureWhite
                              : tossSubText),
                  ),
                ),
              ),
            ),
            if (i < phases.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: tossSubText,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _scheduleRow(Map<String, dynamic> s) {
    final dt = s['dateTime'] == null ? null : asDate(s['dateTime']);
    final overdue = dt != null && dt.isBefore(DateTime.now());
    String badge;
    if (dt == null) {
      badge = "미정";
    } else {
      final diff = dayOnly(dt).difference(dayOnly(DateTime.now())).inDays;
      badge = diff < 0 ? "${-diff}일 지남" : (diff == 0 ? "오늘" : "D-$diff");
    }
    final color = (dt == null || overdue) ? warningRed : tossBlue;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(
        s['title']?.toString() ?? s['type']?.toString() ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700, color: tossText),
      ),
      subtitle: Text(
        "${s['type'] ?? ''}${dt != null ? '  ·  ${_md(dt)}' : ''}",
        style: const TextStyle(fontSize: 12, color: tossSubText),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          badge,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
      onTap: () => _run(() => widget.actions.openSchedule()),
    );
  }

  // ───────────────────────── 단계·일정 탭 ─────────────────────────
  void _toggleSchedule(Map<String, dynamic> s) {
    // 검사일정은 합격/불합격 결과를 남겨야 하므로 일정 화면에서 처리한다.
    if (s['type'] == '검사일정') {
      _run(
        () => widget.actions.openSchedule(phaseId: s['phaseId']?.toString()),
      );
      return;
    }
    final list = log['schedules'] as List? ?? [];
    for (final e in list) {
      if (e is Map && e['id'] == s['id']) {
        e['isCompleted'] = !(e['isCompleted'] == true);
        break;
      }
    }
    _changed();
  }

  Widget _buildPhasesTab() {
    final phases = phasesOf(log);
    final unassigned = schedulesInPhase(log, null);

    if (phases.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
        children: [
          const Icon(Icons.account_tree_outlined, size: 52, color: tossSubText),
          const SizedBox(height: 16),
          const Text(
            "프로젝트를 단계로 나눠 관리해보세요",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: tossText,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "설계 → 자재 입고 → 제작 → 설치 → 시운전·검사 → 납품\n표준 단계를 시작일/납기일에 맞춰 자동으로 나눠드려요.",
            textAlign: TextAlign.center,
            style: TextStyle(color: tossSubText, height: 1.5),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showStandardSetup,
            icon: const Icon(Icons.auto_awesome_rounded, color: pureWhite),
            label: const Text(
              "표준 단계로 시작하기",
              style: TextStyle(color: pureWhite, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: tossBlue,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _showPhaseEditor(),
            icon: const Icon(Icons.add_rounded),
            label: const Text("단계 직접 추가"),
          ),
          if (unassigned.isNotEmpty) ...[
            const SizedBox(height: 28),
            _sectionTitle("단계 없는 일정 (${unassigned.length})"),
            ...unassigned.map(_phaseScheduleTile),
          ],
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorder: (oldI, newI) {
            if (newI > oldI) newI -= 1;
            final list = phasesOf(log);
            final moved = list.removeAt(oldI);
            list.insert(newI, moved);
            setPhases(log, list);
            _changed();
          },
          children: [
            for (int i = 0; i < phases.length; i++)
              _phaseCard(phases[i], i, key: ValueKey(phases[i]['id'])),
          ],
        ),
        if (unassigned.isNotEmpty) ...[
          const SizedBox(height: 16),
          _sectionTitle("단계 없는 일정 (${unassigned.length})"),
          const SizedBox(height: 6),
          ...unassigned.map(_phaseScheduleTile),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _showPhaseEditor(),
          icon: const Icon(Icons.add_rounded),
          label: const Text("단계 추가"),
          style: OutlinedButton.styleFrom(
            foregroundColor: tossBlue,
            side: const BorderSide(color: tossBlue),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _phaseCard(Map<String, dynamic> p, int index, {required Key key}) {
    final id = p['id'].toString();
    final items = schedulesInPhase(log, id);
    final progress = phaseProgress(log, p);
    final done = progress >= 1.0;
    final cur = currentPhase(log);
    final isCurrent = cur != null && cur['id'] == p['id'];
    final s = phaseStart(p), e = phaseEnd(p);
    final expanded = _expandedPhases.contains(id);
    final accent = done ? Colors.green : (isCurrent ? tossBlue : tossSubText);

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent ? tossBlue : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() {
              expanded ? _expandedPhases.remove(id) : _expandedPhases.add(id);
            }),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 8, 12),
              child: Row(
                children: [
                  ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        color: tossSubText,
                        size: 20,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                p['name'].toString(),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: done ? tossSubText : tossText,
                                  decoration: done
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                            if (isCurrent) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: tossBlue,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  "진행중",
                                  style: TextStyle(
                                    color: pureWhite,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          (s != null && e != null)
                              ? "${_md(s)} ~ ${_md(e)}  ·  일정 ${items.length}건"
                              : "기간 미정  ·  일정 ${items.length}건",
                          style: const TextStyle(
                            color: tossSubText,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 5,
                            backgroundColor: tossBg,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Checkbox(
                    value: p['isCompleted'] == true || done,
                    activeColor: Colors.green,
                    onChanged: (v) {
                      final list = phasesOf(log);
                      list[index]['isCompleted'] = v == true;
                      setPhases(log, list);
                      _changed();
                    },
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: tossSubText,
                    ),
                    onSelected: (v) {
                      if (v == 'edit') _showPhaseEditor(existing: p);
                      if (v == 'delete') _deletePhase(p);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text("단계 수정")),
                      PopupMenuItem(value: 'delete', child: Text("단계 삭제")),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                children: [
                  const Divider(height: 1),
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        "이 단계에 등록된 세부 일정이 없습니다.",
                        style: TextStyle(color: tossSubText, fontSize: 13),
                      ),
                    )
                  else
                    ...items.map(_phaseScheduleTile),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => _run(
                            () => widget.actions.openSchedule(
                              phaseId: id,
                              add: true,
                            ),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text("세부 일정 추가"),
                        ),
                      ),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => _run(
                            () => widget.actions.openSchedule(phaseId: id),
                          ),
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: const Text("일정 화면에서 보기"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _phaseScheduleTile(Map<String, dynamic> s) {
    final dt = s['dateTime'] == null ? null : asDate(s['dateTime']);
    final done = s['isCompleted'] == true;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Checkbox(
        value: done,
        activeColor: Colors.green,
        onChanged: (_) => _toggleSchedule(s),
      ),
      title: Text(
        s['title']?.toString() ?? s['type']?.toString() ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: done ? tossSubText : tossText,
          decoration: done ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text(
        "${s['type'] ?? ''}${dt != null ? '  ·  ${_md(dt)}' : '  ·  날짜 미정'}",
        style: const TextStyle(fontSize: 12, color: tossSubText),
      ),
      onTap: () => _run(
        () => widget.actions.openSchedule(phaseId: s['phaseId']?.toString()),
      ),
    );
  }

  void _deletePhase(Map<String, dynamic> p) {
    final id = p['id'].toString();
    final list = phasesOf(log)..removeWhere((e) => e['id'] == id);
    setPhases(log, list);
    // 이 단계의 일정은 지우지 않고 "단계 없음"으로 돌린다.
    for (final e in (log['schedules'] as List? ?? [])) {
      if (e is Map && e['phaseId']?.toString() == id) e['phaseId'] = null;
    }
    _changed();
  }

  Future<void> _showPhaseEditor({Map<String, dynamic>? existing}) async {
    final nameCtrl = TextEditingController(
      text: existing?['name']?.toString() ?? '',
    );
    DateTime? start = existing == null ? null : phaseStart(existing);
    DateTime? end = existing == null ? null : phaseEnd(existing);

    Future<DateTime?> pick(DateTime? initial, DateTime? first) =>
        showDatePicker(
          context: context,
          initialDate: initial ?? first ?? DateTime.now(),
          firstDate: first ?? DateTime(2020),
          lastDate: DateTime(2035),
        );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            decoration: const BoxDecoration(
              color: pureWhite,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  existing == null ? "단계 추가" : "단계 수정",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: tossText,
                  ),
                ),
                const SizedBox(height: 16),
                if (existing == null)
                  Wrap(
                    spacing: 8,
                    children: kStandardPhaseNames
                        .where((n) => !phasesOf(log).any((p) => p['name'] == n))
                        .map(
                          (n) => ActionChip(
                            label: Text(n),
                            backgroundColor: tossBg,
                            side: BorderSide.none,
                            onPressed: () => nameCtrl.text = n,
                          ),
                        )
                        .toList(),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameCtrl,
                  autofocus: existing == null,
                  decoration: InputDecoration(
                    labelText: "단계 이름",
                    filled: true,
                    fillColor: tossBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final d = await pick(start, null);
                          if (d != null) {
                            setSheet(() {
                              start = d;
                              if (end != null && end!.isBefore(d)) end = d;
                            });
                          }
                        },
                        child: Text(
                          start == null
                              ? "시작일"
                              : "${start!.month}/${start!.day} 시작",
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final d = await pick(end ?? start, start);
                          if (d != null) setSheet(() => end = d);
                        },
                        child: Text(
                          end == null ? "종료일" : "${end!.month}/${end!.day} 종료",
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      final list = phasesOf(log);
                      if (existing == null) {
                        list.add(makePhase(name, start: start, end: end));
                      } else {
                        final i = list.indexWhere(
                          (p) => p['id'] == existing['id'],
                        );
                        if (i != -1) {
                          list[i]['name'] = name;
                          list[i]['startDate'] = start;
                          list[i]['endDate'] = end;
                        }
                      }
                      setPhases(log, list);
                      Navigator.pop(ctx);
                      _changed();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tossBlue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      existing == null ? "추가" : "저장",
                      style: const TextStyle(
                        color: pureWhite,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 표준 6단계를 시작일~납기일에 맞춰 비중대로 자동 배분한다.
  Future<void> _showStandardSetup() async {
    DateTime start = dayOnly(DateTime.now());
    DateTime end = start.add(const Duration(days: 55));
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final preview = buildStandardPhases(start, end);
          return Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            decoration: const BoxDecoration(
              color: pureWhite,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "표준 단계로 시작하기",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: tossText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "시작일과 납기일만 정하면 각 단계 기간이 자동으로 나뉘어요. 나중에 단계별로 수정할 수 있습니다.",
                    style: TextStyle(
                      color: tossSubText,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: ctx,
                              initialDate: start,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (d != null) {
                              setSheet(() {
                                start = dayOnly(d);
                                if (end.isBefore(start)) end = start;
                              });
                            }
                          },
                          child: Text("시작 ${start.month}/${start.day}"),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: ctx,
                              initialDate: end,
                              firstDate: start,
                              lastDate: DateTime(2035),
                            );
                            if (d != null) setSheet(() => end = dayOnly(d));
                          },
                          child: Text("납기 ${end.month}/${end.day}"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final w in [1, 2, 4, 6, 8, 12])
                        ActionChip(
                          label: Text("$w주"),
                          backgroundColor: tossBg,
                          side: BorderSide.none,
                          onPressed: () => setSheet(
                            () => end = start.add(Duration(days: w * 7 - 1)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ...preview.map(
                    (p) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 90,
                            child: Text(
                              p['name'].toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: tossText,
                              ),
                            ),
                          ),
                          Text(
                            "${_md(phaseStart(p)!)} ~ ${_md(phaseEnd(p)!)}",
                            style: const TextStyle(color: tossSubText),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setPhases(log, preview);
                        Navigator.pop(ctx);
                        _changed();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tossBlue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        "이대로 만들기",
                        style: TextStyle(
                          color: pureWhite,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ───────────────────────── 이슈 / 일지 탭 ─────────────────────────
  Widget _buildIssuesTab() {
    final punches = (log['punch_lists'] as List? ?? []);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        ElevatedButton.icon(
          onPressed: () => _run(widget.actions.addPunch),
          icon: const Icon(Icons.add_rounded, color: pureWhite),
          label: const Text(
            "이슈 등록",
            style: TextStyle(color: pureWhite, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: tossBlue,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (punches.isEmpty)
          _emptyText("등록된 이슈가 없습니다.")
        else
          PunchListSection(
            punchLists: punches,
            onOpenPunchDetail: (p) => _run(() => widget.actions.openPunch(p)),
          ),
      ],
    );
  }

  Widget _buildReportsTab() {
    final reports = (log['daily_reports'] as List? ?? []);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _run(widget.actions.addReport),
                icon: const Icon(Icons.edit_document, color: pureWhite),
                label: const Text(
                  "오늘 일지 작성",
                  style: TextStyle(
                    color: pureWhite,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: tossBlue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: () => _run(widget.actions.openReportCalendar),
              icon: const Icon(Icons.calendar_month_rounded, size: 18),
              label: const Text("달력/통계"),
              style: OutlinedButton.styleFrom(
                foregroundColor: tossBlue,
                side: const BorderSide(color: tossBlue),
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (reports.isEmpty)
          _emptyText("작성된 일지가 없습니다.")
        else
          DailyReportPager(
            reports: reports,
            onOpenReport: (r) => _run(() => widget.actions.openReport(r)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tossBg,
      appBar: AppBar(
        backgroundColor: pureWhite,
        foregroundColor: tossText,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Flexible(
              child: Text(
                log['name']?.toString() ?? '이름 없음',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            if (!_isActive) ...[
              const SizedBox(width: 8),
              const Text(
                "완료됨",
                style: TextStyle(color: tossSubText, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      body: Column(
        children: [
          _buildHeader(),
          Container(
            color: pureWhite,
            child: TabBar(
              controller: _tab,
              labelColor: tossBlue,
              unselectedLabelColor: tossSubText,
              indicatorColor: tossBlue,
              labelStyle: const TextStyle(fontWeight: FontWeight.w800),
              tabs: const [
                Tab(text: "개요"),
                Tab(text: "단계·일정"),
                Tab(text: "이슈"),
                Tab(text: "일지"),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _buildOverviewTab(),
                _buildPhasesTab(),
                _buildIssuesTab(),
                _buildReportsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
