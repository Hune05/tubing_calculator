// 유량 계산 "차압 유량계" 탭: 차압 ↔ 유량 환산(Q = Qmax·√(ΔP/ΔPmax))과 제곱근 환산표,
// ISO 5167-2 오리피스 유량(액체, Reader-Harris/Gallagher 유출 계수).
part of 'flow_calc_page.dart';

mixin _FlowDpTab on State<FlowCalcPage>, CalcFormParts<FlowCalcPage> {
  _FlowCalcPageState get _pg => this as _FlowCalcPageState;

  // ── 환산 ──
  bool _mOrifice = false;
  final _mQmax = TextEditingController();
  final _mQunit = TextEditingController(text: 'm³/h');
  final _mDpMax = TextEditingController();
  DpUnit _mDpUnit = DpUnit.kpa;
  bool _mFromDp = true;
  final _mValue = TextEditingController();
  bool _mByFlow = true;

  // ── 오리피스 ──
  final _oD = TextEditingController();
  final _oBore = TextEditingController();
  final _oDp = TextEditingController();
  DpUnit _oDpUnit = DpUnit.kpa;
  OrificeTap _oTap = OrificeTap.flange;
  bool _oOil = false;
  final _oWaterT = TextEditingController(text: '20');
  final _oRho = TextEditingController();
  final _oCst = TextEditingController();

  Map<String, TextEditingController> get _dpFields => {
    'mQmax': _mQmax,
    'mQunit': _mQunit,
    'mDpMax': _mDpMax,
    'mValue': _mValue,
    'oD': _oD,
    'oBore': _oBore,
    'oDp': _oDp,
    'oWaterT': _oWaterT,
    'oRho': _oRho,
    'oCst': _oCst,
  };

  Map<String, Object> _dpDraftJson() => {
    'orifice': _mOrifice,
    'dpUnit': _mDpUnit.name,
    'fromDp': _mFromDp,
    'byFlow': _mByFlow,
    'oDpUnit': _oDpUnit.name,
    'oTap': _oTap.name,
    'oOil': _oOil,
  };

  void _applyDpDraft(Object? m) {
    if (m is! Map) return;
    T pick<T extends Enum>(List<T> values, Object? name, T now) =>
        values.firstWhere((v) => v.name == name, orElse: () => now);
    if (m['orifice'] is bool) _mOrifice = m['orifice'] as bool;
    if (m['fromDp'] is bool) _mFromDp = m['fromDp'] as bool;
    if (m['byFlow'] is bool) _mByFlow = m['byFlow'] as bool;
    if (m['oOil'] is bool) _oOil = m['oOil'] as bool;
    _mDpUnit = pick(DpUnit.values, m['dpUnit'], _mDpUnit);
    _oDpUnit = pick(DpUnit.values, m['oDpUnit'], _oDpUnit);
    _oTap = pick(OrificeTap.values, m['oTap'], _oTap);
  }

  double? _n(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', ''));

  String get _qu => _mQunit.text.trim();

  Widget _meterTab() => _pg._page([
    _pg._chips(
      '계산 종류',
      '차압 환산: 전송기 측정 범위(최대 차압)와 그때의 유량(최대 유량)으로 차압과 유량을 서로 환산합니다. '
          '유량계 데이터시트·계기 목록(Instrument index)에 두 값이 있습니다.\n'
          '오리피스(ISO 5167-2): 오리피스 판 치수와 차압으로 액체 유량을 계산합니다.',
      [
        calcChip('fm_mode_range', '차압 환산', !_mOrifice, () {
          setState(() => _mOrifice = false);
        }),
        calcChip('fm_mode_orifice', '오리피스(ISO 5167-2)', _mOrifice, () {
          setState(() => _mOrifice = true);
        }),
      ],
    ),
    if (_mOrifice) ..._orificeBody() else ..._rangeBody(),
  ]);

  // ─────────────── 차압 환산 ───────────────

  Widget _dpUnitChips(String key, DpUnit now, ValueChanged<DpUnit> set) =>
      _pg._chips(
        '차압 단위',
        '전송기 명판·데이터시트의 측정 범위 단위를 고르십시오. mmH₂O는 9.80665Pa(관용 값)로 계산합니다.',
        [
          for (final u in DpUnit.values)
            calcChip('${key}_${u.name}', u.label, now == u, () => set(u)),
        ],
      );

  List<Widget> _rangeBody() {
    final qMax = _n(_mQmax);
    final dpMax = _n(_mDpMax);
    final v = _n(_mValue);
    final ok = qMax != null && qMax > 0 && dpMax != null && dpMax > 0;
    final du = _mDpUnit.label;
    Widget result;
    if (!ok) {
      result = calcResult(
        big: '—',
        caption: '최대 유량과 최대 차압을 넣으십시오',
        lines: const [],
      );
    } else if (v == null || v < 0) {
      result = calcResult(
        big: '—',
        caption: _mFromDp ? '측정 차압을 넣으십시오' : '유량을 넣으십시오',
        lines: const [],
      );
    } else {
      final q = _mFromDp ? dpToFlow(v, dpMax, qMax) : v;
      final dp = _mFromDp ? v : flowToDp(v, dpMax, qMax);
      final qPct = q / qMax * 100;
      final dpPct = dp / dpMax * 100;
      result = calcResult(
        key: const Key('fm_range_result'),
        big: _mFromDp ? '${_sig(q)} $_qu' : '${_sig(dp)} $du',
        caption: _mFromDp ? '유량' : '차압',
        warn: dpPct > 100 + 1e-9,
        lines: [
          '유량 ${_fmt(qPct)}% · 차압 ${_fmt(dpPct)}%',
          '전송기 출력(차압 비례): ${_fmt(4 + 16 * dpPct / 100, 3)} mA',
          '전송기 출력(제곱근 출력 설정): ${_fmt(4 + 16 * qPct / 100, 3)} mA',
          if (dpPct > 100 + 1e-9) '측정 범위(최대 차압)를 초과했습니다.',
        ],
      );
    }
    return [
      calcField(
        'fm_qmax',
        '최대 유량 (100%)',
        _mQmax,
        '최대 차압일 때의 유량입니다. 유량계 데이터시트·오리피스 사이징 시트·DCS 태그 범위에 있습니다.',
      ),
      calcBox(
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: calcLabel('유량 단위', '결과와 표에 붙는 단위입니다. 계산에는 영향이 없습니다.'),
            ),
            Expanded(
              flex: 4,
              child: TextField(
                key: const Key('fm_qunit'),
                controller: _mQunit,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: fc.text,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
      _dpUnitChips('fm_du', _mDpUnit, (u) => setState(() => _mDpUnit = u)),
      calcField(
        'fm_dpmax',
        '최대 차압 ($du)',
        _mDpMax,
        '차압 전송기의 측정 범위 상한(URV)입니다. 전송기 명판·교정 성적서에 있습니다.',
      ),
      _pg._chips(
        '입력',
        '차압 → 유량: 전송기·차압계로 측정한 차압을 넣으면 유량을 계산합니다.\n'
            '유량 → 차압: 원하는 유량에서 걸리는 차압을 계산합니다. 교정할 때 가할 차압을 구할 때 씁니다.',
        [
          calcChip('fm_from_dp', '차압 → 유량', _mFromDp, () {
            setState(() => _mFromDp = true);
          }),
          calcChip('fm_from_q', '유량 → 차압', !_mFromDp, () {
            setState(() => _mFromDp = false);
          }),
        ],
      ),
      calcField(
        'fm_value',
        _mFromDp ? '측정 차압 ($du)' : '유량${_qu.isEmpty ? '' : ' ($_qu)'}',
        _mValue,
        _mFromDp
            ? '전송기 지시값·차압계 값입니다. 최대 차압과 같은 단위로 넣으십시오.'
            : '차압을 알고 싶은 유량입니다.',
      ),
      const SizedBox(height: 4),
      result,
      if (ok) ...[const SizedBox(height: 12), _sqrtTable(qMax, dpMax)],
      _pg._note(
        '유량은 차압의 제곱근에 비례합니다: Q = Qmax × √(ΔP / ΔPmax). 유량 50%일 때 차압은 25%입니다. '
        '차압 약 1% 아래 저유량 구간은 제조사 설정(선형·차단)에 따라 다릅니다.',
      ),
    ];
  }

  Widget _sqrtTable(double qMax, double dpMax) {
    const pts = [0.0, 25.0, 50.0, 75.0, 100.0];
    return Container(
      key: const Key('fm_table'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fc.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '제곱근 환산표',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: fc.text,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              calcChip('fm_by_flow', '유량 % 기준', _mByFlow, () {
                setState(() => _mByFlow = true);
              }),
              calcChip('fm_by_dp', '차압 % 기준', !_mByFlow, () {
                setState(() => _mByFlow = false);
              }),
            ],
          ),
          const SizedBox(height: 8),
          _row('유량', '차압', 'mA(차압)', head: true),
          for (final p in pts)
            () {
              final qPct = _mByFlow ? p : 10 * math.sqrt(p);
              final dpPct = _mByFlow ? p * p / 100 : p;
              return _row(
                '${_fmt(qPct)}%\n${_sig(qMax * qPct / 100)} $_qu',
                '${_fmt(dpPct)}%\n${_sig(dpMax * dpPct / 100)} ${_mDpUnit.label}',
                _fmt(4 + 16 * dpPct / 100, 3),
              );
            }(),
        ],
      ),
    );
  }

  Widget _row(String a, String b, String c, {bool head = false}) {
    final st = TextStyle(
      fontSize: 14,
      fontWeight: head ? FontWeight.w800 : FontWeight.w600,
      color: head ? fc.textSub : fc.text,
      height: 1.3,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 4, child: Text(a, style: st)),
          Expanded(flex: 4, child: Text(b, style: st)),
          Expanded(
            flex: 3,
            child: Text(c, style: st, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  // ─────────────── 오리피스 ───────────────

  FluidState? get _oState {
    if (_oOil) {
      final r = _n(_oRho), v = _n(_oCst);
      return r == null || v == null ? null : oilState(r, v);
    }
    final t = _n(_oWaterT);
    return t == null ? null : waterState(t);
  }

  List<Widget> _orificeBody() {
    final s = _oState;
    final dPipe = _n(_oD);
    final bore = _n(_oBore);
    final dp = _n(_oDp);
    OrificeResult? r;
    if (s != null && dPipe != null && bore != null && dp != null) {
      r = orificeFlow(
        dPipeMm: dPipe,
        dBoreMm: bore,
        dpKpa: dp * _oDpUnit.kpa,
        fluid: s,
        tap: _oTap,
      );
    }
    Widget result;
    if (s == null) {
      result = calcResult(
        big: '—',
        caption: _oOil
            ? '기름 밀도와 동점도를 넣으십시오'
            : '물 온도를 ${_fmt(kWaterTable.first.$1, 0)}~${_fmt(kWaterTable.last.$1, 0)}°C로 넣으십시오',
        lines: const [],
      );
    } else if (r == null) {
      result = calcResult(
        big: '—',
        caption: '관 내경 D, 오리피스 구멍 d(D보다 작게), 차압을 넣으십시오',
        lines: const [],
      );
    } else {
      final out = r.outOfRange.isNotEmpty;
      result = calcResult(
        key: const Key('fm_orifice_result'),
        big: '${_sig(r.qM3s * 3600)} m³/h',
        caption: '유량 (${_oTap.label}, ISO 5167-2)',
        warn: out,
        lines: [
          '다른 단위: ${_sig(r.qM3s * 60000)} L/min · ${_sig(r.qmKgS * 3600)} kg/h',
          '유출 계수 C = ${_fmt(r.c, 4)} (Reader-Harris/Gallagher)',
          'β = d/D = ${_fmt(r.beta, 4)} · ReD = ${_int(r.reD)}',
          '영구 압력손실: ${_sig(r.lossKpa / _oDpUnit.kpa)} ${_oDpUnit.label} (차압의 ${_fmt(r.lossKpa / (dp! * _oDpUnit.kpa) * 100, 0)}%)',
          if (!out && r.uncertaintyPct != null)
            'C의 불확도: ±${_fmt(r.uncertaintyPct!)}% (ISO 5167-2 5.3.3.1)',
          if (out)
            'ISO 5167-2 적용 범위 밖: ${r.outOfRange.join(', ')}. 이 값은 참고로만 쓰십시오.',
        ],
      );
    }
    return [
      _pg._chips(
        '유체 (액체)',
        '물: 온도로 밀도·점도를 표에서 읽습니다. 기름: 밀도와 동점도를 넣습니다.\n'
            '기체·증기는 팽창 계수 계산이 더 필요해 넣지 않았습니다.',
        [
          calcChip('fm_o_water', '물', !_oOil, () {
            setState(() => _oOil = false);
          }),
          calcChip('fm_o_oil', '기름', _oOil, () {
            setState(() => _oOil = true);
          }),
        ],
      ),
      if (!_oOil)
        calcField('fm_o_waterT', '물 온도 (°C)', _oWaterT, '오리피스를 지나는 물의 온도입니다.')
      else ...[
        calcField(
          'fm_o_rho',
          '밀도 (kg/m³)',
          _oRho,
          '운전 온도에서의 밀도입니다. 제품 자료(TDS)에 있습니다.',
        ),
        calcField(
          'fm_o_cst',
          '동점도 (cSt = mm²/s)',
          _oCst,
          '운전 온도에서의 동점도입니다. 제품 자료에 40°C·100°C 값이 있습니다.',
        ),
      ],
      calcField(
        'fm_o_D',
        '관 내경 D (mm)',
        _oD,
        '오리피스 앞 관의 실제 내경입니다. 오리피스 사이징 시트·계기 데이터시트에 있습니다. '
            'ISO 5167-2는 50~1000mm에 적용합니다.',
      ),
      calcField(
        'fm_o_d',
        '오리피스 구멍 d (mm)',
        _oBore,
        '오리피스 판 구멍 지름입니다. 판 손잡이(탭)에 각인되어 있고 사이징 시트에도 있습니다. '
            'd/D(β)는 0.1~0.75, d는 12.5mm 이상이어야 합니다.',
      ),
      _pg._chips(
        '탭 위치',
        '차압을 빼내는 구멍 위치입니다. 플랜지 탭: 판 앞뒤 25.4mm(오리피스 플랜지). '
            '코너 탭: 판 바로 앞뒤. D·D/2 탭: 앞 D, 뒤 D/2. 사이징 시트에 적혀 있습니다.',
        [
          for (final t in OrificeTap.values)
            calcChip('fm_tap_${t.name}', t.label, _oTap == t, () {
              setState(() => _oTap = t);
            }),
        ],
      ),
      _dpUnitChips('fm_odu', _oDpUnit, (u) => setState(() => _oDpUnit = u)),
      calcField(
        'fm_o_dp',
        '차압 (${_oDpUnit.label})',
        _oDp,
        '오리피스 앞뒤 차압입니다. 차압 전송기 지시값을 넣습니다.',
      ),
      const SizedBox(height: 4),
      result,
      _pg._note(
        '액체만 계산합니다(팽창 계수 ε = 1). C는 레이놀즈 수에 따라 바뀌어 반복 계산합니다. '
        '판 가장자리 마모·휨, 앞뒤 직관 길이 부족은 오차를 키웁니다. 최종 값은 제작사 사이징 시트로 확인하십시오.',
      ),
    ];
  }
}
