// 구리 부스바 허용전류: DIN 43671(1975) 표 값. 칸마다 두 출처 이상이 같은 값만 넣는다(2026-09-26 조사).
//
// 조건(DIN 43671 표 머리말): 옥내, 주위 35°C, 부스바 65°C, 부스바 폭을 세운 상태(수직),
// 같은 상 부스바 사이 간격 = 부스바 두께. 교류 4가닥은 2가닥씩 두 묶음(묶음 사이 50mm), 직류 4가닥은
// 한 줄로 4가닥. 재질 E-Cu F30.
//
// 출처(docs/전기계산기_근거.md "부스바"):
//  A. Druseidt "Belastungstabelle für Stromschienen aus Kupfer nach DIN 43671"(교류·직류, 도장·도장 안 함, 1~4가닥 전체)
//     https://shop.druseidt.de/allgemeine-informationen/flexible-verbinder/belastungstabelle-fuer-stromschienen-aus-kupfer-nach-din-43671/
//  B. Rittal 카탈로그 33 "Rated currents of busbars E-Cu (DIN 43 671)"(1가닥, 교류·직류, 12×2~100×10)
//     https://www.rittal.com/imf/none/3_1978/
//  C. Radiolex "Current load capacity of copper and aluminium busbars"(교류 1·2가닥, 도장·도장 안 함)
//     https://en.radiolex.pl/wiedza/current-load-capacity-of-copper-and-aluminium-busbars/
//  D. EAE E-Kabin B 시리즈 "Copper busbar assembly implementation guide" Chart 1(교류 1~4가닥)
//     https://techniq.hu/wp-content/uploads/2024/06/EAE-E-Kabin-B-szeria-elosztoszekreny.pdf
//  E. Mostec "Dauerbelastung für Stromschienen aus Kupfer (DIN43671)"(20×5 이상, 교류·직류 1~4가닥)
//     http://www.mostec.de/03Mostec2000/Mostec2000/Anhang/Tabellen/Stromschienen.html
//  F. Licht + Technik "Kupferschienen"(1가닥 도장 안 함, 교류·직류)
//     https://lichtplustechnik.de/en/kupferschienen/
//  G. PDFCOFFEE "DIN 43671 (Tabla de Barras)"(두 칸의 충돌 확인용)
//     https://pdfcoffee.com/din-43671-1-pdf-tabla-de-barras-pdf-free.html
//
// 출처끼리 달랐던 칸(두 출처가 같은 값을 씀):
//  · 30×10 교류 도장 안 함 2가닥: A·C·D 1060, E 1030 → 1060
//  · 50×5 교류 도장 안 함 3가닥: A·D 1260, E 1240 → 1260
//  · 25×5 교류 도장 3가닥: D·G 839, A 869 → 839
//  · 160×10 직류 도장 안 함 4가닥: E·G 7710, A 7110 → 7710
// 값 0: DIN 43671 표에 값이 없는 칸. 값 -1: 한 출처(A)뿐이라 넣지 않은 칸(얇은 부스바 직류 2·3가닥).
// 알루미늄(DIN 43670)은 출처끼리 값이 달라 넣지 않았다. 온도 보정계수 k2는 DIN 43671에 그림으로만 있어
// 넣지 않았다(35°C·85°C를 Rittal 1.29, Siemens LV 10 1.3으로 읽음).
library;

/// 부스바 한 줄: 폭×두께(mm), 단면적(mm², DIN 43671 표 값), 1~4가닥 허용전류(A).
class BusbarRow {
  final int width;
  final int thick;
  final double area;
  final List<int> acPainted;
  final List<int> acBare;
  final List<int> dcPainted;
  final List<int> dcBare;
  const BusbarRow(
    this.width,
    this.thick,
    this.area,
    this.acPainted,
    this.acBare,
    this.dcPainted,
    this.dcBare,
  );

  String get label => '$width×$thick';

  List<int> column({required bool dc, required bool painted}) =>
      dc ? (painted ? dcPainted : dcBare) : (painted ? acPainted : acBare);
}

