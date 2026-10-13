// 작업 배치도 화면 — 판·측판·간섭 확인·저장본과 차이.
// layout_board_page.dart의 _LayoutBoardPageState를 역할별로 나눈 part(10-13). 동작은 같다.
// setState는 State 밖(확장)에서 부르면 보호 멤버 경고가 나지만, 이 확장은 그 State 자신이다.
// ignore_for_file: invalid_use_of_protected_member
part of '../layout_board_page.dart';

extension _LayoutBoardPlates on _LayoutBoardPageState {
  bool _plateHasContent(String id) {
    final p = _plateStore[id];
    if (p == null) return false;
    return ((p['items'] as List?)?.isNotEmpty ?? false) ||
        ((p['dimensions'] as List?)?.isNotEmpty ?? false);
  }

  bool get _hasAnyContent =>
      _routes.isNotEmpty ||
      _placedItems.isNotEmpty ||
      _dimensions.isNotEmpty ||
      _plateStore.values.any(
        (p) =>
            ((p['items'] as List?)?.isNotEmpty ?? false) ||
            ((p['dimensions'] as List?)?.isNotEmpty ?? false),
      );

  // 🚀 [신규] 완전히 빈 도면을 처음 여는 사람이 기능을 눌러보며 익힐 수
  // 있도록, 간단한 예시 배치를 한 번에 불러오는 버튼용 데이터.
  void _loadSampleLayout() {
    _pushUndo();
    setState(() {
      _placedItems.clear();
      _dimensions.clear();
      final PlacedItem a = PlacedItem(
        id: 'sample_a',
        name: '차단기 A',
        position: const Offset(40, 40),
        width: 80,
        height: 80,
      );
      final PlacedItem b = PlacedItem(
        id: 'sample_b',
        name: '차단기 B',
        position: const Offset(180, 40),
        width: 80,
        height: 80,
      );
      final PlacedItem duct = PlacedItem(
        id: 'sample_duct',
        name: 'ABS덕트 60mm',
        position: const Offset(40, 160),
        width: 60,
        height: 200,
      );
      _placedItems.addAll([a, b, duct]);
      _dimensions.add(
        PlacedDimension(
          id: 'sample_dim_1',
          p1: a,
          p2: b,
          type: DimensionType.edge,
          note: '이격거리 예시',
        ),
      );
    });
    HapticFeedback.mediumImpact();
  }

  bool get _isSkid => _kind == kLayoutKindSkid;

  void _fitBoardToView() {
    final Size? v = _viewportSize;
    if (v == null || _panelWidth <= 0 || _panelHeight <= 0) return;
    final double vh = v.height;
    // 둘레에 W·H 표기(화면 12px 글씨) 자리를 남기고 맞춘다.
    const double pad = 28;
    final double k = math.min(
      (v.width - pad * 2) / _panelWidth,
      (vh - pad * 2) / _panelHeight,
    );
    final double dx = (v.width - _panelWidth * k) / 2;
    final double dy = (vh - _panelHeight * k) / 2;
    _viewerController.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      // 깊이축도 k로 둔다. 1로 두면 확대 기능이 지금 배율을 1로 읽어 맞춘 크기의 4배까지만 키워 줬다.
      ..scaleByDouble(k, k, k, 1);
  }

  void _startNewSkid() {
    _fitPending = true;
    _kind = kLayoutKindSkid;
    _sidePlatesOn = false;
    _panelWidth = kSkidDefaultLength;
    _panelHeight = kSkidDefaultWidth;
  }

  /// 저장 문서 모양(items + sidePlates)에서 기준 자리를 담아 둔다.
  void _captureSavedBaseline(Map<String, dynamic> data) {
    Map<String, Rect> rects(Map<String, dynamic> p) => {
      for (final it in layoutItemsFromData(p)) it.id: it.boundingBox,
    };
    Map<String, String> names(Map<String, dynamic> p) => {
      for (final it in layoutItemsFromData(p)) it.id: it.name,
    };
    _savedRects = {kPlateMain: rects(data)};
    _savedNames = {kPlateMain: names(data)};
    final side = data['sidePlates'];
    if (side is Map) {
      side.forEach((id, p) {
        if (p is Map) {
          final m = Map<String, dynamic>.from(p);
          _savedRects[id.toString()] = rects(m);
          _savedNames[id.toString()] = names(m);
        }
      });
    }
  }

