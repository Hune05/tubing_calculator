// 단위 환산 — 분류·단위·환산 상수와 인치 분수·전선 굵기·배관 호칭 계산(화면 없음).
//
// 2026-09-26 사용자 요청: "가장 많이 쓰고 평이 좋은 수준으로". 평 좋은 환산 앱들처럼 한 분류의
// 모든 단위를 한꺼번에 바꾸고(칸에 "1"을 미리 넣지 않음), 현장 앱처럼 인치 분수(1/16")와 오차,
// 배관 호칭표를 둔다. 상수는 모두 정의값(1 in = 25.4 mm, 1 lb = 0.45359237 kg,
// 1 kgf = 9.80665 N …)이다. 평·근·돈은 계량법상 거래에 못 쓰는 단위라 넣지 않았다.
//
// 2026-09-26 점검 반영: 압력은 게이지압(진공은 음수)과 절대압(a) 단위, 수주 온도 기준 표시,
// mH₂O·cmHg·hPa, 온도차·에너지 분류, 냉동톤, 배관 호칭(20A·DN50·3/4B …) 찾기, "1,5" 소수점
// 쉼표, 작은 수도 유효 7자리, SQ→AWG는 같거나 굵은 규격, ASME B36.10M 외경 바로잡음.
import 'dart:math' as math;

String _norm(String x) => x.trim().toLowerCase().replaceAll(' ', '');

/// 찾기 순위: 0 = 이름이 같다, 1 = 앞이 같다, 2 = 들어 있다. 안 맞으면 null.
int? _rankIn(String s, Iterable<String> names) {
  int? best;
  for (final x in names) {
    final n = _norm(x);
    final r = n == s
        ? 0
        : n.startsWith(s)
        ? 1
        : n.contains(s)
        ? 2
        : null;
    if (r != null && (best == null || r < best)) best = r;
  }
  return best;
}

/// 0점을 옮기는 환산(온도·절대압)에서 빼기 끝에 남는 아주 작은 찌꺼기를 0으로.
/// 예: 32 °F → 273.15000000000003 K → 0.00000000000003 °C가 지수로 보이던 것.
double _snap(double r, double scale) => r.abs() < scale.abs() * 1e-12 ? 0 : r;

/// 단위 하나. 값 → 기준 단위([toBase]), 기준 → 값([fromBase]).
class UnitDef {
  final String id;
  final String symbol; // 칸 이름(예: psi)
  final String name; // 한글 이름(예: 파운드/제곱인치)
  final double Function(double) toBase;
  final double Function(double) fromBase;

  /// 찾기에 쓰는 다른 이름.
  final List<String> aliases;

  /// 숫자판 대신 글자판(분수·피트 입력).
  final bool textInput;

  /// 음수를 넣을 수 있다(온도·각도·게이지 압력의 진공). 삼성 자판에 "-"가 나오게 한다.
  final bool signed;

  const UnitDef._({
    required this.id,
    required this.symbol,
    required this.name,
    required this.toBase,
    required this.fromBase,
    this.aliases = const [],
    this.textInput = false,
    this.signed = false,
  });

  /// 기준 단위의 [factor]배인 단위.
  factory UnitDef.linear(
    String id,
    String symbol,
    String name,
    double factor, {
    List<String> aliases = const [],
    bool signed = false,
  }) => UnitDef._(
    id: id,
    symbol: symbol,
    name: name,
    toBase: (v) => v * factor,
    fromBase: (b) => b / factor,
    aliases: aliases,
    signed: signed,
  );

  /// 절대압 단위: 값 × [factor] − 표준 대기압 = 게이지압(Pa).
  factory UnitDef.absolute(
    String id,
    String symbol,
    String name,
    double factor, {
    List<String> aliases = const [],
  }) => UnitDef._(
    id: id,
    symbol: symbol,
    name: name,
    toBase: (v) => _snap(v * factor - kStdAtmPa, kStdAtmPa),
    fromBase: (b) => _snap((b + kStdAtmPa) / factor, kStdAtmPa / factor),
    aliases: aliases,
  );

  factory UnitDef.custom(
    String id,
    String symbol,
    String name, {
    required double Function(double) toBase,
    required double Function(double) fromBase,
    List<String> aliases = const [],
    bool textInput = false,
    bool signed = false,
  }) => UnitDef._(
    id: id,
    symbol: symbol,
    name: name,
    toBase: toBase,
    fromBase: fromBase,
    aliases: aliases,
    textInput: textInput,
    signed: signed,
  );

  /// 찾기 순위(0이 제일 잘 맞음). 안 맞으면 null.
  int? rank(String q) {
    final s = _norm(q);
    if (s.isEmpty) return null;
    return _rankIn(s, [symbol, name, ...aliases]);
  }

  bool matches(String q) => rank(q) != null;
}

/// 분류. [units]가 비었으면 표·전용 화면(전선 굵기·배관 호칭).
class UnitCategory {
  final String id;
  final String label;
  final List<UnitDef> units;
  final List<String> aliases;

  /// 기준 단위로 이보다 낮으면 있을 수 없는 값(온도: 0 K). 없으면 null.
  final double? minBase;
  const UnitCategory(
    this.id,
    this.label,
    this.units, {
    this.aliases = const [],
    this.minBase,
  });

