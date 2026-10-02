// 접지바 구멍 계산기(10-03): 구리 평강에 볼트 구멍을 한 줄 또는 두 줄로 뚫고, 끝을 L자 탭이나 챙 달린
// 모자 모양으로 꺾어 접지바를 만들 때 자르는 길이와 구멍·꺾기 위치. 화면 없이 계산만 한다.
//  · 구멍 줄은 폭 가운데(한 줄) 또는 가운데에서 위아래로 줄 간격의 반씩(두 줄). 위치는 왼쪽 끝에서 구멍
//    중심까지(길이 방향 x), 막대 한쪽(A줄 쪽) 가장자리에서 구멍 중심까지(폭 방향 y).
//  · 두 줄은 대칭(두 줄 구멍이 같은 x에 마주 봄)이거나 비대칭(엇갈림: B줄을 길이 방향으로 shift만큼 옮김,
//    비우면 반 피치).
//  · 구멍 수로 정하면 구멍 줄 길이 = 2e + (n−1)p + 엇갈림. 길이로 정하면 n = ⌊(줄 길이 − 2e − 엇갈림) ÷ p⌋ + 1이고,
//    남는 길이는 양 끝 여유에 똑같이 나눈다.
//  · 끝 여유 e는 곧은 구간 끝에서 첫 구멍 중심까지다. 끝이 꺾여 있으면 꺾기 끝선에서 잰다.
//  · 꺾기는 눕혀 꺾기(두께 방향) 90°로 busbar_bend.dart와 같은 식이다. 치수는 모두 바깥 치수.
//     - L 탭: 끝에서 바깥 모서리까지 A. 곧은 길이 = A − (r + t).
//     - 모자: 챙 F(끝에서 다리 바깥면까지, 왼쪽·오른쪽 따로) · 높이 H(챙 바닥면에서 윗면까지) · 몸체는 구멍 줄.
//       곧은 길이 = 챙 F − (r + t), 다리 H − 2(r + t). 꺾기 4곳(위로·아래로·아래로·위로).
//  · 탭(챙)에도 같은 줄 수로 구멍을 뚫는다. 탭의 평평한 길이 가운데에 모아 놓는다.
//  · 구멍마다 크기를 따로 줄 수 있다(overrides: 구멍 번호 → 지름).
//  · 무게는 구리 밀도 8.9 g/cm³로 구멍 뺀 부피를 곱한 근사값이다.
library;

import 'dart:math' as math;

import 'busbar_bend.dart';

/// 구리 밀도(kg/mm³): 8.9 g/cm³.
const double kCopperKgPerMm3 = 8.9e-6;

/// 구멍 지름 칩(mm). NEMA 접지바 7/16"(3/8" 볼트용), 통신 접지바 5/16"(1/4" 볼트용).
const List<double> kGroundHoleDias = [7.9, 11.1];

/// 구멍 피치 칩(mm). 5/8"(통신 5/16" 구멍 줄), 3/4"·1"(NEMA 2구멍 러그), 1-3/4"(NEMA 러그 패드).
const List<double> kGroundPitches = [15.875, 19.05, 25.4, 44.45];

/// 한 줄에 가장 많이 뚫는 구멍 수(화면·그림이 감당하는 한도).
const int kGroundMaxHoles = 60;

/// 구멍 하나.
class GroundHole {
  /// 번호(바꾸기 키): 접지 구멍 'gA3', 탭·챙 구멍 'tL-A1'·'tR-B2'.
  final String id;

  /// 화면에 보이는 이름: '3번', 'A3', '왼쪽 1', '오른쪽 B2'.
  final String label;

  /// 왼쪽 끝에서 구멍 중심까지, 막대 A쪽 가장자리에서 구멍 중심까지(mm).
  final double x, y;

  /// 지름(mm). [custom]이면 사용자가 따로 정한 값.
  final double dia;
  final bool custom;

  const GroundHole({
    required this.id,
    required this.label,
    required this.x,
    required this.y,
    required this.dia,
    required this.custom,
  });
}

class GroundBarPlan {
  /// 자르는 길이(mm).
  final double length;

  /// 한 줄의 접지 구멍 수.
  final int holes;

  /// 줄 수(1 또는 2).
  final int rows;

