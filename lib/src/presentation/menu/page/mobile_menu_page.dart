import 'package:tubing_calculator/src/presentation/common/feature_search.dart';
import 'package:tubing_calculator/src/presentation/common/record_search.dart';
import 'package:tubing_calculator/src/presentation/safety/safety_check_page.dart';
import 'package:tubing_calculator/src/presentation/alignment/alignment_page.dart';
import 'package:tubing_calculator/src/presentation/alignment/alignment_guide_page.dart';
import 'package:tubing_calculator/src/presentation/drawing_viewer/drawing_library_page.dart';
import 'package:tubing_calculator/src/presentation/equipment/equipment_model.dart'
    show summarize;
import 'package:tubing_calculator/src/presentation/equipment/equipment_pages.dart';
import 'package:tubing_calculator/src/presentation/equipment/equipment_reminders.dart'
    show rescheduleEquipmentReminders;
import 'package:tubing_calculator/src/presentation/equipment/equipment_store.dart';
import 'package:tubing_calculator/src/presentation/bend_check/bend_check_page.dart';
import 'package:tubing_calculator/src/data/repositories/work_project_repository.dart';
import 'package:tubing_calculator/src/presentation/inventory/material_catalog.dart'
    show allMaterialCatalog;
import 'package:tubing_calculator/src/core/utils/home_widget_sync.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/attendance.dart'
    show AttendanceCache, dateKey, loadAttendanceRange;
import 'package:tubing_calculator/src/core/common_widgets/press_feedback.dart';
import 'package:tubing_calculator/src/core/theme/app_icon_set.dart';
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import '../../my_work_logs/widgets/work_theme.dart';
import 'package:tubing_calculator/src/presentation/common/app_icons.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geocoding/geocoding.dart';
import 'package:tubing_calculator/src/core/database/database_helper.dart';
import 'package:tubing_calculator/src/data/conduit_drawings.dart';

// 🚀 [수정됨] 단일 설정 페이지 대신 통합 네비게이션 페이지 임포트
// (실제 파일 경로에 맞게 수정해 주세요)
import 'package:tubing_calculator/src/presentation/conduit/screens/main_navigation_page.dart';

// 🚀 1. 현장 작업 페이지들 임포트
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_remote_page.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_calculator_page.dart';
import 'package:tubing_calculator/src/presentation/fabrication/screens/qr_scanner_page.dart';
import 'package:tubing_calculator/src/presentation/fabrication/screens/viewer_only_screen.dart';
import 'package:tubing_calculator/src/presentation/reference/page/app_usage_page.dart';
import 'package:tubing_calculator/src/presentation/reference/page/equipment_usage_page.dart';
import 'package:tubing_calculator/src/presentation/reference/page/tube_reference_page.dart';
import 'package:tubing_calculator/src/presentation/reference/search/knowledge_search_page.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/screens/mobile_cutting_project_list_page.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/screens/short_pipe_cutting_page.dart';
import 'package:tubing_calculator/src/presentation/steel_cutting/screens/mobile_steel_project_list_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/layout_board_project_list_page.dart';

// 🚀 2. 자재 관리 페이지들 임포트
import 'package:tubing_calculator/src/presentation/inventory/pages/mobile_inventory_login.dart';
import 'package:tubing_calculator/src/presentation/inventory/pages/mobile_inventory_status_page.dart';
import 'package:tubing_calculator/src/presentation/inventory/pages/low_stock_count.dart';
import 'package:tubing_calculator/src/presentation/material_request/material_request_page.dart';
import 'package:tubing_calculator/src/presentation/attendance/attendance_clock.dart';
import 'package:tubing_calculator/src/presentation/attendance/pages/attendance_page.dart';

// 🚀 3. 프로필 및 소통 페이지 임포트
import 'package:tubing_calculator/src/presentation/profile/pages/mobile_profile_page.dart';
import 'package:tubing_calculator/src/presentation/profile/pages/mobile_settings_page.dart';
import 'package:tubing_calculator/src/presentation/profile/widgets/settings_cloud_card.dart'
    show pullNewerCalculatorSettings;
import 'package:tubing_calculator/src/presentation/profile/profile_tools.dart'
    show kGuestName;

// 🚀 4. 프로젝트 관리 페이지 임포트
import 'package:tubing_calculator/src/presentation/my_work_logs/screens/work_log_main_screen.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/reminder_tools.dart'
    show fetchMissingReportCount;
import 'package:tubing_calculator/src/presentation/my_schedule/mobile_my_schedule_page.dart';
import 'package:tubing_calculator/src/presentation/my_schedule/schedule_reminders.dart'
    show rescheduleDriftingMonthlyReminders;

// 🚀 6. 사내 일정 관리 캘린더 페이지 임포트

// 🚀 7. 신규 알림 내역 페이지 임포트
import 'package:tubing_calculator/src/presentation/notification/pages/mobile_notification_page.dart';
import 'package:tubing_calculator/src/presentation/notification/pages/my_notifications_tab.dart';
import 'package:tubing_calculator/src/presentation/notification/pages/news_page.dart';
import 'package:tubing_calculator/src/presentation/field_tools/level_page.dart';
import 'package:tubing_calculator/src/presentation/field_tools/eng_calculator_page.dart';
import 'package:tubing_calculator/src/presentation/field_tools/protractor_page.dart';
import 'package:tubing_calculator/src/presentation/unit_converter/unit_converter_page.dart';
import 'package:tubing_calculator/src/presentation/electrical/electric_calculator_page.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/pressure_test_page.dart';
import 'package:tubing_calculator/src/presentation/flow/flow_calc_page.dart';
import 'package:tubing_calculator/src/presentation/instrument/signal_calculator_page.dart';
import '../../trash/trash_page.dart';
import '../../electrical/cable_tray_page.dart';
import '../../electrical/busbar_bend_page.dart';
import '../../electrical/busbar_ground_page.dart';
import '../../electrical/circuit_reading_page.dart';
import '../../electrical/panel_design_page.dart';
import '../../electrical/troubleshoot_page.dart';
import '../../electrical/cable_tray_route_page.dart';

// 색의 뜻(D-B): 앱의 주 색 하나(청록). 예전에는 이 화면만 파랑이었다.
const Color tossBlue = AppColors.brand;
const Color purpleBadge = Color(0xFF8A2BE2);
const Color slate900 = AppColors.text;
const Color slate600 = AppColors.textSub;
const Color slate100 = AppColors.background;
const Color pureWhite = Color(0xFFFFFFFF);
const Color warningRed = AppColors.danger;
const Color makitaTeal = AppColors.brand;

/// 빠른 실행(즐겨찾기) 목록에 쓰려고 메뉴 버튼 하나의 정보를 담아 둔 것.
/// [_buildMenuButton]이 그릴 때마다(매 build) 자기 것을 쌓아 둔다.
class _MenuEntry {
  final String title;
  final String subtitle;
  final AppGlyph icon;
  final Color iconColor;
  final VoidCallback onTap;

  /// 전체 메뉴 카드에 뜨는 것과 같은 알림 글(예: "3곳 안 씀"). 없으면 null.
  final String? badgeText;
  final Color? badgeColor;

  const _MenuEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.badgeText,
    this.badgeColor,
  });
}

class MobileMenuPage extends StatefulWidget {
  final String currentWorker;
  final bool isAdmin;

  const MobileMenuPage({
    super.key,
    required this.currentWorker,
    this.isAdmin = false,
  });

  @override
  State<MobileMenuPage> createState() => _MobileMenuPageState();
}

/// 앱을 켜 둔 채 날씨를 자동으로 다시 받는 간격.
const Duration kWeatherRefreshEvery = Duration(minutes: 30);

/// 받은 지 [kWeatherRefreshEvery] 이상 지났으면 true(앱을 다시 볼 때 바로 다시 받는다).
bool weatherIsOld(DateTime? at, DateTime now) =>
    at != null && now.difference(at) >= kWeatherRefreshEvery;

/// 받은 지 한 시간 이상이면 true(자동 갱신이 계속 실패했다는 뜻이라 화면에 기준 시각을 적는다).
bool weatherIsStale(DateTime? at, DateTime now) =>
    at != null && now.difference(at) >= const Duration(hours: 1);

/// 즐겨찾기(빠른 실행) 켜고 끄기 — 위젯 없이 시험 가능한 순수 함수.
/// 이미 있으면 빼고, 없으면 넣는다.
Set<String> toggleQuickLaunchFavorite(Set<String> current, String title) {
  final next = Set<String>.from(current);
  if (!next.remove(title)) next.add(title);
  return next;
}

/// 이름을 바꾼 메뉴(예전 이름 → 새 이름). 빠른 실행은 제목으로 저장하므로, 예전 이름으로
/// 저장된 즐겨찾기·순서·사용 기록·홈 위젯 동작을 새 이름으로 읽는다(2026-10-03 문구 통일).
const Map<String, String> kQuickLaunchRenamed = {
  '압력 시험': '압력시험',
  '튜브 컷팅': '라인 컷팅',
  '튜브 가공': '라인 컷팅',
};

/// 저장된 제목 목록의 예전 이름을 새 이름으로 바꾼다(겹치면 하나만 남긴다).
/// 위젯 없이 시험 가능한 순수 함수.
List<String> renameQuickLaunchTitles(List<String> titles) {
  final out = <String>[];
  for (final t in titles) {
    final n = kQuickLaunchRenamed[t] ?? t;
    if (!out.contains(n)) out.add(n);
  }
  return out;
}

/// 빠른 실행 줄 순서 — 저장된 [order]에 있는 제목은 그 순서대로 앞에, 순서에 없는
/// 즐겨찾기(예전에 담아 둔 것 등)는 [titles]에 온 원래 순서대로 뒤에 붙인다.
/// [titles]에 없는 제목은 버린다. 위젯 없이 시험 가능한 순수 함수.
List<String> orderQuickLaunch(List<String> titles, List<String> order) {
  final known = <String>[
    for (final t in order)
      if (titles.contains(t)) t,
  ];
  final seen = known.toSet();
  return [
    ...known,
    for (final t in titles)
      if (!seen.contains(t)) t,
  ];
}

