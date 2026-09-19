import '../widgets/work_theme.dart';
import '../widgets/korean_text.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart'; // 🚀 HapticFeedback을 위해 추가
import '../../../core/utils/image_picker_helper.dart';
import 'package:tubing_calculator/src/core/common_widgets/makita_time_picker.dart';

// 🚀 [추가] 방금 만든 배치도 페이지 임포트
import 'layout_board_page.dart';
import 'tablet_layout_board_page.dart';
import '../widgets/photo_detail_modal.dart';
import 'floor_plan_pin_page.dart';
import '../models/project_phase.dart';
import '../models/report_tools.dart';
import '../models/photo_store.dart';
import '../widgets/voice_input_button.dart';
import 'photo_annotate_page.dart';

part 'daily_report_page_draft.dart';
part 'daily_report_page_submit.dart';
part 'daily_report_page_photos.dart';

const Color tossBlue = Color(0xFF007580); // 마키타 틸로 통일(다른 화면과 동일)
const Color tossText = Color(0xFF191F28);
const Color tossSubText = Color(0xFF8B95A1);
const Color tossInputBg = Color(0xFFF2F4F6);
const Color pureWhite = Color(0xFFFFFFFF);
const Color makitaTeal = Color(0xFF007580);

class DailyReportPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  // 🚀 [추가] 새로 작성할 때 참고할 가장 최근 일지 - "어제 값 불러오기"와
  // "어제 적어둔 내일 계획" 안내에 쓴다.
  final Map<String, dynamic>? previousReport;
  // 🚀 [추가] "오늘 처리한 이슈" 태그 후보 - 미해결이거나 오늘 처리
  // 완료된 이슈들.
  final List<Map<String, dynamic>> relatedIssueCandidates;
  // 🚀 [추가] 작업 위치를 텍스트 대신 도면 위에 핀으로 찍기 위한 이미지
  // (이슈 등록과 동일한 프로젝트 도면을 공유).
  final String? floorPlanImagePath;
  // 🚀 [일보↔단계 연결] 오늘 작업한 단계를 고르고, 오늘 끝낸 세부 일정을 체크하면
  // 저장 시 프로젝트에 자동 반영된다.
  final List<Map<String, dynamic>> phases;
  final List<Map<String, dynamic>> pendingSchedules;
  final String? defaultPhaseId;
  // 새 일보 작성 중 임시 저장 키(전화가 오거나 앱이 꺼져도 내용을 이어 쓴다).
  final String? draftKey;
  // 프로젝트의 자재 요청/입고 항목들(사용한 자재를 골라 연결하는 용도).
  final List<Map<String, dynamic>> materialItems;

  const DailyReportPage({
    super.key,
    this.existingData,
    this.previousReport,
    this.relatedIssueCandidates = const [],
    this.floorPlanImagePath,
    this.phases = const [],
    this.pendingSchedules = const [],
    this.defaultPhaseId,
    this.draftKey,
    this.materialItems = const [],
  });

  @override
  State<DailyReportPage> createState() => _DailyReportPageState();
}

class _DailyReportPageState extends State<DailyReportPage> {
  late TextEditingController _pointCtrl;
  late TextEditingController _wiringPointCtrl;
  late TextEditingController _noteCtrl;
  late TextEditingController _asBuiltCtrl;
  late TextEditingController _nextDayPlanCtrl;
  late TextEditingController _materialsUsedCtrl;

  // 🚀 [변경] 하루에 여러 작업을 같이 하는 경우가 많아 복수 선택으로 변경.
  final Set<String> _selectedWorkTypes = {'신규 설치'};
  final List<String> _workTypes = [
    '신규 설치',
    '라인 수정',
    '결선/트레이싱',
    '철거/교체',
    '검사/테스트',
  ];
  int _workerCount = 1;
  bool _isOvertime = false;
  // 🚀 [추가] 연장/야간 작업을 했을 때, 몇 시부터 몇 시까지 했는지도
  // 입력할 수 있게 - 단순 여부(boolean)만으로는 나중에 얼마나 초과
  // 근무했는지 알 수 없었다.
  TimeOfDay? _overtimeStart;
  TimeOfDay? _overtimeEnd;