// 열: [1, 2, 3, 4가닥]. 교류는 60Hz까지, 직류는 16⅔Hz 교류와 같은 열.
// dart format off
const List<BusbarRow> kBusbars = [
  //        폭  두께  단면적   교류 도장 1~4가닥          교류 도장 안 함 1~4가닥    직류 도장 1~4가닥          직류 도장 안 함 1~4가닥
  BusbarRow( 12,  2, 23.5, [ 123,  202,  228,    0], [ 108,  182,  216,    0], [ 123,   -1,   -1,    0], [ 108,   -1,   -1,    0]),
  BusbarRow( 15,  2, 29.5, [ 148,  240,  261,    0], [ 128,  212,  247,    0], [ 148,   -1,   -1,    0], [ 128,   -1,   -1,    0]),
  BusbarRow( 15,  3, 44.5, [ 187,  316,  381,    0], [ 162,  282,  361,    0], [ 187,   -1,   -1,    0], [ 162,   -1,   -1,    0]),
  BusbarRow( 20,  2, 39.5, [ 189,  302,  313,    0], [ 162,  264,  298,    0], [ 189,   -1,   -1,    0], [ 162,   -1,   -1,    0]),
  BusbarRow( 20,  3, 59.5, [ 237,  394,  454,    0], [ 204,  348,  431,    0], [ 237,   -1,   -1,    0], [ 204,   -1,   -1,    0]),
  BusbarRow( 20,  5, 99.1, [ 319,  560,  728,    0], [ 274,  500,  690,    0], [ 320,  562,  729,    0], [ 274,  502,  687,    0]),
  BusbarRow( 20, 10,  199, [ 497,  924, 1320,    0], [ 427,  825, 1180,    0], [ 499,  932, 1300,    0], [ 428,  832, 1210,    0]),
  BusbarRow( 25,  3, 74.5, [ 287,  470,  525,    0], [ 245,  412,  498,    0], [ 287,   -1,   -1,    0], [ 245,   -1,   -1,    0]),
  BusbarRow( 25,  5,  124, [ 384,  662,  839,    0], [ 327,  586,  795,    0], [ 384,   -1,   -1,    0], [ 327,   -1,   -1,    0]),
  BusbarRow( 30,  3, 89.5, [ 337,  544,  593,    0], [ 285,  476,  564,    0], [ 337,   -1,   -1,    0], [ 286,   -1,   -1,    0]),
  BusbarRow( 30,  5,  149, [ 447,  760,  944,    0], [ 379,  672,  896,    0], [ 448,  766,  950,    0], [ 380,  676,  897,    0]),
  BusbarRow( 30, 10,  299, [ 676, 1200, 1670,    0], [ 573, 1060, 1480,    0], [ 683, 1230, 1630,    0], [ 579, 1080, 1520,    0]),
  BusbarRow( 40,  3,  119, [ 435,  692,  725,    0], [ 366,  600,  690,    0], [ 436,   -1,   -1,    0], [ 367,   -1,   -1,    0]),
  BusbarRow( 40,  5,  199, [ 573,  952, 1140,    0], [ 482,  836, 1090,    0], [ 576,  966, 1160,    0], [ 484,  848, 1100,    0]),
  BusbarRow( 40, 10,  399, [ 850, 1470, 2000, 2580], [ 715, 1290, 1770, 2280], [ 865, 1530, 2000,    0], [ 728, 1350, 1880,    0]),
  BusbarRow( 50,  5,  249, [ 697, 1140, 1330, 2010], [ 583,  994, 1260, 1920], [ 703, 1170, 1370,    0], [ 588, 1020, 1300,    0]),
  BusbarRow( 50, 10,  499, [1020, 1720, 2320, 2950], [ 852, 1510, 2040, 2600], [1050, 1830, 2360,    0], [ 875, 1610, 2220,    0]),
  BusbarRow( 60,  5,  299, [ 826, 1330, 1510, 2310], [ 688, 1150, 1440, 2210], [ 836, 1370, 1580, 2060], [ 696, 1190, 1500, 1970]),
  BusbarRow( 60, 10,  599, [1180, 1960, 2610, 3290], [ 985, 1720, 2300, 2900], [1230, 2130, 2720, 3580], [1020, 1870, 2570, 3390]),
  BusbarRow( 80,  5,  399, [1070, 1680, 1830, 2830], [ 885, 1450, 1750, 2720], [1090, 1770, 1990, 2570], [ 902, 1530, 1890, 2460]),
  BusbarRow( 80, 10,  799, [1500, 2410, 3170, 3930], [1240, 2110, 2790, 3450], [1590, 2730, 3420, 4490], [1310, 2380, 3240, 4280]),
  BusbarRow(100,  5,  499, [1300, 2010, 2150, 3300], [1080, 1730, 2050, 3190], [1340, 2160, 2380, 3080], [1110, 1810, 2270, 2960]),
  BusbarRow(100, 10,  999, [1810, 2850, 3720, 4530], [1490, 2480, 3260, 3980], [1940, 3310, 4100, 5310], [1600, 2890, 3900, 5150]),
  BusbarRow(120, 10, 1200, [2110, 3280, 4270, 5130], [1740, 2860, 3740, 4500], [2300, 3900, 4780, 6260], [1890, 3390, 4560, 6010]),
  BusbarRow(160, 10, 1600, [2700, 4130, 5360, 6320], [2220, 3590, 4680, 5530], [3010, 5060, 6130, 8010], [2470, 4400, 5860, 7710]),
  BusbarRow(200, 10, 2000, [3290, 4970, 6430, 7490], [2690, 4310, 5610, 6540], [3720, 6220, 7460, 9730], [3040, 5390, 7150, 9390]),
];
// dart format on

/// 표 칸의 상태.
enum BusbarCell { ok, notInTable, notVerified }

/// 한 조합의 허용전류. [amps]는 [cell]이 ok일 때만 있다.
class BusbarRating {
  final BusbarRow row;
  final int bars;
  final BusbarCell cell;
  final int? amps;
  const BusbarRating(this.row, this.bars, this.cell, this.amps);

  /// 전류 밀도(A/mm²) = 허용전류 ÷ (단면적 × 가닥 수).
  double? get density => amps == null ? null : amps! / (row.area * bars);
}

BusbarRating busbarRating(
  BusbarRow row, {
  required int bars,
  required bool dc,
  required bool painted,
}) {
  final n = bars.clamp(1, 4);
  final v = row.column(dc: dc, painted: painted)[n - 1];
  if (v > 0) return BusbarRating(row, n, BusbarCell.ok, v);
  return BusbarRating(
    row,
    n,
    v == 0 ? BusbarCell.notInTable : BusbarCell.notVerified,
    null,
  );
}

/// [need] A 이상인 부스바 중 단면적(구리 양)이 가장 작은 것. 단면적이 같으면(예: 20×10과 40×5)
/// 허용전류가 큰 쪽. 없으면 null.
BusbarRating? smallestBusbar(
  double need, {
  required int bars,
  required bool dc,
  required bool painted,
}) {
  BusbarRating? best;
  for (final r in kBusbars) {
    final k = busbarRating(r, bars: bars, dc: dc, painted: painted);
    if (k.amps == null || k.amps! < need - 1e-9) continue;
    if (best == null ||
        r.area < best.row.area - 1e-9 ||
        ((r.area - best.row.area).abs() < 1e-9 && k.amps! > best.amps!)) {
      best = k;
    }
  }
  return best;
}
