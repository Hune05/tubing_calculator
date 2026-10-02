// 케이블 무게(kg/km, 개산) 표와 AMS 계장 케이블. 케이블 트레이 하중 계산에 쓴다(10-03).
// 제조사 카탈로그 두 곳 이상에서 확인한 값만 넣고, 다르면 큰 값(안전 쪽)을 쓴다.
//  · F-CV 1~4심: LS전선(2020 영문 카탈로그)·대한전선(MV/LV 2025-12)·넥상스코리아(TFR-CV) 중 큰 값.
//    넥상스 2C 6sq "2454"는 오기라 뺐다.
//  · F-CVV-S: LS전선(= 상진전선 CVV-SB 같은 표)·넥상스(TFR-CVV-S)·대한전선(6sq까지) 중 큰 값.
//  · F-GV: LS전선·넥상스(TFR-GV) 중 큰 값.
//  · AMS(알루미늄 마일라 차폐) 계장 케이블:
//    - 일괄 차폐 심형(F-CVV-AMS): LS·넥상스. 외경은 F-CVV-S와 같다(두 회사 표). 넥상스 3C 10sq "260"은 오기라 뺐다.
//    - 개별+일괄 차폐 쌍·3심형(F-CVV-I/C-AMS): LS·대한전선. 외경·무게 칸마다 큰 값. 한 곳에만 있는 1P·1T·9P는 뺐다.
//    알루미늄 마일라는 정전 차폐이지 외장(기계적 보호)이 아니다(세 회사 모두 "차폐"로 적음).
// 근거와 출처: docs/전기_케이블트레이_근거.md "케이블 무게".
library;

import 'conduit_tables.dart';

// dart format off
const List<double> _sizes = [1.5, 2.5, 4, 6, 10, 16, 25, 35, 50, 70, 95, 120, 150, 185, 240, 300];
const Map<CableKind, List<double>> _w = {
  CableKind.fcv1: [55, 75, 90, 110, 180, 210, 320, 410, 535, 735, 995, 1235, 1520, 1880, 2440, 3030],
  CableKind.fcv2: [125, 155, 200, 250, 360, 485, 715, 930, 1220, 1680, 2245, 2810, 3470, 4300, 5585, 6905],
  CableKind.fcv3: [160, 185, 245, 325, 465, 645, 960, 1270, 1675, 2325, 3135, 3925, 4840, 6010, 7825, 9695],
  CableKind.fcv4: [175, 230, 300, 395, 585, 815, 1235, 1635, 2175, 3030, 4095, 5145, 6320, 7880, 10255, 12745],
  CableKind.fgv: [65, 80, 115, 135, 190, 230, 340, 440, 570, 785, 1080, 1310, 1600, 1990, 2580, 3210],
};
// F-CVV-S [1.5, 2.5, 4, 6, 10] (null = 표에 없음)
const List<double> _cvSizes = [1.5, 2.5, 4, 6, 10];
const Map<int, List<double?>> _cvvs = {
  2: [175, 210, 280, 340, 480],
  3: [210, 250, 360, 450, 600],
  4: [250, 325, 440, 550, 770],
  5: [300, 380, 520, 660, 920],
  6: [330, 420, 635, 790, 1100],
  7: [360, 470, 670, 880, 1230],
  8: [420, 530, 780, 1000, 1420],
  10: [500, 660, 950, 1220, 1720],
  12: [570, 730, 1100, 1420, 2000],
  15: [690, 915, 1350, 1730, null],
  20: [870, 1140, 1730, 2245, null],
  30: [1230, 1620, 2500, null, null],
};
// 일괄 AMS 심형 [1.5, 2.5, 4, 6, 10]
const Map<int, List<double?>> _amsCore = {
  2: [165, 200, 265, 320, 430],
  3: [195, 240, 330, 410, 570],
  4: [230, 300, 425, 530, 730],
  5: [280, 340, 500, 630, 880],
  6: [320, 415, 580, 750, 1050],
  7: [340, 440, 630, 810, 1160],
  8: [400, 500, 740, 950, 1330],
  10: [470, 610, 890, 1150, 1640],
  12: [530, 700, 1030, 1330, 1910],
  15: [640, 840, 1260, 1630, null],
  20: [830, 1080, 1630, 2150, null],
  30: [1160, 1540, 2385, null, null],
};
// I/C AMS 쌍형 (외경 mm, 무게 kg/km): 1.5sq, 2.5sq
const Map<int, List<(double, double)>> _icPair = {
  2: [(18.5, 300), (20, 370)],
  3: [(19.5, 360), (21.5, 450)],
  4: [(21, 430), (23, 550)],
  5: [(23, 520), (25, 650)],
  6: [(25, 600), (27.5, 770)],
  7: [(25, 640), (27, 830)],
  8: [(27, 730), (30, 960)],
  10: [(32, 970), (35.5, 1260)],
  12: [(33, 1080), (36.5, 1410)],
  15: [(36, 1300), (40, 1700)],
  20: [(40.5, 1660), (45, 2210)],
  30: [(49, 2450), (55, 3260)],
};
// I/C AMS 3심(triad)형
const Map<int, List<(double, double)>> _icTriad = {
  2: [(19.5, 370), (21, 470)],
  3: [(20.5, 470), (22.5, 600)],
  4: [(22, 570), (24.5, 750)],
  5: [(24.5, 690), (26.5, 910)],
  6: [(26.5, 810), (29.5, 1080)],
  7: [(26.5, 880), (29.5, 1180)],
  8: [(29, 1010), (32, 1370)],
  10: [(34, 1250), (38, 1720)],
  12: [(35.5, 1450), (39.5, 1980)],
  15: [(38.5, 1770), (42.5, 2420)],
  20: [(44, 2320), (49, 3190)],
  30: [(51, 3360), (56.5, 4650)],
};
// dart format on

