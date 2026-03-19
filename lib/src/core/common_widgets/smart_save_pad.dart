import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:tubing_calculator/src/core/database/database_helper.dart';

const Color makitaTeal = Color(0xFF007580);

class SmartSavePad extends StatefulWidget {
  final double totalCut;
  final List<dynamic> bendList;
  final bool includeStart;
  final bool includeEnd;
  final double tailLength;
  final String startDir;

  // 🚀 [추가] 프로젝트 관리(자재 누적)로 쏠 콜백 함수
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
    this.onSaveCallback, // 🚀 [추가]
  });

  @override
  State<SmartSavePad> createState() => _SmartSavePadState();
}

class _SmartSavePadState extends State<SmartSavePad> {
  String _selectedSize = '1/2"';

  final TextEditingController _projectController = TextEditingController();
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();

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
  void dispose() {
    _projectController.dispose();
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  Widget _buildFieldInput(
    String label,
    TextEditingController controller, {
    IconData? icon,
    TextInputAction action = TextInputAction.next,
  }) {
    return TextField(
      controller: controller,
      textInputAction: action,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
        prefixIcon: icon != null
            ? Icon(icon, color: Colors.white38, size: 18)
            : null,
        filled: true,
        fillColor: Colors.black45,
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
          borderSide: const BorderSide(color: makitaTeal),
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
      backgroundColor: Colors.black45,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      labelStyle: TextStyle(
        color: isSel ? Colors.white : Colors.white54,
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
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white24),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "작업 도면 저장",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildFieldInput(
              "프로젝트 네임 (예: A동 보일러실)",
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
                  child: Icon(Icons.arrow_forward_rounded, color: Colors.amber),
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
            const SizedBox(height: 24),
            const Text(
              "파이프 규격 (Inch)",
              style: TextStyle(
                color: Colors.amber,
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
              "파이프 규격 (mm)",
              style: TextStyle(
                color: Colors.amber,
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
                        ? "미상"
                        : _fromController.text,
                    "to": _toController.text.isEmpty
                        ? "미상"
                        : _toController.text,
                    "start_fit": widget.includeStart,
                    "end_fit": widget.includeEnd,
                    "tail": widget.tailLength,
                    "start_dir": widget.startDir,
                  };

                  await DatabaseHelper.instance.insertHistory({
                    'date': DateTime.now().toString().substring(0, 16),
                    'p_to_p': jsonEncode(pToPData),
                    'pipe_size': _selectedSize,
                    'total_length': widget.totalCut,
                    'bend_data': jsonEncode(widget.bendList),
                  });

                  // 🚀 [자재 연동 핵심 로직] 부속품 리스트 생성 후 콜백 트리거
                  if (widget.onSaveCallback != null) {
                    List<Map<String, dynamic>> usedFittings = [];

                    // 체크박스 옵션에 따라 "현재 선택한 파이프 규격"의 Fitting을 자동으로 할당
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

                    // 부모(ProjectManagementPage)가 던져준 함수를 실행해 바구니에 담음
                    widget.onSaveCallback!(widget.totalCut, usedFittings);
                  }

                  if (!mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("작업 보관함 및 프로젝트 자재에 누적 저장되었습니다! 💾"),
                      backgroundColor: makitaTeal,
                    ),
                  );
                },
                child: const Text(
                  "도면 저장하기",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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
