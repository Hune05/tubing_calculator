import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/utils/image_picker_helper.dart'; // 🚀 경로 확인 필수!

const Color tossText = Color(0xFF191F28);
const Color tossSubText = Color(0xFF8B95A1);
const Color tossInputBg = Color(0xFFF2F4F6);
const Color pureWhite = Color(0xFFFFFFFF);
const Color warningRed = Color(0xFFF04438);

class PunchListPage extends StatefulWidget {
  const PunchListPage({super.key});

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
    '기타',
  ];

  String _selectedPriority = '보통';
  final List<String> _priorities = ['긴급', '보통', '여유'];

  @override
  void dispose() {
    _locationCtrl.dispose();
    _punchCtrl.dispose();
    super.dispose();
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
          "펀치 리스트(하자) 추가",
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
                        (val) => setState(() => _selectedDefect = val),
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
                        (val) => setState(() => _selectedPriority = val),
                        isWarning: true,
                      ),
                    )
                    .toList(),
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
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                File(entry.value),
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
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
                "펀치 등록하기",
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
