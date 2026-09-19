import 'package:flutter/material.dart';
import '../widgets/korean_text.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:tubing_calculator/src/core/common_widgets/makita_time_picker.dart';

const Color tossBlue = Color(0xFF007580); // 🚀 마키타 틸로 통일
const Color tossText = Color(0xFF191F28);
const Color tossSubText = Color(0xFF8B95A1);
const Color tossBg = Color(0xFFF2F4F6);
const Color pureWhite = Color(0xFFFFFFFF);
const Color warningRed = Color(0xFFF04438);

// 🚀 [추가] 프로젝트 카드의 "계산기" 버튼이 사실 debugPrint만 찍는
// 죽은 버튼이었어서, 그 자리를 "일정 관리"로 교체했다. 자재 요청/입고일/
// 납기일/검사일정처럼 날짜가 있는 항목을 등록해두면, 서버(Cloud
// Functions)가 15분마다 확인해서 시간이 다가오거나(사전 알림) 지나면
// (초과 알림) 폰으로 알려준다 - 자재 발주의 입고 예정 알림과 동일한
// 방식(functions/index.js 참고).
const List<String> kScheduleTypes = ["자재 요청", "입고일", "납기일", "검사일정", "기타"];

IconData _iconForType(String type) {
  switch (type) {
    case "자재 요청":
      return Icons.local_shipping_outlined;
    case "입고일":
      return Icons.inventory_2_outlined;
    case "납기일":
      return Icons.event_available_outlined;
    case "검사일정":
      return Icons.fact_check_outlined;
    default:
      return Icons.event_note_outlined;
  }
}

class ProjectSchedulePage extends StatefulWidget {
  final String projectName;
  final List<Map<String, dynamic>> initialSchedules;
  // 🚀 [추가] 이슈(펀치)가 검사일정에 연결(linkedScheduleId)돼 있을 때,
  // 그 검사일정 카드에 "미해결 이슈 N건"을 보여주기 위한 참조용 목록.
  // 여기서 수정하지는 않고 개수만 세는 용도라 읽기 전용으로 받는다.
  final List<Map<String, dynamic>> punchLists;
  // 🚀 [프로젝트 단계] 이 프로젝트의 단계 목록(id/name). 일정을 단계에 붙이고
  // 단계별로 걸러볼 때 쓴다. initialPhaseId가 있으면 그 단계만 보여주고 새
  // 일정도 그 단계로 만든다. openEditorOnStart면 열자마자 새 일정 입력을 띄운다.
  final List<Map<String, dynamic>> phases;
  final String? initialPhaseId;
  final bool openEditorOnStart;

  const ProjectSchedulePage({
    super.key,
    required this.projectName,
    required this.initialSchedules,
    this.punchLists = const [],
    this.phases = const [],
    this.initialPhaseId,
    this.openEditorOnStart = false,
  });

  @override
  State<ProjectSchedulePage> createState() => _ProjectSchedulePageState();
}

class _ProjectSchedulePageState extends State<ProjectSchedulePage> {
  late List<Map<String, dynamic>> _schedules;
  bool _changed = false;
  // 🚀 [추가] 납기일/검사일정 등과 섞여 있으면 자재 요청/입고일만 따로
  // 확인하기 번거로워서, 목록 위에 필터를 둬서 "자재만" 모아볼 수 있게
  // 한다 (새 화면/메뉴 없이 기존 일정 관리 안에서 필터로 해결).
  String _filter = "전체";
  static const List<String> _materialTypes = ["자재 요청", "입고일"];
  // 🚀 [추가] 완료된 일정도 계속 목록에 남아있으면 시간이 지날수록
  // 리스트가 길어지므로, 기본은 미완료만 보여주고 필요할 때만 켜서
  // 완료된 것까지 보게 한다.
  bool _hideCompleted = true;
  // 🚀 [추가] 리스트 대신 달력으로도 볼 수 있게 - 작업 일지의 달력 뷰와
  // 통일감 있게, 새 화면을 열지 않고 같은 화면 안에서 토글한다.
  bool _showCalendar = false;
  late DateTime _calendarMonth;

  List<Map<String, dynamic>> get _visibleSchedules {
    Iterable<Map<String, dynamic>> list = _schedules;
    if (_filter == "자재") {
      list = list.where((s) => _materialTypes.contains(s['type']));
    }
    if (_hideCompleted) {
      list = list.where((s) => s['isCompleted'] != true);
    }
    if (_phaseFilter != null) {
      list = list.where((s) {
        final pid = s['phaseId']?.toString();
        if (_phaseFilter == '__none__') return pid == null || pid.isEmpty;
        return pid == _phaseFilter;
      });
    }
    return list.toList();
  }

  // null=전체, '__none__'=단계 미지정, 그 외=단계 id
  String? _phaseFilter;

