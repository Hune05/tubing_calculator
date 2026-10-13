// 작업 배치도 화면 — 배경 도면·축척.
// layout_board_page.dart의 _LayoutBoardPageState를 역할별로 나눈 part(10-13). 동작은 같다.
// setState는 State 밖(확장)에서 부르면 보호 멤버 경고가 나지만, 이 확장은 그 State 자신이다.
// ignore_for_file: invalid_use_of_protected_member
part of '../layout_board_page.dart';

extension _LayoutBoardBackground on _LayoutBoardPageState {
  /// 밝기·흑백을 한 번에 거는 색 필터.
  ColorFilter get _backgroundFilter {
    final double b = _backgroundBrightness;
    if (_backgroundGray) {
      return ColorFilter.matrix([
        0.2126 * b, 0.7152 * b, 0.0722 * b, 0, 0, //
        0.2126 * b, 0.7152 * b, 0.0722 * b, 0, 0, //
        0.2126 * b, 0.7152 * b, 0.0722 * b, 0, 0, //
        0, 0, 0, 1, 0,
      ]);
    }
    return ColorFilter.matrix([
      b, 0, 0, 0, 0, //
      0, b, 0, 0, 0, //
      0, 0, b, 0, 0, //
      0, 0, 0, 1, 0,
    ]);
  }

