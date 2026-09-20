import 'package:flutter/material.dart';

import 'cutting_theme.dart';

// 🚀 [통신 없는 현장] 발전소처럼 통신이 안 되는 곳에서 입력한 것은 폰에 쌓였다가 통신되면
// 저절로 올라간다. 그런데 화면에는 "저장했습니다"만 나와서 서버에 올라갔는지 알 수 없었다.
// 아직 올라가지 못한 저장이 있으면 이 줄로 알려 준다(Firestore가 알려 주는 대기 상태를 쓴다).
class PendingWritesBanner extends StatelessWidget {
  // 아직 올라가지 못한 저장 건수(0이면 아무것도 그리지 않는다).
  final int count;
  const PendingWritesBanner({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      key: const Key('pending_writes_banner'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: CuttingColors.warningSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CuttingColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_upload_outlined,
            size: 18,
            color: CuttingColors.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "아직 올라가지 못한 저장이 $count건 있습니다. 통신되면 저절로 올라갑니다.",
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: CuttingColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
