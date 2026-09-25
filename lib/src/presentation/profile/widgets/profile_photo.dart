// 프로필 사진 고르기: 갤러리·카메라·지우기. 프로필 화면과 상세 프로필이 같이 쓴다.
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../profile_tools.dart';

// 색의 뜻(D-B): 앱의 주 색 하나(청록). 예전에는 이 화면만 파랑이었다.
const Color _blue = AppColors.brand;
const Color _slate900 = AppColors.text;
const Color _slate600 = AppColors.textSub;
const Color _red = Color(0xFFF04452);

/// 사진을 바꾼 결과. [removed]면 지운 것, [url]이 있으면 새 사진.
class ProfilePhotoChange {
  final String? url;
  final bool removed;
  const ProfilePhotoChange.uploaded(this.url) : removed = false;
  const ProfilePhotoChange.removed() : url = null, removed = true;
}

/// 아래에서 올라오는 창으로 갤러리·카메라·지우기를 고르고, 골랐으면 정사각형으로 잘라 올린다.
/// 바뀐 게 없으면 null. [onBusy]로 올리는 중 표시를 켜고 끈다.
Future<ProfilePhotoChange?> changeProfilePhoto(
  BuildContext context, {
  required String userName,
  required bool hasPhoto,
  required ValueChanged<bool> onBusy,
}) async {
  if (ProfileStore.isGuest(userName)) {
    _snack(context, '먼저 이름을 넣거나 로그인한 뒤 사진을 올리십시오.', error: true);
    return null;
  }
  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(LucideIcons.image, color: _blue),
            title: const Text(
              "갤러리에서 고르기",
              style: TextStyle(fontWeight: FontWeight.w700, color: _slate900),
            ),
            onTap: () => Navigator.pop(ctx, 'gallery'),
          ),
          ListTile(
            leading: const Icon(LucideIcons.camera, color: _blue),
            title: const Text(
              "카메라로 찍기",
              style: TextStyle(fontWeight: FontWeight.w700, color: _slate900),
            ),
            onTap: () => Navigator.pop(ctx, 'camera'),
          ),
          if (hasPhoto)
            ListTile(
              leading: const Icon(LucideIcons.trash2, color: _red),
              title: const Text(
                "사진 지우기",
                style: TextStyle(fontWeight: FontWeight.w700, color: _red),
              ),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ListTile(
            leading: const Icon(Icons.close_rounded, color: _slate600),
            title: const Text("닫기", style: TextStyle(color: _slate600)),
            onTap: () => Navigator.pop(ctx),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return null;

  if (choice == 'delete') {
    onBusy(true);
    final ok = await ProfileStore.instance.deletePhoto(userName);
    onBusy(false);
    if (!context.mounted) return null;
    _snack(
      context,
      ok ? '프로필 사진을 지웠습니다.' : '지우지 못했습니다. 통신을 확인하십시오.',
      error: !ok,
    );
    return ok ? const ProfilePhotoChange.removed() : null;
  }

  final XFile? picked;
  try {
    picked = await ImagePicker().pickImage(
      source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 85,
    );
  } catch (e) {
    debugPrint('사진 고르기 실패: $e');
    if (context.mounted) _snack(context, '사진을 가져오지 못했습니다.', error: true);
    return null;
  }
  if (picked == null || !context.mounted) return null;

  final CroppedFile? cropped = await ImageCropper().cropImage(
    sourcePath: picked.path,
    aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: '프로필 사진',
        toolbarColor: _blue,
        toolbarWidgetColor: Colors.white,
        initAspectRatio: CropAspectRatioPreset.square,
        lockAspectRatio: true,
      ),
      IOSUiSettings(title: '프로필 사진', aspectRatioLockEnabled: true),
    ],
  );
  if (cropped == null || !context.mounted) return null;

  HapticFeedback.lightImpact();
  onBusy(true);
  final url = await ProfileStore.instance.uploadPhoto(
    userName,
    File(cropped.path),
  );
  onBusy(false);
  if (!context.mounted) return null;
  if (url == null) {
    _snack(context, '사진을 올리지 못했습니다. 통신을 확인하고 다시 해 보십시오.', error: true);
    return null;
  }
  _snack(context, '프로필 사진을 바꿨습니다.');
  return ProfilePhotoChange.uploaded(url);
}

void _snack(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: error ? _red : _slate900,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
