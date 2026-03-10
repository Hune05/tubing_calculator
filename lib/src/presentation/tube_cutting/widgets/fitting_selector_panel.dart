import 'package:flutter/material.dart';
// ★ 이전 파일명 대신 새 DB 파일명으로 변경
import '../../../data/models/smart_fitting_db.dart';

const Color darkBg = Color(0xFF1E2124);
const Color cardBg = Color(0xFF2A2E33);
const Color mutedWhite = Color(0xFFD0D4D9);

class FittingSelectorPanel extends StatelessWidget {
  final TextEditingController totalLenCtrl;
  final String selectedTubeSize;
  final String startFitting;
  final String endFitting;
  final List<String> availableFittings;
  final VoidCallback onCalculate;
  final Function(String?) onTubeSizeChanged;
  final Function(String?) onStartFittingChanged;
  final Function(String?) onEndFittingChanged;

  const FittingSelectorPanel({
    super.key,
    required this.totalLenCtrl,
    required this.selectedTubeSize,
    required this.startFitting,
    required this.endFitting,
    required this.availableFittings,
    required this.onCalculate,
    required this.onTubeSizeChanged,
    required this.onStartFittingChanged,
    required this.onEndFittingChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "1. 튜브 규격 (Size)",
              style: TextStyle(color: mutedWhite, fontSize: 16),
            ),
            const SizedBox(height: 8),
            _buildDropdown(
              selectedTubeSize,
              SmartFittingDB
                  .tubeSizes, // ★ FittingDeductionDB -> SmartFittingDB
              onTubeSizeChanged,
            ),
            const SizedBox(height: 32),

            const Text(
              "2. 도면상 전체 치수 (Center to Center)",
              style: TextStyle(color: mutedWhite, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: totalLenCtrl,
              keyboardType: TextInputType.number,
              onChanged: (_) => onCalculate(),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: cardBg,
                suffixText: "mm",
                suffixStyle: const TextStyle(color: Colors.grey, fontSize: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 32),

            const Text(
              "3. 양단 피팅(조인트) 선택",
              style: TextStyle(color: mutedWhite, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "시작점 (Start)",
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      _buildDropdown(
                        startFitting,
                        availableFittings,
                        onStartFittingChanged,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "끝점 (End)",
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      _buildDropdown(
                        endFitting,
                        availableFittings,
                        onEndFittingChanged,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(
    String currentValue,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        // ★ 경고 해결: withOpacity -> withValues(alpha: 0.1)
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentValue,
          isExpanded: true,
          dropdownColor: darkBg,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          items: items
              .map((val) => DropdownMenuItem(value: val, child: Text(val)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
