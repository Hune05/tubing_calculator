// 작업 배치도 화면 — 놓기·끌기·맞추기·돌리기·복제.
// layout_board_page.dart의 _LayoutBoardPageState를 역할별로 나눈 part(10-13). 동작은 같다.
// setState는 State 밖(확장)에서 부르면 보호 멤버 경고가 나지만, 이 확장은 그 State 자신이다.
// ignore_for_file: invalid_use_of_protected_member
part of '../layout_board_page.dart';

extension _LayoutBoardPlace on _LayoutBoardPageState {
  Offset _snapToGrid(Offset offset) {
    if (_gridSize <= 0) return offset;
    double dx = (offset.dx / _gridSize).round() * _gridSize;
    double dy = (offset.dy / _gridSize).round() * _gridSize;
    return Offset(dx, dy);
  }

  // 🚀 [복원] 드래그 중인 모듈의 좌/중앙/우(또는 상/중앙/하)가 다른
  // 모듈의 같은 기준선에 근접하면 안내선을 그어준다. 위치를 강제로
  // 옮기지는 않는다(그냥 눈에 보이는 힌트) - 실제로 "다른 모듈이
  // 움직이던" 문제는 이 안내선 때문이 아니라 모듈 위젯에 key가 없어
  // 생긴 별개의 버그였고, 이미 고쳤다(각 모듈의 Positioned에
  // ValueKey(item.id) 부여).
  Offset _snapToAlignment(PlacedItem dragging, Offset proposed) {
    const double snapThreshold = 6.0;
    // 가운데는 부품 기준점(접속구 가운데, 없으면 상자 가운데)으로 견준다.
    final Offset ref = itemRefCenterOffset(dragging);
    final double left = proposed.dx;
    final double right = proposed.dx + dragging.width;
    final double centerX = proposed.dx + ref.dx;
    final double top = proposed.dy;
    final double bottom = proposed.dy + dragging.height;
    final double centerY = proposed.dy + ref.dy;

    bool rangesOverlap(
      double aStart,
      double aEnd,
      double bStart,
      double bEnd,
    ) => aStart < bEnd && bStart < aEnd;

    double? guideX;
    double? guideY;

    for (final other in _placedItems) {
      if (other.id == dragging.id) continue;
      final double oLeft = other.position.dx;
      final double oRight = other.position.dx + other.width;
      final double oCenterX = other.center.dx;
      final double oTop = other.position.dy;
      final double oBottom = other.position.dy + other.height;
      final double oCenterY = other.center.dy;

      final bool yOverlaps = rangesOverlap(top, bottom, oTop, oBottom);
      final bool xOverlaps = rangesOverlap(left, right, oLeft, oRight);

      if (guideX == null && !yOverlaps) {
        if ((left - oLeft).abs() <= snapThreshold) {
          guideX = oLeft;
        } else if ((right - oRight).abs() <= snapThreshold) {
          guideX = oRight;
        } else if ((centerX - oCenterX).abs() <= snapThreshold) {
          guideX = oCenterX;
        }
      }
      if (guideY == null && !xOverlaps) {
        if ((top - oTop).abs() <= snapThreshold) {
          guideY = oTop;
        } else if ((bottom - oBottom).abs() <= snapThreshold) {
          guideY = oBottom;
        } else if ((centerY - oCenterY).abs() <= snapThreshold) {
          guideY = oCenterY;
        }
      }
    }

    _alignGuideX = guideX;
    _alignGuideY = guideY;
    return proposed;
  }

