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

  // 🚀 [추가] 마킹 페이지로부터 시작 방향 값을 전달받습니다.
  final String startDir;

  const SmartSavePad({
    super.key,
    required this.totalCut,
    required this.bendList,
    required this.includeStart,
    required this.includeEnd,
    required this.tailLength,
    required this.startDir, // 🚀 [추가]
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
                  // 💡 피팅, Tail, 그리고 시작 방향(start_dir)을 DB(JSON)에 확실히 못 박아버립니다!
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
                    "start_dir": widget.startDir, // 🚀 [추가] 부모로부터 받은 시작 방향 저장!
                  };

                  await DatabaseHelper.instance.insertHistory({
                    'date': DateTime.now().toString().substring(0, 16),
                    'p_to_p': jsonEncode(pToPData),
                    'pipe_size': _selectedSize,
                    'total_length': widget.totalCut,
                    'bend_data': jsonEncode(widget.bendList),
                  });

                  if (!mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("작업 보관함에 저장되었습니다! 💾"),
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
