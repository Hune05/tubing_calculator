import 'package:tubing_calculator/src/presentation/common/quick_tool_bar.dart';
import 'package:tubing_calculator/src/presentation/equipment/equipment_model.dart' show LedgerView;
import 'package:tubing_calculator/src/presentation/equipment/equipment_pages.dart' show EquipmentLedgerPage;
import 'package:tubing_calculator/src/presentation/attendance/attendance_reminder.dart' show kClockOutPayload;
import 'package:tubing_calculator/src/presentation/attendance/pages/attendance_page.dart' show AttendancePage;
import 'package:tubing_calculator/src/presentation/equipment/equipment_reminders.dart' show kEquipPayloadPrefix;
import 'package:tubing_calculator/src/core/theme/app_theme.dart';
import 'package:tubing_calculator/src/core/utils/home_widget_sync.dart';
import 'package:tubing_calculator/src/core/theme/field_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:ui' show PlatformDispatcher;
import 'package:tubing_calculator/src/core/utils/error_log.dart';
import 'package:tubing_calculator/src/core/utils/startup_guard.dart';
import 'package:tubing_calculator/src/data/repositories/work_project_repository.dart'
    show openLegacyHiveIfNeeded;
import 'package:tubing_calculator/src/core/common_widgets/app_frame.dart';
import 'package:tubing_calculator/src/core/common_widgets/text_fields_traversal.dart';

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
import 'package:tubing_calculator/src/presentation/steel_cutting/screens/mobile_steel_project_list_page.dart';
import 'package:tubing_calculator/src/presentation/my_schedule/mobile_my_schedule_page.dart';
import 'package:tubing_calculator/src/presentation/my_schedule/schedule_reminders.dart'
    show parsePersonalReminderPayload;
import 'package:tubing_calculator/src/presentation/menu/page/home_menu_router.dart';
import 'package:tubing_calculator/src/presentation/menu/page/mobile_loading_screen.dart';
import 'package:tubing_calculator/src/presentation/fabrication/fab_qr.dart';
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
import 'package:tubing_calculator/src/presentation/drawing_viewer/drawing_library_page.dart' show importAndOpenDrawing;
import 'package:tubing_calculator/src/presentation/my_work_logs/widgets/work_theme.dart'
    show WorkRoute;
import 'package:tubing_calculator/src/presentation/profile/profile_tools.dart'
    show ensureSignedIn;
import 'package:tubing_calculator/src/presentation/reference/page/tube_reference_page.dart'
    show TubeReferencePage, kRefKecTabIndex;
import 'package:tubing_calculator/src/presentation/pressure_test/pressure_test_page.dart'
    show PressureTestPage, kPtRecordTabIndex;
import 'package:tubing_calculator/src/presentation/pressure_test/hold_alarm.dart'
    show kPtHoldPayload;

// 알림을 눌렀을 때 화면을 열기 위한 전역 내비게이터.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// 알림에서 열 화면. 개인 일정이면 내 일정의 그 날짜, 서버 알림(일정·이슈·일지)이면 작업 일지,
/// 전기 기준 새 개정 공고면 현장 자료의 전기 기준 탭, 압력 시험 유지시간 완료면 압력 시험의 시험 기록 탭.
/// 없으면 null(주간·일일 보고는 아래에서 따로).
Route<void>? routeForNotification(String? payload, Map<String, dynamic> data) {
  final sched = parsePersonalReminderPayload(payload);
  if (sched != null) {
    return MaterialPageRoute<void>(
      builder: (_) => MobileMyScheduleScreen(initialDate: sched.date),
    );
  }
  // 공구 점검 기한 알림: 기한 지남·임박 장비 목록을 연다.
  if (payload != null && payload.startsWith(kEquipPayloadPrefix)) {
    return MaterialPageRoute<void>(
      builder: (_) => const EquipmentLedgerPage(initialView: LedgerView.due),
    );
  }
  // 퇴근 깜빡 알림(예약 918500, attendance_reminder.dart): 근태 화면을 연다(찍는 것은 사용자가 누른다).
  if (payload == kClockOutPayload) {
    return MaterialPageRoute<void>(builder: (_) => const AttendancePage());
  }
  // 압력 시험 유지시간 완료(폰 예약 알림 918400, hold_alarm.dart).
  if (payload == kPtHoldPayload) {
    return MaterialPageRoute<void>(
      builder: (_) => const PressureTestPage(initialTab: kPtRecordTabIndex),
    );
  }
  if (data['open'] == 'work_logs') {
    return WorkRoute(builder: (_) => const WorkLogMainScreen());
  }
  // 전기 기준(KEC) 새 개정 공고(서버 함수 checkKecNotice).
  if (data['open'] == 'reference_kec') {
    return MaterialPageRoute<void>(
      builder: (_) => const TubeReferencePage(initialTab: kRefKecTabIndex),
    );
  }
  return null;
}

