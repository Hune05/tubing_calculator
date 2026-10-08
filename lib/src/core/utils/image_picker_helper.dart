import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/photo_stamp.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/report_style.dart';

const Color makitaTeal = AppColors.brand;
const Color slate600 = AppColors.textSub;
const Color slate900 = AppColors.text;
const Color pureWhite = Color(0xFFFFFFFF);

class ImagePickerHelper {
  static final ImagePicker _picker = ImagePicker();

  /// 고른 사진은 캐시 폴더에 오는데, 서버에 올리기 전에 폰이 캐시를 비우면 사진이 사라지고
  /// 일지에는 없는 경로만 남았다. 앱 문서 폴더로 옮겨 둔다(못 옮기면 원래 경로).
  static Future<String> keepPhoto(String path) async {
    try {
      final dir = Directory(
        '${(await getApplicationDocumentsDirectory()).path}/photos',
      );
      if (!await dir.exists()) await dir.create(recursive: true);
      final name = path.split(RegExp(r'[\\/]')).last;
      final dst = '${dir.path}/${DateTime.now().microsecondsSinceEpoch}_$name';
      await File(path).copy(dst);
      return dst;
    } catch (e) {
      debugPrint('사진 보관 실패: $e');
      return path;
    }
  }

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
      return image == null ? null : await keepPhoto(image.path);
    }
    return null;
  }

  /// 카메라(1장) 또는 갤러리(여러 장 한 번에)를 골라 경로 목록을 돌려준다.
  /// [maxCount]는 앞으로 더 추가할 수 있는 최대 장수.
  ///
  /// [stampSite]가 true이고(작업 일지·이슈처럼 현장 증빙 사진일 때만 true로 부른다)
  /// 카메라로 막 찍은 사진이면(갤러리에서 고른 옛 사진은 아니면), 설정에서 켜져 있을 때
  /// [siteLabel]·촬영 시각·(있으면) 위치를 사진에 찍는다(필드 헬퍼 3번).
  static Future<List<String>> pickImages(
    BuildContext context, {
    int maxCount = 10,
    bool stampSite = false,
    String? siteLabel,
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
        // 현장 증빙 사진(도장)은 긴 변 2560px면 충분하다. 원본 그대로 줄이고 도장 찍느라 몇 초 걸렸다(10-08).
        maxWidth: stampSite ? 2560 : null,
        maxHeight: stampSite ? 2560 : null,
      );
      if (image == null) return [];
      var path = image.path;
      if (stampSite && ReportStyle.current.photoStamp) {
        path = await stampPhoto(path, siteName: siteLabel ?? '');
      }
      return [await keepPhoto(path)];
    }
    final images = await _picker.pickMultiImage(imageQuality: 70);
    return [for (final e in images.take(maxCount)) await keepPhoto(e.path)];
  }

  /// 제출용 사진(압력계 눈금처럼 특정 부분을 확대해 붙여야 할 때)을 자르는 화면을
  /// 띄운다. 사각형을 안 건드리고 확인하면 전체 사진 그대로, 드래그해서 확대하면
  /// 그 부분만 새 파일로 저장한다. 취소하면 null(원본을 그대로 쓰면 된다).
  static Future<String?> cropImage(
    String sourcePath, {
    String title = '사진 자르기(확대할 부분을 선택)',
  }) async {
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: sourcePath,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: title,
            toolbarColor: makitaTeal,
            toolbarWidgetColor: pureWhite,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(title: title),
        ],
      );
      if (cropped == null) return null;
      // 자른 파일은 앱 캐시 폴더에 생겨 폰이 캐시를 비우면 사라진다. 문서 폴더로 옮겨 그 경로를 쓴다(10-08).
      final kept = await keepPhoto(cropped.path);
      if (kept != cropped.path) {
        try {
          await File(cropped.path).delete();
        } catch (_) {}
      }
      return kept;
    } catch (e) {
      debugPrint('사진 자르기 실패: $e');
      return null;
    }
  }
}
