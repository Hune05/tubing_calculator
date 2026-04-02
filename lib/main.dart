import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

// 🚀 Hive 로컬 DB 연동
import 'package:hive_flutter/hive_flutter.dart';

// 🔥 파이어베이스 & FCM 연동 (필수 추가)
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';

// 🚀 딥링크 패키지
import 'package:app_links/app_links.dart';

// 💡 파이어베이스 DB 시더 및 기존 화면들 임포트
import 'package:tubing_calculator/src/core/utils/db_seeder.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/main_calculator_screen.dart';
import 'package:tubing_calculator/src/presentation/settings/screens/settings_screen.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/marking_page.dart';
import 'package:tubing_calculator/src/presentation/history/screens/history_screen.dart';
import 'package:tubing_calculator/src/presentation/inventory/pages/inventory_page.dart';
import 'package:tubing_calculator/src/presentation/project/project_management_page.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/screens/cutting_project_list_screen.dart';
import 'package:tubing_calculator/src/presentation/menu/page/menu_screen.dart';
import 'package:tubing_calculator/src/presentation/menu/page/mobile_loading_screen.dart';
import 'package:tubing_calculator/src/presentation/fabrication/screens/viewer_only_screen.dart';

// 🚀 [추가 1] 앱이 완전히 꺼져있거나 백그라운드일 때 알림을 받는 함수 (반드시 최상단에 위치!)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("백그라운드 알림 수신: ${message.notification?.title}");
}

// 🚀 [추가 2] 포그라운드(앱 켜진 상태) 알림을 띄우기 위한 채널 설정
late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
late AndroidNotificationChannel channel;

bool isFlutterLocalNotificationsInitialized = false;

Future<void> setupFlutterNotifications() async {
  if (isFlutterLocalNotificationsInitialized) return;

  channel = const AndroidNotificationChannel(
    'high_importance_channel', // 채널 ID
    '현장 중요 알림', // 채널 이름
    description: '자재 발주 및 중요 현장 알림에 사용됩니다.',
    importance: Importance.high,
  );

  flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // 안드로이드 채널 생성
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  // iOS 포그라운드 알림 설정
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  isFlutterLocalNotificationsInitialized = true;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hive 초기화
  await Hive.initFlutter();
  await Hive.openBox('projectsBox');

  // Firebase 초기화
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 🚀 [추가 3] 백그라운드 메시지 핸들러 등록
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 🚀 [추가 4] 로컬 알림 초기화
  await setupFlutterNotifications();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _requestNotificationPermission();
    _setupForegroundMessageListener();
    _printMyFCMToken(); // 🔥 [추가] 앱 시작 시 토큰 출력
  }

  // 🚀 [추가] 기기 고유 토큰 발급 확인용 함수 (터미널에서 확인 후 복사하세요!)
  void _printMyFCMToken() async {
    String? token = await FirebaseMessaging.instance.getToken();
    debugPrint("=====================================");
    debugPrint("🔥 내 기기 FCM 토큰: $token");
    debugPrint("=====================================");
  }

  // 🚀 [추가 5] 앱 켰을 때 사용자에게 알림 권한 묻기
  void _requestNotificationPermission() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('사용자 알림 권한 상태: ${settings.authorizationStatus}');

    // (선택) 특정 주제(Topic) 구독 - 나중에 "orders" 그룹으로 단체 알람 보낼 때 유용함
    await messaging.subscribeToTopic("field_orders");
  }

  // 🚀 [추가 6] 앱을 켜놓고 보고 있을 때 알림이 오면 화면 위에 팝업 띄우기
  void _setupForegroundMessageListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: '@mipmap/ic_launcher', // 앱 기본 아이콘 사용
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
      }
    });
  }

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
// 🚀 딥링크 핸들러 및 라우터 로직 (기존과 동일하게 유지)
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

    try {
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
