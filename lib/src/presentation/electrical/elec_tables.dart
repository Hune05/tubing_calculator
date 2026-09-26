// 전기 계산기 표 — 모두 출처가 있는 값만 넣는다(2026-09-26 조사, docs/전기계산기_근거.md).
//
// 허용전류: KEC 232.5.2 → KS C IEC 60364-5-52 부속서 B(구리). B.52.2~B.52.5는 두 출처
// (TiSoft IEC 60364-5-52 도움말, 한국 전선업계 KS C IEC 60364-5-52 표 자료)가 맞는 값,
// D1·D2 열은 한 출처(TiSoft)뿐. 보정: B.52.14(공기)·B.52.15(지중)·B.52.17(묶음)·B.52.19(관로).
// 도체 저항: IEC 60228 2종(연선) 20°C(Nexans 자료). 차단기 정격: LS ELECTRIC Metasol MCCB 목록.
library;

/// 절연체. 최고 허용온도 PVC 70°C, XLPE/EPR 90°C(KEC 표 232.5-1).
enum Insulation { pvc70, xlpe90 }

/// 공사 방법(KS C IEC 60364-5-52 표 A.52.3 기준 방법).
enum InstallMethod { a1, a2, b1, b2, c, d1, d2, e }

const List<double> kCableSizes = [
  1.5, 2.5, 4, 6, 10, 16, 25, 35, 50, 70, 95, 120, 150, 185, 240, 300,
];

// 열 순서: A1, A2, B1, B2, C, D1, D2 (구리, 공기 30°C / 지중 20°C).
final Map<double, List<double>> _b522 = {
  // PVC 70°C, 도체 2가닥에 전류
  1.5: [14.5, 14, 17.5, 16.5, 19.5, 22, 22],
  2.5: [19.5, 18.5, 24, 23, 27, 29, 28],
  4: [26, 25, 32, 30, 36, 37, 38],
  6: [34, 32, 41, 38, 46, 46, 48],
  10: [46, 43, 57, 52, 63, 60, 64],
  16: [61, 57, 76, 69, 85, 78, 83],
  25: [80, 75, 101, 90, 112, 99, 110],
  35: [99, 92, 125, 111, 138, 119, 132],
  50: [119, 110, 151, 133, 168, 140, 156],
  70: [151, 139, 192, 168, 213, 173, 192],
  95: [182, 167, 232, 201, 258, 204, 230],
  120: [210, 192, 269, 232, 299, 231, 261],
  150: [240, 219, 300, 258, 344, 261, 293],
  185: [273, 248, 341, 294, 392, 292, 331],
  240: [321, 291, 400, 344, 461, 336, 382],
  300: [367, 334, 458, 394, 530, 379, 427],
};
final Map<double, List<double>> _b523 = {
  // XLPE 90°C, 2가닥
  1.5: [19, 18.5, 23, 22, 24, 25, 27],
  2.5: [26, 25, 31, 30, 33, 33, 35],
  4: [35, 33, 42, 40, 45, 43, 46],
  6: [45, 42, 54, 51, 58, 53, 58],
  10: [61, 57, 75, 69, 80, 71, 77],
  16: [81, 76, 100, 91, 107, 91, 100],
  25: [106, 99, 133, 119, 138, 116, 129],
  35: [131, 121, 164, 146, 171, 139, 155],
  50: [158, 145, 198, 175, 209, 164, 183],
  70: [200, 183, 253, 221, 269, 203, 225],
  95: [241, 220, 306, 265, 328, 239, 270],
  120: [278, 253, 354, 305, 382, 271, 306],
  150: [318, 290, 393, 334, 441, 306, 343],
  185: [362, 329, 449, 384, 506, 343, 387],
  240: [424, 386, 528, 459, 599, 395, 448],
  300: [486, 442, 603, 532, 693, 446, 502],
};
final Map<double, List<double>> _b524 = {
  // PVC 70°C, 3가닥
  1.5: [13.5, 13, 15.5, 15, 17.5, 18, 19],
  2.5: [18, 17.5, 21, 20, 24, 24, 24],
  4: [24, 23, 28, 27, 32, 30, 33],
  6: [31, 29, 36, 34, 41, 38, 41],
  10: [42, 39, 50, 46, 57, 50, 54],
  16: [56, 52, 68, 62, 76, 64, 70],
  25: [73, 68, 89, 80, 96, 82, 92],
  35: [89, 83, 110, 99, 119, 98, 110],
  50: [108, 99, 134, 118, 144, 116, 130],
  70: [136, 125, 171, 149, 184, 143, 162],
  95: [164, 150, 207, 179, 223, 169, 193],
  120: [188, 172, 239, 206, 259, 192, 220],
  150: [216, 196, 262, 225, 299, 217, 246],
  185: [245, 223, 296, 255, 341, 243, 278],
  240: [286, 261, 346, 297, 403, 280, 320],
  300: [328, 298, 394, 339, 464, 316, 359],
};
final Map<double, List<double>> _b525 = {
  // XLPE 90°C, 3가닥
  1.5: [17, 16.5, 20, 19.5, 22, 21, 23],
  2.5: [23, 22, 28, 26, 30, 28, 30],
  4: [31, 30, 37, 35, 40, 36, 39],
  6: [40, 38, 48, 44, 52, 44, 49],
  10: [54, 51, 66, 60, 71, 58, 65],
  16: [73, 68, 88, 80, 96, 75, 84],
  25: [95, 89, 117, 105, 119, 96, 107],
  35: [117, 109, 144, 128, 147, 115, 129],
  50: [141, 130, 175, 154, 179, 135, 153],
  70: [179, 164, 222, 194, 229, 167, 188],
  95: [216, 197, 269, 233, 278, 197, 226],
  120: [249, 227, 312, 268, 322, 223, 257],
  150: [285, 259, 342, 300, 371, 251, 287],
  185: [324, 295, 384, 340, 424, 281, 324],
  240: [380, 346, 450, 398, 500, 324, 375],
  300: [435, 396, 514, 455, 576, 365, 419],
};

