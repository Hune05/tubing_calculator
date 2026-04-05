import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 🔥 파이어베이스 Auth
import 'package:shared_preferences/shared_preferences.dart'; // 🚀 로컬 저장소

import 'mobile_profile_edit_page.dart';
import 'package:tubing_calculator/src/presentation/menu/page/mobile_loading_screen.dart'; // 🚀 로그아웃 후 돌아갈 로딩/로그인 화면 임포트

const Color slate900 = Color(0xFF191F28);
const Color slate800 = Color(0xFF333D4B);
const Color slate600 = Color(0xFF8B95A1);
const Color slate100 = Color(0xFFF2F4F6);
const Color pureWhite = Color(0xFFFFFFFF);
const Color red500 = Color(0xFFF04452);

class MobileProfilePage extends StatelessWidget {
  final String currentWorker;

  const MobileProfilePage({super.key, required this.currentWorker});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: slate100,
      appBar: AppBar(
        backgroundColor: slate100,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: slate900),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // 🌟 내 정보 카드 영역
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: pureWhite,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: slate100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.user,
                        size: 40,
                        color: slate600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      currentWorker,
                      style: const TextStyle(
                        color: slate900,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "현장 작업자",
                      style: TextStyle(
                        color: slate600,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // 🌟 메뉴 리스트 영역
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: pureWhite,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    _buildProfileMenuItem(
                      title: "프로필 수정",
                      icon: LucideIcons.settings,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MobileProfileEditPage(
                              initialName: currentWorker,
                            ),
                          ),
                        );
                      },
                    ),
                    const Divider(
                      height: 1,
                      color: slate100,
                      indent: 24,
                      endIndent: 24,
                    ),
                    _buildProfileMenuItem(
                      title: "로그아웃",
                      icon: LucideIcons.logOut,
                      titleColor: red500,
                      iconColor: red500,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _showLogoutDialog(context);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileMenuItem({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    Color titleColor = slate800,
    Color iconColor = slate600,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Row(
          children: [
            Icon(icon, size: 24, color: iconColor),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              // 🔥 에러 해결: 최신 Flutter 버전에 맞게 withValues 사용
              color: slate600.withValues(alpha: 0.5),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: pureWhite,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "로그아웃 하시겠습니까?",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: slate900,
              letterSpacing: -0.5,
            ),
          ),
          content: const Text(
            "안전한 작업을 위해\n작업이 끝났다면 로그아웃 해주세요.",
            style: TextStyle(fontSize: 15, color: slate600, height: 1.4),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      backgroundColor: slate100,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "취소",
                      style: TextStyle(
                        color: slate600,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      HapticFeedback.mediumImpact();

                      // 🔥 1. 파이어베이스 로그아웃 (이것만으로 세션 종료 충분)
                      await FirebaseAuth.instance.signOut();

                      // 🔥 2. 기기에 저장된 오프라인용 이름 삭제
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('user_real_name');

                      if (context.mounted) {
                        // 🔥 3. 모든 화면 기록을 싹 지우고 로그인 화면으로 완벽하게 이동
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MobileLoadingScreen(),
                          ),
                          (route) => false,
                        );
                      }
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: red500,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "로그아웃",
                      style: TextStyle(
                        color: pureWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
