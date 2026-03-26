import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 🚀 기존 모바일 페이지들 임포트
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_remote_page.dart';
import 'package:tubing_calculator/src/presentation/inventory/pages/mobile_inventory_page.dart';
import 'package:tubing_calculator/src/presentation/inventory/pages/mobile_inventory_status_page.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/calculator_page.dart';

// 🚀 스캐너와 뷰어 화면 임포트
import 'package:tubing_calculator/src/presentation/fabrication/screens/qr_scanner_page.dart';
import 'package:tubing_calculator/src/presentation/fabrication/screens/viewer_only_screen.dart';

// 🎨 테마 컬러 정의
const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate600 = Color(0xFF475569);
const Color slate100 = Color(0xFFF1F5F9);
const Color pureWhite = Color(0xFFFFFFFF);

class MobileMenuPage extends StatelessWidget {
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
                    // 🚀🚀 [수정됨] 현장 작업용 QR 스캔 버튼 🚀🚀
                    _buildMenuButton(
                      context: context,
                      title: "현장 도면 스캔 (QR)",
                      subtitle: "오프라인 지시서 스캔 후 3D 뷰어 즉시 실행",
                      icon: Icons.qr_code_scanner,
                      color: Colors.deepPurple,
                      onTap: () async {
                        HapticFeedback.lightImpact();

                        // 1. 카메라 켜기
                        final String? scannedData = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const QRScannerPage(),
                          ),
                        );

                        // 2. QR 데이터가 들어왔을 때 처리
                        if (scannedData != null && context.mounted) {
                          try {
                            Uri uri = Uri.parse(scannedData);

                            // 💡 QR 주소에서 데이터 쪼개기 (p: 프로젝트, s: 사이즈, b: 벤딩데이터)
                            String project =
                                uri.queryParameters['p'] ?? "Scanned Project";
                            String pipeSize =
                                uri.queryParameters['s'] ?? "1/4\"";
                            String bendsStr = uri.queryParameters['b'] ?? "";

                            List<Map<String, double>> parsedBends = [];

                            // 💡 100_90_0-200_45_90 형태를 List로 변환
                            if (bendsStr.isNotEmpty) {
                              final parts = bendsStr.split('-');
                              for (var part in parts) {
                                final vals = part.split('_');
                                if (vals.length == 3) {
                                  parsedBends.add({
                                    'length': double.tryParse(vals[0]) ?? 0.0,
                                    'angle': double.tryParse(vals[1]) ?? 0.0,
                                    'rotation': double.tryParse(vals[2]) ?? 0.0,
                                  });
                                }
                              }
                            }

                            // 🚀 3. ViewerOnlyScreen이 요구하는 파라미터에 딱 맞게 쏴줌!
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ViewerOnlyScreen(
                                  project: project,
                                  pipeSize: pipeSize,
                                  bendList: parsedBends,
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

                    // 🚀🚀 여기까지 QR 버튼 🚀🚀
                    _buildMenuButton(
                      context: context,
                      title: "메인 계산기 모드",
                      subtitle: "태블릿 권장 · 도면 생성 및 3D 뷰어",
                      icon: Icons.monitor,
                      color: makitaTeal,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CalculatorWrapper(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildMenuButton(
                      context: context,
                      title: "벤딩 리모컨",
                      subtitle: "스마트폰 권장 · 수치 입력 및 전송",
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
                    const SizedBox(height: 16),
                    _buildMenuButton(
                      context: context,
                      title: "자재 관리 (입/출고)",
                      subtitle: "신규 자재 등록 및 수량 변경",
                      icon: Icons.inventory_2,
                      color: const Color(0xFFD97706),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MobileInventoryPage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildMenuButton(
                      context: context,
                      title: "자재 현황 (실시간)",
                      subtitle: "파이어베이스 재고 및 위치 조회",
                      icon: Icons.fact_check_outlined,
                      color: const Color(0xFF2563EB),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const MobileInventoryStatusPage(),
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
            color: makitaTeal.withValues(alpha: 0.3),
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
              color: pureWhite.withValues(alpha: 0.2),
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
                        color: pureWhite.withValues(alpha: 0.8),
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
            color: Colors.black.withValues(alpha: 0.04),
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
                    color: color.withValues(alpha: 0.1),
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

class CalculatorWrapper extends StatefulWidget {
  const CalculatorWrapper({super.key});

  @override
  State<CalculatorWrapper> createState() => _CalculatorWrapperState();
}

class _CalculatorWrapperState extends State<CalculatorWrapper> {
  final List<Map<String, double>> _bendList = [];
  String _startDir = "RIGHT";

  void _addBend(double length, double angle, double rotation) {
    setState(() {
      _bendList.add({'length': length, 'angle': angle, 'rotation': rotation});
    });
  }

  void _updateBend(int index, double length, double angle, double rotation) {
    setState(() {
      _bendList[index] = {
        'length': length,
        'angle': angle,
        'rotation': rotation,
      };
    });
  }

  void _deleteBend(int index) {
    setState(() => _bendList.removeAt(index));
  }

  void _reorderBend(int oldIndex, int newIndex) {
    setState(() {
      final item = _bendList.removeAt(oldIndex);
      _bendList.insert(newIndex, item);
    });
  }

  void _clearBends() {
    setState(() => _bendList.clear());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: makitaTeal,
        title: const Text(
          "메인 계산기",
          style: TextStyle(color: pureWhite, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: pureWhite),
        elevation: 0,
      ),
      body: CalculatorPage(
        bendList: _bendList,
        startDir: _startDir,
        onStartDirChanged: (dir) => setState(() => _startDir = dir),
        onAddBend: _addBend,
        onAddMultipleBends: (bends) {
          setState(() {
            _bendList.addAll(bends);
          });
        },
        onUpdateBend: _updateBend,
        onDeleteBend: _deleteBend,
        onReorderBend: _reorderBend,
        onClear: _clearBends,
      ),
    );
  }
}
