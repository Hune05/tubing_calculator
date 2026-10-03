// 전기기기 계산: 전동기 선정 탭. 펌프·팬 소요 동력, 상사법칙(속도 변경), 가속(기동) 시간.
// 계산은 motor_formula.dart. 모두 정의식이고, 효율·여유율·토크는 사용자가 넣는다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/common_widgets/recent_calc_history.dart';
import '../common/calc_form_parts.dart';
import 'elec_form_parts.dart';
import 'motor_formula.dart';
import 'motor_tables.dart';

enum _Sec { power, affinity, accel }

String _secName(_Sec s) => switch (s) {
  _Sec.power => '펌프·팬 동력',
  _Sec.affinity => '속도 변경(상사법칙)',
  _Sec.accel => '가속 시간',
};

/// 표준 정격 목록(kW): 카탈로그(HD현대일렉트릭 IE3 4극) 정격 출력. 올림해서 고를 때 쓴다.
final List<double> _kRatings = [for (final r in kIe3Hd60Hz) r.kw];

class ElecMotorSelectTab extends StatefulWidget {
  const ElecMotorSelectTab({super.key, this.history});

  /// "최근 계산 기록"을 다른 탭과 함께 쓸 때 밖에서 만든 기록을 넣는다.
  final RecentCalcLog? history;

  @override
  State<ElecMotorSelectTab> createState() => _ElecMotorSelectTabState();
}

