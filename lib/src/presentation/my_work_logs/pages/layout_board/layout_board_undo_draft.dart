// 작업 배치도 화면 — 되돌리기·임시 저장·불러오기.
// layout_board_page.dart의 _LayoutBoardPageState를 역할별로 나눈 part(10-13). 동작은 같다.
// setState는 State 밖(확장)에서 부르면 보호 멤버 경고가 나지만, 이 확장은 그 State 자신이다.
// ignore_for_file: invalid_use_of_protected_member
part of '../layout_board_page.dart';

extension _LayoutBoardUndoDraft on _LayoutBoardPageState {
  // 중판은 예전처럼 맨 위 칸에, 측판은 sidePlates 칸에 적는다.
  Map<String, dynamic> _buildSnapshotJson() {
    final plates = _allPlates();
    final main = plates[kPlateMain]!;
    return {
      'projectId': _currentProjectId,
      'projectName': _projectName,
      if (_drawingNo.isNotEmpty) 'drawingNo': _drawingNo,
      if (_revision.isNotEmpty) 'revision': _revision,
      for (final k in const [
        'panelWidth',
        'panelHeight',
        'items',
        'dimensions',
        'backgroundImagePath',
        // 8차(10-09): 주소가 빠져, 임시 저장에서 이어 한 뒤 저장하면 서버 문서의 배경 주소가 지워졌다
        // (폰에 파일이 없으면 다른 폰은 물론 이 폰에서도 배경이 사라졌다).
        'backgroundImageUrl',
        'backgroundOpacity',
        'backgroundRect',
        'backgroundBrightness',
        'backgroundGray',
      ])
        k: main[k],
      ..._sidePlateFields(plates),
    };
  }

  /// 저장하는 사이 고친 것이 있는지 견줄 때 쓰는 모양. 배경 주소는 저장하면서 올려 받은 것이라
  /// 고침으로 치지 않는다(치면 배경을 처음 올린 저장마다 임시 저장이 남았다).
  String _editFingerprint() {
    final m = _buildSnapshotJson()..remove('backgroundImageUrl');
    final side = m['sidePlates'];
    if (side is Map) {
      m['sidePlates'] = {
        for (final e in side.entries)
          e.key: e.value is Map
              ? (Map<String, dynamic>.from(e.value as Map)
                  ..remove('backgroundImageUrl'))
              : e.value,
      };
    }
    return jsonEncode(m);
  }

  Map<String, dynamic> _captureUndoState() => {
    // 외함 크기·축척 맞추기도 되돌린다(10-07: 부품만 돌아오고 판 크기·배경 자리는 그대로였다).
    'panelW': _panelWidth,
    'panelH': _panelHeight,
    // Rect는 JSON으로 못 바꿔 숫자 목록으로 담는다(10-08: 축척 맞춘 도면에서 ↶가 오류만 내고 듣지 않았다).
    'bgRect': _backgroundRect == null
        ? null
        : drawingRectToJson(_backgroundRect!),
    'items': _placedItems.map((e) => e.toJson()).toList(),
    'dimensions': _dimensions.map((e) => e.toJson()).toList(),
    if (_isSkid) 'routes': _routes.map((r) => r.toJson()).toList(),
    // 정면·측면에서 평면 부품을 옮기거나 놓아도 되돌릴 수 있게 평면 부품도 담는다.
    if (_isSkid && _plateId != kPlateMain)
      'planItems': List.of(
        (_plateStore[kPlateMain]?['items'] as List?) ?? const [],
      ),
  };

  // 실제로 뭔가 바꾸기 "직전"에 호출한다.
  void _pushUndo() {
    _undoStack.add(_captureUndoState());
    if (_undoStack.length > _maxUndoSteps) _undoStack.removeAt(0);
    _redoStack.clear(); // 새 조작을 하면 이전에 되돌렸던 redo 기록은 무효
  }