// 방법 E(다심 케이블, 구멍 트레이·사다리) — B.52.10(PVC)·B.52.12(XLPE). [2가닥, 3가닥].
final Map<double, List<double>> _eP = {
  1.5: [22, 18.5], 2.5: [30, 25], 4: [40, 34], 6: [51, 43], 10: [70, 60],
  16: [94, 80], 25: [119, 101], 35: [148, 126], 50: [180, 153],
  70: [232, 198], 95: [282, 238], 120: [328, 278], 150: [379, 319],
  185: [434, 364], 240: [514, 430], 300: [593, 497],
};
final Map<double, List<double>> _eX = {
  1.5: [26, 23], 2.5: [36, 32], 4: [49, 42], 6: [63, 54], 10: [86, 75],
  16: [115, 100], 25: [149, 127], 35: [185, 158], 50: [225, 192],
  70: [289, 246], 95: [352, 298], 120: [410, 346], 150: [473, 399],
  185: [542, 456], 240: [641, 538], 300: [741, 621],
};

/// 기본 허용전류(A, 보정 전). 표에 없으면 null.
double? baseAmpacity(
  double size,
  Insulation ins,
  int loaded,
  InstallMethod m,
) {
  final three = loaded >= 3;
  if (m == InstallMethod.e) {
    final row = (ins == Insulation.pvc70 ? _eP : _eX)[size];
    return row?[three ? 1 : 0];
  }
  final t = ins == Insulation.pvc70
      ? (three ? _b524 : _b522)
      : (three ? _b525 : _b523);
  final row = t[size];
  if (row == null) return null;
  const col = {
    InstallMethod.a1: 0,
    InstallMethod.a2: 1,
    InstallMethod.b1: 2,
    InstallMethod.b2: 3,
    InstallMethod.c: 4,
    InstallMethod.d1: 5,
    InstallMethod.d2: 6,
  };
  return row[col[m]!];
}

bool isGround(InstallMethod m) =>
    m == InstallMethod.d1 || m == InstallMethod.d2;

// 주위 온도 보정 — B.52.14(공기, 기준 30°C)·B.52.15(지중, 기준 20°C). [PVC, XLPE], PVC 없는 칸은 null.
const Map<int, List<double?>> _tAir = {
  10: [1.22, 1.15], 15: [1.17, 1.12], 20: [1.12, 1.08], 25: [1.06, 1.04],
  30: [1.00, 1.00], 35: [0.94, 0.96], 40: [0.87, 0.91], 45: [0.79, 0.87],
  50: [0.71, 0.82], 55: [0.61, 0.76], 60: [0.50, 0.71], 65: [null, 0.65],
  70: [null, 0.58], 75: [null, 0.50], 80: [null, 0.41],
};
const Map<int, List<double?>> _tGround = {
  10: [1.10, 1.07], 15: [1.05, 1.04], 20: [1.00, 1.00], 25: [0.95, 0.96],
  30: [0.89, 0.93], 35: [0.84, 0.89], 40: [0.77, 0.85], 45: [0.71, 0.80],
  50: [0.63, 0.76], 55: [0.55, 0.71], 60: [0.45, 0.65], 65: [null, 0.60],
  70: [null, 0.53], 75: [null, 0.46], 80: [null, 0.38],
};

