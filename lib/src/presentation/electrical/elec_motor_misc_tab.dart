// 전동기·발전기 계산: 전동기 구동·효율 탭. 권선 온도 상승, 효율 절감·회수, 감속기·벨트, 권상·컨베이어 동력, 소프트스타터,
// 제동 에너지, 직류 전동기. 계산은 motor_misc.dart. 모두 정의식이고 값(마찰계수·효율·전압 등)은 사용자가 넣는다.
import 'package:flutter/material.dart';

import '../../core/common_widgets/recent_calc_history.dart';
import '../common/calc_form_parts.dart';
import 'elec_form_parts.dart';
import 'motor_misc.dart';
import 'motor_tables.dart';

enum _Sec { temp, insul, energy, gear, load, soft, brake, dc }

String _secName(_Sec s) => switch (s) {
  _Sec.temp => '권선 온도',
  _Sec.insul => '절연 등급',
  _Sec.energy => '효율 절감',
  _Sec.gear => '감속기·벨트',
  _Sec.load => '권상·컨베이어',
  _Sec.soft => '소프트스타터',
  _Sec.brake => '제동 에너지',
  _Sec.dc => '직류 전동기',
};

typedef _Out = (List<Widget>, String?, List<String>, bool);

class ElecMotorMiscTab extends StatefulWidget {
  const ElecMotorMiscTab({super.key, this.history});

  /// "최근 계산 기록"을 다른 탭과 함께 쓸 때 밖에서 만든 기록을 넣는다.
  final RecentCalcLog? history;

  @override
  State<ElecMotorMiscTab> createState() => _ElecMotorMiscTabState();
}

