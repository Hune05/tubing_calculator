// 작업 배치도 화면 — 스키드 4면 보기·전선관 경로.
// layout_board_page.dart의 _LayoutBoardPageState를 역할별로 나눈 part(10-13). 동작은 같다.
// setState는 State 밖(확장)에서 부르면 보호 멤버 경고가 나지만, 이 확장은 그 State 자신이다.
// ignore_for_file: invalid_use_of_protected_member
part of '../layout_board_page.dart';

extension _LayoutBoardSkid on _LayoutBoardPageState {
  /// 끄는 동안 가상선을 그릴 상자: 잡은 토막을 관 바깥지름 굵기로 감싼 것.
  PlacedItem? get _routeGuideItem {
    final r = _draggingRoute;
    if (r == null) return null;
    final (planW, planH) = _planSize;
    final pts = r
        .points(_planItems)
        .map(
          (v) => projectToView(
            v,
            _plateId,
            planW: planW,
            planH: planH,
            viewH: _panelHeight,
          ),
        )
        .toList();
    if (pts.length < 2) return null;
    final int i = _routeDragSeg.clamp(0, pts.length - 2);
    final Rect box = Rect.fromPoints(pts[i], pts[i + 1]).inflate(r.od / 2);
    return PlacedItem(
      id: 'route_guide',
      name: r.name,
      position: box.topLeft,
      width: box.width,
      height: box.height,
    );
  }

