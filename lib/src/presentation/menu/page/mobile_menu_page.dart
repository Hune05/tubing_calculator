import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

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
import 'package:tubing_calculator/src/presentation/material/material_order_page.dart';
import 'package:tubing_calculator/src/presentation/material/order_log_page.dart';

// 🚀 3. 프로필 및 소통 페이지 임포트
import 'package:tubing_calculator/src/presentation/profile/pages/mobile_profile_page.dart';
import 'package:tubing_calculator/src/presentation/chat/pages/mobile_chat_list_page.dart';

// 🚀 4. 프로젝트 관리 페이지 임포트
import 'package:tubing_calculator/src/presentation/my_work_logs/screens/work_log_main_screen.dart';
import 'package:tubing_calculator/src/presentation/my_schedule/mobile_my_schedule_page.dart';

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
    this.isAdmin = false,
  });

  @override
  State<MobileMenuPage> createState() => _MobileMenuPageState();
}

class _MobileMenuPageState extends State<MobileMenuPage> {
  // 🚀 [신규] "내 일정 관리" 메뉴 버튼에 "오늘 N건" 배지를 보여주기 위한
  // 오늘 미완료 일정 개수 - 프로젝트 일정 + 개인 일정(반복 포함)을 합산.
  int? _todayScheduleCount;

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
    _fetchDetailedWeather();
    _loadTodayScheduleCount();
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
                    ).then((_) => _loadTodayScheduleCount());
                  },
                ),
                _buildMenuButton(
                  context: context,
                  title: "내 일정 관리",
                  subtitle: "프로젝트 일정 통합 + 개인 일정 · 반복 · 알림",
                  icon: Icons.event_note_rounded,
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
                // 모으고, 참고자료(벤딩 실무 마스터)는 맨 아래로 내렸다.
                // 예전엔 계산기와 QR스캔/리모컨/참고자료가 뒤섞여 있어서
                // 어디까지가 계산기고 어디부터가 도구/자료인지 한눈에
                // 안 들어왔다.

                // --- 계산기 3종 ---
                _buildMenuButton(
                  context: context,
                  title: "전선관 벤딩 마킹 계산기",
                  subtitle: "장비 프로필 설정 · 자이로 각도기 · 마킹 뷰어",
                  icon: Icons.architecture_rounded,
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
                  title: "튜브 컷팅 계산기",
                  subtitle: "피팅 삽입깊이 차감 · 절단 자재 기록",
                  icon: Icons.content_cut_rounded,
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
                  subtitle: "라인 조립 없이 규격·길이만으로 재단 최적화·지시서 출력",
                  icon: Icons.square_foot_rounded,
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
                  icon: Icons
                      .architecture_rounded, // 중복 아이콘 사용 원치 않으시면 Icons.draw_rounded 등으로 변경하셔도 좋습니다.
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

                const SizedBox(height: 12),
                const Divider(height: 1, color: slate100, thickness: 4),
                const SizedBox(height: 12),

                // --- 참고 자료 (맨 아래) ---
                _buildMenuButton(
                  context: context,
                  title: "튜브 규격 및 실측 도표",
                  subtitle: "3/8\", 1/2\" 외경·반지름 및 실측 가이드",
                  icon: Icons.table_chart_rounded,
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

                // 🚀 [수정] 사용자 요청으로 "현장 소통(메시지/일정)",
                // "공용 차량 및 장비", "자재 관리" 3개 섹션을 메뉴에서
                // 숨김. 계산기/배치도/프로젝트 관리와 무관한 기능들이라
                // 메뉴를 계산기 중심으로 간결하게 유지하기 위함. 페이지와
                // import는 그대로 남겨뒀으니 필요해지면 이 주석 위치에
                // 버튼들을 다시 붙이면 된다.
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
    // 🚀 [삭제] 위에 있던 인사말 제목이 없어진 뒤로는 이 top 여백이
    // "동기화 중..." 상태(여백 없음)와 로드 완료 상태 사이에 불필요한
    // 위치 차이를 만들어서 없앴다.
    return Column(
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
