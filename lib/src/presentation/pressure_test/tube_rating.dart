// 계기용 정밀 튜브(외경 기준)의 허용 사용압력과 시험압력 한도(화면 없음).
// 근거는 docs/압력시험계산기_근거.md "튜브 허용 사용압력".
//
// 계산 값: ASME B31.3-2018 304.1.2(a) 식 (3a)를 P로 푼 것 P = 2·S·E·W·t / (D − 2·Y·t).
// E = W = 1(이음매 없는 관), Y = 0.4(표 304.1.1, 482°C 이하). t ≥ D/6이면 표 304.1.1 주에 따라
// Y = d/(D + d)로 계산한다(Lamé 식과 같다. Swagelok 표도 이렇게 계산돼 있다).
// 치수는 최대 외경과 최소 두께로 계산한다(Swagelok MS-01-107 3쪽 "maximum OD and minimum wall"과 같은 방법).
//   SS316(ASTM A269-14 표 4): 외경 +0.005"(0.13mm), 두께 외경 1/2"(12.7mm) 미만 −15%, 이상 −10%.
//   탄소강(ASTM A179): 최소 두께로 주문하는 관이라 적힌 두께를 그대로 쓰고, 외경은 SS와 같게 +0.13mm(보수적).
// S·항복강도: B31.3-2018 표 A-1(165·166·188·189쪽). A179 400°F 이상 값은 engineersforengineers 표와 같음을 확인.
// 제조사 표 값: Swagelok "Tubing Data" MS-01-107 Rev W(2023-10) 표 1(3쪽, 탄소강 인치),
// 표 3(5쪽, 스테인리스 인치), 표 4(6쪽, 스테인리스 mm). −28~37°C 값. 같은 방법으로 다시 계산해
// 100psi(인치)·10bar(mm) 아래로 버린 값과 모두 같음을 확인했다(3/8" × 0.083" 등 피팅 시험 값은 목록에 넣지 않음).
//
// B31.1(동력 배관)이면 B31.1-2022 104.1.2(a) 식 (9) P = 2SEW(tm − A) / (Do − 2y(tm − A))로 계산한다.
// E = W = 1(이음매 없는 관, 102.4.7: 크리프 영역 아래·탄소강 제외), A = 0(압축 이음 튜브는 나사·홈을 내지 않음),
// y = 0.4(표 104.1.2-1, 482°C 이하 페라이트·오스테나이트강). Do/tm < 6이면 y = d/(d + Do)(같은 표 일반 주 (b)).
// S: SS316은 표 A-3 A213 TP316(A269는 B31.1 부록 A 표에 없다), 주 (9)의 높은 값이 아닌 줄.
// 탄소강은 표 A-1 A179. 원문 사본(B31.1-2022 PDF, 126·127·152·153쪽)에서 확인. 치수는 B31.3과 같게 최대 외경·최소 두께.
library;

import 'dart:math' as math;

import 'pressure_calc.dart' show PipingCode;

/// 튜브 재질.
enum TubeMaterial { ss316, cs }

/// 치수 단위(인치 튜브·mm 튜브).
enum TubeSystem { inch, metric }

extension TubeMaterialInfo on TubeMaterial {
  /// 칩 이름.
  String get label => this == TubeMaterial.ss316 ? 'SS316' : '탄소강';

  /// 기록·기록서에 적는 이름.
  String get specLabel =>
      this == TubeMaterial.ss316 ? 'SS316 (ASTM A269/A213)' : '탄소강 (ASTM A179)';

  /// 최소 항복강도(ksi, 표 A-1). 시험 온도(38°C 이하) 값으로 쓴다.
  double get syKsi => this == TubeMaterial.ss316 ? 30 : 26;

  /// 표 A-1 최저 온도(°C, SI 표 값: −425°F = −254°C, −20°F = −29°C).
  double get minTempC => this == TubeMaterial.ss316 ? -254 : -29;
}

/// 튜브 규격 하나(외경 × 두께). 인치 튜브는 인치, mm 튜브는 mm로 적는다.
class TubeSize {
  final String id;
  final TubeSystem system;
  final String odText; // '1/4' 또는 '12'
  final double od;
  final double wall;

