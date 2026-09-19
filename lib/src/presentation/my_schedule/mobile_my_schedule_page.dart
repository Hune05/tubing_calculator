import '../my_work_logs/widgets/work_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

import 'package:tubing_calculator/main.dart'
    show flutterLocalNotificationsPlugin;
import '../../data/repositories/work_project_repository.dart';
import '../../core/common_widgets/makita_time_picker.dart';
import '../my_work_logs/screens/work_log_main_screen.dart';
import '../my_work_logs/models/project_phase.dart' show colorForProject;

// 🚀 [신규] "내 일정 관리" - 마키타 틸 팔레트로 앱 전체와 통일.
const Color scheduleTeal = Color(0xFF007580);
const Color scheduleTealDark = Color(0xFF004D54);
const Color scheduleBg = Color(0xFFF2F4F6);
const Color scheduleText = Color(0xFF191F28);
const Color scheduleSubText = Color(0xFF8B95A1);
const Color scheduleWhite = Colors.white;
const Color scheduleDanger = Color(0xFFE0432B);

const String kPersonalSchedulesCollection = 'personal_schedules';
const String kScheduleTemplatesCollection = 'schedule_templates';
const String kScheduleChannelId = 'personal_schedule_channel';

// 🚀 [통합형] 프로젝트 안의 일정(자재 요청/입고일/납기일/검사일정)과 이
// 화면에서 새로 만드는 개인 일정(개인/영업/기타)을 같은 색 체계로
// 묶어서, 어디서 온 일정이든 색만 보고 종류를 바로 구분할 수 있게 한다.
const List<String> kPersonalCategories = [
  "개인",
  "영업",
  "출장",
  "자재 요청",
  "납기일",
  "검사일정",
  "기타",
];

const Map<String, Color> kScheduleColors = {
  '개인': scheduleTeal,
  '영업': Color(0xFFC77700),
  '출장': Color(0xFF0E9AA7),
  '자재 요청': Color(0xFF8E63CE),
  '입고일': Color(0xFF2F80ED),
  '납기일': Color(0xFFE0432B),
  '검사일정': Color(0xFF1D8A4E),
  '기타': Color(0xFF8B95A1),
};

// 🚀 [프로젝트별 색] 여러 프로젝트가 동시에 진행돼도 달력에서 구분되도록,
// 프로젝트 ID로 고정된 색을 배정한다(같은 프로젝트는 언제나 같은 색).
Color colorForCategory(String cat) =>
    kScheduleColors[cat] ?? kScheduleColors['기타']!;

IconData iconForCategory(String cat) {
  switch (cat) {
    case '개인':
      return Icons.person_outline_rounded;
    case '영업':
      return Icons.handshake_outlined;
    case '출장':
      return Icons.flight_takeoff_rounded;
    case '자재 요청':
      return Icons.local_shipping_outlined;
    case '입고일':
      return Icons.inventory_2_outlined;
    case '납기일':
      return Icons.event_available_outlined;
    case '검사일정':
      return Icons.fact_check_outlined;
    default:
      return Icons.event_note_outlined;
  }
}

const Map<int, String> kReminderOptions = {
  0: "알림 없음",
  30: "30분 전",
  60: "1시간 전",
  1440: "하루 전",
};

const Map<String, String> kRecurrenceLabels = {
  'none': "반복 없음",
  'weekly': "매주 반복",
  'monthly': "매월 반복",
};

enum _ViewMode { month, week, day, timeline }

// 🚀 달력 위에 표시되는 "일정 한 건"을 표현하는 값 - 프로젝트 일정과
// 개인 일정(그리고 반복 일정이 펼쳐진 각 회차)을 같은 모양으로 다뤄서
// 달력/목록 코드가 출처를 신경 쓰지 않고 그릴 수 있게 한다.
class _AgendaItem {
  final String key;
  final DateTime date;
  final bool hasTime;
  final String title;
  final String category;
  final bool isCompleted;
  final bool isPersonal;
  final String? personalDocId;
  final String? projectId;
  final String? projectName;
  final String? scheduleId;
  final String recurrence;
  // 기간 일정의 몇 번째 날인지(0부터)와 전체 일수 - 달력에 이어진 막대를
  // 그릴 때 시작/끝을 알아내는 데 쓴다.
  final int spanIndex;
  final int spanTotal;
  final String? spanKey;

  // 프로젝트 일정은 프로젝트 고유색, 개인 일정은 카테고리색.
  Color get color => projectId != null
      ? colorForProject(projectId!)
      : colorForCategory(category);

  // "제목 (2/3일)"에서 뒤의 일차 표시를 뺀 원래 제목 - 막대 위 글자용.
  String get baseTitle => title.replaceFirst(RegExp(r' \(\d+/\d+일\)$'), '');

  const _AgendaItem({
    required this.key,
    required this.date,
    required this.hasTime,
    required this.title,
    required this.category,
    required this.isCompleted,
    required this.isPersonal,
    this.personalDocId,
    this.projectId,
    this.projectName,
    this.scheduleId,
    this.recurrence = 'none',
    this.spanIndex = 0,
    this.spanTotal = 1,
    this.spanKey,
  });
}

class _TlEvent {
  final DateTime start;
  final int len;
  final _AgendaItem item;
  int lane = 0;
  _TlEvent(this.start, this.len, this.item);
}

class _TlRow {
  final String label;
  final Color color;
  final List<_TlEvent> events = [];
  int laneCount = 1;
  _TlRow(this.label, this.color);
}

class MobileMyScheduleScreen extends StatefulWidget {
  // 🚀 모바일 메뉴에서는 이미 알고 있는 currentWorker를 바로 넘겨주고,
  // 태블릿 그리드 메뉴처럼 이 값을 모르는 경로로 들어오면 null을 받아
  // SharedPreferences에서 직접 읽는다.
  final String? currentWorker;

  const MobileMyScheduleScreen({super.key, this.currentWorker});

  @override
  State<MobileMyScheduleScreen> createState() => _MobileMyScheduleScreenState();
}

class _MobileMyScheduleScreenState extends State<MobileMyScheduleScreen> {
  String _currentWorker = "로그인 필요";
  _ViewMode _viewMode = _ViewMode.month;
  DateTime? _tlStart;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  final WorkProjectRepository _projectRepo = WorkProjectRepository();
  List<Map<String, dynamic>> _projects = [];
  bool _loadingProjects = true;

  static bool _tzReady = false;
  bool _channelReady = false;

  // 🚀 [2번 강화] 카테고리는 다중 선택(빈 집합 = 전체 표시), 프로젝트는
  // 단일 선택(null = 전체 프로젝트)으로 좁혀본다.
  final Set<String> _activeCategoryFilters = {};
  String? _activeProjectFilter;

  @override
  void initState() {
    super.initState();
    _initTimeZone();
    _loadCurrentWorker();
    _loadProjects();
  }

  Future<void> _initTimeZone() async {
    if (_tzReady) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    _tzReady = true;
  }

