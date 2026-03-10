import 'package:flutter/material.dart';
import 'mobile_menu_page.dart'; // 모바일 메뉴 페이지 임포트

class MobileLoadingScreen extends StatefulWidget {
  const MobileLoadingScreen({super.key});

  @override
  State<MobileLoadingScreen> createState() => _MobileLoadingScreenState();
}

class _MobileLoadingScreenState extends State<MobileLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    // 1초 주기로 부드럽게 깜빡이는 애니메이션
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E2124), // 다크 테마 배경
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          // 화면 터치 시 '모바일 메뉴 화면'으로 부드럽게 이동
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const MobileMenuPage(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    return FadeTransition(
                      opacity: animation,
                      child: child,
                    ); // 페이드인 효과
                  },
            ),
          );
        },
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 둥근 아이콘 배경
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFF007580).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.engineering,
                  size: 80,
                  color: Color(0xFF007580),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                "FIELD HELPER",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "모바일 현장 지원 시스템 v2.0",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 100),

              // 깜빡이는 탭 투 스타트 텍스트
              FadeTransition(
                opacity: _animController,
                child: const Text(
                  "- TAP TO START -",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF007580),
                    letterSpacing: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
