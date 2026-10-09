import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'dart:async';
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

/// 고르기만 한 사진(도장·보관 전). [ImagePickerHelper.finishPhoto]로 마무리한다(10-09).
class PickedPhoto {
  /// image_picker가 준 임시 경로(바로 화면에 보일 수 있다).
  final String rawPath;

  /// 카메라로 막 찍은 사진(도장은 이것에만).
  final bool fromCamera;
  const PickedPhoto(this.rawPath, {this.fromCamera = false});
}

class ImagePickerHelper {
  static final ImagePicker _picker = ImagePicker();

  /// 시험에서 사진 고르기·마무리를 바꿔 넣는다.
  @visibleForTesting
  static Future<List<PickedPhoto>> Function(int maxCount)? debugPickRaw;
  @visibleForTesting
  static Future<String> Function(PickedPhoto p)? debugFinish;

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
    final picked = await pickRawImages(
      context,
      maxCount: maxCount,
      stampSite: stampSite,
    );
    return [
      for (final p in picked)
        await finishPhoto(p, stampSite: stampSite, siteLabel: siteLabel),
    ];
  }

  /// 사진을 고르기만 한다(도장·보관은 [finishPhoto]). 작업 일지처럼 고르자마자 화면에 먼저
  /// 보이고 마무리는 뒤에서 하려는 곳이 쓴다(10-09: 다 끝날 때까지 몇 초 동안 아무 표시가 없었다).
  /// 현장 사진([stampSite])은 고를 때부터 긴 변 [kStampMaxSide]로 줄인다(서버에 올릴 때 크기).
  static Future<List<PickedPhoto>> pickRawImages(
    BuildContext context, {
    int maxCount = 10,
    bool stampSite = false,
  }) async {
    if (maxCount <= 0) return [];
    final fake = debugPickRaw;
    if (fake != null) return fake(maxCount);
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
    final side = stampSite ? kStampMaxSide.toDouble() : null;
    if (source == ImageSource.camera) {
      // 도장에 넣을 위치 이름을 카메라를 여는 동안 미리 묻는다(찍고 나서 최대 2초 기다리던 것, 10-09).
      if (stampSite && ReportStyle.current.photoStamp) {
        unawaited(quickSiteLocationLabel());
      }
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: side,
        maxHeight: side,
      );
      return image == null ? [] : [PickedPhoto(image.path, fromCamera: true)];
    }
    // 갤러리 사진도 현장 사진이면 고를 때 줄인다(10-09: 원본 크기 그대로 다시 저장해 장수만큼 느렸다).
    final images = await _picker.pickMultiImage(
      imageQuality: 70,
      maxWidth: side,
      maxHeight: side,
    );
    return [for (final e in images.take(maxCount)) PickedPhoto(e.path)];
  }

  /// 고른 사진을 마무리한다: 카메라 사진이고 도장이 켜져 있으면 도장을 찍고, 앱 사진 폴더로 옮긴다.
  /// 마무리한 경로(실패하면 받은 경로).
  static Future<String> finishPhoto(
    PickedPhoto p, {
    bool stampSite = false,
    String? siteLabel,
  }) async {
    final fake = debugFinish;
    if (fake != null) return fake(p);
    var path = p.rawPath;
    if (p.fromCamera && stampSite && ReportStyle.current.photoStamp) {
      path = await stampPhoto(path, siteName: siteLabel ?? '');
    }
    final kept = await keepPhoto(path);
    // 도장 찍은 임시 파일은 사진 폴더로 옮겼으면 지운다(8차).
    if (path != p.rawPath && kept != path) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
    return kept;
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
