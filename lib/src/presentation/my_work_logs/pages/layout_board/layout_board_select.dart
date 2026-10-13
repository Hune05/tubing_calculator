// 작업 배치도 화면 — 여러 개 선택·정렬.
// layout_board_page.dart의 _LayoutBoardPageState를 역할별로 나눈 part(10-13). 동작은 같다.
// setState는 State 밖(확장)에서 부르면 보호 멤버 경고가 나지만, 이 확장은 그 State 자신이다.
// ignore_for_file: invalid_use_of_protected_member
part of '../layout_board_page.dart';

extension _LayoutBoardSelect on _LayoutBoardPageState {
  void _toggleMultiSelectMode() {
    setState(() {
      _multiSelectMode = !_multiSelectMode;
      if (!_multiSelectMode) {
        _multiSelectedIds = {};
        for (var i in _placedItems) {
          i.isSelected = false;
        }
      }
    });
  }

  List<PlacedItem> get _selectedGroup =>
      _placedItems.where((i) => _multiSelectedIds.contains(i.id)).toList();

  void _nudgeSelected(Offset direction) {
    final items = _selectedGroup.where((i) => !i.isLocked).toList();
    if (items.isEmpty) return;
    _pushUndo();
    setState(() {
      for (final i in items) {
        i.position = Offset(
          (i.position.dx + direction.dx * (_gridSize > 0 ? _gridSize : 1))
              .clamp(0.0, math.max(0.0, _panelWidth - i.width)),
          (i.position.dy + direction.dy * (_gridSize > 0 ? _gridSize : 1))
              .clamp(0.0, math.max(0.0, _panelHeight - i.height)),
        );
      }
    });
  }

  void _duplicateSelectedGroup() {
    final items = _selectedGroup;
    if (items.isEmpty) return;
    _pushUndo();
    final newIds = <String>{};
    setState(() {
      for (final item in items) {
        final newItem = PlacedItem(
          id: newLayoutId('dup_'),
          name: item.name,
          position: _snapToGrid(
            Offset(
              (item.position.dx + 20).clamp(
                0.0,
                math.max(0.0, _panelWidth - item.width),
              ),
              (item.position.dy + 20).clamp(
                0.0,
                math.max(0.0, _panelHeight - item.height),
              ),
            ),
          ),
          width: item.width,
          height: item.height,
          isSelected: true,
          shape: item.shape,
          depth: item.depth,
          elevation: item.elevation,
          // 뒤집기는 같이 옮기고, 잠금은 복제본에 붙이지 않는다(옮기려고 복제하니까).
          flipped: item.flipped,
          tag: item.tag,
          rotation: item.rotation,
        );
        _placedItems.add(newItem);
        newIds.add(newItem.id);
      }
      for (final i in _placedItems) {
        i.isSelected = newIds.contains(i.id);
      }
      _multiSelectedIds = newIds;
    });
    HapticFeedback.mediumImpact();
  }

  void _toggleLockSelected() {
    final items = _selectedGroup;
    if (items.isEmpty) return;
    final bool allLocked = items.every((i) => i.isLocked);
    _pushUndo();
    setState(() {
      for (final i in items) {
        i.isLocked = !allLocked;
      }
    });
    HapticFeedback.lightImpact();
  }

