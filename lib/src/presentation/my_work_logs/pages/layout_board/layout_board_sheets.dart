// 작업 배치도 화면 — 위 막대·더보기·설정·자재 수량·사용법.
// layout_board_page.dart의 _LayoutBoardPageState를 역할별로 나눈 part(10-13). 동작은 같다.
// setState는 State 밖(확장)에서 부르면 보호 멤버 경고가 나지만, 이 확장은 그 State 자신이다.
// ignore_for_file: invalid_use_of_protected_member
part of '../layout_board_page.dart';

extension _LayoutBoardSheets on _LayoutBoardPageState {
  Future<void> _loadGridPref() async {
    try {
      final v = (await SharedPreferences.getInstance()).getDouble(
        _gridPrefsKey,
      );
      if (v != null && _gridChoices.contains(v) && mounted) {
        setState(() => _gridSize = v);
      }
    } catch (_) {}
  }

  void _cycleGrid() {
    final i = _gridChoices.indexOf(_gridSize);
    final next = _gridChoices[(i + 1) % _gridChoices.length];
    setState(() => _gridSize = next);
    SharedPreferences.getInstance()
        .then((p) => p.setDouble(_gridPrefsKey, next))
        .catchError((_) => false);
  }

  String get _gridLabel => _gridSize <= 0 ? "끔" : "${_gridSize.toInt()}mm";