  bool get isTable => units.isEmpty;
  UnitDef? unit(String id) {
    for (final u in units) {
      if (u.id == id) return u;
    }
    return null;
  }

  /// [base]가 있을 수 없는 값(절대영도 아래 등)이면 true.
  bool belowMin(double base) => minBase != null && base < minBase! - 1e-9;
}

double _deg(double r) => r * 180 / math.pi;
double _rad(double d) => d * math.pi / 180;

const double kMmPerInch = 25.4;

/// 표준 대기압(Pa). 절대압 = 게이지압 + 이 값.
const double kStdAtmPa = 101325;

// 길이(기준 m). 분수 인치·피트인치는 글자로 넣고 읽는다.
final UnitCategory kLength = UnitCategory('length', '길이', [
  // "12파이 튜브"처럼 파이(ø)는 외경 mm를 뜻한다(배관 호칭표로 가지 않게 mm에 둔다).
  UnitDef.linear(
    'mm',
    'mm',
    '밀리미터',
    0.001,
    aliases: ['밀리', 'mili', '파이', 'ø', 'φ'],
  ),
  UnitDef.linear('cm', 'cm', '센티미터', 0.01, aliases: ['센티']),
  UnitDef.linear('m', 'm', '미터', 1),
  UnitDef.custom(
    'in_frac',
    'inch 분수',
    '인치(분수)',
    toBase: (inch) => inch * 0.0254,
    fromBase: (m) => m / 0.0254,
    aliases: ['인치', '분수', 'inch', 'in', '"', '1/16'],
    textInput: true,
  ),
  UnitDef.linear('in', 'inch', '인치(소수)', 0.0254, aliases: ['인치', 'in']),
  UnitDef.custom(
    'ft_in',
    "ft-in",
    '피트·인치',
    toBase: (inch) => inch * 0.0254,
    fromBase: (m) => m / 0.0254,
    aliases: ['피트', 'feet', 'ft', "'"],
    textInput: true,
  ),
  UnitDef.linear('ft', 'ft', '피트', 0.3048, aliases: ['피트', 'feet', 'foot']),
  UnitDef.linear('yd', 'yd', '야드', 0.9144, aliases: ['야드', 'yard']),
  UnitDef.linear('km', 'km', '킬로미터', 1000),
]);

// 압력(기준 Pa, 게이지압). 진공은 음수로 넣는다. (a)·psia는 절대압(표준 대기압 101.325 kPa 기준).
//
// 수주·수은주 값의 근거(두 곳 이상에서 같은 값):
// - mmH₂O 9.80665 Pa, mH₂O 9806.65 Pa, inH₂O 249.0889 Pa: NIST SP 811 부록 B.8 "conventional"
//   (물 1000 kg/m³ = 4 °C 물, 4 °C 실제 밀도 999.972와 0.003% 차이). SensorsONE 환산표
//   "inH₂O 4°C" 249.089 Pa.
// - inH₂O 68 °F(20 °C) 248.64 Pa: Mensor CPC8000 설명서 표 11.3(0.03606233 psi = 248.6406 Pa),
//   solenoid-valve.world 환산표(248.64 Pa). 20 °C 물 998.207 kg/m³ × 9.80665 × 0.0254로도 같다.
//   Fluke 718·719 교정기가 "inH2O at 20 °C"를 쓴다. (60 °F는 NIST 248.84 Pa로 다른 값이다.)
// - mmHg 133.322387415 Pa, cmHg 1333.22387415 Pa, inHg 3386.389 Pa: NIST SP 811 B.8 conventional.
final UnitCategory kPressure = UnitCategory(
  'pressure',
  '압력',
  [
    UnitDef.linear('mpa', 'MPa', '메가파스칼', 1e6, signed: true),
    UnitDef.linear('kpa', 'kPa', '킬로파스칼', 1e3, signed: true),
    UnitDef.linear('bar', 'bar', '바', 1e5, aliases: ['barg'], signed: true),
    UnitDef.linear(
      'kgfcm2',
      'kgf/cm²',
      'kg/cm² (키로)',
      98066.5,
      aliases: [
        'kg/cm2',
        'kgf/cm2',
        'kgcm',
        '키로',
        '킬로',
        'kg/cm2g',
        'kgf/cm2g',
        '킬로그램힘',
      ],
      signed: true,
    ),
    UnitDef.linear(
      'psi',
      'psi',
      '파운드/제곱인치',
      6894.757293168361,
      aliases: ['프사이', '피에스아이', 'psig', 'lb/in2'],
      signed: true,
    ),
    UnitDef.linear('atm', 'atm', '기압', 101325, aliases: ['기압'], signed: true),
    UnitDef.linear('mbar', 'mbar', '밀리바', 100, signed: true),
    UnitDef.linear('hpa', 'hPa', '헥토파스칼', 100, aliases: ['헥토'], signed: true),
    UnitDef.linear('pa', 'Pa', '파스칼', 1, signed: true),
    UnitDef.linear(
      'mmh2o',
      'mmH₂O',
      '밀리미터 수주(4 °C)',
      9.80665,
      aliases: ['mmh2o', 'mmaq', '수주', 'mmwc'],
      signed: true,
    ),
    UnitDef.linear(
      'mh2o',
      'mH₂O',
      '미터 수주(4 °C)',
      9806.65,
      aliases: ['mh2o', 'maq', 'mwc', '수주', '양정', '수두', 'head'],
      signed: true,
    ),
    UnitDef.linear(
      'inh2o',
      'inH₂O',
      '인치 수주(4 °C)',
      249.08891,
      aliases: ['inh2o', 'inwc', 'inaq', '수주'],
      signed: true,
    ),
    UnitDef.linear(
      'inh2o68',
      'inH₂O 68°F',
      '인치 수주(68 °F)',
      248.64,
      aliases: ['inh2o', 'inwc', '20°c', '68°f', '수주'],
      signed: true,
    ),
    UnitDef.linear(
      'mmhg',
      'mmHg',
      '밀리미터 수은주',
      133.322387415,
      aliases: ['mmhg', '수은주', 'torr', '토르'],
      signed: true,
    ),
    UnitDef.linear(
      'cmhg',
      'cmHg',
      '센티미터 수은주',
      1333.22387415,
      aliases: ['cmhg', '수은주'],
      signed: true,
    ),
    UnitDef.linear(
      'inhg',
      'inHg',
      '인치 수은주',
      3386.389,
      aliases: ['inhg', '수은주'],
      signed: true,
    ),
    UnitDef.absolute(
      'bara',
      'bar(a)',
      '바 절대압',
      1e5,
      aliases: ['bara', 'bar a', '절대압', 'abs'],
    ),
    UnitDef.absolute(
      'kpaa',
      'kPa(a)',
      '킬로파스칼 절대압',
      1e3,
      aliases: ['kpaa', 'kpa a', '절대압', 'abs'],
    ),
    UnitDef.absolute(
      'psia',
      'psia',
      '파운드/제곱인치 절대압',
      6894.757293168361,
      aliases: ['psi a', '절대압', 'abs'],
    ),
    UnitDef.absolute(
      'kgfcm2a',
      'kg/cm²(a)',
      'kg/cm² 절대압',
      98066.5,
      aliases: ['kg/cm2a', 'kgf/cm2a', 'kg/cm2(a)', '절대압', 'abs'],
    ),
  ],
  aliases: ['압력', 'pressure', '게이지압', '진공'],
);

