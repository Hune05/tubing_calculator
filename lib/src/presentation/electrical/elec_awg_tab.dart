// 전기 계산기 AWG·kcmil 모드: 전선 굵기·전압강하 탭에서 "AWG·kcmil"을 누르면 이 화면을 쓴다.
// NEC 방식(수입 설비·미국식 제어반). 표는 awg_tables.dart(두 출처 이상 확인). SQ 모드는 그대로 둔다.
part of 'electric_calculator_page.dart';

extension _AwgTab on _ElectricCalculatorPageState {
  static const String _necNote =
      'NEC(미국 전기 규정) 기준입니다. KEC는 mm²(SQ) 전선으로 계산하므로 국내 설비는 SQ로 선정하십시오.';

  static const String _motorLabelNec = '전동기 부하 (×1.25, NEC 430.22)';
  static const String _motorGuideNec =
      'NEC 430.22: 연속 운전 전동기 1대의 전선은 전부하 전류의 125% 이상 허용전류로 선정합니다.\n'
      '명판 전류보다 NEC 430.250 표 전류를 쓰는 것이 원칙입니다(NEC 430.6).';

  /// SQ(mm²) / AWG·kcmil 선택. 전선 굵기·전압강하 탭이 같은 선택을 쓴다.
  Widget _unitPicker(String prefix) => _chipGroup(
    '굵기 단위',
    'SQ(mm²): 국내 전선(KS·KEC)입니다. 기본입니다.\n'
        'AWG·kcmil: 미국식 굵기입니다. 수입 설비·NEC 방식 제어반 배선을 확인할 때 씁니다. '
        '허용전류는 NEC 표 310.16, 저항은 NEC 9장 표 8로 계산합니다.\n'
        '전선 굵기·전압강하 탭이 같은 선택을 씁니다.',
    [
      calcChip('${prefix}_unit_sq', 'SQ (mm²)', !_awg, () {
        _set(() => _awg = false);
      }),
      calcChip('${prefix}_unit_awg', 'AWG·kcmil', _awg, () {
        _set(() => _awg = true);
      }),
    ],
  );

  String _awgText(AwgSize s) => '${s.label} (${fmt(s.mm2, 2)} mm²)';

  String _colLabel(NecColumn c) => switch (c) {
    NecColumn.c60 => '60°C',
    NecColumn.c75 => '75°C',
    NecColumn.c90 => '90°C',
  };

  /// 제어반 내부 배선 참고: UL 508A 표 28.1 값.
  String? _ul508aLine(AwgSize s) {
    final u = kUl508aT281[s.label];
    if (u == null) return null;
    return '참고: 제어반 내부 배선은 UL 508A 표 28.1 '
        '${u.$1 == null ? '' : '60°C ${u.$1}A, '}75°C ${u.$2}A입니다.';
  }

  String _sqEquivLine(AwgSize s) {
    final sq = sqAtLeast(s.mm2);
    return '${s.label} = ${fmt(s.mm2, 2)} mm²'
        '${sq == null ? '' : '. 같거나 굵은 SQ는 ${sqText(sq)}입니다'}.';
  }

  /// 통전 도체 수 입력(빈 칸이면 3).
  int get _awgCccN {
    final v = _num(_awgCcc);
    return v == null || v < 1 ? 3 : v.round();
  }

  double get _awgAmbC => _num(_awgAmb) ?? 30;

