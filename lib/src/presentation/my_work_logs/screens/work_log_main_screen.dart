import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // debugPrint 사용을 위해 추가
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

// 🚀 [수정됨] Dialog가 아니라 새로 만든 Page를 임포트합니다.
// 경로가 본인 프로젝트 폴더와 맞는지 꼭 확인해 주세요!
import '../widgets/create_log_sheet.dart';
import '../widgets/project_summary_card.dart';
import '../models/project_phase.dart';
import '../models/report_tools.dart';
import '../models/photo_store.dart';
import '../models/backup_tools.dart';
import '../pages/report_search_page.dart';
import '../pages/project_stats_page.dart';
import '../pages/retro_overview_page.dart';
import '../pages/storage_management_page.dart';
import 'dart:async';
import '../pages/project_detail_page.dart';
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
  // 🚀 [3번 강화] "내 일정 관리"에서 프로젝트 유래 일정을 탭했을 때, 목록을
  // 거치지 않고 바로 그 프로젝트의 일정 관리 화면으로 들어가기 위한 값.
  final String? initialProjectId;

  const WorkLogMainScreen({super.key, this.initialProjectId});

  @override
  State<WorkLogMainScreen> createState() => _WorkLogMainScreenState();
}

class _WorkLogMainScreenState extends State<WorkLogMainScreen> {
  final WorkProjectRepository _repo = WorkProjectRepository();
  List<Map<String, dynamic>> _workLogs = [];
  bool _isLoading = true;
  // 🚀 [프로젝트 목록 정렬] due=납기 임박순(납기 없는 건 뒤로), recent=최근 생성순,
  // progress=진행률 낮은순(뒤처진 프로젝트 먼저)
  String _sortMode = 'due';
  // 🚀 [추가] 완료 처리된 프로젝트는 기본적으로 목록/대시보드에서 숨기고
  // "완료됨" 탭을 눌러야 보이게 한다 - 오래 쓸수록 목록이 무한정
  // 길어지는 걸 막기 위함.
  bool _showCompleted = false;

  bool _isActive(Map<String, dynamic> log) => log['status'] != 'DONE';

  List<Map<String, dynamic>> get _activeLogs =>
      _workLogs.where(_isActive).toList();
  List<Map<String, dynamic>> get _doneLogs =>
      _workLogs.where((l) => !_isActive(l) && l['archived'] != true).toList();
  List<Map<String, dynamic>> get _archivedLogs =>
      _workLogs.where((l) => !_isActive(l) && l['archived'] == true).toList();
  bool _showArchived = false;

