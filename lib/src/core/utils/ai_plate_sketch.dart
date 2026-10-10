// 손으로 그린 철판 그림 사진을 서버(functions/index.js parsePlateSketch)에 보내 외곽(mm)·귀 처리·구멍·두께로 받는다.
// 앱에는 키가 없다. 실패하면 이유만 알려 주고, 사용자는 사진 위에 직접 따라 찍을 수 있다(철판 가공 › 손그림 읽어 만들기).
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';

import 'ai_polish.dart' show aiPolishErrorMessage;

/// 외곽 꼭짓점 하나(mm, 원점은 판 왼쪽 아래). [corner]는 'none'·'round'·'chamfer', [size]는 R·C 값.
class PlateSketchPoint {
  final double x, y;
  final String corner;
  final double size;
  const PlateSketchPoint(this.x, this.y, {this.corner = 'none', this.size = 0});
}

/// 구멍 하나(mm). [slot]은 장공 전체 길이(둥근 구멍은 0), [angle]은 장공 방향(가로 0).
class PlateSketchHole {
  final double x, y, dia, slot, angle;
  const PlateSketchHole(
    this.x,
    this.y,
    this.dia, {
    this.slot = 0,
    this.angle = 0,
  });
}

class PlateSketchResult {
  final List<PlateSketchPoint> outline;
  final List<PlateSketchHole> holes;
  final double? thickness;

  /// AI가 짐작했거나 옮기지 못한 곳(사람이 확인할 것).
  final List<String> unclear;

  /// 실패 이유(통신·횟수·못 읽음). null이면 성공.
  final String? error;
  final int? remaining;

  const PlateSketchResult.ok({
    required this.outline,
    this.holes = const [],
    this.thickness,
    this.unclear = const [],
    this.remaining,
  }) : error = null;

  const PlateSketchResult.fail(String this.error)
    : outline = const [],
      holes = const [],
      thickness = null,
      unclear = const [],
      remaining = null;

  bool get ok => error == null;
}

typedef PlateSketchCall = Future<PlateSketchResult> Function(Uint8List jpeg);

double? _n(Object? v) => v is num && v.isFinite ? v.toDouble() : null;

/// 서버가 돌려준 plate 자료를 읽는다(서버에서 이미 다듬었지만 한 번 더 확인).
PlateSketchResult readPlateSketch(Object? plate, {int? remaining}) {
  if (plate is! Map) return const PlateSketchResult.fail('AI가 그림을 옮기지 못했습니다');
  final unclear = [
    for (final s
        in (plate['unclear'] is List ? plate['unclear'] as List : const []))
      if (s is String && s.trim().isNotEmpty) s.trim(),
  ];
  if (plate['readable'] != true) {
    final why = plate['reason'];
    return PlateSketchResult.fail(
      why is String && why.trim().isNotEmpty ? why.trim() : '철판 모양을 읽지 못했습니다',
    );
  }
  final pts = <PlateSketchPoint>[];
  for (final p
      in (plate['outline'] is List ? plate['outline'] as List : const [])) {
    if (p is! Map) continue;
    final x = _n(p['x']), y = _n(p['y']);
    if (x == null || y == null) continue;
    final c = p['corner'];
    final s = _n(p['size']) ?? 0;
    pts.add(
      PlateSketchPoint(
        x,
        y,
        corner: (c == 'round' || c == 'chamfer') && s > 0
            ? c as String
            : 'none',
        size: s > 0 ? s : 0,
      ),
    );
  }
  if (pts.length < 3) return const PlateSketchResult.fail('철판 모양을 읽지 못했습니다');
  final holes = <PlateSketchHole>[];
  for (final h
      in (plate['holes'] is List ? plate['holes'] as List : const [])) {
    if (h is! Map) continue;
    final x = _n(h['x']), y = _n(h['y']), d = _n(h['dia']);
    if (x == null || y == null || d == null || d <= 0) continue;
    holes.add(
      PlateSketchHole(
        x,
        y,
        d,
        slot: _n(h['slot']) ?? 0,
        angle: _n(h['angle']) ?? 0,
      ),
    );
  }
  final t = _n(plate['thickness']);
  return PlateSketchResult.ok(
    outline: pts,
    holes: holes,
    thickness: t != null && t > 0 ? t : null,
    unclear: unclear,
    remaining: remaining,
  );
}

/// 실제 서버 호출.
Future<PlateSketchResult> callParsePlateSketch(Uint8List jpeg) async {
  try {
    final callable = FirebaseFunctions.instanceFor(region: 'asia-northeast3')
        .httpsCallable(
          'parsePlateSketch',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 90)),
        );
    final res = await callable.call<Map<Object?, Object?>>({
      'image': base64Encode(jpeg),
      'mime': 'image/jpeg',
    });
    final rem = res.data['remaining'];
    return readPlateSketch(
      res.data['plate'],
      remaining: rem is int ? rem : null,
    );
  } on FirebaseFunctionsException catch (e) {
    return PlateSketchResult.fail(aiPolishErrorMessage(e.code, e.message));
  } catch (_) {
    return const PlateSketchResult.fail('통신이 되는지 확인해 주십시오');
  }
}
