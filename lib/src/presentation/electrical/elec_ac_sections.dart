// 기초 계산 탭의 "교류 역산"(역률·전압 구하기)과 "임피던스"(R·L·C 직렬) 묶음. 계산은 ac_calc.dart.
// 입력은 이 화면 안에서만 가지고 있고 저장하지 않는다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/field_view.dart';
import '../common/calc_form_parts.dart';
import 'ac_calc.dart';
import 'elec_form_parts.dart' show fmt, readNum;

String _sig(double v) => fmt(v, v.abs() >= 100 ? 1 : (v.abs() >= 1 ? 2 : 4));

/// 구하는 값: 역률 또는 전압.
enum _Solve { pf, voltage }

class AcSolveSection extends StatefulWidget {
  const AcSolveSection({super.key});

  @override
  State<AcSolveSection> createState() => _AcSolveSectionState();
}

class _AcSolveSectionState extends State<AcSolveSection> with CalcFormParts<AcSolveSection> {
  _Solve _solve = _Solve.pf;
  bool _three = true;
  bool _fromKva = false; // 역률: kW와 kVA / 전압: kVA와 전류
  final _kw = TextEditingController();
  final _kva = TextEditingController();
  final _volts = TextEditingController(text: '380');
  final _amps = TextEditingController();
  final _pf = TextEditingController();

  @override
  void dispose() {
    for (final c in [_kw, _kva, _volts, _amps, _pf]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _chips(String label, String guide, List<Widget> chips) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        calcLabel(label, guide),
        const SizedBox(height: 4),
        Wrap(spacing: 6, runSpacing: 6, children: chips),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final kw = readNum(_kw), kva = readNum(_kva), v = readNum(_volts), a = readNum(_amps);
    final pfRaw = readNum(_pf);
    final pf = pfRaw == null ? null : (pfRaw > 1 ? pfRaw / 100 : pfRaw);
    final k = _three ? '√3 × ' : '';
    final lines = <String>[];
    String big = '-';
    String caption = _solve == _Solve.pf ? '역률' : '전압';

    if (_solve == _Solve.pf) {
      double? r;
      if (_fromKva) {
        r = (kw != null && kva != null) ? pfFromKwKva(kw, kva) : null;
        if (r != null) lines.add('역률 cosφ = P ÷ S = ${_sig(kw!)} ÷ ${_sig(kva!)} = ${fmt(r, 3)}');
      } else {
        r = (kw != null && v != null && a != null) ? pfFromKwVi(kw: kw, volts: v, amps: a, three: _three) : null;
        if (r != null) {
          lines.add('역률 cosφ = P ÷ (${k}V × I) = ${_sig(kw! * 1000)} ÷ ($k${fmt(v!, 0)} × ${_sig(a!)}) = ${fmt(r, 3)}');
        }
      }
      if (r != null) {
        big = '${fmt(r * 100, 1)} %';
        lines.add('위상각 φ = acos ${fmt(r, 3)} = ${fmt(math.acos(r) * 180 / math.pi, 1)}°');
        if (kw != null) {
          final s = kw / r;
          lines.add('피상전력 S = P ÷ cosφ = ${_sig(kw)} ÷ ${fmt(r, 3)} = ${_sig(s)} kVA, 무효전력 Q = √(S² − P²) = ${_sig(math.sqrt(math.max(0, s * s - kw * kw)))} kvar');
        }
      } else if ((_fromKva && kw != null && kva != null) || (!_fromKva && kw != null && v != null && a != null)) {
        lines.add('계산한 역률이 1을 넘습니다. 전압·전류·kW(또는 kVA) 값이 서로 맞는지 확인하십시오.');
      }
    } else {
      double? r;
      if (_fromKva) {
        r = (kva != null && a != null) ? voltageFromKva(kva: kva, amps: a, three: _three) : null;
        if (r != null) lines.add('전압 V = S × 1000 ÷ (${k}I) = ${_sig(kva! * 1000)} ÷ ($k${_sig(a!)}) = ${fmt(r, 1)} V');
      } else {
        r = (kw != null && a != null && pf != null) ? voltageFromKwIPf(kw: kw, amps: a, pf: pf, three: _three) : null;
        if (r != null) {
          lines.add('전압 V = P × 1000 ÷ (${k}I × cosφ) = ${_sig(kw! * 1000)} ÷ ($k${_sig(a!)} × ${fmt(pf!, 3)}) = ${fmt(r, 1)} V');
        }
      }
      if (r != null) {
        big = '${fmt(r, 1)} V';
        if (_three) lines.add('삼상은 선간 전압입니다.');
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _chips('구하는 값', '역률 또는 전압 중 모르는 값을 고르면 나머지로 구합니다.', [
          calcChip('ec_as_pf', '역률', _solve == _Solve.pf, () => setState(() => _solve = _Solve.pf)),
          calcChip('ec_as_v', '전압', _solve == _Solve.voltage, () => setState(() => _solve = _Solve.voltage)),
        ]),
        _chips('결선', '단상 S = V × I, 삼상 S = √3 × V × I (V 선간전압, I 선전류).', [
          calcChip('ec_as_1', '단상', !_three, () => setState(() => _three = false)),
          calcChip('ec_as_3', '삼상', _three, () => setState(() => _three = true)),
        ]),
        _chips(
          '아는 값',
          _solve == _Solve.pf
              ? 'kW·kVA: 전력계와 피상전력 값으로 구합니다. kW·전압·전류: 측정한 값으로 구합니다.'
              : 'kW·전류·역률 또는 kVA·전류로 전압을 구합니다.',
          [
            calcChip('ec_as_base', _solve == _Solve.pf ? 'kW·전압·전류' : 'kW·전류·역률', !_fromKva, () => setState(() => _fromKva = false)),
            calcChip('ec_as_kva', _solve == _Solve.pf ? 'kW·kVA' : 'kVA·전류', _fromKva, () => setState(() => _fromKva = true)),
          ],
        ),
        if (!(_solve == _Solve.voltage && _fromKva))
          calcField('ec_as_kw', '유효전력 P (kW)', _kw, '부하의 유효전력입니다(전력계 값).'),
        if (_fromKva)
          calcField('ec_as_kvav', '피상전력 S (kVA)', _kva, '피상전력입니다.'),
        if (_solve == _Solve.pf && !_fromKva)
          calcField('ec_as_volts', '전압 V (V)', _volts, '삼상은 선간 전압입니다.'),
        if (!(_solve == _Solve.pf && _fromKva))
          calcField('ec_as_amps', '전류 I (A)', _amps, '선전류입니다.'),
        if (_solve == _Solve.voltage && !_fromKva)
          calcField('ec_as_pf_in', '역률 cosφ (%)', _pf, '85 또는 0.85처럼 넣으십시오.'),
        const SizedBox(height: 8),
        calcResult(
          key: const Key('ec_as_result'),
          big: big,
          caption: caption,
          lines: lines.isEmpty ? const ['필요한 칸을 넣으십시오.'] : lines,
        ),
      ],
    );
  }

}

class ImpedanceSection extends StatefulWidget {
  const ImpedanceSection({super.key});

