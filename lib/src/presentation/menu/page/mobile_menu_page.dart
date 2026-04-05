import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

// 🚀 1. 현장 작업 페이지들 임포트
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_remote_page.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_calculator_page.dart';
import 'package:tubing_calculator/src/presentation/fabrication/screens/qr_scanner_page.dart';
import 'package:tubing_calculator/src/presentation/fabrication/screens/viewer_only_screen.dart';

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
import 'package:tubing_calculator/src/presentation/project/pages/mobile_project_admin_page.dart'; // 관리자 전용

// 🚀 5. 공용 차량 및 장비 페이지 임포트
import 'package:tubing_calculator/src/presentation/vehicle/pages/mobile_vehicle_management_page.dart';
import 'package:tubing_calculator/src/presentation/vehicle/pages/mobile_vehicle_admin_page.dart'; // 관리자 전용

const Color slate900 = Color(0xFF191F28);
const Color slate600 = Color(0xFF8B95A1);
const Color slate100 = Color(0xFFF2F4F6);
const Color pureWhite = Color(0xFFFFFFFF);
const Color warningRed = Color(0xFFF04438);

class MobileMenuPage extends StatelessWidget {
  final String currentWorker;
  final bool isAdmin; // 🚀 관리자 권한 여부 (테스트를 위해 기본값 true 설정)

  const MobileMenuPage({
    super.key,
    required this.currentWorker,
    this.isAdmin = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pureWhite,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 16),

              // ==========================================
              // 🌟 1. 프로젝트 관리 그룹
              // ==========================================
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
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

              if (isAdmin)
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

              const SizedBox(height: 32),
              const Divider(height: 1, color: slate100, thickness: 8),
              const SizedBox(height: 24),

              // ==========================================
              // 🌟 2. 현장 작업 그룹
              // ==========================================
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
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
                          double.tryParse(uri.queryParameters['t'] ?? '0.0') ??
                          0.0;
                      String startDir = uri.queryParameters['d'] ?? 'RIGHT';
                      List<Map<String, double>> parsedBends = [];

                      if (bendsStr.isNotEmpty) {
                        final parts = bendsStr.split('-');
                        for (var part in parts) {
                          final vals = part.split('_');
                          if (vals.length >= 3) {
                            double length = double.tryParse(vals[0]) ?? 0.0;
                            double angle = double.tryParse(vals[1]) ?? 0.0;
                            double rotation = double.tryParse(vals[2]) ?? 0.0;
                            double mark = 0.0;
                            if (vals.length >= 4) {
                              mark = double.tryParse(vals[3]) ?? 0.0;
                            }
                            parsedBends.add({
                              'length': length,
                              'angle': angle,
                              'rotation': rotation,
                              'mark': mark,
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
                title: "벤딩 마킹 계산기",
                subtitle: "스마트폰 최적화 · 단계별 치수 입력",
                icon: Icons.calculate_outlined,
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

              const SizedBox(height: 32),
              const Divider(height: 1, color: slate100, thickness: 8),
              const SizedBox(height: 24),

              // ==========================================
              // 🌟 3. 현장 소통 그룹
              // ==========================================
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
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
                      builder: (context) =>
                          MobileChatListPage(currentUser: currentWorker),
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),
              const Divider(height: 1, color: slate100, thickness: 8),
              const SizedBox(height: 24),

              // ==========================================
              // 🚚 4. 공용 차량 및 장비 그룹
              // ==========================================
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
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
                        currentUser: currentWorker,
                      ),
                    ),
                  );
                },
              ),
              if (isAdmin)
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

              // ==========================================
              // 🌟 5. 자재 관리 그룹
              // ==========================================
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
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
                        isAdmin: isAdmin,
                        currentUser: currentWorker,
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
                      builder: (context) =>
                          MobileInventoryStatusPage(workerName: currentWorker),
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
                      builder: (context) => const MobileInventoryLoginScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "$currentWorker님,\n오늘도 안전 작업하세요",
                style: const TextStyle(
                  color: slate900,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.green.shade500,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "메인 서버 연결됨",
                    style: TextStyle(
                      color: slate600,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      MobileProfilePage(currentWorker: currentWorker),
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

  Widget _buildMenuButton({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
    String? badgeText,
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
                            color: warningRed,
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
