// 프로필·설정 화면이 같이 쓰는 카드형 메뉴 줄과 알림 막대.
import 'package:tubing_calculator/src/core/common_widgets/snack_once.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_icon_set.dart';
import '../../../core/theme/app_tokens.dart';

const Color profileSlate900 = AppColors.text;
const Color profileSlate800 = Color(0xFF333D4B);
const Color profileSlate600 = AppColors.textSub;
const Color profileSlate100 = AppColors.background;
const Color profileWhite = Color(0xFFFFFFFF);
const Color profileRed500 = Color(0xFFF04452);

Widget buildProfileMenuCard(List<Widget> items) {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: profileWhite,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0)
            const Divider(
              height: 1,
              color: profileSlate100,
              indent: 24,
              endIndent: 24,
            ),
          items[i],
        ],
      ],
    ),
  );
}

Widget profileMenuItem({
  required String title,
  String? subtitle,
  required IconData icon,
  required VoidCallback onTap,
  Color titleColor = profileSlate800,
  Color iconColor = profileSlate600,
}) {
  return InkWell(
    onTap: () {
      HapticFeedback.lightImpact();
      onTap();
    },
    borderRadius: BorderRadius.circular(24),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: Row(
        children: [
          Icon(icon, size: 24, color: iconColor),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: profileSlate600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(
            AppIcons.forward,
            color: profileSlate600.withValues(alpha: 0.5),
            size: 24,
          ),
        ],
      ),
    ),
  );
}

void showProfileSnack(
  BuildContext context,
  String msg, {
  bool isError = false,
}) {
  showSnackOnce(ScaffoldMessenger.of(context),
    SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: isError ? profileRed500 : profileSlate900,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
