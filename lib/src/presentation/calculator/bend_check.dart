/// 마킹 화면들이 같이 쓰는 형상 점검.
///
/// 엔진이 내는 경고(짧은 구간·못 꺾는 방향)에 더해, 관이 저희끼리 닿는지
/// 보고 굴림(롤) 각도를 뽑는다.
///
/// 🚀 [고침] 예전에는 이 점검이 폰 결과 탭에만 있었다. 태블릿 마킹 화면과
/// 전선관 마킹 화면은 만들 수 없는 형상도 그냥 값을 찍어 줬다.
library;

import 'package:tubing_calculator/src/core/engine/bend_path.dart';

class BendCheck {
  /// 화면에 띄울 경고 글.
  final List<String> warnings;

  /// 구간 번호(0부터) → 앞 벤드에서 관을 굴릴 각도.
  final Map<int, double> rollByIndex;

  const BendCheck({this.warnings = const [], this.rollByIndex = const {}});

  bool get hasWarning => warnings.isNotEmpty;
}

/// 배관 목록을 공간에서 걸어 보고 점검한다.
///
/// [bendList]는 화면이 들고 있는 그대로('length'·'angle'·'rotation').
/// [outerDiameter]가 0이면 닿는지는 보지 않는다.
BendCheck checkBends(
  List<dynamic> bendList, {
  required double radius,
  required String startDir,
  double tail = 0.0,
  double outerDiameter = 0.0,
  List<String> engineWarnings = const [],
}) {
  final segs = <PathSegment>[
    for (final raw in bendList)
      if (raw is Map)
        PathSegment(
          length: (raw['length'] as num?)?.toDouble() ?? 0.0,
          angle: (raw['angle'] as num?)?.toDouble() ?? 0.0,
          rotation: (raw['rotation'] as num?)?.toDouble() ?? 0.0,
        ),
  ];
  if (segs.isEmpty) {
    return BendCheck(warnings: List<String>.from(engineWarnings));
  }

  final path = buildBendPath(
    segs,
    radius: radius,
    startDirection: directionForName(startDir),
    tail: tail,
  );

  return BendCheck(
    warnings: [
      ...engineWarnings,
      // 공간 기하가 본 것(짧은 구간·못 꺾는 방향·쓸 수 없는 방향값).
      // 엔진이 이미 말한 것과 겹치면 한 번만 보여 준다.
      ...path.warnings.where((w) => !engineWarnings.contains(w)),
      ...selfInterferenceWarnings(path, outerDiameter: outerDiameter),
    ],
    rollByIndex: {
      for (final b in path.bends)
        if (b.rollDeg > 0.5) b.index: b.rollDeg,
    },
  );
}
