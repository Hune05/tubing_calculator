import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart'; // 🚀 HapticFeedback을 위해 추가
import '../../../core/utils/image_picker_helper.dart';
import 'package:tubing_calculator/src/core/common_widgets/makita_time_picker.dart';

// 🚀 [추가] 방금 만든 배치도 페이지 임포트
import 'layout_board_page.dart';
import 'tablet_layout_board_page.dart';
import '../widgets/photo_detail_modal.dart';
import 'floor_plan_pin_page.dart';

const Color tossBlue = Color(0xFF3182F6);
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

  const DailyReportPage({
    super.key,
    this.existingData,
    this.previousReport,
    this.relatedIssueCandidates = const [],
    this.floorPlanImagePath,
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

    if (_isEdit) {
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
  }

  @override
  void dispose() {
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
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("어제 값을 불러왔습니다.")),
    );
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
      MaterialPageRoute(
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
    if (_attachedImages.length >= 5) return;
    FocusScope.of(context).unfocus();
    final path = await ImagePickerHelper.pickImage(context);
    if (path != null) setState(() => _attachedImages.add(path));
  }

  // 🚀 지난 날짜 일지 수정 시 사유를 받는 팝업. 취소하면 null.
  Future<String?> _askEditReason() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "지난 일지 수정 사유",
          style: TextStyle(fontWeight: FontWeight.w800, color: tossText),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "지난 날짜의 작업 일보는 함부로 바꾸지 않도록, 수정할 때 사유를 남깁니다.",
              style: TextStyle(color: tossSubText, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLines: 2,
              style: const TextStyle(color: tossText),
              decoration: InputDecoration(
                hintText: "예: 포인트 집계 실수 정정",
                hintStyle: const TextStyle(color: Color(0xFFB0B8C1)),
                filled: true,
                fillColor: tossInputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text("취소", style: TextStyle(color: tossSubText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: tossBlue,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(
              context,
              ctrl.text.trim().isEmpty ? "사유 미입력" : ctrl.text.trim(),
            ),
            child: const Text(
              "수정 확정",
              style: TextStyle(color: pureWhite, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _submit() async {
    String ptText = _pointCtrl.text.trim();
    String wpText = _wiringPointCtrl.text.trim();
    String ntText = _noteCtrl.text.trim();

    if (ptText.isEmpty &&
        wpText.isEmpty &&
        ntText.isEmpty &&
        _attachedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("작업 포인트, 내용, 또는 사진을 입력해주세요."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 🚀 지난 날짜 일지를 수정하는 경우, 사유를 받아 이력에 남기기 전엔
    // 저장을 진행하지 않는다. 취소하면 그대로 화면에 머문다.
    final List<Map<String, dynamic>> editHistory = _isEdit
        ? List<Map<String, dynamic>>.from(
            (widget.existingData!['editHistory'] as List? ?? []).map(
              (e) => Map<String, dynamic>.from(e),
            ),
          )
        : [];

    if (_isPastEdit) {
      final String? reason = await _askEditReason();
      if (reason == null) return;
      editHistory.add({'reason': reason, 'editedAt': DateTime.now()});
    }

    final dateStr = _isEdit ? widget.existingData!['date'] : _todayDateStr();

    final newReport = {
      "date": dateStr,
      "work_type": _selectedWorkTypes.toList(),
      "worker_count": _workerCount,
      "is_overtime": _isOvertime,
      // 🚀 [추가] 연장/야간 작업 시간대 - 껐으면 기록도 지운다.
      "overtime_start": _isOvertime && _overtimeStart != null
          ? _formatTimeOfDay(_overtimeStart!)
          : null,
      "overtime_end": _isOvertime && _overtimeEnd != null
          ? _formatTimeOfDay(_overtimeEnd!)
          : null,
      "overtime_hours": _isOvertime ? _overtimeHours : null,
      "points": int.tryParse(ptText) ?? 0,
      "wiring_points": int.tryParse(wpText) ?? 0,
      "note": ntText.isEmpty ? "특이사항 없음" : ntText,
      "is_as_built": _isAsBuilt,
      "as_built_reason": _isAsBuilt ? _asBuiltCtrl.text.trim() : "",
      "has_image": _attachedImages.isNotEmpty,
      "image_path": _attachedImages.isNotEmpty ? _attachedImages.first : null,
      "image_paths": List.from(_attachedImages),
      "editHistory": editHistory,
      // 🚀 [추가] 오늘 처리한 이슈 태그.
      "linkedIssueIds": _selectedIssueIds.toList(),
      // 🚀 [추가] 내일 계획 / 오늘 사용한 자재.
      "next_day_plan": _nextDayPlanCtrl.text.trim(),
      "materials_used": _materialsUsedCtrl.text.trim(),
      // 🚀 [추가] 도면 위 작업 위치 핀.
      "locationPinDx": _pinDx,
      "locationPinDy": _pinDy,
    };

    if (!mounted) return;
    Navigator.pop(context, newReport);
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
          issue['content'] ?? issue['location'] ?? '이슈',
          style: TextStyle(
            color: selected ? pureWhite : tossSubText,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pureWhite,
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
        title: Text(
          _isEdit ? "작업 일보 수정" : "작업 일보 작성",
          style: const TextStyle(
            color: tossText,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🚀 [추가] 오늘 날짜가 아닌 일지를 열었을 때, 저장 시 사유가
              // 필요하다는 걸 미리 알려준다.
              if (_isPastEdit) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                    ),
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
                          "${widget.existingData!['date']}의 지난 일지입니다. 저장하려면 수정 사유를 입력해야 해요.",
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
                const SizedBox(height: 20),
              ],
              // 🚀 [추가] 새로 작성 중이고 어제(최근) 일지가 있으면, 반복
              // 작업일 때 타이핑을 줄이는 버튼과 어제 적어둔 계획을 보여준다.
              if (!_isEdit && widget.previousReport != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _loadPreviousValues,
                        icon: const Icon(Icons.history_rounded, size: 18),
                        label: const Text("어제 값 불러오기"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: tossBlue,
                          side: BorderSide(
                            color: tossBlue.withValues(alpha: 0.4),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if ((widget.previousReport!['next_day_plan'] as String?)
                        ?.isNotEmpty ==
                    true) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: makitaTeal.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.event_note_rounded,
                          color: makitaTeal,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "어제 적어둔 계획: ${widget.previousReport!['next_day_plan']}",
                            style: const TextStyle(
                              color: makitaTeal,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
              ],
              // 1. 작업 유형 선택 (🚀 복수 선택 가능)
              const Text(
                "작업 유형 (여러 개 선택 가능)",
                style: TextStyle(
                  color: tossText,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _workTypes.map((type) {
                  final bool selected = _selectedWorkTypes.contains(type);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (selected) {
                        // 최소 1개는 남겨둔다.
                        if (_selectedWorkTypes.length > 1) {
                          _selectedWorkTypes.remove(type);
                        }
                      } else {
                        _selectedWorkTypes.add(type);
                      }
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? tossBlue : tossInputBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (selected) ...[
                            const Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: pureWhite,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            type,
                            style: TextStyle(
                              color: selected ? pureWhite : tossSubText,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              // 2. 투입 인원 및 연장 여부
              const Text(
                "투입 인원 및 시간",
                style: TextStyle(
                  color: tossText,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: tossInputBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "오늘 투입된 인원",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: tossText,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => setState(() {
                                if (_workerCount > 1) _workerCount--;
                              }),
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: tossSubText,
                              ),
                            ),
                            Text(
                              "$_workerCount 명",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: tossText,
                              ),
                            ),
                            IconButton(
                              onPressed: () => setState(() => _workerCount++),
                              icon: const Icon(
                                Icons.add_circle_outline,
                                color: tossBlue,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFFD1D6DB), height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "연장 / 야간 작업 수행",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: tossText,
                          ),
                        ),
                        CupertinoSwitch(
                          value: _isOvertime,
                          activeTrackColor:
                              tossBlue, // 🚀 activeColor -> activeTrackColor 변경 완료
                          onChanged: (val) => setState(() => _isOvertime = val),
                        ),
                      ],
                    ),
                    // 🚀 [추가] 연장/야간 작업 시간대 입력
                    if (_isOvertime) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _pickOvertimeTime(isStart: true),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: pureWhite,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _overtimeStart != null
                                          ? _formatTimeOfDay(_overtimeStart!)
                                          : "시작 시간",
                                      style: TextStyle(
                                        color: _overtimeStart != null
                                            ? tossText
                                            : tossSubText,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.access_time_rounded,
                                      size: 16,
                                      color: tossSubText,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text("~", style: TextStyle(color: tossSubText)),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => _pickOvertimeTime(isStart: false),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: pureWhite,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _overtimeEnd != null
                                          ? _formatTimeOfDay(_overtimeEnd!)
                                          : "종료 시간",
                                      style: TextStyle(
                                        color: _overtimeEnd != null
                                            ? tossText
                                            : tossSubText,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.access_time_rounded,
                                      size: 16,
                                      color: tossSubText,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_overtimeHours != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          "연장/야간 근무 시간: ${_overtimeHours!.toStringAsFixed(1)}시간",
                          style: const TextStyle(
                            color: tossBlue,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // 3. 작업 포인트 및 상세 내용
              const Text(
                "상세 작업 내역",
                style: TextStyle(
                  color: tossText,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pointCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: tossText,
                      ),
                      decoration: InputDecoration(
                        labelText: "벤딩 완료 (pt)",
                        labelStyle: const TextStyle(
                          color: tossSubText,
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: tossInputBg,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _wiringPointCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: tossText,
                      ),
                      decoration: InputDecoration(
                        labelText: "결선 완료 (개소)",
                        labelStyle: const TextStyle(
                          color: tossSubText,
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: tossInputBg,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteCtrl,
                maxLines: 4,
                style: const TextStyle(
                  fontSize: 15,
                  color: tossText,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText:
                      "오늘 작업의 특이사항이나 전달사항을 적어주세요.\n(예: 센서 3개소 결선 완료, 튜브 라인 연결)",
                  hintStyle: const TextStyle(color: Color(0xFFB0B8C1)),
                  filled: true,
                  fillColor: tossInputBg,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // 🚀 [추가] 오늘 사용한 자재 (간단 기록)
              const Text(
                "오늘 사용한 자재 (선택)",
                style: TextStyle(
                  color: tossText,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _materialsUsedCtrl,
                maxLines: 2,
                style: const TextStyle(
                  fontSize: 15,
                  color: tossText,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText: "예: 1/2\" 튜빙 10m, 유니온 피팅 5개",
                  hintStyle: const TextStyle(color: Color(0xFFB0B8C1)),
                  filled: true,
                  fillColor: tossInputBg,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // 🚀 [추가] 내일 계획 메모
              const Text(
                "내일 계획 (선택)",
                style: TextStyle(
                  color: tossText,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nextDayPlanCtrl,
                maxLines: 2,
                style: const TextStyle(
                  fontSize: 15,
                  color: tossText,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText: "예: 내일은 B동 결선 마무리 예정",
                  hintStyle: const TextStyle(color: Color(0xFFB0B8C1)),
                  filled: true,
                  fillColor: tossInputBg,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // 🚀 [추가] 오늘 처리한 이슈 태그
              if (widget.relatedIssueCandidates.isNotEmpty) ...[
                const Text(
                  "오늘 처리한 이슈 (선택)",
                  style: TextStyle(
                    color: tossText,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.relatedIssueCandidates
                      .map(_buildIssueChip)
                      .toList(),
                ),
                const SizedBox(height: 32),
              ],

              // 🚀 [추가] 도면 위 작업 위치 핀
              if (widget.floorPlanImagePath != null) ...[
                const Text(
                  "오늘 작업 위치 (선택)",
                  style: TextStyle(
                    color: tossText,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                FloorPlanThumbnail(
                  imagePath: widget.floorPlanImagePath!,
                  dx: _pinDx,
                  dy: _pinDy,
                  onTap: _openPinPicker,
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _openPinPicker,
                  icon: const Icon(Icons.push_pin_outlined, size: 16),
                  label: Text(_pinDx == null ? "위치 찍기" : "위치 다시 찍기"),
                  style: TextButton.styleFrom(
                    foregroundColor: makitaTeal,
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // 🚀 4. 현장 배치도 스케치 연동 버튼
              const Text(
                "현장 배치도 스케치",
                style: TextStyle(
                  color: tossText,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  // 🚀 [수정] 화면 크기를 다시 재서 태블릿 폭이면 좌우 패널형
                  // 태블릿 버전을, 아니면 기존 바텀시트형 모바일 버전을 연다.
                  final bool isTabletSize =
                      MediaQuery.of(context).size.shortestSide >= 600;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => isTabletSize
                          ? const TabletLayoutBoardPage()
                          : const MobileLayoutBoardPage(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: tossBlue.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: tossBlue.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.architecture_rounded,
                        color: tossBlue,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "배치도 및 스케치 작성",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: tossText,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "장비 배치, 튜빙/결선 라인을 직접 그려보세요.",
                              style: TextStyle(
                                fontSize: 13,
                                color: tossSubText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: tossSubText,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // 5. As-Built
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _isAsBuilt
                      ? Colors.orange.withValues(alpha: 0.05)
                      : tossInputBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isAsBuilt
                        ? Colors.orange.withValues(alpha: 0.3)
                        : Colors.transparent,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "도면 반영 요청",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: tossText,
                          ),
                        ),
                        CupertinoSwitch(
                          value: _isAsBuilt,
                          activeTrackColor: Colors
                              .orange
                              .shade500, // 🚀 activeColor -> activeTrackColor 변경 완료
                          onChanged: (val) => setState(() => _isAsBuilt = val),
                        ),
                      ],
                    ),
                    if (_isAsBuilt) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _asBuiltCtrl,
                        style: const TextStyle(fontSize: 14, color: tossText),
                        decoration: InputDecoration(
                          hintText: "변경 사유 및 실제 시공 치수를 입력하세요.",
                          hintStyle: const TextStyle(color: Color(0xFFB0B8C1)),
                          filled: true,
                          fillColor: pureWhite,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.orange.shade200,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // 6. 사진 첨부
              const Text(
                "현장 사진 첨부",
                style: TextStyle(
                  color: tossText,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    InkWell(
                      onTap: _handleAddImage,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: tossInputBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.camera_alt_rounded,
                              color: tossSubText,
                              size: 24,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${_attachedImages.length}/5",
                              style: const TextStyle(
                                color: tossSubText,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ..._attachedImages.asMap().entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Stack(
                          alignment: Alignment.topRight,
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(12),
                              // 🚀 [추가] 첨부한 사진을 탭하면 삭제밖에
                              // 못 하던 걸 고쳐서, 눌렀을 때 크게(줌 가능)
                              // 볼 수 있게 했다.
                              onTap: () => PhotoDetailModal.show(
                                context: context,
                                title: "현장 사진",
                                content: "",
                                imagePaths: _attachedImages,
                                initialIndex: entry.key,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  File(entry.value),
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () => setState(
                                () => _attachedImages.removeAt(entry.key),
                              ),
                              child: Container(
                                margin: const EdgeInsets.all(4),
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
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: SizedBox(
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: tossBlue,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _submit,
              child: Text(
                _isEdit ? "수정 완료" : "일보 저장하기",
                style: const TextStyle(
                  color: pureWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
