import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

// 🚀 [일보 사진 클라우드 보관] 예전엔 일보 사진이 폰 안의 파일 경로로만 저장돼서,
// 앱을 지우고 다시 깔거나 다른 기기에서 열면 사진이 사라졌다. 저장한 일보의 사진을
// Firebase Storage에 올리고 문서에는 다운로드 URL을 저장한다. 화면들은
// [PhotoImage]로 경로/URL 어느 쪽이든 그대로 보여준다.

bool isRemotePhoto(String path) => path.startsWith('http');

class PhotoImage extends StatelessWidget {
  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;

  const PhotoImage(
    this.path, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  Widget _broken() => Container(
    width: width,
    height: height,
    color: const Color(0xFFF2F4F6),
    child: const Icon(
      Icons.image_not_supported_outlined,
      size: 20,
      color: Color(0xFF8B95A1),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (isRemotePhoto(path)) {
      return Image.network(
        path,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => _broken(),
        loadingBuilder: (ctx, child, prog) => prog == null
            ? child
            : Container(
                width: width,
                height: height,
                color: const Color(0xFFF2F4F6),
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
      );
    }
    return Image.file(
      File(path),
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, _, _) => _broken(),
    );
  }
}

ImageProvider photoProvider(String path) =>
    isRemotePhoto(path) ? NetworkImage(path) : FileImage(File(path));

// 로컬 경로 사진을 올리고 URL을 돌려준다. 실패하면 null(로컬 경로 유지).
Future<String?> uploadPhoto(String projectId, String localPath) async {
  try {
    final file = File(localPath);
    if (!await file.exists()) return null;
    final name =
        '${DateTime.now().microsecondsSinceEpoch}_${localPath.split(RegExp(r'[\\/]')).last}';
    final ref = FirebaseStorage.instance
        .ref()
        .child('project_photos')
        .child(projectId)
        .child(name);
    await ref.putFile(file);
    return await ref.getDownloadURL();
  } catch (e) {
    debugPrint('사진 업로드 실패: $e');
    return null;
  }
}

// 일보 하나의 사진(image_paths/image_path/image_tags)을 URL로 바꾼다.
// 바뀐 게 있으면 true.
Future<bool> uploadReportPhotos(String projectId, Map report) async {
  final paths = (report['image_paths'] as List? ?? [])
      .map((e) => e.toString())
      .toList();
  if (paths.every(isRemotePhoto)) return false;
  final tags = Map<String, dynamic>.from((report['image_tags'] as Map?) ?? {});
  final newPaths = <String>[];
  final newTags = <String, dynamic>{};
  bool changed = false;
  for (final p in paths) {
    String out = p;
    if (!isRemotePhoto(p)) {
      final url = await uploadPhoto(projectId, p);
      if (url != null) {
        out = url;
        changed = true;
      }
    }
    newPaths.add(out);
    if (tags[p] != null) newTags[out] = tags[p];
  }
  if (changed) {
    report['image_paths'] = newPaths;
    report['image_path'] = newPaths.isNotEmpty ? newPaths.first : null;
    report['image_tags'] = newTags;
  }
  return changed;
}
