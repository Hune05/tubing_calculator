// 접지 러그 취부 계산(10-03): 접지바 구멍 중 어느 구멍에 러그를 달지, 볼트가 몇 개 드는지 정한다.
// 화면 없이 계산만 한다.
//  · 러그 1구멍은 구멍 하나, 2구멍은 러그 구멍 간격 S만큼 떨어진 구멍 둘을 쓴다.
//    S가 구멍 피치 P의 정수배(step = S ÷ P)여야 한다. 아니면 피치를 러그 간격에 맞추라고 알린다.
//  · 러그는 시작 구멍 번호부터 차례로 붙인다. 러그가 덮는 구멍 다음에 [skip]개 구멍을 비우고 다음 러그.
//  · 볼트 한 개: 볼트 1, 너트 1, 평와셔 2, 스프링 와셔 1. 볼트 길이 하한은 러그 패드 + 부스바 두께(그립)에
//    와셔·너트·나사 여유를 더한 값이다(와셔·너트 두께는 제품마다 달라 넣지 않았다).
library;

import 'busbar_ground.dart';

/// 러그 구멍 간격 칩(mm): NEMA 2구멍 러그 3/4"·1"·1-3/4".
const List<double> kLugSpacings = [19.05, 25.4, 44.45];

/// 러그 하나가 쓰는 구멍.
class LugPlacement {
  final int number; // 러그 번호(1부터)
  final List<GroundHole> holes;
  const LugPlacement(this.number, this.holes);
}

class LugPlan {
  final List<LugPlacement> lugs;

  /// 볼트 세트 수(쓰는 구멍 수와 같다).
  final int bolts;

  /// 러그 패드 + 부스바 두께(mm): 볼트가 지나는 두께.
  final double grip;

  /// 구멍 지름에 맞는 볼트 이름. 모르는 지름이면 null.
  final String? boltName;

  final List<String> problems;

  bool get ok => problems.isEmpty;

  const LugPlan({
    required this.lugs,
    required this.bolts,
    required this.grip,
    required this.boltName,
    required this.problems,
  });

  /// 러그가 쓰는 구멍 번호(그림에서 표시).
  Set<String> get usedIds => {
    for (final l in lugs)
      for (final h in l.holes) h.id,
  };
}

/// 구멍 지름에 맞는 볼트(KS B ISO 273 보통급 틈새 구멍·NEMA 접지바 구멍). 모르면 null.
String? lugBoltFor(double holeDia) {
  const table = <(double, String)>[
    (6.6, 'M6'),
    (7.9, '1/4"(6.35mm)'),
    (9, 'M8'),
    (11.1, '3/8"(9.5mm) 또는 M10'),
    (11, 'M10'),
    (13.5, 'M12'),
    (17.5, 'M16'),
  ];
  for (final (d, name) in table) {
    if ((d - holeDia).abs() <= 0.15) return name;
  }
  return null;
}

/// [row] 접지 구멍 줄(왼쪽에서 오른쪽 순서), [pitch] 그 줄의 구멍 피치,
/// [lugHoles] 러그 구멍 수(1·2), [spacing] 2구멍 러그의 구멍 간격, [count] 러그 개수,
/// [start] 첫 러그의 시작 구멍 번호(1부터), [skip] 러그 사이 비울 구멍 수.
LugPlan lugPlan({
  required List<GroundHole> row,
  required double pitch,
  required int lugHoles,
  required double spacing,
  required int count,
  int start = 1,
  int skip = 0,
  double lugPad = 0,
  double barThick = 0,
  bool centered = false,
}) {
  final problems = <String>[];
  final lugs = <LugPlacement>[];
  var step = 0;
  if (lugHoles == 2) {
    step = pitch > 0 ? (spacing / pitch).round() : 0;
    if (step < 1) {
      problems.add(
        '러그 구멍 간격 ${_f(spacing)}mm가 구멍 피치 ${_f(pitch)}mm보다 작아 두 구멍을 같은 러그에 쓸 수 없습니다. 피치를 러그 간격에 맞추십시오.',
      );
    } else if ((spacing - step * pitch).abs() > 0.5) {
      problems.add(
        '러그 구멍 간격 ${_f(spacing)}mm가 구멍 피치 ${_f(pitch)}mm의 정수배가 아닙니다(가장 가까운 ${_f(step * pitch)}mm). 피치를 ${_f(spacing / (step < 1 ? 1 : step))}mm로 하거나 러그 간격을 맞추십시오.',
      );
    }
  }
  if (count < 1) problems.add('러그 개수를 1개 이상으로 넣으십시오.');
  if (problems.isEmpty) {
    var at = (start < 1 ? 1 : start) - 1;
    if (centered && row.isNotEmpty) {
      // 러그 묶음이 덮는 구멍 수 H를 구멍 줄 가운데에 놓는다(홀수 차이는 가운데에 가까운 쪽).
      final span = lugHoles == 2 ? step + 1 : 1;
      final covered = count * span + (count - 1) * skip;
      final lo = ((row.length - covered) / 2).floor().clamp(0, row.length);
      final mid = (row.first.x + row.last.x) / 2;
      double off(int a) {
        if (a < 0 || a + covered > row.length) return double.infinity;
        return ((row[a].x + row[a + covered - 1].x) / 2 - mid).abs();
      }

      at = off(lo) <= off(lo + 1) ? lo : lo + 1;
      if (at + covered > row.length) at = lo;
    }
    for (var i = 0; i < count; i++) {
      final last = at + (lugHoles == 2 ? step : 0);
      if (last >= row.length) {
        problems.add(
          '러그 ${i + 1}번이 구멍 ${row.length}개를 넘어갑니다. 러그 수를 줄이거나 시작·비움을 조정하십시오.',
        );
        break;
      }
      lugs.add(
        LugPlacement(i + 1, [row[at], if (lugHoles == 2) row[at + step]]),
      );
      at = last + 1 + skip;
    }
  }
  final used = lugs.fold<int>(0, (a, l) => a + l.holes.length);
  final dia = row.isEmpty ? 0.0 : row.first.dia;
  return LugPlan(
    lugs: lugs,
    bolts: used,
    grip: lugPad + barThick,
    boltName: lugBoltFor(dia),
    problems: problems,
  );
}

String _f(double v) {
  var s = v.toStringAsFixed(1);
  if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
  return s;
}

/// 챙 구멍으로 접지바를 판넬에 취부할 때 판넬에 뚫을 자리 하나.
class PanelHole {
  final GroundHole hole;

  /// 판넬에서 가장 왼쪽 구멍을 0으로 한 가로 거리, 막대 A쪽 가장자리에서 잰 세로 거리(mm).
  final double x, y;
  const PanelHole(this.hole, this.x, this.y);
}

/// 모자 모양으로 꺾은 접지바를 판넬에 올렸을 때 챙 구멍 자리(판넬 구멍 뚫는 위치).
/// 챙 길이는 다리 바깥면에서 챙 끝까지(바깥 치수). 모자가 아니거나 챙 구멍이 없으면 빈 목록.
List<PanelHole> panelPattern(
  GroundBarPlan p, {
  required double flangeLeft,
  required double flangeRight,
}) {
  if (!p.hat || p.tabHoleList.isEmpty) return const [];
  final raw = <(GroundHole, double)>[];
  for (final h in p.tabHoleList) {
    final left = h.label.startsWith('왼쪽');
    // 왼쪽 다리 바깥면을 0으로, 오른쪽은 몸체 바깥 폭만큼 더 간 자리
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
