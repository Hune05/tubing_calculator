import 'package:flutter/material.dart';
import '../widgets/korean_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import '../widgets/photo_detail_modal.dart';
import '../models/photo_store.dart';
import '../models/project_phase.dart'
    show issueWeeklyExcluded, setIssueWeeklyExcluded;
import '../../../core/utils/image_picker_helper.dart' show ImagePickerHelper;
import 'floor_plan_pin_page.dart';

const Color makitaTeal = Color(0xFF007580);
const Color tossText = Color(0xFF191F28);
const Color tossSubText = Color(0xFF8B95A1);
const Color tossInputBg = Color(0xFFF2F4F6);
const Color pureWhite = Color(0xFFFFFFFF);
const Color warningRed = Color(0xFFF04438);

// 🚀 [신규] 이슈(펀치)를 탭하면 사진 모달 대신 여기로 들어온다.
// "언제 발생했고, 어떻게 처리했는지"를 명확히 남기기 위한 화면 -
// 등록 폼(punch_list_page.dart)의 UI는 그대로 두고, 조회/처리 전용으로
// 별도 페이지를 만들었다.
class PunchDetailPage extends StatefulWidget {
  final Map<String, dynamic> punch;
  // 🚀 이 프로젝트의 "검사일정" 타입 일정 목록 - 이슈를 검사일정에 연결해
  // 두면, 그 검사일이 임박/초과할 때 우선순위와 무관하게 더 자주 알림이
  // 오도록 서버에서 처리한다(functions/index.js의 checkPunchIssues 참고).
  final List<Map<String, dynamic>> inspectionSchedules;
  // 🚀 [추가] 이 이슈에 도면 위치 핀이 찍혀 있으면 보여주기 위한 도면
  // 이미지 경로 (프로젝트 단위로 하나 공유).
  final String? floorPlanImagePath;

  const PunchDetailPage({
    super.key,
    required this.punch,
    this.inspectionSchedules = const [],
    this.floorPlanImagePath,
  });

  @override
  State<PunchDetailPage> createState() => _PunchDetailPageState();
}

