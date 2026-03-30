import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 🚀 기존 모바일 페이지들 임포트
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_remote_page.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_calculator_page.dart';

// 🚀 스캐너와 뷰어 화면 임포트
import 'package:tubing_calculator/src/presentation/fabrication/screens/qr_scanner_page.dart';
import 'package:tubing_calculator/src/presentation/fabrication/screens/viewer_only_screen.dart';

// 🚀 자재 관리 임포트
import 'package:tubing_calculator/src/presentation/inventory/pages/mobile_inventory_login.dart'; // 관리자 등록용
import 'package:tubing_calculator/src/presentation/inventory/pages/mobile_inventory_status_page.dart'; // 불출/반납용 (현황)

const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate600 = Color(0xFF475569);
const Color slate100 = Color(0xFFF1F5F9);
const Color pureWhite = Color(0xFFFFFFFF);

class MobileMenuPage extends StatelessWidget {
  // 📡 작업자 이름을 관리하기 위해 상수로 두거나, 추후 로그인 정보에서 받아오도록 설정합니다.
  final String currentWorker = "현장작업자";

  const MobileMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: slate100,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  "작업 모드 선택",
                  style: TextStyle(
                    color: slate600,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    // 1. 현장 작업용 QR 스캔 버튼
                    _buildMenuButton(
                      context: context,
                      title: "현장 도면 스캔 (QR)",
                      subtitle: "오프라인 지시서 스캔 후 3D 뷰어 즉시 실행",
                      icon: Icons.qr_code_scanner,
                      color: Colors.deepPurple,
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
                            String pipeSize =
                                uri.queryParameters['s'] ?? "1/4\"";
                            String bendsStr = uri.queryParameters['b'] ?? "";

                            bool startFit = uri.queryParameters['sf'] == 'true';
                            bool endFit = uri.queryParameters['ef'] == 'true';
                            double tail =
                                double.tryParse(
                                  uri.queryParameters['t'] ?? '0.0',
                                ) ??
                                0.0;
                            String startDir =
                                uri.queryParameters['d'] ?? 'RIGHT';

                            List<Map<String, double>> parsedBends = [];

                            if (bendsStr.isNotEmpty) {
                              final parts = bendsStr.split('-');
                              for (var part in parts) {
                                final vals = part.split('_');
                                if (vals.length >= 3) {
                                  double length =
                                      double.tryParse(vals[0]) ?? 0.0;
                                  double angle =
                                      double.tryParse(vals[1]) ?? 0.0;
                                  double rotation =
                                      double.tryParse(vals[2]) ?? 0.0;
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
                              const SnackBar(
                                content: Text("QR 코드 데이터를 해석할 수 없습니다."),
                              ),
                            );
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // 2. 스와이프형 모바일 계산기 버튼
                    _buildMenuButton(
                      context: context,
                      title: "모바일 계산기",
                      subtitle: "스마트폰 최적화 · 단계별 치수 입력",
                      icon: Icons.swipe_right_alt,
                      color: Colors.teal.shade700,
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
                    const SizedBox(height: 16),

                    // 3. 벤딩 리모컨 버튼
                    _buildMenuButton(
                      context: context,
                      title: "벤딩 리모컨",
                      subtitle: "스마트폰 권장 · 수치 전송용 리모컨",
                      icon: Icons.precision_manufacturing,
                      color: const Color(0xFF00606B),
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

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Divider(height: 1, color: Colors.black12),
                    ),

                    const Text(
                      "자재 관리 시스템",
                      style: TextStyle(
                        color: slate600,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 🚀 4. 자재 현황 및 불출/반납 버튼 (에러 해결 지점)
                    _buildMenuButton(
                      context: context,
                      title: "자재 현황 (불출 / 반납)",
                      subtitle: "현재 재고 확인 및 현장 자재 입출고 처리",
                      icon: Icons.fact_check_outlined,
                      color: const Color(0xFF2563EB), // 파란색
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MobileInventoryStatusPage(
                              workerName: currentWorker, // 📡 에러 해결: 필수 인자값 전달
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // 🚀 5. 자재 관리자 전용 버튼 (마스터 등록)
                    _buildMenuButton(
                      context: context,
                      title: "자재 마스터 관리",
                      subtitle: "관리자 전용 · 신규 자재 등록 및 삭제",
                      icon: Icons.admin_panel_settings,
                      color: const Color(0xFFD97706), // 주황색
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

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🌟 상단 마키타 테마 헤더
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 40, bottom: 40),
      decoration: BoxDecoration(
        color: makitaTeal,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: makitaTeal.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: pureWhite.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.rocket_launch, size: 36, color: pureWhite),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "TUBING SYSTEM",
                  style: TextStyle(
                    color: pureWhite,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "DB 서버 연결됨 (Online)",
                      style: TextStyle(
                        color: pureWhite.withOpacity(0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🌟 화이트 테마 카드 메뉴 버튼
  Widget _buildMenuButton({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 32, color: color),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: slate900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 13, color: slate600),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey.shade400,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