  /// 지금 판에서 저장본과 다른 것: 옮긴 부품(옛 자리→새 자리), 새 부품, 지운 부품(옛 자리·이름).
  ({List<(Rect, Rect)> moved, List<Rect> added, List<(Rect, String)> removed})
  _savedDiff() {
    final old = _savedRects[_plateId] ?? const {};
    final oldNames = _savedNames[_plateId] ?? const {};
    final moved = <(Rect, Rect)>[];
    final added = <Rect>[];
    final removed = <(Rect, String)>[];
    final seen = <String>{};
    for (final it in _placedItems) {
      if (it.shape == InstrumentShape.note) continue;
      seen.add(it.id);
      final Rect? o = old[it.id];
      if (o == null) {
        added.add(it.boundingBox);
      } else if (o != it.boundingBox) {
        moved.add((o, it.boundingBox));
      }
    }
    old.forEach((id, r) {
      if (!seen.contains(id)) removed.add((r, oldNames[id] ?? ""));
    });
    return (moved: moved, added: added, removed: removed);
  }

  /// 간섭 확인 열쇠: 모든 판의 부품 + 깊이·측판 설정.
  String _clashFingerprint() {
    final b = StringBuffer()
      ..write(_plateId)
      ..write('|')
      ..write(_sidePlatesOn)
      ..write('|')
      ..write(_cabinetDepth)
      ..write('|')
      ..write(_panelWidth)
      ..write(',')
      ..write(_panelHeight)
      ..write('|');
    _fingerprintItems(b, _placedItems);
    for (final e in _plateStore.entries) {
      b
        ..write('#')
        ..write(e.key)
        ..write(e.value['panelWidth'])
        ..write(',')
        ..write(e.value['panelHeight'])
        ..write(',')
        ..write(e.value['bottomOffset'])
        ..write(',')
        ..write(e.value['gap'])
        ..write('|');
      _fingerprintItems(b, (e.value['items'] as List?) ?? const []);
    }
    return b.toString();
  }

  List<({ConduitRoute route, PlacedItem item})> _skidRouteClashes() {
    if (!_isSkid || _routes.isEmpty) return const [];
    final plan = _planItems
        .where((it) => it.shape != InstrumentShape.note)
        .toList();
    final kb = StringBuffer();
    _fingerprintItems(kb, plan);
    for (final r in _routes) {
      kb.write(jsonEncode(r.toJson()));
    }
    final String key = kb.toString();
    if (key == _routeClashKey) return _routeClashCache;
    _routeClashKey = key;
    final out = <({ConduitRoute route, PlacedItem item})>[];
    for (final r in _routes) {
      final pts = r.points(plan);
      final double h = r.od / 2;
      final seen = <String>{};
      for (var i = 0; i + 1 < pts.length; i++) {
        final a = pts[i], b = pts[i + 1];
        final double x0 = math.min(a.x, b.x) - h, x1 = math.max(a.x, b.x) + h;
        final double y0 = math.min(a.y, b.y) - h, y1 = math.max(a.y, b.y) + h;
        final double z0 = math.min(a.z, b.z) - h, z1 = math.max(a.z, b.z) + h;
        for (final it in plan) {
          if (it.id == r.startItemId || it.id == r.endItemId) continue;
          if (it.elevation == null || seen.contains(it.id)) continue;
          final double v = skidVerticalSize(it);
          final double ix0 = it.position.dx, ix1 = ix0 + it.width;
          final double iy0 = it.position.dy, iy1 = iy0 + it.height;
          final double iz0 = it.elevation! - v / 2, iz1 = it.elevation! + v / 2;
          if (x0 < ix1 &&
              x1 > ix0 &&
              y0 < iy1 &&
              y1 > iy0 &&
              z0 < iz1 &&
              z1 > iz0) {
            seen.add(it.id);
            out.add((route: r, item: it));
          }
        }
      }
    }
    return _routeClashCache = out;
  }

