import 'package:tubing_calculator/src/core/theme/app_icon_set.dart';
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'dart:async';
import '../my_work_logs/widgets/work_theme.dart';
import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/core/utils/cache_first.dart';
import 'package:tubing_calculator/src/core/common_widgets/app_components.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../tube_cutting/cutting_pending_banner.dart';
import 'kakao_place_search.dart';
import 'korean_holidays.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

import '../../data/repositories/work_project_repository.dart';
import '../../core/common_widgets/makita_time_picker.dart';
import '../my_work_logs/screens/work_log_main_screen.dart';
import '../my_work_logs/models/project_phase.dart' show colorForProject;
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'schedule_backup.dart';
import 'schedule_ics.dart';
import 'schedule_search_dialog.dart';
import 'schedule_logic.dart';
import '../profile/pages/mobile_profile_page.dart' show MobileProfilePage;
import 'schedule_reminders.dart';
import '../my_work_logs/models/reminder_tools.dart'
    show ensureNotificationPermission;

// 🚀 [신규] "내 일정 관리" - 마키타 틸 팔레트로 앱 전체와 통일.
const Color scheduleTeal = AppColors.brand;
const Color scheduleTealDark = Color(0xFF004D54);
const Color scheduleBg = AppColors.background;
const Color scheduleText = AppColors.text;
const Color scheduleSubText = AppColors.textSub;
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
  '영업': AppColors.caution,
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
  10: "10분 전",
  30: "30분 전",
  60: "1시간 전",
  120: "2시간 전",
  1440: "하루 전",
  2880: "이틀 전",
};

const Map<String, String> kRecurrenceLabels = {
  'none': "반복 없음",
  'daily': "매일",
  'weekdays': "평일마다",
  'weekly': "매주",
  'biweekly': "격주",
  'monthly': "매월",
  'yearly': "매년",
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
  // 장소(예: 중부발전). 적어 두면 카드에서 눌러 지도로 찾는다.
  final String place;
  // 장소 검색으로 고른 주소와 좌표(손으로 적었으면 비어 있다).
  final String placeAddress;
  final double? placeLat;
  final double? placeLng;
  // 기간 일정의 몇 번째 날인지(0부터)와 전체 일수 - 달력에 이어진 막대를
  // 그릴 때 시작/끝을 알아내는 데 쓴다.
  final int spanIndex;
  final int spanTotal;
  final String? spanKey;
  // 끝나는 시각(넣었을 때만)과 메모.
  final DateTime? end;
  final String note;

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
    this.place = '',
    this.placeAddress = '',
    this.placeLat,
    this.placeLng,
    this.spanIndex = 0,
    this.spanTotal = 1,
    this.spanKey,
    this.end,
    this.note = '',
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

  /// 처음 보여 줄 날짜(알림을 눌러 들어올 때). 없으면 오늘.
  final DateTime? initialDate;

  const MobileMyScheduleScreen({
    super.key,
    this.currentWorker,
    this.initialDate,
  });

  @override
  State<MobileMyScheduleScreen> createState() => _MobileMyScheduleScreenState();
}

class _MobileMyScheduleScreenState extends State<MobileMyScheduleScreen> {
  String _currentWorker = kNoWorkerName;
  _ViewMode _viewMode = _ViewMode.month;
  DateTime? _tlStart;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  late DateTime _focusedDay = widget.initialDate ?? DateTime.now();
  late DateTime _selectedDay = widget.initialDate ?? DateTime.now();

  final WorkProjectRepository _projectRepo = WorkProjectRepository();
  List<Map<String, dynamic>> _projects = [];
  bool _loadingProjects = true;

  /// 폰 목록을 보이는 중에 서버 목록을 받는 중(머리 아래 가는 줄).
  bool _refreshingProjects = false;

  static bool _tzReady = false;

  // 🚀 [2번 강화] 카테고리는 다중 선택(빈 집합 = 전체 표시), 프로젝트는
  // 단일 선택(null = 전체 프로젝트)으로 좁혀본다.
  final Set<String> _activeCategoryFilters = {};
  // 완료한 일정을 목록에서 감춘다(달력 표시·건수는 그대로).
  bool _hideCompleted = false;
  String? _activeProjectFilter;

