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

/// 짧은 구간 경고("N번 구간: 앞뒤 벤드를 빼면 곧은 부분이 …")의 번호를 뽑는다.
final RegExp _shortSegment = RegExp(r'^(\d+)번 구간: 앞뒤 벤드를 빼면');
final RegExp _segmentNo = RegExp(r'(\d+)번 구간');

/// 배관 목록을 공간에서 걸어 보고 점검한다.
///
/// [bendList]는 화면이 들고 있는 그대로('length'·'angle'·'rotation').
/// [outerDiameter]가 0이면 닿는지는 보지 않는다.
///
/// 🚀 [고침] 직관(0°)은 다음 구간에 합쳐서 본다. 직관 150 다음에 7mm짜리
/// 21° 구간이 와도 한 줄로 이어진 관이라 꺾을 수 있는데, 구간을 따로 보면
/// "곧은 부분 -14mm, 만들 수 없습니다"로 잡혔다. 엔진이 같은 까닭으로 낸
/// 경고(직관 옆 구간)도 합쳐 본 결과로 바꾼다. 경고 글의 구간 번호는 입력
/// 목록 번호 그대로다.
BendCheck checkBends(
  List<dynamic> bendList, {
  required double radius,
  required String startDir,
  double tail = 0.0,
  double outerDiameter = 0.0,
  List<String> engineWarnings = const [],
}) {
  final input = <PathSegment>[
    for (final raw in bendList)
      if (raw is Map)
        PathSegment(
          length: (raw['length'] as num?)?.toDouble() ?? 0.0,
          angle: (raw['angle'] as num?)?.toDouble() ?? 0.0,
          rotation: (raw['rotation'] as num?)?.toDouble() ?? 0.0,
        ),
  ];
  if (input.isEmpty) {
    return BendCheck(warnings: List<String>.from(engineWarnings));
  }

  // 직관을 다음 구간에 합친다(마지막 직관은 꼬리라 그대로 둔다).
  final segs = <PathSegment>[];
  final origNo = <int>[]; // 합친 목록 번호(0부터) → 입력 목록 번호(1부터)
  double carry = 0.0;
  for (int i = 0; i < input.length; i++) {
    final s = input[i];
    final isLast = i == input.length - 1;
    if (s.angle <= 0 && !isLast) {
      carry += s.length;
      continue;
    }
    segs.add(
      carry > 0
          ? PathSegment(
              length: s.length + carry,
              angle: s.angle,
              rotation: s.rotation,
            )
          : s,
    );
    origNo.add(i + 1);
    carry = 0.0;
  }
  String renumber(String w) => w.replaceAllMapped(_segmentNo, (m) {
    final n = int.parse(m.group(1)!);
    return '${(n >= 1 && n <= origNo.length) ? origNo[n - 1] : n}번 구간';
  });

  // 엔진 경고 중 직관 옆 구간의 "곧은 부분 음수"는 합쳐 본 결과로 바꾼다.
  bool besideStraight(int no) {
    final i = no - 1;
    if (i < 0 || i >= input.length) return false;
    final selfStraight = input[i].angle <= 0 && i != input.length - 1;
    final prevStraight = i > 0 && input[i - 1].angle <= 0;
    return selfStraight || prevStraight;
  }

  final kept = engineWarnings.where((w) {
    final m = _shortSegment.firstMatch(w);
    return m == null || !besideStraight(int.parse(m.group(1)!));
  }).toList();

  final path = buildBendPath(
    segs,
    radius: radius,
    startDirection: directionForName(startDir),
    tail: tail,
  );

  final pathWarnings = [for (final w in path.warnings) renumber(w)];
  return BendCheck(
    warnings: [
      ...kept,
      // 공간 기하가 본 것(짧은 구간·못 꺾는 방향·쓸 수 없는 방향값).
      // 엔진이 이미 말한 것과 겹치면 한 번만 보여 준다.
      ...pathWarnings.where((w) => !kept.contains(w)),
      ...selfInterferenceWarnings(path, outerDiameter: outerDiameter)
          .map(renumber),
    ],
    rollByIndex: {
      for (final b in path.bends)
        if (b.rollDeg > 0.5 && b.index >= 0 && b.index < origNo.length)
          origNo[b.index] - 1: b.rollDeg,
    },
  );
}