  /// Swagelok MS-01-107 표 값(인치: psig, mm: bar). 없으면 null.
  final int? swSs;
  final int? swCs;

  const TubeSize(
    this.id,
    this.system,
    this.odText,
    this.od,
    this.wall, {
    this.swSs,
    this.swCs,
  });

  bool get inch => system == TubeSystem.inch;
  double get odMm => inch ? od * 25.4 : od;
  double get wallMm => inch ? wall * 25.4 : wall;
  double get idMm => odMm - 2 * wallMm;

  /// 목록 이름: 1/4" × 0.035", 12 × 1.5 mm.
  String get label => inch
      ? '$odText" × ${wall.toStringAsFixed(3)}"'
      : '$odText × ${_num(wall)} mm';

  /// 제조사 표 값(kPa). 없으면 null.
  double? makerKpa(TubeMaterial m) {
    final v = m == TubeMaterial.ss316 ? swSs : swCs;
    if (v == null) return null;
    return inch ? v * kPsiKpa : v * 100.0;
  }

  /// 제조사 표 원래 값 글: "5100 psig", "330 bar".
  String? makerText(TubeMaterial m) {
    final v = m == TubeMaterial.ss316 ? swSs : swCs;
    if (v == null) return null;
    return inch ? '$v psig' : '$v bar';
  }

  /// 제조사 표 출처.
  String makerSource(TubeMaterial m) {
    final t = m == TubeMaterial.cs ? '표 1, 3쪽' : (inch ? '표 3, 5쪽' : '표 4, 6쪽');
    return 'Swagelok MS-01-107 $t';
  }
}

String _num(double v) {
  var s = v.toStringAsFixed(3);
  s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return s;
}

const double kPsiKpa = 6.894757293168361;
const double kKsiKpa = 6894.757293168361;

