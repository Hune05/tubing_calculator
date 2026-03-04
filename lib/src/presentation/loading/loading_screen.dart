import 'package:flutter/material.dart';

// 💡 마스터님의 메뉴 스크린 경로를 적어주세요! (아래는 예시입니다)
// import 'package:tubing_calculator/src/presentation/calculator/widgets/menu_screen.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    // 💡 TAP TO START 글씨가 부드럽게 깜빡거리도록 애니메이션을 넣었습니다.
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // 배경색 고정
      // 💡 화면 어디든 터치하면 넘어가도록 GestureDetector로 전체를 감쌌습니다.
      body: GestureDetector(
        behavior: HitTestBehavior.opaque, // 빈 공간을 눌러도 인식되게 함
        onTap: () {
          // 💡 터치하는 순간 마스터님의 메뉴 스크린으로 쏴줍니다!
          // (혹시 라우팅 이름표 방식을 쓰시면 Navigator.pushReplacementNamed(context, '/menu'); 로 쓰셔도 됩니다)
          /*
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MenuScreen()),
          );
          */
          // 💡 main.dart에 '/menu' 길을 뚫어두셨다면 이게 제일 깔끔합니다.
          Navigator.pushReplacementNamed(context, '/menu');
        },
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.precision_manufacturing,
                  size: 90,
                  color: Color(0xFF007580),
                ),
                const SizedBox(height: 24),
                const Text(
                  "TUBING CALCULATOR",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 80), // 아이콘과 글씨 사이 간격 넉넉하게
                // 💡 뺑뺑이 로딩 대신 들어간 'TAP TO START' 깜빡이
                FadeTransition(
                  opacity: _animationController,
                  child: const Text(
                    "- TAP TO START -",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF007580),
                      letterSpacing: 2.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