  List<Widget> _awgConditionFields() => [
    _chipGroup(
      '전선 절연 온도 (NEC 310.16 열)',
      '전선 피복에 표시된 최고 온도입니다.\n'
          '· 60°C: TW, UF\n· 75°C: THW, THWN, XHHW, USE\n'
          '· 90°C: THHN, THWN-2, XHHW-2\n'
          '표시를 모르면 60°C로 두면 안전합니다.',
      [
        for (final c in NecColumn.values)
          calcChip(
            'ec_awg_col_${necColumnTemp(c)}',
            _colLabel(c),
            _awgCol == c,
            () {
              _set(() => _awgCol = c);
            },
          ),
      ],
    ),
    _chipGroup(
      '단자 온도',
      'NEC 110.14(C)(1): 허용전류는 차단기·기기 단자 온도 열 값을 넘을 수 없습니다.\n'
          '· 자동: 100A 이하 회로는 60°C, 100A 초과는 75°C 열로 제한합니다.\n'
          '· 60°C·75°C: 기기 단자에 표시된 값이 있으면 고르십시오(예: 60/75°C 표시는 75°C).\n'
          '90°C 전선은 온도·가닥 보정에만 90°C 열을 쓰고, 결과는 단자 열 값 이하로 둡니다.\n'
          '설계 문자 B·C·D 전동기 회로는 75°C 이상 전선이면 75°C 열을 쓸 수 있습니다.',
      [
        calcChip('ec_awg_term_auto', '자동', _awgTerm == NecTerminal.auto, () {
          _set(() => _awgTerm = NecTerminal.auto);
        }),
        calcChip('ec_awg_term_60', '60°C', _awgTerm == NecTerminal.c60, () {
          _set(() => _awgTerm = NecTerminal.c60);
        }),
        calcChip('ec_awg_term_75', '75°C', _awgTerm == NecTerminal.c75, () {
          _set(() => _awgTerm = NecTerminal.c75);
        }),
      ],
    ),
    _field(
      'ec_awg_amb',
      '주위 온도 (°C)',
      _awgAmb,
      '전선 주위 온도입니다. NEC 310.16 기준은 30°C입니다. 제어반 내부는 40~50을 넣으십시오.',
    ),
    _field(
      'ec_awg_ccc',
      '관·케이블 속 통전 도체 수',
      _awgCcc,
      '같은 전선관·케이블 속에서 전류가 흐르는 도체 수입니다. 삼상 3선이면 3입니다. '
          '접지선은 세지 않습니다. 3을 넘으면 NEC 310.15(C)(1) 감소계수를 곱합니다.',
    ),
  ];

