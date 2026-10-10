// 접지 러그·취부 보조(10-03): 러그 구멍 간격 칩, 구멍 지름에 맞는 볼트, 판넬 취부 구멍 자리.
// 러그 구멍 자체는 busbar_ground.dart가 접지 구멍과 따로 부스바 가운데에 추가한다.
library;

import 'busbar_ground.dart';

/// 러그 구멍 간격 칩(mm): NEMA 2구멍 러그 3/4"·1"·1-3/4".
const List<double> kLugSpacings = [19.05, 25.4, 44.45];

/// 구멍 지름에 맞는 볼트(KS B ISO 273 보통급 틈새 구멍·NEMA 접지바 구멍). 모르면 null.
/// 10-10: 0.15mm 안에서 가장 가까운 값으로 고른다(11은 M10, 11.1은 3/8" 또는 M10).
String? lugBoltFor(double holeDia) {
  const table = <(double, String)>[
    (6.6, 'M6'),
    (7.9, '1/4"(6.35mm)'),
    (9, 'M8'),
    (11.1, '3/8"(9.5mm) 또는 M10'),
    (11, 'M10'),
    (13.5, 'M12'),
    (17.5, 'M16'),
    (22, 'M20'),
  ];
  String? best;
  var bestGap = double.infinity;
  for (final (d, name) in table) {
    final gap = (d - holeDia).abs();
    if (gap <= 0.15 + 1e-9 && gap < bestGap) {
      best = name;
      bestGap = gap;
    }
  }
  return best;
}

/// 발 구멍으로 접지바를 판넬에 취부할 때 판넬에 뚫을 자리 하나.
class PanelHole {
  final GroundHole hole;

  /// 판넬에서 가장 왼쪽 구멍을 0으로 한 가로 거리, 막대 A쪽 가장자리에서 잰 세로 거리(mm).
  final double x, y;
  const PanelHole(this.hole, this.x, this.y);
}

/// 모자 모양으로 꺾은 접지바를 판넬에 올렸을 때 발 구멍 자리(판넬 구멍 뚫는 위치).
/// 발 길이는 다리 바깥면에서 발 끝까지(바깥 치수). 일자(꺾기 없음)는 양 끝 취부 구멍 자리를 그대로(10-10).
/// 끝 L자이거나 취부 구멍이 없으면 빈 목록.
List<PanelHole> panelPattern(
  GroundBarPlan p, {
  required double flangeLeft,
  required double flangeRight,
}) {
  final straight = !p.hat && p.flatTabL == 0 && p.flatTabR == 0;
  if (p.tabHoleList.isEmpty || (!p.hat && !straight)) return const [];
  final raw = <(GroundHole, double)>[];
  for (final h in p.tabHoleList) {
    if (!p.hat) {
      raw.add((h, h.x));
      continue;
    }
    final left = h.id.startsWith('tL-');
    // 왼쪽 다리 바깥면을 0으로, 오른쪽은 윗면 바깥 폭만큼 더 간 자리
    final x = left
        ? -(flangeLeft - h.x)
        : p.hatWidth + (flangeRight - (p.length - h.x));
    raw.add((h, x));
  }
  final min = raw.map((e) => e.$2).reduce((a, b) => a < b ? a : b);
  final out = [for (final (h, x) in raw) PanelHole(h, x - min, h.y)];
  out.sort((a, b) => a.x != b.x ? a.x.compareTo(b.x) : a.y.compareTo(b.y));
  return out;
}
