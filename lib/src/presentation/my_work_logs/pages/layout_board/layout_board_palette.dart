// 작업 배치도 화면 — 아래 팔레트·부품 고르기 시트.
// layout_board_page.dart의 _LayoutBoardPageState를 역할별로 나눈 part(10-13). 동작은 같다.
// setState는 State 밖(확장)에서 부르면 보호 멤버 경고가 나지만, 이 확장은 그 State 자신이다.
// ignore_for_file: invalid_use_of_protected_member
part of '../layout_board_page.dart';

extension _LayoutBoardPalette on _LayoutBoardPageState {
  // 좁은 화면 아래 칸: 전선관 계산기 입력 칸처럼 흰 판 위에 모드 전환과 도구.
  Widget _buildBottomPanel() {
    // 폰을 가로로 눕히면 세로가 짧아 도면이 안 보일 수 있어, 아래 칸은 화면 높이의
    // 절반까지만 쓰고 넘치는 부분은 위아래로 굴린다.
    final double maxH = MediaQuery.sizeOf(context).height * 0.5;
    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildModeSegmentedControl(),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: switch (_mode) {
                    BoardMode.measureDimension => _buildDimensionToolBar(),
                    BoardMode.placeModule => _buildModulePalette(),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 모드 전환(모듈 배치/이동 ↔ 고정 치수 측정): 전선관 계산기처럼 회색 판 안에서
  // 고른 쪽만 틸로 채운다.
  Widget _buildModeSegmentedControl() {
    final segments = <(BoardMode, String, IconData)>[
      (BoardMode.placeModule, "부품 배치/이동", Icons.open_with_rounded),
      (BoardMode.measureDimension, "치수 측정", Icons.straighten_rounded),
    ];

    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tossBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: layoutLine),
      ),
      child: Row(
        children: segments.map((seg) {
          final isSelected = _mode == seg.$1;
          return Expanded(
            child: Semantics(
              button: true,
              selected: isSelected,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (isSelected) return;
                  HapticFeedback.selectionClick();
                  setState(() {
                    _mode = seg.$1;
                    _dimensionStartPoint = null;
                    _activeItem = null;
                    for (var i in _placedItems) {
                      i.isSelected = false;
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected ? tossBlue : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          seg.$3,
                          size: 20,
                          color: isSelected ? pureWhite : tossSubText,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          seg.$2,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? pureWhite : tossSubText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // 좁은 화면 모듈 배치 도구: 끌어다 놓을 것 한 줄 + 가상선·여러 개 선택 단추 + 내 프리셋.
  Widget _buildModulePalette() {
    return Column(
      key: const ValueKey("palette"),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _panelLabel("끌어다 도면에 놓습니다"),
        const SizedBox(height: 8),
        // 단추가 늘어 좁은 폰에서는 옆으로 민다(신규 모듈은 위로 끌어 놓는다).
        SizedBox(
          height: 64,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _dragTile(
                  const ModulePreset("신규 부품", 80, 80),
                  (_) => _buildPaletteItem("신규 부품"),
                  affinity: Axis.vertical,
                ),
                const SizedBox(width: 8),
                // 스키드는 전선관 작업 부속만(계기·밸브·피팅·전기는 캐비닛에서 쓴다).
                if (_isSkid) ...[
                  _buildSkidButton(
                    "skid_steel",
                    Icons.view_stream_rounded,
                    "형강",
                    "형강 놓기",
                    kSkidSteelPresets,
                    iconWidget: _skidIcon(SkidShape.beam, SkidFace.end),
                  ),
                  const SizedBox(width: 8),
                  // 전선관은 "경로"로 그린다(따로 놓는 막대는 경로와 이어지지 않아 헷갈렸다).
                  _buildRouteButton(),
                  const SizedBox(width: 8),
                  _buildIsoButton(),
                  const SizedBox(width: 8),
                  _buildSkidButton(
                    "skid_jb",
                    Icons.inbox_outlined,
                    "JB",
                    "정션박스 놓기",
                    kSkidJbPresets,
                    iconWidget: _skidIcon(SkidShape.jb, SkidFace.side),
                  ),
                  const SizedBox(width: 8),
                  _buildSkidButton(
                    "skid_fitting",
                    Icons.plumbing_rounded,
                    "부속",
                    "전선관 부속 놓기",
                    kSkidFittingPresets,
                    iconWidget: _skidIcon(SkidShape.cdLB, SkidFace.side, h: 24),
                  ),
                ] else ...[
                  _buildDuctButton(),
                  const SizedBox(width: 8),
                  _buildElecButton(),
                  const SizedBox(width: 8),
                  _buildInstrumentButton(),
                  const SizedBox(width: 8),
                  _buildValveButton(),
                  const SizedBox(width: 8),
                  _buildFittingButton(),
                ],
                const SizedBox(width: 8),
                // 도면 위에 글만 적는 상자("여기 트레이" 같은 말). 자재 수량에는 안 센다.
                _dragTile(
                  const ModulePreset(
                    "메모",
                    160,
                    40,
                    shape: InstrumentShape.note,
                  ),
                  (_) => _buildPaletteItem("메모 글자"),
                  affinity: Axis.vertical,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildGuideColorSwitch()),
            const SizedBox(width: 8),
            Expanded(child: _buildMultiSelectToggle()),
          ],
        ),
        if (_customPresets.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildPresetArea(),
        ],
      ],
    );
  }

  // 좁은 화면 "계기" 단추: 누르면 제조사별 목록이 뜨고, 고르면 지금 보이는 도면 가운데에 놓는다.
  // (아래 칸 높이를 늘리면 도면이 좁아져서 끌어다 놓기 대신 목록으로 둔다.)
  Widget _buildInstrumentButton() => _buildSheetButton(
    key: const ValueKey("instrument_button"),
    icon: Icons.speed_rounded,
    label: "계기",
    onTap: () => _showPresetSheet(
      title: "계기 놓기",
      help: "정면에서 본 몸통 크기입니다(2인치 브래킷 빼고). 누르면 지금 보이는 도면 가운데에 놓습니다.",
      groups: kInstrumentPresets,
    ),
  );

  void _openFittingSheet() => _showPresetSheet(
    title: "피팅 놓기",
    help:
        "하이록·스웨즈락 튜브 피팅을 옆에서 본 크기입니다(1/4\"·3/8\"·1/2\"는 두 회사 치수가 같습니다). 누르면 지금 보이는 도면 가운데에 놓습니다.",
    groups: kFittingPresets,
    sizeFilter: true,
  );

  void _openValveSheet() => _showPresetSheet(
    title: "밸브 놓기",
    help: "매니폴드 밸브를 정면(손잡이 쪽)에서 본 크기입니다. 누르면 지금 보이는 도면 가운데에 놓습니다.",
    groups: kValvePresets,
  );

  Widget _buildFittingButton() => _buildSheetButton(
    key: const ValueKey("fitting_button"),
    icon: Icons.plumbing_rounded,
    label: "피팅",
    onTap: _openFittingSheet,
  );

  Widget _buildValveButton() => _buildSheetButton(
    key: const ValueKey("valve_button"),
    icon: Icons.tune_rounded,
    label: "밸브",
    onTap: _openValveSheet,
  );

  Widget _buildRouteButton() => _buildSheetButton(
    key: const ValueKey("skid_route"),
    icon: Icons.route_rounded,
    iconWidget: _routeIcon,
    label: "경로",
    onTap: _showRoutesSheet,
  );

  /// 좁은 화면 모듈 배치 도구의 "입체" 단추(스키드 입체 보기, 보기 전용).
  Widget _buildIsoButton() => _buildSheetButton(
    key: const ValueKey("skid_iso"),
    icon: Icons.view_in_ar_rounded,
    label: "입체",
    onTap: _openSkidIso,
  );

  // 스키드 평면 모듈 단추(형강·전선관·정션박스). 길이는 1000으로 놓이고 놓은 뒤 고친다.
  Widget _buildSkidButton(
    String key,
    IconData icon,
    String label,
    String title,
    Map<String, List<ModulePreset>> groups, {
    Widget? iconWidget,
  }) => _buildSheetButton(
    key: ValueKey(key),
    icon: icon,
    iconWidget: iconWidget,
    label: label,
    onTap: () => _openSkidSheet(title, groups),
  );

  /// 스키드 단추 그림: 부품 그림을 단추 크기로(형강 = 단면, JB = 옆모습, 부속 = 곤질레다 LB 옆모습).
  Widget _skidIcon(
    String shape,
    SkidFace face, {
    double w = 30,
    double h = 22,
  }) => SizedBox(
    width: w,
    height: h,
    child: CustomPaint(
      painter: SkidPartPainter(
        shape: shape,
        face: face,
        stroke: tossBlue,
        strokeWidth: 1.6,
      ),
    ),
  );

  Widget get _routeIcon => const SizedBox(
    width: 28,
    height: 22,
    child: CustomPaint(painter: SkidRouteIconPainter(color: tossBlue)),
  );

  void _openSkidSheet(
    String title,
    Map<String, List<ModulePreset>> groups,
  ) => _showPresetSheet(
    title: title,
    help: groups == kSkidFittingPresets
        ? "삼화기전 F-7 곤질레다와 커플링·유니온 커플링입니다. 삼화는 치수를 공개하지 않아 곤질레다는 같은 모양인 국산(JK) 표, 커플링은 KS 표, 유니온은 국산(대승) 표 값입니다. 위에서 본 길이×폭(mm)으로 놓이고, 높이는 정면에서 끌어 맞추거나 편집 칸에 넣으십시오. 형강 위로 올려 놓으면 높이는 형강 윗면에 자동으로 맞춥니다."
        : groups == kSkidJbPresets
        ? "위에서 본 가로×세로(mm)입니다. 누르면 지금 보이는 도면 가운데에 놓습니다. 바닥에서 높이는 놓은 뒤 편집 칸에 넣으십시오. 형강 위로 올려 놓으면 형강 윗면에 자동으로 맞춥니다."
        : "위에서 본 폭(mm)으로, 길이 1000으로 놓입니다. 놓은 뒤 편집 칸에서 실제 길이로 고치고, 세로로 쓰려면 돌리십시오.",
    groups: groups,
  );

  void _openElecSheet() => _showPresetSheet(
    title: "전기 부품 놓기",
    help:
        "DIN 레일에 다는 부품을 정면에서 본 크기입니다(깊이는 판 면에서, 레일 포함). 누르면 지금 보이는 도면 가운데에 놓습니다.",
    groups: kElecPresets,
  );

  Widget _buildElecButton() => _buildSheetButton(
    key: const ValueKey("elec_button"),
    icon: Icons.electrical_services_rounded,
    label: "전기",
    onTap: _openElecSheet,
  );

  Widget _buildDuctButton() => _buildSheetButton(
    key: const ValueKey("duct_button"),
    icon: Icons.view_week_rounded,
    label: "덕트",
    onTap: () => _showPresetSheet(
      title: "덕트 놓기",
      help:
          "폭×높이(mm)입니다. 도면에는 폭만큼 놓이고, 길이는 놓은 뒤 세로 칸에서 고칩니다. 누르면 지금 보이는 도면 가운데에 놓습니다.",
      groups: kDuctPresetGroups,
    ),
  );

  Widget _buildSheetButton({
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Widget? iconWidget,
  }) {
    return Material(
      key: key,
      color: pureWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: tossSubText.withValues(alpha: 0.3), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 64,
          height: 56,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              iconWidget ?? Icon(icon, size: 22, color: tossBlue),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: tossText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPresetSheet({
    required String title,
    required String help,
    required Map<String, List<ModulePreset>> groups,
    bool sizeFilter = false,
  }) async {
    final ModulePreset? picked = await showModalBottomSheet<ModulePreset>(
      context: context,
      isScrollControlled: true,
      backgroundColor: pureWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: sizeFilter ? 0.8 : 0.6,
          maxChildSize: 0.9,
          builder: (ctx, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: tossText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                keepWords(help),
                style: const TextStyle(
                  fontSize: 14,
                  color: tossSubText,
                  height: 1.4,
                ),
              ),
              if (sizeFilter) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final size in kFittingSizes)
                      ChoiceChip(
                        key: ValueKey("fitting_size_$size"),
                        label: Text(size),
                        selected: size == _fittingSize,
                        showCheckmark: false,
                        labelStyle: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: size == _fittingSize ? pureWhite : tossText,
                        ),
                        selectedColor: tossBlue,
                        backgroundColor: pureWhite,
                        side: BorderSide(
                          color: size == _fittingSize ? tossBlue : layoutLine,
                        ),
                        onSelected: (_) {
                          setState(() => _fittingSize = size);
                          setSheet(() {});
                        },
                      ),
                  ],
                ),
              ],
              for (final brand in groups.entries)
                if (!sizeFilter ||
                    brand.value.any(
                      (p) => fittingTubeSize(p.name) == _fittingSize,
                    )) ...[
                  const SizedBox(height: 16),
                  _panelLabel(brand.key),
                  for (final p in brand.value)
                    if (!sizeFilter || fittingTubeSize(p.name) == _fittingSize)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: _instrumentThumb(p, box: 48),
                        title: Text(
                          p.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: tossText,
                          ),
                        ),
                        // 덕트는 이름에 폭×높이가 있고 도면 세로(길이)는 놓은 뒤 고치므로 크기를 따로 안 적는다.
                        trailing: p.shape == InstrumentShape.duct
                            ? null
                            : Text(
                                "${p.width.toInt()}×${p.height.toInt()}",
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: tossSubText,
                                ),
                              ),
                        onTap: () => Navigator.pop(ctx, p),
                      ),
                ],
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    _onAcceptItem(picked, _visibleBoardCenter(picked));
  }

  // 좁은 화면 가상선 단추: 누를 때마다 센터선(틸) ↔ 외곽선(주황)으로 바뀐다.
  Widget _buildGuideColorSwitch() {
    final bool isCenter = !_showEdgeGuide;
    return _toolToggle(
      icon: Icons.sync_alt_rounded,
      label: isCenter ? "가상선: 센터" : "가상선: 측면",
      selected: true,
      color: isCenter ? guideCenterColor : edgeDimColor,
      onTap: () => setState(() {
        _showCenterGuide = !isCenter;
        _showEdgeGuide = isCenter;
      }),
    );
  }

  Widget _buildPaletteItem(String defaultName, {bool large = false}) {
    // 넓은 화면의 왼쪽 칸에서는 크게 보인다. 끄는 동안 떠다니는 복사본으로도
    // 쓰이므로 폭은 늘 고정값이어야 한다(무한 폭이면 오류가 난다).
    return Container(
      width: large ? 228 : 64,
      height: large ? 56 : 56,
      decoration: BoxDecoration(
        color: tossBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tossBlue.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Center(
        child: large
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_box_rounded, color: tossBlue, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    defaultName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: tossBlue,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_box_rounded, color: tossBlue, size: 20),
                  const SizedBox(height: 2),
                  Text(
                    defaultName,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: tossBlue,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // 켜고 끄는 도구 단추(높이 44, 글씨 14). 알약 모양 대신 모서리만 둥근 네모.
  Widget _toolToggle({
    required IconData icon,
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      toggled: selected,
      child: Material(
        color: selected ? color.withValues(alpha: 0.10) : pureWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? color : layoutLine,
            width: selected ? 2 : 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 22, color: selected ? color : tossSubText),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: selected ? color : tossSubText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 칸 안의 작은 제목(14, 굵게).
  Widget _panelLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w800,
      color: tossSubText,
    ),
  );

  // 도면으로 끌어다 놓는 것 하나. affinity를 주면 그 방향으로 끌 때만 집힌다.
  Widget _dragTile(
    ModulePreset preset,
    Widget Function(bool dragging) builder, {
    Axis? affinity,
  }) {
    return Draggable<ModulePreset>(
      data: preset,
      affinity: affinity,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(opacity: 0.8, child: builder(true)),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: builder(true)),
      child: builder(false),
    );
  }
}