/// [list]의 [oldIndex]번 항목을 [newIndex] 자리로 옮긴다(ReorderableListView가
/// 주는 newIndex는 뽑기 전 기준이라 아래로 옮길 때 1을 빼야 한다).
List<String> moveQuickLaunch(List<String> list, int oldIndex, int newIndex) {
  final next = List<String>.from(list);
  if (oldIndex < 0 || oldIndex >= next.length) return next;
  if (newIndex > oldIndex) newIndex -= 1;
  final item = next.removeAt(oldIndex);
  next.insert(newIndex.clamp(0, next.length), item);
  return next;
}

/// 빠른 실행 줄을 길게 눌렀을 때 보여주는 "작업 히스토리"에 쓸 상대 시각
/// 글자 — 위젯 없이 시험 가능한 순수 함수.
String quickLaunchRelativeTime(DateTime at, DateTime now) {
  final d = now.difference(at);
  if (d.inMinutes < 1) return '방금 전';
  if (d.inMinutes < 60) return '${d.inMinutes}분 전';
  if (d.inHours < 24) return '${d.inHours}시간 전';
  if (d.inDays < 30) return '${d.inDays}일 전';
  if (d.inDays < 365) return '${(d.inDays / 30).floor()}개월 전';
  return '${(d.inDays / 365).floor()}년 전';
}

String _quickLaunchLastUsedKey(String title) => 'home_quick_last_used_$title';

/// [title]의 사용 기록 글. 이름을 바꾼 메뉴는 예전 이름으로 남긴 기록도 읽는다.
String? _readQuickLaunchHistory(SharedPreferences p, String title) {
  final raw = p.getString(_quickLaunchLastUsedKey(title));
  if (raw != null) return raw;
  for (final e in kQuickLaunchRenamed.entries) {
    if (e.value != title) continue;
    final old = p.getString(_quickLaunchLastUsedKey(e.key));
    if (old != null) return old;
  }
  return null;
}

/// 빠른 실행에서 실제로 눌러 들어간 시각 목록에 새 기록 하나를 맨 앞에
/// 붙인다 — 위젯 없이 시험 가능한 순수 함수(원래 목록은 안 바꾸고 새
/// 목록을 돌려준다). 오래된 것은 [max]개까지만 남긴다.
List<DateTime> quickLaunchAppendHistory(
  List<DateTime> history,
  DateTime now, {
  int max = 8,
}) {
  final next = [now, ...history];
  return next.length > max ? next.sublist(0, max) : next;
}

/// SharedPreferences에 저장해 둔 글을 사용 시각 목록으로 되돌린다.
List<DateTime> quickLaunchDecodeHistory(String? raw) {
  if (raw == null || raw.isEmpty) return [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded
          .whereType<String>()
          .map(DateTime.tryParse)
          .whereType<DateTime>()
          .toList();
    }
  } catch (_) {
    // JSON이 아니면 예전 형식(글 하나)일 수 있으니 아래에서 마저 시도한다.
  }
  final single = DateTime.tryParse(raw);
  return single == null ? [] : [single];
}

/// [quickLaunchDecodeHistory]의 반대 — 저장할 글로 바꾼다.
String quickLaunchEncodeHistory(List<DateTime> history) =>
    jsonEncode(history.map((d) => d.toIso8601String()).toList());

