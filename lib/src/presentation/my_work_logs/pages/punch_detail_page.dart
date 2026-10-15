import 'package:tubing_calculator/src/core/utils/background_photos.dart';
import 'package:tubing_calculator/src/core/common_widgets/app_components.dart'
    show showAppSnack, AppSnackKind;
import '../widgets/ai_polish_button.dart';
import 'package:tubing_calculator/src/core/theme/app_icon_set.dart';
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import '../widgets/korean_text.dart';
import '../widgets/photo_detail_modal.dart';
import '../widgets/confirm_delete.dart';
import '../widgets/work_theme.dart' show WorkRoute;
import '../models/photo_store.dart';
import '../models/issue_view.dart';
import '../models/project_phase.dart'
    show issueWeeklyExcluded, setIssueWeeklyExcluded;
import '../../../core/utils/image_picker_helper.dart' show ImagePickerHelper;
import '../../my_schedule/schedule_logic.dart' show clampPickerInitial;
import 'floor_plan_pin_page.dart';
import 'punch_list_page.dart' show PunchListPage;
import '../models/project_merge.dart' show currentWorkerName, authorLabel;
import '../widgets/assignee_picker.dart';

const Color makitaTeal = AppColors.brand;
const Color tossText = AppColors.text;
const Color tossSubText = AppColors.textSub;
const Color tossInputBg = AppColors.background;
const Color pureWhite = Color(0xFFFFFFFF);
const Color warningRed = AppColors.danger;

/// 상세에서 "이슈 지우기"를 고르면 돌려주는 표시. 받은 쪽이 목록에서 뺀다.
const String kIssueDeletedKey = '__deleted';

// 이슈 상세(10-14 개편). 위 카드에 상태·긴급·기한·유형과 내용, 위치·담당·기한·등록을 모으고,
// 처리 전·후 사진을 나란히, 아래에 처리(메모·사진·처리 완료)를 둔다.
// - 위 연필: 내용·위치·유형·우선순위·사진·도면 위치를 등록 화면 그대로 고친다.
// - 점 3개: 이슈 지우기(확인 창).
// - 처리 기한: 날짜를 고르거나 검사일정에 연결하거나 없앤다(예전엔 등록 때만 정할 수 있었다).
// - "처리 완료로 저장"을 누르면 바로 저장하고 닫는다(예전엔 화면을 나가야 저장됐다).
class PunchDetailPage extends StatefulWidget {
  final Map<String, dynamic> punch;
  // 이 프로젝트의 "검사일정" 일정 — 이슈를 검사일정에 연결하면 그 날짜가 처리 기한이 되고,
  // 임박·초과 때 서버가 더 자주 알린다(functions/index.js의 checkPunchIssues).
  final List<Map<String, dynamic>> inspectionSchedules;
  // 이 이슈에 도면 위치 핀이 있으면 보여 줄 프로젝트 도면.
  final String? floorPlanImagePath;
  // 사진에 찍을 현장(프로젝트) 이름.
  final String? projectName;

  const PunchDetailPage({
    super.key,
    required this.punch,
    this.inspectionSchedules = const [],
    this.floorPlanImagePath,
    this.projectName,
  });

  @override
  State<PunchDetailPage> createState() => _PunchDetailPageState();
}

class _PunchDetailPageState extends State<PunchDetailPage> {
  late Map<String, dynamic> _punch;
  late TextEditingController _resolutionCtrl;
  // 처리 후 사진(처리 전/후 비교용)
  List<String> _afterImages = [];

  /// 고른 뒤 도장·보관을 뒤에서 하는 사진(작업 일지와 같다, 10-09).
  final BackgroundPhotos _photoJobs = BackgroundPhotos();
  bool _changed = false;
  late String _noteAtOpen;
  late List<String> _imagesAtOpen;

  /// 처리 완료를 누르지 않은 채 처리 메모·처리 후 사진을 넣었는지(나가면 사라진다).
  bool get _unsavedResolution =>
      _punch['is_completed'] != true &&
      (_resolutionCtrl.text.trim() != _noteAtOpen.trim() ||
          _afterImages.join('|') != _imagesAtOpen.join('|'));

