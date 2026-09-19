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

  /// 카메라(1장) 또는 갤러리(여러 장 한 번에)를 골라 경로 목록을 돌려준다.
  /// [maxCount]는 앞으로 더 추가할 수 있는 최대 장수.
  static Future<List<String>> pickImages(
    BuildContext context, {
    int maxCount = 10,
  }) async {
    if (maxCount <= 0) return [];
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
                "사진 추가",
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
                '카메라로 촬영',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: slate600),
              title: Text(
                '갤러리에서 여러 장 선택 (최대 $maxCount장)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
    if (source == null) return [];
    if (source == ImageSource.camera) {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 70,
      );
      return image == null ? [] : [image.path];
    }
    final images = await _picker.pickMultiImage(imageQuality: 70);
    return images.take(maxCount).map((e) => e.path).toList();
  }
}
