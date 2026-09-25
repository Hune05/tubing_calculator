// 화면 머리 한 모양(UI 디자인 제안 D-E).
//
// 예전에는 머리가 다섯 가지였다(흰 머리, 청록으로 채운 머리, 주황 머리, 짙은 회색 띠, 머리 없음).
// 한 앱 안에서 머리 색이 바뀌면 다른 앱으로 넘어간 것처럼 보여, 모두 흰 바탕·검정 제목으로
// 맞추고, 전동·전선관처럼 "지금 어느 방식인지"는 제목 옆 작은 칩(모드 칩)으로 보인다.
// 오른쪽 단추는 2개까지, 나머지는 ⋮ 메뉴로.
library;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/field_view.dart';

/// 제목 옆 모드 칩(예: "전동" 주황, "시카고식" 보라). 색은 점과 글에만 써서 머리는 흰색 그대로.
class ModeChip extends StatelessWidget {
  final String label;
  final Color color;
  const ModeChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontFamily: kAppFontFamily,
              fontSize: 12,
              fontWeight: AppText.bold,
              color: Color.lerp(color, Colors.black, 0.25),
            ),
          ),
        ],
      ),
    );
  }
}

/// 머리 제목: 글 + (있으면) 모드 칩. 좁으면 제목이 줄어든다(…).
class AppHeaderTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final ModeChip? mode;
  const AppHeaderTitle(this.title, {super.key, this.subtitle, this.mode});

  @override
  Widget build(BuildContext context) {
    final p = FieldPalette.ofContext(context);
    final main = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: kAppFontFamily,
        fontSize: 18,
        fontWeight: AppText.bold,
        color: p.text,
      ),
    );
    final row = mode == null
        ? main
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: main),
              const SizedBox(width: AppSpace.sm),
              mode!,
            ],
          );
    if (subtitle == null) return row;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row,
        Text(
          subtitle!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.caption.copyWith(color: p.textSub),
        ),
      ],
    );
  }
}

/// 앱 머리. 흰 바탕·검정 제목·아래 가는 선.
AppBar appHeader(
  BuildContext context, {
  required String title,
  String? subtitle,
  ModeChip? mode,
  List<Widget>? actions,
  Widget? leading,
  bool automaticallyImplyLeading = true,
  PreferredSizeWidget? bottom,
}) {
  final p = FieldPalette.ofContext(context);
  return AppBar(
    backgroundColor: p.surface,
    foregroundColor: p.text,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    leading: leading,
    automaticallyImplyLeading: automaticallyImplyLeading,
    title: AppHeaderTitle(title, subtitle: subtitle, mode: mode),
    actions: actions,
    bottom: bottom,
    shape: Border(bottom: BorderSide(color: p.line)),
  );
}