  /// 배경 사진을 90° 시계 방향으로 돌려 새 파일로 저장하고 바꿔 깐다(큰 사진은 긴 변 2500px로 줄인다).
  Future<void> _rotateBackground() async {
    final path = _backgroundImagePath;
    if (path == null) return;
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final ui.Image src = frame.image;
      final double k = math.min(1.0, 2500 / math.max(src.width, src.height));
      final int w = (src.height * k).round(), h = (src.width * k).round();
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.translate(w.toDouble(), 0);
      c.rotate(math.pi / 2);
      c.drawImageRect(
        src,
        Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
        Rect.fromLTWH(0, 0, h.toDouble(), w.toDouble()),
        Paint()..filterQuality = FilterQuality.medium,
      );
      final ui.Image out = await rec.endRecording().toImage(w, h);
      final data = await out.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw Exception("그림 변환 실패");
      final dir = await getTemporaryDirectory();
      final f = File(
        "${dir.path}/layout_bg_rot_${DateTime.now().millisecondsSinceEpoch}.png",
      );
      await f.writeAsBytes(data.buffer.asUint8List());
      if (!mounted) return;
      setState(() {
        _backgroundImagePath = f.path;
        _backgroundImageUrl = null;
        // 축척을 맞춰 둔 자리는 가운데를 두고 가로·세로만 바꾼다.
        final Rect? r = _backgroundRect;
        if (r != null) {
          _backgroundRect = Rect.fromCenter(
            center: r.center,
            width: r.height,
            height: r.width,
          );
        }
      });
      _saveDraftToPrefs();
    } catch (e) {
      if (!mounted) return;
      showSnackOnce(
        ScaffoldMessenger.of(context),
        SnackBar(content: Text(keepWords(failText("사진 돌리기 실패", e)))),
      );
    }
  }

  // 🚀 [신규] 실제 도면 사진(카톡으로 받은 배치도, 손그림 등)을 배경으로
  // 깔아두고 그 위에 모듈을 배치할 수 있게 하는 바텀시트. 불투명도를
  // 조절해서 사진과 모듈이 겹쳐도 알아보기 쉽게 한다.
  /// 축척 맞추기 안내에 쓰는 판 이름.
  String get _scaleTargetName =>
      _isSkid && _plateId == kPlateMain ? "스키드" : _tabLabel(_plateId);

  /// 공유로 받은 도면을 지금 탭 배경에 깔고 축척 맞추기를 띄운다.
  Future<void> _takeSharedDrawing(String path) async {
    // 받은 자리(shared_drawings)는 쌓이기만 하므로 앱 사진 폴더로 옮기고 받은 자리는 비운다.
    // 받은 자리(shared_drawings)에 있는 파일만 옮긴다(없는 파일·다른 자리는 그대로).
    String kept = path;
    if (path.replaceAll('\\', '/').contains('/shared_drawings/') &&
        await File(path).exists()) {
      kept = await ImagePickerHelper.keepPhoto(path);
      if (kept != path) await SharedDrawingInbox.discardAll(path);
    }
    if (!mounted) return;
    setState(() {
      _backgroundImagePath = kept;
      _backgroundImageUrl = null;
      _backgroundRect = null;
      _backgroundOpacity = 0.5;
    });
    _saveDraftToPrefs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _calibrateBackground();
    });
  }

  /// 배경 사진 모서리 두 곳을 찍어 실제 mm에 맞춘다. 넣은 가로·세로로 판 크기도 맞춘다.
  Future<void> _calibrateBackground() async {
    final path = _backgroundImagePath;
    if (path == null) return;
    final r = await DrawingScalePage.open(
      context,
      imagePath: path,
      widthMm: _panelWidth,
      heightMm: _panelHeight,
      targetName: _scaleTargetName,
    );
    if (r == null || !mounted) return;
    // 스키드 정면·측면은 폭이 평면 크기를 따른다. 폭을 바꿔 맞추면 탭을 오갈 때 어긋나므로 막는다(10-08).
    if (_isSkid &&
        _plateId != kPlateMain &&
        (r.widthMm - _panelWidth).abs() > 1) {
      showSnackOnce(
        ScaffoldMessenger.of(context),
        SnackBar(
          content: Text(
            keepWords(
              "정면·측면 판 폭은 평면 크기(${_panelWidth.round()}mm)를 따릅니다. 가로는 그대로 두고 높이만 맞추십시오.",
            ),
          ),
          backgroundColor: warningRed,
        ),
      );
      return;
    }
    // 외함 크기 설정과 같게: 되돌리기 한 단계, 판 밖으로 나간 부품은 안으로, 벽 치수는 지운다.
    _pushUndo();
    setState(() {
      _panelWidth = r.widthMm;
      _panelHeight = r.heightMm;
      _backgroundRect = r.rect;
      _fitPending = true;
      for (final item in _placedItems) {
        item.position = Offset(
          item.position.dx.clamp(0.0, math.max(0.0, _panelWidth - item.width)),
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
    _saveDraftToPrefs();
    showSnackOnce(
      ScaffoldMessenger.of(context),
      SnackBar(
        content: Text(
          keepWords(
            "도면을 가로 ${r.widthMm.toInt()} × 세로 ${r.heightMm.toInt()} mm에 맞췄습니다.",
          ),
        ),
      ),
    );
  }

  void _showBackgroundSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                decoration: const BoxDecoration(
                  color: pureWhite,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1D6DB),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const Text(
                      "배경 사진",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: tossText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      keepWords(
                        "카톡으로 받은 실제 도면 사진을 배경에 깔고 그 위에 부품을\n배치할 수 있습니다. PDF 도면은 카톡에서 사진으로 저장해서 받으십시오.",
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        color: tossSubText,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_backgroundImagePath != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: 16 / 10,
                          child: Image.file(
                            File(_backgroundImagePath!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(
                            Icons.opacity_rounded,
                            size: 18,
                            color: tossSubText,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            "투명도",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: tossText,
                            ),
                          ),
                          Expanded(
                            child: Slider(
                              value: _backgroundOpacity,
                              min: 0.15,
                              max: 1.0,
                              activeColor: tossBlue,
                              onChanged: (v) {
                                setModalState(() => _backgroundOpacity = v);
                                setState(() => _backgroundOpacity = v);
                              },
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.light_mode_outlined,
                            size: 18,
                            color: tossSubText,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            "밝기",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: tossText,
                            ),
                          ),
                          Expanded(
                            child: Slider(
                              key: const ValueKey("background_brightness"),
                              value: _backgroundBrightness,
                              min: 0.6,
                              max: 1.6,
                              activeColor: tossBlue,
                              onChanged: (v) {
                                setModalState(() => _backgroundBrightness = v);
                                setState(() => _backgroundBrightness = v);
                              },
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: SwitchListTile(
                              key: const ValueKey("background_gray"),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: const Text(
                                "흑백으로",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: tossText,
                                ),
                              ),
                              value: _backgroundGray,
                              activeThumbColor: tossBlue,
                              onChanged: (v) {
                                setModalState(() => _backgroundGray = v);
                                setState(() => _backgroundGray = v);
                              },
                            ),
                          ),
                          TextButton.icon(
                            key: const ValueKey("background_rotate"),
                            onPressed: () async {
                              await _rotateBackground();
                              setModalState(() {});
                            },
                            icon: const Icon(
                              Icons.rotate_90_degrees_cw_rounded,
                              size: 18,
                            ),
                            label: const Text(
                              "90° 돌리기",
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_backgroundImagePath != null) ...[
                      const SizedBox(height: 4),
                      FilledButton.icon(
                        key: const ValueKey("background_scale"),
                        onPressed: () {
                          Navigator.pop(context);
                          _calibrateBackground();
                        },
                        icon: const Icon(Icons.straighten_rounded),
                        label: Text(
                          _backgroundRect == null ? "축척 맞추기" : "축척 다시 맞추기",
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: tossBlue,
                          minimumSize: const Size(40, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        keepWords(
                          "도면에서 모서리 두 곳을 찍고 실제 가로·세로를 넣으면 도면이 실제 크기로 깔립니다.",
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          color: tossSubText,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final path = await ImagePickerHelper.pickImage(
                                context,
                              );
                              if (path != null) {
                                setModalState(
                                  () => _backgroundImagePath = path,
                                );
                                setState(() {
                                  _backgroundImagePath = path;
                                  _backgroundImageUrl = null;
                                  _backgroundRect = null;
                                });
                              }
                            },
                            icon: const Icon(
                              Icons.add_photo_alternate_outlined,
                              color: tossBlue,
                            ),
                            label: Text(
                              _backgroundImagePath == null ? "사진 선택" : "사진 변경",
                              style: const TextStyle(
                                color: tossBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(40, 40),
                              side: const BorderSide(color: tossBlue),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        if (_backgroundImagePath != null) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                // 바로 빠졌다 → 맞춰 둔 축척까지 지워지므로 한 번 묻는다
                                // (도면 되돌리기에는 배경이 들어 있지 않다).
                                final ok = await confirmLayoutDanger(
                                  context,
                                  title: "배경 제거",
                                  message:
                                      "깔아 둔 배경 사진을 뺍니다. 사진에 맞춰 둔 축척도 같이 지워집니다.",
                                  confirmLabel: "삭제",
                                );
                                if (!ok || !mounted) return;
                                if (context.mounted) {
                                  setModalState(
                                    () => _backgroundImagePath = null,
                                  );
                                }
                                setState(() {
                                  _backgroundImagePath = null;
                                  _backgroundRect = null;
                                  // 서버 주소도 지운다(10-08: 남아 있어 다시 열면 배경이 다시 받아져 깔렸다).
                                  _backgroundImageUrl = null;
                                });
                              },
                              icon: const Icon(
                                Icons.delete_outline,
                                color: warningRed,
                              ),
                              label: const Text(
                                "배경 제거",
                                style: TextStyle(
                                  color: warningRed,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(40, 40),
                                side: const BorderSide(color: warningRed),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
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
}