  @override
  State<ImpedanceSection> createState() => _ImpedanceSectionState();
}

class _ImpedanceSectionState extends State<ImpedanceSection> with CalcFormParts<ImpedanceSection> {
  final _r = TextEditingController();
  final _xl = TextEditingController();
  final _xc = TextEditingController();
  final _l = TextEditingController();
  final _c = TextEditingController();
  final _hz = TextEditingController(text: '60');
  final _v = TextEditingController();

  @override
  void dispose() {
    for (final c in [_r, _xl, _xc, _l, _c, _hz, _v]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = readNum(_r);
    final hz = readNum(_hz);
    var xl = readNum(_xl);
    var xc = readNum(_xc);
    final lMh = readNum(_l); // mH
    final cUf = readNum(_c); // μF
    final lines = <String>[];
    if (xl == null && lMh != null && hz != null && lMh > 0) {
      xl = inductiveX(hz, lMh / 1000);
      lines.add('유도 리액턴스 XL = 2π × f × L = 2π × ${fmt(hz, 0)} × ${fmt(lMh, 2)} mH = ${_sig(xl)} Ω');
    }
    if (xc == null && cUf != null && hz != null && cUf > 0) {
      xc = capacitiveX(hz, cUf / 1e6);
      if (xc != null) lines.add('용량 리액턴스 XC = 1 ÷ (2π × f × C) = 1 ÷ (2π × ${fmt(hz, 0)} × ${fmt(cUf, 2)} μF) = ${_sig(xc)} Ω');
    }
    final z = r == null ? null : seriesImpedance(r: r, xl: xl ?? 0, xc: xc ?? 0, volts: readNum(_v));
    String big = '-';
    if (z != null) {
      big = '${_sig(z.z)} Ω';
      lines.addAll([
        '합성 리액턴스 X = XL − XC = ${_sig(xl ?? 0)} − ${_sig(xc ?? 0)} = ${_sig(z.x)} Ω (${z.x > 0 ? '유도성' : z.x < 0 ? '용량성' : '공진'})',
        '임피던스 Z = √(R² + X²) = √(${_sig(r!)}² + ${_sig(z.x)}²) = ${_sig(z.z)} Ω',
        '역률 cosφ = R ÷ Z = ${_sig(r)} ÷ ${_sig(z.z)} = ${fmt(z.pf, 3)} (${fmt(z.pf * 100, 1)} %), 위상각 φ = ${fmt(z.angleDeg, 1)}°${z.angleDeg > 0 ? ' (전류가 전압보다 늦음)' : z.angleDeg < 0 ? ' (전류가 전압보다 빠름)' : ''}',
        if (z.amps != null) '전류 I = V ÷ Z = ${fmt(readNum(_v)!, 1)} ÷ ${_sig(z.z)} = ${_sig(z.amps!)} A',
        '직렬 회로 기준입니다. 병렬이면 어드미턴스로 계산해야 합니다.',
      ]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        calcField('ec_zi_r', '저항 R (Ω)', _r, '회로의 저항분입니다.'),
        calcField('ec_zi_xl', '유도 리액턴스 XL (Ω, 선택)', _xl, '알면 직접 넣고, 모르면 아래 인덕턴스로 구합니다.'),
        calcField('ec_zi_l', '인덕턴스 L (mH, 선택)', _l, 'XL 칸을 비우면 이 값으로 XL = 2πfL을 구합니다.'),
        calcField('ec_zi_xc', '용량 리액턴스 XC (Ω, 선택)', _xc, '알면 직접 넣고, 모르면 아래 정전용량으로 구합니다.'),
        calcField('ec_zi_c', '정전용량 C (μF, 선택)', _c, 'XC 칸을 비우면 이 값으로 XC = 1 ÷ (2πfC)를 구합니다.'),
        calcField('ec_zi_hz', '주파수 f (Hz)', _hz, '한국은 60 Hz입니다.'),
        calcField('ec_zi_v', '전압 V (V, 선택)', _v, '넣으면 전류를 구합니다.'),
        const SizedBox(height: 8),
        calcResult(
          key: const Key('ec_zi_result'),
          big: big,
          caption: '임피던스 Z',
          lines: lines.isEmpty ? const ['저항 R과 리액턴스(또는 L·C)를 넣으십시오.'] : lines,
        ),
      ],
    );
  }
}

/// 역률 개선 탭 아래: 콘덴서를 다른 전압·주파수에 쓸 때 실제 출력.
class CapVoltageSection extends StatefulWidget {
  const CapVoltageSection({super.key});

