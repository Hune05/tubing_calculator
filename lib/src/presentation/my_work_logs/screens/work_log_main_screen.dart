import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // debugPrint 사용을 위해 추가

// 🚀 [수정됨] Dialog가 아니라 새로 만든 Page를 임포트합니다.
// 경로가 본인 프로젝트 폴더와 맞는지 꼭 확인해 주세요!
import '../widgets/create_log_sheet.dart';
import '../widgets/work_log_card.dart';
import '../pages/daily_report_page.dart'; // 다이얼로그 대신 Page 임포트
import '../pages/punch_list_page.dart'; // 다이얼로그 대신 Page 임포트
import '../pages/project_schedule_page.dart';
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
          : _workLogs.isEmpty
          ? const Center(
              child: Text(
                "아직 등록된 작업 기록이 없어요.\n아래 버튼을 눌러 새로 시작해 보세요.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: tossSubText,
                  height: 1.5,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(
                top: 16,
                left: 16,
                right: 16,
                bottom: 100,
              ),
              itemCount: _workLogs.length,
              itemBuilder: (context, index) {
                final log = _workLogs[index];
                final bool isExpanded = _expandedIndex == index;

                return WorkLogCard(
                  log: log,
                  isExpanded: isExpanded,
                  onToggleExpand: () {
                    setState(() {
                      _expandedIndex = isExpanded ? null : index;
                    });
                  },
                  // 🚀 [수정] 예전엔 debugPrint만 찍던 죽은 "계산기" 버튼을
                  // "일정 관리"로 교체 - 자재 요청/입고일/납기일/검사일정을
                  // 등록해두면 서버가 알림을 보내준다.
                  onOpenSchedule: () async {
                    final updated =
                        await Navigator.push<List<Map<String, dynamic>>>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProjectSchedulePage(
                              projectName: log['name'] ?? '이름 없음',
                              initialSchedules:
                                  List<Map<String, dynamic>>.from(
                                    log['schedules'] ?? [],
                                  ),
                            ),
                          ),
                        );
                    if (updated != null) {
                      setState(() {
                        log['schedules'] = updated;
                      });
                      _saveProject(log);
                    }
                  },
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

                  onAddPunchList: () async {
                    // 🚀 Navigator.push를 사용하여 전체 화면 페이지로 이동
                    final newPunch = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PunchListPage(),
                      ),
                    );

                    if (newPunch != null) {
                      // 🚀 [추가] 이슈가 처리될 때까지 매일 알림을 보내기
                      // 위한 식별자/플래그. 등록일 기준으로 "며칠째
                      // 미해결"인지 계산하고, 하루 1회만 보내도록
                      // lastPunchReminderDate로 중복 발송을 막는다
                      // (자재 발주/일정 알림과 동일한 패턴).
                      newPunch['id'] = DateTime.now()
                          .millisecondsSinceEpoch
                          .toString();
                      newPunch['created_at'] = DateTime.now();
                      newPunch['lastPunchReminderDate'] = null;
                      setState(() {
                        log['punch_lists'].insert(0, newPunch);
                      });
                      _saveProject(log);
                    }
                  },
                  onTogglePunchComplete: (punch) {
                    setState(() {
                      punch['is_completed'] = !(punch['is_completed'] == true);
                    });
                    _saveProject(log);
                  },
                  onDelete: () {
                    final deletedId = log['id']?.toString();
                    setState(() {
                      _workLogs.removeAt(index);

                      // 🚀 [에러 해결] if문 중괄호 추가 적용
                      if (_expandedIndex == index) {
                        _expandedIndex = null;
                      } else if (_expandedIndex != null &&
                          _expandedIndex! > index) {
                        _expandedIndex = _expandedIndex! - 1;
                      }
                    });
                    if (deletedId != null) {
                      _repo.deleteProject(deletedId);
                    }
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
