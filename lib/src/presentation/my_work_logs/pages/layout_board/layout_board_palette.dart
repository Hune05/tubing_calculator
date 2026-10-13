// 작업 배치도 화면 — 아래 칸(모드·도구 단추)과 부품 담기 페이지 열기.
// layout_board_page.dart의 _LayoutBoardPageState를 역할별로 나눈 part(10-13). 동작은 같다.
// setState는 State 밖(확장)에서 부르면 보호 멤버 경고가 나지만, 이 확장은 그 State 자신이다.
// ignore_for_file: invalid_use_of_protected_member
part of '../layout_board_page.dart';

extension _LayoutBoardPalette on _LayoutBoardPageState {
  /// 아래 칸(10-13 개편): 모드 줄(배치 | 치수 + 가상선) 한 줄과 도구 단추 다섯 개 한 줄.
  /// 예전엔 부품 묶음 단추 여덟 개가 옆으로 밀리고 글자가 잘렸다("신규 부"·"메모 글").
  /// 부품은 "부품" 페이지(LayoutPartsPage)에서 고른다.
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildModeRow(),
                const SizedBox(height: 10),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: switch (_mode) {
                    BoardMode.measureDimension => _buildDimensionToolBar(),
                    BoardMode.placeModule => _buildToolRow(),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 모드(배치 | 치수)와 가상선 단추 한 줄.
  Widget _buildModeRow() => Row(
    children: [
      Expanded(child: _buildModeSegmentedControl()),
      const SizedBox(width: 8),
      _buildGuideColorSwitch(),
    ],
  );

  // 모드 전환(부품 배치/이동 ↔ 치수 측정): 회색 판 안에서 고른 쪽만 틸로 채운다.
  Widget _buildModeSegmentedControl() {
    final segments = <(BoardMode, String, IconData)>[
      (BoardMode.placeModule, "배치", Icons.open_with_rounded),
      (BoardMode.measureDimension, "치수", Icons.straighten_rounded),
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
                  // 좁은 폰(320)·큰 글씨에서는 글자를 조금 줄여서라도 한 줄에 넣는다.
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

  // 가상선 단추: 누를 때마다 센터선(틸) ↔ 외곽선(주황)으로 바뀐다.
  Widget _buildGuideColorSwitch() {
    final bool isCenter = !_showEdgeGuide;
    return _toolToggle(
      icon: Icons.sync_alt_rounded,
      label: isCenter ? "가상선 센터" : "가상선 측면",
      selected: true,
      color: isCenter ? guideCenterColor : edgeDimColor,
      onTap: () => setState(() {
        _showCenterGuide = !isCenter;
        _showEdgeGuide = isCenter;
      }),
    );
  }

  /// 도구 단추 다섯 개(옆으로 안 밀리고 글자가 안 잘린다).
  /// 캐비닛: 부품·찾기·메모·여러 개·도면 / 스키드: 부품·경로·입체·여러 개·도면.
  Widget _buildToolRow() {
    final List<Widget> buttons = [
      layoutToolButton(
        key: const ValueKey("parts_button"),
        icon: Icons.add_box_rounded,
        label: "부품",
        primary: true,
        onTap: () => _openPartsPage(),
      ),
      if (_isSkid) ...[
        layoutToolButton(
          key: const ValueKey("route_button"),
          icon: Icons.timeline_rounded,
          label: "경로",
          onTap: _showRoutesSheet,
        ),
        layoutToolButton(
          key: const ValueKey("iso_button"),
          icon: Icons.view_in_ar_rounded,
          label: "입체",
          onTap: _openSkidIso,
        ),
      ] else ...[
        layoutToolButton(
          key: const ValueKey("search_button"),
          icon: Icons.search_rounded,
          label: "찾기",
          onTap: () => _openPartsPage(search: true),
        ),
        layoutToolButton(
          key: const ValueKey("note_button"),
          icon: Icons.sticky_note_2_outlined,
          label: "메모",
          onTap: _placeNote,
        ),
      ],
      _buildMultiSelectToggle(),
      layoutToolButton(
        key: const ValueKey("board_settings_button"),
        icon: Icons.tune_rounded,
        label: "도면",
        onTap: _openBoardSettings,
      ),
    ];
    return Row(
      key: const ValueKey("palette"),
      children: [
        for (int i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(child: buttons[i]),
        ],
      ],
    );
  }

  static const String _fittingCategoryKey = 'fitting';

  /// 부품 담기 페이지에 보일 묶음(도면 종류에 따라). 스키드는 전선관 작업 부속만.
  List<LayoutPartsCategory> get _partsCategories => _isSkid
      ? [
          LayoutPartsCategory('skid_steel', '형강', kSkidSteelPresets),
          LayoutPartsCategory('skid_jb', 'JB', kSkidJbPresets),
          LayoutPartsCategory('skid_fitting', '부속', kSkidFittingPresets),
        ]
      : [
          const LayoutPartsCategory('duct', '덕트', kDuctPresetGroups),
          LayoutPartsCategory('elec', '전기', kElecPresets),
          const LayoutPartsCategory('instrument', '계기', kInstrumentPresets),
          LayoutPartsCategory('valve', '밸브', kValvePresets),
          LayoutPartsCategory(_fittingCategoryKey, '피팅', kFittingPresets),
        ];

  /// 부품 담기 페이지를 열고, 고른 부품을 지금 보이는 도면 가운데에 놓는다.
  Future<void> _openPartsPage({bool search = false, String? category}) async {
    final ModulePreset? picked = await Navigator.of(context).push<ModulePreset>(
      MaterialPageRoute(
        builder: (_) => LayoutPartsPage(
          categories: _partsCategories,
          customPresets: () => _customPresets,
          favorites: () => _favParts,
          recents: _recentParts,
          onToggleFavorite: _toggleFavPart,
          onManagePresets: _showPresetManageSheet,
          fittingCategoryKey: _isSkid ? '' : _fittingCategoryKey,
          fittingSize: _fittingSize,
          onFittingSize: (s) => setState(() => _fittingSize = s),
          autofocusSearch: search,
          initialCategory: category,
        ),
      ),
    );
    if (picked == null || !mounted) return;
    // 빈 상자·메모는 "최근 쓴 부품"에 안 남긴다.
    if (picked != kLayoutNewPartPreset && picked != kLayoutNotePreset) {
      _rememberRecentPart(picked.name);
    }
    _onAcceptItem(picked, _visibleBoardCenter(picked));
  }

  /// 도면 위에 글만 적는 상자("여기 트레이" 같은 말). 자재 수량에는 안 센다.
  void _placeNote() =>
      _onAcceptItem(kLayoutNotePreset, _visibleBoardCenter(kLayoutNotePreset));

  /// "도면" 단추: 크기·모눈·안내선·측판·배경 사진 설정 페이지.
  void _openBoardSettings() => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => _LayoutSettingsPage(owner: this)),
  );

  // ───── 부품 찾기 기억(최근 쓴 부품·즐겨찾기·안내선 붙이기) ─────

  static const String _recentPartsKey = 'layout_recent_parts_v1';
  static const String _favPartsKey = 'layout_fav_parts_v1';
  static const String _snapGuidesKey = 'layout_snap_guides_v1';

  Future<void> _loadPartPrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _recentParts = p.getStringList(_recentPartsKey) ?? [];
        _favParts = (p.getStringList(_favPartsKey) ?? []).toSet();
        _snapToGuides = p.getBool(_snapGuidesKey) ?? true;
      });
    } catch (_) {}
  }

  /// 놓은 부품을 "최근 쓴 부품" 맨 앞에 둔다(8개까지).
  void _rememberRecentPart(String name) {
    final next = [
      name,
      ..._recentParts.where((n) => n != name),
    ].take(8).toList();
    _recentParts = next;
    _savePrefList(_recentPartsKey, next);
  }

  void _toggleFavPart(String name) {
    final next = {..._favParts};
    if (!next.remove(name)) next.add(name);
    setState(() => _favParts = next);
    _savePrefList(_favPartsKey, next.toList());
  }

  Future<void> _savePrefList(String key, List<String> v) async {
    try {
      await (await SharedPreferences.getInstance()).setStringList(key, v);
    } catch (_) {}
  }

  Future<void> _setSnapToGuides(bool v) async {
    setState(() => _snapToGuides = v);
    try {
      await (await SharedPreferences.getInstance()).setBool(_snapGuidesKey, v);
    } catch (_) {}
  }

  // ───── 공용 작은 부품 ─────

  // 켜고 끄는 도구 단추(높이 44, 글씨 15). 알약 모양 대신 모서리만 둥근 네모.
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
                mainAxisSize: MainAxisSize.min,
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
}
