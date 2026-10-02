// 접지바 구멍 계산기(10-03): 구리 평강에 볼트 구멍을 한 줄로 뚫고, 끝을 L자 탭이나 챙 달린 모자 모양으로
// 꺾어 접지바를 만들 때 자르는 길이와 구멍·꺾기 위치. 화면 없이 계산만 한다.
//  · 구멍은 폭 가운데 한 줄, 피치 p로 늘어선다. 위치는 왼쪽 끝에서 구멍 중심까지.
//  · 구멍 수로 정하면 구멍 줄 길이 = 2e + (n−1)p. 길이로 정하면 n = ⌊(줄 길이 − 2e) ÷ p⌋ + 1이고,
//    남는 길이는 양 끝 여유에 똑같이 나눈다.
//  · 끝 여유 e는 곧은 구간 끝에서 첫 구멍 중심까지다. 끝이 꺾여 있으면 꺾기 끝선에서 잰다.
//  · 꺾기는 눕혀 꺾기(두께 방향) 90°로 busbar_bend.dart와 같은 식이다. 치수는 모두 바깥 치수.
//     - L 탭: 끝에서 바깥 모서리까지 A. 곧은 길이 = A − (r + t).
//     - 모자: 챙 F(끝에서 다리 바깥면까지) · 높이 H(챙 바닥면에서 윗면까지) · 몸체는 구멍 줄.
//       곧은 길이 = 챙 F − (r + t), 다리 H − 2(r + t). 꺾기 4곳(위로·아래로·아래로·위로).
//  · 탭(챙)에도 구멍을 뚫는다. 탭의 평평한 길이 가운데에 모아 놓는다.
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

/// 가장 많이 뚫는 구멍 수(화면·그림이 감당하는 한도).
const int kGroundMaxHoles = 60;

class GroundBarPlan {
  /// 자르는 길이(mm).
  final double length;

  /// 접지 구멍 수.
  final int holes;

  /// 왼쪽 끝에서 접지 구멍 중심까지 거리(mm).
  final List<double> positions;

  /// 구멍 줄이 놓이는 곧은 구간(왼쪽 끝에서 잰 시작·끝, mm). 끝 여유 e는 여기서부터 잰다.
  final double flatStart, flatEnd;

  /// 곧은 구간 끝에서 첫·마지막 구멍 중심까지(mm).
  final double endLeft, endRight;

  /// 구멍 중심선: 폭 가운데(mm).
  final double centerLine;

  /// 대략 무게(kg, 구멍 뺌).
  final double weightKg;

  /// 꺾기(왼쪽 → 오른쪽 순서, 없으면 비어 있음). 시작·끝선은 왼쪽 끝에서 잰 거리.
  final List<BusbarBend> bends;

  /// 꺾기가 있을 때 옆모습 그림용 계산(없으면 null)과 그리기 시작 방향(°).
  final BusbarBendPlan? bendPlan;
  final double startHeading;

  /// 탭·챙 구멍 중심 위치(왼쪽 끝에서, mm)와 지름. 왼쪽 것이 먼저.
  final List<double> tabHoles;
  final double tabHoleDia;

  /// 탭·챙 한 곳의 곧은(평평한) 길이(mm). 탭이 없으면 0.
  final double tabFlat;

  /// 모자 모양인지, 그때의 몸체 바깥 폭(다리 바깥면 사이, mm).
  final bool hat;
  final double hatWidth;

  /// 만들 수 없는 이유들(비어 있으면 가능).
  final List<String> problems;

  bool get ok => problems.isEmpty;

