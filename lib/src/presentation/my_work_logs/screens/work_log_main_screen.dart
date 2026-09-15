import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // debugPrint 사용을 위해 추가
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

// 🚀 [수정됨] Dialog가 아니라 새로 만든 Page를 임포트합니다.
// 경로가 본인 프로젝트 폴더와 맞는지 꼭 확인해 주세요!
import '../widgets/create_log_sheet.dart';
import '../widgets/work_log_card.dart';
import '../pages/daily_report_page.dart'; // 다이얼로그 대신 Page 임포트
import '../pages/punch_list_page.dart'; // 다이얼로그 대신 Page 임포트
import '../pages/punch_detail_page.dart';
import '../pages/project_schedule_page.dart';
import '../pages/daily_report_calendar_page.dart';
import 'package:tubing_calculator/src/data/repositories/work_project_repository.dart';

// 토스 스타일 색상 팔레트
const Color tossBlue = Color(0xFF007580); // 🚀 마키타 틸로 통일
const Color tossText = Color(0xFF191F28);
const Color tossSubText = Color(0xFF8B95A1);
const Color tossBg = Color(0xFFF2F4F6);
const Color pureWhite = Color(0xFFFFFFFF);

class WorkLogMainScreen extends StatefulWidget {
  const WorkLogMainScreen({super.key});

  @override
  State<WorkLogMainScreen> createState() => _WorkLogMainScreenState();
}

class _WorkLogMainScreenState extends State<WorkLogMainScreen> {
  final WorkProjectRepository _repo = WorkProjectRepository();
  List<Map<String, dynamic>> _workLogs = [];
  int? _expandedIndex;
  bool _isLoading = true;
  // 🚀 [추가] 완료 처리된 프로젝트는 기본적으로 목록/대시보드에서 숨기고
  // "완료됨" 탭을 눌러야 보이게 한다 - 오래 쓸수록 목록이 무한정
  // 길어지는 걸 막기 위함.
  bool _showCompleted = false;

  bool _isActive(Map<String, dynamic> log) => log['status'] != 'DONE';

