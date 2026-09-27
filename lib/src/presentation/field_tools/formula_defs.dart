// 공식 계산(화면 없음): 전기·유량 공식 모음. 공식 하나마다 "무엇을 구하는지"를 하나로
// 고정해 두어(옴의 법칙도 전압·전류·저항 셋을 따로 둔다), 칸마다 무슨 값을 넣어야 하는지
// 이름·단위·도움말로 알려준다. 값은 모두 SI 단위(볼트·암페어·옴·와트·미터·초 등)로 받는다.
//
// 근거: 옴의 법칙·전력 공식·리액턴스·공진 주파수는 전기 기초 공식(교과서 수준, 유도 과정
// docs 없음 — 상수 없는 정의식이라 원문 대조가 필요 없다). 레이놀즈수·연속방정식·수두압은
// 유체역학 기초 공식. 3상 전력의 √3은 평형 3상 선간전압 기준(역률 각 θ는 부하 역률각).
library;

import 'dart:math' as math;

class FormulaVar {
  final String key;
  final String label; // "전류 (I)"
  final String unit; // "A"
  final String hint; // 이 칸에 뭘 넣는지
  const FormulaVar({
    required this.key,
    required this.label,
    required this.unit,
    required this.hint,
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
  hint: '도체에 흐르는 전류입니다.',
);
const _r = FormulaVar(
  key: 'r',
  label: '저항 (R)',
  unit: 'Ω',
  hint: '도체·부하의 저항입니다.',
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
    name: '옴의 법칙 — 전압 구하기',
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
    name: '옴의 법칙 — 전류 구하기',
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
    name: '옴의 법칙 — 저항 구하기',
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
    name: '전력 — 전압·전류로',
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
    name: '전력 — 전류·저항으로',
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
    name: '전력 — 전압·저항으로',
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
    description: '평형 3상 부하의 전력입니다. 역률각은 전류·전압 사이 위상각(cosθ)입니다.',
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
    name: '연속방정식 — 유량 구하기',
    description: '관 단면적과 유속을 알 때 유량을 구합니다.',
    formulaText: 'Q = A × V',
    inputs: const [
      FormulaVar(
        key: 'a',
        label: '단면적 (A)',
        unit: 'm²',
        hint: '관 안지름의 단면적입니다(원관이면 π×D²/4).',
      ),
      FormulaVar(
        key: 'vel',
        label: '유속 (V)',
        unit: 'm/s',
        hint: '유체가 흐르는 속도입니다.',
      ),
    ],
    resultLabel: '유량',
    resultUnit: 'm³/s',
    compute: (v) => v['a']! * v['vel']!,
  ),
  FormulaDef(
    id: 'flow_v_from_d',
    category: '유량',
    name: '관 유속(안지름으로)',
    description: '원형 관의 안지름과 유량을 알 때 유속을 구합니다.',
    formulaText: 'V = Q / (π × D²/4)',
    inputs: const [
      FormulaVar(
        key: 'q',
        label: '유량 (Q)',
        unit: 'm³/s',
        hint: '단위시간당 흐르는 부피입니다.',
      ),
      FormulaVar(
        key: 'd',
        label: '안지름 (D)',
        unit: 'm',
        hint: '관 안지름입니다(mm면 0.001을 곱해 넣으십시오).',
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
        hint: '유체가 흐르는 속도입니다.',
      ),
      FormulaVar(key: 'd', label: '안지름 (D)', unit: 'm', hint: '관 안지름입니다.'),
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
      FormulaVar(key: 'h', label: '높이 (h)', unit: 'm', hint: '액체 기둥의 높이입니다.'),
    ],
    resultLabel: '압력',
    resultUnit: 'Pa',
    compute: (v) => v['rho']! * 9.80665 * v['h']!,
  ),
];
