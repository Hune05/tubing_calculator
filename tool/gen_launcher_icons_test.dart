// 런처 아이콘(android/app/src/main/res/mipmap-*/ic_launcher.png) 다시 만들기.
// 앱 로고(lib/src/core/theme/app_logo.dart의 AppLogoMark)를 그대로 그려 PNG로 적는다.
// 기본색을 바꿨을 때 돌린다:
//   flutter test tool/gen_launcher_icons_test.dart
// 평소 `flutter test`(test/ 폴더)에는 안 들어간다.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/core/theme/app_logo.dart';
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';

const Map<String, int> _sizes = {
  'mdpi': 48,
  'hdpi': 72,
  'xhdpi': 96,
  'xxhdpi': 144,
  'xxxhdpi': 192,
};

void main() {
  testWidgets('런처 아이콘 PNG를 앱 로고 색으로 다시 적는다', (tester) async {
    for (final e in _sizes.entries) {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            // 런처 아이콘은 꽉 찬 네모(모서리는 런처가 깎는다). 둥근 모서리 밖도 바탕색으로 채운다.
            child: RepaintBoundary(
              key: key,
              child: Container(
                color: AppColors.brand,
                child: AppLogoMark(size: e.value.toDouble()),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      late final ByteData bytes;
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final ui.Image img = await boundary.toImage(pixelRatio: 1);
        bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!;
      });
      final file = File(
        'android/app/src/main/res/mipmap-${e.key}/ic_launcher.png',
      );
      file.writeAsBytesSync(bytes.buffer.asUint8List());
      expect(file.lengthSync(), greaterThan(100));
    }
  });
}
