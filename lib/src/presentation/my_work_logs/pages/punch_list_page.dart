import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/utils/image_picker_helper.dart'; // 🚀 경로 확인 필수!
import '../widgets/photo_detail_modal.dart';
import 'floor_plan_pin_page.dart';

const Color tossText = Color(0xFF191F28);
const Color tossSubText = Color(0xFF8B95A1);
const Color tossInputBg = Color(0xFFF2F4F6);
const Color pureWhite = Color(0xFFFFFFFF);
const Color warningRed = Color(0xFFF04438);
const Color makitaTeal = Color(0xFF007580);

class PunchListPage extends StatefulWidget {
  // 🚀 [추가] 같은 프로젝트에서 최근에 썼던 위치들 - 매번 타이핑하지
  // 않고 칩으로 골라 채울 수 있게 한다.
  final List<String> recentLocations;
  // 🚀 [추가] 이 프로젝트에 이미 등록된 도면(카톡 등으로 받은 실제 배치도
  // 사진) 경로 - 있으면 위치를 텍스트 대신 도면 위 핀으로 찍을 수 있다.
  final String? floorPlanImagePath;

  const PunchListPage({
    super.key,
    this.recentLocations = const [],
    this.floorPlanImagePath,
  });

  @override
  State<PunchListPage> createState() => _PunchListPageState();
}

class _PunchListPageState extends State<PunchListPage> {
  final TextEditingController _locationCtrl = TextEditingController();
  final TextEditingController _punchCtrl = TextEditingController();
  final List<String> _attachedImages = [];

  // 상태값
  String _selectedDefect = '치수/각도 불량';
  // 🚀 결함 유형에 전기/계장 관련 펀치(결선 불량, 라벨 누락) 추가
  final List<String> _defectTypes = [
    '치수/각도 불량',
    '누수/손상',
    '결선/단선 불량',
    '라벨/마킹 누락',
    '오작/간섭',
    '미시공',
    '자재 부족', // 🚀 [추가] 자재가 부족해서 진행이 막히는 것도 이슈로 등록
    '기타',
  ];

  // 🚀 [추가] 결함 유형을 고르면 그에 맞는 우선순위를 미리 채워준다 -
  // 급한 걸 깜빡하고 "보통"으로 등록하는 실수를 줄이기 위함. 사용자가
  // 직접 우선순위를 한 번 만지면(_priorityTouched) 그 뒤로는 자동으로
  // 덮어쓰지 않는다.
  static const Map<String, String> _suggestedPriority = {
    '결선/단선 불량': '긴급',
    '누수/손상': '긴급',
    '미시공': '긴급',
    '자재 부족': '긴급', // 🚀 자재 부족은 작업 자체가 막히므로 긴급으로 제안
    '치수/각도 불량': '보통',
    '오작/간섭': '보통',
    '라벨/마킹 누락': '여유',
  };
  bool _priorityTouched = false;

  String _selectedPriority = '보통';
  final List<String> _priorities = ['긴급', '보통', '여유'];

  // 🚀 [추가] 등록 시점에 바로 처리 기한을 정할 수 있게 - 우선순위별
  // 알림 주기보다 구체적인 기한이 필요할 때 쓴다. 옵션 이름과 실제
  // 날짜를 분리해서, "3일 내" 같은 상대 옵션이 렌더링마다 다시 계산돼
  // 선택 표시가 어긋나는 걸 막는다.
  String _dueDateOption = "기한 없음";
  DateTime? _customDueDate;

  // 🚀 [추가] 도면 위 위치 핀
  String? _floorPlanImagePath;
  double? _pinDx;
  double? _pinDy;
  // 이번 등록에서 도면을 새로 고른 경우, 프로젝트에 저장해야 하므로
  // 별도로 기억해둔다 (기존에 있던 도면을 그대로 쓴 경우는 null).
  String? _newFloorPlanPath;

  @override
  void initState() {
    super.initState();
    _floorPlanImagePath = widget.floorPlanImagePath;
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    _punchCtrl.dispose();
    super.dispose();
  }

