// 접지바 구멍 계산기(10-03): 구리 평강에 볼트 구멍을 한 줄로 뚫고 끝을 L자로 꺾어 접지바를 만들 때
// 자르는 길이와 구멍 위치. 화면 없이 계산만 한다.
//  · 구멍은 폭 가운데 한 줄, 피치 p로 늘어선다. 위치는 왼쪽 끝에서 구멍 중심까지.
//  · 구멍 수로 정하면 구멍 줄 길이 = 2e + (n−1)p. 길이로 정하면 n = ⌊(줄 길이 − 2e) ÷ p⌋ + 1이고,
//    남는 길이는 양 끝 여유에 똑같이 나눈다.
//  · 끝 여유 e는 곧은 구간 끝에서 첫 구멍 중심까지다. 끝에 L 꺾기가 있으면 꺾기 끝선에서 잰다.
//  · L 꺾기(눕혀 꺾기, 두께 방향)는 busbar_bend.dart의 같은 식이다. 탭 길이는 바깥 치수(끝에서 바깥 모서리까지).
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

  /// 구멍 수.
  final int holes;

  /// 왼쪽 끝에서 구멍 중심까지 거리(mm).
  final List<double> positions;

  /// 구멍 줄이 놓이는 곧은 구간(왼쪽 끝에서 잰 시작·끝, mm). 끝 여유 e는 여기서부터 잰다.
  final double flatStart, flatEnd;

  /// 곧은 구간 끝에서 첫·마지막 구멍 중심까지(mm).
  final double endLeft, endRight;

  /// 구멍 중심선: 폭 가운데(mm).
  final double centerLine;

  /// 대략 무게(kg, 구멍 뺌).
  final double weightKg;

  /// L 꺾기(왼쪽 → 오른쪽 순서, 없으면 비어 있음). 시작·끝선은 왼쪽 끝에서 잰 거리.
  final List<BusbarBend> bends;

  /// L 꺾기가 있을 때 옆모습 그림용 계산(없으면 null)과 그리기 시작 방향(°).
  final BusbarBendPlan? bendPlan;
  final double startHeading;

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
    required this.problems,
  });
}

/// L 꺾기 하나가 차지하는 곧은 길이(mm): 끝에서 꺾기 시작선까지 + 호.
double _tabSpan(double outside, double d, double r, double k) {
  final s = busbarSetback(d, r, k, 90);
  final adj = busbarDimAdjust(d, k, 90, BusbarDimRef.outside);
  return outside + adj - s + busbarArc(d, r, k, 90);
}

/// [t]·[w] 두께·폭, [holeDia] 구멍 지름, [pitch] 구멍 피치, [endDist] 끝 여유.
/// [count]를 주면 구멍 수로, [length]를 주면 막대 길이(자르는 길이)로 정한다(둘 다 있으면 [count]).
/// [tabLeft]·[tabRight]는 끝 L 꺾기 탭의 바깥 길이(0이면 꺾지 않음), [r]·[k]는 꺾기 안쪽 반경·중립선 계수.
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
}) {
  final problems = <String>[];
  final rr = r ?? t;
  final minTab = rr + t; // 바깥 치수로 꺾을 수 있는 가장 짧은 탭
  var spanL = 0.0, spanR = 0.0;
  if (tabLeft > 0) {
    if (tabLeft < minTab) {
      problems.add(
        '왼쪽 탭 ${_f(tabLeft)}mm는 안쪽 반경 ${_f(rr)}mm로 꺾기에 너무 짧습니다. 최소 ${_f(minTab)}mm.',
      );
    }
    spanL = _tabSpan(tabLeft, t, rr, k);
  }
  if (tabRight > 0) {
    if (tabRight < minTab) {
      problems.add(
        '오른쪽 탭 ${_f(tabRight)}mm는 안쪽 반경 ${_f(rr)}mm로 꺾기에 너무 짧습니다. 최소 ${_f(minTab)}mm.',
      );
    }
    spanR = _tabSpan(tabRight, t, rr, k);
  }
  var n = 0;
  var run = 0.0; // 곧은 구간 길이
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
  if (holeDia >= w) {
    problems.add('구멍 지름이 부스바 폭보다 크거나 같습니다.');
  }
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

  // L 꺾기 계산(옆모습 그림·꺾기 선). 왼쪽만·오른쪽만·양쪽.
  BusbarBendPlan? bp;
  var heading = 0.0;
  if (n > 0 && (tabLeft > 0 || tabRight > 0)) {
    final s = busbarSetback(t, rr, k, 90);
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
  final hole = n * math.pi / 4 * holeDia * holeDia * t;
  final kg = math.max(0.0, t * w * len - hole) * kCopperKgPerMm3;
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
    problems: problems,
  );
}

String _f(double v) {
  var s = v.toStringAsFixed(1);
  if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
  return s;
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
