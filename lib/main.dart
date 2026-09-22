import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:ui' show PlatformDispatcher;
import 'package:tubing_calculator/src/core/utils/error_log.dart';

// 🚀 Hive 로컬 DB 연동
import 'package:hive_flutter/hive_flutter.dart';

// 🔥 파이어베이스 & FCM 연동
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';

// 🚀 딥링크 패키지
import 'package:app_links/app_links.dart';
import 'package:tubing_calculator/src/core/utils/shared_drawing_inbox.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/widgets/shared_drawing_sheet.dart'
    show openSharedDrawing;

// 💡 프로젝트 화면 임포트들
import 'package:tubing_calculator/src/core/utils/db_seeder.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/main_calculator_screen.dart';
import 'package:tubing_calculator/src/presentation/settings/screens/settings_screen.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/marking_page.dart';
import 'package:tubing_calculator/src/presentation/history/screens/history_screen.dart';
import 'package:tubing_calculator/src/presentation/inventory/pages/inventory_page.dart';
import 'package:tubing_calculator/src/presentation/project/project_management_page.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/screens/cutting_project_list_screen.dart';
import 'package:tubing_calculator/src/presentation/steel_cutting/screens/mobile_steel_project_list_page.dart';
import 'package:tubing_calculator/src/presentation/my_schedule/mobile_my_schedule_page.dart';
import 'package:tubing_calculator/src/presentation/menu/page/home_menu_router.dart';
import 'package:tubing_calculator/src/presentation/menu/page/mobile_loading_screen.dart';
import 'package:tubing_calculator/src/presentation/fabrication/screens/viewer_only_screen.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/layout_board_page.dart'
    show LayoutBoardPage;
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/weekly_report_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/report_tools.dart'
    show
        kWeeklyReportPayload,
        kWeeklyReportPdfPayload,
        kDailyReportPayload,
        recordSeenReminders;
import 'package:tubing_calculator/src/presentation/my_work_logs/screens/work_log_main_screen.dart'
    show WorkLogMainScreen;
import 'package:tubing_calculator/src/presentation/my_work_logs/widgets/work_theme.dart'
    show WorkRoute;

// 알림을 눌렀을 때 화면을 열기 위한 전역 내비게이터.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void _handleNotificationPayload(String? payload) {
  final isDaily = payload == kDailyReportPayload;
  if (!isDaily &&
      payload != kWeeklyReportPayload &&
      payload != kWeeklyReportPdfPayload) {
    return;
  }
  final autoPdf = payload == kWeeklyReportPdfPayload;
  // 앱이 막 켜지는 중일 수 있어 내비게이터가 준비될 때까지 잠깐 기다린다.
  Future<void> tryOpen(int left) async {
    final nav = appNavigatorKey.currentState;
    if (nav != null) {
      if (isDaily) {
        // 오늘 작업 일지를 안 쓴 프로젝트가 하나면 바로 작성 화면까지 간다.
        nav.push(
          WorkRoute(
            builder: (_) => const WorkLogMainScreen(autoWriteReport: true),
          ),
        );
      } else {
        await openWeeklyReportFromNotification(nav, autoPdf: autoPdf);
      }
    } else if (left > 0) {
      await Future.delayed(const Duration(milliseconds: 500));
      await tryOpen(left - 1);
    }
  }

  tryOpen(10);
}

// 🚀 [백그라운드 핸들러]
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("백그라운드 알림 수신: ${message.notification?.title}");
}

// 🚀 로컬 알림 플러그인 전역 변수
late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
late AndroidNotificationChannel channel;
bool isFlutterLocalNotificationsInitialized = false;

