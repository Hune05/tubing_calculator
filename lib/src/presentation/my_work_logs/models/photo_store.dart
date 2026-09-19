import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import '../../../core/utils/error_log.dart';

// 🚀 [작업 일지 사진 클라우드 보관] 예전엔 작업 일지 사진이 폰 안의 파일 경로로만 저장돼서,
// 앱을 지우고 다시 깔거나 다른 기기에서 열면 사진이 사라졌다. 저장한 작업 일지의 사진을
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

// 업로드 전 긴 변 1600px, 품질 75로 줄인다(현장 사진 수 MB → 수백 KB). 도면/스케치
// 같은 PNG는 형식을 유지한다. 실패하면 원본을 그대로 올린다.
Future<File> _compressed(File src) async {
  try {
    final lower = src.path.toLowerCase();
    final isPng = lower.endsWith('.png');
    final dir = await getTemporaryDirectory();
    final target =
        '${dir.path}/up_${DateTime.now().microsecondsSinceEpoch}${isPng ? '.png' : '.jpg'}';
    final out = await FlutterImageCompress.compressAndGetFile(
      src.path,
      target,
      quality: 75,
      minWidth: 1600,
      minHeight: 1600,
      format: isPng ? CompressFormat.png : CompressFormat.jpeg,
    );
    if (out == null) return src;
    final f = File(out.path);
    return (await f.length()) < (await src.length()) ? f : src;
  } catch (e) {
    debugPrint('사진 압축 실패(원본 업로드): $e');
    recordError('사진 압축', e);
    return src;
  }
}

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
    await ref.putFile(await _compressed(file));
    return await ref.getDownloadURL();
  } catch (e) {
    debugPrint('사진 업로드 실패: $e');
    recordError('사진 업로드', e);
    return null;
  }
}

// 아직 클라우드에 못 올라간(파일이 남아 있는) 로컬 사진 수.
int countLocalPhotos(List<Map<String, dynamic>> logs) {
  bool pending(dynamic p) {
    final s = p?.toString() ?? '';
    return s.isNotEmpty && !isRemotePhoto(s) && File(s).existsSync();
  }

  int n = 0;
  for (final log in logs) {
    for (final r in (log['daily_reports'] as List? ?? []).whereType<Map>()) {
      n += (r['image_paths'] as List? ?? []).where(pending).length;
    }
    for (final p in (log['punch_lists'] as List? ?? []).whereType<Map>()) {
      n += (p['image_paths'] as List? ?? []).where(pending).length;
      n += (p['resolution_images'] as List? ?? []).where(pending).length;
    }
    if (pending(log['floor_plan_image_path'])) n++;
  }
  return n;
}

// 이미 올라간 큰 사진을 다시 줄여 올린다. 새 URL로 문서를 바꾼 뒤(호출한 쪽이
// 저장) 옛 파일은 [oldRefs]로 돌려주니, 저장이 서버에 반영된 다음 지우면 된다.
// (저장 전에 지워서 링크가 깨지는 일이 없도록 여기서는 지우지 않는다.)
Future<({int count, int savedBytes, List<Reference> oldRefs})>
optimizeProjectPhotos(
  Map<String, dynamic> log, {
  void Function(int done, int total)? onProgress,
}) async {
  final pid = log['id']?.toString() ?? 'misc';
  final urls = <String>{};
  void collect(dynamic v) {
    final s = v?.toString() ?? '';
    if (isRemotePhoto(s)) urls.add(s);
  }

  for (final r in (log['daily_reports'] as List? ?? []).whereType<Map>()) {
    for (final p in (r['image_paths'] as List? ?? [])) {
      collect(p);
    }
  }
  for (final p in (log['punch_lists'] as List? ?? []).whereType<Map>()) {
    for (final x in (p['image_paths'] as List? ?? [])) {
      collect(x);
    }
    for (final x in (p['resolution_images'] as List? ?? [])) {
      collect(x);
    }
  }
  collect(log['floor_plan_image_path']);

  final repl = <String, String>{};
  final oldRefs = <Reference>[];
  int saved = 0, done = 0;
  for (final url in urls) {
    onProgress?.call(done, urls.length);
    try {
      final ref = FirebaseStorage.instance.refFromURL(url);
      final size = (await ref.getMetadata()).size ?? 0;
      if (size >= 400 * 1024) {
        final bytes = await ref.getData(25 * 1024 * 1024);
        if (bytes != null) {
          final dir = await getTemporaryDirectory();
          final ext = ref.name.toLowerCase().endsWith('.png') ? '.png' : '.jpg';
          final tmp = File(
            '${dir.path}/dl_${DateTime.now().microsecondsSinceEpoch}$ext',
          );
          await tmp.writeAsBytes(bytes);
          final small = await _compressed(tmp);
          final newSize = await small.length();
          if (newSize < size * 0.8) {
            final name = '${DateTime.now().microsecondsSinceEpoch}_opt$ext';
            final nref = FirebaseStorage.instance
                .ref()
                .child('project_photos')
                .child(pid)
                .child(name);
            await nref.putFile(small);
            repl[url] = await nref.getDownloadURL();
            oldRefs.add(ref);
            saved += size - newSize;
          }
        }
      }
    } catch (e) {
      debugPrint('사진 정리 실패(건너뜀): $e');
    }
    done++;
  }
  onProgress?.call(done, urls.length);

  if (repl.isNotEmpty) {
    String m(dynamic v) => repl[v?.toString() ?? ''] ?? (v?.toString() ?? '');
    for (final r in (log['daily_reports'] as List? ?? []).whereType<Map>()) {
      final paths = (r['image_paths'] as List? ?? []).map(m).toList();
      final tags = Map<String, dynamic>.from((r['image_tags'] as Map?) ?? {});
      final caps = Map<String, dynamic>.from(
        (r['image_captions'] as Map?) ?? {},
      );
      r['image_captions'] = {for (final e in caps.entries) m(e.key): e.value};
      r['image_paths'] = paths;
      if (r['image_path'] != null) r['image_path'] = m(r['image_path']);
      r['image_tags'] = {for (final e in tags.entries) m(e.key): e.value};
    }
    for (final p in (log['punch_lists'] as List? ?? []).whereType<Map>()) {
      p['image_paths'] = (p['image_paths'] as List? ?? []).map(m).toList();
      if (p['resolution_images'] != null) {
        p['resolution_images'] = (p['resolution_images'] as List)
            .map(m)
            .toList();
      }
      if (p['image_path'] != null) p['image_path'] = m(p['image_path']);
    }
    if (log['floor_plan_image_path'] != null) {
      log['floor_plan_image_path'] = m(log['floor_plan_image_path']);
    }
  }
  return (count: repl.length, savedBytes: saved, oldRefs: oldRefs);
}

