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

// 🚀 [신규] "내 일정 관리" - 마키타 틸 팔레트로 앱 전체와 통일.
const Color scheduleTeal = Color(0xFF007580);
const Color scheduleTealDark = Color(0xFF004D54);
const Color scheduleBg = Color(0xFFF2F4F6);
const Color scheduleText = Color(0xFF191F28);
const Color scheduleSubText = Color(0xFF8B95A1);
const Color scheduleWhite = Colors.white;
const Color scheduleDanger = Color(0xFFE0432B);

const String kPersonalSchedulesCollection = 'personal_schedules';
const String kScheduleChannelId = 'personal_schedule_channel';

// 🚀 [통합형] 프로젝트 안의 일정(자재 요청/입고일/납기일/검사일정)과 이
// 화면에서 새로 만드는 개인 일정(개인/영업/기타)을 같은 색 체계로
// 묶어서, 어디서 온 일정이든 색만 보고 종류를 바로 구분할 수 있게 한다.
const List<String> kPersonalCategories = [
  "개인",
  "영업",
  "자재 요청",
  "납기일",
  "검사일정",
  "기타",
];

const Map<String, Color> kScheduleColors = {
  '개인': scheduleTeal,
  '영업': Color(0xFFC77700),
  '자재 요청': Color(0xFF8E63CE),
  '입고일': Color(0xFF2F80ED),
  '납기일': Color(0xFFE0432B),
  '검사일정': Color(0xFF1D8A4E),
  '기타': Color(0xFF8B95A1),
};

Color colorForCategory(String cat) =>
    kScheduleColors[cat] ?? kScheduleColors['기타']!;

IconData iconForCategory(String cat) {
  switch (cat) {
    case '개인':
      return Icons.person_outline_rounded;
    case '영업':
      return Icons.handshake_outlined;
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

enum _ViewMode { month, week, day }

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
  });
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
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  final WorkProjectRepository _projectRepo = WorkProjectRepository();
  List<Map<String, dynamic>> _projects = [];
  bool _loadingProjects = true;

  static bool _tzReady = false;
  bool _channelReady = false;

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
        items.add(
          _AgendaItem(
            key: 'proj_${project['id']}_${s['id']}',
            date: date,
            hasTime: true,
            title: (rawTitle != null && rawTitle.isNotEmpty)
                ? rawTitle
                : category,
            category: category,
            isCompleted: s['isCompleted'] == true,
            isPersonal: false,
            projectId: project['id']?.toString(),
            projectName: (project['name'] as String?) ?? '이름 없음',
            scheduleId: s['id']?.toString(),
          ),
        );
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
                                        setSheetState(() => baseDate = picked);
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
        ],
      ),
    );
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
            onPressed: () => setState(() {
              _selectedDay = _selectedDay.subtract(const Duration(days: 1));
              _focusedDay = _selectedDay;
            }),
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
            onPressed: () => setState(() {
              _selectedDay = _selectedDay.add(const Duration(days: 1));
              _focusedDay = _selectedDay;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(Map<DateTime, List<_AgendaItem>> byDay) {
    return Container(
      color: scheduleWhite,
      padding: const EdgeInsets.only(bottom: 8),
      child: TableCalendar<_AgendaItem>(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2035, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
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
          markerBuilder: (context, day, events) {
            if (events.isEmpty) return null;
            return Positioned(
              bottom: 2,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: events.take(3).map((e) {
                  return Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: colorForCategory(e.category),
                      shape: BoxShape.circle,
                    ),
                  );
                }).toList(),
              ),
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

  Widget _buildProgressBar(Map<DateTime, List<_AgendaItem>> byDay) {
    final items = _itemsInCurrentPeriod(byDay);
    final total = items.length;
    final done = items.where((e) => e.isCompleted).length;
    final ratio = total > 0 ? done / total : 0.0;
    final String periodLabel = switch (_viewMode) {
      _ViewMode.day => "오늘",
      _ViewMode.week => "이번 주",
      _ViewMode.month => "이번 달",
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheduleWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E8EB)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              "$periodLabel 완료 $done / $total",
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: scheduleText,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                color: scheduleTeal,
              ),
            ),
          ),
          const SizedBox(width: 8),
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
    );
  }

  Widget _buildCategoryLegend() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: kScheduleColors.entries.map((e) {
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: e.value,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    e.key,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildAgendaCard(_AgendaItem item) {
    final Color c = colorForCategory(item.category);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheduleWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E8EB)),
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
                    if (item.hasTime)
                      Text(
                        "${item.date.hour.toString().padLeft(2, '0')}:${item.date.minute.toString().padLeft(2, '0')}",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    if (item.projectName != null)
                      Text(
                        "· ${item.projectName}",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
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
                final allItems = [..._projectAgendaItems(), ...personalItems];

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
                  child: Column(
                    children: [
                      _buildViewModeToggle(),
                      if (_viewMode == _ViewMode.day)
                        _buildDayHeader()
                      else
                        _buildCalendar(byDay),
                      _buildProgressBar(byDay),
                      _buildCategoryLegend(),
                      const Divider(height: 1, color: Color(0xFFE5E8EB)),
                      Expanded(
                        child: selectedItems.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
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
                                physics: const AlwaysScrollableScrollPhysics(),
                                itemCount: selectedItems.length,
                                itemBuilder: (context, i) =>
                                    _buildAgendaCard(selectedItems[i]),
                              ),
                      ),
                    ],
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
