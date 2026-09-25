import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// 만들 수 없는 형상이거나 관이 저희끼리 닿을 때 값 위에 띄우는 띠.
/// 마킹 화면 세 곳(폰·태블릿·전선관)이 같은 모양으로 쓴다.
class BendWarningBanner extends StatelessWidget {
  final List<String> warnings;

  const BendWarningBanner({super.key, required this.warnings});

  static const Color _amber = AppColors.caution;

  @override
  Widget build(BuildContext context) {
    if (warnings.isEmpty) return const SizedBox.shrink();
    return Container(
      key: const Key('bend_warning_banner'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3DF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _amber.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '이대로는 만들 수 없습니다',
            style: TextStyle(
              color: _amber,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          for (final w in warnings)
            Text(
              w,
              style: const TextStyle(
                color: _amber,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}
