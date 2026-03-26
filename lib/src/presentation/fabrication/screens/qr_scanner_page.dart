import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
      appBar: AppBar(
        title: const Text(
          "도면 QR 스캔",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF007580),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: MobileScanner(
        onDetect: (capture) {
          // 🚀 1. 이미 한 번 읽어서 자물쇠가 잠겼다면 무시하고 리턴!
          if (_isScanned) return;

          final barcode = capture.barcodes.first;
          if (barcode.rawValue != null) {
            // 🚀 2. 데이터를 읽자마자 자물쇠를 '잠금' 상태로 변경
            setState(() {
              _isScanned = true;
            });

            // 🚀 3. 안전하게 딱 한 번만 데이터를 들고 메뉴로 복귀
            Navigator.pop(context, barcode.rawValue);
          }
        },
      ),
    );
  }
}