  List<Map<String, dynamic>> get _activeLogs =>
      _workLogs.where(_isActive).toList();
  List<Map<String, dynamic>> get _doneLogs =>
      _workLogs.where((l) => !_isActive(l)).toList();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final projects = await _repo.fetchAllProjects();
      if (!mounted) return;
      setState(() {
        _workLogs = projects;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("⚠️ 내 프로젝트 불러오기 실패: $e");
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  // 🚀 [수정] 예전엔 리스트 전체를 통째로 Hive에 다시 썼는데, 이제
  // 프로젝트가 Firestore 문서 하나하나로 나뉘어 있어서 "방금 바뀐
  // 프로젝트 하나만" 저장하면 된다.
  void _saveProject(Map<String, dynamic> log) {
    _repo.upsertProject(log);
  }

  void _showCreateSheet() async {
    final newLog = await CreateLogSheet.show(context);
    if (newLog != null) {
      setState(() {
        _workLogs.insert(0, newLog);
      });
      _saveProject(newLog);
    }
  }

  // 🚀 [추가] "일정 관리" 진입 로직을 하나로 모아서, 프로젝트 카드
  // 버튼과 아래 "전체 일정 확인" 요약 카드 둘 다에서 재사용한다.
  Future<void> _openSchedule(Map<String, dynamic> log) async {
    final updated = await Navigator.push<List<Map<String, dynamic>>>(
      context,
      MaterialPageRoute(
        builder: (context) => ProjectSchedulePage(
          projectName: log['name'] ?? '이름 없음',
          initialSchedules: List<Map<String, dynamic>>.from(
            log['schedules'] ?? [],
          ),
          // 🚀 검사일정에 연결된 이슈 미해결 건수를 보여주기 위한 참조용.
          punchLists: List<Map<String, dynamic>>.from(log['punch_lists'] ?? []),
        ),
      ),
    );
    if (updated != null) {
      setState(() {
        log['schedules'] = updated;
      });
      _saveProject(log);
    }
  }

  DateTime _asDateTime(dynamic v) {
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  // 🚀 [추가] 프로젝트 완료/보관 처리. 완료로 표시하면 알림(서버의
  // checkDailyReportReminder 등은 이미 status가 'ONGOING'이 아니면
  // 건너뛰도록 돼 있었다)도 자연히 멈추고, 목록/대시보드에서도 빠진다.
  void _toggleProjectStatus(Map<String, dynamic> log) {
    setState(() {
      log['status'] = _isActive(log) ? 'DONE' : 'ONGOING';
    });
    _saveProject(log);
  }

  String _todayMmDd() {
    final now = DateTime.now();
    return "${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}";
  }

  // 🚀 [추가] 오늘 일지를 아직 안 쓴 진행중 프로젝트들.
  List<Map<String, dynamic>> get _projectsMissingTodayReport {
    final today = _todayMmDd();
    return _activeLogs.where((log) {
      final reports = (log['daily_reports'] as List<dynamic>? ?? []);
      return !reports.any((r) => r is Map && r['date'] == today);
    }).toList();
  }

  // 🚀 [추가] 전체 진행중 프로젝트의 미해결 이슈를 우선순위(긴급→보통→
  // 여유)순, 같은 우선순위면 오래된 순으로 모은다.
  static const Map<String, int> _priorityOrder = {'긴급': 0, '보통': 1, '여유': 2};

  List<Map<String, dynamic>> get _allUnresolvedIssues {
    final List<Map<String, dynamic>> items = [];
    for (final log in _activeLogs) {
      final punches = (log['punch_lists'] as List<dynamic>? ?? []);
      for (final p in punches) {
        if (p is! Map) continue;
        if (p['is_completed'] == true) continue;
        items.add({
          ...Map<String, dynamic>.from(p),
          '_projectRef': log,
          '_projectName': log['name'] ?? '이름 없음',
        });
      }
    }
    items.sort((a, b) {
      final pa = _priorityOrder[a['priority']] ?? 1;
      final pb = _priorityOrder[b['priority']] ?? 1;
      if (pa != pb) return pa.compareTo(pb);
      final ca = a['created_at'] == null
          ? DateTime.now()
          : _asDateTime(a['created_at']);
      final cb = b['created_at'] == null
          ? DateTime.now()
          : _asDateTime(b['created_at']);
      return ca.compareTo(cb);
    });
    return items;
  }

  // 🚀 [추가] 이슈 상세 열기 - 카드 안에서든 대시보드에서든 동일하게
  // 재사용한다.
  Future<void> _openPunchDetail(
    Map<String, dynamic> log,
    Map<String, dynamic> punch,
  ) async {
    final inspectionSchedules = (log['schedules'] as List<dynamic>? ?? [])
        .where((s) => s['type'] == '검사일정')
        .map((s) => Map<String, dynamic>.from(s))
        .toList();
    final updated = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => PunchDetailPage(
          punch: punch,
          inspectionSchedules: inspectionSchedules,
          floorPlanImagePath: log['floor_plan_image_path'],
        ),
      ),
    );
    if (updated != null) {
      setState(() {
        final idx = log['punch_lists'].indexOf(punch);
        if (idx != -1) log['punch_lists'][idx] = updated;
      });
      _saveProject(log);
    }
  }

  // 🚀 [추가] 작업 일지 작성 화면 열기 - 대시보드의 "오늘 일지 미작성"
  // 칩에서 특정 프로젝트로 바로 들어갈 때도 재사용한다.
  Future<void> _addDailyReportFor(Map<String, dynamic> log) async {
    final newReport = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (context) => const DailyReportPage()),
    );
    if (newReport != null) {
      setState(() {
        log['daily_reports'].insert(0, newReport);
      });
      _saveProject(log);
    }
  }

  // 🚀 [추가] 프로젝트마다 일정 관리를 따로 열어봐야 했는데, 전체
  // 프로젝트의 미완료 일정을 한데 모아 날짜순(입고일 미정인 자재요청은
  // 맨 위)으로 보여준다. 원본 일정 Map을 그대로 담아두고 '_projectRef'로
  // 어느 프로젝트 것인지 표시한다.
  List<Map<String, dynamic>> get _allUpcomingSchedules {
    final List<Map<String, dynamic>> items = [];
    for (final log in _activeLogs) {
      final schedules = (log['schedules'] as List<dynamic>? ?? []);
      for (final s in schedules) {
        if (s is! Map) continue;
        if (s['isCompleted'] == true) continue;
        items.add({
          ...Map<String, dynamic>.from(s),
          '_projectRef': log,
          '_projectName': log['name'] ?? '이름 없음',
        });
      }
    }
    items.sort((a, b) {
      final DateTime? da = a['dateTime'] == null
          ? null
          : _asDateTime(a['dateTime']);
      final DateTime? db = b['dateTime'] == null
          ? null
          : _asDateTime(b['dateTime']);
      if (da == null && db == null) return 0;
      if (da == null) return -1;
      if (db == null) return 1;
      return da.compareTo(db);
    });
    return items;
  }

  // 🚀 [신규] "오늘 일지 / 다가오는 일정 / 미해결 이슈"를 한 화면에
  // 모은 통합 대시보드. 프로젝트마다 따로 열어보지 않아도 오늘 뭘 해야
  // 하는지 여기서 다 보인다.
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
                  "오늘 일지 미작성 ${missingReports.length}건",
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
                  "다가오는 일정 (미완료 ${schedules.length}건)",
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
                "외 ${schedules.length - displayedSchedules.length}건 더",
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
                  "미해결 이슈 (${issues.length}건)",
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
                "외 ${issues.length - displayedIssues.length}건 더",
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tossBg, // 토스 스타일 옅은 회색 배경
      appBar: AppBar(
        title: const Text(
          '내 프로젝트',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: tossText,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: pureWhite, // 토스 스타일 흰색 앱바
        foregroundColor: tossText,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: tossBlue))
          : Column(
              children: [
                if (!_showCompleted) _buildDashboard(),
                // 🚀 [추가] 진행중/완료됨 전환 - 완료 처리한 프로젝트는
                // 기본 목록에서 빠지고 이 탭을 눌러야 보인다.
                if (_doneLogs.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: Text("진행중 (${_activeLogs.length})"),
                          selected: !_showCompleted,
                          selectedColor: tossBlue.withValues(alpha: 0.15),
                          labelStyle: TextStyle(
                            color: !_showCompleted ? tossBlue : tossSubText,
                            fontWeight: FontWeight.bold,
                          ),
                          backgroundColor: tossBg,
                          side: BorderSide.none,
                          onSelected: (_) =>
                              setState(() => _showCompleted = false),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text("완료됨 (${_doneLogs.length})"),
                          selected: _showCompleted,
                          selectedColor: tossBlue.withValues(alpha: 0.15),
                          labelStyle: TextStyle(
                            color: _showCompleted ? tossBlue : tossSubText,
                            fontWeight: FontWeight.bold,
                          ),
                          backgroundColor: tossBg,
                          side: BorderSide.none,
                          onSelected: (_) =>
                              setState(() => _showCompleted = true),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final visibleLogs = _showCompleted
                          ? _doneLogs
                          : _activeLogs;
                      if (visibleLogs.isEmpty) {
                        return Center(
                          child: Text(
                            _showCompleted
                                ? "완료된 프로젝트가 없습니다."
                                : "아직 등록된 작업 기록이 없어요.\n아래 버튼을 눌러 새로 시작해 보세요.",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: tossSubText,
                              height: 1.5,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.only(
                          top: 16,
                          left: 16,
                          right: 16,
                          bottom: 100,
                        ),
                        itemCount: visibleLogs.length,
                        itemBuilder: (context, index) {
                          final log = visibleLogs[index];
                          final int workLogIndex = _workLogs.indexOf(log);
                          final bool isExpanded =
                              _expandedIndex == workLogIndex;

                          return WorkLogCard(
                            log: log,
                            isExpanded: isExpanded,
                            onToggleExpand: () {
                              setState(() {
                                _expandedIndex = isExpanded
                                    ? null
                                    : workLogIndex;
                              });
                            },
                            onToggleProjectStatus: () =>
                                _toggleProjectStatus(log),
                            isProjectActive: _isActive(log),
                            // 🚀 [수정] 예전엔 debugPrint만 찍던 죽은 "계산기" 버튼을
                            // "일정 관리"로 교체 - 자재 요청/입고일/납기일/검사일정을
                            // 등록해두면 서버가 알림을 보내준다. 진입 로직은
                            // "전체 일정 확인" 요약 카드와 공유하는 _openSchedule로 뺐다.
                            onOpenSchedule: () => _openSchedule(log),
                            // 🚀 [에러 해결] Dialog.show 대신 Navigator.push로 새로운 Page 열기
                            onAddDailyReport: () async {
                              // 🚀 Navigator.push를 사용하여 전체 화면 페이지로 이동
                              final newReport = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const DailyReportPage(),
                                ),
                              );

                              if (newReport != null) {
                                setState(() {
                                  log['daily_reports'].insert(0, newReport);
                                });
                                _saveProject(log);
                              }
                            },
                            // 🚀 [추가] 작업 일지 항목을 탭하면 사진 모달이 아니라
                            // 그날 작업 일보 전체를 보고 수정할 수 있는 화면으로
                            // 들어간다 (등록 때 쓰는 화면을 수정 모드로 재사용).
                            onOpenDailyReport: (report) async {
                              final updated =
                                  await Navigator.push<Map<String, dynamic>>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          DailyReportPage(existingData: report),
                                    ),
                                  );
                              if (updated != null) {
                                setState(() {
                                  final idx = log['daily_reports'].indexOf(
                                    report,
                                  );
                                  if (idx != -1)
                                    log['daily_reports'][idx] = updated;
                                });
                                _saveProject(log);
                              }
                            },
                            // 🚀 [추가] 달력으로 빠진 날 확인 + 기간 통계/내보내기.
                            onOpenDailyReportCalendar: () async {
                              final updated =
                                  await Navigator.push<
                                    List<Map<String, dynamic>>
                                  >(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          DailyReportCalendarPage(
                                            projectName: log['name'] ?? '이름 없음',
                                            initialReports:
                                                List<Map<String, dynamic>>.from(
                                                  log['daily_reports'] ?? [],
                                                ),
                                          ),
                                    ),
                                  );
                              if (updated != null) {
                                setState(() {
                                  log['daily_reports'] = updated;
                                });
                                _saveProject(log);
                              }
                            },

                            onAddPunchList: () async {
                              // 🚀 [추가] 같은 프로젝트에서 최근에 쓴 위치를
                              // 최신순으로 추려서 넘긴다(최대 6개, 중복 제거).
                              final List<String> recentLocations = [];
                              for (final p
                                  in (log['punch_lists'] as List<dynamic>? ??
                                      [])) {
                                final loc = p['location']?.toString();
                                if (loc != null &&
                                    loc.isNotEmpty &&
                                    loc != '위치 미상' &&
                                    !recentLocations.contains(loc)) {
                                  recentLocations.add(loc);
                                }
                                if (recentLocations.length >= 6) break;
                              }

                              // 🚀 Navigator.push를 사용하여 전체 화면 페이지로 이동
                              final newPunch =
                                  await Navigator.push<Map<String, dynamic>>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PunchListPage(
                                        recentLocations: recentLocations,
                                        floorPlanImagePath:
                                            log['floor_plan_image_path'],
                                      ),
                                    ),
                                  );

                              if (newPunch != null) {
                                // 🚀 이번에 새로 고른 도면이면 프로젝트에
                                // 저장해서 다음 이슈 등록부터도 재사용한다.
                                final String? newFloorPlanPath = newPunch
                                    .remove('__newFloorPlanPath');
                                if (newFloorPlanPath != null) {
                                  log['floor_plan_image_path'] =
                                      newFloorPlanPath;
                                }
                                // 🚀 [추가] 이슈가 처리될 때까지 매일 알림을 보내기
                                // 위한 식별자/플래그. 등록일 기준으로 "며칠째
                                // 미해결"인지 계산하고, 하루 1회만 보내도록
                                // lastPunchReminderDate로 중복 발송을 막는다
                                // (자재 발주/일정 알림과 동일한 패턴).
                                newPunch['id'] = DateTime.now()
                                    .millisecondsSinceEpoch
                                    .toString();
                                newPunch['created_at'] = DateTime.now();
                                newPunch['lastPunchReminderAt'] = null;
                                // 🚀 [추가] 검사일정(파이널 검사 등)에 연결해두면
                                // 그 기한 임박/초과 시 우선순위와 무관하게 더 자주
                                // 알림이 오도록 서버(checkPunchIssues)에서 처리한다.
                                newPunch['linkedScheduleId'] = null;
                                setState(() {
                                  log['punch_lists'].insert(0, newPunch);
                                });
                                _saveProject(log);
                              }
                            },
                            // 🚀 [변경] 이슈를 탭하면 언제 발생했고 어떻게 처리
                            // 했는지 정리할 수 있는 상세 화면으로 들어간다.
                            onOpenPunchDetail: (punch) async {
                              // 🚀 검사일정 연결 선택지를 보여주기 위해, 이
                              // 프로젝트의 "검사일정" 타입 일정만 추려서 넘긴다.
                              final inspectionSchedules =
                                  (log['schedules'] as List<dynamic>? ?? [])
                                      .where((s) => s['type'] == '검사일정')
                                      .map((s) => Map<String, dynamic>.from(s))
                                      .toList();
                              final updated =
                                  await Navigator.push<Map<String, dynamic>>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PunchDetailPage(
                                        punch: punch,
                                        inspectionSchedules:
                                            inspectionSchedules,
                                        floorPlanImagePath:
                                            log['floor_plan_image_path'],
                                      ),
                                    ),
                                  );
                              if (updated != null) {
                                setState(() {
                                  final idx = log['punch_lists'].indexOf(punch);
                                  if (idx != -1)
                                    log['punch_lists'][idx] = updated;
                                });
                                _saveProject(log);
                              }
                            },
                            onDelete: () {
                              final deletedId = log['id']?.toString();
                              setState(() {
                                _workLogs.removeAt(workLogIndex);

                                // 🚀 [에러 해결] if문 중괄호 추가 적용
                                if (_expandedIndex == workLogIndex) {
                                  _expandedIndex = null;
                                } else if (_expandedIndex != null &&
                                    _expandedIndex! > workLogIndex) {
                                  _expandedIndex = _expandedIndex! - 1;
                                }
                              });
                              if (deletedId != null) {
                                _repo.deleteProject(deletedId);
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
      // 🚀 토스 스타일 그림자가 들어간 플로팅 버튼
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSheet,
        backgroundColor: tossBlue,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: pureWhite),
        label: const Text(
          "새 작업 추가",
          style: TextStyle(
            color: pureWhite,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