  String? _phaseNameOf(Map<String, dynamic> item) {
    final pid = item['phaseId']?.toString();
    if (pid == null) return null;
    for (final p in widget.phases) {
      if (p['id']?.toString() == pid) return p['name']?.toString();
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _schedules = widget.initialSchedules
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    _sort();
    final now = DateTime.now();
    _calendarMonth = DateTime(now.year, now.month);
    _phaseFilter = widget.initialPhaseId;
    if (widget.openEditorOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showEditor();
      });
    }
  }

  void _sort() {
    _schedules.sort((a, b) {
      // 🚀 입고일을 아직 모르는 "자재 요청"(dateTime null)은 확인이 가장
      // 필요한 항목이니 맨 위로 올린다.
      final DateTime? da = a['dateTime'] == null
          ? null
          : _asDateTime(a['dateTime']);
      final DateTime? db = b['dateTime'] == null
          ? null
          : _asDateTime(b['dateTime']);
      if (da == null && db == null) return 0;
      if (da == null) return -1;
      if (db == null) return 1;
      return da.compareTo(db);
    });
  }

  // 🚀 Firestore에서 다시 불러오면 DateTime이 아니라 Timestamp로 온다
  // (저장 직후 메모리에 있는 값은 DateTime). 두 경우 다 처리한다.
  DateTime _asDateTime(dynamic v) {
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  // 🚀 [추가] 검사일정/납기일은 자주 밀릴 수 있어서, 그냥 날짜만
  // 덮어쓰지 않고 "왜 바뀌었는지"를 남긴다. 취소하면 null을 반환해서
  // 날짜 변경 자체를 되돌린다.
  static const List<String> _reschedulableTypes = ["검사일정", "납기일"];

  Future<String?> _askChangeReason(BuildContext context) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "일정 변경 사유",
          style: TextStyle(fontWeight: FontWeight.w800, color: tossText),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 2,
          style: const TextStyle(color: tossText),
          decoration: InputDecoration(
            hintText: "예: 검사업체 사정으로 일정 연기",
            hintStyle: const TextStyle(color: Color(0xFFB0B8C1)),
            filled: true,
            fillColor: tossBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
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
              "변경 확정",
              style: TextStyle(color: pureWhite, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditor({Map<String, dynamic>? existing}) async {
    String type = existing?['type'] ?? kScheduleTypes.first;
    final titleCtrl = TextEditingController(text: existing?['title'] ?? '');
    final noteCtrl = TextEditingController(text: existing?['note'] ?? '');
    // 🚀 [추가] "자재 요청"은 등록 시점에 아직 입고일을 모를 수 있다 -
    // 발주만 넣어두고 나중에 거래처가 입고일을 알려주면 그때 채우는
    // 흐름이라, 새로 만들 때는 날짜를 비워둘 수 있게 한다(다른 종류는
    // 날짜가 곧 그 일정의 의미라 계속 필수로 둔다).
    DateTime? dateTime = existing != null
        ? (existing['dateTime'] != null
              ? _asDateTime(existing['dateTime'])
              : null)
        : (type == "자재 요청"
              ? null
              : DateTime.now().add(const Duration(days: 1)));
    // 🚀 [추가] 며칠 전부터 매일 미리 알림을 받을지 - 기본은 0(당일
    // 60~75분 전 1회 알림, 기존과 동일). 검사일정처럼 미리 준비가
    // 필요한 일정은 3일/7일 전부터로 늘려서 쓸 수 있다.
    int reminderLeadDays = existing?['reminderLeadDays'] ?? 0;
    // 🚀 [프로젝트 단계] 이 일정이 속한 단계. 새 일정이면 지금 보고 있는
    // 단계(있으면)를 기본으로 한다.
    String? phaseId = existing != null
        ? existing['phaseId']?.toString()
        : widget.initialPhaseId;
    // 🚀 [기간 일정] 며칠~몇 주에 걸친 작업(설치·시운전 등)은 종료일까지
    // 넣으면 내 일정 관리 달력에 이어진 막대로 보인다. null이면 하루짜리.
    DateTime? endDate = existing?['endDate'] != null
        ? _asDateTime(existing!['endDate'])
        : null;
    // 🚀 검사일정/납기일이 바뀔 때마다 "언제에서 언제로, 왜" 바뀌었는지
    // 쌓아두는 이력. 기존 이력은 그대로 유지하고 새 변경만 추가된다.
    final List<Map<String, dynamic>> changeHistory =
        existing?['changeHistory'] != null
        ? List<Map<String, dynamic>>.from(
            (existing!['changeHistory'] as List).map(
              (e) => Map<String, dynamic>.from(e),
            ),
          )
        : [];

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                decoration: const BoxDecoration(
                  color: pureWhite,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                // 내용은 스크롤되고, 추가/저장 버튼은 아래에 고정해 항상 보이게 한다.
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              existing == null ? "일정 추가" : "일정 수정",
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: tossText,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              "종류",
                              style: TextStyle(
                                color: tossSubText,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: kScheduleTypes.map((t) {
                                final bool selected = t == type;
                                return ChoiceChip(
                                  label: Text(t),
                                  selected: selected,
                                  selectedColor: tossBlue.withValues(
                                    alpha: 0.15,
                                  ),
                                  labelStyle: TextStyle(
                                    color: selected ? tossBlue : tossSubText,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  backgroundColor: tossBg,
                                  side: BorderSide.none,
                                  onSelected: (_) => setModalState(() {
                                    type = t;
                                    // 🚀 "자재 요청"이 아닌 종류는 날짜가 필수라
                                    // 비어있으면 기본값(내일)을 채워준다.
                                    if (type != "자재 요청" && dateTime == null) {
                                      dateTime = DateTime.now().add(
                                        const Duration(days: 1),
                                      );
                                    }
                                  }),
                                );
                              }).toList(),
                            ),
                            if (widget.phases.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const Text(
                                "단계",
                                style: TextStyle(
                                  color: tossSubText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final p in [
                                    {'id': null, 'name': '미지정'},
                                    ...widget.phases,
                                  ])
                                    ChoiceChip(
                                      label: Text(p['name'].toString()),
                                      selected: phaseId == p['id']?.toString(),
                                      selectedColor: tossBlue.withValues(
                                        alpha: 0.15,
                                      ),
                                      labelStyle: TextStyle(
                                        color: phaseId == p['id']?.toString()
                                            ? tossBlue
                                            : tossSubText,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      backgroundColor: tossBg,
                                      side: BorderSide.none,
                                      onSelected: (_) => setModalState(
                                        () => phaseId = p['id']?.toString(),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 20),
                            TextField(
                              controller: titleCtrl,
                              style: const TextStyle(
                                color: tossText,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                labelText: "제목 (비워두면 종류로 표시)",
                                filled: true,
                                fillColor: tossBg,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () async {
                                final DateTime base =
                                    dateTime ?? DateTime.now();
                                final pickedDate = await showDatePicker(
                                  context: context,
                                  initialDate: base,
                                  firstDate: DateTime.now().subtract(
                                    const Duration(days: 365),
                                  ),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 730),
                                  ),
                                );
                                if (pickedDate == null) return;
                                if (!context.mounted) return;
                                final pickedTime = await showMakitaTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.fromDateTime(base),
                                );
                                final DateTime newDateTime = DateTime(
                                  pickedDate.year,
                                  pickedDate.month,
                                  pickedDate.day,
                                  pickedTime?.hour ?? 9,
                                  pickedTime?.minute ?? 0,
                                );

                                // 🚀 검사일정/납기일을 "수정"하면서 날짜가 실제로
                                // 바뀌는 경우엔 사유를 받아 이력에 남긴다. 새로
                                // 만드는 중이거나 다른 종류면 그냥 바로 반영한다.
                                final bool isReschedule =
                                    existing != null &&
                                    _reschedulableTypes.contains(type) &&
                                    dateTime != null &&
                                    !dateTime!.isAtSameMomentAs(newDateTime);

                                if (isReschedule) {
                                  if (!context.mounted) return;
                                  final String? reason = await _askChangeReason(
                                    context,
                                  );
                                  if (reason == null) return; // 취소 시 변경 안 함
                                  changeHistory.add({
                                    'from': dateTime,
                                    'to': newDateTime,
                                    'reason': reason,
                                    'changedAt': DateTime.now(),
                                  });
                                }

                                setModalState(() {
                                  dateTime = newDateTime;
                                  // 🚀 날짜를 받았다는 건 입고일이 확정됐다는
                                  // 뜻이니, "자재 요청"이었다면 여기서 바로
                                  // "입고일"로 전환한다.
                                  if (type == "자재 요청") type = "입고일";
                                });
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: tossBg,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      dateTime != null
                                          ? _formatDateTime(dateTime!)
                                          : "아직 입고일 모름 (탭해서 입력)",
                                      style: TextStyle(
                                        color: dateTime != null
                                            ? tossText
                                            : tossSubText,
                                        fontWeight: dateTime != null
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.calendar_month_rounded,
                                      color: tossBlue,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (type == "자재 요청" && dateTime != null) ...[
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () =>
                                    setModalState(() => dateTime = null),
                                style: TextButton.styleFrom(
                                  foregroundColor: tossSubText,
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  "아직 모름으로 되돌리기",
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                            if (dateTime != null) ...[
                              const SizedBox(height: 16),
                              const Text(
                                "기간 (여러 날에 걸친 작업)",
                                style: TextStyle(
                                  color: tossSubText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final d in [1, 3, 7, 14, 28, 56])
                                    Builder(
                                      builder: (_) {
                                        final DateTime s = DateTime(
                                          dateTime!.year,
                                          dateTime!.month,
                                          dateTime!.day,
                                        );
                                        final int cur = endDate == null
                                            ? 1
                                            : DateTime(
                                                    endDate!.year,
                                                    endDate!.month,
                                                    endDate!.day,
                                                  ).difference(s).inDays +
                                                  1;
                                        final bool selected = cur == d;
                                        return ChoiceChip(
                                          label: Text(
                                            d == 1
                                                ? "당일"
                                                : (d % 7 == 0
                                                      ? "${d ~/ 7}주"
                                                      : "$d일"),
                                          ),
                                          selected: selected,
                                          selectedColor: tossBlue.withValues(
                                            alpha: 0.15,
                                          ),
                                          labelStyle: TextStyle(
                                            color: selected
                                                ? tossBlue
                                                : tossSubText,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          backgroundColor: tossBg,
                                          side: BorderSide.none,
                                          onSelected: (_) => setModalState(
                                            () => endDate = d == 1
                                                ? null
                                                : s.add(Duration(days: d - 1)),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () async {
                                  final DateTime s = DateTime(
                                    dateTime!.year,
                                    dateTime!.month,
                                    dateTime!.day,
                                  );
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate:
                                        (endDate == null ||
                                            endDate!.isBefore(s))
                                        ? s
                                        : endDate!,
                                    firstDate: s,
                                    lastDate: s.add(const Duration(days: 730)),
                                  );
                                  if (picked != null) {
                                    setModalState(
                                      () =>
                                          endDate = picked == s ? null : picked,
                                    );
                                  }
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tossBg,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(
                                    endDate == null
                                        ? "종료일 없음 (하루 일정)"
                                        : "종료일 ${endDate!.year}.${endDate!.month.toString().padLeft(2, '0')}.${endDate!.day.toString().padLeft(2, '0')}",
                                    style: TextStyle(
                                      color: endDate == null
                                          ? tossSubText
                                          : tossText,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                "며칠 전부터 미리 알림",
                                style: TextStyle(
                                  color: tossSubText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [0, 1, 3, 7].map((d) {
                                  final bool selected = reminderLeadDays == d;
                                  return ChoiceChip(
                                    label: Text(d == 0 ? "당일만" : "$d일 전부터"),
                                    selected: selected,
                                    selectedColor: tossBlue.withValues(
                                      alpha: 0.15,
                                    ),
                                    labelStyle: TextStyle(
                                      color: selected ? tossBlue : tossSubText,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    backgroundColor: tossBg,
                                    side: BorderSide.none,
                                    onSelected: (_) => setModalState(
                                      () => reminderLeadDays = d,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                            const SizedBox(height: 12),
                            TextField(
                              controller: noteCtrl,
                              maxLines: 2,
                              style: const TextStyle(color: tossText),
                              decoration: InputDecoration(
                                labelText: "메모 (선택)",
                                filled: true,
                                fillColor: tossBg,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tossBlue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.pop(context, {
                            'id':
                                existing?['id'] ??
                                DateTime.now().millisecondsSinceEpoch
                                    .toString(),
                            'type': type,
                            'title': titleCtrl.text.trim().isNotEmpty
                                ? titleCtrl.text.trim()
                                : type,
                            'dateTime': dateTime,
                            'endDate': endDate,
                            'phaseId': phaseId,
                            'note': noteCtrl.text.trim(),
                            'isCompleted': existing?['isCompleted'] ?? false,
                            // 🚀 입고일을 아직 모르는 "자재 요청"이 "발주한
                            // 지 며칠째"를 알려줄 수 있도록 최초 등록
                            // 시각을 남겨둔다 (수정해도 값은 유지).
                            'requestedAt':
                                existing?['requestedAt'] ?? DateTime.now(),
                            'changeHistory': changeHistory,
                            // 🚀 [추가] 며칠 전부터 미리 알림 받을지.
                            'reminderLeadDays': reminderLeadDays,
                            // 🚀 [수정] 이 화면(수정 모드)에서 새 Map을
                            // 통째로 만들어 기존 항목을 덮어쓰다 보니,
                            // 검사 결과(합격/불합격+코멘트)를 여기서
                            // 안 옮겨주면 단순 제목/메모 수정만 해도
                            // 검사 결과가 사라지는 문제가 있었다. 그대로
                            // 이어서 담아준다.
                            'inspectionResult': existing?['inspectionResult'],
                            'inspectionComment': existing?['inspectionComment'],
                            'inspectionResultAt':
                                existing?['inspectionResultAt'],
                            // 🚀 시간/종류가 바뀔 수 있으니 저장할 때마다
                            // 알림 발송 플래그를 초기화해서, 새 시각
                            // 기준으로 다시 알림이 잡히게 한다.
                            'reminderSent': false,
                            'lastOverdueReminderDate': null,
                            'lastLeadReminderDate': null,
                          });
                        },
                        child: Text(
                          existing == null ? "추가" : "저장",
                          style: const TextStyle(
                            color: pureWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
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

    if (result == null) return;
    setState(() {
      if (existing != null) {
        final idx = _schedules.indexWhere((s) => s['id'] == existing['id']);
        if (idx != -1) {
          _schedules[idx] = result;
        }
      } else {
        _schedules.add(result);
      }
      _sort();
      _changed = true;
    });
  }

  // 🚀 [추가] 검사일정은 단순 체크가 아니라 "합격/불합격 + 코멘트"를
  // 남기게 해서 나중에 어떤 검사가 어떻게 됐는지 추적할 수 있게 한다.
  // 취소하면 null - 완료 처리를 하지 않는다.
  Future<Map<String, String>?> _askInspectionResult(
    BuildContext context,
  ) async {
    String result = 'PASS';
    final ctrl = TextEditingController();
    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: pureWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "검사 결과 입력",
            style: TextStyle(fontWeight: FontWeight.w800, color: tossText),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text("합격"),
                      selected: result == 'PASS',
                      selectedColor: Colors.green.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        color: result == 'PASS' ? Colors.green : tossSubText,
                        fontWeight: FontWeight.bold,
                      ),
                      backgroundColor: tossBg,
                      side: BorderSide.none,
                      onSelected: (_) => setDialogState(() => result = 'PASS'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text("불합격"),
                      selected: result == 'FAIL',
                      selectedColor: warningRed.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        color: result == 'FAIL' ? warningRed : tossSubText,
                        fontWeight: FontWeight.bold,
                      ),
                      backgroundColor: tossBg,
                      side: BorderSide.none,
                      onSelected: (_) => setDialogState(() => result = 'FAIL'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLines: 2,
                style: const TextStyle(color: tossText),
                decoration: InputDecoration(
                  hintText: "코멘트 (선택)",
                  hintStyle: const TextStyle(color: Color(0xFFB0B8C1)),
                  filled: true,
                  fillColor: tossBg,
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
                backgroundColor: result == 'FAIL' ? warningRed : Colors.green,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(context, {
                'result': result,
                'comment': ctrl.text.trim(),
              }),
              child: const Text(
                "완료 처리",
                style: TextStyle(color: pureWhite, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleComplete(Map<String, dynamic> item) async {
    final bool willComplete = !(item['isCompleted'] == true);

    if (willComplete && item['type'] == "검사일정") {
      final result = await _askInspectionResult(context);
      if (result == null) return; // 취소 시 완료 처리 안 함
      setState(() {
        item['isCompleted'] = true;
        item['inspectionResult'] = result['result'];
        item['inspectionComment'] = result['comment'];
        item['inspectionResultAt'] = DateTime.now();
        _changed = true;
      });
      return;
    }

    setState(() {
      item['isCompleted'] = willComplete;
      if (!willComplete) {
        // 다시 미완료로 되돌리면 결과도 초기화한다 - 재검사를 의미하므로.
        item['inspectionResult'] = null;
        item['inspectionComment'] = null;
        item['inspectionResultAt'] = null;
      }
      _changed = true;
    });
  }

  void _delete(Map<String, dynamic> item) {
    setState(() {
      _schedules.removeWhere((s) => s['id'] == item['id']);
      _changed = true;
    });
  }

  String _formatDateTime(DateTime dt) {
    final ampm = dt.hour < 12 ? '오전' : '오후';
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    return "${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} $ampm $h:$m";
  }

  String _relativeLabel(DateTime dt, bool isCompleted) {
    if (isCompleted) return "완료됨";
    final diff = dt.difference(DateTime.now());
    if (diff.isNegative) {
      final days = diff.abs().inDays;
      return days > 0 ? "$days일 지남" : "기한 초과";
    }
    if (diff.inDays > 0) return "D-${diff.inDays}";
    if (diff.inHours > 0) return "${diff.inHours}시간 후";
    return "곧";
  }

  // 🚀 입고일을 아직 모르는 "자재 요청" 항목의 두 번째 줄 문구 - 요청한
  // 지 며칠째인지 보여줘서 얼마나 오래 기다렸는지 감이 오게 한다.
  String _pendingRequestLabel(Map<String, dynamic> item) {
    final DateTime? requestedAt = item['requestedAt'] == null
        ? null
        : _asDateTime(item['requestedAt']);
    if (requestedAt == null) return "입고일 미정";
    final int days = DateTime.now().difference(requestedAt).inDays;
    return days > 0 ? "요청한 지 $days일째 · 입고일 미정" : "오늘 요청 · 입고일 미정";
  }

  // 🚀 [추가] 이 검사일정에 연결된(linkedScheduleId) 이슈 중 아직 처리
  // 안 된 게 몇 건인지 - 검사 전에 뭘 마저 처리해야 하는지 바로 보이게.
  int _unresolvedIssueCount(Map<String, dynamic> item) {
    final String? id = item['id']?.toString();
    if (id == null) return 0;
    return widget.punchLists
        .where((p) => p['linkedScheduleId'] == id && p['is_completed'] != true)
        .length;
  }

  // 🚀 카드에 보여줄 "가장 최근 변경" 한 줄 요약. M/d → M/d 형식으로
  // 짧게 보여주고, 전체 이력(사유 포함)은 탭하면 바텀시트로 본다.
  String _lastChangeLabel(Map<String, dynamic> item) {
    final List history = item['changeHistory'] as List;
    final Map<String, dynamic> last = Map<String, dynamic>.from(history.last);
    final DateTime from = _asDateTime(last['from']);
    final DateTime to = _asDateTime(last['to']);
    final String countSuffix = history.length > 1
        ? " 외 ${history.length - 1}회"
        : "";
    return "${from.month}/${from.day} → ${to.month}/${to.day} 변경$countSuffix";
  }

  void _showChangeHistory(Map<String, dynamic> item) {
    final List history = (item['changeHistory'] as List).reversed.toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        decoration: const BoxDecoration(
          color: pureWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              keepWords("${item['title'] ?? item['type'] ?? ''} · 변경 이력"),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: tossText,
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: history.length,
                separatorBuilder: (_, __) => const Divider(height: 20),
                itemBuilder: (context, index) {
                  final entry = Map<String, dynamic>.from(history[index]);
                  final DateTime from = _asDateTime(entry['from']);
                  final DateTime to = _asDateTime(entry['to']);
                  final DateTime changedAt = _asDateTime(entry['changedAt']);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${_formatDateTime(from)} → ${_formatDateTime(to)}",
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: tossText,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry['reason'] ?? '사유 미입력',
                        style: const TextStyle(color: tossText, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        keepWords("${_formatDateTime(changedAt)}에 변경"),
                        style: const TextStyle(
                          color: tossSubText,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🚀 [신규] "_calendarMonth" 기준 달의 일정을 텍스트로 정리해 클립보드에
  // 복사한다(작업 일지 달력의 내보내기와 동일한 패턴) - 카카오톡 등에
  // 붙여넣어 공유할 수 있다.
  void _exportMonth() {
    final int year = _calendarMonth.year;
    final int month = _calendarMonth.month;

    final List<Map<String, dynamic>> inMonth = [];
    final List<Map<String, dynamic>> undated = [];
    for (final s in _schedules) {
      if (s['dateTime'] == null) {
        undated.add(s);
        continue;
      }
      final DateTime dt = _asDateTime(s['dateTime']);
      if (dt.year == year && dt.month == month) inMonth.add(s);
    }
    inMonth.sort(
      (a, b) =>
          _asDateTime(a['dateTime']).compareTo(_asDateTime(b['dateTime'])),
    );

    final Map<String, int> countByType = {};
    int passCount = 0;
    int failCount = 0;
    for (final s in inMonth) {
      final String type = s['type'] ?? '기타';
      countByType[type] = (countByType[type] ?? 0) + 1;
      if (s['inspectionResult'] == 'PASS') passCount++;
      if (s['inspectionResult'] == 'FAIL') failCount++;
    }

    final buffer = StringBuffer();
    buffer.writeln("📋 [${widget.projectName}] $year년 $month월 일정 요약");
    for (final entry in countByType.entries) {
      buffer.writeln("${entry.key}: ${entry.value}건");
    }
    if (passCount > 0 || failCount > 0) {
      buffer.writeln("검사 결과: 합격 $passCount건 / 불합격 $failCount건");
    }
    buffer.writeln();

    buffer.writeln("[상세]");
    for (final s in inMonth) {
      final DateTime dt = _asDateTime(s['dateTime']);
      final String label = s['title'] ?? s['type'] ?? '';
      final String dateStr =
          "${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}";
      String line = "$dateStr ${s['type'] ?? ''} - $label";
      if (s['isCompleted'] == true) {
        if (s['inspectionResult'] != null) {
          line += s['inspectionResult'] == 'FAIL' ? " (불합격)" : " (합격)";
        } else {
          line += " (완료)";
        }
      }
      buffer.writeln(line);
      final comment = s['inspectionComment']?.toString() ?? '';
      if (comment.isNotEmpty) buffer.writeln("   ↳ $comment");
    }

    if (undated.isNotEmpty) {
      buffer.writeln();
      buffer.writeln("입고일 미정 자재 요청: ${undated.length}건");
      for (final s in undated) {
        buffer.writeln("- ${s['title'] ?? s['type'] ?? ''}");
      }
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(keepWords("이번 달 일정 요약이 클립보드에 복사되었습니다.")),
        backgroundColor: tossBlue,
      ),
    );
  }

  // 🚀 [신규] 일정 달력 뷰. 작업 일지와 달리 이 화면의 일정은 dateTime에
  // 연도까지 정확히 들어있어서 실제 날짜 기준으로 정확히 그릴 수 있다.
  // 날짜가 아직 없는 "자재 요청"은 달력에 넣을 수 없어 아래 별도
  // 목록으로 보여준다.
  Widget _buildCalendarBody() {
    final int daysInMonth = DateTime(
      _calendarMonth.year,
      _calendarMonth.month + 1,
      0,
    ).day;
    final int leadingBlanks =
        DateTime(_calendarMonth.year, _calendarMonth.month, 1).weekday - 1;

    // 이 달에 해당하는(연/월 일치) 일정만 날짜별로 묶는다.
    final Map<int, List<Map<String, dynamic>>> byDay = {};
    final List<Map<String, dynamic>> undated = [];
    for (final s in _visibleSchedules) {
      if (s['dateTime'] == null) {
        undated.add(s);
        continue;
      }
      final DateTime dt = _asDateTime(s['dateTime']);
      if (dt.year == _calendarMonth.year && dt.month == _calendarMonth.month) {
        byDay.putIfAbsent(dt.day, () => []).add(s);
      }
    }

    Color dotColorFor(Map<String, dynamic> s) {
      if (s['isCompleted'] == true) return Colors.green;
      final DateTime dt = _asDateTime(s['dateTime']);
      return dt.isBefore(DateTime.now()) ? warningRed : tossBlue;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: pureWhite,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => setState(() {
                  _calendarMonth = DateTime(
                    _calendarMonth.year,
                    _calendarMonth.month - 1,
                  );
                }),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Text(
                "${_calendarMonth.year}년 ${_calendarMonth.month}월",
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: tossText,
                ),
              ),
              IconButton(
                onPressed: () => setState(() {
                  _calendarMonth = DateTime(
                    _calendarMonth.year,
                    _calendarMonth.month + 1,
                  );
                }),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: ["월", "화", "수", "목", "금", "토", "일"]
              .map(
                (d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: const TextStyle(
                        color: tossSubText,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
          ),
          itemCount: leadingBlanks + daysInMonth,
          itemBuilder: (context, index) {
            if (index < leadingBlanks) return const SizedBox.shrink();
            final int day = index - leadingBlanks + 1;
            final items = byDay[day] ?? const [];

            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: items.isEmpty ? null : () => _showDaySchedules(day, items),
              child: Container(
                decoration: BoxDecoration(
                  color: items.isNotEmpty
                      ? tossBlue.withValues(alpha: 0.08)
                      : pureWhite,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "$day",
                      style: TextStyle(
                        fontWeight: items.isNotEmpty
                            ? FontWeight.w800
                            : FontWeight.normal,
                        color: items.isNotEmpty ? tossText : tossSubText,
                        fontSize: 13,
                      ),
                    ),
                    if (items.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Wrap(
                          spacing: 2,
                          children: items
                              .take(3)
                              .map(
                                (s) => Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: dotColorFor(s),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        if (undated.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            "날짜 미정",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: tossSubText,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          ...undated.map(
            (s) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: pureWhite,
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: () => _showEditor(existing: s),
                child: Text(
                  s['title'] ?? s['type'] ?? '',
                  style: const TextStyle(
                    color: tossText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showDaySchedules(int day, List<Map<String, dynamic>> items) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        decoration: const BoxDecoration(
          color: pureWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${_calendarMonth.year}.${_calendarMonth.month.toString().padLeft(2, '0')}.${day.toString().padLeft(2, '0')}",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: tossText,
              ),
            ),
            const SizedBox(height: 16),
            ...items.map((item) {
              final bool isCompleted = item['isCompleted'] == true;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _toggleComplete(item);
                  },
                  child: Icon(
                    isCompleted
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: isCompleted ? Colors.green : tossBlue,
                  ),
                ),
                title: Text(
                  item['title'] ?? item['type'] ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: tossText,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                subtitle: Text(
                  item['type'] ?? '',
                  style: const TextStyle(color: tossSubText, fontSize: 12),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.edit_outlined, color: tossSubText),
                  onPressed: () {
                    Navigator.pop(context);
                    _showEditor(existing: item);
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
        backgroundColor: tossBg,
        appBar: AppBar(
          backgroundColor: pureWhite,
          foregroundColor: tossText,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "일정 관리",
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              Text(
                widget.projectName,
                style: const TextStyle(
                  fontSize: 12,
                  color: tossSubText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: _exportMonth,
              icon: const Icon(Icons.ios_share_rounded),
              tooltip: "이번 달 일정 요약 내보내기",
            ),
            IconButton(
              onPressed: () => setState(() => _showCalendar = !_showCalendar),
              icon: Icon(
                _showCalendar
                    ? Icons.view_list_rounded
                    : Icons.calendar_month_rounded,
              ),
              tooltip: _showCalendar ? "리스트로 보기" : "달력으로 보기",
            ),
          ],
        ),
        body: _showCalendar
            ? _buildCalendarBody()
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1줄: 종류 필터 + 완료 표시. 칩 배경이 화면 배경과 같아서
                        // 안 눌린 칩이 안 보이던 것을 흰색으로 고쳤다.
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ...["전체", "자재"].map((f) {
                                final bool selected = f == _filter;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(f == "자재" ? "자재 요청/입고일" : f),
                                    selected: selected,
                                    showCheckmark: false,
                                    selectedColor: const Color(0xFFD5E9EB),
                                    labelStyle: TextStyle(
                                      color: selected ? tossBlue : tossSubText,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    backgroundColor: pureWhite,
                                    side: BorderSide.none,
                                    onSelected: (_) =>
                                        setState(() => _filter = f),
                                  ),
                                );
                              }),
                              // 🚀 [추가] 완료된 일정 숨기기/보기 토글
                              FilterChip(
                                label: Text(_hideCompleted ? "완료 숨김" : "완료 표시"),
                                selected: !_hideCompleted,
                                showCheckmark: false,
                                avatar: Icon(
                                  _hideCompleted
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  size: 16,
                                  color: tossBlue,
                                ),
                                selectedColor: const Color(0xFFD5E9EB),
                                labelStyle: const TextStyle(
                                  color: tossBlue,
                                  fontWeight: FontWeight.bold,
                                ),
                                backgroundColor: pureWhite,
                                side: BorderSide.none,
                                onSelected: (v) =>
                                    setState(() => _hideCompleted = !v),
                              ),
                            ],
                          ),
                        ),
                        // 2줄: 단계 필터
                        if (widget.phases.isNotEmpty)
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children:
                                  [
                                    {'id': null, 'name': '전 단계'},
                                    ...widget.phases,
                                    {'id': '__none__', 'name': '단계 미지정'},
                                  ].map((p) {
                                    final bool selected =
                                        _phaseFilter == p['id']?.toString();
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ChoiceChip(
                                        label: Text(p['name'].toString()),
                                        selected: selected,
                                        showCheckmark: false,
                                        selectedColor: const Color(0xFFD5E9EB),
                                        labelStyle: TextStyle(
                                          color: selected
                                              ? tossBlue
                                              : tossSubText,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        backgroundColor: pureWhite,
                                        side: BorderSide.none,
                                        visualDensity: VisualDensity.compact,
                                        onSelected: (_) => setState(
                                          () => _phaseFilter = p['id']
                                              ?.toString(),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _visibleSchedules.isEmpty
                        ? Center(
                            child: Text(
                              _schedules.isNotEmpty && _hideCompleted
                                  ? "미완료 일정이 없습니다.\n(완료된 일정은 '완료 숨김'을 꺼서 볼 수 있습니다)"
                                  : _filter == "자재"
                                  ? "등록된 자재 요청/입고일이 없습니다."
                                  : "등록된 일정이 없습니다.\n자재 요청/입고일/납기일/검사일정을 등록해 두면\n시간에 맞춰 알림을 받을 수 있습니다.",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: tossSubText,
                                height: 1.5,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _visibleSchedules.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = _visibleSchedules[index];
                              // 🚀 "자재 요청"인데 아직 입고일을 모르면 dateTime이
                              // null이다 - 이 경우 날짜 관련 UI 대신 "요청한 지
                              // N일째 미정" 상태를 보여준다.
                              final DateTime? dt = item['dateTime'] == null
                                  ? null
                                  : _asDateTime(item['dateTime']);
                              final bool isCompleted =
                                  item['isCompleted'] == true;
                              final bool isPending = dt == null && !isCompleted;
                              final bool isOverdue =
                                  !isCompleted &&
                                  dt != null &&
                                  dt.isBefore(DateTime.now());

                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: pureWhite,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () => _toggleComplete(item),
                                      child: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isCompleted
                                              ? Colors.green.withValues(
                                                  alpha: 0.12,
                                                )
                                              : tossBlue.withValues(alpha: 0.1),
                                        ),
                                        child: Icon(
                                          isCompleted
                                              ? Icons.check_rounded
                                              : _iconForType(
                                                  item['type'] ?? '기타',
                                                ),
                                          color: isCompleted
                                              ? Colors.green
                                              : tossBlue,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  item['title'] ??
                                                      item['type'] ??
                                                      '',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 15,
                                                    color: isCompleted
                                                        ? tossSubText
                                                        : tossText,
                                                    decoration: isCompleted
                                                        ? TextDecoration
                                                              .lineThrough
                                                        : null,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            (dt != null
                                                    ? _formatDateTime(dt)
                                                    : _pendingRequestLabel(
                                                        item,
                                                      )) +
                                                (_phaseNameOf(item) != null
                                                    ? "  ·  ${_phaseNameOf(item)}"
                                                    : ''),
                                            style: TextStyle(
                                              color: isPending
                                                  ? warningRed
                                                  : tossSubText,
                                              fontSize: 12,
                                              fontWeight: isPending
                                                  ? FontWeight.w700
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                          if ((item['changeHistory'] as List?)
                                                  ?.isNotEmpty ==
                                              true) ...[
                                            const SizedBox(height: 4),
                                            InkWell(
                                              onTap: () =>
                                                  _showChangeHistory(item),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.history_rounded,
                                                    size: 13,
                                                    color: tossBlue,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    _lastChangeLabel(item),
                                                    style: const TextStyle(
                                                      color: tossBlue,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                          // 🚀 [추가] 이 검사일정에 연결된
                                          // 이슈 중 미해결 건수 - 검사 전에
                                          // 뭘 마저 처리해야 하는지 보여준다.
                                          if (!isCompleted &&
                                              _unresolvedIssueCount(item) >
                                                  0) ...[
                                            const SizedBox(height: 4),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.error_outline_rounded,
                                                  size: 13,
                                                  color: warningRed,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  keepWords(
                                                    "연결된 미해결 이슈 ${_unresolvedIssueCount(item)}건",
                                                  ),
                                                  style: const TextStyle(
                                                    color: warningRed,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                          // 🚀 [추가] 검사일정 완료 시 남긴 코멘트를
                                          // 함께 보여준다.
                                          if (isCompleted &&
                                              (item['inspectionComment']
                                                          as String?)
                                                      ?.isNotEmpty ==
                                                  true) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              "↳ ${item['inspectionComment']}",
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: tossSubText,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: pureWhite,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.black12,
                                            ),
                                          ),
                                          child: Text(
                                            isCompleted &&
                                                    item['inspectionResult'] !=
                                                        null
                                                ? (item['inspectionResult'] ==
                                                          'FAIL'
                                                      ? "❌ 불합격"
                                                      : "✅ 합격")
                                                : dt != null
                                                ? _relativeLabel(
                                                    dt,
                                                    isCompleted,
                                                  )
                                                : (isCompleted ? "완료됨" : "미정"),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: isCompleted
                                                  ? (item['inspectionResult'] ==
                                                            'FAIL'
                                                        ? warningRed
                                                        : tossSubText)
                                                  : (isOverdue || isPending
                                                        ? warningRed
                                                        : tossBlue),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () =>
                                              _showEditor(existing: item),
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            size: 18,
                                            color: tossSubText,
                                          ),
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.only(
                                            top: 6,
                                          ),
                                          splashRadius: 18,
                                        ),
                                      ],
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        HapticFeedback.lightImpact();
                                        _delete(item);
                                      },
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                        color: tossSubText,
                                      ),
                                      splashRadius: 18,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showEditor(),
          backgroundColor: tossBlue,
          icon: const Icon(Icons.add_rounded, color: pureWhite),
          label: const Text(
            "일정 추가",
            style: TextStyle(color: pureWhite, fontWeight: FontWeight.w700),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () =>
                    Navigator.pop(context, _changed ? _schedules : null),
                style: OutlinedButton.styleFrom(
                  foregroundColor: tossText,
                  side: const BorderSide(color: Colors.black12),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  "완료",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