  // 🚀 [버그 수정] 정렬 스냅뿐 아니라 그냥 드래그로도 모듈을 다른 모듈
  // 위에 완전히 겹쳐 놓을 수 있었다(패널 모듈은 실제 물건이라 서로
  // 같은 자리를 차지할 수 없어야 한다). 후보 위치가 다른 모듈과
  // 겹치는지 검사해서, 겹치면 그 위치로는 이동을 아예 허용하지 않는다.
  bool _overlapsAny(
    PlacedItem dragging,
    Offset candidate, {
    Set<String>? excludeIds,
  }) {
    final Rect rect = Rect.fromLTWH(
      candidate.dx,
      candidate.dy,
      dragging.width,
      dragging.height,
    );
    for (final other in _placedItems) {
      if (other.id == dragging.id) continue;
      if (excludeIds != null && excludeIds.contains(other.id)) continue;
      // 메모 글자는 자리를 차지하지 않는다. 스키드 평면에서는 형강 위에 JB·부속을 올리는
      // 게 정상이라, 형강이거나 바닥에서 높이가 다르면 겹쳐도 된다(예전엔 높이를 몰라 막았다).
      if (dragging.shape == InstrumentShape.note ||
          other.shape == InstrumentShape.note) {
        continue;
      }
      if (_isSkid && _plateId == kPlateMain && _skidStackOk(dragging, other)) {
        continue;
      }
      // DIN 레일 부품은 레일 위에 올라앉는 것이 정상이라 레일과는 겹쳐도 된다.
      if ((_isRail(other) && _isRailPart(dragging)) ||
          (_isRail(dragging) && _isRailPart(other))) {
        continue;
      }
      final Rect otherRect = Rect.fromLTWH(
        other.position.dx,
        other.position.dy,
        other.width,
        other.height,
      );
      if (rect.overlaps(otherRect)) return true;
    }
    return false;
  }

  bool _skidStackOk(PlacedItem a, PlacedItem b) {
    if (_skidSteelShapes.contains(a.shape) ||
        _skidSteelShapes.contains(b.shape)) {
      return true;
    }
    return (a.elevation ?? 0) != (b.elevation ?? 0);
  }

  void _onAcceptItem(ModulePreset preset, Offset localPosition) {
    // 스키드 정면·측면에서 놓으면 평면 부품으로 놓는다(한 부품을 모든 면에서 본다).
    if (_isSkid && _plateId != kPlateMain) {
      _placeFromView(preset, localPosition);
      return;
    }
    HapticFeedback.mediumImpact();
    _pushUndo();
    setState(() {
      for (var item in _placedItems) {
        item.isSelected = false;
      }

      double clampedX = localPosition.dx.clamp(
        0.0,
        math.max(0.0, _panelWidth - preset.width),
      );
      double clampedY = localPosition.dy.clamp(
        0.0,
        math.max(0.0, _panelHeight - preset.height),
      );

      final newItem = PlacedItem(
        id: newLayoutId(),
        name: preset.name,
        position: _snapToGrid(Offset(clampedX, clampedY)),
        width: preset.width,
        height: preset.height,
        isSelected: true,
        shape: preset.shape,
        depth: preset.depthOrGuess,
        // 🚀 [버그 수정] 새로 놓는 부품은 각도 칸을 0으로 못박는다. 비워 두면(null)
        // 처음 돌릴 때 "칸 비율로 이미 돌아가 있는지" 추측하는 예전 부품용 로직을 타는데,
        // 단자대·DIN 레일처럼 가로가 긴 전기 부품은 그 추측표(isLandscape)에 없어 "이미
        // 90° 돌아간 것"으로 잘못 보고, 실제로는 90°만 돌렸는데 각도 칸은 180으로 뛰면서
        // 가로세로가 안 맞아 찌그러져 보였다. 새로 놓을 땐 안 돌린 게 확실하므로 0으로 박는다.
        rotation: 0,
      );
      _snapToRail(newItem);
      _snapToSteel(newItem, plan: _placedItems);

      _placedItems.add(newItem);
      _activeItem = newItem;
      _previewItem = null;
    });
    _showInspectorBottomSheet(_placedItems.last);
  }

