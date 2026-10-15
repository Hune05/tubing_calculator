// ignore_for_file: invalid_use_of_protected_member
part of 'alignment_page.dart';

// 결과 탭: 판정, 검산 경고, 발 이동량(심 판 조합까지), 회차로 적기·기록 남기기. 위 그림은 옆/위에서 본 모양(계산값대로).
extension _AlignResultTab on _AlignmentPageState {
  Widget _resultCanvas(AlignResult? r) {
    if (_planError != null) return _canvasEmpty('고정 발을 바꿨습니다. 펌프 발까지 거리를 넣으면 셉니다.');
    if (r == null) {
      return _canvasEmpty(
        _distancesDone ? '지시값을 다 넣으면 계산한 모양이 나옵니다.' : '거리와 지시값을 다 넣으면 계산한 모양이 나옵니다.',
      );
    }
    final top = _resultView == 'top';
    return Padding(
      // 오른쪽 위 보기 단추 자리를 비운다.
      padding: const EdgeInsets.fromLTRB(4, 46, 4, 28),
      child: CustomPaint(
        key: Key(top ? 'align_plan' : 'align_diagram_v'),
        size: Size.infinite,
        painter: top
            ? AlignTopRenderPainter(
                horizontal: r.horizontal,
                xRear: _rearX,
                shimFront: r.shimFront,
                shimRear: r.shimRear,
                moveFront: r.moveFront,
                moveRear: r.moveRear,
              )
            : AlignSideRenderPainter(
                vertical: r.vertical,
                xRear: _rearX,
                shimFront: r.shimFront,
                shimRear: r.shimRear,
              ),
      ),
    );
  }