  @override
  void initState() {
    super.initState();
    _initTimeZone();
    _loadCurrentWorker();
    _loadProjects();
    // 한 번씩만 예약해 둔 매달 반복 알림(날짜가 달마다 바뀌는 것)을 다음 회차로 다시 잡는다.
    rescheduleDriftingMonthlyReminders();
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

  // (D-F) 폰에 남은 프로젝트 일정을 먼저 그리고, 서버 것이 오면 바꿔 끼운다.
  Future<void> _loadProjects() async {
    await loadCacheFirst<List<Map<String, dynamic>>>(
      cached: _projectRepo.fetchCachedProjects,
      fresh: _projectRepo.fetchAllProjects,
      isEmpty: (l) => l.isEmpty,
      onData: (projects, {required fresh}) {
        if (!mounted) return;
        setState(() {
          _projects = projects;
          _loadingProjects = false;
          _refreshingProjects = !fresh;
        });
      },
      onError: (e, {required hadCache}) {
        if (!mounted) return;
        setState(() {
          _loadingProjects = false;
          _refreshingProjects = false;
        });
      },
    );
  }

  DateTime _normalize(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _asDateTime(dynamic v) {
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  // 🚀 [1번 강화] 완료 안 된 채로 시간(또는 종일이면 그 날 자정)이 이미
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
      if (_hideCompleted && item.isCompleted) return false;
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
        // 편집에서 고를 수 있는 기간(730일)까지 펼친다.
        final int totalDays = spanDayCount(startDay, rawEnd);
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
    final String place = (data['place'] as String?)?.trim() ?? '';
    final String placeAddress = (data['placeAddress'] as String?)?.trim() ?? '';
    final double? placeLat = (data['placeLat'] as num?)?.toDouble();
    final double? placeLng = (data['placeLng'] as num?)?.toDouble();
    final Map<String, dynamic> completedMap = Map<String, dynamic>.from(
      data['completedOccurrences'] as Map? ?? {},
    );
    final DateTime? baseEnd = hasTime ? readEndTime(data, base) : null;
    final String note = (data['note'] as String?)?.trim() ?? '';

    if (!isRecurring(recurrence)) {
      // 🚀 [기간 일정] 출장처럼 여러 날에 걸친 일정은 endDate(마지막 날)까지
      // 하루씩 펼쳐서, 달력 마커/오늘 일정/목록이 매일 자연스럽게 잡히게
      // 한다. 시간은 첫날에만 있고 이후 날은 종일로 취급한다.
      final DateTime startDay = DateTime(base.year, base.month, base.day);
      final DateTime? rawEnd = data['endDate'] != null
          ? _asDateTime(data['endDate'])
          : null;
      final int totalDays = spanDayCount(startDay, rawEnd);
      if (totalDays > 1) {
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
            place: place,
            placeAddress: placeAddress,
            placeLat: placeLat,
            placeLng: placeLng,
            spanIndex: i,
            spanTotal: totalDays,
            spanKey: docId,
            end: i == 0 ? baseEnd : null,
            note: note,
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
          place: place,
          placeAddress: placeAddress,
          placeLat: placeLat,
          placeLng: placeLng,
          end: baseEnd,
          note: note,
        ),
      ];
    }

    final DateTime rangeStart = DateTime(DateTime.now().year - 1, 1, 1);
    final DateTime rangeEnd = DateTime(DateTime.now().year + 2, 12, 31, 23, 59);
    // 매달 반복은 31일처럼 없는 날짜를 그 달의 마지막 날로 맞춘다(schedule_logic.dart).
    return [
      for (final cursor in recurrenceDates(
        base,
        recurrence,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        until: readUntil(data),
        exceptions: readExceptions(data),
      ))
        _AgendaItem(
          key: 'personal_${docId}_${_normalize(cursor).toIso8601String()}',
          date: cursor,
          hasTime: hasTime,
          title: title,
          category: category,
          isCompleted: isOccurrenceCompleted(completedMap, cursor),
          isPersonal: true,
          personalDocId: docId,
          recurrence: recurrence,
          place: place,
          placeAddress: placeAddress,
          placeLat: placeLat,
          placeLng: placeLng,
          end: occurrenceEnd(cursor, base, baseEnd),
          note: note,
        ),
    ];
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
        // 키에 점이 들어 있어서 칸 목록(FieldPath)으로 넘긴다. 완료를 풀 때는 예전 중첩 모양도 지운다.
        await docRef.update({
          FieldPath(occurrenceFieldPath(item.date)): !item.isCompleted,
          if (item.isCompleted)
            FieldPath(legacyOccurrenceFieldPath(item.date)):
                FieldValue.delete(),
        });
      }
    } else {
      if (item.projectId == null || item.scheduleId == null) return;
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
      // 화면을 연 시점의 사본으로 문서 전체를 덮어쓰지 않고, 저장 직전에 다시 읽어 일정 완료만 바꾼다.
      await _projectRepo.setScheduleCompleted(
        item.projectId!,
        item.scheduleId!,
        !item.isCompleted,
      );
    }
  }

  // 개인 일정 알림 예약은 schedule_reminders.dart 의 함수가 한다(알림 점검에서도 같이 쓴다).
  Future<void> _scheduleOrCancelReminder(
    String docId,
    Map<String, dynamic> data,
  ) async {
    // 알림을 단 일정을 처음 저장할 때 알림 권한을 묻는다(앱을 켤 때 묻지 않는다).
    if (readReminders(data).isNotEmpty) await ensureNotificationPermission();
    await schedulePersonalReminder(docId, data);
  }

  Future<void> _deletePersonalItem(
    String docId, {
    String recurrence = 'none',
    DateTime? occurrence,
  }) async {
    final col = FirebaseFirestore.instance.collection(
      kPersonalSchedulesCollection,
    );
    // 반복 일정은 "이 회차만 / 이후 모두 / 전체" 가운데 고른다.
    if (isRecurring(recurrence) && occurrence != null) {
      final scope = await _askRecurrenceScope(context, forDelete: true);
      if (scope == null) return;
      if (scope == 'one') {
        await col.doc(docId).update({
          'recurrenceExceptions': FieldValue.arrayUnion([
            occurrenceKey(occurrence),
          ]),
        });
        await _rescheduleDoc(docId);
        return;
      }
      if (scope == 'following') {
        await col.doc(docId).update({
          'recurrenceUntil': untilBeforeOccurrence(
            occurrence,
          ).toIso8601String(),
        });
        await _rescheduleDoc(docId);
        return;
      }
    }
    if (!mounted) return;
    final confirmed = await confirmScheduleDelete(
      context,
      title: "일정 삭제",
      message: isRecurring(recurrence)
          ? "이 반복 일정을 회차까지 모두 삭제합니다. 되돌릴 수 없습니다."
          : "이 개인 일정을 삭제하시겠습니까? 되돌릴 수 없습니다.",
    );
    if (!confirmed) return;
    await cancelPersonalReminders(docId);
    await col.doc(docId).delete();
  }

  /// 옛 문서를 끊거나 회차를 뺀 뒤 그 문서의 알림을 다시 잡는다(끊긴 뒤 회차는 안 울리게).
  Future<void> _rescheduleDoc(String docId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(kPersonalSchedulesCollection)
          .doc(docId)
          .get();
      final data = doc.data();
      if (data != null) await schedulePersonalReminder(docId, data);
    } catch (e) {
      debugPrint('알림 다시 잡기 실패: $e');
    }
  }

  /// 반복 일정을 고치거나 지울 때 어디까지인지 묻는다. 'one' / 'following' / 'all' / null(취소).
  Future<String?> _askRecurrenceScope(
    BuildContext ctx, {
    required bool forDelete,
  }) {
    final verb = forDelete ? "삭제" : "고치기";
    return showDialog<String>(
      context: ctx,
      builder: (dctx) => AlertDialog(
        backgroundColor: scheduleWhite,
        surfaceTintColor: Colors.transparent,
        title: Text(
          "반복 일정 $verb",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: scheduleText,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final o in const [
              ('one', "이 회차만"),
              ('following', "이 회차부터 이후 모두"),
              ('all', "모든 회차"),
            ])
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  o.$2,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () => Navigator.pop(dctx, o.$1),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: const Text("취소", style: TextStyle(color: scheduleSubText)),
          ),
        ],
      ),
    );
  }

  // 🚀 [개인 일정 추가/수정] 제목·카테고리·날짜·시간·반복·알림을 한
  // 시트에서 입력한다. existing이 있으면 수정 모드.
  Future<void> _showAddPersonalSheet({
    String? docId,
    Map<String, dynamic>? existing,
    // 반복 일정의 어느 회차에서 열었는지(회차만 고치기·이후 모두 고치기에 쓴다).
    DateTime? occurrence,
  }) async {
    if (!_requireWorker()) return;
    final titleCtrl = TextEditingController(
      text: existing?['title'] as String? ?? '',
    );
    final placeCtrl = TextEditingController(
      text: existing?['place'] as String? ?? '',
    );
    String placeAddress = (existing?['placeAddress'] as String?)?.trim() ?? '';
    double? placeLat = (existing?['placeLat'] as num?)?.toDouble();
    double? placeLng = (existing?['placeLng'] as num?)?.toDouble();
    // 지도 검색으로 고른 장소 이름. 칸의 글이 이것과 달라지면 옛 주소·좌표를 버린다.
    String pickedPlaceName = placeAddress.isNotEmpty || placeLat != null
        ? placeCtrl.text.trim()
        : '';
    String? titleError;
    String category = (existing?['category'] as String?) ?? '개인';
    // 반복 일정의 시작(전체 고치기 때 이 날짜를 지킨다).
    final DateTime? seriesBase = existing != null
        ? _asDateTime(existing['dateTime'])
        : null;
    final String oldRecurrence = (existing?['recurrence'] as String?) ?? 'none';
    // 회차에서 열었으면 그 회차 날짜로 보여 준다(시각은 일정 것).
    DateTime baseDate = seriesBase != null
        ? (occurrence != null && isRecurring(oldRecurrence)
              ? DateTime(
                  occurrence.year,
                  occurrence.month,
                  occurrence.day,
                  seriesBase.hour,
                  seriesBase.minute,
                )
              : seriesBase)
        : _selectedDay;
    bool hasTime = existing?['hasTime'] != false;
    TimeOfDay time = TimeOfDay(hour: baseDate.hour, minute: baseDate.minute);
    // 끝나는 시각(선택)·메모·알림 여러 개·반복 끝.
    final DateTime? existingEnd = seriesBase != null && hasTime
        ? readEndTime(existing!, seriesBase)
        : null;
    TimeOfDay? endTime = existingEnd == null
        ? null
        : TimeOfDay(hour: existingEnd.hour, minute: existingEnd.minute);
    String? timeError;
    final noteCtrl = TextEditingController(
      text: existing?['note'] as String? ?? '',
    );
    final Set<int> reminders = {...readReminders(existing ?? const {})};
    DateTime? recurrenceUntil = existing == null ? null : readUntil(existing);
    DateTime endDate = existing?['endDate'] != null
        ? _asDateTime(existing!['endDate'])
        : baseDate;
    String recurrence = oldRecurrence;
    bool saving = false;

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
                              onChanged: (_) {
                                if (titleError != null) {
                                  setSheetState(() => titleError = null);
                                }
                              },
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: scheduleText,
                              ),
                              decoration: InputDecoration(
                                hintText: "일정 제목 (예: 거래처 미팅)",
                                errorText: titleError,
                                filled: true,
                                fillColor: const Color(0xFFF7F8F9),
                                hintStyle: const TextStyle(
                                  color: Color(0xFF6B7684),
                                  fontWeight: FontWeight.w500,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFD1D6DB),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFD1D6DB),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: scheduleTeal,
                                    width: 1.6,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            // 장소: 이름만 적어 두면 카드에서 눌러 지도로 찾는다(주소는 지도에서 본다).
                            TextField(
                              controller: placeCtrl,
                              textInputAction: TextInputAction.done,
                              onChanged: (v) {
                                if (!shouldForgetPickedPlace(
                                  pickedPlaceName,
                                  v,
                                )) {
                                  return;
                                }
                                setSheetState(() {
                                  pickedPlaceName = '';
                                  placeAddress = '';
                                  placeLat = null;
                                  placeLng = null;
                                });
                              },
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: scheduleText,
                              ),
                              decoration: InputDecoration(
                                hintText: "장소 (선택) — 예: 중부발전",
                                prefixIcon: const Icon(
                                  Icons.place_outlined,
                                  size: 20,
                                  color: scheduleSubText,
                                ),
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: "이름으로 찾아 주소 넣기",
                                      icon: const Icon(
                                        Icons.search_rounded,
                                        size: 20,
                                        color: scheduleTeal,
                                      ),
                                      onPressed: () async {
                                        final picked = await _pickKakaoPlace(
                                          placeCtrl.text.trim(),
                                        );
                                        if (picked == null) return;
                                        setSheetState(() {
                                          placeCtrl.text = picked.name;
                                          pickedPlaceName = picked.name;
                                          placeAddress = picked.address;
                                          placeLat = picked.lat;
                                          placeLng = picked.lng;
                                        });
                                      },
                                    ),
                                    IconButton(
                                      tooltip: "지도에서 보기",
                                      icon: const Icon(
                                        Icons.map_outlined,
                                        size: 20,
                                        color: scheduleTeal,
                                      ),
                                      onPressed: () => _openMap(
                                        placeCtrl.text.trim(),
                                        lat: placeLat,
                                        lng: placeLng,
                                      ),
                                    ),
                                  ],
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF7F8F9),
                                hintStyle: const TextStyle(
                                  color: Color(0xFF6B7684),
                                  fontWeight: FontWeight.w500,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFD1D6DB),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFD1D6DB),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: scheduleTeal,
                                    width: 1.6,
                                  ),
                                ),
                              ),
                            ),
                            if (placeAddress.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6, left: 6),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.subdirectory_arrow_right_rounded,
                                      size: 14,
                                      color: Color(0xFF6B7684),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        placeAddress,
                                        maxLines: 2,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF6B7684),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: "주소 지우기",
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 16,
                                        color: Color(0xFF6B7684),
                                      ),
                                      onPressed: () => setSheetState(() {
                                        placeAddress = '';
                                        placeLat = null;
                                        placeLng = null;
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: noteCtrl,
                              minLines: 1,
                              maxLines: 3,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: scheduleText,
                              ),
                              decoration: InputDecoration(
                                hintText: "메모 (선택) — 준비물, 만날 사람 등",
                                prefixIcon: const Icon(
                                  Icons.notes_rounded,
                                  size: 20,
                                  color: scheduleSubText,
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF7F8F9),
                                hintStyle: const TextStyle(
                                  color: Color(0xFF6B7684),
                                  fontWeight: FontWeight.w500,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFD1D6DB),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFD1D6DB),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: scheduleTeal,
                                    width: 1.6,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "종류",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6B7684),
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
                                color: Color(0xFF6B7684),
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
                            if (hasTime) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () async {
                                        final picked =
                                            await showMakitaTimePicker(
                                              context: context,
                                              initialTime:
                                                  endTime ??
                                                  TimeOfDay(
                                                    hour: (time.hour + 1) % 24,
                                                    minute: time.minute,
                                                  ),
                                              title: "끝나는 시간",
                                            );
                                        if (picked != null) {
                                          setSheetState(() {
                                            endTime = picked;
                                            timeError = null;
                                          });
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.timer_outlined,
                                        size: 16,
                                        color: scheduleTeal,
                                      ),
                                      label: Text(
                                        endTime == null
                                            ? "끝나는 시간 (선택)"
                                            : "끝 ${endTime!.format(context)}",
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
                                  if (endTime != null)
                                    IconButton(
                                      tooltip: "끝나는 시간 지우기",
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                        color: scheduleSubText,
                                      ),
                                      onPressed: () => setSheetState(() {
                                        endTime = null;
                                        timeError = null;
                                      }),
                                    ),
                                ],
                              ),
                              if (timeError != null)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 4,
                                    left: 4,
                                  ),
                                  child: Text(
                                    timeError!,
                                    style: const TextStyle(
                                      color: scheduleDanger,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
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
                                  color: Color(0xFF6B7684),
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
                                color: Color(0xFF6B7684),
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
                            if (isRecurring(recurrence)) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () async {
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate:
                                              recurrenceUntil ??
                                              baseDate.add(
                                                const Duration(days: 30),
                                              ),
                                          firstDate: DateTime(
                                            baseDate.year,
                                            baseDate.month,
                                            baseDate.day,
                                          ),
                                          lastDate: DateTime(2035),
                                        );
                                        if (picked != null) {
                                          setSheetState(
                                            () => recurrenceUntil = picked,
                                          );
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.event_busy_outlined,
                                        size: 16,
                                        color: scheduleTeal,
                                      ),
                                      label: Text(
                                        recurrenceUntil == null
                                            ? "반복 끝 (계속)"
                                            : "${recurrenceUntil!.year}.${recurrenceUntil!.month.toString().padLeft(2, '0')}.${recurrenceUntil!.day.toString().padLeft(2, '0')}까지",
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
                                  if (recurrenceUntil != null)
                                    IconButton(
                                      tooltip: "반복 끝 지우기",
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                        color: scheduleSubText,
                                      ),
                                      onPressed: () => setSheetState(
                                        () => recurrenceUntil = null,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 20),
                            Text(
                              hasTime ? "알림 (여러 개 가능)" : "알림 (종일)",
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6B7684),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                Builder(
                                  builder: (_) {
                                    final bool none = reminders.isEmpty;
                                    return ChoiceChip(
                                      label: const Text("알림 없음"),
                                      selected: none,
                                      onSelected: (_) => setSheetState(
                                        () => reminders.clear(),
                                      ),
                                      selectedColor: scheduleTeal,
                                      labelStyle: TextStyle(
                                        color: none
                                            ? Colors.white
                                            : scheduleText,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      backgroundColor: Colors.grey.shade100,
                                    );
                                  },
                                ),
                                for (final e
                                    in (hasTime
                                            ? kReminderOptions
                                            : kAllDayReminderOptions)
                                        .entries
                                        .where((e) => e.key != 0))
                                  FilterChip(
                                    label: Text(e.value),
                                    selected: reminders.contains(e.key),
                                    onSelected: (on) => setSheetState(() {
                                      if (on) {
                                        if (reminders.length <
                                            kMaxRemindersPerSchedule) {
                                          reminders.add(e.key);
                                        }
                                      } else {
                                        reminders.remove(e.key);
                                      }
                                    }),
                                    selectedColor: scheduleTeal,
                                    checkmarkColor: Colors.white,
                                    labelStyle: TextStyle(
                                      color: reminders.contains(e.key)
                                          ? Colors.white
                                          : scheduleText,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    backgroundColor: Colors.grey.shade100,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (docId != null) ...[
                              const SizedBox(height: 4),
                              SizedBox(
                                width: double.infinity,
                                child: TextButton.icon(
                                  onPressed: () async {
                                    Navigator.pop(ctx);
                                    await _deletePersonalItem(
                                      docId,
                                      recurrence: oldRecurrence,
                                      occurrence: occurrence,
                                    );
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
                                  final err = scheduleTitleError(
                                    titleCtrl.text,
                                  );
                                  if (err != null) {
                                    // 아무 말 없이 멈추지 않고 제목 칸 아래에 까닭을 보여 준다.
                                    setSheetState(() => titleError = err);
                                    return;
                                  }
                                  // 종일 일정은 시간 알림을, 시간 일정은 종일 알림을 쓸 수 없다(스위치를 바꾼 경우).
                                  reminders.removeWhere(
                                    (m) => hasTime
                                        ? !kReminderOptions.containsKey(m)
                                        : !kAllDayReminderOptions.containsKey(
                                            m,
                                          ),
                                  );
                                  DateTime combined = hasTime
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
                                  DateTime? combinedEnd;
                                  if (hasTime && endTime != null) {
                                    combinedEnd = DateTime(
                                      baseDate.year,
                                      baseDate.month,
                                      baseDate.day,
                                      endTime!.hour,
                                      endTime!.minute,
                                    );
                                    if (!combinedEnd.isAfter(combined)) {
                                      setSheetState(
                                        () => timeError = "끝나는 시간이 시작보다 앞입니다.",
                                      );
                                      return;
                                    }
                                  }
                                  // 반복 일정의 회차에서 열었으면 어디까지 고칠지 묻는다.
                                  String scope = 'all';
                                  if (docId != null &&
                                      isRecurring(oldRecurrence) &&
                                      occurrence != null) {
                                    final s = await _askRecurrenceScope(
                                      ctx,
                                      forDelete: false,
                                    );
                                    if (s == null) return;
                                    scope = s;
                                    // 모든 회차를 고칠 때 날짜를 안 바꿨으면 시작일은 그대로 둔다
                                    // (회차 날짜로 바꾸면 앞 회차가 사라진다).
                                    final bool dateChanged =
                                        _normalize(baseDate) !=
                                        _normalize(occurrence);
                                    if (scope == 'all' &&
                                        !dateChanged &&
                                        seriesBase != null) {
                                      combined = hasTime
                                          ? DateTime(
                                              seriesBase.year,
                                              seriesBase.month,
                                              seriesBase.day,
                                              time.hour,
                                              time.minute,
                                            )
                                          : DateTime(
                                              seriesBase.year,
                                              seriesBase.month,
                                              seriesBase.day,
                                            );
                                      if (combinedEnd != null) {
                                        combinedEnd = DateTime(
                                          seriesBase.year,
                                          seriesBase.month,
                                          seriesBase.day,
                                          endTime!.hour,
                                          endTime!.minute,
                                        );
                                      }
                                    }
                                  }
                                  // 반복이 없는 시간 일정은 저장 전에 같은 시간대 일정이 있는지 알려 준다.
                                  if (hasTime && recurrence == 'none') {
                                    final conflicts = conflictsWith(
                                      LiteAgenda(
                                        key: 'new',
                                        date: combined,
                                        hasTime: true,
                                        title: titleCtrl.text.trim(),
                                        isCompleted: false,
                                        end: combinedEnd,
                                      ),
                                      _lastLite,
                                      excludeKeyPrefix: docId == null
                                          ? null
                                          : 'personal_$docId',
                                    );
                                    if (conflicts.isNotEmpty) {
                                      if (!ctx.mounted) return;
                                      final go = await _confirmConflicts(
                                        ctx,
                                        conflicts,
                                      );
                                      if (!go) return;
                                    }
                                  }
                                  final data = <String, dynamic>{
                                    'title': titleCtrl.text.trim(),
                                    'place': placeCtrl.text.trim(),
                                    'placeAddress': placeAddress,
                                    'placeLat': placeLat,
                                    'placeLng': placeLng,
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
                                    'recurrenceUntil':
                                        isRecurring(recurrence) &&
                                            recurrenceUntil != null
                                        ? DateTime(
                                            recurrenceUntil!.year,
                                            recurrenceUntil!.month,
                                            recurrenceUntil!.day,
                                          ).toIso8601String()
                                        : null,
                                    'endTime': combinedEnd?.toIso8601String(),
                                    'note': noteCtrl.text.trim(),
                                    'owner': _currentWorker,
                                    'isCompleted':
                                        existing?['isCompleted'] ?? false,
                                    'completedOccurrences':
                                        existing?['completedOccurrences'] ??
                                        <String, dynamic>{},
                                    // 예전 칸(reminderMinutesBefore)도 같이 적어 예전 앱이 읽게 둔다.
                                    'reminders': reminders.toList()..sort(),
                                    'reminderMinutesBefore': hasTime
                                        ? (reminders.isEmpty
                                              ? 0
                                              : reminders.reduce(
                                                  (a, b) => a > b ? a : b,
                                                ))
                                        : 0,
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  };
                                  if (saving) return;
                                  saving = true;
                                  final col = FirebaseFirestore.instance
                                      .collection(kPersonalSchedulesCollection);
                                  final String targetDocId;
                                  // 통신이 없으면 서버 확인이 끝나지 않아 창이 안 닫히고, 다시 누르면
                                  // 두 번 저장되던 것: 폰에 먼저 적히므로 기다리지 않고 닫는다.
                                  if (docId == null) {
                                    data['createdAt'] =
                                        FieldValue.serverTimestamp();
                                    final ref = col.doc();
                                    targetDocId = ref.id;
                                    unawaited(
                                      ref
                                          .set(data)
                                          .catchError(_scheduleSaveFailed),
                                    );
                                  } else if (scope == 'all') {
                                    targetDocId = docId;
                                    // 완료 표시는 따로 저장한다. 시트를 연 뒤에 한 완료가
                                    // 시트 열 때 값으로 덮여 지워지던 것.
                                    data.remove('completedOccurrences');
                                    data.remove('isCompleted');
                                    unawaited(
                                      col
                                          .doc(docId)
                                          .update(data)
                                          .catchError(_scheduleSaveFailed),
                                    );
                                  } else {
                                    // 이 회차만 / 이후 모두: 옛 문서는 그 자리에서 끊고 새 문서를 만든다.
                                    final ref = col.doc();
                                    targetDocId = ref.id;
                                    data['createdAt'] =
                                        FieldValue.serverTimestamp();
                                    data['completedOccurrences'] =
                                        <String, dynamic>{};
                                    data['isCompleted'] = false;
                                    data['recurrenceExceptions'] = null;
                                    if (scope == 'one') {
                                      data['recurrence'] = 'none';
                                      data['recurrenceUntil'] = null;
                                    }
                                    unawaited(
                                      ref
                                          .set(data)
                                          .catchError(_scheduleSaveFailed),
                                    );
                                    unawaited(
                                      col
                                          .doc(docId)
                                          .update(
                                            scope == 'one'
                                                ? {
                                                    'recurrenceExceptions':
                                                        FieldValue.arrayUnion([
                                                          occurrenceKey(
                                                            occurrence!,
                                                          ),
                                                        ]),
                                                  }
                                                : {
                                                    'recurrenceUntil':
                                                        untilBeforeOccurrence(
                                                          occurrence!,
                                                        ).toIso8601String(),
                                                  },
                                          )
                                          .then((_) => _rescheduleDoc(docId))
                                          .catchError(_scheduleSaveFailed),
                                    );
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
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
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
                                      // 옆의 적용 단추를 누르려다 잘못 눌러도 바로 지워지지 않게 한 번 묻는다.
                                      final ok = await confirmScheduleDelete(
                                        context,
                                        title: "템플릿 삭제",
                                        message:
                                            "'$name' 템플릿을 삭제하시겠습니까? 되돌릴 수 없습니다.",
                                      );
                                      if (!ok) return;
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
                                    "기준일을 선택해서 적용하기",
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
    if (!_requireWorker()) return;
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
    // 🚀 [고침] 통신이 없으면 서버 확인이 끝나지 않아 "추가했습니다"가 안 떴다.
    // 폰에 먼저 적히므로 기다리지 않고 알리고, 실패하면 따로 알린다.
    unawaited(batch.commit().catchError(_scheduleSaveFailed));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("일정 ${items.length}건을 추가했습니다.")));
    }
  }

  // 🚀 [고침] 개인 일정 저장이 실패해도 알리지 않았다(화면엔 저장된 것처럼 보였다).
  void _scheduleSaveFailed(Object e) {
    debugPrint('일정 저장 실패: $e');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("일정을 저장하지 못했습니다. 통신을 확인하고 다시 해 보십시오.")),
    );
  }

  Future<void> _showCreateTemplateSheet() async {
    if (!_requireWorker()) return;
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
                                fillColor: const Color(0xFFF7F8F9),
                                hintStyle: const TextStyle(
                                  color: Color(0xFF6B7684),
                                  fontWeight: FontWeight.w500,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFD1D6DB),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFD1D6DB),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: scheduleTeal,
                                    width: 1.6,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            for (int i = 0; i < blueprint.length; i++)
                              // 줄마다 키를 줘야 한 줄을 지웠을 때 다음 줄 글이 지운 줄 글로 남지 않는다.
                              KeyedSubtree(
                                key: ValueKey(identityHashCode(blueprint[i])),
                                child: _buildTemplateItemRow(
                                  blueprint[i],
                                  onRemove: blueprint.length <= 1
                                      ? null
                                      : () => setSheetState(
                                          () => blueprint.removeAt(i),
                                        ),
                                  setSheetState: setSheetState,
                                ),
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
        border: Border.all(color: AppColors.line),
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
              const Flexible(
                child: Text(
                  "기준일로부터",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
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
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
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
                icon: const Icon(AppIcons.back),
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
                icon: const Icon(AppIcons.forward),
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
                                const Divider(height: 1, color: AppColors.line),
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
                                const Divider(height: 1, color: AppColors.line),
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

  // ───────────── 일정 검색 ─────────────
  Future<void> _showSearchDialog() async {
    final entries = [
      for (final it in _lastItems)
        SearchEntry(
          groupKey: it.personalDocId != null
              ? 'p_${it.personalDocId}'
              : 'j_${it.projectId}_${it.scheduleId ?? it.key}',
          key: it.key,
          date: it.date,
          title: it.baseTitle,
          category: it.category,
          projectName: it.projectName,
        ),
    ];
    final picked = await showDialog<SearchEntry>(
      context: context,
      builder: (ctx) => ScheduleSearchDialog(
        entries: entries,
        filtered:
            _activeCategoryFilters.isNotEmpty || _activeProjectFilter != null,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _focusedDay = picked.date;
        _selectedDay = picked.date;
      });
    }
  }

  // ───────────── 내 일정 내보내기·가져오기 ─────────────
  // 이름을 모르면 개인 일정을 저장하지 않고 알려 준다.
  bool _requireWorker() {
    if (canSaveAsWorker(_currentWorker)) return true;
    // 🚀 [고침] 막기만 하고 이름을 넣으러 가는 길이 없었다.
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("이름이 없어 저장할 수 없습니다. 이름을 먼저 넣으십시오."),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            key: const Key('schedule_need_name'),
            label: "이름 넣기",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    MobileProfilePage(currentWorker: _currentWorker),
              ),
            ),
          ),
        ),
      );
    }
    return false;
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<List<PersonalDoc>> _fetchMyPersonalDocs() async {
    final snap = await FirebaseFirestore.instance
        .collection(kPersonalSchedulesCollection)
        .where('owner', isEqualTo: _currentWorker)
        .get();
    return [for (final d in snap.docs) (id: d.id, data: d.data())];
  }

  Future<void> _exportPersonal() async {
    try {
      final docs = await _fetchMyPersonalDocs();
      if (docs.isEmpty) {
        _toast("내보낼 개인 일정이 없습니다.");
        return;
      }
      final now = DateTime.now();
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/my_schedules_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.json',
      );
      await file.writeAsString(encodePersonalSchedules(docs, now));
      // ignore: deprecated_member_use
      await Share.shareXFiles([XFile(file.path)], text: '내 일정 백업');
    } catch (e) {
      _toast("내보내기 실패: $e");
    }
  }

  /// 구글·네이버·삼성 캘린더가 읽는 .ics 파일로 내보낸다(카톡·메일로 보내 그쪽 달력에 넣는다).
  Future<void> _exportIcs() async {
    try {
      final docs = await _fetchMyPersonalDocs();
      if (docs.isEmpty) {
        _toast("내보낼 개인 일정이 없습니다.");
        return;
      }
      final now = DateTime.now();
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/my_schedules_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.ics',
      );
      await file.writeAsString(buildIcs(docs));
      // ignore: deprecated_member_use
      await Share.shareXFiles([
        XFile(file.path, mimeType: 'text/calendar'),
      ], text: '내 일정 (캘린더 파일)');
    } catch (e) {
      _toast("내보내기 실패: $e");
    }
  }

  Future<void> _importPersonal() async {
    if (!_requireWorker()) return;
    try {
      final res = await FilePicker.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (res == null || res.files.isEmpty) return;
      final pf = res.files.first;
      final text = pf.bytes != null
          ? utf8.decode(pf.bytes!)
          : await File(pf.path!).readAsString();
      final backup = parsePersonalSchedules(text);
      if (backup.items.isEmpty) {
        _toast("가져올 일정이 없습니다.");
        return;
      }
      final existing = {for (final d in await _fetchMyPersonalDocs()) d.id};
      final plan = planPersonalRestore(backup, existing);
      if (!mounted) return;
      String names(List<String> l) => l.length <= 3
          ? l.join(', ')
          : "${l.take(3).join(', ')} 외 ${l.length - 3}건";
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: scheduleWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "내 일정 가져오기",
            style: TextStyle(color: scheduleText, fontWeight: FontWeight.bold),
          ),
          content: Text(
            "${plan.added.isEmpty ? '' : '새로 들어오는 일정 ${plan.added.length}건 (${names(plan.added)})\n'}"
            "${plan.overwritten.isEmpty ? '' : '덮어쓰는 일정 ${plan.overwritten.length}건 (${names(plan.overwritten)})\n'}"
            "${backup.skipped == 0 ? '' : '읽을 수 없어 건너뛰는 항목 ${backup.skipped}건\n'}"
            "\n덮어쓰는 일정은 지금 내용이 백업 내용으로 바뀝니다. 계속하시겠습니까?",
            style: const TextStyle(color: scheduleSubText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("취소"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("가져오기"),
            ),
          ],
        ),
      );
      if (go != true) return;
      var n = 0;
      for (final d in backup.items) {
        final data = dataForRestore(d.data, _currentWorker)
          ..['updatedAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection(kPersonalSchedulesCollection)
            .doc(d.id)
            .set(data);
        await _scheduleOrCancelReminder(d.id, data);
        n++;
      }
      _toast("일정 $n건을 가져왔습니다.");
    } on FormatException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast("가져오기 실패: $e");
    }
  }

  // 맨 위 "오늘 일정" 한 줄 요약. 누르면 오늘로 이동한다.
  Widget _buildTodaySummary(String text) {
    return InkWell(
      onTap: () => setState(() {
        _focusedDay = DateTime.now();
        _selectedDay = DateTime.now();
      }),
      child: Container(
        width: double.infinity,
        color: scheduleTeal.withValues(alpha: 0.07),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.today_rounded, size: 16, color: scheduleTeal),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: scheduleTeal,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
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
            icon: const Icon(AppIcons.back, color: scheduleText),
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
            icon: const Icon(AppIcons.forward, color: scheduleText),
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
  // 날짜 칸 안의 일정 막대: 날짜 동그라미 아래에서 시작해 한 줄씩 아래로 쌓는다.
  static const double _kCellRowTop = 28;
  static const double _kCellRowH = 16;
  static const double _kCellBarH = 15;

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
    // 공휴일은 일요일처럼 빨간 날로 보여 준다(표: korean_holidays.dart).
    final bool holiday = isKoreanHoliday(day);
    final Color textColor = selected
        ? Colors.white
        : outside
        ? Colors.grey.shade400
        : today
        ? scheduleTeal
        : ((weekend || holiday) ? scheduleDanger : scheduleText);
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.only(top: 3),
        width: 24,
        height: 24,
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
            fontSize: 13,
            fontWeight: (selected || today) ? FontWeight.bold : FontWeight.w500,
            color: textColor,
          ),
        ),
      ),
    );
  }

  // 이름으로 장소를 찾아 고른다(카카오 로컬). 고른 것의 이름·주소·좌표를 돌려준다.
  Future<KakaoPlace?> _pickKakaoPlace(String initial) async {
    final ctrl = TextEditingController(text: initial);
    return showModalBottomSheet<KakaoPlace>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        List<KakaoPlace> results = const [];
        bool loading = false;
        String message = '';
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            Future<void> run() async {
              final q = ctrl.text.trim();
              if (q.isEmpty) return;
              setSheet(() {
                loading = true;
                message = '';
              });
              try {
                final found = await searchKakaoPlaces(q);
                setSheet(() {
                  results = found;
                  loading = false;
                  message = found.isEmpty
                      ? "찾은 곳이 없습니다. 이름을 줄여서 다시 찾아 보십시오."
                      : '';
                });
              } catch (e) {
                setSheet(() {
                  loading = false;
                  results = const [];
                  message = e.toString();
                });
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  16 + MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "장소 찾기",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: scheduleText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "회사·기관 이름을 적으십시오. 예: 중부발전",
                      style: TextStyle(fontSize: 13, color: Color(0xFF6B7684)),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: ctrl,
                            autofocus: true,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => run(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: scheduleText,
                            ),
                            decoration: InputDecoration(
                              hintText: "장소 이름",
                              filled: true,
                              fillColor: const Color(0xFFF7F8F9),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: Color(0xFFD1D6DB),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: scheduleTeal,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 16,
                            ),
                          ),
                          onPressed: loading ? null : run,
                          child: const Text(
                            "찾기",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (message.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          message,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: scheduleDanger,
                          ),
                        ),
                      )
                    else if (results.isNotEmpty)
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: results.length,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1, color: AppColors.line),
                          itemBuilder: (_, i) {
                            final r = results[i];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                r.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: scheduleText,
                                ),
                              ),
                              subtitle: Text(
                                r.address.isEmpty ? "주소 없음" : r.address,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7684),
                                ),
                              ),
                              trailing: const Icon(
                                AppIcons.forward,
                                color: Color(0xFF6B7684),
                              ),
                              onTap: () => Navigator.pop(ctx, r),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 장소를 지도에서 찾는다. 구글 지도 앱이 있으면 앱으로, 없으면 브라우저로 열린다.
  Future<void> _openMap(String place, {double? lat, double? lng}) async {
    final String q = lat != null && lng != null ? "$lat,$lng" : place.trim();
    if (q.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("장소를 먼저 적으십시오.")));
      }
      return;
    }
    final Uri uri = Uri.parse(
      "https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(q)}",
    );
    try {
      final bool ok = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!ok && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("지도를 열지 못했습니다.")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("지도를 열지 못했습니다: $e")));
      }
    }
  }

  // 날짜 칸에 그리는 일정 막대(색 + 제목).
  Widget _calendarBar(
    _AgendaItem e, {
    bool roundLeft = true,
    bool roundRight = true,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: e.color,
        borderRadius: BorderRadius.horizontal(
          left: Radius.circular(roundLeft ? 4 : 0),
          right: Radius.circular(roundRight ? 4 : 0),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 4, right: 2),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            e.baseTitle,
            maxLines: 1,
            overflow: TextOverflow.clip,
            softWrap: false,
            // 막대 높이가 고정(15)이라 글자 크게 설정에서 넘친다 → 이 글씨만 키우지 않는다.
            textScaler: TextScaler.noScaling,
            style: const TextStyle(
              fontSize: 11,
              height: 1.15,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar(Map<DateTime, List<_AgendaItem>> byDay) {
    final Map<String, int> barLanes = _assignBarLanes(byDay);
    return Container(
      color: scheduleWhite,
      padding: const EdgeInsets.only(bottom: 8),
      child: TableCalendar<_AgendaItem>(
        locale: 'ko_KR',
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2035, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        // 아래로 밀면 한 달 전체, 위로 밀면 그 주만 보여서 아래 일정 목록이 넓어진다.
        availableGestures: AvailableGestures.all,
        availableCalendarFormats: const {
          CalendarFormat.month: "월",
          CalendarFormat.week: "주",
        },
        onFormatChanged: (format) {
          HapticFeedback.selectionClick();
          setState(() {
            _calendarFormat = format;
            // 위 보기 모드 칩도 같이 맞춘다(주만 보이는데 "월"이 켜져 있으면 헷갈린다).
            _viewMode = format == CalendarFormat.week
                ? _ViewMode.week
                : _ViewMode.month;
          });
        },
        rowHeight: 76,
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
          leftChevronIcon: Icon(AppIcons.back, color: scheduleText),
          rightChevronIcon: Icon(AppIcons.forward, color: scheduleText),
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
          // 날짜 칸에 일정을 "제목이 보이는 막대"로 그린다. 기간 일정(2일 이상)은 여러 칸을 잇는 한
          // 덩어리로, 하루 일정도 같은 모양의 막대로 그린다(예전에는 점만 찍어서 무슨 일정인지 알 수
          // 없었다). 칸에 ${_kMaxBarLanes}줄까지 넣고 넘치는 개수는 날짜 옆에 "+N"으로 알린다.
          markerBuilder: (context, day, events) {
            if (events.isEmpty) return null;
            // 일요일=0 … 토요일=6 (달력이 일요일 시작이라 주 경계 계산용)
            final int dayIdx = day.weekday % 7;
            final spans = <_AgendaItem>[];
            final singles = <_AgendaItem>[];
            for (final e in events) {
              final bool isSpan = e.spanTotal > 1 && e.spanKey != null;
              if (isSpan &&
                  (barLanes[e.spanKey] ?? _kMaxBarLanes) < _kMaxBarLanes) {
                spans.add(e);
              } else {
                singles.add(e);
              }
            }
            // 줄 번호 → 그 줄에 놓을 일정. 기간 일정은 며칠에 걸쳐 같은 줄을 써야 이어져 보이므로
            // 미리 정한 줄을 그대로 쓰고, 하루 일정은 남은 줄을 위에서부터 채운다.
            final Map<int, _AgendaItem> rowOf = {};
            for (final e in spans) {
              rowOf[barLanes[e.spanKey]!] = e;
            }
            final placed = <_AgendaItem>[];
            for (final e in singles) {
              int? free;
              for (var r = 0; r < _kMaxBarLanes; r++) {
                if (!rowOf.containsKey(r)) {
                  free = r;
                  break;
                }
              }
              if (free == null) break;
              rowOf[free] = e;
              placed.add(e);
            }
            final int hidden = events.length - spans.length - placed.length;
            return LayoutBuilder(
              builder: (context, box) {
                final double cellW = box.maxWidth;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final row in rowOf.entries)
                      if (!(row.value.spanTotal > 1 &&
                          row.value.spanKey != null))
                        // 하루 일정: 그 칸 안에만 그린다.
                        Positioned(
                          left: 3,
                          width: cellW - 6,
                          top: _kCellRowTop + row.key * _kCellRowH,
                          height: _kCellBarH,
                          child: _calendarBar(row.value),
                        )
                      else if (row.value.spanIndex == 0 || dayIdx == 0)
                        // 기간 일정: 구간의 첫 칸(기간 첫날 또는 그 주의 일요일)에서 그 주 끝까지
                        // 한 덩어리로 그려서 제목을 쓴다. 뒤 칸들은 같은 막대를 다시 그리지 않는다.
                        Builder(
                          builder: (_) {
                            final e = row.value;
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
                              top: _kCellRowTop + row.key * _kCellRowH,
                              height: _kCellBarH,
                              child: _calendarBar(
                                e,
                                roundLeft: roundLeft,
                                roundRight: roundRight,
                              ),
                            );
                          },
                        ),
                    if (hidden > 0)
                      Positioned(
                        top: 4,
                        right: 2,
                        child: Text(
                          "+$hidden",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.grey.shade600,
                          ),
                        ),
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
        // 빈 날을 길게 누르면 그 날짜로 새 일정.
        onDayLongPressed: (selected, focused) {
          HapticFeedback.mediumImpact();
          setState(() {
            _selectedDay = selected;
            _focusedDay = focused;
          });
          _showAddPersonalSheet();
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
    final DateTime todayN = _normalize(DateTime.now());
    final String periodLabel = switch (_viewMode) {
      _ViewMode.day =>
        _normalize(_selectedDay) == todayN
            ? "오늘"
            : "${_selectedDay.month}월 ${_selectedDay.day}일",
      _ViewMode.week => "이번 주",
      _ViewMode.month => "이번 달",
      _ViewMode.timeline => "이 기간",
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheduleWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
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
          children:
              [
                const MapEntry('__hide__', Colors.transparent),
                ...kScheduleColors.entries,
              ].map((e) {
                if (e.key == '__hide__') return _buildHideCompletedChip();
                final bool selected = _activeCategoryFilters.contains(e.key);
                final bool dimmed =
                    _activeCategoryFilters.isNotEmpty && !selected;
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

  Widget _buildHideCompletedChip() {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        key: const Key('schedule_hide_completed'),
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _hideCompleted = !_hideCompleted);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _hideCompleted
                ? scheduleTeal.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _hideCompleted
                  ? scheduleTeal.withValues(alpha: 0.4)
                  : const Color(0xFFD1D6DB),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _hideCompleted
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 12,
                color: _hideCompleted ? scheduleTeal : Colors.grey.shade600,
              ),
              const SizedBox(width: 4),
              Text(
                "완료 숨김",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: _hideCompleted ? FontWeight.bold : null,
                  color: _hideCompleted ? scheduleTeal : Colors.grey.shade700,
                ),
              ),
            ],
          ),
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

  // 시작 시간이 1시간 안쪽으로 겹치는 일정들의 key(화면을 그릴 때마다 다시 계산).
  Set<String> _overlapKeys = {};
  // 지금 화면에 있는 모든 일정(새 일정을 저장하기 전에 겹치는지 볼 때 쓴다).
  List<LiteAgenda> _lastLite = const [];
  // 지금 화면에 있는 모든 일정(검색에 쓴다).
  List<_AgendaItem> _lastItems = const [];

  // 저장하려는 일정과 시간이 겹치는 기존 일정이 있으면 물어본다. 계속 저장하면 true.
  Future<bool> _confirmConflicts(
    BuildContext ctx,
    List<LiteAgenda> conflicts,
  ) async {
    String hm(DateTime d) =>
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final list = conflicts
        .take(3)
        .map((e) => '• ${hm(e.date)} ${e.title}')
        .join('\n');
    final more = conflicts.length > 3 ? '\n외 ${conflicts.length - 3}건' : '';
    final go = await showDialog<bool>(
      context: ctx,
      builder: (d) => AlertDialog(
        backgroundColor: scheduleWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "같은 시간대에 다른 일정이 있습니다",
          style: TextStyle(color: scheduleText, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "앞뒤 1시간 안에 있는 일정입니다.\n\n$list$more\n\n그래도 저장하시겠습니까?",
          style: const TextStyle(color: scheduleSubText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text("시간 바꾸기"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text("그대로 저장"),
          ),
        ],
      ),
    );
    return go == true;
  }

  Widget _buildAgendaCard(_AgendaItem item) {
    final Color c = item.color;
    final bool overdue = _isOverdue(item);
    final bool overlaps = _overlapKeys.contains(item.key);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: overdue ? scheduleDanger.withValues(alpha: 0.04) : scheduleWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: overdue
              ? scheduleDanger.withValues(alpha: 0.4)
              : AppColors.line,
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
                    if (item.place.isNotEmpty)
                      InkWell(
                        onTap: () => _openMap(
                          item.place,
                          lat: item.placeLat,
                          lng: item.placeLng,
                        ),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: scheduleTeal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.place_rounded,
                                size: 12,
                                color: scheduleTeal,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                item.place,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: scheduleTeal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
                    if (overlaps)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1E0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          "시간 겹침",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB54708),
                          ),
                        ),
                      ),
                    if (item.hasTime)
                      Text(
                        formatTimeRange(item.date, item.end),
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
                if (item.note.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
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
                          occurrence: item.date,
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
    return WorkTheme(
      child: Scaffold(
        backgroundColor: scheduleBg,
        // 검색·입력 창에서 키보드가 올라와도 뒤의 달력 화면은 줄어들지 않게 한다(창이 스스로 피한다).
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          backgroundColor: scheduleWhite,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          // (D-F) 폰 목록을 보이는 동안 서버 목록을 받는 중이면 가는 줄.
          bottom: refreshingBar(
            _refreshingProjects,
            key: const Key('schedule_refreshing'),
          ),
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
              tooltip: "일정 검색",
              icon: const Icon(AppIcons.search),
              onPressed: _showSearchDialog,
            ),
            IconButton(
              tooltip: "오늘로 이동",
              icon: const Icon(AppIcons.calendar),
              onPressed: () => setState(() {
                _focusedDay = DateTime.now();
                _selectedDay = DateTime.now();
              }),
            ),
            PopupMenuButton<String>(
              tooltip: "더보기",
              onSelected: (v) {
                if (v == 'template') {
                  HapticFeedback.selectionClick();
                  _showTemplateSheet();
                }
                if (v == 'refresh') {
                  HapticFeedback.selectionClick();
                  _loadProjects();
                }
                if (v == 'export') _exportPersonal();
                if (v == 'ics') _exportIcs();
                if (v == 'import') _importPersonal();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'template', child: Text("일정 세트 템플릿")),
                PopupMenuItem(value: 'refresh', child: Text("프로젝트 일정 새로고침")),
                PopupMenuItem(value: 'export', child: Text("내 일정 내보내기")),
                PopupMenuItem(value: 'ics', child: Text("캘린더 파일(.ics)로 보내기")),
                PopupMenuItem(value: 'import', child: Text("내 일정 가져오기")),
              ],
            ),
          ],
        ),
        body: _loadingProjects
            // (D-C) 가운데 빙글이 대신 카드 모양 자리.
            ? const LoadingList(key: Key('schedule_loading'))
            : StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection(kPersonalSchedulesCollection)
                    .where('owner', isEqualTo: _currentWorker)
                    .snapshots(includeMetadataChanges: true),
                builder: (context, snapshot) {
                  final List<_AgendaItem> personalItems = [];
                  // 통신 없는 곳에서 만든 일정이 아직 서버로 못 올라갔으면 알려 준다.
                  var pending = 0;
                  if (snapshot.hasData) {
                    pending = snapshot.data!.docs
                        .where((d) => d.metadata.hasPendingWrites)
                        .length;
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
                    byDay
                        .putIfAbsent(_normalize(item.date), () => [])
                        .add(item);
                  }
                  for (final list in byDay.values) {
                    list.sort((a, b) => a.date.compareTo(b.date));
                  }

                  final selectedItems = byDay[_normalize(_selectedDay)] ?? [];
                  _lastItems = allItems;
                  _lastLite = [
                    for (final it in allItems)
                      LiteAgenda(
                        key: it.key,
                        date: it.date,
                        hasTime: it.hasTime,
                        title: it.title,
                        isCompleted: it.isCompleted,
                        end: it.end,
                      ),
                  ];
                  _overlapKeys = overlappingKeys([
                    for (final it in allItems)
                      LiteAgenda(
                        key: it.key,
                        date: it.date,
                        hasTime: it.hasTime,
                        title: it.title,
                        isCompleted: it.isCompleted,
                        end: it.end,
                      ),
                  ]);
                  final todayItems = byDay[_normalize(DateTime.now())] ?? [];
                  final String todayText = todaySummary([
                    for (final it in todayItems)
                      LiteAgenda(
                        key: it.key,
                        date: it.date,
                        hasTime: it.hasTime,
                        title: it.title,
                        isCompleted: it.isCompleted,
                      ),
                  ], DateTime.now());

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
                          PendingWritesBanner(count: pending),
                          _buildTodaySummary(todayText),
                          _buildViewModeToggle(),
                          if (_viewMode == _ViewMode.timeline) ...[
                            _buildProgressBar(byDay),
                            _buildCategoryLegend(),
                            _buildProjectFilterRow(),
                            const Divider(height: 1, color: AppColors.line),
                          ],
                          Expanded(
                            child: _viewMode == _ViewMode.timeline
                                ? _buildTimeline(byDay)
                                : ListView(
                                    padding: const EdgeInsets.only(bottom: 100),
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    children: [
                                      if (_viewMode == _ViewMode.day)
                                        _buildDayHeader()
                                      else
                                        _buildCalendar(byDay),
                                      _buildProgressBar(byDay),
                                      _buildCategoryLegend(),
                                      _buildProjectFilterRow(),
                                      const Divider(
                                        height: 1,
                                        color: AppColors.line,
                                      ),
                                      if (holidayName(_selectedDay).isNotEmpty)
                                        Container(
                                          margin: const EdgeInsets.fromLTRB(
                                            16,
                                            12,
                                            16,
                                            0,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: scheduleDanger.withValues(
                                              alpha: 0.08,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.flag_rounded,
                                                size: 16,
                                                color: scheduleDanger,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                "${_selectedDay.month}월 ${_selectedDay.day}일 · ${holidayName(_selectedDay)}",
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w800,
                                                  color: scheduleDanger,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (selectedItems.isEmpty) ...[
                                        const SizedBox(height: 40),
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
                                      ] else
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            16,
                                            12,
                                            16,
                                            0,
                                          ),
                                          child: Column(
                                            children: [
                                              for (final it in selectedItems)
                                                _buildAgendaCard(it),
                                            ],
                                          ),
                                        ),
                                    ],
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
      ),
    );
  }
}

const List<String> kWeekdaysKo = ['월', '화', '수', '목', '금', '토', '일'];

// 🚀 [홈 배지] 메뉴 화면에서 "오늘 일정 N건" 배지를 보여주기 위한 헬퍼.
// 프로젝트 일정(오늘 날짜인 것)과 개인 일정(오늘 또는 오늘에 걸리는
// 반복 회차)을 합쳐서 세되, 이미 완료 처리된 것은 빼서 "아직 할 일"
// 개수만 보여준다.
DateTime? _looseDate(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

// 지우기 전에 묻는 창. [삭제]를 누르면 true.
Future<bool> confirmScheduleDelete(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: scheduleWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        title,
        style: const TextStyle(
          color: scheduleText,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Text(message, style: const TextStyle(color: scheduleSubText)),
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
  return confirmed == true;
}

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
        final DateTime date = _looseDate(dt) ?? today;
        // 여러 날 일정은 달력처럼 종료일까지 센다.
        if (spanCoversDay(date, _looseDate(s['endDate']), today)) count++;
      }
    }

    final personalSnap = await FirebaseFirestore.instance
        .collection(kPersonalSchedulesCollection)
        .where('owner', isEqualTo: currentWorker)
        .get();
    for (final doc in personalSnap.docs) {
      final data = doc.data();
      if (data['dateTime'] == null) continue;
      final DateTime? base = _looseDate(data['dateTime']);
      if (base == null) continue;
      final String recurrence = (data['recurrence'] as String?) ?? 'none';
      final Map<String, dynamic> completedMap = Map<String, dynamic>.from(
        data['completedOccurrences'] as Map? ?? {},
      );

      if (recurrence == 'none') {
        if (spanCoversDay(base, _looseDate(data['endDate']), today) &&
            data['isCompleted'] != true) {
          count++;
        }
      } else {
        if (recurrenceOccursOn(
          base,
          recurrence,
          today,
          until: readUntil(data),
          exceptions: readExceptions(data),
        )) {
          if (!isOccurrenceCompleted(completedMap, today)) count++;
        }
      }
    }
    return count;
  } catch (_) {
    return 0;
  }
}
