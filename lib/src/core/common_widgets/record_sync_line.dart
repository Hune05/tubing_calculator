// 기록 목록 위 한 줄: "서버에 저장되어 있습니다" / "폰에만 저장된 것 N건"(10-09).
// 교정·압력시험 기록 화면의 줄과 같은 말·같은 모양이다.
import 'package:flutter/material.dart';

import '../../data/record_sync.dart';
import '../theme/app_tokens.dart';

class RecordSyncLine extends StatelessWidget {
  final RecordSyncStatus? status;
  const RecordSyncLine(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final s = status;
    if (s == null) return const SizedBox.shrink();
    final waiting = !s.enabled || s.pending > 0;
    final color = waiting ? AppColors.caution : AppColors.textSub;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        children: [
          Icon(
            waiting ? Icons.cloud_upload_outlined : Icons.cloud_done_outlined,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              recordSyncText(s),
              style: TextStyle(
                fontSize: 13,
                fontWeight: waiting ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