/// 목록: 인치 1/8"~1", mm 6~25mm. 제조사 값은 Swagelok MS-01-107 Rev W 표 1·3·4.
/// mm 탄소강 표(표 2)는 EN 10305-1 관 기준이라 A179와 재질이 달라 넣지 않았다.
const List<TubeSize> kTubeSizes = [
  // dart format off
  // 인치: (id, 외경 글, 외경 in, 두께 in, Swagelok SS 표 3 psig, 탄소강 표 1 psig)
  TubeSize('i1/8x028', TubeSystem.inch, '1/8', 0.125, 0.028, swSs: 8500, swCs: 8000),
  TubeSize('i1/8x035', TubeSystem.inch, '1/8', 0.125, 0.035, swSs: 10900, swCs: 10200),
  TubeSize('i1/4x028', TubeSystem.inch, '1/4', 0.25, 0.028, swSs: 4000, swCs: 3700),
  TubeSize('i1/4x035', TubeSystem.inch, '1/4', 0.25, 0.035, swSs: 5100, swCs: 4800),
  TubeSize('i1/4x049', TubeSystem.inch, '1/4', 0.25, 0.049, swSs: 7500, swCs: 7000),
  TubeSize('i1/4x065', TubeSystem.inch, '1/4', 0.25, 0.065, swSs: 10200, swCs: 9600),
  TubeSize('i3/8x035', TubeSystem.inch, '3/8', 0.375, 0.035, swSs: 3300, swCs: 3100),
  TubeSize('i3/8x049', TubeSystem.inch, '3/8', 0.375, 0.049, swSs: 4800, swCs: 4500),
  TubeSize('i3/8x065', TubeSystem.inch, '3/8', 0.375, 0.065, swSs: 6500, swCs: 6200),
  TubeSize('i1/2x035', TubeSystem.inch, '1/2', 0.5, 0.035, swSs: 2600, swCs: 2300),
  TubeSize('i1/2x049', TubeSystem.inch, '1/2', 0.5, 0.049, swSs: 3700, swCs: 3300),
  TubeSize('i1/2x065', TubeSystem.inch, '1/2', 0.5, 0.065, swSs: 5100, swCs: 4500),
  TubeSize('i1/2x083', TubeSystem.inch, '1/2', 0.5, 0.083, swSs: 6700, swCs: 5900),
  TubeSize('i3/4x049', TubeSystem.inch, '3/4', 0.75, 0.049, swSs: 2400, swCs: 2100),
  TubeSize('i3/4x065', TubeSystem.inch, '3/4', 0.75, 0.065, swSs: 3300, swCs: 2900),
  TubeSize('i3/4x083', TubeSystem.inch, '3/4', 0.75, 0.083, swSs: 4200, swCs: 3700),
  TubeSize('i3/4x095', TubeSystem.inch, '3/4', 0.75, 0.095, swSs: 4900, swCs: 4300),
  TubeSize('i3/4x109', TubeSystem.inch, '3/4', 0.75, 0.109, swSs: 5800, swCs: 5100),
  TubeSize('i1x065', TubeSystem.inch, '1', 1.0, 0.065, swSs: 2400, swCs: 2100),
  TubeSize('i1x083', TubeSystem.inch, '1', 1.0, 0.083, swSs: 3100, swCs: 2700),
  TubeSize('i1x095', TubeSystem.inch, '1', 1.0, 0.095, swSs: 3600, swCs: 3200),
  TubeSize('i1x109', TubeSystem.inch, '1', 1.0, 0.109, swSs: 4200, swCs: 3700),
  TubeSize('i1x120', TubeSystem.inch, '1', 1.0, 0.120, swSs: 4700, swCs: 4100),
  // mm: (id, 외경 글, 외경 mm, 두께 mm, Swagelok SS 표 4 bar)
  TubeSize('m6x1', TubeSystem.metric, '6', 6.0, 1.0, swSs: 430),
  TubeSize('m6x1.5', TubeSystem.metric, '6', 6.0, 1.5, swSs: 720),
  TubeSize('m8x1', TubeSystem.metric, '8', 8.0, 1.0, swSs: 310),
  TubeSize('m8x1.5', TubeSystem.metric, '8', 8.0, 1.5, swSs: 530),
  TubeSize('m10x1', TubeSystem.metric, '10', 10.0, 1.0, swSs: 240),
  TubeSize('m10x1.5', TubeSystem.metric, '10', 10.0, 1.5, swSs: 410),
  TubeSize('m12x1', TubeSystem.metric, '12', 12.0, 1.0, swSs: 200),
  TubeSize('m12x1.5', TubeSystem.metric, '12', 12.0, 1.5, swSs: 330),
  TubeSize('m12x2', TubeSystem.metric, '12', 12.0, 2.0, swSs: 480),
  TubeSize('m14x2', TubeSystem.metric, '14', 14.0, 2.0, swSs: 390),
  TubeSize('m16x1.5', TubeSystem.metric, '16', 16.0, 1.5, swSs: 230),
  TubeSize('m16x2', TubeSystem.metric, '16', 16.0, 2.0, swSs: 330),
  TubeSize('m18x2', TubeSystem.metric, '18', 18.0, 2.0, swSs: 290),
  TubeSize('m20x2', TubeSystem.metric, '20', 20.0, 2.0, swSs: 260),
  TubeSize('m22x2', TubeSystem.metric, '22', 22.0, 2.0, swSs: 240),
  TubeSize('m25x2', TubeSystem.metric, '25', 25.0, 2.0, swSs: 200),
  TubeSize('m25x2.5', TubeSystem.metric, '25', 25.0, 2.5, swSs: 260),
  // dart format on
];

/// 단위별 기본 규격.
const String kTubeDefaultInch = 'i1/4x035';
const String kTubeDefaultMetric = 'm12x1.5';

List<TubeSize> tubeSizes(TubeSystem s) => [
  for (final t in kTubeSizes)
    if (t.system == s) t,
];

TubeSize? tubeById(String? id) {
  for (final t in kTubeSizes) {
    if (t.id == id) return t;
  }
  return null;
}

/// 기록에 적는 튜브 규격 글: "SS316 (ASTM A269/A213) 1/4" × 0.035" (6.35 × 0.89 mm)".
String tubeSpecText(TubeSize t, TubeMaterial m) =>
    '${m.specLabel} ${t.label}${t.inch ? ' (${_num2(t.odMm)} × ${_num2(t.wallMm)} mm)' : ''}';

String _num2(double v) {
  var s = v.toStringAsFixed(2);
  s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return s;
}

// ─────────────── 허용 응력(B31.3-2018 표 A-1) ───────────────

