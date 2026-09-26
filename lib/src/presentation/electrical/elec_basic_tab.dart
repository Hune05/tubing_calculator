// 전기 계산기 ⑤ 기초 계산 탭: 옴의 법칙·전력, 교류 전력, Y·Δ 결선, 전력량·요금, 도체 저항, 주파수.
// 식은 basic_calc.dart. 칸 값은 _ElectricCalculatorPageState에 있고 같은 저장 칸에 남는다.
part of 'electric_calculator_page.dart';

/// 기초 계산 탭의 항목.
enum BasicSection { ohm, acPower, starDelta, energy, resistance, frequency }

extension on BasicSection {
  String get label => switch (this) {
    BasicSection.ohm => '옴의 법칙·전력',
    BasicSection.acPower => '교류 전력',
    BasicSection.starDelta => 'Y·Δ 결선',
    BasicSection.energy => '전력량·요금',
    BasicSection.resistance => '도체 저항',
    BasicSection.frequency => '주파수(Hz)',
  };
}

/// 유효숫자 약 4자리로 보인다(0.0123 → "0.0123", 1234.5 → "1235").
String sig(double v) {
  if (!v.isFinite) return '—';
  final a = v.abs();
  if (a == 0) return '0';
  final d = a >= 1000
      ? 0
      : a >= 100
      ? 1
      : a >= 10
      ? 2
      : a >= 1
      ? 3
      : (3 - (math.log(a) / math.ln10).floor()).clamp(0, 9);
  return fmt(v, d);
}

extension _BasicTab on _ElectricCalculatorPageState {
  Widget _basicTab() {
    final (body, summary) = switch (_bsSec) {
      BasicSection.ohm => _ohmSection(),
      BasicSection.acPower => _acPowerSection(),
      BasicSection.starDelta => _starDeltaSection(),
      BasicSection.energy => _energySection(),
      BasicSection.resistance => _resistanceSection(),
      BasicSection.frequency => _frequencySection(),
    };
    return _page(sumKey: 'ec_sum_basic', summary: summary, [
      _chipGroup(
        '계산 항목',
        '옴의 법칙·전력: V·I·R·P 중 두 값으로 나머지를 계산합니다.\n'
            '교류 전력: 전압·전류·역률로 kW·kvar·kVA를 계산합니다.\n'
            'Y·Δ 결선: 선간전압·상전압, 선전류·상전류를 바꿉니다.\n'
            '전력량·요금: kW와 사용 시간으로 kWh와 요금을 계산합니다.\n'
            '도체 저항: 구리·알루미늄 도체의 저항과 직렬·병렬 합성 저항을 계산합니다.\n'
            '주파수(Hz): 주기, 동기속도·슬립, 발전기 주파수, 리액턴스, 공진 주파수를 계산합니다.',
        [
          for (final s in BasicSection.values)
            calcChip('ec_bs_${s.name}', s.label, _bsSec == s, () {
              _set(() => _bsSec = s);
            }),
        ],
      ),
      ...body,
    ]);
  }

  /// 음수가 있으면 "입력 확인" 결과.
  bool _neg(List<TextEditingController> cs) => _anyNegative(cs);

  // ─────────────── 옴의 법칙·전력 ───────────────