/// 홈이 뜬 뒤에(늦어도 [maxWait] 뒤에) [f]를 부른다. 앱이 꺼진 상태에서 알림을 눌러 켜면 로딩 화면이
/// 1.5초 뒤 맨 위 화면을 홈으로 바꾸는데, 그 전에 알림 화면을 올리면 알림 화면이 홈으로 덮였다(10-07).
void _afterHomeReady(void Function() f, {Duration maxWait = const Duration(seconds: 12)}) {
  if (SharedDrawingInbox.homeReady.value) {
    f();
    return;
  }
  var done = false;
  late VoidCallback l;
  void run() {
    if (done) return;
    done = true;
    SharedDrawingInbox.homeReady.removeListener(l);
    f();
  }

  l = () {
    if (SharedDrawingInbox.homeReady.value) run();
  };
  SharedDrawingInbox.homeReady.addListener(l);
  Future.delayed(maxWait, run);
}

void _openRouteWhenReady(Route<void> route, [int left = 10]) {
  _afterHomeReady(() => _pushWhenNavReady(route, left));
}

void _pushWhenNavReady(Route<void> route, int left) {
  final nav = appNavigatorKey.currentState;
  if (nav != null) {
    nav.push(route);
  } else if (left > 0) {
    Future.delayed(
      const Duration(milliseconds: 500),
      () => _pushWhenNavReady(route, left - 1),
    );
  }
}

