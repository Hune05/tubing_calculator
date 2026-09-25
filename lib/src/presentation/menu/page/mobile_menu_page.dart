import '../../my_work_logs/widgets/work_theme.dart';
import 'package:tubing_calculator/src/presentation/common/app_icons.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geocoding/geocoding.dart';

// 🚀 [수정됨] 단일 설정 페이지 대신 통합 네비게이션 페이지 임포트
// (실제 파일 경로에 맞게 수정해 주세요)
import 'package:tubing_calculator/src/presentation/conduit/screens/main_navigation_page.dart';

// 🚀 1. 현장 작업 페이지들 임포트
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_remote_page.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_calculator_page.dart';
import 'package:tubing_calculator/src/presentation/fabrication/screens/qr_scanner_page.dart';
import 'package:tubing_calculator/src/presentation/fabrication/screens/viewer_only_screen.dart';
import 'package:tubing_calculator/src/presentation/reference/page/tube_reference_page.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/screens/mobile_cutting_project_list_page.dart';
import 'package:tubing_calculator/src/presentation/steel_cutting/screens/mobile_steel_project_list_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/layout_board_project_list_page.dart';

// 🚀 2. 자재 관리 페이지들 임포트
import 'package:tubing_calculator/src/presentation/inventory/pages/mobile_inventory_login.dart';
import 'package:tubing_calculator/src/presentation/inventory/pages/mobile_inventory_status_page.dart';

// 🚀 3. 프로필 및 소통 페이지 임포트
import 'package:tubing_calculator/src/presentation/profile/pages/mobile_profile_page.dart';

// 🚀 4. 프로젝트 관리 페이지 임포트
import 'package:tubing_calculator/src/presentation/my_work_logs/screens/work_log_main_screen.dart';
import 'package:tubing_calculator/src/presentation/my_schedule/mobile_my_schedule_page.dart';
import 'package:tubing_calculator/src/presentation/my_schedule/schedule_reminders.dart'
    show rescheduleDriftingMonthlyReminders;

// 🚀 6. 사내 일정 관리 캘린더 페이지 임포트

// 🚀 7. 신규 알림 내역 페이지 임포트
import 'package:tubing_calculator/src/presentation/notification/pages/mobile_notification_page.dart';
import 'package:tubing_calculator/src/presentation/field_tools/level_page.dart';
import 'package:tubing_calculator/src/presentation/field_tools/protractor_page.dart';

const Color tossBlue = Color(0xFF3182F6);
const Color purpleBadge = Color(0xFF8A2BE2);
const Color slate900 = Color(0xFF191F28);
const Color slate600 = Color(0xFF8B95A1);
const Color slate100 = Color(0xFFF2F4F6);
const Color pureWhite = Color(0xFFFFFFFF);
const Color warningRed = Color(0xFFF04438);
const Color makitaTeal = Color(0xFF007580);

class MobileMenuPage extends StatefulWidget {
  final String currentWorker;
  final bool isAdmin;

  const MobileMenuPage({
    super.key,
    required this.currentWorker,
    this.isAdmin = false,
  });

  @override
  State<MobileMenuPage> createState() => _MobileMenuPageState();
}

