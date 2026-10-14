// ignore_for_file: invalid_use_of_protected_member
part of 'alignment_page.dart';

// ④ 심 기록(10-15 새로): 기계마다 네 발 밑 심을 남긴다.
// 시작 심(같은 기계 지난 기록의 끝 값으로 미리) + 이번 작업 회차 누계 = 지금 심. 가진 심 두께로 판 조합.
// 회차 적기·고치기, 기록 남기기(시작·끝 심을 같이), 이 기계의 심 이력.
extension _AlignShim on _AlignmentPageState {
  Map<AlignFoot, double> get _startMap => {
    for (final f in AlignFoot.values) f: parseNumberText(_start[f]!.text) ?? 0,
  };

  void _saveShimDraft() => AlignShimStore.save(_machine.text.trim(), _startMap);

  // ── 회차 ──

  Future<void> _setRounds(List<AlignRound> next) async {
    setState(() => _rounds = next);
    await AlignSessionStore.save(next);
  }

  Future<void> _addRound(AlignResult r) async {
    final round = AlignRound(
      at: _now,
      offset: r.offset,
      angle100: r.angle100,
      verdict: judge(r, _tol),
      shimFront: r.shimFront,
      shimRear: r.shimRear,
      moveFront: r.moveFront,
      moveRear: r.moveRear,
    );
    await _setRounds([..._rounds, round]);
    _go(3);
    await _editDone(_rounds.length - 1);
  }

