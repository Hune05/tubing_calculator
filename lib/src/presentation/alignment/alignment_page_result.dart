// ignore_for_file: invalid_use_of_protected_member
part of 'alignment_page.dart';

// 결과 탭: 판정, 검산 경고, 발 이동량(심 판 조합까지), 회차로 적기·기록 남기기. 위 그림은 옆/위에서 본 모양(계산값대로).
extension _AlignResultTab on _AlignmentPageState {
  Widget _resultCanvas(AlignResult? r) {
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _addRound(r),
              icon: const Icon(Icons.playlist_add_check_rounded, size: 20),
              label: Text('${_rounds.length + 1}회차로 적기', style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: _saveButton(r)),
        ],
      ),
      children: [
        // 할 일(심·옆 이동)을 맨 위에(10-15: 세로 폰에서 판정 막대·알림에 밀려 안 보였다).
        PlateSection('발 이동량 (모터)', [_shimTable(r)], first: true),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    onPressed: r == null ? null : () => _save(r),
    icon: const Icon(AppIcons.save, size: 18),
    label: Text(r == null ? '결과가 나와야 저장' : '기록 남기기', style: const TextStyle(fontWeight: FontWeight.w800)),
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
                Container(height: 10, decoration: BoxDecoration(color: fc.line, borderRadius: BorderRadius.circular(5))),
                Container(
                  height: 10,
                  width: cs.maxWidth * frac,
                  decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(5)),
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
    Widget line(String foot, double shim, double move) {
      final id = foot == '앞발' ? 'front' : 'rear';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(width: 50, child: Text(foot, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: fc.textSub))),
              Expanded(
                child: Text(
                  '심 ${shimText(shim)}',
                  key: Key('align_shim_$id'),
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: shim.abs() < 0.005 ? fc.ok : fc.text),
                ),
              ),
              Expanded(
                child: Text(
                  '옆 ${moveText(move)}',
                  key: Key('align_move_$id'),
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: move.abs() < 0.005 ? fc.ok : fc.text),
                ),
              ),
            ],
          ),
          // 가진 심으로 몇 장(10-15).
          if (shim.abs() >= 0.005)
            Padding(
              padding: const EdgeInsets.only(left: 50, top: 2),
              child: Text(
                '${shim > 0 ? '넣을' : '뺄'} 심 판: ${shimPlateText(shim, _sizes)}',
                key: Key('align_plates_$id'),
                style: TextStyle(fontSize: 12.5, color: fc.textSub),
              ),
            ),
        ],
      );
    }

    return Column(
      children: [
        line('앞발', r.shimFront, r.moveFront),
        Divider(height: 18, color: fc.line),
        line('뒷발', r.shimRear, r.moveRear),
      ],
    );
  }
}
