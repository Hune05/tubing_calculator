// 전기기기 계산: 전동기 공식 탭. 속도·슬립, 전류·효율, 토크·출력, 기동 방식, 부하율 다섯 묶음.
// 계산은 motor_formula.dart. 모두 정의식·교재 일반식이고, 명판 값(효율·역률·정격전류)은 사용자가 넣는다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/common_widgets/recent_calc_history.dart';
import '../common/calc_form_parts.dart';
import 'elec_form_parts.dart';
import 'motor_capacitor.dart';
import 'motor_formula.dart';
import 'motor_tables.dart';

enum _Sec { speed, current, torque, maxTorque, start, load, flc }

/// 전류·전압·역률 중 구할 값.
enum _Solve { current, voltage, pf }

String _secName(_Sec s) => switch (s) {
  _Sec.speed => '속도·슬립',
  _Sec.current => '전류·효율',
  _Sec.torque => '토크·출력',
  _Sec.maxTorque => '최대 토크',
  _Sec.start => '기동 방식',
  _Sec.load => '부하율',
  _Sec.flc => '전부하 전류 표',
};

class ElecMotorFormulaTab extends StatefulWidget {
  const ElecMotorFormulaTab({super.key, this.history});

  /// "최근 계산 기록"을 다른 탭과 함께 쓸 때 밖에서 만든 기록을 넣는다.
  final RecentCalcLog? history;

  @override
  State<ElecMotorFormulaTab> createState() => _ElecMotorFormulaTabState();
}