  bool _isAsBuilt = false;
  List<String> _attachedImages = [];
  late bool _isEdit;

  // 🚀 [추가] 오늘 처리한 이슈 태그
  final Set<String> _selectedIssueIds = {};

  // 사진 태그(작업 전/중/후 등): 경로 → 태그
  final Map<String, String> _imageTags = {};
  // 사진 메모(캡션): 경로 → 텍스트
  final Map<String, String> _imageCaptions = {};
  // 이 일보에서 사용했다고 고른 자재 요청/입고 항목 id
  final Set<String> _usedMaterialIds = {};
  final Set<String> _workedPhaseIds = {};
  final Set<String> _completedScheduleIds = {};
  final Set<String> _completedPhaseIds = {};

  // 자주 쓰는 작업 문구 - 누르면 상세 내역에 한 줄 추가된다.
  static const List<String> _quickPhrases = [
    '배관 취부',
    '용접',
    '튜빙 벤딩',
    '지지대 설치',
    '배선/결선',
    '압력 테스트',
    '누설 점검',
    '자재 정리',
  ];

  // 🚀 [추가] 도면 위 작업 위치 핀
  double? _pinDx;
  double? _pinDy;

  String _todayDateStr() {
    final today = DateTime.now();
    return "${today.month.toString().padLeft(2, '0')}/${today.day.toString().padLeft(2, '0')}";
  }

  // 🚀 [추가] 지난 날짜의 일지를 아무 때나 함부로 고칠 수 없도록, 오늘
  // 날짜가 아닌 일지를 수정할 때는 사유를 남기게 한다.
  bool get _isPastEdit =>
      _isEdit && widget.existingData!['date'] != _todayDateStr();

