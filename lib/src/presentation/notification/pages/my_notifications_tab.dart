/// "새소식" 화면의 "내 알림" · "지난 알림" 탭 + 헤더 확성기 아이콘의 안읽음
/// 점.
///
/// "공지"(announcements, 관리자가 올려야 채워짐)와 달리, 여기는 앱이 이미
/// 알고 있는 사실(오늘 일정·작업 일지 미작성·오프라인 저장 대기)을 스스로
/// 알림처럼 쌓아 보여준다. 밀어서 지우면 "지난 알림"으로 넘어가고, 그
/// 사실이 그대로여도 오늘은 다시 안 뜬다(내일 다시 참이면 다시 뜬다).
/// (2026-09-28 사용자 요청 — 확성기가 "역할이 없다"고 해서 실제 역할을
/// 만들었다.)
library;

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/theme/app_icon_set.dart';
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:tubing_calculator/src/data/pending_write_log.dart';
import 'package:tubing_calculator/src/presentation/equipment/equipment_model.dart';
import 'package:tubing_calculator/src/presentation/equipment/equipment_pages.dart';
import 'package:tubing_calculator/src/presentation/equipment/equipment_store.dart';
import 'package:tubing_calculator/src/presentation/safety/safety_check_model.dart';
import 'package:tubing_calculator/src/presentation/safety/safety_check_page.dart';
import 'package:tubing_calculator/src/data/repositories/work_project_repository.dart';
import 'package:tubing_calculator/src/presentation/notification/pages/pending_writes_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/screens/work_log_main_screen.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/widgets/work_theme.dart'
    show WorkRoute;
import 'package:tubing_calculator/src/presentation/calculator/widgets/swipe_delete.dart';
import 'package:tubing_calculator/src/presentation/my_schedule/mobile_my_schedule_page.dart'
    show fetchTodayScheduleCount, MobileMyScheduleScreen;
import 'package:tubing_calculator/src/presentation/my_work_logs/models/reminder_tools.dart'
    show fetchMissingReportCount;

const Color _slate900 = AppColors.text;
const Color _slate600 = AppColors.textSub;
const Color _pureWhite = Color(0xFFFFFFFF);
const Color _warn = Color(0xFFF04452);

const String _kArchiveKey = 'my_notifications_archive_v1';
const int _kArchiveCap = 50;