  (List<Widget>, String?) _ohmSection() {
    final cs = [_ohmV, _ohmI, _ohmR, _ohmP];
    final negative = _neg(cs);
    final r = negative
        ? null
        : ohmLaw(
            v: _num(_ohmV),
            i: _num(_ohmI),
            r: _num(_ohmR),
            p: _num(_ohmP),
          );
    final filled = cs.where((c) => (_num(c) ?? 0) > 0).length;
    final names = {'V': '전압', 'I': '전류', 'R': '저항', 'P': '전력'};
    String p(double w) =>
        w >= 1000 ? '${sig(w)} W (${sig(w / 1000)} kW)' : '${sig(w)} W';
    final out = r == null
        ? null
        : [
            if (!r.from.contains('V')) '${sig(r.v)} V',
            if (!r.from.contains('I')) '${sig(r.i)} A',
            if (!r.from.contains('R')) '${sig(r.r)} Ω',
            if (!r.from.contains('P'))
              r.p >= 1000 ? '${sig(r.p / 1000)} kW' : '${sig(r.p)} W',
          ];
    return (
      [
        _field('ec_ohm_v', '전압 V (V)', _ohmV, '회로 양 끝의 전압입니다. 두 값만 넣으십시오.'),
        _field('ec_ohm_i', '전류 I (A)', _ohmI, '흐르는 전류입니다.'),
        _field(
          'ec_ohm_r',
          '저항 R (Ω)',
          _ohmR,
          '저항 값입니다. 히터는 명판 전압·전력으로 계산할 수도 있습니다.',
        ),
        _field(
          'ec_ohm_p',
          '전력 P (W)',
          _ohmP,
          '소비 전력(W)입니다. kW면 1000을 곱해 넣으십시오.',
        ),
        const SizedBox(height: 12),
        if (negative)
          _negativeResult('ec_ohm_result')
        else
          calcResult(
            key: const Key('ec_ohm_result'),
            big: out == null ? '—' : out.join(' · '),
            caption: r == null
                ? 'V·I·R·P 중 두 값을 넣으십시오'
                : '${names[r.from[0]]}·${names[r.from[1]]}로 계산',
            lines: [
              if (r != null) ...[
                'V = ${sig(r.v)} V, I = ${sig(r.i)} A',
                'R = ${sig(r.r)} Ω, P = ${p(r.p)}',
              ],
              if (filled > 2) '세 칸 이상 넣으면 V·I·R·P 순서로 앞의 두 값만 씁니다.',
              '식: V = I × R, P = V × I = I² × R = V² ÷ R',
              '직류나 저항 부하(히터 등)에 씁니다. 교류 전동기는 역률이 있어 "교류 전력"을 쓰십시오.',
            ],
          ),
      ],
      out?.join(' · '),
    );
  }

  // ─────────────── 교류 전력 ───────────────