/// 온도 보정계수. 표 사이 온도는 한 칸 더운 쪽(안전 쪽)을 쓴다. 넘으면 null(쓸 수 없음).
double? tempFactor(double tempC, Insulation ins, {required bool ground}) {
  final t = ground ? _tGround : _tAir;
  final keys = t.keys.toList()..sort();
  int? k;
  for (final x in keys) {
    if (x >= tempC - 1e-9) {
      k = x;
      break;
    }
  }
  if (k == null) return null;
  if (tempC < keys.first) k = keys.first;
  return t[k]![ins == Insulation.pvc70 ? 0 : 1];
}

/// 여러 회로를 같이 놓을 때 배치.
enum GroupLayout {
  bunched, // 묶음·전선관·덕트 속(B.52.17 1행)
  wallSingleLayer, // 벽·무구멍 트레이에 한 줄(2행)
  perforatedTray, // 구멍 트레이 한 줄(4행)
  ladder, // 사다리·행거 한 줄(5행)
  groundDuct, // 지중 관로 닿게(B.52.19 다심)
  groundDirect, // 땅에 직접 묻음, 닿게(B.52.18)
}

// B.52.18 직매 케이블 닿게: 회로 수 [2,3,4,5,6,7,8,9,12,16,20].
const List<int> _gDirectN = [1, 2, 3, 4, 5, 6, 7, 8, 9, 12, 16, 20];
const List<double> _gDirect = [
  1.00, 0.75, 0.65, 0.60, 0.55, 0.50, 0.45, 0.43, 0.41, 0.36, 0.32, 0.29,
];

const List<int> _gN = [1, 2, 3, 4, 5, 6, 7, 8, 9, 12, 16, 20];
const Map<GroupLayout, List<double>> _gF = {
  GroupLayout.bunched: [1.00, 0.80, 0.70, 0.65, 0.60, 0.57, 0.54, 0.52, 0.50, 0.45, 0.41, 0.38],
  GroupLayout.wallSingleLayer: [1.00, 0.85, 0.79, 0.75, 0.73, 0.72, 0.72, 0.71, 0.70, 0.70, 0.70, 0.70],
  GroupLayout.perforatedTray: [1.00, 0.88, 0.82, 0.77, 0.75, 0.73, 0.73, 0.72, 0.72, 0.72, 0.72, 0.72],
  GroupLayout.ladder: [1.00, 0.87, 0.82, 0.80, 0.80, 0.79, 0.79, 0.78, 0.78, 0.78, 0.78, 0.78],
};
// B.52.19 다심 케이블, 관로 닿게: 회로 수 1~20.
const List<double> _gDuct = [
  1.00, 0.85, 0.75, 0.70, 0.65, 0.60, 0.57, 0.54, 0.52, 0.49,
  0.47, 0.45, 0.44, 0.42, 0.41, 0.39, 0.38, 0.37, 0.35, 0.34,
];

/// 회로 수 보정계수. 표 사이 수는 한 칸 많은 쪽(안전 쪽). 20 넘으면 20.
double groupFactor(int circuits, GroupLayout layout) {
  final n = circuits.clamp(1, 20);
  if (layout == GroupLayout.groundDuct) return _gDuct[n - 1];
  if (layout == GroupLayout.groundDirect) {
    for (var i = 0; i < _gDirectN.length; i++) {
      if (_gDirectN[i] >= n) return _gDirect[i];
    }
    return _gDirect.last;
  }
  final row = _gF[layout]!;
  for (var i = 0; i < _gN.length; i++) {
    if (_gN[i] >= n) return row[i];
  }
  return row.last;
}

/// IEC 60228 2종(연선) 구리 20°C 직류 저항(Ω/km).
final Map<double, double> kCuR20 = {
  0.75: 24.5, 1.0: 18.1, 1.5: 12.1, 2.5: 7.41, 4: 4.61, 6: 3.08, 10: 1.83, 16: 1.15, 25: 0.727,
  35: 0.524, 50: 0.387, 70: 0.268, 95: 0.193, 120: 0.153, 150: 0.124,
  185: 0.0991, 240: 0.0754, 300: 0.0601,
};

/// 운전 온도에서 저항(Ω/km). 구리 온도계수 0.00393/°C.
double cuResistance(double size, double tempC) =>
    kCuR20[size]! * (1 + 0.00393 * (tempC - 20));

/// 리액턴스(Ω/km) — 자료가 없을 때 쓰는 값(EIG). 50mm² 아래는 거의 영향 없음.
const double kReactanceOhmPerKm = 0.08;

/// 차단기(MCCB) 정격 전류 — LS ELECTRIC Metasol 목록(30AF의 3·5·10A 포함).
const List<int> kBreakerRatings = [
  3, 5, 10, 15, 20, 30, 40, 50, 60, 75, 100, 125, 150, 175, 200, 225, 250, 300, 350,
  400, 500, 630, 700, 800,
];

