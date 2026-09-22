import '../widgets/work_theme.dart';
import '../widgets/korean_text.dart';
import 'package:flutter/material.dart';
// debugPrint 사용을 위해 추가
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

// 🚀 [수정됨] Dialog가 아니라 새로 만든 Page를 임포트합니다.
// 경로가 본인 프로젝트 폴더와 맞는지 꼭 확인해 주세요!
import '../widgets/create_log_sheet.dart';
import '../widgets/project_summary_card.dart';
import '../models/project_phase.dart';
import '../models/report_tools.dart';
import '../models/photo_store.dart';
import '../models/backup_tools.dart';
import '../models/report_style.dart';
import '../models/summary_image.dart';
import 'package:share_plus/share_plus.dart';
import '../pages/report_style_page.dart';
import '../pages/report_search_page.dart';
import '../pages/project_stats_page.dart';
import '../pages/weekly_report_page.dart';
import '../pages/notification_check_page.dart';
import '../widgets/reminder_problem_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
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

part 'work_log_main_screen_banners.dart';
part 'work_log_main_screen_dashboard.dart';

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
  // initialProjectId로 들어갈 때 처음 보여 줄 탭(0=개요, 1=단계·일정).
  final int initialTab;
  // 작업 일지 알림으로 들어왔을 때: 오늘 작업 일지를 안 쓴 프로젝트가 딱 하나면 바로 작성 화면을 연다
  // (여럿이면 어느 프로젝트인지 고르도록 목록 화면에 그대로 둔다).
  final bool autoWriteReport;

  const WorkLogMainScreen({
    super.key,
    this.initialProjectId,
    this.initialTab = 1,
    this.autoWriteReport = false,
  });

  @override
  State<WorkLogMainScreen> createState() => _WorkLogMainScreenState();
}