  (List<Widget>, String?) _acPowerSection() {
    final negative = _neg([_acV, _acI, _acKw, _acPf]);
    final notes = <String>[];
    final v = _num(_acV);
    final a = _num(_acI);
    final kwIn = _num(_acKw);
    final ready =
        !negative &&
        v != null &&
        v > 0 &&
        (_acFromKw ? (kwIn != null && kwIn > 0) : (a != null && a > 0));
    final pf = _pctOf(_acPf, 0.85, '역률', ready ? notes : []);
    final r = !ready
        ? null
        : _acFromKw
        ? acPowerFromKw(kw: kwIn!, pf: pf, volts: v, three: _acThree)
        : acPowerFromCurrent(volts: v, amps: a!, pf: pf, three: _acThree);
    final k = _acThree ? '√3 × ' : '';
    final summary = r == null
        ? null
        : _acFromKw
        ? '${sig(r.kva)} kVA · ${sig(r.amps)} A'
        : '${sig(r.kw)} kW · ${sig(r.kva)} kVA';
    return (
      [
        _chipGroup(
          '결선',
          '단상: S = V × I. 삼상: S = √3 × V × I (V는 선간전압, I는 선전류).',
          [
            calcChip('ec_ac_1', '단상', !_acThree, () {
              _set(() => _acThree = false);
            }),
            calcChip('ec_ac_3', '삼상', _acThree, () {
              _set(() => _acThree = true);
            }),
          ],
        ),
        _chipGroup(
          '아는 값',
          '전압·전류·역률: 측정한 전류로 kW·kvar·kVA를 계산합니다.\n'
              'kW·역률: 부하 전력으로 kVA·kvar와 전류를 계산합니다.',
          [
            calcChip('ec_ac_vi', '전압·전류·역률', !_acFromKw, () {
              _set(() => _acFromKw = false);
            }),
            calcChip('ec_ac_kw', 'kW·역률', _acFromKw, () {
              _set(() => _acFromKw = true);
            }),
          ],
        ),
        _field(
          'ec_ac_v',
          '선간전압 (V)',
          _acV,
          '회로의 선간 전압입니다. 고압(6600V 등)도 넣을 수 있습니다.',
        ),
        if (_acFromKw)
          _field('ec_ac_kw_in', '유효전력 (kW)', _acKw, '부하의 유효전력(kW)입니다.')
        else
          _field('ec_ac_i', '전류 (A)', _acI, '선전류입니다. 클램프 미터로 측정한 값을 넣으십시오.'),
        _field('ec_ac_pf', '역률 (%)', _acPf, '역률(cosφ)입니다. 비우면 85로 계산합니다.'),
        const SizedBox(height: 12),
        if (negative)
          _negativeResult('ec_ac_result')
        else
          calcResult(
            key: const Key('ec_ac_result'),
            big: r == null
                ? '—'
                : _acFromKw
                ? '${sig(r.kva)} kVA'
                : '${sig(r.kw)} kW',
            caption: r == null
                ? (_acFromKw ? '전압과 kW를 넣으십시오' : '전압과 전류를 넣으십시오')
                : (_acFromKw ? '피상전력' : '유효전력'),
            lines: [
              if (r != null) ...[
                '유효전력 P = ${sig(r.kw)} kW',
                '무효전력 Q = ${sig(r.kvar)} kvar',
                '피상전력 S = ${sig(r.kva)} kVA',
                if (_acFromKw) '전류 I = ${sig(r.amps)} A',
                '역률 ${fmt(r.pf * 100)}% (위상각 ${fmt(r.angleDeg, 1)}°)',
                ...notes,
              ],
              _acFromKw
                  ? '식: S = P ÷ cosφ, Q = √(S² − P²), I = S × 1000 ÷ (${k}V)'
                  : '식: S = ${k}V × I ÷ 1000, P = S × cosφ, Q = √(S² − P²)',
            ],
          ),
      ],
      summary,
    );
  }

  // ─────────────── Y·Δ 결선 ───────────────

