// 전기 계산기 전선관 탭: 전선관 속 전선 점유율과 최소 전선관 굵기.
// 표·규칙은 conduit_tables.dart(전선관 내경·케이블 외경·점유율 한도, 두 출처 이상 확인).
part of 'electric_calculator_page.dart';

/// 전선관 탭의 전선 한 줄(종류·굵기·가닥 수).
class _CdRow {
  CableKind kind;
  double size;
  final TextEditingController count;
  _CdRow(this.kind, this.size, String n)
    : count = TextEditingController(text: n);
}

extension _ConduitTab on _ElectricCalculatorPageState {
  static const int _maxRows = 8;

  Map<String, Object?> _conduitDraft() => {
    'cdKind': _cdKind.name,
    'cdRule': _cdRule.name,
    'cdSize': _cdSize,
    'cdEasy': _cdEasy,
    'cdRows': [
      for (final r in _cdRows)
        {'k': r.kind.name, 's': r.size, 'n': r.count.text},
    ],
  };

  void _applyConduitDraft(Map<String, dynamic> m) {
    final kind = ConduitKind.values.where((k) => k.name == m['cdKind']);
    if (kind.isNotEmpty) _cdKind = kind.first;
    final rule = FillRule.values.where((r) => r.name == m['cdRule']);
    if (rule.isNotEmpty) _cdRule = rule.first;
    if (m['cdEasy'] is bool) _cdEasy = m['cdEasy'] as bool;
    final rows = m['cdRows'];
    if (rows is List && rows.isNotEmpty) {
      final next = <_CdRow>[];
      for (final r in rows.take(_maxRows)) {
        if (r is! Map) continue;
        final k = CableKind.values.where((c) => c.name == r['k']);
        final s = r['s'];
        if (k.isEmpty || s is! num) continue;
        if (!cableSizes(k.first).contains(s.toDouble())) continue;
        next.add(
          _CdRow(
            k.first,
            s.toDouble(),
            r['n'] is String ? r['n'] as String : '1',
          ),
        );
      }
      if (next.isNotEmpty) {
        _disposeConduitRows();
        _cdRows
          ..clear()
          ..addAll(next);
      }
    }
    final size = m['cdSize'];
    if (size is num && conduitSizes(_cdKind).any((c) => c.size == size)) {
      _cdSize = size.toInt();
    } else if (!conduitSizes(_cdKind).any((c) => c.size == _cdSize)) {
      _cdSize = conduitSizes(_cdKind).first.size;
    }
  }

  void _disposeConduitRows() {
    for (final r in _cdRows) {
      r.count.dispose();
    }
  }

  /// 입력한 줄을 계산용 목록으로. 가닥 수가 비었거나 0이면 뺀다. 음수가 있으면 null.
  List<ConduitWire>? _cdWires() {
    final out = <ConduitWire>[];
    for (final r in _cdRows) {
      final n = _num(r.count);
      if (n == null || n == 0) continue;
      if (n < 0) return null;
      out.add(ConduitWire(r.kind, r.size, n.round()));
    }
    return out;
  }

  ConduitSpec get _cdSpec => conduitSizes(_cdKind).firstWhere(
    (c) => c.size == _cdSize,
    orElse: () => conduitSizes(_cdKind).first,
  );