  void _restoreUndoState(Map<String, dynamic> snap) {
    final pw = snap['panelW'], ph = snap['panelH'];
    if (pw is double && ph is double) {
      _panelWidth = pw;
      _panelHeight = ph;
    }
    if (snap.containsKey('bgRect')) {
      final b = snap['bgRect'];
      _backgroundRect = b is Rect ? b : drawingRectFromJson(b);
    }
    _placedItems
      ..clear()
      ..addAll(
        (snap['items'] as List).map(
          (e) => PlacedItem.fromJson(Map<String, dynamic>.from(e)),
        ),
      );
    _dimensions
      ..clear()
      ..addAll(
        (snap['dimensions'] as List).map(
          (e) => PlacedDimension.fromJson(Map<String, dynamic>.from(e)),
        ),
      );
    final planItems = snap['planItems'];
    if (planItems is List && _plateStore[kPlateMain] != null) {
      _plateStore[kPlateMain]!['items'] = List.of(planItems);
    }
    // 도면 전체를 담은 기록이면 종류·측판 켜짐도 돌리고, 그때 없던 판은 뺀다.
    if (snap['whole'] == true) {
      if (snap['kind'] is String) _kind = snap['kind'] as String;
      if (snap['sidePlatesOn'] is bool) {
        _sidePlatesOn = snap['sidePlatesOn'] as bool;
      }
      if (snap['showHiddenParts'] is bool) {
        _showHiddenParts = snap['showHiddenParts'] as bool;
      }
      final keep =
          (snap['plates'] as Map?)?.keys.map((k) => k.toString()).toSet() ?? {};
      _plateStore.removeWhere((id, _) => id != _plateId && !keep.contains(id));
    }
    // 도면 전체 지우기를 되돌릴 때: 다른 탭 것도 돌려놓는다.
    final plates = snap['plates'];
    if (plates is Map) {
      plates.forEach((id, p) {
        if (p is Map && id != _plateId) {
          _plateStore[id.toString()] = Map<String, dynamic>.from(p);
        }
      });
    }
    final routes = snap['routes'];
    if (routes is List) {
      _routes
        ..clear()
        ..addAll([
          for (final r in routes)
            if (r is Map) ConduitRoute.fromJson(Map<String, dynamic>.from(r)),
        ]);
    }
    relinkDimensions(_dimensions, _placedItems);
    _activeItem = null;
    _previewItem = null;
    _dimensionStartPoint = null;
  }

