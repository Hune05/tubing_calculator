// 작업 배치도 화면 — 부품 편집 창(아래 시트).
// layout_board_page.dart의 _LayoutBoardPageState를 역할별로 나눈 part(10-13). 동작은 같다.
// setState는 State 밖(확장)에서 부르면 보호 멤버 경고가 나지만, 이 확장은 그 State 자신이다.
// ignore_for_file: invalid_use_of_protected_member
part of '../layout_board_page.dart';

extension _LayoutBoardItemSheet on _LayoutBoardPageState {
  Widget _buildBottomSheetHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 5,
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  /// 부품 편집 창(아래 시트). 10-13 정리: 자주 쓰는 것(이름·태그·크기·깊이·회전·뒤집기·복제)만 바로,
  /// 가끔 쓰는 것(위치 숫자·맨 앞/뒤·잠금·내 프리셋 저장)은 "더보기"에 접어 둔다. 단추 13개가 한 창에 다 있었다.
  void _showInspectorBottomSheet(PlacedItem item) {
    // 🚀 이 편집창 안에서 이름/회전/크기 등을 몇 번을 고치든, 열기
    // 직전 상태 하나만 기억해서 "편집 취소"가 한 번에 되게 한다
    // (텍스트 입력마다 undo를 쌓으면 되돌리기가 너무 잘게 쪼개진다).
    _pushUndo();
    final TextEditingController nameCtrl = TextEditingController(
      text: item.name,
    );
    final TextEditingController tagCtrl = TextEditingController(
      text: item.tag ?? "",
    );
    final TextEditingController widthCtrl = TextEditingController(
      text: item.width.toInt().toString(),
    );
    final TextEditingController heightCtrl = TextEditingController(
      text: item.height.toInt().toString(),
    );
    final TextEditingController depthCtrl = TextEditingController(
      text: _depthText(_isSkid ? item.elevation : item.depth),
    );
    bool more = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.15),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            void syncSize() => setModalState(() {
              widthCtrl.text = item.width.toInt().toString();
              heightCtrl.text = item.height.toInt().toString();
            });
            // 자주 쓰는 단추(높이 44, 옅은 청록 바탕).
            Widget quick({
              required Key key,
              required IconData icon,
              required String label,
              required VoidCallback onTap,
            }) => ElevatedButton.icon(
              key: key,
              onPressed: onTap,
              icon: Icon(icon, size: 18, color: tossBlue),
              label: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: tossBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(40, 44),
                backgroundColor: tossBlue.withValues(alpha: 0.1),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
              ),
            );
            // 더보기 안 단추(테두리만).
            Widget plain({
              required Key key,
              required IconData icon,
              required String label,
              required VoidCallback onTap,
              Color color = tossText,
            }) => OutlinedButton.icon(
              key: key,
              onPressed: onTap,
              icon: Icon(icon, size: 18, color: color),
              label: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(40, 44),
                side: BorderSide(color: color.withValues(alpha: 0.25)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
            // 위치 숫자 입력: 다른 부품과 겹치면 옮기지 않는다(끌 때와 같은 규칙, 10-13).
            void moveTo(Offset wanted) {
              final Offset next = Offset(
                wanted.dx.clamp(0.0, math.max(0.0, _panelWidth - item.width)),
                wanted.dy.clamp(0.0, math.max(0.0, _panelHeight - item.height)),
              );
              if (_overlapsAny(item, next)) {
                showSnackOnce(
                  ScaffoldMessenger.of(context),
                  SnackBar(
                    content: Text(keepWords("그 자리는 다른 부품과 겹칩니다. 옮기지 않았습니다.")),
                    backgroundColor: tossText,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              } else {
                setState(() => item.position = next);
              }
              setModalState(() {});
            }

            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 16,
                left: 24,
                right: 24,
              ),
              decoration: BoxDecoration(
                color: pureWhite,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 30,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              // 자판이 뜨면 세로가 모자라므로 굴러가게 감싼다.
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
                          "부품 편집",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: tossText,
                            letterSpacing: -0.5,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: tossSubText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey("item_name_field"),
                      controller: nameCtrl,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: tossText,
                      ),
                      decoration: InputDecoration(
                        labelText: "부품 이름",
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
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (val) {
                        setState(() {
                          item.name = val.isEmpty ? "이름 없음" : val;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildTagField(item, tagCtrl),
                    if (_buildRailLengthHint(item, () {}) != null) ...[
                      const SizedBox(height: 12),
                      _buildRailLengthHint(item, syncSize)!,
                    ],
                    const SizedBox(height: 20),
                    const Text(
                      "부품 크기 (가로 x 세로)",
                      style: TextStyle(
                        color: tossText,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildCoordinateInput(
                            "가로 너비 (mm)",
                            widthCtrl.text,
                            (val) {
                              setState(() {
                                item.width =
                                    (parseNumberText(val) ?? item.width).clamp(
                                      1.0,
                                      100000.0,
                                    );
                                item.position = Offset(
                                  item.position.dx.clamp(
                                    0.0,
                                    math.max(0.0, _panelWidth - item.width),
                                  ),
                                  item.position.dy,
                                );
                              });
                            },
                            controller: widthCtrl,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildCoordinateInput(
                            "세로 높이 (mm)",
                            heightCtrl.text,
                            (val) {
                              setState(() {
                                item.height =
                                    (parseNumberText(val) ?? item.height).clamp(
                                      1.0,
                                      100000.0,
                                    );
                                item.position = Offset(
                                  item.position.dx,
                                  item.position.dy.clamp(
                                    0.0,
                                    math.max(0.0, _panelHeight - item.height),
                                  ),
                                );
                              });
                            },
                            controller: heightCtrl,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildCoordinateInput(
                      _isSkid
                          ? "바닥에서 높이 (mm, 부품 가운데까지)"
                          : "깊이 (mm, 판에서 앞으로 튀어나온 길이)",
                      depthCtrl.text,
                      (val) {
                        setState(() {
                          if (_isSkid) {
                            item.elevation = _parseDepth(val);
                          } else {
                            item.depth = _parseDepth(val);
                          }
                        });
                      },
                      controller: depthCtrl,
                    ),
                    const SizedBox(height: 20),
                    // 자주 쓰는 동작: 돌리기 · 뒤집기(그림 있는 부품) · 복제
                    Row(
                      children: [
                        Expanded(
                          child: quick(
                            key: const ValueKey("rotate_button"),
                            icon: Icons.rotate_90_degrees_cw_rounded,
                            label: "90° 회전",
                            onTap: () {
                              // 가로·세로를 바꾸고 각도 칸도 90 더한다(가운데는 그 자리).
                              _rotateItem(item);
                              syncSize();
                            },
                          ),
                        ),
                        if (_canFlip(item)) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: quick(
                              key: const ValueKey("flip_button"),
                              icon: Icons.flip_rounded,
                              label: SkidShape.isFitting(item.shape)
                                  ? "뒤집기 (허브 반대)"
                                  : "좌우 뒤집기",
                              onTap: () {
                                _flipItem(item);
                                setModalState(() {});
                              },
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        Expanded(
                          child: quick(
                            key: const ValueKey("duplicate_button"),
                            icon: Icons.content_copy_rounded,
                            label: "부품 복제",
                            onTap: () {
                              // 복제(되돌리기 한 번으로 돌아간다). 겹치지 않는 옆자리에 놓는다.
                              _duplicateItem(item);
                              Navigator.pop(context);
                              showSnackOnce(
                                ScaffoldMessenger.of(context),
                                SnackBar(
                                  content: Text(
                                    keepWords("'${item.name}' 부품을 복사했습니다."),
                                  ),
                                  backgroundColor: tossText,
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 가끔 쓰는 것은 접어 둔다.
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        key: const ValueKey("item_more"),
                        onPressed: () => setModalState(() => more = !more),
                        icon: Icon(
                          more
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          size: 20,
                          color: tossSubText,
                        ),
                        label: Text(
                          more ? "접기" : "더보기 (위치 숫자 · 앞뒤 순서 · 잠금 · 내 프리셋)",
                          style: const TextStyle(
                            color: tossSubText,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    if (more) ...[
                      const SizedBox(height: 8),
                      const Text(
                        "위치 (mm, 왼쪽 위 기준)",
                        style: TextStyle(
                          color: tossText,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildCoordinateInput(
                              "X 좌표 (mm)",
                              item.position.dx.toInt().toString(),
                              (val) => moveTo(
                                Offset(
                                  parseNumberText(val) ?? item.position.dx,
                                  item.position.dy,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildCoordinateInput(
                              "Y 좌표 (mm)",
                              item.position.dy.toInt().toString(),
                              (val) => moveTo(
                                Offset(
                                  item.position.dx,
                                  parseNumberText(val) ?? item.position.dy,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // 겹칠 때 어느 것이 위로 보일지. 목록 맨 뒤가 화면 맨 위다.
                      Row(
                        children: [
                          Expanded(
                            child: plain(
                              key: const ValueKey("front_button"),
                              icon: Icons.flip_to_front_rounded,
                              label: "맨 앞으로",
                              onTap: () {
                                setState(() {
                                  _placedItems.remove(item);
                                  _placedItems.add(item);
                                });
                                setModalState(() {});
                                HapticFeedback.lightImpact();
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: plain(
                              key: const ValueKey("back_button"),
                              icon: Icons.flip_to_back_rounded,
                              label: "맨 뒤로",
                              onTap: () {
                                setState(() {
                                  _placedItems.remove(item);
                                  _placedItems.insert(0, item);
                                });
                                setModalState(() {});
                                HapticFeedback.lightImpact();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: plain(
                              key: const ValueKey("lock_button"),
                              icon: item.isLocked
                                  ? Icons.lock_rounded
                                  : Icons.lock_open_rounded,
                              label: item.isLocked ? "잠금 해제" : "이 부품 위치 잠그기",
                              color: item.isLocked ? warningRed : tossText,
                              onTap: () {
                                setState(() => item.isLocked = !item.isLocked);
                                setModalState(() {});
                                HapticFeedback.lightImpact();
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: plain(
                              key: const ValueKey("preset_save_button"),
                              icon: Icons.star_border_rounded,
                              label: "내 프리셋으로 저장",
                              onTap: () {
                                _saveAsCustomPreset(
                                  nameCtrl.text.trim().isNotEmpty
                                      ? nameCtrl.text.trim()
                                      : item.name,
                                  item.width,
                                  item.height,
                                  shape: item.shape,
                                  depth: item.depth,
                                );
                                HapticFeedback.lightImpact();
                                showSnackOnce(
                                  ScaffoldMessenger.of(context),
                                  SnackBar(
                                    content: Text(keepWords("내 프리셋에 저장했습니다.")),
                                    backgroundColor: tossText,
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        key: const ValueKey("delete_button"),
                        onPressed: () {
                          setState(() {
                            _dimensions.removeWhere(
                              (dim) =>
                                  dim.p1.id == item.id || dim.p2.id == item.id,
                            );
                            _placedItems.remove(item);
                            if (_dimensionStartPoint?.id == item.id) {
                              _dimensionStartPoint = null;
                            }
                            _activeItem = null;
                          });
                          Navigator.pop(context);
                        },
                        icon: const Icon(
                          Icons.delete_outline,
                          color: warningRed,
                        ),
                        label: const Text(
                          "이 부품 삭제",
                          style: TextStyle(
                            color: warningRed,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(40, 40),
                          side: const BorderSide(color: warningRed, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
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
    ).whenComplete(() {
      if (!mounted) return;
      setState(() {
        item.isSelected = false;
        _activeItem = null;
      });
    });
  }

  /// 태그 번호 칸(좁은 화면 편집창). 비우면 없앤다.
  Widget _buildTagField(PlacedItem item, TextEditingController ctrl) {
    return TextField(
      key: const ValueKey("item_tag_field"),
      controller: ctrl,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: tossText,
      ),
      decoration: InputDecoration(
        labelText: "태그 번호 (PT-101 같은 것, 비워도 됨)",
        labelStyle: const TextStyle(
          color: tossSubText,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        floatingLabelStyle: const TextStyle(
          color: tossBlue,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
        filled: true,
        fillColor: tossBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: (val) =>
          setState(() => item.tag = val.trim().isEmpty ? null : val.trim()),
    );
  }

  // 모듈 이름 밑 한 줄: 캐비닛은 깊이, 스키드는 바닥에서 높이.
  String? _itemCaption(PlacedItem item) {
    final double? v = _isSkid ? item.elevation : item.depth;
    if (v == null) return null;
    return "${_isSkid ? "높이" : "깊이"} ${v.toInt()}";
  }

  // 깊이 칸: 빈칸이면 모름(null), 숫자면 mm.
  String _depthText(double? d) => d == null
      ? ""
      : (d == d.roundToDouble() ? d.toInt().toString() : d.toString());

  double? _parseDepth(String v) {
    // "1,200"·"12,5"도 읽는다(10-08: 높이가 지워져 바닥에 놓였다).
    final d = parseNumberText(v);
    return d == null || d <= 0 ? null : d;
  }

  InputDecoration _inspectorFieldDecoration() => InputDecoration(
    filled: true,
    fillColor: tossBg,
    isDense: false,
    constraints: const BoxConstraints(minHeight: 52),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: layoutLine),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: layoutLine),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: tossBlue, width: 2),
    ),
  );

  Widget _buildCoordinateInput(
    String label,
    String value,
    Function(String) onChanged, {
    TextEditingController? controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: tossSubText,
          ),
        ),
        const SizedBox(height: 8),
        // 칸을 떠나면(다른 칸을 누르면) 바로 넣는다. 예전에는 키보드 "완료"를 눌러야만 들어가서,
        // 다른 칸을 누르면 친 값이 버려지고 X·Y 칸은 다시 그릴 때 친 글자가 사라졌다(10-07).
        _InspectorNumberField(
          value: controller?.text ?? value,
          controller: controller,
          onCommit: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: tossBg,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

// 부품 편집 창의 숫자 입력 칸(크기·위치).
// 예전엔 그릴 때마다 입력 칸을 새로 만들어서, 값을 치다가 다른 칸을 누르면 친 값이 사라졌다.
// 이제 칸 하나를 계속 쓰고, 완료를 누르거나 다른 곳을 누를 때(포커스가 빠질 때) 값을 넣는다.
class _InspectorNumberField extends StatefulWidget {
  final String value;
  final void Function(String) onCommit;
  final InputDecoration decoration;

  /// 바깥에서 읽는 칸(창의 "확인"이 이 글을 읽는 경우)이면 그 컨트롤러를 그대로 쓴다.
  final TextEditingController? controller;

  const _InspectorNumberField({
    required this.value,
    required this.onCommit,
    required this.decoration,
    this.controller,
  });

  @override
  State<_InspectorNumberField> createState() => _InspectorNumberFieldState();
}

class _InspectorNumberFieldState extends State<_InspectorNumberField> {
  late final TextEditingController _ctrl =
      widget.controller ?? TextEditingController(text: widget.value);
  late String _committed = widget.value;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      // 화면에서 빠지는 중(폭이 바뀌어 칸이 사라지거나 화면을 닫음)에는 넣지 않는다.
      if (!_focus.hasFocus && mounted && _active) _commit();
    });
  }

  bool _active = true;

  @override
  void deactivate() {
    _active = false;
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _active = true;
  }

  @override
  void didUpdateWidget(covariant _InspectorNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 치는 중이 아닐 때만 바깥 값(끌어서 옮긴 위치, 되돌리기 등)을 따라간다.
    if (!_focus.hasFocus &&
        widget.controller == null &&
        _ctrl.text != widget.value) {
      _ctrl.text = widget.value;
    }
    if (!_focus.hasFocus) _committed = _ctrl.text;
  }

  void _commit() {
    if (_ctrl.text.trim().isEmpty) {
      _ctrl.text = _committed;
      return;
    }
    if (_ctrl.text != _committed) {
      _committed = _ctrl.text;
      widget.onCommit(_ctrl.text);
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      focusNode: _focus,
      keyboardType: TextInputType.number,
      onSubmitted: (_) => _commit(),
      onTapOutside: (_) => _focus.unfocus(),
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: tossText,
      ),
      decoration: widget.decoration,
    );
  }
}