  WallPoint? _getNearestWallPoint(Offset touchPosition) {
    double distLeft = touchPosition.dx;
    double distRight = _panelWidth - touchPosition.dx;
    double distTop = touchPosition.dy;
    double distBottom = _panelHeight - touchPosition.dy;

    double minDist = [
      distLeft,
      distRight,
      distTop,
      distBottom,
    ].reduce(math.min);
    if (minDist > _wallTapTolerance) return null;

    Offset wallPos;
    if (minDist == distLeft) {
      wallPos = Offset(0, touchPosition.dy);
    } else if (minDist == distRight) {
      wallPos = Offset(_panelWidth, touchPosition.dy);
    } else if (minDist == distTop) {
      wallPos = Offset(touchPosition.dx, 0);
    } else {
      wallPos = Offset(touchPosition.dx, _panelHeight);
    }

    return WallPoint(position: _snapToGrid(wallPos));
  }

  void _onTapItem(PlacedItem item) {
    HapticFeedback.lightImpact();
    if (_mode == BoardMode.measureDimension) {
      _handleDimensionPoint(item);
      return;
    }
    if (_multiSelectMode) {
      setState(() {
        if (_multiSelectedIds.contains(item.id)) {
          _multiSelectedIds = {..._multiSelectedIds}..remove(item.id);
          item.isSelected = false;
        } else {
          _multiSelectedIds = {..._multiSelectedIds, item.id};
          item.isSelected = true;
        }
      });
      return;
    }
    setState(() {
      for (var i in _placedItems) {
        i.isSelected = false;
      }
      item.isSelected = true;
      _activeItem = item;
    });
    _showInspectorBottomSheet(item);
  }

  void _onTapBoard(Offset localPosition) {
    if (_mode == BoardMode.measureDimension) {
      // 🚀 [신규] 측정 시작 전(첫 지점을 아직 안 찍은 상태)에 기존
      // 치수선 근처를 탭하면, 새 측정을 시작하는 대신 그 치수선을
      // 삭제/기준 전환/메모/최소 간격 설정할 수 있는 창을 연다.
      if (_dimensionStartPoint == null) {
        final PlacedDimension? hitDim = _findDimensionNear(localPosition);
        if (hitDim != null) {
          HapticFeedback.lightImpact();
          _showDimensionActionsSheet(hitDim);
          return;
        }
      }
      final WallPoint? nearestWall = _getNearestWallPoint(localPosition);
      if (nearestWall == null) return; // 벽에서 너무 먼 빈 허공 탭은 무시
      HapticFeedback.lightImpact();
      _handleDimensionPoint(nearestWall);
    } else {
      // 스키드: 경로 선 가까이를 누르면 그 경로 입력을 연다.
      if (_isSkid) {
        final ConduitRoute? hit = _findRouteNear(localPosition);
        if (hit != null) {
          HapticFeedback.lightImpact();
          _showRouteEditor(hit);
          return;
        }
      }
      setState(() {
        for (var i in _placedItems) {
          i.isSelected = false;
        }
        _activeItem = null;
        _multiSelectedIds = {};
      });
    }
  }

  Offset? _boardLocal(Offset global) {
    final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.globalToLocal(global);
  }

  // 지금 화면에 보이는 도면 가운데(모듈 왼쪽 위 자리). 못 구하면 도면 한가운데.
  Offset _visibleBoardCenter(ModulePreset p) {
    final half = Offset(p.width / 2, p.height / 2);
    try {
      final viewer = _viewerKey.currentContext!.findRenderObject() as RenderBox;
      final board = _boardKey.currentContext!.findRenderObject() as RenderBox;
      final g = viewer.localToGlobal(viewer.size.center(Offset.zero));
      return board.globalToLocal(g) - half;
    } catch (_) {
      return Offset(_panelWidth / 2, _panelHeight / 2) - half;
    }
  }

