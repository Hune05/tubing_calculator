import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

// 🎨 토스 스타일 미니멀 컬러 팔레트
const Color slate900 = Color(0xFF191F28);
const Color pureWhite = Color(0xFFFFFFFF);

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  // 🚀 핵심: 두 번 찍히는 걸 막아주는 '자물쇠' 역할
  bool _isScanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // 스캐너 배경은 어둡게 (안정감)
      appBar: AppBar(
        backgroundColor: pureWhite, // 🌟 메뉴와 동일한 순백색 헤더
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: slate900), // 뒤로가기 아이콘 까맣게
        centerTitle: true,
        title: const Text(
          "도면 스캔",
          style: TextStyle(
            color: slate900,
            fontSize: 18,
            fontWeight: FontWeight.w800, // 토스식 굵은 타이틀
          ),
        ),
      ),
      body: Stack(
        children: [
          // 1. 카메라 스캐너 화면
          MobileScanner(
            onDetect: (capture) {
              // 🚀 1. 이미 한 번 읽어서 자물쇠가 잠겼다면 무시하고 리턴!
              if (_isScanned) return;

              final barcode = capture.barcodes.first;
              if (barcode.rawValue != null) {
                // 🚀 2. 데이터를 읽자마자 자물쇠를 '잠금' 상태로 변경
                setState(() {
                  _isScanned = true;
                });

                HapticFeedback.lightImpact(); // 스캔 성공 시 가벼운 진동 피드백

                // 🚀 3. QR에 담긴 전체 URL 문자열을 들고 복귀
                Navigator.pop(context, barcode.rawValue);
              }
            },
          ),

          // 2. 🌟 토스 감성: 둥글고 부드러운 스캔 가이드라인 오버레이
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2), // 위쪽 여백
                // 둥근 스캔 타겟 박스
                Center(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: pureWhite.withValues(alpha: 0.8), // 부드러운 흰색 테두리
                        width: 4,
                      ),
                      borderRadius: BorderRadius.circular(32), // 토스 특유의 둥근 모서리
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // 친절한 안내 문구 캡슐
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: slate900.withValues(alpha: 0.6), // 반투명 검정 배경
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Text(
                    "도면의 QR 코드를 사각형 안에 맞춰주세요",
                    style: TextStyle(
                      color: pureWhite,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(flex: 3), // 아래쪽 여백
              ],
            ),
          ),
        ],
      ),
    );
  }
}
