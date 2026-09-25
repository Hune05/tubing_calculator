import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';

import 'korean_text.dart';

const Color _red = AppColors.danger;
const Color _sub = AppColors.textSub;

// 내 프로젝트 화면 위에 뜨는 "작업 일지 알림 예약에 문제가 있습니다" 카드.
// [onRetry]는 다시 예약한 뒤 아직도 문제가 있으면 그 문구를, 해결됐으면 null을 돌려준다.
class ReminderProblemCard extends StatefulWidget {
  final String message;
  final bool preview; // 점검 화면에서 띄운 미리 보기인지
  final VoidCallback onOpenCheck;
  final Future<String?> Function() onRetry;
  final void Function(String? stillProblem) onRetried;

  const ReminderProblemCard({
    super.key,
    required this.message,
    required this.preview,
    required this.onOpenCheck,
    required this.onRetry,
    required this.onRetried,
  });

  @override
  State<ReminderProblemCard> createState() => _ReminderProblemCardState();
}

class _ReminderProblemCardState extends State<ReminderProblemCard> {
  bool _busy = false;

  Future<void> _retry() async {
    if (_busy) return;
    setState(() => _busy = true);
    String? still;
    try {
      still = await widget.onRetry();
    } catch (_) {
      still = widget.message;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    widget.onRetried(still);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            still == null
                ? '알림을 다시 예약했습니다.'
                : '다시 예약했지만 아직 맞지 않습니다. 알림 점검에서 확인하십시오.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _red.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '작업 일지 알림 예약에 문제가 있습니다',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            keepWords(
              widget.preview
                  ? '${widget.message} (점검 화면에서 띄운 미리 보기이며 실제 문제는 아닙니다.)'
                  : '${widget.message} 다시 예약하거나 알림 점검에서 확인하십시오.',
            ),
            style: const TextStyle(fontSize: 12, height: 1.4, color: _sub),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: widget.onOpenCheck,
                child: const Text('알림 점검 열기'),
              ),
              TextButton(
                onPressed: _busy ? null : _retry,
                child: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        '다시 예약',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