  (List<Widget>, String?) _starDeltaSection() {
    final negative = _neg([_ydV, _ydI]);
    final vIn = _num(_ydV);
    final iIn = _num(_ydI);
    final v = vIn != null && vIn > 0 ? vIn : null;
    final i = iIn != null && iIn > 0 ? iIn : null;
    final r = negative || (v == null && i == null)
        ? null
        : starDelta(star: _ydStar, fromLine: _ydFromLine, volts: v, amps: i);
    String? big;
    if (r != null) {
      final parts = <String>[
        if (v != null)
          _ydFromLine ? '상전압 ${sig(r.phaseV!)} V' : '선간전압 ${sig(r.lineV!)} V',
        if (i != null)
          _ydFromLine ? '상전류 ${sig(r.phaseI!)} A' : '선전류 ${sig(r.lineI!)} A',
      ];
      big = parts.join(' · ');
    }
    return (
      [
        _chipGroup(
          '결선',
          'Y(성형): 선간전압 = √3 × 상전압, 선전류 = 상전류.\n'
              'Δ(삼각): 선간전압 = 상전압, 선전류 = √3 × 상전류.\n'
              '상 값은 권선(부하) 하나에 걸리는 전압과 흐르는 전류입니다.',
          [
            calcChip('ec_yd_star', 'Y(성형)', _ydStar, () {
              _set(() => _ydStar = true);
            }),
            calcChip('ec_yd_delta', 'Δ(삼각)', !_ydStar, () {
              _set(() => _ydStar = false);
            }),
          ],
        ),
        _chipGroup('아는 값', '선간 값: 선간전압·선전류를 넣습니다. 상 값: 권선 하나의 전압·전류를 넣습니다.', [
          calcChip('ec_yd_line', '선간 값', _ydFromLine, () {
            _set(() => _ydFromLine = true);
          }),
          calcChip('ec_yd_phase', '상 값', !_ydFromLine, () {
            _set(() => _ydFromLine = false);
          }),
        ]),
        _field(
          'ec_yd_v',
          _ydFromLine ? '선간전압 (V)' : '상전압 (V)',
          _ydV,
          _ydFromLine ? '선과 선 사이 전압입니다(예: 380).' : '권선 하나에 걸리는 전압입니다.',
        ),
        _field(
          'ec_yd_i',
          _ydFromLine ? '선전류 (A)' : '상전류 (A)',
          _ydI,
          _ydFromLine ? '전선 한 가닥에 흐르는 전류입니다.' : '권선 하나에 흐르는 전류입니다.',
        ),
        const SizedBox(height: 12),
        if (negative)
          _negativeResult('ec_yd_result')
        else
          calcResult(
            key: const Key('ec_yd_result'),
            big: big ?? '—',
            caption: r == null
                ? '전압이나 전류를 넣으십시오'
                : '${_ydStar ? 'Y(성형)' : 'Δ(삼각)'} 결선',
            lines: [
              if (r != null && r.lineV != null)
                '선간전압 ${sig(r.lineV!)} V, 상전압 ${sig(r.phaseV!)} V',
              if (r != null && r.lineI != null)
                '선전류 ${sig(r.lineI!)} A, 상전류 ${sig(r.phaseI!)} A',
              if (r != null && r.lineV != null && r.lineI != null)
                '피상전력 S = √3 × V선 × I선 = ${sig(math.sqrt(3) * r.lineV! * r.lineI! / 1000)} kVA',
              _ydStar ? '식: V선 = √3 × V상, I선 = I상' : '식: V선 = V상, I선 = √3 × I상',
              'Y-Δ 기동: Y로 기동하면 권선 전압이 1/√3이 되어 선전류와 토크가 Δ 직입 기동의 1/3입니다.',
            ],
          ),
      ],
      big,
    );
  }

  // ─────────────── 전력량·요금 ───────────────

  (List<Widget>, String?) _energySection() {
    final negative = _neg([_enKw, _enHours, _enDays, _enPrice]);
    final notes = <String>[];
    final kw = _num(_enKw);
    final ok = !negative && kw != null && kw > 0;
    final hIn = _num(_enHours);
    final dIn = _num(_enDays);
    final h = hIn == null || hIn <= 0 ? 24.0 : math.min(hIn, 24.0);
    final d = dIn == null || dIn <= 0 ? 1.0 : dIn;
    if (ok) {
      if (hIn == null || hIn <= 0) notes.add('사용 시간 값이 없어 하루 24시간으로 계산했습니다.');
      if (hIn != null && hIn > 24) notes.add('하루 사용 시간은 24시간까지만 계산합니다.');
      if (dIn == null || dIn <= 0) notes.add('일수 값이 없어 1일로 계산했습니다.');
    }
    final kwh = ok ? energyKwh(kw, h, d) : null;
    final price = _num(_enPrice);
    final cost = kwh != null && price != null && price > 0 ? kwh * price : null;
    final summary = kwh == null
        ? null
        : [
            '${sig(kwh)} kWh',
            if (cost != null) '약 ${fmt(cost, 0)}원',
          ].join(' · ');
    return (
      [
        _field(
          'ec_en_kw',
          '전력 (kW)',
          _enKw,
          '부하가 쓰는 유효전력(kW)입니다. 전동기는 축 출력이 아니라 입력 전력입니다.',
        ),
        _field(
          'ec_en_h',
          '하루 사용 시간 (h)',
          _enHours,
          '하루에 운전하는 시간입니다. 연속 운전이면 24입니다.',
        ),
        _field(
          'ec_en_d',
          '일수 (일)',
          _enDays,
          '계산할 날 수입니다. 한 달은 30, 1년은 365를 넣으십시오.',
        ),
        _field(
          'ec_en_price',
          '단가 (원/kWh, 선택)',
          _enPrice,
          '1kWh당 요금입니다. 전기요금 청구서나 계약 요금표에서 보십시오. 비워 두면 전력량만 계산합니다.',
        ),
        const SizedBox(height: 12),
        if (negative)
          _negativeResult('ec_en_result')
        else
          calcResult(
            key: const Key('ec_en_result'),
            big: kwh == null ? '— kWh' : '${sig(kwh)} kWh',
            caption: kwh == null ? '전력(kW)을 넣으십시오' : '전력량',
            lines: [
              if (kwh != null) '하루 ${sig(kw! * h)} kWh × ${fmt(d)}일',
              if (cost != null)
                '요금 약 ${fmt(cost, 0)}원 (단가 ${fmt(price!, 2)}원/kWh)',
              if (cost != null)
                '기본요금·계절·시간대별 요금·부가세 등은 들어 있지 않습니다. 계약 요금표로 확인하십시오.',
              ...notes,
              '식: kWh = kW × 하루 사용 시간 × 일수, 요금 = kWh × 단가',
            ],
          ),
      ],
      summary,
    );
  }