  @override
  void initState() {
    super.initState();
    _punch = Map<String, dynamic>.from(widget.punch);
    _resolutionCtrl = TextEditingController(
      text: _punch['resolution_note'] ?? '',
    );
    _afterImages = issueAfterPhotos(_punch);
    _noteAtOpen = _resolutionCtrl.text;
    _imagesAtOpen = List<String>.from(_afterImages);
  }

  @override
  void dispose() {
    _resolutionCtrl.dispose();
    super.dispose();
  }

  /// 나가기 전: 처리 메모·사진을 넣고 처리 완료를 안 눌렀으면 한 번 묻는다(10-07: 묻지 않고 사라졌다).
  /// 고친 것이 있으면 돌려준다.
  Future<void> _leave() async {
    if (_unsavedResolution &&
        !await confirmDelete(
          context,
          title: "처리 내용을 버리시겠습니까?",
          message: "'처리 완료'를 누르지 않고 나가면 쓴 처리 메모와 사진이 사라집니다.",
          confirmLabel: "버리기",
        )) {
      return;
    }
    if (mounted) Navigator.pop(context, _changed ? _punch : null);
  }

  void _set(void Function() fn) => setState(() {
    fn();
    _changed = true;
  });

  String _formatDateTime(DateTime dt) {
    final ampm = dt.hour < 12 ? '오전' : '오후';
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    return "${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} $ampm $h:$m";
  }

  String _formatDay(DateTime d) =>
      "${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}";

  Map<String, dynamic>? get _linkedSchedule {
    final id = _punch['linkedScheduleId']?.toString();
    if (id == null) return null;
    for (final s in widget.inspectionSchedules) {
      if (s['id']?.toString() == id) return s;
    }
    return null;
  }

  // ── 고치기·지우기 ──