  // ② 전선 굵기(AWG)
  Widget _awgCableTab() {
    final negative = _anyNegative([
      _ib,
      _awgAmb,
      _awgCcc,
      _length,
      _pf2,
      _chkBreaker,
    ]);
    final notes = <String>[];
    final ibIn = _num(_ib);
    final load = ibIn == null || ibIn <= 0 ? null : ibIn;
    if (_num(_awgAmb) == null) notes.add('주위 온도 값이 없어 30°C로 계산했습니다.');
    final lenIn = _num(_length);
    final len = lenIn == null || lenIn <= 0 ? null : lenIn;
    final pfNotes = <String>[];
    final pf = _dc ? 1.0 : _pctOf(_pf2, 0.85, '역률', pfNotes);
    if (len != null && load != null) notes.addAll(pfNotes);
    final margin = _cableMotor ? 1.25 : 1.0;

    Widget result;
    String? summary;
    var warn = false;
    var basis = <String>[];
    if (negative) {
      result = _negativeResult('ec_cable_result');
    } else if (_checkMode) {
      final r = _awgCheckResult(load, margin, len, pf, notes);
      result = r.$1;
      summary = r.$2;
      warn = r.$3;
      basis = r.$4;
    } else if (load == null) {
      result = calcResult(
        key: const Key('ec_cable_result'),
        big: '—',
        caption: '부하 전류를 넣으면 굵기를 선정합니다',
        lines: const [_necNote],
      );
    } else {
      final c = chooseAwg(
        load: load,
        margin: margin,
        volts: _cv,
        phase: _cph,
        column: _awgCol,
        terminal: _awgTerm,
        ambientC: _awgAmbC,
        currentCarrying: _awgCccN,
        lengthM: len,
        pf: pf,
        supply: _supply,
        motor: _cableMotor,
      );
      final s = c.size;
      final a = c.amp;
      final dropOver = c.dropPct != null && c.dropPct! > c.dropLimitPct + 1e-9;
      warn = s == null || dropOver;
      final ocpd = s == null || _cableMotor
          ? null
          : necSmallConductorMaxOcpd(s);
      result = calcResult(
        key: const Key('ec_cable_result'),
        big: s == null ? '검토 필요' : s.label,
        caption: s == null
            ? '표 범위(500 kcmil)를 넘습니다'
            : 'NEC 310.16 기준 추천 굵기${_dc ? '(직류)' : ''}',
        warn: warn,
        lines: [
          if (s != null && a?.iz != null)
            '허용전류 ${fmt(a!.iz!, 1)}A ≥ 설계전류 ${fmt(c.ib, 1)}A',
          if (ocpd != null) '과전류 보호 장치는 ${ocpd}A 이하로 선정하십시오(NEC 240.4(D)).',
          if (c.dropChecked && c.dropV != null)
            '전압강하 ${fmt(c.dropV!, 2)}V (${fmt(c.dropPct!, 2)}%), '
                '${dropOver ? '한도 ${fmt(c.dropLimitPct, 2)}% 초과' : '한도 ${fmt(c.dropLimitPct, 2)}% 이내입니다.'}',
          if (!c.dropChecked) '길이를 넣으면 전압강하를 검토합니다.',
          if (s != null) _sqEquivLine(s),
          if (s != null) ?_ul508aLine(s),
          _necNote,
          ...notes,
          ...c.notes,
        ],
      );
      summary = s == null
          ? '검토 필요'
          : [
              s.label,
              if (a?.iz != null) '${fmt(a!.iz!, 1)}A',
              if (c.dropPct != null) '전압강하 ${fmt(c.dropPct!, 1)}%',
            ].join(' · ');
      basis = [
        if (c.ib != c.load)
          '설계전류 ${fmt(c.ib, 1)}A = 부하 ${fmt(c.load, 1)}A × 1.25 (NEC 430.22)',
        if (c.byAmpacity != null) '허용전류 기준 ${c.byAmpacity!.label}',
        if (c.byDrop != null)
          '전압강하 기준 ${c.byDrop!.label} (한도 ${fmt(c.dropLimitPct, 2)}%)',
        if (s != null && a != null) ..._awgAmpBasis(s, a),
        _cableMotor
            ? '전동기 회로 전선은 NEC 240.4(G)에 따라 430조로 보호하므로 240.4(D) 한도를 적용하지 않았습니다.'
            : '14·12·10 AWG는 과전류 보호 한도 15·20·30A 이하에서만 선정합니다(NEC 240.4(D)).',
        if (c.dropChecked) _awgVdFormula(_cph),
        if (c.dropChecked) _ElectricCalculatorPageState._supplyTotalLine,
      ];
    }

    return _page(sumKey: 'ec_sum_cable', summary: summary, warn: warn, [
      _systemPicker('ec_cable'),
      _unitPicker('ec_cable'),
      _chipGroup(
        '할 일',
        '굵기 선정: 부하 전류로 NEC 310.16 기준 AWG 굵기를 선정합니다.\n'
            '기존 회로 점검: 포설되어 있는 AWG 전선의 허용전류를 계산하고 부하·차단기와 비교합니다.',
        [
          calcChip('ec_mode_select', '굵기 선정', !_checkMode, () {
            _set(() => _checkMode = false);
          }),
          calcChip('ec_mode_check', '기존 회로 점검', _checkMode, () {
            _set(() => _checkMode = true);
          }),
        ],
      ),
      if (_checkMode)
        calcDropdown<AwgSize>(
          'ec_awg_chk_size',
          '전선 굵기',
          awgByLabel(_awgChk) ?? kAwgPowerSizes.first,
          kAwgPowerSizes,
          _awgText,
          (s) => _set(() => _awgChk = s.label),
          'AWG 번호가 작을수록 굵습니다. 4/0 AWG 다음은 kcmil(천 원형 밀)입니다. 괄호는 NEC 9장 표 8 단면적입니다.',
        ),
      _field(
        'ec_ib',
        _checkMode ? '부하 전류 (A, 선택)' : '부하 전류 (A)',
        _ib,
        _checkMode
            ? '부하 전류를 넣으면 허용전류와 전압강하를 점검합니다. 비워 두면 허용전류만 보입니다.'
            : '이 회로에 실제로 흐르는 전류입니다. 명판 전류나 "부하 전류" 탭의 결과를 넣으십시오.',
      ),
      calcSwitch(
        _motorLabelNec,
        _cableMotor,
        (v) => _set(() => _cableMotor = v),
        _motorGuideNec,
        key: 'ec_cable_motor',
      ),
      if (_checkMode)
        _field(
          'ec_chk_breaker',
          '차단기 정격 (A, 선택)',
          _chkBreaker,
          '설치된 차단기·퓨즈의 정격전류입니다. 비워 두면 설계전류와 허용전류만 비교합니다.',
        ),
      ..._awgConditionFields(),
      _field(
        'ec_length',
        '편도 길이 (m)',
        _length,
        '전원에서 부하까지 전선 한 가닥 길이입니다. 왕복이 아닙니다. 비워 두면 전압강하는 검토하지 않습니다.',
      ),
      if (!_dc)
        _field(
          'ec_pf2',
          '역률 (%)',
          _pf2,
          '전압강하 계산에 씁니다. 전동기 85, 히터·저항 부하 100을 넣으십시오. 비우면 85로 계산합니다.',
        ),
      _supplyDropdown('ec_supply'),
      const SizedBox(height: 12),
      result,
      if (basis.isNotEmpty) _basis('ec_cable_basis', basis),
    ]);
  }

