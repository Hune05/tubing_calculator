import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../tube_cutting/cutting_theme.dart';

// 지시서 PDF를 공유하기 전에 화면에서 먼저 보여 주는 창. 공유는 아래 버튼을 눌러야만 일어난다.
// 테스트에서는 PDF를 그리는 플러그인이 없으므로 [pdfPreviewBuilder]를 바꿔서 쓴다.
typedef PdfPreviewBuilder = Widget Function(Uint8List bytes, String fileName);

PdfPreviewBuilder pdfPreviewBuilder = (bytes, fileName) => PdfPreview(
  build: (_) async => bytes,
  pdfFileName: fileName,
  useActions: false,
  canChangePageFormat: false,
  canChangeOrientation: false,
  canDebug: false,
  allowPrinting: false,
  allowSharing: false,
  maxPageWidth: 700,
  scrollViewDecoration: const BoxDecoration(color: Color(0xFFE9ECEF)),
);

class SteelPdfPreviewPage extends StatelessWidget {
  final Uint8List bytes;
  final String fileName;
  final Future<void> Function() onShare;

  const SteelPdfPreviewPage({
    super.key,
    required this.bytes,
    required this.fileName,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CuttingColors.surface,
      appBar: AppBar(
        backgroundColor: CuttingColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: CuttingColors.textPrimary),
        title: const Text(
          "지시서 미리보기",
          style: TextStyle(
            color: CuttingColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
      ),
      body: pdfPreviewBuilder(bytes, fileName),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              key: const Key('pdf_preview_share'),
              style: ElevatedButton.styleFrom(
                backgroundColor: CuttingColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onShare,
              icon: const Icon(Icons.ios_share_rounded, color: Colors.white),
              label: const Text(
                "공유하기",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
