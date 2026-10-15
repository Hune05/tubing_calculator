// 작업 배치도 화면 — 치수선.
// layout_board_page.dart의 _LayoutBoardPageState를 역할별로 나눈 part(10-13). 동작은 같다.
// setState는 State 밖(확장)에서 부르면 보호 멤버 경고가 나지만, 이 확장은 그 State 자신이다.
// ignore_for_file: invalid_use_of_protected_member
part of '../layout_board_page.dart';

extension _LayoutBoardDimensions on _LayoutBoardPageState {
  void _handleDimensionPoint(MeasurePoint point) {
    setState(() {
      if (_dimensionStartPoint == null) {
        _dimensionStartPoint = point;
      } else {
        if (_dimensionStartPoint!.id != point.id) {
          // 🚀 [버그 수정] type을 비교 조건에서 빼먹어서, 같은 두 지점을
          // "센터 기준"으로 한 번 측정하고 나면 "측면 기준"으로는 다시
          // 측정이 안 되고 아무 반응 없이 무시되던 문제. 이게 마치 "첫
          // 치수가 고정되어 안 바뀐다"처럼 보였던 원인이었다. 이제는
          // 같은 두 지점이라도 기준(type)이 다르면 별도 치수로 추가된다.
          bool exists = _dimensions.any(
            (dim) =>
                dim.type == _currentDimType &&
                dim.isDiagonal == _dimensionDiagonalMode &&
                ((dim.p1.id == _dimensionStartPoint!.id &&
                        dim.p2.id == point.id) ||
                    (dim.p1.id == point.id &&
                        dim.p2.id == _dimensionStartPoint!.id)),
          );

          if (!exists) {
            _pushUndo();
            _dimensions.add(
              PlacedDimension(
                id: newLayoutId(),
                p1: _dimensionStartPoint!,
                p2: point,
                type: _currentDimType,
                isDiagonal: _dimensionDiagonalMode,
              ),
            );
            HapticFeedback.heavyImpact();
          }
        }
        // 🚀 체인 모드면 방금 찍은 점을 다음 구간의 시작점으로 그대로
        // 이어가서 계속 탭하는 것만으로 연속 치수선이 만들어지게 한다.
        _dimensionStartPoint = _dimensionChainMode
            ? point
            : (_dimensionBaselineMode ? _dimensionStartPoint : null);
      }
    });
  }

  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final Offset ab = b - a;
    final double abLenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (abLenSq == 0) return (p - a).distance;
    double t = ((p - a).dx * ab.dx + (p - a).dy * ab.dy) / abLenSq;
    t = t.clamp(0.0, 1.0);
    final Offset proj = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
    return (p - proj).distance;
  }

  // 🚀 [신규] 번호 배지(치수선의 p1 지점에 그려짐)는 선 자체보다 좀 더
  // 넉넉한 반경으로 우선 인식해서, 목록표에서 확인한 번호를 도면에서
  // 다시 찾아 탭할 때 더 잘 잡히게 한다.
  PlacedDimension? _findDimensionNear(Offset pos) {
    const double segmentTolerance = 14.0;
    const double badgeTolerance = 16.0;
    PlacedDimension? closest;
    double closestDist = double.infinity;
    for (final dim in _dimensions) {
      final endpoints = computeDimensionEndpoints(dim);
      final double badgeDist = (pos - endpoints.p1).distance;
      if (badgeDist <= badgeTolerance && badgeDist < closestDist) {
        closestDist = badgeDist;
        closest = dim;
        continue;
      }
      final double segDist = _distanceToSegment(
        pos,
        endpoints.p1,
        endpoints.p2,
      );
      if (segDist <= segmentTolerance && segDist < closestDist) {
        closestDist = segDist;
        closest = dim;
      }
    }
    return closest;
  }

  // 🚀 [신규] 치수선 하나를 탭했을 때 - 삭제/기준 전환/메모/최소 간격
  // 설정을 한 곳에서 처리하는 바텀시트.
  void _showDimensionActionsSheet(PlacedDimension dim) {
    // 🚀 이 창 안에서 기준/메모/최소 간격을 몇 번을 고치든, 열기 직전
    // 상태 하나만 기억해서 "편집 취소"가 한 번에 되게 한다(모듈 편집
    // 바텀시트와 동일 원칙).
    _pushUndo();
    final TextEditingController noteCtrl = TextEditingController(
      text: dim.note ?? "",
    );
    final TextEditingController minGapCtrl = TextEditingController(
      text: dim.minGapMm != null ? dim.minGapMm!.toInt().toString() : "",
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final endpoints = computeDimensionEndpoints(dim);
            return SingleChildScrollView(
              child: Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  top: 16,
                  left: 24,
                  right: 24,
                ),
                decoration: const BoxDecoration(
                  color: pureWhite,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBottomSheetHandle(),
                    Text(
                      "치수선 - ${endpoints.distance.round()} mm",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: tossText,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "측정 기준",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: tossSubText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDimTypeChoiceChip(
                            "센터 기준",
                            DimensionType.center,
                            dim,
                            setModalState,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildDimTypeChoiceChip(
                            "측면 기준",
                            DimensionType.edge,
                            dim,
                            setModalState,
                          ),
                        ),
                      ],
                    ),
                    // 10-15 통일: 칸 이름은 테두리 위, 테두리·바탕은 테마 기본
                    const SizedBox(height: 26),
                    TextField(
                      controller: noteCtrl,
                      style: const TextStyle(fontSize: 14, color: tossText),
                      decoration: const InputDecoration(
                        labelText: "메모",
                        hintText: "예: 케이블 트레이 통과 구간",
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (v) {
                        setState(() {
                          dim.note = v.trim().isEmpty ? null : v.trim();
                          _dimensionsVersion++;
                        });
                      },
                    ),
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: minGapCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              fontSize: 14,
                              color: tossText,
                            ),
                            // 10-15 통일: 칸 이름은 테두리 위, 풀이는 칸 아래
                            decoration: const InputDecoration(
                              labelText: "최소 유지 간격 (mm)",
                              helperText: "이보다 좁으면 경고 표시",
                              hintText: "예: 30",
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                            onChanged: (v) {
                              final parsed = parseNumberText(v);
                              setState(() {
                                dim.minGapMm = parsed;
                                _dimensionsVersion++;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            minGapCtrl.clear();
                            setModalState(() {});
                            setState(() {
                              dim.minGapMm = null;
                              _dimensionsVersion++;
                            });
                          },
                          child: const Text(
                            "해제",
                            style: TextStyle(
                              color: tossSubText,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // 🚀 [신규] 자주 쓰는 최소 간격값을 바로 고를 수 있는
                    // 프리셋 칩.
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [20, 30, 50, 100].map((v) {
                        final bool selected = dim.minGapMm == v.toDouble();
                        return GestureDetector(
                          onTap: () {
                            minGapCtrl.text = v.toString();
                            setModalState(() {});
                            setState(() {
                              dim.minGapMm = v.toDouble();
                              _dimensionsVersion++;
                            });
                          },
                          child: Container(
                            constraints: const BoxConstraints(
                              minHeight: 48,
                              minWidth: 64,
                            ),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            // 10-15 통일: 고른 값은 옅은 청록 + ✓ + 짙은 청록 글자
                            decoration: BoxDecoration(
                              color: selected ? pickFill() : pureWhite,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: selected ? pickLine() : pickIdleLine(),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (selected) ...[
                                  pickCheck(),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  "${v}mm",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: selected ? pickInk() : tossSubText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    // 🚀 [신규] 대각선 모드 - 이 치수를 축 정렬 없이 두
                    // 중심점 사이 실제 직선거리+각도로 바꾼다.
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: dim.isDiagonal,
                      activeThumbColor: diagonalDimColor,
                      onChanged: (v) {
                        setState(() {
                          dim.isDiagonal = v;
                          _dimensionsVersion++;
                        });
                        setModalState(() {});
                      },
                      title: const Text(
                        "대각선 모드",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: tossText,
                        ),
                      ),
                      subtitle: Text(
                        keepWords("축에 맞추지 않고 실제 직선거리+각도로 표시"),
                        style: TextStyle(fontSize: 14, color: tossSubText),
                      ),
                    ),
                    // 🚀 [신규] 안전 이격거리 등 규정과 관련된 중요한
                    // 치수선을 굵은 선 + 방패 아이콘으로 강조 표시한다.
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: dim.isSafetyCritical,
                      activeThumbColor: warningRed,
                      onChanged: (v) {
                        setState(() {
                          dim.isSafetyCritical = v;
                          _dimensionsVersion++;
                        });
                        setModalState(() {});
                      },
                      title: const Text(
                        "안전 이격거리로 강조 표시",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: tossText,
                        ),
                      ),
                      subtitle: Text(
                        keepWords("굵은 선 + 🛡 표시로 다른 치수와 구분"),
                        style: TextStyle(fontSize: 14, color: tossSubText),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _pushUndo();
                          setState(() {
                            _dimensions.removeWhere((d) => d.id == dim.id);
                          });
                          Navigator.pop(context);
                        },
                        icon: const Icon(
                          Icons.delete_outline,
                          color: warningRed,
                        ),
                        label: const Text(
                          "이 치수선 삭제",
                          style: TextStyle(
                            color: warningRed,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(40, 40),
                          side: const BorderSide(color: warningRed),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDimTypeChoiceChip(
    String label,
    DimensionType type,
    PlacedDimension dim,
    StateSetter setModalState,
  ) {
    final bool selected = dim.type == type;
    final Color color = type == DimensionType.center
        ? centerDimColor
        : edgeDimColor;
    return GestureDetector(
      onTap: () {
        setState(() {
          dim.type = type;
          _dimensionsVersion++;
        });
        setModalState(() {});
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : tossBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1.4,
          ),
        ),
        // 10-15 통일: 고른 쪽에 ✓. 색은 도면 치수선 색(센터·측면)과 같아야 해서 그대로 둔다.
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check_rounded, size: 15, color: color),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? color : tossSubText,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClearDimensions() async {
    final ok = await confirmLayoutDanger(
      context,
      title: "치수선 전체 지우기",
      message:
          "치수선 ${_dimensions.length}개를 모두 지웁니다. 부품은 그대로 둡니다. 지운 뒤에도 되돌리기로 돌아올 수 있습니다.",
      confirmLabel: "전체 지우기",
    );
    if (!ok || !mounted) return;
    _pushUndo();
    setState(() {
      _dimensions.clear();
      _dimensionStartPoint = null;
      _dimensionsVersion++;
    });
  }

  // 체인과 기준점은 같이 켤 수 없다(둘 다 "다음 점" 규칙이라 하나만).
  void _toggleChainMode() => setState(() {
    _dimensionChainMode = !_dimensionChainMode;
    if (_dimensionChainMode) _dimensionBaselineMode = false;
  });

  void _toggleBaselineMode() => setState(() {
    _dimensionBaselineMode = !_dimensionBaselineMode;
    if (_dimensionBaselineMode) _dimensionChainMode = false;
    if (!_dimensionBaselineMode) _dimensionStartPoint = null;
  });

  // 치수 재기 안내 한 줄(좁은 화면 아래 칸과 넓은 화면 오른쪽 칸이 같이 쓴다).
  String _dimensionHint() {
    if (_dimensionStartPoint != null && _dimensionBaselineMode) {
      return "기준점: 다음 지점마다 기준점에서 측정한 치수가 하나씩 생깁니다. '첫 지점 취소'로 기준을 풉니다.";
    }
    if (_dimensionStartPoint != null) return "다음 지점을 누르면 치수선이 이어집니다.";
    if (_dimensionChainMode) return "체인: 지점을 계속 누르면 이어서 측정합니다.";
    if (_dimensionBaselineMode) {
      return "기준점: 처음 누른 지점이 기준으로 남고, 다음 지점마다 치수가 생깁니다.";
    }
    return "측정할 두 지점(부품 또는 벽면)을 차례로 누르십시오. 치수선을 누르면 고칩니다.";
  }

  // 좁은 화면 치수 재기 도구: 기준·체인·대각선 단추 한 줄 + 안내 + 첫 지점 취소.
  // 치수선 전체 지우기는 위 막대 "더보기"의 빨간 칸으로 옮겼다(확인을 받는다).
  Widget _buildDimensionToolBar() {
    final bool isCenter = _currentDimType == DimensionType.center;
    return Column(
      key: const ValueKey("dimension"),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              flex: 4,
              child: _toolToggle(
                icon: Icons.sync_alt_rounded,
                label: isCenter ? "센터 기준" : "측면 기준",
                selected: true,
                color: isCenter ? centerDimColor : edgeDimColor,
                onTap: () => setState(() {
                  _currentDimType = isCenter
                      ? DimensionType.edge
                      : DimensionType.center;
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: _toolToggle(
                icon: Icons.link_rounded,
                label: "체인",
                selected: _dimensionChainMode,
                color: tossBlue,
                onTap: _toggleChainMode,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: _toolToggle(
                icon: Icons.push_pin_outlined,
                label: "기준점",
                selected: _dimensionBaselineMode,
                color: tossBlue,
                onTap: _toggleBaselineMode,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: _toolToggle(
                icon: Icons.turn_slight_right_rounded,
                label: "대각선",
                selected: _dimensionDiagonalMode,
                color: diagonalDimColor,
                onTap: () => setState(
                  () => _dimensionDiagonalMode = !_dimensionDiagonalMode,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                keepWords(_dimensionHint()),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: tossSubText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
            // 첫 지점을 잘못 찍었을 때 두 번째 지점을 억지로 찍지 않고 취소한다.
            if (_dimensionStartPoint != null)
              TextButton.icon(
                onPressed: () => setState(() => _dimensionStartPoint = null),
                style: TextButton.styleFrom(
                  minimumSize: const Size(40, 40),
                  foregroundColor: tossText,
                ),
                icon: const Icon(Icons.undo_rounded, size: 22),
                label: const Text(
                  "첫 지점 취소",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