  List<String> _awgAmpBasis(AwgSize s, AwgAmpacity a) {
    final base = necAmpacity(s, _awgCol);
    final kt = necTempFactor(_awgAmbC, _awgCol);
    final kadj = necAdjustFactor(_awgCccN);
    return [
      if (base != null && kt != null && a.corrected != null)
        '${s.label} ${_colLabel(_awgCol)} 열 ${base}A × 온도 보정 ${fmt(kt, 2)} × 가닥 감소 ${fmt(kadj, 2)} '
            '= ${fmt(a.corrected!, 1)}A',
      if (a.terminalLimit != null)
        '단자 ${_colLabel(a.terminal)} 열 ${a.terminalLimit}A 이하 (NEC 110.14(C))',
      '기준: NEC 표 310.16(구리, 통전 도체 3가닥 이하, 30°C), 310.15(B)(1) 온도 보정, '
          '310.15(C)(1) 가닥 감소 (주위 ${fmt(_awgAmbC)}°C, 통전 도체 $_awgCccN가닥)',
    ];
  }

  (Widget, String?, bool, List<String>) _awgCheckResult(
    double? load,
    double margin,
    double? len,
    double pf,
    List<String> notes,
  ) {
    final s = awgByLabel(_awgChk) ?? kAwgPowerSizes.first;
    final ib = load == null ? null : load * margin;
    final brIn = _num(_chkBreaker);
    final br = brIn == null || brIn <= 0 ? null : brIn;
    final a = awgAmpacity(
      s,
      column: _awgCol,
      terminal: _awgTerm,
      circuitA: br ?? ib ?? 0,
      ambientC: _awgAmbC,
      currentCarrying: _awgCccN,
    );
    final iz = a.iz;
    final lines = <String>[];
    var fail = false;
    final ocpd = _cableMotor ? null : necSmallConductorMaxOcpd(s);
    if (iz == null) {
      lines.add(
        '주위 온도 ${fmt(_awgAmbC)}°C가 ${_colLabel(_awgCol)} 전선의 보정표 범위를 넘습니다.',
      );
    } else {
      final izT = fmt(iz, 1);
      if (ib != null) {
        if (ib <= iz + 1e-9) {
          lines.add('설계전류 ${fmt(ib, 1)}A ≤ 허용전류 ${izT}A: 이내입니다.');
        } else {
          fail = true;
          lines.add('설계전류 ${fmt(ib, 1)}A가 허용전류 ${izT}A를 초과합니다.');
        }
      }
      if (br != null) {
        if (ib != null && ib > br + 1e-9) {
          fail = true;
          lines.add('설계전류 ${fmt(ib, 1)}A가 차단기 ${fmt(br)}A를 초과합니다.');
        }
        if (br <= iz + 1e-9) {
          lines.add('차단기 ${fmt(br)}A ≤ 허용전류 ${izT}A: 이내입니다.');
        } else if (!_cableMotor) {
          fail = true;
          lines.add('차단기 ${fmt(br)}A가 허용전류 ${izT}A를 초과합니다.');
        } else {
          lines.add(
            '차단기 ${fmt(br)}A가 허용전류 ${izT}A를 초과합니다. 전동기 회로는 NEC 430조 표로 차단기 범위를 확인하십시오.',
          );
        }
        if (ocpd != null && br > ocpd + 1e-9) {
          fail = true;
          lines.add('${s.label} 과전류 보호 한도 ${ocpd}A를 초과합니다(NEC 240.4(D)).');
        }
      }
      if (ib == null && br == null) {
        lines.add('부하 전류나 차단기 정격을 넣으면 허용전류와 비교합니다.');
      }
      if (ocpd != null && br == null) {
        lines.add('과전류 보호 장치는 ${ocpd}A 이하로 선정하십시오(NEC 240.4(D)).');
      }
    }
    double? dv;
    double? pct;
    final limit = voltageDropLimit(_supply, len ?? 0);
    if (len != null && load != null && _cv > 0) {
      dv = awgVoltageDrop(
        current: load,
        lengthM: len,
        size: s,
        phase: _cph,
        pf: pf,
      );
      pct = dv / _cv * 100;
    }
    final dropOver = pct != null && pct > limit + 1e-9;
    if (dv != null) {
      lines.add(
        '전압강하 ${fmt(dv, 2)}V (${fmt(pct!, 2)}%), '
        '${dropOver ? '한도 ${fmt(limit, 2)}% 초과. 굵기를 올리거나 길이를 줄이십시오.' : '한도 ${fmt(limit, 2)}% 이내입니다.'}',
      );
    } else if (len == null) {
      lines.add('길이를 넣으면 전압강하를 검토합니다.');
    } else {
      lines.add('부하 전류를 넣으면 전압강하를 검토합니다.');
    }
    lines.add(_sqEquivLine(s));
    final ul = _ul508aLine(s);
    if (ul != null) lines.add(ul);
    lines.add(_necNote);
    lines.addAll(notes);
    final warn = fail || dropOver || iz == null;
    final result = calcResult(
      key: const Key('ec_cable_result'),
      big: iz == null ? '검토 필요' : '${fmt(iz, 1)} A',
      caption: iz == null
          ? '${s.label} 허용전류를 계산할 수 없습니다'
          : '${s.label} 허용전류 (NEC)',
      warn: warn,
      lines: lines,
    );
    final checked = ib != null || br != null;
    final summary = iz == null
        ? '검토 필요'
        : [
            '${s.label} 허용전류 ${fmt(iz, 1)}A',
            if (checked) fail ? '점검 필요' : '조건 만족',
            if (pct != null) '전압강하 ${fmt(pct, 1)}%',
          ].join(' · ');
    final basis = [
      if (ib != null && load != null && ib != load)
        '설계전류 ${fmt(ib, 1)}A = 부하 ${fmt(load, 1)}A × 1.25 (NEC 430.22)',
      ..._awgAmpBasis(s, a),
      if (dv != null) _awgVdFormula(_cph),
      if (dv != null) _ElectricCalculatorPageState._supplyTotalLine,
    ];
    return (result, summary, warn, basis);
  }