class _PunchDetailPageState extends State<PunchDetailPage> {
  late Map<String, dynamic> _punch;
  late TextEditingController _resolutionCtrl;
  // 처리 후 사진(처리 전/후 비교용)
  List<String> _afterImages = [];
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _punch = Map<String, dynamic>.from(widget.punch);
    _resolutionCtrl = TextEditingController(
      text: _punch['resolution_note'] ?? '',
    );
    _afterImages = ((_punch['resolution_images'] as List?) ?? [])
        .map((e) => e.toString())
        .toList();
  }

  Map<String, dynamic>? get _linkedSchedule {
    final String? id = _punch['linkedScheduleId'];
    if (id == null) return null;
    for (final s in widget.inspectionSchedules) {
      if (s['id'] == id) return s;
    }
    return null;
  }

  String _priorityCadenceLabel(dynamic priority) {
    switch (priority) {
      case '긴급':
        return '긴급 (하루 여러 번 알림)';
      case '여유':
        return '여유 (2~3일에 한 번 알림)';
      default:
        return '보통 (하루 한 번 알림)';
    }
  }

  @override
  void dispose() {
    _resolutionCtrl.dispose();
    super.dispose();
  }

  DateTime? _asDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    return DateTime.tryParse(v.toString());
  }

  String _formatDateTime(DateTime dt) {
    final ampm = dt.hour < 12 ? '오전' : '오후';
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    return "${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} $ampm $h:$m";
  }

  Future<void> _addAfterPhotos() async {
    final paths = await ImagePickerHelper.pickImages(
      context,
      maxCount: 6 - _afterImages.length,
    );
    if (paths.isNotEmpty) setState(() => _afterImages.addAll(paths));
  }

  Widget _afterThumbs({required bool editable}) {
    return SizedBox(
      height: 84,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (editable)
            InkWell(
              onTap: _addAfterPhotos,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 84,
                height: 84,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: tossInputBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_rounded, color: tossSubText),
                    SizedBox(height: 4),
                    Text(
                      "처리 후 사진",
                      style: TextStyle(color: tossSubText, fontSize: 10),
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
                      borderRadius: BorderRadius.circular(12),
                      child: PhotoImage(_afterImages[i], width: 84, height: 84),
                    ),
                  ),
                  if (editable)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => setState(() => _afterImages.removeAt(i)),
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
    );
  }

  void _markResolved() {
    setState(() {
      _punch['is_completed'] = true;
      _punch['resolution_images'] = List<String>.from(_afterImages);
      _punch['resolved_at'] = DateTime.now();
      _punch['resolution_note'] = _resolutionCtrl.text.trim().isEmpty
          ? "별도 메모 없음"
          : _resolutionCtrl.text.trim();
      _changed = true;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(keepWords("처리 완료로 저장했습니다."))));
  }

  void _reopen() {
    setState(() {
      _punch['is_completed'] = false;
      _punch['resolved_at'] = null;
      _changed = true;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(keepWords("미처리 상태로 되돌렸습니다."))));
  }

  @override
  Widget build(BuildContext context) {
    final DateTime? occurredAt = _asDateTime(_punch['created_at']);
    final DateTime? resolvedAt = _asDateTime(_punch['resolved_at']);
    final bool isCompleted = _punch['is_completed'] == true;
    final List<dynamic> imagePaths =
        _punch['image_paths'] ??
        (_punch['image_path'] != null ? [_punch['image_path']] : []);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
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
            onPressed: () => Navigator.pop(context, _changed ? _punch : null),
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
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상태 배지
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? Colors.green.withValues(alpha: 0.12)
                      : warningRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isCompleted
                          ? Icons.check_circle_rounded
                          : Icons.error_rounded,
                      size: 16,
                      color: isCompleted ? Colors.green : warningRed,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isCompleted ? "처리 완료" : "미처리",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: isCompleted ? Colors.green : warningRed,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _sectionCard(
                title: "발생 정보",
                children: [
                  _infoRow(
                    "발생 일시",
                    occurredAt != null ? _formatDateTime(occurredAt) : "기록 없음",
                  ),
                  _infoRow("위치", _punch['location'] ?? '위치 모름'),
                  _infoRow("결함 유형", _punch['defect_type'] ?? '-'),
                  _infoRow("우선순위", _priorityCadenceLabel(_punch['priority'])),
                  const SizedBox(height: 12),
                  Text(
                    _punch['content'] ?? '',
                    style: const TextStyle(
                      fontSize: 15,
                      color: tossText,
                      height: 1.5,
                    ),
                  ),
                  // 🚀 [추가] 도면 위 위치 핀 - 등록 시 찍어뒀으면 여기서
                  // 다시 보여준다.
                  if (widget.floorPlanImagePath != null &&
                      _punch['locationPinDx'] != null) ...[
                    const SizedBox(height: 12),
                    FloorPlanThumbnail(
                      imagePath: widget.floorPlanImagePath!,
                      dx: (_punch['locationPinDx'] as num).toDouble(),
                      dy: (_punch['locationPinDy'] as num).toDouble(),
                      height: 140,
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 16),
              _buildDeadlineSection(),
              const SizedBox(height: 16),
              _buildWeeklyToggle(),

              if (imagePaths.isNotEmpty) ...[
                const SizedBox(height: 16),
                _sectionCard(
                  title: "현장 사진",
                  children: [
                    SizedBox(
                      height: 80,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: imagePaths.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) => InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => PhotoDetailModal.show(
                            context: context,
                            title: "현장 사진",
                            content: _punch['content'] ?? '',
                            imagePaths: imagePaths,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: PhotoImage(
                              imagePaths[index].toString(),
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),

              // 처리 현황
              _sectionCard(
                title: "처리 현황",
                children: [
                  if (isCompleted) ...[
                    _infoRow(
                      "처리 일시",
                      resolvedAt != null
                          ? _formatDateTime(resolvedAt)
                          : "기록 없음",
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _punch['resolution_note'] ?? '',
                      style: const TextStyle(
                        fontSize: 15,
                        color: tossText,
                        height: 1.5,
                      ),
                    ),
                    if (_afterImages.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _afterThumbs(editable: false),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _reopen,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: tossSubText,
                          side: const BorderSide(color: Colors.black12),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          "다시 미처리로 되돌리기",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ] else ...[
                    Text(
                      keepWords("어떻게 처리했는지 남겨 두면, 나중에 확인할 때 편합니다."),
                      style: TextStyle(color: tossSubText, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _resolutionCtrl,
                      maxLines: 3,
                      style: const TextStyle(color: tossText),
                      decoration: InputDecoration(
                        hintText: "예: 재시공하여 치수 재조정 완료",
                        hintStyle: const TextStyle(color: Color(0xFFB0B8C1)),
                        filled: true,
                        fillColor: tossInputBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _afterThumbs(editable: true),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _markResolved,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: makitaTeal,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🚀 [신규] "보통 검사 전까지 처리" 같은 관행을 반영 - 이슈를 일정
  // 관리에 등록된 검사일정(예: 파이널 검사)에 연결해두면, 그 날짜가
  // 처리 기한이 되고 임박/초과 시 알림이 더 자주 온다.
  Widget _buildDeadlineSection() {
    final schedule = _linkedSchedule;

    if (schedule != null) {
      final DateTime? dt = _asDateTime(schedule['dateTime']);
      final String label = schedule['title'] ?? schedule['type'] ?? '검사일정';
      final bool isPast = dt != null && dt.isBefore(DateTime.now());
      return _sectionCard(
        title: "처리 기한",
        children: [
          Row(
            children: [
              Icon(
                Icons.event_available_rounded,
                size: 18,
                color: isPast ? warningRed : makitaTeal,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dt != null ? "$label · ${_formatDateTime(dt)}" : label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isPast ? warningRed : tossText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              setState(() {
                _punch['linkedScheduleId'] = null;
                _changed = true;
              });
            },
            style: TextButton.styleFrom(
              foregroundColor: tossSubText,
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text("연결 해제", style: TextStyle(fontSize: 13)),
          ),
        ],
      );
    }

    // 🚀 검사일정에 연결돼있지 않아도, 등록할 때 직접 정한 처리 기한
    // (dueDate)이 있으면 그걸 보여준다.
    final DateTime? dueDate = _asDateTime(_punch['dueDate']);
    if (dueDate != null) {
      final bool isPast = dueDate.isBefore(DateTime.now());
      return _sectionCard(
        title: "처리 기한",
        children: [
          Row(
            children: [
              Icon(
                Icons.event_rounded,
                size: 18,
                color: isPast ? warningRed : makitaTeal,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _formatDateTime(dueDate),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isPast ? warningRed : tossText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              setState(() {
                _punch['dueDate'] = null;
                _changed = true;
              });
            },
            style: TextButton.styleFrom(
              foregroundColor: tossSubText,
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text("기한 해제", style: TextStyle(fontSize: 13)),
          ),
        ],
      );
    }

    if (widget.inspectionSchedules.isEmpty) {
      return _sectionCard(
        title: "처리 기한",
        children: [
          Text(
            keepWords(
              "등록된 검사일정이 없습니다. \"일정 관리\"에서 검사일정을 등록하면 이 이슈와 연결해 기한을 관리할 수 있습니다.",
            ),
            style: TextStyle(color: tossSubText, fontSize: 13, height: 1.4),
          ),
        ],
      );
    }

    return _sectionCard(
      title: "처리 기한",
      children: [
        Text(
          keepWords("이 이슈를 검사일정에 연결하면, 그 날짜까지가 처리 기한이 됩니다."),
          style: TextStyle(color: tossSubText, fontSize: 13),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.inspectionSchedules.map((s) {
            final DateTime? dt = _asDateTime(s['dateTime']);
            final String label = s['title'] ?? s['type'] ?? '검사일정';
            return ActionChip(
              backgroundColor: tossInputBg,
              side: BorderSide.none,
              label: Text(
                dt != null ? "$label (${dt.month}/${dt.day})" : label,
                style: const TextStyle(
                  color: tossText,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              onPressed: () {
                setState(() {
                  _punch['linkedScheduleId'] = s['id'];
                  _changed = true;
                });
              },
            );
          }).toList(),
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
            "주간 업무 보고에 포함",
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          subtitle: Text(
            keepWords("끄면 주간 보고의 미해결 이슈 현황과 통계에서 빠집니다."),
            style: TextStyle(fontSize: 12, color: tossSubText),
          ),
          value: include,
          onChanged: (v) {
            setState(() {
              setIssueWeeklyExcluded(_punch, !v);
              _changed = true;
            });
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(v ? "주간 보고에 포함했습니다." : "주간 보고에서 뺐습니다."),
                  persist: false,
                  action: SnackBarAction(
                    label: "되돌리기",
                    onPressed: () {
                      if (!mounted) return;
                      // 바꾸기 전 상태(제외 여부 = v)로 되돌린다.
                      setState(() {
                        setIssueWeeklyExcluded(_punch, v);
                        _changed = true;
                      });
                    },
                  ),
                ),
              );
          },
        ),
      ],
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(16),
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

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(color: tossSubText, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: tossText,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