  void _selectDefect(String type) {
    setState(() {
      _selectedDefect = type;
      if (!_priorityTouched && _suggestedPriority.containsKey(type)) {
        _selectedPriority = _suggestedPriority[type]!;
      }
    });
  }

  void _selectPriority(String p) {
    setState(() {
      _selectedPriority = p;
      _priorityTouched = true;
    });
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _customDueDate ?? DateTime.now().add(const Duration(days: 3)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _dueDateOption = "직접 지정";
        _customDueDate = picked;
      });
    }
  }

  // 🚀 선택된 옵션을 실제 DateTime으로 환산 (제출 시점에 계산).
  DateTime? get _resolvedDueDate {
    switch (_dueDateOption) {
      case "3일 내":
        return DateTime.now().add(const Duration(days: 3));
      case "1주일 내":
        return DateTime.now().add(const Duration(days: 7));
      case "직접 지정":
        return _customDueDate;
      default:
        return null;
    }
  }

  Future<void> _pickFloorPlanImage() async {
    final path = await ImagePickerHelper.pickImage(context);
    if (path == null) return;
    setState(() {
      _floorPlanImagePath = path;
      _newFloorPlanPath = path;
      _pinDx = null;
      _pinDy = null;
    });
    if (!mounted) return;
    await _openPinPicker();
  }

  Future<void> _openPinPicker() async {
    if (_floorPlanImagePath == null) return;
    final result = await Navigator.push<Offset>(
      context,
      MaterialPageRoute(
        builder: (context) => FloorPlanPinPage(
          imagePath: _floorPlanImagePath!,
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

  void _submit() {
    String locValue = _locationCtrl.text.trim();
    String textValue = _punchCtrl.text.trim();

    if (textValue.isEmpty && _attachedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("결함 내용이나 사진을 최소 1장 첨부해주세요."),
          backgroundColor: warningRed,
        ),
      );
      return;
    }

    final newPunch = {
      "location": locValue.isEmpty ? "위치 미상" : locValue,
      "defect_type": _selectedDefect,
      "priority": _selectedPriority,
      "content": textValue.isEmpty ? "내용 없음 (사진 참조)" : textValue,
      "is_completed": false,
      "has_image": _attachedImages.isNotEmpty,
      "image_path": _attachedImages.isNotEmpty ? _attachedImages.first : null,
      "image_paths": List.from(_attachedImages),
      // 🚀 [추가] 등록 시점에 바로 정한 처리 기한.
      "dueDate": _resolvedDueDate,
      // 🚀 [추가] 도면 위 위치 핀 (프로젝트 도면 기준 0~1 비율 좌표).
      "locationPinDx": _pinDx,
      "locationPinDy": _pinDy,
      // 🚀 이번에 새로 고른 도면이면 프로젝트에 저장해야 한다는 신호.
      // work_log_main_screen.dart에서 이 키를 보고 처리한 뒤 제거한다.
      if (_newFloorPlanPath != null) "__newFloorPlanPath": _newFloorPlanPath,
    };

    Navigator.pop(context, newPunch);
  }

  Widget _buildChoiceChip(
    String label,
    String currentValue,
    Function(String) onSelect, {
    bool isWarning = false,
  }) {
    bool isSelected = label == currentValue;
    Color activeColor = isWarning && label == '긴급'
        ? warningRed
        : (isWarning ? tossText : Colors.orange.shade600);

    return GestureDetector(
      onTap: () => onSelect(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : tossInputBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? pureWhite : tossSubText,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 14,
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
        title: const Text(
          "이슈 등록",
          style: TextStyle(
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
              // 1. 위치 및 태그
              const Text(
                "발생 위치 및 태그",
                style: TextStyle(
                  color: tossText,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _locationCtrl,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: tossText,
                ),
                decoration: InputDecoration(
                  hintText: "예: 2층 A구역 또는 P&ID Tag 번호",
                  hintStyle: const TextStyle(
                    color: Color(0xFFB0B8C1),
                    fontWeight: FontWeight.normal,
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
              // 🚀 [추가] 최근 사용 위치 - 탭 한 번으로 채우기
              if (widget.recentLocations.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.recentLocations.map((loc) {
                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(() => _locationCtrl.text = loc),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: tossInputBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          loc,
                          style: const TextStyle(
                            color: tossSubText,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              // 🚀 [추가] 도면 위 위치 핀 - 텍스트 위치 대신(또는 함께)
              // 실제 배치도 사진 위에 정확한 지점을 찍어둘 수 있다.
              const SizedBox(height: 16),
              if (_floorPlanImagePath == null)
                InkWell(
                  onTap: _pickFloorPlanImage,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: tossInputBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.map_outlined, color: tossSubText, size: 20),
                        SizedBox(width: 10),
                        Text(
                          "도면 불러와서 위치 찍기 (선택)",
                          style: TextStyle(
                            color: tossSubText,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FloorPlanThumbnail(
                      imagePath: _floorPlanImagePath!,
                      dx: _pinDx,
                      dy: _pinDy,
                      onTap: _openPinPicker,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: _openPinPicker,
                          icon: const Icon(Icons.push_pin_outlined, size: 16),
                          label: Text(_pinDx == null ? "위치 찍기" : "위치 다시 찍기"),
                          style: TextButton.styleFrom(
                            foregroundColor: makitaTeal,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: _pickFloorPlanImage,
                          icon: const Icon(Icons.image_outlined, size: 16),
                          label: const Text("다른 도면 선택"),
                          style: TextButton.styleFrom(
                            foregroundColor: tossSubText,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              const SizedBox(height: 32),

              // 2. 결함 유형 선택
              const Text(
                "결함 유형",
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
                children: _defectTypes
                    .map(
                      (type) => _buildChoiceChip(
                        type,
                        _selectedDefect,
                        _selectDefect,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 32),

              // 3. 우선순위 선택
              const Text(
                "처리 우선순위",
                style: TextStyle(
                  color: tossText,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: _priorities
                    .map(
                      (p) => _buildChoiceChip(
                        p,
                        _selectedPriority,
                        _selectPriority,
                        isWarning: true,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 32),

              // 🚀 [추가] 처리 기한 직접 지정
              const Text(
                "처리 기한 (선택)",
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
                children: [
                  _buildChoiceChip(
                    "기한 없음",
                    _dueDateOption,
                    (_) => setState(() {
                      _dueDateOption = "기한 없음";
                      _customDueDate = null;
                    }),
                  ),
                  _buildChoiceChip(
                    "3일 내",
                    _dueDateOption,
                    (_) => setState(() => _dueDateOption = "3일 내"),
                  ),
                  _buildChoiceChip(
                    "1주일 내",
                    _dueDateOption,
                    (_) => setState(() => _dueDateOption = "1주일 내"),
                  ),
                  InkWell(
                    onTap: _pickDueDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _dueDateOption == "직접 지정"
                            ? tossText
                            : tossInputBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _dueDateOption == "직접 지정" && _customDueDate != null
                            ? "${_customDueDate!.month}/${_customDueDate!.day}까지"
                            : "직접 지정",
                        style: TextStyle(
                          color: _dueDateOption == "직접 지정"
                              ? pureWhite
                              : tossSubText,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // 4. 상세 내용
              const Text(
                "상세 보완 내용",
                style: TextStyle(
                  color: tossText,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _punchCtrl,
                maxLines: 4,
                style: const TextStyle(
                  fontSize: 15,
                  color: tossText,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText:
                      "어떤 부분을 어떻게 수정해야 하는지 상세히 적어주세요.\n(예: 센서 극성 오결선, 트레이싱 단선 등)",
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

              // 5. 사진 첨부
              const Text(
                "현장 사진 (최대 5장)",
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
                              Icons.add_a_photo_rounded,
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
                              // 🚀 [추가] 삭제만 되던 걸 고쳐서, 눌렀을 때
                              // 크게(줌 가능) 볼 수 있게 했다.
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
                backgroundColor: warningRed,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _submit,
              child: const Text(
                "이슈 등록하기",
                style: TextStyle(
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
