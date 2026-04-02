import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 🚀 기존 모바일 페이지들 임포트
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_remote_page.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_calculator_page.dart';

// 🚀 스캐너와 뷰어 화면 임포트
import 'package:tubing_calculator/src/presentation/fabrication/screens/qr_scanner_page.dart';
import 'package:tubing_calculator/src/presentation/fabrication/screens/viewer_only_screen.dart';

// 🚀 자재 관리 임포트
import 'package:tubing_calculator/src/presentation/inventory/pages/mobile_inventory_login.dart';
import 'package:tubing_calculator/src/presentation/inventory/pages/mobile_inventory_status_page.dart';
import 'package:tubing_calculator/src/presentation/material/material_order_page.dart'; // 🔥 신규 발주 페이지 임포트

// 🎨 토스 스타일 무채색 팔레트
const Color slate900 = Color(0xFF191F28); // 아주 진한 검정 (타이틀용)
const Color slate600 = Color(0xFF8B95A1); // 부드러운 회색 (서브타이틀용)
const Color slate100 = Color(0xFFF2F4F6); // 아주 연한 회색 (배경용)
const Color pureWhite = Color(0xFFFFFFFF);

class MobileMenuPage extends StatelessWidget {
  final String currentWorker;

  const MobileMenuPage({super.key, required this.currentWorker});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pureWhite, // 전체 배경을 순백색으로
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),

              // 🌟 현장 작업 그룹
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
                title: "수동 벤더 계산기",
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
              const Divider(
                height: 1,
                color: slate100,
                thickness: 8,
              ), // 굵고 연한 구분선
              const SizedBox(height: 24),

              // 🌟 자재 관리 그룹
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
              // 🔥 신규 추가된 자재 발주 관리 메뉴
              _buildMenuButton(
                context: context,
                title: "자재 발주 및 현황",
                subtitle: "신규 자재 발주 요청 및 배송 상태 확인",
                icon: Icons.local_shipping_outlined,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MaterialOrderPage(),
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
                title: "자재 마스터 관리",
                subtitle: "관리자 전용 · 신규 자재 등록 및 삭제",
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

  // 🌟 토스 감성: 큼직하고 시원한 타이포그래피 헤더 (색상 박스 제거)
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 20),
      child: Column(
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
                  color: Colors.green.shade500, // 연결 상태 점만 살짝 컬러
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
    );
  }

  // 🌟 무채색 + 선 없는 깔끔한 리스트 아이템
  Widget _buildMenuButton({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            // 💡 알록달록한 색을 빼고 세련된 무채색 원형 배경 적용
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: slate100, // 아주 연한 회색 배경
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: slate900), // 진한 회색/검정 아이콘
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: slate900,
                      letterSpacing: -0.5,
                    ),
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
              color: slate600.withOpacity(0.5),
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}