  /// A줄·B줄 접지 구멍의 왼쪽 끝에서 중심까지 거리(mm). B줄은 한 줄이면 비어 있음.
  final List<double> positions, positionsB;

  /// 접지 구멍 전부(A줄 다음 B줄)와 탭·챙 구멍 전부(왼쪽 다음 오른쪽).
  final List<GroundHole> groundHoles, tabHoleList;

  /// 구멍 줄이 놓이는 곧은 구간(왼쪽 끝에서 잰 시작·끝, mm). 끝 여유 e는 여기서부터 잰다.
  final double flatStart, flatEnd;

  /// 곧은 구간 끝에서 첫·마지막 구멍 중심까지(mm).
  final double endLeft, endRight;

  /// 구멍 줄 위치: 폭 방향(막대 A쪽 가장자리에서, mm). 한 줄이면 [rowY]는 하나.
  final List<double> rowY;

  /// B줄을 길이 방향으로 옮긴 거리(mm, 엇갈림이 아니면 0).
  final double stagger;

  /// 대략 무게(kg, 구멍 뺌).
  final double weightKg;

  /// 꺾기(왼쪽 → 오른쪽 순서, 없으면 비어 있음). 시작·끝선은 왼쪽 끝에서 잰 거리.
  final List<BusbarBend> bends;

  /// 꺾기가 있을 때 옆모습 그림용 계산(없으면 null)과 그리기 시작 방향(°).
  final BusbarBendPlan? bendPlan;
  final double startHeading;

  /// 탭·챙 한 곳의 곧은(평평한) 길이(mm): 왼쪽·오른쪽. 없으면 0.
  final double flatTabL, flatTabR;

  /// 모자 모양인지, 그때의 몸체 바깥 폭(다리 바깥면 사이, mm).
  final bool hat;
  final double hatWidth;

  /// 만들 수 없는 이유들(비어 있으면 가능).
  final List<String> problems;

  bool get ok => problems.isEmpty;

  /// 바꾼 크기가 있는 구멍 수.
  int get customCount =>
      groundHoles.where((h) => h.custom).length +
      tabHoleList.where((h) => h.custom).length;

  const GroundBarPlan({
    required this.length,
    required this.holes,
    required this.rows,
    required this.positions,
    required this.positionsB,
    required this.groundHoles,
    required this.tabHoleList,
    required this.flatStart,
    required this.flatEnd,
    required this.endLeft,
    required this.endRight,
    required this.rowY,
    required this.stagger,
    required this.weightKg,
    required this.bends,
    required this.bendPlan,
    required this.startHeading,
    required this.flatTabL,
    required this.flatTabR,
    required this.hat,
    required this.hatWidth,
    required this.problems,
  });
}

String _f(double v) {
  var s = v.toStringAsFixed(1);
  if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
  return s;
}

