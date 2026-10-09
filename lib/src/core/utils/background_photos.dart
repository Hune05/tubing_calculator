// 고른 사진을 목록에 먼저 넣고, 도장 찍기·보관은 뒤에서 하는 일(10-09).
// 예전에는 다 끝날 때까지 몇 초 동안 아무 표시가 없어 사진이 늦게 붙는 것처럼 보였다.
// 작업 일지 사진, 이슈 등록 사진, 이슈 처리 후 사진이 같이 쓴다.
import 'dart:io';

import 'package:flutter/material.dart';

import 'image_picker_helper.dart';

class BackgroundPhotos {
  final Map<String, Future<String>> _jobs = {};

  /// 아직 정리 중인 사진인지(임시 경로).
  bool busy(String path) => _jobs.containsKey(path);

  bool get isIdle => _jobs.isEmpty;

  /// [picked]를 [list] 끝에 바로 넣고, 마무리가 끝나면 그 자리를 마무리한 경로로 바꾼다.
  /// [update]는 화면을 다시 그리는 함수: `(fn) => mounted ? setState(fn) : fn()`.
  /// 정리하는 사이 목록에서 지운 사진은 옮겨 둔 파일도 지운다.
  void addAll(
    List<String> list,
    List<PickedPhoto> picked, {
    required void Function(VoidCallback fn) update,
    bool stampSite = true,
    String? siteLabel,
  }) {
    if (picked.isEmpty) return;
    update(() => list.addAll([for (final p in picked) p.rawPath]));
    for (final p in picked) {
      final job = ImagePickerHelper.finishPhoto(
        p,
        stampSite: stampSite,
        siteLabel: siteLabel,
      );
      _jobs[p.rawPath] = job;
      job.then((done) {
        _jobs.remove(p.rawPath);
        final i = list.indexOf(p.rawPath);
        if (i < 0) {
          if (done != p.rawPath) File(done).delete().ignore();
          update(() {});
          return;
        }
        update(() => list[i] = done);
      });
    }
  }

  /// 정리 중인 사진이 다 끝나기를 기다린다(저장하기 전에, 임시 경로가 저장되지 않게).
  Future<void> waitAll() async {
    while (_jobs.isNotEmpty) {
      await Future.wait(_jobs.values.toList());
      await Future<void>.delayed(Duration.zero);
    }
  }
}

/// 정리 중인 사진 위 표시(어둡게 + 도는 표시). 사진 칸 [Stack] 안에 넣는다.
class PhotoBusyOverlay extends StatelessWidget {
  final double radius;
  const PhotoBusyOverlay({super.key, this.radius = 12});

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(radius),
        ),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Colors.white,
          ),
        ),
      ),
    ),
  );
}
