import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

// 카톡 등에서 "공유"로 받은 도면(사진·PDF). 안드로이드 쪽(MainActivity)이 앱 안 폴더로 복사해
// 두면 여기서 가져간다. PDF는 첫 쪽을 사진(PNG)으로 바꿔 배치도 배경에 깔 수 있게 한다.
// 모두 폰 안에서만 한다(통신 없음).

class SharedDrawing {
  final String path;
  final String mime;
  const SharedDrawing(this.path, this.mime);

  bool get isPdf =>
      mime == 'application/pdf' || path.toLowerCase().endsWith('.pdf');
}

class SharedDrawingInbox {
  static const MethodChannel _ch = MethodChannel('field/shared_drawing');

  /// 홈 메뉴가 떴는지. 그 전(로딩 화면)에 받은 도면은 홈이 뜬 뒤에 연다.
  static final ValueNotifier<bool> homeReady = ValueNotifier(false);

  /// 홈 메뉴가 그려질 때 부른다(여러 번 불러도 된다).
  static void markHomeReady() => homeReady.value = true;

  /// 받아 둔 도면을 하나 가져온다(가져가면 비운다). 없으면 null.
  static Future<SharedDrawing?> take() async {
    try {
      final m = await _ch.invokeMethod<Map<Object?, Object?>>('take');
      final path = m?['path'];
      if (path is! String || path.isEmpty) return null;
      return SharedDrawing(path, (m?['mime'] as String?) ?? '');
    } on MissingPluginException {
      return null; // 안드로이드가 아닌 곳(테스트·아이폰)
    } catch (e) {
      debugPrint('공유 도면 가져오기 실패: $e');
      return null;
    }
  }

  /// 받은 도면을 앱 사진 폴더로 옮긴 뒤 부른다. 받은 자리(shared_drawings)의 파일을
  /// 모두 지운다 — 예전엔 받을 때마다 쌓이기만 했다. 그 폴더가 아니면 아무것도 안 한다.
  static Future<void> discardAll(String takenPath) async {
    try {
      final dir = File(takenPath).parent;
      if (!dir.path.replaceAll('\\', '/').endsWith('/shared_drawings')) return;
      await for (final e in dir.list(followLinks: false)) {
        if (e is File) {
          try {
            await e.delete();
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('받은 도면 정리 실패: $e');
    }
  }

  /// 앱이 떠 있을 때 공유가 새로 들어오면 [onReceived]를 부른다.
  static void listen(VoidCallback onReceived) {
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'received') onReceived();
    });
  }

  /// 배경에 깔 사진 경로. PDF면 첫 쪽을 PNG로 바꿔 같은 폴더에 둔다. 못 바꾸면 null.
  static Future<String?> toImagePath(SharedDrawing d) async {
    if (!d.isPdf) return d.path;
    try {
      final Uint8List bytes = await File(d.path).readAsBytes();
      await for (final page in Printing.raster(bytes, pages: [0], dpi: 200)) {
        final png = await page.toPng();
        final out = File(
          d.path.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '.png'),
        );
        await out.writeAsBytes(png);
        return out.path;
      }
    } catch (e) {
      debugPrint('PDF 첫 쪽 바꾸기 실패: $e');
    }
    return null;
  }
}
