// 미네랄 절연(MI) 케이블 허용전류(A), 구리 도체·구리 외피, 주위 온도 30 ℃.
// IEC 60364-5-52:2009 표 B.52.6~B.52.9에 해당한다. 원문 표는 확인하지 못했고 두 곳의 자료
// (TiSoft 도움말, 승위 BTTZ 카탈로그·Wrexham Mineral Cables 데이터시트)가 서로 일치하는 값만 옮겼다.
// 근거: docs/전기계산기_근거.md "미네랄 절연 케이블".

/// 포설 방법 묶음: C(벽·표면), E·F·G(공기 중 트레이·이격).
enum MiMethod { c, efg }

/// 외피 온도: 70 ℃(PVC 피복 또는 접촉 가능한 나선, 표 B.52.6·8), 105 ℃(접촉 불가 나선, 표 B.52.7·9).
enum MiSheath { t70, t105 }

/// 열 이름. 방법 C는 앞의 3개만 쓴다.
const List<String> kMiColsC = [
  '2도체(트윈·단심 2본)',
  '3도체 다심 또는 단심 3본 삼각 배열',
  '단심 3본 평면 접촉',
];
const List<String> kMiColsEfg = [
  '2도체(트윈·단심 2본) E·F',
  '3도체 다심 또는 단심 3본 삼각 배열 E·F',
  '단심 3본 평면 접촉 F',
  '단심 3본 수직 이격 G',
  '단심 3본 수평 이격 G',
];

class MiRow {
  const MiRow(this.mm2, this.amps);
  final double mm2;
  final List<int> amps;
}

/// 500 V 케이블은 1.5·2.5·4 mm²뿐이다. 750 V는 1.5~240 mm².
const _c70v500 = [
  MiRow(1.5, [23, 19, 21]),
  MiRow(2.5, [31, 26, 29]),
  MiRow(4, [40, 35, 38]),
];
const _c70v750 = [
  MiRow(1.5, [25, 21, 23]),
  MiRow(2.5, [34, 28, 31]),
  MiRow(4, [45, 37, 41]),
  MiRow(6, [57, 48, 52]),
  MiRow(10, [77, 65, 70]),
  MiRow(16, [102, 86, 92]),
  MiRow(25, [133, 112, 120]),
  MiRow(35, [163, 137, 147]),
  MiRow(50, [202, 169, 181]),
  MiRow(70, [247, 207, 221]),
  MiRow(95, [296, 249, 264]),
  MiRow(120, [340, 286, 303]),
  MiRow(150, [388, 327, 346]),
  MiRow(185, [440, 371, 392]),
  MiRow(240, [514, 434, 457]),
];
const _c105v500 = [
  MiRow(1.5, [28, 24, 27]),
  MiRow(2.5, [38, 33, 36]),
  MiRow(4, [51, 44, 47]),
];
const _c105v750 = [
  MiRow(1.5, [31, 26, 30]),
  MiRow(2.5, [42, 35, 41]),
  MiRow(4, [55, 47, 53]),
  MiRow(6, [70, 59, 67]),
  MiRow(10, [96, 81, 91]),
  MiRow(16, [127, 107, 119]),
  MiRow(25, [166, 140, 154]),
  MiRow(35, [203, 171, 187]),
  MiRow(50, [251, 212, 230]),
  MiRow(70, [307, 260, 280]),
  MiRow(95, [369, 312, 334]),
  MiRow(120, [424, 359, 383]),
  MiRow(150, [485, 410, 435]),
  MiRow(185, [550, 465, 492]),
  MiRow(240, [643, 544, 572]),
];
const _e70v500 = [
  MiRow(1.5, [25, 21, 23, 26, 29]),
  MiRow(2.5, [33, 28, 31, 34, 39]),
  MiRow(4, [44, 37, 41, 45, 51]),
];
const _e70v750 = [
  MiRow(1.5, [26, 22, 26, 28, 32]),
  MiRow(2.5, [36, 30, 34, 37, 43]),
  MiRow(4, [47, 40, 45, 49, 56]),
  MiRow(6, [60, 51, 57, 62, 71]),
  MiRow(10, [82, 69, 77, 84, 95]),
  MiRow(16, [109, 92, 102, 110, 125]),
  MiRow(25, [142, 120, 132, 142, 162]),
  MiRow(35, [174, 147, 161, 173, 197]),
  MiRow(50, [215, 182, 198, 213, 242]),
  MiRow(70, [264, 223, 241, 259, 294]),
  MiRow(95, [317, 267, 289, 309, 351]),
  MiRow(120, [364, 308, 331, 353, 402]),
  MiRow(150, [416, 352, 377, 400, 454]),
  MiRow(185, [472, 399, 426, 446, 507]),
  MiRow(240, [552, 466, 496, 497, 565]),
];
const _e105v500 = [
  MiRow(1.5, [31, 26, 29, 33, 37]),
  MiRow(2.5, [41, 35, 39, 43, 49]),
  MiRow(4, [54, 46, 51, 56, 64]),
];
const _e105v750 = [
  MiRow(1.5, [33, 28, 32, 35, 40]),
  MiRow(2.5, [45, 38, 43, 47, 54]),
  MiRow(4, [60, 50, 56, 61, 70]),
  MiRow(6, [76, 64, 71, 78, 89]),
  MiRow(10, [104, 87, 96, 105, 120]),
  MiRow(16, [137, 115, 127, 137, 157]),
  MiRow(25, [179, 150, 164, 178, 204]),
  MiRow(35, [220, 184, 200, 216, 248]),
  MiRow(50, [272, 228, 247, 266, 304]),
  MiRow(70, [333, 279, 300, 323, 370]),
  MiRow(95, [400, 335, 359, 385, 441]),
  MiRow(120, [460, 385, 411, 441, 505]),
  MiRow(150, [526, 441, 469, 498, 565]),
  MiRow(185, [596, 500, 530, 557, 629]),
  MiRow(240, [697, 584, 617, 624, 704]),
];

List<MiRow> miRows({
  required MiMethod method,
  required MiSheath sheath,
  required bool v750,
}) {
  if (method == MiMethod.c) {
    return sheath == MiSheath.t70
        ? (v750 ? _c70v750 : _c70v500)
        : (v750 ? _c105v750 : _c105v500);
  }
  return sheath == MiSheath.t70
      ? (v750 ? _e70v750 : _e70v500)
      : (v750 ? _e105v750 : _e105v500);
}

/// 값 하나. 그 단면적이 없으면 null.
int? miAmpacity({
  required MiMethod method,
  required MiSheath sheath,
  required bool v750,
  required double mm2,
  required int col,
}) {
  for (final r in miRows(method: method, sheath: sheath, v750: v750)) {
    if (r.mm2 == mm2) return col < r.amps.length ? r.amps[col] : null;
  }
  return null;
}
