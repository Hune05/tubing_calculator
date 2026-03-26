import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

// 🚀 Hive 로컬 DB 연동
import 'package:hive_flutter/hive_flutter.dart';

// 🔥 파이어베이스 연동
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// 🚀 딥링크 패키지
import 'package:app_links/app_links.dart';

// 💡 파이어베이스 DB 시더
import 'package:tubing_calculator/src/core/utils/db_seeder.dart';

// 💡 기존 화면들 임포트
import 'package:tubing_calculator/src/presentation/calculator/widgets/main_calculator_screen.dart';
import 'package:tubing_calculator/src/presentation/settings/screens/settings_screen.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/marking_page.dart';
import 'package:tubing_calculator/src/presentation/history/screens/history_screen.dart';
import 'package:tubing_calculator/src/presentation/inventory/pages/inventory_page.dart';
import 'package:tubing_calculator/src/presentation/project/project_management_page.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/screens/cutting_project_list_screen.dart';
import 'package:tubing_calculator/src/presentation/menu/page/menu_screen.dart';

// 📱 모바일 전용 화면 임포트
import 'package:tubing_calculator/src/presentation/menu/page/mobile_loading_screen.dart';

// 🚀 현장 작업자 전용 3D 뷰어 화면 임포트
import 'package:tubing_calculator/src/presentation/fabrication/screens/viewer_only_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('projectsBox');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
      home: const DeepLinkHandler(child: DeviceRouter()),
      routes: {
        '/menu': (context) => const MenuScreen(),
        '/calculator': (context) => const MainCalculatorScreen(),
        '/marking': (context) => const MarkingPage(startDir: 'RIGHT'),
        '/settings': (context) => const SettingsScreen(),
        '/history': (context) => const HistoryScreen(),
        '/inventory': (context) => const InventoryPage(),
        '/projects': (context) => const ProjectManagementPage(),
        '/cutting': (context) => const CuttingProjectListScreen(),
      },
    );
  }
}

// ---------------------------------------------------------
// 🚀 [핵심 수정] 딥링크 핸들러 (완전 종료 상태 인식 추가)
// ---------------------------------------------------------
class DeepLinkHandler extends StatefulWidget {
  final Widget child;
  const DeepLinkHandler({super.key, required this.child});

  @override
  State<DeepLinkHandler> createState() => _DeepLinkHandlerState();
}

class _DeepLinkHandlerState extends State<DeepLinkHandler> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // 🚀 1. 앱이 완전히 꺼져 있다가 QR 스캔으로 처음 켜질 때 (Cold Start)
    try {
      // 💡 에러 해결: 최신 버전 함수인 getInitialAppLink() 로 변경!
      final initialUri = await _appLinks.getInitialAppLink();
      if (initialUri != null &&
          initialUri.scheme == 'tubingapp' &&
          initialUri.host == 'view') {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _handleViewerLink(initialUri);
        });
      }
    } catch (e) {
      debugPrint("초기 링크 로드 에러: $e");
    }

    // 🚀 2. 앱이 백그라운드(뒤로가기 상태)에 켜져 있을 때 QR 스캔할 때
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      if (uri.scheme == 'tubingapp' && uri.host == 'view') {
        _handleViewerLink(uri);
      }
    });
  }

  void _handleViewerLink(Uri uri) {
    try {
      final String proj = uri.queryParameters['p'] ?? 'Unknown';
      final String size = uri.queryParameters['s'] ?? 'Unknown';
      final String compressedBends = uri.queryParameters['b'] ?? '';

      List<Map<String, dynamic>> parsedBends = [];
      if (compressedBends.isNotEmpty) {
        List<String> segments = compressedBends.split('-');
        for (String seg in segments) {
          List<String> parts = seg.split('_');
          if (parts.length == 3) {
            double a = double.tryParse(parts[1]) ?? 0.0;
            parsedBends.add({
              'length': double.tryParse(parts[0]) ?? 0.0,
              'angle': a,
              'rotation': double.tryParse(parts[2]) ?? 0.0,
              'is_straight': a == 0.0,
            });
          }
        }
      }

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ViewerOnlyScreen(
              project: proj,
              pipeSize: size,
              bendList: parsedBends,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("딥링크 파싱 및 뷰어 연결 에러: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

// ---------------------------------------------------------
// 기존 라우터 및 로딩 스크린 로직 유지
// ---------------------------------------------------------
class DeviceRouter extends StatelessWidget {
  const DeviceRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return const MobileLoadingScreen();
        } else {
          return const LoadingScreen();
        }
      },
    );
  }
}

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

  Future<void> _seedDatabase() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(color: Color(0xFF007580)),
        );
      },
    );

    await SmartFittingDBSeeder.uploadInitialData();

    // 💡 에러 해결: 비동기 작업 후 안전한 플러터 context 처리 방식
    if (!mounted) return;

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("✅ 파이어베이스 DB 데이터 구축이 완료되었습니다!"),
        backgroundColor: Color(0xFF007580),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
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