// 토크(기준 N·m).
final UnitCategory kTorque = UnitCategory(
  'torque',
  '토크',
  [
    UnitDef.linear('nm', 'N·m', '뉴턴미터', 1, aliases: ['nm', 'n.m', 'n-m']),
    UnitDef.linear('ncm', 'N·cm', '뉴턴센티미터', 0.01, aliases: ['ncm']),
    UnitDef.linear(
      'kgfm',
      'kgf·m',
      '킬로그램힘미터',
      9.80665,
      aliases: ['kgm', 'kgf.m', 'kg-m'],
    ),
    UnitDef.linear(
      'kgfcm',
      'kgf·cm',
      '킬로그램힘센티미터',
      0.0980665,
      aliases: ['kgcm', 'kgf.cm', 'kg-cm'],
    ),
    UnitDef.linear(
      'lbfft',
      'lbf·ft',
      '파운드피트',
      1.3558179483314004,
      aliases: ['lb-ft', 'lbft', 'ft-lb', 'ftlb'],
    ),
    UnitDef.linear(
      'lbfin',
      'lbf·in',
      '파운드인치',
      0.1129848290276167,
      aliases: ['lb-in', 'lbin', 'in-lb'],
    ),
  ],
  aliases: ['토크', 'torque', '조임'],
);

// 중량(질량, 기준 kg).
final UnitCategory kMass = UnitCategory(
  'mass',
  '중량',
  [
    UnitDef.linear('g', 'g', '그램', 0.001),
    UnitDef.linear('kg', 'kg', '킬로그램', 1, aliases: ['키로', '킬로']),
    UnitDef.linear('t', 't', '톤', 1000, aliases: ['톤', 'ton']),
    UnitDef.linear('lb', 'lb', '파운드', 0.45359237, aliases: ['파운드', 'pound']),
    UnitDef.linear('oz', 'oz', '온스', 0.028349523125, aliases: ['온스', 'ounce']),
  ],
  aliases: ['중량', '무게', '질량'],
);

// 힘(기준 N).
final UnitCategory kForce = UnitCategory(
  'force',
  '힘',
  [
    UnitDef.linear('n', 'N', '뉴턴', 1, aliases: ['뉴턴']),
    UnitDef.linear('kn', 'kN', '킬로뉴턴', 1000),
    UnitDef.linear('kgf', 'kgf', '킬로그램힘', 9.80665, aliases: ['키로', 'kg힘']),
    UnitDef.linear('tf', 'tf', '톤힘', 9806.65, aliases: ['톤', 'ton']),
    UnitDef.linear('lbf', 'lbf', '파운드힘', 4.4482216152605, aliases: ['파운드']),
  ],
  aliases: ['힘', '하중', 'force'],
);