  Future<void> _maybeShowOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_onboardingShownPrefsKey) == true) return;
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: pureWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "작업 배치도 사용법",
            style: TextStyle(color: tossText, fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                keepWords("① 아래 '부품'을 눌러 고르면 도면 가운데에 놓입니다. 끌어서 옮기십시오."),
                style: TextStyle(color: tossText, fontSize: 14, height: 1.6),
              ),
              Text(
                keepWords("② '치수'에서 두 지점을 차례로 누르면 거리가 표시됩니다."),
                style: TextStyle(color: tossText, fontSize: 14, height: 1.6),
              ),
              Text(
                keepWords(
                  "③ 부품을 길게 누르거나 '여러 개'를 켜면 여러 부품을 한 번에 옮기거나 정렬할 수 있습니다.",
                ),
                style: TextStyle(color: tossText, fontSize: 14, height: 1.6),
              ),
              Text(
                keepWords(
                  "④ '도면'에서 크기·모눈·배경 사진을 정하고, ⋮ 더보기에 자재 수량·템플릿·기록이 있습니다.",
                ),
                style: TextStyle(color: tossText, fontSize: 14, height: 1.6),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                "확인",
                style: TextStyle(color: tossBlue, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
      await prefs.setBool(_onboardingShownPrefsKey, true);
    } catch (_) {}
  }

  // 🚀 [신규] 배치된 모듈을 이름별로 모아 세어서 보여준다 - 자재 발주
  // 전에 "무엇이 몇 개 필요한지" 한눈에 확인하고, 텍스트로 복사하거나
  // 카톡 등으로 바로 공유할 수 있게 했다.
  // 🚀 [신규] 치수/가이드선에 쓰이는 색이 많아져서(센터/측면/대각선/
  // 정렬가이드/경고 등) 처음 쓰는 사람은 헷갈릴 수 있어, 각 색이 뭘
  // 뜻하는지 바로 확인할 수 있는 범례를 추가했다.
  void _showColorLegendDialog() {
    Widget row(Color color, String label, String desc) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 16,
              height: 16,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: tossText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: const TextStyle(
                      fontSize: 14,
                      color: tossSubText,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "색상 범례",
          style: TextStyle(color: tossText, fontWeight: FontWeight.w800),
        ),
        content: SizedBox(
          width: 340,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                row(centerDimColor, "파란색", "센터 기준 치수선·가상선"),
                row(edgeDimColor, "주황색", "측면(여백) 기준 치수선"),
                row(diagonalDimColor, "보라색", "대각선 모드 치수선(직선거리+각도)"),
                row(alignGuideColor, "마젠타색", "부품을 옮길 때 뜨는 정렬 안내선"),
                row(warningRed, "빨간색", "최소 간격 위반 경고, 삭제 등 위험/주의 표시"),
                row(tossText, "🛡 방패 표시", "안전 이격거리로 강조된 치수선(굵은 선)"),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "확인",
              style: TextStyle(color: tossBlue, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showMaterialSummarySheet() {
    // 모든 탭(판)의 부품을 합쳐 센다(예전엔 지금 탭만 세서 측판·평면 것이 빠졌다).
    final Map<String, int> counts = {};
    final Map<String, int> perTab = {};
    var totalItems = 0;
    // 덕트·레일·형강·전선관은 개수 옆에 길이 합도 적는다. 메모 글자는 세지 않는다.
    final Map<String, double> lengthByName = {};
    // 이름별 태그 번호(있는 것만).
    final Map<String, List<String>> tagsByName = {};
    for (final e in _allPlates().entries) {
      final items = layoutItemsFromData(
        e.value,
      ).where((it) => it.shape != InstrumentShape.note).toList();
      if (items.isEmpty) continue;
      perTab[_tabLabel(e.key)] = items.length;
      totalItems += items.length;
      for (final item in items) {
        counts[item.name] = (counts[item.name] ?? 0) + 1;
        if (item.tag != null) {
          (tagsByName[item.name] ??= []).add(item.tag!);
        }
        if (isLengthItem(item)) {
          lengthByName[item.name] =
              (lengthByName[item.name] ?? 0) + itemLengthMm(item);
        }
      }
    }
    // 전선관 경로는 규격별 길이 합(꺾이는 점 사이 합).
    final Map<int, double> routeLenBySize = {};
    for (final r in _routes) {
      routeLenBySize[r.size] =
          (routeLenBySize[r.size] ?? 0) + r.totalLengthWith(_planItems);
    }
    final List<(String, double)> lengthLines = [
      for (final e in lengthByName.entries) (e.key, e.value),
      for (final e in routeLenBySize.entries) ("전선관 경로 ${e.key}", e.value),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    String mm(double v) => v >= 1000
        ? "${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}m"
        : "${v.round()}mm";
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    String buildSummaryText() {
      final buf = StringBuffer();
      buf.writeln(
        "[${_projectName.isNotEmpty ? _projectName : '작업 배치도'} 자재 수량]",
      );
      for (final e in entries) {
        final tags = tagsByName[e.key];
        buf.writeln(
          "- ${e.key} x ${e.value}개${tags == null ? "" : " (${tags.join(', ')})"}",
        );
      }
      buf.writeln("총 부품 $totalItems개");
      if (lengthLines.isNotEmpty) {
        buf.writeln("길이 합");
        for (final l in lengthLines) {
          buf.writeln("- ${l.$1}: ${mm(l.$2)}");
        }
      }
      if (_showTabs && perTab.length > 1) {
        buf.writeln(
          "(${perTab.entries.map((e) => "${e.key} ${e.value}개").join(' · ')})",
        );
      }
      return buf.toString();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            decoration: const BoxDecoration(
              color: pureWhite,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBottomSheetHandle(),
                const Text(
                  "자재 수량",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: tossText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  keepWords("배치된 부품을 이름별로 모아 세었습니다."),
                  style: TextStyle(fontSize: 14, color: tossSubText),
                ),
                const SizedBox(height: 16),
                if (entries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        "배치된 부품이 없습니다.",
                        style: TextStyle(color: tossSubText),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: entries.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: tossBg),
                      itemBuilder: (context, index) {
                        final e = entries[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  tagsByName[e.key] == null
                                      ? e.key
                                      : "${e.key}\n${tagsByName[e.key]!.join(', ')}",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: tossText,
                                  ),
                                ),
                              ),
                              Text(
                                "${e.value}개",
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: tossBlue,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                if (lengthLines.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    "길이 합 (긴 변 기준, 경로는 꺾이는 점 사이 합)",
                    style: TextStyle(
                      fontSize: 12,
                      color: tossSubText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  for (final l in lengthLines)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l.$1,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: tossText,
                              ),
                            ),
                          ),
                          Text(
                            mm(l.$2),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: tossBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 12),
                const Divider(height: 1, color: tossBg),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text(
                      "총 부품 수",
                      style: TextStyle(
                        fontSize: 14,
                        color: tossSubText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      "$totalItems개",
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: tossText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: entries.isEmpty
                            ? null
                            : () async {
                                await Clipboard.setData(
                                  ClipboardData(text: buildSummaryText()),
                                );
                                if (!context.mounted) return;
                                showSnackOnce(
                                  ScaffoldMessenger.of(context),
                                  SnackBar(
                                    content: Text(keepWords("자재 목록을 복사했습니다.")),
                                  ),
                                );
                              },
                        icon: const Icon(Icons.copy_rounded, color: tossText),
                        label: const Text(
                          "텍스트 복사",
                          style: TextStyle(
                            color: tossText,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(40, 40),
                          side: BorderSide(
                            color: tossText.withValues(alpha: 0.2),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: entries.isEmpty
                            ? null
                            : () {
                                // ignore: deprecated_member_use
                                Share.share(buildSummaryText());
                              },
                        icon: const Icon(
                          Icons.ios_share_rounded,
                          color: pureWhite,
                        ),
                        label: const Text(
                          "공유하기",
                          style: TextStyle(
                            color: pureWhite,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(40, 40),
                          backgroundColor: tossBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPanelSettingsSheet() {
    final widthCtrl = TextEditingController(
      text: _panelWidth.toInt().toString(),
    );
    final heightCtrl = TextEditingController(
      text: _panelHeight.toInt().toString(),
    );
    // 잘못 넣었을 때 창 안에 보이는 글(스낵바는 창 뒤에 가려 안 보인다).
    final sizeError = ValueNotifier<String?>(null);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBottomSheetHandle(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "도면 크기 설정",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: tossText,
                        letterSpacing: -0.5,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: tossSubText),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  keepWords(
                    _isSkid && _plateId != kPlateMain
                        ? "정면·측면 판은 높이만 바꿉니다. 폭은 평면 탭에서 스키드 크기로 바꾸십시오."
                        : _isSkid
                        ? "스키드 평면(길이 × 폭)을 mm로 넣으십시오. 정면·측면 판 폭도 따라 바뀝니다."
                        : "중판(캐비닛) 실제 크기를 mm로 넣으십시오.",
                  ),
                  style: TextStyle(color: tossSubText, fontSize: 14),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      // 스키드 정면·측면의 폭은 평면 크기에서 오므로 잠근다(10-08 사용자 결정:
                      // 바꿔도 탭을 오가면 평면 크기로 돌아가고 벽 치수만 지워졌다).
                      child: IgnorePointer(
                        ignoring: _isSkid && _plateId != kPlateMain,
                        child: Opacity(
                          opacity: _isSkid && _plateId != kPlateMain ? 0.45 : 1,
                          child: _buildCoordinateInput(
                            "가로 (W) mm",
                            widthCtrl.text,
                            (val) {},
                            controller: widthCtrl,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildCoordinateInput(
                        "세로 (H) mm",
                        heightCtrl.text,
                        (val) {},
                        controller: heightCtrl,
                      ),
                    ),
                  ],
                ),
                ValueListenableBuilder<String?>(
                  valueListenable: sizeError,
                  builder: (_, err, _) => err == null
                      ? const SizedBox(height: 36)
                      : Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 12),
                          child: Text(
                            keepWords(err),
                            style: const TextStyle(
                              color: warningRed,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      final double? w = _isSkid && _plateId != kPlateMain
                          ? _panelWidth
                          : parseNumberText(widthCtrl.text);
                      final double? h = parseNumberText(heightCtrl.text);
                      // 0이나 글자를 넣으면 화면이 깨졌다(NaN). 막고 알린다.
                      if (w == null ||
                          h == null ||
                          !w.isFinite ||
                          !h.isFinite ||
                          w < 10 ||
                          h < 10) {
                        sizeError.value = "가로·세로는 10mm 이상 숫자로 넣으십시오.";
                        return;
                      }
                      _pushUndo();
                      setState(() {
                        _panelWidth = w;
                        _panelHeight = h;

                        for (var item in _placedItems) {
                          item.position = Offset(
                            item.position.dx.clamp(
                              0.0,
                              math.max(0.0, _panelWidth - item.width),
                            ),
                            item.position.dy.clamp(
                              0.0,
                              math.max(0.0, _panelHeight - item.height),
                            ),
                          );
                        }
                        _dimensions.removeWhere(
                          (dim) => dim.p1 is WallPoint || dim.p2 is WallPoint,
                        );
                      });
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(40, 40),
                      backgroundColor: tossBlue,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      "도면 크기 적용",
                      style: TextStyle(
                        color: pureWhite,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
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
  }

  // 위 막대: 자주 쓰는 것(되돌리기·다시 실행·저장)만 둔다. 나머지는 "더보기"
  // 바텀시트에 모으고, 전체 지우기 같은 위험한 것은 그 안에서도 따로 떼어 확인을 받는다.
  PreferredSizeWidget _buildAppBar() {
    final bool canUndo = _undoStack.isNotEmpty;
    final bool canRedo = _redoStack.isNotEmpty;
    // 폰 폭에서는 저장 단추를 아이콘만 두어 제목 자리를 넓힌다.
    final bool narrowBar = MediaQuery.of(context).size.width < 600;
    return AppBar(
      backgroundColor: tossBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 64,
      centerTitle: false,
      titleSpacing: 0,
      leadingWidth: 52,
      shape: const Border(bottom: BorderSide(color: layoutLine)),
      leading: IconButton(
        tooltip: "뒤로",
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: const Icon(AppIcons.back, color: tossText, size: 22),
        onPressed: () => Navigator.pop(context),
      ),
      // 제목은 배치도 이름 하나만 쓴다. 폰 폭은 단추 넷이 자리를 차지하므로
      // 두 줄까지 접어서 이름이 잘리지 않게 한다.
      // 제목은 배치도 이름, 그 밑에 종류·크기 한 줄(10-13).
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _projectName.isNotEmpty
                ? _projectName
                : (_isSkid ? "새 스키드" : "새 캐비닛"),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tossText,
              fontSize: narrowBar ? 16 : 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          // 폰(좁은 막대)은 제목 자리가 100dp쯤이라 "캐비닛 600×800"도 잘린다 → 크기만.
          Text(
            narrowBar
                ? "${_panelWidth.toInt()}×${_panelHeight.toInt()}mm"
                : "${_isSkid ? "스키드" : "캐비닛"} · ${_panelWidth.toInt()}×${_panelHeight.toInt()}mm",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: tossSubText,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
      ),
      actions: [
        // 길게 누르면 되돌리기 기록이 열린다. 같은 것을 "더보기"에서도 연다.
        GestureDetector(
          onLongPress: canUndo ? _showUndoHistorySheet : null,
          child: IconButton(
            tooltip: "되돌리기",
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: canUndo ? _undo : null,
            icon: Icon(
              AppIcons.undo,
              size: 24,
              color: canUndo ? tossText : tossSubText.withValues(alpha: 0.35),
            ),
          ),
        ),
        IconButton(
          tooltip: "다시 실행",
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: canRedo ? _redo : null,
          icon: Icon(
            AppIcons.redo,
            size: 24,
            color: canRedo ? tossText : tossSubText.withValues(alpha: 0.35),
          ),
        ),
        const SizedBox(width: 4),
        if (_isSaving)
          const SizedBox(
            width: 76,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: tossBlue,
                ),
              ),
            ),
          )
        else if (narrowBar)
          Tooltip(
            message: "저장·공유",
            child: SizedBox(
              width: 44,
              height: 44,
              child: FilledButton(
                onPressed: _showSaveActionSheet,
                style: FilledButton.styleFrom(
                  backgroundColor: tossBlue,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Icon(
                  AppIcons.download,
                  size: 22,
                  color: pureWhite,
                ),
              ),
            ),
          )
        else
          Tooltip(
            message: "저장·공유",
            child: FilledButton.icon(
              onPressed: _showSaveActionSheet,
              style: FilledButton.styleFrom(
                backgroundColor: tossBlue,
                minimumSize: const Size(72, 44),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(AppIcons.download, size: 20, color: pureWhite),
              label: const Text(
                "저장",
                style: TextStyle(
                  color: pureWhite,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        IconButton(
          tooltip: "더보기",
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: _showMoreSheet,
          icon: const Icon(AppIcons.more, color: tossText, size: 24),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // 위 막대 "더보기": 자주 안 쓰는 것을 묶어 둔 바텀시트.
  // 맨 아래 빨간 칸의 전체 지우기는 한 번 더 묻고 지운다(되돌리기로도 돌아온다).
  void _showMoreSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        void run(VoidCallback action) {
          Navigator.pop(ctx);
          action();
        }

        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              maxWidth: 560,
            ),
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tossBg,
              borderRadius: BorderRadius.circular(24),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _moreSection("도면", [
                    layoutSheetRow(
                      key: const ValueKey("board_settings_row"),
                      icon: Icons.tune_rounded,
                      label: "도면 설정",
                      caption: "크기 · 모눈 · 안내선 · 측판 · 배경 사진",
                      onTap: () => run(_openBoardSettings),
                    ),
                    layoutSheetRow(
                      icon: Icons.inventory_2_outlined,
                      label: "자재 수량",
                      onTap: () => run(_showMaterialSummarySheet),
                    ),
                    if (_savedRects.isNotEmpty)
                      layoutSheetRow(
                        key: const ValueKey("toggle_saved_diff"),
                        icon: Icons.difference_outlined,
                        label: "저장본과 차이 보기",
                        caption: _showSavedDiff
                            ? "켜짐 · 옮긴 부품의 옛 자리는 점선, 지운 부품은 붉은 점선"
                            : "꺼짐 · 마지막 저장본에서 무엇이 바뀌었는지 도면에 그립니다",
                        onTap: () => run(
                          () =>
                              setState(() => _showSavedDiff = !_showSavedDiff),
                        ),
                      ),
                    layoutSheetRow(
                      icon: Icons.palette_outlined,
                      label: "색상 범례",
                      onTap: () => run(_showColorLegendDialog),
                    ),
                  ]),
                  _moreSection("기록", [
                    layoutSheetRow(
                      icon: Icons.history_rounded,
                      label: "되돌리기 기록",
                      caption: _undoStack.isEmpty
                          ? "되돌릴 것이 없습니다"
                          : "${_undoStack.length}단계까지 골라서 한 번에 되돌립니다",
                      onTap: _undoStack.isEmpty
                          ? null
                          : () => run(_showUndoHistorySheet),
                    ),
                  ]),
                  _moreSection("템플릿", [
                    layoutSheetRow(
                      icon: Icons.bookmark_add_outlined,
                      label: "템플릿으로 저장",
                      onTap: () => run(_saveAsTemplate),
                    ),
                    layoutSheetRow(
                      icon: Icons.library_books_outlined,
                      label: "템플릿 불러오기",
                      onTap: () => run(_showTemplateLibrarySheet),
                    ),
                    layoutSheetRow(
                      icon: Icons.move_down_outlined,
                      label: "다른 도면에서 부품 가져오기",
                      onTap: () => run(_showImportModulesFlow),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  // 위험한 것은 따로 뗀 빨간 칸에 둔다.
                  Container(
                    decoration: BoxDecoration(
                      color: pureWhite,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: warningRed.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        layoutSheetRow(
                          icon: Icons.straighten_rounded,
                          label: "치수선 전체 지우기",
                          danger: true,
                          onTap: _dimensions.isEmpty
                              ? null
                              : () => run(_confirmClearDimensions),
                        ),
                        const Divider(height: 1, color: layoutLine),
                        layoutSheetRow(
                          icon: Icons.delete_sweep_outlined,
                          label: "도면 전체 지우기",
                          caption: "모든 탭의 부품·경로·치수선을 지웁니다",
                          danger: true,
                          onTap: _hasAnyContent
                              ? () => run(_confirmClearBoard)
                              : null,
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
    );
  }

  Widget _moreSection(String title, List<Widget> rows) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Text(
              title,
              style: const TextStyle(
                color: tossSubText,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Container(
            decoration: layoutCardDecoration(),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < rows.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: layoutLine),
                  rows[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "도면" 단추로 여는 도면 설정 페이지(10-13 개편). 예전 ⋮ 더보기의 도면 줄들을 옮겼다.
/// 값은 배치도 State([owner])에서 읽는다. 켜고 끄는 것은 여기서 바로 하고, 창을 여는 것은
/// 이 페이지를 닫은 뒤 도면 위에서 연다(더보기와 같은 방식).
class _LayoutSettingsPage extends StatefulWidget {
  final _LayoutBoardPageState owner;
  const _LayoutSettingsPage({required this.owner});

  @override
  State<_LayoutSettingsPage> createState() => _LayoutSettingsPageState();
}

class _LayoutSettingsPageState extends State<_LayoutSettingsPage> {
  _LayoutBoardPageState get o => widget.owner;

  /// 이 페이지를 닫고 도면 위에서 창을 연다.
  void _run(VoidCallback action) {
    Navigator.pop(context);
    action();
  }

  /// 켜고 끄기: 바로 하고 이 페이지를 다시 그린다.
  void _toggle(VoidCallback action) {
    action();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bool skid = o._isSkid;
    return Scaffold(
      backgroundColor: tossBg,
      appBar: AppBar(
        backgroundColor: tossBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        shape: const Border(bottom: BorderSide(color: layoutLine)),
        title: const Text(
          "도면 설정",
          style: TextStyle(
            color: tossText,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          o._moreSection("크기·모눈", [
            layoutSheetRow(
              key: const ValueKey("settings_size"),
              icon: Icons.aspect_ratio_rounded,
              label: skid ? "스키드 크기 (길이 × 폭)" : "외함 크기",
              caption:
                  "${o._showTabs ? "${o._tabLabel(o._plateId)} " : ""}지금 ${o._panelWidth.toInt()} × ${o._panelHeight.toInt()} mm",
              onTap: () => _run(o._showPanelSettingsSheet),
            ),
            layoutSheetRow(
              key: const ValueKey("grid_snap"),
              icon: Icons.grid_4x4_rounded,
              label: "모눈 맞춤: ${o._gridLabel}",
              caption: o._gridSize <= 0
                  ? "끔 · 놓는 자리 그대로. 누르면 1mm"
                  : "누를 때마다 끔 → 1 → 5 → 10mm",
              onTap: () => _toggle(o._cycleGrid),
            ),
            layoutSheetRow(
              key: const ValueKey("snap_guides"),
              icon: Icons.align_horizontal_left_rounded,
              label: "안내선에 붙이기",
              caption: o._snapToGuides
                  ? "켜짐 · 끌 때 옆 부품의 왼·가운데·오른 선에 가까우면 붙습니다"
                  : "꺼짐 · 안내선만 보이고 자리는 손가락 그대로",
              onTap: () => _toggle(() => o._setSnapToGuides(!o._snapToGuides)),
            ),
          ]),
          if (skid)
            o._moreSection("보기", [
              layoutSheetRow(
                key: const ValueKey("toggle_hidden_parts"),
                icon: Icons.layers_outlined,
                label: "가려진 부품 보이기",
                caption: o._showHiddenParts
                    ? "켜짐 · 정면·측면에서 뒤에 가려진 부품을 점선으로 그립니다"
                    : "꺼짐 · 가까운 부품만 보입니다",
                onTap: () => _toggle(() {
                  o.setState(() => o._showHiddenParts = !o._showHiddenParts);
                  o._saveDraftToPrefs();
                }),
              ),
            ]),
          if (!skid)
            o._moreSection("측판", [
              layoutSheetRow(
                key: const ValueKey("toggle_side_plates"),
                icon: Icons.view_column_outlined,
                label: "좌·우 측판",
                caption: o._sidePlatesOn
                    ? "켜짐 · 위 탭으로 판을 바꿉니다"
                    : "꺼짐 · 켜면 측판에 전기 부품을 따로 배치합니다",
                onTap: () => _toggle(o._toggleSidePlates),
              ),
              layoutSheetRow(
                icon: Icons.layers_outlined,
                label: "측판·깊이 설정",
                caption: o._cabinetDepth == null
                    ? "캐비닛 깊이·측판 높이 차"
                    : "캐비닛 깊이 ${o._cabinetDepth!.toInt()} mm",
                onTap: () => _run(o._showCabinetSettingsSheet),
              ),
              layoutSheetRow(
                icon: Icons.warning_amber_rounded,
                label: "간섭 확인",
                caption: "중판·측판 부품 간섭, 문보다 깊은 부품 확인",
                onTap: () => _run(o._showClashSheet),
              ),
            ]),
          o._moreSection("배경", [
            layoutSheetRow(
              key: const ValueKey("settings_background"),
              icon: Icons.image_outlined,
              label: "배경 사진",
              caption: o._backgroundImagePath != null
                  ? "깔려 있습니다"
                  : "도면 사진을 깔고 축척을 맞춥니다",
              onTap: () => _run(o._showBackgroundSheet),
            ),
          ]),
        ],
      ),
    );
  }
}
