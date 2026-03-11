import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 🔥 파이어베이스 연동
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// 💡 파이어베이스 DB 시더 (초기 데이터 업로드용)
import 'package:tubing_calculator/src/core/utils/db_seeder.dart';

// 💡 기존 화면들 임포트 (태블릿용)
import 'package:tubing_calculator/src/presentation/calculator/widgets/main_calculator_screen.dart';
import 'package:tubing_calculator/src/presentation/settings/screens/settings_screen.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/marking_page.dart';
import 'package:tubing_calculator/src/presentation/history/screens/history_screen.dart';
import 'package:tubing_calculator/src/presentation/inventory/pages/inventory_page.dart';
import 'package:tubing_calculator/src/presentation/project/project_management_page.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/screens/cutting_project_list_screen.dart';
import 'package:tubing_calculator/src/presentation/menu/page/menu_screen.dart'; // 태블릿 메뉴

// 📱 모바일 전용 화면 임포트
import 'package:tubing_calculator/src/presentation/menu/page/mobile_loading_screen.dart'; // 🚀 모바일 전용 로딩 화면!

void main() async {
  // 플러터 엔진 초기화
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 파이어베이스 서버 연결
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 풀스크린 모드
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      // 🔥 initialRoute 대신 기기 크기에 따라 화면을 나눠주는 '문지기(DeviceRouter)'를 홈으로 설정!
      home: const DeviceRouter(),
      // 🗺️ 라우트(주소록) 깔끔하게 정리
      routes: {
        '/menu': (context) => const MenuScreen(),
        '/calculator': (context) => const MainCalculatorScreen(),
        '/marking': (context) => const MarkingPage(),
        '/settings': (context) => const SettingsScreen(),
        '/history': (context) => const HistoryScreen(),
        '/inventory': (context) => const InventoryPage(),
        '/projects': (context) => const ProjectManagementPage(),
        '/cutting': (context) => const CuttingProjectListScreen(), // 스마트 컷팅 연결!
      },
    );
  }
}

// ---------------------------------------------------------
// [핵심] 기기 판별 라우터 (스마트폰 vs 태블릿 자동 분기)
// ---------------------------------------------------------
class DeviceRouter extends StatelessWidget {
  const DeviceRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          // ✅ 가로가 600 미만인 스마트폰은 무조건 '모바일 로딩 화면'으로 보냅니다!
          return const MobileLoadingScreen();
        } else {
          // ✅ 태블릿이면 기존 '태블릿 로딩 화면'을 띄웁니다!
          return const LoadingScreen();
        }
      },
    );
  }
}

// ---------------------------------------------------------
// [1] 로딩 스크린 (태블릿 전용 - 기존 코드 유지 + DB 시더 버튼 추가)
// ---------------------------------------------------------
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

  // 🚀 DB 초기 업로드 함수
  Future<void> _seedDatabase() async {
    // 로딩 인디케이터 띄우기 (UX 편의)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(color: Color(0xFF007580)),
        );
      },
    );

    // 스크립트 실행
    await SmartFittingDBSeeder.uploadInitialData();

    // 로딩 인디케이터 닫기 (다이얼로그 팝)
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ 파이어베이스 DB 데이터 구축이 완료되었습니다!"),
          backgroundColor: Color(0xFF007580),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
          // 기존 터치 영역 (전체 화면)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
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
                    const SizedBox(height: 80),
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

          // 💡 개발자 전용 숨김 버튼 (우측 하단 작은 아이콘)
          // 화면의 구석에 작게 배치하여 일반 사용자는 누를 일이 없게 만듭니다.
          Positioned(
            bottom: 20,
            right: 20,
            child: IconButton(
              icon: const Icon(
                Icons.cloud_upload_outlined,
                color: Colors.white30,
                size: 24,
              ),
              onPressed: _seedDatabase,
              tooltip: "DB 초기화 (개발자용)",
            ),
          ),
        ],
      ),
    );
  }
}
