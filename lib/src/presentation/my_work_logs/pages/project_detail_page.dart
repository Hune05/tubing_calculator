import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/project_phase.dart';
import '../widgets/work_log_card.dart';
import '../models/report_tools.dart';
import '../models/photo_store.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/address_book.dart';
import '../models/report_style.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../../core/utils/image_picker_helper.dart' show ImagePickerHelper;
import '../models/summary_image.dart';
import 'package:share_plus/share_plus.dart';
import '../models/phase_templates.dart';
import '../../../data/repositories/work_project_repository.dart';
import 'report_search_page.dart' show ProjectPhotosPage;
import 'project_stats_page.dart';

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
  final void Function() toggleArchive;
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
    required this.toggleArchive,
    required this.delete,
  });
}

class ProjectDetailPage extends StatefulWidget {
  final Map<String, dynamic> log;
  final ProjectActions actions;
  final int initialTab;
  final bool openExport;

  const ProjectDetailPage({
    super.key,
    required this.log,
    required this.actions,
    this.initialTab = 0,
    this.openExport = false,
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
    if (widget.openExport) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showReportExport();
      });
    }
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
        _buildTypeRow(),
        _buildContactsSection(),
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
        ..._buildRetroSection(),
        ..._buildDelayBanner(),
        if (phases.isNotEmpty) ...[
          _sectionTitle("단계 진행"),
          const SizedBox(height: 10),
          _buildPhaseStrip(phases),
          const SizedBox(height: 22),
        ],
        ..._buildMaterialCard(),
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
              if (!_isActive) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text("프로젝트를 완료 처리했어요."),
                    action: SnackBarAction(
                      label: "회고 작성",
                      onPressed: _editRetro,
                    ),
                  ),
                );
              }
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
        if (!_isActive)
          Center(
            child: TextButton.icon(
              onPressed: () {
                final was = log['archived'] == true;
                widget.actions.toggleArchive();
                if (!was) {
                  Navigator.pop(context);
                } else {
                  setState(() {});
                }
              },
              icon: Icon(
                log['archived'] == true
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
                size: 18,
              ),
              label: Text(log['archived'] == true ? "보관 해제" : "보관함으로 이동"),
              style: TextButton.styleFrom(foregroundColor: tossSubText),
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
        ..._buildDelayBanner(),
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
        TextButton.icon(
          onPressed: _saveAsTemplate,
          icon: const Icon(Icons.bookmark_add_outlined, size: 18),
          label: const Text("이 단계 구성을 템플릿으로 저장"),
          style: TextButton.styleFrom(foregroundColor: tossSubText),
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
                          ((s != null && e != null)
                                  ? "${_md(s)} ~ ${_md(e)}  ·  일정 ${items.length}건"
                                  : "기간 미정  ·  일정 ${items.length}건") +
                              _workStatText(p['id'].toString()),
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
    var templates = await loadPhaseTemplates();
    // 프로젝트 공사 유형과 같은 유형으로 저장된 템플릿이 있으면 그걸 먼저 고른다.
    final myType = log['workType']?.toString() ?? '';
    var tpl = templates.firstWhere(
      (t) => myType.isNotEmpty && t.workType == myType,
      orElse: () => templates.first,
    );
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final preview = buildPhasesFromWeights(
            tpl.names,
            tpl.weights,
            start,
            end,
          );
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
                    "단계 만들기",
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
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final t in templates)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onLongPress: t.builtIn
                                  ? null
                                  : () async {
                                      await deletePhaseTemplate(t.name);
                                      final all = await loadPhaseTemplates();
                                      setSheet(() {
                                        templates = all;
                                        tpl = all.first;
                                      });
                                    },
                              child: ChoiceChip(
                                label: Text(
                                  (myType.isNotEmpty && t.workType == myType)
                                      ? "${t.name} ★추천"
                                      : t.name,
                                ),
                                selected:
                                    identical(tpl, t) || tpl.name == t.name,
                                showCheckmark: false,
                                selectedColor: tossBlue,
                                backgroundColor: tossBg,
                                side: BorderSide.none,
                                labelStyle: TextStyle(
                                  color: tpl.name == t.name
                                      ? pureWhite
                                      : tossSubText,
                                  fontWeight: FontWeight.w700,
                                ),
                                onSelected: (_) => setSheet(() => tpl = t),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (templates.length > 1)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        "저장한 템플릿은 길게 누르면 삭제돼요.",
                        style: TextStyle(color: tossSubText, fontSize: 11),
                      ),
                    ),
                  const SizedBox(height: 12),
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
        if (punches.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              onPressed: _showIssueExport,
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: const Text("이슈 보고서 내보내기"),
              style: OutlinedButton.styleFrom(foregroundColor: tossText),
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

  void _showIssueExport() {
    bool onlyOpen = true;
    bool withMedia = true;
    showModalBottomSheet(
      context: context,
      backgroundColor: pureWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "이슈 보고서 내보내기",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text("미해결만"),
                      selected: onlyOpen,
                      onSelected: (_) => setS(() => onlyOpen = true),
                    ),
                    ChoiceChip(
                      label: const Text("전체"),
                      selected: !onlyOpen,
                      onSelected: (_) => setS(() => onlyOpen = false),
                    ),
                  ],
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: withMedia,
                  onChanged: (v) => setS(() => withMedia = v == true),
                  title: const Text(
                    "PDF에 사진·도면 위치 포함",
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await shareReportText(
                            buildIssueReportDoc(log, onlyOpen: onlyOpen),
                          );
                        },
                        icon: const Icon(Icons.chat_outlined, size: 18),
                        label: const Text("텍스트(카톡)"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          try {
                            await shareReportPdf(
                              buildIssueReportDoc(log, onlyOpen: onlyOpen),
                              withPhotos: withMedia,
                            );
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("PDF 생성 실패: $e")),
                              );
                            }
                          }
                        },
                        icon: const Icon(
                          Icons.picture_as_pdf_outlined,
                          size: 18,
                        ),
                        label: const Text("PDF"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveAsTemplate() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("템플릿 이름"),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: "예: 배관 신설 공사"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text("저장"),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || name == '표준') return;
    await savePhaseTemplate(
      templateFromPhases(
        name,
        phasesOf(log),
        workType: log['workType']?.toString(),
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("'$name' 템플릿을 저장했어요. 단계 만들기에서 불러올 수 있습니다.")),
      );
    }
  }

  Future<void> _editReportHeader() async {
    final cur = (log['reportHeader'] as Map?) ?? {};
    final company = TextEditingController(
      text: cur['company']?.toString() ?? '',
    );
    final manager = TextEditingController(
      text: cur['manager']?.toString() ?? '',
    );
    String? logo = (cur['logoB64']?.toString() ?? '').isEmpty
        ? null
        : cur['logoB64'].toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text("이 프로젝트 보고서 머리말"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "발주처마다 다른 머리말·로고가 필요할 때 적어요. 비워 두면 기본 보고서 양식을 써요.",
                  style: TextStyle(fontSize: 12, color: tossSubText),
                ),
                TextField(
                  controller: company,
                  decoration: InputDecoration(
                    labelText: "회사명 / 현장명",
                    hintText: ReportStyle.current.company,
                  ),
                ),
                TextField(
                  controller: manager,
                  decoration: InputDecoration(
                    labelText: "담당자",
                    hintText: ReportStyle.current.manager,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (logo != null)
                      Container(
                        width: 48,
                        height: 48,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Image.memory(
                          base64Decode(logo!),
                          fit: BoxFit.contain,
                        ),
                      ),
                    OutlinedButton(
                      onPressed: () async {
                        final path = await ImagePickerHelper.pickImage(ctx);
                        if (path == null) return;
                        final bytes =
                            await FlutterImageCompress.compressWithFile(
                              path,
                              minWidth: 300,
                              minHeight: 300,
                              quality: 80,
                              format: path.toLowerCase().endsWith('.png')
                                  ? CompressFormat.png
                                  : CompressFormat.jpeg,
                            );
                        if (bytes != null)
                          setD(() => logo = base64Encode(bytes));
                      },
                      child: Text(logo == null ? "이 프로젝트 로고" : "로고 변경"),
                    ),
                    if (logo != null)
                      TextButton(
                        onPressed: () => setD(() => logo = null),
                        child: const Text("삭제"),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("취소"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("저장"),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final c = company.text.trim(), m = manager.text.trim();
    if (c.isEmpty && m.isEmpty && logo == null) {
      log.remove('reportHeader');
    } else {
      log['reportHeader'] = {
        'company': c,
        'manager': m,
        if (logo != null) 'logoB64': logo,
      };
    }
    _changed();
  }

  Future<void> _shareSummaryImage() async {
    try {
      final f = await createSummaryImage(log);
      // ignore: deprecated_member_use
      await Share.shareXFiles([
        XFile(f.path),
      ], text: "${log['name'] ?? '프로젝트'} 현황");
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("이미지 만들기 실패: $e")));
      }
    }
  }

  // ───────────────────────── 사진 용량 정리 ─────────────────────────
  Future<void> _optimizePhotos() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("사진 용량 정리"),
        content: const Text(
          "이 프로젝트에 올라간 큰 사진(400KB 이상)을 줄여서 다시 올립니다. "
          "새 사진으로 저장이 끝난 뒤에 옛 파일은 삭제돼요. 사진 수에 따라 시간이 걸릴 수 있습니다.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("정리 시작"),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;

    final progress = ValueNotifier<String>("준비 중…");
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ValueListenableBuilder<String>(
                  valueListenable: progress,
                  builder: (_, v, _) => Text(v),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    String message;
    try {
      final res = await optimizeProjectPhotos(
        log,
        onProgress: (d, t) => progress.value = "사진 확인 중… $d / $t",
      );
      if (res.count > 0) {
        progress.value = "저장 반영 대기 중…";
        widget.actions.save();
        // 서버에 새 URL이 반영된 뒤에만 옛 파일을 지운다(최대 20초 대기).
        for (int i = 0; i < 100; i++) {
          if (WorkProjectRepository.pendingWrites.value == 0) break;
          await Future.delayed(const Duration(milliseconds: 200));
        }
        if (WorkProjectRepository.pendingWrites.value == 0) {
          for (final r in res.oldRefs) {
            try {
              await r.delete();
            } catch (_) {}
          }
        }
        message =
            "${res.count}장을 줄였어요. 약 ${(res.savedBytes / 1024 / 1024).toStringAsFixed(1)}MB 절약";
      } else {
        message = "줄일 만한 큰 사진이 없어요.";
      }
    } catch (e) {
      message = "정리 중 오류가 났어요: $e";
    }
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  // ───────────────────────── 연락처 ─────────────────────────
  static const _contactRoles = ['현장 담당', '협력사', '자재 업체', '발주처', '기타'];

  List<Map<String, dynamic>> get _contacts => (log['contacts'] as List? ?? [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  Future<void> _call(String phone, {bool sms = false}) async {
    final n = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (n.isEmpty) return;
    final ok = await launchUrl(Uri(scheme: sms ? 'sms' : 'tel', path: n));
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(sms ? "문자 앱을 열 수 없어요." : "전화 앱을 열 수 없어요.")),
      );
    }
  }

  Future<void> _editContact({int? index}) async {
    final list = _contacts;
    final cur = index == null ? <String, dynamic>{} : list[index];
    final name = TextEditingController(text: cur['name']?.toString() ?? '');
    final phone = TextEditingController(text: cur['phone']?.toString() ?? '');
    String role = cur['role']?.toString() ?? _contactRoles.first;
    bool saveToBook = index == null;
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(index == null ? "연락처 추가" : "연락처 수정"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    final picked = await _pickFromBook();
                    if (picked != null) {
                      setD(() {
                        name.text = picked['name']?.toString() ?? '';
                        phone.text = picked['phone']?.toString() ?? '';
                        role = picked['role']?.toString() ?? role;
                        saveToBook = false;
                      });
                    }
                  },
                  icon: const Icon(Icons.menu_book_outlined, size: 18),
                  label: const Text("주소록에서 선택"),
                ),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: "이름 / 업체명"),
                ),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: "전화번호"),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final r in _contactRoles)
                      ChoiceChip(
                        label: Text(r),
                        selected: role == r,
                        onSelected: (_) => setD(() => role = r),
                      ),
                  ],
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: saveToBook,
                  onChanged: (v) => setD(() => saveToBook = v == true),
                  title: const Text(
                    "주소록에도 저장 (다른 프로젝트에서 재사용)",
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (index != null)
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'delete'),
                child: const Text("삭제", style: TextStyle(color: warningRed)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("취소"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'save'),
              child: const Text("저장"),
            ),
          ],
        ),
      ),
    );
    if (action == null) return;
    if (action == 'delete' && index != null) {
      list.removeAt(index);
    } else if (action == 'save') {
      if (name.text.trim().isEmpty && phone.text.trim().isEmpty) return;
      final item = {
        'name': name.text.trim(),
        'phone': phone.text.trim(),
        'role': role,
      };
      if (saveToBook) saveAddress(item);
      if (index == null) {
        list.add(item);
      } else {
        list[index] = item;
      }
    }
    log['contacts'] = list;
    _changed();
  }

  Future<Map<String, dynamic>?> _pickFromBook() async {
    var book = await loadAddressBook();
    if (!mounted) return null;
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: pureWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setB) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.6,
            ),
            child: book.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(30),
                    child: Text(
                      "주소록이 비어 있어요. 연락처를 저장할 때 '주소록에도 저장'을 체크하세요.",
                      style: TextStyle(color: tossSubText),
                    ),
                  )
                : ListView(
                    shrinkWrap: true,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
                        child: Text(
                          "주소록 (길게 누르면 삭제)",
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      for (final e in book)
                        ListTile(
                          title: Text("${e['name']}  ·  ${e['role']}"),
                          subtitle: Text(e['phone']?.toString() ?? ''),
                          onTap: () => Navigator.pop(ctx, e),
                          onLongPress: () async {
                            await removeAddress(e);
                            final nb = await loadAddressBook();
                            setB(() => book = nb);
                          },
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactsSection() {
    final list = _contacts;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.contacts_outlined, size: 18, color: tossBlue),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  "연락처",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: tossText,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _editContact(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text("추가"),
              ),
            ],
          ),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 6, right: 8),
              child: Text(
                "현장 담당자, 협력사, 자재 업체 연락처를 적어 두면 바로 전화·문자할 수 있어요.",
                style: TextStyle(color: tossSubText, fontSize: 12, height: 1.4),
              ),
            ),
          for (int i = 0; i < list.length; i++)
            InkWell(
              onLongPress: () => _editContact(index: i),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${list[i]['name']}  ·  ${list[i]['role']}",
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: tossText,
                              fontSize: 14,
                            ),
                          ),
                          if ((list[i]['phone']?.toString() ?? '').isNotEmpty)
                            Text(
                              list[i]['phone'].toString(),
                              style: const TextStyle(
                                color: tossSubText,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if ((list[i]['phone']?.toString() ?? '').isNotEmpty) ...[
                      IconButton(
                        tooltip: "전화",
                        icon: const Icon(
                          Icons.call_rounded,
                          color: Colors.green,
                        ),
                        onPressed: () => _call(list[i]['phone'].toString()),
                      ),
                      IconButton(
                        tooltip: "문자",
                        icon: const Icon(Icons.sms_outlined, color: tossBlue),
                        onPressed: () =>
                            _call(list[i]['phone'].toString(), sms: true),
                      ),
                    ],
                    IconButton(
                      tooltip: "수정",
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: tossSubText,
                      ),
                      onPressed: () => _editContact(index: i),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ───────────────────────── 공사 유형 ─────────────────────────
  Widget _buildTypeRow() {
    final t = log['workType']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ActionChip(
          avatar: const Icon(
            Icons.category_outlined,
            size: 16,
            color: tossBlue,
          ),
          label: Text(t.isEmpty ? "공사 유형 지정" : "공사 유형: $t"),
          backgroundColor: pureWhite,
          side: BorderSide.none,
          labelStyle: const TextStyle(
            color: tossBlue,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
          onPressed: _pickType,
        ),
      ),
    );
  }

  Future<void> _pickType() async {
    final ctrl = TextEditingController();
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: pureWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "공사 유형",
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in kProjectTypes)
                  ActionChip(
                    label: Text(t),
                    onPressed: () => Navigator.pop(ctx, t),
                  ),
                ActionChip(
                  label: const Text("지정 안 함"),
                  onPressed: () => Navigator.pop(ctx, ''),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              decoration: InputDecoration(
                hintText: "직접 입력 (예: 반도체 라인 이설)",
                suffixIcon: IconButton(
                  icon: const Icon(Icons.check_rounded),
                  onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                ),
              ),
              onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
            ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    if (picked.isEmpty) {
      log.remove('workType');
    } else {
      log['workType'] = picked;
    }
    _changed();
  }

  // ───────────────────────── 완료 회고 ─────────────────────────
  Map<String, dynamic> get _retro =>
      Map<String, dynamic>.from((log['retro'] as Map?) ?? {});

  Future<void> _editRetro() async {
    final r = _retro;
    final cause = TextEditingController(text: r['cause']?.toString() ?? '');
    final lesson = TextEditingController(text: r['lesson']?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("프로젝트 회고"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: cause,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "지연/문제 원인",
                  hintText: "예: 자재 입고가 2주 늦어짐",
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: lesson,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "다음에 참고할 점",
                  hintText: "예: 자재는 착수 전에 미리 발주",
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("저장"),
          ),
        ],
      ),
    );
    if (ok == true) {
      log['retro'] = {
        'cause': cause.text.trim(),
        'lesson': lesson.text.trim(),
        'updatedAt': DateTime.now(),
      };
      _changed();
    }
  }

  List<Widget> _buildRetroSection() {
    if (_isActive) return [];
    final ps = projectStart(log), pd = projectDue(log);
    final dates = [
      for (final r in (log['daily_reports'] as List? ?? []).whereType<Map>())
        reportDateOf(r),
    ]..sort();
    final actualStart = dates.isNotEmpty ? dates.first : null;
    final actualEnd = log['completedAt'] != null
        ? dayOnly(asDate(log['completedAt']))
        : (dates.isNotEmpty ? dates.last : null);
    final planned = (ps != null && pd != null)
        ? pd.difference(ps).inDays + 1
        : null;
    final actual = (actualStart != null && actualEnd != null)
        ? actualEnd.difference(actualStart).inDays + 1
        : null;
    final r = _retro;
    final cause = r['cause']?.toString() ?? '';
    final lesson = r['lesson']?.toString() ?? '';

    Widget line(String label, String value, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(color: tossSubText, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: color ?? tossText,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );

    final diff = (planned != null && actual != null) ? actual - planned : null;
    final phaseLines = <Widget>[];
    for (final p in phasesOf(log)) {
      final s = phaseStart(p), e = phaseEnd(p);
      final st = phaseWorkStats(log, p['id'].toString());
      if (s == null || e == null) continue;
      final plannedDays = e.difference(s).inDays + 1;
      phaseLines.add(
        line(
          p['name'].toString(),
          "계획 ${plannedDays}일 → 작업 ${st.days}일 (${st.manDays}인·일)",
        ),
      );
    }

    return [
      Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: pureWhite,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.flag_circle_outlined,
                  color: tossBlue,
                  size: 20,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    "프로젝트 회고",
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: tossText,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _editRetro,
                  child: Text(cause.isEmpty && lesson.isEmpty ? "작성" : "수정"),
                ),
              ],
            ),
            if (planned != null) line("계획 기간", "$planned일"),
            if (actual != null) line("실제 기간", "$actual일"),
            if (diff != null)
              line(
                "차이",
                diff == 0
                    ? "계획대로 완료"
                    : diff > 0
                    ? "$diff일 지연"
                    : "${-diff}일 단축",
                color: diff > 0 ? warningRed : Colors.green.shade700,
              ),
            if (phaseLines.isNotEmpty) ...[
              const Divider(height: 20),
              ...phaseLines,
            ],
            if (cause.isNotEmpty) ...[
              const Divider(height: 20),
              const Text(
                "지연/문제 원인",
                style: TextStyle(color: tossSubText, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(cause, style: const TextStyle(color: tossText, height: 1.4)),
            ],
            if (lesson.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                "다음에 참고할 점",
                style: TextStyle(color: tossSubText, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                lesson,
                style: const TextStyle(color: tossText, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    ];
  }

  // ───────────────────────── 지연 경고 ─────────────────────────
  List<Widget> _buildDelayBanner() {
    final d = delayedPhase(log);
    if (d == null) return [];
    final after = phasesOf(log).length - d.index - 1;
    return [
      Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: warningRed.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: warningRed.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: warningRed,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "'${d.phase['name']}' 단계가 ${d.days}일 지연되고 있어요",
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: warningRed,
                    ),
                  ),
                ),
              ],
            ),
            if (after > 0) ...[
              const SizedBox(height: 6),
              Text(
                "뒤 단계 $after개의 일정도 그만큼 밀릴 수 있습니다.",
                style: const TextStyle(fontSize: 12, color: tossSubText),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _confirmShift(d.index, d.days),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: warningRed,
                    side: const BorderSide(color: warningRed),
                  ),
                  child: Text("지연 반영: 뒤 단계 ${d.days}일 밀기"),
                ),
              ),
            ],
          ],
        ),
      ),
    ];
  }

  Future<void> _confirmShift(int index, int days) async {
    bool withSchedules = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text("뒤 단계 일정 밀기"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("지연된 단계의 종료일을 오늘로 늘리고, 뒤 단계의 시작/종료일을 $days일씩 미룹니다."),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: withSchedules,
                onChanged: (v) => setD(() => withSchedules = v == true),
                title: const Text(
                  "뒤 단계의 미완료 세부 일정도 함께 밀기 (알림도 새 날짜로 다시 보내요)",
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("취소"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("밀기"),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      shiftPhasesAfterDelay(log, index, days, includeSchedules: withSchedules);
      _changed();
    }
  }

  // ───────────────────────── 기간 보고서 ─────────────────────────
  void _showReportExport() {
    int mode = 0; // 0=최근 7일 1=최근 14일 2=이번 달 3=전체
    bool withPhotos = ReportStyle.current.defaultPhotos;
    showModalBottomSheet(
      context: context,
      backgroundColor: pureWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          ReportDoc build() {
            final now = dayOnly(DateTime.now());
            final from = switch (mode) {
              0 => now.subtract(const Duration(days: 6)),
              1 => now.subtract(const Duration(days: 13)),
              2 => DateTime(now.year, now.month, 1),
              _ => DateTime(2000),
            };
            return buildReportDoc(log, from, now);
          }

          const labels = ['최근 7일', '최근 14일', '이번 달', '전체'];
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "작업 보고서 내보내기",
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (int i = 0; i < labels.length; i++)
                        ChoiceChip(
                          label: Text(labels[i]),
                          selected: mode == i,
                          onSelected: (_) => setS(() => mode = i),
                        ),
                    ],
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: withPhotos,
                    onChanged: (v) => setS(() => withPhotos = v == true),
                    title: const Text(
                      "PDF에 사진 포함 (최대 24장, 만드는 데 시간이 걸려요)",
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await shareReportText(build());
                          },
                          icon: const Icon(Icons.chat_outlined, size: 18),
                          label: const Text("텍스트(카톡)"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            try {
                              await shareReportPdf(
                                build(),
                                withPhotos: withPhotos,
                              );
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("PDF 생성 실패: $e")),
                                );
                              }
                            }
                          },
                          icon: const Icon(
                            Icons.picture_as_pdf_outlined,
                            size: 18,
                          ),
                          label: const Text("PDF"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ───────────────────────── 자재 현황 ─────────────────────────
  List<Widget> _buildMaterialCard() {
    final mats = schedulesOf(log).where(isMaterialSchedule).toList();
    if (mats.isEmpty) return [];
    final counts = {'pending': 0, 'expected': 0, 'late': 0, 'done': 0};
    for (final m in mats) {
      counts[materialState(m)] = counts[materialState(m)]! + 1;
    }
    final open = mats.where((m) => materialState(m) != 'done').toList()
      ..sort((a, b) {
        int rank(Map m) => switch (materialState(m)) {
          'late' => 0,
          'pending' => 1,
          _ => 2,
        };
        final r = rank(a).compareTo(rank(b));
        if (r != 0) return r;
        if (a['dateTime'] == null || b['dateTime'] == null) return 0;
        return asDate(a['dateTime']).compareTo(asDate(b['dateTime']));
      });
    Widget stat(String label, String key, Color c) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: c.withValues(alpha: counts[key]! > 0 ? 0.12 : 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              "${counts[key]}",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: counts[key]! > 0 ? c : tossSubText,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: counts[key]! > 0 ? c : tossSubText,
              ),
            ),
          ],
        ),
      ),
    );
    return [
      _sectionTitle("자재 현황"),
      const SizedBox(height: 10),
      Row(
        children: [
          stat("입고일 미정", 'pending', const Color(0xFFC77700)),
          const SizedBox(width: 8),
          stat("입고 예정", 'expected', tossBlue),
          const SizedBox(width: 8),
          stat("입고 지연", 'late', warningRed),
          const SizedBox(width: 8),
          stat("입고 완료", 'done', Colors.green),
        ],
      ),
      const SizedBox(height: 6),
      ...(() {
        final used = mats
            .where(
              (m) => materialUsageCount(log, m['id']?.toString() ?? '') > 0,
            )
            .toList();
        if (used.isEmpty) return <Widget>[];
        return <Widget>[
          const SizedBox(height: 10),
          const Text(
            "일보에서 사용 기록",
            style: TextStyle(
              color: tossSubText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          for (final m in used.take(6))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                "• ${m['title'] ?? m['type']} · ${materialUsageCount(log, m['id'].toString())}일 사용",
                style: const TextStyle(color: tossText, fontSize: 13),
              ),
            ),
          const SizedBox(height: 6),
        ];
      })(),
      ...(() {
        final unused = unusedReceivedMaterials(log);
        if (unused.isEmpty) return <Widget>[];
        return <Widget>[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFC77700).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "입고됐지만 사용 기록이 없어요",
                  style: TextStyle(
                    color: Color(0xFFC77700),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                for (final m in unused.take(4))
                  Text(
                    "• ${m['title'] ?? m['type']}",
                    style: const TextStyle(color: tossText, fontSize: 13),
                  ),
                if (unused.length > 4)
                  Text(
                    "외 ${unused.length - 4}건",
                    style: const TextStyle(color: tossSubText, fontSize: 12),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ];
      })(),
      ...(() {
        final vs = _contacts
            .where(
              (c) =>
                  c['role'] == '자재 업체' &&
                  (c['phone']?.toString() ?? '').isNotEmpty,
            )
            .toList();
        if (vs.isEmpty) return <Widget>[];
        return <Widget>[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final v in vs)
                ActionChip(
                  avatar: const Icon(Icons.call_rounded, size: 14),
                  label: Text("${v['name']}에 전화"),
                  backgroundColor: pureWhite,
                  onPressed: () => _call(v['phone'].toString()),
                ),
            ],
          ),
        ];
      })(),
      ...open.take(5).map(_scheduleRow),
      if (open.length > 5)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => _tab.animateTo(1),
            child: Text("나머지 ${open.length - 5}건 더 보기"),
          ),
        ),
      const SizedBox(height: 22),
    ];
  }

  String _workStatText(String phaseId) {
    final st = phaseWorkStats(log, phaseId);
    if (st.days == 0) return "";
    return "  ·  투입 ${st.days}일 (${st.manDays}인·일)";
  }

  // ───────────────────────── 일보 선택 내보내기 ─────────────────────────
  bool _selectMode = false;
  final Set<Map> _sel = {};

  // 일보 확정: 확정한 일보는 수정하려면 사유를 남기고 확정을 풀어야 한다.
  Future<void> _lockReports(List<Map> reps) async {
    final targets = reps.where((r) => r['locked'] != true).toList();
    if (targets.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("확정할 일보가 없어요.")));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("일보 확정"),
        content: Text(
          "일보 ${targets.length}건을 확정본으로 잠글까요?\n확정 후 수정하려면 사유를 남기고 확정을 풀어야 해요(이력이 남아요).",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("확정"),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final now = DateTime.now();
    for (final r in targets) {
      r['locked'] = true;
      r['lockedAt'] = now;
    }
    setState(() {
      _selectMode = false;
      _sel.clear();
    });
    _changed();
  }

  Future<void> _exportSelected() async {
    if (_sel.isEmpty) return;
    final doc = buildReportDoc(
      log,
      DateTime(2000),
      DateTime.now().add(const Duration(days: 1)),
      only: _sel.toList(),
    );
    final fmt = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: pureWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat_outlined),
              title: const Text("텍스트로 공유 (카톡)"),
              onTap: () => Navigator.pop(ctx, 'text'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text("PDF로 공유"),
              onTap: () => Navigator.pop(ctx, 'pdf'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text("PDF로 공유 (사진 포함)"),
              onTap: () => Navigator.pop(ctx, 'pdfp'),
            ),
          ],
        ),
      ),
    );
    try {
      if (fmt == 'text') await shareReportText(doc);
      if (fmt == 'pdf') await shareReportPdf(doc);
      if (fmt == 'pdfp') await shareReportPdf(doc, withPhotos: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("내보내기 실패: $e")));
      }
    }
  }

  // ───────────────────────── 일지 타임라인 ─────────────────────────
  // 날짜는 "MM/dd" 문자열이라 월 단위로 묶어 헤더를 붙이고, 카드마다 요약 한 줄,
  // 사진 썸네일, 단계/이슈/일정완료 칩을 보여준다.
  List<Widget> _buildReportTimeline(List reports) {
    final phaseNames = {
      for (final p in phasesOf(log)) p['id'].toString(): p['name'].toString(),
    };
    final out = <Widget>[];
    String? lastMonth;
    for (final r in reports) {
      if (r is! Map) continue;
      final date = r['date']?.toString() ?? '';
      final rd = reportDateOf(r);
      final month = date.contains('/')
          ? "${rd.year == DateTime.now().year ? '' : '${rd.year}년 '}${rd.month}월"
          : '';
      if (month != lastMonth) {
        lastMonth = month;
        out.add(
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 8),
            child: Text(
              month,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: tossSubText,
              ),
            ),
          ),
        );
      }
      final card = _reportCard(r, phaseNames);
      out.add(
        _selectMode
            ? Row(
                children: [
                  Checkbox(
                    value: _sel.contains(r),
                    activeColor: tossBlue,
                    onChanged: (_) => setState(() {
                      _sel.contains(r) ? _sel.remove(r) : _sel.add(r);
                    }),
                  ),
                  Expanded(child: card),
                ],
              )
            : card,
      );
    }
    return out;
  }

  Widget _reportCard(Map r, Map<String, String> phaseNames) {
    final note = (r['note']?.toString() ?? '').trim();
    final summary = (note.isEmpty || note == '특이사항 없음')
        ? (r['materials_used']?.toString().isNotEmpty == true
              ? "자재: ${r['materials_used']}"
              : "특이사항 없음")
        : note.split('\n').first;
    final types = (r['work_type'] is List)
        ? (r['work_type'] as List).join(' · ')
        : (r['work_type']?.toString() ?? '');
    final phaseChips = reportIds(
      r,
      'workedPhaseIds',
    ).map((id) => phaseNames[id]).whereType<String>().toList();
    final imgTags = Map<String, dynamic>.from((r['image_tags'] as Map?) ?? {});
    final imgs = (r['image_paths'] as List? ?? [])
        .map((e) => e.toString())
        .toList();
    final issueCnt = reportIds(r, 'linkedIssueIds').length;
    final doneCnt = reportIds(r, 'completedScheduleIds').length;
    final pt = (r['points'] as num?)?.toInt() ?? 0;
    final wp = (r['wiring_points'] as num?)?.toInt() ?? 0;

    Widget chip(String t, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        t,
        style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (_selectMode) {
            setState(() {
              _sel.contains(r) ? _sel.remove(r) : _sel.add(r);
            });
          } else {
            _run(() => widget.actions.openReport(r as Map<String, dynamic>));
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    "${r['date'] ?? ''}",
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: tossText,
                    ),
                  ),
                  if (r['locked'] == true)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.lock_rounded,
                        size: 14,
                        color: tossSubText,
                      ),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "$types · ${r['worker_count'] ?? 1}명${r['is_overtime'] == true ? ' · 연장' : ''}",
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: tossSubText),
                    ),
                  ),
                  if (pt > 0 || wp > 0)
                    Text(
                      [if (pt > 0) "${pt}pt", if (wp > 0) "결선 $wp"].join(' · '),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: tossBlue,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: tossText,
                  height: 1.4,
                ),
              ),
              if (phaseChips.isNotEmpty ||
                  issueCnt > 0 ||
                  doneCnt > 0 ||
                  r['is_as_built'] == true) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final n in phaseChips) chip(n, tossBlue),
                    if (issueCnt > 0) chip("이슈 처리 $issueCnt", warningRed),
                    if (doneCnt > 0) chip("일정 완료 $doneCnt", Colors.green),
                    if (r['is_as_built'] == true)
                      chip("도면 반영 요청", const Color(0xFFC77700)),
                  ],
                ),
              ],
              if (imgs.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 56,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: imgs.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (_, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        children: [
                          PhotoImage(imgs[i], width: 56, height: 56),
                          if (imgTags[imgs[i]] != null)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: Container(
                                color: Colors.black54,
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 1,
                                ),
                                child: Text(
                                  imgTags[imgs[i]].toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
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
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showReportExport,
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: const Text("보고서 내보내기"),
                style: OutlinedButton.styleFrom(foregroundColor: tossText),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProjectPhotosPage(log: log),
                  ),
                ),
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text("사진 모아보기"),
                style: OutlinedButton.styleFrom(foregroundColor: tossText),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (reports.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: _selectMode
                ? Row(
                    children: [
                      TextButton(
                        onPressed: () => setState(() {
                          _selectMode = false;
                          _sel.clear();
                        }),
                        child: const Text("취소"),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          _sel
                            ..clear()
                            ..addAll(reports.whereType<Map>());
                        }),
                        child: const Text("전체 선택"),
                      ),
                      TextButton(
                        onPressed: _sel.isEmpty
                            ? null
                            : () => _lockReports(_sel.toList()),
                        child: const Text("확정"),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: _sel.isEmpty ? null : _exportSelected,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tossBlue,
                        ),
                        child: Text(
                          "${_sel.length}건 내보내기",
                          style: const TextStyle(color: pureWhite),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => setState(() => _selectMode = true),
                        icon: const Icon(Icons.checklist_rounded, size: 18),
                        label: const Text("골라서 내보내기/확정"),
                        style: TextButton.styleFrom(
                          foregroundColor: tossSubText,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            _lockReports(reports.whereType<Map>().toList()),
                        icon: const Icon(Icons.lock_outline_rounded, size: 18),
                        label: const Text("전부 확정"),
                        style: TextButton.styleFrom(
                          foregroundColor: tossSubText,
                        ),
                      ),
                    ],
                  ),
          ),
        const SizedBox(height: 10),
        if (reports.isEmpty)
          _emptyText("작성된 일지가 없습니다.")
        else
          ..._buildReportTimeline(reports),
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
        actions: [
          PopupMenuButton<String>(
            tooltip: "더보기",
            onSelected: (v) {
              if (v == 'optimize') _optimizePhotos();
              if (v == 'summary') _shareSummaryImage();
              if (v == 'header') _editReportHeader();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'summary', child: Text("현황 요약 이미지 공유")),
              PopupMenuItem(value: 'header', child: Text("이 프로젝트 보고서 머리말")),
              PopupMenuItem(value: 'optimize', child: Text("사진 용량 정리")),
            ],
          ),
          IconButton(
            tooltip: "투입 통계",
            icon: const Icon(Icons.bar_chart_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProjectStatsPage(
                  logs: [log],
                  title: "${log['name'] ?? '프로젝트'} 통계",
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tab.animation!,
        builder: (context, _) {
          final i = _tab.index;
          if (i == 0 || !_isActive) return const SizedBox.shrink();
          final (label, icon, action) = switch (i) {
            1 => (
              "일정 추가",
              Icons.add_task_rounded,
              () => _run(() => widget.actions.openSchedule(add: true)),
            ),
            2 => (
              "이슈 등록",
              Icons.error_outline_rounded,
              () => _run(widget.actions.addPunch),
            ),
            _ => (
              "일지 작성",
              Icons.edit_document,
              () => _run(widget.actions.addReport),
            ),
          };
          return FloatingActionButton.extended(
            onPressed: action,
            backgroundColor: tossBlue,
            foregroundColor: pureWhite,
            icon: Icon(icon),
            label: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          );
        },
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
