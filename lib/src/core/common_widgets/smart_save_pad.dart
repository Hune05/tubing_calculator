import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:tubing_calculator/src/core/database/database_helper.dart';
import 'package:tubing_calculator/src/core/utils/app_settings_controller.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';
import 'package:tubing_calculator/src/data/tube_drawing_specs.dart';

const Color makitaTeal = AppColors.brand;
const Color _slate900 = AppColors.text;
const Color _slate600 = AppColors.textSub;
const Color _slate100 = AppColors.background;
const Color _pureWhite = Color(0xFFFFFFFF);

class SmartSavePad extends StatefulWidget {
  final double totalCut;
  final List<dynamic> bendList;
  final bool includeStart;
  final bool includeEnd;
  final double tailLength;
  final String startDir;

  // 🚀 프로젝트 관리(자재 누적)로 쏠 콜백 함수
  final Function(double totalCut, List<Map<String, dynamic>> fittings)?
  onSaveCallback;

  const SmartSavePad({
    super.key,
    required this.totalCut,
    required this.bendList,
    required this.includeStart,
    required this.includeEnd,
    required this.tailLength,
    required this.startDir,
    this.onSaveCallback,
  });

  @override
  State<SmartSavePad> createState() => _SmartSavePadState();
}

class _SmartSavePadState extends State<SmartSavePad> {
  String _selectedSize = '1/2"';

  final TextEditingController _projectController = TextEditingController();
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  final List<String> _inchSizes = [
    '1/4"',
    '5/16"',
    '3/8"',
    '1/2"',
    '5/8"',
    '3/4"',
    '7/8"',
    '1"',
  ];
  final List<String> _mmSizes = ['8mm', '10mm', '12mm', '20mm', '25mm'];

  @override
  void initState() {
    super.initState();
    // 🚀 [고침] 예전에는 늘 1/2"로 저장됐다. 설정의 관 크기를 먼저 고른다.
    final s = AppSettingsController();
    if (s.tubeOD > 0) {
      final odMm = s.isInch ? s.tubeOD * 25.4 : s.tubeOD;
      final chip = sizeChipForOd(odMm, [..._inchSizes, ..._mmSizes]);
      if (chip != null) {
        _selectedSize = chip;
      } else {
        // 목록에 없는 크기(6mm 등)는 칩을 하나 더 만든다.
        String n(double v) =>
            v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
        _selectedSize = s.isInch ? '${n(s.tubeOD)}"' : '${n(s.tubeOD)}mm';
        (s.isInch ? _inchSizes : _mmSizes).insert(0, _selectedSize);
      }
    }
  }

