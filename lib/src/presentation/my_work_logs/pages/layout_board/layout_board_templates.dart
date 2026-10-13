// 작업 배치도 화면 — 템플릿·다른 도면에서 가져오기·내 프리셋.
// layout_board_page.dart의 _LayoutBoardPageState를 역할별로 나눈 part(10-13). 동작은 같다.
// setState는 State 밖(확장)에서 부르면 보호 멤버 경고가 나지만, 이 확장은 그 State 자신이다.
// ignore_for_file: invalid_use_of_protected_member
part of '../layout_board_page.dart';

extension _LayoutBoardTemplates on _LayoutBoardPageState {
  Future<void> _loadCustomPresets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_customPresetsPrefsKey);
      if (raw == null) return;
      final List<dynamic> list = jsonDecode(raw);
      if (!mounted) return;
      setState(() {
        _customPresets = list
            .map(
              (e) => ModulePreset(
                e['name'] as String,
                (e['width'] as num).toDouble(),
                (e['height'] as num).toDouble(),
                // 모양·깊이도 같이(예전 프리셋에는 없어서 네모로 놓였다).
                shape: e['shape'] as String?,
                depth: (e['depth'] as num?)?.toDouble(),
              ),
            )
            .toList();
      });
    } catch (_) {}
  }

  Future<void> _saveCustomPresets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _customPresetsPrefsKey,
        jsonEncode(
          _customPresets
              .map(
                (p) => {
                  'name': p.name,
                  'width': p.width,
                  'height': p.height,
                  if (p.shape != null) 'shape': p.shape,
                  if (p.depth != null) 'depth': p.depth,
                },
              )
              .toList(),
        ),
      );
    } catch (_) {}
  }

  Future<void> _saveAsCustomPreset(
    String name,
    double width,
    double height, {
    String? shape,
    double? depth,
  }) async {
    setState(() {
      _customPresets = [
        ..._customPresets,
        ModulePreset(name, width, height, shape: shape, depth: depth),
      ];
    });
    await _saveCustomPresets();
  }

  Future<void> _deleteCustomPreset(int index) async {
    setState(() {
      _customPresets = [..._customPresets]..removeAt(index);
    });
    await _saveCustomPresets();
  }

  /// 밀어서 지운 프리셋을 같은 자리에 돌려놓는다.
  Future<void> _restoreCustomPreset(int index, ModulePreset preset) async {
    if (!mounted || _customPresets.contains(preset)) return;
    setState(() {
      _customPresets = [..._customPresets]
        ..insert(index.clamp(0, _customPresets.length), preset);
    });
    await _saveCustomPresets();
  }

  // 🚀 [신규] 레이아웃 템플릿 라이브러리 - 자주 쓰는 배치 구성을
  // 별도의 "템플릿"으로 저장해두고, 새 프로젝트를 시작할 때 바로
  // 불러와 쓸 수 있게 한다. 특정 프로젝트에 종속되지 않는 재사용
  // 가능한 참고 배치라서 layouts와는 별도 컬렉션에 저장한다(배경
  // 사진은 기기 로컬 경로라 다른 기기/프로젝트에서 못 여니 제외).
  void _saveAsTemplate() {
    if (!_hasAnyContent) {
      showSnackOnce(
        ScaffoldMessenger.of(context),
        SnackBar(content: Text(keepWords("템플릿으로 저장할 내용이 없습니다."))),
      );
      return;
    }
    final TextEditingController nameCtrl = TextEditingController(
      text: _projectName.isNotEmpty ? _projectName : "새 템플릿",
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "템플릿으로 저장",
          style: TextStyle(color: tossText, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          style: const TextStyle(color: tossText, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            labelText: "템플릿 이름",
            labelStyle: const TextStyle(
              color: tossSubText,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            floatingLabelStyle: const TextStyle(
              color: tossBlue,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
            filled: true,
            fillColor: tossBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("취소", style: TextStyle(color: tossSubText)),
          ),
          TextButton(
            onPressed: () async {
              final String name = nameCtrl.text.trim().isEmpty
                  ? "이름 없는 템플릿"
                  : nameCtrl.text.trim();
              Navigator.pop(ctx);
              try {
                // 중판(평면)은 예전 칸에, 측판·경로·종류는 저장 문서와 같은 칸에(예전엔
                // 지금 보는 탭만 담겨 측판에서 저장하면 측판이 중판으로 들어갔다).
                _dropOrphanViewDims();
                final plates = _allPlates();
                final main = plates[kPlateMain]!;
                // 통신이 없으면 add가 끝나지 않아 알림이 영영 안 떴다. 문서 이름을 먼저 정하고(다시 눌러도
                // 같은 이름이면 하나만 남게) 폰에 적힌 뒤 8초까지만 기다린다(10-08).
                await FirebaseFirestore.instance
                    .collection('layout_templates')
                    .doc(_templateDocId ??= newLayoutId())
                    .set({
                      'name': name,
                      'panelWidth': main['panelWidth'],
                      'panelHeight': main['panelHeight'],
                      'items': main['items'],
                      'dimensions': main['dimensions'],
                      // 측판 배경 사진(폰 경로·서버 주소·자리)은 템플릿에 넣지 않는다(10-08: 남의 배경이 따라갔다).
                      ..._sidePlateFields({
                        for (final e in plates.entries)
                          e.key: {
                            for (final kv in e.value.entries)
                              if (!kv.key.startsWith('background'))
                                kv.key: kv.value,
                          },
                      }),
                      'createdAt': FieldValue.serverTimestamp(),
                    })
                    .timeout(const Duration(seconds: 8), onTimeout: () {});
                _templateDocId = null;
                if (!mounted) return;
                showSnackOnce(
                  ScaffoldMessenger.of(context),
                  SnackBar(
                    content: Text(keepWords("템플릿으로 저장했습니다.")),
                    backgroundColor: tossBlue,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                showSnackOnce(
                  ScaffoldMessenger.of(context),
                  SnackBar(
                    content: Text(keepWords(failText("템플릿 저장 실패", e))),
                    backgroundColor: warningRed,
                  ),
                );
              }
            },
            child: const Text(
              "저장",
              style: TextStyle(color: tossBlue, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showTemplateLibrarySheet() {
    // 시트를 다시 그릴 때마다 서버를 새로 읽지 않게 한 번만 읽어 둔다.
    final Future<QuerySnapshot> future = FirebaseFirestore.instance
        .collection('layout_templates')
        .orderBy('createdAt', descending: true)
        .get();
    // 밀어서 지운 줄(서버 목록은 다시 읽기 전까지 그대로라 여기서 뺀다).
    final Set<String> hidden = {};
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) => SafeArea(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.7,
              ),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: pureWhite,
                borderRadius: BorderRadius.circular(20),
              ),
              child: _sheetUndoHost(
                (hostCtx) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: Text(
                        "템플릿 불러오기",
                        style: TextStyle(
                          color: tossText,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Flexible(
                      child: FutureBuilder<QuerySnapshot>(
                        future: future,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: tossBlue,
                                ),
                              ),
                            );
                          }
                          final docs = (snapshot.data?.docs ?? [])
                              .where((d) => !hidden.contains(d.id))
                              .toList();
                          if (docs.isEmpty) {
                            return Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                keepWords(
                                  "저장된 템플릿이 없습니다.\n'더보기 > 템플릿으로 저장'으로 먼저 만들어 보십시오.",
                                ),
                                style: TextStyle(color: tossSubText),
                              ),
                            );
                          }
                          return ListView.builder(
                            shrinkWrap: true,
                            itemCount: docs.length,
                            itemBuilder: (context, i) {
                              final doc = docs[i];
                              final data = doc.data() as Map<String, dynamic>;
                              final int itemCount =
                                  (data['items'] as List?)?.length ?? 0;
                              final String name =
                                  data['name'] as String? ?? "이름 없는 템플릿";
                              // 휴지통 단추는 잘못 누르면 바로 지워졌다 → 왼쪽으로 밀어 지우고
                              // 되돌리기를 준다(같은 문서에 같은 내용을 다시 적는다).
                              return SwipeToDelete(
                                itemKey: ValueKey('layout-template-${doc.id}'),
                                radius: 0,
                                bottomMargin: 0,
                                onDelete: () {
                                  setSheet(() => hidden.add(doc.id));
                                  doc.reference.delete().catchError((Object e) {
                                    debugPrint('템플릿 삭제 실패: $e');
                                  });
                                  showDeleteUndo(
                                    hostCtx,
                                    name,
                                    onUndo: () {
                                      doc.reference.set(data).catchError((
                                        Object e,
                                      ) {
                                        debugPrint('템플릿 되돌리기 실패: $e');
                                      });
                                      if (ctx.mounted) {
                                        setSheet(() => hidden.remove(doc.id));
                                      }
                                    },
                                  );
                                },
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.dashboard_customize_rounded,
                                    color: tossBlue,
                                  ),
                                  title: Text(
                                    name,
                                    style: const TextStyle(
                                      color: tossText,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    "부품 $itemCount개",
                                    style: const TextStyle(
                                      color: tossSubText,
                                      fontSize: 14,
                                    ),
                                  ),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    _applyTemplate(data);
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                      child: Text(
                        keepWords("줄을 왼쪽으로 밀면 삭제됩니다."),
                        style: const TextStyle(
                          color: tossSubText,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _applyTemplate(Map<String, dynamic> data) {
    void doApply() {
      final whole = data.containsKey('kind');
      if (whole) {
        // 측판·경로까지 갈아 끼우는 템플릿: 중판으로 간 뒤, 다른 판·도면 종류까지 담아 되돌리기에 쌓는다.
        // 10-07: 예전에는 판을 바꾸기 전에 쌓은 기록이 측판 기록과 함께 지워지거나, 되돌려도 측판·종류가
        // 돌아오지 않아 측판 부품이 영영 없어졌다.
        if (_plateId != kPlateMain) setState(() => _switchPlate(kPlateMain));
        _pushWholeUndo();
      } else {
        _pushUndo();
      }
      setState(() {
        // 측판·경로가 담긴 템플릿(kind 칸이 있는 것)은 중판으로 가서 전부 갈아 끼운다.
        if (whole) {
          _applySidePlateFields(data);
        }
        _panelWidth = (data['panelWidth'] as num?)?.toDouble() ?? _panelWidth;
        _panelHeight =
            (data['panelHeight'] as num?)?.toDouble() ?? _panelHeight;
        _placedItems
          ..clear()
          ..addAll(layoutItemsFromData(data));
        _dimensions
          ..clear()
          ..addAll(layoutDimensionsFromData(data));
        relinkDimensions(_dimensions, _placedItems);
      });
      _saveDraftToPrefs();
    }

    if (!_hasAnyContent) {
      doApply();
      return;
    }
    // 🚀 현재 작업 중인 내용이 있으면 덮어써도 되는지 먼저 확인한다.
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "템플릿 적용",
          style: TextStyle(color: tossText, fontWeight: FontWeight.bold),
        ),
        content: Text(
          keepWords(
            "템플릿을 불러오면 지금 작업 중인 배치는 사라집니다(되돌리기로 돌아올 수 있습니다). 계속하시겠습니까?",
          ),
          style: TextStyle(color: tossSubText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("취소", style: TextStyle(color: tossSubText)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              doApply();
            },
            child: const Text(
              "적용",
              style: TextStyle(color: tossBlue, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // 가져올 도면 후보: 목록 화면과 같이 내 배치도(만든 사람 칸이 없는 예전 배치도 포함)만,
  // 최근 고친 순. 예전엔 updatedAt으로 서버 정렬을 걸어서 이 칸이 없는 예전 배치도가 빠졌다.
  Future<List<QueryDocumentSnapshot>> _loadImportSources() async {
    final LayoutOwner me = await loadLayoutOwner();
    final snap = await FirebaseFirestore.instance.collection('layouts').get();
    return layoutImportCandidates(
      snap.docs,
      me: me,
      currentId: _currentProjectId,
      dataOf: (d) => d.data() as Map<String, dynamic>,
      idOf: (d) => d.id,
    );
  }

  // 🚀 [신규] 다른 프로젝트 도면에서 모듈 가져오기 - 이전에 저장해둔
  // 다른 배치도의 모듈 중 원하는 것만 골라 지금 도면으로 복사해 온다.
  // 1단계: 가져올 원본 도면 선택 → 2단계: 그 안의 모듈 체크박스 선택.
  void _showImportModulesFlow() {
    // 10-09: 시트가 다시 그려질 때마다(키보드·화면 회전) 배치도 전체를 다시 받지 않게 한 번만 받는다.
    final sources = _loadImportSources();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.7,
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
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Text(
                    "가져올 도면 선택",
                    style: TextStyle(
                      color: tossText,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                Flexible(
                  child: FutureBuilder<List<QueryDocumentSnapshot>>(
                    future: sources,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: CircularProgressIndicator(color: tossBlue),
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            keepWords("도면 목록을 불러오지 못했습니다. 통신을 확인하십시오."),
                            style: TextStyle(color: tossSubText, fontSize: 15),
                          ),
                        );
                      }
                      final docs =
                          snapshot.data ?? const <QueryDocumentSnapshot>[];
                      if (docs.isEmpty) {
                        return Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            keepWords("가져올 수 있는 다른 도면이 없습니다."),
                            style: TextStyle(color: tossSubText, fontSize: 15),
                          ),
                        );
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: docs.length,
                        itemBuilder: (context, i) {
                          final data = docs[i].data() as Map<String, dynamic>;
                          final int itemCount =
                              (data['items'] as List?)?.length ?? 0;
                          return ListTile(
                            leading: const Icon(
                              Icons.dashboard_customize_rounded,
                              color: tossBlue,
                            ),
                            title: Text(
                              data['projectName'] as String? ?? "이름 없는 도면",
                              style: const TextStyle(
                                color: tossText,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              "부품 $itemCount개",
                              style: const TextStyle(
                                color: tossSubText,
                                fontSize: 14,
                              ),
                            ),
                            enabled: itemCount > 0,
                            onTap: () {
                              Navigator.pop(ctx);
                              _showImportItemPicker(data);
                            },
                          );
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

  void _showImportItemPicker(Map<String, dynamic> sourceData) {
    final List<PlacedItem> sourceItems = ((sourceData['items'] as List?) ?? [])
        .map((e) => PlacedItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final Set<String> selectedIds = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.7,
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
                        keepWords(
                          "가져올 부품 선택 (${sourceData['projectName'] ?? ''})",
                        ),
                        style: const TextStyle(
                          color: tossText,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: sourceItems.length,
                        itemBuilder: (context, i) {
                          final item = sourceItems[i];
                          final bool selected = selectedIds.contains(item.id);
                          return CheckboxListTile(
                            value: selected,
                            onChanged: (v) {
                              setModalState(() {
                                if (v == true) {
                                  selectedIds.add(item.id);
                                } else {
                                  selectedIds.remove(item.id);
                                }
                              });
                            },
                            title: Text(
                              item.name,
                              style: const TextStyle(
                                color: tossText,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              "${item.width.toInt()}×${item.height.toInt()}mm",
                              style: const TextStyle(
                                color: tossSubText,
                                fontSize: 14,
                              ),
                            ),
                            activeColor: tossBlue,
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          onPressed: selectedIds.isEmpty
                              ? null
                              : () {
                                  Navigator.pop(ctx);
                                  _importSelectedModules(
                                    sourceItems.where(
                                      (i) => selectedIds.contains(i.id),
                                    ),
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(40, 40),
                            backgroundColor: tossBlue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            keepWords("선택한 부품 ${selectedIds.length}개 가져오기"),
                            style: const TextStyle(
                              color: pureWhite,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _importSelectedModules(Iterable<PlacedItem> items) {
    _pushUndo();
    setState(() {
      for (final src in items) {
        final PlacedItem newItem = PlacedItem(
          id: newLayoutId('import_'),
          name: src.name,
          position: _snapToGrid(
            Offset(
              src.position.dx.clamp(
                0.0,
                math.max(0.0, _panelWidth - src.width),
              ),
              src.position.dy.clamp(
                0.0,
                math.max(0.0, _panelHeight - src.height),
              ),
            ),
          ),
          width: src.width,
          height: src.height,
          shape: src.shape,
          depth: src.depth,
          elevation: src.elevation,
          flipped: src.flipped,
          tag: src.tag,
          rotation: src.rotation,
        );
        // 겹치는 자리면 조금씩 옮겨가며 빈 자리를 찾는다.
        while (_overlapsAny(newItem, newItem.position)) {
          final Offset moved = _snapToGrid(
            Offset(newItem.position.dx + 20, newItem.position.dy + 20),
          );
          if (moved.dx > _panelWidth - newItem.width ||
              moved.dy > _panelHeight - newItem.height) {
            break; // 더 옮길 자리가 없으면 겹친 채로 둔다(사용자가 직접 조정).
          }
          newItem.position = moved;
        }
        _placedItems.add(newItem);
      }
    });
    HapticFeedback.mediumImpact();
    showSnackOnce(
      ScaffoldMessenger.of(context),
      SnackBar(
        content: Text(keepWords("부품 ${items.length}개를 가져왔습니다.")),
        backgroundColor: tossBlue,
      ),
    );
  }

  // 내 프리셋: 이름 검색(4개 이상일 때), 끌어다 놓을 목록, 지우기 단추가 있는 "관리".
  Widget _buildPresetArea() {
    final String q = _presetSearchQuery.toLowerCase();
    final List<ModulePreset> filtered = q.isEmpty
        ? _customPresets
        : _customPresets
              .where((p) => p.name.toLowerCase().contains(q))
              .toList();
    Widget tile(ModulePreset p) => GestureDetector(
      onLongPress: () => _confirmDeleteCustomPreset(_customPresets.indexOf(p)),
      child: _dragTile(p, (_) => _buildCustomPresetChip(p)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: _panelLabel("내 프리셋 ${_customPresets.length}개")),
            TextButton.icon(
              onPressed: _showPresetManageSheet,
              style: TextButton.styleFrom(
                minimumSize: const Size(40, 40),
                foregroundColor: tossBlue,
              ),
              icon: const Icon(Icons.edit_outlined, size: 20),
              label: const Text(
                "관리",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        if (_customPresets.length > 3) ...[
          TextField(
            controller: _presetSearchCtrl,
            onChanged: (v) => setState(() => _presetSearchQuery = v.trim()),
            style: const TextStyle(fontSize: 15, color: tossText),
            decoration: _inspectorFieldDecoration().copyWith(
              hintText: "프리셋 이름 검색",
              hintStyle: const TextStyle(fontSize: 15, color: tossSubText),
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 22,
                color: tossSubText,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              suffixIcon: _presetSearchQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: "검색 지우기",
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 22,
                        color: tossSubText,
                      ),
                      onPressed: () {
                        _presetSearchCtrl.clear();
                        setState(() => _presetSearchQuery = '');
                      },
                    ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              "찾는 프리셋이 없습니다",
              style: TextStyle(fontSize: 14, color: tossSubText),
            ),
          )
        else
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => tile(filtered[i]),
            ),
          ),
      ],
    );
  }

  // 내 프리셋 관리: 줄을 왼쪽으로 밀어 지우고, 잘못 밀었으면 되돌린다.
  // (예전엔 줄마다 휴지통 단추가 있어 잘못 누르기 쉬웠다.)
  void _showPresetManageSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.7,
              maxWidth: 560,
            ),
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: pureWhite,
              borderRadius: BorderRadius.circular(24),
            ),
            child: _sheetUndoHost(
              (hostCtx) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
                    child: Text(
                      "내 프리셋 관리",
                      style: TextStyle(
                        color: tossText,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text(
                      keepWords(
                        "이 폰에만 저장됩니다. 줄을 왼쪽으로 밀면 삭제되고, 끌어다 놓는 목록에서 빠집니다.",
                      ),
                      style: const TextStyle(color: tossSubText, fontSize: 14),
                    ),
                  ),
                  if (_customPresets.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        "저장된 프리셋이 없습니다",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: tossSubText, fontSize: 15),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _customPresets.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, color: layoutLine),
                        itemBuilder: (context, i) {
                          final p = _customPresets[i];
                          return SwipeToDelete(
                            // 이름이 같은 프리셋이 있을 수 있어 객체로 가른다.
                            itemKey: ValueKey('preset-${identityHashCode(p)}'),
                            radius: 0,
                            bottomMargin: 0,
                            onDelete: () {
                              final idx = _customPresets.indexOf(p);
                              if (idx < 0) return;
                              _deleteCustomPreset(idx);
                              setSheet(() {});
                              showDeleteUndo(
                                hostCtx,
                                p.name,
                                onUndo: () async {
                                  await _restoreCustomPreset(idx, p);
                                  if (ctx.mounted) setSheet(() {});
                                },
                              );
                            },
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 60),
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  left: 20,
                                  right: 20,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      color: tossBlue,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            p.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: tossText,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          Text(
                                            "${p.width.toInt()} × ${p.height.toInt()} mm",
                                            style: const TextStyle(
                                              color: tossSubText,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomPresetChip(ModulePreset preset, {double? width}) {
    return Container(
      height: 56,
      width: width,
      constraints: const BoxConstraints(minWidth: 72),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tossBlue.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 20, color: tossBlue),
          const SizedBox(width: 6),
          _flexIf(
            width != null,
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preset.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: tossText,
                  ),
                ),
                Text(
                  "${preset.width.toInt()}×${preset.height.toInt()}",
                  style: const TextStyle(fontSize: 14, color: tossSubText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 폭이 정해졌을 때만 Flexible로 감싼다(가로로 굴리는 목록 안에서는 폭이 끝없어 Flexible을 못 쓴다).
  Widget _flexIf(bool flex, Widget child) =>
      flex ? Flexible(child: child) : child;

  Future<void> _confirmDeleteCustomPreset(int index) async {
    if (index < 0 || index >= _customPresets.length) return;
    final preset = _customPresets[index];
    final ok = await confirmLayoutDanger(
      context,
      title: "프리셋 삭제",
      message: "'${preset.name}' 프리셋을 지웁니다.",
      confirmLabel: "삭제",
    );
    if (ok && mounted) await _deleteCustomPreset(index);
  }
}