  Set<String> _skidRouteClashProblemIds() => {
    for (final c in _skidRouteClashes()) c.item.id,
  };

  ClashReport _clashReportCached() {
    final key = _clashFingerprint();
    if (_clashCache == null || key != _clashKey) {
      _clashKey = key;
      _clashCache = _clashReport();
    }
    return _clashCache!;
  }

  Map<String, dynamic> _captureActivePlate() => {
    ...?_plateStore[_plateId],
    'panelWidth': _panelWidth,
    'panelHeight': _panelHeight,
    'items': _placedItems.map((e) => e.toJson()).toList(),
    'dimensions': _dimensions.map((e) => e.toJson()).toList(),
    'backgroundImagePath': _backgroundImagePath,
    'backgroundImageUrl': _backgroundImageUrl,
    'backgroundOpacity': _backgroundOpacity,
    'backgroundRect': _backgroundRect == null
        ? null
        : drawingRectToJson(_backgroundRect!),
    if (_backgroundBrightness != 1.0)
      'backgroundBrightness': _backgroundBrightness,
    if (_backgroundGray) 'backgroundGray': true,
  };

  Map<String, Map<String, dynamic>> _allPlates() => {
    ..._plateStore,
    _plateId: _captureActivePlate(),
  };

  /// 평면 부품을 지우면 정면·측면에서 그 부품을 기준으로 잰 치수(view_…)가 허공에 남는다.
  /// 저장·탭 바꾸기 전에 그런 치수를 걷어 낸다.
  void _dropOrphanViewDims() {
    if (!_isSkid) return;
    final plan = _plateId == kPlateMain
        ? _placedItems
        : layoutItemsFromData(_plateStore[kPlateMain] ?? const {});
    final planIds = {for (final it in plan) it.id};
    bool orphan(Map d) {
      for (final k in const ['p1', 'p2']) {
        final id = (d[k] as Map?)?['id']?.toString() ?? '';
        if (id.startsWith('view_') && !planIds.contains(id.substring(5))) {
          return true;
        }
      }
      return false;
    }

    for (final e in _plateStore.entries) {
      if (e.key == kPlateMain) continue;
      final dims = e.value['dimensions'];
      if (dims is List && dims.any((d) => d is Map && orphan(d))) {
        e.value['dimensions'] = [
          for (final d in dims)
            if (!(d is Map && orphan(d))) d,
        ];
      }
    }
    if (_plateId != kPlateMain) {
      _dimensions.removeWhere((d) => orphan(d.toJson()));
    }
  }

  // 새 판(탭) 기본 크기. 캐비닛 측판 = 가로 300 × 중판 세로.
  // 스키드 정면 = 스키드 길이 × 높이, 좌·우측면 = 스키드 폭 × 높이.
  Map<String, dynamic> _newSidePlate([String? id]) {
    final main = _allPlates()[kPlateMain];
    final double mainW =
        (main?['panelWidth'] as num?)?.toDouble() ?? _panelWidth;
    final double mainH =
        (main?['panelHeight'] as num?)?.toDouble() ?? _panelHeight;
    final double w = !_isSkid ? 300.0 : (id == kSkidViewFront ? mainW : mainH);
    return {
      'panelWidth': w,
      'panelHeight': _isSkid ? kSkidDefaultHeight : mainH,
      'items': <dynamic>[],
      'dimensions': <dynamic>[],
      'backgroundOpacity': 0.5,
    };
  }

  /// 탭 순서와 이름(캐비닛: 좌측판·중판·우측판, 스키드: 평면·정면·좌측면·우측면).
  List<String> get _tabOrder => _isSkid ? kSkidViewOrder : kPlateOrder;

