// 현장 사진 도장: 큰 사진은 긴 변 2560px로 줄여 찍는다(10-08: 원본 그대로라 사진이 4~5초 늦게 붙었다).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/photo_stamp.dart';

class _FakePaths extends Fake with MockPlatformInterfaceMixin implements PathProviderPlatform {
  _FakePaths(this.dir);
  final String dir;
  @override
  Future<String?> getApplicationDocumentsPath() async => dir;
}

void main() {
  testWidgets('4000×3000 사진에 도장을 찍으면 2560×1920이 된다', (tester) async {
    final tmp = Directory.systemTemp.createTempSync('stamp');
    addTearDown(() => tmp.deleteSync(recursive: true));
    PathProviderPlatform.instance = _FakePaths(tmp.path);
    await tester.runAsync(() async {
      final rec = ui.PictureRecorder();
      Canvas(rec).drawRect(const Rect.fromLTWH(0, 0, 4000, 3000), Paint()..color = Colors.blue);
      final img = await rec.endRecording().toImage(4000, 3000);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      final src = File('${tmp.path}/src.png')..writeAsBytesSync(png!.buffer.asUint8List());
      final out = await stampPhoto(src.path, siteName: '1층');
      expect(out, isNot(src.path));
      final codec = await ui.instantiateImageCodec(File(out).readAsBytesSync());
      final f = await codec.getNextFrame();
      expect(f.image.width, kStampMaxSide);
      expect(f.image.height, 1920);
    });
  });
}
