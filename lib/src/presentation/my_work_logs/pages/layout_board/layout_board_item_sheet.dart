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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.15),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
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
              // 🚀 [버그 수정] 편집창에 버튼이 계속 늘어나면서(회전/복제/
              // 프리셋 저장/잠금/레이어 순서까지) 키보드가 뜨면 남는
              // 세로 공간이 부족해 화면 밖으로 넘치는 오버플로우가 났다 -
              // 스크롤 가능하게 감싸서 내용이 많아도 넘치지 않고 스크롤
              // 되게 한다.
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
                    const SizedBox(height: 20),

                    if (_canFlip(item)) ...[
                      // 그림이 있는 부품은 좌우를 뒤집을 수 있다(부속은 허브 방향, 엘보·밸브는 나사 방향).
                      ElevatedButton.icon(
                        key: const ValueKey("flip_button"),
                        onPressed: () {
                          _flipItem(item);
                          setModalState(() {});
                        },
                        icon: const Icon(
                          Icons.flip_rounded,
                          size: 18,
                          color: tossBlue,
                        ),
                        label: Text(
                          SkidShape.isFitting(item.shape)
                              ? "좌우 뒤집기 (허브 반대쪽)"
                              : "좌우 뒤집기",
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
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    // 🚀 [여기가 핵심 추가본입니다] 회전 & 복사 버튼
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // 90° 회전: 가로·세로를 바꾸고 각도 칸도 90 더한다(넓은 화면과 같은 함수).
                              _rotateItem(item);
                              // 바텀시트의 텍스트 필드 값도 함께 업데이트
                              setModalState(() {
                                widthCtrl.text = item.width.toInt().toString();
                                heightCtrl.text = item.height
                                    .toInt()
                                    .toString();
                              });
                            },
                            icon: const Icon(
                              Icons.rotate_90_degrees_cw_rounded,
                              size: 18,
                              color: tossBlue,
                            ),
                            label: const Text(
                              "90° 회전",
                              style: TextStyle(
                                color: tossBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(40, 40),
                              backgroundColor: tossBlue.withValues(alpha: 0.1),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // 부품 복제(되돌리기 한 번으로 돌아간다)
                              _duplicateItem(item);
                              Navigator.pop(context); // 복제 후 창 닫기

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
                            icon: const Icon(
                              Icons.content_copy_rounded,
                              size: 18,
                              color: tossText,
                            ),
                            label: const Text(
                              "부품 복제",
                              style: TextStyle(
                                color: tossText,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(40, 40),
                              backgroundColor: tossBg,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 🚀 [신규] 레이어 순서(앞/뒤) 조정 - 모듈이 서로 겹칠 때
                    // 어느 것이 위로 보일지 정할 수 있게 한다. 리스트 맨
                    // 뒤에 있을수록 화면 맨 위에 그려진다.
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _placedItems.remove(item);
                                _placedItems.add(item);
                              });
                              setModalState(() {});
                              HapticFeedback.lightImpact();
                            },
                            icon: const Icon(
                              Icons.flip_to_front_rounded,
                              size: 18,
                              color: tossText,
                            ),
                            label: const Text(
                              "맨 앞으로",
                              style: TextStyle(
                                color: tossText,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(40, 40),
                              side: BorderSide(
                                color: tossText.withValues(alpha: 0.2),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _placedItems.remove(item);
                                _placedItems.insert(0, item);
                              });
                              setModalState(() {});
                              HapticFeedback.lightImpact();
                            },
                            icon: const Icon(
                              Icons.flip_to_back_rounded,
                              size: 18,
                              color: tossText,
                            ),
                            label: const Text(
                              "맨 뒤로",
                              style: TextStyle(
                                color: tossText,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(40, 40),
                              side: BorderSide(
                                color: tossText.withValues(alpha: 0.2),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 🚀 [신규] 지금 이 모듈의 이름/크기를 "내 프리셋"으로
                    // 저장 - 다음 도면에서 팔레트에서 바로 드래그해 쓸 수
                    // 있다(예: 자주 쓰는 차단기 규격).
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () {
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
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.star_border_rounded,
                          size: 18,
                          color: tossBlue,
                        ),
                        label: const Text(
                          "이 크기를 내 프리셋으로 저장",
                          style: TextStyle(
                            color: tossBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    // 🚀 [신규] 위치가 확정된 모듈을 잠가서 실수로 드래그해
                    // 옮겨지지 않게 한다.
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() => item.isLocked = !item.isLocked);
                          setModalState(() {});
                          HapticFeedback.lightImpact();
                        },
                        icon: Icon(
                          item.isLocked
                              ? Icons.lock_rounded
                              : Icons.lock_open_rounded,
                          size: 18,
                          color: item.isLocked ? warningRed : tossSubText,
                        ),
                        label: Text(
                          item.isLocked ? "잠금 해제" : "이 부품 위치 잠그기",
                          style: TextStyle(
                            color: item.isLocked ? warningRed : tossSubText,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
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
                      _buildRailLengthHint(item, () {
                        setModalState(() {
                          widthCtrl.text = item.width.toInt().toString();
                          heightCtrl.text = item.height.toInt().toString();
                        });
                      })!,
                    ],
                    const SizedBox(height: 28),
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
                    const SizedBox(height: 16),
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
                    const SizedBox(height: 28),
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
                            (val) {
                              setState(() {
                                double newX =
                                    parseNumberText(val) ?? item.position.dx;
                                item.position = Offset(
                                  newX.clamp(
                                    0.0,
                                    math.max(0.0, _panelWidth - item.width),
                                  ),
                                  item.position.dy,
                                );
                              });
                              setModalState(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildCoordinateInput(
                            "Y 좌표 (mm)",
                            item.position.dy.toInt().toString(),
                            (val) {
                              setState(() {
                                double newY =
                                    parseNumberText(val) ?? item.position.dy;
                                item.position = Offset(
                                  item.position.dx,
                                  newY.clamp(
                                    0.0,
                                    math.max(0.0, _panelHeight - item.height),
                                  ),
                                );
                              });
                              setModalState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
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
