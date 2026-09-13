import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

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

  const ProjectSchedulePage({
    super.key,
    required this.projectName,
    required this.initialSchedules,
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

  List<Map<String, dynamic>> get _visibleSchedules {
    if (_filter == "자재") {
      return _schedules
          .where((s) => _materialTypes.contains(s['type']))
          .toList();
    }
    return _schedules;
  }

  @override
  void initState() {
    super.initState();
    _schedules = widget.initialSchedules
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    _sort();
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
        : (type == "자재 요청" ? null : DateTime.now().add(const Duration(days: 1)));

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
                            selectedColor: tossBlue.withValues(alpha: 0.15),
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
                          final DateTime base = dateTime ?? DateTime.now();
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
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(base),
                          );
                          setModalState(() {
                            dateTime = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime?.hour ?? 9,
                              pickedTime?.minute ?? 0,
                            );
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            "아직 모름으로 되돌리기",
                            style: TextStyle(fontSize: 13),
                          ),
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
                      const SizedBox(height: 20),
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
                              'note': noteCtrl.text.trim(),
                              'isCompleted': existing?['isCompleted'] ?? false,
                              // 🚀 입고일을 아직 모르는 "자재 요청"이 "발주한
                              // 지 며칠째"를 알려줄 수 있도록 최초 등록
                              // 시각을 남겨둔다 (수정해도 값은 유지).
                              'requestedAt': existing?['requestedAt'] ??
                                  DateTime.now(),
                              // 🚀 시간/종류가 바뀔 수 있으니 저장할 때마다
                              // 알림 발송 플래그를 초기화해서, 새 시각
                              // 기준으로 다시 알림이 잡히게 한다.
                              'reminderSent': false,
                              'lastOverdueReminderDate': null,
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

  void _toggleComplete(Map<String, dynamic> item) {
    setState(() {
      item['isCompleted'] = !(item['isCompleted'] == true);
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
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: ["전체", "자재"].map((f) {
                  final bool selected = f == _filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f == "자재" ? "자재 요청/입고일만" : f),
                      selected: selected,
                      selectedColor: tossBlue.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        color: selected ? tossBlue : tossSubText,
                        fontWeight: FontWeight.bold,
                      ),
                      backgroundColor: tossBg,
                      side: BorderSide.none,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  );
                }).toList(),
              ),
            ),
            Expanded(
              child: _visibleSchedules.isEmpty
                  ? Center(
                      child: Text(
                        _filter == "자재"
                            ? "등록된 자재 요청/입고일이 없습니다."
                            : "등록된 일정이 없습니다.\n자재 요청/입고일/납기일/검사일정을 등록해두면\n시간에 맞춰 알림을 받을 수 있어요.",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: tossSubText, height: 1.5),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _visibleSchedules.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = _visibleSchedules[index];
                        // 🚀 "자재 요청"인데 아직 입고일을 모르면 dateTime이
                        // null이다 - 이 경우 날짜 관련 UI 대신 "요청한 지
                        // N일째 미정" 상태를 보여준다.
                        final DateTime? dt = item['dateTime'] == null
                            ? null
                            : _asDateTime(item['dateTime']);
                        final bool isCompleted = item['isCompleted'] == true;
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
                                        ? Colors.green.withValues(alpha: 0.12)
                                        : tossBlue.withValues(alpha: 0.1),
                                  ),
                                  child: Icon(
                                    isCompleted
                                        ? Icons.check_rounded
                                        : _iconForType(item['type'] ?? '기타'),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            item['title'] ?? item['type'] ?? '',
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                              color: isCompleted
                                                  ? tossSubText
                                                  : tossText,
                                              decoration: isCompleted
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      dt != null
                                          ? _formatDateTime(dt)
                                          : _pendingRequestLabel(item),
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
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    dt != null
                                        ? _relativeLabel(dt, isCompleted)
                                        : (isCompleted ? "완료됨" : "미정"),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isCompleted
                                          ? tossSubText
                                          : (isOverdue || isPending
                                                ? warningRed
                                                : tossBlue),
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
                                    padding: const EdgeInsets.only(top: 6),
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