/// [t]·[w] 두께·폭, [holeDia] 접지 구멍 기본 지름, [pitch] 구멍 피치, [endDist] 끝 여유.
/// [count]를 주면 한 줄 구멍 수로, [length]를 주면 막대 길이(자르는 길이)로 정한다(둘 다 있으면 [count]).
/// [tabLeft]·[tabRight]는 끝 L 탭의 바깥 길이(0이면 꺾지 않음), [r]·[k]는 꺾기 안쪽 반경·중립선 계수.
/// [hat]이면 챙 달린 모자 모양: [hatFlange] 왼쪽 챙, [hatFlangeRight] 오른쪽 챙(null이면 같음), [hatHeight] 높이.
/// [rows] 1 또는 2, [rowGap] 두 줄 사이 간격, [staggered] 두 줄을 엇갈리게(비대칭), [shift] 엇갈림 거리(null이면 반 피치).
/// [tabHoleCount]개(줄마다) 구멍(지름 [tabHoleDia], 피치 [tabHolePitch])을 탭·챙 평평한 길이 가운데에 뚫는다.
/// [overrides]로 구멍마다 지름을 따로 준다(키는 [GroundHole.id]).
GroundBarPlan groundBar({
  required double t,
  required double w,
  required double holeDia,
  required double pitch,
  required double endDist,
  int? count,
  double? length,
  double tabLeft = 0,
  double tabRight = 0,
  double? r,
  double k = 0.4,
  bool hat = false,
  double hatHeight = 0,
  double hatFlange = 0,
  double? hatFlangeRight,
  int rows = 1,
  double rowGap = 0,
  bool staggered = false,
  double? shift,
  int tabHoleCount = 0,
  double tabHoleDia = 0,
  double tabHolePitch = 0,
  Map<String, double> overrides = const {},
}) {
  final problems = <String>[];
  void warn(String s) {
    if (!problems.contains(s)) problems.add(s);
  }

  final rr = r ?? t;
  final os = rr + t; // 90° 바깥 모서리 물림(바깥 모서리에서 꺾기 시작선까지)
  final arc = busbarArc(t, rr, k, 90);
  final s = busbarSetback(t, rr, k, 90); // 중립선 물림
  final nRows = rows == 2 ? 2 : 1;
  final yA = nRows == 1 ? w / 2 : w / 2 - rowGap / 2;
  final yB = w / 2 + rowGap / 2;
  final rowY = nRows == 1 ? [yA] : [yA, yB];

  // 탭·챙 한 곳: 평평한 길이와 막대 길이를 차지하는 양
  var flatL = 0.0, flatR = 0.0, spanL = 0.0, spanR = 0.0;
  if (hat) {
    final fl = hatFlange, fr = hatFlangeRight ?? hatFlange;
    if (fl < os) {
      warn('왼쪽 챙 ${_f(fl)}mm는 안쪽 반경 ${_f(rr)}mm로 꺾기에 너무 짧습니다. 최소 ${_f(os)}mm.');
    }
    if (fr < os) {
      warn(
        '오른쪽 챙 ${_f(fr)}mm는 안쪽 반경 ${_f(rr)}mm로 꺾기에 너무 짧습니다. 최소 ${_f(os)}mm.',
      );
    }
    if (hatHeight < 2 * os) {
      warn(
        '모자 높이 ${_f(hatHeight)}mm는 안쪽 반경 ${_f(rr)}mm로 꺾기에 너무 낮습니다. 최소 ${_f(2 * os)}mm.',
      );
    }
    flatL = fl - os;
    flatR = fr - os;
    final leg = hatHeight - 2 * os + arc;
    spanL = flatL + arc + leg;
    spanR = flatR + arc + leg;
  } else {
    if (tabLeft > 0) {
      if (tabLeft < os) {
        warn(
          '왼쪽 탭 ${_f(tabLeft)}mm는 안쪽 반경 ${_f(rr)}mm로 꺾기에 너무 짧습니다. 최소 ${_f(os)}mm.',
        );
      }
      flatL = tabLeft - os;
      spanL = flatL + arc;
    }
    if (tabRight > 0) {
      if (tabRight < os) {
        warn(
          '오른쪽 탭 ${_f(tabRight)}mm는 안쪽 반경 ${_f(rr)}mm로 꺾기에 너무 짧습니다. 최소 ${_f(os)}mm.',
        );
      }
      flatR = tabRight - os;
      spanR = flatR + arc;
    }
  }

  // 접지 구멍 줄 길이 계산
  final st = nRows == 2 && staggered ? (shift ?? pitch / 2) : 0.0;
  var n = 0;
  var run = 0.0; // 접지 구멍 줄이 놓이는 곧은 구간 길이
  var len = 0.0;
  if (count != null) {
    n = count;
    run = n < 1 ? 0 : 2 * endDist + (n - 1) * pitch + st;
    len = run + spanL + spanR;
  } else if (length != null) {
    len = length;
    run = len - spanL - spanR;
    n = run < 2 * endDist + st || pitch <= 0
        ? 0
        : ((run - 2 * endDist - st) / pitch + 1e-9).floor() + 1;
  }
  if (n > kGroundMaxHoles) {
    warn('구멍이 한 줄에 $kGroundMaxHoles개를 넘어 계산하지 않습니다.');
    n = 0;
  }
  if (n < 1) warn('구멍이 들어갈 자리가 없습니다. 길이나 구멍 수를 늘리십시오.');
  if (holeDia >= w) warn('구멍 지름이 부스바 폭보다 크거나 같습니다.');
  if (endDist < holeDia / 2) {
    warn('끝 여유가 구멍 반지름보다 작아 구멍이 끝 면을 뚫습니다.');
  }
  if (nRows == 2 && rowGap <= 0) warn('두 줄은 줄 간격이 있어야 합니다.');
  final holeRun = n < 1 ? 0.0 : 2 * endDist + (n - 1) * pitch + st;
  final rest = n < 1 ? 0.0 : run - holeRun;
  final first = spanL + endDist + rest / 2;

  double dOf(String id) => overrides[id] ?? holeDia;
  final ground = <GroundHole>[];
  final posA = <double>[], posB = <double>[];
  for (var row = 0; row < nRows; row++) {
    final letter = row == 0 ? 'A' : 'B';
    for (var i = 0; i < n; i++) {
      final id = 'g$letter${i + 1}';
      final x = first + (row == 1 ? st : 0) + i * pitch;
      (row == 0 ? posA : posB).add(x);
      ground.add(
        GroundHole(
          id: id,
          label: nRows == 1 ? '${i + 1}번' : '$letter${i + 1}',
          x: x,
          y: rowY[row],
          dia: dOf(id),
          custom: overrides.containsKey(id),
        ),
      );
    }
  }

  // 탭·챙 구멍: 평평한 길이 가운데에 모은다. 줄마다 tabHoleCount개.
  final tabs = <GroundHole>[];
  final hasTabs = hat || tabLeft > 0 || tabRight > 0;
  if (hasTabs && tabHoleCount > 0 && tabHoleDia > 0) {
    final stT = nRows == 2 && staggered && tabHoleCount > 1
        ? tabHolePitch / 2
        : 0.0;
    void side(String letter, String name, double flat, bool left) {
      if (flat <= 0) return;
      final group = (tabHoleCount - 1) * tabHolePitch + stT;
      final start = (flat - group) / 2;
      for (var row = 0; row < nRows; row++) {
        final rl = row == 0 ? 'A' : 'B';
        for (var i = 0; i < tabHoleCount; i++) {
          final off = start + (row == 1 ? stT : 0) + i * tabHolePitch;
          final id = 't$letter-$rl${i + 1}';
          tabs.add(
            GroundHole(
              id: id,
              label: nRows == 1 ? '$name ${i + 1}' : '$name $rl${i + 1}',
              x: left ? off : len - off,
              y: rowY[row],
              dia: overrides[id] ?? tabHoleDia,
              custom: overrides.containsKey(id),
            ),
          );
        }
      }
      for (final h in tabs.where((h) => h.id.startsWith('t$letter-'))) {
        final off = left ? h.x : len - h.x;
        if (off - h.dia / 2 < -1e-9 || off + h.dia / 2 > flat + 1e-9) {
          warn(
            '탭 구멍이 평평한 길이 ${_f(flat)}mm에 들어가지 않습니다. 탭을 늘리거나 구멍 수·피치를 줄이십시오.',
          );
        }
      }
    }

    side('L', '왼쪽', hat || tabLeft > 0 ? flatL : 0, true);
    side('R', '오른쪽', hat || tabRight > 0 ? flatR : 0, false);
    if (tabHoleCount > 1 && tabHolePitch <= tabHoleDia) {
      warn('탭 구멍 피치가 구멍 지름 이하라 구멍이 서로 겹칩니다.');
    }
  }

  // 구멍 검사(접지 구멍): 폭 안, 곧은 구간 안, 겹침
  // 같은 종류의 문제는 구멍마다 반복하지 않고 한 줄로 묶는다.
  String names(List<String> l) =>
      l.length <= 3 ? l.join('·') : '${l.take(3).join('·')} 외 ${l.length - 3}개';
  final tooBig = <String>[], outWidth = <String>[], outFlat = <String>[];
  for (final h in [...ground, ...tabs]) {
    if (h.dia >= w) {
      tooBig.add(h.label);
    } else if (h.y - h.dia / 2 < -1e-9 || h.y + h.dia / 2 > w + 1e-9) {
      outWidth.add(h.label);
    }
  }
  for (final h in ground) {
    if (n > 0 &&
        (h.x - h.dia / 2 < spanL - 1e-9 ||
            h.x + h.dia / 2 > len - spanR + 1e-9)) {
      outFlat.add(h.label);
    }
  }
  if (tooBig.isNotEmpty) {
    warn('구멍 ${names(tooBig)} 지름이 부스바 폭보다 크거나 같습니다.');
  }
  if (outWidth.isNotEmpty) {
    warn('구멍 ${names(outWidth)}이 부스바 폭 밖으로 나옵니다. 줄 간격이나 지름을 줄이십시오.');
  }
  if (outFlat.isNotEmpty) {
    warn('구멍 ${names(outFlat)}이 곧은 구간(꺾기 선) 밖으로 나옵니다. 끝 여유를 늘리거나 지름을 줄이십시오.');
  }
  void overlap(List<GroundHole> a) {
    var sameRow = false;
    final cross = <String>[];
    for (var i = 0; i < a.length; i++) {
      for (var j = i + 1; j < a.length; j++) {
        final dx = a[i].x - a[j].x, dy = a[i].y - a[j].y;
        if (math.sqrt(dx * dx + dy * dy) <= (a[i].dia + a[j].dia) / 2 - 1e-9) {
          if (dy.abs() < 1e-9) {
            sameRow = true;
          } else {
            cross.add('${a[i].label}-${a[j].label}');
          }
        }
      }
    }
    if (sameRow) warn('구멍 피치가 구멍 지름 이하라 구멍이 서로 겹칩니다.');
    if (cross.isNotEmpty) {
      warn('두 줄 구멍(${names(cross)})이 서로 겹칩니다. 줄 간격이나 엇갈림을 늘리십시오.');
    }
  }

  overlap(ground);
  overlap(tabs);

  // 꺾기 계산(옆모습 그림·꺾기 선).
  BusbarBendPlan? bp;
  var heading = 0.0;
  if (n > 0 && hat) {
    final leg = hatHeight - 2 * os;
    bp = busbarBendPlan(
      d: t,
      r: rr,
      k: k,
      legs: [flatL + s, leg + 2 * s, run + 2 * s, leg + 2 * s, flatR + s],
      turns: const [90, -90, -90, 90],
    );
  } else if (n > 0 && (tabLeft > 0 || tabRight > 0)) {
    final adj = busbarDimAdjust(t, k, 90, BusbarDimRef.outside);
    final main = run + (tabLeft > 0 ? s : 0) + (tabRight > 0 ? s : 0);
    bp = busbarBendPlan(
      d: t,
      r: rr,
      k: k,
      legs: [
        if (tabLeft > 0) tabLeft + adj,
        main,
        if (tabRight > 0) tabRight + adj,
      ],
      turns: [if (tabLeft > 0) 90, if (tabRight > 0) 90],
    );
    heading = tabLeft > 0 ? -90 : 0;
  }
  final holeVol =
      [...ground, ...tabs].fold<double>(0, (a, h) => a + h.dia * h.dia) *
      math.pi /
      4 *
      t;
  final kg = math.max(0.0, t * w * len - holeVol) * kCopperKgPerMm3;
  final lastX = n < 1 ? 0.0 : first + (n - 1) * pitch + st;
  return GroundBarPlan(
    length: len,
    holes: n,
    rows: nRows,
    positions: posA,
    positionsB: posB,
    groundHoles: ground,
    tabHoleList: tabs,
    flatStart: spanL,
    flatEnd: len - spanR,
    endLeft: n < 1 ? 0 : first - spanL,
    endRight: n < 1 ? 0 : len - spanR - lastX,
    rowY: rowY,
    stagger: st,
    weightKg: kg,
    bends: bp?.bends ?? const [],
    bendPlan: bp,
    startHeading: heading,
    flatTabL: flatL,
    flatTabR: flatR,
    hat: hat,
    hatWidth: hat ? run + 2 * os : 0,
    problems: problems,
  );
}

/// 구멍 위치를 [per]개씩 묶은 줄(표시용): 예 (라벨 '1~5번', 값 [25, 50.4, …]).
List<(String, List<double>)> groundHoleRows(
  List<double> positions, {
  int per = 5,
  String prefix = '',
}) {
  final rows = <(String, List<double>)>[];
  for (var i = 0; i < positions.length; i += per) {
    final end = math.min(i + per, positions.length);
    rows.add((
      prefix.isEmpty
          ? (end - i == 1 ? '${i + 1}번' : '${i + 1}~$end번')
          : (end - i == 1 ? '$prefix${i + 1}' : '$prefix${i + 1}~$end'),
      positions.sublist(i, end),
    ));
  }
  return rows;
}