class _ElecMotorMiscTabState extends State<ElecMotorMiscTab>
    with
        CalcFormParts<ElecMotorMiscTab>,
        RecentCalcHistoryMixin<ElecMotorMiscTab>,
        ElecTabParts<ElecMotorMiscTab>,
        AutomaticKeepAliveClientMixin<ElecMotorMiscTab> {
  @override
  RecentCalcLog get calcLog => widget.history ?? super.calcLog;

  @override
  bool get wantKeepAlive => true;

  _Sec _sec = _Sec.temp;

  // 권선 온도
  final _r1 = TextEditingController();
  final _t1 = TextEditingController(text: '20');
  final _r2 = TextEditingController();
  final _t2 = TextEditingController(text: '30');
  bool _al = false;

  // 절연 등급
  String _cls = 'F';
  final _irise = TextEditingController();
  final _iamb = TextEditingController(text: '40');

  // 효율 절감
  final _ekw = TextEditingController();
  final _elf = TextEditingController(text: '75');
  final _ehours = TextEditingController();
  final _eold = TextEditingController();
  final _enew = TextEditingController();
  final _eprice = TextEditingController();
  final _eextra = TextEditingController();

  // 감속기·벨트
  final _gin = TextEditingController();
  final _gkw = TextEditingController();
  final _gratio = TextEditingController();
  final _gd1 = TextEditingController();
  final _gd2 = TextEditingController();
  final _geff = TextEditingController();

  // 권상·컨베이어
  bool _conv = false;
  final _lm = TextEditingController();
  final _lv = TextEditingController();
  final _lmu = TextEditingController();
  final _lang = TextEditingController(text: '0');
  final _leff = TextEditingController();

  // 소프트스타터
  final _sia = TextEditingController();
  final _smult = TextEditingController(text: '6');
  final _sv = TextEditingController();
  final _sload = TextEditingController();

  // 제동
  final _bj = TextEditingController();
  final _brpm1 = TextEditingController();
  final _brpm2 = TextEditingController(text: '0');
  final _bsec = TextEditingController();
  final _bvdc = TextEditingController();

  // 직류
  final _dv = TextEditingController();
  final _dia = TextEditingController();
  final _dra = TextEditingController();
  final _drpm = TextEditingController();

  /// 칸과 "최근 계산 기록" 입력 묶음의 키.
  List<(TextEditingController, String)> get _texts => [
    (_r1, 'r1'), (_t1, 't1'), (_r2, 'r2'), (_t2, 't2'),
    (_irise, 'irise'), (_iamb, 'iamb'),
    (_ekw, 'ekw'), (_elf, 'elf'), (_ehours, 'ehours'), (_eold, 'eold'),
    (_enew, 'enew'), (_eprice, 'eprice'), (_eextra, 'eextra'),
    (_gin, 'gin'), (_gkw, 'gkw'), (_gratio, 'gratio'), (_gd1, 'gd1'), (_gd2, 'gd2'), (_geff, 'geff'),
    (_lm, 'lm'), (_lv, 'lv'), (_lmu, 'lmu'), (_lang, 'lang'), (_leff, 'leff'),
    (_sia, 'sia'), (_smult, 'smult'), (_sv, 'sv'), (_sload, 'sload'),
    (_bj, 'bj'), (_brpm1, 'brpm1'), (_brpm2, 'brpm2'), (_bsec, 'bsec'), (_bvdc, 'bvdc'),
    (_dv, 'dv'), (_dia, 'dia'), (_dra, 'dra'), (_drpm, 'drpm'),
  ];

  List<TextEditingController> get _all => [for (final (c, _) in _texts) c];

  @override
  Map<String, Object?>? historySnapshot() => {
    'sec': _sec.name,
    for (final (c, k) in _texts) k: c.text,
    'al': _al,
    'cls': _cls,
    'conv': _conv,
  };

  @override
  void applyHistorySnapshot(Map<String, dynamic> m) {
    for (final (c, k) in _texts) {
      if (m[k] is String) c.text = m[k] as String;
    }
    _sec = _Sec.values.firstWhere((s) => s.name == m['sec'], orElse: () => _sec);
    if (m['al'] is bool) _al = m['al'] as bool;
    final cls = m['cls'];
    if (cls is String && insulationByName(cls) != null) _cls = cls;
    if (m['conv'] is bool) _conv = m['conv'] as bool;
  }

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  double? _ratio(TextEditingController c) {
    final v = readNum(c);
    if (v == null) return null;
    return v > 1 ? v / 100 : v;
  }

  // ─────────────── 권선 온도 ───────────────

  _Out _temp() {
    final r1 = readNum(_r1), t1 = readNum(_t1), r2 = readNum(_r2), t2 = readNum(_t2);
    final r = (r1 != null && t1 != null && r2 != null && t2 != null)
        ? windingTempRise(r1: r1, t1: t1, r2: r2, t2: t2, aluminum: _al)
        : null;
    final k = windingK(_al);
    final lines = <String>[];
    String? summary;
    if (r != null) {
      lines.addAll([
        '① 권선 온도 T = (R2 ÷ R1) × (k + T1) − k = (${fmt(r2!, 4)} ÷ ${fmt(r1!, 4)}) × (${fmt(k, 1)} + ${fmt(t1!, 1)}) − ${fmt(k, 1)} = ${fmt(r.hotTempC, 1)} ℃',
        '② 온도 상승 ΔT = T − 주위 온도 = ${fmt(r.hotTempC, 1)} − ${fmt(t2!, 1)} = ${fmt(r.riseK, 1)} K',
        '저항은 정지한 직후 가능한 한 빨리 재야 합니다. 시간이 지나면 식어서 실제보다 낮게 나옵니다. 차가울 때 저항과 그때 온도(주위와 같아질 때까지 둔 상태)는 같은 단자 사이에서 재십시오.',
        '상수 k = ${fmt(k, 1)}(${_al ? '알루미늄' : '구리'} 권선, 저항법, IEEE 112 원문). IEC 60034-1은 구리 235·알루미늄 225를 써서 구리는 0.5 K 안팎 차이가 납니다. 절연 등급 한계와 비교하려면 "절연 등급" 묶음을 쓰십시오.',
      ]);
      summary = '온도 상승 ${fmt(r.riseK, 1)} K · 권선 ${fmt(r.hotTempC, 1)} ℃';
    }
    return (
      [
        elecChipGroup('권선 재질', '대부분의 전동기는 구리입니다.', [
          calcChip('mm_cu', '구리 (234.5)', !_al, () => setState(() => _al = false)),
          calcChip('mm_al', '알루미늄 (225)', _al, () => setState(() => _al = true)),
        ]),
        elecField('mm_r1', '차가울 때 저항 R1 (Ω)', _r1, '전동기가 주위 온도와 같아진 상태에서 잰 권선 저항입니다(한 상 또는 단자 사이).'),
        elecField('mm_t1', '그때 온도 T1 (℃)', _t1, 'R1을 잴 때의 권선(= 주위) 온도입니다.'),
        elecField('mm_r2', '운전 직후 저항 R2 (Ω)', _r2, '정격 부하로 충분히 돌린 직후 같은 단자에서 잰 저항입니다.'),
        elecField('mm_t2', '운전 중 주위 온도 T2 (℃)', _t2, '운전할 때의 주위 공기 온도입니다.'),
      ],
      summary,
      lines.isEmpty ? const ['R1·T1·R2·T2를 모두 넣으십시오.'] : lines,
      false,
    );
  }

  // ─────────────── 절연 등급 ───────────────

  _Out _insul() {
    final cls = insulationByName(_cls)!;
    final rise = readNum(_irise), amb = readNum(_iamb);
    final r = (rise != null && amb != null) ? insulationCheck(cls: cls, riseK: rise, ambientC: amb) : null;
    final lines = <String>[
      '등급 ${cls.name}: 최고 연속 사용 온도 ${fmt(cls.maxC, 0)} ℃(IEC 60085 표 1)${cls.riseK == null ? '' : ', 저항법 온도 상승 한계 ${fmt(cls.riseK!, 0)} K(IEC 60034-1:2010 표 7, 주위 40 ℃·해발 1000 m 이하)'}',
      if (cls.riseKSmall != null)
        '600 W 미만 기계와 팬 없는 자냉식(IC40)·봉입 권선 기계는 한계가 ${fmt(cls.riseKSmall!, 0)} K입니다(같은 표 항목 1d·1e). 아래 비교는 일반 기계 값 ${fmt(cls.riseK!, 0)} K로 합니다.',
      if (cls.note.isNotEmpty) cls.note,
    ];
    String? summary;
    var warn = false;
    if (r != null) {
      lines.addAll([
        '① 권선 온도 = 주위 + 온도 상승 = ${fmt(amb!, 1)} + ${fmt(rise!, 1)} = ${fmt(r.hotTempC, 1)} ℃',
        '② 등급 온도와의 차 = ${fmt(cls.maxC, 0)} − ${fmt(r.hotTempC, 1)} = ${fmt(r.marginK, 1)} K${r.marginK < 0 ? ' (등급 온도를 넘었습니다)' : ''}',
        if (r.riseMarginK != null)
          '③ 온도 상승 한계와의 차 = ${fmt(cls.riseK!, 0)} − ${fmt(rise, 1)} = ${fmt(r.riseMarginK!, 1)} K${r.riseMarginK! < 0 ? ' (한계 초과)' : ''}',
        '④ 수명 경험칙(10 ℃ 반감): 등급 온도에서의 수명을 1로 볼 때 ${fmt(r.lifeFactor, 2)}배입니다. 10 ℃ 오르면 절반, 내리면 2배가 되는 근사이고 절연 재료마다 실제는 다릅니다. 등급 온도에서의 기대 수명은 한 자료가 약 20,000시간이라 합니다.',
        '한국 제조사 자료 가운데 "F종 절연(B종 온도 상승) 설계"라고 적은 곳이 있습니다(한 곳). 그러면 한계는 B종 80 K이고 절연은 F종이라 여유가 있습니다. 명판·카탈로그의 표시를 확인하십시오.',
      ]);
      summary = '권선 ${fmt(r.hotTempC, 0)} ℃ · 등급 여유 ${fmt(r.marginK, 0)} K';
      warn = r.marginK < 0 || (r.riseMarginK != null && r.riseMarginK! < 0);
    }
    return (
      [
        elecChipGroup('절연 등급', '전동기 명판의 INS.CL(절연 등급)입니다. 기본은 F입니다. A·E급은 IEC 60034-1:2010 온도 상승 표(표 7)에 없어 넣지 않았습니다.', [
          for (final c in kInsulation)
            calcChip('mm_cls_${c.name}', c.name, _cls == c.name, () => setState(() => _cls = c.name)),
        ]),
        elecField('mm_irise', '온도 상승 (K, 선택)', _irise, '권선 온도 묶음의 결과(저항법)나 측정한 온도 상승입니다. 넣으면 등급과 비교합니다.'),
        elecField('mm_iamb', '주위 온도 (℃)', _iamb, '운전할 때 주위 공기 온도입니다. 규격 기준은 40 ℃입니다.'),
      ],
      summary,
      lines,
      warn,
    );
  }

  // ─────────────── 효율 절감 ───────────────

  _Out _energy() {
    final kw = readNum(_ekw), lf = _ratio(_elf), h = readNum(_ehours);
    final eo = _ratio(_eold), en = _ratio(_enew), price = readNum(_eprice);
    final extra = readNum(_eextra);
    final r = (kw != null && lf != null && h != null && eo != null && en != null && price != null)
        ? energySaving(kw: kw, loadFactor: lf, hours: h, effOld: eo, effNew: en, price: price, extraCost: extra)
        : null;
    final lines = <String>[];
    String? summary;
    if (r != null) {
      lines.addAll([
        '① 연간 소비 전력량 = P × 부하율 × 시간 ÷ 효율: 지금 ${fmt(kw!, 2)} × ${fmt(lf!, 2)} × ${fmt(h!, 0)} ÷ ${fmt(eo!, 3)} = ${fmt(r.kwhOld, 0)} kWh, 바꾼 뒤 ÷ ${fmt(en!, 3)} = ${fmt(r.kwhNew, 0)} kWh',
        '② 연간 절감 = ${fmt(r.kwhOld, 0)} − ${fmt(r.kwhNew, 0)} = ${fmt(r.savedKwh, 0)} kWh → ${fmt(r.savedMoney, 0)} 원 (단가 ${fmt(price!, 1)} 원/kWh)',
        if (r.paybackYears != null)
          '③ 투자 회수 기간 = 추가 비용 ÷ 연간 절감액 = ${fmt(extra!, 0)} ÷ ${fmt(r.savedMoney, 0)} = ${fmt(r.paybackYears!, 2)} 년'
        else if (extra != null)
          '③ 절감액이 없거나 0 이하라 회수 기간을 구하지 않았습니다.',
        '효율은 부분 부하에서 정격 효율과 다릅니다. 부하율이 낮을 때의 효율을 알면 그 값을 넣으십시오. 단가는 계약 종별과 시간대에 따라 다릅니다.',
      ]);
      summary = '연 ${fmt(r.savedKwh, 0)} kWh · ${fmt(r.savedMoney, 0)} 원 절감';
    }
    return (
      [
        elecField('mm_ekw', '축 출력 P (kW)', _ekw, '전동기 정격 출력입니다.'),
        elecField('mm_elf', '평균 부하율 (%)', _elf, '평균 운전 출력이 정격의 몇 %인지입니다. 75 또는 0.75처럼 넣으십시오.'),
        elecField('mm_ehours', '연간 운전 시간 (h)', _ehours, '1년 동안 실제로 돌리는 시간입니다. 24시간 연속은 8760입니다.'),
        elecField('mm_eold', '지금 효율 (%)', _eold, '현재 전동기의 효율(해당 부하율에서)입니다.'),
        elecField('mm_enew', '바꾼 뒤 효율 (%)', _enew, '교체할 전동기의 효율입니다.'),
        elecField('mm_eprice', '전력 단가 (원/kWh)', _eprice, '평균 전기요금 단가입니다. 계약 종별에 따라 다릅니다.'),
        elecField('mm_eextra', '추가 비용 (원, 선택)', _eextra, '효율이 높은 전동기로 바꾸는 데 더 드는 비용입니다. 넣으면 회수 기간을 구합니다.'),
      ],
      summary,
      lines.isEmpty ? const ['출력·부하율·시간·두 효율·단가를 넣으십시오.'] : lines,
      false,
    );
  }

  // ─────────────── 감속기·벨트 ───────────────

  _Out _gear() {
    final nin = readNum(_gin), kw = readNum(_gkw), eff = _ratio(_geff);
    final d1 = readNum(_gd1), d2 = readNum(_gd2);
    var ratio = readNum(_gratio);
    final fromD = ratio == null && d1 != null && d2 != null && d1 > 0 && d2 > 0;
    if (fromD) ratio = d2 / d1;
    final g = (nin != null && kw != null && ratio != null && eff != null)
        ? gearOut(inRpm: nin, inKw: kw, ratio: ratio, eff: eff)
        : null;
    final lines = <String>[];
    String? summary;
    if (g != null) {
      if (fromD) lines.add('① 감속비 i = 출력 풀리(기어) 지름 ÷ 입력 풀리 지름 = ${fmt(d2, 1)} ÷ ${fmt(d1, 1)} = ${fmt(g.ratio, 3)}');
      lines.addAll([
        '${fromD ? '②' : '①'} 출력 회전수 = 입력 ÷ i = ${fmt(nin!, 0)} ÷ ${fmt(g.ratio, 3)} = ${fmt(g.outRpm, 1)} rpm',
        '${fromD ? '③' : '②'} 출력 토크 = 입력 토크 × i × η = ${fmt(kw! * 1000 * 60 / (2 * 3.141592653589793 * nin), 1)} × ${fmt(g.ratio, 3)} × ${fmt(eff!, 3)} = ${fmt(g.outTorqueNm, 1)} N·m (${fmt(g.outTorqueNm / 9.80665, 1)} kgf·m)',
        '${fromD ? '④' : '③'} 출력 동력 = 입력 × η = ${fmt(kw, 2)} × ${fmt(eff, 3)} = ${fmt(g.outKw, 2)} kW',
        '감속비를 직접 넣으면 그 값을 쓰고, 비우면 풀리 지름(잇수)으로 구합니다. 벨트 미끄럼은 반영하지 않았습니다.',
      ]);
      summary = '출력 ${fmt(g.outRpm, 0)} rpm · ${fmt(g.outTorqueNm, 0)} N·m';
    }
    return (
      [
        elecField('mm_gin', '입력 회전수 (rpm)', _gin, '전동기 정격 회전수입니다.'),
        elecField('mm_gkw', '입력 동력 (kW)', _gkw, '전동기 축 출력입니다.'),
        elecField('mm_gratio', '감속비 i (선택)', _gratio, '감속기 명판의 감속비입니다. 10이면 입력이 10 회전할 때 출력이 1 회전합니다.'),
        elecField('mm_gd1', '입력 풀리 지름 (선택)', _gd1, '벨트나 기어로 구할 때. 단위는 자유입니다(잇수도 가능).'),
        elecField('mm_gd2', '출력 풀리 지름 (선택)', _gd2, '입력 풀리와 같은 단위로 넣으십시오.'),
        elecField('mm_geff', '전달 효율 (%)', _geff, '감속기·벨트 효율입니다. 95 또는 0.95처럼 넣으십시오(제조사 값).'),
      ],
      summary,
      lines.isEmpty ? const ['입력 회전수·동력·효율과 감속비(또는 풀리 지름)를 넣으십시오.'] : lines,
      false,
    );
  }

  // ─────────────── 권상·컨베이어 ───────────────

  _Out _load() {
    final m = readNum(_lm), v = readNum(_lv), eff = _ratio(_leff);
    final mu = readNum(_lmu), ang = readNum(_lang);
    final p = (m != null && v != null && eff != null)
        ? (_conv
              ? (mu != null && ang != null
                    ? conveyorPowerKw(massKg: m, speed: v, mu: mu, angleDeg: ang, eff: eff)
                    : null)
              : hoistPowerKw(massKg: m, speed: v, eff: eff))
        : null;
    final lines = <String>[];
    String? summary;
    if (p != null) {
      if (_conv) {
        lines.addAll([
          '① 구동력 F = m × g × (μ × cosθ + sinθ) = ${fmt(m!, 0)} × 9.807 × (${fmt(mu!, 3)} × cos ${fmt(ang!, 1)}° + sin ${fmt(ang, 1)}°) = ${fmt(p * 1000 * eff! / v!, 0)} N',
          '② 소요 동력 P = F × v ÷ (1000 × η) = ${fmt(p * 1000 * eff * 1, 0)} ÷ 1000 ÷ ${fmt(eff, 3)} = ${fmt(p, 2)} kW',
          'μ(마찰·주행 저항 계수)는 컨베이어 종류와 롤러 상태에 따라 다릅니다. 제조사·설계 기준의 값을 넣으십시오. 가속·벨트 자체 질량은 반영하지 않았습니다.',
        ]);
      } else {
        lines.addAll([
          '① 권상 동력 P = m × g × v ÷ (1000 × η) = ${fmt(m!, 0)} × 9.807 × ${fmt(v!, 3)} ÷ (1000 × ${fmt(eff!, 3)}) = ${fmt(p, 2)} kW',
          '정속 상승 기준입니다. 가속할 때는 관성 동력이 더 필요하고, 카운터웨이트가 있으면 균형 질량을 뺀 값으로 계산하십시오.',
        ]);
      }
      summary = '소요 동력 ${fmt(p, 2)} kW';
    }
    return (
      [
        elecChipGroup('부하', '권상(올리기)은 중력만, 컨베이어는 마찰과 경사를 함께 봅니다.', [
          calcChip('mm_hoist', '권상', !_conv, () => setState(() => _conv = false)),
          calcChip('mm_conv', '컨베이어', _conv, () => setState(() => _conv = true)),
        ]),
        elecField('mm_lm', _conv ? '이동 질량 m (kg)' : '들어 올리는 질량 m (kg)', _lm, _conv ? '벨트 위에서 움직이는 화물 질량입니다(벨트·롤러 질량은 별도).' : '훅과 화물을 합친 질량입니다.'),
        elecField('mm_lv', '속도 v (m/s)', _lv, '정속 속도입니다. m/min이면 ÷ 60 해서 넣으십시오.'),
        if (_conv) ...[
          elecField('mm_lmu', '마찰(주행 저항) 계수 μ', _lmu, '설계 기준·제조사 값입니다.'),
          elecField('mm_lang', '경사각 (°)', _lang, '수평이면 0입니다.'),
        ],
        elecField('mm_leff', '전달 효율 (%)', _leff, '감속기·체인 등의 총 효율입니다. 85 또는 0.85처럼 넣으십시오.'),
      ],
      summary,
      lines.isEmpty ? const ['질량·속도·효율(컨베이어는 μ·경사도)을 넣으십시오.'] : lines,
      false,
    );
  }

  // ─────────────── 소프트스타터 ───────────────

  _Out _soft() {
    final ia = readNum(_sia), m = readNum(_smult), v = _ratio(_sv), load = _ratio(_sload);
    final r = (ia != null && m != null && v != null) ? softStart(ratedAmps: ia, multiple: m, voltageRatio: v) : null;
    final lines = <String>[];
    String? summary;
    var warn = false;
    if (r != null) {
      lines.addAll([
        '① 기동 전류 = 정격전류 × 기동 배수 × 전압비 = ${fmt(ia!, 1)} × ${fmt(m!, 1)} × ${fmt(v!, 2)} = ${fmt(r.motorAmps, 1)} A (직입 ${fmt(ia * m, 1)} A의 ${fmt(v * 100, 0)} %)',
        '② 기동 토크 = 직입 기동 토크 × 전압비² = ${fmt(v, 2)}² = ${fmt(r.torqueRatio, 3)}배 (직입의 ${fmt(r.torqueRatio * 100, 0)} %)',
      ]);
      if (load != null) {
        lines.add(
          '③ 부하가 기동할 때 필요로 하는 토크가 정격 토크의 ${fmt(load * 100, 0)} %입니다. 직입 기동 토크(정격의 몇 배인지는 명판·제조사 값)에 ${fmt(r.torqueRatio, 3)}를 곱한 값이 그보다 커야 기동합니다.',
        );
      }
      lines.add('전류 제한(보통 정격의 300~400 %)과 램프 시간은 제조사 설정 범위이고 부하의 기계적 가속 시간에 맞춥니다. 전압이 낮을수록 토크가 급히 줄어 기동하지 못할 수 있습니다.');
      summary = '기동 전류 ${fmt(r.motorAmps, 1)} A · 토크 ${fmt(r.torqueRatio * 100, 0)} %';
    } else if (ia != null && m != null && v != null) {
      lines.add('시작 전압은 0보다 크고 100 % 이하로 넣으십시오.');
      warn = true;
    }
    return (
      [
        elecField('mm_sia', '정격전류 (A)', _sia, '전동기 명판의 정격전류입니다.'),
        elecField('mm_smult', '직입 기동 배수', _smult, '직입 기동전류가 정격전류의 몇 배인지입니다. 명판·제조사 값을 넣으십시오.'),
        elecField('mm_sv', '시작 전압 (%)', _sv, '소프트스타터가 처음 걸어 주는 전압이 정격전압의 몇 %인지입니다. 40 또는 0.4처럼 넣으십시오.'),
        elecField('mm_sload', '기동 때 부하 토크 (정격 토크의 %, 선택)', _sload, '기동 순간 부하가 필요로 하는 토크입니다. 펌프·팬은 작고, 컨베이어·압축기는 큽니다.'),
      ],
      summary,
      lines.isEmpty ? const ['정격전류·기동 배수·시작 전압을 넣으십시오.'] : lines,
      warn,
    );
  }

  // ─────────────── 제동 에너지 ───────────────

  _Out _brake() {
    final j = readNum(_bj), r1 = readNum(_brpm1), r2 = readNum(_brpm2), s = readNum(_bsec), vdc = readNum(_bvdc);
    final b = (j != null && r1 != null && r2 != null && s != null)
        ? brakeEnergy(j: j, rpm1: r1, rpm2: r2, seconds: s, vdc: vdc)
        : null;
    final lines = <String>[];
    String? summary;
    if (b != null) {
      lines.addAll([
        '① 줄어드는 운동 에너지 E = ½ × J × (ω1² − ω2²) = ½ × ${fmt(j!, 3)} × ((2π × ${fmt(r1!, 0)} ÷ 60)² − (2π × ${fmt(r2!, 0)} ÷ 60)²) = ${fmt(b.energyJ, 0)} J (${fmt(b.energyJ / 3600, 2)} Wh)',
        '② 평균 제동 전력 = E ÷ t = ${fmt(b.energyJ, 0)} ÷ ${fmt(s!, 1)} ÷ 1000 = ${fmt(b.avgKw, 2)} kW',
        '③ 일정 토크로 감속하면 시작 순간 제동 전력 = 평균 × 2 × N1 ÷ (N1 + N2) = ${fmt(b.avgKw, 2)} × 2 × ${fmt(r1, 0)} ÷ (${fmt(r1, 0)} + ${fmt(r2, 0)}) = ${fmt(b.peakKw, 2)} kW(0 rpm까지 세우면 평균의 2배)',
        if (b.maxOhm != null)
          '④ 제동 저항 상한 R ≤ V² ÷ P = ${fmt(vdc!, 0)}² ÷ ${fmt(b.peakKw * 1000, 0)} = ${fmt(b.maxOhm!, 1)} Ω',
        '마찰·부하 토크가 도와 주면 실제 회생 에너지는 이보다 작습니다. 저항의 최소 허용값과 연속 정격(와트)은 인버터 제조사 값을 따르십시오. 제동 개시 직류 전압은 인버터 설명서의 값입니다.',
      ]);
      summary = '제동 에너지 ${fmt(b.energyJ / 1000, 1)} kJ · 최대 ${fmt(b.peakKw, 1)} kW';
    }
    return (
      [
        elecField('mm_bj', '총 관성 J (kg·m²)', _bj, '전동기 축으로 환산한 전동기 + 부하 관성입니다(전동기 선정 탭의 가속 시간에서 구하는 값).'),
        elecField('mm_brpm1', '감속 전 회전수 (rpm)', _brpm1, '제동을 시작할 때 회전수입니다.'),
        elecField('mm_brpm2', '감속 후 회전수 (rpm)', _brpm2, '정지까지면 0입니다.'),
        elecField('mm_bsec', '감속 시간 (초)', _bsec, '인버터에 설정한 감속 시간이나 실제 정지 시간입니다.'),
        elecField('mm_bvdc', '제동 개시 직류 전압 (V, 선택)', _bvdc, '인버터가 제동 저항을 켜는 직류 전압입니다. 설명서의 값(예: 400 V급 약 700~800 V대)이며 넣으면 저항 상한을 구합니다.'),
      ],
      summary,
      lines.isEmpty ? const ['관성·감속 전후 회전수·감속 시간을 넣으십시오.'] : lines,
      false,
    );
  }

  // ─────────────── 직류 전동기 ───────────────

  _Out _dc() {
    final v = readNum(_dv), ia = readNum(_dia), ra = readNum(_dra), rpm = readNum(_drpm);
    final d = (v != null && ia != null && ra != null) ? dcMotor(volts: v, ia: ia, ra: ra, rpm: rpm) : null;
    final lines = <String>[];
    String? summary;
    var warn = false;
    if (d != null) {
      lines.addAll([
        '① 역기전력 Ea = V − Ia × Ra = ${fmt(v!, 1)} − ${fmt(ia!, 2)} × ${fmt(ra!, 3)} = ${fmt(d.backEmf, 1)} V',
        '② 전기자가 기계로 바꾸는 전력 P = Ea × Ia = ${fmt(d.backEmf, 1)} × ${fmt(ia, 2)} ÷ 1000 = ${fmt(d.devKw, 2)} kW',
        if (d.torqueNm != null)
          '③ 발생 토크 T = P ÷ ω = ${fmt(d.devKw * 1000, 0)} ÷ (2π × ${fmt(rpm!, 0)} ÷ 60) = ${fmt(d.torqueNm!, 2)} N·m',
        '④ 전기자 전류가 같은 동안 속도는 역기전력에 비례하고 자속에 반비례합니다(N ∝ Ea ÷ Φ). 계자를 약하게 하면 속도가 올라가고, 부하가 커져 Ia가 늘면 Ea가 줄어 속도가 조금 내려갑니다.',
        '전기자 전류 Ia와 저항 Ra는 전기자 회로 값입니다. 직권·분권 구분은 계자 접속에 따라 다르며 이 계산은 전기자 쪽 식입니다.',
      ]);
      summary = '역기전력 ${fmt(d.backEmf, 1)} V · ${fmt(d.devKw, 2)} kW';
    } else if (v != null && ia != null && ra != null) {
      lines.add('전기자 전압강하(Ia × Ra)가 단자 전압 이상입니다. 값을 확인하십시오.');
      warn = true;
    }
    return (
      [
        elecField('mm_dv', '단자 전압 V (V)', _dv, '전기자에 걸리는 직류 전압입니다.'),
        elecField('mm_dia', '전기자 전류 Ia (A)', _dia, '전기자(회전자) 회로 전류입니다.'),
        elecField('mm_dra', '전기자 저항 Ra (Ω)', _dra, '명판이나 측정한 전기자 저항입니다.'),
        elecField('mm_drpm', '회전수 (rpm, 선택)', _drpm, '넣으면 발생 토크를 구합니다.'),
      ],
      summary,
      lines.isEmpty ? const ['단자 전압·전기자 전류·저항을 넣으십시오.'] : lines,
      warn,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final (fields, summary, lines, warn) = switch (_sec) {
      _Sec.temp => _temp(),
      _Sec.insul => _insul(),
      _Sec.energy => _energy(),
      _Sec.gear => _gear(),
      _Sec.load => _load(),
      _Sec.soft => _soft(),
      _Sec.brake => _brake(),
      _Sec.dc => _dc(),
    };
    return elecPage(
      sumKey: 'mm_sum',
      summary: summary,
      warn: warn,
      [
        elecChipGroup('계산 항목', '전동기 용량·열·에너지·기동·제동을 따지는 식입니다.', [
          for (final s in _Sec.values)
            calcChip('mm_sec_${s.name}', _secName(s), _sec == s, () => setState(() => _sec = s)),
        ]),
        ...fields,
        const SizedBox(height: 6),
        calcResult(solve: true, 
          key: const Key('mm_result'),
          big: summary == null ? '-' : summary.split(' · ').first,
          caption: _secName(_sec),
          warn: warn,
          lines: lines,
        ),
        elecBasis('mm_basis', [
          '모두 정의식과 교재 일반식입니다. 표 값은 쓰지 않고, 효율·마찰계수·전압은 사용자가 넣습니다.',
          '권선 온도 T = (R2 ÷ R1)(k + T1) − k, k 구리 234.5·알루미늄 225(IEEE 112-2004 원문, IEC 60034-1은 구리 235). 절연 등급 온도는 IEC 60085 표 1 원문, 저항법 온도 상승 한계(B 80·F 105·H 125 K, 600 W 미만·IC40·봉입 권선은 85·110·130 K)는 IEC 60034-1:2010 표 7 원문입니다. A·E급은 그 표에 없어 뺐고, N급 한계는 확인하지 못했습니다.',
          '소프트스타터: 전동기 전류는 전압에 비례, 토크는 전압²에 비례. 전류 제한 300~400 %는 제조사 설정 범위의 관례입니다.',
          '제동 에너지 E = ½J(ω1² − ω2²). 일정 토크 감속이면 시작 순간 제동 전력은 평균 × 2N1 ÷ (N1 + N2)입니다(0 rpm까지 세우면 평균의 2배). 저항 허용값은 인버터 제조사 값을 따릅니다.',
          '직류 전동기: Ea = V − Ia·Ra, 발생 전력 Ea·Ia, 속도 N ∝ Ea ÷ Φ.',
          '기본 기동 배수 ${fmt(kMotorStartMultipleDefault, 0)}은 예시입니다(전동기 기동 전류 5~7배).',
        ]),
      ],
    );
  }
}