  void _deleteSelectedGroup() {
    if (_multiSelectedIds.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "선택 부품 삭제",
          style: TextStyle(color: tossText, fontWeight: FontWeight.bold),
        ),
        content: Text(
          keepWords("선택한 부품 ${_multiSelectedIds.length}개를 삭제하시겠습니까?"),
          style: const TextStyle(color: tossSubText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("취소", style: TextStyle(color: tossSubText)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              final ids = _multiSelectedIds;
              _pushUndo();
              setState(() {
                _dimensions.removeWhere(
                  (d) => ids.contains(d.p1.id) || ids.contains(d.p2.id),
                );
                _placedItems.removeWhere((i) => ids.contains(i.id));
                _multiSelectedIds = {};
              });
            },
            child: const Text(
              "삭제",
              style: TextStyle(color: warningRed, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // 🚀 [신규] 선택된 모듈 2개 이상을 한쪽으로 맞추거나(정렬), 간격을
  // 균등하게 배분한다(3개 이상일 때만 의미 있음) - 파워포인트 등에서
  // 흔히 쓰는 정렬/분포 도구와 동일한 개념.
  void _applyAlignment(String action) {
    final items = _selectedGroup.where((i) => !i.isLocked).toList();
    if (items.length < 2) return;
    _pushUndo();
    setState(() {
      switch (action) {
        case 'left':
          final double minX = items.map((i) => i.position.dx).reduce(math.min);
          for (final i in items) {
            i.position = Offset(minX, i.position.dy);
          }
          break;
        case 'right':
          final double maxRight = items
              .map((i) => i.position.dx + i.width)
              .reduce(math.max);
          for (final i in items) {
            i.position = Offset(maxRight - i.width, i.position.dy);
          }
          break;
        case 'top':
          final double minY = items.map((i) => i.position.dy).reduce(math.min);
          for (final i in items) {
            i.position = Offset(i.position.dx, minY);
          }
          break;
        case 'bottom':
          final double maxBottom = items
              .map((i) => i.position.dy + i.height)
              .reduce(math.max);
          for (final i in items) {
            i.position = Offset(i.position.dx, maxBottom - i.height);
          }
          break;
        case 'distributeH':
          if (items.length < 3) break;
          final sorted = [...items]
            ..sort((a, b) => a.position.dx.compareTo(b.position.dx));
          final first = sorted.first;
          final last = sorted.last;
          final double totalSpan =
              (last.position.dx + last.width) - first.position.dx;
          final double totalWidth = sorted.fold<double>(
            0,
            (acc, i) => acc + i.width,
          );
          final double gap = (totalSpan - totalWidth) / (sorted.length - 1);
          double cursor = first.position.dx + first.width + gap;
          for (int k = 1; k < sorted.length - 1; k++) {
            sorted[k].position = Offset(cursor, sorted[k].position.dy);
            cursor += sorted[k].width + gap;
          }
          break;
        case 'distributeV':
          if (items.length < 3) break;
          final sortedV = [...items]
            ..sort((a, b) => a.position.dy.compareTo(b.position.dy));
          final firstV = sortedV.first;
          final lastV = sortedV.last;
          final double totalSpanV =
              (lastV.position.dy + lastV.height) - firstV.position.dy;
          final double totalHeightV = sortedV.fold<double>(
            0,
            (acc, i) => acc + i.height,
          );
          final double gapV =
              (totalSpanV - totalHeightV) / (sortedV.length - 1);
          double cursorV = firstV.position.dy + firstV.height + gapV;
          for (int k = 1; k < sortedV.length - 1; k++) {
            sortedV[k].position = Offset(sortedV[k].position.dx, cursorV);
            cursorV += sortedV[k].height + gapV;
          }
          break;
      }
    });
  }

  void _showAlignmentSheet() {
    if (_selectedGroup.length < 2) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        Widget actionTile(IconData icon, String label, String action) {
          return ListTile(
            leading: Icon(icon, color: tossBlue),
            title: Text(
              label,
              style: const TextStyle(
                color: tossText,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () {
              Navigator.pop(ctx);
              _applyAlignment(action);
            },
          );
        }

        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: pureWhite,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Row(
                    children: [
                      const Text(
                        "정렬 / 간격 배분",
                        style: TextStyle(
                          color: tossText,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                actionTile(
                  Icons.align_horizontal_left_rounded,
                  "왼쪽 정렬",
                  'left',
                ),
                actionTile(
                  Icons.align_horizontal_right_rounded,
                  "오른쪽 정렬",
                  'right',
                ),
                actionTile(Icons.align_vertical_top_rounded, "위쪽 정렬", 'top'),
                actionTile(
                  Icons.align_vertical_bottom_rounded,
                  "아래쪽 정렬",
                  'bottom',
                ),
                actionTile(
                  Icons.align_horizontal_center_rounded,
                  "가로 간격 균등 분배 (3개 이상)",
                  'distributeH',
                ),
                actionTile(
                  Icons.align_vertical_center_rounded,
                  "세로 간격 균등 분배 (3개 이상)",
                  'distributeV',
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  // 🚀 [신규] 다중 선택 도구모음 - 2개 이상 선택 시 그룹 이동/
  // 복제/잠금/정렬/삭제를 한 번에 할 수 있게 하단에 띄운다.
  // 🚀 [개선] 선택하는 순간 뚝 나타나던 걸 부드럽게 슬라이드 인/
  // 아웃 되도록 항상 트리에 두고 위치만 애니메이션한다.
  Widget _buildMultiSelectBar() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      left: 0,
      right: 0,
      bottom: _multiSelectedIds.isNotEmpty ? 0 : -200,
      child: IgnorePointer(
        ignoring: _multiSelectedIds.isEmpty,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: _multiSelectedIds.isNotEmpty ? 1 : 0,
          child: SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              decoration: BoxDecoration(
                color: tossText,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Text(
                    keepWords("${_multiSelectedIds.length}개 선택"),
                    style: const TextStyle(
                      color: pureWhite,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          const SizedBox(width: 8),
                          _buildMultiBarIcon(
                            Icons.keyboard_arrow_up_rounded,
                            () => _nudgeSelected(const Offset(0, -1)),
                          ),
                          _buildMultiBarIcon(
                            Icons.keyboard_arrow_down_rounded,
                            () => _nudgeSelected(const Offset(0, 1)),
                          ),
                          _buildMultiBarIcon(
                            Icons.keyboard_arrow_left_rounded,
                            () => _nudgeSelected(const Offset(-1, 0)),
                          ),
                          _buildMultiBarIcon(
                            AppIcons.forward,
                            () => _nudgeSelected(const Offset(1, 0)),
                          ),
                          Container(
                            width: 1,
                            height: 24,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            color: pureWhite.withValues(alpha: 0.2),
                          ),
                          _buildMultiBarIcon(
                            Icons.copy_rounded,
                            _duplicateSelectedGroup,
                          ),
                          // 🚀 [신규] 잠금/정렬은 아이콘만으로는 뜻이
                          // 바로 와닿지 않을 수 있어 짧은 라벨을 같이
                          // 붙였다(이동/복제/삭제는 아이콘만으로도
                          // 충분히 익숙한 동작이라 그대로 둠).
                          _buildMultiBarLabeledIcon(
                            _selectedGroup.isNotEmpty &&
                                    _selectedGroup.every((i) => i.isLocked)
                                ? Icons.lock_open_rounded
                                : Icons.lock_outline_rounded,
                            _selectedGroup.isNotEmpty &&
                                    _selectedGroup.every((i) => i.isLocked)
                                ? "잠금 해제"
                                : "잠금",
                            _toggleLockSelected,
                          ),
                          _buildMultiBarLabeledIcon(
                            Icons.align_horizontal_left_rounded,
                            "정렬",
                            _multiSelectedIds.length >= 2
                                ? _showAlignmentSheet
                                : null,
                          ),
                          _buildMultiBarIcon(
                            Icons.delete_outline_rounded,
                            _deleteSelectedGroup,
                            color: warningRed,
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: "선택 해제",
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: () {
                      setState(() {
                        for (final i in _placedItems) {
                          i.isSelected = false;
                        }
                        _multiSelectedIds = {};
                      });
                    },
                    icon: const Icon(
                      Icons.close_rounded,
                      color: pureWhite,
                      size: 26,
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

  Widget _buildMultiBarIcon(
    IconData icon,
    VoidCallback? onPressed, {
    Color color = pureWhite,
    String? tooltip,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: Icon(
        icon,
        color: onPressed == null ? color.withValues(alpha: 0.3) : color,
        size: 26,
      ),
    );
  }

  // 잠금·정렬처럼 아이콘만으로는 뜻이 바로 오지 않는 것에 짧은 글을 붙인다.
  Widget _buildMultiBarLabeledIcon(
    IconData icon,
    String label,
    VoidCallback? onPressed,
  ) {
    final bool enabled = onPressed != null;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: enabled ? pureWhite : pureWhite.withValues(alpha: 0.3),
                size: 22,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: enabled
                      ? pureWhite.withValues(alpha: 0.9)
                      : pureWhite.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 여러 개 선택 켜기/끄기(예전엔 위 막대에 있었다).
  Widget _buildMultiSelectToggle() {
    return _toolToggle(
      icon: Icons.library_add_check_rounded,
      label: "여러 개 선택",
      selected: _multiSelectMode,
      color: tossBlue,
      onTap: _toggleMultiSelectMode,
    );
  }
}