  const GroundBarPlan({
    required this.length,
    required this.holes,
    required this.positions,
    required this.flatStart,
    required this.flatEnd,
    required this.endLeft,
    required this.endRight,
    required this.centerLine,
    required this.weightKg,
    required this.bends,
    required this.bendPlan,
    required this.startHeading,
    required this.tabHoles,
    required this.tabHoleDia,
    required this.tabFlat,
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

/// [t]·[w] 두께·폭, [holeDia] 접지 구멍 지름, [pitch] 구멍 피치, [endDist] 끝 여유.
/// [count]를 주면 구멍 수로, [length]를 주면 막대 길이(자르는 길이)로 정한다(둘 다 있으면 [count]).
/// [tabLeft]·[tabRight]는 끝 L 탭의 바깥 길이(0이면 꺾지 않음), [r]·[k]는 꺾기 안쪽 반경·중립선 계수.
/// [hat]이면 챙 달린 모자 모양: [hatFlange] 챙 길이, [hatHeight] 높이(탭 값은 쓰지 않음).
/// [tabHoleCount]개 구멍(지름 [tabHoleDia], 피치 [tabHolePitch])을 탭·챙 평평한 길이 가운데에 뚫는다.
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
  int tabHoleCount = 0,
  double tabHoleDia = 0,
  double tabHolePitch = 0,
}) {
  final problems = <String>[];
  final rr = r ?? t;
  final os = rr + t; // 90° 바깥 모서리 물림(바깥 모서리에서 꺾기 시작선까지)
  final arc = busbarArc(t, rr, k, 90);
  final s = busbarSetback(t, rr, k, 90); // 중립선 물림

  // 탭·챙 한 곳: 평평한 길이와 막대 길이를 차지하는 양(평평 + 호 + 모자는 다리까지)
  var flatL = 0.0, flatR = 0.0, spanL = 0.0, spanR = 0.0;
  if (hat) {
    if (hatFlange < os) {
      problems.add(
        '챙 ${_f(hatFlange)}mm는 안쪽 반경 ${_f(rr)}mm로 꺾기에 너무 짧습니다. 최소 ${_f(os)}mm.',
      );
    }
    if (hatHeight < 2 * os) {
      problems.add(
        '모자 높이 ${_f(hatHeight)}mm는 안쪽 반경 ${_f(rr)}mm로 꺾기에 너무 낮습니다. 최소 ${_f(2 * os)}mm.',
      );
    }
    flatL = flatR = hatFlange - os;
    spanL = spanR = flatL + arc + (hatHeight - 2 * os) + arc;
  } else {
    if (tabLeft > 0) {
      if (tabLeft < os) {
        problems.add(
          '왼쪽 탭 ${_f(tabLeft)}mm는 안쪽 반경 ${_f(rr)}mm로 꺾기에 너무 짧습니다. 최소 ${_f(os)}mm.',
        );
      }
      flatL = tabLeft - os;
      spanL = flatL + arc;
    }
    if (tabRight > 0) {
      if (tabRight < os) {
        problems.add(
          '오른쪽 탭 ${_f(tabRight)}mm는 안쪽 반경 ${_f(rr)}mm로 꺾기에 너무 짧습니다. 최소 ${_f(os)}mm.',
        );
      }
      flatR = tabRight - os;
      spanR = flatR + arc;
    }
  }

  var n = 0;
  var run = 0.0; // 접지 구멍 줄이 놓이는 곧은 구간 길이
  var len = 0.0;
  if (count != null) {
    n = count;
    run = n < 1 ? 0 : 2 * endDist + (n - 1) * pitch;
    len = run + spanL + spanR;
  } else if (length != null) {
    len = length;
    run = len - spanL - spanR;
    n = run < 2 * endDist || pitch <= 0
        ? 0
        : ((run - 2 * endDist) / pitch + 1e-9).floor() + 1;
  }
  if (n > kGroundMaxHoles) {
    problems.add('구멍이 $kGroundMaxHoles개를 넘어 계산하지 않습니다.');
    n = 0;
  }
  if (n < 1) problems.add('구멍이 들어갈 자리가 없습니다. 길이나 구멍 수를 늘리십시오.');
  if (holeDia >= w) problems.add('구멍 지름이 부스바 폭보다 크거나 같습니다.');
  if (n > 1 && pitch <= holeDia) {
    problems.add('구멍 피치가 구멍 지름 이하라 구멍이 서로 겹칩니다.');
  }
  if (endDist < holeDia / 2) {
    problems.add('끝 여유가 구멍 반지름보다 작아 구멍이 끝 면을 뚫습니다.');
  }
  final holeRun = n < 1 ? 0.0 : 2 * endDist + (n - 1) * pitch;
  final rest = n < 1 ? 0.0 : run - holeRun;
  final first = spanL + endDist + rest / 2;
  final pos = [for (var i = 0; i < n; i++) first + i * pitch];

  // 탭·챙 구멍: 평평한 길이 가운데에 모은다.
  final tabHoles = <double>[];
  final hasTabs = hat || tabLeft > 0 || tabRight > 0;
  if (hasTabs && tabHoleCount > 0 && tabHoleDia > 0) {
    for (final f in [
      if (hat || tabLeft > 0) flatL,
      if (hat || tabRight > 0) flatR,
    ]) {
      if (f <= 0) continue;
      final group = (tabHoleCount - 1) * tabHolePitch;
      if (tabHoleCount > 1 && tabHolePitch <= tabHoleDia) {
        problems.add('탭 구멍 피치가 구멍 지름 이하라 구멍이 서로 겹칩니다.');
        break;
      }
      if (group + tabHoleDia > f + 1e-9) {
        problems.add(
          '탭 구멍이 평평한 길이 ${_f(f)}mm에 들어가지 않습니다. 탭을 늘리거나 구멍 수·피치를 줄이십시오.',
        );
        break;
      }
    }
    if (tabHoleDia >= w) problems.add('탭 구멍 지름이 부스바 폭보다 크거나 같습니다.');
    final start = (flatL - (tabHoleCount - 1) * tabHolePitch) / 2;
    if (hat || tabLeft > 0) {
      for (var i = 0; i < tabHoleCount; i++) {
        tabHoles.add(start + i * tabHolePitch);
      }
    }
    final startR = (flatR - (tabHoleCount - 1) * tabHolePitch) / 2;
    if (hat || tabRight > 0) {
      for (var i = tabHoleCount - 1; i >= 0; i--) {
        tabHoles.add(len - (startR + i * tabHolePitch));
      }
    }
  }

  // 꺾기 계산(옆모습 그림·꺾기 선).
  BusbarBendPlan? bp;
  var heading = 0.0;
  if (n > 0 && hat) {
    bp = busbarBendPlan(
      d: t,
      r: rr,
      k: k,
      legs: [
        flatL + s,
        (hatHeight - 2 * os) + 2 * s,
        run + 2 * s,
        (hatHeight - 2 * os) + 2 * s,
        flatR + s,
      ],
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
      (n * holeDia * holeDia + tabHoles.length * tabHoleDia * tabHoleDia) *
      math.pi /
      4 *
      t;
  final kg = math.max(0.0, t * w * len - holeVol) * kCopperKgPerMm3;
  return GroundBarPlan(
    length: len,
    holes: n,
    positions: pos,
    flatStart: spanL,
    flatEnd: len - spanR,
    endLeft: n < 1 ? 0 : first - spanL,
    endRight: n < 1 ? 0 : len - spanR - pos.last,
    centerLine: w / 2,
    weightKg: kg,
    bends: bp?.bends ?? const [],
    bendPlan: bp,
    startHeading: heading,
    tabHoles: tabHoles,
    tabHoleDia: tabHoleDia,
    tabFlat: hat ? flatL : math.max(flatL, flatR),
    hat: hat,
    hatWidth: hat ? run + 2 * os : 0,
    problems: problems,
  );
}

/// 구멍 위치를 [per]개씩 묶은 줄(표시용): 예 (라벨 '1~5번', 값 [25, 50.4, …]).
List<(String, List<double>)> groundHoleRows(GroundBarPlan p, {int per = 5}) {
  final rows = <(String, List<double>)>[];
  for (var i = 0; i < p.positions.length; i += per) {
    final end = math.min(i + per, p.positions.length);
    rows.add((
      end - i == 1 ? '${i + 1}번' : '${i + 1}~$end번',
      p.positions.sublist(i, end),
    ));
  }
  return rows;
}