  // ─────────────── 도체 저항 ───────────────

  (List<Widget>, String?) _resistanceSection() {
    final negative = _neg([_rsArea, _rsLen, _rs1, _rs2, _rs3]);
    final notes = <String>[];
    final a = _num(_rsArea);
    final l = _num(_rsLen);
    final ok = !negative && a != null && a > 0 && l != null && l > 0;
    final tIn = _num(_rsTemp);
    final t = tIn ?? 20;
    if (ok && tIn == null) notes.add('도체 온도 값이 없어 20°C로 계산했습니다.');
    final r = ok
        ? conductorResistance(metal: _rsMetal, areaMm2: a, lengthM: l, tempC: t)
        : null;
    final perKm = ok
        ? conductorResistance(
            metal: _rsMetal,
            areaMm2: a,
            lengthM: 1000,
            tempC: t,
          )
        : null;
    final cu = _rsMetal == ConductorMetal.copper;
    final table = cu && a != null ? kCuR20[a] : null;
    final rs = [
      for (final c in [_rs1, _rs2, _rs3])
        if ((_num(c) ?? 0) > 0) _num(c)!,
    ];
    final spReady = !negative && rs.length >= 2;
    return (
      [
        _chipGroup(
          '도체 재질',
          '20°C 고유저항: 구리 0.017241, 알루미늄 0.028264 Ω·mm²/m. 온도계수: 구리 0.00393, 알루미늄 0.00403 /°C '
              '(IEC 60287-1-1 표 1).',
          [
            calcChip('ec_rs_cu', '구리', cu, () {
              _set(() => _rsMetal = ConductorMetal.copper);
            }),
            calcChip('ec_rs_al', '알루미늄', !cu, () {
              _set(() => _rsMetal = ConductorMetal.aluminium);
            }),
          ],
        ),
        _field(
          'ec_rs_a',
          '단면적 (mm²)',
          _rsArea,
          '도체 단면적(sq = mm²)입니다. 부스바는 폭 × 두께입니다.',
        ),
        _field(
          'ec_rs_l',
          '길이 (m)',
          _rsLen,
          '도체 한 가닥 길이입니다. 왕복 저항은 결과의 왕복 값을 보십시오.',
        ),
        _field(
          'ec_rs_t',
          '도체 온도 (°C)',
          _rsTemp,
          '저항을 구할 도체 온도입니다. 운전 중 최고 온도는 PVC 70, XLPE 90입니다. 비우면 20으로 계산합니다.',
          signed: true,
        ),
        const SizedBox(height: 12),
        if (negative)
          _negativeResult('ec_rs_result')
        else
          calcResult(
            key: const Key('ec_rs_result'),
            big: r == null ? '— Ω' : '${sig(r)} Ω',
            caption: r == null
                ? '단면적과 길이를 넣으십시오'
                : '한 가닥 저항 (${cu ? '구리' : '알루미늄'}, ${fmt(t)}°C)',
            lines: [
              if (r != null) '왕복(2가닥) ${sig(r * 2)} Ω',
              if (perKm != null) '1km당 ${sig(perKm)} Ω/km',
              if (table != null)
                '참고: IEC 60228 2종(연선) 구리 20°C 최대 저항 ${sig(table)} Ω/km. '
                    '연선 전선은 이 표 값으로 계산하는 것이 안전합니다.',
              ...notes,
              '식: R = ρ20 × L ÷ A × (1 + α(θ − 20))',
            ],
          ),
        const SizedBox(height: 16),
        _sectionTitle('직렬·병렬 합성 저항'),
        _field('ec_rs_r1', '저항 R1 (Ω)', _rs1, '합성할 저항 값입니다. 두 개 이상 넣으십시오.'),
        _field('ec_rs_r2', '저항 R2 (Ω)', _rs2, '합성할 저항 값입니다.'),
        _field('ec_rs_r3', '저항 R3 (Ω, 선택)', _rs3, '세 개를 합성할 때 넣습니다.'),
        const SizedBox(height: 12),
        calcResult(
          key: const Key('ec_rs_sp_result'),
          big: spReady ? '${sig(seriesResistance(rs))} Ω' : '— Ω',
          caption: spReady ? '직렬 합성 저항' : '저항을 두 개 이상 넣으십시오',
          lines: [
            if (spReady) '병렬 합성 저항 ${sig(parallelResistance(rs))} Ω',
            '식: 직렬 R = R1 + R2 + R3, 병렬 1/R = 1/R1 + 1/R2 + 1/R3',
          ],
        ),
      ],
      r == null ? null : '${sig(r)} Ω · 왕복 ${sig(r * 2)} Ω',
    );
  }

