// 바코드·QR을 카메라로 읽어 글자를 돌려준다. 자재를 찾거나 새 자재 이름을 넣을 때 쓴다.
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// 읽으면 화면을 닫고 그 글을 돌려준다. 뒤로 가면 null.
Future<String?> scanBarcode(BuildContext context) {
  return Navigator.push<String>(
    context,
    MaterialPageRoute(builder: (_) => const _BarcodeScanPage()),
  );
}

class _BarcodeScanPage extends StatefulWidget {
  const _BarcodeScanPage();

  @override
  State<_BarcodeScanPage> createState() => _BarcodeScanPageState();
}

class _BarcodeScanPageState extends State<_BarcodeScanPage> {
  bool _done = false; // 한 번만 돌려주려고

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('바코드 스캔'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_done) return;
              for (final b in capture.barcodes) {
                final v = b.rawValue?.trim();
                if (v != null && v.isNotEmpty) {
                  _done = true;
                  if (mounted) Navigator.pop(context, v);
                  return;
                }
              }
            },
          ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: 48),
              child: Text(
                '자재의 바코드나 QR을 화면 안에 맞춰 주십시오',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
