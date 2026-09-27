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

// 🚀 [수정됨] 단일 설정 페이지 대신 통합 네비게이션 페이지 임포트
// (실제 파일 경로에 맞게 수정해 주세요)
import 'package:tubing_calculator/src/presentation/conduit/screens/main_navigation_page.dart';

// 🚀 1. 현장 작업 페이지들 임포트
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_remote_page.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_calculator_page.dart';
import 'package:tubing_calculator/src/presentation/fabrication/screens/qr_scanner_page.dart';
import 'package:tubing_calculator/src/presentation/fabrication/screens/viewer_only_screen.dart';
import 'package:tubing_calculator/src/presentation/reference/page/tube_reference_page.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/screens/mobile_cutting_project_list_page.dart';
import 'package:tubing_calculator/src/presentation/steel_cutting/screens/mobile_steel_project_list_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/layout_board_project_list_page.dart';

// 🚀 2. 자재 관리 페이지들 임포트
import 'package:tubing_calculator/src/presentation/inventory/pages/mobile_inventory_login.dart';
import 'package:tubing_calculator/src/presentation/inventory/pages/mobile_inventory_status_page.dart';
import 'package:tubing_calculator/src/presentation/inventory/pages/low_stock_count.dart';
import 'package:tubing_calculator/src/presentation/attendance/pages/attendance_page.dart';

// 🚀 3. 프로필 및 소통 페이지 임포트
import 'package:tubing_calculator/src/presentation/profile/pages/mobile_profile_page.dart';
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
import 'package:tubing_calculator/src/presentation/field_tools/level_page.dart';
import 'package:tubing_calculator/src/presentation/field_tools/eng_calculator_page.dart';
import 'package:tubing_calculator/src/presentation/field_tools/protractor_page.dart';
import 'package:tubing_calculator/src/presentation/unit_converter/unit_converter_page.dart';
import 'package:tubing_calculator/src/presentation/electrical/electric_calculator_page.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/pressure_test_page.dart';
import 'package:tubing_calculator/src/presentation/flow/flow_calc_page.dart';
import 'package:tubing_calculator/src/presentation/instrument/signal_calculator_page.dart';

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

  /// 안에 들어가면 탭·하위 메뉴가 여러 개 있는 화면인지(빠른 실행 상세 화면에서
  /// "부가 기능 보기"로 들어간다).
  final bool hasExtra;

  /// 전체 메뉴 카드에 뜨는 것과 같은 알림 글(예: "3곳 안 씀"). 없으면 null.
  final String? badgeText;
  final Color? badgeColor;

  const _MenuEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.hasExtra = false,
    this.badgeText,
    this.badgeColor,
  });
}

/// 즐겨찾기한 메뉴를 카드로 보여주는 빠른 실행 화면.
/// - 좌우로 밀면 카드를 한 장씩 넘겨 본다(카드 지갑에서 카드를 넘기듯).
/// - 위로 밀면 모든 카드가 지갑처럼 겹쳐서 한 화면에 다 보인다 — 아무 카드나
///   누르면 바로 그 기능으로 들어간다.
/// - 그 상태에서 아래로 밀면 다시 한 장 보기로 돌아온다.
class _QuickLaunchCards extends StatefulWidget {
  final List<_MenuEntry> entries;
  final void Function(String title) onLongPressFavorite;
  const _QuickLaunchCards({
    super.key,
    required this.entries,
    required this.onLongPressFavorite,
  });

  @override
  State<_QuickLaunchCards> createState() => _QuickLaunchCardsState();
}

class _QuickLaunchCardsState extends State<_QuickLaunchCards> {
  late final PageController _pageCtrl = PageController(viewportFraction: 0.88);
  int _frontIndex = 0;
  bool _fanOpen = false;

