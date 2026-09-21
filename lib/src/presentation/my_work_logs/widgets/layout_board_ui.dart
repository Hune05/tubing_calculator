import 'package:flutter/material.dart';

import 'korean_text.dart';

// 작업 배치도 화면(목록·도면)이 같이 쓰는 색과 모양.
// 전선관 계산기와 같은 색(slate)과 흰 둥근 카드에 맞췄다.
// 이름은 예전 것(toss…)을 그대로 두어 화면 코드를 덜 건드린다.
const Color tossBlue = Color(0xFF007580); // 마키타 틸(전선관 계산기와 같음)
const Color tossText = Color(0xFF0F172A); // slate900
const Color tossSubText = Color(0xFF475569); // slate600(밖에서도 읽히게 진하게)
const Color tossBg = Color(0xFFF1F5F9); // slate100
const Color layoutLine = Color(0xFFE2E8F0); // slate200: 칸 테두리
const Color pureWhite = Color(0xFFFFFFFF);
const Color warningRed = Color(0xFFF04438);

/// 누르는 곳의 가장 작은 크기(dp). 폰은 맨손으로 쓰므로 보통 폰 크기로 둔다.
const double kLayoutTouch = 40;

/// 전선관 계산기 카드: 흰 바탕, 둥근 모서리, 옅은 테두리와 그림자.
BoxDecoration layoutCardDecoration({double radius = 18, Color? color}) =>
    BoxDecoration(
      color: color ?? pureWhite,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: tossSubText.withValues(alpha: 0.15),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: tossText.withValues(alpha: 0.03),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );

/// 바텀시트 안의 한 줄 단추(높이 60dp, 글씨 16).
Widget layoutSheetRow({
  required IconData icon,
  required String label,
  required VoidCallback? onTap,
  String? caption,
  bool danger = false,
  Color? iconColor,
}) {
  final Color fg = danger ? warningRed : tossText;
  final bool enabled = onTap != null;
  return InkWell(
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Icon(
              icon,
              size: 26,
              color: !enabled
                  ? tossSubText.withValues(alpha: 0.4)
                  : (danger ? warningRed : (iconColor ?? tossBlue)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: enabled ? fg : tossSubText.withValues(alpha: 0.5),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (caption != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      keepWords(caption),
                      style: const TextStyle(color: tossSubText, fontSize: 14),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 되돌리기 어려운 일(전체 지우기, 삭제) 앞에서 한 번 더 묻는다. "지운다"를 누르면 true.
Future<bool> confirmLayoutDanger(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: pureWhite,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        title,
        style: const TextStyle(
          color: tossText,
          fontWeight: FontWeight.w900,
          fontSize: 18,
        ),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Text(
          keepWords(message),
          style: const TextStyle(color: tossSubText, fontSize: 15, height: 1.4),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(88, 48)),
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text(
            "취소",
            style: TextStyle(
              color: tossSubText,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: warningRed,
            minimumSize: const Size(88, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            confirmLabel,
            style: const TextStyle(
              color: pureWhite,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );
  return ok == true;
}
