import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

// 🚀 1. 현장 작업 페이지들 임포트
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_remote_page.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_calculator_page.dart';
import 'package:tubing_calculator/src/presentation/fabrication/screens/qr_scanner_page.dart';
import 'package:tubing_calculator/src/presentation/fabrication/screens/viewer_only_screen.dart';
import 'package:tubing_calculator/src/presentation/reference/page/tube_reference_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/layout_board_page.dart';

// 🚀 2. 자재 관리 페이지들 임포트
import 'package:tubing_calculator/src/presentation/inventory/pages/mobile_inventory_login.dart';
import 'package:tubing_calculator/src/presentation/inventory/pages/mobile_inventory_status_page.dart';
import 'package:tubing_calculator/src/presentation/material/material_order_page.dart';
import 'package:tubing_calculator/src/presentation/material/order_log_page.dart';

// 🚀 3. 프로필 및 소통 페이지 임포트
import 'package:tubing_calculator/src/presentation/profile/pages/mobile_profile_page.dart';
import 'package:tubing_calculator/src/presentation/chat/pages/mobile_chat_list_page.dart';

// 🚀 4. 프로젝트 관리 페이지 임포트
import 'package:tubing_calculator/src/presentation/project/pages/mobile_project_list_page.dart';
import 'package:tubing_calculator/src/presentation/project/pages/mobile_project_admin_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/screens/work_log_main_screen.dart';

// 🚀 5. 공용 차량 및 장비 페이지 임포트
import 'package:tubing_calculator/src/presentation/vehicle/pages/mobile_vehicle_management_page.dart';
import 'package:tubing_calculator/src/presentation/vehicle/pages/mobile_vehicle_admin_page.dart';

// 🚀 6. 사내 일정 관리 캘린더 페이지 임포트
import 'package:tubing_calculator/src/presentation/schedule/pages/mobile_schedule_page.dart';

// 🚀 7. 신규 알림 내역 페이지 임포트
import 'package:tubing_calculator/src/presentation/notification/pages/mobile_notification_page.dart';

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
    this.isAdmin = true,
  });

  @override
  State<MobileMenuPage> createState() => _MobileMenuPageState();
}

class _MobileMenuPageState extends State<MobileMenuPage> {
  String _weatherGreeting = "";

  // 🚀 날씨 상세 데이터 상태 관리
  String _weatherDesc = "확인 중";
  String _pmState = "확인 중";
  String _currentTemp = "-";
  bool _rainExpected = false;
  String _rainStart = "";
  String _rainEnd = "";
  double _totalRain = 0.0;
  bool _isWeatherLoaded = false;