  Widget _cdRowBox(int i) {
    final r = _cdRows[i];
    final sizes = cableSizes(r.kind);
    return calcBox(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButton<CableKind>(
                    key: Key('ec_cd_kind_$i'),
                    value: r.kind,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    dropdownColor: fc.surface,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: fc.text,
                    ),
                    items: [
                      for (final k in CableKind.values)
                        DropdownMenuItem(
                          value: k,
                          child: Text(cableKindLabel(k)),
                        ),
                    ],
                    onChanged: (k) {
                      if (k == null) return;
                      _set(() {
                        r.kind = k;
                        final ss = cableSizes(k);
                        if (!ss.contains(r.size)) {
                          r.size = ss.firstWhere(
                            (s) => s >= r.size,
                            orElse: () => ss.last,
                          );
                        }
                      });
                    },
                  ),
                ),
                if (_cdRows.length > 1)
                  IconButton(
                    key: Key('ec_cd_del_$i'),
                    tooltip: '이 줄 지우기',
                    icon: Icon(Icons.close_rounded, color: fc.textSub),
                    onPressed: () => _set(() {
                      _cdRows.removeAt(i).count.dispose();
                    }),
                  ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: DropdownButton<double>(
                    key: Key('ec_cd_size_$i'),
                    value: r.size,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    dropdownColor: fc.surface,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: fc.text,
                    ),
                    items: [
                      for (final s in sizes)
                        DropdownMenuItem(
                          value: s,
                          child: Text(
                            '${sqText(s)} (외경 ${fmt(cableOd(r.kind, s)!)})',
                          ),
                        ),
                    ],
                    onChanged: (s) {
                      if (s != null) _set(() => r.size = s);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextField(
                    key: Key('ec_cd_n_$i'),
                    controller: r.count,
                    textAlign: TextAlign.right,
                    keyboardType: const TextInputType.numberWithOptions(),
                    textInputAction: TextInputAction.next,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: fc.text,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      suffixText: '가닥',
                    ),
                    onChanged: (_) => _set(() {}),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _conduitTab() {
    final wires = _cdWires();
    final negative = wires == null;
    final spec = _cdSpec;
    Widget result;
    String? summary;
    var warn = false;
    var basis = <String>[];
    if (negative) {
      result = _negativeResult('ec_cd_result');
    } else if (wires.isEmpty) {
      result = calcResult(
        key: const Key('ec_cd_result'),
        big: '— %',
        caption: '전선 가닥 수를 넣으면 점유율을 계산합니다',
        lines: const [],
      );
    } else {
      final limit = fillLimit(_cdRule, wires, easyPull: _cdEasy);
      final area = wiresArea(wires);
      final pct = fillPercent(wires, spec.id);
      final over = pct > limit.pct + 1e-9;
      final mins = {
        for (final k in ConduitKind.values)
          k: minConduit(k, wires, _cdRule, easyPull: _cdEasy),
      };
      final mine = mins[_cdKind];
      warn = over;
      result = calcResult(
        key: const Key('ec_cd_result'),
        big: '${fmt(pct, 1)} %',
        caption:
            '${conduitKindLabel(_cdKind)} ${spec.size} (내경 ${fmt(spec.id, 1)}mm) 점유율',
        warn: warn,
        lines: [
          over
              ? '한도 ${fmt(limit.pct)}% 초과. ${mine == null ? '표 안에 맞는 규격이 없습니다.' : '${conduitKindLabel(_cdKind)} ${mine.size} 이상으로 선정하십시오.'}'
              : '한도 ${fmt(limit.pct)}% 이내입니다.',
          limit.reason,
          for (final k in ConduitKind.values)
            mins[k] == null
                ? '최소 ${conduitKindLabel(k)}: 표 안에 맞는 규격이 없습니다'
                : '최소 ${conduitKindLabel(k)}: ${mins[k]!.size} '
                      '(${fmt(fillPercent(wires, mins[k]!.id), 1)}%)',
          '전선 단면적 합 ${fmt(area, 1)} mm² (외경 기준), 관 내 단면적 ${fmt(conduitArea(spec.id), 1)} mm²',
          ...limit.notes,
        ],
      );
      summary = [
        '${conduitKindLabel(_cdKind)} ${spec.size} ${fmt(pct, 1)}%',
        over ? '한도 ${fmt(limit.pct)}% 초과' : '한도 ${fmt(limit.pct)}% 이내',
        if (mine != null) '최소 ${mine.size}',
      ].join(' · ');
      basis = [
        '점유율 = 전선 단면적 합(π/4 × 외경² × 가닥 수) ÷ 관 내 단면적(π/4 × 내경²)',
        for (final w in wires)
          '${cableKindLabel(w.kind)} ${sqText(w.size)} 외경 ${fmt(cableOd(w.kind, w.size)!)}mm × ${w.count}가닥',
        ...fillRuleBasis(_cdRule),
        conduitSource(_cdKind),
        cableOdSource,
      ];
    }

    return _page(sumKey: 'ec_sum_cd', summary: summary, warn: warn, [
      _chipGroup('전선관 종류', conduitKindGuide, [
        for (final k in ConduitKind.values)
          calcChip(
            'ec_cd_type_${k.name}',
            conduitKindLabel(k),
            _cdKind == k,
            () {
              _set(() {
                _cdKind = k;
                final ss = conduitSizes(k);
                _cdSize = ss
                    .firstWhere(
                      (c) => c.id >= spec.id - 1e-9,
                      orElse: () => ss.last,
                    )
                    .size;
              });
            },
          ),
      ]),
      _chipGroup('점유율 기준', fillRuleGuide, [
        for (final r in FillRule.values)
          calcChip('ec_cd_rule_${r.name}', fillRuleLabel(r), _cdRule == r, () {
            _set(() => _cdRule = r);
          }),
      ]),
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: calcLabel(
          '관에 넣는 전선',
          '관 하나에 넣는 전선을 종류·굵기·가닥 수로 넣습니다. 케이블은 1가닥이 케이블 1본입니다.\n'
              '괄호 안 외경(mm)은 제조사 카탈로그 값입니다. F-CV는 제조사 중 큰 값, HFIX·IV는 규격 외경 상한입니다.\n'
              'F-CVV-S는 제어용 차폐 케이블(1.5~10sq)입니다.\n'
              '접지선도 같은 관에 넣으면 한 줄로 더하십시오.',
        ),
      ),
      for (var i = 0; i < _cdRows.length; i++) _cdRowBox(i),
      if (_cdRows.length < _maxRows)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('ec_cd_add'),
            onPressed: () => _set(() {
              final last = _cdRows.last;
              _cdRows.add(_CdRow(last.kind, last.size, '1'));
            }),
            icon: const Icon(Icons.add_rounded),
            label: const Text('전선 추가'),
          ),
        ),
      if (_cdRule == FillRule.naesun && !negative && easyPullApplies(wires))
        calcSwitch(
          '굴곡이 적어 쉽게 인출 (48%)',
          _cdEasy,
          (v) => _set(() => _cdEasy = v),
          '같은 굵기 절연전선만 넣고 관의 굴곡이 적어 전선을 쉽게 인출할 수 있으면 48%까지 넣을 수 있습니다(구 내선규정 2225-5). '
              '굴곡이 많거나 길면 끄십시오(32%).',
          key: 'ec_cd_easy',
        ),
      calcDropdown<ConduitSpec>(
        'ec_cd_size',
        '전선관 굵기',
        spec,
        conduitSizes(_cdKind),
        (c) => '${c.size} (내경 ${fmt(c.id, 1)}mm)',
        (c) => _set(() => _cdSize = c.size),
        '점유율을 볼 전선관 호칭입니다. 괄호는 내경(외경 − 2 × 두께)입니다. '
            '결과에 종류별 최소 전선관도 같이 보입니다.',
      ),
      const SizedBox(height: 12),
      result,
      if (basis.isNotEmpty) _basis('ec_cd_basis', basis),
    ]);
  }
}