class _MobileMenuPageState extends State<MobileMenuPage>
    with WidgetsBindingObserver {
  // 🚀 [통신 없는 현장] 날씨를 못 불러왔는지. 못 불러오면 "동기화 중..."에 머물지 않고
  // 다시 부를 수 있게 알려 준다.
  bool _weatherFailed = false;
  // 🚀 [신규] "내 일정 관리" 메뉴 버튼에 "오늘 N건" 배지를 보여주기 위한
  // 오늘 미완료 일정 개수 - 프로젝트 일정 + 개인 일정(반복 포함)을 합산.
  int? _todayScheduleCount;
  // 오늘 작업 일지를 안 쓴 진행중 프로젝트 수(모르면 null).
  int? _missingReports;
  // 필드 헬퍼 2번: 최소 수량 아래로 내려간 자재 수(자재 현황과 같은 기준).
  int? _lowStock;

  // ── 빠른 실행(즐겨찾기) ──
  /// 즐겨찾기한 메뉴 제목들(제목이 곧 아이디 — 다 서로 다른 글이라 겹치지 않는다).
  Set<String> _favorites = {};

  /// 빠른 실행 줄 순서(편집 모드에서 꾹 눌러 끌어 바꾼다). 즐겨찾기 제목들만 담는다.
  List<String> _quickOrder = [];

  /// 전체 메뉴 대신 빠른 실행(즐겨찾기 카드)만 보이는 중인지. 시작 화면은
  /// 항상 빠른 실행이다(사용자 요청 2026-09-27) — 폰에 저장해 두지 않는다.
  bool _quickMode = true;

  /// 빠른 실행 목록을 편집(빼기) 중인지 — 헤더 점 세개 메뉴 "빠른 실행
  /// 편집"으로 켠다. 켜져 있으면 줄을 눌러도 실행 안 되고 빼기만 된다
  /// (2026-09-28, 길게 누르기가 "작업 히스토리 보기"로 바뀌면서 빼기는
  /// 따로 편집 모드를 둠).
  bool _editMode = false;

  /// 이번 build에서 만든 메뉴 버튼들(빠른 실행 화면이 여기서 골라 쓴다).
  final List<_MenuEntry> _menuEntries = [];

  // 점검 기한이 지났거나 7일 안에 오는 공구 수(홈 배지). 폰에 저장된 것만 읽어 빠르다.
  int _equipDue = 0;

  Future<void> _loadEquipmentDue() async {
    try {
      final list = await EquipmentStore.load();
      final s = summarize(list, DateTime.now());
      if (mounted) setState(() => _equipDue = s.overdue + s.soon);
    } catch (_) {}
  }

  static const String _kFavoritesKey = 'home_quick_launch_favorites_v1';
  static const String _kQuickOrderKey = 'home_quick_launch_order_v1';

  // 🚀 날씨 상세 데이터 상태 관리
  String _weatherDesc = "확인 중";
  String _pmState = "확인 중";
  String _currentTemp = "-";
  // 🚀 [날씨 고도화] GPS로 위치를 못 가져올 때(권한 거부, 위치 서비스
  // 꺼짐 등)를 대비한 기본 지역명 - 원래 하드코딩돼 있던 부산을 그대로
  // 폴백 값으로 남겨뒀다.
  String _cityName = "부산";
  bool _rainExpected = false;
  String _rainStart = "";
  String _rainEnd = "";
  double _totalRain = 0.0;
  bool _isWeatherLoaded = false;
  // 마지막으로 날씨를 성공적으로 받은 시각. 앱을 켜 둔 채 자동으로 다시 받을 때 쓴다.
  DateTime? _weatherAt;
  Timer? _weatherTimer;
  // 위치를 몰라 부산 날씨를 보인다(화면에 알린다).
  bool _locationUnknown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadEquipmentDue();
    // 공구 점검 기한 알림을 다시 잡는다(폰을 껐다 켜거나 다른 폰에서 고쳐도 맞게).
    EquipmentStore.load()
        .then(rescheduleEquipmentReminders)
        .catchError((_) => 0);
    _fetchDetailedWeather();
    // 다른 기기(폰↔태블릿)에서 고친 계산기 설정이 더 새로우면 받는다(기다리지 않음, 통신이 없으면 그대로).
    pullNewerCalculatorSettings();
    _weatherTimer = Timer.periodic(
      kWeatherRefreshEvery,
      (_) => _refreshWeatherIfShown(),
    );
    _loadTodayScheduleCount();
    _loadMissingReports();
    _loadLowStock();
    _loadQuickLaunchSettings();
    _loadTodayAttendanceForWidget();
    HomeWidgetSync.pendingAction.addListener(_onWidgetAction);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onWidgetAction());
    // 격주·평일·반복 끝이 있는 일정 알림은 한 번씩만 잡혀 있어서 다음 회차를 다시 잡아야
    // 한다. 예전엔 "내 일정" 화면을 열 때만 잡아서, 며칠 안 열면 알림이 끊겼다.
    // 앱을 켤 때 한 번(기다리지 않음, 통신이 없으면 폰 캐시로).
    if (!_remindersRescheduledThisRun) {
      _remindersRescheduledThisRun = true;
      rescheduleDriftingMonthlyReminders();
    }
  }

  static bool _remindersRescheduledThisRun = false;

  // ── 홈 화면 위젯 ──
  /// 오늘 근태 종류(위젯 "오늘 요약"에 보인다). 아직 못 읽었으면 null.
  String? _todayAttendance;

  Future<void> _loadTodayAttendanceForWidget() async {
    try {
      await AttendanceCache.refresh();
      if (!mounted) return;
      _todayAttendance = AttendanceCache.byDate[dateKey(DateTime.now())];
      _syncSummaryWidget();
      await _syncClockWidget();
    } catch (_) {}
  }

  /// 출퇴근 위젯에 오늘 상태(출근 전·근무 중·퇴근함)를 넘긴다. 못 읽으면 보내지 않는다(위젯은 낡은 값이면 단추를 둘 다 보인다).
  Future<void> _syncClockWidget() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final y = DateTime(now.year, now.month, now.day - 1);
    final recs = await loadAttendanceRange(
      DateTime(now.year, now.month, now.day - 7),
      today,
    );
    if (!mounted || recs == null) return;
    final st = clockStatus(
      now: now,
      today: recs[dateKey(today)],
      yesterday: recs[dateKey(y)],
    );
    HomeWidgetSync.push(
      clockJson: encodeClockWidgetPayload(st, now, records: recs),
    );
  }

  /// 빠른 실행 위젯에 지금 즐겨찾기 순서를 넘긴다(같은 값이면 안 보낸다).
  void _syncQuickWidget() {
    HomeWidgetSync.push(quickJson: encodeQuickWidgetPayload(_quickTitles()));
  }

  /// 오늘 요약 위젯에 지금 알고 있는 값을 넘긴다. 아직 못 읽은 값은 위젯에 "—"로 보인다.
  void _syncSummaryWidget() {
    final now = DateTime.now();
    const wd = ['월', '화', '수', '목', '금', '토', '일'];
    String two(int v) => v.toString().padLeft(2, '0');
    HomeWidgetSync.push(
      summaryJson: encodeSummaryWidgetPayload(
        date: '${now.month}월 ${now.day}일 (${wd[now.weekday - 1]})',
        schedule: _todayScheduleCount,
        reports: _missingReports,
        stock: _lowStock,
        attendance: _todayAttendance,
        updatedAt: '${two(now.hour)}:${two(now.minute)}',
      ),
    );
  }

  /// 위젯을 눌러 들어온 동작을 한다. "quick:제목"이면 그 빠른 실행 기능을 연다.
  void _onWidgetAction() {
    final a = HomeWidgetSync.pendingAction.value;
    if (a == null || !mounted) return;
    // 출퇴근 위젯 단추: 근태 화면을 열면서 지금 시각으로 한 번 찍는다(화면이 이미 찍었는지 확인한다).
    final att = a.attendanceAction;
    if (att != null) {
      HomeWidgetSync.pendingAction.value = null;
      final auto = switch (att) {
        'in' => AttendanceAutoPunch.clockIn,
        'out' => AttendanceAutoPunch.clockOut,
        _ => AttendanceAutoPunch.none,
      };
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AttendancePage(autoPunch: auto)),
        );
      });
      return;
    }
    // 압력시험 위젯: 시험 기록 탭(타이머)을 연다.
    if (a.isPressureOpen) {
      HomeWidgetSync.pendingAction.value = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const PressureTestPage(initialTab: kPtRecordTabIndex),
          ),
        );
      });
      return;
    }
    final quick = a.quickTitle;
    final title = quick == null ? null : (kQuickLaunchRenamed[quick] ?? quick);
    if (title == null) {
      HomeWidgetSync.pendingAction.value = null; // "open"·"summary": 앱만 열면 된다.
      return;
    }
    // 메뉴 줄은 첫 build 뒤에 만들어지므로 한 프레임 기다린 뒤 찾는다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || HomeWidgetSync.pendingAction.value != a) return;
      final entry = _menuEntries.where((e) => e.title == title).firstOrNull;
      HomeWidgetSync.pendingAction.value = null;
      if (entry != null) _enterFromQuickLaunch(entry);
    });
  }

  @override
  void dispose() {
    _weatherTimer?.cancel();
    HomeWidgetSync.pendingAction.removeListener(_onWidgetAction);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 앱을 켜 둔 채로도 날씨가 낡지 않게 한다(사용자 요청 2026-09-27).
  // - 앱이 앞에 있는 동안 [kWeatherRefreshEvery]마다 조용히 다시 받는다. 통신이 안 되면 받아 둔 값을 그대로 두고
  //   화면에 "기준 시각"만 보인다(하루 48번, 한 번에 3건이라 무료 한도 안).
  // - 앱을 다시 볼 때 못 불러왔었거나 받은 지 [kWeatherRefreshEvery]가 지났으면 바로 다시 받는다.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 홈이 맨 앞일 때만 받는다(계산 화면을 쓰는 중에 설정이 바뀌지 않게).
    if (state == AppLifecycleState.resumed &&
        (ModalRoute.of(context)?.isCurrent ?? false)) {
      pullNewerCalculatorSettings();
    }
    if (state == AppLifecycleState.resumed &&
        (_weatherFailed || _weatherIsOld)) {
      _fetchDetailedWeather(quiet: !_weatherFailed);
    }
  }

  bool get _weatherIsOld => weatherIsOld(_weatherAt, DateTime.now());

  /// 받은 지 한 시간이 넘었으면(자동 갱신이 계속 실패했다는 뜻) 화면에 기준 시각을 적는다.
  bool get _weatherIsStale => weatherIsStale(_weatherAt, DateTime.now());

  void _refreshWeatherIfShown() {
    if (!mounted) return;
    final state = WidgetsBinding.instance.lifecycleState;
    if (state != null && state != AppLifecycleState.resumed) return;
    _fetchDetailedWeather(quiet: !_weatherFailed);
  }

  Future<void> _loadMissingReports() async {
    final n = await fetchMissingReportCount();
    if (mounted) setState(() => _missingReports = n);
    _syncSummaryWidget();
  }

  Future<void> _loadLowStock() async {
    final n = await fetchLowStockCount();
    if (mounted) setState(() => _lowStock = n);
    _syncSummaryWidget();
  }

  Future<void> _loadQuickLaunchSettings() async {
    try {
      final p = await SharedPreferences.getInstance();
      final favs = p.getStringList(_kFavoritesKey);
      final order = p.getStringList(_kQuickOrderKey);
      if (!mounted) return;
      setState(() {
        if (favs != null) _favorites = renameQuickLaunchTitles(favs).toSet();
        if (order != null) _quickOrder = renameQuickLaunchTitles(order);
      });
      // 메뉴 줄은 첫 build 뒤에 생기므로 한 프레임 뒤에 빠른 실행 위젯에 넘긴다.
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncQuickWidget());
    } catch (_) {}
  }

  Future<void> _saveFavorites() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_kFavoritesKey, _favorites.toList());
      await p.setStringList(_kQuickOrderKey, _quickOrder);
      _syncQuickWidget();
    } catch (_) {}
  }

  /// 지금 화면에 보이는 빠른 실행 제목들(저장된 순서 → 나머지는 메뉴 순서).
  List<String> _quickTitles() => orderQuickLaunch([
    for (final e in _menuEntries)
      if (_favorites.contains(e.title)) e.title,
  ], _quickOrder);

  /// 메뉴 카드를 길게 누르면 즐겨찾기(빠른 실행)에 넣거나 뺀다.
  void _toggleFavorite(String title) {
    HapticFeedback.mediumImpact();
    final wasFav = _favorites.contains(title);
    // 새로 넣은 건 맨 아래에 붙이고, 뺀 건 순서에서도 지운다(지금 보이는 순서를 먼저 굳힌 뒤에).
    final current = _quickTitles();
    setState(() {
      _favorites = toggleQuickLaunchFavorite(_favorites, title);
      _quickOrder = wasFav
          ? [
              for (final t in current)
                if (t != title) t,
            ]
          : [...current, title];
    });
    _saveFavorites();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 1),
          content: Text(
            _favorites.contains(title)
                ? '"$title"을(를) 빠른 실행에 넣었습니다'
                : '"$title"을(를) 빠른 실행에서 뺐습니다',
          ),
        ),
      );
  }

  void _toggleQuickMode() {
    HapticFeedback.selectionClick();
    setState(() => _quickMode = !_quickMode);
  }

  /// "전체 메뉴 ⇄ 빠른 실행" 전환 알약 단추(공학용 계산기의 기본/공학 모드
  /// 전환과 같은 생김새).
  Widget _buildModeToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: GestureDetector(
        key: const Key('home_quick_toggle'),
        onTap: _toggleQuickMode,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: slate100,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _quickMode ? Icons.apps : Icons.bolt,
                size: 18,
                color: tossBlue,
              ),
              const SizedBox(width: 6),
              Text(
                _quickMode ? '전체 메뉴 보기' : '빠른 실행 보기',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: slate900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 즐겨찾기한 메뉴를, 전체 메뉴 목록과 같은 줄 모양으로 걸러 보여주는
  /// 빠른 실행 화면.
  Widget _buildQuickLaunch() {
    final byTitle = {for (final e in _menuEntries) e.title: e};
    final favEntries = [
      for (final t in _quickTitles())
        if (byTitle[t] != null) byTitle[t]!,
    ];
    if (favEntries.isEmpty) {
      return Padding(
        key: const Key('home_quick_launch_empty'),
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
        // 글씨 폭만큼만 차지하면 왼쪽에 쏠려 보여서, 가로 전체를 채워 가운데에 둔다.
        child: SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              Icon(Icons.star_border, size: 40, color: slate600),
              const SizedBox(height: 12),
              const Text(
                "빠른 실행에 넣은 기능이 없습니다",
                style: TextStyle(fontWeight: FontWeight.w700, color: slate900),
              ),
              const SizedBox(height: 6),
              const Text(
                "전체 메뉴에서 카드를 길게 누르면 여기 추가됩니다.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: slate600),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      key: const Key('home_quick_launch'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 편집 모드일 때만 보이는 안내 줄 — 헤더 점 세개의 "빠른 실행
        // 편집"으로 켜진다. 여기서 "완료"를 누르면 끈다.
        if (_editMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    "빠른 실행 편집 중: 길게 눌러 끌면 순서 바꾸기, ⊖로 빼기",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: slate600,
                    ),
                  ),
                ),
                TextButton(
                  key: const Key('home_quick_edit_done'),
                  onPressed: () => setState(() => _editMode = false),
                  child: const Text(
                    "완료",
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        if (_editMode)
          // 편집 중에는 줄을 꾹 눌러(0.5초) 끌어서 순서를 바꾼다. 집어 올릴 때·놓을 때
          // 손끝에 진동을 줘서 "잡혔다/놓았다"가 느껴지게 한다.
          ReorderableListView(
            key: const Key('home_quick_reorder'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderStart: (_) => HapticFeedback.heavyImpact(),
            onReorderEnd: (_) => HapticFeedback.lightImpact(),
            proxyDecorator: (child, index, animation) => Material(
              elevation: 8,
              color: pureWhite,
              borderRadius: BorderRadius.circular(14),
              shadowColor: Colors.black38,
              child: child,
            ),
            onReorder: (oldIndex, newIndex) {
              final titles = [for (final e in favEntries) e.title];
              setState(
                () => _quickOrder = moveQuickLaunch(titles, oldIndex, newIndex),
              );
              HapticFeedback.selectionClick();
              _saveFavorites();
            },
            children: [
              for (var i = 0; i < favEntries.length; i++)
                ReorderableDelayedDragStartListener(
                  key: ValueKey('quick_reorder_${favEntries[i].title}'),
                  index: i,
                  child: _buildQuickLaunchRow(favEntries[i]),
                ),
            ],
          )
        else
          for (final e in favEntries) _buildQuickLaunchRow(e),
      ],
    );
  }

  /// 즐겨찾기 한 줄 — 전체 메뉴 목록의 줄과 똑같은 모양(아이콘 원·제목·부제·
  /// 화살표)으로 그린다. 누르면 바로 그 기능으로 들어가면서 사용 기록을
  /// 남기고, 길게 누르면 그 기록("작업 히스토리")을 보여준다. 즐겨찾기에서
  /// 빼는 건 길게 누르기가 아니라 헤더 "빠른 실행 편집"으로 들어가야 한다
  /// (2026-09-28 — 길게 누르기 자리를 히스토리 보기로 내줌).
  Widget _buildQuickLaunchRow(_MenuEntry entry) {
    return PressFeedback(
      child: InkWell(
        key: Key('home_quick_${entry.title}'),
        onTap: _editMode
            ? null
            : () {
                HapticFeedback.selectionClick();
                _enterFromQuickLaunch(entry);
              },
        onLongPress: _editMode ? null : () => _showQuickLaunchHistory(entry),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: entry.iconColor.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: AppIcon(entry.icon, size: 28, color: entry.iconColor),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            entry.title,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: entry.iconColor,
                              letterSpacing: -0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (entry.badgeText != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: entry.badgeColor ?? warningRed,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              entry.badgeText!,
                              style: const TextStyle(
                                color: pureWhite,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: slate600,
                      ),
                    ),
                  ],
                ),
              ),
              if (_editMode)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      key: Key('home_quick_remove_${entry.title}'),
                      onTap: () => _toggleFavorite(entry.title),
                      child: const Icon(
                        Icons.remove_circle,
                        color: warningRed,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.drag_handle,
                      key: Key('home_quick_handle_${entry.title}'),
                      color: slate600.withValues(alpha: 0.6),
                      size: 26,
                    ),
                  ],
                )
              else
                Icon(
                  AppIcons.forward,
                  color: slate600.withValues(alpha: 0.5),
                  size: 28,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 빠른 실행 줄을 눌러 진짜 그 기능으로 들어갈 때 — 사용 시각을
  /// "작업 히스토리"에 남기고 연다.
  Future<void> _enterFromQuickLaunch(_MenuEntry entry) async {
    try {
      final p = await SharedPreferences.getInstance();
      final key = _quickLaunchLastUsedKey(entry.title);
      final history = quickLaunchDecodeHistory(
        _readQuickLaunchHistory(p, entry.title),
      );
      await p.setString(
        key,
        quickLaunchEncodeHistory(
          quickLaunchAppendHistory(history, DateTime.now()),
        ),
      );
    } catch (_) {}
    entry.onTap();
  }

  /// 빠른 실행 줄을 길게 누르면 뜨는 "작업 히스토리". 벤딩·전선관 벤딩
  /// 마킹 계산기는 이미 저장한 도면(보관함) 기록이 있어서 "몇 분 전 한 번
  /// 썼다"는 의미 없는 시각 대신 **무슨 프로젝트로 뭘 했는지**를 그대로
  /// 보여준다 — 나머지 화면은 그런 기록이 없어서 실행한 시각 목록으로
  /// 대신한다(2026-09-28 사용자 요청).
  Future<void> _showQuickLaunchHistory(_MenuEntry entry) async {
    HapticFeedback.selectionClick();
    List<Widget> rows;
    if (entry.title == '튜브 벤딩 마킹') {
      rows = await _tubeWorkHistoryRows();
    } else if (entry.title == '전선관 벤딩 마킹') {
      rows = await _conduitWorkHistoryRows();
    } else {
      rows = await _genericQuickLaunchHistoryRows(entry.title);
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        key: const Key('quick_launch_history_sheet'),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.7,
        ),
        decoration: const BoxDecoration(
          color: pureWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: entry.iconColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: AppIcon(entry.icon, size: 22, color: entry.iconColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    '${entry.title} · 작업 기록',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: slate900,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: slate600),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: rows,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 저장한 도면이 없는 화면들 — "실행한 시각" 목록으로 대신한다(예전 방식).
  Future<List<Widget>> _genericQuickLaunchHistoryRows(String title) async {
    List<DateTime> history = [];
    try {
      final p = await SharedPreferences.getInstance();
      history = quickLaunchDecodeHistory(_readQuickLaunchHistory(p, title));
    } catch (_) {}
    if (history.isEmpty) {
      return const [
        Text(
          "아직 이 화면을 빠른 실행으로 연 기록이 없습니다.",
          style: TextStyle(color: slate600, height: 1.4),
        ),
      ];
    }
    final now = DateTime.now();
    return [
      for (final t in history)
        _workHistoryRow(title: quickLaunchRelativeTime(t, now), subtitle: ''),
    ];
  }

  /// 튜브 벤딩 마킹이 실제로 저장해 둔 도면 기록(보관함, SQLite
  /// `history` 테이블)에서 "무슨 프로젝트로 뭘 했는지"를 그대로 읽어 온다.
  Future<List<Widget>> _tubeWorkHistoryRows() async {
    List<Map<String, dynamic>> rows = [];
    try {
      rows = await DatabaseHelper.instance.getHistory();
    } catch (_) {}
    if (rows.isEmpty) {
      return const [
        Text(
          "아직 저장한 도면이 없습니다.",
          style: TextStyle(color: slate600, height: 1.4),
        ),
      ];
    }
    return [
      for (final item in rows.take(6))
        _workHistoryRow(
          title: _tubeHistoryTitle(item),
          subtitle: _tubeHistorySubtitle(item),
        ),
    ];
  }

  String _tubeHistoryTitle(Map<String, dynamic> item) {
    try {
      final p = jsonDecode(item['p_to_p'] ?? '{}');
      final project = (p['project'] ?? '프로젝트 미지정').toString();
      final from = (p['from'] ?? '모름').toString();
      final to = (p['to'] ?? '모름').toString();
      return '$project · $from ➔ $to';
    } catch (_) {
      return '경로 모름';
    }
  }

  String _tubeHistorySubtitle(Map<String, dynamic> item) {
    String note = '';
    try {
      final p = jsonDecode(item['p_to_p'] ?? '{}');
      note = (p['note'] ?? '').toString();
    } catch (_) {}
    final cut = (double.tryParse(item['total_length']?.toString() ?? '') ?? 0.0)
        .round();
    final date = (item['date'] ?? '').toString();
    return [if (note.isNotEmpty) note, '총 ${cut}mm', date].join(' · ');
  }

  /// 전선관 벤딩 마킹의 보관함(SharedPreferences에 저장한 도면
  /// 목록)에서 "무슨 작업(묶음)으로 뭘 했는지"를 그대로 읽어 온다.
  Future<List<Widget>> _conduitWorkHistoryRows() async {
    List<ConduitDrawing> drawings = [];
    try {
      drawings = await loadConduitDrawings();
    } catch (_) {}
    if (drawings.isEmpty) {
      return const [
        Text(
          "아직 저장한 도면이 없습니다.",
          style: TextStyle(color: slate600, height: 1.4),
        ),
      ];
    }
    return [
      for (final d in drawings.take(6))
        _workHistoryRow(
          title: '${d.folderName} · ${d.title}',
          subtitle: [
            if (d.notes.isNotEmpty) d.notes,
            '총 ${d.totalCut.round()}mm',
            d.date,
          ].join(' · '),
        ),
    ];
  }

  /// "작업 히스토리" 목록 한 줄 — 제목(굵게)과, 있으면 부제(메모·길이·날짜)를 함께.
  Widget _workHistoryRow({required String title, required String subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.history, size: 16, color: slate600.withValues(alpha: 0.7)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: slate900,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: slate600, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadTodayScheduleCount() async {
    final count = await fetchTodayScheduleCount(widget.currentWorker);
    if (mounted) setState(() => _todayScheduleCount = count);
    _syncSummaryWidget();
  }

  // 🚀 날씨 상태 단순화 (맑음, 흐림, 비, 눈)
  String _simplifyWeather(String mainCondition) {
    switch (mainCondition) {
      case 'Clear':
        return '맑음';
      case 'Clouds':
        return '흐림';
      case 'Rain':
      case 'Drizzle':
      case 'Thunderstorm':
        return '비';
      case 'Snow':
        return '눈';
      default:
        return '흐림';
    }
  }

  // 🚀 [날씨 고도화] 위치 권한을 확인/요청하고 현재 위치를 가져온다.
  // 위치 서비스가 꺼져 있거나, 권한이 거부/영구거부됐거나, 어떤
  // 이유로든 실패하면 null을 돌려줘서 호출한 쪽이 기존 하드코딩된
  // 부산 좌표로 조용히 폴백하게 한다 - 위치를 못 가져왔다고 날씨
  // 기능 자체가 죽으면 안 되니까.
  // 🚀 [고침] 예전에는 홈이 뜨자마자 위치 권한을 물었다(무엇에 쓰는지 알기 전이라
  // 거절하기 쉽고, 거절하면 다시 안 물어 준다). 이제 켤 때는 이미 허용된 경우만 쓰고,
  // 날씨 카드를 누를 때([ask]) 묻는다. 날씨에는 대략 위치면 충분하다(건물 안에서
  // 정밀 GPS를 기다리다 8초를 다 쓰던 것).
  Future<Position?> _determinePosition({bool ask = false}) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && ask) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      // 🚀 [고침] 통신·GPS가 약하면 위치 8초 + 날씨 8초로 최대 16초 빈칸이었다.
      // 마지막으로 알던 위치가 있으면 바로 쓰고, 없을 때만 짧게 기다린다.
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      return null;
    }
  }

  // 🚀 [날씨 위치 버그 수정] OpenWeatherMap의 지역명(weather API의 "name"
  // 필드)은 자체 도시 목록 중 좌표에서 가장 가까운 항목을 고르는 방식이라,
  // "부산 지사동"처럼 실제로는 잘 안 쓰는 동네 이름이 나올 수 있었다(GPS
  // 좌표 자체는 맞아도, OWM 도시 목록의 매칭 결과가 지나치게 세분화됨).
  // 기기 자체 지오코더(Android는 Google 지오코딩 서비스 이용)로 "시/도 +
  // 구/군" 수준의 더 알아보기 쉬운 이름을 만들고, 실패하면 OWM 이름으로
  // 폴백한다.
  Future<String?> _resolveCityLabel(Position? position, String? owmName) async {
    if (position != null) {
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final String city = (p.locality?.isNotEmpty ?? false)
              ? p.locality!
              : (p.administrativeArea ?? '');
          final String district = (p.subLocality?.isNotEmpty ?? false)
              ? p.subLocality!
              : (p.subAdministrativeArea ?? '');
          final parts = <String>{
            city,
            district,
          }.where((s) => s.isNotEmpty).toList();
          if (parts.isNotEmpty) return parts.join(' ');
        }
      } catch (e) {
        // 기기 지오코더가 없거나(플레이 서비스 미탑재 등) 실패하면
        // 아래 OWM 이름으로 조용히 폴백한다.
      }
    }
    return (owmName != null && owmName.isNotEmpty) ? owmName : null;
  }

  // 🚀 API 3개(현재날씨, 대기질, 일기예보)를 동시에 불러와 분석
  // [quiet]이면 자동 갱신이다: 실패해도 받아 둔 값을 지우지 않는다.
  Future<void> _fetchDetailedWeather({bool quiet = false}) async {
    try {
      const String apiKey = 'ce796b79713bbdf70ec6a7cfb98f2b11';
      // 🚀 [날씨 고도화] 원래 부산 좌표로 고정돼 있던 걸, GPS로 가져온
      // 현재 위치가 있으면 그걸 쓰고 없으면 부산으로 폴백하도록 바꿨다 -
      // 현장을 옮겨 다니는 작업 특성상 지금 있는 곳 날씨가 더 쓸모 있다.
      final position = await _determinePosition();
      if (mounted) setState(() => _locationUnknown = position == null);
      final double lat = position?.latitude ?? 35.1795;
      final double lon = position?.longitude ?? 129.0756; // 부산 좌표(폴백)

      final weatherUrl = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$apiKey&units=metric&lang=kr',
      );
      final airUrl = Uri.parse(
        'https://api.openweathermap.org/data/2.5/air_pollution?lat=$lat&lon=$lon&appid=$apiKey',
      );
      final forecastUrl = Uri.parse(
        'https://api.openweathermap.org/data/2.5/forecast?lat=$lat&lon=$lon&appid=$apiKey&units=metric&lang=kr',
      );

      // 통신이 없으면 응답이 오지 않으므로 오래 기다리지 않는다.
      final responses = await Future.wait([
        http.get(weatherUrl),
        http.get(airUrl),
        http.get(forecastUrl),
      ]).timeout(const Duration(seconds: 8));

      if (responses[0].statusCode == 200 &&
          responses[1].statusCode == 200 &&
          responses[2].statusCode == 200) {
        final weatherData = jsonDecode(responses[0].body);
        final airData = jsonDecode(responses[1].body);
        final forecastData = jsonDecode(responses[2].body);

        String mainCondition = weatherData['weather'][0]['main'];
        String desc = _simplifyWeather(mainCondition);
        // 기온이 20처럼 딱 떨어지면 정수로 와서 형이 안 맞아 실패로 보였다.
        double temp = (weatherData['main']['temp'] as num).toDouble();

        int aqi = (airData['list'][0]['main']['aqi'] as num).toInt();
        List<String> pmLabels = ['알 수 없음', '좋음', '보통', '나쁨', '매우 나쁨', '위험'];
        String pm = (aqi > 0 && aqi <= 5) ? pmLabels[aqi] : '알 수 없음';

        DateTime now = DateTime.now();
        DateTime endCheck = now.add(const Duration(hours: 24));
        DateTime? firstRain;
        DateTime? lastRain;
        double rainSum = 0.0;

        for (var item in forecastData['list']) {
          DateTime dt = DateTime.fromMillisecondsSinceEpoch(item['dt'] * 1000);
          if (dt.isAfter(endCheck)) break;

          if (item['rain'] != null && item['rain']['3h'] != null) {
            firstRain ??= dt;
            lastRain = dt;
            rainSum += (item['rain']['3h'] as num).toDouble();
          }
        }

        // 🚀 [날씨 위치 버그 수정] 기기 지오코더로 먼저 시도하고, 실패하면
        // OWM의 지역명으로 폴백한다 (자세한 이유는 _resolveCityLabel 참고).
        final String? resolvedCity = await _resolveCityLabel(
          position,
          weatherData['name'] as String?,
        );

        if (mounted) {
          setState(() {
            if (resolvedCity != null && resolvedCity.isNotEmpty) {
              _cityName = resolvedCity;
            }
            _weatherDesc = desc;
            _currentTemp = temp.toStringAsFixed(1);
            _pmState = pm;
            if (rainSum > 0 && firstRain != null && lastRain != null) {
              _rainExpected = true;
              _rainStart = "${firstRain.hour}";
              _rainEnd = "${lastRain.hour}";
              _totalRain = rainSum;
            } else {
              _rainExpected = false;
            }
            _isWeatherLoaded = true;
            _weatherFailed = false;
            _weatherAt = DateTime.now();
          });
        }
      } else {
        _setFallback(quiet: quiet);
      }
    } catch (e) {
      _setFallback(quiet: quiet);
    }
  }

  void _setFallback({bool quiet = false}) {
    if (!mounted) return;
    if (quiet && _weatherAt != null) {
      // 자동 갱신이 실패했다: 받아 둔 값은 두고 기준 시각 표시만 다시 그린다.
      setState(() {});
      return;
    }
    setState(() {
      _isWeatherLoaded = true;
      _weatherFailed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 빠른 실행 화면이 고를 수 있게 이번 build에서 새로 쌓는다(오래된 콜백이
    // 안 남게 매번 비운다).
    _menuEntries.clear();
    return Scaffold(
      backgroundColor: pureWhite,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _fetchDetailedWeather,
          color: tossBlue,
          backgroundColor: pureWhite,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(context),
                _buildSmartHeader(context),
                // 🚀 [고침] 이름 없이 쓰면 알림이 없고 일정은 저장이 막히는데, 이름을 넣을
                // 곳으로 가는 길이 오른쪽 위 작은 사람 아이콘뿐이었다.
                if (widget.currentWorker == kGuestName) _buildGuestBanner(),
                const SizedBox(height: 16),
                _buildModeToggle(),
                Offstage(
                  // 빠른 실행 모드에서도 전체 메뉴는 그대로 만들어 둔다(즐겨찾기 목록을
                  // 모으는 부수효과 때문 — _buildMenuButton이 _menuEntries에 쌓는다).
                  // 화면에만 안 보이고 자리도 안 차지한다. **순서 중요**: 아래 quickLaunch가
                  // _menuEntries를 읽으므로, 이 Offstage(=버튼들을 실제로 만드는 곳)가
                  // 먼저 와야 한다(전에는 순서가 반대라 빠른 실행이 항상 빈 목록을 봤다 —
                  // 2026-09-27 사용자가 "즐겨찾기 추가해도 없다고 나온다"고 알려줘서 찾음).
                  offstage: _quickMode,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 24.0,
                          vertical: 8.0,
                        ),
                        child: Text(
                          "프로젝트 관리",
                          style: TextStyle(
                            color: slate600,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      // 🚀 [고침] 가장 자주 하는 "오늘 작업 일지 쓰기"가 홈에 없어 홈 → 내
                      // 프로젝트 → 카드 → 일지 탭 → 작성으로 들어가야 했고, 안 쓴 수도 안 보였다.
                      _buildMenuButton(
                        context: context,
                        title: "오늘 작업 일지 쓰기",
                        subtitle: "안 쓴 프로젝트를 바로 엽니다",
                        icon: AppGlyph.project,
                        iconColor: makitaTeal,
                        badgeText: (_missingReports ?? 0) > 0
                            ? "$_missingReports곳 안 씀"
                            : null,
                        badgeColor: AppColors.caution,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            WorkRoute(
                              builder: (context) => const WorkLogMainScreen(
                                autoWriteReport: true,
                              ),
                            ),
                          ).then((_) {
                            _loadTodayScheduleCount();
                            _loadMissingReports();
                          });
                        },
                      ),
                      _buildMenuButton(
                        context: context,
                        title: "내 프로젝트",
                        subtitle: "개인 작업 일지 · 이슈 목록 · 자재 기록",
                        icon: AppGlyph.project,
                        iconColor: slate900,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            WorkRoute(
                              builder: (context) => const WorkLogMainScreen(),
                            ),
                          ).then((_) {
                            _loadTodayScheduleCount();
                            _loadMissingReports();
                          });
                        },
                      ),
                      _buildMenuButton(
                        context: context,
                        title: "작업 전 안전 점검",
                        subtitle: "항목을 확인해 기록으로 남기고 카톡으로 보내기",
                        icon: AppGlyph.safety,
                        iconColor: makitaTeal,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SafetyCheckPage(),
                            ),
                          );
                        },
                      ),
                      _buildMenuButton(
                        context: context,
                        title: "내 일정 관리",
                        subtitle: "프로젝트 일정과 개인 일정 함께 보기 · 반복 · 알림",
                        icon: AppGlyph.schedule,
                        iconColor: makitaTeal,
                        badgeText:
                            (_todayScheduleCount != null &&
                                _todayScheduleCount! > 0)
                            ? "오늘 $_todayScheduleCount건"
                            : null,
                        badgeColor: makitaTeal,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MobileMyScheduleScreen(
                                currentWorker: widget.currentWorker,
                              ),
                            ),
                          ).then((_) => _loadTodayScheduleCount());
                        },
                      ),

                      // 🚀 [정리] 2026-09-26 사용자 요청: "현장 작업" 한 묶음(13개)을 공종별로 나눔.
                      // 배관·튜브 → 전기 → 계장 → 가공·배치 → 현장 도구 → 자재 관리 → 참고 자료 순.
                      _sectionHeader("근무"),
                      _buildMenuButton(
                        context: context,
                        title: "근태 관리",
                        subtitle: "연차·월차·반차·조퇴·특근과 출퇴근 시간 기록",
                        icon: AppGlyph.schedule,
                        iconColor: slate900,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AttendancePage(),
                            ),
                          ).then((_) => _loadTodayAttendanceForWidget());
                        },
                      ),
                      _sectionHeader("배관·튜브"),
                      _buildMenuButton(
                        context: context,
                        title: "튜브 벤딩 마킹",
                        subtitle: "스마트폰용 · 단계별 치수 입력",
                        icon: AppGlyph.tubeBend,
                        iconColor: makitaTeal,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const MobileCalculatorPage(),
                            ),
                          );
                        },
                      ),

                      _buildMenuButton(
                        context: context,
                        title: "벤딩 실측 기록",
                        subtitle: "계산값과 실측값의 차이를 남겨 다음 마킹에 참고",
                        icon: AppGlyph.tubeSpec,
                        iconColor: makitaTeal,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const BendCheckPage(),
                            ),
                          );
                        },
                      ),
                      _buildMenuButton(
                        context: context,
                        title: "라인 컷팅",
                        subtitle: "부속 공제로 절단 길이 · 지시서 · 재고",
                        icon: AppGlyph.tubeCut,
                        iconColor: makitaTeal,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const MobileCuttingProjectListPage(),
                            ),
                          );
                        },
                      ),
                      _buildMenuButton(
                        context: context,
                        title: "단관 컷팅",
                        subtitle: "같은 길이 여러 개 · 원자재 본수 · 자르는 눈금",
                        icon: AppGlyph.straightPipe,
                        iconColor: makitaTeal,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ShortPipeCuttingPage(),
                            ),
                          );
                        },
                      ),
                      _buildMenuButton(
                        context: context,
                        title: "압력시험",
                        subtitle: "튜브·배관 수압·공압 시험압력 · 유지시간 기록 · 기록서",
                        icon: AppGlyph.pressureGauge,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PressureTestPage(),
                            ),
                          );
                        },
                      ),
                      _buildMenuButton(
                        context: context,
                        title: "유량 계산",
                        subtitle: "유속·관경 · 압력손실 · 차압 유량계 · 유량계 점검",
                        icon: AppGlyph.flow,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const FlowCalcPage(),
                            ),
                          );
                        },
                      ),
                      _sectionHeader("전기"),
                      _buildMenuButton(
                        context: context,
                        title: "전선관 벤딩 마킹",
                        subtitle: "장비 프로필 설정 · 마킹 뷰어",
                        icon: AppGlyph.conduitBend,
                        iconColor: Colors.blueGrey, // 메인 기능이므로 파란색 강조
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ConduitMainNavigation(),
                            ),
                          );
                        },
                      ),
                      _buildMenuButton(
                        context: context,
                        title: "전기 설비 계산",
                        subtitle: "부하 합산·전선 굵기·전압강하·단락 전류·접지·축전지",
                        icon: AppGlyph.electric,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ElectricCalculatorPage(),
                            ),
                          );
                        },
                      ),
                      _buildMenuButton(
                        context: context,
                        title: "케이블 트레이 규격 선정",
                        subtitle: "트레이 점유율 판정·권장 폭 (KEC 232.41)",
                        icon: AppGlyph.cableTray,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CableTrayPage(),
                            ),
                          );
                        },
                      ),
                      _buildMenuButton(
                        context: context,
                        title: "케이블 트레이 가공",
                        subtitle: "넘어가기·옆으로 비켜가기·단 오르내리기·가지 내기(티)",
                        icon: AppGlyph.trayRoute,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CableTrayRoutePage(),
                            ),
                          );
                        },
                      ),
                      _buildMenuButton(
                        context: context,
                        title: "부스바 가공",
                        subtitle: "L·U·Z 절곡 절단 길이와 절곡 시작선",
                        icon: AppGlyph.busbarBend,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const BusbarBendPage(),
                            ),
                          );
                        },
                      ),
                      _buildMenuButton(
                        context: context,
                        title: "접지바 가공",
                        subtitle: "구멍 위치·절단 길이·중량",
                        icon: AppGlyph.groundBar,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const GroundBarPage(),
                            ),
                          );
                        },
                      ),
                      _buildMenuButton(
                        context: context,
                        title: "분전반·조명 계산",
                        subtitle: "조명 광속법 · 분전반 상 평형 · 여러 부하 간선 전압강하",
                        icon: AppGlyph.panelBoard,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PanelDesignPage(),
                            ),
                          );
                        },
                      ),
                      _buildMenuButton(
                        context: context,
                        title: "고장 진단",
                        subtitle:
                            "차단기 트립·전압 이상·접속부 발열·지락·조명·변압기·전동기를 질문과 측정값으로 좁히기",
                        icon: AppGlyph.troubleshoot,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TroubleshootPage(),
                            ),
                          );
                        },
                      ),
                      _sectionHeader("전동기·발전기"),
                      _buildMenuButton(
                        context: context,
                        title: "전동기·발전기 계산",
                        subtitle: "전동기 공식·선정·콘덴서·구동·보호·점검, 발전기 용량",
                        icon: AppGlyph.motor,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ElectricCalculatorPage(
                                    group: ElecGroup.motor,
                                  ),
                            ),
                          );
                        },
                      ),
                      _buildMenuButton(
                        context: context,
                        title: "결선도·기동 회로",
                        subtitle: "Y·Δ 결선, 직입·정역·Y-Δ 시퀀스를 눌러 보며 이해",
                        icon: AppGlyph.ladder,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CircuitReadingPage(),
                            ),
                          );
                        },
                      ),
                      _sectionHeader("계장"),
                      _buildMenuButton(
                        context: context,
                        title: "계기 교정",
                        subtitle: "교정 점검 · 4-20mA · 온도 센서 · 교정 가스 · 성적서",
                        icon: AppGlyph.currentLoop,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const SignalCalculatorPage(),
                            ),
                          );
                        },
                      ),
                      _sectionHeader("축 정렬"),
                      _buildMenuButton(
                        context: context,
                        title: "축 정렬 계산",
                        subtitle: "모터·펌프 커플링 센터링 · 발 심 두께와 좌우 이동량",
                        icon: AppGlyph.alignment,
                        iconColor: slate900,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AlignmentPage(),
                            ),
                          );
                        },
                      ),
                      _buildMenuButton(
                        context: context,
                        title: "축 정렬 현장 지침",
                        subtitle: "배관 당김·용접 변형·소프트 풋 등 잘 안 맞을 때 조치",
                        icon: AppGlyph.alignment,
                        iconColor: slate900,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AlignmentGuidePage(),
                            ),
                          );
                        },
                      ),
                      _sectionHeader("가공·배치"),
                      _buildMenuButton(
                        context: context,
                        title: "형강 컷팅",
                        subtitle: "규격·길이만 넣어 재단 계획·지시서 출력",
                        icon: AppGlyph.steel,
                        iconColor: makitaTeal,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const MobileSteelProjectListPage(),
                            ),
                          );
                        },
                      ),
                      _buildMenuButton(
                        context: context,
                        title: "작업 배치도",
                        subtitle: "캐비닛 중판 레이아웃 및 튜빙/결선 스케치",
                        icon: AppGlyph.layout,
                        iconColor: slate900,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          // 🚀 [수정] 예전엔 여기서 바로 빈 도면을 열어서, 저장해둔
                          // 배치도를 다시 불러볼 방법이 없었다(저장은 Firestore에
                          // 되는데 불러오는 화면 자체가 없었음). 이제 목록을 먼저
                          // 보여주고, 거기서 기존 도면을 열거나 새로 시작한다.
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const LayoutBoardProjectListPage(),
                            ),
                          );
                        },
                      ),
                      _sectionHeader("현장 도구"),
                      _buildMenuButton(
                        context: context,
                        title: "도면 보기",
                        subtitle:
                            "PDF·DXF·사진 도면 보기 · 틀림·질문 표시 · 문제 목록 · 표시한 PDF 보내기",
                        icon: AppGlyph.layout,
                        iconColor: slate900,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DrawingLibraryPage(),
                            ),
                          );
                        },
                      ),
                      _buildMenuButton(
                        context: context,
                        title: "단위 환산",
                        subtitle: "길이·압력·온도·토크·분수 인치·배관 호칭",
                        icon: AppGlyph.unitConvert,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const UnitConverterPage(),
                            ),
                          );
                        },
                      ),
                      _buildMenuButton(
                        context: context,
                        title: "수평계",
                        subtitle: "기포 수평계 · 배관 구배(%·mm/m) · 영점 맞추기",
                        icon: AppGlyph.level,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LevelPage(),
                            ),
                          );
                        },
                      ),
                      _buildMenuButton(
                        context: context,
                        title: "각도기",
                        subtitle: "벤딩 각도 재기 · 화면 각도기",
                        icon: AppGlyph.protractor,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProtractorPage(),
                            ),
                          );
                        },
                      ),
                      _buildMenuButton(
                        context: context,
                        title: "공학용 계산기",
                        subtitle: "사칙연산·삼각함수·거듭제곱 · 인치 분수·피트",
                        icon: AppGlyph.engCalc,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const EngCalculatorPage(),
                            ),
                          );
                        },
                      ),
                      _buildMenuButton(
                        context: context,
                        title: "벤딩 리모컨",
                        subtitle: "수치 전송용 리모컨 (스마트폰 권장)",
                        icon: AppGlyph.remote,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MobileRemotePage(),
                            ),
                          );
                        },
                      ),
                      _buildMenuButton(
                        context: context,
                        title: "현장 도면 스캔 (QR)",
                        subtitle: "종이 지시서 QR을 찍어 3D 뷰어로 보기",
                        icon: AppGlyph.scan,
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          final String? scannedData = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const QRScannerPage(),
                            ),
                          );

                          if (scannedData != null && context.mounted) {
                            try {
                              Uri uri = Uri.parse(scannedData);
                              String project =
                                  uri.queryParameters['p'] ?? "Scanned Project";
                              String pipeSize =
                                  uri.queryParameters['s'] ?? "1/4\"";
                              String bendsStr = uri.queryParameters['b'] ?? "";
                              bool startFit =
                                  uri.queryParameters['sf'] == 'true';
                              bool endFit = uri.queryParameters['ef'] == 'true';
                              double tail =
                                  double.tryParse(
                                    uri.queryParameters['t'] ?? '0.0',
                                  ) ??
                                  0.0;
                              String startDir =
                                  uri.queryParameters['d'] ?? 'RIGHT';
                              List<Map<String, double>> parsedBends = [];

                              if (bendsStr.isNotEmpty) {
                                final parts = bendsStr.split('-');
                                for (var part in parts) {
                                  final vals = part.split('_');
                                  if (vals.length >= 3) {
                                    parsedBends.add({
                                      'length': double.tryParse(vals[0]) ?? 0.0,
                                      'angle': double.tryParse(vals[1]) ?? 0.0,
                                      'rotation':
                                          double.tryParse(vals[2]) ?? 0.0,
                                      'mark': vals.length >= 4
                                          ? (double.tryParse(vals[3]) ?? 0.0)
                                          : 0.0,
                                    });
                                  }
                                }
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ViewerOnlyScreen(
                                    project: project,
                                    pipeSize: pipeSize,
                                    bendList: parsedBends,
                                    startFit: startFit,
                                    endFit: endFit,
                                    tailLength: tail,
                                    startDir: startDir,
                                  ),
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    "QR 코드를 읽을 수 없습니다.",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  backgroundColor: Colors.redAccent.shade400,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                      ),
                      _sectionHeader("자재 관리"),
                      _buildMenuButton(
                        context: context,
                        title: "자재 현황",
                        subtitle: "지금 재고 확인 및 현장 자재 입출고 처리",
                        icon: AppGlyph.stock,
                        iconColor: slate900,
                        // 필드 헬퍼 2번: 현장 나가기 전에 홈만 보고 부족한 자재를 알 수 있게.
                        badgeText: (_lowStock ?? 0) > 0
                            ? "$_lowStock건 부족"
                            : null,
                        badgeColor: AppColors.caution,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MobileInventoryStatusPage(
                                workerName: widget.currentWorker,
                              ),
                            ),
                          ).then((_) => _loadLowStock());
                        },
                      ),
                      _buildMenuButton(
                        context: context,
                        title: "장비 관리 대장",
                        subtitle: "개인·작업 공구 점검 기한, QR 찾기",
                        icon: AppGlyph.equipment,
                        iconColor: slate900,
                        badgeText: _equipDue > 0 ? "기한 $_equipDue건" : null,
                        badgeColor: AppColors.caution,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const EquipmentLedgerPage(),
                            ),
                          ).then((_) => _loadEquipmentDue());
                        },
                      ),
                      _buildMenuButton(
                        context: context,
                        title: "재고조사·자재 등록",
                        subtitle: "재고조사 · 새 자재 등록 및 삭제",
                        icon: AppGlyph.stockAdmin,
                        iconColor: slate900,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const MobileInventoryLoginScreen(),
                            ),
                          ).then((_) => _loadLowStock());
                        },
                      ),
                      _buildMenuButton(
                        context: context,
                        title: "자재 요청 정리",
                        subtitle: "손으로 쓴 요청 메모를 찍으면 목록으로 정리해 카톡으로 보내기",
                        icon: AppGlyph.materialRequest,
                        iconColor: slate900,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MaterialRequestPage(),
                            ),
                          );
                        },
                      ),
                      _sectionHeader("참고 자료"),
                      _buildMenuButton(
                        context: context,
                        title: "자료 검색",
                        subtitle: "증상·코드·장비 이름으로 고장 조치·알람 코드·현장 자료 찾기",
                        icon: AppGlyph.searchDocs,
                        iconColor: slate900,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const KnowledgeSearchPage(),
                            ),
                          );
                        },
                      ),
                      _buildMenuButton(
                        context: context,
                        title: "현장 자료",
                        subtitle: "튜브·전선관·형강 규격표, 발전 설비, 전기 기준(KEC)",
                        icon: AppGlyph.tubeSpec,
                        iconColor: slate900,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TubeReferencePage(),
                            ),
                          );
                        },
                      ),
                      _buildMenuButton(
                        context: context,
                        title: "장비 사용법",
                        subtitle: "벤더·절단기·계측기 쓰는 법, 주의·정비·고장·정리",
                        icon: AppGlyph.benderHand,
                        iconColor: slate900,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const EquipmentUsagePage(),
                            ),
                          );
                        },
                      ),
                      // 🚀 [정리] "자재 발주 및 현황"과 "발주 의뢰 내역"은 메뉴에서 뺐다
                      // (2026-09-20). 발주 기록이 한 건도 없고, 발주를 넣으면 지금
                      // 숨겨 둔 현장 소통(채팅)으로 글이 가는 반쪽 구조였다. 화면
                      // 파일(발주·발주 기록·채팅·차량 관리자)은 2026-09-23에 지웠다.
                      // 필요해지면 git 기록(3bef015 이전)에서 꺼내 여기에 붙이면 된다.
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
                if (_quickMode) _buildQuickLaunch(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 메뉴 기능을 이름·설명으로 찾는 창(초성도 된다). 누르면 그 메뉴를 그대로 연다.
  // 검색 창 하나를 여는 동안 프로젝트 목록은 폰에 있는 것을 한 번만 읽어 쓴다.
  Future<List<Map<String, dynamic>>> _readLogsForSearch() async {
    try {
      return await WorkProjectRepository().fetchCachedProjects();
    } catch (_) {
      return const [];
    }
  }

  Future<List<FeatureItem>> _recordResults(
    String q,
    Future<List<Map<String, dynamic>>> logs,
  ) async {
    final hits = searchRecords(q, await logs, allMaterialCatalog());
    return [
      for (final r in hits)
        FeatureItem(
          title: r.title,
          subtitle: r.subtitle,
          icon: switch (r.kind) {
            '이슈' => AppIcons.warning,
            '작업 일지' => AppIcons.editNote,
            '자재' => AppIcons.list,
            _ => AppIcons.openFile,
          },
          onTap: () {
            if (r.projectId == null) {
              // 자재는 자재 현황에서 찾는다.
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MobileInventoryStatusPage(
                    workerName: widget.currentWorker,
                  ),
                ),
              );
              return;
            }
            Navigator.push(
              context,
              WorkRoute(
                builder: (_) => WorkLogMainScreen(
                  initialProjectId: r.projectId,
                  initialTab: r.tab,
                ),
              ),
            );
          },
        ),
    ];
  }

  void _openMenuSearch() {
    HapticFeedback.selectionClick();
    final logs = _readLogsForSearch();
    showFeatureSearchSheet(
      context,
      title: '메뉴 검색',
      moreResults: (q) => _recordResults(q, logs),
      items: [
        for (final e in _menuEntries)
          FeatureItem(
            title: e.title,
            subtitle: e.subtitle,
            glyph: e.icon,
            color: e.iconColor,
            onTap: e.onTap,
          ),
      ],
    );
  }

  // 🚀 [홈 화면 레이아웃 고도화] 예전엔 날씨/공지 카드와 알림 종·프로필
  // 아이콘이 한 Row 안에 같이 있어서, 아이콘들이 마치 날씨 카드에 딸린
  // 부속물처럼 어색하게 붙어 있었다(날씨가 화면에서 제일 위 - 가장
  // 눈에 띄는 자리를 차지하는 것도 어색했음). 아이콘은 화면 맨 위 독립된
  // 얇은 상단바로 분리하고, 날씨/공지/차량 카드는 그 아래 자기만의
  // 줄로 내렸다.
  Widget _buildTopBar(BuildContext context) {
    const weekdaysKo = ['월', '화', '수', '목', '금', '토', '일'];
    final now = DateTime.now();
    final dateStr =
        "${now.month}월 ${now.day}일 (${weekdaysKo[now.weekday - 1]})";
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 이름 줄(영문 필기체) — 빠른 실행·전체 메뉴 화면 머리에만 둔다
          // (2026-09-28 사용자 요청). 날짜·프로필과 붙어 있으면 답답해
          // 보인다고 해서 따로 한 줄로 떼고, 끝에 점 세개(더보기)를 뒀다.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Field Helper',
                style: TextStyle(
                  fontFamily: 'Pacifico',
                  fontSize: 26,
                  color: slate900, // 청록보다 검은색이 낫다는 의견(2026-09-28)
                  height: 1.1,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: const Key('home_menu_search'),
                    tooltip: "메뉴 검색",
                    icon: const Icon(AppIcons.search, color: slate600),
                    onPressed: _openMenuSearch,
                  ),
                  NewsHeaderBadgeIcon(
                    currentWorker: widget.currentWorker,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            NewsPage(currentWorker: widget.currentWorker),
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    key: const Key('home_header_menu'),
                    tooltip: "더보기",
                    icon: const Icon(Icons.more_vert, color: slate600),
                    onSelected: (v) {
                      if (v == 'profile') {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MobileProfilePage(
                              currentWorker: widget.currentWorker,
                            ),
                          ),
                        );
                      } else if (v == 'settings') {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MobileSettingsPage(
                              currentWorker: widget.currentWorker,
                            ),
                          ),
                        );
                      } else if (v == 'app_usage') {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AppUsagePage(),
                          ),
                        );
                      } else if (v == 'trash') {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TrashPage(),
                          ),
                        );
                      } else if (v == 'quick_edit') {
                        // 전체 메뉴를 보고 있었어도 빠른 실행으로 바꾸고
                        // 바로 편집 모드까지 켠다(2026-09-28).
                        HapticFeedback.selectionClick();
                        setState(() {
                          _quickMode = true;
                          _editMode = true;
                        });
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'profile', child: Text("내 프로필")),
                      PopupMenuItem(value: 'settings', child: Text("설정")),
                      PopupMenuItem(value: 'app_usage', child: Text("앱 사용법")),
                      PopupMenuItem(value: 'trash', child: Text("휴지통")),
                      PopupMenuItem(
                        value: 'quick_edit',
                        child: Text("빠른 실행 편집"),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            dateStr,
            style: const TextStyle(
              color: slate900,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  // 공지 듣기는 한 번만 만든다. 예전엔 build 안에서 만들어 날씨·일정 수가 바뀔 때마다
  // 끊고 다시 붙어 머리가 잠깐 빈칸이 됐다.
  Stream<QuerySnapshot>? _noticeStream;
  Stream<QuerySnapshot> get _notices => _noticeStream ??= FirebaseFirestore
      .instance
      .collection('announcements')
      // isActive+createdAt 복합 색인 없이도 동작하도록, 최신순 20건만 받아서
      // 활성 공지를 앱에서 고른다.
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots();

  // 🚀 [정리] 숨긴 차량 기능의 `vehicles` 실시간 듣기를 뺐다(화면은 09-23에 숨겼는데
  // 홈 머리가 계속 서버를 듣고, 내 이름 차량이 있으면 날씨 대신 숨긴 화면으로 보냈다).
  Widget _buildGuestBanner() {
    return Container(
      key: const Key('home_guest_banner'),
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.caution.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_add_alt_1_rounded, color: AppColors.caution),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              "이름을 넣으면 알림을 받고 일정·작업 일지에 이름이 남습니다.",
              style: TextStyle(
                color: slate900,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    MobileProfilePage(currentWorker: widget.currentWorker),
              ),
            ),
            child: const Text(
              "이름 넣기",
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      child: Builder(
        builder: (context) {
          return StreamBuilder<QuerySnapshot>(
            stream: _notices,
            builder: (context, noticeSnap) {
              // 🚀 [고침] 공지를 기다리는 동안(통신이 없으면 오래) 머리 칸이 통째로
              // 비어 있었다. 기다리는 동안은 날씨를 먼저 보인다.

              final activeNotices = noticeSnap.hasData
                  ? noticeSnap.data!.docs
                        .where(
                          (d) =>
                              (d.data() as Map<String, dynamic>)['isActive'] ==
                              true,
                        )
                        .toList()
                  : <QueryDocumentSnapshot>[];
              if (activeNotices.isNotEmpty) {
                var noticeData =
                    activeNotices.first.data() as Map<String, dynamic>;
                String noticeTitle = noticeData['title'] ?? "새로운 사내 공지가 있습니다.";

                // 🚀 [고침] 공지가 있으면 날씨·비 예보가 통째로 사라졌다. 공지 아래에 같이 둔다.
                Widget withWeather(Widget notice) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    notice,
                    const SizedBox(height: 12),
                    GestureDetector(
                      key: const Key('home_weather_under_notice'),
                      onTap: _openWeatherApp,
                      child: _buildWeatherWidget(),
                    ),
                  ],
                );

                if (noticeTitle.contains("회식") || noticeTitle.contains("회의")) {
                  return withWeather(
                    _buildHeaderContent(
                      title: noticeTitle.contains("회의")
                          ? "회의 일정 공지가\n등록되어 있습니다."
                          : "회식 일정 공지가\n등록되어 있습니다.",
                      titleIcon: LucideIcons.bellRing,
                      subText: "눌러서 전체 공지를 확인하십시오.",
                      isActionable: true,
                      onTap: () {
                        HapticFeedback.heavyImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MobileNotificationPage(
                              currentWorker: widget.currentWorker,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }

                return withWeather(
                  _buildHeaderContent(
                    title: "새로운 사내 공지가\n등록되었습니다.",
                    titleIcon: LucideIcons.clipboardList,
                    subText: noticeTitle,
                    isActionable: true,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MobileNotificationPage(
                            currentWorker: widget.currentWorker,
                          ),
                        ),
                      );
                    },
                  ),
                );
              }

              return _buildHeaderContent(
                customSubWidget: _buildWeatherWidget(),
                isActionable: true,
                onTap: _openWeatherApp,
              );
            },
          );
        },
      ),
    );
  }

  // 🚀 [날씨 고도화] 날씨 카드를 탭하면 기기에 설치된 날씨 앱을 직접
  // 열어본다. Android는 "날씨 앱"이라는 표준 앱이 정해져 있지 않아서
  // (기종/제조사마다 다르거나 아예 없기도 함), CATEGORY_APP_WEATHER로
  // 등록된 앱이 있는지 먼저 확인해서 있으면 그걸 열고, 없으면(이
  // 사용자의 갤럭시 폴드4는 실제로 확인해보니 따로 실행 가능한 날씨
  // 앱이 없었다) 웹 브라우저로 날씨 검색 결과를 대신 보여준다.
  Future<void> _openWeatherApp() async {
    HapticFeedback.lightImpact();
    // 위치를 아직 묻지 않았으면 이번 누름에 묻고 내 위치 날씨로 다시 불러온다.
    try {
      if (await Geolocator.checkPermission() == LocationPermission.denied) {
        final pos = await _determinePosition(ask: true);
        if (pos != null) {
          await _fetchDetailedWeather();
          return;
        }
      }
    } catch (_) {}
    // 🚀 삼성 날씨는 런처 아이콘용 MAIN/LAUNCHER 액티비티가 없어서(기기의
    // dumpsys로 확인) 일반적인 "앱 실행" 방식으론 안 열렸다. 대신 앱
    // 자체의 MainActivity를 직접 지정해서 연다.
    try {
      await const AndroidIntent(
        action: 'android.intent.action.MAIN',
        package: 'com.sec.android.daemonapp',
        componentName: 'com.sec.android.daemonapp.app.MainActivity',
      ).launch();
      return;
    } catch (_) {
      // 삼성 날씨가 없는 기기면 아래 일반 날씨 앱 → 웹 순으로 폴백.
    }
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.MAIN',
        category: 'android.intent.category.APP_WEATHER',
      );
      final canResolve = await intent.canResolveActivity() ?? false;
      if (canResolve) {
        await intent.launch();
        return;
      }
    } catch (_) {
      // 기기에 날씨 앱이 없거나 인텐트를 해석할 수 없으면 아래 웹
      // 폴백으로 넘어간다.
    }

    final query = Uri.encodeComponent("$_cityName 날씨");
    final webUri = Uri.parse(
      "https://search.naver.com/search.naver?query=$query",
    );
    if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  static String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Widget _buildWeatherWidget() {
    if (!_isWeatherLoaded) {
      return const Row(
        key: Key('home_weather_loading'),
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2, color: slate600),
          ),
          SizedBox(width: 8),
          Text("날씨 불러오는 중…", style: TextStyle(color: slate600, fontSize: 12)),
        ],
      );
    }
    // 통신이 없어 못 불러온 경우: 눌러서 다시 부를 수 있게 한다.
    if (_weatherFailed) {
      return InkWell(
        onTap: () {
          setState(() {
            _isWeatherLoaded = false;
            _weatherFailed = false;
          });
          _fetchDetailedWeather();
        },
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.refresh, size: 14, color: slate600),
            SizedBox(width: 4),
            // 좁은 폰(320)에서 16px 넘쳤다.
            Flexible(
              child: Text(
                "날씨를 불러오지 못했습니다. 누르면 다시 불러옵니다.",
                style: TextStyle(color: slate600, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }
    // 🚀 [삭제] 위에 있던 인사말 제목이 없어진 뒤로는 이 top 여백이
    // "동기화 중..." 상태(여백 없음)와 로드 완료 상태 사이에 불필요한
    // 위치 차이를 만들어서 없앴다.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // 동 이름이 길면("부산광역시 강서구") 344dp에서 넘쳤다.
            Flexible(
              child: Text(
                // 🚀 [고침] 위치를 모르면 말없이 부산 날씨였다. 그렇다고 적고,
                // 누르면 위치를 묻는다.
                "${_locationUnknown ? '$_cityName(위치 모름)' : _cityName} "
                "$_currentTemp°C  /  $_weatherDesc"
                "${_weatherIsStale ? ' (${_hhmm(_weatherAt!)} 기준)' : ''}",
                style: const TextStyle(color: slate600, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(width: 1, height: 10, color: Colors.grey.shade300),
            const SizedBox(width: 8),
            // 🚀 [수정] 고정 Text라 온도/날씨 문구가 조금만 길어져도 우측이
            // 화면 밖으로 넘쳐 "RIGHT OVERFLOWED" 경고가 떴음. Flexible +
            // ellipsis로 감싸서 공간이 부족하면 이 텍스트만 잘리게 한다.
            Flexible(
              child: Text(
                "미세먼지 : $_pmState",
                style: const TextStyle(color: slate600, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            // 🚀 [날씨 고도화] 이 카드를 탭하면 날씨 앱(또는 웹 날씨
            // 페이지)이 열린다는 걸 알려주는 작은 표시.
            Icon(AppIcons.forward, size: 14, color: slate600),
          ],
        ),
        if (_rainExpected) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.water_drop, size: 12, color: Colors.blueGrey.shade400),
              const SizedBox(width: 4),
              Text(
                "$_rainStart시에 비 예상 ($_rainEnd시까지 ${_totalRain.toStringAsFixed(1)}mm)",
                style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 12),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildHeaderContent({
    String? title,
    IconData? titleIcon,
    String? subText,
    Widget? customSubWidget,
    required bool isActionable,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.transparent,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (titleIcon != null) ...[
              Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: Icon(titleIcon, size: 24, color: slate900),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🚀 [삭제] 시간대별 "수고했다"류 인사말 문구는 없앴다 -
                  // 이 헤더를 날씨 전용으로 쓸 땐 title을 아예 넘기지
                  // 않아서(null), 날씨 정보(customSubWidget)만 남는다.
                  // 공지/회의 배너처럼 진짜 제목이 필요한 다른 곳은
                  // 그대로 title을 넘겨서 쓴다.
                  if (title != null) ...[
                    Text(
                      title,
                      style: const TextStyle(
                        color: slate900,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (customSubWidget != null)
                    customSubWidget
                  else if (subText != null)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            subText,
                            style: const TextStyle(
                              color: slate600,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isActionable) ...[
                          const SizedBox(width: 2),
                          const Icon(
                            AppIcons.forward,
                            size: 16,
                            color: slate600,
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 홈 메뉴 묶음 제목(위에 두꺼운 구분선).
  Widget _sectionHeader(String title) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 32),
      const Divider(height: 1, color: slate100, thickness: 8),
      const SizedBox(height: 24),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
        child: Text(
          title,
          key: Key('menu_section_$title'),
          style: const TextStyle(
            color: slate600,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );

  Widget _buildMenuButton({
    required BuildContext context,
    required String title,
    required String subtitle,
    required AppGlyph icon,
    required VoidCallback onTap,
    Color? iconColor,
    String? badgeText,
    Color? badgeColor,
  }) {
    // 빠른 실행 화면이 쓸 수 있게 이번 build에서 만든 버튼 정보를 쌓아 둔다.
    _menuEntries.add(
      _MenuEntry(
        title: title,
        subtitle: subtitle,
        icon: icon,
        iconColor: iconColor ?? slate900,
        onTap: onTap,
        badgeText: badgeText,
        badgeColor: badgeColor,
      ),
    );
    final isFav = _favorites.contains(title);
    return PressFeedback(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        onLongPress: () => _toggleFavorite(title),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: (iconColor ?? slate900).withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: AppIcon(
                      icon,
                      size: 28,
                      color: iconColor ?? slate900,
                    ),
                  ),
                  // 길게 눌러 즐겨찾기(빠른 실행)에 넣은 메뉴에는 작은 별 표시.
                  if (isFav)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: pureWhite,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.star,
                          size: 16,
                          color: Color(0xFFF5A623),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: iconColor ?? slate900,
                              letterSpacing: -0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (badgeText != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor ?? warningRed,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badgeText,
                              style: const TextStyle(
                                color: pureWhite,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: slate600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                AppIcons.forward,
                color: slate600.withValues(alpha: 0.5),
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
