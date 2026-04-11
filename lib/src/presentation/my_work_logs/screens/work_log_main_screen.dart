import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // debugPrint 사용을 위해 추가
import 'package:hive_flutter/hive_flutter.dart';

// 🚀 [수정됨] Dialog가 아니라 새로 만든 Page를 임포트합니다.
// 경로가 본인 프로젝트 폴더와 맞는지 꼭 확인해 주세요!
import '../widgets/create_log_sheet.dart';
import '../widgets/work_log_card.dart';
import '../pages/daily_report_page.dart'; // 다이얼로그 대신 Page 임포트
import '../pages/punch_list_page.dart'; // 다이얼로그 대신 Page 임포트

// 토스 스타일 색상 팔레트
const Color tossBlue = Color(0xFF3182F6);
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
  final Box _myBox = Hive.box('projectsBox');
  List<Map<String, dynamic>> _workLogs = [];
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final String? jsonString = _myBox.get('projectList');
    if (jsonString != null) {
      final List<dynamic> decoded = jsonDecode(jsonString);
      setState(() {
        _workLogs = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      });
    }
  }

  void _saveData() {
    _myBox.put('projectList', jsonEncode(_workLogs));
  }

  void _showCreateSheet() async {
    final newLog = await CreateLogSheet.show(context);
    if (newLog != null) {
      setState(() {
        _workLogs.insert(0, newLog);
        _saveData();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tossBg, // 토스 스타일 옅은 회색 배경
      appBar: AppBar(
        title: const Text(
          '내 작업 보관함',
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
      body: _workLogs.isEmpty
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
                  onOpenCalculator: () {
                    // 🚀 [에러 해결] print 대신 debugPrint 사용
                    debugPrint("계산기 화면으로 이동");
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
                        _saveData();
                      });
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
                      setState(() {
                        log['punch_lists'].insert(0, newPunch);
                        _saveData();
                      });
                    }
                  },
                  onDelete: () {
                    setState(() {
                      _workLogs.removeAt(index);

                      // 🚀 [에러 해결] if문 중괄호 추가 적용
                      if (_expandedIndex == index) {
                        _expandedIndex = null;
                      } else if (_expandedIndex != null &&
                          _expandedIndex! > index) {
                        _expandedIndex = _expandedIndex! - 1;
                      }

                      _saveData();
                    });
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