  String _tabLabel(String id) => _isSkid ? skidViewLabel(id) : plateLabel(id);

  bool get _showTabs => _isSkid || _sidePlatesOn;

  void _loadPlateFields(Map<String, dynamic> d) {
    _panelWidth = (d['panelWidth'] as num?)?.toDouble() ?? _panelWidth;
    _panelHeight = (d['panelHeight'] as num?)?.toDouble() ?? _panelHeight;
    _placedItems
      ..clear()
      ..addAll(layoutItemsFromData(d));
    _dimensions
      ..clear()
      ..addAll(layoutDimensionsFromData(d));
    _backgroundImagePath = d['backgroundImagePath'] as String?;
    _backgroundImageUrl = d['backgroundImageUrl'] as String?;
    _backgroundOpacity = (d['backgroundOpacity'] as num?)?.toDouble() ?? 0.5;
    _backgroundRect = drawingRectFromJson(d['backgroundRect']);
    _backgroundBrightness =
        (d['backgroundBrightness'] as num?)?.toDouble() ?? 1.0;
    _backgroundGray = d['backgroundGray'] == true;
    relinkDimensions(_dimensions, _placedItems);
  }

  /// 보이는 판을 [id]로 바꾼다(setState 안에서 부른다). 되돌리기 기록도 판마다 따로.
  void _switchPlate(String id) {
    if (id == _plateId) return;
    _dropOrphanViewDims();
    _plateStore[_plateId] = _captureActivePlate();
    // 스키드의 경로·평면 부품은 판끼리 같이 쓴다. 다른 탭으로 넘어가면 이 판 기록에서 그 몫을 뺀다
    // (10-08: 돌아와 ↶를 누르면 다른 탭에서 놓은 JB·고친 경로까지 지웠다). 이 판 부품만 되돌린다.
    List<Map<String, dynamic>> plateOnly(List<Map<String, dynamic>> l) => [
      for (final s in l)
        if (s['whole'] == true)
          s
        else
          (Map<String, dynamic>.from(s)
            ..remove('routes')
            ..remove('planItems')),
    ];
    _plateUndo[_plateId] = _isSkid
        ? [plateOnly(_undoStack), plateOnly(_redoStack)]
        : [List.of(_undoStack), List.of(_redoStack)];
    final target = _plateStore.remove(id) ?? _newSidePlate(id);
    // 스키드 정면·측면 판 폭은 늘 평면 크기에서(스키드 크기를 바꿔도 따라오게).
    if (_isSkid && id != kPlateMain) {
      final main = _plateStore[kPlateMain];
      final mainW = (main?['panelWidth'] as num?)?.toDouble() ?? _panelWidth;
      final mainH = (main?['panelHeight'] as num?)?.toDouble() ?? _panelHeight;
      target['panelWidth'] = id == kSkidViewFront ? mainW : mainH;
    }
    _plateId = id;
    _plateStore[id] = {
      for (final k in const ['bottomOffset', 'gap'])
        if (target[k] != null) k: target[k],
    };
    _loadPlateFields(target);
    final st = _plateUndo[id];
    _undoStack
      ..clear()
      ..addAll(st?[0] ?? const []);
    _redoStack
      ..clear()
      ..addAll(st?[1] ?? const []);
    _activeItem = null;
    _previewItem = null;
    _dimensionStartPoint = null;
    _viewerController.value = Matrix4.identity();
    if (_isSkid) _fitPending = true;
  }

  /// 저장할 때 붙이는 측판 칸(예전 앱은 이 칸을 모르고 중판만 읽는다).
  Map<String, dynamic> _sidePlateFields(
    Map<String, Map<String, dynamic>> plates,
  ) => {
    'kind': _kind,
    'routes': _routes.map((r) => r.toJson()).toList(),
    'sidePlatesOn': _sidePlatesOn,
    if (!_showHiddenParts) 'showHiddenParts': false,
    if (_cabinetDepth != null) 'cabinetDepth': _cabinetDepth,
    'sidePlates': {
      for (final e in plates.entries)
        if (e.key != kPlateMain) e.key: e.value,
    },
  };