class _ArchiveEntry {
  final String id;
  final String title;
  final String detail;
  final DateTime dismissedAt;
  const _ArchiveEntry({
    required this.id,
    required this.title,
    required this.detail,
    required this.dismissedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'detail': detail,
    'dismissedAt': dismissedAt.toIso8601String(),
  };

  static _ArchiveEntry? fromJson(Map<String, dynamic> j) {
    final at = DateTime.tryParse(j['dismissedAt']?.toString() ?? '');
    if (at == null) return null;
    return _ArchiveEntry(
      id: j['id']?.toString() ?? '',
      title: j['title']?.toString() ?? '',
      detail: j['detail']?.toString() ?? '',
      dismissedAt: at,
    );
  }
}

Future<List<_ArchiveEntry>> _loadArchive() async {
  final p = await SharedPreferences.getInstance();
  final raw = p.getString(_kArchiveKey);
  if (raw == null || raw.isEmpty) return const [];
  try {
    final list = jsonDecode(raw) as List;
    return [
      for (final e in list)
        if (_ArchiveEntry.fromJson(Map<String, dynamic>.from(e as Map)) != null)
          _ArchiveEntry.fromJson(Map<String, dynamic>.from(e))!,
    ];
  } catch (_) {
    return const [];
  }
}

Future<void> _appendArchive(_ArchiveEntry e) async {
  final p = await SharedPreferences.getInstance();
  final list = await _loadArchive();
  final updated = [...list, e];
  final capped = updated.length > _kArchiveCap
      ? updated.sublist(updated.length - _kArchiveCap)
      : updated;
  await p.setString(
    _kArchiveKey,
    jsonEncode([for (final x in capped) x.toJson()]),
  );
}

Future<void> _removeLastArchiveEntry(String id, DateTime dismissedAt) async {
  final p = await SharedPreferences.getInstance();
  final list = await _loadArchive();
  final updated = [...list];
  for (var i = updated.length - 1; i >= 0; i--) {
    if (updated[i].id == id && updated[i].dismissedAt == dismissedAt) {
      updated.removeAt(i);
      break;
    }
  }
  await p.setString(
    _kArchiveKey,
    jsonEncode([for (final x in updated) x.toJson()]),
  );
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool _isDismissedToday(List<_ArchiveEntry> archive, String id, DateTime now) =>
    archive.any((e) => e.id == id && _sameDay(e.dismissedAt, now));

class _AutoItem {
  final String id;
  final IconData icon;
  final Color color;
  final String title;
  final String detail;

  /// 눌렀을 때 열 화면(없으면 눌러지지 않는다).
  final Route<void> Function()? route;
  const _AutoItem({
    required this.id,
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
    this.route,
  });
}

/// 지금 참인 것들만 순수 계산으로 골라낸다(화면 이동 없음). 오프라인 저장
/// 대기 → 오늘 일정 → 작업 일지 미작성 순서.
Future<List<_AutoItem>> _buildCandidates(String currentWorker) async {
  final pending = WorkProjectRepository.pendingWrites.value;
  int todayCount = 0;
  int? missing;
  try {
    todayCount = await fetchTodayScheduleCount(currentWorker);
  } catch (_) {}
  try {
    missing = await fetchMissingReportCount();
  } catch (_) {}

  // 최근에 안전 점검을 써 온 사람이 오늘은 아직 안 했으면 알린다(안 쓰는 사람에게는 알리지 않는다).
  bool safetyMissing = false;
  try {
    final records = await loadSafetyRecords();
    final now = DateTime.now();
    safetyMissing =
        safetyUsedRecently(records, now) && safetyCheckToday(records, now) == null;
  } catch (_) {}

  // 교정·검사 기한이 지났거나 30일 안에 오는 장비.
  LedgerSummary? equipSummary;
  try {
    equipSummary = summarize(await EquipmentStore.load(), DateTime.now());
  } catch (_) {}

  final list = <_AutoItem>[];
  if (equipSummary != null && (equipSummary.overdue + equipSummary.soon) > 0) {
    final s = equipSummary;
    list.add(
      _AutoItem(
        id: 'equip_due',
        icon: Icons.build_circle_outlined,
        color: s.overdue > 0 ? AppColors.danger : AppColors.caution,
        title: s.overdue > 0
            ? '장비 교정 기한 지남 ${s.overdue}대'
            : '장비 교정 기한 임박 ${s.soon}대',
        detail: s.overdue > 0 && s.soon > 0
            ? '기한이 지난 장비 ${s.overdue}대, 30일 안에 오는 장비 ${s.soon}대가 있습니다. 눌러서 확인하십시오.'
            : (s.overdue > 0
                  ? '교정·검사 기한이 지난 장비가 있습니다. 눌러서 확인하십시오.'
                  : '30일 안에 교정·검사 기한이 오는 장비가 있습니다. 눌러서 확인하십시오.'),
        route: () => MaterialPageRoute<void>(
          builder: (_) => const EquipmentLedgerPage(initialView: LedgerView.due),
        ),
      ),
    );
  }
  if (safetyMissing) {
    list.add(
      _AutoItem(
        id: 'safety_today',
        icon: Icons.health_and_safety_outlined,
        color: AppColors.caution,
        title: '오늘 안전 점검 아직',
        detail: '작업 전 안전 점검을 아직 안 했습니다. 눌러서 바로 점검하십시오.',
        route: () => MaterialPageRoute<void>(builder: (_) => const SafetyCheckPage()),
      ),
    );
  }
  if (pending > 0) {
    list.add(
      _AutoItem(
        id: 'pending_writes',
        icon: Icons.cloud_upload_outlined,
        color: Colors.deepOrange,
        title: '오프라인 저장 대기 $pending건',
        detail: () {
          final names = PendingWriteLog.namesLabel(
            WorkProjectRepository.pendingLog.entries.value,
          );
          final head = names.isEmpty ? '' : '$names — ';
          return '$head통신이 없어 폰에만 저장된 작업이 있습니다. 연결되면 서버로 자동으로 올라갑니다.';
        }(),
        route: () =>
            MaterialPageRoute<void>(builder: (_) => const PendingWritesPage()),
      ),
    );
  }
  if (todayCount > 0) {
    list.add(
      _AutoItem(
        id: 'today_schedule',
        icon: Icons.event_outlined,
        color: AppColors.brand,
        title: '오늘 일정 $todayCount건',
        detail: '오늘 처리할 일정이 있습니다. 눌러서 "내 일정 관리"에서 확인하십시오.',
        route: () => MaterialPageRoute<void>(
          builder: (_) => MobileMyScheduleScreen(currentWorker: currentWorker),
        ),
      ),
    );
  }
  if (missing != null && missing > 0) {
    list.add(
      _AutoItem(
        id: 'missing_report',
        icon: Icons.edit_note_outlined,
        color: _warn,
        title: '작업 일지 미작성 $missing건',
        detail: '오늘 작업 일지를 아직 안 쓴 진행중 프로젝트가 있습니다. 눌러서 바로 쓰십시오.',
        route: () => WorkRoute<void>(
          builder: (_) => const WorkLogMainScreen(autoWriteReport: true),
        ),
      ),
    );
  }
  return list;
}

Future<List<_AutoItem>> _activeMyNotifications(String currentWorker) async {
  final candidates = await _buildCandidates(currentWorker);
  final archive = await _loadArchive();
  final now = DateTime.now();
  return candidates
      .where((c) => !_isDismissedToday(archive, c.id, now))
      .toList();
}

/// 헤더 확성기 아이콘 안읽음 점 계산에 쓴다 — "내 알림" 활성 건수만
/// 세고(공지 안읽음은 부르는 쪽에서 스트림으로 따로 본다), 못 읽으면 0.
Future<int> countActiveMyNotifications(String currentWorker) async {
  try {
    return (await _activeMyNotifications(currentWorker)).length;
  } catch (_) {
    return 0;
  }
}

/// 홈 머리의 확성기 아이콘 — 공지 안읽음이나 내 알림이 하나라도 있으면
/// 작은 점을 띄운다(2026-09-28 추가 — 예전엔 눌러보기 전엔 알 방법이 없었다).
class NewsHeaderBadgeIcon extends StatefulWidget {
  final String currentWorker;
  final Future<void> Function() onPressed;
  const NewsHeaderBadgeIcon({
    super.key,
    required this.currentWorker,
    required this.onPressed,
  });

  @override
  State<NewsHeaderBadgeIcon> createState() => _NewsHeaderBadgeIconState();
}

class _NewsHeaderBadgeIconState extends State<NewsHeaderBadgeIcon> {
  bool _hasActiveAuto = false;

  bool get _hasIdentity =>
      widget.currentWorker.isNotEmpty && widget.currentWorker != '로그인 필요';

  @override
  void initState() {
    super.initState();
    _loadAuto();
    WorkProjectRepository.pendingWrites.addListener(_loadAuto);
  }

  @override
  void dispose() {
    WorkProjectRepository.pendingWrites.removeListener(_loadAuto);
    super.dispose();
  }

  Future<void> _loadAuto() async {
    final n = await countActiveMyNotifications(widget.currentWorker);
    if (mounted) setState(() => _hasActiveAuto = n > 0);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _hasIdentity
          ? FirebaseFirestore.instance
                .collection('announcements')
                .orderBy('createdAt', descending: true)
                .limit(50)
                .snapshots()
          : null,
      builder: (context, snapshot) {
        var hasUnread = false;
        if (_hasIdentity && snapshot.hasData) {
          hasUnread = snapshot.data!.docs.any((d) {
            final data = d.data() as Map<String, dynamic>;
            final readBy = (data['readBy'] as List?) ?? [];
            return !readBy.contains(widget.currentWorker);
          });
        }
        final showDot = hasUnread || _hasActiveAuto;
        return IconButton(
          key: const Key('home_news_button'),
          tooltip: '새소식',
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.campaign_outlined, color: _slate600),
              if (showDot)
                Positioned(
                  top: -1,
                  right: -1,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: _warn,
                      shape: BoxShape.circle,
                      border: Border.all(color: _pureWhite, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          onPressed: () async {
            HapticFeedback.lightImpact();
            await widget.onPressed();
            _loadAuto();
          },
        );
      },
    );
  }
}

/// "내 알림" 탭 — 지금 참인 것만 나열, 밀어서 지우면 "지난 알림"으로.
class MyNotificationsTab extends StatefulWidget {
  final String currentWorker;
  const MyNotificationsTab({super.key, required this.currentWorker});

  @override
  State<MyNotificationsTab> createState() => _MyNotificationsTabState();
}

class _MyNotificationsTabState extends State<MyNotificationsTab> {
  List<_AutoItem>? _items;

  @override
  void initState() {
    super.initState();
    _load();
    WorkProjectRepository.pendingWrites.addListener(_load);
  }

  @override
  void dispose() {
    WorkProjectRepository.pendingWrites.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final items = await _activeMyNotifications(widget.currentWorker);
    if (mounted) setState(() => _items = items);
  }

  Future<void> _dismiss(_AutoItem item) async {
    final now = DateTime.now();
    await _appendArchive(
      _ArchiveEntry(
        id: item.id,
        title: item.title,
        detail: item.detail,
        dismissedAt: now,
      ),
    );
    setState(() => _items?.removeWhere((e) => e.id == item.id));
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text('"${item.title}" 알림을 지웠습니다.'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: '되돌리기',
          onPressed: () async {
            await _removeLastArchiveEntry(item.id, now);
            _load();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (items == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brand),
      );
    }
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 48,
              color: _slate600.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              '확인할 알림이 없습니다.',
              style: TextStyle(
                color: _slate600,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];
          return Dismissible(
            key: Key('my_notif_${item.id}'),
            direction: DismissDirection.endToStart,
            background: swipeDeleteBackground(radius: 0, bottomMargin: 0),
            onDismissed: (_) => _dismiss(item),
            child: InkWell(
              onTap: item.route == null
                  ? null
                  : () async {
                      HapticFeedback.lightImpact();
                      await Navigator.push(context, item.route!());
                      if (mounted) _load();
                    },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(item.icon, color: item.color, size: 22),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _slate900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.detail,
                            style: const TextStyle(
                              fontSize: 14,
                              color: _slate600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (item.route != null)
                      const Padding(
                        padding: EdgeInsets.only(left: 8, top: 10),
                        child: Icon(
                          AppIcons.forward,
                          color: AppColors.textFaint,
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
}

/// "지난 알림" 탭 — 지운 것들을 최신순으로 다시 본다(순수 기록, 되돌리기는
/// "내 알림" 탭의 스낵바에서만 가능).
class PastNotificationsTab extends StatefulWidget {
  const PastNotificationsTab({super.key});

  @override
  State<PastNotificationsTab> createState() => _PastNotificationsTabState();
}

class _PastNotificationsTabState extends State<PastNotificationsTab> {
  List<_ArchiveEntry>? _archive;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _loadArchive();
    if (mounted) setState(() => _archive = list.reversed.toList());
  }

  Future<void> _clearAll() async {
    HapticFeedback.mediumImpact();
    final p = await SharedPreferences.getInstance();
    await p.remove(_kArchiveKey);
    _load();
  }

  String _timeLabel(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    final hm =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    if (day == today) return '오늘 $hm';
    if (day == today.subtract(const Duration(days: 1))) return '어제 $hm';
    return '${t.month}/${t.day} $hm';
  }

  @override
  Widget build(BuildContext context) {
    final archive = _archive;
    if (archive == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brand),
      );
    }
    if (archive.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 48,
              color: _slate600.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              '지난 알림이 없습니다.',
              style: TextStyle(
                color: _slate600,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '지난 알림 ${archive.length}건',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: _slate600,
                ),
              ),
              TextButton(
                onPressed: _clearAll,
                child: const Text(
                  '전부 지우기',
                  style: TextStyle(
                    color: _slate600,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: archive.length,
            itemBuilder: (context, i) {
              final e = archive[i];
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 20,
                      color: _slate600,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _slate900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _timeLabel(e.dismissedAt),
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: _slate600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
