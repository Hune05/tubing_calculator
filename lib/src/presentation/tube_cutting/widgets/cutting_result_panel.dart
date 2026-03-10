import 'package:flutter/material.dart';

const Color darkBg = Color(0xFF1E2124);
const Color cardBg = Color(0xFF2A2E33);
const Color makitaTeal = Color(0xFF007580);
const Color mutedWhite = Color(0xFFD0D4D9);

class CuttingResultPanel extends StatelessWidget {
  final double cutLength;
  final String startFitting;
  final double startDeduction;
  final String endFitting;
  final double endDeduction;
  final VoidCallback? onSave;

  const CuttingResultPanel({
    super.key,
    required this.cutLength,
    required this.startFitting,
    required this.startDeduction,
    required this.endFitting,
    required this.endDeduction,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // ★ 경고 해결: withOpacity -> withValues(alpha: 0.3)
      color: cardBg.withValues(alpha: 0.3),
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "실제 튜브 절단 기장 (Cut Length)",
            style: TextStyle(color: Colors.grey, fontSize: 20),
          ),
          const SizedBox(height: 16),
          Text(
            cutLength > 0 ? "${cutLength.toStringAsFixed(1)} mm" : "0.0 mm",
            style: TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.w900,
              color: cutLength > 0 ? Colors.greenAccent : mutedWhite,
            ),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: darkBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildDeductionRow("시작 공제 ($startFitting)", startDeduction),
                const Divider(color: Colors.white24, height: 24),
                _buildDeductionRow("끝단 공제 ($endFitting)", endDeduction),
              ],
            ),
          ),

          const SizedBox(height: 60),

          ElevatedButton.icon(
            onPressed: onSave,
            icon: const Icon(Icons.save, size: 28),
            label: const Text(
              "계산 완료 및 튜브 소모량 기록",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: makitaTeal,
              foregroundColor: Colors.white,
              disabledBackgroundColor: cardBg,
              // ★ 에러 해결: Size.infinity 대신 확실한 사이즈 지정
              minimumSize: const Size(double.infinity, 64),
              padding: const EdgeInsets.symmetric(vertical: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeductionRow(String label, double value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
        Text(
          "- ${value.toStringAsFixed(1)} mm",
          style: const TextStyle(
            color: Colors.redAccent,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
