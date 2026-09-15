import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart'; // 🚀 HapticFeedback을 위해 추가
import '../../../core/utils/image_picker_helper.dart';

// 🚀 [추가] 방금 만든 배치도 페이지 임포트
import 'layout_board_page.dart';
import 'tablet_layout_board_page.dart';
import '../widgets/photo_detail_modal.dart';

const Color tossBlue = Color(0xFF3182F6);
const Color tossText = Color(0xFF191F28);
const Color tossSubText = Color(0xFF8B95A1);
const Color tossInputBg = Color(0xFFF2F4F6);
const Color pureWhite = Color(0xFFFFFFFF);

class DailyReportPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;

  const DailyReportPage({super.key, this.existingData});

  @override
  State<DailyReportPage> createState() => _DailyReportPageState();
}

class _DailyReportPageState extends State<DailyReportPage> {
  late TextEditingController _pointCtrl;
  late TextEditingController _wiringPointCtrl;
  late TextEditingController _noteCtrl;
  late TextEditingController _asBuiltCtrl;

  String _selectedWorkType = '신규 설치';
  final List<String> _workTypes = [
    '신규 설치',
    '라인 수정',
    '결선/트레이싱',
    '철거/교체',
    '검사/테스트',
  ];
  int _workerCount = 1;
  bool _isOvertime = false;

  bool _isAsBuilt = false;
  List<String> _attachedImages = [];
  late bool _isEdit;

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

    if (_isEdit) {
      _isAsBuilt = widget.existingData!['is_as_built'] ?? false;
      _selectedWorkType = widget.existingData!['work_type'] ?? '신규 설치';
      _workerCount = widget.existingData!['worker_count'] ?? 1;
      _isOvertime = widget.existingData!['is_overtime'] ?? false;

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
    super.dispose();
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
      "work_type": _selectedWorkType,
      "worker_count": _workerCount,
      "is_overtime": _isOvertime,
      "points": int.tryParse(ptText) ?? 0,
      "wiring_points": int.tryParse(wpText) ?? 0,
      "note": ntText.isEmpty ? "특이사항 없음" : ntText,
      "is_as_built": _isAsBuilt,
      "as_built_reason": _isAsBuilt ? _asBuiltCtrl.text.trim() : "",
      "has_image": _attachedImages.isNotEmpty,
      "image_path": _attachedImages.isNotEmpty ? _attachedImages.first : null,
      "image_paths": List.from(_attachedImages),
      "editHistory": editHistory,
    };

    if (!mounted) return;
    Navigator.pop(context, newReport);
  }

  Widget _buildChoiceChip(
    String label,
    String currentValue,
    Function(String) onSelect,
  ) {
    bool isSelected = label == currentValue;
    return GestureDetector(
      onTap: () => onSelect(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? tossBlue : tossInputBg,
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
              // 1. 작업 유형 선택
              const Text(
                "작업 유형",
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
                children: _workTypes
                    .map(
                      (type) => _buildChoiceChip(
                        type,
                        _selectedWorkType,
                        (val) => setState(() => _selectedWorkType = val),
                      ),
                    )
                    .toList(),
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