  /// 모서리 편집 단추로 켜고 끈다 — 켜져 있으면 카드마다 빼기(×) 단추가 뜬다.
  bool _editMode = false;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  /// 편집 모드에서 즐겨찾기를 빼면 목록이 짧아지는데, 그때 [_frontIndex]가
  /// 이제 없는 자리를 가리키고 있으면(예: 3장 중 3번째를 보다가 1장을 빼서
  /// 2장이 됨) 범위 밖 인덱스 접근으로 앱이 빨간 화면과 함께 죽었다
  /// (2026-09-27 실제로 겪은 버그 — RangeError). 목록이 바뀔 때마다 맨 앞
  /// 자리를 안전한 범위로 당겨 둔다.
  @override
  void didUpdateWidget(covariant _QuickLaunchCards oldWidget) {
    super.didUpdateWidget(oldWidget);
    final clamped = quickLaunchClampFrontIndex(
      _frontIndex,
      widget.entries.length,
    );
    if (clamped != _frontIndex) {
      _frontIndex = clamped;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageCtrl.hasClients) _pageCtrl.jumpToPage(_frontIndex);
      });
    }
  }

  /// 겹침(지갑) 보기에서 카드를 고르면, 그 기능으로 바로 들어가지 않고 일단
  /// 그 카드를 앞(한 장 보기)으로 가져오기만 한다 — 한 번 더 눌러야 실행된다.
  void _bringToFront(int i) {
    HapticFeedback.selectionClick();
    setState(() {
      _frontIndex = i;
      _fanOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 방어적으로 한 번 더 — didUpdateWidget이 못 잡는 경우에도 절대 범위를
    // 벗어난 자리를 읽지 않게 한다.
    _frontIndex = quickLaunchClampFrontIndex(
      _frontIndex,
      widget.entries.length,
    );
    final n = widget.entries.length;
    return LayoutBuilder(
      builder: (context, box) {
        // 실물 카드(운전면허증 등) 비율(가로:세로 ≈ 1.586:1)에 가깝게, 화면
        // 폭 가득 크게 — 다만 태블릿처럼 넓은 화면에서 지나치게 커지지 않게 최대값을 둔다.
        final cardWidth = (box.maxWidth - 48).clamp(220.0, 380.0);
        final cardHeight = cardWidth / 1.586;
        return GestureDetector(
          // 아래로 밀면 전체(지갑) 보기, 위로 밀면 맨 앞 카드로 돌아온다.
          onVerticalDragEnd: n < 2
              ? null
              : (d) {
                  final v = d.primaryVelocity ?? 0;
                  if (!_fanOpen && v > 200) {
                    HapticFeedback.selectionClick();
                    setState(() => _fanOpen = true);
                  } else if (_fanOpen && v < -200) {
                    HapticFeedback.selectionClick();
                    setState(() => _fanOpen = false);
                  }
                },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _fanOpen
                  ? _buildFan(cardWidth, cardHeight)
                  : _buildSingle(cardWidth, cardHeight, n),
              Positioned(right: 0, top: 0, child: _buildEditButton()),
            ],
          ),
        );
      },
    );
  }

  /// 모서리 편집 단추(연필 ⇄ 완료). 누르면 카드마다 빼기(×) 단추가 뜨고 끈다.
  Widget _buildEditButton() => GestureDetector(
    key: const Key('home_quick_edit'),
    onTap: () {
      HapticFeedback.selectionClick();
      setState(() => _editMode = !_editMode);
    },
    child: Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: slate100,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4),
        ],
      ),
      child: Icon(
        _editMode ? Icons.check : Icons.edit_outlined,
        size: 16,
        color: tossBlue,
      ),
    ),
  );

  void _openDetail(BuildContext context, int i) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _QuickLaunchDetailPage(entry: widget.entries[i]),
      ),
    );
  }

  Widget _buildSingle(double cardWidth, double cardHeight, int n) => Column(
    children: [
      const SizedBox(height: 8),
      Text(
        n > 1
            ? '${_frontIndex + 1} / $n · 좌우로 밀어 넘기기 · 아래로 밀면 전체 보기'
            : '눌러서 열기',
        style: TextStyle(
          fontSize: 11,
          color: slate600,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        height: cardHeight,
        child: PageView.builder(
          controller: _pageCtrl,
          itemCount: n,
          onPageChanged: (i) => setState(() => _frontIndex = i),
          itemBuilder: (context, i) => Center(
            child: _QuickLaunchCard(
              entry: widget.entries[i],
              width: cardWidth,
              height: cardHeight,
              editing: _editMode,
              // 카드를 누르면 바로 기능으로 들어가지 않고, 먼저 상세 화면(알림·
              // 마지막 작업 등)으로 간다 — 실행은 상세 화면에서 한다.
              onTap: _editMode ? null : () => _openDetail(context, i),
              onLongPress: () =>
                  widget.onLongPressFavorite(widget.entries[i].title),
              onRemove: () =>
                  widget.onLongPressFavorite(widget.entries[i].title),
            ),
          ),
        ),
      ),
      // 부가 기능(탭 안내) 표시는 기본 카드 화면에서는 없앴다 — 카드를 누르면
      // 가는 상세 화면에 "부가 기능 보기" 줄로만 남아 있다.
      if (n > 1) ...[
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < n; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _frontIndex
                      ? tossBlue
                      : slate600.withValues(alpha: 0.3),
                ),
              ),
          ],
        ),
      ],
      const SizedBox(height: 8),
    ],
  );

  Widget _buildFan(double cardWidth, double cardHeight) {
    final n = widget.entries.length;
    const headerH = 32.0;
    // 남는 세로 자리를 (n-1) 등분해 카드가 그만큼씩 밀려 내려오게(맨 앞 카드가
    // 맨 아래·맨 위에 옴). 자리가 모자라면 최소 22px까지만 줄인다.
    final available = cardHeight * 1.8;
    final peek = n > 1
        ? ((available - cardHeight) / (n - 1)).clamp(22.0, 64.0)
        : 0.0;
    final stackHeight = cardHeight + peek * (n - 1);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: headerH,
          child: Center(
            child: Text(
              '즐겨찾기 $n개 · 카드를 눌러 그 카드로 돌아가기 · 위로 밀면 닫기',
              style: TextStyle(
                fontSize: 11,
                color: slate600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        SizedBox(
          height: stackHeight,
          width: cardWidth,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < n; i++)
                Positioned(
                  top: i * peek,
                  child: _QuickLaunchCard(
                    entry: widget.entries[i],
                    width: cardWidth,
                    height: cardHeight,
                    editing: _editMode,
                    onTap: () => _bringToFront(i),
                    onLongPress: () =>
                        widget.onLongPressFavorite(widget.entries[i].title),
                    onRemove: () =>
                        widget.onLongPressFavorite(widget.entries[i].title),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 즐겨찾기 카드 한 장(실물 카드 느낌 — 그라데이션·그림자, 아이콘·이름·부가 기능 표시).
/// "부가 기능" 배지를 누르면 부제 자리가 살짝 아래로 슬라이드되며 부가 기능
/// 이름들(칩)로 바뀐다 — 새 자리를 안 만들고 부제 자리 하나만 그대로 쓴다.
class _QuickLaunchCard extends StatelessWidget {
  final _MenuEntry entry;
  final double width;
  final double height;
  final VoidCallback? onTap;
  final VoidCallback onLongPress;

  /// 편집 모드일 때 카드 모서리에 빼기(×) 단추를 보여준다.
  final bool editing;
  final VoidCallback onRemove;

  const _QuickLaunchCard({
    required this.entry,
    required this.width,
    required this.height,
    required this.onTap,
    required this.onLongPress,
    this.editing = false,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final base = entry.iconColor;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              key: Key('home_quick_${entry.title}'),
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              onLongPress: onLongPress,
              child: Container(
                width: width,
                height: height,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [base, Color.lerp(base, Colors.black, 0.35)!],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: AppIcon(entry.icon, size: 20, color: Colors.white),
                    ),
                    const Spacer(),
                    Text(
                      entry.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 편집 모드에서만 보이는 빼기(×) 단추 — 카드 오른쪽 위 모서리.
          if (editing)
            Positioned(
              right: -6,
              top: -6,
              child: GestureDetector(
                key: Key('home_quick_remove_${entry.title}'),
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 4),
                    ],
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 14,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 빠른 실행 카드를 누르면 오는 상세 화면. 카드는 위에 그대로 두고, 아래는
/// "알림"·"마지막 작업"으로 나눠 보여준다. 실제 기능으로는 여기서 카드나
/// 알림·마지막 작업 줄을 눌러야 들어간다(그때 마지막 사용 시각을 남긴다).
class _QuickLaunchDetailPage extends StatefulWidget {
  final _MenuEntry entry;
  const _QuickLaunchDetailPage({required this.entry});

  @override
  State<_QuickLaunchDetailPage> createState() => _QuickLaunchDetailPageState();
}

class _QuickLaunchDetailPageState extends State<_QuickLaunchDetailPage> {
  List<DateTime> _history = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_quickLaunchLastUsedKey(widget.entry.title));
      if (!mounted) return;
      setState(() {
        _history = quickLaunchDecodeHistory(raw);
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _enter() async {
    HapticFeedback.lightImpact();
    try {
      final p = await SharedPreferences.getInstance();
      final next = quickLaunchAppendHistory(_history, DateTime.now());
      await p.setString(
        _quickLaunchLastUsedKey(widget.entry.title),
        quickLaunchEncodeHistory(next),
      );
    } catch (_) {}
    widget.entry.onTap();
  }

  /// [onTap]이 없으면(null) 그냥 보여주기만 하는 줄이 된다(화살표도 안 보임) —
  /// "마지막 작업 시간"·"작업 히스토리"는 정보만 보여주고, 실제 기능은
  /// 카드를 눌러야만 들어간다(2026-09-27 사용자 지시).
  Widget _sectionRow({
    required IconData icon,
    required String text,
    required Color color,
    VoidCallback? onTap,
    Key? key,
  }) {
    final row = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontWeight: FontWeight.w700, color: color),
            ),
          ),
          if (onTap != null)
            Icon(
              AppIcons.forward,
              size: 18,
              color: slate600.withValues(alpha: 0.5),
            ),
        ],
      ),
    );
    if (onTap == null) return KeyedSubtree(key: key, child: row);
    return InkWell(
      key: key,
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: row,
    );
  }

  /// "마지막 작업 시간"(맨 앞 기록)보다 앞서 쌓인 사용 기록들 — 진짜로
  /// 여러 번 쓴 기록이 있어야 뜬다(단순 반복 표시가 아니라 실제 기록).
  Widget _historySection() {
    if (!_loaded) {
      return _sectionRow(
        key: const Key('quick_detail_history'),
        icon: Icons.history_toggle_off,
        text: '불러오는 중…',
        color: slate600,
      );
    }
    final previous = _history.length > 1 ? _history.sublist(1) : <DateTime>[];
    if (previous.isEmpty) {
      return _sectionRow(
        key: const Key('quick_detail_history'),
        icon: Icons.history_toggle_off,
        text: '아직 반복해서 쓴 기록이 없습니다',
        color: slate600,
      );
    }
    final now = DateTime.now();
    return Container(
      key: const Key('quick_detail_history'),
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          for (var i = 0; i < previous.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: i == previous.length - 1
                  ? null
                  : BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
              child: Row(
                children: [
                  Icon(Icons.circle, size: 6, color: slate600),
                  const SizedBox(width: 12),
                  Text(
                    quickLaunchRelativeTime(previous[i], now),
                    style: TextStyle(color: slate900, fontSize: 13),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    return Scaffold(
      key: const Key('quick_detail_page'),
      backgroundColor: slate100,
      appBar: AppBar(
        backgroundColor: pureWhite,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: slate900,
        title: Text(
          entry.title,
          style: const TextStyle(fontWeight: FontWeight.w800, color: slate900),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: _QuickLaunchCard(
                entry: entry,
                width: 320,
                height: 320 / 1.586,
                onTap: _enter,
                onLongPress: () {},
                onRemove: () {},
              ),
            ),
            const SizedBox(height: 28),
            Text(
              '마지막 작업 시간',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: slate600,
              ),
            ),
            const SizedBox(height: 8),
            _sectionRow(
              key: const Key('quick_detail_last_used'),
              icon: Icons.history,
              text: _loaded
                  ? quickLaunchRelativeTime(
                      _history.isEmpty ? null : _history.first,
                      DateTime.now(),
                    )
                  : '불러오는 중…',
              color: slate900,
            ),
            const SizedBox(height: 20),
            Text(
              '작업 히스토리',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: slate600,
              ),
            ),
            const SizedBox(height: 8),
            _historySection(),
            if (entry.hasExtra) ...[
              const SizedBox(height: 20),
              Text(
                '부가 기능',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: slate600,
                ),
              ),
              const SizedBox(height: 8),
              _sectionRow(
                key: const Key('quick_detail_extra'),
                icon: Icons.apps,
                text: '부가 기능 보기',
                color: slate900,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _SubFeatureInfoPage(entry: entry),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 상세 화면 "부가 기능 보기"를 누르면 오는 풀 화면. [kQuickLaunchTabInfo]에
/// 등록된, 그 화면 안의 진짜 탭 이름과 각 탭이 하는 일을 보여준다(코드를
/// 읽어 확인한 내용 — 억지로 지어내지 않는다). 맨 아래에 바로 그 기능으로
/// 들어가는 단추도 둔다.
class _SubFeatureInfoPage extends StatelessWidget {
  final _MenuEntry entry;
  const _SubFeatureInfoPage({required this.entry});

  Future<void> _enter(BuildContext context) async {
    HapticFeedback.lightImpact();
    try {
      final p = await SharedPreferences.getInstance();
      final key = _quickLaunchLastUsedKey(entry.title);
      final history = quickLaunchDecodeHistory(p.getString(key));
      await p.setString(
        key,
        quickLaunchEncodeHistory(
          quickLaunchAppendHistory(history, DateTime.now()),
        ),
      );
    } catch (_) {}
    entry.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final items = kQuickLaunchTabInfo[entry.title] ?? const <String, String>{};
    return Scaffold(
      key: const Key('quick_subfeature_page'),
      backgroundColor: slate100,
      appBar: AppBar(
        backgroundColor: pureWhite,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: slate900,
        title: Text(
          '${entry.title} · 부가 기능',
          style: const TextStyle(fontWeight: FontWeight.w800, color: slate900),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Center(
                    child: _QuickLaunchCard(
                      entry: entry,
                      width: 280,
                      height: 280 / 1.586,
                      onTap: () => _enter(context),
                      onLongPress: () {},
                      onRemove: () {},
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '이 화면 안에는 이런 탭이 있습니다.',
                    style: TextStyle(
                      fontSize: 13,
                      color: slate600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final tab in items.entries)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: pureWhite,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: entry.iconColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tab.key,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: slate900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  tab.value,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: slate600,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  key: const Key('quick_subfeature_enter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: entry.iconColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _enter(context),
                  child: Text(
                    '지금 ${entry.title} 열기',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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

/// 빠른 실행 상세 화면 "마지막 작업"에 쓸 상대 시각 글자 — 위젯 없이 시험 가능.
String quickLaunchRelativeTime(DateTime? at, DateTime now) {
  if (at == null) return '아직 사용한 기록이 없습니다';
  final d = now.difference(at);
  if (d.inMinutes < 1) return '방금 전';
  if (d.inMinutes < 60) return '${d.inMinutes}분 전';
  if (d.inHours < 24) return '${d.inHours}시간 전';
  if (d.inDays < 30) return '${d.inDays}일 전';
  if (d.inDays < 365) return '${(d.inDays / 30).floor()}개월 전';
  return '${(d.inDays / 365).floor()}년 전';
}

String _quickLaunchLastUsedKey(String title) => 'home_quick_last_used_$title';

/// 빠른 실행 상세 화면 "작업 히스토리"에 쓸 사용 시각 목록에 새 기록 하나를
/// 맨 앞에 붙인다 — 위젯 없이 시험 가능한 순수 함수(원래 목록은 안 바꾸고
/// 새 목록을 돌려준다). 오래된 것은 [max]개까지만 남긴다.
List<DateTime> quickLaunchAppendHistory(
  List<DateTime> history,
  DateTime now, {
  int max = 8,
}) {
  final next = [now, ...history];
  return next.length > max ? next.sublist(0, max) : next;
}

/// SharedPreferences에 저장해 둔 글을 사용 시각 목록으로 되돌린다. 2026-09-27
/// 이전 버전은 ISO8601 글 하나만 저장했어서, 그 예전 형식도 그대로 읽는다.
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

/// 즐겨찾기를 빼서 목록이 짧아졌을 때 맨 앞 카드 자리가 범위를 벗어나지
/// 않게 당긴다 — 위젯 없이 시험 가능한 순수 함수. **실제 버그**(2026-09-27):
/// 3장 중 3번째를 보던 중 1장을 빼서 2장이 됐는데 자리를 안 당겨서
/// `widget.entries[2]`가 RangeError로 앱이 빨간 화면과 함께 죽었다.
int quickLaunchClampFrontIndex(int frontIndex, int entryCount) {
  if (entryCount <= 0) return 0;
  return frontIndex.clamp(0, entryCount - 1);
}

/// 진짜로 안에 탭(TabBar)이 여러 개 있는 화면만 골라, 탭 이름 → 그 탭이
/// 하는 일 한 줄을 적어 둔 것 — 각 화면의 실제 코드를 읽어 확인했다
/// (2026-09-28). 부제를 "·"로 쪼개 억지로 부가 기능처럼 보이게 하던 예전
/// 방식은 하단 네비게이션(탭처럼 보이지만 진짜 탭이 아닌 화면)까지 부가
/// 기능으로 잘못 표시하고 있었다 — 이 맵에 없는 화면은 "부가 기능" 자체가
/// 안 뜬다(빠른 실행 카드·상세 화면 모두).
const Map<String, Map<String, String>> kQuickLaunchTabInfo = {
  '압력 시험': {
    '시험 압력': '배관·장비 사양에 맞는 목표 시험 압력을 계산합니다.',
    '시험 기록': '실제 압력 시험 중의 측정값을 그때그때 기록합니다.',
    '압력 강하': '시간이 지나며 압력이 얼마나 떨어졌는지(감압) 판정합니다.',
    '공압 안전거리': '공압 시험의 위험 에너지에 맞는 안전거리를 계산합니다.',
  },
  '유량 계산': {
    '유속·관 굵기': '유량으로 유속을 구하거나, 유량에 맞는 관 굵기를 정합니다.',
    '압력손실': '관을 흐르며 마찰로 잃는 압력(차압)을 계산합니다.',
    '차압 유량계': '오리피스 같은 차압식 유량계의 차압-유량 관계를 계산합니다.',
    '유량계 점검': '설치된 유량계가 실제로 잘 재고 있는지 점검값을 계산합니다.',
  },
  '전기 설계 계산': {
    '기초 계산': '전압·전류·저항 같은 전기 기초값을 계산합니다.',
    '부하 전류': '모터·히터 같은 부하 종류에 맞는 전류를 계산합니다.',
    '부하 합산': '여러 부하 전류를 더해 총부하를 구합니다.',
    '전선 굵기': '부하·거리에 맞는 전선 굵기를 정하거나 기존 회로를 점검합니다.',
    '전압강하': '전선 길이·굵기에 따른 전압강하를 계산합니다.',
    '단락 전류': '회로가 단락됐을 때 흐를 수 있는 전류를 계산합니다.',
    '전선관': '전선관(콘듀이트) 관련 계산을 합니다.',
    '부스바': '부스바 용량·규격을 계산합니다.',
    '역률 개선': '역률 개선용 콘덴서 용량을 계산합니다.',
    '발전기 용량': '비상 발전기 용량을 부하에 맞게 산정합니다.',
    '축전지 용량': '정전 대비 축전지(배터리) 용량을 산정합니다.',
  },
  '계기 교정': {
    '교정 점검': '입력값 대비 측정값·지시값을 넣어 오차·히스테리시스를 계산합니다.',
    '4-20mA': '전류 신호와 실제 물리량(압력·온도 등) 사이를 서로 바꿔 계산합니다.',
    '온도 센서': 'Pt100·Pt1000 저항이나 K·J·T형 등 열전대 기전력을 온도로 바꿉니다.',
    '교정 가스': '가스 검지기 교정에 쓰는 교정 가스 관련 값을 계산합니다.',
    '루프 전압': '4-20mA 루프의 전압강하·부담저항 등을 계산합니다.',
  },
  '각도기': {
    '벤딩 각도 재기': '화면을 흰색·파란색으로 나누는 기준선으로 실제 벤딩 각도를 잽니다.',
    '화면 각도기': '화면 자체를 각도기처럼 써서 임의의 각도를 잽니다.',
  },
  '현장 자료·장비 사용법': {
    '튜브': '튜브 규격·자료를 찾아봅니다.',
    '전선관': '전선관(콘듀이트) 규격·자료를 찾아봅니다.',
    '형강': '형강(H형강 등) 규격·자료를 찾아봅니다.',
    '장비 사용법': '현장 장비 사용법을 안내합니다.',
    '앱 사용법': '이 앱 자체의 사용법을 안내합니다.',
    '단위 환산': '단위 환산 자료를 보여줍니다.',
    '발전 설비': '발전 설비 관련 참고 자료를 보여줍니다.',
    '전기 기준(KEC)': '한국전기설비규정(KEC) 참고 자료를 보여줍니다.',
  },
};

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

  /// 전체 메뉴 대신 빠른 실행(즐겨찾기 카드)만 보이는 중인지. 시작 화면은
  /// 항상 빠른 실행이다(사용자 요청 2026-09-27) — 폰에 저장해 두지 않는다.
  bool _quickMode = true;

  /// 이번 build에서 만든 메뉴 버튼들(빠른 실행 화면이 여기서 골라 쓴다).
  final List<_MenuEntry> _menuEntries = [];

  static const String _kFavoritesKey = 'home_quick_launch_favorites_v1';

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
    // 격주·평일·반복 끝이 있는 일정 알림은 한 번씩만 잡혀 있어서 다음 회차를 다시 잡아야
    // 한다. 예전엔 "내 일정" 화면을 열 때만 잡아서, 며칠 안 열면 알림이 끊겼다.
    // 앱을 켤 때 한 번(기다리지 않음, 통신이 없으면 폰 캐시로).
    if (!_remindersRescheduledThisRun) {
      _remindersRescheduledThisRun = true;
      rescheduleDriftingMonthlyReminders();
    }
  }

  static bool _remindersRescheduledThisRun = false;

  @override
  void dispose() {
    _weatherTimer?.cancel();
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
  }

  Future<void> _loadLowStock() async {
    final n = await fetchLowStockCount();
    if (mounted) setState(() => _lowStock = n);
  }

  Future<void> _loadQuickLaunchSettings() async {
    try {
      final p = await SharedPreferences.getInstance();
      final favs = p.getStringList(_kFavoritesKey);
      if (!mounted) return;
      setState(() {
        if (favs != null) _favorites = favs.toSet();
      });
    } catch (_) {}
  }

  Future<void> _saveFavorites() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_kFavoritesKey, _favorites.toList());
    } catch (_) {}
  }

  /// 메뉴 카드를 길게 누르면 즐겨찾기(빠른 실행)에 넣거나 뺀다.
  void _toggleFavorite(String title) {
    HapticFeedback.mediumImpact();
    setState(() => _favorites = toggleQuickLaunchFavorite(_favorites, title));
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

  /// 즐겨찾기한 메뉴를 카드로 보여주는 빠른 실행 화면(카드 자체는 [_QuickLaunchCards]).
  Widget _buildQuickLaunch() {
    final favEntries = _menuEntries
        .where((e) => _favorites.contains(e.title))
        .toList();
    if (favEntries.isEmpty) {
      return Padding(
        key: const Key('home_quick_launch_empty'),
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
        child: Column(
          children: [
            Icon(Icons.star_border, size: 40, color: slate600),
            const SizedBox(height: 12),
            const Text(
              "즐겨찾기한 기능이 없습니다",
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
      );
    }
    return _QuickLaunchCards(
      key: const Key('home_quick_launch'),
      entries: favEntries,
      onLongPressFavorite: _toggleFavorite,
    );
  }

  Future<void> _loadTodayScheduleCount() async {
    final count = await fetchTodayScheduleCount(widget.currentWorker);
    if (mounted) setState(() => _todayScheduleCount = count);
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
                        subtitle: "개인 작업 일지 · 이슈 리스트 및 자재 기록",
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
                        title: "내 일정 관리",
                        subtitle: "프로젝트 일정 통합 + 개인 일정 · 반복 · 알림",
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
                          );
                        },
                      ),
                      _sectionHeader("배관·튜브"),
                      _buildMenuButton(
                        context: context,
                        title: "벤딩 마킹 계산기",
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
                        title: "튜브 컷팅 계산기",
                        subtitle: "피팅 삽입깊이 차감 · 절단 자재 기록",
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
                        title: "압력 시험",
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
                        subtitle: "유속·관 굵기 · 압력손실 · 차압 유량계 · 유량계 점검",
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
                        title: "전선관 벤딩 마킹 계산기",
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
                        title: "전기 설계 계산",
                        subtitle: "부하 합산·전선 굵기·전압강하·단락 전류·발전기·축전지",
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
                      _sectionHeader("가공·배치"),
                      _buildMenuButton(
                        context: context,
                        title: "형강 컷팅 (찬넬/앵글)",
                        subtitle: "라인 조립 없이 규격·길이만으로 재단 계획·지시서 출력",
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
                        subtitle: "오프라인 지시서 스캔 후 3D 뷰어 실행",
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
                        title: "자재 통합 관리",
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
                      _sectionHeader("참고 자료"),
                      _buildMenuButton(
                        context: context,
                        title: "현장 자료·장비 사용법",
                        subtitle: "튜브·전선관·형강 규격표, 벤더·톱 사용법, 앱 사용법",
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 앱 이름(영문 필기체) — 빠른 실행·전체 메뉴 화면 머리에만 둔다
              // (2026-09-28 사용자 요청, 로딩 화면과 달리 여기는 이름만 이렇게).
              const Text(
                'Field Helper',
                style: TextStyle(
                  fontFamily: 'Pacifico',
                  fontSize: 22,
                  color: makitaTeal,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
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
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      MobileProfilePage(currentWorker: widget.currentWorker),
                ),
              );
            },
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: slate100,
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.user, size: 24, color: slate900),
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
                      subText: "터치하여 전체 알림을 확인하십시오.",
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
    // hasExtra는 더 이상 여기서 손으로 표시하지 않고, 실제로 안에 탭이 여러
    // 개 있다고 코드로 확인한 화면(kQuickLaunchTabInfo)인지로 정한다
    // (2026-09-28, 손으로 단 표시가 실제와 어긋나 있었다).
    _menuEntries.add(
      _MenuEntry(
        title: title,
        subtitle: subtitle,
        icon: icon,
        iconColor: iconColor ?? slate900,
        onTap: onTap,
        hasExtra: kQuickLaunchTabInfo.containsKey(title),
        badgeText: badgeText,
        badgeColor: badgeColor,
      ),
    );
    final isFav = _favorites.contains(title);
    return InkWell(
      onTap: onTap,
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
                  child: AppIcon(icon, size: 28, color: iconColor ?? slate900),
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
    );
  }
}
