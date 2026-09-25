import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'dart:async' show FutureOr;
import '../widgets/korean_text.dart';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/repositories/work_project_repository.dart';
import '../models/photo_store.dart';
import '../models/project_phase.dart';
import '../models/report_style.dart';
import '../models/report_tools.dart';
import '../screens/work_log_main_screen.dart';
import '../widgets/work_theme.dart';
import '../models/weekly_plan.dart';

const Color _teal = AppColors.brand;
const Color _text = AppColors.text;
const Color _sub = AppColors.textSub;
const Color _bg = AppColors.background;

// 알림을 눌렀을 때: 프로젝트를 불러와 주간 업무 보고 화면을 바로 연다.
Future<void> openWeeklyReportFromNotification(
  NavigatorState nav, {
  bool autoPdf = false,
}) async {
  try {
    await loadReportStyle(); // 알림으로 바로 열면 양식(로고·담당자)이 아직 안 읽혔을 수 있다.
    final logs = await WorkProjectRepository().fetchAllProjects();
    final repo = WorkProjectRepository();
    nav.push(
      WorkRoute(
        builder: (_) => WeeklyReportPage(
          logs: logs,
          // 밀어서 제외/다시 포함한 결과를 저장한다.
          onIssueChanged: (log) => repo.upsertProject(log),
          // 프로젝트 이름 옆 아이콘: 그 프로젝트 화면(개요 탭)을 연다.
          onOpenProject: (log) => nav.push(
            WorkRoute(
              builder: (_) => WorkLogMainScreen(
                initialProjectId: log['id']?.toString(),
                initialTab: 0,
              ),
            ),
          ),
          // 다녀온 뒤 최신 상태로 다시 읽는다.
          reload: () => repo.fetchAllProjects(),
        ),
      ),
    );
    // 설정에서 켠 경우: 화면을 열자마자 PDF를 만들어 공유창까지 연다.
    if (autoPdf) await shareReportPdf(buildWeeklyPlanDoc(logs));
  } catch (_) {}
}

// 🚀 [주간 업무 보고] 전주 실적 · 금주 진행/예정 · 차주 계획을 한 번에 정리해
// 미리 보고, 텍스트(카톡)나 PDF로 공유한다.
class WeeklyReportPage extends StatefulWidget {
  final List<Map<String, dynamic>> logs;
  // 있으면 "■ 프로젝트" 줄을 눌러 그 프로젝트 화면으로 이동할 수 있다.
  final FutureOr<void> Function(Map<String, dynamic> log)? onOpenProject;
  // 있으면 미해결 이슈 줄을 눌러 이슈 상세로 이동할 수 있다.
  final FutureOr<void> Function(Map<String, dynamic> log, Map punch)?
  onOpenIssue;
  // 이슈 줄을 밀어서 "주간 제외"했을 때 저장하라고 알리는 콜백(없으면 밀기 비활성).
  final void Function(Map<String, dynamic> log)? onIssueChanged;
  // 프로젝트/이슈 화면에 다녀온 뒤 최신 프로젝트 목록을 다시 읽어 오는 함수(선택).
  // 알림으로 연 화면처럼 목록 사본을 직접 들고 있을 때 쓴다.
  final Future<List<Map<String, dynamic>>> Function()? reload;
  const WeeklyReportPage({
    super.key,
    required this.logs,
    this.onOpenProject,
    this.onOpenIssue,
    this.onIssueChanged,
    this.reload,
  });

  @override
  State<WeeklyReportPage> createState() => _WeeklyReportPageState();
}

class _WeeklyReportPageState extends State<WeeklyReportPage> {
  String? _projectId; // null = 진행중 전체
  bool _photos = false;
  bool _split = false;
  DateTime? _asOf; // null = 오늘
  int _overviewSort = 0; // 0=기본 1=진행률 낮은 순 2=납기 빠른 순
  static const _overviewSortLabels = ['기본 순', '진행률 낮은 순', '납기 빠른 순'];
  // 접어 둔 "섹션|프로젝트" 키(프로젝트가 많을 때 화면을 짧게 보려고).
  final Set<String> _collapsed = {};
  late List<Map<String, dynamic>> _logs = widget.logs;