// 온도(기준 K). 0 K(절대영도)보다 낮은 값은 화면에서 알린다.
final UnitCategory kTemperature = UnitCategory(
  'temp',
  '온도',
  [
    UnitDef.custom(
      'c',
      '°C',
      '섭씨',
      toBase: (c) => c + 273.15,
      fromBase: (k) => _snap(k - 273.15, 273.15),
      aliases: ['섭씨', 'c', '도'],
      signed: true,
    ),
    UnitDef.custom(
      'f',
      '°F',
      '화씨',
      toBase: (f) => (f + 459.67) * 5 / 9,
      fromBase: (k) => _snap(k * 9 / 5 - 459.67, 459.67),
      aliases: ['화씨', 'f'],
      signed: true,
    ),
    UnitDef.custom(
      'k',
      'K',
      '켈빈',
      toBase: (k) => k,
      fromBase: (k) => k,
      aliases: ['켈빈', 'kelvin'],
      signed: true,
    ),
  ],
  aliases: ['온도', 'temperature'],
  minBase: 0,
);

// 온도차(ΔT, 기준 K). 0점을 옮기지 않는다: 1 °C 차 = 1 K 차 = 1.8 °F 차.
final UnitCategory kTempDiff = UnitCategory(
  'tempdiff',
  '온도차',
  [
    UnitDef.linear(
      'dc',
      'Δ°C',
      '섭씨 온도차',
      1,
      aliases: ['°c차', '온도차', 'delta', 'dt'],
      signed: true,
    ),
    UnitDef.linear(
      'df',
      'Δ°F',
      '화씨 온도차',
      5 / 9,
      aliases: ['°f차', '온도차', 'delta', 'dt'],
      signed: true,
    ),
    UnitDef.linear(
      'dk',
      'K',
      '켈빈(온도차)',
      1,
      aliases: ['온도차', 'delta'],
      signed: true,
    ),
  ],
  aliases: ['온도차', 'Δt', 'delta t', 'dt'],
);

// 유량(기준 m³/s).
final UnitCategory kFlow = UnitCategory(
  'flow',
  '유량',
  [
    UnitDef.linear('lmin', 'L/min', '리터/분', 1e-3 / 60, aliases: ['lpm', '리터']),
    UnitDef.linear('lh', 'L/h', '리터/시간', 1e-3 / 3600),
    UnitDef.linear('ls', 'L/s', '리터/초', 1e-3),
    UnitDef.linear(
      'm3h',
      'm³/h',
      '세제곱미터/시간',
      1 / 3600,
      aliases: ['m3/h', '루베', 'cmh'],
    ),
    UnitDef.linear(
      'm3min',
      'm³/min',
      '세제곱미터/분',
      1 / 60,
      aliases: ['m3/min', 'cmm'],
    ),
    UnitDef.linear(
      'gpm',
      'GPM',
      '미국 갤런/분',
      0.003785411784 / 60,
      aliases: ['gpm', 'gal/min', '갤런'],
    ),
  ],
  aliases: ['유량', 'flow'],
);

// 면적(기준 m²).
final UnitCategory kArea = UnitCategory(
  'area',
  '면적',
  [
    UnitDef.linear('mm2', 'mm²', '제곱밀리미터', 1e-6, aliases: ['mm2', 'sq']),
    UnitDef.linear('cm2', 'cm²', '제곱센티미터', 1e-4, aliases: ['cm2']),
    UnitDef.linear('m2', 'm²', '제곱미터', 1, aliases: ['m2', '헤베']),
    UnitDef.linear('in2', 'in²', '제곱인치', 6.4516e-4, aliases: ['in2', 'sq in']),
    UnitDef.linear('ft2', 'ft²', '제곱피트', 0.09290304, aliases: ['ft2', 'sq ft']),
  ],
  aliases: ['면적', 'area'],
);

// 부피(기준 m³).
final UnitCategory kVolume = UnitCategory(
  'volume',
  '부피',
  [
    UnitDef.linear('ml', 'mL', '밀리리터(cc)', 1e-6, aliases: ['cc', 'ml']),
    UnitDef.linear('l', 'L', '리터', 1e-3, aliases: ['리터']),
    UnitDef.linear('m3', 'm³', '세제곱미터', 1, aliases: ['m3', '루베']),
    UnitDef.linear(
      'gal',
      'gal',
      '미국 갤런',
      0.003785411784,
      aliases: ['갤런', 'gallon'],
    ),
    UnitDef.linear('in3', 'in³', '세제곱인치', 1.6387064e-5, aliases: ['in3']),
    UnitDef.linear('ft3', 'ft³', '세제곱피트', 0.028316846592, aliases: ['ft3']),
  ],
  aliases: ['부피', '체적', 'volume'],
);

// 각도·구배(기준 도). 구배(%·mm/m)는 tan.
final UnitCategory kAngle = UnitCategory(
  'angle',
  '각도·구배',
  [
    UnitDef.custom(
      'deg',
      '°',
      '도',
      toBase: (d) => d,
      fromBase: (d) => d,
      aliases: ['도', 'deg'],
      signed: true,
    ),
    UnitDef.custom(
      'rad',
      'rad',
      '라디안',
      toBase: _deg,
      fromBase: _rad,
      aliases: ['라디안'],
      signed: true,
    ),
    UnitDef.custom(
      'pct',
      '%',
      '구배 퍼센트',
      toBase: (p) => _deg(math.atan(p / 100)),
      fromBase: (d) => math.tan(_rad(d)) * 100,
      aliases: ['퍼센트', '구배', 'slope'],
      signed: true,
    ),
    UnitDef.custom(
      'mmm',
      'mm/m',
      '구배 mm/m',
      toBase: (v) => _deg(math.atan(v / 1000)),
      fromBase: (d) => math.tan(_rad(d)) * 1000,
      aliases: ['mm/m', '구배', '기울기'],
      signed: true,
    ),
  ],
  aliases: ['각도', '구배', '기울기', 'angle'],
);