  @override
  void initState() {
    super.initState();
    _isEdit = widget.existingData != null;

    _pointCtrl = TextEditingController(
      text: _isEdit ? widget.existingData!['points'].toString() : "",
    );
    _wiringPointCtrl = TextEditingController(
      text: _isEdit
          ? (widget.existingData!['wiring_points']?.toString() ?? "")
          : "",
    );
    _noteCtrl = TextEditingController(
      text: _isEdit ? widget.existingData!['note'] : "",
    );
    _asBuiltCtrl = TextEditingController(
      text: _isEdit ? widget.existingData!['as_built_reason'] : "",
    );
    _nextDayPlanCtrl = TextEditingController(
      text: _isEdit ? (widget.existingData!['next_day_plan'] ?? '') : '',
    );
    _materialsUsedCtrl = TextEditingController(
      text: _isEdit ? (widget.existingData!['materials_used'] ?? '') : '',
    );

    if (!_isEdit && widget.defaultPhaseId != null) {
      _workedPhaseIds.add(widget.defaultPhaseId!);
    }
    if (_isEdit) {
      _workedPhaseIds.addAll(reportIds(widget.existingData!, 'workedPhaseIds'));
      ((widget.existingData!['image_tags'] as Map?) ?? {}).forEach(
        (k, v) => _imageTags[k.toString()] = v.toString(),
      );
      ((widget.existingData!['image_captions'] as Map?) ?? {}).forEach(
        (k, v) => _imageCaptions[k.toString()] = v.toString(),
      );
      _usedMaterialIds.addAll(
        reportIds(widget.existingData!, 'usedMaterialIds'),
      );
      _completedScheduleIds.addAll(
        reportIds(widget.existingData!, 'completedScheduleIds'),
      );
      _completedPhaseIds.addAll(
        reportIds(widget.existingData!, 'completedPhaseIds'),
      );
      _isAsBuilt = widget.existingData!['is_as_built'] ?? false;
      // 🚀 예전엔 work_type이 단일 문자열이었다 - 리스트/문자열 둘 다
      // 안전하게 처리해서 이전에 저장된 일지도 그대로 열린다.
      final dynamic wt = widget.existingData!['work_type'];
      _selectedWorkTypes.clear();
      if (wt is List) {
        _selectedWorkTypes.addAll(wt.map((e) => e.toString()));
      } else if (wt is String && wt.isNotEmpty) {
        _selectedWorkTypes.add(wt);
      }
      if (_selectedWorkTypes.isEmpty) _selectedWorkTypes.add('신규 설치');
      _workerCount = widget.existingData!['worker_count'] ?? 1;
      _isOvertime = widget.existingData!['is_overtime'] ?? false;
      _overtimeStart = _parseTimeOfDay(widget.existingData!['overtime_start']);
      _overtimeEnd = _parseTimeOfDay(widget.existingData!['overtime_end']);
      _selectedIssueIds.addAll(
        (widget.existingData!['linkedIssueIds'] as List? ?? []).map(
          (e) => e.toString(),
        ),
      );
      _pinDx = (widget.existingData!['locationPinDx'] as num?)?.toDouble();
      _pinDy = (widget.existingData!['locationPinDy'] as num?)?.toDouble();

      List<dynamic> existingPaths =
          widget.existingData!['image_paths'] ??
          (widget.existingData!['image_path'] != null
              ? [widget.existingData!['image_path']]
              : []);
      _attachedImages = List<String>.from(existingPaths);
    }

    _loadFavs();
    if (!_isEdit && widget.draftKey != null) {
      _draftTimer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => _saveDraft(),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => _offerDraft());
    }
  }

  // ───────────── 자재 즐겨찾기 ─────────────
  static const _kFavKey = 'fav_materials_v1';
  List<String> _favMaterials = [];

  // 즐겨찾기는 Firestore(my_project_settings/fav_materials)와 이 기기 양쪽에 둔다.
  DocumentReference<Map<String, dynamic>> get _favDoc => FirebaseFirestore
      .instance
      .collection('my_project_settings')
      .doc('fav_materials');

  Future<void> _loadFavs() async {
    try {
      final p = await SharedPreferences.getInstance();
      final local = p.getStringList(_kFavKey) ?? [];
      if (mounted) setState(() => _favMaterials = local);
      final snap = await _favDoc.get().timeout(const Duration(seconds: 6));
      final cloud = ((snap.data()?['items'] as List?) ?? [])
          .map((e) => e.toString())
          .toList();
      final merged = [...cloud, ...local.where((e) => !cloud.contains(e))];
      if (mounted) setState(() => _favMaterials = merged);
      await p.setStringList(_kFavKey, merged);
      if (merged.length != cloud.length) {
        await _favDoc.set({'items': merged});
      }
    } catch (_) {}
  }

  Future<void> _saveFavs() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_kFavKey, _favMaterials);
      await _favDoc.set({'items': _favMaterials});
    } catch (_) {}
  }

  void _addFavFromInput() {
    // 쉼표/줄바꿈으로 나눠 항목별로 즐겨찾기에 넣는다.
    final items = _materialsUsedCtrl.text
        .split(RegExp(r'[,\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);
    setState(() {
      for (final i in items) {
        if (!_favMaterials.contains(i)) _favMaterials.add(i);
      }
    });
    _saveFavs();
  }

  void _useFav(String item) {
    final t = _materialsUsedCtrl.text.trim();
    _materialsUsedCtrl.text = t.isEmpty ? item : '$t, $item';
    setState(() {});
  }

  // 어제 일보를 통째로(사진 제외) 복사: 값 + 작업 내용 + 사용 자재.
  void _copyPreviousAll() {
    final prev = widget.previousReport;
    if (prev == null) return;
    _loadPreviousValues();
    setState(() {
      final n = (prev['note']?.toString() ?? '').trim();
      if (_noteCtrl.text.trim().isEmpty && n.isNotEmpty && n != '특이사항 없음') {
        _noteCtrl.text = n;
      }
      final m = (prev['materials_used']?.toString() ?? '').trim();
      if (_materialsUsedCtrl.text.trim().isEmpty && m.isNotEmpty) {
        _materialsUsedCtrl.text = m;
      }
    });
  }

  // ───────────── 임시 저장 ─────────────
  Timer? _draftTimer;
  String _lastDraft = '';
  bool _submitted = false;

  @override
  void dispose() {
    _draftTimer?.cancel();
    _saveDraft(); // 컨트롤러가 정리되기 전에 마지막 내용을 한 번 더 저장
    _pointCtrl.dispose();
    _wiringPointCtrl.dispose();
    _noteCtrl.dispose();
    _asBuiltCtrl.dispose();
    _nextDayPlanCtrl.dispose();
    _materialsUsedCtrl.dispose();
    super.dispose();
  }

  // 🚀 [추가] 어제(가장 최근) 일지의 작업유형/인원/연장여부를 그대로
  // 불러온다 - 반복되는 작업일 때 타이핑을 줄여준다.
  void _loadPreviousValues() {
    final prev = widget.previousReport;
    if (prev == null) return;
    setState(() {
      final dynamic wt = prev['work_type'];
      _selectedWorkTypes.clear();
      if (wt is List) {
        _selectedWorkTypes.addAll(wt.map((e) => e.toString()));
      } else if (wt is String && wt.isNotEmpty) {
        _selectedWorkTypes.add(wt);
      }
      if (_selectedWorkTypes.isEmpty) _selectedWorkTypes.add('신규 설치');
      _workerCount = prev['worker_count'] ?? _workerCount;
      _isOvertime = prev['is_overtime'] ?? _isOvertime;
      final prevPhases = reportIds(prev, 'workedPhaseIds');
      if (prevPhases.isNotEmpty) {
        _workedPhaseIds
          ..clear()
          ..addAll(prevPhases);
      }
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(keepWords("어제 일보의 기본 정보를 가져왔습니다."))));
  }

  Future<void> _pickTag(String path) async {
    final picked = await showModalBottomSheet<String>(
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
                "사진 분류",
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in kPhotoTags)
                    ActionChip(
                      label: Text(t),
                      onPressed: () => Navigator.pop(ctx, t),
                    ),
                  ActionChip(
                    label: const Text("분류 해제"),
                    onPressed: () => Navigator.pop(ctx, ''),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      if (picked.isEmpty) {
        _imageTags.remove(path);
      } else {
        _imageTags[path] = picked;
      }
    });
  }

  void _addPhrase(String p) {
    final t = _noteCtrl.text.trimRight();
    _noteCtrl.text = t.isEmpty ? p : '$t\n$p';
    _noteCtrl.selection = TextSelection.collapsed(
      offset: _noteCtrl.text.length,
    );
    setState(() {});
  }

  // 어제 적어둔 "내일 계획"을 오늘 작업 내역의 시작점으로 넣는다.
  void _usePlanAsNote() {
    final plan = (widget.previousReport?['next_day_plan'] as String?)?.trim();
    if (plan == null || plan.isEmpty) return;
    final t = _noteCtrl.text.trimRight();
    _noteCtrl.text = t.isEmpty ? plan : '$t\n$plan';
    setState(() {});
  }

  TimeOfDay? _parseTimeOfDay(dynamic v) {
    if (v is! String || !v.contains(':')) return null;
    final parts = v.split(':');
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _formatTimeOfDay(TimeOfDay t) =>
      "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";

  // 🚀 자정을 넘기는 야간 근무(예: 18:00~02:00)도 고려해서 시간 차를
  // 계산한다.
  double? get _overtimeHours {
    if (_overtimeStart == null || _overtimeEnd == null) return null;
    int startMin = _overtimeStart!.hour * 60 + _overtimeStart!.minute;
    int endMin = _overtimeEnd!.hour * 60 + _overtimeEnd!.minute;
    if (endMin <= startMin) endMin += 24 * 60; // 자정 넘김
    return (endMin - startMin) / 60.0;
  }

  Future<void> _pickOvertimeTime({required bool isStart}) async {
    final picked = await showMakitaTimePicker(
      context: context,
      title: isStart ? "시작 시간" : "종료 시간",
      initialTime:
          (isStart ? _overtimeStart : _overtimeEnd) ??
          const TimeOfDay(hour: 18, minute: 0),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _overtimeStart = picked;
      } else {
        _overtimeEnd = picked;
      }
    });
  }

  Future<void> _openPinPicker() async {
    if (widget.floorPlanImagePath == null) return;
    final result = await Navigator.push<Offset>(
      context,
      WorkRoute(
        builder: (context) => FloorPlanPinPage(
          imagePath: widget.floorPlanImagePath!,
          initialDx: _pinDx,
          initialDy: _pinDy,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _pinDx = result.dx;
        _pinDy = result.dy;
      });
    }
  }

  void _handleAddImage() async {
    if (_attachedImages.length >= 10) return;
    FocusScope.of(context).unfocus();
    final paths = await ImagePickerHelper.pickImages(
      context,
      maxCount: 10 - _attachedImages.length,
    );
    if (paths.isNotEmpty) setState(() => _attachedImages.addAll(paths));
  }

  Widget _buildIssueChip(Map<String, dynamic> issue) {
    final String id = issue['id']?.toString() ?? '';
    final bool selected = _selectedIssueIds.contains(id);
    return GestureDetector(
      onTap: () => setState(() {
        if (selected) {
          _selectedIssueIds.remove(id);
        } else {
          _selectedIssueIds.add(id);
        }
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? makitaTeal : tossInputBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          // 위치가 있으면 함께 보여줘서 같은 내용의 이슈도 구분되게 한다.
          "${(issue['location']?.toString() ?? '').isEmpty || issue['location'] == '위치 모름' ? '' : '${issue['location']} · '}${issue['content'] ?? '이슈'}",
          style: TextStyle(
            color: selected ? pureWhite : tossSubText,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // ───────────────────────── 새 UI 조각들 ─────────────────────────
  Widget _card({
    required String title,
    IconData? icon,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: makitaTeal),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: tossText,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  InputDecoration _dec({String? hint, String? label}) => InputDecoration(
    hintText: hint,
    labelText: label,
    labelStyle: const TextStyle(color: tossSubText, fontSize: 13),
    hintStyle: const TextStyle(color: Color(0xFFB0B8C1), fontSize: 14),
    filled: true,
    fillColor: tossInputBg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );

  Widget _selChip(String label, bool sel, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: sel ? makitaTeal : tossInputBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: sel ? pureWhite : tossSubText,
              fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      );

  // 접이식 항목: 접혀 있어도 채워진 값은 요약으로 보인다.
  Widget _more({
    required String title,
    required IconData icon,
    required String summary,
    required bool filled,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: filled && _isEdit,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          leading: Icon(
            icon,
            color: filled ? makitaTeal : tossSubText,
            size: 20,
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: tossText,
            ),
          ),
          subtitle: summary.isEmpty
              ? null
              : Text(
                  summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: makitaTeal),
                ),
          children: children,
        ),
      ),
    );
  }

  Widget _timeBox(String label, TimeOfDay? t, bool isStart) => Expanded(
    child: InkWell(
      onTap: () => _pickOvertimeTime(isStart: isStart),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: tossInputBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              t != null ? _formatTimeOfDay(t) : label,
              style: TextStyle(
                color: t != null ? tossText : tossSubText,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const Icon(Icons.access_time_rounded, size: 16, color: tossSubText),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final String prevPlan =
        (widget.previousReport?['next_day_plan'] as String?)?.trim() ?? '';
    final String dateLabel = _isEdit
        ? "${widget.existingData!['date']}"
        : _todayDateStr();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F6),
      appBar: AppBar(
        backgroundColor: pureWhite,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: tossText,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              _isEdit ? "작업 일보 수정" : "작업 일보",
              style: const TextStyle(
                color: tossText,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              dateLabel,
              style: const TextStyle(color: tossSubText, fontSize: 12),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
          children: [
            if (_isPastEdit)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.history_edu_rounded,
                      color: Colors.orange.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        keepWords(
                          "${widget.existingData!['date']}의 지난 일지입니다. 저장하려면 수정 사유를 입력해야 합니다.",
                        ),
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── 빠른 시작 (새 일보 + 어제 일보가 있을 때) ──
            if (!_isEdit && widget.previousReport != null)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: makitaTeal.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.bolt_rounded,
                          color: makitaTeal,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            "어제 일보",
                            style: TextStyle(
                              color: makitaTeal,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _loadPreviousValues,
                          style: TextButton.styleFrom(
                            foregroundColor: makitaTeal,
                            minimumSize: const Size(0, 32),
                          ),
                          child: const Text(
                            "기본 정보만",
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        TextButton(
                          onPressed: _copyPreviousAll,
                          style: TextButton.styleFrom(
                            foregroundColor: makitaTeal,
                            minimumSize: const Size(0, 32),
                          ),
                          child: const Text(
                            "내용까지",
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    if (prevPlan.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        "어제 적은 계획: $prevPlan",
                        style: const TextStyle(
                          color: makitaTeal,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _usePlanAsNote,
                          style: TextButton.styleFrom(
                            foregroundColor: makitaTeal,
                            minimumSize: const Size(0, 30),
                          ),
                          child: const Text(
                            "오늘 작업 내용에 넣기",
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // ── 오늘 작업 (핵심) ──
            _card(
              title: "오늘 작업",
              icon: Icons.construction_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.phases.isNotEmpty) ...[
                    const Text(
                      "작업한 단계",
                      style: TextStyle(
                        color: tossSubText,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.phases.map((p) {
                        final id = p['id'].toString();
                        final sel = _workedPhaseIds.contains(id);
                        return _selChip(p['name'].toString(), sel, () {
                          setState(() {
                            sel
                                ? _workedPhaseIds.remove(id)
                                : _workedPhaseIds.add(id);
                          });
                        });
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text(
                    "작업 유형 (여러 개 선택)",
                    style: TextStyle(
                      color: tossSubText,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _workTypes.map((type) {
                      final sel = _selectedWorkTypes.contains(type);
                      return _selChip(type, sel, () {
                        setState(() {
                          if (sel) {
                            if (_selectedWorkTypes.length > 1) {
                              _selectedWorkTypes.remove(type);
                            }
                          } else {
                            _selectedWorkTypes.add(type);
                          }
                        });
                      });
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text(
                        "투입 인원",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: tossText,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() {
                          if (_workerCount > 1) _workerCount--;
                        }),
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: tossSubText,
                        ),
                      ),
                      Text(
                        "$_workerCount명",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: tossText,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => _workerCount++),
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: makitaTeal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _pointCtrl,
                          keyboardType: TextInputType.number,
                          decoration: _dec(label: "벤딩 완료 (pt)"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _wiringPointCtrl,
                          keyboardType: TextInputType.number,
                          decoration: _dec(label: "결선 완료 (개소)"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _noteCtrl,
                    maxLines: 4,
                    style: const TextStyle(
                      fontSize: 15,
                      color: tossText,
                      height: 1.5,
                    ),
                    decoration: _dec(
                      hint: "오늘 작업 내용·특이사항\n(예: 센서 3개소 결선 완료, 튜브 라인 연결)",
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: VoiceInputButton(
                      controller: _noteCtrl,
                      onChanged: () => setState(() {}),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _quickPhrases
                        .map(
                          (p) => ActionChip(
                            label: Text(
                              p,
                              style: const TextStyle(fontSize: 12),
                            ),
                            backgroundColor: tossInputBg,
                            side: BorderSide.none,
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _addPhrase(p),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),

            // ── 사진 ──
            _card(
              title: "현장 사진",
              icon: Icons.photo_camera_rounded,
              trailing: Text(
                "${_attachedImages.length}/10",
                style: const TextStyle(
                  color: tossSubText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _photoAction(
                      Icons.add_a_photo_rounded,
                      "사진 추가",
                      _handleAddImage,
                    ),
                    _photoAction(
                      Icons.architecture_rounded,
                      "배치도 스케치",
                      _openSketch,
                    ),
                    for (int i = 0; i < _attachedImages.length; i++)
                      _photoThumb(i, _attachedImages[i]),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 0, 8),
              child: Text(
                "더 기록하기 (선택)",
                style: TextStyle(
                  color: tossSubText,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),

            // ── 접이식 항목들 ──
            _more(
              title: "연장 / 야간 작업",
              icon: Icons.nights_stay_outlined,
              summary: _isOvertime
                  ? (_overtimeHours != null
                        ? "${_overtimeHours!.toStringAsFixed(1)}시간"
                        : "연장 작업함")
                  : "",
              filled: _isOvertime,
              children: [
                Row(
                  children: [
                    const Text(
                      "연장/야간 작업 수행",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: tossText,
                      ),
                    ),
                    const Spacer(),
                    CupertinoSwitch(
                      value: _isOvertime,
                      activeTrackColor: makitaTeal,
                      onChanged: (v) => setState(() => _isOvertime = v),
                    ),
                  ],
                ),
                if (_isOvertime) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _timeBox("시작 시간", _overtimeStart, true),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text("~", style: TextStyle(color: tossSubText)),
                      ),
                      _timeBox("종료 시간", _overtimeEnd, false),
                    ],
                  ),
                  if (_overtimeHours != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        keepWords(
                          "연장/야간 근무 시간: ${_overtimeHours!.toStringAsFixed(1)}시간",
                        ),
                        style: const TextStyle(
                          color: makitaTeal,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ],
            ),
            _more(
              title: "사용한 자재",
              icon: Icons.inventory_2_outlined,
              summary: [
                if (_usedMaterialIds.isNotEmpty)
                  "자재 요청 ${_usedMaterialIds.length}건",
                if (_materialsUsedCtrl.text.trim().isNotEmpty)
                  _materialsUsedCtrl.text.trim(),
              ].join(' · '),
              filled:
                  _materialsUsedCtrl.text.trim().isNotEmpty ||
                  _usedMaterialIds.isNotEmpty,
              children: [
                if (widget.materialItems.isNotEmpty) ...[
                  const Text(
                    "발주한 자재 중 오늘 사용한 것",
                    style: TextStyle(color: tossSubText, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final m in widget.materialItems)
                        FilterChip(
                          label: Text(
                            (m['title'] ?? m['type'] ?? '').toString(),
                            style: const TextStyle(fontSize: 12),
                          ),
                          selected: _usedMaterialIds.contains(
                            m['id']?.toString(),
                          ),
                          showCheckmark: false,
                          selectedColor: makitaTeal.withValues(alpha: 0.2),
                          backgroundColor: tossInputBg,
                          side: BorderSide.none,
                          visualDensity: VisualDensity.compact,
                          onSelected: (v) => setState(() {
                            final id = m['id']?.toString() ?? '';
                            v
                                ? _usedMaterialIds.add(id)
                                : _usedMaterialIds.remove(id);
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                Align(
                  alignment: Alignment.centerRight,
                  child: VoiceInputButton(
                    controller: _materialsUsedCtrl,
                    onChanged: () => setState(() {}),
                  ),
                ),
                TextField(
                  controller: _materialsUsedCtrl,
                  maxLines: 2,
                  onChanged: (_) => setState(() {}),
                  decoration: _dec(hint: "예: 1/2\" 튜빙 10m, 유니온 피팅 5개"),
                ),
                if (_favMaterials.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    keepWords("자주 쓰는 자재 (눌러서 추가, 길게 눌러 삭제)"),
                    style: TextStyle(color: tossSubText, fontSize: 11),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final f in _favMaterials)
                        GestureDetector(
                          onLongPress: () {
                            setState(() => _favMaterials.remove(f));
                            _saveFavs();
                          },
                          child: ActionChip(
                            avatar: const Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: Color(0xFFF5B301),
                            ),
                            label: Text(
                              f,
                              style: const TextStyle(fontSize: 12),
                            ),
                            backgroundColor: tossInputBg,
                            side: BorderSide.none,
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _useFav(f),
                          ),
                        ),
                    ],
                  ),
                ],
                if (_materialsUsedCtrl.text.trim().isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _addFavFromInput,
                      icon: const Icon(Icons.star_border_rounded, size: 16),
                      label: const Text("입력한 자재를 즐겨찾기에 추가"),
                      style: TextButton.styleFrom(
                        foregroundColor: makitaTeal,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 32),
                      ),
                    ),
                  ),
              ],
            ),
            _more(
              title: "내일 계획",
              icon: Icons.event_note_outlined,
              summary: _nextDayPlanCtrl.text.trim(),
              filled: _nextDayPlanCtrl.text.trim().isNotEmpty,
              children: [
                TextField(
                  controller: _nextDayPlanCtrl,
                  maxLines: 2,
                  onChanged: (_) => setState(() {}),
                  decoration: _dec(hint: "예: 내일은 B동 결선 마무리 예정"),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: VoiceInputButton(
                    controller: _nextDayPlanCtrl,
                    onChanged: () => setState(() {}),
                  ),
                ),
              ],
            ),
            if (widget.pendingSchedules.isNotEmpty)
              _more(
                title: "오늘 끝낸 일정",
                icon: Icons.task_alt_rounded,
                summary: _completedScheduleIds.isEmpty
                    ? ""
                    : "${_completedScheduleIds.length}건 완료 처리",
                filled: _completedScheduleIds.isNotEmpty,
                children: [
                  Text(
                    keepWords("체크하면 저장할 때 프로젝트 일정이 완료로 바뀝니다."),
                    style: TextStyle(color: tossSubText, fontSize: 12),
                  ),
                  ...widget.pendingSchedules.map((sc) {
                    final id = sc['id']?.toString() ?? '';
                    return CheckboxListTile(
                      value: _completedScheduleIds.contains(id),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: makitaTeal,
                      title: Text(
                        sc['title']?.toString() ?? sc['type']?.toString() ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: tossText,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        sc['type']?.toString() ?? '',
                        style: const TextStyle(
                          color: tossSubText,
                          fontSize: 12,
                        ),
                      ),
                      onChanged: (v) => setState(() {
                        v == true
                            ? _completedScheduleIds.add(id)
                            : _completedScheduleIds.remove(id);
                      }),
                    );
                  }),
                ],
              ),
            if (widget.relatedIssueCandidates.isNotEmpty)
              _more(
                title: "오늘 처리한 이슈",
                icon: Icons.build_circle_outlined,
                summary: _selectedIssueIds.isEmpty
                    ? ""
                    : "${_selectedIssueIds.length}건",
                filled: _selectedIssueIds.isNotEmpty,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.relatedIssueCandidates
                        .map(_buildIssueChip)
                        .toList(),
                  ),
                ],
              ),
            if (widget.floorPlanImagePath != null)
              _more(
                title: "작업 위치 (도면 핀)",
                icon: Icons.push_pin_outlined,
                summary: _pinDx == null ? "" : "위치 지정됨",
                filled: _pinDx != null,
                children: [
                  FloorPlanThumbnail(
                    imagePath: widget.floorPlanImagePath!,
                    dx: _pinDx,
                    dy: _pinDy,
                    onTap: _openPinPicker,
                  ),
                  TextButton.icon(
                    onPressed: _openPinPicker,
                    icon: const Icon(Icons.push_pin_outlined, size: 16),
                    label: Text(_pinDx == null ? "위치 찍기" : "위치 다시 찍기"),
                    style: TextButton.styleFrom(
                      foregroundColor: makitaTeal,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            _more(
              title: "도면 수정 요청",
              icon: Icons.draw_outlined,
              summary: _isAsBuilt ? _asBuiltCtrl.text.trim() : "",
              filled: _isAsBuilt,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        keepWords("실제 시공이 도면과 달라 수정이 필요합니다"),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: tossText,
                        ),
                      ),
                    ),
                    CupertinoSwitch(
                      value: _isAsBuilt,
                      activeTrackColor: Colors.orange.shade500,
                      onChanged: (v) => setState(() => _isAsBuilt = v),
                    ),
                  ],
                ),
                if (_isAsBuilt) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _asBuiltCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: _dec(hint: "변경 사유 및 실제 시공 치수를 입력하십시오."),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: pureWhite,
            border: Border(top: BorderSide(color: Color(0xFFEDEFF2))),
          ),
          child: SizedBox(
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: makitaTeal,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _submit,
              child: Text(
                _isEdit ? "수정 완료" : "일보 저장",
                style: const TextStyle(
                  color: pureWhite,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