  Future<void> _editDone(int i) async {
    final out = await showModalBottomSheet<AlignRound>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DoneSheet(round: _rounds[i], index: i),
    );
    if (out == null) return;
    await _setRounds([for (var k = 0; k < _rounds.length; k++) k == i ? out : _rounds[k]]);
  }

  // ── 저장 ──

  Future<void> _save(AlignResult r) async {
    final equipment = await EquipmentStore.load();
    if (!mounted) return;
    final machineDefault = _machine.text.trim().isNotEmpty
        ? _machine.text.trim()
        : await AlignStore.lastMachine();
    if (!mounted) return;
    final start = _startMap;
    final end = footNow(start, _rounds);
    final out = await showModalBottomSheet<AlignRecord>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SaveSheet(
        result: r,
        method: _method,
        rpm: _rpm,
        inputs: _inputs(),
        verdict: judge(r, _tol),
        now: _now,
        machineDefault: machineDefault,
        equipment: [for (final e in equipment) if (!e.isRetired) e],
        rounds: _rounds,
        footStart: start,
        footEnd: end,
      ),
    );
    if (out == null) return;
    await AlignStore.put(out);
    if (_rounds.isNotEmpty) await _setRounds([]); // 회차는 기록에 같이 저장됐다
    // 다음 작업은 지금 심에서 시작한다(같은 기계면 그대로 이어진다).
    final recs = await AlignStore.load();
    if (mounted) {
      setState(() {
        _records = recs;
        _machine.text = out.machine;
        for (final f in AlignFoot.values) {
          final v = end[f] ?? 0;
          _start[f]!.text = v.abs() < 0.005 ? '' : footMm(v);
        }
      });
    }
    await AlignShimStore.save(out.machine, end);
    // 장비 대장의 장비를 골랐으면 그 장비 이력에 "축 정렬"을 남긴다(점검 기한은 그대로).
    if (out.equipmentId.isNotEmpty) {
      final list = await EquipmentStore.load();
      for (final e in list) {
        if (e.id == out.equipmentId) {
          await EquipmentStore.put(
            recordAlignment(
              e,
              at: out.at,
              note: '${out.stage.label} · 평행 ${out.offset.toStringAsFixed(3)} mm, 각도 ${out.angle100.toStringAsFixed(3)} mm/100mm',
            ),
          );
        }
      }
    }
    final cmp = compareText(out, await AlignStore.load());
    _toast(cmp == null ? '기록했습니다' : '기록했습니다. $cmp');
  }

  // ── 화면 ──

  List<Widget> _shimTab(AlignResult? r) {
    final start = _startMap;
    final totals = shimTotals(_rounds);
    final now = footNow(start, _rounds);
    final machine = _machine.text.trim();
    final last = lastFeetFor(_records, machine);
    final history = shimHistory(_records, machine);
    return [
      _card('기계', [
        TextField(
          key: const Key('align_shim_machine'),
          controller: _machine,
          onChanged: (_) {
            setState(() {});
            _saveShimDraft();
          },
          decoration: const InputDecoration(
            labelText: '기계 이름',
            hintText: '예: 1호기 급수펌프 · 모터',
            isDense: true,
          ),
        ),
        if (last != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: TextButton.icon(
              key: const Key('align_shim_load_last'),
              onPressed: () {
                setState(() {
                  for (final f in AlignFoot.values) {
                    final v = last[f] ?? 0;
                    _start[f]!.text = v.abs() < 0.005 ? '' : footMm(v);
                  }
                });
                _saveShimDraft();
                _toast('지난 기록의 끝 심을 시작 심으로 넣었습니다');
              },
              icon: const Icon(Icons.history_rounded, size: 18),
              label: Text('지난 기록(${history.first.at.month}/${history.first.at.day})의 끝 심을 시작으로'),
            ),
          ),
      ]),
      _card('네 발 밑 심 (mm)', [
        const Text(
          '시작 심은 작업 전에 발 밑에 있던 심입니다. 회차에 적은 "한 일"이 더해져 지금 심이 됩니다. '
          '왼쪽·오른쪽은 펌프 쪽에서 모터를 볼 때입니다.',
          style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.textSub),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const SizedBox(width: 44),
            for (final t in ['앞발 (커플링 쪽)', '뒷발'])
              Expanded(
                child: Text(
                  t,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textSub),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (final side in [
          ('왼쪽', AlignFoot.frontLeft, AlignFoot.rearLeft),
          ('오른쪽', AlignFoot.frontRight, AlignFoot.rearRight),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 44,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(side.$1, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textSub)),
                  ),
                ),
                Expanded(child: _footCell(side.$2, totals[side.$2]!, now[side.$2]!)),
                const SizedBox(width: 6),
                Expanded(child: _footCell(side.$3, totals[side.$3]!, now[side.$3]!)),
              ],
            ),
          ),
      ]),
      _sizesCard(),
      _roundsCard(r),
      if (history.isNotEmpty)
        _card('이 기계의 심 이력', [
          for (final h in history.take(10))
            Padding(
              key: Key('align_shim_hist_${h.id}'),
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${h.at.year}.${h.at.month}.${h.at.day} · ${h.stage.label} · ${verdictLabel(h.verdict)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [for (final f in AlignFoot.values) '${f.label} ${footMm(h.footEnd[f] ?? 0)}'].join(' · '),
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textSub),
                  ),
                ],
              ),
            ),
        ]),
      if (r == null)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(
            '기록 남기기는 ③ 결과가 나온 뒤에 할 수 있습니다. 시작 심과 기계 이름은 지금 적어 두면 폰에 남습니다.',
            style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textFaint),
          ),
        ),
    ];
  }

  Widget _footCell(AlignFoot f, double change, double now) => Container(
    padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
    decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: Key('align_start_${f.name}'),
          controller: _start[f],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          onChanged: (_) {
            setState(() {});
            _saveShimDraft();
          },
          decoration: const InputDecoration(
            labelText: '시작',
            isDense: true,
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '이번 작업 ${signedMm(change)}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: change.abs() < 0.005 ? AppColors.textSub : AppColors.brand,
          ),
        ),
        Text(
          '지금 ${footMm(now)}',
          key: Key('align_now_${f.name}'),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: now < -0.005 ? AppColors.danger : AppColors.text,
          ),
        ),
        Text(
          now < -0.005 ? '시작보다 더 뺐습니다(시작 심 확인)' : '판 ${shimPlateText(now, _sizes)}',
          style: TextStyle(fontSize: 11.5, color: now < -0.005 ? AppColors.danger : AppColors.textSub),
        ),
      ],
    ),
  );

  /// 가진 심 두께(판 조합에 씀). 누르면 빼고, 칸에 넣어 더한다.
  Widget _sizesCard() {
    void addSize() {
      final v = parseNumberText(_sizeAdd.text);
      if (v == null || v <= 0 || _sizes.contains(v)) return;
      setState(() {
        _sizes = [..._sizes, v]..sort((a, b) => b.compareTo(a));
        _sizeAdd.clear();
      });
      AlignShimStore.saveSizes(_sizes);
    }

    return _card('가진 심 두께 (mm)', [
      const Text(
        '심 판 조합을 셀 때 씁니다. 가진 것만 남기십시오(누르면 뺍니다).',
        style: TextStyle(fontSize: 12.5, color: AppColors.textSub),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final s in _sizes)
            InputChip(
              key: Key('align_size_$s'),
              label: Text(footMm(s)),
              onDeleted: _sizes.length <= 1
                  ? null
                  : () {
                      setState(() => _sizes = [..._sizes]..remove(s));
                      AlignShimStore.saveSizes(_sizes);
                    },
            ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('align_size_add_field'),
              controller: _sizeAdd,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: '두께 더하기 (예: 0.3)', isDense: true),
              onSubmitted: (_) => addSize(),
            ),
          ),
          IconButton(key: const Key('align_size_add'), icon: const Icon(AppIcons.add), onPressed: addSize),
        ],
      ),
    ]);
  }

  Widget _roundsCard(AlignResult? r) {
    final moves = moveTotals(_rounds);
    return _card('정렬 작업 회차', [
      if (_rounds.isEmpty)
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            '③ 결과에서 "회차로 적기"를 누르면 여기에 쌓입니다. 측정 → 심 넣고 빼기·옆으로 밀기 → 재측정을 회차로 남기고, 발마다 넣고 뺀 심이 위 표에 더해집니다.',
            style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.textSub),
          ),
        ),
      for (var i = 0; i < _rounds.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                padding: const EdgeInsets.symmetric(vertical: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.brandSoft, borderRadius: BorderRadius.circular(8)),
                child: Text('${i + 1}회차', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.brand)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '평행 ${_rounds[i].offset.toStringAsFixed(3)} mm · 각도 ${_rounds[i].angle100.toStringAsFixed(3)} mm/100mm · ${verdictLabel(_rounds[i].verdict)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.text),
                    ),
                    const SizedBox(height: 2),
                    Text('한 일: ${doneLine(_rounds[i])}', key: Key('align_round_line_$i'), style: const TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.textSub)),
                  ],
                ),
              ),
              TextButton(
                key: Key('align_round_done_$i'),
                onPressed: () => _editDone(i),
                child: Text(_rounds[i].done == null ? '한 일 적기' : '고치기'),
              ),
            ],
          ),
        ),
      if (moves.$1.abs() >= 0.005 || moves.$2.abs() >= 0.005)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text('옆으로 민 누계: 앞 ${moveText(moves.$1)}, 뒤 ${moveText(moves.$2)}', style: const TextStyle(fontSize: 12.5, color: AppColors.textSub)),
        ),
      // 회차별 심 누계(예전 화면의 키를 이어 쓴다).
      if (_rounds.any((x) => x.done != null))
        Wrap(
          spacing: 10,
          children: [
            for (final f in AlignFoot.values)
              Text(
                '${f.label} ${signedMm(shimTotals(_rounds)[f]!)} mm',
                key: Key('align_total_${f.name}'),
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.text),
              ),
          ],
        ),
      Row(
        children: [
          if (r != null)
            Expanded(
              child: OutlinedButton(
                key: const Key('align_round_add_here'),
                onPressed: () => _addRound(r),
                child: Text('지금 결과를 ${_rounds.length + 1}회차로 적기'),
              ),
            ),
          if (_rounds.isNotEmpty) ...[
            const SizedBox(width: 8),
            TextButton(
              key: const Key('align_round_undo'),
              onPressed: () => _setRounds(_rounds.sublist(0, _rounds.length - 1)),
              child: const Text('마지막 회차 지우기'),
            ),
          ],
        ],
      ),
    ]);
  }
}