/// (°F, ksi). 최저 온도부터 100°F까지는 첫 값. 표에 있는 800°F(427°C)까지만 넣었다.
const Map<TubeMaterial, List<(double, double)>> _sTable = {
  // A269·A213 TP316(S31600): 188·189쪽(스테인리스 관·튜브), 최소 항복 30ksi.
  TubeMaterial.ss316: [
    (100, 20.0),
    (200, 20.0),
    (300, 20.0),
    (400, 19.3),
    (500, 18.0),
    (600, 17.0),
    (650, 16.6),
    (700, 16.3),
    (750, 16.1),
    (800, 15.9),
  ],
  // A179(K01200): 165·166쪽, 최소 항복 26ksi.
  TubeMaterial.cs: [
    (100, 15.7),
    (200, 15.7),
    (300, 15.3),
    (400, 14.8),
    (500, 14.1),
    (600, 13.3),
    (650, 12.8),
    (700, 12.4),
    (750, 10.7),
    (800, 9.2),
  ],
};

// ─────────────── 허용 응력(B31.1-2022 표 A-3·A-1) ───────────────

/// (°F, ksi). 표 머리 "100 200 … 800"(°F 이하). 800°F(427°C)까지만 넣었다(B31.3과 같은 범위).
const Map<TubeMaterial, List<(double, double)>> _sTable311 = {
  // 표 A-3 이음매 없는 관·튜브 오스테나이트 A213 TP316(S31600), 주 (10) 줄(152·153쪽), 최소 항복 30ksi.
  // 같은 규격의 주 (9) 줄(20.0 20.0 20.0 19.3 18.0 17.0 16.6 16.3 16.1 15.9)은 "조금만 변형돼도 새거나
  // 오동작하는 곳에는 쓰지 않는다"는 값이라 압축 이음 튜브에는 쓰지 않는다.
  TubeMaterial.ss316: [
    (100, 20.0),
    (200, 17.3),
    (300, 15.6),
    (400, 14.3),
    (500, 13.3),
    (600, 12.6),
    (650, 12.3),
    (700, 12.1),
    (750, 11.9),
    (800, 11.8),
  ],
  // 표 A-1 이음매 없는 관·튜브 A179, 주 (1)(2)(5)(126·127쪽), 인장 (47)·항복 26ksi.
  TubeMaterial.cs: [
    (100, 13.4),
    (200, 13.4),
    (300, 13.4),
    (400, 13.4),
    (500, 13.4),
    (600, 13.3),
    (650, 12.8),
    (700, 12.4),
    (750, 10.7),
    (800, 9.2),
  ],
};

/// B31.1 최저 온도(°C). 표 A-1·A-3에는 최저 온도 칸이 없고 저온은 124.1.2(B31T)로 따로 정한다.
/// 부록 VIII 표 VIII-1(B31T 발췌)의 스테인리스 무리 저온 사용 한계가 −20°F(−29°C)라,
/// 앱은 두 재질 모두 −29°C 아래를 계산하지 않는다(그 아래는 B31T 요건 검토 대상).
const double kTube311MinC = -29;

List<(double, double)> _table(TubeMaterial m, PipingCode code) =>
    code == PipingCode.b311 ? _sTable311[m]! : _sTable[m]!;

/// 표 최저 온도(°C).
double tubeMinTempC(TubeMaterial m, PipingCode code) =>
    code == PipingCode.b311 ? kTube311MinC : m.minTempC;

/// 허용 응력 표 이름: "B31.1 표 A-3, A213 TP316".
String tubeStressTableText(TubeMaterial m, PipingCode code) {
  if (code == PipingCode.b311) {
    return m == TubeMaterial.ss316
        ? 'B31.1 표 A-3, A213 TP316'
        : 'B31.1 표 A-1, A179';
  }
  return m == TubeMaterial.ss316
      ? 'B31.3 표 A-1, A269·A213 TP316'
      : 'B31.3 표 A-1, A179';
}

/// 표에 넣은 최고 온도(°F). 입력은 °C로 427°C(= 800.6°F)까지 받고 800°F 값을 쓴다(SI 표 427°C).
const double kTubeMaxF = 800;
const double kTubeMaxC = 427;

