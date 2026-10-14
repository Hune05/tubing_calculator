// ignore_for_file: invalid_use_of_protected_member
part of 'alignment_page.dart';

// ③ 결과: 판정, 검산 경고, 발 이동량(심 판 조합까지), 위·옆에서 본 그림(계산값대로 움직임), 회차로 적기.
extension _AlignResultTab on _AlignmentPageState {
  List<Widget> _resultTab(({AlignResult? result, String? error}) solved) {
    final r = solved.result;
    if (solved.error != null) {
      return [_notice(solved.error!, AppColors.danger, key: 'align_error')];
    }
    if (r == null) {
      final missing = [
        if (!_distancesDone) '① 준비의 거리',
        if (!_readingsDone) '② 측정의 지시값',
      ];
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Column(
            children: [
              Text(
                '${missing.join('과 ')}을 모두 넣으면 결과가 나옵니다.',
                key: const Key('align_hint'),
                textAlign: TextAlign.center,
                style: AppText.sub,
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                key: const Key('align_hint_go'),
                onPressed: () => _go(_distancesDone ? 1 : 0),
                child: Text(_distancesDone ? '측정으로' : '준비로'),
              ),
            ],
          ),
        ),
      ];
    }
    final tol = _tol;
    final v = judge(r, tol);
    final ok = v == AlignVerdict.ok;
    final color = ok ? AppColors.ok : AppColors.danger;
    return [
      Container(
        key: const Key('align_verdict'),
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ok ? '합격: 허용오차 이내입니다' : verdictLabel(v),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color),
            ),
            const SizedBox(height: 10),
            _gauge('평행 어긋남', r.offset, tol.offset, 'mm'),
            const SizedBox(height: 8),
            _gauge('각도', r.angle100, tol.angle100, 'mm/100mm'),
            const SizedBox(height: 6),
            Text(
              '평행 어긋남 ${r.offset.toStringAsFixed(3)} mm (허용 ${tol.offset.toStringAsFixed(2)})  ·  '
              '각도 ${r.angle100.toStringAsFixed(3)} mm/100mm (허용 ${tol.angle100.toStringAsFixed(2)})',
              key: const Key('align_offsets'),
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
      if (r.closure > 0.05)
        _notice(
          '지시값이 서로 안 맞습니다 (3시 + 9시 ≠ 6시, 차이 ${r.closure.toStringAsFixed(2)} mm). '
          '다이얼이 흔들렸거나 부호를 잘못 넣었을 수 있습니다. 다시 읽어 보십시오.',
          AppColors.caution,
          key: 'align_closure',
          guideId: 'closure',
        ),
      _card('발 이동량 (모터)', [_shimTable(r)]),
      Card(
        margin: const EdgeInsets.only(top: 12),
        elevation: 0,
        color: AppColors.surface,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('위에서 본 모양 (네 발 심, 옆 이동)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSub)),
                ),
              ),
              LayoutBuilder(
                builder: (context, c) => SizedBox(
                  height: AlignTopRenderPainter.heightFor(c.maxWidth),
                  child: CustomPaint(
                    key: const Key('align_plan'),
                    size: Size.infinite,
                    painter: AlignTopRenderPainter(
                      horizontal: r.horizontal,
                      xRear: _rearX,
                      shimFront: r.shimFront,
                      shimRear: r.shimRear,
                      moveFront: r.moveFront,
                      moveRear: r.moveRear,
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('옆에서 본 모양 (네 발 심, 위아래)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSub)),
                ),
              ),
              LayoutBuilder(
                builder: (context, c) => SizedBox(
                  height: AlignSideRenderPainter.heightFor(c.maxWidth),
                  child: CustomPaint(
                    key: const Key('align_diagram_v'),
                    size: Size.infinite,
                    painter: AlignSideRenderPainter(
                      vertical: r.vertical,
                      xRear: _rearX,
                      shimFront: r.shimFront,
                      shimRear: r.shimRear,
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 4, 8, 4),
                child: Text(
                  '그림의 심 판 두께와 옆 어긋남은 크게 부풀린 것입니다. 실제 값은 위 표를 보십시오. 왼쪽 발과 오른쪽 발은 같은 값입니다.',
                  style: TextStyle(fontSize: 11, color: AppColors.textFaint),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      FilledButton.tonalIcon(
        key: const Key('align_round_add'),
        onPressed: () => _addRound(r),
        icon: const Icon(Icons.playlist_add_check_rounded, size: 20),
        label: Text('이대로 하고 ${_rounds.length + 1}회차로 적기'),
      ),
      const SizedBox(height: 6),
      const Text(
        '심을 넣고 빼고 옆으로 민 뒤 "회차로 적기"를 누르면 ④ 심 기록에 발마다 쌓입니다. 다시 재서 ②에 넣으면 결과가 바뀝니다.\n'
        '이 결과는 두 축의 어긋남을 직선으로 본 계산입니다. 소프트 풋(발 뜸)·배관 당김(파이프 스트레인)·커플링 상태는 따로 확인하십시오. '
        '제조사·사내 정렬 기준이 있으면 그것이 우선입니다.',
        style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textFaint),
      ),
    ];
  }

  /// 허용 대비 막대(허용선까지 초록, 넘으면 빨강).
  Widget _gauge(String label, double v, double tol, String unit) {
    final over = v > tol;
    final frac = tol <= 0 ? 1.0 : (v / (tol * 2)).clamp(0.0, 1.0);
    final c = over ? AppColors.danger : AppColors.ok;
    return Row(
      children: [
        SizedBox(width: 74, child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textSub))),
        Expanded(
          child: LayoutBuilder(
            builder: (context, cs) => Stack(
              clipBehavior: Clip.none,
              children: [
                Container(height: 10, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(5))),
                Container(
                  height: 10,
                  width: cs.maxWidth * frac,
                  decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(5)),
                ),
                // 허용선(막대 가운데)
                Positioned(
                  left: cs.maxWidth / 2 - 1,
                  top: -3,
                  child: Container(width: 2, height: 16, color: AppColors.text),
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
    Widget line(String foot, double shim, double move) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(width: 56, child: Text(foot, style: const TextStyle(fontWeight: FontWeight.w800))),
              Expanded(
                child: Text(
                  '심 ${shimText(shim)}',
                  key: Key('align_shim_${foot == '앞발' ? 'front' : 'rear'}'),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: shim.abs() < 0.005 ? AppColors.ok : AppColors.text),
                ),
              ),
              Expanded(
                child: Text(
                  '옆 ${moveText(move)}',
                  key: Key('align_move_${foot == '앞발' ? 'front' : 'rear'}'),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: move.abs() < 0.005 ? AppColors.ok : AppColors.text),
                ),
              ),
            ],
          ),
          // 가진 심으로 몇 장(10-15).
          if (shim.abs() >= 0.005)
            Padding(
              padding: const EdgeInsets.only(left: 56, top: 2),
              child: Text(
                '${shim > 0 ? '넣을' : '뺄'} 심 판: ${shimPlateText(shim, _sizes)}',
                key: Key('align_plates_${foot == '앞발' ? 'front' : 'rear'}'),
                style: const TextStyle(fontSize: 12.5, color: AppColors.textSub),
              ),
            ),
        ],
      ),
    );
    return Column(children: [line('앞발', r.shimFront, r.moveFront), const Divider(height: 1), line('뒷발', r.shimRear, r.moveRear)]);
  }
}