  /// 부품 가운데가 레일 위(가로 안, 세로로 40mm 안)에 오면 세로 자리를 레일 가운데에 맞춘다.
  /// 스키드 평면에서 부품을 형강 위로 올렸으면(부품 가운데가 형강 칸 안) 바닥에서 높이를 그 형강 윗면에
  /// 맞춘다. 형강 위가 아니면 높이를 건드리지 않는다. 맞췄으면 안내 글을 띄운다.
  void _snapToSteel(PlacedItem item, {List<PlacedItem>? plan}) {
    if (!_isSkid || _plateId != kPlateMain) return;
    final double? e = skidRestElevation(item, plan ?? _placedItems);
    if (e == null) return;
    if (item.elevation != null && (item.elevation! - e).abs() < 0.5) return;
    item.elevation = e;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              keepWords('형강 위에 얹었습니다. 바닥에서 높이 ${e.round()}mm로 맞췄습니다.'),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
    });
  }

  void _snapToRail(PlacedItem item) {
    if (!_isRailPart(item)) return;
    final double cx = item.position.dx + item.width / 2;
    final double cy = item.position.dy + item.height / 2;
    for (final rail in _placedItems) {
      if (rail.id == item.id || !_isRail(rail)) continue;
      final Rect r = rail.boundingBox;
      // 세로로 긴 레일(돌려 놓은 것)은 가로 자리를 맞춘다.
      final bool vertical = rail.height > rail.width;
      if (vertical) {
        if (cy < r.top || cy > r.bottom || (cx - r.center.dx).abs() > 40) {
          continue;
        }
        item.position = Offset(
          (r.center.dx - item.width / 2).clamp(
            0.0,
            math.max(0.0, _panelWidth - item.width),
          ),
          item.position.dy,
        );
      } else {
        if (cx < r.left || cx > r.right || (cy - r.center.dy).abs() > 40) {
          continue;
        }
        item.position = Offset(
          item.position.dx,
          (r.center.dy - item.height / 2).clamp(
            0.0,
            math.max(0.0, _panelHeight - item.height),
          ),
        );
      }
      return;
    }
  }

  /// 레일에 붙은 부품들의 폭 합(레일 길이 제안).
  double _railPartsWidth(PlacedItem rail) {
    final Rect r = rail.boundingBox;
    final bool vertical = rail.height > rail.width;
    double sum = 0;
    for (final it in _placedItems) {
      if (!_isRailPart(it)) continue;
      final Offset c = it.center;
      if (vertical
          ? (c.dy >= r.top &&
                c.dy <= r.bottom &&
                (c.dx - r.center.dx).abs() <= 40)
          : (c.dx >= r.left &&
                c.dx <= r.right &&
                (c.dy - r.center.dy).abs() <= 40)) {
        sum += vertical ? it.height : it.width;
      }
    }
    return sum;
  }

  /// 레일 편집칸 아래 한 줄: 붙은 부품 폭 합과 "이 길이로" 단추. 레일이 아니거나 붙은 것이 없으면 null.
  Widget? _buildRailLengthHint(PlacedItem item, VoidCallback onApplied) {
    if (!_isRail(item)) return null;
    final double sum = _railPartsWidth(item);
    if (sum <= 0) return null;
    final bool vertical = item.height > item.width;
    final double now = vertical ? item.height : item.width;
    // 양 끝 여유 20mm.
    final double suggest = (sum + 40).ceilToDouble();
    return Container(
      key: const ValueKey("rail_length_hint"),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tossBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              keepWords(
                "붙은 부품 폭 합 ${sum.toInt()}mm (여유 포함 ${suggest.toInt()}) · 지금 레일 ${now.toInt()}",
              ),
              style: const TextStyle(
                fontSize: 13,
                color: tossText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: now == suggest
                ? null
                : () {
                    _pushUndo();
                    setState(() {
                      if (vertical) {
                        item.height = suggest;
                      } else {
                        item.width = suggest;
                      }
                    });
                    onApplied();
                  },
            child: const Text(
              "이 길이로",
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  bool _showResizeHandle(PlacedItem item) =>
      item.isSelected &&
      !item.isLocked &&
      !_pdfCapture &&
      _mode == BoardMode.placeModule &&
      !_multiSelectMode &&
      _viewZoom >= 2.0;

  Widget _buildResizeHandle(PlacedItem item) {
    // 화면에서 40dp가 되게 도면 단위로 환산한다.
    final double s = 40 / _viewZoom;
    return Positioned(
      right: -s / 2,
      bottom: -s / 2,
      child: GestureDetector(
        key: ValueKey("resize_${item.id}"),
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) {
          _pushUndo();
          _resizeStart = (w: item.width, h: item.height);
          _resizeRaw = Offset.zero;
        },
        onPanUpdate: (d) {
          final st = _resizeStart;
          if (st == null) return;
          _resizeRaw += d.delta;
          setState(() {
            final Offset want = _snapToGrid(
              Offset(st.w + _resizeRaw.dx, st.h + _resizeRaw.dy),
            );
            item.width = want.dx.clamp(
              5.0,
              math.max(5.0, _panelWidth - item.position.dx),
            );
            item.height = want.dy.clamp(
              5.0,
              math.max(5.0, _panelHeight - item.position.dy),
            );
          });
        },
        onPanEnd: (_) {
          _resizeStart = null;
          _saveDraftToPrefs();
        },
        child: Container(
          width: s,
          height: s,
          decoration: BoxDecoration(
            color: pureWhite,
            shape: BoxShape.circle,
            border: Border.all(color: tossBlue, width: 2 / _viewZoom),
          ),
          child: Icon(
            Icons.open_in_full_rounded,
            size: s * 0.5,
            color: tossBlue,
          ),
        ),
      ),
    );
  }

  /// 지금 돌아가 있는 각도(90° 단위). 각도 칸이 없는 예전 부품은 그림처럼 가로·세로 비율로 가린다.
  int _effectiveTurns(PlacedItem item) {
    if (item.quarterTurns != null) return item.quarterTurns!;
    final String? s = item.shape;
    if (s == null || s.isEmpty || SkidShape.isSkid(s)) return 0;
    return InstrumentShape.inferredQuarterTurns(
      s,
      Size(item.width, item.height),
    );
  }

  /// 90° 시계 방향으로 돌린다. 가로·세로를 바꾸고 각도 칸을 90 더한다(0→90→180→270→0).
  void _rotateItem(PlacedItem item) {
    _pushUndo();
    setState(() {
      item.rotation = ((_effectiveTurns(item) + 1) % 4) * 90;
      final double temp = item.width;
      item.width = item.height;
      item.height = temp;
      item.position = Offset(
        item.position.dx.clamp(0.0, math.max(0.0, _panelWidth - item.width)),
        item.position.dy.clamp(0.0, math.max(0.0, _panelHeight - item.height)),
      );
    });
    HapticFeedback.lightImpact();
  }

  /// 좌우 뒤집기를 보일 부품: 그림이 있는 것(메모 글자·덕트·전기 부품은 뒤집을 것이 없다).
  bool _canFlip(PlacedItem item) {
    final String? s = item.shape;
    if (s == null || s.isEmpty) return false;
    if (SkidShape.isFitting(s)) return true;
    if (SkidShape.isSkid(s)) return false;
    if (s == InstrumentShape.note || s == InstrumentShape.duct) return false;
    if (s.startsWith('el_')) return false;
    return true;
  }

  /// 부품을 길이 방향으로 좌우 뒤집는다(부속은 허브가 반대쪽). 크기·자리는 그대로.
  void _flipItem(PlacedItem item) {
    _pushUndo();
    setState(() => item.flipped = !item.flipped);
    HapticFeedback.lightImpact();
  }

  // 부품 하나 복제: 오른쪽 아래로 20mm 비켜 놓는다.
  void _duplicateItem(PlacedItem item) {
    _pushUndo();
    final newItem = PlacedItem(
      id: newLayoutId(),
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
      isSelected: false,
      shape: item.shape,
      depth: item.depth,
      elevation: item.elevation,
      flipped: item.flipped,
      tag: item.tag,
      // 🚀 [버그 수정] 각도 칸을 안 옮겨서, 90°로 돌려 둔 부품을 복제하면 복제본이
      // 각도 칸 없는 부품처럼 취급되어(추측 로직을 타서) 다음에 돌릴 때 찌그러질 수 있었다.
      rotation: item.rotation,
    );
    setState(() {
      _placedItems.add(newItem);
    });
    HapticFeedback.mediumImpact();
  }
}