/// 제조사 표 온도 범위(−20~100°F = −28~37°C).
const double kMakerMinF = -20;
const double kMakerMaxF = 100;

double cToF(double c) => c * 9 / 5 + 32;
double fToC(double f) => (f - 32) * 5 / 9;

/// 설계 온도(°C)에서 허용 응력(ksi). 표 범위 밖이면 null. 표 사이는 직선 보간.
/// [code]가 B31.1이면 B31.1 표 A-3·A-1 값.
double? tubeAllowableKsi(
  TubeMaterial m,
  double tC, {
  PipingCode code = PipingCode.b313,
}) {
  if (tC < tubeMinTempC(m, code) - 1e-9 || tC > kTubeMaxC + 1e-9) return null;
  final f = math.min(cToF(tC), kTubeMaxF);
  final t = _table(m, code);
  if (f <= t.first.$1) return t.first.$2;
  for (var i = 0; i < t.length - 1; i++) {
    final a = t[i], b = t[i + 1];
    if (f <= b.$1 + 1e-9) {
      return a.$2 + (b.$2 - a.$2) * (f - a.$1) / (b.$1 - a.$1);
    }
  }
  return t.last.$2;
}

/// 표 온도 범위 글(°C): "−254~427°C".
String tubeTempRangeText(TubeMaterial m, {PipingCode code = PipingCode.b313}) =>
    '${tubeMinTempC(m, code).round()}~${kTubeMaxC.round()}°C';

/// B31.3 304.1.2 식으로 압력(kPa). [odMm] 외경, [tMm] 두께, [sKsi] 응력.
/// t ≥ D/6이면 Y = d/(D + d), 아니면 0.4.
double b313TubeKpa({
  required double odMm,
  required double tMm,
  required double sKsi,
}) {
  final d = odMm - 2 * tMm;
  final y = isThickWall(odMm, tMm) ? d / (odMm + d) : 0.4;
  return 2 * sKsi * kKsiKpa * tMm / (odMm - 2 * y * tMm);
}

bool isThickWall(double odMm, double tMm) => tMm >= odMm / 6 - 1e-12;

/// B31.1 104.1.2(a) 식 (9)로 압력(kPa). E = W = 1, A = 0.
/// y = 0.4(표 104.1.2-1, 482°C 이하), Do/tm < 6이면 y = d/(d + Do)(같은 표 일반 주 (b)).
double b311TubeKpa({
  required double odMm,
  required double tMm,
  required double sKsi,
}) {
  final d = odMm - 2 * tMm;
  final y = isThickWall311(odMm, tMm) ? d / (d + odMm) : 0.4;
  return 2 * sKsi * kKsiKpa * tMm / (odMm - 2 * y * tMm);
}

/// B31.1: Do/tm < 6.
bool isThickWall311(double odMm, double tMm) => odMm / tMm < 6 - 1e-12;

double _codeKpa(PipingCode code, double odMm, double tMm, double sKsi) =>
    code == PipingCode.b311
    ? b311TubeKpa(odMm: odMm, tMm: tMm, sKsi: sKsi)
    : b313TubeKpa(odMm: odMm, tMm: tMm, sKsi: sKsi);

/// 최대 외경(mm): 공칭 + 0.13mm(0.005").
double tubeMaxOdMm(TubeSize t) => t.odMm + (t.inch ? 0.005 * 25.4 : 0.13);

/// 최소 두께(mm): SS316은 외경 12.7mm 미만 −15%, 이상 −10%(A269 표 4). 탄소강 A179는 적힌 두께 그대로.
double tubeMinWallMm(TubeSize t, TubeMaterial m) {
  if (m == TubeMaterial.cs) return t.wallMm;
  return t.wallMm * (t.odMm < 12.7 - 1e-9 ? 0.85 : 0.90);
}

/// 두께 허용차 글.
String tubeWallTolText(TubeSize t, TubeMaterial m) => m == TubeMaterial.cs
    ? 'A179는 최소 두께로 주문하는 관이라 적힌 두께 그대로'
    : (t.odMm < 12.7 - 1e-9
          ? 'A269 표 4: 외경 12.7mm 미만 −15%'
          : 'A269 표 4: 외경 12.7mm 이상 −10%');

