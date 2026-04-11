import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

const Color makitaTeal = Color(0xFF007580);
const Color slate600 = Color(0xFF475569);
const Color slate900 = Color(0xFF0F172A);
const Color pureWhite = Color(0xFFFFFFFF);

class ImagePickerHelper {
  static final ImagePicker _picker = ImagePicker();

  /// 카메라/갤러리 선택 바텀 시트를 띄우고, 선택된 이미지의 경로를 반환합니다.
  static Future<String?> pickImage(BuildContext context) async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: pureWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "사진 첨부 방식 선택",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: slate900,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: makitaTeal),
              title: const Text(
                '카메라로 바로 촬영',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: slate600),
              title: const Text(
                '갤러리에서 사진 선택',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (source != null) {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 70, // 이미지 용량 최적화
      );
      return image?.path;
    }
    return null;
  }
}
