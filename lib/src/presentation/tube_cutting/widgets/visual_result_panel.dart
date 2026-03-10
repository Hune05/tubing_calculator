import 'package:flutter/material.dart';
import '../../../data/models/fitting_item.dart';

const Color cardBg = Color(0xFF2A2E33);
const Color makitaTeal = Color(0xFF007580);
const Color mutedWhite = Color(0xFFD0D4D9);

class VisualResultPanel extends StatelessWidget {
  final FittingItem startFitting;
  final FittingItem endFitting;
  final double cutLength;
  final VoidCallback? onSave;

  const VisualResultPanel({
    super.key,
    required this.startFitting,
    required this.endFitting,
    required this.cutLength,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: cardBg.withOpacity(0.3),
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "시각적 컷팅 확정 (Visual Check)",
            style: TextStyle(color: Colors.grey, fontSize: 18),
          ),
          const SizedBox(height: 40),

          // ★ 핵심: 파이프라인 시각화 영역
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. 시작점 실루엣
              _buildFittingSilhouette(startFitting),

              // 2. 파이프 라인 (절단 기장 표시)
              Expanded(
                child: Column(
                  children: [
                    Text(
                      cutLength > 0
                          ? "${cutLength.toStringAsFixed(1)} mm"
                          : "치수 입력 대기",
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: cutLength > 0 ? Colors.greenAccent : mutedWhite,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 실제 파이프를 형상화한 그래픽
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          height: 8,
                          color: cutLength > 0
                              ? Colors.blueGrey
                              : Colors.grey.shade800,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              width: 4,
                              height: 24,
                              color: Colors.blueGrey,
                            ), // 절단면 1
                            Container(
                              width: 4,
                              height: 24,
                              color: Colors.blueGrey,
                            ), // 절단면 2
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 3. 끝점 실루엣
              _buildFittingSilhouette(endFitting),
            ],
          ),

          const SizedBox(height: 60),

          // 공제 내역 텍스트 요약
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "시작 공제: -${startFitting.deduction}mm",
                style: const TextStyle(color: Colors.redAccent),
              ),
              Text(
                "끝단 공제: -${endFitting.deduction}mm",
                style: const TextStyle(color: Colors.redAccent),
              ),
            ],
          ),

          const Spacer(),

          // 저장 버튼
          ElevatedButton.icon(
            onPressed: onSave,
            icon: const Icon(Icons.check_circle_outline, size: 28),
            label: const Text(
              "시각 확인 완료 & 기록 저장",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: makitaTeal,
              foregroundColor: Colors.white,
              disabledBackgroundColor: cardBg,
              minimumSize: const Size(double.infinity, 64),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 부속 실루엣을 그려주는 위젯
  Widget _buildFittingSilhouette(FittingItem item) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: Icon(item.icon, size: 40, color: Colors.white70),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 100,
          child: Text(
            item.displayName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