/// KEC 232.3.9 표 232.3-1 전압강하 한도(%).
enum SupplyType { lvLighting, lvOther, hvLighting, hvOther }

double voltageDropLimit(SupplyType t, double lengthM) {
  final base = switch (t) {
    SupplyType.lvLighting => 3.0,
    SupplyType.lvOther => 5.0,
    SupplyType.hvLighting => 6.0,
    SupplyType.hvOther => 8.0,
  };
  // 100m 넘으면 1m마다 0.005% 더, 더하는 것은 0.5%까지.
  final extra = lengthM > 100 ? ((lengthM - 100) * 0.005).clamp(0, 0.5) : 0.0;
  return base + extra;
}

/// KEC 142.3.2 표 142.3-1 보호도체(같은 재질) 최소 굵기.
double peConductorSize(double phaseSize) {
  if (phaseSize <= 16) return phaseSize;
  if (phaseSize <= 35) return 16;
  final half = phaseSize / 2;
  for (final s in kCableSizes) {
    if (s >= half - 1e-9) return s;
  }
  return half;
}

/// 후강 전선관(KS C 8401) 호칭 → 안지름(mm, 바깥지름 − 2×두께, 제조사 표).
const Map<int, double> kThickConduitId = {
  16: 16.4, 22: 21.9, 28: 28.3, 36: 36.9, 42: 42.8, 54: 54.0,
  70: 69.6, 82: 82.3, 92: 93.7, 104: 106.4,
};

// ─────────────── 제어반 내부 배선 — IEC 60204-1:2016(+AMD1:2021 그대로) ───────────────
// 표 6: PVC 구리, 반 안 주위 40°C, 3상 회로. JIS B 9960-1:2019(IEC 60204-1 IDT) 표 이미지와
// ABB 자료(0.75~50mm²)가 같은 값. 표 D.1 온도, D.2 회로 수(9 넘으면 60364 B.52.17).

const List<double> kPanelSizes = [
  0.75, 1.0, 1.5, 2.5, 4, 6, 10, 16, 25, 35, 50, 70, 95, 120,
];

/// 열 순서: B1, B2, C, E.
final Map<double, List<double>> _iec60204t6 = {
  0.75: [8.6, 8.5, 9.8, 10.4],
  1.0: [10.3, 10.1, 11.7, 12.4],
  1.5: [13.5, 13.1, 15.2, 16.1],
  2.5: [18.3, 17.4, 21, 22],
  4: [24, 23, 28, 30],
  6: [31, 30, 36, 37],
  10: [44, 40, 50, 52],
  16: [59, 54, 66, 70],
  25: [77, 70, 84, 88],
  35: [96, 86, 104, 110],
  50: [117, 103, 125, 133],
  70: [149, 130, 160, 171],
  95: [180, 156, 194, 207],
  120: [208, 179, 225, 240],
};

double? panelBaseAmpacity(double size, InstallMethod m) {
  final row = _iec60204t6[size];
  if (row == null) return null;
  return switch (m) {
    InstallMethod.b1 => row[0],
    InstallMethod.b2 => row[1],
    InstallMethod.c => row[2],
    InstallMethod.e => row[3],
    _ => null,
  };
}

/// 표 D.1(기준 40°C). 40°C 아래는 표에 없어 1.0(안전 쪽), 60°C 넘으면 null.
double? panelTempFactor(double tempC) {
  if (tempC <= 40) return 1.0;
  for (final e in const [
    (45.0, 0.91),
    (50.0, 0.82),
    (55.0, 0.71),
    (60.0, 0.58),
  ]) {
    if (tempC <= e.$1 + 1e-9) return e.$2;
  }
  return null;
}

/// 표 D.2(회로·케이블 수 2·4·6·9). 사이 수는 많은 쪽, 9 넘으면 B.52.17.
double panelGroupFactor(int n, InstallMethod m) {
  if (n <= 1) return 1.0;
  final row = switch (m) {
    InstallMethod.c => const [0.85, 0.75, 0.72, 0.70],
    InstallMethod.e => const [0.88, 0.77, 0.73, 0.72],
    _ => const [0.80, 0.65, 0.57, 0.50],
  };
  const ns = [2, 4, 6, 9];
  for (var i = 0; i < ns.length; i++) {
    if (ns[i] >= n) return row[i];
  }
  return groupFactor(
    n,
    switch (m) {
      InstallMethod.c => GroupLayout.wallSingleLayer,
      InstallMethod.e => GroupLayout.perforatedTray,
      _ => GroupLayout.bunched,
    },
  );
}