/// 한 가닥 무게(kg/km). 표에 없으면 null.
double? cableWeight(CableKind k, double size) {
  final cores = cvvsCores(k);
  if (cores != null) {
    final i = _cvSizes.indexOf(size);
    return i < 0 ? null : _cvvs[cores]?[i];
  }
  final row = _w[k];
  if (row == null) return null;
  final i = _sizes.indexOf(size);
  return i < 0 ? null : row[i];
}

/// AMS(알루미늄 마일라 차폐) 계장 케이블 종류.
enum AmsKind { overallCore, icPair, icTriad }

String amsKindLabel(AmsKind k) => switch (k) {
  AmsKind.overallCore => 'F-CVV-AMS (일괄 차폐)',
  AmsKind.icPair => 'F-CVV-I/C-AMS 쌍',
  AmsKind.icTriad => 'F-CVV-I/C-AMS 3심',
};

/// 심 수(일괄) 또는 쌍·3심 수 목록.
List<int> amsCounts(AmsKind k) => switch (k) {
  AmsKind.overallCore => _amsCore.keys.toList(),
  AmsKind.icPair => _icPair.keys.toList(),
  AmsKind.icTriad => _icTriad.keys.toList(),
};

String amsCountLabel(AmsKind k, int n) => switch (k) {
  AmsKind.overallCore => '$n심',
  AmsKind.icPair => '${n}P',
  AmsKind.icTriad => '${n}T',
};

/// 고를 수 있는 굵기(mm²).
List<double> amsSizes(AmsKind k, int n) {
  if (k == AmsKind.overallCore) {
    final row = _amsCore[n];
    if (row == null) return const [];
    return [
      for (var i = 0; i < _cvSizes.length; i++)
        if (row[i] != null && amsSpec(k, n, _cvSizes[i]) != null) _cvSizes[i],
    ];
  }
  return const [1.5, 2.5];
}

/// 심 수(도체 가닥 수).
int amsCores(AmsKind k, int n) => switch (k) {
  AmsKind.overallCore => n,
  AmsKind.icPair => n * 2,
  AmsKind.icTriad => n * 3,
};

/// 외경(mm)과 무게(kg/km). 표에 없으면 null.
({double od, double kg})? amsSpec(AmsKind k, int n, double size) {
  if (k == AmsKind.overallCore) {
    final i = _cvSizes.indexOf(size);
    final w = i < 0 ? null : _amsCore[n]?[i];
    final kind = CableKind.values.where((c) => cvvsCores(c) == n);
    final od = kind.isEmpty ? null : cableOd(kind.first, size);
    return w == null || od == null ? null : (od: od, kg: w);
  }
  final t = k == AmsKind.icPair ? _icPair : _icTriad;
  final i = size == 1.5 ? 0 : (size == 2.5 ? 1 : -1);
  final row = t[n];
  if (row == null || i < 0) return null;
  return (od: row[i].$1, kg: row[i].$2);
}

const String cableWeightSource =
    '무게(개산): F-CV는 LS전선·대한전선·넥상스, F-CVV-S는 LS전선·넥상스·대한전선, F-GV는 LS전선·넥상스, '
    'AMS는 LS전선·넥상스·대한전선 카탈로그 중 큰 값(안전 쪽).';