/// BTU(IT)/h를 W로: 1055.05585262 J / 3600 s.
const double _wPerBtuH = 0.29307107017222;

// 동력(기준 W). HP·kcal/h·냉동톤처럼 전기가 아닌 것도 있어 "동력"이라 부른다.
// 냉동톤: USRT = 12,000 BTU/h = 3516.853 W(NIST SP 811 B.8 "ton of refrigeration"),
// RT = 3,320 kcal/h = 3861.16 W(일본냉동공조학회 용어 68: 1 JRT = 3320 kcal/h = 3.86 kW,
// 1 USRT = 3024 kcal/h = 3.52 kW). 1 kcal/h = 4186.8 J / 3600 s = 1.163 W.
final UnitCategory kPower = UnitCategory(
  'power',
  '동력',
  [
    UnitDef.linear('w', 'W', '와트', 1),
    UnitDef.linear('kw', 'kW', '킬로와트', 1000),
    UnitDef.linear(
      'hp',
      'HP',
      '마력(HP)',
      745.6998715822702,
      aliases: ['마력', 'hp', '영마력'],
    ),
    UnitDef.linear('ps', 'PS', '미터마력(PS)', 735.49875, aliases: ['마력', 'ps']),
    UnitDef.linear('kcalh', 'kcal/h', '킬로칼로리/시간', 1.163, aliases: ['칼로리']),
    UnitDef.linear('btuh', 'BTU/h', 'BTU/시간', _wPerBtuH),
    UnitDef.linear(
      'usrt',
      'USRT',
      '미국 냉동톤',
      12000 * _wPerBtuH,
      aliases: ['냉동톤', '냉동', 'rt'],
    ),
    UnitDef.linear(
      'rt',
      'RT',
      '냉동톤(3,320 kcal/h)',
      3320 * 1.163,
      aliases: ['냉동톤', '냉동', 'jrt'],
    ),
  ],
  aliases: ['동력', '전력', '마력', '냉동능력', 'power'],
);

// 에너지·열량(기준 J). kcal·BTU는 국제(IT) 값: 1 kcal = 4186.8 J, 1 BTU = 1055.05585262 J
// (NIST SP 811 B.8: 4.1868 E+03, 1.055 056 E+03).
final UnitCategory kEnergy = UnitCategory(
  'energy',
  '에너지',
  [
    UnitDef.linear('j', 'J', '줄', 1),
    UnitDef.linear('kj', 'kJ', '킬로줄', 1e3),
    UnitDef.linear('mj', 'MJ', '메가줄', 1e6),
    UnitDef.linear('wh', 'Wh', '와트시', 3600),
    UnitDef.linear('kwh', 'kWh', '킬로와트시', 3.6e6, aliases: ['전력량']),
    UnitDef.linear('kcal', 'kcal', '킬로칼로리', 4186.8, aliases: ['칼로리']),
    UnitDef.linear('btu', 'BTU', '영국열량단위', 1055.05585262, aliases: ['btu']),
  ],
  aliases: ['에너지', '열량', '전력량', 'energy'],
);

/// 전선 굵기(SQ ↔ AWG)·배관 호칭: 표·전용 화면. 호칭 하나하나로도 찾는다(12AWG, 2.5sq …).
final UnitCategory kWire = UnitCategory(
  'wire',
  '전선 굵기',
  [],
  aliases: [
    '전선',
    'awg',
    'sq',
    '스퀘어',
    '케이블',
    'mm²',
    for (final n in kAwgList) ...['${awgLabel(n)}awg', 'awg${awgLabel(n)}'],
    for (final s in kSqSizes) '${formatNumber(s)}sq',
  ],
);

/// 배관 호칭: 표의 줄마다 20A · DN20 · 3/4B · 3/4" · NPS3/4로 찾는다(띄어 쓴 "1 1/2B"도).
final UnitCategory kPipe = UnitCategory(
  'pipe',
  '배관 호칭',
  [],
  aliases: [
    '호칭',
    '배관',
    '파이프',
    'dn',
    'nps',
    '전선관',
    '튜브',
    '외경',
    'od',
    for (final p in kPipeSizes) ...[
      p.a,
      'DN${p.dn}',
      '${p.b}B',
      '${p.b}"',
      'NPS${p.b}',
      if (p.b.contains('-')) '${p.b.replaceAll('-', '')}B',
    ],
    for (final t in kTubeInchSizes) '$t"',
  ],
);

/// 분류 차례: 많이 쓰는 것(길이·압력·온도·토크·유량·전선·배관)을 앞에 둔다.
final List<UnitCategory> kUnitCategories = [
  kLength,
  kPressure,
  kTemperature,
  kTorque,
  kFlow,
  kWire,
  kPipe,
  kMass,
  kForce,
  kPower,
  kEnergy,
  kTempDiff,
  kArea,
  kVolume,
  kAngle,
];

