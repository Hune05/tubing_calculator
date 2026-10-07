// 공식 계산(화면 없음): 전기·유량·유공압 공식 모음(발전 플랜트 현장에서 자주 쓰는 것
// 위주, 2026-09-27 사용자 요청 — 전문대 전기 수준까지라 가장 많이 쓰는 공식 중심으로,
// 부족한 지식을 자료 모음으로 채우고 싶다고 함). 공식 하나마다 "무엇을 구하는지"를 하나로
// 고정해 두어(옴의 법칙도 전압·전류·저항 셋을 따로 둔다), 칸마다 무슨 값을 넣어야 하는지
// 이름·단위·도움말로 알려준다. 값은 모두 SI 단위(볼트·암페어·옴·와트·미터·초 등)로 받는다.
//
// 근거: 옴의 법칙·전력·임피던스·변압기·전동기 공식은 전기 기초 공식(교과서 수준, 유도
// 과정 docs 없음 — 상수 없는 정의식이라 원문 대조가 필요 없다). 레이놀즈수·연속방정식·
// 수두압·베르누이·마찰손실은 유체역학 기초 공식. 유공압(파스칼 원리·보일의 법칙 등)도
// 마찬가지로 교과서 수준 정의식. 3상 전력의 √3은 평형 3상 선간전압 기준(역률 각 θ는
// 부하 역률각). 전동기 토크 상수 9549(또는 9550)는 60/(2π) ≈ 9.5493을 kW·rpm 단위로
// 정리한 값이라 자료마다 9549~9550으로 조금씩 다르며, 여기서는 9549를 쓴다.
library;

import 'dart:math' as math;

/// 목록 화면 카테고리 머리에 보일 짧은 설명(법칙·공식 모음이라는 걸 알려준다).
const Map<String, String> kFormulaCategoryIntro = {
  '전기': '옴의 법칙부터 전동기·변압기까지, 현장에서 가장 자주 쓰는 전기 공식입니다.',
  '유량': '배관 속 유체(물·기름·공기)의 유량·유속·압력손실을 구하는 공식입니다.',
  '유공압': '유압·공압 실린더의 힘·속도·동력과 기체 법칙(보일·게이지압)입니다.',
};

class FormulaVar {
  final String key;
  final String label; // "전류 (I)"
  final String unit; // "A"
  final String hint; // 이 칸에 뭘 넣는지

  /// 역률·효율처럼 0~1 비율인 칸. 85처럼 %로 넣어도 0.85로 읽는다(10-07: 예전에는 85배 결과가 나왔다).
  final bool ratio;
  const FormulaVar({
    required this.key,
    required this.label,
    required this.unit,
    required this.hint,
    this.ratio = false,
  });
}

class FormulaDef {
  final String id;
  final String category; // "전기" | "유량"
  final String name;
  final String description;
  final List<FormulaVar> inputs;
  final String resultLabel;
  final String resultUnit;
  final String formulaText; // "V = I × R" 같은 화면에 보일 식.
  final double Function(Map<String, double> v) compute;
  const FormulaDef({
    required this.id,
    required this.category,
    required this.name,
    required this.description,
    required this.inputs,
    required this.resultLabel,
    required this.resultUnit,
    required this.formulaText,
    required this.compute,
  });
}

const _i = FormulaVar(
  key: 'i',
  label: '전류 (I)',
  unit: 'A',
  hint: '',
);
const _r = FormulaVar(
  key: 'r',
  label: '저항 (R)',
  unit: 'Ω',
  hint: '',
);
const _v = FormulaVar(
  key: 'v',
  label: '전압 (V)',
  unit: 'V',
  hint: '두 점 사이의 전위차(단상은 상전압)입니다.',
);