  // ─────────────── 주파수(Hz) ───────────────

  (List<Widget>, String?) _frequencySection() {
    final negative = _neg([_hzF, _hzPoles, _hzRpm, _hzL, _hzC]);
    final fIn = _num(_hzF);
    final f = !negative && fIn != null && fIn > 0 ? fIn : null;
    final pIn = _num(_hzPoles);
    final poles = pIn?.round();
    final polesOk = poles != null && poles >= 2 && poles.isEven;
    final n = _num(_hzRpm);
    final rpm = !negative && n != null && n > 0 ? n : null;
    final ns = f != null && polesOk ? syncSpeedRpm(f, poles) : null;
    final lIn = _num(_hzL);
    final cIn = _num(_hzC);
    final henry = !negative && lIn != null && lIn > 0 ? lIn / 1000 : null;
    final farad = !negative && cIn != null && cIn > 0 ? cIn / 1e6 : null;
    String speedTable(double hz) => [
      for (final p in const [2, 4, 6, 8]) '$p극 ${fmt(syncSpeedRpm(hz, p), 0)}',
    ].join(', ');
    final summary = [
      if (f != null) '${fmt(f)}Hz',
      if (ns != null) '$poles극 ${fmt(ns, 0)} rpm',
      if (ns != null && rpm != null) '슬립 ${fmt(slip(ns, rpm) * 100, 2)}%',
    ];
    return (
      [
        _field(
          'ec_hz_f',
          '주파수 f (Hz)',
          _hzF,
          '한국 전력 계통은 60Hz입니다. 유럽·중국 등 50Hz 기기는 50을 넣으십시오.',
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Wrap(
            spacing: 6,
            children: [
              for (final hz in const [50, 60])
                calcChip('ec_hz_$hz', '${hz}Hz', f == hz, () {
                  _set(() => _hzF.text = '$hz');
                }),
            ],
          ),
        ),
        if (negative)
          _negativeResult('ec_hz_result')
        else
          calcResult(
            key: const Key('ec_hz_result'),
            big: f == null ? '— ms' : '${sig(periodSec(f) * 1000)} ms',
            caption: f == null ? '주파수를 넣으십시오' : '주기 T',
            lines: [
              if (f != null) '각주파수 ω = ${sig(angularFreq(f))} rad/s',
              '식: T = 1 ÷ f, ω = 2π × f',
            ],
          ),
        const SizedBox(height: 16),
        _sectionTitle('동기속도·슬립·발전기'),
        _field(
          'ec_hz_p',
          '극수 (극)',
          _hzPoles,
          '전동기·발전기의 극수입니다(2·4·6·8 …). 명판의 동기속도로 알 수 있습니다: 60Hz에서 3600rpm은 2극, 1800rpm은 4극입니다.',
        ),
        _field(
          'ec_hz_n',
          '회전수 n (rpm, 선택)',
          _hzRpm,
          '측정한 회전수나 명판의 정격 회전수입니다. 넣으면 슬립과 발전기 주파수를 계산합니다.',
        ),
        if (!negative)
          calcResult(
            key: const Key('ec_hz_speed_result'),
            big: ns == null ? '— rpm' : '${fmt(ns, 0)} rpm',
            caption: ns == null
                ? (pIn != null && !polesOk
                      ? '극수는 2 이상 짝수입니다'
                      : '주파수와 극수를 넣으십시오')
                : '동기속도 ns ($poles극, ${fmt(f!)}Hz)',
            lines: [
              if (ns != null && rpm != null)
                '슬립 s = (ns − n) ÷ ns = ${fmt(slip(ns, rpm) * 100, 2)}%'
                    '${rpm > ns ? ' (동기속도보다 빠름: 유도 발전기 운전)' : ''}',
              if (polesOk && rpm != null)
                '동기발전기라면 f = p × n ÷ 120 = ${sig(generatorHz(poles, rpm))} Hz',
              '60Hz 동기속도(rpm): ${speedTable(60)}',
              '50Hz 동기속도(rpm): ${speedTable(50)}',
              '50Hz 전동기를 60Hz로 쓰면 동기속도는 1.2배(60 ÷ 50)입니다. 토크·전류는 전압과 전압/주파수(V/f) 비에 따라 '
                  '달라지므로 명판·제조사 자료를 확인하십시오.',
              '식: ns = 120 × f ÷ p, s = (ns − n) ÷ ns, f = p × n ÷ 120',
            ],
          ),
        const SizedBox(height: 16),
        _sectionTitle('리액턴스·공진'),
        _field('ec_hz_l', '인덕턴스 L (mH)', _hzL, '코일·리액터의 인덕턴스(mH)입니다.'),
        _field('ec_hz_c', '정전용량 C (μF)', _hzC, '콘덴서의 정전용량(μF)입니다.'),
        if (!negative)
          calcResult(
            key: const Key('ec_hz_x_result'),
            big: henry != null && farad != null
                ? '${sig(resonanceHz(henry, farad))} Hz'
                : (henry != null && f != null
                      ? '${sig(inductiveReactance(f, henry))} Ω'
                      : (farad != null && f != null
                            ? '${sig(capacitiveReactance(f, farad))} Ω'
                            : '—')),
            caption: henry != null && farad != null
                ? '공진 주파수 f0'
                : (henry != null && f != null
                      ? '유도성 리액턴스 XL'
                      : (farad != null && f != null
                            ? '용량성 리액턴스 XC'
                            : 'L이나 C를 넣으십시오')),
            lines: [
              if (henry != null && f != null)
                'XL = 2π × f × L = ${sig(inductiveReactance(f, henry))} Ω (${fmt(f)}Hz)',
              if (farad != null && f != null)
                'XC = 1 ÷ (2π × f × C) = ${sig(capacitiveReactance(f, farad))} Ω (${fmt(f)}Hz)',
              if (henry != null && farad != null)
                'f0 = 1 ÷ (2π × √(L × C)) = ${sig(resonanceHz(henry, farad))} Hz',
              '식: XL = 2πfL, XC = 1 ÷ (2πfC), f0 = 1 ÷ (2π√(LC))',
            ],
          ),
      ],
      summary.isEmpty ? null : summary.join(' · '),
    );
  }
}