UnitCategory unitCategory(String id) =>
    kUnitCategories.firstWhere((c) => c.id == id, orElse: () => kLength);

/// 찾기 결과 한 줄(분류 + 단위; 표 분류는 단위 없음).
typedef UnitHit = ({UnitCategory category, UnitDef? unit});

/// 모든 분류에서 찾는다. 이름이 딱 같은 것 → 앞이 같은 것 → 들어 있는 것 차례
/// (예: "mAq"는 mH₂O가 먼저, mmH₂O는 뒤. "kg"은 중량의 kg이 먼저).
List<UnitHit> searchUnits(String q) {
  final s = _norm(q);
  if (s.isEmpty) return const [];
  final ranked = <({UnitHit hit, int rank, int order})>[];
  for (final c in kUnitCategories) {
    final catRank = _rankIn(s, [c.label, ...c.aliases]);
    if (c.isTable) {
      if (catRank != null) {
        ranked.add((
          hit: (category: c, unit: null),
          rank: catRank,
          order: ranked.length,
        ));
      }
      continue;
    }
    var any = false;
    for (final u in c.units) {
      final r = u.rank(s);
      if (r != null) {
        ranked.add((
          hit: (category: c, unit: u),
          rank: r,
          order: ranked.length,
        ));
        any = true;
      }
    }
    if (!any && catRank != null) {
      ranked.add((
        hit: (category: c, unit: null),
        rank: catRank,
        order: ranked.length,
      ));
    }
  }
  ranked.sort((a, b) => a.rank != b.rank ? a.rank - b.rank : a.order - b.order);
  return [for (final r in ranked) r.hit];
}

// ─────────────────────────── 숫자 ───────────────────────────

final RegExp _plainNumber = RegExp(r'^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$');

/// 숫자 칸 읽기. 빈 칸·잘못된 글은 null.
///
/// 쉼표: 점이 없고 마지막 쉼표 뒤가 딱 세 자리가 아니면 소수점으로 읽는다("1,5" = 1.5,
/// 쉼표 소수점 자판). 그 밖에는 천 단위 구분이다("1,000" = 1000, "1,000.5" = 1000.5).
/// 쉼표 소수점이 둘 이상이거나("1,2,5") 점 뒤에 쉼표가 오면("1.000,5") 못 읽는다.
double? parseNumber(String s) {
  var t = s.trim();
  if (t.isEmpty) return null;
  if (t.contains(',')) {
    final dot = t.indexOf('.');
    final lastComma = t.lastIndexOf(',');
    if (dot < 0) {
      final after = t.substring(lastComma + 1);
      if (RegExp(r'^\d{3}$').hasMatch(after)) {
        t = t.replaceAll(',', '');
      } else {
        if (t.indexOf(',') != lastComma) return null;
        t = t.replaceFirst(',', '.');
      }
    } else {
      if (lastComma > dot) return null;
      t = t.replaceAll(',', '');
    }
  }
  if (!_plainNumber.hasMatch(t)) return null;
  return double.tryParse(t);
}

/// 아직 치는 중인 숫자("-", ".", "-.")라 못 읽어도 알리지 않는다.
bool isPartialNumber(String s) => RegExp(r'^[+-]?\.?$').hasMatch(s.trim());

/// 인치 분수 칸에 치는 중인 글(숫자와 - / ' " . 띄어쓰기만)이면 true.
bool isPartialInches(String s) => RegExp(r'''^[\d\s'"\-/.]*$''').hasMatch(s);

/// 보이는 숫자: 유효 7자리, 끝의 0은 뗀다. 1e12 이상이나 1e-9 미만만 지수.
/// (1 mmH₂O = 0.00000980665 MPa도 소수 자리에서 잘리지 않는다.)
String formatNumber(double v) {
  if (v.isNaN || v.isInfinite) return '';
  if (v == 0) return '0';
  final a = v.abs();
  if (a >= 1e12 || a < 1e-9) return v.toStringAsExponential(4);
  final mag = (math.log(a) / math.ln10).floor(); // 12.3 → 1, 0.012 → -2
  final dec = (6 - mag).clamp(0, 15);
  var s = v.toStringAsFixed(dec);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s == '-0' ? '0' : s;
}

// ─────────────────────────── 인치 분수 ───────────────────────────

/// 인치 글 읽기: `1.375`, `3/8`, `1-3/8`, `1 3/8`, `1-3/8"`, `1' 3-5/8"`, `2'`, `1'3"`.
/// 인치로 돌려준다. 못 읽으면 null.
double? parseInches(String input) {
  var s = input
      .trim()
      .replaceAll('″', '"')
      .replaceAll('”', '"')
      .replaceAll('′', "'")
      .replaceAll('’', "'");
  if (s.isEmpty) return null;
  double total = 0;
  final fi = s.indexOf("'");
  var hadFeet = false;
  if (fi >= 0) {
    final ft = double.tryParse(s.substring(0, fi).trim());
    if (ft == null) return null;
    total += ft * 12;
    hadFeet = true;
    s = s.substring(fi + 1).trim();
    if (s.startsWith('-')) s = s.substring(1).trim();
  }
  s = s.replaceAll('"', '').trim();
  if (s.isEmpty) return hadFeet ? total : null;
  // 소수·정수만.
  final dec = double.tryParse(s);
  if (dec != null && RegExp(r'^\d+(\.\d+)?$').hasMatch(s)) return total + dec;
  // 분수 또는 대분수 — 정수와 분수 사이엔 띄어쓰기나 "-"가 있어야 한다("13/8"은 13/8).
  final m = RegExp(
    r'^(?:(\d+)(?:\s*-\s*|\s+))?(\d+)\s*/\s*(\d+)$',
  ).firstMatch(s);
  if (m == null) return null;
  final d = int.parse(m.group(3)!);
  if (d == 0) return null;
  final whole = m.group(1) == null ? 0 : int.parse(m.group(1)!);
  return total + whole + int.parse(m.group(2)!) / d;
}