  /// 저장된 문서의 측판 칸을 읽는다(중판은 늘 쓰던 칸에서 따로 읽는다).
  void _applySidePlateFields(Map<String, dynamic> data) {
    _showHiddenParts = data['showHiddenParts'] != false;
    _plateStore.clear();
    _plateUndo.clear();
    _plateId = kPlateMain;
    final side = data['sidePlates'];
    if (side is Map) {
      side.forEach((id, p) {
        if (p is Map && id != kPlateMain) {
          _plateStore[id.toString()] = Map<String, dynamic>.from(p);
        }
      });
    }
    _routes
      ..clear()
      ..addAll([
        for (final r in (data['routes'] as List?) ?? const [])
          if (r is Map) ConduitRoute.fromJson(Map<String, dynamic>.from(r)),
      ]);
    _sidePlatesOn = data['sidePlatesOn'] == true;
    _kind = data['kind'] == kLayoutKindSkid
        ? kLayoutKindSkid
        : kLayoutKindCabinet;
    if (_kind == kLayoutKindSkid) _fitPending = true;
    _cabinetDepth = (data['cabinetDepth'] as num?)?.toDouble();
  }

  ClashReport _clashReport() {
    final plates = _allPlates();
    // 메모 글자는 물건이 아니라 간섭에서 뺀다.
    Map<String, dynamic> noNotes(Map<String, dynamic> p) => {
      ...p,
      'items': [
        for (final it in (p['items'] as List? ?? const []))
          if (it is Map && it['shape'] != InstrumentShape.note) it,
      ],
    };
    PlateData? side(String id) => _sidePlatesOn && plates[id] != null
        ? PlateData.fromJson(noNotes(plates[id]!))
        : null;
    return checkCabinetClashes(
      main: PlateData.fromJson(noNotes(plates[kPlateMain]!)),
      left: side(kPlateLeft),
      right: side(kPlateRight),
      cabinetDepth: _cabinetDepth,
    );
  }

  void _toggleSidePlates() {
    setState(() {
      if (_sidePlatesOn && _plateId != kPlateMain) _switchPlate(kPlateMain);
      _sidePlatesOn = !_sidePlatesOn;
    });
    _saveDraftToPrefs();
  }

