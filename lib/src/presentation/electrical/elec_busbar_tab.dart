// 전기 계산기 ⑥ 부스바 탭: 구리 부스바 허용전류(DIN 43671)와 굵기 선정.
// 표는 busbar_tables.dart(칸마다 두 출처 이상 확인). 교류/직류는 다른 탭과 같은 선택(_dc)을 쓴다.
part of 'electric_calculator_page.dart';

extension _BusbarTab on _ElectricCalculatorPageState {
  static const String _condLine =
      '조건: DIN 43671, 옥내, 주위 35°C, 부스바 65°C, 부스바 폭을 세운 상태, 같은 상 부스바 간격 = 두께';

  String get _busKind =>
      '${_dc ? '직류' : '교류'}, ${_busPainted ? '도장' : '도장 안 함'}';

  String _barsText(BusbarRow r, int bars) =>
      bars == 1 ? r.label : '${r.label} × $bars';

  Widget _busTab() {
    final negative = _anyNegative([_busI, _busMargin]);
    final load = _num(_busI);
    final mIn = _num(_busMargin);
    final margin = mIn == null || mIn < 0 ? 0.0 : mIn;
    final need = load == null || load <= 0 ? null : load * (1 + margin / 100);

    Widget result;
    String? summary;
    var warn = false;
    if (negative) {
      result = _negativeResult('ec_bus_result');
    } else if (!_busPick) {
      final k = busbarRating(
        _busRow,
        bars: _busBars,
        dc: _dc,
        painted: _busPainted,
      );
      final amps = k.amps;
      final over = amps != null && need != null && need > amps + 1e-9;
      warn = amps == null || over;
      result = calcResult(
        key: const Key('ec_bus_result'),
        big: amps == null ? '표 값 없음' : '$amps A',
        caption: '${_barsText(_busRow, _busBars)} 허용전류 ($_busKind)',
        warn: warn,
        lines: [
          if (amps != null)
            '전류 밀도 ${fmt(k.density!, 2)} A/mm² (단면적 ${fmt(_busRow.area)} mm²'
                '${_busBars > 1 ? ' × $_busBars' : ''})',
          if (k.cell == BusbarCell.notInTable)
            'DIN 43671 표에 이 가닥 수 값이 없습니다. 가닥 수를 줄이거나 규격을 바꾸십시오.',
          if (k.cell == BusbarCell.notVerified)
            '이 조합(얇은 부스바 직류 2·3가닥)은 두 출처로 확인한 값이 없어 넣지 않았습니다. 제조사 자료로 확인하십시오.',
          if (amps != null && need != null)
            over
                ? '선정 전류 ${fmt(need, 1)} A가 허용전류 $amps A를 초과합니다. 규격이나 가닥 수를 올리십시오.'
                : '선정 전류 ${fmt(need, 1)} A는 허용전류 $amps A 이내입니다.',
          _condLine,
          '주위 35°C 초과나 부스바 65°C 초과로 쓰려면 보정계수(k2)가 필요합니다. 제조사 자료로 확인하십시오.',
        ],
      );
      if (amps != null) {
        summary =
            '${_barsText(_busRow, _busBars)} · $amps A · ${fmt(k.density!, 2)} A/mm²';
      } else {
        summary = '표 값 없음';
      }
    } else if (need == null) {
      result = calcResult(
        key: const Key('ec_bus_result'),
        big: '—',
        caption: '부하 전류를 넣으면 규격을 선정합니다',
        lines: const [],
      );
    } else {
      final picks = [
        for (final n in const [1, 2, 3, 4])
          (n, smallestBusbar(need, bars: n, dc: _dc, painted: _busPainted)),
      ];
      final first = picks.firstWhere(
        (p) => p.$2 != null,
        orElse: () => (0, null),
      );
      warn = first.$2 == null;
      result = calcResult(
        key: const Key('ec_bus_result'),
        big: first.$2 == null ? '검토 필요' : _barsText(first.$2!.row, first.$1),
        caption: first.$2 == null
            ? '표 범위(200×10 × 4가닥)를 넘습니다'
            : '${fmt(need, 1)} A 이상, 가닥 수가 가장 적은 규격 ($_busKind)',
        warn: warn,
        lines: [
          for (final (n, k) in picks)
            k == null
                ? '$n가닥: 표 안에 맞는 규격이 없습니다'
                : '$n가닥: ${_barsText(k.row, n)} (${k.amps} A, ${fmt(k.density!, 2)} A/mm²)',
          if (margin > 0)
            '선정 전류 ${fmt(need, 1)} A = 부하 ${fmt(load!, 1)} A × ${fmt(1 + margin / 100, 2)}',
          if (_dc) '얇은 부스바의 직류 2·3가닥 값은 두 출처로 확인하지 못해 선정에서 뺐습니다.',
          '단면적이 같은 규격(예: 20×10과 40×5)은 허용전류가 큰 쪽을 보입니다.',
          _condLine,
        ],
      );
      summary = [
        for (final (n, k) in picks.take(3))
          if (k != null) '$n가닥 ${k.row.label}',
      ].join(' · ');
      if (summary.isEmpty) summary = '검토 필요';
    }

    return _page(sumKey: 'ec_sum_bus', summary: summary, warn: warn, [
      _chipGroup(
        '할 일',
        '허용전류: 규격과 가닥 수를 지정하면 허용전류와 전류 밀도를 계산합니다.\n'
            '굵기 선정: 부하 전류로 1~4가닥별 가장 작은 규격을 선정합니다.',
        [
          calcChip('ec_bus_mode_amp', '허용전류', !_busPick, () {
            _set(() => _busPick = false);
          }),
          calcChip('ec_bus_mode_pick', '굵기 선정', _busPick, () {
            _set(() => _busPick = true);
          }),
        ],
      ),
      _chipGroup(
        '전류',
        '교류(60Hz까지)와 직류 값이 다릅니다. 굵은 부스바는 교류에서 표피 효과로 허용전류가 작아집니다.\n'
            '부하 전류·전선 굵기·전압강하 탭과 같은 교류/직류 선택을 씁니다.',
        [
          calcChip('ec_bus_ac', '교류', !_dc, () {
            _set(() => _dc = false);
          }),
          calcChip('ec_bus_dc', '직류', _dc, () {
            _set(() => _dc = true);
          }),
        ],
      ),
      _chipGroup(
        '표면',
        '도장: 부스바 표면에 도료를 칠한 것입니다. 열을 잘 내보내 허용전류가 큽니다.\n'
            '도장 안 함: 칠하지 않은 부스바입니다. 모르면 도장 안 함으로 두십시오(값이 작은 쪽).',
        [
          calcChip('ec_bus_painted', '도장', _busPainted, () {
            _set(() => _busPainted = true);
          }),
          calcChip('ec_bus_bare', '도장 안 함', !_busPainted, () {
            _set(() => _busPainted = false);
          }),
        ],
      ),
      if (!_busPick) ...[
        calcDropdown<BusbarRow>(
          'ec_bus_size',
          '부스바 규격 (폭×두께 mm)',
          _busRow,
          kBusbars,
          (r) => '${r.label} (${fmt(r.area)} mm²)',
          (r) => _set(() => _busRow = r),
          '구리 부스바의 폭 × 두께(mm)입니다. 괄호는 DIN 43671 표의 단면적입니다(모서리 둥글림 반영).',
        ),
        _chipGroup(
          '상당 가닥 수',
          '한 상에 나란히 붙여 쓰는 부스바 수입니다. 가닥 사이 간격은 부스바 두께와 같다고 봅니다.\n'
              '교류 4가닥은 2가닥씩 두 묶음(묶음 사이 50mm)입니다. DIN 43671의 4가닥 값은 교류 40×10과 폭 50mm 이상, '
              '직류 폭 60mm 이상에만 있습니다.',
          [
            for (final n in const [1, 2, 3, 4])
              calcChip('ec_bus_n_$n', '$n가닥', _busBars == n, () {
                _set(() => _busBars = n);
              }),
          ],
        ),
      ],
      _field(
        'ec_bus_i',
        _busPick ? '부하 전류 (A)' : '부하 전류 (A, 선택)',
        _busI,
        _busPick
            ? '부스바에 흐르는 최대 연속 전류입니다. 차단기 정격이나 변압기 정격전류를 넣기도 합니다.'
            : '넣으면 허용전류 이내인지 봅니다.',
      ),
      _field(
        'ec_bus_margin',
        '여유 (%)',
        _busMargin,
        '설계 기준의 여유율입니다. 부하 전류에 곱해 선정 전류를 정합니다. 없으면 0입니다.',
      ),
      const SizedBox(height: 12),
      result,
      _basis('ec_bus_basis', [
        'DIN 43671(구리 부스바 연속 전류) 표 값. 재질 E-Cu F30.',
        '$_condLine. 교류 4가닥은 2가닥씩 두 묶음(묶음 사이 50mm), 직류 4가닥은 한 줄.',
        '값 확인: Druseidt·Rittal·Radiolex·EAE·Mostec·Licht+Technik 표 중 두 곳 이상이 같은 값만 넣었습니다.',
        '배전반 제조사가 IEC 61439 형식 시험으로 정한 정격이 있으면 그 값을 우선합니다.',
        '넣지 않은 것: 온도 보정계수 k2(DIN 43671에 그림으로만 있음), 알루미늄 부스바(DIN 43670, 출처끼리 값이 다름), '
            '단락 시 열적·기계적 강도.',
      ]),
    ]);
  }
}
