// 유량 계산 "유량계 점검" 탭: 유량 전송기 명판·설정의 측정 범위와 출력 방식을 넣고, 설치·루프 점검 때
// 잰 루프 전류(mA)와 표시창·DCS 지시값이 맞는지 본다. 계산은 flow_meter_check.dart.
part of 'flow_calc_page.dart';

mixin _FlowMeterCheckTab on State<FlowCalcPage>, CalcFormParts<FlowCalcPage> {
  _FlowCalcPageState get _pgc => this as _FlowCalcPageState;

  MeterType _mcType = MeterType.dp;
  DpOut _mcDpOut = DpOut.sqrtOut;
  DpUnit _mcDpUnit = DpUnit.kpa;
  final _mcLrv = TextEditingController(text: '0');
  final _mcUrv = TextEditingController();
  final _mcUnit = TextEditingController(text: 'm³/h');
  final _mcDpMax = TextEditingController();
  final _mcCut = TextEditingController();
  final _mcTol = TextEditingController();
  final _mcMa = TextEditingController();
  final _mcInd = TextEditingController();

  Map<String, TextEditingController> get _mcFields => {
    'mcLrv': _mcLrv,
    'mcUrv': _mcUrv,
    'mcUnit': _mcUnit,
    'mcDpMax': _mcDpMax,
    'mcCut': _mcCut,
    'mcTol': _mcTol,
    'mcMa': _mcMa,
    'mcInd': _mcInd,
  };

  Map<String, Object> _mcDraftJson() => {
    'type': _mcType.name,
    'dpOut': _mcDpOut.name,
    'dpUnit': _mcDpUnit.name,
  };

  void _applyMcDraft(Object? m) {
    if (m is! Map) return;
    T pick<T extends Enum>(List<T> values, Object? name, T now) =>
        values.firstWhere((v) => v.name == name, orElse: () => now);
    _mcType = pick(MeterType.values, m['type'], _mcType);
    _mcDpOut = pick(DpOut.values, m['dpOut'], _mcDpOut);
    _mcDpUnit = pick(DpUnit.values, m['dpUnit'], _mcDpUnit);
  }

  double? _mcn(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', ''));

  String get _mcu => _mcUnit.text.trim();

  bool get _mcIsDp => _mcType == MeterType.dp;

  void _setMcType(MeterType t) => setState(() {
    // 질량식은 kg/h가 보통이다. 단위를 손대지 않았을 때만 바꾼다.
    final u = _mcUnit.text.trim();
    if (t == MeterType.coriolis && u == 'm³/h') _mcUnit.text = 'kg/h';
    if (t != MeterType.coriolis && u == 'kg/h') _mcUnit.text = 'm³/h';
    _mcType = t;
  });

  String get _typeGuide =>
      '차압식: 오리피스·벤추리·피토관 + 차압 전송기. 명판의 측정 범위는 차압(예: 0~25kPa)이고, '
      '출력은 선형(LINEAR, 차압 비례) 또는 제곱근(SQRT, 유량 비례)입니다.\n'
      '전자식·와류식·터빈·질량식: mA가 유량에 비례합니다. 명판이나 변환기 설정의 측정 범위(Range)를 넣습니다. '
      '와류식·터빈의 K-factor는 펄스 출력에 쓰는 값이라 mA 점검에는 필요 없습니다.';

  Widget _meterCheckTab() {
    final isDp = _mcIsDp;
    final lrv = isDp ? 0.0 : _mcn(_mcLrv);
    final urv = _mcn(_mcUrv);
    final rangeOk = lrv != null && urv != null && urv > lrv;
    final dpMax = _mcn(_mcDpMax);
    final hasDpMax = isDp && dpMax != null && dpMax > 0;

    return _pgc._page([
      _pgc._chips('유량계 종류', _typeGuide, [
        for (final t in MeterType.values)
          calcChip('mc_type_${t.name}', t.label, _mcType == t, () {
            _setMcType(t);
          }),
      ]),
      if (isDp)
        _pgc._chips(
          '전송기 출력',
          '명판·설정(HART의 Transfer function, 요꼬가와 Output mode)을 보십시오.\n'
              '제곱근(SQRT): 전송기가 제곱근을 해서 mA가 유량에 비례합니다. DCS는 선형으로 받습니다.\n'
              '차압 그대로(LINEAR): mA가 차압에 비례합니다. DCS·지시계에서 제곱근을 해야 합니다.\n'
              '제곱근은 한 곳에서만 해야 합니다.',
          [
            calcChip(
              'mc_out_sqrt',
              '제곱근(SQRT)',
              _mcDpOut == DpOut.sqrtOut,
              () => setState(() => _mcDpOut = DpOut.sqrtOut),
            ),
            calcChip(
              'mc_out_lin',
              '차압 그대로(LINEAR)',
              _mcDpOut == DpOut.linearDp,
              () => setState(() => _mcDpOut = DpOut.linearDp),
            ),
          ],
        ),
      if (!isDp)
        calcField(
          'mc_lrv',
          '측정 범위 하한 (0%)',
          _mcLrv,
          '4mA일 때의 유량입니다. 보통 0입니다. 양방향 전자식은 음수(역방향 최대)일 수 있습니다.',
          signed: true,
        ),
      calcField(
        'mc_urv',
        isDp ? '최대 유량 (100%)' : '측정 범위 상한 (100%)',
        _mcUrv,
        isDp
            ? '20mA(최대 차압)일 때의 유량입니다. 오리피스 사이징 시트·계기 데이터시트·DCS 태그 범위에 있습니다.'
            : '20mA일 때의 유량입니다. 명판의 Range·Span, 변환기 설정, DCS 태그 범위가 모두 같아야 합니다.',
      ),
      calcBox(
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: calcLabel(
                '유량 단위',
                '결과와 표에 붙는 단위입니다. 계산에는 영향이 없습니다. 측정 범위와 지시값을 같은 단위로 넣으십시오.',
              ),
            ),
            Expanded(
              flex: 4,
              child: TextField(
                key: const Key('mc_unit'),
                controller: _mcUnit,
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
      if (isDp) ...[
        _pgc._dpUnitChips(
          'mc_du',
          _mcDpUnit,
          (u) => setState(() => _mcDpUnit = u),
        ),
        calcField(
          'mc_dpmax',
          '최대 차압 (${_mcDpUnit.label}, 선택)',
          _mcDpMax,
          '전송기 명판의 측정 범위 상한(URV)입니다. 넣으면 아래 표에 점마다 걸리는 차압이 나옵니다.',
        ),
      ],
      calcField(
        'mc_cut',
        '소유량 차단 (%, 선택)',
        _mcCut,
        '설정된 유량 % 아래는 0으로 표시하는 기능입니다(Low flow cut-off). 전송기나 DCS 설정에 있습니다. '
            '이 값 아래에서 지시가 0이면 정상입니다.',
      ),
      calcField(
        'mc_tol',
        '허용오차 (±스팬 %, 선택)',
        _mcTol,
        '교정 절차서·제조사 사양의 허용오차입니다. 넣으면 합격·불합격을 봅니다. 앱에 정해 둔 값은 없습니다.',
      ),
      calcField(
        'mc_ma',
        '측정 전류 (mA)',
        _mcMa,
        '루프에 직렬로 건 멀티미터·루프 교정기 값이나 HART 통신기의 출력 전류(AO)입니다.',
      ),
      calcField(
        'mc_ind',
        '지시값 (선택)',
        _mcInd,
        '같은 때에 읽은 전송기 표시창이나 DCS 화면의 유량입니다. 측정 범위와 같은 단위로 넣으십시오.',
        signed: true,
      ),
      const SizedBox(height: 4),
      _mcResult(lrv, urv, rangeOk),
      if (rangeOk) ...[
        const SizedBox(height: 12),
        _mcTable(lrv, urv, hasDpMax ? dpMax : null),
      ],
      _pgc._note(
        isDp
            ? '차압식: 유량 % = 10 × √(차압 %). 유량 50%에서 차압은 25%입니다. '
                  '제곱근(SQRT) 출력이면 유량 50%에서 12mA, 차압 그대로(LINEAR)면 8mA입니다.'
            : 'mA = 4 + 16 × (유량 − 하한) / (상한 − 하한). 유량 50%에서 12mA입니다.',
      ),
      _pgc._note(
        '루프 전류는 NAMUR NE43 기준으로 3.8~20.5mA가 유효한 측정, 3.6mA 이하·21mA 이상은 고장 신호입니다.',
      ),
    ]);
  }

  Widget _mcResult(double? lrv, double? urv, bool rangeOk) {
    if (!rangeOk) {
      return calcResult(
        big: '—',
        caption: _mcIsDp ? '최대 유량을 넣으십시오' : '측정 범위 하한과 상한(하한보다 크게)을 넣으십시오',
        lines: const [],
      );
    }
    final lo = lrv!, hi = urv!;
    final ma = _mcn(_mcMa);
    final ind = _mcn(_mcInd);
    final tol = _mcn(_mcTol);
    final cut = _mcn(_mcCut);
    final u = _mcu.isEmpty ? '' : ' $_mcu';

    // 전류 없이 지시값만: 그 지시값이면 나와야 할 전류.
    if (ma == null) {
      if (ind == null) {
        return calcResult(
          big: '—',
          caption: '측정 전류나 지시값을 넣으십시오',
          lines: const [],
        );
      }
      final pct = pvToPct(ind, lo, hi);
      return calcResult(
        key: const Key('mc_result'),
        big: '${_fmt(meterMa(pct, _mcType, _mcDpOut), 3)} mA',
        caption: '이 지시값이면 나와야 할 전류',
        lines: [
          '유량 ${_fmt(pct)}%'
              '${_mcIsDp ? ' · 차압 ${_fmt(dpPctOfFlow(pct))}%' : ''}',
          '측정 전류를 넣으면 지시값과 맞는지 봅니다.',
        ],
      );
    }

    final r = checkMeter(
      ma: ma,
      lrv: lo,
      urv: hi,
      type: _mcType,
      dpOut: _mcDpOut,
      indicated: ind,
      tolSpanPct: tol != null && tol > 0 ? tol : null,
      cutPct: cut,
    );
    final st = signalState(ma);
    final bad =
        st == SignalState.failLow ||
        st == SignalState.failHigh ||
        st == SignalState.gapLow ||
        st == SignalState.gapHigh;
    final lines = <String>[
      if (ind != null && r.pass != null)
        '이 전류면 보여야 할 지시값: ${_sig(r.expected)}$u',
      '유량 ${_fmt(r.flowPct)}%'
          '${_mcIsDp ? ' · 차압 ${_fmt(dpPctOfFlow(r.flowPct))}%' : ''}',
      if (r.cutOff) '소유량 차단(${_fmt(cut!)}%) 아래라 0으로 표시되는 것이 정상입니다.',
      if (st != SignalState.normal) _mcSignalText(st),
      if (ind != null) ...[
        '지시값 차이: ${_sig(ind - r.expected)}$u (스팬 ${_fmt(r.errSpanPct!)}%'
            '${r.errReadPct == null ? '' : ', 지시값 ${_fmt(r.errReadPct!)}%'})',
        '이 지시값이면 나와야 할 전류: '
            '${_fmt(meterMa(pvToPct(ind, lo, hi), _mcType, _mcDpOut), 3)} mA',
      ],
      if (r.mistake == SqrtMistake.twice)
        _mcIsDp
            ? '지시값이 제곱근을 두 번 한 값과 맞습니다. 전송기가 제곱근(SQRT) 출력인데 DCS에서도 제곱근을 하고 있는지 보십시오.'
            : '지시값이 제곱근을 한 값과 맞습니다. DCS 태그에 제곱근(SQRT)이 켜져 있는지 보십시오.',
      if (r.mistake == SqrtMistake.none)
        '지시값이 제곱근을 안 한 값과 맞습니다. 전송기가 차압 그대로(LINEAR)인데 DCS에서도 제곱근을 안 하고 있는지 보십시오.',
      if (ind != null && r.pass == false && r.mistake == null)
        '측정 범위(명판·전송기 설정·DCS 태그)가 서로 같은지 먼저 보십시오.',
    ];

    if (ind != null && r.pass != null) {
      return calcResult(
        key: const Key('mc_result'),
        big: r.pass! ? '합격' : '불합격',
        caption: '지시값 점검 (허용 ±${_fmt(tol!)}% 스팬)',
        warn: !r.pass! || bad,
        lines: lines,
      );
    }
    return calcResult(
      key: const Key('mc_result'),
      big: '${_sig(r.expected)}$u',
      caption: '이 전류면 보여야 할 지시값',
      warn: bad,
      lines: lines,
    );
  }

  String _mcSignalText(SignalState st) => switch (st) {
    SignalState.failLow => '3.6mA 이하: 고장 신호(하한)입니다. 단선·전원·계기 고장을 점검하십시오.',
    SignalState.gapLow => '3.6~3.8mA: 정상 측정 구간이 아닙니다. 계기의 고장 신호 설정값인지 보십시오.',
    SignalState.underRange => '3.8~4mA: 0% 아래지만 유효한 측정입니다. 역류나 영점 틀어짐을 보십시오.',
    SignalState.normal => '',
    SignalState.overRange =>
      '20~20.5mA: 100%를 넘었지만 유효한 측정입니다. 측정 범위가 작지 않은지 보십시오.',
    SignalState.gapHigh => '20.5~21mA: 정상 측정 구간이 아닙니다. 포화값·고장 신호 설정값인지 보십시오.',
    SignalState.failHigh => '21mA 이상: 고장 신호(상한)입니다.',
  };

  Widget _mcTable(double lrv, double urv, double? dpMax) {
    const pts = [0.0, 25.0, 50.0, 75.0, 100.0];
    final isDp = _mcIsDp;
    return Container(
      key: const Key('mc_table'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fc.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '점검표',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: fc.text,
            ),
          ),
          const SizedBox(height: 8),
          _pgc._row('유량', isDp ? '차압' : '', 'mA', head: true),
          for (final p in pts)
            _pgc._row(
              '${_fmt(p)}%\n${_sig(pctToPv(p, lrv, urv))} $_mcu',
              isDp
                  ? '${_fmt(dpPctOfFlow(p))}%'
                        '${dpMax == null ? '' : '\n${_sig(dpMax * dpPctOfFlow(p) / 100)} ${_mcDpUnit.label}'}'
                  : '',
              _fmt(meterMa(p, _mcType, _mcDpOut), 3),
            ),
        ],
      ),
    );
  }
}