/// 인치를 가장 가까운 1/[denom]" 분수로. [errMm]은 (실제 − 분수)mm — 양수면 실제가 더 길다.
({String text, double errMm}) inchFraction(double inches, {int denom = 16}) {
  final neg = inches < 0;
  final a = inches.abs();
  final n = (a * denom).round();
  final whole = n ~/ denom;
  var num = n % denom;
  var den = denom;
  while (num != 0 && num % 2 == 0) {
    num ~/= 2;
    den ~/= 2;
  }
  final body = num == 0
      ? '$whole"'
      : (whole == 0 ? '$num/$den"' : '$whole-$num/$den"');
  return (
    text: neg ? '-$body' : body,
    errMm: (a - n / denom) * kMmPerInch * (neg ? -1 : 1),
  );
}

/// 인치를 피트·인치 분수로(예: 4' 1-3/8").
String feetInches(double inches, {int denom = 16}) {
  final neg = inches < 0;
  final n = (inches.abs() * denom).round(); // 1/denom 인치 단위로 반올림
  final ft = n ~/ (12 * denom);
  final rest = (n - ft * 12 * denom) / denom;
  final inch = inchFraction(rest, denom: denom).text;
  final body = ft == 0 ? inch : "$ft' $inch";
  return neg ? '-$body' : body;
}

/// 분수 오차 글: `1-3/8"보다 0.08mm 깁니다` / `… 짧습니다` / `오차 없음`.
/// [fraction]은 [inchFraction]의 글(예: 1-3/8").
String fractionErrorText(double errMm, String fraction) {
  if (errMm.abs() < 0.005) return '오차 없음';
  // 0.075처럼 끝이 5인 값이 0.0749999…로 계산돼 내려가지 않게 조금 더한다.
  final v = (errMm.abs() + 1e-9).toStringAsFixed(2);
  return errMm > 0 ? '$fraction보다 ${v}mm 깁니다' : '$fraction보다 ${v}mm 짧습니다';
}

// ─────────────────────────── 전선 굵기 ───────────────────────────

/// AWG 번호 → 지름(mm). 0 = 1/0, -1 = 2/0, -2 = 3/0, -3 = 4/0.
double awgDiameterMm(int n) => 0.127 * math.pow(92, (36 - n) / 39).toDouble();
double awgAreaMm2(int n) {
  final d = awgDiameterMm(n);
  return math.pi / 4 * d * d;
}

/// 글로 쓴 AWG("10", "1/0", "0", "00", "4/0") → 번호. 못 읽으면 null.
int? parseAwg(String s) {
  final t = s
      .trim()
      .toLowerCase()
      .replaceAll('awg', '')
      .replaceAll('#', '')
      .trim();
  final m = RegExp(r'^(\d)/0$').firstMatch(t);
  if (m != null) return 1 - int.parse(m.group(1)!);
  if (RegExp(r'^0+$').hasMatch(t)) return 1 - t.length;
  final n = int.tryParse(t);
  if (n == null || n < 0 || n > 40) return null;
  return n;
}

String awgLabel(int n) => n > 0 ? '$n' : '${1 - n}/0';

/// KS C IEC 60228 공칭 단면적(mm², "sq").
const List<double> kSqSizes = [
  0.5,
  0.75,
  1,
  1.5,
  2.5,
  4,
  6,
  10,
  16,
  25,
  35,
  50,
  70,
  95,
  120,
  150,
  185,
  240,
  300,
  400,
  500,
  630,
];

/// AWG 번호 목록(굵은 쪽으로): 20 … 1, 1/0 … 4/0.
const List<int> kAwgList = [
  20,
  18,
  16,
  14,
  12,
  10,
  8,
  6,
  4,
  3,
  2,
  1,
  0,
  -1,
  -2,
  -3,
];

/// 가장 가까운 SQ와, 같거나 굵은 SQ(없으면 null). 바꿔 쓸 때는 [atLeast]를 쓴다
/// (1/0 AWG 53.5mm²: 가장 가까운 것은 50sq지만 더 가늘다 → 70sq).
({double nearest, double? atLeast}) sqFor(double mm2) {
  var nearest = kSqSizes.first;
  for (final s in kSqSizes) {
    if ((s - mm2).abs() < (nearest - mm2).abs()) nearest = s;
  }
  double? atLeast;
  for (final s in kSqSizes) {
    if (s >= mm2 - 1e-9) {
      atLeast = s;
      break;
    }
  }
  return (nearest: nearest, atLeast: atLeast);
}