class _ElecMotorSelectTabState extends State<ElecMotorSelectTab>
    with
        CalcFormParts<ElecMotorSelectTab>,
        RecentCalcHistoryMixin<ElecMotorSelectTab>,
        ElecTabParts<ElecMotorSelectTab>,
        AutomaticKeepAliveClientMixin<ElecMotorSelectTab> {
  @override
  RecentCalcLog get calcLog => widget.history ?? super.calcLog;

  @override
  bool get wantKeepAlive => true;

  _Sec _sec = _Sec.power;

  // 펌프·팬 동력
  bool _fan = false;
  final _flow = TextEditingController();
  final _head = TextEditingController(); // 펌프 양정 m / 팬 압력 Pa
  final _density = TextEditingController(text: '1000');
  final _eff = TextEditingController();
  final _margin = TextEditingController();
  final _drive = TextEditingController(text: '100');

  // 상사법칙
  final _n1 = TextEditingController();
  final _n2 = TextEditingController();
  final _q1 = TextEditingController();
  final _h1 = TextEditingController();
  final _p1 = TextEditingController();

  // 가속 시간
  final _mkw = TextEditingController();
  final _mrpm = TextEditingController();
  final _avgMotorPct = TextEditingController();
  final _avgLoadPct = TextEditingController();
  bool _gd2 = false;
  final _jm = TextEditingController();
  final _jl = TextEditingController();
  final _lrpm = TextEditingController();

  List<TextEditingController> get _all => [
    _flow, _head, _density, _eff, _margin, _drive, _n1, _n2, _q1, _h1, _p1,
    _mkw, _mrpm, _avgMotorPct, _avgLoadPct, _jm, _jl, _lrpm,
  ];

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

  // ─────────────── 펌프·팬 동력 ───────────────

  (List<Widget>, String?, List<String>, bool) _power() {
    final q = readNum(_flow);
    final h = readNum(_head);
    final rho = readNum(_density);
    final eff = _ratio(_eff);
    final margin = (readNum(_margin) ?? 0) / 100;
    final drive = _ratio(_drive) ?? 1.0;
    final r = (q != null && h != null && eff != null)
        ? (_fan
              ? fanPower(flowM3h: q, pressurePa: h, fanEff: eff, margin: margin, driveEff: drive)
              : (rho == null
                    ? null
                    : pumpPower(
                        flowM3h: q,
                        headM: h,
                        density: rho,
                        pumpEff: eff,
                        margin: margin,
                        driveEff: drive,
                      )))
        : null;
    final lines = <String>[];
    String? summary;
    if (r != null) {
      final up = roundUpToList(r.motorKw, _kRatings);
      if (_fan) {
        lines.add('① 공기동력 = Q × Δp ÷ 1000 = (${fmt(q!, 1)} ÷ 3600) × ${fmt(h!, 0)} ÷ 1000 = ${fmt(r.hydraulicKw, 2)} kW');
      } else {
        lines.add('① 수동력 = ρ × g × Q × H ÷ 1000 = ${fmt(rho!, 0)} × 9.807 × (${fmt(q!, 1)} ÷ 3600) × ${fmt(h!, 1)} ÷ 1000 = ${fmt(r.hydraulicKw, 2)} kW');
      }
      lines.addAll([
        '② 축동력 = ${_fan ? '공기동력' : '수동력'} ÷ ${_fan ? '팬' : '펌프'} 효율 = ${fmt(r.hydraulicKw, 2)} ÷ ${fmt(eff!, 3)} = ${fmt(r.shaftKw, 2)} kW',
        '③ 전동기 소요 출력 = 축동력 × (1 + 여유율) ÷ 전달 효율 = ${fmt(r.shaftKw, 2)} × (1 + ${fmt(margin, 2)}) ÷ ${fmt(drive, 2)} = ${fmt(r.motorKw, 2)} kW',
        if (up != null)
          '④ 카탈로그 정격으로 올림: ${fmt(up, 2)} kW (HD현대일렉트릭 IE3 4극 정격 목록 기준, 제조사 표준품으로 확인하십시오)'
        else
          '④ 소요 출력이 ${fmt(_kRatings.last, 0)} kW를 넘어 목록에서 정하지 않았습니다. 제조사 표준품을 확인하십시오.',
        if (!_fan) '한국 간이식은 P[kW] = 0.163 × Q[m³/min] × H[m] × 비중 ÷ η입니다. 위 식과 같은 값입니다(0.163 = 9.807 ÷ 60).',
      ]);
      summary = '소요 출력 ${fmt(r.motorKw, 2)} kW${up == null ? '' : ' → ${fmt(up, 2)} kW'}';
    }
    return (
      [
        elecChipGroup('부하', '펌프는 양정으로, 팬·블로어는 압력으로 동력을 구합니다.', [
          calcChip('ms_pump', '펌프', !_fan, () => setState(() => _fan = false)),
          calcChip('ms_fan', '팬·블로어', _fan, () => setState(() => _fan = true)),
        ]),
        elecField('ms_flow', '유량 Q (m³/h)', _flow, '펌프·팬이 보내는 유량입니다. m³/min이면 × 60 해서 넣으십시오.'),
        if (!_fan)
          elecField('ms_head', '전양정 H (m)', _head, '펌프가 올려야 하는 전체 양정(실양정 + 배관 손실)입니다.')
        else
          elecField('ms_head', '압력 Δp (Pa)', _head, '팬이 내야 하는 전압(Pa)입니다. mmAq는 × 9.807 해서 Pa로 바꾸십시오.'),
        if (!_fan)
          elecField('ms_density', '밀도 ρ (kg/m³)', _density, '물은 1000입니다. 다른 액체는 비중 × 1000을 넣으십시오.'),
        elecField('ms_eff', _fan ? '팬 효율 (%)' : '펌프 효율 (%)', _eff, '제조사 성능 곡선이나 자료의 효율입니다. 70 또는 0.7처럼 넣으십시오.'),
        elecField('ms_margin', '여유율 (%, 선택)', _margin, '동력에 더하는 여유입니다. 설계 기준에 따라 넣으십시오(관례로 10~20 %를 쓰는 곳이 많습니다). 비우면 0입니다.'),
        elecField('ms_drive', '전달 효율 (%)', _drive, '직결이면 100, 벨트·감속기를 쓰면 그 효율입니다.'),
      ],
      summary,
      lines.isEmpty ? const ['유량·양정(또는 압력)·효율을 넣으십시오.'] : lines,
      false,
    );
  }

  // ─────────────── 상사법칙 ───────────────

  (List<Widget>, String?, List<String>, bool) _affinity() {
    final n1 = readNum(_n1);
    final n2 = readNum(_n2);
    final a = (n1 != null && n2 != null)
        ? affinity(n1: n1, n2: n2, q1: readNum(_q1), h1: readNum(_h1), p1: readNum(_p1))
        : null;
    final lines = <String>[];
    String? summary;
    if (a != null) {
      lines.add('① 속도비 r = N2 ÷ N1 = ${fmt(n2!, 1)} ÷ ${fmt(n1!, 1)} = ${fmt(a.ratio, 3)}');
      if (a.flow != null) lines.add('② 유량 Q2 = Q1 × r = ${fmt(readNum(_q1)!, 2)} × ${fmt(a.ratio, 3)} = ${fmt(a.flow!, 2)}');
      if (a.head != null) lines.add('③ 양정 H2 = H1 × r² = ${fmt(readNum(_h1)!, 2)} × ${fmt(a.ratio, 3)}² = ${fmt(a.head!, 2)}');
      if (a.power != null) lines.add('④ 동력 P2 = P1 × r³ = ${fmt(readNum(_p1)!, 2)} × ${fmt(a.ratio, 3)}³ = ${fmt(a.power!, 2)} (${fmt(math.pow(a.ratio, 3) * 100, 1)} %)');
      lines.add('원심 펌프·팬에서 배관 저항이 속도의 제곱으로 변하는 조건(정적 양정이 작을 때)의 근사식입니다. 정적 양정이 크면 양정·동력이 어긋납니다.');
      summary = '속도비 ${fmt(a.ratio, 3)} · 유량 ${fmt(a.ratio * 100, 1)} % · 동력 ${fmt(math.pow(a.ratio, 3) * 100, 1)} %';
    }
    return (
      [
        elecField('ms_n1', '기준 속도 N1 (rpm 또는 Hz)', _n1, '지금 운전 속도입니다. 인버터 주파수(Hz)로 넣어도 됩니다. 단위를 N2와 같게 하십시오.'),
        elecField('ms_n2', '바꿀 속도 N2', _n2, '바꾸려는 속도입니다. N1과 같은 단위로 넣으십시오.'),
        elecField('ms_q1', '기준 유량 Q1 (선택)', _q1, '단위는 자유입니다. 넣으면 같은 단위로 새 유량을 구합니다.'),
        elecField('ms_h1', '기준 양정·압력 H1 (선택)', _h1, '단위는 자유입니다.'),
        elecField('ms_p1', '기준 동력 P1 (kW, 선택)', _p1, '전동기 입력이나 축동력입니다. 넣으면 새 동력과 절감 비율을 구합니다.'),
      ],
      summary,
      lines.isEmpty ? const ['기준 속도와 바꿀 속도를 넣으십시오.'] : lines,
      false,
    );
  }

  // ─────────────── 가속 시간 ───────────────

  (List<Widget>, String?, List<String>, bool) _accel() {
    final kw = readNum(_mkw);
    final rpm = readNum(_mrpm);
    final mp = _pct(_avgMotorPct);
    final lp = _pct(_avgLoadPct);
    final jmIn = readNum(_jm);
    final jlIn = readNum(_jl);
    final lrpmIn = readNum(_lrpm);
    final lines = <String>[];
    String? summary;
    var warn = false;
    if (kw != null && rpm != null && mp != null && lp != null && jmIn != null) {
      final tr = kw * 1000 * 60 / (2 * math.pi * rpm);
      final jm = _gd2 ? gd2ToJ(jmIn) : jmIn;
      final jlRaw = jlIn == null ? 0.0 : (_gd2 ? gd2ToJ(jlIn) : jlIn);
      final lr = lrpmIn ?? rpm;
      final jl = reflectedInertia(jlRaw, lr, rpm);
      final total = jm + jl;
      final tMotor = tr * mp;
      final tLoad = tr * lp;
      final r = accelTime(totalJ: total, rpm: rpm, motorAvgNm: tMotor, loadAvgNm: tLoad);
      lines.addAll([
        '① 정격 토크 T = P × 1000 × 60 ÷ (2π × N) = ${fmt(kw, 2)} × 1000 × 60 ÷ (2π × ${fmt(rpm, 0)}) = ${fmt(tr, 1)} N·m',
        '② 총 관성 J = J전동기 + J부하 × (N부하 ÷ N전동기)² = ${fmt(jm, 3)} + ${fmt(jlRaw, 3)} × (${fmt(lr, 0)} ÷ ${fmt(rpm, 0)})² = ${fmt(total, 3)} kg·m²',
        '③ 평균 전동기 토크 = ${fmt(tr, 1)} × ${fmt(mp, 2)} = ${fmt(tMotor, 1)} N·m, 평균 부하 토크 = ${fmt(tr, 1)} × ${fmt(lp, 2)} = ${fmt(tLoad, 1)} N·m',
      ]);
      if (r == null) {
        lines.add('평균 가속 토크(전동기 − 부하)가 0 이하라 기동(가속)하지 못합니다. 더 큰 전동기나 기동 방식(감압 기동이 아닌 직입 등)을 검토하십시오.');
        warn = true;
        summary = '가속 토크 부족: 기동 불가';
      } else {
        lines.addAll([
          '④ 가속 토크 Ta = ${fmt(tMotor, 1)} − ${fmt(tLoad, 1)} = ${fmt(r.accelTorqueNm, 1)} N·m',
          '⑤ 가속 시간 t = J × ω ÷ Ta = ${fmt(total, 3)} × (2π × ${fmt(rpm, 0)} ÷ 60) ÷ ${fmt(r.accelTorqueNm, 1)} = ${fmt(r.seconds, 2)} 초',
          '기동 중 토크는 속도에 따라 변하므로 입력한 평균 토크의 정확도만큼만 맞습니다. 전동기 토크 곡선(제조사 자료)이 있으면 곡선의 평균값을 넣으십시오. 감압 기동이면 토크가 전압²에 비례해 줄어듭니다.',
        ]);
        summary = '가속 시간 ${fmt(r.seconds, 2)} 초';
      }
    }
    return (
      [
        elecField('ms_mkw', '전동기 정격 출력 (kW)', _mkw, '명판의 정격 출력입니다.'),
        elecField('ms_mrpm', '정격 회전수 (rpm)', _mrpm, '명판의 정격 회전수입니다.'),
        elecField('ms_avgm', '기동 중 평균 전동기 토크 (정격 토크의 %)', _avgMotorPct, '기동 구간에서 전동기가 내는 평균 토크가 정격 토크의 몇 %인지입니다. 제조사 토크 곡선의 평균값을 넣으십시오. 150 또는 1.5처럼 넣습니다.'),
        elecField('ms_avgl', '기동 중 평균 부하 토크 (정격 토크의 %)', _avgLoadPct, '부하가 요구하는 평균 토크가 정격 토크의 몇 %인지입니다. 펌프·팬은 속도 제곱에 비례해 올라가므로 평균은 정격보다 작습니다.'),
        elecChipGroup('관성 단위', 'J(kg·m²) 또는 GD²(kgf·m²)입니다. GD²는 J의 4배입니다(J = GD² ÷ 4).', [
          calcChip('ms_j', 'J (kg·m²)', !_gd2, () => setState(() => _gd2 = false)),
          calcChip('ms_gd2', 'GD² (kgf·m²)', _gd2, () => setState(() => _gd2 = true)),
        ]),
        elecField('ms_jm', '전동기 관성', _jm, '전동기 제조사 자료의 회전자 관성입니다.'),
        elecField('ms_jl', '부하 관성 (선택)', _jl, '펌프 임펠러·팬·커플링 등 부하 쪽 관성입니다. 비우면 0으로 봅니다.'),
        elecField('ms_lrpm', '부하 축 회전수 (rpm, 선택)', _lrpm, '감속기가 있어 부하 축 속도가 다르면 넣으십시오. 비우면 전동기와 같습니다.'),
      ],
      summary,
      lines.isEmpty ? const ['정격 출력·회전수·평균 토크·관성을 넣으십시오.'] : lines,
      warn,
    );
  }

  /// 정격 토크의 배수. 10 이상이면 %로 보고 100으로 나눈다(150 → 1.5), 그보다 작으면 배수 그대로.
  double? _pct(TextEditingController c) {
    final v = readNum(c);
    if (v == null || v < 0) return null;
    return v >= 10 ? v / 100 : v;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final (fields, summary, lines, warn) = switch (_sec) {
      _Sec.power => _power(),
      _Sec.affinity => _affinity(),
      _Sec.accel => _accel(),
    };
    return elecPage(
      sumKey: 'ms_sum',
      summary: summary,
      warn: warn,
      [
        elecChipGroup('계산 항목', '전동기 용량을 정하거나 속도·기동을 따지는 식입니다.', [
          for (final s in _Sec.values)
            calcChip('ms_sec_${s.name}', _secName(s), _sec == s, () => setState(() => _sec = s)),
        ]),
        ...fields,
        const SizedBox(height: 6),
        calcResult(
          key: const Key('ms_result'),
          big: summary == null ? '-' : summary.split(' · ').first.split(' → ').first,
          caption: _secName(_sec),
          warn: warn,
          lines: lines,
        ),
        elecBasis('ms_basis', const [
          '펌프 수동력 = ρ·g·Q·H, 팬 공기동력 = Q·Δp, 축동력 = 유체 동력 ÷ 효율. 모두 정의식입니다.',
          '상사법칙: 유량 ∝ N, 양정 ∝ N², 동력 ∝ N³.',
          '가속 시간 = J·ω ÷ (전동기 평균 토크 − 부하 평균 토크), ω = 2πN ÷ 60. 전동기 축으로 환산한 관성은 J부하 × (N부하 ÷ N전동기)².',
          '효율·여유율·평균 토크는 앱이 정하지 않습니다. 설계 기준과 제조사 자료의 값을 넣으십시오.',
        ]),
      ],
    );
  }
}