// 🚀 로컬 알림 초기화 설정
Future<void> setupFlutterNotifications() async {
  if (isFlutterLocalNotificationsInitialized) return;

  channel = const AndroidNotificationChannel(
    'high_importance_channel',
    '현장 중요 알림',
    description: '자재 발주 및 중요 현장 알림에 사용됩니다.',
    importance: Importance.high,
  );

  flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
      );

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  await flutterLocalNotificationsPlugin.initialize(
    settings: initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      debugPrint("앱 실행 중 포그라운드 알림 터치됨: ${response.payload}");
      if (response.id != null) recordSeenReminders([response.id!]);
      _handleNotificationPayload(response.payload);
    },
  );

  // 앱이 꺼진 상태에서 알림을 눌러 시작한 경우.
  final launch = await flutterLocalNotificationsPlugin
      .getNotificationAppLaunchDetails();
  if (launch?.didNotificationLaunchApp == true) {
    final id = launch?.notificationResponse?.id;
    if (id != null) recordSeenReminders([id]);
    _handleNotificationPayload(launch?.notificationResponse?.payload);
  }

  isFlutterLocalNotificationsInitialized = true;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 화면 그리기 오류와 잡히지 않은 오류를 기록해 둔다(앱 상태 화면에서 본다).
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    recordError('화면 오류', details.exception);
    if (previousOnError != null) {
      previousOnError(details);
    } else {
      FlutterError.presentError(details);
    }
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    recordError('앱 오류', error);
    return false;
  };

  await Hive.initFlutter();
  await Hive.openBox('projectsBox');

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await setupFlutterNotifications();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await initializeDateFormatting('ko_KR', null); // 달력 등 한글 요일/월 이름
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
    _setupBackgroundAndTerminatedMessageListener();
    _handleFCMToken();
    // 카톡 등에서 공유로 받은 도면: 앱이 떠 있을 때 새로 들어오면, 그리고 앱을 켠 뒤
    // 홈 메뉴가 뜨면(로딩 화면이 홈으로 바뀌면서 먼저 띄운 창을 덮지 않게) 가져간다.
    SharedDrawingInbox.listen(_checkSharedDrawing);
    SharedDrawingInbox.homeReady.addListener(_checkSharedDrawing);
  }

  bool _sharedDrawingBusy = false;

  /// 공유로 받은 도면이 있으면 어느 배치도에 깔지 묻고 연다. PDF는 첫 쪽을 사진으로 바꾼다.
  Future<void> _checkSharedDrawing() async {
    if (!SharedDrawingInbox.homeReady.value || _sharedDrawingBusy) return;
    _sharedDrawingBusy = true;
    try {
      // take()는 받아 둔 것을 비우므로 화면이 준비된 뒤에만 가져간다.
      if (appNavigatorKey.currentContext == null) return;
      final d = await SharedDrawingInbox.take();
      if (d == null) return;
      final String? path = await SharedDrawingInbox.toImagePath(d);
      final ctx = appNavigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      if (path == null) {
        ScaffoldMessenger.maybeOf(
          ctx,
        )?.showSnackBar(const SnackBar(content: Text("받은 PDF를 열 수 없습니다.")));
        return;
      }
      unawaited(openSharedDrawing(ctx, path));
    } finally {
      _sharedDrawingBusy = false;
    }
  }

  void _handleFCMToken() async {
    String? token = await FirebaseMessaging.instance.getToken();
    debugPrint("=====================================");
    debugPrint("🔥 내 기기 FCM 토큰: $token");
    debugPrint("=====================================");

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      debugPrint("🔄 FCM 토큰 갱신됨: $newToken");
    });
  }

  void _requestNotificationPermission() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('사용자 알림 권한 상태: ${settings.authorizationStatus}');
    await messaging.subscribeToTopic("field_orders");
  }

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
              icon: '@mipmap/ic_launcher',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
      }
    });
  }

  void _setupBackgroundAndTerminatedMessageListener() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('백그라운드에서 알림 터치 진입: ${message.data}');
    });

    FirebaseMessaging.instance.getInitialMessage().then((
      RemoteMessage? message,
    ) {
      if (message != null) {
        debugPrint('앱 종료 상태에서 알림 터치 진입: ${message.data}');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      // 날짜 선택기·달력 등 기본 위젯 문구를 한국어로(예전엔 Select date/Cancel/OK 영어).
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      // 딥링크 받는 위젯은 화면(route) 밖에 둔다. home에 두면 로딩 화면이 홈으로 바뀔 때
      // 같이 버려져 그 뒤로는 QR 링크가 안 열렸다.
      builder: (context, child) =>
          DeepLinkHandler(child: child ?? const SizedBox()),
      home: const DeviceRouter(),
      routes: {
        // 🚀 [수정] 폴더블 대응: MenuScreen을 바로 고정하지 않고
        // HomeMenuRouter를 거쳐서, 그 순간의 화면 크기(펼침/접힘)에 맞는
        // 홈 화면이 실시간으로 나오게 한다.
        '/menu': (context) => const HomeMenuRouter(),
        '/calculator': (context) => const MainCalculatorScreen(),
        '/marking': (context) => const MarkingPage(startDir: 'RIGHT'),
        '/settings': (context) => const SettingsScreen(),
        '/history': (context) => const HistoryScreen(),
        '/inventory': (context) => const InventoryPage(),
        '/projects': (context) => const ProjectManagementPage(),
        '/cutting': (context) => const CuttingProjectListScreen(),
        '/steel-cutting': (context) => const MobileSteelProjectListPage(),
        '/my-schedule': (context) => const MobileMyScheduleScreen(),
      },
    );
  }
}

