// ignore_for_file: invalid_use_of_protected_member
part of 'alignment_page.dart';

// 심 기록 탭(10-15 새로): 기계마다 네 발 밑 심을 남긴다.
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
      // 고정 발을 바꿔 펌프도 움직이면 펌프 할 일을 메모로(심 기록은 모터 발만 센다).
      note: _pumpNote().isEmpty ? '' : '펌프: ${_pumpNote()}',
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
    final lastName = await AlignStore.lastMachine();
    // 지난 이름은 그 기계 기록이 남아 있을 때만(지운 기록 이름이 다시 나오지 않게).
    final machineDefault = _machine.text.trim().isNotEmpty
        ? _machine.text.trim()
        : (shimHistory(_records, lastName).isNotEmpty ? lastName : '');
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
        // 판정 기준도 같이 남긴다(보고서 PDF에 적으려고, 10-15).
        inputs: {
          ..._inputs(),
          'tolO': _tol.offset.toString(),
          'tolA': _tol.angle100.toString(),
          if (_pumpNote().isNotEmpty) 'pumpPlan': _pumpNote(),
        },
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
        _setStart(end, out.machine);
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

  /// 위 그림: 위에서 본 네 발과 지금 심.
  Widget _shimCanvas() {
    final now = footNow(_startMap, _rounds);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 22),
      child: CustomPaint(
        key: const Key('align_feet'),
        size: Size.infinite,
        painter: AlignFeetRenderPainter(now: now, change: shimTotals(_rounds)),
      ),
    );
  }

  Widget _shimPanel(AlignResult? r) {
    final totals = shimTotals(_rounds);
    final now = footNow(_startMap, _rounds);
    final machine = _machine.text.trim();
    final last = lastFeetFor(_records, machine);
    final history = shimHistory(_records, machine);
    return PlatePanel(
      title: '심 기록',
      status: machine.isEmpty
          ? '기계 이름을 넣으면 그 기계의 지난 심을 이어 씁니다.'
          : (_rounds.isEmpty ? '$machine · 이번 작업 회차 없음' : '$machine · ${_rounds.length}회차까지 적음'),
      statusKey: const Key('align_shim_status'),
      actions: [
        plateHelpButton(context, 'align_shim_help', '심 기록', [
          '기계마다 네 발 밑에 있는 심을 남깁니다. 다음에 같은 기계를 맞출 때 지난번 끝 심에서 시작합니다.',
          '시작 심은 작업 전에 발 밑에 있던 심입니다. 회차에 적은 "한 일"이 더해져 지금 심이 됩니다.',
          '왼쪽·오른쪽은 펌프 쪽에서 모터를 볼 때입니다.',
          '판 조합은 아래 "가진 심 두께"로 셉니다. 가진 두께만 남겨 두십시오.',
          '기록 남기기를 누르면 결과·회차·시작/끝 심이 같이 저장되고, 지금 심이 다음 작업의 시작 심이 됩니다.',
        ]),
      ],
      footer: _saveButton(r),
      children: [
        PlateSection('기계', [
          PlateNumField(
            fieldKey: 'align_shim_machine',
            label: '기계 이름',
            controller: _machine,
            text: true,
            unit: null,
            hint: '예: 1호기 급수펌프 · 모터',
            onChanged: (_) {
              setState(_machineChanged);
              _saveShimDraft();
            },
          ),
          if (last != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('align_shim_load_last'),
                onPressed: () {
                  setState(() => _setStart(last, machine));
                  _saveShimDraft();
                  _toast('지난 기록의 끝 심을 시작 심으로 넣었습니다');
                },
                icon: const Icon(Icons.history_rounded, size: 18),
                label: Text('지난 기록(${history.first.at.month}/${history.first.at.day})의 끝 심을 시작으로'),
              ),
            ),
        ], first: true),
        _softFootSection(),
        PlateSection('네 발 밑 심 (mm)', [
          Row(
            children: [
              const SizedBox(width: 44),
              for (final t in ['앞발 (커플링 쪽)', '뒷발'])
                Expanded(
                  child: Text(t, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: fc.textSub)),
                ),
            ],
          ),
          for (final side in [
            ('왼쪽', AlignFoot.frontLeft, AlignFoot.rearLeft),
            ('오른쪽', AlignFoot.frontRight, AlignFoot.rearRight),
          ])
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 44,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Text(side.$1, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: fc.textSub)),
                  ),
                ),
                Expanded(child: _footCell(side.$2, totals[side.$2]!, now[side.$2]!)),
                const SizedBox(width: 8),
                Expanded(child: _footCell(side.$3, totals[side.$3]!, now[side.$3]!)),
              ],
            ),
        ]),
        _roundsSection(r),
        _sizesSection(),
        if (history.isNotEmpty)
          PlateSection('이 기계의 심 이력', [
            for (final h in history.take(10))
              Column(
                key: Key('align_shim_hist_${h.id}'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${h.at.year}.${h.at.month}.${h.at.day} · ${h.stage.label} · ${verdictLabel(h.verdict)}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: fc.text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [for (final f in AlignFoot.values) '${f.label} ${footMm(h.footEnd[f] ?? 0)}'].join(' · '),
                    style: TextStyle(fontSize: 12.5, color: fc.textSub),
                  ),
                ],
              ),
          ]),
      ],
    );
  }

  /// 넣은 소프트 풋 값.
  Map<AlignFoot, double> get _softFoot => softFootOf(_inputs());

  /// 소프트 풋 점검(10-15): 정렬 전에 한 발씩 풀어 올라오는 양. 기준을 넘으면 결과 탭에도 알린다.
  Widget _softFootSection() {
    final v = _softFoot;
    final over = softFootOver(v);
    final lim = kSoftFootLimit.toStringAsFixed(2);
    Widget cell(AlignFoot f, String label) => _field(softFootKey(f), label, signed: false);
    return PlateSection(
      '소프트 풋 점검 (정렬 전에)',
      [
        _note('네 발 볼트를 다 조인 뒤 다이얼을 발 위에 대고, 한 발씩 풀어 올라오는 양을 넣습니다. 흔히 $lim mm 넘게 올라오면 고칩니다.'),
        plateRow([cell(AlignFoot.frontLeft, '앞발 왼쪽'), cell(AlignFoot.rearLeft, '뒷발 왼쪽')]),
        plateRow([cell(AlignFoot.frontRight, '앞발 오른쪽'), cell(AlignFoot.rearRight, '뒷발 오른쪽')]),
        if (v.isNotEmpty)
          Container(
            key: const Key('align_softfoot_line'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: (over.isEmpty ? fc.ok : fc.caution).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              over.isEmpty
                  ? '넣은 발은 모두 $lim mm 이하입니다.${v.length < 4 ? ' (네 발을 다 보십시오)' : ''}'
                  : '${softFootList(v, over)} mm: $lim 넘음. 평행 틈이면 그 발에 올라온 만큼 심을 더 넣고, 각진 틈이면 틈 게이지로 네 모서리를 봅니다.',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: over.isEmpty ? fc.ok : fc.caution, height: 1.4),
            ),
          ),
      ],
      trailing: TextButton(
        key: const Key('align_softfoot_guide'),
        onPressed: () => _openGuide('softfoot'),
        child: const Text('조치 보기'),
      ),
    );
  }

  Widget _footCell(AlignFoot f, double change, double now) => Container(
    padding: const EdgeInsets.all(8),
    // 바탕을 흰 판 + 테두리로(10-15 폰: 회색 바탕에 회색 칸이라 시작 칸이 안 보였다).
    decoration: BoxDecoration(
      color: fc.surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: fc.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlateNumField(
          fieldKey: 'align_start_${f.name}',
          label: '시작',
          controller: _start[f]!,
          onChanged: (_) {
            setState(() {});
            _saveShimDraft();
          },
        ),
        const SizedBox(height: 6),
        Text(
          '이번 작업 ${signedMm(change)}',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: change.abs() < 0.005 ? fc.textSub : fc.brand),
        ),
        Text(
          '지금 ${footMm(now)}',
          key: Key('align_now_${f.name}'),
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: now < -0.005 ? fc.danger : fc.text),
        ),
        Text(
          now < -0.005 ? '시작보다 더 뺐습니다(시작 심 확인)' : '판 ${shimPlateText(now, _sizes)}',
          style: TextStyle(fontSize: 11.5, color: now < -0.005 ? fc.danger : fc.textSub),
        ),
      ],
    ),
  );

  /// 가진 심 두께(판 조합에 씀). 누르면 빼고, 칸에 넣어 더한다.
  Widget _sizesSection() {
    void addSize() {
      final v = parseNumberText(_sizeAdd.text);
      if (v == null || v <= 0 || _sizes.contains(v)) return;
      setState(() {
        _sizes = [..._sizes, v]..sort((a, b) => b.compareTo(a));
        _sizeAdd.clear();
      });
      AlignShimStore.saveSizes(_sizes);
    }

    return PlateSection('가진 심 두께 (mm)', [
      _note('심 판 조합을 셀 때 씁니다. 가진 것만 남기십시오(× 누르면 뺍니다).'),
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
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: PlateNumField(
              fieldKey: 'align_size_add_field',
              label: '두께 더하기',
              hint: '0.3',
              controller: _sizeAdd,
            ),
          ),
          const SizedBox(width: 8),
          PlateActionButton(key: const Key('align_size_add'), icon: AppIcons.add, label: '더하기', onTap: addSize),
        ],
      ),
    ]);
  }

  Widget _roundsSection(AlignResult? r) {
    final moves = moveTotals(_rounds);
    return PlateSection('정렬 작업 회차', [
      if (_rounds.isEmpty)
        _note('결과 탭에서 "회차로 적기"를 누르면 여기에 쌓입니다. 측정 → 심 넣고 빼기·옆으로 밀기 → 재측정을 회차로 남기고, 발마다 넣고 뺀 심이 위 표에 더해집니다.'),
      for (var i = 0; i < _rounds.length; i++)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              padding: const EdgeInsets.symmetric(vertical: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: fc.brandSoft, borderRadius: BorderRadius.circular(8)),
              child: Text('${i + 1}회차', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: fc.brand)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '평행 ${_rounds[i].offset.toStringAsFixed(3)} mm · 각도 ${_rounds[i].angle100.toStringAsFixed(3)} · ${verdictLabel(_rounds[i].verdict)}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: fc.text),
                  ),
                  const SizedBox(height: 2),
                  Text('한 일: ${doneLine(_rounds[i])}', key: Key('align_round_line_$i'), style: TextStyle(fontSize: 12.5, height: 1.45, color: fc.textSub)),
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
      if (moves.$1.abs() >= 0.005 || moves.$2.abs() >= 0.005)
        Text('옆으로 민 누계: 앞 ${moveText(moves.$1)}, 뒤 ${moveText(moves.$2)}', style: TextStyle(fontSize: 12.5, color: fc.textSub)),
      // 회차별 심 누계(예전 화면의 키를 이어 쓴다).
      if (_rounds.any((x) => x.done != null))
        Wrap(
          spacing: 10,
          children: [
            for (final f in AlignFoot.values)
              Text(
                '${f.label} ${signedMm(shimTotals(_rounds)[f]!)} mm',
                key: Key('align_total_${f.name}'),
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: fc.text),
              ),
          ],
        ),
      if (r != null || _rounds.isNotEmpty)
        plateActions([
          if (r != null)
            PlateActionButton(
              key: const Key('align_round_add_here'),
              icon: Icons.playlist_add_check_rounded,
              label: '지금 결과를 ${_rounds.length + 1}회차로',
              onTap: () => _addRound(r),
            ),
          if (_rounds.isNotEmpty)
            PlateActionButton(
              key: const Key('align_round_undo'),
              icon: AppIcons.undo,
              label: '마지막 회차 지우기',
              danger: true,
              onTap: () => _setRounds(_rounds.sublist(0, _rounds.length - 1)),
            ),
        ]),
    ]);
  }
}
