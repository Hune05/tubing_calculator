// 작업 배치도 화면 — 도면 그리기(캔버스·부품·미니맵).
// layout_board_page.dart의 _LayoutBoardPageState를 역할별로 나눈 part(10-13). 동작은 같다.
// setState는 State 밖(확장)에서 부르면 보호 멤버 경고가 나지만, 이 확장은 그 State 자신이다.
// ignore_for_file: invalid_use_of_protected_member
part of '../layout_board_page.dart';

extension _LayoutBoardCanvas on _LayoutBoardPageState {
  /// 지금 확대 배율(가로축). getMaxScaleOnAxis는 화면 맞춤에서 깊이축 1까지 봐서 줄여 볼 때도 1로 나온다.
  double get _viewZoom {
    final m = _viewerController.value;
    return math.sqrt(m[0] * m[0] + m[1] * m[1]);
  }

  /// 치수·가상선·경로 이름 글씨 배율: 줄여 볼 때도 읽히는 크기로(dimensionMarkScale).
  /// PDF로 찍는 동안은 1로 고정한다(판마다 확대 배율이 달라 쪽마다 글씨 크기가 달랐다).
  double get _markScale => _pdfCapture ? 1.0 : dimensionMarkScale(_viewZoom);

  /// 판 가로·세로(W·H) 표기 글씨 크기(도면 mm). 16mm로 두면 스키드를 화면에 맞췄을 때
  /// 2px로 작아져서, 화면에서 12px 아래로 작아지지 않게 한다.
  // 판 가로·세로 글자. 스키드는 어느 면인지 알 수 있게 길이·폭·높이로 쓴다
  // (측면에서 "W: 1200"만 보이면 길이가 잘린 것처럼 보였다). 캐비닛은 W·H 그대로.
  String get _sizeLabelW {
    if (!_isSkid) return "W";
    return _plateId == kPlateMain || _plateId == kSkidViewFront ? "길이" : "폭";
  }

  String get _sizeLabelH {
    if (!_isSkid) return "H";
    return _plateId == kPlateMain ? "폭" : "높이";
  }

  double get _sizeLabelFont {
    final double z = _viewZoom;
    return z <= 0 ? 16 : math.max(16, 12 / z);
  }

