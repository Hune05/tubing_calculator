// 접지바 가공(10-03): 구리 평강에 볼트 구멍을 한 줄 또는 두 줄로 뚫고, 끝을 L자 탭이나 챙 달린
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

/// 구멍 사이 최소 간격(mm, 구멍 중심 사이): 구멍 피치·줄 간격이 이보다 작으면 이 값으로 계산한다.
const double kGroundMinSpacing = 12;

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

  /// 접지 러그 구멍(접지 구멍과 따로 추가하는 구멍, 부스바 가운데). 러그 번호별로 이어서.
  final List<GroundHole> lugHoleList;

  /// 탭·챙 구멍 줄 수와 줄 위치(폭 방향). 접지 구멍과 따로 정한다.
  final int tabRows;
  final List<double> tabRowY;

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

  /// 실제로 계산에 쓴 구멍 피치(최소 간격으로 올린 뒤 값)와 탭·챙 구멍 피치.
  final double pitchUsed, tabPitchUsed;

  /// 구멍 가장자리에서 가장 가까운 꺾기 시작선까지 거리(mm): 몸체(접지·러그 구멍)와 탭·챙 구멍. 꺾기가 없으면 null.
  final double? minEdgeBody, minEdgeTab;

  /// 위 두 거리에 필요한 최소 거리(mm): 구멍 지름 25.4 미만 2T + R, 이상 2.5T + R(일반 판금 규칙).
  final double reqEdgeBody, reqEdgeTab;

  /// 입력을 바꿔 계산했다는 알림(문제는 아님).
  final List<String> notes;

  /// 만들 수 없는 이유들(비어 있으면 가능).
  final List<String> problems;

  bool get ok => problems.isEmpty;

  /// 바꾼 크기가 있는 구멍 수.
  int get customCount =>
      groundHoles.where((h) => h.custom).length +
      tabHoleList.where((h) => h.custom).length +
      lugHoleList.where((h) => h.custom).length;

  const GroundBarPlan({
    required this.length,
    required this.holes,
    required this.rows,
    required this.positions,
    required this.positionsB,
    required this.groundHoles,
    required this.tabHoleList,
    required this.lugHoleList,
    required this.tabRows,
    required this.tabRowY,
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
    required this.pitchUsed,
    required this.minEdgeBody,
    required this.minEdgeTab,
    required this.reqEdgeBody,
    required this.reqEdgeTab,
    required this.tabPitchUsed,
    required this.notes,
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
/// 접지 러그 구멍: [lugHoles] 1·2구멍 러그, [lugSpacing] 2구멍 러그의 구멍 간격, [lugCount] 러그 수,
/// [lugPitch] 러그 사이 중심 간격, [lugHoleDia] 러그 구멍 지름. 구멍은 곧은 구간 가운데·폭 가운데에 따로 뚫는다.
/// [packGround]이면 한 줄 접지 구멍을 왼쪽(뒤) 끝에서부터 촘촘히 놓고, 러그 구멍 묶음은 그 뒤 남는 자리 가운데에 같은 줄로 둔다.
/// [packGround]이면 한 줄 접지 구멍을 왼쪽(뒤) 끝에서부터 촘촘히 놓고, 러그 구멍 묶음은 그 뒤 남는 자리 가운데에 같은 줄로 둔다.
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
  int tabRows = 1,
  double tabRowGap = 0,
  bool tabStaggered = false,
  int tabSides = 3,
  int lugHoles = 0,
  double lugSpacing = 0,
  int lugCount = 0,
  double lugPitch = 0,
  double lugHoleDia = 0,
  bool packGround = false,
  Map<String, double> overrides = const {},
}) {
  final tabName = hat ? '챙' : '탭';
  final notes = <String>[];
  double minUp(double v, String name) {
    if (v <= 0 || v >= kGroundMinSpacing) return v;
    notes.add(
      '$name ${_f(v)}mm는 최소 간격 ${_f(kGroundMinSpacing)}mm보다 작아 ${_f(kGroundMinSpacing)}mm로 계산했습니다.',
    );
    return kGroundMinSpacing;
  }

  pitch = minUp(pitch, '구멍 피치');
  if (rows == 2) rowGap = minUp(rowGap, '줄 간격');
  if (tabHoleCount > 1) tabHolePitch = minUp(tabHolePitch, '$tabName 구멍 피치');
  if (tabRows == 2 && tabHoleCount > 0) {
    tabRowGap = minUp(tabRowGap, '$tabName 구멍 줄 간격');
  }
  if (lugHoles == 2 && lugCount > 0) lugSpacing = minUp(lugSpacing, '러그 구멍 간격');
  if (lugCount > 1) lugPitch = minUp(lugPitch, '러그 사이 간격');
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
  final lugOn = lugHoles > 0 && lugCount > 0 && lugHoleDia > 0;
  final packed = packGround && lugOn;
  final lugGroupW =
      (lugCount > 1 ? (lugCount - 1) * lugPitch : 0.0) +
      (lugHoles == 2 ? lugSpacing : 0.0);
  final st = nRows == 2 && staggered ? (shift ?? pitch / 2) : 0.0;
  var n = 0;
  var run = 0.0; // 접지 구멍 줄이 놓이는 곧은 구간 길이
  var len = 0.0;
  if (count != null) {
    n = count;
    run = n < 1
        ? 0
        : packed
        ? endDist + (n - 1) * pitch + st + pitch + lugGroupW + endDist
        : 2 * endDist + (n - 1) * pitch + st;
    len = run + spanL + spanR;
  } else if (length != null) {
    len = length;
    run = len - spanL - spanR;
    final fixed = packed ? st + pitch + lugGroupW : st;
    n = run < 2 * endDist + fixed || pitch <= 0
        ? 0
        : ((run - 2 * endDist - fixed) / pitch + 1e-9).floor() + 1;
  }
  if (n > kGroundMaxHoles) {
    warn('구멍이 한 줄에 $kGroundMaxHoles개를 초과해 계산하지 않습니다.');
    n = 0;
  }
  if (n < 1) warn('구멍이 들어갈 자리가 없습니다. 길이나 구멍 수를 늘리십시오.');
  if (holeDia >= w) warn('구멍 지름이 부스바 폭보다 크거나 같습니다.');
  if (endDist < holeDia / 2) {
    warn('끝 여유가 구멍 반지름보다 작아 구멍이 끝 면을 뚫습니다.');
  }
  if (nRows == 2 && rowGap <= 0) warn('두 줄은 줄 간격이 있어야 합니다.');
  final holeRun = n < 1 ? 0.0 : 2 * endDist + (n - 1) * pitch + st;
  final rest = n < 1 || packed ? 0.0 : run - holeRun;
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

  // 탭·챙 구멍: 평평한 길이 가운데에 모은다. 줄마다 tabHoleCount개. 줄 수·줄 간격은 접지 구멍과 따로.
  final nRowsT = tabRows == 2 ? 2 : 1;
  final rowYT = nRowsT == 1
      ? [w / 2]
      : [w / 2 - tabRowGap / 2, w / 2 + tabRowGap / 2];
  final tabs = <GroundHole>[];
  final hasTabs = hat || tabLeft > 0 || tabRight > 0;
  if (hasTabs && tabHoleCount > 0 && tabHoleDia > 0) {
    final stT = nRowsT == 2 && tabStaggered && tabHoleCount > 1
        ? tabHolePitch / 2
        : 0.0;
    if (nRowsT == 2 && tabRowGap <= 0) warn('취부 구멍 두 줄은 줄 간격이 있어야 합니다.');
    void side(String letter, String name, double flat, bool left) {
      if (flat <= 0) return;
      final group = (tabHoleCount - 1) * tabHolePitch + stT;
      final start = (flat - group) / 2;
      for (var row = 0; row < nRowsT; row++) {
        final rl = row == 0 ? 'A' : 'B';
        for (var i = 0; i < tabHoleCount; i++) {
          final off = start + (row == 1 ? stT : 0) + i * tabHolePitch;
          final id = 't$letter-$rl${i + 1}';
          tabs.add(
            GroundHole(
              id: id,
              label: nRowsT == 1 ? '$name ${i + 1}' : '$name $rl${i + 1}',
              x: left ? off : len - off,
              y: rowYT[row],
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

    side(
      'L',
      '왼쪽',
      (hat || tabLeft > 0) && tabSides & 1 != 0 ? flatL : 0,
      true,
    );
    side(
      'R',
      '오른쪽',
      (hat || tabRight > 0) && tabSides & 2 != 0 ? flatR : 0,
      false,
    );
    if (tabHoleCount > 1 && tabHolePitch <= tabHoleDia) {
      warn('탭 구멍 피치가 구멍 지름 이하라 구멍이 서로 겹칩니다.');
    }
  }

  // 접지 러그 구멍: 곧은 구간 가운데, 폭 가운데에 따로 추가한다(접지 구멍을 쓰지 않음).
  final lugs = <GroundHole>[];
  if (lugHoles > 0 && lugCount > 0 && lugHoleDia > 0) {
    // 묶은 경우: 마지막 접지 구멍 뒤 남는 자리(마지막 구멍 + 피치 ~ 끝 여유 앞)의 가운데
    final cx = packed
        ? ((spanL + endDist + (n - 1) * pitch + st + pitch) +
                  (len - spanR - endDist)) /
              2
        : (spanL + (len - spanR)) / 2;
    for (var k = 0; k < lugCount; k++) {
      final lx = cx + (k - (lugCount - 1) / 2) * lugPitch;
      for (var m = 0; m < (lugHoles == 2 ? 2 : 1); m++) {
        final id = 'u${k + 1}-${m + 1}';
        lugs.add(
          GroundHole(
            id: id,
            label: lugHoles == 2 ? '러그 ${k + 1}-${m + 1}' : '러그 ${k + 1}',
            x:
                lx +
                (lugHoles == 2
                    ? (m == 0 ? -lugSpacing / 2 : lugSpacing / 2)
                    : 0),
            y: w / 2,
            dia: overrides[id] ?? lugHoleDia,
            custom: overrides.containsKey(id),
          ),
        );
      }
    }
  }

  // 구멍 검사(접지 구멍): 폭 안, 곧은 구간 안, 겹침
  // 같은 종류의 문제는 구멍마다 반복하지 않고 한 줄로 묶는다.
  String names(List<String> l) =>
      l.length <= 3 ? l.join('·') : '${l.take(3).join('·')} 외 ${l.length - 3}개';
  final tooBig = <String>[], outWidth = <String>[], outFlat = <String>[];
  for (final h in [...ground, ...tabs, ...lugs]) {
    if (h.dia >= w) {
      tooBig.add(h.label);
    } else if (h.y - h.dia / 2 < -1e-9 || h.y + h.dia / 2 > w + 1e-9) {
      outWidth.add(h.label);
    }
  }
  for (final h in [...ground, ...lugs]) {
    if ((n > 0 || h.id.startsWith('u')) &&
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
  // 러그 구멍끼리, 러그 구멍과 접지 구멍
  final lugClash = <String>[];
  for (var i = 0; i < lugs.length; i++) {
    for (var j = i + 1; j < lugs.length; j++) {
      final dx = lugs[i].x - lugs[j].x, dy = lugs[i].y - lugs[j].y;
      if (math.sqrt(dx * dx + dy * dy) <=
          (lugs[i].dia + lugs[j].dia) / 2 - 1e-9) {
        lugClash.add('${lugs[i].label}-${lugs[j].label}');
      }
    }
  }
  if (lugClash.isNotEmpty) {
    warn('러그 구멍(${names(lugClash)})이 서로 겹칩니다. 러그 사이 간격이나 러그 구멍 간격을 늘리십시오.');
  }
  final lugOnGround = <String>[];
  for (final l in lugs) {
    for (final g in ground) {
      final dx = l.x - g.x, dy = l.y - g.y;
      if (math.sqrt(dx * dx + dy * dy) <= (l.dia + g.dia) / 2 - 1e-9) {
        lugOnGround.add('${l.label}-${g.label}');
      }
    }
  }
  if (lugOnGround.isNotEmpty) {
    warn(
      '러그 구멍이 접지 구멍과 겹칩니다(${names(lugOnGround)}). 접지 구멍을 두 줄로 하거나 줄 간격·피치를 늘리거나 러그 위치를 바꾸십시오.',
    );
  }

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
      [
        ...ground,
        ...tabs,
        ...lugs,
      ].fold<double>(0, (a, h) => a + h.dia * h.dia) *
      math.pi /
      4 *
      t;
  final kg = math.max(0.0, t * w * len - holeVol) * kCopperKgPerMm3;
  // 구멍 가장자리 ~ 꺾기 시작선 거리(꺾는 쪽만): 몸체 구멍은 곧은 구간 양 끝, 탭·챙 구멍은 각 평평한 길이 끝.
  double? edgeBody;
  for (final h in [...ground, ...lugs]) {
    final r = h.dia / 2;
    if (spanL > 0) {
      final d = h.x - spanL - r;
      edgeBody = edgeBody == null ? d : math.min(edgeBody, d);
    }
    if (spanR > 0) {
      final d = len - spanR - h.x - r;
      edgeBody = edgeBody == null ? d : math.min(edgeBody, d);
    }
  }
  double? edgeTab;
  for (final h in tabs) {
    final left = h.label.startsWith('왼쪽');
    final off = left ? h.x : len - h.x;
    final d = (left ? flatL : flatR) - off - h.dia / 2;
    edgeTab = edgeTab == null ? d : math.min(edgeTab, d);
  }
  // 필요 거리: 일반 판금 규칙 d ≥ 2T + R(구멍 지름 25.4mm 미만), 2.5T + R(이상). 구리 부스바 전용 표준은 아니다.
  double reqFor(Iterable<GroundHole> hs) {
    final big = hs.any((h) => h.dia >= 25.4);
    return (big ? 2.5 : 2.0) * t + rr;
  }

  final reqBody = reqFor([...ground, ...lugs]);
  final reqTab = reqFor(tabs);
  if (edgeTab != null && edgeTab < reqTab - 1e-9) {
    notes.add(
      '$tabName 구멍 가장자리가 꺾기 시작선에서 ${_f(edgeTab)}mm로 필요 거리 ${_f(reqTab)}mm(2T + R)보다 가깝습니다. 꺾을 때 구멍이 늘어날 수 있으니 $tabName 길이를 ${_f(reqTab - edgeTab)}mm 이상 늘리거나 구멍 지름을 줄이거나 시험 조각으로 확인하십시오(일반 판금 규칙이며 구리 부스바 전용 표준은 아닙니다).',
    );
  }
  if (edgeBody != null && edgeBody < reqBody - 1e-9) {
    notes.add(
      '접지·러그 구멍 가장자리가 꺾기 시작선에서 ${_f(edgeBody)}mm로 필요 거리 ${_f(reqBody)}mm(2T + R)보다 가깝습니다. 끝 여유를 ${_f(reqBody - edgeBody)}mm 이상 늘리십시오(일반 판금 규칙이며 구리 부스바 전용 표준은 아닙니다).',
    );
  }
  // 막대 가장자리(폭 방향·꺾지 않은 끝)와 구멍 가장자리: 권장 2T, 최소 1T(일반 판금 자료).
  double? edgeW;
  for (final h in [...ground, ...tabs, ...lugs]) {
    final d = math.min(h.y, w - h.y) - h.dia / 2;
    edgeW = edgeW == null ? d : math.min(edgeW, d);
  }
  if (edgeW != null && edgeW < 2 * t - 1e-9) {
    notes.add(
      '구멍 가장자리가 막대 가장자리(폭 방향)에서 ${_f(edgeW)}mm로 가깝습니다. 일반 판금 자료는 권장 2T(${_f(2 * t)}mm), 최소 1T(${_f(t)}mm)입니다${edgeW < t - 1e-9 ? '. 최소에도 못 미칩니다' : ''}.',
    );
  }
  if (n > 0) {
    final endGap = <double>[
      if (spanL == 0) endDist - holeDia / 2,
      if (spanR == 0) endDist - holeDia / 2,
    ];
    final endMin = endGap.isEmpty ? null : endGap.reduce(math.min);
    if (endMin != null && endMin < 2 * t - 1e-9) {
      notes.add(
        '꺾지 않은 막대 끝에서 구멍 가장자리까지 ${_f(endMin)}mm입니다. 일반 판금 자료는 권장 2T(${_f(2 * t)}mm), 최소 1T(${_f(t)}mm)입니다.',
      );
    }
  }
  // 구멍 가장자리 사이 간격(같은 줄 이웃): 최소 1T, 권장 2T(한 곳 자료).
  if (n > 1) {
    final gap = pitch - holeDia;
    if (gap < t - 1e-9) {
      notes.add(
        '이웃한 접지 구멍 가장자리 사이가 ${_f(gap)}mm로 좁습니다(최소 1T = ${_f(t)}mm, 한 곳 자료). 구멍 사이가 찢어질 수 있습니다.',
      );
    }
  }
  final lastX = n < 1 ? 0.0 : first + (n - 1) * pitch + st;
  return GroundBarPlan(
    length: len,
    holes: n,
    rows: nRows,
    positions: posA,
    positionsB: posB,
    groundHoles: ground,
    tabHoleList: tabs,
    lugHoleList: lugs,
    tabRows: nRowsT,
    tabRowY: rowYT,
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
    pitchUsed: pitch,
    minEdgeBody: edgeBody,
    minEdgeTab: edgeTab,
    reqEdgeBody: reqBody,
    reqEdgeTab: reqTab,
    tabPitchUsed: tabHolePitch,
    notes: notes,
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