class _ElecMotorFormulaTabState extends State<ElecMotorFormulaTab>
    with
        CalcFormParts<ElecMotorFormulaTab>,
        RecentCalcHistoryMixin<ElecMotorFormulaTab>,
        ElecTabParts<ElecMotorFormulaTab>,
        AutomaticKeepAliveClientMixin<ElecMotorFormulaTab> {
  @override
  RecentCalcLog get calcLog => widget.history ?? super.calcLog;

  @override
  bool get wantKeepAlive => true;

  _Sec _sec = _Sec.speed;

  // 속도·슬립
  final _hz = TextEditingController(text: '60');
  final _poles = TextEditingController(text: '4');
  final _rpm = TextEditingController();
  final _slipPct = TextEditingController();

  // 전류·전압·역률, 부하율이 같이 쓰는 값
  _Solve _solve = _Solve.current;
  bool _pIsInput = false; // kW가 입력 전력(전력계 값)이면 true, 아니면 축 출력
  final _amps = TextEditingController();
  final _kw = TextEditingController();
  final _volts = TextEditingController(text: '380');
  final _eff = TextEditingController();
  final _pf = TextEditingController();
  bool _three = true;

  // 토크·출력
  bool _torqueToPower = false;
  final _tkw = TextEditingController();
  final _trpm = TextEditingController();
  final _tnm = TextEditingController();

  // 최대 토크
  final _xkw = TextEditingController();
  final _xrpm = TextEditingController();
  final _xmult = TextEditingController();
  final _xvolt = TextEditingController();
  bool _xIec = true; // true IEC 60034-12 설계 N, false NEMA MG-1 설계 A·B
  int _xPoles = 4;

  // 기동 방식
  final _rated = TextEditingController();
  final _mult = TextEditingController(text: '6');
  StartKind _kind = StartKind.direct;
  final _tap = TextEditingController(text: '65');

  // 전부하 전류 표
  bool _flcNec = true;
  double _necHp = 10;
  double _ie3Kw = 11;

  // 부하율
  final _meas = TextEditingController();
  final _lrated = TextEditingController();
  final _lpf = TextEditingController();
  final _leff = TextEditingController();

  List<TextEditingController> get _all => [
    _hz, _poles, _rpm, _slipPct, _kw, _volts, _eff, _pf, _tkw, _trpm, _tnm,
    _rated, _mult, _tap, _meas, _lrated, _lpf, _leff, _amps,
    _xkw, _xrpm, _xmult, _xvolt,
  ];

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  /// 0~1 값. 1을 넘으면 %로 보고 100으로 나눈다(85 → 0.85).
  double? _ratio(TextEditingController c) {
    final v = readNum(c);
    if (v == null) return null;
    return v > 1 ? v / 100 : v;
  }

  // ─────────────── 묶음별 화면 ───────────────

  (List<Widget>, String?, List<String>, bool) _speed() {
    final hz = readNum(_hz);
    final pRaw = readNum(_poles);
    final poles = pRaw?.round();
    final ns = (hz != null && poles != null && pRaw == poles.toDouble())
        ? motorSyncRpm(hz, poles)
        : null;
    final rpm = readNum(_rpm);
    final slipIn = readNum(_slipPct);
    double? s;
    double? n;
    if (ns != null && rpm != null) {
      s = motorSlip(ns, rpm);
      n = rpm;
    } else if (ns != null && slipIn != null) {
      s = slipIn / 100;
      n = motorRpmFromSlip(ns, s);
    }
    final lines = <String>[
      if (ns != null)
        '① 동기속도 Ns = 120 × f ÷ P = 120 × ${fmt(hz!, 1)} ÷ $poles = ${fmt(ns, 1)} rpm',
      if (ns != null && s != null && rpm != null)
        '② 슬립 s = (Ns − N) ÷ Ns = (${fmt(ns, 0)} − ${fmt(rpm, 0)}) ÷ ${fmt(ns, 0)} = ${fmt(s * 100, 2)} %'
            '${rpm > ns ? ' (동기속도보다 빠름: 유도 발전기 운전)' : ''}',
      if (ns != null && s != null && rpm == null)
        '② 회전수 N = (1 − s) × Ns = (1 − ${fmt(s, 4)}) × ${fmt(ns, 1)} = ${fmt(n!, 1)} rpm',
      if (ns != null && s != null)
        '③ 회전자 전류 주파수 f2 = s × f = ${fmt(s, 4)} × ${fmt(hz!, 1)} = ${fmt(rotorHz(hz, s), 2)} Hz',
    ];
    String? summary;
    if (ns != null) {
      summary = '동기속도 ${fmt(ns, 0)} rpm${s == null ? '' : ' · 슬립 ${fmt(s * 100, 2)} %'}';
    }
    return (
      [
        elecField('mf_hz', '주파수 f (Hz)', _hz, '전원 주파수입니다. 한국은 60 Hz입니다.'),
        elecField('mf_poles', '극수 P', _poles, '2·4·6·8처럼 짝수입니다. 명판의 극수이거나, 60 Hz에서 3600 rpm은 2극, 1800 rpm은 4극, 1200 rpm은 6극입니다.'),
        elecField('mf_rpm', '회전수 N (rpm, 선택)', _rpm, '측정한 회전수나 명판 정격 회전수입니다. 넣으면 슬립을 구합니다.'),
        elecField('mf_slip', '슬립 s (%, 선택)', _slipPct, '회전수 대신 슬립을 알면 넣으십시오. 회전수 칸이 비어 있을 때 회전수를 구합니다.'),
      ],
      summary,
      lines.isEmpty ? const ['주파수와 극수를 넣으십시오(극수는 2 이상 짝수).'] : lines,
      false,
    );
  }

  (List<Widget>, String?, List<String>, bool) _current() {
    final kw = readNum(_kw);
    final v = readNum(_volts);
    final amps = readNum(_amps);
    final effIn = _ratio(_eff);
    final eff = _pIsInput ? 1.0 : effIn;
    final pf = _ratio(_pf);
    final k = _three ? '√3 × ' : '';
    final pName = _pIsInput ? '입력 전력 P1' : '축 출력 P';
    final lines = <String>[];
    String? summary;
    switch (_solve) {
      case _Solve.current:
        final r = (kw != null && v != null && eff != null && pf != null)
            ? motorElectrical(kw: kw, volts: v, eff: eff, pf: pf, three: _three)
            : null;
        if (r != null) {
          lines.addAll([
            '① 정격전류 I = P ÷ (${k}V × η × cosφ) = ${fmt(kw!, 2)} × 1000 ÷ ($k${fmt(v!, 0)} × ${fmt(eff!, 3)} × ${fmt(pf!, 3)}) = ${fmt(r.current, 1)} A',
            '② 입력 전력 P1 = P ÷ η = ${fmt(kw, 2)} ÷ ${fmt(eff, 3)} = ${fmt(r.inputKw, 2)} kW',
            '③ 피상전력 S = P1 ÷ cosφ = ${fmt(r.inputKw, 2)} ÷ ${fmt(pf, 3)} = ${fmt(r.apparentKva, 2)} kVA',
            '④ 손실 = P1 − P = ${fmt(r.inputKw, 2)} − ${fmt(kw, 2)} = ${fmt(r.lossKw, 2)} kW',
            '명판 정격전류가 있으면 그 값을 우선 적용하십시오(명판은 효율·역률이 실제 제품 값이라 위 식과 조금 다릅니다).',
          ]);
          summary = '정격전류 ${fmt(r.current, 1)} A · 입력 ${fmt(r.inputKw, 2)} kW';
        }
      case _Solve.voltage:
        final r = (kw != null && amps != null && eff != null && pf != null)
            ? motorVoltage(kw: kw, amps: amps, eff: eff, pf: pf, three: _three)
            : null;
        if (r != null) {
          lines.addAll([
            '① 전압 V = P ÷ (${k}I × η × cosφ) = ${fmt(kw!, 2)} × 1000 ÷ ($k${fmt(amps!, 2)} × ${fmt(eff!, 3)} × ${fmt(pf!, 3)}) = ${fmt(r, 1)} V',
            '${_three ? '삼상은 선간 전압입니다. ' : ''}정격 전압과 크게 다르면 전류·역률·효율 값이 맞는지 확인하십시오.',
          ]);
          summary = '전압 ${fmt(r, 1)} V';
        }
      case _Solve.pf:
        final r = (kw != null && v != null && amps != null && eff != null)
            ? motorPowerFactor(kw: kw, volts: v, amps: amps, eff: eff, three: _three)
            : null;
        if (r != null) {
          lines.addAll([
            '① 역률 cosφ = P ÷ (${k}V × I × η) = ${fmt(kw!, 2)} × 1000 ÷ ($k${fmt(v!, 0)} × ${fmt(amps!, 2)} × ${fmt(eff!, 3)}) = ${fmt(r, 3)} (${fmt(r * 100, 1)} %)',
            '② 위상각 φ = ${fmt(math.acos(r) * 180 / math.pi, 1)}°',
          ]);
          summary = '역률 ${fmt(r * 100, 1)} %';
        } else if (kw != null && v != null && amps != null && eff != null) {
          lines.add('계산한 역률이 1을 넘습니다. 전압·전류·출력·효율 값이 서로 맞는지 확인하십시오.');
        }
    }
    return (
      [
        _phaseChips(),
        elecChipGroup('구할 값', '정격전류, 전압, 역률 중 모르는 것을 고르면 나머지 값으로 구합니다.', [
          calcChip('mf_s_current', '전류', _solve == _Solve.current, () => setState(() => _solve = _Solve.current)),
          calcChip('mf_s_voltage', '전압', _solve == _Solve.voltage, () => setState(() => _solve = _Solve.voltage)),
          calcChip('mf_s_pf', '역률', _solve == _Solve.pf, () => setState(() => _solve = _Solve.pf)),
        ]),
        elecChipGroup('kW 기준', '전동기 명판의 축 출력을 쓰면 "축 출력"(효율을 같이 넣습니다). 전력계로 잰 값이면 "입력 전력"을 고르면 효율이 필요 없습니다.', [
          calcChip('mf_p_out', '축 출력', !_pIsInput, () => setState(() => _pIsInput = false)),
          calcChip('mf_p_in', '입력 전력(전력계)', _pIsInput, () => setState(() => _pIsInput = true)),
        ]),
        elecField('mf_kw', _pIsInput ? '입력 전력 P1 (kW)' : '축 출력 P (kW)', _kw, _pIsInput ? '전력계로 잰 입력 전력입니다.' : '전동기 명판의 정격 출력(축에서 나오는 기계 출력)입니다. HP면 × 0.7457 해서 kW로 바꾸십시오.'),
        if (_solve != _Solve.voltage)
          elecField('mf_v', '전압 V (V)', _volts, '삼상은 선간 전압, 단상은 사용 전압입니다.'),
        if (_solve != _Solve.current)
          elecField('mf_amps', '전류 I (A)', _amps, '클램프 미터로 잰 운전 전류이거나 명판 정격전류입니다.'),
        if (!_pIsInput)
          elecField('mf_eff', '효율 η (%)', _eff, '명판의 효율입니다. 90 또는 0.9처럼 넣으십시오. 명판에 없으면 제조사 자료의 값을 넣으십시오.'),
        if (_solve != _Solve.pf)
          elecField('mf_pf', '역률 cosφ (%)', _pf, '명판의 역률입니다. 85 또는 0.85처럼 넣으십시오.'),
      ],
      summary,
      lines.isEmpty ? ['구할 값에 필요한 칸을 모두 넣으십시오($pName 포함).'] : lines,
      false,
    );
  }

  (List<Widget>, String?, List<String>, bool) _flc() {
    final lines = <String>[];
    String? summary;
    final widgets = <Widget>[
      elecChipGroup('표 선택', 'NEC 430.250은 미국 규격의 삼상 유도전동기 전부하 전류 표(HP, 230·460 V)입니다. IE3 예시는 제조사 카탈로그의 4극 60 Hz 380·440 V 값입니다.', [
        calcChip('mf_flc_nec', 'NEC 430.250 (HP)', _flcNec, () => setState(() => _flcNec = true)),
        calcChip('mf_flc_ie3', 'IE3 4극 예시 (kW)', !_flcNec, () => setState(() => _flcNec = false)),
      ]),
    ];
    if (_flcNec) {
      final r = necRow(_necHp)!;
      widgets.add(calcDropdown<double>(
        'mf_flc_row',
        '전동기 출력 (HP)',
        _necHp,
        [for (final x in kNec430250) x.hpValue],
        (hp) => '${necRow(hp)!.hp} HP (${fmt(hp * 0.7457, 2)} kW)',
        (hp) => setState(() => _necHp = hp),
        '표에 있는 HP를 고릅니다. kW는 × 1.341 해서 HP로 바꾸십시오.',
      ));
      lines.addAll([
        '230 V: ${fmt(r.a230, 1)} A, 460 V: ${fmt(r.a460, 1)} A (삼상 유도전동기, ${r.hp} HP)',
        'NEC 430.6(A)(1)은 전선·차단기를 명판이 아니라 이 표 값으로 고르게 합니다(저속·다속 전동기 예외). 한국 현장은 명판 값을 우선하십시오.',
        '표 값은 NECA·1999 NEC·NEC 2014 세 사본이 모든 칸에서 같았습니다.',
      ]);
      summary = '${r.hp} HP: 230 V ${fmt(r.a230, 1)} A · 460 V ${fmt(r.a460, 1)} A';
    } else {
      final r = ie3Row(_ie3Kw)!;
      widgets.add(calcDropdown<double>(
        'mf_flc_row',
        '전동기 출력 (kW)',
        _ie3Kw,
        [for (final x in kIe3Hd60Hz) x.kw],
        (kw) => '${fmt(kw, 2)} kW',
        (kw) => setState(() => _ie3Kw = kw),
        '카탈로그에 있는 정격 출력을 고릅니다.',
      ));
      lines.addAll([
        '380 V: ${fmt(r.a380, 2)} A, 440 V: ${fmt(r.a440, 2)} A (효율 ${fmt(r.eff, 1)} %, 역률 ${fmt(r.pf * 100, 1)} %)',
        'HD현대일렉트릭 저압 유도전동기 카탈로그(2022-03) 4극 60 Hz 값입니다. 제조사 예시일 뿐이고 실제 전동기는 명판 값을 쓰십시오.',
      ]);
      summary = '${fmt(r.kw, 2)} kW: 380 V ${fmt(r.a380, 1)} A · 440 V ${fmt(r.a440, 1)} A';
    }
    return (widgets, summary, lines, false);
  }

  (List<Widget>, String?, List<String>, bool) _torque() {
    final kw = readNum(_tkw);
    final rpm = readNum(_trpm);
    final nm = readNum(_tnm);
    String? summary;
    final lines = <String>[];
    if (!_torqueToPower) {
      final t = (kw != null && rpm != null) ? motorTorqueNm(kw, rpm) : null;
      if (t != null) {
        lines.addAll([
          '① 토크 T = P ÷ ω = P × 1000 × 60 ÷ (2π × N) = ${fmt(kw!, 2)} × 1000 × 60 ÷ (2π × ${fmt(rpm!, 0)}) = ${fmt(t, 2)} N·m',
          '간이식 T = 9549 × P[kW] ÷ N[rpm] = 9549 × ${fmt(kw, 2)} ÷ ${fmt(rpm, 0)} = ${fmt(9549.3 * kw / rpm, 2)} N·m',
          '② kgf·m 단위로는 ${fmt(nmToKgfM(t), 2)} kgf·m (1 kgf·m = 9.807 N·m)',
        ]);
        summary = '토크 ${fmt(t, 1)} N·m (${fmt(nmToKgfM(t), 2)} kgf·m)';
      }
    } else {
      final p = (nm != null && rpm != null) ? motorPowerKw(nm, rpm) : null;
      if (p != null) {
        lines.addAll([
          '① 출력 P = T × ω = T × 2π × N ÷ 60 = ${fmt(nm!, 2)} × 2π × ${fmt(rpm!, 0)} ÷ 60 ÷ 1000 = ${fmt(p, 2)} kW',
          '간이식 P = T[N·m] × N[rpm] ÷ 9549 = ${fmt(nm, 2)} × ${fmt(rpm, 0)} ÷ 9549 = ${fmt(nm * rpm / 9549.3, 2)} kW',
        ]);
        summary = '출력 ${fmt(p, 2)} kW';
      }
    }
    return (
      [
        elecChipGroup('방향', '출력과 회전수로 토크를 구하거나, 토크와 회전수로 출력을 구합니다.', [
          calcChip('mf_t_fwd', '출력 → 토크', !_torqueToPower, () => setState(() => _torqueToPower = false)),
          calcChip('mf_t_rev', '토크 → 출력', _torqueToPower, () => setState(() => _torqueToPower = true)),
        ]),
        if (!_torqueToPower)
          elecField('mf_tkw', '출력 P (kW)', _tkw, '전동기 축 출력입니다.')
        else
          elecField('mf_tnm', '토크 T (N·m)', _tnm, '축 토크입니다. kgf·m는 × 9.807 해서 N·m로 바꾸십시오.'),
        elecField('mf_trpm', '회전수 N (rpm)', _trpm, '정격 회전수(명판) 또는 측정 회전수입니다.'),
      ],
      summary,
      lines.isEmpty ? const ['값을 넣으십시오.'] : lines,
      false,
    );
  }

  (List<Widget>, String?, List<String>, bool) _maxTorque() {
    final kw = readNum(_xkw);
    final rpm = readNum(_xrpm);
    final mult = readNum(_xmult);
    final vIn = readNum(_xvolt);
    final vr = vIn == null ? null : (vIn > 3 ? vIn / 100 : vIn);
    final tr = (kw != null && rpm != null) ? motorTorqueNm(kw, rpm) : null;
    final lines = <String>[];
    String? summary;
    if (tr != null) {
      lines.add('① 정격 토크 T = P × 1000 × 60 ÷ (2π × N) = ${fmt(kw!, 2)} × 1000 × 60 ÷ (2π × ${fmt(rpm!, 0)}) = ${fmt(tr, 1)} N·m');
      final tm = mult == null ? null : maxTorqueNm(tr, mult);
      if (tm != null) {
        lines.add('② 최대 토크 = 정격 토크 × 명판 배수 = ${fmt(tr, 1)} × ${fmt(mult!, 2)} = ${fmt(tm, 1)} N·m (${fmt(nmToKgfM(tm), 2)} kgf·m)');
        summary = '최대 토크 ${fmt(tm, 1)} N·m';
        if (vr != null && vr > 0) {
          final tv = torqueAtVoltage(tm, vr);
          lines.add('③ 전압이 정격의 ${fmt(vr * 100, 0)} %이면 최대 토크는 전압²에 비례해 ${fmt(tv, 1)} N·m(${fmt(vr * vr * 100, 0)} %)로 줄고, 정격 토크 대비 ${fmt(tv / tr, 2)}배입니다.');
        }
      }
      // 규격 최소 배수
      if (_xIec) {
        final m = iecDesignNMinMultiple(kw, _xPoles);
        lines.add(
          m == null
              ? '④ IEC 60034-12 설계 N 표에서 ${fmt(kw, 2)} kW $_xPoles극 값을 찾지 못했습니다.'
              : '④ IEC 60034-12 설계 N 최소값: ${fmt(kw, 2)} kW $_xPoles극은 정격 토크의 ${fmt(m, 1)}배 이상입니다 → 최소 ${fmt(tr * m, 1)} N·m. 상한은 없고, 설계 H는 확인하지 못했습니다.',
        );
        if (tm == null && m != null) summary = '규격 최소 최대 토크 ${fmt(tr * m, 1)} N·m';
      } else {
        final hp = kw / 0.7457;
        final sync = {2: 3600, 4: 1800, 6: 1200, 8: 900}[_xPoles]!;
        final pct = nemaAbMinPercent(hp, sync);
        lines.add(
          pct == null
              ? '④ NEMA MG-1 12.39 설계 A·B 표에서 ${fmt(hp, 1)} hp $_xPoles극($sync rpm) 값을 확인하지 못했습니다(표에서 읽은 행은 1·1.5·2·3·5·7.5 hp, 10~125 hp, 250 hp 이상이고 1 hp 3600 rpm 칸은 비어 있습니다).'
              : '④ NEMA MG-1 설계 A·B 최소값: ${fmt(hp, 1)} hp $_xPoles극($sync rpm)은 정격 토크의 ${fmt(pct, 0)} % 이상입니다 → 최소 ${fmt(tr * pct / 100, 1)} N·m. 설계 C·D는 값이 다릅니다.',
        );
        if (tm == null && pct != null) summary = '규격 최소 최대 토크 ${fmt(tr * pct / 100, 1)} N·m';
      }
      lines.add('명판이나 제조사 자료에 최대 토크(또는 배수)가 있으면 그 값을 우선하십시오. 규격 값은 "최소" 보증이라 실제 전동기는 이보다 클 수 있고, 인버터 전용기·대형·2·6·8극은 다를 수 있습니다.');
    }
    return (
      [
        elecField('mf_xkw', '출력 P (kW)', _xkw, '전동기 명판의 정격 출력입니다.'),
        elecField('mf_xrpm', '정격 회전수 N (rpm)', _xrpm, '명판의 정격 회전수입니다.'),
        elecField('mf_xmult', '최대 토크 배수 (선택)', _xmult, '정격 토크의 몇 배인지입니다. 명판·제조사 자료의 breakdown torque 값입니다. 넣으면 최대 토크를 구합니다.'),
        elecField('mf_xvolt', '운전 전압 / 정격 전압 (%, 선택)', _xvolt, '전압이 떨어졌을 때 확인하려면 넣으십시오. 90 또는 0.9처럼 넣습니다.'),
        elecChipGroup('규격 최소값', '명판에 최대 토크가 없을 때 참고하는 규격의 보증 최소값입니다.', [
          calcChip('mf_x_iec', 'IEC 60034-12 설계 N', _xIec, () => setState(() => _xIec = true)),
          calcChip('mf_x_nema', 'NEMA MG-1 설계 A·B', !_xIec, () => setState(() => _xIec = false)),
        ]),
        elecChipGroup('극수', '규격 표를 읽을 극수입니다(60 Hz 동기속도 3600·1800·1200·900 rpm에 해당).', [
          for (final p in const [2, 4, 6, 8])
            calcChip('mf_xp_$p', '$p극', _xPoles == p, () => setState(() => _xPoles = p)),
        ]),
      ],
      summary,
      lines.isEmpty ? const ['출력과 정격 회전수를 넣으십시오.'] : lines,
      false,
    );
  }

  (List<Widget>, String?, List<String>, bool) _start() {
    final ir = readNum(_rated);
    final m = readNum(_mult);
    final tapIn = readNum(_tap);
    final tap = tapIn == null ? null : (tapIn > 1 ? tapIn / 100 : tapIn);
    final needTap =
        _kind == StartKind.autoTransformer || _kind == StartKind.reactor;
    final r = (ir != null && m != null)
        ? motorStart(ratedAmps: ir, multiple: m, kind: _kind, tap: tap ?? 1)
        : null;
    final lines = <String>[];
    bool warn = false;
    if (ir != null && m != null && needTap && r == null) {
      lines.add('탭(전동기 단자 전압 비)은 0보다 크고 100 % 미만으로 넣으십시오.');
      warn = true;
    }
    if (r != null) {
      final direct = ir! * m!;
      lines.add('① 직입 기동전류 = 정격전류 × 기동 배수 = ${fmt(ir, 1)} × ${fmt(m, 1)} = ${fmt(direct, 1)} A');
      switch (_kind) {
        case StartKind.direct:
          lines.add('② 직입 기동: 전류 그대로, 기동 토크도 그대로입니다.');
        case StartKind.starDelta:
          lines.add('② Y로 기동하면 권선 전압이 1/√3이라 전원 쪽 전류와 기동 토크가 직입의 1/3입니다. 전원 쪽 기동전류 = ${fmt(direct, 1)} ÷ 3 = ${fmt(r.lineAmps, 1)} A');
        case StartKind.autoTransformer:
          lines.add('② 기동보상기(탭 ${fmt(tap! * 100, 0)} %): 전동기 전류는 탭 배, 전원 쪽 전류는 탭² 배입니다. 전원 쪽 기동전류 = ${fmt(direct, 1)} × ${fmt(tap, 2)}² = ${fmt(r.lineAmps, 1)} A');
          lines.add('③ 기동 토크는 전압²에 비례하므로 탭² = ${fmt(r.torqueRatio, 3)}배입니다.');
        case StartKind.reactor:
          lines.add('② 리액터(전동기 단자 전압 ${fmt(tap! * 100, 0)} %): 전류도 같은 비율로 줄어 전원 쪽 기동전류 = ${fmt(direct, 1)} × ${fmt(tap, 2)} = ${fmt(r.lineAmps, 1)} A');
          lines.add('③ 기동 토크는 전압²에 비례하므로 탭² = ${fmt(r.torqueRatio, 3)}배입니다.');
      }
      lines.add('④ 직입 대비 기동전류 ${fmt(r.currentRatio * 100, 1)} %, 기동 토크 ${fmt(r.torqueRatio * 100, 1)} %');
      lines.add('기동 토크가 부하가 필요로 하는 토크보다 작으면 기동하지 못합니다. 기동 배수는 명판이나 제조사 자료의 값을 넣으십시오.');
    }
    return (
      [
        elecChipGroup('기동 방식', '직입, Y-Δ, 기동보상기(오토트랜스), 리액터 기동 중에서 고릅니다.', [
          calcChip('mf_k_direct', '직입', _kind == StartKind.direct, () => setState(() => _kind = StartKind.direct)),
          calcChip('mf_k_yd', 'Y-Δ', _kind == StartKind.starDelta, () => setState(() => _kind = StartKind.starDelta)),
          calcChip('mf_k_auto', '기동보상기', _kind == StartKind.autoTransformer, () => setState(() => _kind = StartKind.autoTransformer)),
          calcChip('mf_k_reactor', '리액터', _kind == StartKind.reactor, () => setState(() => _kind = StartKind.reactor)),
        ]),
        elecField('mf_rated', '정격전류 (A)', _rated, '전동기 명판의 정격전류입니다. 전류·효율 묶음으로 구할 수도 있습니다.'),
        elecField('mf_mult', '직입 기동 배수', _mult, '직입 기동전류가 정격전류의 몇 배인지입니다. 보통 5~8배이고 명판(코드 문자)이나 제조사 자료의 값을 넣으십시오. 처음 값 ${fmt(kMotorStartMultipleDefault, 0)}은 예시입니다.'),
        if (needTap)
          elecField('mf_tap', '전동기 단자 전압 비 (%)', _tap, '기동할 때 전동기 단자에 걸리는 전압이 정격전압의 몇 %인지입니다(탭 65 %, 80 % 등). 65 또는 0.65처럼 넣으십시오.'),
      ],
      r == null ? null : '전원 쪽 기동전류 ${fmt(r.lineAmps, 1)} A · 토크 ${fmt(r.torqueRatio * 100, 0)} %',
      lines.isEmpty ? const ['정격전류와 기동 배수를 넣으십시오.'] : lines,
      warn,
    );
  }

  (List<Widget>, String?, List<String>, bool) _load() {
    final i = readNum(_meas);
    final ir = readNum(_lrated);
    final v = readNum(_volts);
    final pf = _ratio(_lpf);
    final eff = _ratio(_leff);
    final r = (i != null && ir != null && v != null && pf != null)
        ? motorLoad(
            measuredAmps: i,
            ratedAmps: ir,
            volts: v,
            pf: pf,
            three: _three,
            eff: eff,
          )
        : null;
    final k = _three ? '√3 × ' : '';
    final lines = <String>[
      if (r != null) ...[
        '① 전류 부하율 = 측정 전류 ÷ 정격전류 × 100 = ${fmt(i!, 1)} ÷ ${fmt(ir!, 1)} × 100 = ${fmt(r.loadPct, 1)} %${r.loadPct > 100 ? ' (정격 초과: 과부하)' : ''}',
        '② 입력 전력 = ${k}V × I × cosφ = $k${fmt(v!, 0)} × ${fmt(i, 1)} × ${fmt(pf!, 3)} ÷ 1000 = ${fmt(r.inputKw, 2)} kW',
        if (r.outputKw != null)
          '③ 축 출력 ≈ 입력 × 효율 = ${fmt(r.inputKw, 2)} × ${fmt(eff!, 3)} = ${fmt(r.outputKw!, 2)} kW',
        '전류 부하율은 근사입니다. 부분 부하에서는 역률과 효율이 정격 값과 달라 출력 추정이 어긋날 수 있습니다. 같은 전동기를 같은 조건에서 비교하는 용도로 쓰십시오.',
      ],
    ];
    return (
      [
        _phaseChips(),
        elecField('mf_meas', '측정 전류 (A)', _meas, '클램프 미터로 잰 운전 중 전류입니다. 삼상이면 세 상 평균을 넣으십시오.'),
        elecField('mf_lrated', '정격전류 (A)', _lrated, '전동기 명판의 정격전류입니다.'),
        elecField('mf_lv', '전압 V (V)', _volts, '삼상은 선간 전압입니다.'),
        elecField('mf_lpf', '운전 중 역률 cosφ (%)', _lpf, '측정했거나 명판의 역률입니다. 85 또는 0.85처럼 넣으십시오.'),
        elecField('mf_leff', '효율 η (%, 선택)', _leff, '넣으면 축 출력까지 추정합니다.'),
      ],
      r == null ? null : '부하율 ${fmt(r.loadPct, 1)} % · 입력 ${fmt(r.inputKw, 2)} kW',
      lines.isEmpty ? const ['측정 전류·정격전류·전압·역률을 넣으십시오.'] : lines,
      r != null && r.loadPct > 100,
    );
  }

  Widget _phaseChips() => elecChipGroup('상', '삼상 또는 단상입니다.', [
    calcChip('mf_ph3', '삼상', _three, () => setState(() => _three = true)),
    calcChip('mf_ph1', '단상', !_three, () => setState(() => _three = false)),
  ]);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final (fields, summary, lines, warn) = switch (_sec) {
      _Sec.speed => _speed(),
      _Sec.current => _current(),
      _Sec.torque => _torque(),
      _Sec.maxTorque => _maxTorque(),
      _Sec.start => _start(),
      _Sec.load => _load(),
      _Sec.flc => _flc(),
    };
    final ok = summary != null;
    return elecPage(
      sumKey: 'mf_sum',
      summary: summary,
      warn: warn,
      [
        elecChipGroup('계산 항목', '전동기에서 가장 자주 쓰는 식을 묶음으로 나눴습니다.', [
          for (final s in _Sec.values)
            calcChip('mf_sec_${s.name}', _secName(s), _sec == s, () => setState(() => _sec = s)),
        ]),
        ...fields,
        const SizedBox(height: 6),
        calcResult(
          key: const Key('mf_result'),
          big: ok ? summary.split(' · ').first : '-',
          caption: _secName(_sec),
          warn: warn,
          lines: lines,
        ),
        elecBasis('mf_basis', const [
          '모두 정의식과 교재에 나오는 일반식입니다. 표 값은 쓰지 않습니다.',
          '동기속도 Ns = 120f ÷ P, 슬립 s = (Ns − N) ÷ Ns, 회전수 N = (1 − s)Ns, 회전자 주파수 f2 = s·f.',
          '정격전류 I = P ÷ (√3·V·η·cosφ), 입력 P1 = P ÷ η, 토크 T = P ÷ ω (ω = 2πN ÷ 60). 전압·역률은 같은 식을 풀어서 구합니다.',
          '기동: Y-Δ는 전류·토크가 직입의 1/3, 기동보상기는 전원 쪽 전류와 토크가 탭², 리액터는 전류가 탭·토크가 탭²입니다.',
          '최대 토크: 정격 토크 × 명판 배수, 전압²에 비례. 규격 최소값은 NEMA MG-1 12.39 설계 A·B 표와 IEC 60034-12 표 1 설계 N 원문입니다(NEMA 설계 C·D와 IEC 설계 H는 못 찾아 넣지 않았습니다).',
          '명판의 정격전류·효율·역률이 있으면 명판 값을 우선합니다. 과부하계전기·차단기 상한은 "전동기 보호" 탭에서 계산합니다.',
        ]),
      ],
    );
  }
}
