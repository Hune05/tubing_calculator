import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/instrument_shape_painter.dart';
import '../models/layout_board_models.dart';

import 'korean_text.dart';

// 작업 배치도 화면(목록·도면)이 같이 쓰는 색과 모양.
// 전선관 계산기와 같은 색(slate)과 흰 둥근 카드에 맞췄다.
// 이름은 예전 것(toss…)을 그대로 두어 화면 코드를 덜 건드린다.
const Color tossBlue = AppColors.brand; // 마키타 틸(전선관 계산기와 같음)
const Color tossText = AppColors.text; // slate900
const Color tossSubText = AppColors.textSub; // slate600(밖에서도 읽히게 진하게)
const Color tossBg = AppColors.background; // slate100
const Color layoutLine = AppColors.line; // slate200: 칸 테두리
const Color pureWhite = Color(0xFFFFFFFF);
const Color warningRed = AppColors.danger;

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
  Key? key,
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
    key: key,
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

/// 아래 도구 줄 단추(10-13 개편): 아이콘 위, 글씨(14) 아래, 높이 60. 글은 네 글자 안으로 해서
/// 어느 폭에서도 잘리지 않게 한다. [primary]는 채운 청록(부품 담기), [selected]는 켜진 토글.
Widget layoutToolButton({
  Key? key,
  required IconData icon,
  required String label,
  required VoidCallback? onTap,
  bool selected = false,
  bool primary = false,
  Color? color,
}) {
  final Color accent = color ?? tossBlue;
  final Color fg = primary ? pureWhite : (selected ? accent : tossText);
  final Color bg = primary
      ? tossBlue
      : (selected ? accent.withValues(alpha: 0.10) : pureWhite);
  return Semantics(
    button: true,
    selected: selected,
    child: Material(
      key: key,
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: primary || selected ? accent : layoutLine,
          width: selected && !primary ? 2 : 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap();
              },
        child: SizedBox(
          height: 60,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: fg),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: fg,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 부품 목록의 작은 그림(모양이 있으면 그 모양, 없으면 네모).
Widget layoutPresetThumb(ModulePreset p, {double box = 44}) {
  final double k = box / math.max(p.width, p.height);
  return SizedBox(
    width: box,
    height: box,
    child: Center(
      child: SizedBox(
        width: p.width * k,
        height: p.height * k,
        child: CustomPaint(
          painter: InstrumentShapePainter(shape: p.shape ?? '', strokeWidth: 1),
        ),
      ),
    ),
  );
}