  Future<void> _loadCurrentWorker() async {
    if (widget.currentWorker != null && widget.currentWorker!.isNotEmpty) {
      setState(() => _currentWorker = widget.currentWorker!);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('user_real_name');
    if (saved != null && saved.isNotEmpty && mounted) {
      setState(() => _currentWorker = saved);
    }
  }

  Future<void> _loadProjects() async {
    try {
      final projects = await _projectRepo.fetchAllProjects();
      if (!mounted) return;
      setState(() {
        _projects = projects;
        _loadingProjects = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingProjects = false);
    }
  }

  DateTime _normalize(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _asDateTime(dynamic v) {
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  // 🚀 [1번 강화] 완료 안 된 채로 시각(또는 종일이면 그 날 자정)이 이미
  // 지난 일정 - 놓친 일정을 놓치지 않고 알아채도록 목록에서 강조한다.
  bool _isOverdue(_AgendaItem item) {
    if (item.isCompleted) return false;
    final now = DateTime.now();
    return item.hasTime
        ? item.date.isBefore(now)
        : _normalize(item.date).isBefore(_normalize(now));
  }

  // 🚀 [2번 강화] 카테고리(다중)/프로젝트(단일) 필터를 적용한다. 둘 다
  // 선택 안 하면(빈 집합/null) 전체를 보여준다.
  List<_AgendaItem> _applyFilters(List<_AgendaItem> items) {
    return items.where((item) {
      if (_activeCategoryFilters.isNotEmpty &&
          !_activeCategoryFilters.contains(item.category)) {
        return false;
      }
      if (_activeProjectFilter != null &&
          item.projectId != _activeProjectFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  // 🚀 "내 프로젝트"의 schedules[] 안에서 날짜가 있는 항목만 뽑아
  // 달력용 항목으로 바꾼다. 여러 워커가 같은 프로젝트를 보는 이 앱의
  // 특성상, 프로젝트 일정은 개인 소유자 구분 없이 전부 보여준다(기존
  // "내 프로젝트" 화면도 워커별로 나뉘어 있지 않다).
  List<_AgendaItem> _projectAgendaItems() {
    final List<_AgendaItem> items = [];
    for (final project in _projects) {
      final schedules = (project['schedules'] as List<dynamic>? ?? []);
      for (final raw in schedules) {
        final s = Map<String, dynamic>.from(raw as Map);
        if (s['dateTime'] == null) continue;
        final date = _asDateTime(s['dateTime']);
        final category = (s['type'] as String?) ?? '기타';
        final rawTitle = (s['title'] as String?)?.trim();
        final String baseTitle = (rawTitle != null && rawTitle.isNotEmpty)
            ? rawTitle
            : category;
        // 🚀 [기간 일정] 프로젝트 일정도 endDate가 있으면 하루씩 펼쳐서
        // 달력에 이어진 막대로 보이게 한다.
        final DateTime startDay = DateTime(date.year, date.month, date.day);
        final DateTime? rawEnd = s['endDate'] != null
            ? _asDateTime(s['endDate'])
            : null;
        final DateTime endDay = rawEnd != null
            ? DateTime(rawEnd.year, rawEnd.month, rawEnd.day)
            : startDay;
        int totalDays = endDay.isBefore(startDay)
            ? 1
            : (endDay.difference(startDay).inHours / 24).round() + 1;
        if (totalDays > 120) totalDays = 1;
        for (int i = 0; i < totalDays; i++) {
          items.add(
            _AgendaItem(
              key: totalDays > 1
                  ? 'proj_${project['id']}_${s['id']}_d$i'
                  : 'proj_${project['id']}_${s['id']}',
              date: i == 0
                  ? date
                  : DateTime(startDay.year, startDay.month, startDay.day + i),
              hasTime: i == 0,
              title: totalDays > 1
                  ? '$baseTitle (${i + 1}/$totalDays일)'
                  : baseTitle,
              category: category,
              isCompleted: s['isCompleted'] == true,
              isPersonal: false,
              projectId: project['id']?.toString(),
              projectName: (project['name'] as String?) ?? '이름 없음',
              scheduleId: s['id']?.toString(),
              spanIndex: i,
              spanTotal: totalDays,
              spanKey: totalDays > 1
                  ? 'proj_${project['id']}_${s['id']}'
                  : null,
            ),
          );
        }
      }
    }
    return items;
  }

  // 🚀 [반복 일정] 개인 일정 문서 하나를 실제 화면에 뿌릴 "회차" 목록으로
  // 펼친다. 반복이 없으면 회차 1개, 매주/매월이면 지난 1년~앞으로 2년
  // 범위 안에서 회차를 전부 만들어 달력에 마커가 계속 찍히게 한다.
  List<_AgendaItem> _expandPersonalItem(
    String docId,
    Map<String, dynamic> data,
  ) {
    final DateTime base = _asDateTime(data['dateTime']);
    final String recurrence = (data['recurrence'] as String?) ?? 'none';
    final String category = (data['category'] as String?) ?? '개인';
    final String title = (data['title'] as String?)?.trim().isNotEmpty == true
        ? data['title'] as String
        : '제목 없음';
    final bool hasTime = data['hasTime'] != false;
    final Map<String, dynamic> completedMap = Map<String, dynamic>.from(
      data['completedOccurrences'] as Map? ?? {},
    );

    if (recurrence == 'none') {
      // 🚀 [기간 일정] 출장처럼 여러 날에 걸친 일정은 endDate(마지막 날)까지
      // 하루씩 펼쳐서, 달력 마커/오늘 일정/목록이 매일 자연스럽게 잡히게
      // 한다. 시간은 첫날에만 있고 이후 날은 종일로 취급한다.
      final DateTime startDay = DateTime(base.year, base.month, base.day);
      final DateTime? rawEnd = data['endDate'] != null
          ? _asDateTime(data['endDate'])
          : null;
      final DateTime endDay = rawEnd != null
          ? DateTime(rawEnd.year, rawEnd.month, rawEnd.day)
          : startDay;
      final int totalDays = endDay.isBefore(startDay)
          ? 1
          : (endDay.difference(startDay).inHours / 24).round() + 1;
      if (totalDays > 1 && totalDays <= 120) {
        return List.generate(totalDays, (i) {
          final DateTime day = DateTime(
            startDay.year,
            startDay.month,
            startDay.day + i,
          );
          return _AgendaItem(
            key: 'personal_${docId}_d$i',
            date: i == 0 ? base : day,
            hasTime: i == 0 ? hasTime : false,
            title: '$title (${i + 1}/$totalDays일)',
            category: category,
            isCompleted: data['isCompleted'] == true,
            isPersonal: true,
            personalDocId: docId,
            recurrence: recurrence,
            spanIndex: i,
            spanTotal: totalDays,
            spanKey: docId,
          );
        });
      }
      return [
        _AgendaItem(
          key: 'personal_$docId',
          date: base,
          hasTime: hasTime,
          title: title,
          category: category,
          isCompleted: data['isCompleted'] == true,
          isPersonal: true,
          personalDocId: docId,
          recurrence: recurrence,
        ),
      ];
    }

    final DateTime rangeStart = DateTime(DateTime.now().year - 1, 1, 1);
    final DateTime rangeEnd = DateTime(DateTime.now().year + 2, 12, 31);
    final List<_AgendaItem> occurrences = [];
    DateTime cursor = base;
    int guard = 0;
    while (!cursor.isAfter(rangeEnd) && guard < 400) {
      guard++;
      if (!cursor.isBefore(rangeStart)) {
        final occKey = _normalize(cursor).toIso8601String();
        occurrences.add(
          _AgendaItem(
            key: 'personal_${docId}_$occKey',
            date: cursor,
            hasTime: hasTime,
            title: title,
            category: category,
            isCompleted: completedMap[occKey] == true,
            isPersonal: true,
            personalDocId: docId,
            recurrence: recurrence,
          ),
        );
      }
      cursor = recurrence == 'weekly'
          ? cursor.add(const Duration(days: 7))
          : DateTime(
              cursor.year,
              cursor.month + 1,
              cursor.day,
              cursor.hour,
              cursor.minute,
            );
    }
    return occurrences;
  }

  // 🚀 [3번 강화] 프로젝트 유래 일정 카드에서 바로 "내 프로젝트"의 해당
  // 프로젝트 일정 관리(ProjectSchedulePage)로 이동한다.
  void _openProjectSchedule(String? projectId) {
    if (projectId == null) return;
    Navigator.push(
      context,
      WorkRoute(
        builder: (context) => WorkLogMainScreen(initialProjectId: projectId),
      ),
    ).then((_) => _loadProjects());
  }

  Future<void> _toggleCompletion(_AgendaItem item) async {
    HapticFeedback.selectionClick();
    if (item.isPersonal) {
      final docRef = FirebaseFirestore.instance
          .collection(kPersonalSchedulesCollection)
          .doc(item.personalDocId);
      if (item.recurrence == 'none') {
        await docRef.update({'isCompleted': !item.isCompleted});
      } else {
        final occKey = _normalize(item.date).toIso8601String();
        await docRef.update({
          'completedOccurrences.$occKey': !item.isCompleted,
        });
      }
    } else {
      final projectIndex = _projects.indexWhere(
        (p) => p['id']?.toString() == item.projectId,
      );
      if (projectIndex < 0) return;
      final project = Map<String, dynamic>.from(_projects[projectIndex]);
      final schedules = List<Map<String, dynamic>>.from(
        (project['schedules'] as List? ?? []).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );
      final idx = schedules.indexWhere(
        (s) => s['id']?.toString() == item.scheduleId,
      );
      if (idx < 0) return;
      schedules[idx]['isCompleted'] = !item.isCompleted;
      project['schedules'] = schedules;
      setState(() => _projects[projectIndex] = project);
      await _projectRepo.upsertProject(project);
    }
  }

  Future<void> _ensureScheduleChannel() async {
    if (_channelReady) return;
    const channel = AndroidNotificationChannel(
      kScheduleChannelId,
      '내 일정 알림',
      description: '개인 일정 리마인더 알림',
      importance: Importance.high,
    );
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
    _channelReady = true;
  }

  int _notifIdFor(String docId) => docId.hashCode & 0x7fffffff;

  // 🚀 [오늘 일정 알림] 저장할 때마다 예전 예약은 취소하고 다시 잡는다
  // (수정/반복설정 변경 시 중복 알림이 남지 않게). 반복 일정은
  // matchDateTimeComponents로 "매주 이 요일 이 시각"/"매월 이 날짜 이
  // 시각"에 계속 울리도록 한다.
  Future<void> _scheduleOrCancelReminder(
    String docId,
    Map<String, dynamic> data,
  ) async {
    final int notifId = _notifIdFor(docId);
    await flutterLocalNotificationsPlugin.cancel(id: notifId);

    final int reminderMinutes = (data['reminderMinutesBefore'] as int?) ?? 0;
    if (reminderMinutes <= 0) return;
    if (data['hasTime'] == false) return;

    final DateTime base = DateTime.parse(data['dateTime'] as String);
    DateTime remindAt = base.subtract(Duration(minutes: reminderMinutes));
    final String recurrence = (data['recurrence'] as String?) ?? 'none';

    DateTimeComponents? matchComponents;
    if (recurrence == 'weekly') {
      matchComponents = DateTimeComponents.dayOfWeekAndTime;
    } else if (recurrence == 'monthly') {
      matchComponents = DateTimeComponents.dayOfMonthAndTime;
    }

    if (matchComponents != null) {
      final now = DateTime.now();
      while (remindAt.isBefore(now)) {
        remindAt = recurrence == 'weekly'
            ? remindAt.add(const Duration(days: 7))
            : DateTime(
                remindAt.year,
                remindAt.month + 1,
                remindAt.day,
                remindAt.hour,
                remindAt.minute,
              );
      }
    } else if (remindAt.isBefore(DateTime.now())) {
      return;
    }

    await _ensureScheduleChannel();
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: notifId,
      title: '일정 알림',
      body: (data['title'] as String?)?.trim().isNotEmpty == true
          ? data['title'] as String
          : '등록된 일정',
      scheduledDate: tz.TZDateTime.from(remindAt, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          kScheduleChannelId,
          '내 일정 알림',
          channelDescription: '개인 일정 리마인더 알림',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: matchComponents,
    );
  }

  Future<void> _deletePersonalItem(String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: scheduleWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "일정 삭제",
          style: TextStyle(color: scheduleText, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "이 개인 일정을 삭제할까요? 되돌릴 수 없습니다.",
          style: TextStyle(color: scheduleSubText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("취소", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "삭제",
              style: TextStyle(
                color: scheduleDanger,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await flutterLocalNotificationsPlugin.cancel(id: _notifIdFor(docId));
    await FirebaseFirestore.instance
        .collection(kPersonalSchedulesCollection)
        .doc(docId)
        .delete();
  }

  // 🚀 [개인 일정 추가/수정] 제목·카테고리·날짜·시간·반복·알림을 한
  // 시트에서 입력한다. existing이 있으면 수정 모드.
  Future<void> _showAddPersonalSheet({
    String? docId,
    Map<String, dynamic>? existing,
  }) async {
    final titleCtrl = TextEditingController(
      text: existing?['title'] as String? ?? '',
    );
    String category = (existing?['category'] as String?) ?? '개인';
    DateTime baseDate = existing != null
        ? _asDateTime(existing['dateTime'])
        : _selectedDay;
    bool hasTime = existing?['hasTime'] != false;
    TimeOfDay time = TimeOfDay(hour: baseDate.hour, minute: baseDate.minute);
    DateTime endDate = existing?['endDate'] != null
        ? _asDateTime(existing!['endDate'])
        : baseDate;
    String recurrence = (existing?['recurrence'] as String?) ?? 'none';
    int reminderMinutes = (existing?['reminderMinutesBefore'] as int?) ?? 0;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (ctx, scrollController) => Container(
                decoration: const BoxDecoration(
                  color: scheduleWhite,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: scheduleTeal.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.event_note_rounded,
                              color: scheduleTeal,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              docId == null ? "새 일정 만들기" : "일정 수정",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: scheduleText,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.grey,
                            ),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: titleCtrl,
                              autofocus: docId == null,
                              decoration: InputDecoration(
                                hintText: "일정 제목 (예: 거래처 미팅)",
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "카테고리",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: kPersonalCategories.map((cat) {
                                final bool selected = category == cat;
                                final Color c = colorForCategory(cat);
                                return InkWell(
                                  onTap: () =>
                                      setSheetState(() => category = cat),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? c
                                          : c.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: c.withValues(
                                          alpha: selected ? 1 : 0.35,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      cat,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: selected ? Colors.white : c,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              "날짜/시간",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: baseDate,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2035),
                                      );
                                      if (picked != null) {
                                        setSheetState(() {
                                          final int span =
                                              DateTime(
                                                    endDate.year,
                                                    endDate.month,
                                                    endDate.day,
                                                  )
                                                  .difference(
                                                    DateTime(
                                                      baseDate.year,
                                                      baseDate.month,
                                                      baseDate.day,
                                                    ),
                                                  )
                                                  .inDays;
                                          baseDate = picked;
                                          endDate = picked.add(
                                            Duration(days: span < 0 ? 0 : span),
                                          );
                                        });
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.calendar_today_outlined,
                                      size: 16,
                                      color: scheduleTeal,
                                    ),
                                    label: Text(
                                      "${baseDate.year}.${baseDate.month.toString().padLeft(2, '0')}.${baseDate.day.toString().padLeft(2, '0')}",
                                      style: const TextStyle(
                                        color: scheduleTeal,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: scheduleTeal,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: !hasTime
                                        ? null
                                        : () async {
                                            final picked =
                                                await showMakitaTimePicker(
                                                  context: context,
                                                  initialTime: time,
                                                  title: "일정 시간",
                                                );
                                            if (picked != null) {
                                              setSheetState(
                                                () => time = picked,
                                              );
                                            }
                                          },
                                    icon: const Icon(
                                      Icons.access_time_rounded,
                                      size: 16,
                                      color: scheduleTeal,
                                    ),
                                    label: Text(
                                      hasTime ? time.format(context) : "종일",
                                      style: const TextStyle(
                                        color: scheduleTeal,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: scheduleTeal,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: !hasTime,
                              activeThumbColor: scheduleTeal,
                              title: const Text(
                                "종일 일정 (시간 없음)",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: scheduleText,
                                ),
                              ),
                              onChanged: (v) =>
                                  setSheetState(() => hasTime = !v),
                            ),
                            if (recurrence == 'none') ...[
                              const SizedBox(height: 8),
                              const Text(
                                "기간 (출장·연차처럼 여러 날)",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final n in [1, 2, 3, 4, 5, 7])
                                    Builder(
                                      builder: (_) {
                                        final int cur =
                                            DateTime(
                                                  endDate.year,
                                                  endDate.month,
                                                  endDate.day,
                                                )
                                                .difference(
                                                  DateTime(
                                                    baseDate.year,
                                                    baseDate.month,
                                                    baseDate.day,
                                                  ),
                                                )
                                                .inDays +
                                            1;
                                        final bool selected = cur == n;
                                        return ChoiceChip(
                                          label: Text(
                                            n == 1 ? "당일" : "${n - 1}박 $n일",
                                          ),
                                          selected: selected,
                                          onSelected: (_) => setSheetState(
                                            () => endDate = baseDate.add(
                                              Duration(days: n - 1),
                                            ),
                                          ),
                                          selectedColor: scheduleTeal,
                                          labelStyle: TextStyle(
                                            color: selected
                                                ? Colors.white
                                                : scheduleText,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          backgroundColor: Colors.grey.shade100,
                                        );
                                      },
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: endDate.isBefore(baseDate)
                                        ? baseDate
                                        : endDate,
                                    firstDate: DateTime(
                                      baseDate.year,
                                      baseDate.month,
                                      baseDate.day,
                                    ),
                                    lastDate: DateTime(2035),
                                  );
                                  if (picked != null) {
                                    setSheetState(() => endDate = picked);
                                  }
                                },
                                icon: const Icon(
                                  Icons.event_available_outlined,
                                  size: 16,
                                  color: scheduleTeal,
                                ),
                                label: Text(
                                  "종료일 ${endDate.year}.${endDate.month.toString().padLeft(2, '0')}.${endDate.day.toString().padLeft(2, '0')}",
                                  style: const TextStyle(color: scheduleTeal),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: scheduleTeal),
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            const Text(
                              "반복",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: kRecurrenceLabels.entries.map((e) {
                                final bool selected = recurrence == e.key;
                                return ChoiceChip(
                                  label: Text(e.value),
                                  selected: selected,
                                  onSelected: (_) =>
                                      setSheetState(() => recurrence = e.key),
                                  selectedColor: scheduleTeal,
                                  labelStyle: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : scheduleText,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  backgroundColor: Colors.grey.shade100,
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20),
                            if (hasTime) ...[
                              const Text(
                                "알림",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: kReminderOptions.entries.map((e) {
                                  final bool selected =
                                      reminderMinutes == e.key;
                                  return ChoiceChip(
                                    label: Text(e.value),
                                    selected: selected,
                                    onSelected: (_) => setSheetState(
                                      () => reminderMinutes = e.key,
                                    ),
                                    selectedColor: scheduleTeal,
                                    labelStyle: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : scheduleText,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    backgroundColor: Colors.grey.shade100,
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (docId != null) ...[
                              const SizedBox(height: 4),
                              SizedBox(
                                width: double.infinity,
                                child: TextButton.icon(
                                  onPressed: () async {
                                    Navigator.pop(ctx);
                                    await _deletePersonalItem(docId);
                                  },
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: scheduleDanger,
                                  ),
                                  label: const Text(
                                    "이 일정 삭제",
                                    style: TextStyle(color: scheduleDanger),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (titleCtrl.text.trim().isEmpty) return;
                                  final DateTime combined = hasTime
                                      ? DateTime(
                                          baseDate.year,
                                          baseDate.month,
                                          baseDate.day,
                                          time.hour,
                                          time.minute,
                                        )
                                      : DateTime(
                                          baseDate.year,
                                          baseDate.month,
                                          baseDate.day,
                                        );
                                  final data = <String, dynamic>{
                                    'title': titleCtrl.text.trim(),
                                    'category': category,
                                    'dateTime': combined.toIso8601String(),
                                    'hasTime': hasTime,
                                    'endDate':
                                        (recurrence == 'none' &&
                                            !endDate.isBefore(baseDate))
                                        ? DateTime(
                                            endDate.year,
                                            endDate.month,
                                            endDate.day,
                                          ).toIso8601String()
                                        : null,
                                    'recurrence': recurrence,
                                    'owner': _currentWorker,
                                    'isCompleted':
                                        existing?['isCompleted'] ?? false,
                                    'completedOccurrences':
                                        existing?['completedOccurrences'] ??
                                        <String, dynamic>{},
                                    'reminderMinutesBefore': reminderMinutes,
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  };
                                  String targetDocId;
                                  if (docId == null) {
                                    data['createdAt'] =
                                        FieldValue.serverTimestamp();
                                    final ref = await FirebaseFirestore.instance
                                        .collection(
                                          kPersonalSchedulesCollection,
                                        )
                                        .add(data);
                                    targetDocId = ref.id;
                                  } else {
                                    await FirebaseFirestore.instance
                                        .collection(
                                          kPersonalSchedulesCollection,
                                        )
                                        .doc(docId)
                                        .update(data);
                                    targetDocId = docId;
                                  }
                                  await _scheduleOrCancelReminder(
                                    targetDocId,
                                    data,
                                  );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: scheduleTeal,
                                  elevation: 0,
                                  minimumSize: const Size(double.infinity, 52),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  "저장하기",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
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
        },
      ),
    );
  }

  // 🚀 [4번 강화] "일정 세트 템플릿" - 매달 정기 점검처럼 여러 건이 묶여
  // 반복되는 일정 조합을 이름 붙여 저장해두고, 기준 날짜 하나만 골라
  // 한 번에 전부 만든다. 각 항목은 절대 날짜가 아니라 기준일로부터의
  // 상대 일수(dayOffset)로 저장해서, 언제 적용하든 같은 간격이 유지된다.
  Future<void> _showTemplateSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (ctx, scrollController) => Container(
          decoration: const BoxDecoration(
            color: scheduleWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        "일정 세트 템플릿",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: scheduleText,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.grey),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _showCreateTemplateSheet();
                    },
                    icon: const Icon(Icons.add, color: scheduleTeal),
                    label: const Text(
                      "새 템플릿 만들기",
                      style: TextStyle(
                        color: scheduleTeal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: scheduleTeal),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection(kScheduleTemplatesCollection)
                      .where('owner', isEqualTo: _currentWorker)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: scheduleTeal),
                      );
                    }
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            "저장된 템플릿이 없습니다.",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final doc = docs[i];
                        final data = doc.data() as Map<String, dynamic>;
                        final name = (data['name'] as String?) ?? '이름 없는 템플릿';
                        final items = (data['items'] as List? ?? []);
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: scheduleBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: scheduleText,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: scheduleDanger,
                                      size: 20,
                                    ),
                                    onPressed: () async {
                                      await doc.reference.delete();
                                    },
                                  ),
                                ],
                              ),
                              Text(
                                items
                                    .map((e) => (e as Map)['title'] ?? '')
                                    .join(' · '),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () async {
                                    final baseDate = await showDatePicker(
                                      context: context,
                                      initialDate: DateTime.now(),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2035),
                                    );
                                    if (baseDate == null) return;
                                    await _applyTemplate(data, baseDate);
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  },
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: scheduleTeal),
                                  ),
                                  child: const Text(
                                    "기준일 골라 적용하기",
                                    style: TextStyle(color: scheduleTeal),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _applyTemplate(
    Map<String, dynamic> template,
    DateTime baseDate,
  ) async {
    final items = (template['items'] as List? ?? []);
    if (items.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    final col = FirebaseFirestore.instance.collection(
      kPersonalSchedulesCollection,
    );
    for (final raw in items) {
      final bp = Map<String, dynamic>.from(raw as Map);
      final int offset = (bp['dayOffset'] as num?)?.toInt() ?? 0;
      final bool hasTime = bp['hasTime'] == true;
      final int minutes = (bp['timeMinutes'] as num?)?.toInt() ?? 9 * 60;
      final DateTime day = baseDate.add(Duration(days: offset));
      final DateTime dateTime = hasTime
          ? DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60)
          : DateTime(day.year, day.month, day.day);
      batch.set(col.doc(), {
        'title': (bp['title'] as String?)?.trim().isNotEmpty == true
            ? bp['title']
            : '제목 없음',
        'category': (bp['category'] as String?) ?? '개인',
        'dateTime': dateTime.toIso8601String(),
        'hasTime': hasTime,
        'recurrence': 'none',
        'owner': _currentWorker,
        'isCompleted': false,
        'completedOccurrences': <String, dynamic>{},
        'reminderMinutesBefore': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("일정 ${items.length}건을 추가했습니다.")));
    }
  }

  Future<void> _showCreateTemplateSheet() async {
    final nameCtrl = TextEditingController();
    final List<Map<String, dynamic>> blueprint = [
      {
        'title': '',
        'category': '개인',
        'dayOffset': 0,
        'hasTime': false,
        'timeMinutes': 9 * 60,
      },
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (ctx, scrollController) => Container(
                decoration: const BoxDecoration(
                  color: scheduleWhite,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              "새 템플릿 만들기",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: scheduleText,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.grey,
                            ),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: nameCtrl,
                              decoration: InputDecoration(
                                hintText: "템플릿 이름 (예: 매달 정기 점검)",
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            for (int i = 0; i < blueprint.length; i++)
                              _buildTemplateItemRow(
                                blueprint[i],
                                onRemove: blueprint.length <= 1
                                    ? null
                                    : () => setSheetState(
                                        () => blueprint.removeAt(i),
                                      ),
                                setSheetState: setSheetState,
                              ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () => setSheetState(() {
                                blueprint.add({
                                  'title': '',
                                  'category': '개인',
                                  'dayOffset': 0,
                                  'hasTime': false,
                                  'timeMinutes': 9 * 60,
                                });
                              }),
                              icon: const Icon(Icons.add, color: scheduleTeal),
                              label: const Text(
                                "항목 추가",
                                style: TextStyle(color: scheduleTeal),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: scheduleTeal),
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () async {
                                  final validItems = blueprint
                                      .where(
                                        (b) => (b['title'] as String)
                                            .trim()
                                            .isNotEmpty,
                                      )
                                      .toList();
                                  if (nameCtrl.text.trim().isEmpty ||
                                      validItems.isEmpty) {
                                    return;
                                  }
                                  await FirebaseFirestore.instance
                                      .collection(kScheduleTemplatesCollection)
                                      .add({
                                        'name': nameCtrl.text.trim(),
                                        'owner': _currentWorker,
                                        'items': validItems,
                                        'createdAt':
                                            FieldValue.serverTimestamp(),
                                      });
                                  if (ctx.mounted) Navigator.pop(ctx);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: scheduleTeal,
                                  elevation: 0,
                                  minimumSize: const Size(double.infinity, 52),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  "템플릿 저장",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
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
        },
      ),
    );
  }

  Widget _buildTemplateItemRow(
    Map<String, dynamic> item, {
    required VoidCallback? onRemove,
    required StateSetter setSheetState,
  }) {
    final int minutes = item['timeMinutes'] as int;
    final TimeOfDay time = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E8EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: item['title'] as String,
                  onChanged: (v) => item['title'] = v,
                  decoration: InputDecoration(
                    hintText: "항목 제목",
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              if (onRemove != null)
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Colors.grey,
                  ),
                  onPressed: onRemove,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: kPersonalCategories.map((cat) {
              final bool selected = item['category'] == cat;
              final Color c = colorForCategory(cat);
              return InkWell(
                onTap: () => setSheetState(() => item['category'] = cat),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? c : c.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: selected ? Colors.white : c,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                "기준일로부터",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 18),
                onPressed: () => setSheetState(
                  () => item['dayOffset'] = (item['dayOffset'] as int) - 1,
                ),
              ),
              Text(
                "${item['dayOffset']}일",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: scheduleText,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 18),
                onPressed: () => setSheetState(
                  () => item['dayOffset'] = (item['dayOffset'] as int) + 1,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () async {
                  if (item['hasTime'] != true) return;
                  final picked = await showMakitaTimePicker(
                    context: context,
                    initialTime: time,
                    title: "시간",
                  );
                  if (picked != null) {
                    setSheetState(
                      () => item['timeMinutes'] =
                          picked.hour * 60 + picked.minute,
                    );
                  }
                },
                child: Text(
                  item['hasTime'] == true ? time.format(context) : "종일",
                  style: const TextStyle(
                    color: scheduleTeal,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Switch(
                value: item['hasTime'] == true,
                activeThumbColor: scheduleTeal,
                onChanged: (v) => setSheetState(() => item['hasTime'] = v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<_AgendaItem> _itemsInCurrentPeriod(
    Map<DateTime, List<_AgendaItem>> byDay,
  ) {
    DateTime start;
    DateTime end;
    switch (_viewMode) {
      case _ViewMode.day:
        start = _normalize(_selectedDay);
        end = start;
        break;
      case _ViewMode.week:
        final int weekday = _focusedDay.weekday % 7; // 일요일=0 기준
        start = _normalize(_focusedDay).subtract(Duration(days: weekday));
        end = start.add(const Duration(days: 6));
        break;
      case _ViewMode.timeline:
      case _ViewMode.month:
        start = DateTime(_focusedDay.year, _focusedDay.month, 1);
        end = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
        break;
    }
    final List<_AgendaItem> result = [];
    byDay.forEach((day, items) {
      if (!day.isBefore(start) && !day.isAfter(end)) {
        result.addAll(items);
      }
    });
    return result;
  }

  // 🚀 [타임라인 보기] 프로젝트(와 개인 일정 카테고리)를 세로 행으로, 날짜를
  // 가로로 늘어놓은 간트형 화면. 동시에 진행되는 여러 프로젝트의 기간이
  // 서로 어떻게 겹치는지를 한눈에 보는 용도다. 새 데이터 없이 달력이 쓰는
  // 같은 일정 목록(byDay)을 그대로 재사용한다. 왼쪽 이름 열은 가로로
  // 밀어도 고정되어 있다.
  static const int _kTlDays = 56; // 8주
  static const double _kTlDayW = 34;
  static const double _kTlLabelW = 92;
  static const double _kTlHeaderH = 44;
  static const double _kTlLaneH = 22;

  Widget _buildTimeline(Map<DateTime, List<_AgendaItem>> byDay) {
    final DateTime today = _normalize(DateTime.now());
    _tlStart ??= today.subtract(Duration(days: (today.weekday % 7) + 7));
    final DateTime winStart = _tlStart!;
    final DateTime winEnd = winStart.add(const Duration(days: _kTlDays));

    // 일정 덩어리(기간이면 첫날 기준 1개, 하루짜리는 각각 1개)로 복원
    final Map<String, _TlRow> rows = {};
    byDay.forEach((day, items) {
      for (final it in items) {
        if (it.spanTotal > 1 && it.spanIndex != 0) continue;
        final String rowKey = it.projectId != null
            ? 'p:${it.projectId}'
            : 'c:${it.category}';
        final String rowLabel = it.projectId != null
            ? (it.projectName ?? '프로젝트')
            : it.category;
        final row = rows.putIfAbsent(rowKey, () => _TlRow(rowLabel, it.color));
        row.events.add(_TlEvent(_normalize(day), it.spanTotal, it));
      }
    });
    final List<_TlRow> rowList =
        rows.values
            .where(
              (r) => r.events.any(
                (e) =>
                    e.start.isBefore(winEnd) &&
                    e.start.add(Duration(days: e.len)).isAfter(winStart),
              ),
            )
            .toList()
          ..sort((a, b) => a.label.compareTo(b.label));

    for (final r in rowList) {
      r.events.sort((a, b) => a.start.compareTo(b.start));
      final List<DateTime> laneFree = [];
      for (final e in r.events) {
        final DateTime end = e.start.add(Duration(days: e.len));
        int lane = laneFree.indexWhere((f) => !e.start.isBefore(f));
        if (lane == -1) {
          laneFree.add(end);
          lane = laneFree.length - 1;
        } else {
          laneFree[lane] = end;
        }
        e.lane = lane;
      }
      r.laneCount = laneFree.isEmpty ? 1 : laneFree.length;
    }

    final double gridW = _kTlDays * _kTlDayW;
    double rowH(_TlRow r) => r.laneCount * _kTlLaneH + 10;

    Widget header() {
      return SizedBox(
        width: gridW,
        height: _kTlHeaderH,
        child: Stack(
          children: [
            for (int i = 0; i < _kTlDays; i++)
              Builder(
                builder: (_) {
                  final d = winStart.add(Duration(days: i));
                  final bool isToday = d == today;
                  final bool weekend =
                      d.weekday == DateTime.saturday ||
                      d.weekday == DateTime.sunday;
                  return Positioned(
                    left: i * _kTlDayW,
                    width: _kTlDayW,
                    top: 0,
                    bottom: 0,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (d.day == 1 || i == 0)
                          Text(
                            "${d.month}월",
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: scheduleTeal,
                            ),
                          )
                        else
                          const SizedBox(height: 12),
                        const SizedBox(height: 2),
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isToday ? scheduleTeal : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            "${d.day}",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isToday
                                  ? Colors.white
                                  : (weekend ? scheduleDanger : scheduleText),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      );
    }

    Widget gridRow(_TlRow r) {
      final double h = rowH(r);
      return SizedBox(
        width: gridW,
        height: h,
        child: Stack(
          children: [
            for (int i = 0; i < _kTlDays; i++)
              Builder(
                builder: (_) {
                  final d = winStart.add(Duration(days: i));
                  final bool isToday = d == today;
                  final bool weekend =
                      d.weekday == DateTime.saturday ||
                      d.weekday == DateTime.sunday;
                  if (!isToday && !weekend) return const SizedBox.shrink();
                  return Positioned(
                    left: i * _kTlDayW,
                    width: _kTlDayW,
                    top: 0,
                    bottom: 0,
                    child: ColoredBox(
                      color: isToday
                          ? scheduleTeal.withValues(alpha: 0.12)
                          : Colors.grey.withValues(alpha: 0.06),
                    ),
                  );
                },
              ),
            for (final e in r.events)
              Builder(
                builder: (_) {
                  final int s = e.start.difference(winStart).inDays;
                  final int en = s + e.len;
                  if (en <= 0 || s >= _kTlDays) return const SizedBox.shrink();
                  final int cs = s < 0 ? 0 : s;
                  final int ce = en > _kTlDays ? _kTlDays : en;
                  return Positioned(
                    left: cs * _kTlDayW + 1,
                    width: (ce - cs) * _kTlDayW - 2,
                    top: 5 + e.lane * _kTlLaneH,
                    height: _kTlLaneH - 4,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (_) => Container(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                            decoration: const BoxDecoration(
                              color: scheduleWhite,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(24),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [_buildAgendaCard(e.item)],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          color: e.item.color.withValues(
                            alpha: e.item.isCompleted ? 0.45 : 1,
                          ),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          e.item.baseTitle,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.clip,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
          child: Row(
            children: [
              IconButton(
                tooltip: "4주 전",
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => setState(
                  () => _tlStart = winStart.subtract(const Duration(days: 28)),
                ),
              ),
              Expanded(
                child: Text(
                  "${winStart.month}/${winStart.day} ~ ${winEnd.subtract(const Duration(days: 1)).month}/${winEnd.subtract(const Duration(days: 1)).day} (8주)",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: scheduleText,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _tlStart = null),
                child: const Text("오늘"),
              ),
              IconButton(
                tooltip: "4주 후",
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () => setState(
                  () => _tlStart = winStart.add(const Duration(days: 28)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: rowList.isEmpty
              ? const Center(
                  child: Text(
                    "이 기간에 등록된 일정이 없습니다.",
                    style: TextStyle(
                      color: scheduleSubText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 100),
                  child: Stack(
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Padding(
                          padding: const EdgeInsets.only(left: _kTlLabelW),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              header(),
                              for (final r in rowList) ...[
                                const Divider(
                                  height: 1,
                                  color: Color(0xFFE5E8EB),
                                ),
                                gridRow(r),
                              ],
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: 0,
                        width: _kTlLabelW,
                        child: ColoredBox(
                          color: scheduleWhite,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: _kTlHeaderH),
                              for (final r in rowList) ...[
                                const Divider(
                                  height: 1,
                                  color: Color(0xFFE5E8EB),
                                ),
                                SizedBox(
                                  height: rowH(r),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: r.color,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            r.label,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: scheduleText,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildViewModeToggle() {
    Widget segment(String label, _ViewMode mode) {
      final bool selected = _viewMode == mode;
      return Expanded(
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _viewMode = mode;
              _calendarFormat = mode == _ViewMode.week
                  ? CalendarFormat.week
                  : CalendarFormat.month;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? scheduleTeal : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          segment("월", _ViewMode.month),
          segment("주", _ViewMode.week),
          segment("일", _ViewMode.day),
          segment("타임라인", _ViewMode.timeline),
        ],
      ),
    );
  }

  // 🚀 [6번 강화] 화살표 탭뿐 아니라 좌우로 밀어서도 하루씩 이동할 수
  // 있게 한다.
  void _shiftDay(int deltaDays) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedDay = _selectedDay.add(Duration(days: deltaDays));
      _focusedDay = _selectedDay;
    });
  }

  Widget _buildDayHeader() {
    return Container(
      color: scheduleWhite,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: scheduleText),
            onPressed: () => _shiftDay(-1),
          ),
          SizedBox(
            width: 180,
            child: Text(
              "${_selectedDay.year}.${_selectedDay.month.toString().padLeft(2, '0')}.${_selectedDay.day.toString().padLeft(2, '0')} (${kWeekdaysKo[_selectedDay.weekday - 1]})",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: scheduleText,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: scheduleText),
            onPressed: () => _shiftDay(1),
          ),
        ],
      ),
    );
  }

  // 🚀 [기간 막대] 여러 날 일정은 시작~종료 칸을 가로로 이어지는 한 줄
  // 막대로 그린다. 같은 일정이 매일 같은 줄(lane)에 오도록, 기간이 겹치지
  // 않는 것끼리 같은 줄을 재사용하는 식으로 줄 번호를 미리 정한다.
  // 줄은 최대 3개까지만 막대로 그리고, 넘치는 건 아래 점으로 표시된다.
  static const int _kMaxBarLanes = 3;

  Map<String, int> _assignBarLanes(Map<DateTime, List<_AgendaItem>> byDay) {
    final Map<String, DateTime> starts = {};
    final Map<String, int> lengths = {};
    byDay.forEach((day, items) {
      for (final it in items) {
        if (it.spanTotal > 1 && it.spanKey != null) {
          final id = it.spanKey!;
          final start = day.subtract(Duration(days: it.spanIndex));
          starts[id] = _normalize(start);
          lengths[id] = it.spanTotal;
        }
      }
    });
    final ids = starts.keys.toList()
      ..sort((a, b) => starts[a]!.compareTo(starts[b]!));
    final List<DateTime> laneFreeFrom = [];
    final Map<String, int> lanes = {};
    for (final id in ids) {
      final s = starts[id]!;
      final e = s.add(Duration(days: lengths[id]!));
      int lane = laneFreeFrom.indexWhere((free) => !s.isBefore(free));
      if (lane == -1) {
        laneFreeFrom.add(e);
        lane = laneFreeFrom.length - 1;
      } else {
        laneFreeFrom[lane] = e;
      }
      lanes[id] = lane;
    }
    return lanes;
  }

  // 🚀 날짜 숫자를 칸 위쪽에 두고, 선택/오늘 표시는 칸 전체가 아니라
  // 그 숫자 주변의 작은 원에만 그린다. 칸이 세로로 길어지면서 기본 표시
  // (칸 정중앙에 큰 원)가 날짜를 가리고 어색해져서 직접 그린다.
  Widget _dayNumberCell(
    DateTime day, {
    bool selected = false,
    bool today = false,
    bool outside = false,
  }) {
    final bool weekend =
        day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
    final Color textColor = selected
        ? Colors.white
        : outside
        ? Colors.grey.shade400
        : today
        ? scheduleTeal
        : (weekend ? scheduleDanger : scheduleText);
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? scheduleTeal
              : (today ? scheduleTeal.withValues(alpha: 0.15) : null),
          shape: BoxShape.circle,
        ),
        child: Text(
          '${day.day}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: (selected || today) ? FontWeight.bold : FontWeight.w500,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _dotRow(List<_AgendaItem> dots) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: dots.take(3).map((e) {
        return Container(
          width: 5,
          height: 5,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(color: e.color, shape: BoxShape.circle),
        );
      }).toList(),
    );
  }

  Widget _buildCalendar(Map<DateTime, List<_AgendaItem>> byDay) {
    final Map<String, int> barLanes = _assignBarLanes(byDay);
    return Container(
      color: scheduleWhite,
      padding: const EdgeInsets.only(bottom: 8),
      child: TableCalendar<_AgendaItem>(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2035, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        rowHeight: 84,
        startingDayOfWeek: StartingDayOfWeek.sunday,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        eventLoader: (day) => byDay[_normalize(day)] ?? [],
        headerStyle: const HeaderStyle(
          titleCentered: true,
          formatButtonVisible: false,
          titleTextStyle: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: scheduleText,
          ),
          leftChevronIcon: Icon(Icons.chevron_left, color: scheduleText),
          rightChevronIcon: Icon(Icons.chevron_right, color: scheduleText),
        ),
        calendarStyle: const CalendarStyle(
          todayDecoration: BoxDecoration(
            color: Color(0x4D007580),
            shape: BoxShape.circle,
          ),
          todayTextStyle: TextStyle(
            color: scheduleTeal,
            fontWeight: FontWeight.bold,
          ),
          selectedDecoration: BoxDecoration(
            color: scheduleTeal,
            shape: BoxShape.circle,
          ),
          weekendTextStyle: TextStyle(color: scheduleDanger),
          markersMaxCount: 3,
          markerMargin: EdgeInsets.symmetric(horizontal: 1),
        ),
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, day, focused) => _dayNumberCell(day),
          outsideBuilder: (context, day, focused) =>
              _dayNumberCell(day, outside: true),
          todayBuilder: (context, day, focused) => _dayNumberCell(
            day,
            today: true,
            selected: isSameDay(_selectedDay, day),
          ),
          selectedBuilder: (context, day, focused) => _dayNumberCell(
            day,
            selected: true,
            today: isSameDay(day, DateTime.now()),
          ),
          markerBuilder: (context, day, events) {
            if (events.isEmpty) return null;
            final bars = events
                .where(
                  (e) =>
                      e.spanTotal > 1 &&
                      e.spanKey != null &&
                      (barLanes[e.spanKey] ?? 0) < _kMaxBarLanes,
                )
                .toList();
            final dots = events.where((e) => !bars.contains(e)).toList();
            // 일요일=0 … 토요일=6 (달력이 일요일 시작이라 주 경계 계산용)
            final int dayIdx = day.weekday % 7;
            return LayoutBuilder(
              builder: (context, box) {
                final double cellW = box.maxWidth;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 🚀 막대는 "구간의 첫 칸"(기간 첫날 또는 그 주의 일요일)에서
                    // 그 주 끝(또는 종료일)까지 한 덩어리로 그려서 제목을 쓴다.
                    // 뒤 칸들이 자기 막대를 또 그리면 제목이 덮이므로, 그 칸들은
                    // 이 일정의 막대를 그리지 않는다.
                    for (final e in bars)
                      if (e.spanIndex == 0 || dayIdx == 0)
                        Builder(
                          builder: (_) {
                            final int remaining = e.spanTotal - e.spanIndex;
                            final int n = remaining < (7 - dayIdx)
                                ? remaining
                                : (7 - dayIdx);
                            final bool roundLeft = e.spanIndex == 0;
                            final bool roundRight = n == remaining;
                            return Positioned(
                              left: roundLeft ? 3 : 0,
                              width:
                                  cellW * n -
                                  (roundLeft ? 3 : 0) -
                                  (roundRight ? 3 : 0),
                              bottom: 2 + (barLanes[e.spanKey] ?? 0) * 14.0,
                              height: 12,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: e.color,
                                  borderRadius: BorderRadius.horizontal(
                                    left: Radius.circular(roundLeft ? 4 : 0),
                                    right: Radius.circular(roundRight ? 4 : 0),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      e.baseTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.clip,
                                      softWrap: false,
                                      style: const TextStyle(
                                        fontSize: 9,
                                        height: 1.0,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    if (dots.isNotEmpty)
                      Positioned(
                        bottom: 2 + _kMaxBarLanes * 14.0,
                        left: 0,
                        right: 0,
                        child: Center(child: _dotRow(dots)),
                      ),
                  ],
                );
              },
            );
          },
        ),
        onDaySelected: (selected, focused) {
          HapticFeedback.lightImpact();
          setState(() {
            _selectedDay = selected;
            _focusedDay = focused;
          });
        },
        onPageChanged: (focused) {
          setState(() => _focusedDay = focused);
        },
      ),
    );
  }

  // 🚀 [5번 강화] "완료/남음"만 보여주던 진행 막대에 "지연"(기한이
  // 지났는데 완료 안 한 것) 개수를 더해서, 그냥 안 끝난 게 아니라 이미
  // 늦은 게 몇 건인지 한눈에 알 수 있는 요약 카드로 키웠다.
  Widget _buildProgressBar(Map<DateTime, List<_AgendaItem>> byDay) {
    final items = _itemsInCurrentPeriod(byDay);
    final total = items.length;
    final done = items.where((e) => e.isCompleted).length;
    final overdue = items.where(_isOverdue).length;
    final remaining = total - done;
    final ratio = total > 0 ? done / total : 0.0;
    final String periodLabel = switch (_viewMode) {
      _ViewMode.day => "오늘",
      _ViewMode.week => "이번 주",
      _ViewMode.month => "이번 달",
      _ViewMode.timeline => "이번 달",
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheduleWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E8EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: RichText(
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: scheduleText,
                    ),
                    children: [
                      TextSpan(text: "$periodLabel 완료 $done · 남음 $remaining"),
                      if (overdue > 0)
                        TextSpan(
                          text: " · 지연 $overdue",
                          style: const TextStyle(color: scheduleDanger),
                        ),
                    ],
                  ),
                ),
              ),
              Text(
                total > 0 ? "${(ratio * 100).toStringAsFixed(0)}%" : "-",
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: scheduleTeal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              color: scheduleTeal,
            ),
          ),
        ],
      ),
    );
  }

  // 🚀 [2번 강화] 범례를 그냥 보여주기만 하던 걸 탭 가능한 필터로 바꿨다.
  // 눌린 카테고리만 남기고, 하나도 안 눌려 있으면(기본) 전체를 보여준다.
  Widget _buildCategoryLegend() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: kScheduleColors.entries.map((e) {
            final bool selected = _activeCategoryFilters.contains(e.key);
            final bool dimmed = _activeCategoryFilters.isNotEmpty && !selected;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (selected) {
                      _activeCategoryFilters.remove(e.key);
                    } else {
                      _activeCategoryFilters.add(e.key);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? e.value.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: selected
                        ? Border.all(color: e.value.withValues(alpha: 0.4))
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: dimmed ? Colors.grey.shade300 : e.value,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        e.key,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: selected ? FontWeight.bold : null,
                          color: dimmed
                              ? Colors.grey.shade400
                              : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // 🚀 [2번 강화] 프로젝트가 2개 이상 있을 때만 노출 - 프로젝트 하나뿐이면
  // 필터할 의미가 없으니 화면만 복잡해진다.
  Widget _buildProjectFilterRow() {
    final Map<String, String> projectNames = {
      for (final p in _projects)
        if (p['id'] != null)
          p['id'].toString(): (p['name'] as String?) ?? '이름 없음',
    };
    if (projectNames.length < 2) return const SizedBox.shrink();

    Widget chip(String? id, String label) {
      final bool selected = _activeProjectFilter == id;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          avatar: id == null
              ? null
              : CircleAvatar(backgroundColor: colorForProject(id), radius: 5),
          label: Text(label, style: const TextStyle(fontSize: 12)),
          selected: selected,
          onSelected: (_) {
            HapticFeedback.selectionClick();
            setState(() => _activeProjectFilter = selected ? null : id);
          },
          selectedColor: scheduleTeal,
          labelStyle: TextStyle(
            color: selected ? Colors.white : scheduleText,
            fontWeight: FontWeight.bold,
          ),
          backgroundColor: Colors.grey.shade100,
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            chip(null, "전체 프로젝트"),
            ...projectNames.entries.map((e) => chip(e.key, e.value)),
          ],
        ),
      ),
    );
  }

  Widget _buildAgendaCard(_AgendaItem item) {
    final Color c = item.color;
    final bool overdue = _isOverdue(item);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: overdue ? scheduleDanger.withValues(alpha: 0.04) : scheduleWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: overdue
              ? scheduleDanger.withValues(alpha: 0.4)
              : const Color(0xFFE5E8EB),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _toggleCompletion(item),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                item.isCompleted
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: item.isCompleted ? scheduleTeal : Colors.grey.shade400,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(iconForCategory(item.category), color: c, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: item.isCompleted ? Colors.grey : scheduleText,
                    decoration: item.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: c.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.category,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: c,
                        ),
                      ),
                    ),
                    if (overdue)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: scheduleDanger,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          "지연",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    if (item.hasTime)
                      Text(
                        "${item.date.hour.toString().padLeft(2, '0')}:${item.date.minute.toString().padLeft(2, '0')}",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    // 🚀 [3번 강화] 프로젝트 이름을 탭하면 "내 프로젝트"의
                    // 그 프로젝트 일정 관리로 바로 넘어간다. 예전엔
                    // 프로젝트 이름만 보여주고 이동 방법이 없었다.
                    if (item.projectName != null)
                      InkWell(
                        onTap: () => _openProjectSchedule(item.projectId),
                        child: Text(
                          "· ${item.projectName} 바로가기",
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: scheduleTeal,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    if (item.recurrence != 'none')
                      Icon(
                        Icons.repeat_rounded,
                        size: 12,
                        color: Colors.grey.shade500,
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (item.isPersonal)
            IconButton(
              icon: const Icon(
                Icons.edit_outlined,
                size: 18,
                color: Colors.grey,
              ),
              onPressed: () {
                FirebaseFirestore.instance
                    .collection(kPersonalSchedulesCollection)
                    .doc(item.personalDocId)
                    .get()
                    .then((doc) {
                      if (doc.exists && mounted) {
                        _showAddPersonalSheet(
                          docId: doc.id,
                          existing: doc.data(),
                        );
                      }
                    });
              },
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Icon(
                Icons.folder_shared_outlined,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scheduleBg,
      appBar: AppBar(
        backgroundColor: scheduleWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: const Text(
          "내 일정 관리",
          style: TextStyle(
            color: scheduleText,
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        iconTheme: const IconThemeData(color: scheduleText),
        actions: [
          IconButton(
            tooltip: "일정 세트 템플릿",
            icon: const Icon(Icons.dataset_outlined),
            onPressed: () {
              HapticFeedback.selectionClick();
              _showTemplateSheet();
            },
          ),
          IconButton(
            tooltip: "프로젝트 일정 새로고침",
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              HapticFeedback.selectionClick();
              _loadProjects();
            },
          ),
          IconButton(
            tooltip: "오늘로 이동",
            icon: const Icon(Icons.today_rounded),
            onPressed: () => setState(() {
              _focusedDay = DateTime.now();
              _selectedDay = DateTime.now();
            }),
          ),
        ],
      ),
      body: _loadingProjects
          ? const Center(child: CircularProgressIndicator(color: scheduleTeal))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(kPersonalSchedulesCollection)
                  .where('owner', isEqualTo: _currentWorker)
                  .snapshots(),
              builder: (context, snapshot) {
                final List<_AgendaItem> personalItems = [];
                if (snapshot.hasData) {
                  for (final doc in snapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    personalItems.addAll(_expandPersonalItem(doc.id, data));
                  }
                }
                final allItems = _applyFilters([
                  ..._projectAgendaItems(),
                  ...personalItems,
                ]);

                final Map<DateTime, List<_AgendaItem>> byDay = {};
                for (final item in allItems) {
                  byDay.putIfAbsent(_normalize(item.date), () => []).add(item);
                }
                for (final list in byDay.values) {
                  list.sort((a, b) => a.date.compareTo(b.date));
                }

                final selectedItems = byDay[_normalize(_selectedDay)] ?? [];

                return RefreshIndicator(
                  color: scheduleTeal,
                  onRefresh: _loadProjects,
                  child: GestureDetector(
                    // 🚀 [6번 강화] 일 보기일 때만 좌우 스와이프로 하루씩
                    // 이동한다(월/주 보기는 달력 자체가 이미 스와이프로
                    // 페이지 전환을 지원하므로 건드리지 않는다).
                    onHorizontalDragEnd: _viewMode != _ViewMode.day
                        ? null
                        : (details) {
                            final v = details.primaryVelocity ?? 0;
                            if (v.abs() < 200) return;
                            _shiftDay(v < 0 ? 1 : -1);
                          },
                    child: Column(
                      children: [
                        _buildViewModeToggle(),
                        if (_viewMode == _ViewMode.day)
                          _buildDayHeader()
                        else if (_viewMode != _ViewMode.timeline)
                          _buildCalendar(byDay),
                        _buildProgressBar(byDay),
                        _buildCategoryLegend(),
                        _buildProjectFilterRow(),
                        const Divider(height: 1, color: Color(0xFFE5E8EB)),
                        Expanded(
                          child: _viewMode == _ViewMode.timeline
                              ? _buildTimeline(byDay)
                              : selectedItems.isEmpty
                              ? ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    const SizedBox(height: 60),
                                    Icon(
                                      Icons.event_available_outlined,
                                      size: 48,
                                      color: Colors.grey.shade300,
                                    ),
                                    const SizedBox(height: 12),
                                    const Center(
                                      child: Text(
                                        "이 날은 등록된 일정이 없습니다.",
                                        style: TextStyle(
                                          color: scheduleSubText,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    12,
                                    16,
                                    100,
                                  ),
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  itemCount: selectedItems.length,
                                  itemBuilder: (context, i) =>
                                      _buildAgendaCard(selectedItems[i]),
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.selectionClick();
          _showAddPersonalSheet();
        },
        backgroundColor: scheduleTeal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "새 일정",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

const List<String> kWeekdaysKo = ['월', '화', '수', '목', '금', '토', '일'];

// 🚀 [홈 배지] 메뉴 화면에서 "오늘 일정 N건" 배지를 보여주기 위한 헬퍼.
// 프로젝트 일정(오늘 날짜인 것)과 개인 일정(오늘 또는 오늘에 걸리는
// 반복 회차)을 합쳐서 세되, 이미 완료 처리된 것은 빼서 "아직 할 일"
// 개수만 보여준다.
Future<int> fetchTodayScheduleCount(String currentWorker) async {
  try {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int count = 0;

    final repo = WorkProjectRepository();
    final projects = await repo.fetchAllProjects();
    for (final project in projects) {
      final schedules = (project['schedules'] as List<dynamic>? ?? []);
      for (final raw in schedules) {
        final s = Map<String, dynamic>.from(raw as Map);
        if (s['dateTime'] == null || s['isCompleted'] == true) continue;
        final dynamic dt = s['dateTime'];
        final DateTime date = dt is Timestamp
            ? dt.toDate()
            : (dt is String ? DateTime.tryParse(dt) ?? today : today);
        if (DateTime(date.year, date.month, date.day) == today) count++;
      }
    }

    final personalSnap = await FirebaseFirestore.instance
        .collection(kPersonalSchedulesCollection)
        .where('owner', isEqualTo: currentWorker)
        .get();
    for (final doc in personalSnap.docs) {
      final data = doc.data();
      if (data['dateTime'] == null) continue;
      final DateTime base =
          DateTime.tryParse(data['dateTime'] as String) ?? today;
      final String recurrence = (data['recurrence'] as String?) ?? 'none';
      final Map<String, dynamic> completedMap = Map<String, dynamic>.from(
        data['completedOccurrences'] as Map? ?? {},
      );

      if (recurrence == 'none') {
        if (DateTime(base.year, base.month, base.day) == today &&
            data['isCompleted'] != true) {
          count++;
        }
      } else {
        final bool matchesToday = recurrence == 'weekly'
            ? base.weekday == today.weekday
            : base.day == today.day;
        if (matchesToday && !base.isAfter(today)) {
          final occKey = today.toIso8601String();
          if (completedMap[occKey] != true) count++;
        }
      }
    }
    return count;
  } catch (_) {
    return 0;
  }
}
