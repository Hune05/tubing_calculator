// ignore_for_file: invalid_use_of_protected_member
part of 'alignment_page.dart';

// ② 측정: 보는 자리 시계 그림(바늘이 넣은 값대로·넣는 자리 강조), 다이얼별 읽음값과 바로 검산, 다이얼 보는 법.
extension _AlignMeasure on _AlignmentPageState {
  /// 지시값 칸에 들어가 있으면 위에 붙이는 작은 시계 그림.
  Widget? _measurePinned() {
    final m = _focus == null ? null : RegExp(r'^([abrf])(90|180|270)$').firstMatch(_focus!);
    if (m == null) return null;
    final p = m.group(1)!;
    final hi = switch (m.group(2)) { '90' => 1, '180' => 2, _ => 3 };
    return SizedBox(
      height: 236,
      child: CustomPaint(
        key: const Key('align_clock_pinned'),
        size: Size.infinite,
        painter: AlignClockPainter(
          values: [for (final a in ['90', '180', '270']) _n('$p$a')],
          highlight: hi,
          title: _dialName(p),
        ),
      ),
    );
  }

  String _dialName(String p) => switch (p) {
    'a' => '다이얼 A (모터 림)',
    'b' => '다이얼 B (펌프 림)',
    'r' => '림 (바깥 둘레)',
    _ => '페이스 (옆면)',
  };

  List<Widget> _measureTab(({AlignResult? result, String? error}) solved) {
    final dials = _dials;
    final p = dials.contains(_clockDial) ? _clockDial : dials.first;
    final vals = [for (final a in ['90', '180', '270']) _n('$p$a')];
    int? hi;
    final m = _focus == null ? null : RegExp(r'^([abrf])(90|180|270)$').firstMatch(_focus!);
    if (m != null && m.group(1) == p) {
      hi = switch (m.group(2)) { '90' => 1, '180' => 2, _ => 3 };
    }
    return [
      Card(
        margin: const EdgeInsets.only(top: 12),
        elevation: 0,
        color: AppColors.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: Text('보는 자리와 읽은 값', style: AppText.title)),
                  for (final d in dials)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ChoiceChip(
                        key: Key('align_clock_dial_$d'),
                        label: Text(switch (d) { 'a' => 'A', 'b' => 'B', 'r' => '림', _ => '페이스' }),
                        selected: p == d,
                        showCheckmark: false,
                        selectedColor: AppColors.brandSoft,
                        onSelected: (_) => setState(() => _clockDial = d),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 300,
                child: CustomPaint(
                  key: const Key('align_clock'),
                  size: Size.infinite,
                  painter: AlignClockPainter(values: vals, highlight: hi, title: _dialName(p)),
                ),
              ),
              _checkLine(p),
              const SizedBox(height: 6),
              const Text(
                '고정 쪽(펌프)에 서서 이동 쪽(모터)을 바라봅니다. 이 자리에서 3시가 오른쪽, 9시가 왼쪽입니다. '
                '12시에서 0을 맞추고 축을 같이 돌려 3시 → 6시 → 9시 순서로 읽습니다. 아래 칸에 넣으면 그림의 바늘이 그 값을 가리킵니다.',
                style: TextStyle(fontSize: 12.5, height: 1.55, color: AppColors.textSub),
              ),
            ],
          ),
        ),
      ),
      if (_method == AlignMethod.reverse)
        _card('지시값 (12시는 0)', [
          _readingRow('a', '다이얼 A (고정 쪽에 걸고 모터 림을 읽음)'),
          _readingRow('b', '다이얼 B (모터 쪽에 걸고 펌프 림을 읽음)'),
        ])
      else
        _card('지시값 (12시는 0)', [
          _readingRow('r', '림 (바깥둘레)'),
          _readingRow('f', '페이스 (옆면)'),
        ]),
      _dialGuide(),
      if (solved.error != null) _notice(solved.error!, AppColors.danger, key: 'align_error_measure'),
    ];
  }

  /// 바로 검산: 3시 + 9시 = 6시면 제대로 읽은 것(10-15, 예전엔 결과에서만 알았다).
  Widget _checkLine(String p) {
    final a = _n('${p}90'), b = _n('${p}180'), c = _n('${p}270');
    if (a == null || b == null || c == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 4),
        child: Text('세 자리를 다 넣으면 3시 + 9시 = 6시인지 바로 봅니다.', style: TextStyle(fontSize: 12.5, color: AppColors.textSub)),
      );
    }
    final diff = (a + c - b).abs();
    final ok = diff <= 0.05;
    final col = ok ? AppColors.ok : AppColors.caution;
    return Container(
      key: Key('align_check_$p'),
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: col.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: Text(
        ok
            ? '검산 맞음: 3시 + 9시 = ${(a + c).toStringAsFixed(2)}, 6시 = ${b.toStringAsFixed(2)}'
            : '검산 안 맞음(차이 ${diff.toStringAsFixed(2)}): 3시 + 9시 = ${(a + c).toStringAsFixed(2)}, 6시 = ${b.toStringAsFixed(2)}. 다시 읽어 보십시오.',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: col),
      ),
    );
  }

  Widget _readingRow(String p, String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSub)),
        const SizedBox(height: 6),
        _row([
          _field('${p}90', '3시'),
          _field('${p}180', '6시'),
          _field('${p}270', '9시'),
        ]),
      ],
    ),
  );

  /// 다이얼 게이지 쓰는 법과 읽는 법(접어 둠).
  Widget _dialGuide() {
    Widget tile(double v, String caption, {bool bezel = false}) => Expanded(
      child: Column(
        children: [
          SizedBox(height: 104, child: CustomPaint(size: Size.infinite, painter: AlignSmallDialPainter(v, bezelArrow: bezel))),
          const SizedBox(height: 4),
          Text(caption, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, height: 1.35, color: AppColors.text, fontWeight: FontWeight.w600)),
        ],
      ),
    );
    return Card(
      margin: const EdgeInsets.only(top: 12),
      elevation: 0,
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const Key('align_dial_guide_tile'),
        title: const Text('다이얼 게이지 보는 법', style: AppText.title),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 300,
            child: CustomPaint(key: const Key('align_dial_guide'), size: Size.infinite, painter: AlignDialGuidePainter(value: -0.12)),
          ),
          const SizedBox(height: 4),
          const Text(
            '큰 바늘이 0에서 시계 방향으로 가면 +(스핀들이 눌림), 반대로 가면 −(스핀들이 나옴)입니다. '
            '위 그림은 0에서 반시계 방향으로 12칸 → −0.12 mm입니다.',
            style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.textSub),
          ),
          const SizedBox(height: 14),
          Text('거는 순서', style: AppText.subtitle),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              tile(0.5, '① 스핀들을 0.5 mm쯤\n눌러서 겁니다'),
              tile(0, '② 12시에서 베젤을\n돌려 0에 맞춥니다', bezel: true),
              tile(-0.10, '③ 두 축을 같이 돌려\n3·6·9시에서 읽습니다'),
              tile(0, '④ 12시로 오면\n다시 0인지 봅니다'),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            '3시 + 9시 = 6시가 되면 제대로 읽은 것입니다. 크게 다르면 브래킷이 흔들리거나 스핀들이 덜 눌린 것이니 다시 겁니다. '
            '결과의 "넣기"는 발 밑에 심을 넣어 모터를 올리는 것, "오른쪽"은 이 자리에서 본 오른쪽입니다.',
            style: TextStyle(fontSize: 12.5, height: 1.55, color: AppColors.textSub),
          ),
        ],
      ),
    );
  }
}
