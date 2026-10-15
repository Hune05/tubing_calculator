// ignore_for_file: invalid_use_of_protected_member
part of 'alignment_page.dart';

// 지시값 탭: 다이얼별 3·6·9시와 바로 검산. 위 그림은 보는 자리 시계(바늘이 넣은 값대로, 넣는 자리 강조).
extension _AlignMeasure on _AlignmentPageState {
  String _dialName(String p) => switch (p) {
    'a' => '다이얼 A (모터 림)',
    'b' => '다이얼 B (펌프 림)',
    'r' => '림 (바깥 둘레)',
    _ => '페이스 (옆면)',
  };

  String _dialShort(String p) => switch (p) { 'a' => 'A', 'b' => 'B', 'r' => '림', _ => '페이스' };

  String get _shownDial => _dials.contains(_clockDial) ? _clockDial : _dials.first;

  Widget _measureCanvas() {
    final p = _shownDial;
    int? hi;
    final m = _focus == null ? null : RegExp(r'^([abrf])(90|180|270)$').firstMatch(_focus!);
    if (m != null && m.group(1) == p) {
      hi = switch (m.group(2)) { '90' => 1, '180' => 2, _ => 3 };
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 30),
      child: CustomPaint(
        key: const Key('align_clock'),
        size: Size.infinite,
        painter: AlignClockPainter(
          // 3점 측정이면 채운 값도 바늘로(10-15).
          values: () {
            final f = fillReadings(_n('${p}90'), _n('${p}180'), _n('${p}270'));
            return f == null ? [for (final a in ['90', '180', '270']) _n('$p$a')] : [f.r90, f.r180, f.r270];
          }(),
          highlight: hi,
          title: _dialName(p),
        ),
      ),
    );
  }

  /// 그림 오른쪽 위: 어느 다이얼을 그릴지.
  Widget _dialSwitch() => PlateViewSwitch([
    for (final d in _dials)
      PlateOption('align_clock_dial_$d', _dialShort(d), _shownDial == d, () => setState(() => _clockDial = d)),
  ]);

  Widget _measurePanel(({AlignResult? result, String? error}) solved) {
    final reverse = _method == AlignMethod.reverse;
    final left = _readingKeys.length - _readingCount;
    final done = _readingsDone;
    return PlatePanel(
      title: '지시값',
      status: done
          ? (left == 0 ? '지시값을 다 넣었습니다. 결과 탭에서 보십시오.' : '빈 자리는 3시 + 9시 = 6시로 셉니다(3점 측정). 결과 탭에서 보십시오.')
          : '12시에서 0을 맞추고 3시 → 6시 → 9시 순서로 읽습니다(남은 칸 $left개).',
      statusKey: const Key('align_measure_status'),
      statusColor: done ? fc.ok : null,
      actions: [
        plateHelpButton(context, 'align_measure_help', '지시값 넣는 법', [
          '고정 쪽(펌프)에 서서 이동 쪽(모터)을 바라봅니다. 이 자리에서 3시가 오른쪽, 9시가 왼쪽입니다.',
          '12시에서 베젤을 돌려 0에 맞추고, 두 축을 같이 돌려 3시 → 6시 → 9시에서 읽습니다. 12시로 돌아오면 다시 0인지 봅니다.',
          '큰 바늘이 0에서 시계 방향으로 가면 +(스핀들이 눌림), 반대로 가면 −(스핀들이 나옴)입니다.',
          '3시 + 9시 = 6시가 되면 제대로 읽은 것입니다. 크게 다르면 브래킷이 흔들리거나 스핀들이 덜 눌린 것이니 다시 겁니다.',
          '받침판·배관에 막혀 한 자리(보통 6시)를 못 읽으면 그 칸을 비워 두십시오. 3시 + 9시 = 6시로 채워 계산합니다(3점 측정). 이때는 검산을 못 하니 두 번 재서 값을 맞춰 보십시오.',
          '칸에 넣으면 위 시계의 바늘이 그 값을 가리킵니다.',
        ]),
      ],
      children: [
        for (var i = 0; i < _dials.length; i++)
          PlateSection(
            reverse
                ? (_dials[i] == 'a' ? '다이얼 A · 펌프 쪽에 걸고 모터 림을 읽음' : '다이얼 B · 모터 쪽에 걸고 펌프 림을 읽음')
                : (_dials[i] == 'r' ? '림 · 바깥 둘레' : '페이스 · 옆면'),
            [
              plateRow([
                _field('${_dials[i]}90', '3시'),
                _field('${_dials[i]}180', '6시'),
                _field('${_dials[i]}270', '9시'),
              ]),
              _checkLine(_dials[i]),
            ],
            first: i == 0,
          ),
        if (solved.error != null) _notice(solved.error!, fc.danger, key: 'align_error_measure'),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: PlateActionButton(
            key: const Key('align_dial_guide_tile'),
            icon: LucideIcons.gauge,
            label: '다이얼 게이지 보는 법',
            onTap: _openDialGuide,
          ),
        ),
      ],
    );
  }

  /// 바로 검산: 3시 + 9시 = 6시면 제대로 읽은 것(10-15, 예전엔 결과에서만 알았다).
  Widget _checkLine(String p) {
    final a = _n('${p}90'), b = _n('${p}180'), c = _n('${p}270');
    if (a == null || b == null || c == null) {
      // 3점 측정: 한 자리만 비면 채운 값을 보여 준다(검산은 못 함).
      final f = fillReadings(a, b, c);
      if (f != null && f.derived != null) {
        final at = f.derived!;
        final v = at == 90 ? f.r90 : (at == 180 ? f.r180 : f.r270);
        final name = at == 90 ? '3시' : (at == 180 ? '6시' : '9시');
        return Container(
          key: Key('align_check_$p'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: fc.brandSoft, borderRadius: BorderRadius.circular(6)),
          child: Text(
            '3점 측정: $name = ${v >= 0 ? '+' : ''}${v.toStringAsFixed(2)}(셈). 한 자리가 비어 검산은 못 합니다.',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: fc.brand),
          ),
        );
      }
      return Text('세 자리를 넣으면 3시 + 9시 = 6시인지 바로 봅니다. 한 자리를 못 읽으면 비워 두십시오(3점 측정).', style: TextStyle(fontSize: 12.5, color: fc.textSub));
    }
    final diff = (a + c - b).abs();
    final ok = diff <= 0.05;
    final col = ok ? fc.ok : fc.caution;
    return Container(
      key: Key('align_check_$p'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: col.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(
        ok
            ? '검산 맞음: 3시 + 9시 = ${(a + c).toStringAsFixed(2)}, 6시 = ${b.toStringAsFixed(2)}'
            : '검산 안 맞음(차이 ${diff.toStringAsFixed(2)}): 3시 + 9시 = ${(a + c).toStringAsFixed(2)}, 6시 = ${b.toStringAsFixed(2)}. 다시 읽어 보십시오.',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: col),
      ),
    );
  }

  /// 다이얼 게이지 쓰는 법과 읽는 법(아래 창).
  Future<void> _openDialGuide() => showPlateSheet<void>(context, (ctx) {
    Widget tile(double v, String caption, {bool bezel = false}) => Expanded(
      child: Column(
        children: [
          SizedBox(height: 96, child: CustomPaint(size: Size.infinite, painter: AlignSmallDialPainter(v, bezelArrow: bezel))),
          const SizedBox(height: 4),
          Text(caption, textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, height: 1.35, color: fc.text, fontWeight: FontWeight.w600)),
        ],
      ),
    );
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: fc.line, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 12),
          Text('다이얼 게이지 보는 법', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: fc.text)),
          SizedBox(
            height: 260,
            child: CustomPaint(key: const Key('align_dial_guide'), size: Size.infinite, painter: AlignDialGuidePainter(value: -0.12)),
          ),
          _note('큰 바늘이 0에서 시계 방향으로 가면 +(스핀들이 눌림), 반대로 가면 −(스핀들이 나옴)입니다. 위 그림은 0에서 반시계 방향으로 12칸 → −0.12 mm입니다.'),
          const SizedBox(height: 14),
          Text('거는 순서', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: fc.text)),
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
          _note('결과의 "넣기"는 발 밑에 심을 넣어 모터를 올리는 것, "오른쪽"은 펌프 쪽에서 본 오른쪽입니다.'),
        ],
      ),
    );
  });
}