// ---------------------------------------------------------
// 🚀 딥링크 핸들러 및 라우터 로직
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
      if (initialUri != null) {
        // 앱을 켜며 받은 링크는 홈 메뉴가 뜬 뒤에 연다. 예전엔 0.5초 뒤 열어서 로딩 화면이
        // 홈으로 바뀌며 열린 화면을 덮어 버렸다.
        _whenHomeReady(() {
          if (!mounted) return;
          if (initialUri.scheme == 'tubingapp' && initialUri.host == 'view') {
            _handleViewerLink(initialUri);
          } else if (initialUri.scheme == 'tubingcalc' &&
              initialUri.host == 'layout') {
            _handleLayoutLink(initialUri);
          }
        });
      }
    } catch (e) {
      debugPrint("초기 링크 로드 에러: $e");
    }

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      if (uri.scheme == 'tubingapp' && uri.host == 'view') {
        _handleViewerLink(uri);
      } else if (uri.scheme == 'tubingcalc' && uri.host == 'layout') {
        _handleLayoutLink(uri);
      }
    });
  }

  void _whenHomeReady(void Function() f) {
    if (SharedDrawingInbox.homeReady.value) {
      f();
      return;
    }
    late VoidCallback l;
    l = () {
      if (!SharedDrawingInbox.homeReady.value) return;
      SharedDrawingInbox.homeReady.removeListener(l);
      f();
    };
    SharedDrawingInbox.homeReady.addListener(l);
  }

  // 🚀 [신규] 배치도 QR 코드 스캔 링크(tubingcalc://layout?project=문서ID)
  // 처리 - 예전엔 이 딥링크를 받는 핸들러가 아예 없어서 QR을 스캔해도
  // 아무 반응이 없었다.
  void _handleLayoutLink(Uri uri) {
    try {
      final String? projectId = uri.queryParameters['project'];
      if (projectId == null || projectId.isEmpty) return;
      if (mounted) {
        appNavigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => LayoutBoardPage(projectId: projectId),
          ),
        );
      }
    } catch (e) {
      debugPrint("배치도 딥링크 처리 에러: $e");
    }
  }

  void _handleViewerLink(Uri uri) {
    try {
      final String proj = uri.queryParameters['p'] ?? 'Unknown';
      final String size = uri.queryParameters['s'] ?? 'Unknown';
      final String compressedBends = uri.queryParameters['b'] ?? '';
      final bool startFit = uri.queryParameters['sf'] == 'true';
      final bool endFit = uri.queryParameters['ef'] == 'true';
      final double tail =
          double.tryParse(uri.queryParameters['t'] ?? '0.0') ?? 0.0;
      final String startDir = uri.queryParameters['d'] ?? 'RIGHT';

      List<Map<String, dynamic>> parsedBends = [];
      if (compressedBends.isNotEmpty) {
        List<String> segments = compressedBends.split('-');
        for (String seg in segments) {
          List<String> parts = seg.split('_');
          // 🚀 [수정] 마킹값(4번째 항목)이 포함된 최신 압축 포맷도 인식하도록 >= 3으로 완화
          if (parts.length >= 3) {
            double a = double.tryParse(parts[1]) ?? 0.0;
            parsedBends.add({
              'length': double.tryParse(parts[0]) ?? 0.0,
              'angle': a,
              'rotation': double.tryParse(parts[2]) ?? 0.0,
              'is_straight': a == 0.0,
              'mark': parts.length >= 4
                  ? (double.tryParse(parts[3]) ?? 0.0)
                  : 0.0,
            });
          }
        }
      }

      if (mounted) {
        appNavigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => ViewerOnlyScreen(
              project: proj,
              pipeSize: size,
              bendList: parsedBends,
              startFit: startFit,
              endFit: endFit,
              tailLength: tail,
              startDir: startDir,
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
    // 홈 화면(HomeMenuRouter)과 같은 기준(짧은 변 600). 예전엔 가로로 든 폰이 태블릿
    // 로딩 화면으로 가서 자동 로그인 없이 "로그인 필요"로 홈에 들어갔다.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.biggest.shortestSide < 600) {
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