  @override
  void dispose() {
    _projectController.dispose();
    _fromController.dispose();
    _toController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // 흰 배경·회색 채움·청록 강조 — 앱 나머지 화면(app_dialog.dart의
  // appFieldDecoration)과 같은 톤으로(2026-09-28, 예전엔 이 창만 어두운
  // 바탕에 노란 강조라 폰 색감과 안 맞았다).
  Widget _buildFieldInput(
    String label,
    TextEditingController controller, {
    IconData? icon,
    TextInputAction action = TextInputAction.next,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      textInputAction: action,
      maxLines: maxLines,
      style: const TextStyle(
        color: _slate900,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _slate600, fontSize: 13),
        alignLabelWithHint: maxLines > 1,
        prefixIcon: icon != null
            ? Icon(icon, color: _slate600.withValues(alpha: 0.6), size: 18)
            : null,
        filled: true,
        fillColor: _slate100,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: makitaTeal, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildSizeChip(String size) {
    bool isSel = _selectedSize == size;
    return ChoiceChip(
      label: Text(size),
      selected: isSel,
      selectedColor: makitaTeal,
      backgroundColor: _slate100,
      showCheckmark: false,
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      labelStyle: TextStyle(
        color: isSel ? _pureWhite : _slate600,
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
      onSelected: (v) => setState(() => _selectedSize = size),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20,
        right: 20,
        top: 24,
      ),
      decoration: const BoxDecoration(
        color: _pureWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "보관함에 저장",
              style: TextStyle(
                color: _slate900,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildFieldInput(
              "프로젝트 이름 (예: A동 보일러실)",
              _projectController,
              icon: Icons.business,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildFieldInput(
                    "From (시작점)",
                    _fromController,
                    icon: Icons.login,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.arrow_forward_rounded, color: _slate600),
                ),
                Expanded(
                  child: _buildFieldInput(
                    "To (도착점)",
                    _toController,
                    icon: Icons.logout,
                    action: TextInputAction.done,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildFieldInput(
              "무엇을 했는지 (메모, 선택)",
              _noteController,
              icon: Icons.edit_note,
              action: TextInputAction.done,
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            const Text(
              "튜브 규격 (inch)",
              style: TextStyle(
                color: _slate600,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6.0,
              runSpacing: 6.0,
              children: _inchSizes.map((size) => _buildSizeChip(size)).toList(),
            ),
            const SizedBox(height: 16),
            const Text(
              "튜브 규격 (mm)",
              style: TextStyle(
                color: _slate600,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6.0,
              runSpacing: 6.0,
              children: _mmSizes.map((size) => _buildSizeChip(size)).toList(),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: makitaTeal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  Map<String, dynamic> pToPData = {
                    "project": _projectController.text.isEmpty
                        ? "프로젝트 미지정"
                        : _projectController.text,
                    "from": _fromController.text.isEmpty
                        ? "모름"
                        : _fromController.text,
                    "to": _toController.text.isEmpty
                        ? "모름"
                        : _toController.text,
                    "start_fit": widget.includeStart,
                    "end_fit": widget.includeEnd,
                    "tail": widget.tailLength,
                    "start_dir": widget.startDir,
                    // 무엇을 했는지 짧은 메모 — 빠른 실행 "작업 히스토리"에도 그대로 보여준다.
                    "note": _noteController.text,
                    // 다시 열 때 같은 값으로 마킹을 셈하도록 장비 값을 남긴다.
                    kTubeDrawingSpecsKey: tubeSpecsSnapshot(MachineSpecs()),
                  };

                  // 1. 비동기 작업 대기 (DB 저장)
                  await DatabaseHelper.instance.insertHistory({
                    'date': DateTime.now().toString().substring(0, 16),
                    'p_to_p': jsonEncode(pToPData),
                    'pipe_size': _selectedSize,
                    'total_length': widget.totalCut,
                    'bend_data': jsonEncode(widget.bendList),
                  });

                  // 2. 콜백 실행 (동기 작업)
                  if (widget.onSaveCallback != null) {
                    List<Map<String, dynamic>> usedFittings = [];

                    if (widget.includeStart) {
                      usedFittings.add({
                        'db_name': '[SWAGELOK] $_selectedSize Union (Start)',
                        'maker': 'SWAGELOK',
                        'spec': _selectedSize,
                        'name': 'Union',
                        'qty': 1,
                      });
                    }
                    if (widget.includeEnd) {
                      usedFittings.add({
                        'db_name': '[SWAGELOK] $_selectedSize Union (End)',
                        'maker': 'SWAGELOK',
                        'spec': _selectedSize,
                        'name': 'Union',
                        'qty': 1,
                      });
                    }

                    widget.onSaveCallback!(widget.totalCut, usedFittings);
                  }

                  // 🚀 3. 비동기/콜백 처리가 모두 끝난 후 UI 조작 전 반드시 체크!
                  if (!context.mounted) return;

                  // 4. 안전하게 UI 조작 (경고 100% 소멸)
                  Navigator.pop(context);

                  // 프로젝트에 연결해 저장할 때(콜백이 있을 때)만 프로젝트 자재에도 들어간다.
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        widget.onSaveCallback != null
                            ? "보관함과 프로젝트 자재에 저장했습니다."
                            : "보관함에 저장했습니다.",
                      ),
                      backgroundColor: makitaTeal,
                    ),
                  );
                },
                child: const Text(
                  "저장",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _pureWhite,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
