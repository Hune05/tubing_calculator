import 'dart:io';
import 'package:flutter/material.dart';

const Color makitaTeal = Color(0xFF007580);
const Color slate200 = Color(0xFFE2E8F0);
const Color slate600 = Color(0xFF475569);
const Color slate900 = Color(0xFF0F172A);
const Color slate50 = Color(0xFFF8FAFC);
const Color pureWhite = Color(0xFFFFFFFF);

class PhotoDetailModal extends StatelessWidget {
  final String title;
  final String content;
  final List<dynamic>? imagePaths;
  final bool isAsBuilt;
  final String? asBuiltReason;

  const PhotoDetailModal({
    super.key,
    required this.title,
    required this.content,
    this.imagePaths,
    this.isAsBuilt = false,
    this.asBuiltReason,
  });

  /// 어디서든 쉽게 띄울 수 있는 정적 메서드
  static void show({
    required BuildContext context,
    required String title,
    required String content,
    List<dynamic>? imagePaths,
    bool isAsBuilt = false,
    String? asBuiltReason,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => PhotoDetailModal(
        title: title,
        content: content,
        imagePaths: imagePaths,
        isAsBuilt: isAsBuilt,
        asBuiltReason: asBuiltReason,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool hasImages = imagePaths != null && imagePaths!.isNotEmpty;

    return Dialog(
      backgroundColor: pureWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 헤더 영역
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: slate900,
              ),
            ),
            const Divider(height: 24, thickness: 1, color: slate200),

            // 2. 텍스트 내용 영역
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content,
                    style: const TextStyle(
                      fontSize: 16,
                      color: slate900,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // As-Built 경고창
                  if (isAsBuilt &&
                      asBuiltReason != null &&
                      asBuiltReason!.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Text(
                        "⚠️ As-Built: $asBuiltReason",
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),

            // 3. 사진 뷰어 영역
            Expanded(
              child: hasImages
                  ? Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        // 좌우 스와이프를 위한 PageView
                        PageView.builder(
                          itemCount: imagePaths!.length,
                          itemBuilder: (context, index) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              // 줌인/아웃을 위한 InteractiveViewer
                              child: InteractiveViewer(
                                minScale: 1.0,
                                maxScale: 5.0,
                                child: Image.file(
                                  File(imagePaths![index]),
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            );
                          },
                        ),

                        // 사진이 여러 장일 때 안내 문구
                        if (imagePaths!.length > 1)
                          Container(
                            margin: const EdgeInsets.all(12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "👈 좌우로 스와이프 (${imagePaths!.length}장) 👉",
                              style: const TextStyle(
                                color: pureWhite,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    )
                  // 사진이 없을 때 빈 화면 표시
                  : Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: slate50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: slate200),
                      ),
                      child: const Center(
                        child: Text(
                          "📷 첨부된 사진이 없습니다.",
                          style: TextStyle(
                            color: slate600,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
            ),

            const SizedBox(height: 16),

            // 4. 하단 닫기 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: makitaTeal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "닫기",
                  style: TextStyle(
                    color: pureWhite,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
