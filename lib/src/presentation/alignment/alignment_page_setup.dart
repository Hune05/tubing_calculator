// ignore_for_file: invalid_use_of_protected_member
part of 'alignment_page.dart';

// ① 준비: 방식, 측정 그림(넣는 거리 연동), 거리, 회전수·판정 기준, 처짐·열팽창, 현장 지침.
extension _AlignSetup on _AlignmentPageState {
  /// 거리 칸에 들어가 있으면 위에 붙이는 작은 그림(그 치수만).
  Widget? _setupPinned() {
    final i = _focus == null ? -1 : _distKeys.indexOf(_focus!);
    if (i < 0) return null;
    return LayoutBuilder(
      builder: (context, c) => SizedBox(
        height: AlignSetupRenderPainter.compactHeightFor(c.maxWidth),
        child: CustomPaint(
          key: const Key('align_setup_pinned'),
          size: Size.infinite,
          painter: AlignSetupRenderPainter(
            _method,
            highlight: i,
            values: [for (final k in _distKeys) _f(k).text.trim()],
            compact: true,
          ),
        ),
      ),
    );
  }

  List<Widget> _setupTab() {
    final reverse = _method == AlignMethod.reverse;
    final keys = _distKeys;
    final hi = _focus == null ? null : keys.indexOf(_focus!);
    return [
      const SizedBox(height: 8),
      SegmentedButton<AlignMethod>(
        key: const Key('align_method'),
        segments: const [
          ButtonSegment(value: AlignMethod.reverse, label: Text('리버스 다이얼')),
          ButtonSegment(value: AlignMethod.rimFace, label: Text('림·페이스')),
        ],
        selected: {_method},
        onSelectionChanged: (s) {
          setState(() {
            _method = s.first;
            _clockDial = _method == AlignMethod.reverse ? 'a' : 'r';
          });
          _saveDraftSoon();
        },
      ),
      const SizedBox(height: 12),
      _methodCard(),
      // 측정 그림: 지금 넣는 거리를 진하게, 넣은 값을 치수선에(10-15 연동).
      Card(
        margin: const EdgeInsets.only(top: 12),
        elevation: 0,
        color: AppColors.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  '거는 자리와 재는 거리',
                  style: AppText.title,
                ),
              ),
              const SizedBox(height: 6),
              LayoutBuilder(
                builder: (context, c) => SizedBox(
                  height: AlignSetupRenderPainter.heightFor(c.maxWidth),
                  child: CustomPaint(
                    key: const Key('align_setup_diagram'),
                    size: Size.infinite,
                    painter: AlignSetupRenderPainter(
                      _method,
                      highlight: hi == null || hi < 0 ? null : hi,
                      values: [for (final k in keys) _f(k).text.trim()],
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(6, 2, 6, 2),
                child: Text(
                  '거리 칸을 누르면 그 치수가 위에 붙어 보이고, 넣은 값이 치수선에 붙습니다(그림 비율: 모터 IEC 160M, 펌프 ISO 2858 65-40-250).',
                  style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSub),
                ),
              ),
            ],
          ),
        ),
      ),
      // 한 칸에 한 줄(10-15: 두 칸씩 놓으니 좁은 폰에서 이름이 "① A·B 두 접…"으로 잘렸다).
      if (reverse)
        _card('거리 (mm)', [
          _row([_field('between', '① A·B 두 접촉면 사이', suffix: 'mm')]),
          _row([_field('coupB', '② B면에서 커플링 중심까지', suffix: 'mm')]),
          _row([_field('front', '③ A면에서 모터 앞발까지', suffix: 'mm')]),
          _row([_field('rear', '④ A면에서 모터 뒷발까지', suffix: 'mm')]),
        ])
      else
        _card('거리 (mm)', [
          _row([_field('coupR', '① 림면에서 커플링 중심까지', suffix: 'mm')]),
          _row([_field('front', '② 림면에서 모터 앞발까지', suffix: 'mm')]),
          _row([_field('rear', '③ 림면에서 모터 뒷발까지', suffix: 'mm')]),
          _row([_field('faceR', '④ 페이스가 닿는 반지름', suffix: 'mm')]),
        ]),
      _tolCard(),
      _toggleCard(
        keyName: 'align_sag_toggle',
        label: '브래킷 처짐 보정 (선택)',
        open: _showSag,
        applied: _hasAny(reverse ? ['sagA', 'sagB'] : ['sagR']),
        onTap: () => setState(() => _showSag = !_showSag),
        child: reverse
            ? _row([_field('sagA', '다이얼 A 처짐 (mm)'), _field('sagB', '다이얼 B 처짐 (mm)')])
            : _row([_field('sagR', '림 다이얼 처짐 (mm)')]),
        help: '같은 다이얼 세팅을 어긋남 없는 곧은 관에 걸고 12시를 0으로 맞춘 뒤 6시에서 읽은 값입니다(보통 마이너스).',
      ),
      _toggleCard(
        keyName: 'align_target_toggle',
        label: '열팽창 목표 (선택)',
        open: _showTarget,
        applied: _hasAny(['targetY', 'targetZ']),
        onTap: () => setState(() => _showTarget = !_showTarget),
        child: _row([_field('targetY', '위아래 목표 (mm)'), _field('targetZ', '옆 목표 (mm)')]),
        help: '차가울 때 모터 축을 커플링 중심에서 이만큼 어긋나게 맞춰 두어야 운전 온도에서 맞는 경우에 넣습니다. + 위·오른쪽. 비우면 0.',
      ),
      _guideEntry(),
    ];
  }

  Widget _guideEntry() => Card(
    margin: const EdgeInsets.only(top: 12),
    elevation: 0,
    color: AppColors.surface,
    child: InkWell(
      key: const Key('align_guide_entry'),
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openGuide(),
      child: const Padding(
        padding: EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            Icon(AppIcons.help, size: 22, color: AppColors.brand),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('현장 지침 (잘 안 맞을 때)', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: AppColors.text)),
                  SizedBox(height: 2),
                  Text('배관 당김·용접 변형·소프트 풋·못 돌림·볼트 바운드 등 경우별 조치', style: TextStyle(fontSize: 12.5, color: AppColors.textSub)),
                ],
              ),
            ),
            Icon(AppIcons.forward, size: 18, color: AppColors.textFaint),
          ],
        ),
      ),
    ),
  );

  Widget _methodCard() {
    final reverse = _method == AlignMethod.reverse;
    Widget line(String head, String body, Color c) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 1),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
            child: Text(head, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: c)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(body, style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.text))),
        ],
      ),
    );
    final head = Row(
      children: [
        Expanded(
          child: Text(
            reverse ? '리버스 다이얼 방식' : '림·페이스 방식',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.text),
          ),
        ),
        Text(_showMethodHelp ? '접기' : '설명 보기', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.brand)),
        Icon(_showMethodHelp ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 20, color: AppColors.brand),
      ],
    );
    return Material(
      key: const Key('align_method_help'),
      color: AppColors.brandSoft,
      borderRadius: BorderRadius.circular(AppRadius.medium),
      child: InkWell(
        key: const Key('align_method_help_toggle'),
        borderRadius: BorderRadius.circular(AppRadius.medium),
        onTap: () => setState(() => _showMethodHelp = !_showMethodHelp),
        child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: !_showMethodHelp
            ? [head]
            : reverse
            ? [
                head,
                line('측정 방법', '다이얼 두 개를 서로 반대로 걸어, 각각 상대 축의 림(바깥 둘레)을 읽습니다. A는 펌프 쪽에 걸어 모터 림을, B는 모터 쪽에 걸어 펌프 림을 읽습니다.', AppColors.brand),
                line('좋은 점', '옆면(페이스)을 측정하지 않아 축이 앞뒤로 밀려도 값이 덜 틀어집니다. 커플링 사이가 먼 경우(스페이서)에도 맞습니다.', AppColors.ok),
                line('주의', '두 접촉면 사이(①)가 짧으면 기울기 오차가 커집니다. 브래킷이 길면 처짐 보정을 넣습니다.', AppColors.caution),
              ]
            : [
                head,
                line('측정 방법', '브래킷 하나에 다이얼 두 개를 달아, 하나는 모터 쪽 커플링의 림(바깥 둘레)을, 하나는 페이스(옆면)를 읽습니다. 림은 어긋남, 페이스는 기울기를 봅니다.', AppColors.brand),
                line('좋은 점', '한쪽 축에서만 걸면 되어 자리가 좁을 때 쉽습니다. 커플링 지름이 크고 사이가 가까울 때 잘 맞습니다.', AppColors.ok),
                line('주의', '돌리는 동안 축이 앞뒤로 밀리면 페이스 값이 틀어집니다. 축을 한쪽으로 밀어 붙인 채 읽습니다. 페이스가 닿는 반지름(④)을 정확히 측정합니다.', AppColors.caution),
              ],
      ),
        ),
      ),
    );
  }

  Widget _tolCard() => _card('회전수와 판정 기준', [
    _row([_field('rpm', '회전수 (rpm)', hint: '예: 1800')]),
    Text(
      '판정에 쓰는 현장 기준입니다. 처음에는 0.05 mm(100분의 5)로 두었고, 고치면 폰에 남아 다음에도 그 값으로 판정합니다. '
      '참고로 흔히 쓰는 경험값은 $_rpm rpm에서 평행 ${defaultTolerance(_rpm).offset.toStringAsFixed(2)} mm입니다. 제조사·사내 기준이 우선입니다.',
      style: const TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSub),
    ),
    const SizedBox(height: 8),
    Row(
      children: [
        Expanded(
          child: TextField(
            key: const Key('align_tol_offset'),
            controller: _tolO,
            onChanged: (_) => _saveTol(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '평행 어긋남 허용 (mm)', isDense: true),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            key: const Key('align_tol_angle'),
            controller: _tolA,
            onChanged: (_) => _saveTol(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '각도 허용 (mm/100mm)', isDense: true),
          ),
        ),
      ],
    ),
  ]);
}