  void _undo() {
    // 모듈을 누르기만 해도 편집 전 모습을 한 번 남겨 둔다. 아무것도 안 바꿨으면
    // 그 기록은 지금과 똑같아서 되돌리기를 눌러도 아무 일이 없어 보였다. 그런 기록은 건너뛴다.
    final String now = jsonEncode(_captureUndoState());
    while (_undoStack.isNotEmpty && jsonEncode(_undoStack.last) == now) {
      _undoStack.removeLast();
    }
    if (_undoStack.isEmpty) {
      setState(() {});
      return;
    }
    setState(() {
      _redoStack.add(_captureUndoState());
      _restoreUndoState(_undoStack.removeLast());
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    setState(() {
      _undoStack.add(_captureUndoState());
      _restoreUndoState(_redoStack.removeLast());
    });
  }

  // 🚀 [신규] 히스토리 목록에서 특정 단계를 눌렀을 때 - 그 지점까지
  // 한 번에 여러 단계를 되돌린다(_undo()를 stepsBack번 반복하는 것과
  // 동일하되, 화면 리렌더는 한 번만 일어나게 묶었다).
  void _jumpToHistoryEntry(int stepsBack) {
    if (stepsBack < 1 || stepsBack > _undoStack.length) return;
    setState(() {
      for (int i = 0; i < stepsBack; i++) {
        _redoStack.add(_captureUndoState());
        _restoreUndoState(_undoStack.removeLast());
      }
    });
  }

  void _showUndoHistorySheet() {
    if (_undoStack.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.6,
            ),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: pureWhite,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Text(
                    keepWords("되돌리기 기록 (${_undoStack.length}단계)"),
                    style: const TextStyle(
                      color: tossText,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _undoStack.length,
                    itemBuilder: (context, i) {
                      // 최근 단계가 위로 오도록 뒤에서부터 보여준다.
                      final int stepsBack = i + 1;
                      return layoutSheetRow(
                        icon: Icons.history_rounded,
                        label: "$stepsBack단계 전으로 되돌리기",
                        onTap: () {
                          Navigator.pop(ctx);
                          _jumpToHistoryEntry(stepsBack);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveDraftToPrefs() async {
    if (!_hasAnyContent) return;
    _dropOrphanViewDims();
    try {
      final prefs = await SharedPreferences.getInstance();
      // 저장해 둔 도면은 도면마다 따로 둔다(10-07: 한 칸뿐이라, 저장한 도면을 열기만 하고 나가도
      // 저장 안 한 새 도면 임시 저장을 덮었고, 저장한 뒤에도 "저장하지 않고 나간 작업"이 거짓으로 떴다).
      // "이어하기"는 새 도면 칸(_draftPrefsKey)만 묻는다.
      final id = _currentProjectId;
      await prefs.setString(
        id == null ? _draftPrefsKey : '${_draftPrefsKey}_$id',
        jsonEncode(_buildSnapshotJson()),
      );
    } catch (_) {
      // 로컬 임시 저장은 실패해도 사용자 작업 흐름을 막을 필요는 없다.
    }
  }

  Future<void> _clearDraftPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftPrefsKey);
      await prefs.remove(_legacyTabletDraftPrefsKey);
      final id = _currentProjectId;
      if (id != null) await prefs.remove('${_draftPrefsKey}_$id');
    } catch (_) {}
  }

  void _applySnapshotJson(Map<String, dynamic> data) {
    _currentProjectId = data['projectId'] as String?;
    _projectName = data['projectName'] as String? ?? "";
    _drawingNo = data['drawingNo'] as String? ?? "";
    _revision = data['revision'] as String? ?? "";
    _applySidePlateFields(data);
    _panelWidth = (data['panelWidth'] as num?)?.toDouble() ?? _panelWidth;
    _panelHeight = (data['panelHeight'] as num?)?.toDouble() ?? _panelHeight;
    _placedItems
      ..clear()
      ..addAll(layoutItemsFromData(data));
    _dimensions
      ..clear()
      ..addAll(layoutDimensionsFromData(data));
    _backgroundImagePath = data['backgroundImagePath'] as String?;
    _backgroundImageUrl = data['backgroundImageUrl'] as String?;
    _backgroundOpacity = (data['backgroundOpacity'] as num?)?.toDouble() ?? 0.5;
    _backgroundRect = drawingRectFromJson(data['backgroundRect']);
    _backgroundBrightness =
        (data['backgroundBrightness'] as num?)?.toDouble() ?? 1.0;
    _backgroundGray = data['backgroundGray'] == true;
    relinkDimensions(_dimensions, _placedItems);
    _restoreMissingBackgrounds();
  }

  /// 다른 폰에서 올린 배경 사진(주소만 있고 폰에 파일이 없음)을 받아 깐다.
  Future<void> _restoreMissingBackgrounds() async {
    Future<String?> fetch(String? path, String? url) async {
      if (url == null || url.isEmpty) return null;
      if (path != null && await File(path).exists()) return null;
      return downloadLayoutBackground(url);
    }

    // 받은 사진은 받기 시작할 때의 판에 넣는다. 받는 사이 탭을 바꿨으면 그 판은 지금 칸이 아니라
    // 보관 칸에 있다(10-08: 중판 배경이 지금 보는 측판에 깔려 다음 저장 때 측판 배경으로 올라갔다).
    void put(String plateId, String path) {
      if (!mounted) return;
      setState(() {
        if (plateId == _plateId) {
          _backgroundImagePath = path;
        } else {
          _plateStore[plateId]?['backgroundImagePath'] = path;
        }
      });
    }

    final first = _plateId;
    final p = await fetch(_backgroundImagePath, _backgroundImageUrl);
    if (p != null) put(first, p);
    // 복사본을 돈다(10-07: 받는 사이 탭을 바꾸면 목록이 바뀌어 오류가 났다).
    for (final e in _plateStore.entries.toList()) {
      final q = await fetch(
        e.value['backgroundImagePath'] as String?,
        e.value['backgroundImageUrl'] as String?,
      );
      if (q != null) put(e.key, q);
    }
  }

  // 🚀 [추가] 새 도면으로 들어왔을 때(특정 프로젝트를 불러온 게 아닐 때)
  // 이전에 저장 안 하고 나간 임시 작업이 남아있으면 이어할지 물어본다.
  Future<bool> _checkAndOfferDraftRecovery() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw =
          prefs.getString(_draftPrefsKey) ??
          prefs.getString(_legacyTabletDraftPrefsKey);
      if (raw == null) return false;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (!mounted) return false;
      final bool resume =
          widget.resumeDraft ??
          await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              backgroundColor: pureWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                "이어서 작업하시겠습니까?",
                style: TextStyle(fontWeight: FontWeight.w800, color: tossText),
              ),
              content: Text(
                keepWords("저장하지 않고 나간 작업 내용이 있습니다."),
                style: TextStyle(color: tossSubText),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(
                    "새로 시작",
                    style: TextStyle(color: tossSubText),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    "이어하기",
                    style: TextStyle(
                      color: tossBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ) ??
          false;

      if (!mounted) return false;
      if (resume) {
        setState(() => _applySnapshotJson(data));
      } else {
        await _clearDraftPrefs();
      }
      return resume;
    } catch (_) {
      // 임시 저장 데이터가 깨져있으면 그냥 무시하고 새로 시작한다.
      return false;
    }
  }

  /// 저장해 둔 도면을 고치다 앱이 꺼졌으면(도면별 임시 저장이 서버 판과 다르면) 이어할지 묻는다
  /// (10-08: 도면별 임시 저장을 적기만 하고 읽지 않아, 다시 열면 서버 판으로만 열려 고친 것이 사라졌다).
  /// 이어하면 임시 저장 내용을 펴고(서버 판 기준은 그대로라 저장 때 바뀐 것으로 잡힌다), 아니면 지운다.
  Future<void> _offerProjectDraft(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_draftPrefsKey}_$id';
      final raw = prefs.getString(key);
      if (raw == null || !mounted) return;
      final draft = jsonDecode(raw) as Map<String, dynamic>;
      Map<String, dynamic> norm(Map<String, dynamic> m) =>
          Map<String, dynamic>.from(m)..remove('projectId');
      if (jsonEncode(norm(draft)) == jsonEncode(norm(_buildSnapshotJson()))) {
        await prefs.remove(key);
        return;
      }
      final resume =
          widget.resumeDraft ??
          await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('저장하지 않은 고침이 있습니다'),
              content: Text(
                keepWords('이 도면을 고치다 저장하지 않고 나간 내용이 있습니다. 이어서 하시겠습니까?'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('저장된 도면으로'),
                ),
                TextButton(
                  key: const Key('layout_project_draft_resume'),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('이어하기'),
                ),
              ],
            ),
          ) ??
          false;
      if (!mounted) return;
      if (resume) {
        draft['projectId'] = id;
        setState(() => _applySnapshotJson(draft));
      } else {
        await prefs.remove(key);
      }
    } catch (_) {
      // 임시 저장이 깨져 있으면 서버 판 그대로 둔다.
    }
  }

