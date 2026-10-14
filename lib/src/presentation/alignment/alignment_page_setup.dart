// ignore_for_file: invalid_use_of_protected_member
part of 'alignment_page.dart';

// 거리 탭: 방식, 거리, 회전수·판정 기준, 처짐·열팽창(늘 보임). 위 그림은 측정 그림(넣는 거리 진하게, 값이 치수선에).
extension _AlignSetup on _AlignmentPageState {
  /// 위 그림: 거리 칸에 들어가 있으면 그 치수만 크게, 아니면 치수 넷 다.
  Widget _setupCanvas() {
    final i = _focus == null ? -1 : _distKeys.indexOf(_focus!);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 24),
      // 그림 칸이 낮으면(가로 화면·자판) 치수선 넷을 다 그리면 기계가 손톱만 해진다(10-15 폰 가로):
      // 그때는 넣는 칸의 치수 하나만.
      child: LayoutBuilder(
        builder: (context, box) => CustomPaint(
          key: const Key('align_setup_diagram'),
          size: Size.infinite,
          painter: AlignSetupRenderPainter(
            _method,
            highlight: i < 0 ? null : i,
            values: [for (final k in _distKeys) _f(k).text.trim()],
            compact: i >= 0 || box.maxHeight < 330,
          ),
        ),
      ),
    );
  }

  Widget _setupPanel() {
    final reverse = _method == AlignMethod.reverse;
    final left = _distKeys.length - _distCount;
    return PlatePanel(
      title: '거리',
      status: left == 0 ? '거리를 다 넣었습니다. 지시값 탭으로 가십시오.' : '거리 $left개를 더 넣으십시오(그림 번호 순서).',
      statusKey: const Key('align_setup_status'),
      statusColor: left == 0 ? fc.ok : null,
      actions: [
        plateHelpButton(context, 'align_method_help', reverse ? '리버스 다이얼 방식' : '림·페이스 방식', [
          if (reverse) ...[
            '다이얼 두 개를 서로 반대로 걸어, 각각 상대 축의 림(바깥 둘레)을 읽습니다. A는 펌프 쪽에 걸어 모터 림을, B는 모터 쪽에 걸어 펌프 림을 읽습니다.',
            '좋은 점: 옆면(페이스)을 재지 않아 축이 앞뒤로 밀려도 값이 덜 틀어집니다. 커플링 사이가 먼 경우(스페이서)에도 맞습니다.',
            '주의: 두 접촉면 사이(①)가 짧으면 기울기 오차가 커집니다. 브래킷이 길면 처짐 보정을 넣습니다.',
          ] else ...[
            '브래킷 하나에 다이얼 두 개를 달아, 하나는 모터 쪽 커플링의 림(바깥 둘레)을, 하나는 페이스(옆면)를 읽습니다. 림은 어긋남, 페이스는 기울기를 봅니다.',
            '좋은 점: 한쪽 축에서만 걸면 되어 자리가 좁을 때 쉽습니다. 커플링 지름이 크고 사이가 가까울 때 잘 맞습니다.',
            '주의: 돌리는 동안 축이 앞뒤로 밀리면 페이스 값이 틀어집니다. 축을 한쪽으로 밀어 붙인 채 읽습니다. 페이스가 닿는 반지름(④)을 정확히 잽니다.',
          ],
          '거리는 모두 mm입니다. 위 그림의 번호(①~④)가 칸 번호와 같습니다.',
          '그림 비율은 모터 IEC 160M, 펌프 ISO 2858 65-40-250 치수표를 따랐습니다.',
        ]),
      ],
      children: [
        PlateSection('측정 방식', [
          PlateSegments([
            for (final m in AlignMethod.values)
              PlateOption(
                'align_m_${m.name}',
                m == AlignMethod.reverse ? '리버스 다이얼' : '림·페이스',
                _method == m,
                () {
                  setState(() {
                    _method = m;
                    _clockDial = m == AlignMethod.reverse ? 'a' : 'r';
                  });
                  _saveDraftSoon();
                },
              ),
          ]),
        ], first: true),
        // 한 칸에 한 줄(10-15: 두 칸씩 놓으니 좁은 폰에서 이름이 "① A·B 두 접…"으로 잘렸다).
        PlateSection('거리 (mm)', [
          if (reverse) ...[
            _field('between', '① A·B 두 접촉면 사이', signed: false),
            _field('coupB', '② B면에서 커플링 중심까지', signed: false),
            _field('front', '③ A면에서 모터 앞발까지', signed: false),
            _field('rear', '④ A면에서 모터 뒷발까지', signed: false),
          ] else ...[
            _field('coupR', '① 림면에서 커플링 중심까지', signed: false),
            _field('front', '② 림면에서 모터 앞발까지', signed: false),
            _field('rear', '③ 림면에서 모터 뒷발까지', signed: false),
            _field('faceR', '④ 페이스가 닿는 반지름', signed: false),
          ],
        ]),
        PlateSection('회전수와 판정 기준', [
          plateRow([_field('rpm', '회전수', hint: '1800', unit: 'rpm', signed: false), const SizedBox.shrink()]),
          plateRow([
            PlateNumField(
              fieldKey: 'align_tol_offset',
              label: '평행 어긋남 허용',
              controller: _tolO,
              onChanged: (_) => _saveTol(),
            ),
            PlateNumField(
              fieldKey: 'align_tol_angle',
              label: '각도 허용',
              controller: _tolA,
              unit: 'mm/100',
              onChanged: (_) => _saveTol(),
            ),
          ]),
          _note(
            '판정에 쓰는 현장 기준입니다. 처음에는 0.05 mm(100분의 5)로 두었고, 고치면 폰에 남아 다음에도 그 값으로 판정합니다. '
            '흔히 쓰는 경험값은 $_rpm rpm에서 평행 ${defaultTolerance(_rpm).offset.toStringAsFixed(2)} mm입니다. 제조사·사내 기준이 우선입니다.',
          ),
        ]),
        // 처짐·열팽창은 늘 펼쳐 둔다(10-15: 접혀 있으면 값이 계산에 들어가는지 몰랐다).
        PlateSection(
          '브래킷 처짐 보정 (선택, 비우면 0)',
          [
            if (reverse)
              plateRow([_field('sagA', '다이얼 A 처짐'), _field('sagB', '다이얼 B 처짐')])
            else
              plateRow([_field('sagR', '림 다이얼 처짐'), const SizedBox.shrink()]),
            _note('같은 다이얼 세팅을 곧은 관에 걸고 12시를 0으로 맞춘 뒤 6시에서 읽은 값입니다(보통 마이너스).'),
          ],
          trailing: _appliedBadge('align_sag_applied', _hasAny(reverse ? ['sagA', 'sagB'] : ['sagR'])),
        ),
        PlateSection(
          '열팽창 목표 (선택, 비우면 0)',
          [
            plateRow([_field('targetY', '위아래 목표'), _field('targetZ', '옆 목표')]),
            _note('차가울 때 모터 축을 커플링 중심에서 이만큼 어긋나게 맞춰 두어야 운전 온도에서 맞는 경우에 넣습니다. + 위·오른쪽.'),
          ],
          trailing: _appliedBadge('align_target_applied', _hasAny(['targetY', 'targetZ'])),
        ),
      ],
    );
  }

  /// 값이 들어 있어 계산에 들어간다는 작은 표시.
  Widget? _appliedBadge(String key, bool on) => !on
      ? null
      : Container(
          key: Key(key),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(color: fc.caution.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(6)),
          child: Text('계산에 들어감', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: fc.caution)),
        );
}