  Widget _resultPanel(({AlignResult? result, String? error}) solved) {
    final r = solved.result;
    final help = plateHelpButton(context, 'align_result_help', '결과 보는 법', [
      '심 +는 발 밑에 그 두께만큼 넣어 모터를 올리고, −는 그만큼 빼서 내립니다. 왼쪽 발과 오른쪽 발은 같은 값입니다.',
      '옆 이동은 펌프 쪽에서 모터를 볼 때 오른쪽·왼쪽입니다.',
      '심을 넣고 빼고 옆으로 민 뒤 "회차로 적기"를 누르면 심 기록 탭에 발마다 쌓입니다. 다시 재서 지시값 탭에 넣으면 결과가 바뀝니다.',
      '이 결과는 두 축의 어긋남을 직선으로 본 계산입니다. 소프트 풋(발 뜸)·배관 당김(파이프 스트레인)·커플링 상태는 따로 확인하십시오.',
      '제조사·사내 정렬 기준이 있으면 그것이 우선입니다.',
    ]);
    if (solved.error != null || r == null) {
      final missing = [
        if (!_distancesDone) '거리',
        if (!_readingsDone) '지시값',
      ];
      return PlatePanel(
        title: '결과',
        status: solved.error != null ? '넣은 값을 확인하십시오.' : '${missing.join('과 ')}을 모두 넣으면 결과가 나옵니다.',
        statusKey: const Key('align_hint'),
        statusColor: solved.error != null ? fc.danger : null,
        actions: [help],
        children: [
          if (solved.error != null) _notice(solved.error!, fc.danger, key: 'align_error'),
          if (solved.error == null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: PlateActionButton(
                key: const Key('align_hint_go'),
                icon: AppIcons.forward,
                label: _distancesDone ? '지시값 넣으러 가기' : '거리 넣으러 가기',
                onTap: () => _go(_distancesDone ? 1 : 0),
              ),
            ),
          ],
        ],
      );
    }
    final tol = _tol;
    final v = judge(r, tol);
    final ok = v == AlignVerdict.ok;
    final color = ok ? fc.ok : fc.danger;
    return PlatePanel(
      title: '결과',
      status: ok ? '합격: 허용오차 이내입니다' : verdictLabel(v),
      statusKey: const Key('align_verdict'),
      statusColor: color,
      actions: [help],
      footer: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              key: const Key('align_round_add'),
              style: OutlinedButton.styleFrom(
                foregroundColor: fc.text,
                side: BorderSide(color: fc.line),
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: _planError != null ? null : () => _addRound(r),
              icon: const Icon(Icons.playlist_add_check_rounded, size: 20),
              label: Text('${_rounds.length + 1}회차로 적기', style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: _saveButton(_planError != null ? null : r)),
        ],
      ),
      children: [
        // 할 일(심·옆 이동)을 맨 위에(10-15: 세로 폰에서 판정 막대·알림에 밀려 안 보였다).
        // 고정 발을 바꿨는데 펌프 거리가 없으면 옛 값(펌프 고정)이 보이지 않게 알림만(10-15 태블릿 확인).
        PlateSection(_plan?.pumpMoves ?? false ? '발 이동량 (모터·펌프)' : '발 이동량 (모터)', [
          if (_planError != null)
            _note('고정 발을 바꿨습니다. 아래 "고정 발"에 펌프 발까지 거리를 넣으면 네 발 값을 셉니다.')
          else
            _shimTable(r),
        ], first: true),
        if (r.closure > 0.05)
          _notice(
            '지시값이 서로 안 맞습니다 (3시 + 9시 ≠ 6시, 차이 ${r.closure.toStringAsFixed(2)} mm). '
            '다이얼이 흔들렸거나 부호를 잘못 넣었을 수 있습니다. 다시 읽어 보십시오.',
            fc.caution,
            key: 'align_closure',
            guideId: 'closure',
          ),
        // 소프트 풋이 남아 있으면 이 결과로 맞춰도 볼트를 조이면 틀어진다(10-15).
        if (softFootOver(_softFoot) case final over when over.isNotEmpty)
          _notice(
            '소프트 풋이 남아 있습니다(${softFootList(_softFoot, over)} mm). 먼저 고치고 다시 재야 이 결과가 맞습니다.',
            fc.caution,
            key: 'align_softfoot_warn',
            guideId: 'softfoot',
          ),
        _fixedSection(),
        PlateSection('판정', [
          _gauge('평행 어긋남', r.offset, tol.offset),
          _gauge('각도', r.angle100, tol.angle100),
          Text(
            '평행 어긋남 ${r.offset.toStringAsFixed(3)} mm (허용 ${tol.offset.toStringAsFixed(2)})  ·  '
            '각도 ${r.angle100.toStringAsFixed(3)} mm/100mm (허용 ${tol.angle100.toStringAsFixed(2)})',
            key: const Key('align_offsets'),
            style: TextStyle(fontSize: 13, height: 1.5, color: fc.text),
          ),
        ]),
        if (_rounds.isNotEmpty)
          PlateSection('이번 작업', [
            _note('${_rounds.length}회차까지 적었습니다. 마지막: 평행 ${_rounds.last.offset.toStringAsFixed(3)} mm · ${verdictLabel(_rounds.last.verdict)}. 회차와 네 발 심은 심 기록 탭에 있습니다.'),
          ]),
      ],
    );
  }

  /// 기록 남기기(결과·심 기록 탭 아래).
  Widget _saveButton(AlignResult? r) => FilledButton.icon(
    key: const Key('align_save'),
    style: FilledButton.styleFrom(
      backgroundColor: fc.brand,
      foregroundColor: fc.onBrand,
      minimumSize: const Size(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    onPressed: r == null ? null : () => _save(r),
    icon: const Icon(AppIcons.save, size: 18),
    label: Text(r == null ? (_planError != null ? '펌프 거리를 넣어야 저장' : '결과가 나와야 저장') : '기록 남기기', style: const TextStyle(fontWeight: FontWeight.w800)),
  );

  /// 허용 대비 막대(허용선까지 초록, 넘으면 빨강).
  Widget _gauge(String label, double v, double tol) {
    final over = v > tol;
    final frac = tol <= 0 ? 1.0 : (v / (tol * 2)).clamp(0.0, 1.0);
    final c = over ? fc.danger : fc.ok;
    return Row(
      children: [
        SizedBox(width: 78, child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: fc.textSub))),
        Expanded(
          child: LayoutBuilder(
            builder: (context, cs) => Stack(
              clipBehavior: Clip.none,
              children: [
                Container(height: 10, decoration: BoxDecoration(color: fc.line, borderRadius: BorderRadius.circular(4))),
                Container(
                  height: 10,
                  width: cs.maxWidth * frac,
                  decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)),
                ),
                // 허용선(막대 가운데)
                Positioned(
                  left: cs.maxWidth / 2 - 1,
                  top: -3,
                  child: Container(width: 2, height: 16, color: fc.text),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 62,
          child: Text(
            v.toStringAsFixed(3),
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: c),
          ),
        ),
      ],
    );
  }

  Widget _shimTable(AlignResult r) {
    final p = _plan;
    final pump = p != null && p.pumpMoves;
    final labelW = pump ? 104.0 : 50.0; // "펌프 안쪽발"이 큰 글씨·태블릿에서 두 줄로 꺾였다
    Widget line(String id, String foot, double shim, double move, {bool plates = true}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(width: labelW, child: Text(foot, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: fc.textSub))),
            // 펌프 발까지 넷이면 글씨를 조금 줄이고 칸 사이를 띄운다(10-15: 두 칸 글씨가 붙었다).
            Expanded(
              flex: 11,
              child: Text(
                '심 ${shimText(shim)}',
                key: Key('align_shim_$id'),
                style: TextStyle(fontSize: pump ? 15 : 17, fontWeight: FontWeight.w900, color: shim.abs() < 0.005 ? fc.ok : fc.text),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 9,
              child: Text(
                '옆 ${moveText(move)}',
                key: Key('align_move_$id'),
                style: TextStyle(fontSize: pump ? 15 : 17, fontWeight: FontWeight.w900, color: move.abs() < 0.005 ? fc.ok : fc.text),
              ),
            ),
          ],
        ),
        // 가진 심으로 몇 장(10-15).
        if (plates && shim.abs() >= 0.005)
          Padding(
            padding: EdgeInsets.only(left: labelW, top: 2),
            child: Text(
              '${shim > 0 ? '넣을' : '뺄'} 심 판: ${shimPlateText(shim, _sizes)}',
              key: Key('align_plates_$id'),
              style: TextStyle(fontSize: 12.5, color: fc.textSub),
            ),
          ),
      ],
    );

    return Column(
      children: [
        line('front', pump ? '모터 앞발' : '앞발', r.shimFront, r.moveFront),
        Divider(height: 18, color: fc.line),
        line('rear', pump ? '모터 뒷발' : '뒷발', r.shimRear, r.moveRear),
        // 고정 발을 바꿔 펌프도 움직일 때(10-15).
        if (pump)
          for (final f in [AlignFootPos.pumpInner, AlignFootPos.pumpOuter])
            if (p.feet[f] case final v?) ...[
              Divider(height: 18, color: fc.line),
              line(f.name, f.label, v.shim, v.move),
            ],
      ],
    );
  }

  /// 고정 발 고르기(10-15): 모터 심을 더 뺄 수 없거나(베이스 바운드) 볼트 구멍이 걸릴 때(볼트 바운드) 펌프도 움직인다.
  Widget _fixedSection() {
    final raw = _solve().result;
    // 심 기록에 심을 적어 둔 경우에만 "뺄 심이 모자람"을 본다(안 적었으면 모두 0이라 늘 모자라게 나온다).
    final now = footNow(_startMap, _rounds);
    final knowsShim = now.values.any((v) => v.abs() >= 0.005);
    Map<AlignFootPos, double> short = const {};
    if (raw != null && knowsShim) {
      final cur = _plan ??
          alignPlan(r: raw, fixed: kAlignFixedDefault, xFront: _frontX, xRear: _rearX, targetY: _opt('targetY'), targetZ: _opt('targetZ'));
      short = alignShortShim(cur, now);
    }
    final needPump = !_fixedDefault || short.isNotEmpty;

    void pick(AlignFootPos f) {
      if (_fixed.contains(f)) return;
      setState(() => _fixed = [_fixed.last, f]);
      _saveDraftSoon();
    }

    void auto() {
      final pi = _n('pumpIn'), po = _n('pumpOut');
      if (raw == null) return;
      if (pi == null || po == null) {
        _toast('펌프 안쪽발·바깥발까지 거리를 먼저 넣으십시오');
        return;
      }
      final best = alignAutoFixed(
        r: raw, now: now, xFront: _frontX, xRear: _rearX, pumpInner: pi, pumpOuter: po,
        targetY: _opt('targetY'), targetZ: _opt('targetZ'),
      );
      if (best == null) {
        _toast('어느 두 발을 고정해도 심이 모자랍니다. 심을 더 넣을 자리(받침 높이)를 먼저 보십시오');
        return;
      }
      setState(() => _fixed = best.toList());
      _saveDraftSoon();
      _toast('고정 발: ${best.map((e) => e.label).join('·')}');
    }

    return PlateSection(
      '고정 발 (심·볼트가 걸릴 때)',
      [
        _note('보통은 펌프 두 발을 고정하고 모터만 움직입니다. 모터 심을 더 뺄 수 없거나 볼트 구멍이 걸려 더 못 밀면, 움직이지 않을 두 발을 바꾸십시오(셋째를 누르면 먼저 고른 것이 빠집니다).'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final f in AlignFootPos.values)
              FilterChip(
                key: Key('align_fix_${f.name}'),
                label: Text(f.label),
                selected: _fixed.contains(f),
                showCheckmark: true,
                selectedColor: fc.brandSoft,
                onSelected: (_) => pick(f),
              ),
          ],
        ),
        if (needPump)
          plateRow([
            _field('pumpIn', '커플링 중심 → 펌프 안쪽발', signed: false),
            _field('pumpOut', '→ 펌프 바깥발', signed: false),
          ]),
        if (_planError != null) _notice(_planError!, fc.danger, key: 'align_plan_error'),
        if (short.isNotEmpty) ...[
          _notice(
            '${[for (final e in short.entries) '${e.key.label} ${e.value.toStringAsFixed(2)} mm'].join(', ')}만큼 뺄 심이 모자랍니다(심 기록의 지금 심보다 더 빼야 함). '
            '펌프를 올리는 쪽으로 고정 발을 바꾸십시오.',
            fc.caution,
            key: 'align_short_shim',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: PlateActionButton(
              key: const Key('align_fix_auto'),
              icon: Icons.auto_fix_high_rounded,
              label: '모자라지 않게 고정 발 고르기',
              onTap: auto,
            ),
          ),
        ],
        if (!_fixedDefault)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('align_fix_reset'),
              onPressed: () {
                setState(() => _fixed = List.of(kAlignFixedDefault));
                _saveDraftSoon();
              },
              child: const Text('처음대로(펌프 고정, 모터만 움직임)'),
            ),
          ),
      ],
    );
  }
}