class TubeRating {
  final TubeSize size;
  final TubeMaterial material;
  final PipingCode code; // 계산 식·허용 응력 표(B31.3 또는 B31.1)
  final double designC;
  final double sKsi; // 설계 온도 S
  final double sTestKsi; // 시험 온도(38°C 이하) S
  final double maxOdMm;
  final double minWallMm;
  final double calcKpa; // 최대 외경·최소 두께 기준 계산 값
  final double nominalKpa; // 공칭 외경·공칭 두께 기준(참고)
  final double? makerKpa; // 제조사 표 값(비교에 쓰는 것: 설계 온도가 −28~37°C일 때만)
  final double? makerTableKpa; // 제조사 표 값(온도와 관계없이, 없으면 null)
  final double yieldKpa; // 시험 온도에서 관 응력이 최소 항복강도가 되는 압력(최소 두께 기준)
  final bool thick; // B31.3: 최소 두께 ≥ 최대 외경/6, B31.1: Do/tm < 6

  const TubeRating({
    required this.size,
    required this.material,
    this.code = PipingCode.b313,
    required this.designC,
    required this.sKsi,
    required this.sTestKsi,
    required this.maxOdMm,
    required this.minWallMm,
    required this.calcKpa,
    required this.nominalKpa,
    required this.makerKpa,
    required this.makerTableKpa,
    required this.yieldKpa,
    required this.thick,
  });

  /// 허용 사용압력: 계산 값과 제조사 표 값 중 작은 것.
  double get allowKpa =>
      makerKpa == null ? calcKpa : math.min(calcKpa, makerKpa!);

  bool get makerGoverns => makerKpa != null && makerKpa! < calcKpa;

  /// ST/S(시험 온도 S ÷ 설계 온도 S).
  double get stRatio => sTestKsi / sKsi;

  /// B31.3 공압 최대(345.5.4 (b)): 345.2.1(a) 압력(여기서는 튜브 항복)의 90%.
  double get yield90Kpa => 0.9 * yieldKpa;

  /// 허용 응력 표 이름("B31.1 표 A-3, A213 TP316").
  String get stressTableText => tubeStressTableText(material, code);
}

/// 튜브 허용 사용압력. [designC] 설계 온도(°C, 없으면 38°C 이하로 본다).
/// [code]가 B31.1이면 B31.1 104.1.2 식과 표 A-3·A-1 S. 표 온도 범위 밖이면 null.
TubeRating? tubeRating({
  required TubeSize size,
  required TubeMaterial material,
  double? designC,
  PipingCode code = PipingCode.b313,
}) {
  final tC = designC ?? fToC(kMakerMaxF);
  final s = tubeAllowableKsi(material, tC, code: code);
  if (s == null) return null;
  final sTest = _table(material, code).first.$2;
  final dMax = tubeMaxOdMm(size);
  final tMin = tubeMinWallMm(size, material);
  final f = cToF(tC);
  final table = size.makerKpa(material);
  // 입력은 °C 정수로 넣으므로 −29°C·38°C(−20.2°F·100.4°F)도 표 온도 안으로 본다.
  final inMakerRange = f >= kMakerMinF - 0.5 && f <= kMakerMaxF + 0.5;
  return TubeRating(
    size: size,
    material: material,
    code: code,
    designC: tC,
    sKsi: s,
    sTestKsi: sTest,
    maxOdMm: dMax,
    minWallMm: tMin,
    calcKpa: _codeKpa(code, dMax, tMin, s),
    nominalKpa: _codeKpa(code, size.odMm, size.wallMm, s),
    makerKpa: inMakerRange ? table : null,
    makerTableKpa: table,
    yieldKpa: _codeKpa(code, dMax, tMin, material.syKsi),
    thick: code == PipingCode.b311
        ? isThickWall311(dMax, tMin)
        : isThickWall(dMax, tMin),
  );
}

/// 튜브 여러 구간의 체적(L) = Σ π/4 · 내경² · 길이(공칭 내경).
double tubeVolumeL(Iterable<(TubeSize, double)> segments) {
  var v = 0.0;
  for (final (t, len) in segments) {
    if (len > 0) v += math.pi / 4 * math.pow(t.idMm / 1000, 2) * len * 1000;
  }
  return v;
}
