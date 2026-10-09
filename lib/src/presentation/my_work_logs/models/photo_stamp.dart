// 현장 사진에 날짜·시각·현장 이름·위치를 찍는다(필드 헬퍼 3번).
//
// 사진이 앱 밖으로 나가는 순간(카톡으로 보내거나 PDF에서 잘라내도) 언제·어디 사진인지
// 알 수 있어야 한다는 게 한국 현장 "사진대지" 관행이다. 지금은 앱 안에서만 프로젝트와
// 연결돼 있어서, 사진이 앱 밖으로 나가면 그 정보가 사라진다.
//
// 카메라로 막 찍은 사진에만 찍는다(image_picker_helper.dart에서 source==camera일
// 때만 부른다). 갤러리에서 예전 사진을 고른 경우는 "지금 시각·위치"가 아니므로 찍지
// 않는다. 위치 권한을 새로 묻지 않는다(사진 한 장 찍을 때마다 위치를 물으면 현장에서
// 성가시다) — 이미 허용돼 있을 때만, 마지막으로 알던 위치를 쓴다.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/app_tokens.dart';

/// 이미 허용된 위치 권한으로 "시/구" 수준 이름을 얻는다. 권한이 없거나, 위치
/// 서비스가 꺼졌거나, 알아내지 못하면 null(도장에서 그 줄만 뺀다).
// 지역 이름은 몇 분 동안 같으니 한 번 받은 것을 다시 쓴다(사진마다 인터넷을 묻지 않게).
String? _lastPlace;
DateTime? _lastPlaceAt;
const Duration _placeKeep = Duration(minutes: 10);

/// 지금 묻고 있는 위치 이름(카메라를 열 때 미리 묻기 시작하고, 도장 찍을 때 같은 물음을 기다린다, 10-09).
Future<String?>? _placeInFlight;

Future<String?> quickSiteLocationLabel() {
  final at = _lastPlaceAt;
  if (at != null && DateTime.now().difference(at) < _placeKeep) {
    return Future.value(_lastPlace);
  }
  return _placeInFlight ??= _lookupPlace().whenComplete(
    () => _placeInFlight = null,
  );
}

Future<String?> _lookupPlace() async {
  try {
    final perm = await Geolocator.checkPermission();
    final allowed =
        perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
    if (!allowed) return null;
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    final pos = await Geolocator.getLastKnownPosition();
    if (pos == null) return null;
    // 좌표 → 지역 이름은 인터넷으로 묻는다. 통신이 없는 현장에서 몇 초씩 기다려 사진이
    // 늦게 붙었다(10-08). 2초만 기다리고 못 받으면 위치 없이 찍는다.
    final places = await placemarkFromCoordinates(
      pos.latitude,
      pos.longitude,
    ).timeout(const Duration(seconds: 2));
    if (places.isEmpty) return null;
    final p = places.first;
    final city = (p.locality?.isNotEmpty ?? false)
        ? p.locality!
        : (p.administrativeArea ?? '');
    final district = (p.subLocality?.isNotEmpty ?? false)
        ? p.subLocality!
        : (p.subAdministrativeArea ?? '');
    final parts = {city, district}.where((s) => s.isNotEmpty).toList();
    _lastPlace = parts.isEmpty ? null : parts.join(' ');
    _lastPlaceAt = DateTime.now();
    return _lastPlace;
  } catch (_) {
    return null;
  }
}

/// 도장 찍을 때 사진 긴 변 한도. 원본(4000px)을 그대로 그리고 PNG로 만들면 몇 초 걸렸다(10-08).
/// 10-09: 2560 → 1600. 서버에 올릴 때도 1600px로 줄이므로(photo_store.dart) 더 크게 찍어 봐야 헛일이었다.
const int kStampMaxSide = 1600;

/// 도장에 넣을 줄들(빈 줄은 뺀다). 화면과 떼어 놓아서 검사할 수 있게.
List<String> photoStampLines({
  required String siteName,
  required DateTime now,
  String? location,
}) {
  return [
    siteName,
    DateFormat('yyyy-MM-dd HH:mm').format(now),
    ?location,
  ].where((s) => s.trim().isNotEmpty).toList();
}

/// [srcPath] 사진 아래에 [siteName]·촬영 시각·(있으면) 위치를 찍은 새 파일 경로를
/// 돌려준다. 무엇이 실패하든 원본 경로를 그대로 돌려준다(사진 자체는 잃지 않는다).
Future<String> stampPhoto(String srcPath, {required String siteName}) async {
  try {
    final bytes = await File(srcPath).readAsBytes();
    final codec = await ui.instantiateImageCodecWithSize(
      await ui.ImmutableBuffer.fromUint8List(bytes),
      getTargetSize: (int w, int h) {
        final longest = w > h ? w : h;
        if (longest <= kStampMaxSide) return ui.TargetImageSize(width: w, height: h);
        final k = kStampMaxSide / longest;
        return ui.TargetImageSize(width: (w * k).round(), height: (h * k).round());
      },
    );
    final frame = await codec.getNextFrame();
    final img = frame.image;
    final w = img.width.toDouble();
    final h = img.height.toDouble();

    final location = await quickSiteLocationLabel();
    final lines = photoStampLines(
      siteName: siteName,
      now: DateTime.now(),
      location: location,
    );
    if (lines.isEmpty) return srcPath;

    final fontSize = (w * 0.032).clamp(18.0, 42.0);
    final painters = [
      for (final line in lines)
        (TextPainter(
          text: TextSpan(
            text: line,
            style: TextStyle(
              fontFamily: kAppFontFamily,
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              shadows: const [Shadow(blurRadius: 4, color: Colors.black87)],
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout(maxWidth: w - fontSize * 2)),
    ];

    final lineGap = fontSize * 0.35;
    final pad = fontSize * 0.6;
    final blockH =
        painters.fold<double>(0, (sum, p) => sum + p.height) +
        lineGap * (painters.length - 1);
    final barH = blockH + pad * 2;

    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec, Rect.fromLTWH(0, 0, w, h));
    canvas.drawImage(img, Offset.zero, Paint());
    canvas.drawRect(
      Rect.fromLTWH(0, h - barH, w, barH),
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );
    var y = h - barH + pad;
    for (final tp in painters) {
      tp.paint(canvas, Offset(pad, y));
      y += tp.height + lineGap;
    }
    final picture = rec.endRecording();
    final out = await picture.toImage(img.width, img.height);
    final data = await out.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return srcPath;

    // 8차(10-09): PNG로 두면 2560px 사진 한 장이 수 MB라 보관·올리기가 무거웠다. JPEG로 바꾼다(안 되면 PNG).
    Uint8List bytesOut = data.buffer.asUint8List();
    var ext = 'png';
    try {
      final jpg = await FlutterImageCompress.compressWithList(
        bytesOut,
        quality: 88,
        minWidth: img.width,
        minHeight: img.height,
        format: CompressFormat.jpeg,
      );
      if (jpg.isNotEmpty) {
        bytesOut = jpg;
        ext = 'jpg';
      }
    } catch (_) {}

    // 임시 폴더에 둔다. 부른 쪽이 사진 폴더로 옮긴 뒤 지운다(예전에는 문서 폴더에 그대로 쌓였다).
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/stamp_${DateTime.now().microsecondsSinceEpoch}.$ext',
    );
    await file.writeAsBytes(bytesOut);
    return file.path;
  } catch (_) {
    return srcPath;
  }
}