  String _awgVdFormula(Phase ph) => ph == Phase.dc
      ? '식: ΔU = 2 × I × L × R (직류, 리액턴스 없음), R은 75°C 저항(NEC 9장 표 8, 구리 연선)'
      : '식: ΔU = ${ph == Phase.three ? '√3' : '2'} × I × L × (R cosφ + X sinφ), '
            'R은 75°C 저항(NEC 9장 표 8, 구리 연선), X = 0.096 Ω/km(60Hz, Schneider EIG)';

  // ③ 전압강하(AWG)
  Widget _awgVdTab() {
    final negative = _anyNegative([_vdI, _vdLen, _vdPf]);
    final ph = _dc ? Phase.dc : _phase;
    final volts = _dc ? _dcVolts : _volts;
    final s = awgByLabel(_vdAwg) ?? kAwgSizes[3];
    final i = _num(_vdI);
    final lenIn = _num(_vdLen);
    final len = lenIn == null || lenIn <= 0 ? null : lenIn;
    final notes = <String>[];
    final ok = !negative && i != null && i > 0;
    final pf = _dc ? 1.0 : _pctOf(_vdPf, 0.85, '역률', ok ? notes : []);
    final dv = !ok || len == null
        ? null
        : awgVoltageDrop(current: i, lengthM: len, size: s, phase: ph, pf: pf);
    final limit = voltageDropLimit(_supply, len ?? 0);
    final pct = dv == null ? null : dv / volts * 100;
    final maxLen = !ok
        ? null
        : maxLengthForDrop(
            current: i,
            size: 0,
            phase: ph,
            volts: volts,
            pf: pf,
            supply: _supply,
            rOhmPerKm: s.r75,
          );
    final over = pct != null && pct > limit + 1e-9;
    String? summary;
    if (pct != null) {
      summary =
          '${fmt(pct, 2)}% · ${over ? '한도 ${fmt(limit, 2)}% 초과' : '한도 ${fmt(limit, 2)}% 이내'}';
    }
    return _page(sumKey: 'ec_sum_vd', summary: summary, warn: over, [
      _systemPicker('ec_vd'),
      _unitPicker('ec_vd'),
      calcDropdown<AwgSize>(
        'ec_vd_awg_size',
        '전선 굵기',
        s,
        kAwgSizes,
        _awgText,
        (v) => _set(() => _vdAwg = v.label),
        'AWG 번호가 작을수록 굵습니다. 18·16 AWG는 제어 배선용입니다. 괄호는 NEC 9장 표 8 단면적입니다.',
      ),
      _field('ec_vd_i', '전류 (A)', _vdI, '회로에 흐르는 전류입니다.'),
      _field('ec_vd_len', '편도 길이 (m)', _vdLen, '전선 한 가닥 길이입니다(왕복 아님).'),
      if (!_dc)
        _field('ec_vd_pf', '역률 (%)', _vdPf, '전동기 85, 히터 100. 비우면 85로 계산합니다.'),
      _supplyDropdown('ec_vd_supply'),
      const SizedBox(height: 12),
      if (negative)
        _negativeResult('ec_vd_result')
      else
        calcResult(
          key: const Key('ec_vd_result'),
          big: pct == null ? '— %' : '${fmt(pct, 2)} %',
          caption: dv == null
              ? (ok ? '길이를 넣으면 전압강하를 계산합니다' : '전류와 길이를 넣으십시오')
              : '전압강하 ${fmt(dv, 2)} V',
          warn: over,
          lines: [
            if (pct != null)
              over
                  ? '한도 ${fmt(limit, 2)}% 초과. 굵기를 올리거나 길이를 줄이십시오.'
                  : '한도 ${fmt(limit, 2)}% 이내입니다.',
            if (maxLen != null) '한도 이내 최대 편도 길이 약 ${fmt(maxLen, 0)} m',
            '${s.label} 저항 ${fmt(s.r75, 4)} Ω/km (75°C, NEC 9장 표 8)',
            if (_dc) '직류 제어·계장 회로는 기기 최소 동작 전압으로도 확인하십시오.',
            ...notes,
          ],
        ),
      _basis('ec_vd_basis', [
        _awgVdFormula(ph),
        '최대 길이: 한도(100m를 넘으면 1m당 0.005%, 최대 0.5% 더함)와 전압강하가 같아지는 길이',
        _ElectricCalculatorPageState._supplyTotalLine,
      ]),
    ]);
  }
}