  Future<void> _loadProject(String id) async {
    setState(() => _isLoadingProject = true);
    try {
      // 통신이 약하면 끝없이 기다렸다(10-08). 8초 뒤 폰 사본으로.
      final ref = FirebaseFirestore.instance.collection('layouts').doc(id);
      final doc = await readDocQuick(ref, wait: const Duration(seconds: 8));
      if (!mounted) return;
      if (!doc.exists) {
        showSnackOnce(
          ScaffoldMessenger.of(context),
          SnackBar(
            content: Text(keepWords("배치도를 찾을 수 없습니다.")),
            backgroundColor: warningRed,
          ),
        );
        return;
      }
      final data = doc.data()!;
      data['projectId'] = doc.id;
      setState(() {
        _applySnapshotJson(data);
        _captureSavedBaseline(data);
      });
      _lastSaveToken = data['saveToken'] as String?;
      await _offerProjectDraft(id);
    } catch (e) {
      if (!mounted) return;
      showSnackOnce(
        ScaffoldMessenger.of(context),
        SnackBar(
          content: Text(keepWords(failText("불러오기 실패", e))),
          backgroundColor: warningRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoadingProject = false);
    }
  }

  /// 도면 전체(다른 판·경로·도면 종류·측판 켜짐)를 되돌리기에 쌓는다. 되돌리면 다른 판도 이때로 바뀐다.
  void _pushWholeUndo() {
    _undoStack.add({
      ..._captureUndoState(),
      'routes': _routes.map((r) => r.toJson()).toList(),
      'plates': {
        for (final e in _plateStore.entries)
          if (e.key != _plateId) e.key: Map<String, dynamic>.from(e.value),
      },
      'whole': true,
      'kind': _kind,
      'sidePlatesOn': _sidePlatesOn,
      'showHiddenParts': _showHiddenParts,
    });
    if (_undoStack.length > _maxUndoSteps) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  // 모든 탭(판)·경로·치수선을 지운다. 되돌리기 기록에 다른 탭 것도 같이 담아 두어
  // 이 탭에서 되돌리기를 누르면 도면 전체가 돌아온다(예전엔 지금 탭만 지웠다).
  void _clearBoard() {
    _undoStack.add({
      ..._captureUndoState(),
      'routes': _routes.map((r) => r.toJson()).toList(),
      'plates': {
        for (final e in _plateStore.entries)
          if (e.key != _plateId) e.key: Map<String, dynamic>.from(e.value),
      },
    });
    if (_undoStack.length > _maxUndoSteps) _undoStack.removeAt(0);
    _redoStack.clear();
    setState(() {
      _placedItems.clear();
      _dimensions.clear();
      _routes.clear();
      for (final e in _plateStore.entries) {
        if (e.key == _plateId) continue;
        e.value['items'] = <Map<String, dynamic>>[];
        e.value['dimensions'] = <Map<String, dynamic>>[];
      }
      _plateUndo.clear();
      _dimensionStartPoint = null;
      _activeItem = null;
      _previewItem = null;
    });
  }

  Future<void> _confirmClearBoard() async {
    final (items, dims) = _countAllPlates();
    final routeNote = _routes.isEmpty ? "" : "경로 ${_routes.length}개와 ";
    final ok = await confirmLayoutDanger(
      context,
      title: "도면 전체 지우기",
      message:
          "모든 탭의 $routeNote부품 $items개, 치수선 $dims개를 지웁니다. 지운 뒤에도 되돌리기로 돌아올 수 있습니다.",
      confirmLabel: "전체 지우기",
    );
    if (ok && mounted) _clearBoard();
  }
}
