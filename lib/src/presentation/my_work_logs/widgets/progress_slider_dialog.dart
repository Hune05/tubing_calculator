import 'package:flutter/material.dart';

const Color makitaTeal = Color(0xFF007580);
const Color slate50 = Color(0xFFF8FAFC);
const Color slate200 = Color(0xFFE2E8F0);
const Color slate600 = Color(0xFF475569);
const Color slate900 = Color(0xFF0F172A);
const Color pureWhite = Color(0xFFFFFFFF);

class ProgressSliderDialog extends StatefulWidget {
  final double currentProgress;

  const ProgressSliderDialog({super.key, required this.currentProgress});

  /// 사용하기 편하게 만든 정적 메서드
  static Future<double?> show(BuildContext context, double current) {
    return showDialog<double>(
      context: context,
      builder: (context) => ProgressSliderDialog(currentProgress: current),
    );
  }

  @override
  State<ProgressSliderDialog> createState() => _ProgressSliderDialogState();
}

class _ProgressSliderDialogState extends State<ProgressSliderDialog> {
  late double _progress;
  late TextEditingController _percentCtrl;

  @override
  void initState() {
    super.initState();
    _progress = widget.currentProgress;
    _percentCtrl = TextEditingController(
      text: (_progress * 100).toInt().toString(),
    );
  }

  @override
  void dispose() {
    _percentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isCompleted = _progress >= 1.0;

    return AlertDialog(
      backgroundColor: pureWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text(
        "진행률 업데이트",
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "현재 진행률 (%)",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: slate900,
                  ),
                ),
              ),
              SizedBox(
                width: 90,
                child: TextField(
                  controller: _percentCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: isCompleted ? Colors.green.shade600 : makitaTeal,
                    fontSize: 18,
                  ),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    filled: true,
                    fillColor: slate50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixText: "%",
                  ),
                  onChanged: (val) {
                    double? parsed = double.tryParse(val);
                    if (parsed != null) {
                      setState(() {
                        _progress = (parsed.clamp(0, 100)) / 100.0;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Slider(
            value: _progress,
            min: 0.0,
            max: 1.0,
            divisions: 100,
            activeColor: isCompleted ? Colors.green.shade500 : makitaTeal,
            inactiveColor: slate200,
            onChanged: (val) {
              setState(() {
                _progress = val;
                _percentCtrl.text = (val * 100).toInt().toString();
              });
            },
          ),
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isCompleted
                    ? Colors.green.shade50
                    : makitaTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isCompleted
                      ? Colors.green.shade300
                      : makitaTeal.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                isCompleted ? "🎉 COMPLETED (완료)" : "🚀 ONGOING (진행중)",
                style: TextStyle(
                  color: isCompleted ? Colors.green.shade700 : makitaTeal,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            "취소",
            style: TextStyle(color: slate600, fontWeight: FontWeight.bold),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isCompleted ? Colors.green.shade600 : makitaTeal,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () => Navigator.pop(context, _progress), // 변경된 값 반환
          child: const Text(
            "저장",
            style: TextStyle(color: pureWhite, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
