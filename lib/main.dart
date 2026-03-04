import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 💡 필요한 화면들 임포트
import 'package:tubing_calculator/src/presentation/calculator/widgets/main_calculator_screen.dart';
import 'package:tubing_calculator/src/presentation/settings/screens/settings_screen.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/marking_page.dart';
import 'package:tubing_calculator/src/presentation/history/screens/history_screen.dart';
import 'package:tubing_calculator/src/presentation/inventory/pages/inventory_page.dart';
// 🔥 신규 추가: 프로젝트 관리 페이지 임포트 (경로는 생성하신 폴더에 맞게 맞춰주세요)
import 'package:tubing_calculator/src/presentation/project/project_management_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      initialRoute: '/',
      routes: {
        '/': (context) => const LoadingScreen(),
        '/menu': (context) => const MenuScreen(),
        '/calculator': (context) => const MainCalculatorScreen(),
        '/marking': (context) => const MarkingPage(),
        '/settings': (context) => const SettingsScreen(),
        '/history': (context) => const HistoryScreen(),
        '/inventory': (context) => const InventoryPage(),
        // 🔥 신규 추가: 프로젝트 관리 라우터 등록
        '/projects': (context) => const ProjectManagementPage(),
      },
    );
  }
}

// ---------------------------------------------------------
// [1] 로딩 스크린 (유지)
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: GestureDetector(
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
    );
  }
}

// ---------------------------------------------------------
// [2] 메뉴 스크린 (프로젝트 관리 메뉴 추가)
// ---------------------------------------------------------
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Tubing Calculator',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: const Color(0xFF007580),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildListTile(
              context,
              icon: Icons.calculate,
              title: '벤딩 계산기 (작업 화면)',
              subtitle: '단일/다중 벤딩 및 마킹 포인트 계산',
              onTap: () => Navigator.pushNamed(context, '/calculator'),
            ),
            const Divider(color: Colors.black12, height: 1),

            _buildListTile(
              context,
              icon: Icons.format_list_numbered,
              title: '마킹 및 컷팅 결과',
              subtitle: '계산된 최종 컷팅 길이와 마킹 지점 바로 확인',
              onTap: () => Navigator.pushNamed(context, '/marking'),
            ),
            const Divider(color: Colors.black12, height: 1),

            _buildListTile(
              context,
              icon: Icons.history,
              title: '작업 기록 보관함',
              subtitle: '저장해둔 이전 계산 내역 및 도면 확인',
              onTap: () => Navigator.pushNamed(context, '/history'),
            ),
            const Divider(color: Colors.black12, height: 1),

            // 🔥 신규 추가: 프로젝트 관리 (BOM) 버튼
            _buildListTile(
              context,
              icon: Icons.assignment, // 현장 서류 느낌의 아이콘
              title: '프로젝트 관리 (BOM)',
              subtitle: '프로젝트별 소모 튜브 본수 및 피팅 집계',
              onTap: () => Navigator.pushNamed(context, '/projects'),
            ),
            const Divider(color: Colors.black12, height: 1),

            _buildListTile(
              context,
              icon: Icons.inventory_2,
              title: '자재 관리 (Inventory)',
              subtitle: '튜브, 피팅, 밸브 등 재고 수량 확인 및 관리',
              onTap: () => Navigator.pushNamed(context, '/inventory'),
            ),
            const Divider(color: Colors.black12, height: 1),

            _buildListTile(
              context,
              icon: Icons.settings,
              title: '장비 및 배관 설정',
              subtitle: '벤더 제원, 삽입 깊이, 여유장 설정',
              onTap: () => Navigator.pushNamed(context, '/settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF007580), size: 36),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.black54)),
      onTap: onTap,
    );
  }
}