void _handleNotificationPayload(String? payload) {
  // 압력 시험 화면이 이미 열려 있으면(앱 실행 중) 하나 더 열지 않고 그 화면의 시험 기록 탭으로 간다.
  if (payload == kPtHoldPayload &&
      PressureTestPage.revealOpen(kPtRecordTabIndex)) {
    return;
  }
  final route = routeForNotification(payload, const {});
  if (route != null) {
    _openRouteWhenReady(route);
    return;
  }
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

  _afterHomeReady(() => tryOpen(10));
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
    description: '일정·이슈·작업 일지 알림에 사용됩니다.',
    importance: Importance.high,
  );

  flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  if (pushMessagingSupported()) {
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  final InitializationSettings initializationSettings =
      notificationInitSettings();

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

  // 옛 Hive 상자: 서버로 옮기기가 끝난 폰은 열지 않고, 파일이 깨져도 앱은 켜진다(10-09).
  await startupStep(
    '옛 저장소',
    openLegacyHiveIfNeeded,
    timeout: const Duration(seconds: 3),
  );

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (pushMessagingSupported()) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }
  // 알림 준비가 실패해도(윈도우 PC 등) 앱은 켜진다.
  await startupStep('알림 준비', setupFlutterNotifications);

  // 상태 표시줄을 보이게 둔다(현장 탭만 몰입 모드). 화면은 AppFrame이 그 밑으로 안 들어가게 한다.
  SystemChrome.setEnabledSystemUIMode(kAppSystemUiMode);
  await initializeDateFormatting('ko_KR', null); // 달력 등 한글 요일/월 이름
  await FieldColors.load(); // 현장 보기(보통·햇빛·야간)
  // "이름만 넣고 시작"한 사람도 uid가 있게 익명 로그인을 뒤에서 시도한다(이미 로그인했으면
  // 그대로). 통신이 없거나 콘솔에서 익명 로그인이 꺼져 있으면 조용히 넘어간다.
  unawaited(ensureSignedIn());
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
    // 서버 알림은 안드로이드·iOS·macOS에서만(윈도우 PC는 지원하지 않아 오류가 난다).
    if (pushMessagingSupported()) {
      _requestNotificationPermission();
      _setupForegroundMessageListener();
      _setupBackgroundAndTerminatedMessageListener();
      // 알림 토큰은 로딩 화면에서 이름 문서에 올린다(ProfileStore.saveToken). 10-09: 여기서
      // 토큰을 로그에 찍던 것은 뺐다(통신 없을 때 getToken 오류가 앱 오류 기록에 쌓였다).
    }
    // 카톡 등에서 공유로 받은 도면: 앱이 떠 있을 때 새로 들어오면, 그리고 앱을 켠 뒤
    // 홈 메뉴가 뜨면(로딩 화면이 홈으로 바뀌면서 먼저 띄운 창을 덮지 않게) 가져간다.
    SharedDrawingInbox.listen(_checkSharedDrawing);
    SharedDrawingInbox.homeReady.addListener(_checkSharedDrawing);
    // 홈 화면 위젯·위젯 알림을 눌러 열렸을 때: 홈 메뉴가 그 동작을 지금 화면 위에 연다.
    // 10-07: 예전에는 열려 있던 화면을 모두 닫아(popUntil), 쓰던 일지 같은 입력이 묻지도 않고 사라졌다.
    HomeWidgetSync.init(onReceived: () {});
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
      // DXF·DWG는 배치도에 못 까니 도면 보기로 바로 연다.
      if (d.isCad) {
        final ctx0 = appNavigatorKey.currentContext;
        if (ctx0 != null && ctx0.mounted) unawaited(importAndOpenDrawing(ctx0, d.path, name: d.name.isEmpty ? null : d.name));
        return;
      }
      final String? path = await SharedDrawingInbox.toImagePath(d);
      final ctx = appNavigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      if (path == null) {
        ScaffoldMessenger.maybeOf(
          ctx,
        )?.showSnackBar(const SnackBar(content: Text("받은 PDF를 열 수 없습니다.")));
        return;
      }
      unawaited(openSharedDrawing(ctx, path, originalPath: d.path, originalName: d.name.isEmpty ? null : d.name));
    } finally {
      _sharedDrawingBusy = false;
    }
  }

  void _requestNotificationPermission() async {
    // 🚀 [고침] 알림 권한은 앱을 켤 때 묻지 않고, 알림을 켜는 순간에 묻는다
    // (reminder_tools.dart ensureNotificationPermission).
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    // 발주 기능은 지웠다. 예전에 구독한 폰도 발주 알림 주제에서 빠진다.
    // 통신이 없으면 실패하는데, 다음에 켤 때 다시 하면 되니 조용히 넘어간다.
    try {
      await messaging.unsubscribeFromTopic("field_orders");
    } catch (_) {}
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
              icon: '@drawable/ic_stat_notify', // 흰 선 아이콘(색 아이콘은 흰 네모로 보였다)
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
      }
    });
  }

  void _setupBackgroundAndTerminatedMessageListener() {
    // 서버 알림을 누르면 그 알림이 가리키는 화면(작업 일지)을 연다(예전엔 글만 찍었다).
    void open(RemoteMessage message) {
      final route = routeForNotification(null, message.data);
      if (route != null) _openRouteWhenReady(route);
    }

    FirebaseMessaging.onMessageOpenedApp.listen(open);
    FirebaseMessaging.instance.getInitialMessage().then((
      RemoteMessage? message,
    ) {
      if (message != null) open(message);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      // 빠른 도구 막대가 지금 화면이 창·시트가 아닌지 알 수 있게 경로 변화를 지켜본다.
      navigatorObservers: [QuickBarGate.tracker],
      debugShowCheckedModeBanner: false,
      // 날짜 선택기·달력 등 기본 위젯 문구를 한국어로(예전엔 Select date/Cancel/OK 영어).
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildAppTheme(),
      // 딥링크 받는 위젯은 화면(route) 밖에 둔다. home에 두면 로딩 화면이 홈으로 바뀔 때
      // 같이 버려져 그 뒤로는 QR 링크가 안 열렸다.
      // 현장 보기(햇빛·야간)를 바꾸면 FieldViewHost가 화면을 모두 다시 그린다.
      // 키보드 "다음"은 글자 칸끼리만 옮겨 간다("?" 도움말·칩을 건너뜀). 모든 화면에 걸린다.
      builder: (context, child) => FocusTraversalGroup(
        policy: TextFieldsOnlyTraversalPolicy(),
        child: FieldViewHost(
          child: AppFrame(
            child: DeepLinkHandler(
              // 빠른 도구 막대: 모든 화면에서 옆 손잡이로 계산기 같은 도구를 바로 연다.
              child: GlobalQuickToolBar(
                navigatorKey: appNavigatorKey,
                child: child ?? const SizedBox(),
              ),
            ),
          ),
        ),
      ),
      home: const MobileLoadingScreen(),
      routes: {
        // 옛 태블릿(PC) 화면 경로는 10-08에 지웠다. 홈은 HomeMenuRouter(폰 메뉴 하나).
        '/menu': (context) => const HomeMenuRouter(),
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

  // 도면 QR은 바로 열지 않고 규격·총 길이를 먼저 보여 준 뒤 연다(fab_qr.dart).
  void _handleViewerLink(Uri uri) {
    try {
      // 확인 창은 Navigator 안쪽 context가 있어야 뜬다.
      final ctx = appNavigatorKey.currentState?.overlay?.context;
      if (!mounted || ctx == null) return;
      FabQr.openWithConfirm(ctx, uri.toString());
    } catch (e) {
      debugPrint("딥링크 파싱 및 뷰어 연결 에러: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

// (2026-09-29) DeviceRouter·LoadingScreen(태블릿용 "TAP TO START" 화면)은 화면 구성을
// 폰 화면 하나로 통일하면서 없앴다. 이제 어떤 화면 크기든 MobileLoadingScreen(자동 로그인)을 쓴다.