class _WorkLogMainScreenState extends State<WorkLogMainScreen> {
  final WorkProjectRepository _repo = WorkProjectRepository();
  List<Map<String, dynamic>> _workLogs = [];
  bool _isLoading = true;
  // 🚀 [프로젝트 목록 정렬] due=납기 빠른 순(납기 없는 건 뒤로), recent=최근 생성순,
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
    _loadGuideFlag();
    recordActiveReminders();
    // 예전에 공유하려고 만들어 둔 PDF 임시 파일 정리(백그라운드).
    getTemporaryDirectory().then(runPdfCleanup).catchError((_) => 0);
  }

  Future<void> _loadData() async {
    try {
      final projects = await _repo.fetchAllProjects();
      // 🚀 [단계 구조 이전] 단계(phases)가 없던 기존 프로젝트를, 등록된 일정
      // 종류/날짜를 기준으로 새 구조로 옮겨 한 번만 저장한다.
      for (final p in projects) {
        final migrated = migrateProjectToPhases(p);
        final snapped = recordProgressSnapshot(p);
        if (migrated || snapped) _repo.upsertProject(p);
      }
      if (!mounted) return;
      setState(() {
        _workLogs = projects;
        _isLoading = false;
      });
      // 알림을 다시 맞춘 뒤에도 예약이 어긋나 있으면 목록 위에 안내 카드를 띄운다.
      syncReportReminder(
        _workLogs,
      ).then((_) => dailyReminderProblem(_workLogs)).then((msg) {
        if (mounted) setState(() => _reminderProblem = msg);
      });
      cleanOldDrafts();
      _runAutoBackup();
      loadReportStyle();
      _refreshPhotoCount();
      _retryTimer ??= Timer.periodic(const Duration(seconds: 90), (_) {
        if (_localPhotos > 0) _retryUploads();
        if (_backupFailed) _runAutoBackup();
      });
      _migrateLocalPhotos();
      if (widget.autoWriteReport) {
        final missing = _projectsMissingTodayReport;
        if (missing.length == 1) {
          final target = missing.first;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _addDailyReportFor(target);
          });
        }
      }
      if (widget.initialProjectId != null) {
        final match = _workLogs.firstWhere(
          (l) => l['id']?.toString() == widget.initialProjectId,
          orElse: () => const {},
        );
        if (match.isNotEmpty && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _openDetail(match, tab: widget.initialTab);
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
    // 저장 실패가 아무 표시 없이 사라지던 것(화면은 저장된 것처럼 보였다).
    _repo.upsertProject(log).catchError((e) {
      debugPrint('프로젝트 저장 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("저장하지 못했습니다. 통신을 확인하고 다시 해 보십시오.")),
        );
      }
    });
    // 작업 일지를 저장하면 오늘 알림을 내일로 미룬다.
    syncReportReminder(_workLogs);
  }

  // 저장한 작업 일지의 사진을 백그라운드로 클라우드에 올리고, 성공하면 문서를 URL로
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
      WorkRoute(
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
    int weeklyMinutes = cur.weeklyMinutes;
    bool autoPdf = cur.autoPdf;
    final morning = await loadMorningSummary();
    if (!mounted) return;
    bool morningOn = morning.enabled;
    int morningMinutes = morning.minutes;
    String hm(int m) =>
        "${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}";
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text("작업 일지 알림"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("작업 일지 작성 알림"),
                  subtitle: Text(
                    keepWords("진행중 프로젝트가 있고 오늘 작업 일지를 쓰지 않았으면 알려 줍니다."),
                  ),
                  value: enabled,
                  onChanged: (v) => setS(() => enabled = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("주간 보고서 알림"),
                  subtitle: Text(
                    keepWords(
                      "매주 금요일 ${hm(weeklyMinutes)}에 주간 업무 보고를 열어 보라고 알려 줍니다.",
                    ),
                  ),
                  value: weekly,
                  onChanged: (v) => setS(() => weekly = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(keepWords("알림 누르면 PDF 바로 만들기")),
                  subtitle: Text(keepWords("끄면 주간 보고 화면이 열립니다.")),
                  value: autoPdf,
                  onChanged: weekly ? (v) => setS(() => autoPdf = v) : null,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  enabled: weekly,
                  title: const Text("주간 알림 시간(금요일)"),
                  trailing: Text(
                    hm(weeklyMinutes),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  onTap: !weekly
                      ? null
                      : () async {
                          final t = await showTimePicker(
                            context: ctx,
                            initialTime: TimeOfDay(
                              hour: weeklyMinutes ~/ 60,
                              minute: weeklyMinutes % 60,
                            ),
                          );
                          if (t != null) {
                            setS(() => weeklyMinutes = t.hour * 60 + t.minute);
                          }
                        },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("아침 요약 알림"),
                  subtitle: Text(
                    keepWords(
                      "매일 ${hm(morningMinutes)}에 오늘 일정과 작성할 작업 일지를 확인하라고 알려 줍니다.",
                    ),
                  ),
                  value: morningOn,
                  onChanged: (v) => setS(() => morningOn = v),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  enabled: morningOn,
                  title: const Text("아침 요약 시간"),
                  trailing: Text(
                    hm(morningMinutes),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  onTap: !morningOn
                      ? null
                      : () async {
                          final t = await showTimePicker(
                            context: ctx,
                            initialTime: TimeOfDay(
                              hour: morningMinutes ~/ 60,
                              minute: morningMinutes % 60,
                            ),
                          );
                          if (t != null) {
                            setS(() => morningMinutes = t.hour * 60 + t.minute);
                          }
                        },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  enabled: enabled,
                  title: const Text("알림 시간"),
                  trailing: Text(
                    keepWords(
                      "${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}",
                    ),
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("취소"),
            ),
            TextButton(
              onPressed: () async {
                await saveReportReminder(
                  enabled,
                  minutes,
                  weekly: weekly,
                  weeklyMinutes: weeklyMinutes,
                  autoPdf: autoPdf,
                );
                await saveMorningSummary(morningOn, morningMinutes);
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
    final newLog = await CreateLogSheet.show(context, existingLogs: _workLogs);
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
      WorkRoute(
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
      // 삭제한 프로젝트에 걸려 있던 작업 일지 알림이 남지 않도록 바로 다시 맞춘다.
      syncReportReminder(_workLogs);
    },
  );

  Future<void> _openReportFor(
    Map<String, dynamic> log,
    Map<String, dynamic> report,
  ) async {
    // 확정된 작업 일지는 사유를 남기고 확정을 풀어야 수정할 수 있다.
    if (report['locked'] == true) {
      final reasonCtrl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("확정된 작업 일지입니다"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(keepWords("수정하려면 확정을 풀어야 하고, 사유가 기록으로 남습니다.")),
              const SizedBox(height: 10),
              TextField(
                controller: reasonCtrl,
                maxLines: 2,
                decoration: const InputDecoration(hintText: "확정 해제 사유"),
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
              child: const Text("확정 풀고 수정"),
            ),
          ],
        ),
      );
      if (ok != true) return;
      final hist = List<dynamic>.from(report['unlockHistory'] as List? ?? [])
        ..add({
          'reason': reasonCtrl.text.trim().isEmpty
              ? '사유 미입력'
              : reasonCtrl.text.trim(),
          'at': DateTime.now(),
        });
      setState(() {
        report['locked'] = false;
        report.remove('lockedAt');
        report['unlockHistory'] = hist;
      });
      _saveProject(log);
    }
    if (!mounted) return;
    final updated = await Navigator.push<Map<String, dynamic>>(
      context,
      WorkRoute(
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
        final list = (log['daily_reports'] ??= <dynamic>[]) as List;
        final idx = list.indexOf(report);
        if (report['unlockHistory'] != null) {
          updated['unlockHistory'] = report['unlockHistory'];
        }
        if (idx != -1) list[idx] = updated;
        applyReportEffects(log, updated);
      });
      _saveProject(log);
      _uploadReportPhotosFor(log, updated);
    }
  }

  Future<void> _openReportCalendarFor(Map<String, dynamic> log) async {
    final updated = await Navigator.push<List<Map<String, dynamic>>>(
      context,
      WorkRoute(
        builder: (context) => DailyReportCalendarPage(
          projectName: log['name'] ?? '이름 없음',
          initialReports: List<Map<String, dynamic>>.from(
            log['daily_reports'] ?? [],
          ),
        ),
      ),
    );
    if (updated != null) {
      // 달력에서 고친 일지도 일지 탭과 같이 일정·이슈에 반영하고 사진을 올린다.
      final before = List<Map<String, dynamic>>.from(
        log['daily_reports'] ?? [],
      );
      setState(() {
        log['daily_reports'] = updated;
        for (final r in updated) {
          if (!before.contains(r)) applyReportEffects(log, r);
        }
      });
      _saveProject(log);
      _uploadReportPhotosFor(log, const {});
    }
  }

  Future<void> _addPunchFor(Map<String, dynamic> log) async {
    // 같은 프로젝트에서 최근에 쓴 위치를 최신순으로 추려서 넘긴다(최대 6개).
    final List<String> recentLocations = [];
    for (final p in (log['punch_lists'] as List<dynamic>? ?? [])) {
      final loc = p['location']?.toString();
      if (loc != null &&
          loc.isNotEmpty &&
          loc != '위치 모름' &&
          !recentLocations.contains(loc)) {
        recentLocations.add(loc);
      }
      if (recentLocations.length >= 6) break;
    }
    final newPunch = await Navigator.push<Map<String, dynamic>>(
      context,
      WorkRoute(
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
      setState(
        () =>
            ((log['punch_lists'] ??= <dynamic>[]) as List).insert(0, newPunch),
      );
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
      case 'stale':
        // 마지막 작업 일지가 오래된(또는 없는) 프로젝트를 위로 - 작업 일지를 빠뜨린 곳 찾기.
        DateTime? lastOf(Map<String, dynamic> l) {
          DateTime? last;
          for (final r
              in (l['daily_reports'] as List? ?? []).whereType<Map>()) {
            final d = reportDateOf(r);
            if (last == null || d.isAfter(last)) last = d;
          }
          return last;
        }
        out.sort((a, b) {
          final da = lastOf(a), db = lastOf(b);
          if (da == null && db == null) return 0;
          if (da == null) return -1;
          if (db == null) return 1;
          return da.compareTo(db);
        });
        break;
      default:
        out.sort((a, b) {
          final da = projectDue(a), db = projectDue(b);
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return da.compareTo(db);
        });
    }
    var res = out;
    if (_showCompleted && _nameFilter.trim().isNotEmpty) {
      final q = _nameFilter.trim().toLowerCase();
      res = res
          .where((l) => (l['name']?.toString() ?? '').toLowerCase().contains(q))
          .toList();
    }
    if (_issueFilterOn) res = withOpenIssues(res);
    return res;
  }

  // 완료된 프로젝트 중 미해결 이슈가 남은 것만 보기. 그런 프로젝트가 없어지면
  // (이슈를 다 처리하면) 필터는 저절로 꺼진다 - 끌 칩이 사라져도 목록이 비지 않게.
  bool _onlyOpenIssueDone = false;
  bool get _issueFilterOn =>
      _showCompleted &&
      !_showArchived &&
      _onlyOpenIssueDone &&
      withOpenIssues(_doneLogs).isNotEmpty;

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
          if (!_showArchived && withOpenIssues(_doneLogs).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: FilterChip(
                label: Text(
                  keepWords(
                    "이슈 남은 프로젝트만 (${withOpenIssues(_doneLogs).length})",
                  ),
                ),
                selected: _issueFilterOn,
                showCheckmark: false,
                selectedColor: tossBlue.withValues(alpha: 0.15),
                backgroundColor: pureWhite,
                side: BorderSide.none,
                labelStyle: TextStyle(
                  color: _issueFilterOn ? tossBlue : tossSubText,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                onSelected: (v) => setState(() => _onlyOpenIssueDone = v),
              ),
            ),
          Row(
            children: [
              if (!_selectProjects)
                TextButton.icon(
                  onPressed: () => setState(() => _selectProjects = true),
                  icon: const Icon(Icons.checklist_rounded, size: 18),
                  label: const Text("선택해서 통합 보고서"),
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
                    keepWords("${_selProjects.length}건 내보내기"),
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
        ).showSnackBar(SnackBar(content: Text(keepWords("내보내기 실패: $e"))));
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
      WorkRoute(
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
  List<Map<String, dynamic>> get _projectsMissingTodayReport =>
      projectsMissingReport(_activeLogs, _todayMmDd());

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
      WorkRoute(
        builder: (context) => PunchDetailPage(
          punch: punch,
          inspectionSchedules: inspectionSchedules,
          floorPlanImagePath: log['floor_plan_image_path'],
        ),
      ),
    );
    if (updated != null) {
      setState(() {
        final list = (log['punch_lists'] ??= <dynamic>[]) as List;
        final idx = list.indexOf(punch);
        if (idx != -1) list[idx] = updated;
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
  // 작업 일지에서 "오늘 끝낸 일정"으로 고를 수 있는 일정: 미완료 + (수정 중인
  // 작업 일지에서 이미 체크한 것). 검사일정은 별도 흐름이라 제외.
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

  // 완료된 프로젝트 카드를 길게 누르면: 마무리 보고서를 다시 만든다.
  Future<void> _showDoneActions(Map<String, dynamic> log) async {
    final pick = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: pureWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "${log['name'] ?? '프로젝트'} (완료)",
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text("마무리 보고서 다시 만들기"),
              subtitle: const Text("사진 포함 PDF"),
              onTap: () => Navigator.pop(ctx, 'final'),
            ),
          ],
        ),
      ),
    );
    if (pick != 'final' || !mounted) return;
    try {
      final r = await shareReportPdf(
        buildFinalReportDoc(log),
        withPhotos: true,
      );
      recordFinalReportShare(log, r.status);
      _saveProject(log);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(keepWords(pdfShareNotice(r.status, '마무리 보고서'))),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(keepWords("PDF 생성 실패: $e"))));
      }
    }
  }

  // 프로젝트 카드를 길게 누르면 자주 하는 작업으로 바로 간다.
  Future<void> _showQuickActions(Map<String, dynamic> log) async {
    final pick = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: pureWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "${log['name'] ?? '프로젝트'}",
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_note_rounded),
              title: const Text("오늘 작업 일지 작성"),
              onTap: () => Navigator.pop(ctx, 'report'),
            ),
            ListTile(
              leading: const Icon(Icons.error_outline_rounded),
              title: const Text("이슈 등록"),
              onTap: () => Navigator.pop(ctx, 'issue'),
            ),
            ListTile(
              leading: const Icon(Icons.event_available_rounded),
              title: const Text("일정 추가"),
              onTap: () => Navigator.pop(ctx, 'schedule'),
            ),
          ],
        ),
      ),
    );
    if (pick == null || !mounted) return;
    if (pick == 'report') await _addDailyReportFor(log);
    if (pick == 'issue') await _addPunchFor(log);
    if (pick == 'schedule') await _openSchedule(log, add: true);
  }

  Future<void> _addDailyReportFor(Map<String, dynamic> log) async {
    final newReport = await Navigator.push<Map<String, dynamic>>(
      context,
      WorkRoute(
        builder: (context) => DailyReportPage(
          previousReport: _previousReportFor(log),
          previousReports: [
            for (final r in (log['daily_reports'] as List<dynamic>? ?? []))
              Map<String, dynamic>.from(r as Map),
          ],
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
        ((log['daily_reports'] ??= <dynamic>[]) as List).insert(0, newReport);
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
  Future<void> _shareOverviewImage() async {
    try {
      final f = await createOverviewImage(_workLogs);
      // ignore: deprecated_member_use
      await Share.shareXFiles([XFile(f.path)], text: '오늘의 전체 현황');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(keepWords("이미지 만들기 실패: $e"))));
      }
    }
  }

  bool _backupFailed = false;

  Future<void> _runAutoBackup() async {
    final r = await autoBackupIfDue(_workLogs);
    if (r != null && mounted) setState(() => _backupFailed = r == false);
  }

  // 금~일에는 주간 보고서 초안을 바로 만들 수 있는 카드를 보여준다.
  void _openWeeklyReport() {
    Navigator.push(
      context,
      WorkRoute(
        builder: (_) => WeeklyReportPage(
          logs: _workLogs,
          onOpenProject: (log) => _openDetail(log),
          onOpenIssue: (log, p) =>
              _openPunchDetail(log, p as Map<String, dynamic>),
          onIssueChanged: (log) => _saveProject(log),
        ),
      ),
    );
  }

  // 처음 쓰는 사람을 위한 안내 카드(한 번 확인하면 다시 안 뜬다). 메뉴의 "사용 안내"로
  // 언제든 다시 볼 수 있다.
  bool _showGuide = false;

  bool _showNotifHint = false;
  String? _reminderProblem; // 알림 예약이 안 맞을 때의 안내 문구
  bool _problemPreview = false; // 점검 화면에서 "미리 보기"로 띄운 카드인지

  Future<void> _loadGuideFlag() async {
    try {
      final p = await SharedPreferences.getInstance();
      final seen = p.getBool('work_guide_seen_v1') ?? false;
      if (!seen && mounted) setState(() => _showGuide = true);
      // 사용 안내를 이미 본 사람에게는, 알림 점검을 한 번도 안 열어 봤다면 알려 준다.
      final checked = p.getBool('notif_check_seen') ?? false;
      if (seen && !checked && mounted) setState(() => _showNotifHint = true);
    } catch (_) {}
  }

  // 알림 점검 화면을 연다. "안내 카드 미리 보기"로 닫히면 예약 문제 카드를 미리 보기로 띄우고,
  // 그 밖에는 돌아온 뒤 예약 상태를 다시 확인해 카드를 갱신한다.
  Future<void> _openNotifCheck() async {
    final res = await Navigator.push<String>(
      context,
      WorkRoute(
        builder: (_) => NotificationCheckPage(
          logs: _workLogs,
          onSaveProject: (log) async {
            await _repo.upsertProject(log);
            await syncReportReminder(_workLogs);
          },
        ),
      ),
    );
    if (!mounted) return;
    if (res == kPreviewProblem) {
      setState(() {
        _problemPreview = true;
        _reminderProblem = reminderCountMismatch(2, 0);
      });
      return;
    }
    final m = await dailyReminderProblem(_workLogs);
    if (mounted) {
      setState(() {
        _problemPreview = false;
        _reminderProblem = m;
      });
    }
  }

  Future<void> _dismissNotifHint({bool open = false}) async {
    setState(() => _showNotifHint = false);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('notif_check_seen', true);
    } catch (_) {}
    if (open && mounted) await _openNotifCheck();
  }

  Widget _buildReminderProblemCard() {
    final msg = _reminderProblem;
    if (msg == null) return const SizedBox.shrink();
    return ReminderProblemCard(
      message: msg,
      preview: _problemPreview,
      onOpenCheck: _openNotifCheck,
      onRetry: () => resyncRemindersAndCheck(_workLogs),
      onRetried: (still) {
        if (!mounted) return;
        setState(() {
          _problemPreview = false;
          _reminderProblem = still;
        });
      },
    );
  }

  Widget _buildNotifHintCard() {
    if (!_showNotifHint) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tossBlue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            keepWords("작업 일지·주간 보고 알림이 제때 오는지 확인해 보십시오"),
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            keepWords("폰 절전 기능 때문에 예약 알림이 안 올 수 있습니다. '알림 점검'에서 상태를 볼 수 있습니다."),
            style: TextStyle(fontSize: 12, height: 1.4, color: tossSubText),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => _dismissNotifHint(),
                child: const Text("나중에"),
              ),
              TextButton(
                onPressed: () => _dismissNotifHint(open: true),
                child: const Text(
                  "알림 점검 열기",
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _dismissGuide() async {
    setState(() => _showGuide = false);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('work_guide_seen_v1', true);
    } catch (_) {}
  }

  static const List<String> _guideTips = [
    "프로젝트를 만들고 '단계·일정' 탭에서 표준 단계로 시작하십시오. 기간에 맞춰 자동으로 나눠 줍니다.",
    "매일 '일지 작성'에 작업 내용·사진·처리한 이슈를 남기면 진행률과 통계에 쌓입니다.",
    "자재는 입고일이 미정이어도 먼저 등록하고, 날짜가 정해지면 채우십시오. 지연되면 알려 줍니다.",
    "금요일엔 '주간 보고'로 이번 주 업무를 한 번에 공유하십시오.",
    "⋮ 메뉴에서 보고서 양식, 백업, 저장 공간 관리를 할 수 있습니다.",
  ];

  Widget _buildGuideCard() {
    if (!_showGuide) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tossBlue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: tossBlue, size: 18),
              SizedBox(width: 6),
              Text(
                "이렇게 쓰면 편합니다",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: tossText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final t in _guideTips)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                "• $t",
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: tossSubText,
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _dismissGuide,
              child: const Text(
                "확인했습니다",
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showGuideSheet() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: pureWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "내 프로젝트 사용 안내",
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
              const SizedBox(height: 10),
              for (final t in _guideTips)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text("• $t", style: const TextStyle(height: 1.4)),
                ),
            ],
          ),
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
              WorkRoute(
                builder: (_) =>
                    ProjectStatsPage(logs: _workLogs, title: "전체 투입 통계"),
              ),
            ),
          ),
          IconButton(
            tooltip: "작업 일지·이슈 검색",
            icon: const Icon(Icons.search_rounded),
            onPressed: _openSearch,
          ),
          PopupMenuButton<String>(
            tooltip: "더보기",
            onSelected: (v) {
              if (v == 'reminder') _showReminderSettings();
              if (v == 'weekly') _openWeeklyReport();
              if (v == 'guide') _showGuideSheet();
              if (v == 'notif') _openNotifCheck();
              if (v == 'overview') _shareOverviewImage();
              if (v == 'style') {
                Navigator.push(
                  context,
                  WorkRoute(builder: (_) => const ReportStylePage()),
                );
              }
              if (v == 'storage') {
                Navigator.push(
                  context,
                  WorkRoute(
                    builder: (_) => StorageManagementPage(
                      logs: _workLogs,
                      onRestored: _loadData,
                    ),
                  ),
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'weekly', child: Text("주간 업무 보고")),
              PopupMenuItem(value: 'reminder', child: Text("작업 일지·주간 알림 설정")),
              PopupMenuItem(value: 'overview', child: Text("전체 현황 이미지 공유")),
              PopupMenuItem(value: 'style', child: Text("보고서 양식 설정")),
              PopupMenuItem(value: 'storage', child: Text("저장 공간 관리")),
              PopupMenuItem(value: 'notif', child: Text("알림 점검")),
              PopupMenuItem(value: 'guide', child: Text("사용 안내")),
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
                  'due': '납기 빠른 순',
                  'progress': '진행률 낮은순',
                  'recent': '최근 등록순',
                  'stale': '작업 일지 오래된 순',
                };
                // 요약 카드/필터는 목록과 같이 스크롤된다(예전엔 위에 고정돼서
                // 오늘 할 일이 많으면 프로젝트 목록이 좁은 창에 갇혔다).
                final header = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGuideCard(),
                    _buildNotifHintCard(),
                    _buildReminderProblemCard(),
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
                            label: const Text('결과 정리 모아보기'),
                            backgroundColor: pureWhite,
                            side: BorderSide.none,
                            labelStyle: const TextStyle(
                              color: tossBlue,
                              fontWeight: FontWeight.bold,
                            ),
                            onPressed: () => Navigator.push(
                              context,
                              WorkRoute(
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
                              : "아직 등록된 작업 기록이 없습니다.\n아래 버튼을 눌러 새로 시작해 보십시오.",
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
                              onLongPress: () => _isActive(log)
                                  ? _showQuickActions(log)
                                  : _showDoneActions(log),
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