  Future<void> _edit() async {
    final edited = await Navigator.push<Map<String, dynamic>>(
      context,
      WorkRoute(
        builder: (_) => PunchListPage(
          initial: _punch,
          floorPlanImagePath: widget.floorPlanImagePath,
          projectName: widget.projectName,
        ),
      ),
    );
    if (edited == null || !mounted) return;
    // 처리 메모·처리 후 사진은 그대로 둔다(고치기 화면은 등록 때 칸만 다룬다).
    edited['resolution_note'] = _punch['resolution_note'];
    edited['resolution_images'] = _punch['resolution_images'];
    _set(() => _punch = edited);
    // 쓰다 만 처리 내용이 없으면 바로 돌려줘 저장한다(앱이 꺼져도 남게).
    if (!_unsavedResolution) {
      showAppSnack(context, "고친 내용을 저장했습니다.");
      Navigator.pop(context, _punch);
    } else {
      showAppSnack(context, "고쳤습니다. 이 화면을 나가면 저장됩니다.");
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDelete(
      context,
      title: "이 이슈를 지우시겠습니까?",
      message: "목록에서 빠지고 주간 보고·통계에서도 사라집니다.",
    );
    if (!ok || !mounted) return;
    Navigator.pop(context, {..._punch, kIssueDeletedKey: true});
  }

  // ── 처리 기한 ──

  Future<void> _editDue() async {
    final cur = issueDueOf(_punch, widget.inspectionSchedules);
    final pick = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: pureWhite,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text("처리 기한", style: AppText.title),
            ),
            ListTile(
              key: const Key('punch_due_pick_date'),
              leading: const Icon(Icons.event_rounded),
              title: const Text("날짜 고르기"),
              onTap: () => Navigator.pop(ctx, 'date'),
            ),
            for (final s in widget.inspectionSchedules)
              ListTile(
                leading: const Icon(Icons.event_available_rounded),
                title: Text("검사일정: ${s['title'] ?? s['type'] ?? '검사일정'}"),
                subtitle: issueDate(s['dateTime']) == null
                    ? null
                    : Text(_formatDay(issueDate(s['dateTime'])!)),
                onTap: () => Navigator.pop(ctx, 'link:${s['id']}'),
              ),
            if (cur != null)
              ListTile(
                key: const Key('punch_due_clear'),
                leading: const Icon(Icons.event_busy_rounded),
                title: const Text("기한 없애기"),
                onTap: () => Navigator.pop(ctx, 'clear'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (pick == null || !mounted) return;
    if (pick == 'clear') {
      _set(() {
        _punch['dueDate'] = null;
        _punch['linkedScheduleId'] = null;
      });
    } else if (pick.startsWith('link:')) {
      _set(() => _punch['linkedScheduleId'] = pick.substring(5));
    } else {
      final now = DateTime.now();
      final first = DateTime(now.year - 1);
      final last = DateTime(now.year + 2, 12, 31);
      final d = await showDatePicker(
        context: context,
        initialDate: clampPickerInitial(
          cur ?? now.add(const Duration(days: 3)),
          first,
          last,
        ),
        firstDate: first,
        lastDate: last,
      );
      if (d == null || !mounted) return;
      _set(() {
        _punch['dueDate'] = d;
        // 날짜를 직접 고르면 검사일정 연결은 푼다(둘이 다르면 헷갈린다).
        _punch['linkedScheduleId'] = null;
      });
    }
  }

  // ── 처리 ──

  Future<void> _addAfterPhotos() async {
    if (_afterImages.length >= 6) {
      showAppSnack(context, "사진은 6장까지 넣을 수 있습니다.", kind: AppSnackKind.error);
      return;
    }
    // 고르자마자 사진 칸에 먼저 보이고 도장 찍기·보관은 뒤에서 한다(10-09).
    final picked = await ImagePickerHelper.pickRawImages(
      context,
      maxCount: 6 - _afterImages.length,
      stampSite: true,
    );
    if (picked.isEmpty || !mounted) return;
    _photoJobs.addAll(
      _afterImages,
      picked,
      update: (fn) => mounted ? setState(fn) : fn(),
      siteLabel: widget.projectName,
    );
  }

  Future<void> _markResolved() async {
    // 뒤에서 정리 중인 처리 후 사진이 있으면 끝날 때까지 기다린다(임시 경로가 저장되지 않게).
    await _photoJobs.waitAll();
    if (!mounted) return;
    _punch['is_completed'] = true;
    _punch['resolution_images'] = List<String>.from(_afterImages);
    _punch['resolved_at'] = DateTime.now();
    _punch['resolution_note'] = _resolutionCtrl.text.trim().isEmpty
        ? "별도 메모 없음"
        : _resolutionCtrl.text.trim();
    showAppSnack(context, "처리 완료로 저장했습니다.");
    Navigator.pop(context, _punch);
  }

  void _reopen() {
    _set(() {
      _punch['is_completed'] = false;
      _punch['resolved_at'] = null;
    });
    showAppSnack(context, "미해결로 되돌렸습니다.");
  }

  void _toggleWeekly(bool include) {
    _set(() => setIssueWeeklyExcluded(_punch, !include));
    showAppSnack(
      context,
      include ? "주간 보고에 포함했습니다." : "주간 보고에서 뺐습니다.",
      kind: AppSnackKind.undo,
      onUndo: () {
        if (!mounted) return;
        // 바꾸기 전 상태(제외 여부 = include)로 되돌린다.
        _set(() => setIssueWeeklyExcluded(_punch, include));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 폰 뒤로 가기(제스처)로 나가도 고친 것을 돌려준다.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _leave();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: pureWhite,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(AppIcons.back, color: tossText, size: 20),
            onPressed: _leave,
          ),
          title: const Text(
            "이슈 상세",
            style: TextStyle(
              color: tossText,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              key: const Key('punch_edit'),
              tooltip: "이슈 고치기",
              icon: const Icon(Icons.edit_outlined, color: tossText),
              onPressed: _edit,
            ),
            PopupMenuButton<String>(
              key: const Key('punch_menu'),
              onSelected: (v) {
                if (v == 'delete') _delete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'delete',
                  child: Text("이슈 지우기", style: TextStyle(color: warningRed)),
                ),
              ],
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _heroCard(),
              const SizedBox(height: 12),
              _photosCard(),
              if (widget.floorPlanImagePath != null &&
                  _punch['locationPinDx'] != null) ...[
                const SizedBox(height: 12),
                _sectionCard(
                  title: "도면 위치",
                  children: [
                    FloorPlanThumbnail(
                      imagePath: widget.floorPlanImagePath!,
                      dx: (_punch['locationPinDx'] as num).toDouble(),
                      dy: (_punch['locationPinDy'] as num).toDouble(),
                      onImage: _punch['locationPinOnImage'] == true,
                      height: 160,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              _resolutionCard(),
              const SizedBox(height: 12),
              _buildWeeklyToggle(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroCard() {
    final state = issueStateOf(_punch, schedules: widget.inspectionSchedules);
    final done = state == IssueState.done;
    final urgent = _punch['priority'] == '긴급';
    final type = (_punch['defect_type'] ?? '').toString().trim();
    final dueText = issueDueLabel(
      _punch,
      schedules: widget.inspectionSchedules,
    );
    final due = issueDueOf(_punch, widget.inspectionSchedules);
    final link = _linkedSchedule;
    final occurredAt = issueDate(_punch['created_at']);
    final loc = issueLocation(_punch);
    final who = (_punch['assignee'] ?? '').toString().trim();
    final content = (_punch['content'] ?? '').toString().trim();
    final dueColor = switch (state) {
      IssueState.overdue => warningRed,
      IssueState.dueSoon => AppColors.caution,
      _ => tossText,
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(6),
        border: Border(
          left: BorderSide(
            width: 4,
            color: done
                ? AppColors.ok
                : (state == IssueState.overdue || urgent
                      ? warningRed
                      : (state == IssueState.dueSoon
                            ? AppColors.caution
                            : AppColors.line)),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _pill(
                done ? "처리 완료" : "미해결",
                done ? AppColors.ok : warningRed,
                icon: done ? Icons.check_circle_rounded : Icons.error_rounded,
              ),
              if (urgent && !done) _pill("긴급", warningRed),
              if (!done && dueText.isNotEmpty)
                _pill(
                  dueText,
                  state == IssueState.overdue
                      ? warningRed
                      : (state == IssueState.dueSoon
                            ? AppColors.caution
                            : AppColors.idle),
                ),
              if (type.isNotEmpty) _pill(type, AppColors.idle),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content.isEmpty ? "내용 없음 (사진 참조)" : content,
            style: const TextStyle(
              fontSize: 17,
              height: 1.45,
              fontWeight: FontWeight.w700,
              color: tossText,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.line),
          const SizedBox(height: 10),
          _infoRow("위치", loc.isEmpty ? "위치 모름" : loc),
          _infoRow(
            "담당자",
            who.isEmpty ? "없음" : who,
            action: "바꾸기",
            actionKey: 'punch_assignee_change',
            onAction: () async {
              final v = await pickAssignee(
                context,
                current: who,
                me: currentWorkerName.value,
              );
              if (v == null || !mounted) return;
              _set(() => _punch['assignee'] = v);
            },
          ),
          _infoRow(
            "처리 기한",
            due == null
                ? "없음"
                : (link != null
                      ? "${link['title'] ?? link['type'] ?? '검사일정'} · ${_formatDay(due)}"
                      : _formatDay(due)),
            valueColor: due == null || done ? tossText : dueColor,
            action: due == null ? "정하기" : "바꾸기",
            actionKey: 'punch_due_change',
            onAction: _editDue,
          ),
          _infoRow("우선순위", switch (_punch['priority']) {
            '긴급' => "긴급 (하루 여러 번 알림)",
            '여유' => "여유 (2~3일에 한 번 알림)",
            _ => "보통 (하루 한 번 알림)",
          }),
          _infoRow(
            "등록",
            [
              if (occurredAt != null) _formatDateTime(occurredAt),
              if (authorLabel(_punch).isNotEmpty) authorLabel(_punch),
            ].join("\n").ifEmpty("기록 없음"),
          ),
        ],
      ),
    );
  }

  Widget _photosCard() {
    final before = issueBeforePhotos(_punch);
    if (before.isEmpty && _afterImages.isEmpty) return const SizedBox.shrink();
    Widget strip(String label, List<String> paths) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label ${paths.length}",
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: tossSubText,
            ),
          ),
          const SizedBox(height: 6),
          if (paths.isEmpty)
            Container(
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tossInputBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                "없음",
                style: TextStyle(color: tossSubText, fontSize: 13),
              ),
            )
          else
            GestureDetector(
              onTap: () => PhotoDetailModal.show(
                context: context,
                title: label,
                content: _punch['content']?.toString() ?? '',
                imagePaths: paths,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  children: [
                    PhotoImage(
                      paths.first,
                      width: double.infinity,
                      height: 96,
                      fit: BoxFit.cover,
                    ),
                    if (paths.length > 1)
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "+${paths.length - 1}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
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
    );
    return _sectionCard(
      title: "사진",
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            strip("처리 전", before),
            const SizedBox(width: 10),
            strip("처리 후", _afterImages),
          ],
        ),
      ],
    );
  }

  Widget _resolutionCard() {
    final isCompleted = _punch['is_completed'] == true;
    final resolvedAt = issueDate(_punch['resolved_at']);
    if (isCompleted) {
      return _sectionCard(
        title: "처리 내용",
        children: [
          _infoRow(
            "처리 일시",
            resolvedAt != null ? _formatDateTime(resolvedAt) : "기록 없음",
          ),
          const SizedBox(height: 4),
          Text(
            _punch['resolution_note']?.toString() ?? '',
            style: const TextStyle(fontSize: 15, color: tossText, height: 1.5),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              key: const Key('punch_reopen'),
              onPressed: _reopen,
              style: OutlinedButton.styleFrom(
                foregroundColor: tossSubText,
                side: const BorderSide(color: AppColors.line),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text(
                "다시 미해결로 되돌리기",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      );
    }
    return _sectionCard(
      title: "처리하기",
      children: [
        TextField(
          key: const Key('punch_resolution_note'),
          controller: _resolutionCtrl,
          maxLines: 3,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(color: tossText),
          decoration: InputDecoration(
            hintText: "어떻게 처리했는지 적습니다. (예: 재시공하여 치수 재조정)",
            hintStyle: const TextStyle(color: AppColors.textFaint),
            filled: true,
            fillColor: tossInputBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: AiPolishButton(controller: _resolutionCtrl),
        ),
        SizedBox(
          height: 84,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              InkWell(
                key: const Key('punch_after_photo_add'),
                onTap: _addAfterPhotos,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 84,
                  height: 84,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: tossInputBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_a_photo_rounded, color: tossSubText),
                      const SizedBox(height: 4),
                      Text(
                        "처리 후 ${_afterImages.length}/6",
                        style: const TextStyle(
                          color: tossSubText,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              for (int i = 0; i < _afterImages.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: () => PhotoDetailModal.show(
                          context: context,
                          title: "처리 후 사진",
                          content: "",
                          imagePaths: _afterImages,
                          initialIndex: i,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: PhotoImage(
                            _afterImages[i],
                            width: 84,
                            height: 84,
                          ),
                        ),
                      ),
                      if (_photoJobs.busy(_afterImages[i]))
                        PhotoBusyOverlay(key: Key('after_photo_busy_$i')),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () async {
                            if (!await confirmDelete(
                              context,
                              title: "이 사진을 지우시겠습니까?",
                            )) {
                              return;
                            }
                            if (mounted) {
                              setState(() => _afterImages.removeAt(i));
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black87,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            key: const Key('punch_resolve'),
            onPressed: _markResolved,
            style: ElevatedButton.styleFrom(
              backgroundColor: makitaTeal,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              elevation: 0,
            ),
            child: const Text(
              "처리 완료로 저장",
              style: TextStyle(
                color: pureWhite,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 이 이슈를 주간 업무 보고에 넣을지(기본: 넣음).
  Widget _buildWeeklyToggle() {
    final include = !issueWeeklyExcluded(_punch);
    return _sectionCard(
      title: "주간 보고",
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            "주간 보고에 포함",
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          subtitle: Text(
            keepWords("끄면 주간 보고의 미해결 이슈 현황과 통계에서 빠집니다."),
            style: const TextStyle(fontSize: 12, color: tossSubText),
          ),
          value: include,
          onChanged: _toggleWeekly,
        ),
      ],
    );
  }

  Widget _pill(String text, Color color, {IconData? icon}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 4),
        ],
        Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: color,
          ),
        ),
      ],
    ),
  );

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: tossSubText,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(
    String label,
    String value, {
    Color valueColor = tossText,
    String? action,
    String? actionKey,
    VoidCallback? onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                label,
                style: const TextStyle(color: tossSubText, fontSize: 13),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
          if (action != null)
            TextButton(
              key: actionKey == null ? null : Key(actionKey),
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(action, style: const TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