  Widget _buildPlateTabs() {
    return Container(
      color: pureWhite,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        children: [
          for (final id in _tabOrder) ...[
            Expanded(
              child: ChoiceChip(
                key: ValueKey("plate_tab_$id"),
                label: SizedBox(
                  width: double.infinity,
                  child: Text(
                    _tabLabel(id),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                  ),
                ),
                // 탭이 넷(스키드)이면 좁아서 안쪽 여백을 줄인다.
                labelPadding: EdgeInsets.zero,
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                selected: id == _plateId,
                showCheckmark: false,
                labelStyle: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: id == _plateId ? pureWhite : tossText,
                ),
                selectedColor: tossBlue,
                backgroundColor: pureWhite,
                side: BorderSide(color: id == _plateId ? tossBlue : layoutLine),
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  setState(() => _switchPlate(id));
                },
              ),
            ),
            if (id != _tabOrder.last) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  void _showCabinetSettingsSheet() {
    String num0(double? v) => v == null
        ? ""
        : (v == v.roundToDouble() ? v.toInt().toString() : v.toString());
    final plates = _allPlates();
    double? field(String id, String k) => (plates[id]?[k] as num?)?.toDouble();
    final depthCtrl = TextEditingController(text: num0(_cabinetDepth));
    final ctrls = {
      for (final id in const [kPlateLeft, kPlateRight])
        for (final k in const ['bottomOffset', 'gap'])
          '$id.$k': TextEditingController(text: num0(field(id, k) ?? 0)),
    };
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          top: 16,
          left: 24,
          right: 24,
        ),
        decoration: const BoxDecoration(
          color: pureWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildBottomSheetHandle(),
              const Text(
                "측판·깊이 설정",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: tossText,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                keepWords(
                  "측판 크기는 측판 탭의 '외함 크기 설정'에서 따로 바꿉니다. 간섭은 좌측판 오른쪽 끝·우측판 왼쪽 끝을 중판 쪽으로 보고 계산합니다.",
                ),
                style: const TextStyle(
                  fontSize: 14,
                  color: tossSubText,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              _buildCoordinateInput(
                "캐비닛 깊이 (중판 면~문 안쪽, mm, 비우면 확인 안 함)",
                depthCtrl.text,
                (_) {},
                controller: depthCtrl,
              ),
              for (final id in const [kPlateLeft, kPlateRight]) ...[
                const SizedBox(height: 16),
                _panelLabel(plateLabel(id)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildCoordinateInput(
                        "바닥 높이 차 (mm)",
                        ctrls['$id.bottomOffset']!.text,
                        (_) {},
                        controller: ctrls['$id.bottomOffset'],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildCoordinateInput(
                        "중판~벽 틈 (mm)",
                        ctrls['$id.gap']!.text,
                        (_) {},
                        controller: ctrls['$id.gap'],
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: tossBlue,
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    final d = parseNumberText(depthCtrl.text);
                    _cabinetDepth = d == null || d <= 0 ? null : d;
                    for (final id in const [kPlateLeft, kPlateRight]) {
                      final base = id == _plateId
                          ? (_plateStore[id] ?? {})
                          : (_plateStore[id] ?? _newSidePlate());
                      _plateStore[id] = {
                        ...base,
                        for (final k in const ['bottomOffset', 'gap'])
                          k: parseNumberText(ctrls['$id.$k']!.text) ?? 0,
                      };
                    }
                  });
                  _saveDraftToPrefs();
                },
                child: const Text(
                  "적용",
                  style: TextStyle(
                    color: pureWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showClashSheet() {
    final r = _clashReport();
    String dText(double? d) => d == null ? "-" : d.toInt().toString();
    final lines = <String>[
      for (final c in r.clashes)
        "${plateLabel(c.plateA)} · ${c.a.name}  ↔  ${plateLabel(c.plateB)} · ${c.b.name}",
      for (final it in r.tooDeep)
        "중판 · ${it.name}: 깊이 ${dText(it.depth)}mm가 캐비닛 깊이 ${dText(_cabinetDepth)}mm보다 깊습니다",
    ];
    final missing = r.noDepth.entries.where((e) => e.value > 0).toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
          ),
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          decoration: BoxDecoration(
            color: pureWhite,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lines.isEmpty ? "간섭 없음" : "간섭 ${lines.length}건",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: lines.isEmpty ? tossText : warningRed,
                ),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final l in lines)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          keepWords(l),
                          style: const TextStyle(
                            fontSize: 15,
                            color: tossText,
                            height: 1.35,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (missing.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  keepWords(
                    "깊이를 넣지 않은 부품은 빼고 확인했습니다: ${missing.map((e) => "${plateLabel(e.key)} ${e.value}개").join(", ")}. 부품을 눌러 깊이를 넣으십시오.",
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    color: tossSubText,
                    height: 1.4,
                  ),
                ),
              ],
              if (!_sidePlatesOn && _cabinetDepth == null) ...[
                const SizedBox(height: 8),
                Text(
                  keepWords("측판을 켜거나 캐비닛 깊이를 넣어야 간섭을 확인할 수 있습니다."),
                  style: const TextStyle(fontSize: 14, color: tossSubText),
                ),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    "닫기",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: tossBlue,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 전체 지우기 확인 글에 쓰는, 모든 탭을 합친 개수.
  (int items, int dims) _countAllPlates() {
    var items = _placedItems.length;
    var dims = _dimensions.length;
    for (final e in _plateStore.entries) {
      if (e.key == _plateId) continue;
      items += (e.value['items'] as List?)?.length ?? 0;
      dims += (e.value['dimensions'] as List?)?.length ?? 0;
    }
    return (items, dims);
  }
}