  Future<void> _reloadLogs() async {
    if (widget.reload == null) return;
    try {
      final fresh = await widget.reload!();
      if (mounted) setState(() => _logs = fresh);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _loadCollapsed();
    _loadSort();
  }

  // 진행률 카드 정렬은 다음에 열어도 그대로 유지한다.
  static const _kSortPref = 'weekly_overview_sort';

  Future<void> _loadSort() async {
    try {
      final p = await SharedPreferences.getInstance();
      final v = p.getInt(_kSortPref);
      if (v != null && v >= 0 && v < 3 && mounted) {
        setState(() => _overviewSort = v);
      }
    } catch (_) {}
  }

  Future<void> _saveSort() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(_kSortPref, _overviewSort);
    } catch (_) {}
  }

  // 접힘 상태는 앱을 다시 열어도 유지한다. 키에서 날짜 범위를 빼서 주가 바뀌어도 이어진다.
  static const _kCollapsedPref = 'weekly_report_collapsed';

  // 접힘은 프로젝트 이름 기준(어느 섹션에서 접든 같은 프로젝트는 함께 접힌다).
  String _ck(String heading, String name) => name;

  Future<void> _loadCollapsed() async {
    try {
      final p = await SharedPreferences.getInstance();
      final saved = p.getStringList(_kCollapsedPref);
      // 예전 형식("섹션|프로젝트")으로 저장된 값은 프로젝트 이름만 뽑아 이어 쓴다.
      if (saved != null && mounted) {
        setState(() => _collapsed.addAll(saved.map((k) => k.split('|').last)));
      }
    } catch (_) {}
  }

  Future<void> _persistCollapsed() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_kCollapsedPref, _collapsed.toList());
    } catch (_) {}
  }

  List<Map<String, dynamic>> get _active =>
      _logs.where((l) => l['status'] != 'DONE').toList();

  ReportDoc get _doc => buildWeeklyPlanDoc(
    _logs,
    onlyIds: _projectId == null ? null : {_projectId!},
    includePhotos: _photos,
    perProject: _split && _projectId == null,
    asOf: _asOf,
  );

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _asOf ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: "기준일을 선택하면 그 날이 속한 주가 '금주'가 됩니다",
    );
    if (picked != null) {
      setState(() {
        final d = DateTime(picked.year, picked.month, picked.day);
        _asOf = d == DateTime(now.year, now.month, now.day) ? null : d;
      });
    }
  }

  // "■ 프로젝트 이름 — ..." 줄이면 해당 프로젝트를 찾는다(이동 기능이 켜졌을 때만).
  Map<String, dynamic>? _projectFor(String line) {
    if (widget.onOpenProject == null || !line.startsWith('■ ')) return null;
    final name = line.substring(2).split(' — ').first.split(' · ').first.trim();
    for (final l in _logs) {
      if (l['name']?.toString() == name) return l;
    }
    return null;
  }

  // "■ 프로젝트 이름 …" 줄이면 프로젝트 이름(실제 프로젝트일 때만).
  String? _projectName(String line) {
    if (!line.startsWith('■ ')) return null;
    final name = line.substring(2).split(' — ').first.split(' · ').first.trim();
    return _logs.any((l) => l['name']?.toString() == name) ? name : null;
  }

  // 접힌 프로젝트 줄 옆에 보여 줄 한 줄 요약: 진행률 줄이 있으면 그것, 없으면 줄 수.
  String _collapsedSummary(ReportSection s, int i) {
    var hidden = 0;
    String? progress;
    for (var j = i + 1; j < s.lines.length; j++) {
      if (s.lines[j].startsWith('■ ')) break;
      hidden++;
      final t = s.lines[j].trim();
      if (progress == null && t.startsWith('◐')) {
        progress = t.substring(1).trim();
      }
    }
    return progress ?? '$hidden줄';
  }

  // 접힌 프로젝트의 하위 줄은 건너뛰고, 보여 줄 줄 번호만 돌려준다.
  Iterable<int> _visibleLines(ReportSection s) sync* {
    var hide = false;
    for (var i = 0; i < s.lines.length; i++) {
      final name = _projectName(s.lines[i]);
      if (name != null) {
        hide = _collapsed.contains(_ck(s.heading, name));
        yield i;
      } else if (s.lines[i].startsWith('■ ')) {
        hide = false;
        yield i;
      } else if (!hide) {
        yield i;
      }
    }
  }

  Widget _lineWidget(ReportSection s, int i) {
    final l = s.lines[i];
    // 이슈 줄: 눌러서 상세로 가는 기능(onOpenIssue)과 밀어서 제외하는 기능
    // (onIssueChanged)은 서로 독립이다. 알림으로 연 화면은 후자만 가진다.
    if (s.issueRefs?[i] != null &&
        (widget.onOpenIssue != null || widget.onIssueChanged != null)) {
      final ref = s.issueRefs![i]!;
      final canOpen = widget.onOpenIssue != null;
      final row = InkWell(
        onTap: !canOpen
            ? null
            : () async {
                await widget.onOpenIssue!(
                  s.issueRefs![i]!.log,
                  s.issueRefs![i]!.punch,
                );
                // 이슈를 고치고 돌아왔을 수 있으니 다시 계산한다.
                await _reloadLogs();
                if (mounted) setState(() {});
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: _sub,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (canOpen)
                const Icon(Icons.chevron_right_rounded, size: 18, color: _sub),
            ],
          ),
        ),
      );
      if (widget.onIssueChanged == null) return row;
      // 오른쪽에서 왼쪽으로 밀면 이 이슈를 주간 보고에서 바로 제외한다.
      return Dismissible(
        key: ValueKey('issue-${identityHashCode(ref.punch)}'),
        direction: DismissDirection.endToStart,
        background: Container(
          color: AppColors.danger.withValues(alpha: 0.12),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 16),
          child: const Text(
            "주간 제외",
            style: TextStyle(
              color: AppColors.danger,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
        onDismissed: (_) {
          setIssueWeeklyExcluded(ref.punch, true);
          widget.onIssueChanged!(ref.log);
          setState(() {});
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(keepWords("이 이슈를 주간 보고에서 뺐습니다.")),
                persist: false,
                action: SnackBarAction(
                  label: "되돌리기",
                  onPressed: () {
                    setIssueWeeklyExcluded(ref.punch, false);
                    widget.onIssueChanged!(ref.log);
                    if (mounted) setState(() {});
                  },
                ),
              ),
            );
        },
        child: row,
      );
    }
    // 금주 요약의 "✓ 금주 완료 · 프로젝트" 줄: 눌러서 완료된 프로젝트 화면으로.
    final doneRef = s.projectRefs?[i];
    if (doneRef != null && widget.onOpenProject != null) {
      return InkWell(
        onTap: () async {
          await widget.onOpenProject!(doneRef);
          await _reloadLogs();
          if (mounted) setState(() {});
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: _sub,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 18, color: _sub),
            ],
          ),
        ),
      );
    }
    final name = _projectName(l);
    if (name != null) {
      final key = _ck(s.heading, name);
      final closed = _collapsed.contains(key);
      final log = _projectFor(l);
      return Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  closed ? _collapsed.remove(key) : _collapsed.add(key);
                });
                _persistCollapsed();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      closed
                          ? Icons.chevron_right_rounded
                          : Icons.expand_more_rounded,
                      size: 18,
                      color: _sub,
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        closed ? '$l  ·  ${_collapsedSummary(s, i)}' : l,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: _text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (log != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              tooltip: "프로젝트 열기",
              icon: const Icon(Icons.open_in_new_rounded, color: _sub),
              onPressed: () async {
                await widget.onOpenProject!(log);
                await _reloadLogs();
                if (mounted) setState(() {});
              },
            ),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        l,
        style: TextStyle(
          fontSize: 13,
          height: 1.4,
          color: l.startsWith('■') ? _text : _sub,
          fontWeight: l.startsWith('■') ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
    );
  }

  // 접을 수 있는 "섹션|프로젝트" 키 전체.
  Set<String> _allProjectKeys(ReportDoc doc) => {
    for (final s in doc.sections)
      for (final l in s.lines)
        if (_projectName(l) != null) _ck(s.heading, _projectName(l)!),
  };

  // 맨 위 "이번 주 한눈에": 진행중 프로젝트의 진행률 막대와 전주 대비 변화.
  // 진행률은 현재 값이라 과거 기준일을 볼 때는 보여 주지 않는다.
  Widget _overviewCard() {
    if (_asOf != null) return const SizedBox.shrink();
    final list = _active
        .where((l) => _projectId == null || l['id']?.toString() == _projectId)
        .toList();
    if (list.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "이번 주 한눈에",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: _teal,
                  ),
                ),
              ),
              if (list.length > 1)
                TextButton.icon(
                  onPressed: () {
                    setState(() => _overviewSort = (_overviewSort + 1) % 3);
                    _saveSort();
                  },
                  icon: const Icon(Icons.sort_rounded, size: 16),
                  label: Text(_overviewSortLabels[_overviewSort]),
                  style: TextButton.styleFrom(
                    foregroundColor: _sub,
                    minimumSize: const Size(0, 30),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (final l in sortedForOverview(list, _overviewSort)) ...[
            Builder(
              builder: (_) {
                final p = projectProgress(l);
                final pct = (p * 100).round();
                final d = progressDeltaSince(l, 7);
                final canOpen = widget.onOpenProject != null;
                return InkWell(
                  onTap: !canOpen
                      ? null
                      : () async {
                          await widget.onOpenProject!(l);
                          await _reloadLogs();
                          if (mounted) setState(() {});
                        },
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8, top: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 84,
                          child: Text(
                            l['name']?.toString() ?? '프로젝트',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _text,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: p.clamp(0.0, 1.0),
                              minHeight: 8,
                              backgroundColor: _bg,
                              color: p >= 1 ? Colors.green : _teal,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 34,
                          child: Text(
                            "$pct%",
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: _text,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 52,
                          child: Text(
                            d == null || d == 0
                                ? ''
                                : "${d > 0 ? '+' : ''}$d%p",
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: (d ?? 0) > 0
                                  ? AppColors.ok
                                  : AppColors.danger,
                            ),
                          ),
                        ),
                        if (canOpen)
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: _sub,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  // 현재 보이는 프로젝트들에서 주간 보고에서 뺀 미해결 이슈(원본 참조).
  List<({Map<String, dynamic> log, Map punch})> get _excludedIssues => [
    for (final l in _active)
      if (_projectId == null || l['id']?.toString() == _projectId)
        for (final p in (l['punch_lists'] as List? ?? []).whereType<Map>())
          if (p['is_completed'] != true && issueWeeklyExcluded(p))
            (log: l, punch: p),
  ];

  Widget _excludedCard() {
    final list = _excludedIssues;
    if (widget.onIssueChanged == null || list.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          title: Text(
            keepWords("제외한 이슈 ${list.length}건 보기"),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: _teal,
            ),
          ),
          children: [
            for (final e in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        "${e.log['name'] ?? ''} · ${e.punch['location'] ?? ''} ${e.punch['content'] ?? ''}",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: _sub,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setIssueWeeklyExcluded(e.punch, false);
                        widget.onIssueChanged!(e.log);
                        setState(() {});
                      },
                      child: const Text("다시 포함"),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // PDF를 만드는 중인지(두 번 누르기 막고 "만드는 중"을 보인다).
  bool _pdfBusy = false;

  Future<void> _pdf(ReportDoc doc) async {
    if (_pdfBusy) return;
    setState(() => _pdfBusy = true);
    try {
      await shareReportPdf(doc, withPhotos: _photos);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(keepWords("PDF 생성 실패: $e"))));
      }
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = _doc;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _text,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          "주간 보고",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          if (_active.length > 1)
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
                children: [
                  for (final e in <MapEntry<String?, String>>[
                    const MapEntry(null, '진행중 전체'),
                    for (final l in _active)
                      MapEntry(
                        l['id']?.toString(),
                        l['name']?.toString() ?? '이름 없음',
                      ),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(e.value),
                        selected: _projectId == e.key,
                        showCheckmark: false,
                        selectedColor: _teal,
                        backgroundColor: Colors.white,
                        side: BorderSide.none,
                        labelStyle: TextStyle(
                          color: _projectId == e.key ? Colors.white : _sub,
                          fontWeight: FontWeight.w700,
                        ),
                        onSelected: (_) => setState(() => _projectId = e.key),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _overviewCard(),
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    onTap: _pickDate,
                    leading: const Icon(Icons.event_rounded, color: _teal),
                    title: Text(
                      _asOf == null
                          ? "기준일: 오늘"
                          : "기준일: ${_asOf!.year}.${_asOf!.month}.${_asOf!.day}",
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      keepWords("눌러서 다른 주의 보고서를 볼 수 있습니다"),
                      style: TextStyle(fontSize: 12, color: _sub),
                    ),
                    trailing: _asOf == null
                        ? const Icon(Icons.chevron_right_rounded)
                        : TextButton(
                            onPressed: () => setState(() => _asOf = null),
                            child: const Text("오늘로"),
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10, left: 2),
                  child: Text(
                    "${doc.title} · ${doc.period}",
                    style: const TextStyle(
                      color: _sub,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_active.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            setState(
                              () => _collapsed
                                ..clear()
                                ..addAll(_allProjectKeys(doc)),
                            );
                            _persistCollapsed();
                          },
                          icon: const Icon(Icons.unfold_less_rounded, size: 18),
                          label: const Text("모두 접기"),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setState(_collapsed.clear);
                            _persistCollapsed();
                          },
                          icon: const Icon(Icons.unfold_more_rounded, size: 18),
                          label: const Text("모두 펼치기"),
                        ),
                      ],
                    ),
                  ),
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    activeThumbColor: _teal,
                    title: const Text(
                      "PDF에 작업 사진 넣기",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      _photos
                          ? "전주·금주 작업 일지 사진 ${doc.photos.length}장(최근 12장까지)"
                          : "전주·금주 작업 일지에 붙인 사진",
                      style: const TextStyle(fontSize: 12, color: _sub),
                    ),
                    value: _photos,
                    onChanged: (v) => setState(() => _photos = v),
                  ),
                ),
                if (_projectId == null && _active.length > 1)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      activeThumbColor: _teal,
                      title: const Text(
                        "프로젝트별로 나눠 보기",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        keepWords("PDF에서는 프로젝트마다 새 페이지로 시작합니다"),
                        style: TextStyle(fontSize: 12, color: _sub),
                      ),
                      value: _split,
                      onChanged: (v) => setState(() => _split = v),
                    ),
                  ),
                if (_photos && doc.compares.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "작업 전 / 후",
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: _teal,
                          ),
                        ),
                        for (final c in doc.compares) ...[
                          const SizedBox(height: 10),
                          Text(
                            c.label,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _text,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              for (final (i, path) in [
                                c.before,
                                c.after,
                              ].indexed)
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      left: i == 0 ? 0 : 6,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: AspectRatio(
                                        aspectRatio: 1.4,
                                        child: PhotoImage(path),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                if (_photos && doc.photos.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "사진 미리보기",
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: _teal,
                          ),
                        ),
                        for (final g in <String?>{
                          for (final p in doc.photos) p.group,
                        }) ...[
                          const SizedBox(height: 10),
                          if (g != null)
                            Text(
                              "■ $g",
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: _text,
                              ),
                            ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final p in doc.photos)
                                if (p.group == g)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: PhotoImage(
                                      p.path,
                                      width: 64,
                                      height: 64,
                                    ),
                                  ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                for (final s in doc.sections)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.heading,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: _teal,
                          ),
                        ),
                        // 🚀 [고침] 밀어서 빼는 기능이 있는 줄 알 길이 없었다.
                        if (widget.onIssueChanged != null &&
                            (s.issueRefs?.isNotEmpty ?? false))
                          Padding(
                            key: const Key('weekly_swipe_hint'),
                            padding: const EdgeInsets.only(top: 2, bottom: 4),
                            child: Text(
                              keepWords("이슈를 왼쪽으로 밀면 이번 주 보고에서 뺍니다."),
                              style: const TextStyle(color: _sub, fontSize: 12),
                            ),
                          ),
                        const SizedBox(height: 8),
                        for (final i in _visibleLines(s)) _lineWidget(s, i),
                      ],
                    ),
                  ),
                _excludedCard(),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => shareReportText(doc),
                      icon: const Icon(Icons.chat_outlined, size: 18),
                      label: const Text("텍스트(카톡)"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    // 🚀 [고침] 예전에는 만드는 동안 아무 표시가 없어 여러 번 눌렀다.
                    child: ElevatedButton.icon(
                      key: const Key('weekly_pdf'),
                      onPressed: _pdfBusy ? null : () => _pdf(doc),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _teal,
                        foregroundColor: Colors.white,
                      ),
                      icon: _pdfBusy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                      label: Text(_pdfBusy ? "만드는 중…" : "PDF"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