  // 도면(확대·이동, 모듈 끌어 놓기, 치수 찍기). 좁은 화면·넓은 화면이 같이 쓴다.
  Widget _buildBoardCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 🚀 [신규] 미니맵에서 "지금 보고 있는 영역"을
        // 계산하려면 뷰포트의 실제 화면 크기가 필요하다.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _viewportSize != constraints.biggest) {
            setState(() => _viewportSize = constraints.biggest);
          }
          // 10-16 캐드식: 처음 연 그대로(확대·이동 안 함)면 판 밖 여백 치수가 화면 밖이라 맞춰 준다.
          if (mounted &&
              _dimStyle == 'cad' &&
              _viewportSize != null &&
              _viewerController.value.isIdentity()) {
            _fitPending = true;
          }
          if (mounted && _fitPending && _viewportSize != null) {
            _fitPending = false;
            setState(_fitBoardToView);
          }
        });
        return GestureDetector(
          // 10-16 캐드식: 판 밖 여백의 치수는 판 위 탭에 안 걸리니 여기서 받는다(판 안 탭은 안쪽이 먼저 가져간다).
          onTapUp: _dimStyle == 'cad'
              ? (d) => _onTapMargin(d.localPosition)
              : null,
          child: InteractiveViewer(
            key: _viewerKey,
            transformationController: _viewerController,
            minScale: 0.05,
            // 스키드는 도면이 커서(2400mm 이상) 화면에 맞추면 0.15배 안팎이다. 치수를 볼 만큼 더 키울 수 있게.
            maxScale: _isSkid ? 12.0 : 4.0,
            boundaryMargin: const EdgeInsets.all(2000),
            constrained: false,
            child: DragTarget<ModulePreset>(
              onMove: (details) {
                final RenderBox box =
                    _boardKey.currentContext!.findRenderObject() as RenderBox;
                Offset localPos = box.globalToLocal(details.offset);
                double clampedX = localPos.dx.clamp(
                  0.0,
                  math.max(0.0, _panelWidth - details.data.width),
                );
                double clampedY = localPos.dy.clamp(
                  0.0,
                  math.max(0.0, _panelHeight - details.data.height),
                );
                setState(() {
                  _previewItem = PlacedItem(
                    id: 'preview',
                    name: details.data.name,
                    position: _snapToGrid(Offset(clampedX, clampedY)),
                    width: details.data.width,
                    height: details.data.height,
                    shape: details.data.shape,
                    rotation: 0,
                  );
                });
              },
              onLeave: (data) => setState(() => _previewItem = null),
              onAcceptWithDetails: (details) {
                final RenderBox box =
                    _boardKey.currentContext!.findRenderObject() as RenderBox;
                _onAcceptItem(details.data, box.globalToLocal(details.offset));
              },
              builder: (context, candidateData, rejectedData) {
                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    GestureDetector(
                      onTapUp: (details) => _onTapBoard(details.localPosition),
                      child: RepaintBoundary(
                        key: _captureKey,
                        child: Container(
                          key: _boardKey,
                          width: _panelWidth,
                          height: _panelHeight,
                          // 10-16: 판 테두리는 부품 위에 겹쳐 그린다. 바탕(decoration)에 두면 테두리 3이
                          // 안쪽 여백이 되어 부품 전체가 3mm 밀리고, 판 높이만 한 부품(덕트 800)이 끝에서 잘렸다.
                          foregroundDecoration: BoxDecoration(
                            border: Border.all(color: tossText, width: 3),
                          ),
                          decoration: BoxDecoration(
                            color: pureWhite,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 30,
                                offset: const Offset(10, 10),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              if (_backgroundImagePath != null &&
                                  File(_backgroundImagePath!).existsSync())
                                // 축척을 맞췄으면 그 자리·크기(mm)에, 아니면 판에 맞춰 깐다.
                                _backgroundRect != null
                                    ? Positioned.fromRect(
                                        key: const ValueKey("board_background"),
                                        rect: _backgroundRect!,
                                        child: Opacity(
                                          opacity: _backgroundOpacity,
                                          child: ColorFiltered(
                                            colorFilter: _backgroundFilter,
                                            child: Image.file(
                                              File(_backgroundImagePath!),
                                              fit: BoxFit.fill,
                                            ),
                                          ),
                                        ),
                                      )
                                    : Positioned.fill(
                                        key: const ValueKey("board_background"),
                                        child: Opacity(
                                          opacity: _backgroundOpacity,
                                          child: ColorFiltered(
                                            colorFilter: _backgroundFilter,
                                            child: Image.file(
                                              File(_backgroundImagePath!),
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ),
                                      ),
                              CustomPaint(
                                size: Size.infinite,
                                painter: GridPainter(
                                  gridSize: _gridSize > 0 ? _gridSize : 5.0,
                                ),
                              ),
                              if (_isSkid) _buildSkidOverlay(),
                              if (_previewItem != null &&
                                  _mode == BoardMode.placeModule) ...[
                                Positioned(
                                  left: _previewItem!.position.dx,
                                  top: _previewItem!.position.dy,
                                  child: Opacity(
                                    opacity: 0.5,
                                    child: _buildBoardItem(_previewItem!),
                                  ),
                                ),
                              ],

                              // 🚀 [복원] 안내선 자체는 문제가
                              // 없었다 - 아래 _placedItems.map()의
                              // Positioned에 key가 있는 한, 이
                              // 위젯들이 조건부로 나타났다 사라져도
                              // 더 이상 목록 순서가 밀려서 엉뚱한
                              // 모듈에 제스처가 연결되는 일이
                              // 없다.
                              if (_alignGuideX != null)
                                Positioned(
                                  left: _alignGuideX,
                                  top: 0,
                                  bottom: 0,
                                  child: IgnorePointer(
                                    child: Container(
                                      width: 1.4,
                                      color: alignGuideColor,
                                    ),
                                  ),
                                ),
                              if (_alignGuideY != null)
                                Positioned(
                                  top: _alignGuideY,
                                  left: 0,
                                  right: 0,
                                  child: IgnorePointer(
                                    child: Container(
                                      height: 1.4,
                                      color: alignGuideColor,
                                    ),
                                  ),
                                ),

                              // 경로 손잡이는 부품 아래에(정면·측면에서 부품을 잡으려다 경로가 열리지 않게).
                              if (_isSkid && _mode == BoardMode.placeModule)
                                ..._buildRouteHandles(),
                              if (_isSkid && _plateId != kPlateMain) ...[
                                ..._buildViewProxies(),
                                ..._buildHiddenOutlines(),
                              ],
                              ..._placedItems.map((item) {
                                // 10-16: "치수" 상태에서도 부품을 끌어 옮긴다(치수선은 부품을 따라온다).
                                final bool canDrag = !item.isLocked;
                                // 끌기 세 단계(손가락 끌기·길게 누른 채 끌기가 같이 쓴다).
                                void dragStart() {
                                  // 드래그 한 번 = undo 한 단계
                                  // (onPanUpdate마다 쌓으면 되돌리기가
                                  // 프레임 단위로 쪼개져 버린다).
                                  final bool isGroupDrag =
                                      _multiSelectMode &&
                                      _multiSelectedIds.contains(item.id) &&
                                      _multiSelectedIds.length > 1;
                                  _pushUndo();
                                  _dragFromOverlap = isGroupDrag
                                      ? _placedItems.any(
                                          (i) =>
                                              _multiSelectedIds.contains(
                                                i.id,
                                              ) &&
                                              _overlapsAny(
                                                i,
                                                i.position,
                                                excludeIds: _multiSelectedIds,
                                              ),
                                        )
                                      : _overlapsAny(item, item.position);
                                  setState(() {
                                    _dragRawPosition = item.position;
                                    _activeItem = item;
                                    if (isGroupDrag) {
                                      _groupDragAnchorOrigin = item.position;
                                      _groupDragOrigins = {
                                        for (final i in _placedItems)
                                          if (_multiSelectedIds.contains(i.id))
                                            i.id: i.position,
                                      };
                                      double minX = double.infinity;
                                      double minY = double.infinity;
                                      double maxRight = -double.infinity;
                                      double maxBottom = -double.infinity;
                                      for (final i in _placedItems) {
                                        if (!_multiSelectedIds.contains(i.id)) {
                                          continue;
                                        }
                                        minX = math.min(minX, i.position.dx);
                                        minY = math.min(minY, i.position.dy);
                                        maxRight = math.max(
                                          maxRight,
                                          i.position.dx + i.width,
                                        );
                                        maxBottom = math.max(
                                          maxBottom,
                                          i.position.dy + i.height,
                                        );
                                      }
                                      _groupOriginBounds = Rect.fromLTRB(
                                        minX,
                                        minY,
                                        maxRight,
                                        maxBottom,
                                      );
                                    } else {
                                      _groupDragAnchorOrigin = null;
                                      _groupDragOrigins = {};
                                      _groupOriginBounds = null;
                                      if (!_multiSelectMode) {
                                        for (var i in _placedItems) {
                                          i.isSelected = false;
                                        }
                                        item.isSelected = true;
                                      }
                                    }
                                  });
                                }

                                void dragUpdate(Offset delta) {
                                  setState(() {
                                    _dragRawPosition += delta;
                                    final bool isGroupDrag =
                                        _groupDragOrigins.isNotEmpty &&
                                        _groupDragOrigins.containsKey(item.id);
                                    if (isGroupDrag) {
                                      // 🚀 [버그 수정] 각 모듈마다 따로 화면
                                      // 경계에 맞춰 자르면(clamp) 폭이 서로
                                      // 다른 모듈들이 경계에 닿는 시점이 달라
                                      // 어떤 건 멈추고 어떤 건 계속 움직여서
                                      // 서로 겹쳐버렸다 - 선택된 모듈 전체의
                                      // 바운딩 박스 기준으로 delta를 딱 한 번만
                                      // 잘라서, 항상 같은 delta를 모두에게
                                      // 적용해 서로의 상대 위치를 유지한다.
                                      final Rect bounds = _groupOriginBounds!;
                                      final Offset rawDelta =
                                          _dragRawPosition -
                                          _groupDragAnchorOrigin!;
                                      final double minDx = -bounds.left;
                                      double maxDx = _panelWidth - bounds.right;
                                      if (maxDx < minDx) {
                                        maxDx = minDx;
                                      }
                                      final double minDy = -bounds.top;
                                      double maxDy =
                                          _panelHeight - bounds.bottom;
                                      if (maxDy < minDy) {
                                        maxDy = minDy;
                                      }
                                      final Offset clampedDelta = Offset(
                                        rawDelta.dx.clamp(minDx, maxDx),
                                        rawDelta.dy.clamp(minDy, maxDy),
                                      );
                                      final Offset snappedDelta = _snapToGrid(
                                        clampedDelta,
                                      );
                                      // 🚀 [버그 수정] 그룹
                                      // 전체를 이 delta만큼
                                      // 옮겼을 때 선택되지
                                      // 않은 다른 모듈과
                                      // 겹치면 이번 프레임의
                                      // 이동은 통째로
                                      // 취소한다(그룹끼리는
                                      // 서로 겹침 검사에서
                                      // 제외).
                                      bool wouldCollide = false;
                                      for (final entry
                                          in _groupDragOrigins.entries) {
                                        final PlacedItem it = _placedItems
                                            .firstWhere(
                                              (x) => x.id == entry.key,
                                            );
                                        final Offset newPos =
                                            entry.value + snappedDelta;
                                        if (_overlapsAny(
                                          it,
                                          newPos,
                                          excludeIds: _multiSelectedIds,
                                        )) {
                                          wouldCollide = true;
                                          break;
                                        }
                                      }
                                      if (wouldCollide && !_dragFromOverlap) {
                                        return;
                                      }
                                      for (final i in _placedItems) {
                                        if (!_multiSelectedIds.contains(i.id) ||
                                            i.isLocked) {
                                          continue;
                                        }
                                        final Offset? origin =
                                            _groupDragOrigins[i.id];
                                        if (origin == null) {
                                          continue;
                                        }
                                        i.position = origin + snappedDelta;
                                      }
                                    } else {
                                      double clampedX = _dragRawPosition.dx
                                          .clamp(
                                            0.0,
                                            math.max(
                                              0.0,
                                              _panelWidth - item.width,
                                            ),
                                          );
                                      double clampedY = _dragRawPosition.dy
                                          .clamp(
                                            0.0,
                                            math.max(
                                              0.0,
                                              _panelHeight - item.height,
                                            ),
                                          );
                                      final gridSnapped = _snapToGrid(
                                        Offset(clampedX, clampedY),
                                      );
                                      // 🚀 [복원] 안내선
                                      // 계산만 하고(위치는
                                      // 안 바꿈), 겹치는
                                      // 자리로는 이동을
                                      // 막되 X/Y를 각각
                                      // 따로 검사해서
                                      // 한쪽이 막혀도
                                      // 다른 쪽으로는
                                      // 벽을 따라
                                      // 미끄러지듯
                                      // 움직일 수 있게
                                      // 한다.
                                      final aligned = _snapToAlignment(
                                        item,
                                        gridSnapped,
                                      );
                                      if (_dragFromOverlap) {
                                        item.position = aligned;
                                        if (!_overlapsAny(item, aligned)) {
                                          _dragFromOverlap = false;
                                        }
                                      } else {
                                        final Offset xOnly = Offset(
                                          aligned.dx,
                                          item.position.dy,
                                        );
                                        if (!_overlapsAny(item, xOnly)) {
                                          item.position = xOnly;
                                        }
                                        final Offset yOnly = Offset(
                                          item.position.dx,
                                          aligned.dy,
                                        );
                                        if (!_overlapsAny(item, yOnly)) {
                                          item.position = yOnly;
                                        }
                                      }
                                    }
                                  });
                                }

                                void dragEnd() {
                                  setState(() {
                                    // DIN 레일 부품을 레일 위에 놓으면 세로 자리를 레일에 맞춘다.
                                    if (_groupDragOrigins.isEmpty) {
                                      _snapToRail(item);
                                    }
                                    // 스키드: 형강 위로 올렸으면 바닥에서 높이를 형강 윗면에 맞춘다.
                                    if (_groupDragOrigins.isEmpty) {
                                      _snapToSteel(item);
                                    }
                                    _activeItem = null;
                                    _dragFromOverlap = false;
                                    _alignGuideX = null;
                                    _alignGuideY = null;
                                    _groupDragAnchorOrigin = null;
                                    _groupDragOrigins = {};
                                    _groupOriginBounds = null;
                                  });
                                }

                                return Positioned(
                                  // 🚀 [버그 수정] 이 Positioned에
                                  // key가 없으면, 정렬 가이드선이
                                  // 조건부로 Stack children 목록에
                                  // 끼어들거나 빠질 때(예: 드래그
                                  // 도중 안내선이 나타남/사라짐)
                                  // 목록의 순서(인덱스)가 밀리면서
                                  // 플러터가 "같은 자리에 있던"
                                  // 엘리먼트를 다른 모듈 것으로
                                  // 착각해 재사용할 수 있었다.
                                  // 그러면 지금 드래그 중이던
                                  // 제스처가 엉뚱한 모듈의
                                  // onPanUpdate로 연결되어, 실제로
                                  // 다른(엉뚱한) 모듈의 위치가
                                  // 바뀌는 것처럼 보였다. id 기반
                                  // key를 달아 항상 같은 모듈에
                                  // 같은 엘리먼트가 매칭되게
                                  // 고정한다.
                                  key: ValueKey(item.id),
                                  left: item.position.dx - _kTouchHitPad,
                                  top: item.position.dy - _kTouchHitPad,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onPanStart: canDrag
                                        ? (_) => dragStart()
                                        : null,
                                    onPanUpdate: canDrag
                                        ? (d) => dragUpdate(d.delta)
                                        : null,
                                    onPanEnd: canDrag ? (_) => dragEnd() : null,
                                    onTap: () => _onTapItem(item),
                                    // 10-13: 길게 누르면 "여러 개 선택" 단추를 먼저 안 켜도 바로 고른다.
                                    // 길게 누른 채 움직이면 끌기, 움직이지 않고 떼면 "여러 개 고르기"(10-16).
                                    onLongPressStart: (_) {
                                      _lpDragMoved = false;
                                      _lpDragLast = Offset.zero;
                                    },
                                    onLongPressMoveUpdate: canDrag
                                        ? (d) {
                                            final Offset delta =
                                                d.localOffsetFromOrigin -
                                                _lpDragLast;
                                            _lpDragLast =
                                                d.localOffsetFromOrigin;
                                            if (!_lpDragMoved) {
                                              _lpDragMoved = true;
                                              dragStart();
                                            }
                                            dragUpdate(delta);
                                          }
                                        : null,
                                    onLongPressEnd: (_) {
                                      if (_lpDragMoved) {
                                        _lpDragMoved = false;
                                        dragEnd();
                                      } else {
                                        _selectByLongPress(item);
                                      }
                                    },
                                    child: Container(
                                      width: item.width + _kTouchHitPad * 2,
                                      height: item.height + _kTouchHitPad * 2,
                                      color: Colors.transparent,
                                      padding: const EdgeInsets.all(
                                        _kTouchHitPad,
                                      ),
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          _buildBoardItem(item),
                                          // 크기 손잡이: 2배 넘게 키웠을 때만, 고른 부품 오른쪽 아래(화면에서 40dp).
                                          if (_showResizeHandle(item))
                                            _buildResizeHandle(item),
                                          if (item.isLocked)
                                            Positioned(
                                              right: -2,
                                              top: -2,
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  3,
                                                ),
                                                decoration: const BoxDecoration(
                                                  color: tossText,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.lock_rounded,
                                                  size: 10,
                                                  color: pureWhite,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                              // 저장본과 차이: 옮긴 부품의 옛 자리·지운 부품은 점선, 새 부품은 초록 점선.
                              if (_showSavedDiff && !_pdfCapture)
                                IgnorePointer(
                                  child: CustomPaint(
                                    size: Size.infinite,
                                    painter: _SavedDiffPainter(
                                      diff: _savedDiff(),
                                      markScale: _markScale,
                                    ),
                                  ),
                                ),
                              // 치수·가상선은 부품 위에 그린다. 부품 아래에 두면 부품이 벽에
                              // 붙을수록 치수 글자가 부품 뒤로 들어가 가려졌다.
                              IgnorePointer(
                                child: CustomPaint(
                                  size: Size.infinite,
                                  painter: DimensionPainter(
                                    dimensions: _syncedDimensions,
                                    activePoint: _dimensionStartPoint,
                                    panelWidth: _panelWidth,
                                    panelHeight: _panelHeight,
                                    version: _dimensionsVersion,
                                    markScale: _markScale,
                                    style: _dimStyle,
                                    items: _placedItems,
                                    layer: 'board',
                                    // 10-16: 첫 지점으로 찍은 부품, 아니면 고른 부품의 치수만 진하게
                                    focusId: _pdfCapture
                                        ? null
                                        : _dimensionStartPoint?.id ??
                                              _placedItems
                                                  .where((i) => i.isSelected)
                                                  .map((i) => i.id)
                                                  .firstOrNull,
                                  ),
                                ),
                              ),
                              if (_mode == BoardMode.placeModule)
                                for (final g in [
                                  _previewItem,
                                  _activeItem,
                                  _routeGuideItem,
                                ])
                                  if (g != null)
                                    for (final w in _buildGuidePaints(g))
                                      IgnorePointer(child: w),
                              // 정면·측면에서 평면 부품을 끄는 동안의 가상선(옆 부품 = 이 탭 부품 + 다른 평면 부품).
                              if (_proxyGuideItem != null)
                                for (final w in _buildGuidePaints(
                                  _proxyGuideItem!,
                                  others: [
                                    ..._placedItems,
                                    for (final p in _viewProxies)
                                      if (p.it.id != _proxyDragId)
                                        PlacedItem(
                                          id: "view_${p.it.id}",
                                          name: p.it.name,
                                          position: p.rect.topLeft,
                                          width: p.rect.width,
                                          height: p.rect.height,
                                        ),
                                  ],
                                ))
                                  IgnorePointer(child: w),
                              // 🚀 [신규] 완전히 빈 도면일 때, 처음
                              // 여는 사람이 뭘 해야 할지 막막하지
                              // 않도록 샘플 배치를 눌러보게 안내.
                              // 스키드 정면·측면은 이 탭 부품이 없어도 평면 부품이 보이면 안내를 빼 가리지 않게 한다.
                              if (_placedItems.isEmpty &&
                                  _dimensions.isEmpty &&
                                  _viewProxies.isEmpty &&
                                  !_isLoadingProject)
                                Positioned.fill(
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.dashboard_customize_outlined,
                                          size: 36,
                                          color: tossSubText.withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          keepWords(
                                            "아래 '부품'을 눌러 골라\n배치를 시작하십시오",
                                          ),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: tossSubText.withValues(
                                              alpha: 0.7,
                                            ),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            height: 1.4,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        OutlinedButton.icon(
                                          onPressed: _loadSampleLayout,
                                          icon: const Icon(
                                            Icons.auto_awesome_rounded,
                                            size: 16,
                                            color: tossBlue,
                                          ),
                                          label: const Text(
                                            "샘플 배치 불러오기",
                                            style: TextStyle(
                                              color: tossBlue,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            minimumSize: const Size(40, 40),
                                            side: const BorderSide(
                                              color: tossBlue,
                                            ),
                                            backgroundColor: pureWhite,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // 10-16 캐드식: 가로·세로 치수와 판 크기는 판 밖 여백에(판에 잘리지 않게 판 바깥 층).
                    if (_dimStyle == 'cad')
                      Positioned(
                        left: 0,
                        top: 0,
                        width: _panelWidth,
                        height: _panelHeight,
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: DimensionPainter(
                              dimensions: _syncedDimensions,
                              panelWidth: _panelWidth,
                              panelHeight: _panelHeight,
                              version: _dimensionsVersion,
                              markScale: _markScale,
                              style: _dimStyle,
                              items: _placedItems,
                              layer: 'margin',
                              focusId:
                                  _dimensionStartPoint?.id ??
                                  _placedItems
                                      .where((i) => i.isSelected)
                                      .map((i) => i.id)
                                      .firstOrNull,
                            ),
                          ),
                        ),
                      ),
                    // 판 가로·세로 표기: 치수 숫자처럼 줄여 볼 때도 화면에서 12px 안팎으로 읽히게
                    // 키우고(_sizeLabelFont), 판 바로 바깥에 붙인다. 캐드식은 여백 맨 바깥 치수가 대신한다.
                    if (_dimStyle != 'cad')
                      Positioned(
                        key: const ValueKey("panel_w_label"),
                        top: -_sizeLabelFont * 1.6,
                        child: Text(
                          "$_sizeLabelW: ${_panelWidth.toInt()} mm",
                          style: TextStyle(
                            color: Colors.blueGrey.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: _sizeLabelFont,
                          ),
                        ),
                      ),
                    if (_dimStyle != 'cad')
                      Positioned(
                        key: const ValueKey("panel_h_label"),
                        left: -_sizeLabelFont * 1.6,
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: Text(
                            "$_sizeLabelH: ${_panelHeight.toInt()} mm",
                            style: TextStyle(
                              color: Colors.blueGrey.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: _sizeLabelFont,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// 캐드식 여백의 치수를 눌렀을 때(10-16): 화면 자리 → 판 좌표, 판 밖이면 치수 찾기.
  void _onTapMargin(Offset viewport) {
    if (_mode != BoardMode.measureDimension || _dimensionStartPoint != null) {
      return;
    }
    final Offset p = MatrixUtils.transformPoint(
      Matrix4.inverted(_viewerController.value),
      viewport,
    );
    if ((Offset.zero & Size(_panelWidth, _panelHeight)).contains(p)) return;
    final PlacedDimension? hit = _findDimensionNear(p);
    if (hit == null) return;
    HapticFeedback.lightImpact();
    _showDimensionActionsSheet(hit);
  }

  // 🚀 [신규] 미니맵 - 전체 도면을 축소해서 보여주고, InteractiveViewer의
  // 변환행렬을 역산해 지금 화면에 실제로 보이는 영역을 겹쳐 그린다.
  // 접어 둔 미니맵: 작은 단추 하나. 눌러야 펴져서 그 밑 모듈을 가리지 않는다.
  Widget _buildMinimapButton() {
    return Tooltip(
      message: "미니맵 펴기",
      child: Material(
        color: pureWhite.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: tossSubText.withValues(alpha: 0.4)),
        ),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => setState(() => _minimapOpen = true),
          child: const SizedBox(
            width: 48,
            height: 48,
            child: Icon(Icons.map_outlined, color: tossText, size: 24),
          ),
        ),
      ),
    );
  }

  /// 확대 배율 글자(미니맵 아래). 누르면 화면에 맞춘다.
  Widget _buildZoomLabel() {
    final double z = _viewZoom;
    final String text = z >= 10
        ? "${z.toStringAsFixed(0)}×"
        : (z >= 1 ? "${z.toStringAsFixed(1)}×" : "${z.toStringAsFixed(2)}×");
    return Tooltip(
      message: "확대 배율 · 누르면 화면에 맞춥니다",
      child: GestureDetector(
        onTap: () => setState(_fitBoardToView),
        child: Container(
          key: const ValueKey("zoom_label"),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: pureWhite.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: tossSubText.withValues(alpha: 0.4)),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: tossText,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMinimap() {
    const double miniW = 96;
    final double scale = miniW / _panelWidth;
    final double miniH = _panelHeight * scale;

    Rect? viewportRect;
    if (_viewportSize != null) {
      try {
        final Matrix4 inverse = Matrix4.inverted(_viewerController.value);
        final Offset topLeft = MatrixUtils.transformPoint(inverse, Offset.zero);
        final Offset bottomRight = MatrixUtils.transformPoint(
          inverse,
          Offset(_viewportSize!.width, _viewportSize!.height),
        );
        viewportRect = Rect.fromPoints(topLeft, bottomRight);
      } catch (_) {}
    }

    return Container(
      width: miniW,
      height: miniH,
      decoration: BoxDecoration(
        color: pureWhite.withValues(alpha: 0.92),
        border: Border.all(color: tossSubText.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          ..._placedItems.map(
            (item) => Positioned(
              left: item.position.dx * scale,
              top: item.position.dy * scale,
              width: math.max(1.5, item.width * scale),
              height: math.max(1.5, item.height * scale),
              child: Container(color: tossBlue.withValues(alpha: 0.5)),
            ),
          ),
          if (viewportRect != null)
            Positioned(
              left: (viewportRect.left * scale).clamp(0.0, miniW),
              top: (viewportRect.top * scale).clamp(0.0, miniH),
              width: (viewportRect.width * scale).clamp(4.0, miniW),
              height: (viewportRect.height * scale).clamp(4.0, miniH),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: warningRed, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 🚀 [정리] 켜고/끄는 토글 없이, 모듈 배치/이동 중에는 항상 현재
  // 선택된 가상선 색상(_currentDimType)의 가이드선 하나만 그려준다.
  List<Widget> _buildGuidePaints(PlacedItem item, {List<PlacedItem>? others}) {
    return [
      for (final type in [
        if (_showCenterGuide) DimensionType.center,
        if (_showEdgeGuide) DimensionType.edge,
      ])
        CustomPaint(
          size: Size.infinite,
          painter: SmartGuidePainter(
            item: item,
            allItems: others ?? _placedItems,
            panelWidth: _panelWidth,
            panelHeight: _panelHeight,
            currentType: type,
            markScale: _markScale,
          ),
        ),
    ];
  }

  Widget _buildBoardItem(PlacedItem item) {
    bool isMeasuringStart =
        _mode == BoardMode.measureDimension &&
        _dimensionStartPoint?.id == item.id;
    Color activeColor = _currentDimType == DimensionType.center
        ? centerDimColor
        : edgeDimColor;

    if (item.shape == InstrumentShape.note) {
      return _buildNoteItem(item, isMeasuringStart, activeColor);
    }
    if (item.shape != null) {
      return _buildInstrumentItem(item, isMeasuringStart, activeColor);
    }

    return Container(
      width: item.width,
      height: item.height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isMeasuringStart
            ? activeColor.withValues(alpha: 0.1)
            : pureWhite,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isMeasuringStart
              ? activeColor
              : (item.isSelected
                    ? tossBlue
                    : (_problemIds.contains(item.id)
                          ? warningRed
                          : Colors.blueGrey.shade300)),
          width:
              isMeasuringStart ||
                  item.isSelected ||
                  _problemIds.contains(item.id)
              ? 3
              : 1.5,
        ),
        boxShadow: item.isSelected
            ? [
                BoxShadow(
                  color: tossBlue.withValues(alpha: 0.25),
                  blurRadius: 15,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(2, 2),
                ),
              ],
      ),
      child: Center(
        child: Text(
          _itemCaption(item) == null
              ? item.name
              : "${item.name}\n${_itemCaption(item)}",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: isMeasuringStart
                ? activeColor
                : (item.isSelected ? tossBlue : tossText),
            height: 1.2,
            letterSpacing: -0.3,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  // 메모 글자: 테두리 없이 글씨만. 고르면 점선 테두리로 자리를 보여 준다.
  Widget _buildNoteItem(
    PlacedItem item,
    bool isMeasuringStart,
    Color activeColor,
  ) {
    final bool hi = item.isSelected || isMeasuringStart;
    final double font = (item.height * 0.6).clamp(8.0, 60.0);
    return Container(
      width: item.width,
      height: item.height,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: hi
          ? BoxDecoration(
              border: Border.all(
                color: isMeasuringStart ? activeColor : tossBlue,
                width: 1.5,
              ),
            )
          : null,
      alignment: Alignment.centerLeft,
      child: Text(
        item.tag == null ? item.name : "${item.tag}\n${item.name}",
        style: TextStyle(
          fontSize: font,
          fontWeight: FontWeight.w700,
          color: isMeasuringStart ? activeColor : tossText,
          height: 1.15,
        ),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // 계기 모듈: 네모 대신 정면 모양을 그리고, 이름은 가운데 흰 띠에 적는다.
  Widget _buildInstrumentItem(
    PlacedItem item,
    bool isMeasuringStart,
    Color activeColor,
  ) {
    final Color color = isMeasuringStart
        ? activeColor
        : (item.isSelected
              ? tossBlue
              : (_problemIds.contains(item.id)
                    ? warningRed
                    : const Color(0xFF64748B)));
    // 피팅처럼 작은 것은 이름 띠가 그림을 다 가려서, 글씨를 줄이고 띠를 비친다.
    final bool small = math.min(item.width, item.height) < 60;
    return SizedBox(
      width: item.width,
      height: item.height,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: SkidShape.isFitting(item.shape)
                  // 전선관 부속은 뒤집어 놓을 수 있어 스키드 부품 그림으로 그린다.
                  ? SkidPartPainter(
                      shape: item.shape!,
                      mirror: item.flipped,
                      // 커플링·유니온은 칸 비율로 못 가려서 각도 칸을 그대로 준다.
                      quarterTurns: skidTurnsOnly(item.shape)
                          ? (item.quarterTurns ?? 0)
                          : null,
                      stroke: color,
                      strokeWidth:
                          item.isSelected ||
                              isMeasuringStart ||
                              _problemIds.contains(item.id)
                          ? 2.5
                          : 1.5,
                    )
                  : InstrumentShapePainter(
                      shape: item.shape!,
                      stroke: color,
                      strokeWidth:
                          item.isSelected ||
                              isMeasuringStart ||
                              _problemIds.contains(item.id)
                          ? 2.5
                          : 1.5,
                      // 각도 칸이 있으면 그대로(0·90·180·270), 없으면 예전처럼 비율로 가린다.
                      quarterTurns: item.quarterTurns,
                      mirror: item.flipped,
                    ),
            ),
          ),
          // 고른 부품은 튜브가 붙는 자리(접속점)를 점으로 보인다.
          if (item.isSelected && !_pdfCapture)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _PortDotsPainter(
                    points: shapeConnectionPoints(
                      item.shape,
                      Size(item.width, item.height),
                      quarterTurns: _effectiveTurns(item),
                      mirror: item.flipped,
                    ),
                    radius: math.max(2.0, 6.0 / _viewZoom),
                  ),
                ),
              ),
            ),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              color: pureWhite.withValues(alpha: small ? 0.55 : 0.85),
              child: Text(
                (item.tag == null ? "" : "${item.tag}\n") +
                    (_itemCaption(item) == null ||
                            small ||
                            item.shape == InstrumentShape.duct
                        ? item.name
                        : "${item.name}\n${_itemCaption(item)}"),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: small ? 8 : 11,
                  fontWeight: FontWeight.w800,
                  color: isMeasuringStart
                      ? activeColor
                      : (item.isSelected ? tossBlue : tossText),
                  height: 1.15,
                  letterSpacing: -0.3,
                ),
                maxLines: small ? (item.tag == null ? 2 : 3) : 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 고른 부품의 접속점(튜브가 붙는 자리)을 작은 점으로.
class _PortDotsPainter extends CustomPainter {
  final List<Offset> points;
  final double radius;
  const _PortDotsPainter({required this.points, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final fill = Paint()..color = const Color(0xFFF59E0B);
    final ring = Paint()
      ..color = pureWhite
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.4;
    for (final p in points) {
      canvas.drawCircle(p, radius, fill);
      canvas.drawCircle(p, radius, ring);
    }
  }

  @override
  bool shouldRepaint(covariant _PortDotsPainter old) =>
      old.radius != radius || old.points.length != points.length;
}

/// 저장본과 지금 도면의 차이를 그린다. 옮긴 부품: 옛 자리 회색 점선 + 새 자리까지 가는 선,
/// 새 부품: 초록 점선, 지운 부품: 붉은 점선과 이름.
class _SavedDiffPainter extends CustomPainter {
  final ({
    List<(Rect, Rect)> moved,
    List<Rect> added,
    List<(Rect, String)> removed,
  })
  diff;
  final double markScale;
  const _SavedDiffPainter({required this.diff, required this.markScale});

  void _dashedRect(Canvas c, Rect r, Paint p) {
    final double dash = p.strokeWidth * 5, gap = p.strokeWidth * 3;
    void line(Offset a, Offset b) {
      final double len = (b - a).distance;
      if (len <= 0) return;
      final Offset d = (b - a) / len;
      for (double t = 0; t < len; t += dash + gap) {
        c.drawLine(a + d * t, a + d * math.min(t + dash, len), p);
      }
    }

    line(r.topLeft, r.topRight);
    line(r.topRight, r.bottomRight);
    line(r.bottomRight, r.bottomLeft);
    line(r.bottomLeft, r.topLeft);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double sw = 1.2 * markScale.clamp(1.0, 3.0);
    final grey = Paint()
      ..color = const Color(0xFF64748B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw;
    final green = Paint()
      ..color = const Color(0xFF16A34A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw;
    final red = Paint()
      ..color = warningRed
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw;
    for (final (old, now) in diff.moved) {
      _dashedRect(canvas, old, grey);
      canvas.drawLine(old.center, now.center, grey);
      canvas.drawCircle(now.center, sw * 1.5, grey..style = PaintingStyle.fill);
      grey.style = PaintingStyle.stroke;
    }
    for (final r in diff.added) {
      _dashedRect(canvas, r.inflate(sw * 2), green);
    }
    for (final (r, name) in diff.removed) {
      _dashedRect(canvas, r, red);
      final tp = TextPainter(
        text: TextSpan(
          text: "지움 $name",
          style: TextStyle(
            color: warningRed,
            fontSize: 10 * markScale.clamp(1.0, 3.0),
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: math.max(40, r.width));
      tp.paint(canvas, r.topLeft + Offset(2, 2));
    }
  }

  @override
  bool shouldRepaint(covariant _SavedDiffPainter old) => true;
}

class _HiddenOutlinePainter extends CustomPainter {
  final double strokeWidth;
  const _HiddenOutlinePainter({required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final double dash = strokeWidth * 6, gap = strokeWidth * 4;
    void line(Offset a, Offset b) {
      final double len = (b - a).distance;
      if (len <= 0) return;
      final Offset d = (b - a) / len;
      for (double t = 0; t < len; t += dash + gap) {
        canvas.drawLine(a + d * t, a + d * math.min(t + dash, len), paint);
      }
    }

    final r = Offset.zero & size;
    line(r.topLeft, r.topRight);
    line(r.topRight, r.bottomRight);
    line(r.bottomRight, r.bottomLeft);
    line(r.bottomLeft, r.topLeft);
  }

  @override
  bool shouldRepaint(covariant _HiddenOutlinePainter old) =>
      old.strokeWidth != strokeWidth;
}