class _MobileMenuPageState extends State<MobileMenuPage>
    with WidgetsBindingObserver {
  // 🚀 [통신 없는 현장] 날씨를 못 불러왔는지. 못 불러오면 "동기화 중..."에 머물지 않고
  // 다시 부를 수 있게 알려 준다.
  bool _weatherFailed = false;
  // 🚀 [신규] "내 일정 관리" 메뉴 버튼에 "오늘 N건" 배지를 보여주기 위한
  // 오늘 미완료 일정 개수 - 프로젝트 일정 + 개인 일정(반복 포함)을 합산.
  int? _todayScheduleCount;

  // 🚀 날씨 상세 데이터 상태 관리
  String _weatherDesc = "확인 중";
  String _pmState = "확인 중";
  String _currentTemp = "-";
  // 🚀 [날씨 고도화] GPS로 위치를 못 가져올 때(권한 거부, 위치 서비스
  // 꺼짐 등)를 대비한 기본 지역명 - 원래 하드코딩돼 있던 부산을 그대로
  // 폴백 값으로 남겨뒀다.
  String _cityName = "부산";
  bool _rainExpected = false;
  String _rainStart = "";
  String _rainEnd = "";
  double _totalRain = 0.0;
  bool _isWeatherLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchDetailedWeather();
    _loadTodayScheduleCount();
    // 격주·평일·반복 끝이 있는 일정 알림은 한 번씩만 잡혀 있어서 다음 회차를 다시 잡아야
    // 한다. 예전엔 "내 일정" 화면을 열 때만 잡아서, 며칠 안 열면 알림이 끊겼다.
    // 앱을 켤 때 한 번(기다리지 않음, 통신이 없으면 폰 캐시로).
    if (!_remindersRescheduledThisRun) {
      _remindersRescheduledThisRun = true;
      rescheduleDriftingMonthlyReminders();
    }
  }

  static bool _remindersRescheduledThisRun = false;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 앱을 다시 볼 때 날씨를 못 불러왔으면 한 번 더 시도한다(현장을 나와 통신이 잡히면
  // 대개 이때 갱신된다). 주기적으로 계속 부르지는 않는다 — 배터리와 데이터만 먹는다.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _weatherFailed) {
      _fetchDetailedWeather();
    }
  }

  Future<void> _loadTodayScheduleCount() async {
    final count = await fetchTodayScheduleCount(widget.currentWorker);
    if (mounted) setState(() => _todayScheduleCount = count);
  }

  // 🚀 날씨 상태 단순화 (맑음, 흐림, 비, 눈)
  String _simplifyWeather(String mainCondition) {
    switch (mainCondition) {
      case 'Clear':
        return '맑음';
      case 'Clouds':
        return '흐림';
      case 'Rain':
      case 'Drizzle':
      case 'Thunderstorm':
        return '비';
      case 'Snow':
        return '눈';
      default:
        return '흐림';
    }
  }

  // 🚀 [날씨 고도화] 위치 권한을 확인/요청하고 현재 위치를 가져온다.
  // 위치 서비스가 꺼져 있거나, 권한이 거부/영구거부됐거나, 어떤
  // 이유로든 실패하면 null을 돌려줘서 호출한 쪽이 기존 하드코딩된
  // 부산 좌표로 조용히 폴백하게 한다 - 위치를 못 가져왔다고 날씨
  // 기능 자체가 죽으면 안 되니까.
  // 🚀 [고침] 예전에는 홈이 뜨자마자 위치 권한을 물었다(무엇에 쓰는지 알기 전이라
  // 거절하기 쉽고, 거절하면 다시 안 물어 준다). 이제 켤 때는 이미 허용된 경우만 쓰고,
  // 날씨 카드를 누를 때([ask]) 묻는다. 날씨에는 대략 위치면 충분하다(건물 안에서
  // 정밀 GPS를 기다리다 8초를 다 쓰던 것).
  Future<Position?> _determinePosition({bool ask = false}) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && ask) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (e) {
      return null;
    }
  }

  // 🚀 [날씨 위치 버그 수정] OpenWeatherMap의 지역명(weather API의 "name"
  // 필드)은 자체 도시 목록 중 좌표에서 가장 가까운 항목을 고르는 방식이라,
  // "부산 지사동"처럼 실제로는 잘 안 쓰는 동네 이름이 나올 수 있었다(GPS
  // 좌표 자체는 맞아도, OWM 도시 목록의 매칭 결과가 지나치게 세분화됨).
  // 기기 자체 지오코더(Android는 Google 지오코딩 서비스 이용)로 "시/도 +
  // 구/군" 수준의 더 알아보기 쉬운 이름을 만들고, 실패하면 OWM 이름으로
  // 폴백한다.
  Future<String?> _resolveCityLabel(Position? position, String? owmName) async {
    if (position != null) {
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final String city = (p.locality?.isNotEmpty ?? false)
              ? p.locality!
              : (p.administrativeArea ?? '');
          final String district = (p.subLocality?.isNotEmpty ?? false)
              ? p.subLocality!
              : (p.subAdministrativeArea ?? '');
          final parts = <String>{
            city,
            district,
          }.where((s) => s.isNotEmpty).toList();
          if (parts.isNotEmpty) return parts.join(' ');
        }
      } catch (e) {
        // 기기 지오코더가 없거나(플레이 서비스 미탑재 등) 실패하면
        // 아래 OWM 이름으로 조용히 폴백한다.
      }
    }
    return (owmName != null && owmName.isNotEmpty) ? owmName : null;
  }

  // 🚀 API 3개(현재날씨, 대기질, 일기예보)를 동시에 불러와 분석
  Future<void> _fetchDetailedWeather() async {
    try {
      const String apiKey = 'ce796b79713bbdf70ec6a7cfb98f2b11';
      // 🚀 [날씨 고도화] 원래 부산 좌표로 고정돼 있던 걸, GPS로 가져온
      // 현재 위치가 있으면 그걸 쓰고 없으면 부산으로 폴백하도록 바꿨다 -
      // 현장을 옮겨 다니는 작업 특성상 지금 있는 곳 날씨가 더 쓸모 있다.
      final position = await _determinePosition();
      final double lat = position?.latitude ?? 35.1795;
      final double lon = position?.longitude ?? 129.0756; // 부산 좌표(폴백)

      final weatherUrl = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$apiKey&units=metric&lang=kr',
      );
      final airUrl = Uri.parse(
        'https://api.openweathermap.org/data/2.5/air_pollution?lat=$lat&lon=$lon&appid=$apiKey',
      );
      final forecastUrl = Uri.parse(
        'https://api.openweathermap.org/data/2.5/forecast?lat=$lat&lon=$lon&appid=$apiKey&units=metric&lang=kr',
      );

      // 통신이 없으면 응답이 오지 않으므로 오래 기다리지 않는다.
      final responses = await Future.wait([
        http.get(weatherUrl),
        http.get(airUrl),
        http.get(forecastUrl),
      ]).timeout(const Duration(seconds: 8));

      if (responses[0].statusCode == 200 &&
          responses[1].statusCode == 200 &&
          responses[2].statusCode == 200) {
        final weatherData = jsonDecode(responses[0].body);
        final airData = jsonDecode(responses[1].body);
        final forecastData = jsonDecode(responses[2].body);

        String mainCondition = weatherData['weather'][0]['main'];
        String desc = _simplifyWeather(mainCondition);
        // 기온이 20처럼 딱 떨어지면 정수로 와서 형이 안 맞아 실패로 보였다.
        double temp = (weatherData['main']['temp'] as num).toDouble();

        int aqi = (airData['list'][0]['main']['aqi'] as num).toInt();
        List<String> pmLabels = ['알 수 없음', '좋음', '보통', '나쁨', '매우 나쁨', '위험'];
        String pm = (aqi > 0 && aqi <= 5) ? pmLabels[aqi] : '알 수 없음';

        DateTime now = DateTime.now();
        DateTime endCheck = now.add(const Duration(hours: 24));
        DateTime? firstRain;
        DateTime? lastRain;
        double rainSum = 0.0;

        for (var item in forecastData['list']) {
          DateTime dt = DateTime.fromMillisecondsSinceEpoch(item['dt'] * 1000);
          if (dt.isAfter(endCheck)) break;

          if (item['rain'] != null && item['rain']['3h'] != null) {
            firstRain ??= dt;
            lastRain = dt;
            rainSum += (item['rain']['3h'] as num).toDouble();
          }
        }

        // 🚀 [날씨 위치 버그 수정] 기기 지오코더로 먼저 시도하고, 실패하면
        // OWM의 지역명으로 폴백한다 (자세한 이유는 _resolveCityLabel 참고).
        final String? resolvedCity = await _resolveCityLabel(
          position,
          weatherData['name'] as String?,
        );

        if (mounted) {
          setState(() {
            if (resolvedCity != null && resolvedCity.isNotEmpty) {
              _cityName = resolvedCity;
            }
            _weatherDesc = desc;
            _currentTemp = temp.toStringAsFixed(1);
            _pmState = pm;
            if (rainSum > 0 && firstRain != null && lastRain != null) {
              _rainExpected = true;
              _rainStart = "${firstRain.hour}";
              _rainEnd = "${lastRain.hour}";
              _totalRain = rainSum;
            } else {
              _rainExpected = false;
            }
            _isWeatherLoaded = true;
          });
        }
      } else {
        _setFallback();
      }
    } catch (e) {
      _setFallback();
    }
  }

  void _setFallback() {
    if (mounted) {
      setState(() {
        _isWeatherLoaded = true;
        _weatherFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pureWhite,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _fetchDetailedWeather,
          color: tossBlue,
          backgroundColor: pureWhite,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(context),
                _buildSmartHeader(context),
                const SizedBox(height: 16),

                const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 8.0,
                  ),
                  child: Text(
                    "프로젝트 관리",
                    style: TextStyle(
                      color: slate600,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _buildMenuButton(
                  context: context,
                  title: "내 프로젝트",
                  subtitle: "개인 작업 일지 · 이슈 리스트 및 자재 기록",
                  icon: AppGlyph.project,
                  iconColor: slate900,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      WorkRoute(
                        builder: (context) => const WorkLogMainScreen(),
                      ),
                    ).then((_) => _loadTodayScheduleCount());
                  },
                ),
                _buildMenuButton(
                  context: context,
                  title: "내 일정 관리",
                  subtitle: "프로젝트 일정 통합 + 개인 일정 · 반복 · 알림",
                  icon: AppGlyph.schedule,
                  iconColor: makitaTeal,
                  badgeText:
                      (_todayScheduleCount != null && _todayScheduleCount! > 0)
                      ? "오늘 $_todayScheduleCount건"
                      : null,
                  badgeColor: makitaTeal,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MobileMyScheduleScreen(
                          currentWorker: widget.currentWorker,
                        ),
                      ),
                    ).then((_) => _loadTodayScheduleCount());
                  },
                ),

                const SizedBox(height: 32),
                const Divider(height: 1, color: slate100, thickness: 8),
                const SizedBox(height: 24),

                const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 8.0,
                  ),
                  child: Text(
                    "현장 작업",
                    style: TextStyle(
                      color: slate600,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                // 🚀 [재배치] 사용자 요청으로 "계산기류"를 전부 위쪽에
                // 모으고, 참고자료(벤딩 실무 가이드)는 맨 아래로 내렸다.
                // 예전엔 계산기와 QR스캔/리모컨/참고자료가 뒤섞여 있어서
                // 어디까지가 계산기고 어디부터가 도구/자료인지 한눈에
                // 안 들어왔다.

                // --- 계산기 3종 ---
                _buildMenuButton(
                  context: context,
                  title: "전선관 벤딩 마킹 계산기",
                  subtitle: "장비 프로필 설정 · 마킹 뷰어",
                  icon: AppGlyph.conduitBend,
                  iconColor: Colors.blueGrey, // 메인 기능이므로 파란색 강조
                  badgeText: "Smart",
                  badgeColor: Colors.blueGrey,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ConduitMainNavigation(),
                      ),
                    );
                  },
                ),

                _buildMenuButton(
                  context: context,
                  title: "벤딩 마킹 계산기",
                  subtitle: "스마트폰용 · 단계별 치수 입력",
                  icon: AppGlyph.tubeBend,
                  iconColor: makitaTeal,
                  badgeText: "Main",
                  badgeColor: makitaTeal,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MobileCalculatorPage(),
                      ),
                    );
                  },
                ),

                _buildMenuButton(
                  context: context,
                  title: "튜브 컷팅 계산기",
                  subtitle: "피팅 삽입깊이 차감 · 절단 자재 기록",
                  icon: AppGlyph.tubeCut,
                  iconColor: makitaTeal,
                  badgeText: "New",
                  badgeColor: makitaTeal,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const MobileCuttingProjectListPage(),
                      ),
                    );
                  },
                ),

                _buildMenuButton(
                  context: context,
                  title: "형강 컷팅 (찬넬/앵글)",
                  subtitle: "라인 조립 없이 규격·길이만으로 재단 계획·지시서 출력",
                  icon: AppGlyph.steel,
                  iconColor: makitaTeal,
                  badgeText: "New",
                  badgeColor: makitaTeal,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const MobileSteelProjectListPage(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),
                const Divider(height: 1, color: slate100, thickness: 4),
                const SizedBox(height: 12),

                // --- 작업 도구 (계산기 보조) ---
                _buildMenuButton(
                  context: context,
                  title: "작업 배치도",
                  subtitle: "캐비닛 중판 레이아웃 및 튜빙/결선 스케치",
                  icon: AppGlyph.layout,
                  iconColor: slate900,
                  badgeText: "New",
                  badgeColor: slate900,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    // 🚀 [수정] 예전엔 여기서 바로 빈 도면을 열어서, 저장해둔
                    // 배치도를 다시 불러볼 방법이 없었다(저장은 Firestore에
                    // 되는데 불러오는 화면 자체가 없었음). 이제 목록을 먼저
                    // 보여주고, 거기서 기존 도면을 열거나 새로 시작한다.
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const LayoutBoardProjectListPage(),
                      ),
                    );
                  },
                ),

                _buildMenuButton(
                  context: context,
                  title: "현장 도면 스캔 (QR)",
                  subtitle: "오프라인 지시서 스캔 후 3D 뷰어 실행",
                  icon: AppGlyph.scan,
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    final String? scannedData = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const QRScannerPage(),
                      ),
                    );

                    if (scannedData != null && context.mounted) {
                      try {
                        Uri uri = Uri.parse(scannedData);
                        String project =
                            uri.queryParameters['p'] ?? "Scanned Project";
                        String pipeSize = uri.queryParameters['s'] ?? "1/4\"";
                        String bendsStr = uri.queryParameters['b'] ?? "";
                        bool startFit = uri.queryParameters['sf'] == 'true';
                        bool endFit = uri.queryParameters['ef'] == 'true';
                        double tail =
                            double.tryParse(
                              uri.queryParameters['t'] ?? '0.0',
                            ) ??
                            0.0;
                        String startDir = uri.queryParameters['d'] ?? 'RIGHT';
                        List<Map<String, double>> parsedBends = [];

                        if (bendsStr.isNotEmpty) {
                          final parts = bendsStr.split('-');
                          for (var part in parts) {
                            final vals = part.split('_');
                            if (vals.length >= 3) {
                              parsedBends.add({
                                'length': double.tryParse(vals[0]) ?? 0.0,
                                'angle': double.tryParse(vals[1]) ?? 0.0,
                                'rotation': double.tryParse(vals[2]) ?? 0.0,
                                'mark': vals.length >= 4
                                    ? (double.tryParse(vals[3]) ?? 0.0)
                                    : 0.0,
                              });
                            }
                          }
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ViewerOnlyScreen(
                              project: project,
                              pipeSize: pipeSize,
                              bendList: parsedBends,
                              startFit: startFit,
                              endFit: endFit,
                              tailLength: tail,
                              startDir: startDir,
                            ),
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              "QR 코드를 읽을 수 없습니다.",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            backgroundColor: Colors.redAccent.shade400,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                ),
                _buildMenuButton(
                  context: context,
                  title: "벤딩 리모컨",
                  subtitle: "수치 전송용 리모컨 (스마트폰 권장)",
                  icon: AppGlyph.remote,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MobileRemotePage(),
                      ),
                    );
                  },
                ),
                _buildMenuButton(
                  context: context,
                  title: "수평계",
                  subtitle: "기포 수평계 · 배관 구배(%·mm/m) · 영점 맞추기",
                  icon: AppGlyph.level,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LevelPage(),
                      ),
                    );
                  },
                ),
                _buildMenuButton(
                  context: context,
                  title: "각도기",
                  subtitle: "벤딩 각도 재기 · 화면 각도기",
                  icon: AppGlyph.protractor,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProtractorPage(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),
                const Divider(height: 1, color: slate100, thickness: 4),
                const SizedBox(height: 12),

                // --- 참고 자료 (맨 아래) ---
                _buildMenuButton(
                  context: context,
                  title: "현장 자료·장비 사용법",
                  subtitle: "튜브·전선관·형강 규격표, 벤더·톱 사용법, 앱 사용법",
                  icon: AppGlyph.tubeSpec,
                  iconColor: slate900,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TubeReferencePage(),
                      ),
                    );
                  },
                ),

                // 🚀 [되살림] "자재 관리"는 다시 쓰기로 해서 메뉴에 꺼냈다(2026-09-20).
                // "현장 소통(메시지/일정)"과 "공용 차량 및 장비"는 계속 숨겨 둔다 —
                // 페이지와 import는 남아 있으니 필요해지면 같은 방식으로 붙이면 된다.
                const SizedBox(height: 32),
                const Divider(height: 1, color: slate100, thickness: 8),
                const SizedBox(height: 24),

                const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 8.0,
                  ),
                  child: Text(
                    "자재 관리",
                    style: TextStyle(
                      color: slate600,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _buildMenuButton(
                  context: context,
                  title: "자재 현황",
                  subtitle: "지금 재고 확인 및 현장 자재 입출고 처리",
                  icon: AppGlyph.stock,
                  iconColor: slate900,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MobileInventoryStatusPage(
                          workerName: widget.currentWorker,
                        ),
                      ),
                    );
                  },
                ),
                _buildMenuButton(
                  context: context,
                  title: "자재 통합 관리",
                  subtitle: "재고조사 · 새 자재 등록 및 삭제",
                  icon: AppGlyph.stockAdmin,
                  iconColor: slate900,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const MobileInventoryLoginScreen(),
                      ),
                    );
                  },
                ),
                // 🚀 [정리] "자재 발주 및 현황"과 "발주 의뢰 내역"은 메뉴에서 뺐다
                // (2026-09-20). 발주 기록이 한 건도 없고, 발주를 넣으면 지금
                // 숨겨 둔 현장 소통(채팅)으로 글이 가는 반쪽 구조였다. 화면
                // 파일(발주·발주 기록·채팅·차량 관리자)은 2026-09-23에 지웠다.
                // 필요해지면 git 기록(3bef015 이전)에서 꺼내 여기에 붙이면 된다.
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🚀 [홈 화면 레이아웃 고도화] 예전엔 날씨/공지 카드와 알림 종·프로필
  // 아이콘이 한 Row 안에 같이 있어서, 아이콘들이 마치 날씨 카드에 딸린
  // 부속물처럼 어색하게 붙어 있었다(날씨가 화면에서 제일 위 - 가장
  // 눈에 띄는 자리를 차지하는 것도 어색했음). 아이콘은 화면 맨 위 독립된
  // 얇은 상단바로 분리하고, 날씨/공지/차량 카드는 그 아래 자기만의
  // 줄로 내렸다.
  Widget _buildTopBar(BuildContext context) {
    const weekdaysKo = ['월', '화', '수', '목', '금', '토', '일'];
    final now = DateTime.now();
    final dateStr =
        "${now.month}월 ${now.day}일 (${weekdaysKo[now.weekday - 1]})";
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            dateStr,
            style: const TextStyle(
              color: slate900,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      MobileProfilePage(currentWorker: widget.currentWorker),
                ),
              );
            },
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: slate100,
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.user, size: 24, color: slate900),
            ),
          ),
        ],
      ),
    );
  }

  // 공지 듣기는 한 번만 만든다. 예전엔 build 안에서 만들어 날씨·일정 수가 바뀔 때마다
  // 끊고 다시 붙어 머리가 잠깐 빈칸이 됐다.
  Stream<QuerySnapshot>? _noticeStream;
  Stream<QuerySnapshot> get _notices => _noticeStream ??= FirebaseFirestore
      .instance
      .collection('announcements')
      // isActive+createdAt 복합 색인 없이도 동작하도록, 최신순 20건만 받아서
      // 활성 공지를 앱에서 고른다.
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots();

  // 🚀 [정리] 숨긴 차량 기능의 `vehicles` 실시간 듣기를 뺐다(화면은 09-23에 숨겼는데
  // 홈 머리가 계속 서버를 듣고, 내 이름 차량이 있으면 날씨 대신 숨긴 화면으로 보냈다).
  Widget _buildSmartHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      child: Builder(
        builder: (context) {
          return StreamBuilder<QuerySnapshot>(
            stream: _notices,
            builder: (context, noticeSnap) {
              if (noticeSnap.connectionState == ConnectionState.waiting) {
                return const SizedBox(height: 60);
              }

              final activeNotices = noticeSnap.hasData
                  ? noticeSnap.data!.docs
                        .where(
                          (d) =>
                              (d.data() as Map<String, dynamic>)['isActive'] ==
                              true,
                        )
                        .toList()
                  : <QueryDocumentSnapshot>[];
              if (activeNotices.isNotEmpty) {
                var noticeData =
                    activeNotices.first.data() as Map<String, dynamic>;
                String noticeTitle = noticeData['title'] ?? "새로운 사내 공지가 있습니다.";

                if (noticeTitle.contains("회식") || noticeTitle.contains("회의")) {
                  return _buildHeaderContent(
                    title: noticeTitle.contains("회의")
                        ? "회의 일정 공지가\n등록되어 있습니다."
                        : "회식 일정 공지가\n등록되어 있습니다.",
                    titleIcon: LucideIcons.bellRing,
                    subText: "터치하여 전체 알림을 확인하십시오.",
                    isActionable: true,
                    onTap: () {
                      HapticFeedback.heavyImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MobileNotificationPage(
                            currentWorker: widget.currentWorker,
                          ),
                        ),
                      );
                    },
                  );
                }

                return _buildHeaderContent(
                  title: "새로운 사내 공지가\n등록되었습니다.",
                  titleIcon: LucideIcons.clipboardList,
                  subText: noticeTitle,
                  isActionable: true,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MobileNotificationPage(
                          currentWorker: widget.currentWorker,
                        ),
                      ),
                    );
                  },
                );
              }

              return _buildHeaderContent(
                customSubWidget: _buildWeatherWidget(),
                isActionable: true,
                onTap: _openWeatherApp,
              );
            },
          );
        },
      ),
    );
  }

  // 🚀 [날씨 고도화] 날씨 카드를 탭하면 기기에 설치된 날씨 앱을 직접
  // 열어본다. Android는 "날씨 앱"이라는 표준 앱이 정해져 있지 않아서
  // (기종/제조사마다 다르거나 아예 없기도 함), CATEGORY_APP_WEATHER로
  // 등록된 앱이 있는지 먼저 확인해서 있으면 그걸 열고, 없으면(이
  // 사용자의 갤럭시 폴드4는 실제로 확인해보니 따로 실행 가능한 날씨
  // 앱이 없었다) 웹 브라우저로 날씨 검색 결과를 대신 보여준다.
  Future<void> _openWeatherApp() async {
    HapticFeedback.lightImpact();
    // 위치를 아직 묻지 않았으면 이번 누름에 묻고 내 위치 날씨로 다시 불러온다.
    try {
      if (await Geolocator.checkPermission() == LocationPermission.denied) {
        final pos = await _determinePosition(ask: true);
        if (pos != null) {
          await _fetchDetailedWeather();
          return;
        }
      }
    } catch (_) {}
    // 🚀 삼성 날씨는 런처 아이콘용 MAIN/LAUNCHER 액티비티가 없어서(기기의
    // dumpsys로 확인) 일반적인 "앱 실행" 방식으론 안 열렸다. 대신 앱
    // 자체의 MainActivity를 직접 지정해서 연다.
    try {
      await const AndroidIntent(
        action: 'android.intent.action.MAIN',
        package: 'com.sec.android.daemonapp',
        componentName: 'com.sec.android.daemonapp.app.MainActivity',
      ).launch();
      return;
    } catch (_) {
      // 삼성 날씨가 없는 기기면 아래 일반 날씨 앱 → 웹 순으로 폴백.
    }
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.MAIN',
        category: 'android.intent.category.APP_WEATHER',
      );
      final canResolve = await intent.canResolveActivity() ?? false;
      if (canResolve) {
        await intent.launch();
        return;
      }
    } catch (_) {
      // 기기에 날씨 앱이 없거나 인텐트를 해석할 수 없으면 아래 웹
      // 폴백으로 넘어간다.
    }

    final query = Uri.encodeComponent("$_cityName 날씨");
    final webUri = Uri.parse(
      "https://search.naver.com/search.naver?query=$query",
    );
    if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildWeatherWidget() {
    if (!_isWeatherLoaded) {
      return const Text(
        "날씨 정보 동기화 중...",
        style: TextStyle(color: slate600, fontSize: 12),
      );
    }
    // 통신이 없어 못 불러온 경우: 눌러서 다시 부를 수 있게 한다.
    if (_weatherFailed) {
      return InkWell(
        onTap: () {
          setState(() {
            _isWeatherLoaded = false;
            _weatherFailed = false;
          });
          _fetchDetailedWeather();
        },
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.refresh_rounded, size: 14, color: slate600),
            SizedBox(width: 4),
            Text(
              "날씨를 불러오지 못했습니다. 누르면 다시 불러옵니다.",
              style: TextStyle(color: slate600, fontSize: 12),
            ),
          ],
        ),
      );
    }
    // 🚀 [삭제] 위에 있던 인사말 제목이 없어진 뒤로는 이 top 여백이
    // "동기화 중..." 상태(여백 없음)와 로드 완료 상태 사이에 불필요한
    // 위치 차이를 만들어서 없앴다.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // 동 이름이 길면("부산광역시 강서구") 344dp에서 넘쳤다.
            Flexible(
              child: Text(
                "$_cityName $_currentTemp°C  /  $_weatherDesc",
                style: const TextStyle(color: slate600, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(width: 1, height: 10, color: Colors.grey.shade300),
            const SizedBox(width: 8),
            // 🚀 [수정] 고정 Text라 온도/날씨 문구가 조금만 길어져도 우측이
            // 화면 밖으로 넘쳐 "RIGHT OVERFLOWED" 경고가 떴음. Flexible +
            // ellipsis로 감싸서 공간이 부족하면 이 텍스트만 잘리게 한다.
            Flexible(
              child: Text(
                "미세먼지 : $_pmState",
                style: const TextStyle(color: slate600, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            // 🚀 [날씨 고도화] 이 카드를 탭하면 날씨 앱(또는 웹 날씨
            // 페이지)이 열린다는 걸 알려주는 작은 표시.
            Icon(Icons.chevron_right_rounded, size: 14, color: slate600),
          ],
        ),
        if (_rainExpected) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.water_drop, size: 12, color: Colors.blueGrey.shade400),
              const SizedBox(width: 4),
              Text(
                "$_rainStart시에 비 예상 ($_rainEnd시까지 ${_totalRain.toStringAsFixed(1)}mm)",
                style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 12),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildHeaderContent({
    String? title,
    IconData? titleIcon,
    String? subText,
    Widget? customSubWidget,
    required bool isActionable,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.transparent,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (titleIcon != null) ...[
              Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: Icon(titleIcon, size: 24, color: slate900),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🚀 [삭제] 시간대별 "수고했다"류 인사말 문구는 없앴다 -
                  // 이 헤더를 날씨 전용으로 쓸 땐 title을 아예 넘기지
                  // 않아서(null), 날씨 정보(customSubWidget)만 남는다.
                  // 공지/회의 배너처럼 진짜 제목이 필요한 다른 곳은
                  // 그대로 title을 넘겨서 쓴다.
                  if (title != null) ...[
                    Text(
                      title,
                      style: const TextStyle(
                        color: slate900,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (customSubWidget != null)
                    customSubWidget
                  else if (subText != null)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            subText,
                            style: const TextStyle(
                              color: slate600,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isActionable) ...[
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: slate600,
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required BuildContext context,
    required String title,
    required String subtitle,
    required AppGlyph icon,
    required VoidCallback onTap,
    Color? iconColor,
    String? badgeText,
    Color? badgeColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: (iconColor ?? slate900).withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: AppIcon(icon, size: 28, color: iconColor ?? slate900),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: iconColor ?? slate900,
                            letterSpacing: -0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (badgeText != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor ?? warningRed,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText,
                            style: const TextStyle(
                              color: pureWhite,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: slate600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: slate600.withValues(alpha: 0.5),
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}