/// 단면적(mm²)에 가장 가까운 AWG와, 같거나 굵은 AWG(4/0보다 굵으면 null).
/// 흔히 쓰는 번호([kAwgList])에서만 고른다(13·15 같은 홀수는 거의 안 판다).
/// 바꿔 쓸 때는 [atLeast]를 쓴다(2.5sq: 가장 가까운 14는 2.08mm²로 가늘다 → 12).
/// 표에 소수 둘째 자리로 반올림해 적은 값(12 AWG 3.3088 → "3.31")을 넣어도 그 AWG가
/// 나오게 0.5%는 같은 굵기로 본다(반올림 차이는 최대 0.5%, 20 AWG 0.5176 → 0.52).
({int nearest, int? atLeast}) awgFor(double mm2) {
  var nearest = kAwgList.first;
  for (final n in kAwgList) {
    if ((awgAreaMm2(n) - mm2).abs() < (awgAreaMm2(nearest) - mm2).abs()) {
      nearest = n;
    }
  }
  int? atLeast;
  for (final n in kAwgList) {
    if (awgAreaMm2(n) >= mm2 * (1 - 0.005)) {
      atLeast = n;
      break;
    }
  }
  return (nearest: nearest, atLeast: atLeast);
}

String sqLabel(double v) => '${formatNumber(v)}sq';

// ─────────────────────────── 배관 호칭 ───────────────────────────

/// 강관 호칭 한 줄: A ↔ B(인치) ↔ DN ↔ 외경(KS·ASME).
typedef PipeSize = ({String a, String b, int dn, double ksOd, double asmeOd});

/// KS D 3507(= JIS G 3452 SGP) 외경과 ASME B36.10M 외경(mm) — 표 값.
/// ASME는 B36.10M 표 1의 mm 열: NPS 10 = 273.0, NPS 12 = 323.8, NPS 18 = 457
/// (인치 값 10.750·12.750·18.000을 곱한 273.1·323.9·457.2가 아니다).
const List<PipeSize> kPipeSizes = [
  (a: '6A', b: '1/8', dn: 6, ksOd: 10.5, asmeOd: 10.3),
  (a: '8A', b: '1/4', dn: 8, ksOd: 13.8, asmeOd: 13.7),
  (a: '10A', b: '3/8', dn: 10, ksOd: 17.3, asmeOd: 17.1),
  (a: '15A', b: '1/2', dn: 15, ksOd: 21.7, asmeOd: 21.3),
  (a: '20A', b: '3/4', dn: 20, ksOd: 27.2, asmeOd: 26.7),
  (a: '25A', b: '1', dn: 25, ksOd: 34.0, asmeOd: 33.4),
  (a: '32A', b: '1-1/4', dn: 32, ksOd: 42.7, asmeOd: 42.2),
  (a: '40A', b: '1-1/2', dn: 40, ksOd: 48.6, asmeOd: 48.3),
  (a: '50A', b: '2', dn: 50, ksOd: 60.5, asmeOd: 60.3),
  (a: '65A', b: '2-1/2', dn: 65, ksOd: 76.3, asmeOd: 73.0),
  (a: '80A', b: '3', dn: 80, ksOd: 89.1, asmeOd: 88.9),
  (a: '90A', b: '3-1/2', dn: 90, ksOd: 101.6, asmeOd: 101.6),
  (a: '100A', b: '4', dn: 100, ksOd: 114.3, asmeOd: 114.3),
  (a: '125A', b: '5', dn: 125, ksOd: 139.8, asmeOd: 141.3),
  (a: '150A', b: '6', dn: 150, ksOd: 165.2, asmeOd: 168.3),
  (a: '200A', b: '8', dn: 200, ksOd: 216.3, asmeOd: 219.1),
  (a: '250A', b: '10', dn: 250, ksOd: 267.4, asmeOd: 273.0),
  (a: '300A', b: '12', dn: 300, ksOd: 318.5, asmeOd: 323.8),
  (a: '350A', b: '14', dn: 350, ksOd: 355.6, asmeOd: 355.6),
  (a: '400A', b: '16', dn: 400, ksOd: 406.4, asmeOd: 406.4),
  (a: '450A', b: '18', dn: 450, ksOd: 457.2, asmeOd: 457),
  (a: '500A', b: '20', dn: 500, ksOd: 508.0, asmeOd: 508.0),
];

/// 인치 튜브 호칭(외경 = 인치 × 25.4, 계산값).
const List<String> kTubeInchSizes = [
  '1/8',
  '1/4',
  '3/8',
  '1/2',
  '5/8',
  '3/4',
  '1',
];

/// 외경표 한 줄(호칭 글, 외경 mm).
typedef OdRow = ({String label, double od});

/// 측정한 외경 [mm]에 가장 가까운 줄. 표 외경의 5%(최소 1mm) 이내에 없으면 null.
OdRow? nearestOd(double mm, List<OdRow> table) {
  OdRow? best;
  for (final r in table) {
    if (best == null || (r.od - mm).abs() < (best.od - mm).abs()) best = r;
  }
  if (best == null) return null;
  final tol = math.max(1.0, best.od * 0.05);
  return (best.od - mm).abs() <= tol ? best : null;
}