// 프로젝트 전체(작업 일지 사진, 이슈 사진, 도면)의 로컬 사진을 올린다. 바뀐 게 있으면 true.
Future<bool> uploadAllPhotos(Map<String, dynamic> log) async {
  final pid = log['id']?.toString();
  if (pid == null) return false;
  bool changed = false;
  for (final r in (log['daily_reports'] as List? ?? []).whereType<Map>()) {
    if (await uploadReportPhotos(pid, r)) changed = true;
  }
  for (final p in (log['punch_lists'] as List? ?? []).whereType<Map>()) {
    final paths = <String>[
      for (final e in (p['image_paths'] as List? ?? [])) e.toString(),
    ];
    if (paths.isEmpty || paths.every(isRemotePhoto)) continue;
    final out = <String>[];
    bool c = false;
    for (final path in paths) {
      if (isRemotePhoto(path)) {
        out.add(path);
        continue;
      }
      final url = await uploadPhoto(pid, path);
      out.add(url ?? path);
      if (url != null) c = true;
    }
    if (c) {
      p['image_paths'] = out;
      p['image_path'] = out.first;
      changed = true;
    }
  }
  // 이슈 처리 후 사진
  for (final p in (log['punch_lists'] as List? ?? []).whereType<Map>()) {
    final paths = <String>[
      for (final e in (p['resolution_images'] as List? ?? [])) e.toString(),
    ];
    if (paths.isEmpty || paths.every(isRemotePhoto)) continue;
    final out = <String>[];
    bool c = false;
    for (final path in paths) {
      if (isRemotePhoto(path)) {
        out.add(path);
        continue;
      }
      final url = await uploadPhoto(pid, path);
      out.add(url ?? path);
      if (url != null) c = true;
    }
    if (c) {
      p['resolution_images'] = out;
      changed = true;
    }
  }
  final plan = log['floor_plan_image_path']?.toString();
  if (plan != null && plan.isNotEmpty && !isRemotePhoto(plan)) {
    final url = await uploadPhoto(pid, plan);
    if (url != null) {
      log['floor_plan_image_path'] = url;
      changed = true;
    }
  }
  return changed;
}

// 작업 일지 하나의 사진(image_paths/image_path/image_tags)을 URL로 바꾼다.
// 바뀐 게 있으면 true.
Future<bool> uploadReportPhotos(String projectId, Map report) async {
  final paths = (report['image_paths'] as List? ?? [])
      .map((e) => e.toString())
      .toList();
  if (paths.every(isRemotePhoto)) return false;
  final tags = Map<String, dynamic>.from((report['image_tags'] as Map?) ?? {});
  final newPaths = <String>[];
  final newTags = <String, dynamic>{};
  final caps = Map<String, dynamic>.from(
    (report['image_captions'] as Map?) ?? {},
  );
  final newCaps = <String, dynamic>{};
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
    if (caps[p] != null) newCaps[out] = caps[p];
  }
  if (changed) {
    report['image_paths'] = newPaths;
    report['image_path'] = newPaths.isNotEmpty ? newPaths.first : null;
    report['image_tags'] = newTags;
    report['image_captions'] = newCaps;
  }
  return changed;
}