final List<FormulaDef> kFormulas = [
  // ─────────────── 전기 ───────────────
  FormulaDef(
    id: 'ohm_v',
    category: '전기',
    name: '옴의 법칙(전압 구하기)',
    description: '전류와 저항을 알 때 전압을 구합니다.',
    formulaText: 'V = I × R',
    inputs: const [_i, _r],
    resultLabel: '전압',
    resultUnit: 'V',
    compute: (v) => v['i']! * v['r']!,
  ),
  FormulaDef(
    id: 'ohm_i',
    category: '전기',
    name: '옴의 법칙(전류 구하기)',
    description: '전압과 저항을 알 때 전류를 구합니다.',
    formulaText: 'I = V / R',
    inputs: const [_v, _r],
    resultLabel: '전류',
    resultUnit: 'A',
    compute: (v) => v['v']! / v['r']!,
  ),
  FormulaDef(
    id: 'ohm_r',
    category: '전기',
    name: '옴의 법칙(저항 구하기)',
    description: '전압과 전류를 알 때 저항을 구합니다.',
    formulaText: 'R = V / I',
    inputs: const [_v, _i],
    resultLabel: '저항',
    resultUnit: 'Ω',
    compute: (v) => v['v']! / v['i']!,
  ),
  FormulaDef(
    id: 'power_vi',
    category: '전기',
    name: '전력(전압·전류로)',
    description: '단상 전력을 전압·전류로 구합니다(직류이거나 역률 1일 때).',
    formulaText: 'P = V × I',
    inputs: const [_v, _i],
    resultLabel: '전력',
    resultUnit: 'W',
    compute: (v) => v['v']! * v['i']!,
  ),
  FormulaDef(
    id: 'power_ir',
    category: '전기',
    name: '전력(전류·저항으로)',
    description: '전류와 저항을 알 때 소비 전력을 구합니다.',
    formulaText: 'P = I² × R',
    inputs: const [_i, _r],
    resultLabel: '전력',
    resultUnit: 'W',
    compute: (v) => v['i']! * v['i']! * v['r']!,
  ),
  FormulaDef(
    id: 'power_vr',
    category: '전기',
    name: '전력(전압·저항으로)',
    description: '전압과 저항을 알 때 소비 전력을 구합니다.',
    formulaText: 'P = V² / R',
    inputs: const [_v, _r],
    resultLabel: '전력',
    resultUnit: 'W',
    compute: (v) => v['v']! * v['v']! / v['r']!,
  ),
  FormulaDef(
    id: 'power_3ph',
    category: '전기',
    name: '3상 전력',
    description: '평형 3상 부하의 유효전력입니다. cosθ는 역률이고, θ(역률각)는 전압과 전류 사이 위상각입니다.',
    formulaText: 'P = √3 × V × I × cosθ',
    inputs: const [
      FormulaVar(
        key: 'v',
        label: '선간전압 (V)',
        unit: 'V',
        hint: '3상 선과 선 사이 전압입니다(예: 380V, 440V).',
      ),
      _i,
      FormulaVar(
        key: 'pf',
        label: '역률 (cosθ)',
        unit: '',
        hint: '부하 역률입니다(0~1). 모르면 1을 넣으면 최대치가 나옵니다.',
        ratio: true,
      ),
    ],
    resultLabel: '전력',
    resultUnit: 'W',
    compute: (v) => math.sqrt(3) * v['v']! * v['i']! * v['pf']!,
  ),
  FormulaDef(
    id: 'reactance_l',
    category: '전기',
    name: '유도 리액턴스',
    description: '코일(인덕터)이 교류에 만드는 저항 성분입니다.',
    formulaText: 'XL = 2π × f × L',
    inputs: const [
      FormulaVar(
        key: 'f',
        label: '주파수 (f)',
        unit: 'Hz',
        hint: '교류 주파수입니다(국내 60Hz).',
      ),
      FormulaVar(
        key: 'l',
        label: '인덕턴스 (L)',
        unit: 'H',
        hint: '코일의 인덕턴스입니다(헨리). mH면 0.001을 곱해 넣으십시오.',
      ),
    ],
    resultLabel: '유도 리액턴스',
    resultUnit: 'Ω',
    compute: (v) => 2 * math.pi * v['f']! * v['l']!,
  ),
  FormulaDef(
    id: 'reactance_c',
    category: '전기',
    name: '용량 리액턴스',
    description: '콘덴서(커패시터)가 교류에 만드는 저항 성분입니다.',
    formulaText: 'XC = 1 / (2π × f × C)',
    inputs: const [
      FormulaVar(
        key: 'f',
        label: '주파수 (f)',
        unit: 'Hz',
        hint: '교류 주파수입니다(국내 60Hz).',
      ),
      FormulaVar(
        key: 'c',
        label: '정전용량 (C)',
        unit: 'F',
        hint: '콘덴서 용량입니다(패럿). μF면 0.000001을 곱해 넣으십시오.',
      ),
    ],
    resultLabel: '용량 리액턴스',
    resultUnit: 'Ω',
    compute: (v) => 1 / (2 * math.pi * v['f']! * v['c']!),
  ),
  FormulaDef(
    id: 'resonant_freq',
    category: '전기',
    name: 'LC 공진 주파수',
    description: '인덕터·콘덴서로 이루어진 회로가 공진하는 주파수입니다.',
    formulaText: 'f = 1 / (2π√(LC))',
    inputs: const [
      FormulaVar(
        key: 'l',
        label: '인덕턴스 (L)',
        unit: 'H',
        hint: '코일의 인덕턴스입니다(헨리).',
      ),
      FormulaVar(
        key: 'c',
        label: '정전용량 (C)',
        unit: 'F',
        hint: '콘덴서 용량입니다(패럿).',
      ),
    ],
    resultLabel: '공진 주파수',
    resultUnit: 'Hz',
    compute: (v) {
      final lc = v['l']! * v['c']!;
      return 1 / (2 * math.pi * math.sqrt(lc));
    },
  ),

  // ─────────────── 유량 ───────────────
  FormulaDef(
    id: 'flow_q',
    category: '유량',
    name: '연속방정식(유량 구하기)',
    description: '관 단면적과 유속을 알 때 유량을 구합니다.',
    formulaText: 'Q = A × V',
    inputs: const [
      FormulaVar(
        key: 'a',
        label: '단면적 (A)',
        unit: 'm²',
        hint: '관 내경의 단면적입니다(원관이면 π×D²/4).',
      ),
      FormulaVar(
        key: 'vel',
        label: '유속 (V)',
        unit: 'm/s',
        hint: '',
      ),
    ],
    resultLabel: '유량',
    resultUnit: 'm³/s',
    compute: (v) => v['a']! * v['vel']!,
  ),
  FormulaDef(
    id: 'flow_v_from_d',
    category: '유량',
    name: '관 유속(내경으로)',
    description: '원형 관의 내경과 유량을 알 때 유속을 구합니다.',
    formulaText: 'V = Q / (π × D²/4)',
    inputs: const [
      FormulaVar(
        key: 'q',
        label: '유량 (Q)',
        unit: 'm³/s',
        hint: '',
      ),
      FormulaVar(
        key: 'd',
        label: '내경 (D)',
        unit: 'm',
        hint: '관 내경입니다(mm면 0.001을 곱해 넣으십시오).',
      ),
    ],
    resultLabel: '유속',
    resultUnit: 'm/s',
    compute: (v) => v['q']! / (math.pi * v['d']! * v['d']! / 4),
  ),
  FormulaDef(
    id: 'reynolds',
    category: '유량',
    name: '레이놀즈수',
    description: '흐름이 층류인지 난류인지 가리는 값입니다(관: 2300 이하 층류, 4000 이상 난류).',
    formulaText: 'Re = ρ × V × D / μ',
    inputs: const [
      FormulaVar(
        key: 'rho',
        label: '밀도 (ρ)',
        unit: 'kg/m³',
        hint: '유체 밀도입니다(물 약 1000, 공기 약 1.2).',
      ),
      FormulaVar(
        key: 'vel',
        label: '유속 (V)',
        unit: 'm/s',
        hint: '',
      ),
      FormulaVar(key: 'd', label: '내경 (D)', unit: 'm', hint: ''),
      FormulaVar(
        key: 'mu',
        label: '점성계수 (μ)',
        unit: 'Pa·s',
        hint: '유체의 점성입니다(물 20°C 약 0.001).',
      ),
    ],
    resultLabel: '레이놀즈수',
    resultUnit: '',
    compute: (v) => v['rho']! * v['vel']! * v['d']! / v['mu']!,
  ),
  FormulaDef(
    id: 'head_pressure',
    category: '유량',
    name: '압력 ↔ 수두',
    description: '액체 기둥 높이(수두)가 만드는 압력입니다.',
    formulaText: 'P = ρ × g × h',
    inputs: const [
      FormulaVar(
        key: 'rho',
        label: '밀도 (ρ)',
        unit: 'kg/m³',
        hint: '유체 밀도입니다(물 약 1000).',
      ),
      FormulaVar(key: 'h', label: '높이 (h)', unit: 'm', hint: ''),
    ],
    resultLabel: '압력',
    resultUnit: 'Pa',
    compute: (v) => v['rho']! * 9.80665 * v['h']!,
  ),
  FormulaDef(
    id: 'flow_velocity_head',
    category: '유량',
    name: '속도수두',
    description: '유속이 가진 에너지를 수두(높이)로 나타낸 값입니다. 베르누이 방정식의 한 항입니다.',
    formulaText: 'hv = V² / (2g)',
    inputs: const [
      FormulaVar(
        key: 'vel',
        label: '유속 (V)',
        unit: 'm/s',
        hint: '',
      ),
    ],
    resultLabel: '속도수두',
    resultUnit: 'm',
    compute: (v) => v['vel']! * v['vel']! / (2 * 9.80665),
  ),
  FormulaDef(
    id: 'flow_friction_loss',
    category: '유량',
    name: '관 마찰손실(달시-바이스바흐)',
    description: '관 속을 흐르며 마찰로 잃는 압력(수두)입니다. 마찰계수는 배관 자료표·무디선도값을 씁니다.',
    formulaText: 'hf = f × (L/D) × V²/(2g)',
    inputs: const [
      FormulaVar(
        key: 'f',
        label: '마찰계수 (f)',
        unit: '',
        hint: '무디선도·배관 자료표의 마찰계수입니다(매끈한 새 강관, 난류면 대략 0.02 안팎).',
      ),
      FormulaVar(
        key: 'l',
        label: '배관 길이 (L)',
        unit: 'm',
        hint: '',
      ),
      FormulaVar(key: 'd', label: '내경 (D)', unit: 'm', hint: ''),
      FormulaVar(
        key: 'vel',
        label: '유속 (V)',
        unit: 'm/s',
        hint: '',
      ),
    ],
    resultLabel: '마찰손실수두',
    resultUnit: 'm',
    compute: (v) =>
        v['f']! * (v['l']! / v['d']!) * (v['vel']! * v['vel']!) / (2 * 9.80665),
  ),
  FormulaDef(
    id: 'flow_orifice',
    category: '유량',
    name: '오리피스·노즐 유량',
    description: '탱크·수조 바닥 구멍이나 오리피스를 통해 나오는 유량입니다. 유량계수는 오리피스 자료표값입니다.',
    formulaText: 'Q = Cd × A × √(2gh)',
    inputs: const [
      FormulaVar(
        key: 'cd',
        label: '유량계수 (Cd)',
        unit: '',
        hint: '오리피스·노즐 자료표의 유량계수입니다(예리한 오리피스 대략 0.6).',
      ),
      FormulaVar(
        key: 'a',
        label: '구멍 단면적 (A)',
        unit: 'm²',
        hint: '',
      ),
      FormulaVar(
        key: 'h',
        label: '수두 (h)',
        unit: 'm',
        hint: '수면부터 구멍까지 높이(압력차를 수두로 환산한 값)입니다.',
      ),
    ],
    resultLabel: '유량',
    resultUnit: 'm³/s',
    compute: (v) => v['cd']! * v['a']! * math.sqrt(2 * 9.80665 * v['h']!),
  ),
  FormulaDef(
    id: 'pump_shaft_power',
    category: '유량',
    name: '펌프 축동력',
    description: '펌프가 유체에 일을 하는 데 실제로 드는 동력입니다(전동기가 펌프에 넣어 주는 동력).',
    formulaText: 'P = ρ × g × Q × H / η',
    inputs: const [
      FormulaVar(
        key: 'rho',
        label: '밀도 (ρ)',
        unit: 'kg/m³',
        hint: '유체 밀도입니다(물 약 1000).',
      ),
      FormulaVar(
        key: 'q',
        label: '유량 (Q)',
        unit: 'm³/s',
        hint: '',
      ),
      FormulaVar(
        key: 'h',
        label: '전양정 (H)',
        unit: 'm',
        hint: '펌프가 올려야 하는 전체 수두(토출-흡입 높이차 + 손실수두)입니다.',
      ),
      FormulaVar(
        key: 'eta',
        label: '펌프 효율 (η)',
        unit: '',
        hint: '펌프 효율입니다(0~1). 명판·자료표값, 모르면 0.7 안팎으로 어림합니다.',
        ratio: true,
      ),
    ],
    resultLabel: '축동력',
    resultUnit: 'W',
    compute: (v) => v['rho']! * 9.80665 * v['q']! * v['h']! / v['eta']!,
  ),

  // ─────────────── 전기(추가): 전력 삼각형·역률·변압기·전동기 ───────────────
  FormulaDef(
    id: 'apparent_power',
    category: '전기',
    name: '피상전력(유효·무효전력으로)',
    description: '유효전력(P)과 무효전력(Q)으로 피상전력(S, 변압기·발전기 용량)을 구합니다.',
    formulaText: 'S = √(P² + Q²)',
    inputs: const [
      FormulaVar(
        key: 'p',
        label: '유효전력 (P)',
        unit: 'W',
        hint: '실제 일을 하는 전력입니다(모터·히터가 소비, 계기로는 kW).',
      ),
      FormulaVar(
        key: 'q',
        label: '무효전력 (Q)',
        unit: 'var',
        hint: '코일·콘덴서가 주고받기만 하는 전력입니다(계기로는 kvar).',
      ),
    ],
    resultLabel: '피상전력',
    resultUnit: 'VA',
    compute: (v) => math.sqrt(v['p']! * v['p']! + v['q']! * v['q']!),
  ),
  FormulaDef(
    id: 'real_power_from_s',
    category: '전기',
    name: '유효전력(피상전력·역률로)',
    description: '변압기·발전기 용량(피상전력)과 부하 역률로 실제 쓰는 전력을 구합니다.',
    formulaText: 'P = S × cosθ',
    inputs: const [
      FormulaVar(
        key: 's',
        label: '피상전력 (S)',
        unit: 'VA',
        hint: '변압기·발전기 명판 용량(피상전력)입니다.',
      ),
      FormulaVar(
        key: 'pf',
        label: '역률 (cosθ)',
        unit: '',
        hint: '부하 역률입니다(0~1).',
        ratio: true,
      ),
    ],
    resultLabel: '유효전력',
    resultUnit: 'W',
    compute: (v) => v['s']! * v['pf']!,
  ),
  FormulaDef(
    id: 'power_factor',
    category: '전기',
    name: '역률(유효·피상전력으로)',
    description: '지금 부하의 역률을 계기로 측정한 유효전력·피상전력으로 거꾸로 구합니다.',
    formulaText: 'cosθ = P / S',
    inputs: const [
      FormulaVar(
        key: 'p',
        label: '유효전력 (P)',
        unit: 'W',
        hint: '전력계(kW)로 측정한 유효전력입니다.',
      ),
      FormulaVar(
        key: 's',
        label: '피상전력 (S)',
        unit: 'VA',
        hint: '변압기 용량이거나, 전압×전류(3상은 √3×V×I)로 구한 피상전력입니다.',
      ),
    ],
    resultLabel: '역률',
    resultUnit: '',
    compute: (v) => v['p']! / v['s']!,
  ),
  FormulaDef(
    id: 'pf_correction_capacitor',
    category: '전기',
    name: '역률 개선 콘덴서 용량',
    description: '역률을 목표까지 올리는 데 필요한 콘덴서 용량입니다. tanθ는 역률각의 탄젠트(=Q/P)입니다.',
    formulaText: 'Qc = P × (tanθ1 − tanθ2)',
    inputs: const [
      FormulaVar(
        key: 'p',
        label: '유효전력 (P)',
        unit: 'W',
        hint: '부하의 유효전력(kW)입니다.',
      ),
      FormulaVar(
        key: 'pf1',
        label: '지금 역률 (cosθ1)',
        unit: '',
        hint: '콘덴서를 달기 전 지금 역률입니다(0~1).',
        ratio: true,
      ),
      FormulaVar(
        key: 'pf2',
        label: '목표 역률 (cosθ2)',
        unit: '',
        hint: '올리고 싶은 목표 역률입니다(0~1, 예: 0.95).',
        ratio: true,
      ),
    ],
    resultLabel: '콘덴서 용량',
    resultUnit: 'var',
    compute: (v) {
      double tanFromCos(double c) => math.sqrt(1 - c * c) / c;
      return v['p']! * (tanFromCos(v['pf1']!) - tanFromCos(v['pf2']!));
    },
  ),
  FormulaDef(
    id: 'impedance_z',
    category: '전기',
    name: '임피던스 크기',
    description: '저항과 리액턴스(유도·용량)가 함께 있는 회로의 전체 임피던스 크기입니다.',
    formulaText: 'Z = √(R² + X²)',
    inputs: const [
      _r,
      FormulaVar(
        key: 'x',
        label: '리액턴스 (X)',
        unit: 'Ω',
        hint: '유도·용량 리액턴스(또는 둘의 합)입니다.',
      ),
    ],
    resultLabel: '임피던스',
    resultUnit: 'Ω',
    compute: (v) => math.sqrt(v['r']! * v['r']! + v['x']! * v['x']!),
  ),
  FormulaDef(
    id: 'conductor_resistance',
    category: '전기',
    name: '전선 저항',
    description: '전선 길이·단면적·재질(고유저항)로 저항을 구합니다. 전압강하 계산의 바탕이 됩니다.',
    formulaText: 'R = ρ × L / A',
    inputs: const [
      FormulaVar(
        key: 'rho',
        label: '고유저항 (ρ)',
        unit: 'Ω·mm²/m',
        hint: '도체 재질의 고유저항입니다(구리 20°C 약 1/58 ≈ 0.0172, 알루미늄 약 0.0282).',
      ),
      FormulaVar(
        key: 'l',
        label: '길이 (L)',
        unit: 'm',
        hint: '전선의 길이입니다(왕복이면 그 길이를 넣으십시오).',
      ),
      FormulaVar(
        key: 'a',
        label: '단면적 (A)',
        unit: 'mm²',
        hint: '전선의 공칭 단면적입니다(예: 2.5, 5.5, 14).',
      ),
    ],
    resultLabel: '저항',
    resultUnit: 'Ω',
    compute: (v) => v['rho']! * v['l']! / v['a']!,
  ),
  FormulaDef(
    id: 'transformer_v2',
    category: '전기',
    name: '변압기 2차 전압(권수비로)',
    description: '1차 권수·2차 권수 비로 2차 쪽에 나오는 전압을 구합니다.',
    formulaText: 'V2 = V1 × (N2 / N1)',
    inputs: const [
      FormulaVar(
        key: 'v1',
        label: '1차 전압 (V1)',
        unit: 'V',
        hint: '',
      ),
      FormulaVar(
        key: 'n1',
        label: '1차 권수 (N1)',
        unit: '턴',
        hint: '',
      ),
      FormulaVar(
        key: 'n2',
        label: '2차 권수 (N2)',
        unit: '턴',
        hint: '',
      ),
    ],
    resultLabel: '2차 전압',
    resultUnit: 'V',
    compute: (v) => v['v1']! * (v['n2']! / v['n1']!),
  ),
  FormulaDef(
    id: 'transformer_short_circuit',
    category: '전기',
    name: '변압기 단락전류(%임피던스로)',
    description: '변압기 명판의 %임피던스로, 2차 쪽을 완전히 단락했을 때 흐를 수 있는 최대 전류를 어림합니다.',
    formulaText: 'Isc = In × 100 / %Z',
    inputs: const [
      FormulaVar(
        key: 'in_',
        label: '정격전류 (In)',
        unit: 'A',
        hint: '변압기 명판의 정격(2차) 전류입니다.',
      ),
      FormulaVar(
        key: 'z',
        label: '%임피던스 (%Z)',
        unit: '%',
        hint: '변압기 명판의 %임피던스입니다(예: 5, 6.5).',
      ),
    ],
    resultLabel: '단락전류',
    resultUnit: 'A',
    compute: (v) => v['in_']! * 100 / v['z']!,
  ),
  FormulaDef(
    id: 'motor_sync_speed',
    category: '전기',
    name: '전동기 동기속도',
    description:
        '유도전동기 명판의 극수와 주파수로 동기속도(회전자기장 속도)를 구합니다. 실제 회전수는 슬립만큼 더 낮습니다.',
    formulaText: 'Ns = 120 × f / P',
    inputs: const [
      FormulaVar(
        key: 'f',
        label: '주파수 (f)',
        unit: 'Hz',
        hint: '전원 주파수입니다(국내 60Hz).',
      ),
      FormulaVar(
        key: 'p',
        label: '극수 (P)',
        unit: '극',
        hint: '전동기 명판의 극수입니다(4극, 6극처럼 짝수).',
      ),
    ],
    resultLabel: '동기속도',
    resultUnit: 'rpm',
    compute: (v) => 120 * v['f']! / v['p']!,
  ),
  FormulaDef(
    id: 'motor_slip',
    category: '전기',
    name: '전동기 슬립',
    description: '동기속도보다 실제 회전수가 얼마나 뒤처지는지(비율)입니다. 유도전동기는 슬립이 있어야 토크가 납니다.',
    formulaText: 's = (Ns − N) / Ns',
    inputs: const [
      FormulaVar(
        key: 'ns',
        label: '동기속도 (Ns)',
        unit: 'rpm',
        hint: '위 "전동기 동기속도" 공식으로 구한 값입니다.',
      ),
      FormulaVar(
        key: 'n',
        label: '실제 회전수 (N)',
        unit: 'rpm',
        hint: '명판·측정으로 나온 실제(정격) 회전수입니다.',
      ),
    ],
    resultLabel: '슬립',
    resultUnit: '',
    compute: (v) => (v['ns']! - v['n']!) / v['ns']!,
  ),
  FormulaDef(
    id: 'motor_torque',
    category: '전기',
    name: '전동기 토크(출력·회전수로)',
    description: '전동기 출력과 회전수로 축 토크를 구합니다. 9549는 60/(2π)를 kW·rpm 단위에 맞춘 상수입니다.',
    formulaText: 'T = 9549 × P(kW) / N(rpm)',
    inputs: const [
      FormulaVar(
        key: 'p',
        label: '출력 (P)',
        unit: 'kW',
        hint: '전동기 축 출력입니다(명판 kW).',
      ),
      FormulaVar(
        key: 'n',
        label: '회전수 (N)',
        unit: 'rpm',
        hint: '',
      ),
    ],
    resultLabel: '토크',
    resultUnit: 'N·m',
    compute: (v) => 9549 * v['p']! / v['n']!,
  ),
  FormulaDef(
    id: 'joule_heat',
    category: '전기',
    name: '줄열(발열량)',
    description: '전류가 저항을 흐를 때 나는 열량입니다(줄의 법칙). 전선·차단기 발열, 히터 용량 계산에 씁니다.',
    formulaText: 'H = I² × R × t',
    inputs: const [
      _i,
      _r,
      FormulaVar(
        key: 't',
        label: '시간 (t)',
        unit: 's',
        hint: '전류가 흐른 시간입니다(초).',
      ),
    ],
    resultLabel: '열량',
    resultUnit: 'J',
    compute: (v) => v['i']! * v['i']! * v['r']! * v['t']!,
  ),

  // ─────────────── 유공압 ───────────────
  FormulaDef(
    id: 'pascal_pressure',
    category: '유공압',
    name: '파스칼의 원리(압력)',
    description: '밀폐된 유체에 가한 압력은 모든 방향에 그대로 전달됩니다. 힘과 단면적으로 압력을 구합니다.',
    formulaText: 'P = F / A',
    inputs: const [
      FormulaVar(
        key: 'f',
        label: '힘 (F)',
        unit: 'N',
        hint: '',
      ),
      FormulaVar(
        key: 'a',
        label: '단면적 (A)',
        unit: 'm²',
        hint: '',
      ),
    ],
    resultLabel: '압력',
    resultUnit: 'Pa',
    compute: (v) => v['f']! / v['a']!,
  ),
  FormulaDef(
    id: 'cylinder_force',
    category: '유공압',
    name: '유압·공압 실린더 힘',
    description: '실린더에 걸리는 압력과 피스톤 단면적으로 실린더가 내는 힘을 구합니다.',
    formulaText: 'F = P × A',
    inputs: const [
      FormulaVar(
        key: 'p',
        label: '압력 (P)',
        unit: 'Pa',
        hint: '실린더에 걸리는 압력입니다(bar면 ×100000 해서 Pa로 넣으십시오).',
      ),
      FormulaVar(
        key: 'a',
        label: '피스톤 단면적 (A)',
        unit: 'm²',
        hint: '피스톤(실린더 내경 기준) 단면적입니다(π×D²/4).',
      ),
    ],
    resultLabel: '힘',
    resultUnit: 'N',
    compute: (v) => v['p']! * v['a']!,
  ),
  FormulaDef(
    id: 'cylinder_speed',
    category: '유공압',
    name: '유압 실린더 속도',
    description: '펌프가 보내는 유량과 피스톤 단면적으로 실린더가 움직이는 속도를 구합니다.',
    formulaText: 'v = Q / A',
    inputs: const [
      FormulaVar(
        key: 'q',
        label: '유량 (Q)',
        unit: 'm³/s',
        hint: '펌프가 실린더로 보내는 유량입니다(L/min이면 ÷60000 해서 넣으십시오).',
      ),
      FormulaVar(
        key: 'a',
        label: '피스톤 단면적 (A)',
        unit: 'm²',
        hint: '피스톤 단면적입니다(π×D²/4).',
      ),
    ],
    resultLabel: '속도',
    resultUnit: 'm/s',
    compute: (v) => v['q']! / v['a']!,
  ),
  FormulaDef(
    id: 'hydraulic_power',
    category: '유공압',
    name: '유압 동력',
    description: '유압 시스템이 내는 동력입니다(압력×유량). 유압 펌프·모터 용량 어림에 씁니다.',
    formulaText: 'Power = P × Q',
    inputs: const [
      FormulaVar(
        key: 'p',
        label: '압력 (P)',
        unit: 'Pa',
        hint: '작동 압력입니다(bar면 ×100000 해서 넣으십시오).',
      ),
      FormulaVar(
        key: 'q',
        label: '유량 (Q)',
        unit: 'm³/s',
        hint: '유압유 유량입니다(L/min이면 ÷60000 해서 넣으십시오).',
      ),
    ],
    resultLabel: '동력',
    resultUnit: 'W',
    compute: (v) => v['p']! * v['q']!,
  ),
  FormulaDef(
    id: 'boyle_pressure',
    category: '유공압',
    name: '보일의 법칙(압력 구하기)',
    description: '온도가 같을 때 기체의 압력과 부피는 반비례합니다(공기 압축·에어탱크 계산에 씁니다).',
    formulaText: 'P2 = P1 × V1 / V2',
    inputs: const [
      FormulaVar(
        key: 'p1',
        label: '처음 압력 (P1)',
        unit: 'Pa',
        hint: '처음 상태의 절대압력입니다.',
      ),
      FormulaVar(
        key: 'v1',
        label: '처음 부피 (V1)',
        unit: 'm³',
        hint: '',
      ),
      FormulaVar(
        key: 'v2',
        label: '나중 부피 (V2)',
        unit: 'm³',
        hint: '',
      ),
    ],
    resultLabel: '나중 압력',
    resultUnit: 'Pa',
    compute: (v) => v['p1']! * v['v1']! / v['v2']!,
  ),
  FormulaDef(
    id: 'boyle_volume',
    category: '유공압',
    name: '보일의 법칙(부피 구하기)',
    description: '온도가 같을 때 기체의 압력과 부피는 반비례합니다. 압력이 바뀐 뒤 부피를 구합니다.',
    formulaText: 'V2 = P1 × V1 / P2',
    inputs: const [
      FormulaVar(
        key: 'p1',
        label: '처음 압력 (P1)',
        unit: 'Pa',
        hint: '처음 상태의 절대압력입니다.',
      ),
      FormulaVar(
        key: 'v1',
        label: '처음 부피 (V1)',
        unit: 'm³',
        hint: '',
      ),
      FormulaVar(
        key: 'p2',
        label: '나중 압력 (P2)',
        unit: 'Pa',
        hint: '압축·팽창 후 절대압력입니다.',
      ),
    ],
    resultLabel: '나중 부피',
    resultUnit: 'm³',
    compute: (v) => v['p1']! * v['v1']! / v['p2']!,
  ),
  FormulaDef(
    id: 'gauge_to_absolute',
    category: '유공압',
    name: '게이지압 → 절대압',
    description: '압력계가 보여주는 게이지압에 대기압을 더하면 절대압이 됩니다. 보일의 법칙 등은 절대압을 씁니다.',
    formulaText: 'Pabs = Pgauge + Patm',
    inputs: const [
      FormulaVar(
        key: 'pg',
        label: '게이지압 (Pgauge)',
        unit: 'Pa',
        hint: '압력계에 보이는 값입니다(bar면 ×100000 해서 넣으십시오).',
      ),
      FormulaVar(
        key: 'patm',
        label: '대기압 (Patm)',
        unit: 'Pa',
        hint: '모르면 표준대기압 101325를 넣으십시오.',
      ),
    ],
    resultLabel: '절대압',
    resultUnit: 'Pa',
    compute: (v) => v['pg']! + v['patm']!,
  ),
];