  @override
  void initState() {
    super.initState();
    _weatherGreeting = _getTimeBasedGreeting();
    _fetchDetailedWeather();
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

  // 🚀 API 3개(현재날씨, 대기질, 일기예보)를 동시에 불러와 분석
  Future<void> _fetchDetailedWeather() async {
    try {
      const String apiKey = 'ce796b79713bbdf70ec6a7cfb98f2b11';
      const double lat = 35.1795;
      const double lon = 129.0756; // 부산 좌표

      final weatherUrl = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$apiKey&units=metric&lang=kr',
      );
      final airUrl = Uri.parse(
        'https://api.openweathermap.org/data/2.5/air_pollution?lat=$lat&lon=$lon&appid=$apiKey',
      );
      final forecastUrl = Uri.parse(
        'https://api.openweathermap.org/data/2.5/forecast?lat=$lat&lon=$lon&appid=$apiKey&units=metric&lang=kr',
      );

      final responses = await Future.wait([
        http.get(weatherUrl),
        http.get(airUrl),
        http.get(forecastUrl),
      ]);

      if (responses[0].statusCode == 200 &&
          responses[1].statusCode == 200 &&
          responses[2].statusCode == 200) {
        final weatherData = jsonDecode(responses[0].body);
        final airData = jsonDecode(responses[1].body);
        final forecastData = jsonDecode(responses[2].body);

        String mainCondition = weatherData['weather'][0]['main'];
        String desc = _simplifyWeather(mainCondition);
        double temp = weatherData['main']['temp'];

        int aqi = airData['list'][0]['main']['aqi'];
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

        if (mounted) {
          setState(() {
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
            _weatherGreeting = _getTimeBasedGreeting();
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
      setState(() => _isWeatherLoaded = true);
    }
  }

  // 🚀 시간대별 맞춤 인사말
  String _getTimeBasedGreeting() {
    int hour = DateTime.now().hour;

    if (hour >= 5 && hour < 9) {
      return "${widget.currentWorker}님,\n활기찬 아침입니다! 오늘도 안전 작업 하세요.";
    } else if (hour >= 9 && hour < 11) {
      return "${widget.currentWorker}님,\n오전 작업 중이시군요. 항상 안전 유의하세요!";
    } else if (hour >= 11 && hour < 14) {
      return "${widget.currentWorker}님,\n맛있는 점심 드시고 오셨나요?";
    } else if (hour >= 14 && hour < 17) {
      return "${widget.currentWorker}님,\n나른한 오후도 파이팅입니다!";
    } else if (hour >= 17 && hour <= 23) {
      return "${widget.currentWorker}님,\n오늘 하루도 정말 고생 많으셨습니다. 푹 쉬세요!";
    } else {
      return "${widget.currentWorker}님,\n늦은 시간까지 고생이 많으십니다.";
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
                  title: "프로젝트 통합 현황",
                  subtitle: "공정 진척도 · 사급 자재 일정 · 검사 및 펀치",
                  icon: Icons.dashboard_customize_rounded,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MobileProjectListPage(),
                      ),
                    );
                  },
                ),

                if (widget.isAdmin)
                  _buildMenuButton(
                    context: context,
                    title: "프로젝트 통합 세팅 (관리자)",
                    subtitle: "프로젝트 개설, 공정 강제 변경, 담당자 지정",
                    icon: Icons.admin_panel_settings_rounded,
                    iconColor: warningRed,
                    badgeText: "Admin",
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MobileProjectAdminPage(),
                        ),
                      );
                    },
                  ),

                _buildMenuButton(
                  context: context,
                  title: "내 프로젝트",
                  subtitle: "개인 작업 일지 · 이슈 리스트 및 자재 기록",
                  icon: Icons.archive_outlined,
                  iconColor: slate900,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WorkLogMainScreen(),
                      ),
                    );
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

                _buildMenuButton(
                  context: context,
                  title: "벤딩 마킹 계산기",
                  subtitle: "스마트폰 최적화 · 단계별 치수 입력",
                  icon: Icons.calculate_rounded,
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
                  title: "현장 도면 스캔 (QR)",
                  subtitle: "오프라인 지시서 스캔 후 3D 뷰어 실행",
                  icon: Icons.qr_code_scanner_rounded,
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
                              "QR 코드 데이터를 해석할 수 없어요.",
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
                  icon: Icons.settings_remote_rounded,
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
                  title: "튜브 규격 및 실측 도표",
                  subtitle: "3/8\", 1/2\" 외경·반지름 및 실측 가이드",
                  icon: Icons.table_chart_rounded,
                  iconColor: Colors.blueGrey,
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
                _buildMenuButton(
                  context: context,
                  title: "작업 배치도",
                  subtitle: "캐비닛 중판 레이아웃 및 튜빙/결선 스케치",
                  icon: Icons.architecture_rounded,
                  iconColor: slate900,
                  badgeText: "New",
                  badgeColor: tossBlue,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MobileLayoutBoardPage(),
                      ),
                    );
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
                    "현장 소통",
                    style: TextStyle(
                      color: slate600,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _buildMenuButton(
                  context: context,
                  title: "업무용 메시지",
                  subtitle: "팀원 및 타 부서 담당자와 실시간 소통",
                  icon: Icons.chat_bubble_outline_rounded,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MobileChatListPage(
                          currentUser: widget.currentWorker,
                        ),
                      ),
                    );
                  },
                ),
                _buildMenuButton(
                  context: context,
                  title: "회사 행사 및 일정",
                  subtitle: "사내 공지, 회식, 주요 작업 캘린더",
                  icon: Icons.calendar_month_rounded,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MobileSchedulePage(
                          isAdmin: widget.isAdmin,
                          currentUser: widget.currentWorker,
                        ),
                      ),
                    );
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
                    "공용 차량 및 장비",
                    style: TextStyle(
                      color: slate600,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _buildMenuButton(
                  context: context,
                  title: "차량 및 장비 운행 관리",
                  subtitle: "공용 트럭·지게차 배차 예약 및 내역 확인",
                  icon: LucideIcons.truck,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MobileVehicleManagementPage(
                          currentUser: widget.currentWorker,
                        ),
                      ),
                    );
                  },
                ),
                if (widget.isAdmin)
                  _buildMenuButton(
                    context: context,
                    title: "차량 통합 세팅 (관리자)",
                    subtitle: "신규 차량 등록, 정비 기록, 마스터 권한 배차",
                    icon: Icons.admin_panel_settings_rounded,
                    iconColor: warningRed,
                    badgeText: "Admin",
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MobileVehicleAdminPage(),
                        ),
                      );
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
                  title: "자재 발주 및 현황",
                  subtitle: "신규 자재 발주 요청 및 진행 상태 확인",
                  icon: Icons.local_shipping_outlined,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MaterialOrderPage(
                          isAdmin: widget.isAdmin,
                          currentUser: widget.currentWorker,
                        ),
                      ),
                    );
                  },
                ),
                _buildMenuButton(
                  context: context,
                  title: "발주 의뢰 내역",
                  subtitle: "과거 발주 및 처리 완료/반려 내역 조회",
                  icon: Icons.history_rounded,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OrderLogPage(),
                      ),
                    );
                  },
                ),
                _buildMenuButton(
                  context: context,
                  title: "자재 현황 (불출 / 반납)",
                  subtitle: "현재 재고 확인 및 현장 자재 입출고 처리",
                  icon: Icons.inventory_2_outlined,
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
                  subtitle: "재고조사 · 신규 자재 등록 및 삭제",
                  icon: Icons.admin_panel_settings_outlined,
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

                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSmartHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('vehicles')
                  .where('currentUser', isEqualTo: widget.currentWorker)
                  .snapshots(),
              builder: (context, vehicleSnap) {
                if (vehicleSnap.hasData && vehicleSnap.data!.docs.isNotEmpty) {
                  var vehicleData =
                      vehicleSnap.data!.docs.first.data()
                          as Map<String, dynamic>;
                  var status = vehicleData['status'];
                  var number = vehicleData['number'] ?? '';

                  if (status == '예약 중') {
                    return _buildHeaderContent(
                      title: "곧 $number 차량 운행이\n예정되어 있습니다.",
                      titleIcon: LucideIcons.calendarClock,
                      subText: "터치하여 예약 상태를 확인해 주세요.",
                      isActionable: true,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MobileVehicleManagementPage(
                              currentUser: widget.currentWorker,
                            ),
                          ),
                        );
                      },
                    );
                  } else if (status == '운행 중') {
                    return _buildHeaderContent(
                      title: "현재 $number 차량을\n운행 중입니다.",
                      titleIcon: LucideIcons.car,
                      subText: "안전 운행하시고, 사용 후 반납해 주세요.",
                      isActionable: true,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MobileVehicleManagementPage(
                              currentUser: widget.currentWorker,
                            ),
                          ),
                        );
                      },
                    );
                  }
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('announcements')
                      .where('isActive', isEqualTo: true)
                      .orderBy('createdAt', descending: true)
                      .limit(1)
                      .snapshots(),
                  builder: (context, noticeSnap) {
                    if (noticeSnap.connectionState == ConnectionState.waiting) {
                      return const SizedBox(height: 60);
                    }

                    if (noticeSnap.hasData &&
                        noticeSnap.data!.docs.isNotEmpty) {
                      var noticeData =
                          noticeSnap.data!.docs.first.data()
                              as Map<String, dynamic>;
                      String noticeTitle =
                          noticeData['title'] ?? "새로운 사내 공지가 있습니다.";

                      if (noticeTitle.contains("회식") ||
                          noticeTitle.contains("회의")) {
                        return _buildHeaderContent(
                          title: noticeTitle.contains("회의")
                              ? "오늘 중요한 회의 일정이\n예정되어 있습니다."
                              : "오늘 사내 회식 일정이\n등록되어 있습니다.",
                          titleIcon: LucideIcons.bellRing,
                          subText: "터치하여 전체 알림을 확인하세요.",
                          isActionable: true,
                          onTap: () {
                            HapticFeedback.heavyImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const MobileNotificationPage(),
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
                              builder: (context) =>
                                  const MobileNotificationPage(),
                            ),
                          );
                        },
                      );
                    }

                    return _buildHeaderContent(
                      title: _weatherGreeting,
                      customSubWidget: _buildWeatherWidget(),
                      isActionable: false,
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(width: 16),
          Row(
            children: [
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MobileNotificationPage(),
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
                  child: const Icon(
                    LucideIcons.bell,
                    size: 24,
                    color: slate900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MobileProfilePage(
                        currentWorker: widget.currentWorker,
                      ),
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
                  child: const Icon(
                    LucideIcons.user,
                    size: 24,
                    color: slate900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherWidget() {
    if (!_isWeatherLoaded) {
      return const Text(
        "날씨 정보 동기화 중...",
        style: TextStyle(color: slate600, fontSize: 12),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "부산시 $_currentTemp°C  /  $_weatherDesc",
                style: const TextStyle(color: slate600, fontSize: 12),
              ),
              const SizedBox(width: 8),
              Container(width: 1, height: 10, color: Colors.grey.shade300),
              const SizedBox(width: 8),
              Text(
                "미세먼지 : $_pmState",
                style: const TextStyle(color: slate600, fontSize: 12),
              ),
            ],
          ),
          if (_rainExpected) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.water_drop,
                  size: 12,
                  color: Colors.blueGrey.shade400,
                ),
                const SizedBox(width: 4),
                Text(
                  "$_rainStart시에 비 예상 ($_rainEnd시까지 ${_totalRain.toStringAsFixed(1)}mm)",
                  style: TextStyle(
                    color: Colors.blueGrey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderContent({
    required String title,
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
    required IconData icon,
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
              child: Icon(icon, size: 28, color: iconColor ?? slate900),
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
