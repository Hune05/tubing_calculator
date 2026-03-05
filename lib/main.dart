import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 🔥 파이어베이스 연동을 위한 패키지 임포트 추가
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // flutterfire CLI가 자동으로 만들어준 파일

// 💡 필요한 화면들 임포트
import 'package:tubing_calculator/src/presentation/calculator/widgets/main_calculator_screen.dart';
import 'package:tubing_calculator/src/presentation/settings/screens/settings_screen.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/marking_page.dart';
import 'package:tubing_calculator/src/presentation/history/screens/history_screen.dart';
import 'package:tubing_calculator/src/presentation/inventory/pages/inventory_page.dart';
import 'package:tubing_calculator/src/presentation/project/project_management_page.dart';

// 🔥 main 함수에 async 키워드 추가 (서버 연결을 기다려야 하기 때문)
void main() async {
  // 플러터 엔진 초기화 (가장 먼저 실행되어야 함)
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 파이어베이스 서버 연결 초기화 (이 두 줄이 핵심입니다!)
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
      initialRoute: '/',
      routes: {
        '/': (context) => const LoadingScreen(),
        '/menu': (context) => const MenuScreen(),
        '/calculator': (context) => const MainCalculatorScreen(),
        '/marking': (context) => const MarkingPage(),
        '/settings': (context) => const SettingsScreen(),
        '/history': (context) => const HistoryScreen(),
        '/inventory': (context) => const InventoryPage(),
        '/projects': (context) => const ProjectManagementPage(),
      },
    );
  }
}

// ---------------------------------------------------------
// [1] 로딩 스크린
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
// [2] 메뉴 스크린 (태블릿 맞춤형 6개 꽉 차는 UI)
// ---------------------------------------------------------
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 🔥 기기 화면 넓이를 감지해서 스마트폰이면 2칸, 태블릿이면 3칸으로 자동 조절!
    var screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = screenWidth > 600 ? 3 : 2;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Tubing Calculator',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
        backgroundColor: const Color(0xFF007580),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: SafeArea(
        child: GridView.count(
          padding: const EdgeInsets.all(24),
          crossAxisCount: crossAxisCount, // 한 줄에 3칸 배치
          crossAxisSpacing: 24,
          mainAxisSpacing: 24,
          childAspectRatio: 1.2, // 태블릿에 맞는 가로가 살짝 긴 황금 비율
          children: [
            _buildGridCard(
              context,
              icon: Icons.calculate_outlined,
              title: '벤딩 계산기',
              subtitle: '단일/다중 벤딩 작업',
              onTap: () => Navigator.pushNamed(context, '/calculator'),
            ),
            _buildGridCard(
              context,
              icon: Icons.straighten,
              title: '마킹 및 컷팅',
              subtitle: '최종 컷팅 길이 확인',
              onTap: () => Navigator.pushNamed(context, '/marking'),
            ),
            _buildGridCard(
              context,
              icon: Icons.folder_special_outlined,
              title: '기록 보관함',
              subtitle: '이전 도면 및 내역',
              onTap: () => Navigator.pushNamed(context, '/history'),
            ),
            _buildGridCard(
              context,
              icon: Icons.assignment_outlined,
              title: '프로젝트 관리',
              subtitle: 'BOM 및 소모량 집계',
              onTap: () => Navigator.pushNamed(context, '/projects'),
            ),
            _buildGridCard(
              context,
              icon: Icons.inventory_2_outlined,
              title: '자재 관리',
              subtitle: '튜브 및 피팅 재고',
              onTap: () => Navigator.pushNamed(context, '/inventory'),
            ),
            _buildGridCard(
              context,
              icon: Icons.settings_suggest_outlined,
              title: '장비 및 설정',
              subtitle: '벤더 제원 및 배관 설정',
              onTap: () => Navigator.pushNamed(context, '/settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF007580).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: const Color(0xFF007580),
                size: 56,
              ), // 큼직한 아이콘
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20, // 큼직한 제목
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14, // 큼직한 부제목
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