  @override
  State<CapVoltageSection> createState() => _CapVoltageSectionState();
}

class _CapVoltageSectionState extends State<CapVoltageSection> with CalcFormParts<CapVoltageSection> {
  final _kvar = TextEditingController();
  final _vn = TextEditingController();
  final _v = TextEditingController();
  final _fn = TextEditingController(text: '60');
  final _f = TextEditingController(text: '60');

  @override
  void dispose() {
    for (final c in [_kvar, _vn, _v, _fn, _f]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qn = readNum(_kvar), vn = readNum(_vn), v = readNum(_v), fn = readNum(_fn), f = readNum(_f);
    final q = (qn != null && vn != null && v != null && fn != null && f != null)
        ? capacitorKvarAtVoltage(ratedKvar: qn, ratedVolts: vn, volts: v, ratedHz: fn, hz: f)
        : null;
    final lines = <String>[];
    if (q != null) {
      lines.addAll([
        '실제 출력 Q = Qn × (V ÷ Vn)² × (f ÷ fn) = ${_sig(qn!)} × (${fmt(v!, 0)} ÷ ${fmt(vn!, 0)})² × (${fmt(f!, 0)} ÷ ${fmt(fn!, 0)}) = ${_sig(q)} kvar',
        '정격 대비 ${fmt(q / qn * 100, 1)} %입니다. 전압이 정격보다 낮으면 출력도 제곱으로 줄어 역률 개선 효과가 작아집니다.',
        if (v > vn * 1.1) '운전 전압이 정격 전압의 110 %를 넘습니다. 콘덴서 수명과 과전압을 확인하십시오(제조사 허용 범위를 따르십시오).',
        '콘덴서 출력은 Q = 2π·f·C·V²이라 전압의 제곱, 주파수에 비례합니다.',
      ]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Text('다른 전압에서의 콘덴서 출력', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: fc.text)),
        const SizedBox(height: 8),
        calcField('ec_cv_q', '명판 출력 Qn (kvar)', _kvar, '콘덴서 명판의 정격 출력입니다.'),
        calcField('ec_cv_vn', '명판 정격 전압 Vn (V)', _vn, '콘덴서 명판의 정격 전압입니다.'),
        calcField('ec_cv_v', '실제 운전 전압 V (V)', _v, '콘덴서를 걸 회로의 전압입니다.'),
        calcField('ec_cv_fn', '명판 주파수 (Hz)', _fn, '명판의 주파수입니다.'),
        calcField('ec_cv_f', '실제 주파수 (Hz)', _f, '한국은 60 Hz입니다.'),
        const SizedBox(height: 8),
        calcResult(
          key: const Key('ec_cv_result'),
          big: q == null ? '- kvar' : '${_sig(q)} kvar',
          caption: '실제 콘덴서 출력',
          lines: lines.isEmpty ? const ['명판 출력·정격 전압·운전 전압을 넣으십시오.'] : lines,
        ),
      ],
    );
  }
}
