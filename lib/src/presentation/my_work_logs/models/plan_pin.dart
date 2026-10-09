// 도면 위치 핀 좌표(10-10).
//
// 예전 핀은 핀 찍는 화면 몸통(앱 막대 아래 전체) 기준 0~1로 저장됐는데, 작은 미리보기·보고서 PDF는
// 그 값을 도면 그림 기준으로 읽어, 도면과 화면의 가로세로 비율이 다르면 핀이 엉뚱한 곳에 찍혔다.
// 이제 도면 그림 기준 0~1로 저장하고 [kPinOnImageKey]: true를 같이 적는다. 예전 핀(표시 없음)은
// 저장된 값을 바꾸지 않고, 보여 줄 때 이 기기의 핀 찍는 화면 크기로 그림 기준으로 다시 계산한다
// (찍은 기기·방향이 같으면 정확히 맞는다).
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'photo_store.dart';

/// 핀이 도면 그림 기준인지 적는 칸.
const String kPinOnImageKey = 'locationPinOnImage';

/// [box] 안에 [image]를 BoxFit.contain으로 놓았을 때 그림이 차지하는 칸.
Rect containRect(Size image, Size box) {
  if (image.width <= 0 || image.height <= 0 || box.isEmpty) {
    return Offset.zero & box;
  }
  final s = (box.width / image.width) < (box.height / image.height)
      ? box.width / image.width
      : box.height / image.height;
  final w = image.width * s, h = image.height * s;
  return Rect.fromLTWH((box.width - w) / 2, (box.height - h) / 2, w, h);
}

Offset _clamp01(Offset o) =>
    Offset(o.dx.clamp(0.0, 1.0), o.dy.clamp(0.0, 1.0));

/// [box] 안의 한 점(px)을 그림 기준 0~1로.
Offset boxPointToImage(Offset local, Size image, Size box) {
  final r = containRect(image, box);
  return _clamp01(
    Offset((local.dx - r.left) / r.width, (local.dy - r.top) / r.height),
  );
}

/// 예전 핀(화면 몸통 기준 0~1)을 그림 기준 0~1로.
Offset legacyPinToImage(Offset boxFrac, Size image, Size box) =>
    boxPointToImage(
      Offset(boxFrac.dx * box.width, boxFrac.dy * box.height),
      image,
      box,
    );

/// 예전 핀을 찍던 화면 몸통 크기(이 기기 화면에서 상태 막대·앱 막대를 뺀 것).
Size legacyPinBox() {
  final views = ui.PlatformDispatcher.instance.views;
  if (views.isEmpty) return const Size(400, 700);
  final v = views.first;
  final dpr = v.devicePixelRatio == 0 ? 1.0 : v.devicePixelRatio;
  final size = v.physicalSize / dpr;
  final top = v.padding.top / dpr;
  final h = size.height - top - kToolbarHeight;
  if (size.width <= 0 || h <= 0) return const Size(400, 700);
  return Size(size.width, h);
}

/// 일지·이슈 한 건의 핀(그림 기준 0~1). 핀이 없으면 null.
/// 예전 핀은 [image](도면 크기)를 알아야 바꿀 수 있다. 모르면 저장된 값 그대로.
Offset? pinOnImageOf(Map item, Size? image, {Size? legacyBox}) {
  final dx = (item['locationPinDx'] as num?)?.toDouble();
  final dy = (item['locationPinDy'] as num?)?.toDouble();
  if (dx == null || dy == null) return null;
  final p = Offset(dx, dy);
  if (item[kPinOnImageKey] == true || image == null) return p;
  return legacyPinToImage(p, image, legacyBox ?? legacyPinBox());
}

final Map<String, Size> _sizeCache = {};

/// 도면 그림의 크기(픽셀). 못 읽으면 null.
Future<Size?> planImageSize(String path) async {
  final hit = _sizeCache[path];
  if (hit != null) return hit;
  final done = Completer<Size?>();
  final stream = photoProvider(path).resolve(ImageConfiguration.empty);
  late final ImageStreamListener l;
  l = ImageStreamListener(
    (info, _) {
      if (!done.isCompleted) {
        done.complete(
          Size(info.image.width.toDouble(), info.image.height.toDouble()),
        );
      }
    },
    onError: (_, _) {
      if (!done.isCompleted) done.complete(null);
    },
  );
  stream.addListener(l);
  Size? s;
  try {
    s = await done.future.timeout(const Duration(seconds: 15));
  } on TimeoutException {
    s = null;
  } finally {
    stream.removeListener(l);
  }
  if (s != null) _sizeCache[path] = s;
  return s;
}

/// 도면 위 핀 하나(그림 기준 0~1 자리와 그릴 표시).
class PlanPin {
  final Offset at;
  final Widget marker;
  final Size markerSize;
  // 표시의 어느 점이 [at]에 오는지(핀 아이콘은 아래 가운데, 번호 동그라미는 가운데).
  final Alignment anchor;
  const PlanPin(
    this.at,
    this.marker, {
    this.markerSize = const Size(28, 28),
    this.anchor = Alignment.bottomCenter,
  });
}

/// 도면 그림과 그 위의 핀들. 그림 크기를 읽어 BoxFit.contain 자리에 핀을 놓는다.
class PlanPinsView extends StatelessWidget {
  final String imagePath;
  final Size? imageSize; // 아는 크기(모르면 읽는다)
  final List<PlanPin> pins;

  const PlanPinsView({
    super.key,
    required this.imagePath,
    this.imageSize,
    this.pins = const [],
  });

  @override
  Widget build(BuildContext context) {
    final known = imageSize;
    if (known != null) return _stack(known);
    return FutureBuilder<Size?>(
      future: planImageSize(imagePath),
      builder: (_, snap) => _stack(snap.data),
    );
  }

  Widget _stack(Size? image) => LayoutBuilder(
    builder: (context, c) {
      final box = Size(c.maxWidth, c.maxHeight);
      final r = image == null ? Offset.zero & box : containRect(image, box);
      return Stack(
        fit: StackFit.expand,
        children: [
          PhotoImage(imagePath, fit: BoxFit.contain),
          if (image != null)
            for (final p in pins)
              Positioned(
                left: r.left +
                    p.at.dx * r.width -
                    p.markerSize.width * (p.anchor.x + 1) / 2,
                top: r.top +
                    p.at.dy * r.height -
                    p.markerSize.height * (p.anchor.y + 1) / 2,
                width: p.markerSize.width,
                height: p.markerSize.height,
                child: p.marker,
              ),
        ],
      );
    },
  );
}