  void _toggleArchive(Map<String, dynamic> log) {
    setState(() {
      if (log['archived'] == true) {
        log.remove('archived');
      } else {
        log['archived'] = true;
      }
    });
    _saveProject(log);
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final projects = await _repo.fetchAllProjects();
      // 🚀 [단계 구조 이전] 단계(phases)가 없던 기존 프로젝트를, 등록된 일정
      // 종류/날짜를 기준으로 새 구조로 옮겨 한 번만 저장한다.
      for (final p in projects) {
        if (migrateProjectToPhases(p)) _repo.upsertProject(p);
      }
      if (!mounted) return;
      setState(() {
        _workLogs = projects;
        _isLoading = false;
      });
      syncReportReminder(_workLogs);
      cleanOldDrafts();
      _runAutoBackup();
      _refreshPhotoCount();
      _retryTimer ??= Timer.periodic(const Duration(seconds: 90), (_) {
        if (_localPhotos > 0) _retryUploads();
        if (_backupFailed) _runAutoBackup();
      });
      _migrateLocalPhotos();
      if (widget.initialProjectId != null) {
        final match = _workLogs.firstWhere(
          (l) => l['id']?.toString() == widget.initialProjectId,
          orElse: () => const {},
        );
        if (match.isNotEmpty && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _openDetail(match, tab: 1);
          });
        }
      }
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
    // 일보를 저장하면 오늘 알림을 내일로 미룬다.
    syncReportReminder(_workLogs);
  }

  // 저장한 일보의 사진을 백그라운드로 클라우드에 올리고, 성공하면 문서를 URL로
  // 갱신한다(실패하면 로컬 경로가 그대로 남아 다음 실행 때 다시 시도).
  Future<void> _uploadReportPhotosFor(
    Map<String, dynamic> log,
    Map report,
  ) async {
    final pid = log['id']?.toString();
    if (pid == null || !_uploading.add(pid)) return;
    if (mounted) setState(() {});
    try {
      if (await uploadAllPhotos(log)) {
        _repo.upsertProject(log);
      }
    } finally {
      _uploading.remove(pid);
      _refreshPhotoCount();
      if (mounted) setState(() {});
    }
  }

  final Set<String> _uploading = {};
  int _localPhotos = 0;
  Timer? _retryTimer;

  void _refreshPhotoCount() {
    final n = countLocalPhotos(_workLogs);
    if (mounted && n != _localPhotos) setState(() => _localPhotos = n);
  }

  // 네트워크가 없어서 못 올라간 사진을 1분 반 간격으로 다시 시도한다.
  Future<void> _retryUploads() async {
    if (_uploading.isNotEmpty) return;
    for (final log in List<Map<String, dynamic>>.from(_workLogs)) {
      await _uploadReportPhotosFor(log, const {});
    }
    _refreshPhotoCount();
  }

  // 예전에 저장된 로컬 경로 사진들도 한 번씩 올린다.
  Future<void> _migrateLocalPhotos() async {
    for (final log in List<Map<String, dynamic>>.from(_workLogs)) {
      await _uploadReportPhotosFor(log, const {});
    }
  }

  Future<void> _openSearch() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => ReportSearchPage(
          logs: _workLogs,
          onOpen: (hit) async {
            Navigator.pop(ctx);
            if (hit.kind == '이슈') {
              await _openPunchDetail(hit.log, hit.item as Map<String, dynamic>);
            } else {
              await _openReportFor(hit.log, hit.item as Map<String, dynamic>);
            }
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  Future<void> _showReminderSettings() async {
    final cur = await loadReportReminder();
    if (!mounted) return;
    bool enabled = cur.enabled;
    int minutes = cur.minutes;
    bool weekly = cur.weekly;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text("작업일보 알림"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("일보 작성 알림"),
                subtitle: const Text("진행중 프로젝트가 있고 오늘 일보를 안 썼으면 알려줘요."),
                value: enabled,
                onChanged: (v) => setS(() => enabled = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("주간 보고서 알림"),
                subtitle: const Text("매주 금요일 17:00에 보고서 초안을 만들어 보라고 알려줘요."),
                value: weekly,
                onChanged: (v) => setS(() => weekly = v),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: enabled,
                title: const Text("알림 시각"),
                trailing: Text(
                  "${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}",
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                onTap: !enabled
                    ? null
                    : () async {
                        final t = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay(
                            hour: minutes ~/ 60,
                            minute: minutes % 60,
                          ),
                        );
                        if (t != null) {
                          setS(() => minutes = t.hour * 60 + t.minute);
                        }
                      },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("취소"),
            ),
            TextButton(
              onPressed: () async {
                await saveReportReminder(enabled, minutes, weekly: weekly);
                await syncReportReminder(_workLogs);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text("저장"),
            ),
          ],
        ),
      ),
    );
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

  // 🚀 [프로젝트 상세] 카드 안에 인라인으로 흩어져 있던 동작들을 메서드로 빼서,
  // 새 프로젝트 상세 화면(ProjectDetailPage)이 그대로 재사용하게 했다.
  Future<void> _openDetail(
    Map<String, dynamic> log, {
    int tab = 0,
    bool openExport = false,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProjectDetailPage(
          log: log,
          actions: _actionsFor(log),
          initialTab: tab,
          openExport: openExport,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  ProjectActions _actionsFor(Map<String, dynamic> log) => ProjectActions(
    addPunch: () => _addPunchFor(log),
    openPunch: (p) => _openPunchDetail(log, p),
    addReport: () => _addDailyReportFor(log),
    openReport: (r) => _openReportFor(log, r),
    openReportCalendar: () => _openReportCalendarFor(log),
    openSchedule: ({String? phaseId, bool add = false}) =>
        _openSchedule(log, phaseId: phaseId, add: add),
    save: () => _saveProject(log),
    toggleStatus: () => _toggleProjectStatus(log),
    toggleArchive: () => _toggleArchive(log),
    delete: () {
      final id = log['id']?.toString();
      setState(() => _workLogs.remove(log));
      if (id != null) _repo.deleteProject(id);
    },
  );

  Future<void> _openReportFor(
    Map<String, dynamic> log,
    Map<String, dynamic> report,
  ) async {
    final updated = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => DailyReportPage(
          existingData: report,
          relatedIssueCandidates: _issueCandidatesFor(log),
          floorPlanImagePath: log['floor_plan_image_path'],
          phases: phasesOf(log),
          materialItems: schedulesOf(log).where(isMaterialSchedule).toList(),
          pendingSchedules: _pendingSchedulesFor(log, report),
        ),
      ),
    );
    if (updated != null) {
      setState(() {
        final idx = log['daily_reports'].indexOf(report);
        if (idx != -1) log['daily_reports'][idx] = updated;
        applyReportEffects(log, updated);
      });
      _saveProject(log);
      _uploadReportPhotosFor(log, updated);
    }
  }

  Future<void> _openReportCalendarFor(Map<String, dynamic> log) async {
    final updated = await Navigator.push<List<Map<String, dynamic>>>(
      context,
      MaterialPageRoute(
        builder: (context) => DailyReportCalendarPage(
          projectName: log['name'] ?? '이름 없음',
          initialReports: List<Map<String, dynamic>>.from(
            log['daily_reports'] ?? [],
          ),
        ),
      ),
    );
    if (updated != null) {
      setState(() => log['daily_reports'] = updated);
      _saveProject(log);
    }
  }

  Future<void> _addPunchFor(Map<String, dynamic> log) async {
    // 같은 프로젝트에서 최근에 쓴 위치를 최신순으로 추려서 넘긴다(최대 6개).
    final List<String> recentLocations = [];
    for (final p in (log['punch_lists'] as List<dynamic>? ?? [])) {
      final loc = p['location']?.toString();
      if (loc != null &&
          loc.isNotEmpty &&
          loc != '위치 미상' &&
          !recentLocations.contains(loc)) {
        recentLocations.add(loc);
      }
      if (recentLocations.length >= 6) break;
    }
    final newPunch = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => PunchListPage(
          recentLocations: recentLocations,
          floorPlanImagePath: log['floor_plan_image_path'],
        ),
      ),
    );
    if (newPunch != null) {
      final String? newFloorPlanPath = newPunch.remove('__newFloorPlanPath');
      if (newFloorPlanPath != null) {
        log['floor_plan_image_path'] = newFloorPlanPath;
      }
      newPunch['id'] = DateTime.now().millisecondsSinceEpoch.toString();
      newPunch['created_at'] = DateTime.now();
      newPunch['lastPunchReminderAt'] = null;
      newPunch['linkedScheduleId'] = null;
      setState(() => log['punch_lists'].insert(0, newPunch));
      _saveProject(log);
      _uploadReportPhotosFor(log, const {});
    }
  }

  List<Map<String, dynamic>> _sortedLogs(List<Map<String, dynamic>> list) {
    final out = [...list];
    switch (_sortMode) {
      case 'progress':
        out.sort((a, b) => projectProgress(a).compareTo(projectProgress(b)));
        break;
      case 'recent':
        break; // fetchAllProjects가 이미 최신순
      default:
        out.sort((a, b) {
          final da = projectDue(a), db = projectDue(b);
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return da.compareTo(db);
        });
    }
    if (_showCompleted && _nameFilter.trim().isNotEmpty) {
      final q = _nameFilter.trim().toLowerCase();
      return out
          .where((l) => (l['name']?.toString() ?? '').toLowerCase().contains(q))
          .toList();
    }
    return out;
  }

  // ── 완료/보관 프로젝트: 이름 검색 + 여러 개 골라 통합 보고서 ──
  String _nameFilter = '';
  bool _selectProjects = false;
  final Set<Map<String, dynamic>> _selProjects = {};

  Widget _buildDoneTools() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            onChanged: (v) => setState(() => _nameFilter = v),
            decoration: InputDecoration(
              hintText: "프로젝트 이름 검색",
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              isDense: true,
              filled: true,
              fillColor: pureWhite,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (!_selectProjects)
                TextButton.icon(
                  onPressed: () => setState(() => _selectProjects = true),
                  icon: const Icon(Icons.checklist_rounded, size: 18),
                  label: const Text("골라서 통합 보고서"),
                  style: TextButton.styleFrom(foregroundColor: tossSubText),
                )
              else ...[
                TextButton(
                  onPressed: () => setState(() {
                    _selectProjects = false;
                    _selProjects.clear();
                  }),
                  child: const Text("취소"),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _selProjects.isEmpty
                      ? null
                      : _exportSelectedProjects,
                  style: ElevatedButton.styleFrom(backgroundColor: tossBlue),
                  child: Text(
                    "${_selProjects.length}건 내보내기",
                    style: const TextStyle(color: pureWhite),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _exportSelectedProjects() async {
    final now = DateTime.now().add(const Duration(days: 1));
    final doc = mergeReportDocs([
      for (final l in _selProjects) buildReportDoc(l, DateTime(2000), now),
    ]);
    final fmt = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: pureWhite,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat_outlined),
              title: const Text("텍스트로 공유"),
              onTap: () => Navigator.pop(ctx, 'text'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text("PDF로 공유"),
              onTap: () => Navigator.pop(ctx, 'pdf'),
            ),
          ],
        ),
      ),
    );
    try {
      if (fmt == 'text') await shareReportText(doc);
      if (fmt == 'pdf') await shareReportPdf(doc);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("내보내기 실패: $e")));
      }
    }
  }

  // 🚀 [추가] "일정 관리" 진입 로직을 하나로 모아서, 프로젝트 카드
  // 버튼과 아래 "전체 일정 확인" 요약 카드 둘 다에서 재사용한다.
  Future<void> _openSchedule(
    Map<String, dynamic> log, {
    String? phaseId,
    bool add = false,
  }) async {
    final updated = await Navigator.push<List<Map<String, dynamic>>>(
      context,
      MaterialPageRoute(
        builder: (context) => ProjectSchedulePage(
          projectName: log['name'] ?? '이름 없음',
          phases: phasesOf(log),
          initialPhaseId: phaseId,
          openEditorOnStart: add,
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
      final done = _isActive(log);
      log['status'] = done ? 'DONE' : 'ONGOING';
      if (done) {
        log['completedAt'] = DateTime.now();
      } else {
        log.remove('completedAt');
      }
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

  // 🚀 [추가] 이 프로젝트의 가장 최근 일지 - "어제 값 불러오기"용.
  Map<String, dynamic>? _previousReportFor(Map<String, dynamic> log) {
    final reports = (log['daily_reports'] as List<dynamic>? ?? []);
    if (reports.isEmpty) return null;
    return Map<String, dynamic>.from(reports.first);
  }

  // 🚀 [추가] 일지 작성 화면에서 "오늘 처리한 이슈"로 태그할 수 있는
  // 후보 - 아직 미해결이거나, 오늘 처리 완료된 이슈.
  List<Map<String, dynamic>> _issueCandidatesFor(Map<String, dynamic> log) {
    final String today = _todayMmDd();
    return (log['punch_lists'] as List<dynamic>? ?? [])
        .where((p) {
          if (p is! Map) return false;
          if (p['is_completed'] != true) return true;
          final resolvedAt = p['resolved_at'];
          if (resolvedAt == null) return false;
          final dt = _asDateTime(resolvedAt);
          return "${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}" ==
              today;
        })
        .map((p) => Map<String, dynamic>.from(p))
        .toList();
  }

  // 🚀 [추가] 작업 일지 작성 화면 열기 - 대시보드의 "오늘 일지 미작성"
  // 칩에서 특정 프로젝트로 바로 들어갈 때도 재사용한다.
  // 일보에서 "오늘 끝낸 일정"으로 고를 수 있는 일정: 미완료 + (수정 중인
  // 일보에서 이미 체크한 것). 검사일정은 별도 흐름이라 제외.
  List<Map<String, dynamic>> _pendingSchedulesFor(
    Map<String, dynamic> log,
    Map<String, dynamic>? report,
  ) {
    final already = report == null
        ? <String>{}
        : reportIds(report, 'completedScheduleIds').toSet();
    return schedulesOf(log).where((s) {
      if (s['type'] == '검사일정') return false;
      return s['isCompleted'] != true || already.contains(s['id']?.toString());
    }).toList();
  }

  Future<void> _addDailyReportFor(Map<String, dynamic> log) async {
    final newReport = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => DailyReportPage(
          previousReport: _previousReportFor(log),
          relatedIssueCandidates: _issueCandidatesFor(log),
          floorPlanImagePath: log['floor_plan_image_path'],
          draftKey: 'report_draft_${log['id']}',
          phases: phasesOf(log),
          materialItems: schedulesOf(log).where(isMaterialSchedule).toList(),
          pendingSchedules: _pendingSchedulesFor(log, null),
          defaultPhaseId: currentPhase(log)?['id']?.toString(),
        ),
      ),
    );
    if (newReport != null) {
      setState(() {
        log['daily_reports'].insert(0, newReport);
        applyReportEffects(log, newReport);
      });
      _saveProject(log);
      _uploadReportPhotosFor(log, newReport);
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
  bool _backupFailed = false;

  Future<void> _runAutoBackup() async {
    final r = await autoBackupIfDue(_workLogs);
    if (r != null && mounted) setState(() => _backupFailed = r == false);
  }

  Widget _buildBackupBanner() {
    if (!_backupFailed) return const SizedBox.shrink();
    const c = Color(0xFFC77700);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 16, color: c),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              "주간 자동 백업에 실패했어요. 앱이 켜져 있는 동안 계속 다시 시도해요.",
              style: TextStyle(
                color: c,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
          TextButton(
            onPressed: _runAutoBackup,
            style: TextButton.styleFrom(
              foregroundColor: c,
              minimumSize: const Size(0, 32),
            ),
            child: const Text(
              "지금 시도",
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncBanner() {
    return ValueListenableBuilder<int>(
      valueListenable: WorkProjectRepository.pendingWrites,
      builder: (context, pending, _) {
        final uploading = _uploading.isNotEmpty;
        if (pending == 0 && _localPhotos == 0 && !uploading) {
          return const SizedBox.shrink();
        }
        String text;
        bool warn = false;
        if (uploading) {
          text = "사진 올리는 중… (남은 사진 $_localPhotos장)";
        } else if (_localPhotos > 0) {
          text = "사진 $_localPhotos장이 아직 올라가지 않았어요. 네트워크를 확인해 주세요.";
          warn = true;
        } else {
          text = "변경사항을 서버에 동기화하는 중이에요. 오프라인이면 연결될 때 자동으로 올라갑니다.";
        }
        final color = warn ? const Color(0xFFC77700) : tossBlue;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              if (uploading || (pending > 0 && _localPhotos == 0))
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              else
                Icon(Icons.cloud_off_rounded, size: 16, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
              if (!uploading && _localPhotos > 0)
                TextButton(
                  onPressed: _retryUploads,
                  style: TextButton.styleFrom(
                    foregroundColor: color,
                    minimumSize: const Size(0, 32),
                  ),
                  child: const Text(
                    "다시 시도",
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // 금~일에는 주간 보고서 초안을 바로 만들 수 있는 카드를 보여준다.
  Widget _buildWeeklyReportCard() {
    if (DateTime.now().weekday < DateTime.friday)
      return const SizedBox.shrink();
    final active = _activeLogs;
    if (active.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tossBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.summarize_rounded, color: tossBlue, size: 18),
              SizedBox(width: 6),
              Text(
                "이번 주 보고서 초안",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: tossBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            "프로젝트를 누르면 최근 7일 일보로 보고서를 만들어 공유할 수 있어요.",
            style: TextStyle(color: tossSubText, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final log in active)
                ActionChip(
                  label: Text(log['name']?.toString() ?? '이름 없음'),
                  backgroundColor: pureWhite,
                  side: BorderSide.none,
                  onPressed: () => _openDetail(log, tab: 3, openExport: true),
                ),
            ],
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
        actions: [
          IconButton(
            tooltip: "투입 통계",
            icon: const Icon(Icons.bar_chart_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ProjectStatsPage(logs: _workLogs, title: "전체 투입 통계"),
              ),
            ),
          ),
          IconButton(
            tooltip: "일보·이슈 검색",
            icon: const Icon(Icons.search_rounded),
            onPressed: _openSearch,
          ),
          PopupMenuButton<String>(
            tooltip: "더보기",
            onSelected: (v) {
              if (v == 'reminder') _showReminderSettings();
              if (v == 'storage') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StorageManagementPage(
                      logs: _workLogs,
                      onRestored: _loadData,
                    ),
                  ),
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'reminder', child: Text("일보·주간 알림 설정")),
              PopupMenuItem(value: 'storage', child: Text("저장 공간 관리")),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: tossBlue))
          : Builder(
              builder: (context) {
                final visibleLogs = _sortedLogs(
                  _showArchived
                      ? _archivedLogs
                      : (_showCompleted ? _doneLogs : _activeLogs),
                );
                const sortLabels = {
                  'due': '납기 임박순',
                  'progress': '진행률 낮은순',
                  'recent': '최근 등록순',
                };
                // 요약 카드/필터는 목록과 같이 스크롤된다(예전엔 위에 고정돼서
                // 오늘 할 일이 많으면 프로젝트 목록이 좁은 창에 갇혔다).
                final header = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSyncBanner(),
                    _buildBackupBanner(),
                    if (!_showCompleted) _buildWeeklyReportCard(),
                    if (!_showCompleted) _buildDashboard(),
                    if (_showCompleted) _buildDoneTools(),
                    if (_showCompleted)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: ActionChip(
                            avatar: const Icon(
                              Icons.insights_rounded,
                              size: 16,
                              color: tossBlue,
                            ),
                            label: const Text('회고 모아보기'),
                            backgroundColor: pureWhite,
                            side: BorderSide.none,
                            labelStyle: const TextStyle(
                              color: tossBlue,
                              fontWeight: FontWeight.bold,
                            ),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    RetroOverviewPage(logs: _workLogs),
                              ),
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: Text("진행중 (${_activeLogs.length})"),
                            selected: !_showCompleted && !_showArchived,
                            showCheckmark: false,
                            selectedColor: tossBlue.withValues(alpha: 0.15),
                            labelStyle: TextStyle(
                              color: !_showCompleted ? tossBlue : tossSubText,
                              fontWeight: FontWeight.bold,
                            ),
                            backgroundColor: pureWhite,
                            side: BorderSide.none,
                            onSelected: (_) => setState(() {
                              _showCompleted = false;
                              _showArchived = false;
                            }),
                          ),
                          if (_doneLogs.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: Text("완료됨 (${_doneLogs.length})"),
                              selected: _showCompleted && !_showArchived,
                              showCheckmark: false,
                              selectedColor: tossBlue.withValues(alpha: 0.15),
                              labelStyle: TextStyle(
                                color: _showCompleted ? tossBlue : tossSubText,
                                fontWeight: FontWeight.bold,
                              ),
                              backgroundColor: pureWhite,
                              side: BorderSide.none,
                              onSelected: (_) => setState(() {
                                _showCompleted = true;
                                _showArchived = false;
                              }),
                            ),
                          ],
                          if (_archivedLogs.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: Text("보관함 (${_archivedLogs.length})"),
                              selected: _showArchived,
                              showCheckmark: false,
                              selectedColor: tossBlue.withValues(alpha: 0.15),
                              labelStyle: TextStyle(
                                color: _showArchived ? tossBlue : tossSubText,
                                fontWeight: FontWeight.bold,
                              ),
                              backgroundColor: pureWhite,
                              side: BorderSide.none,
                              onSelected: (_) => setState(() {
                                _showCompleted = true;
                                _showArchived = true;
                              }),
                            ),
                          ],
                          const Spacer(),
                          PopupMenuButton<String>(
                            tooltip: "정렬",
                            initialValue: _sortMode,
                            onSelected: (v) => setState(() => _sortMode = v),
                            itemBuilder: (_) => [
                              for (final e in sortLabels.entries)
                                PopupMenuItem(
                                  value: e.key,
                                  child: Text(e.value),
                                ),
                            ],
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.sort_rounded,
                                    size: 18,
                                    color: tossSubText,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    sortLabels[_sortMode]!,
                                    style: const TextStyle(
                                      color: tossSubText,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: visibleLogs.isEmpty ? 2 : visibleLogs.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) return header;
                    if (visibleLogs.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 60),
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
                    final log = visibleLogs[index - 1];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _selectProjects
                          ? Row(
                              children: [
                                Checkbox(
                                  value: _selProjects.contains(log),
                                  activeColor: tossBlue,
                                  onChanged: (_) => setState(() {
                                    _selProjects.contains(log)
                                        ? _selProjects.remove(log)
                                        : _selProjects.add(log);
                                  }),
                                ),
                                Expanded(
                                  child: ProjectSummaryCard(
                                    log: log,
                                    isActive: _isActive(log),
                                    onTap: () => setState(() {
                                      _selProjects.contains(log)
                                          ? _selProjects.remove(log)
                                          : _selProjects.add(log);
                                    }),
                                  ),
                                ),
                              ],
                            )
                          : ProjectSummaryCard(
                              log: log,
                              isActive: _isActive(log),
                              onTap: () => _openDetail(log),
                            ),
                    );
                  },
                );
              },
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