  List<Widget> _buildRouteHandles() {
    final plan = _planItems;
    final (planW, planH) = _planSize;
    final double scale = _viewZoom;
    final out = <Widget>[];
    for (final r in _routes) {
      final pts = r
          .points(plan)
          .map(
            (v) => projectToView(
              v,
              _plateId,
              planW: planW,
              planH: planH,
              viewH: _panelHeight,
            ),
          )
          .toList();
      final double th = math.max(24 / (scale <= 0 ? 1 : scale), r.od + 6);
      for (int i = 0; i + 1 < pts.length; i++) {
        final Offset a = pts[i], b = pts[i + 1];
        final double len = (b - a).distance + th;
        if (len <= th) continue;
        final Offset mid = (a + b) / 2;
        out.add(
          Positioned(
            key: ValueKey("route_handle_${r.id}_$i"),
            left: mid.dx - len / 2,
            top: mid.dy - th / 2,
            child: Transform.rotate(
              angle: math.atan2(b.dy - a.dy, b.dx - a.dx),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                // 손가락을 댄 자리부터 따라오게(처음 움직인 만큼이 빠지지 않게).
                dragStartBehavior: DragStartBehavior.down,
                onTap: () => _showRouteEditor(r),
                onPanStart: (d) {
                  _routeDragSeg = i;
                  _startRouteDrag(r, d.globalPosition);
                },
                onPanUpdate: (d) => _updateRouteDrag(d.globalPosition),
                onPanEnd: (_) => _endRouteDrag(),
                child: SizedBox(width: len, height: th),
              ),
            ),
          ),
        );
      }
    }
    return out;
  }

  void _startRouteDrag(ConduitRoute r, Offset global) {
    _pushUndo();
    // 시작 부품에 붙어 있던 경로는 끌면 그 자리(부품 가운데·높이)에서 떨어져 나온다.
    if (r.startItemId != null) {
      final start = r.startPoint(_planItems);
      r
        ..startItemId = null
        ..x = start.x
        ..y = start.y
        ..z = start.z;
      showSnackOnce(
        ScaffoldMessenger.of(context),
        SnackBar(
          content: Text(
            keepWords("경로가 시작 부품에서 떨어졌습니다. 경로를 눌러 시작 부품을 다시 고를 수 있습니다."),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    setState(() => _draggingRoute = r);
    _routeDragLast = _boardLocal(global);
    HapticFeedback.selectionClick();
  }

  void _updateRouteDrag(Offset global) {
    final r = _draggingRoute;
    final now = _boardLocal(global);
    if (r == null || now == null || _routeDragLast == null) return;
    final Offset d = now - _routeDragLast!;
    _routeDragLast = now;
    setState(() {
      switch (_plateId) {
        case kSkidViewFront:
          r.x += d.dx;
          r.z -= d.dy;
        case kPlateLeft:
          r.y += d.dx;
          r.z -= d.dy;
        case kPlateRight:
          r.y -= d.dx;
          r.z -= d.dy;
        default:
          r.x += d.dx;
          r.y += d.dy;
      }
    });
  }

  void _endRouteDrag() {
    final r = _draggingRoute;
    if (r == null) return;
    double snap(double v) =>
        _gridSize <= 0 ? v : (v / _gridSize).round() * _gridSize;
    setState(() {
      r
        ..x = snap(r.x)
        ..y = snap(r.y)
        ..z = snap(r.z);
    });
    setState(() {
      _draggingRoute = null;
      _routeDragLast = null;
    });
    _saveDraftToPrefs();
  }

  /// 지금 탭에서 [p](도면 mm) 가까이 지나는 경로. 손가락 폭(화면 24px)이나 관 굵기 안이면 잡는다.
  ConduitRoute? _findRouteNear(Offset p) {
    final plan = _planItems;
    final (planW, planH) = _planSize;
    final double scale = _viewZoom;
    ConduitRoute? best;
    double bestD = double.infinity;
    for (final r in _routes) {
      final pts = r
          .points(plan)
          .map(
            (v) => projectToView(
              v,
              _plateId,
              planW: planW,
              planH: planH,
              viewH: _panelHeight,
            ),
          )
          .toList();
      final double tol = math.max(24 / (scale <= 0 ? 1 : scale), r.od / 2 + 5);
      for (int i = 0; i + 1 < pts.length; i++) {
        final double d = _distanceToSegment(p, pts[i], pts[i + 1]);
        if (d <= tol && d < bestD) {
          bestD = d;
          best = r;
        }
      }
    }
    return best;
  }

  /// 스키드 입체 보기(보기 전용). 지금 평면 부품과 전선관 경로를 그대로 세워 보여 준다.
  void _openSkidIso() {
    final (double l, double w) = _planSize;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SkidIsoPage(
          plan: List.of(_planItems),
          routes: List.of(_routes),
          length: l,
          width: w,
        ),
      ),
    );
  }

  List<PlacedItem> get _planItems => _plateId == kPlateMain
      ? _placedItems
      : layoutItemsFromData(_plateStore[kPlateMain] ?? const {});

  (double, double) get _planSize {
    if (_plateId == kPlateMain) return (_panelWidth, _panelHeight);
    final m = _plateStore[kPlateMain];
    return (
      (m?['panelWidth'] as num?)?.toDouble() ?? _panelWidth,
      (m?['panelHeight'] as num?)?.toDouble() ?? _panelHeight,
    );
  }

  Widget _buildSkidOverlay() {
    final plan = _planItems;
    final (planW, planH) = _planSize;
    Offset proj(vm.Vector3 p) => projectToView(
      p,
      _plateId,
      planW: planW,
      planH: planH,
      viewH: _panelHeight,
    );
    final routes = [
      for (final r in _routes)
        (r.name, r.points(plan).map(proj).toList(), r.od),
    ];
    final version = jsonEncode([
      _plateId,
      _panelHeight,
      planW,
      planH,
      _routes.map((r) => r.toJson()).toList(),
      if (_plateId != kPlateMain)
        plan
            .map(
              (e) => [
                e.id,
                e.position.dx,
                e.position.dy,
                e.width,
                e.height,
                e.elevation,
              ],
            )
            .toList()
      else
        _routes.map((r) => r.startItemId).toList(),
      if (_plateId == kPlateMain)
        plan
            .where((e) => _routes.any((r) => r.startItemId == e.id))
            .map((e) => [e.position.dx, e.position.dy, e.elevation])
            .toList(),
    ]);
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: SkidOverlayPainter(
          routes: routes,
          // 평면 부품은 점선 네모 대신 그 면에서 본 모양으로 따로 그린다(_buildViewProxies).
          ghosts: const [],
          version: version,
          markScale: _markScale,
        ),
      ),
    );
  }

  List<({PlacedItem it, Rect rect, SkidFace face, bool mirror, double covered})>
  get _viewProxies {
    if (!_isSkid || _plateId == kPlateMain) return const [];
    final (_, planH) = _planSize;
    // 평면 부품이 그대로면 지난번 셈을 쓴다(한 번 그릴 때 여러 번 부른다).
    final kb = StringBuffer()
      ..write(_plateId)
      ..write('|')
      ..write(_panelHeight)
      ..write('|')
      ..write(planH)
      ..write('|');
    _fingerprintItems(kb, _planItems);
    final String key = kb.toString();
    if (key == _proxyKey) return _proxyCache;
    _proxyKey = key;
    return _proxyCache = [
      for (final p in skidViewLayout(
        _planItems.where((it) => it.shape != InstrumentShape.note).toList(),
        _plateId,
        planH: planH,
        viewH: _panelHeight,
      ))
        (
          it: p.it,
          rect: p.rect,
          face: p.face,
          // 옆모습은 뒤집어 놓은 부품이면 반대로, 우측면은 좌우가 뒤집혀 보인다.
          mirror: p.face == SkidFace.side
              ? (p.it.flipped != (_plateId == 'right'))
              : _plateId == 'right',
          covered: p.covered,
        ),
    ];
  }

  /// 반 넘게 가려진 부품의 테두리를 점선(숨은선)으로 가까운 부품 위에 그린다.
  List<Widget> _buildHiddenOutlines() => [
    if (_showHiddenParts)
      for (final p in _viewProxies)
        if (p.covered >= 0.5)
          Positioned(
            key: ValueKey("hidden_${p.it.id}"),
            left: p.rect.left,
            top: p.rect.top,
            width: p.rect.width,
            height: p.rect.height,
            child: IgnorePointer(
              child: CustomPaint(
                painter: _HiddenOutlinePainter(
                  strokeWidth: 1.2 * _markScale.clamp(1.0, 3.0),
                ),
              ),
            ),
          ),
  ];

  PlacedItem? get _proxyGuideItem {
    final id = _proxyDragId;
    if (id == null) return null;
    for (final p in _viewProxies) {
      if (p.it.id == id) {
        return PlacedItem(
          id: "view_guide",
          name: p.it.name,
          position: p.rect.topLeft,
          width: p.rect.width,
          height: p.rect.height,
        );
      }
    }
    return null;
  }

  /// 평면(안 보이는 탭) 부품 하나를 고쳐 저장 칸에 다시 적는다.
  void _updatePlanItem(String id, void Function(PlacedItem) change) {
    final m = _plateStore[kPlateMain];
    if (m == null) return;
    final items = layoutItemsFromData(m);
    for (final it in items) {
      if (it.id == id) change(it);
    }
    m['items'] = items.map((e) => e.toJson()).toList();
  }

  /// 이 탭에서 [left]·[top](mm)으로 옮긴 부품을 평면 위치와 바닥에서 높이로 바꿔 적는다.
  void _moveProxy(String id, double left, double top, double v) {
    final (_, planH) = _planSize;
    _updatePlanItem(id, (it) {
      switch (_plateId) {
        case kSkidViewFront:
          it.position = Offset(left, it.position.dy);
        case 'left':
          it.position = Offset(it.position.dx, left);
        default:
          it.position = Offset(it.position.dx, planH - left - it.height);
      }
      it.elevation = (_panelHeight - top - v / 2).roundToDouble();
    });
    _dimensionsVersion++; // 이 면 치수가 옮긴 부품을 따라 다시 그려지게
  }

  List<Widget> _buildViewProxies() {
    final (planW, planH) = _planSize;
    final double reach = _plateId == kSkidViewFront
        ? planW
        : planH; // 이 탭 가로 = 평면 길이 또는 폭
    return [
      for (final p in _viewProxies)
        Positioned(
          key: ValueKey("view_${p.it.id}"),
          left: p.rect.left,
          top: p.rect.top,
          width: p.rect.width,
          height: p.rect.height,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            // 고정 치수 측정이면 이 면에서 본 자리로 치수 점을 찍고, 아니면 평면 편집으로 간다.
            onTap: () => _mode == BoardMode.measureDimension
                ? _handleDimensionPoint(_viewPoint(p.it, p.rect))
                : _openPlanItemFromView(p.it.id),
            onPanStart: _mode != BoardMode.placeModule || p.it.isLocked
                ? null
                : (_) {
                    _pushUndo();
                    setState(() {
                      _proxyDragId = p.it.id;
                      _proxyRaw = p.rect.topLeft;
                    });
                  },
            onPanUpdate: _mode != BoardMode.placeModule || p.it.isLocked
                ? null
                : (d) {
                    _proxyRaw += d.delta;
                    final double w = p.rect.width, v = p.rect.height;
                    final double maxL = math.max(
                      0.0,
                      math.min(_panelWidth, reach) - w,
                    );
                    final double maxT = math.max(0.0, _panelHeight - v);
                    final Offset snapped = _snapToGrid(_proxyRaw);
                    setState(
                      () => _moveProxy(
                        p.it.id,
                        snapped.dx.clamp(0.0, maxL),
                        snapped.dy.clamp(0.0, maxT),
                        v,
                      ),
                    );
                  },
            onPanEnd: (_) {
              setState(() => _proxyDragId = null);
              _saveDraftToPrefs();
            },
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: SkidPartPainter(
                      shape: p.it.shape ?? '',
                      face: p.face,
                      mirror: p.mirror,
                      stroke:
                          _proxyDragId == p.it.id ||
                              _dimensionStartPoint?.id == _viewPointId(p.it.id)
                          ? tossBlue
                          : const Color(0xFF64748B),
                      strokeWidth: 1.5 * _markScale.clamp(1.0, 3.0),
                    ),
                  ),
                ),
                // 모양이 없는 네모 모듈은 이름을 적는다.
                if (p.it.shape == null)
                  Center(
                    child: Text(
                      p.it.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: tossText,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
    ];
  }

  /// 그릴 치수 목록(정면·측면이면 평면 부품 자리로 맞춘 뒤).
  List<PlacedDimension> get _syncedDimensions {
    _syncViewDimensions();
    return _dimensions;
  }

  PlacedItem _viewPoint(PlacedItem it, Rect rect) => PlacedItem(
    id: _viewPointId(it.id),
    name: it.name,
    position: rect.topLeft,
    width: rect.width,
    height: rect.height,
  );

  /// 정면·측면 치수 점(view_…)을 지금 평면 부품 자리로 맞춘다. 평면에서 부품을 옮기거나
  /// 높이를 바꿔도 치수가 따라오게 그릴 때마다 부른다(저장은 맞춰진 자리로 된다).
  void _syncViewDimensions() {
    if (!_isSkid || _plateId == kPlateMain || _dimensions.isEmpty) return;
    final rects = {for (final p in _viewProxies) _viewPointId(p.it.id): p.rect};
    _dimensions.removeWhere(
      (d) => [
        d.p1,
        d.p2,
      ].any((pt) => pt.id.startsWith('view_') && !rects.containsKey(pt.id)),
    );
    for (final d in _dimensions) {
      for (final pt in [d.p1, d.p2]) {
        final Rect? r = rects[pt.id];
        if (r != null && pt is PlacedItem) {
          pt
            ..position = r.topLeft
            ..width = r.width
            ..height = r.height;
        }
      }
    }
  }

  /// 정면·측면에서 누른 평면 부품: 평면 탭으로 가서 그 부품을 고르고 편집 칸을 연다.
  void _openPlanItemFromView(String id) {
    setState(() => _switchPlate(kPlateMain));
    PlacedItem? hit;
    setState(() {
      for (final i in _placedItems) {
        i.isSelected = i.id == id;
        if (i.id == id) hit = i;
      }
      _activeItem = hit;
    });
    if (hit != null) _showInspectorBottomSheet(hit!);
  }

  /// 정면·측면에서 놓은 부품은 평면에 놓는다(정면이면 평면 폭 가운데, 측면이면 길이 가운데).
  void _placeFromView(ModulePreset preset, Offset localPosition) {
    final m = _plateStore[kPlateMain];
    if (m == null) return;
    HapticFeedback.mediumImpact();
    final (planW, planH) = _planSize;
    final tmp = PlacedItem(
      id: newLayoutId(),
      name: preset.name,
      position: Offset.zero,
      width: preset.width,
      height: preset.height,
      shape: preset.shape,
      depth: preset.depthOrGuess,
      rotation: 0,
    );
    final double v = skidVerticalSize(tmp);
    final bool front = _plateId == kSkidViewFront;
    final double hw = front ? preset.width : preset.height;
    final Offset at = _snapToGrid(
      Offset(
        localPosition.dx.clamp(0.0, math.max(0.0, _panelWidth - hw)),
        localPosition.dy.clamp(0.0, math.max(0.0, _panelHeight - v)),
      ),
    );
    tmp.position = switch (_plateId) {
      kSkidViewFront => Offset(
        at.dx,
        ((planH - preset.height) / 2).roundToDouble(),
      ),
      'left' => Offset(((planW - preset.width) / 2).roundToDouble(), at.dx),
      _ => Offset(
        ((planW - preset.width) / 2).roundToDouble(),
        planH - at.dx - preset.height,
      ),
    };
    tmp.elevation = (_panelHeight - at.dy - v / 2).roundToDouble();
    _pushUndo();
    setState(() {
      m['items'] = [...((m['items'] as List?) ?? const []), tmp.toJson()];
      _previewItem = null;
    });
    _saveDraftToPrefs();
    showSnackOnce(
      ScaffoldMessenger.of(context),
      SnackBar(
        content: Text(
          keepWords(
            front
                ? "평면에도 같이 놓았습니다(폭 가운데). 앞뒤 자리는 평면이나 측면에서 옮기십시오."
                : "평면에도 같이 놓았습니다(길이 가운데). 좌우 자리는 평면이나 정면에서 옮기십시오.",
          ),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showRoutesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.75,
            ),
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            decoration: BoxDecoration(
              color: pureWhite,
              borderRadius: BorderRadius.circular(8),
            ),
            child: _sheetUndoHost(
              (hostCtx) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "전선관 경로",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: tossText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    keepWords(
                      "전선관은 경로로 그립니다. 시작 부품에서 계산기 입력 탭처럼 한 줄씩 넣고, 구조물은 특수 벤딩의 오프셋으로 비켜 갑니다. 도면에서 경로 선을 눌러도 고칠 수 있습니다. 줄을 왼쪽으로 밀면 삭제됩니다.",
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      color: tossSubText,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 시트 높이가 정해져 있어 목록이 남은 자리를 채우고 "새 경로"는 맨 아래에 둔다.
                  Expanded(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final r in _routes)
                          // 휴지통 단추 대신 왼쪽으로 밀어 지우고 되돌리기를 준다.
                          SwipeToDelete(
                            itemKey: ValueKey('route-${r.id}'),
                            radius: 0,
                            bottomMargin: 0,
                            onDelete: () {
                              final idx = _routes.indexOf(r);
                              if (idx < 0) return;
                              _pushUndo();
                              setState(() => _routes.removeAt(idx));
                              setSheet(() {});
                              _saveDraftToPrefs();
                              showDeleteUndo(
                                hostCtx,
                                r.name,
                                onUndo: () {
                                  if (!mounted || _routes.contains(r)) return;
                                  setState(
                                    () => _routes.insert(
                                      idx.clamp(0, _routes.length),
                                      r,
                                    ),
                                  );
                                  if (ctx.mounted) setSheet(() {});
                                  _saveDraftToPrefs();
                                },
                              );
                            },
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.route_rounded,
                                color: tossBlue,
                              ),
                              title: Text(
                                "${r.name} · 후강 ${r.size}",
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: tossText,
                                ),
                              ),
                              subtitle: Text(
                                "${r.bends.length}줄 · 길이 합 ${r.totalLengthWith(_planItems).toInt()} mm"
                                "${r.endRun(_planItems) == null ? "" : " · 끝: ${r.endRun(_planItems)!.item.name}"}"
                                "${_skidRouteClashes().any((c) => c.route.id == r.id) ? "\n⚠ 형강·부품과 겹칩니다: ${_skidRouteClashes().where((c) => c.route.id == r.id).map((c) => c.item.name).toSet().join(', ')}" : ""}",
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: tossSubText,
                                ),
                              ),
                              onTap: () {
                                Navigator.pop(ctx);
                                _showRouteEditor(r);
                              },
                            ),
                          ),
                        if (_routes.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              "아직 경로가 없습니다.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: tossSubText,
                                fontSize: 15,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    key: const ValueKey("route_new"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tossBlue,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showRouteEditor(null);
                    },
                    icon: const Icon(Icons.add_rounded, color: pureWhite),
                    label: const Text(
                      "새 경로",
                      style: TextStyle(
                        color: pureWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
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

  // 경로 입력 화면(위 작은 도면 + 아래 전선관 계산기 입력 탭)을 연다.
  Future<void> _showRouteEditor(ConduitRoute? original) async {
    final route =
        original ??
        ConduitRoute(id: newLayoutId(), name: "경로 ${_routes.length + 1}");
    final saved = await SkidRouteEditorPage.open(
      context,
      route: route,
      plates: _allPlates(),
      otherRoutes: [
        for (final r in _routes)
          if (r.id != route.id) r,
      ],
      initialView: _plateId,
    );
    if (saved == null || !mounted) return;
    _pushUndo(); // 예전엔 경로 고침이 기록에 없어 되돌리기가 경로를 옛것으로 되돌렸다.
    setState(() {
      final i = _routes.indexWhere((e) => e.id == saved.id);
      if (i >= 0) {
        _routes[i] = saved;
      } else {
        _routes.add(saved);
      }
    });
    _saveDraftToPrefs();
  }
}
