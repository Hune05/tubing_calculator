import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

// ---------------------------------------------------------
// 🎨 토스(Toss) 디자인 시스템 색상
// ---------------------------------------------------------
const Color tossBlue = Color(0xFF3182F6);
const Color tossText = Color(0xFF191F28);
const Color tossSubText = Color(0xFF8B95A1);
const Color tossBg = Color(0xFFF2F4F6);
const Color pureWhite = Color(0xFFFFFFFF);
const Color warningRed = Color(0xFFF04438);
const Color dimensionColor = Color(0xFF00C471);
const Color guideColor = tossBlue;

// ---------------------------------------------------------
// 1. 데이터 모델
// ---------------------------------------------------------
abstract class MeasurePoint {
  Offset get center;
  String get id;
}

class PlacedItem implements MeasurePoint {
  @override
  final String id;
  String name;
  Offset position;
  double width;
  double height;
  bool isSelected;

  PlacedItem({
    required this.id,
    required this.name,
    required this.position,
    this.width = 80.0,
    this.height = 80.0,
    this.isSelected = false,
  });

  @override
  Offset get center =>
      Offset(position.dx + width / 2, position.dy + height / 2);
}

class WallPoint implements MeasurePoint {
  @override
  final String id;
  final Offset position;

  WallPoint({required this.position})
    : id = "wall_${position.dx}_${position.dy}";

  @override
  Offset get center => position;
}

class CenterDimension {
  final String id;
  final MeasurePoint p1;
  final MeasurePoint p2;

  CenterDimension({required this.id, required this.p1, required this.p2});
}

// ---------------------------------------------------------
// 2. 메인 페이지 화면 (Tablet Layout)
// ---------------------------------------------------------
class TabletLayoutBoardPage extends StatefulWidget {
  const TabletLayoutBoardPage({super.key});

  @override
  State<TabletLayoutBoardPage> createState() => _TabletLayoutBoardPageState();
}

class _TabletLayoutBoardPageState extends State<TabletLayoutBoardPage> {
  double _panelWidth = 600.0;
  double _panelHeight = 800.0;

  // 🚀 [핵심] 스냅 단위를 5mm로 초정밀화
  final double _gridSize = 5.0;

  bool _isDimensionMode = false;

  final List<PlacedItem> _placedItems = [];
  final List<CenterDimension> _dimensions = [];

  MeasurePoint? _dimensionStartPoint;
  PlacedItem? _selectedItem;
  Offset _dragRawPosition = Offset.zero;

  final GlobalKey _boardKey = GlobalKey();

  // 🚀 스냅 헬퍼 함수 (이제 5mm 단위로 움직임)
  Offset _snapToGrid(Offset offset) {
    double dx = (offset.dx / _gridSize).round() * _gridSize;
    double dy = (offset.dy / _gridSize).round() * _gridSize;
    return Offset(dx, dy);
  }

  void _clearBoard() {
    setState(() {
      _placedItems.clear();
      _dimensions.clear();
      _dimensionStartPoint = null;
      _selectedItem = null;
    });
  }

  void _onAcceptItem(String defaultName, Offset localPosition) {
    HapticFeedback.mediumImpact();
    setState(() {
      for (var item in _placedItems) item.isSelected = false;

      final newItem = PlacedItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: defaultName,
        position: _snapToGrid(localPosition),
        isSelected: true,
      );
      _placedItems.add(newItem);
      _selectedItem = newItem;
    });
  }

  WallPoint _getNearestWallPoint(Offset touchPosition) {
    double distLeft = touchPosition.dx;
    double distRight = _panelWidth - touchPosition.dx;
    double distTop = touchPosition.dy;
    double distBottom = _panelHeight - touchPosition.dy;

    double minDist = [
      distLeft,
      distRight,
      distTop,
      distBottom,
    ].reduce(math.min);

    Offset wallPos;
    if (minDist == distLeft) {
      wallPos = Offset(0, touchPosition.dy);
    } else if (minDist == distRight) {
      wallPos = Offset(_panelWidth, touchPosition.dy);
    } else if (minDist == distTop) {
      wallPos = Offset(touchPosition.dx, 0);
    } else {
      wallPos = Offset(touchPosition.dx, _panelHeight);
    }

    return WallPoint(position: _snapToGrid(wallPos));
  }

  void _handleDimensionPoint(MeasurePoint point) {
    setState(() {
      if (_dimensionStartPoint == null) {
        _dimensionStartPoint = point;
      } else {
        if (_dimensionStartPoint!.id != point.id) {
          bool exists = _dimensions.any(
            (dim) =>
                (dim.p1.id == _dimensionStartPoint!.id &&
                    dim.p2.id == point.id) ||
                (dim.p1.id == point.id &&
                    dim.p2.id == _dimensionStartPoint!.id),
          );

          if (!exists) {
            _dimensions.add(
              CenterDimension(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                p1: _dimensionStartPoint!,
                p2: point,
              ),
            );
            HapticFeedback.heavyImpact();
          }
        }
        _dimensionStartPoint = null;
      }
    });
  }

  void _onTapItem(PlacedItem item) {
    HapticFeedback.lightImpact();
    if (_isDimensionMode) {
      _handleDimensionPoint(item);
    } else {
      setState(() {
        for (var i in _placedItems) i.isSelected = false;
        item.isSelected = true;
        _selectedItem = item;
      });
    }
  }

  void _onTapBoard(Offset localPosition) {
    if (_isDimensionMode) {
      HapticFeedback.lightImpact();
      WallPoint nearestWall = _getNearestWallPoint(localPosition);
      _handleDimensionPoint(nearestWall);
    } else {
      setState(() {
        for (var i in _placedItems) i.isSelected = false;
        _selectedItem = null;
      });
    }
  }

  // 외함 크기 설정 팝업 (태블릿용 Dialog)
  void _showPanelSettingsDialog() {
    final widthCtrl = TextEditingController(
      text: _panelWidth.toInt().toString(),
    );
    final heightCtrl = TextEditingController(
      text: _panelHeight.toInt().toString(),
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: pureWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            "전체 외함 크기 설정",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: tossText,
              letterSpacing: -0.5,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "실제 중판(캐비닛)의 사이즈를 mm 단위로 입력하세요.",
                style: TextStyle(color: tossSubText, fontSize: 14),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _buildInputBox("가로 (W)", widthCtrl)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildInputBox("세로 (H)", heightCtrl)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "취소",
                style: TextStyle(
                  color: tossSubText,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _panelWidth = double.tryParse(widthCtrl.text) ?? 600.0;
                  _panelHeight = double.tryParse(heightCtrl.text) ?? 800.0;
                  _dimensions.removeWhere(
                    (dim) => dim.p1 is WallPoint || dim.p2 is WallPoint,
                  );
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: tossBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "적용",
                style: TextStyle(color: pureWhite, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInputBox(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: tossSubText,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller
            ..selection = TextSelection.collapsed(
              offset: controller.text.length,
            ),
          keyboardType: TextInputType.number,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: tossText,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: tossBg,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------
  // 3. UI 컴포넌트 빌드
  // ---------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tossBg,
      appBar: AppBar(
        backgroundColor: pureWhite,
        elevation: 0,
        title: const Text(
          "스마트 패널 설계 도면",
          style: TextStyle(
            color: tossText,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            tooltip: "외함 사이즈 설정",
            onPressed: _showPanelSettingsDialog,
            icon: const Icon(Icons.aspect_ratio_rounded, color: tossText),
          ),
          TextButton.icon(
            onPressed: _clearBoard,
            icon: const Icon(
              Icons.refresh_rounded,
              color: warningRed,
              size: 18,
            ),
            label: const Text(
              "도면 초기화",
              style: TextStyle(color: warningRed, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        children: [
          _buildLeftSidebar(),
          Expanded(child: _buildMainBoard()),
          _buildRightInspector(),
        ],
      ),
    );
  }

  Widget _buildLeftSidebar() {
    return Container(
      width: 240,
      color: pureWhite,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: tossBg.withValues(alpha: 0.5),
            child: const Text(
              "자재 라이브러리",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: tossText,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Draggable<String>(
                  data: "신규 박스",
                  feedback: Material(
                    color: Colors.transparent,
                    child: Opacity(
                      opacity: 0.8,
                      child: _buildPaletteItem("드래그 중.."),
                    ),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.3,
                    child: _buildPaletteItem("배치 중"),
                  ),
                  child: _buildPaletteItem("신규 박스 모듈"),
                ),
                const SizedBox(height: 16),
                const Text(
                  "위 박스를 우측 도면으로 드래그하여 배치하세요.\n배치 후 터치하면 우측 패널에서 명칭과 크기를 수정할 수 있습니다.",
                  style: TextStyle(
                    color: tossSubText,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaletteItem(String defaultName) {
    return Container(
      width: double.infinity,
      height: 90,
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tossBlue.withValues(alpha: 0.4), width: 2),
        boxShadow: [
          BoxShadow(
            color: tossBlue.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_box_rounded, color: tossBlue, size: 28),
            const SizedBox(height: 6),
            Text(
              defaultName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: tossBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainBoard() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: pureWhite,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text(
                      "모듈 배치/이동",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    icon: Icon(Icons.pan_tool_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text(
                      "센터 치수 측정",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    icon: Icon(Icons.straighten_rounded, size: 16),
                  ),
                ],
                selected: {_isDimensionMode},
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith<Color>((
                    Set<WidgetState> states,
                  ) {
                    if (states.contains(WidgetState.selected)) return tossText;
                    return pureWhite;
                  }),
                  foregroundColor: WidgetStateProperty.resolveWith<Color>((
                    Set<WidgetState> states,
                  ) {
                    if (states.contains(WidgetState.selected)) return pureWhite;
                    return tossText;
                  }),
                ),
                onSelectionChanged: (Set<bool> newSelection) {
                  setState(() {
                    _isDimensionMode = newSelection.first;
                    _dimensionStartPoint = null;
                    for (var i in _placedItems) i.isSelected = false;
                    _selectedItem = null;
                  });
                },
              ),
              const SizedBox(width: 16),
              if (_isDimensionMode && _dimensions.isNotEmpty)
                TextButton.icon(
                  onPressed: () => setState(() => _dimensions.clear()),
                  icon: const Icon(
                    Icons.cleaning_services_rounded,
                    size: 16,
                    color: warningRed,
                  ),
                  label: const Text(
                    "치수 삭제",
                    style: TextStyle(
                      color: warningRed,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // 도면 캔버스
        Expanded(
          child: InteractiveViewer(
            minScale: 0.1,
            maxScale: 4.0,
            boundaryMargin: const EdgeInsets.all(2000),
            child: Center(
              child: DragTarget<String>(
                onAcceptWithDetails: (details) {
                  final RenderBox box =
                      _boardKey.currentContext!.findRenderObject() as RenderBox;
                  _onAcceptItem(
                    details.data,
                    box.globalToLocal(details.offset),
                  );
                },
                builder: (context, candidateData, rejectedData) {
                  return Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      GestureDetector(
                        onTapUp: (details) =>
                            _onTapBoard(details.localPosition),
                        child: Container(
                          key: _boardKey,
                          width: _panelWidth,
                          height: _panelHeight,
                          decoration: BoxDecoration(
                            color: pureWhite,
                            border: Border.all(color: tossText, width: 3),
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
                              CustomPaint(
                                size: Size.infinite,
                                painter: GridPainter(gridSize: _gridSize),
                              ),

                              CustomPaint(
                                size: Size.infinite,
                                painter: CenterDimensionPainter(
                                  dimensions: _dimensions,
                                  activePoint: _dimensionStartPoint,
                                ),
                              ),

                              if (_selectedItem != null && !_isDimensionMode)
                                CustomPaint(
                                  size: Size.infinite,
                                  painter: SmartGuidePainter(
                                    item: _selectedItem!,
                                    allItems: _placedItems,
                                    panelWidth: _panelWidth,
                                    panelHeight: _panelHeight,
                                  ),
                                ),

                              ..._placedItems.map((item) {
                                return Positioned(
                                  left: item.position.dx,
                                  top: item.position.dy,
                                  child: GestureDetector(
                                    onPanStart: !_isDimensionMode
                                        ? (details) {
                                            setState(() {
                                              _dragRawPosition = item.position;
                                              _selectedItem = item;
                                              for (var i in _placedItems)
                                                i.isSelected = false;
                                              item.isSelected = true;
                                            });
                                          }
                                        : null,
                                    onPanUpdate: !_isDimensionMode
                                        ? (details) {
                                            setState(() {
                                              _dragRawPosition += details.delta;
                                              double clampedX = _dragRawPosition
                                                  .dx
                                                  .clamp(
                                                    0,
                                                    _panelWidth - item.width,
                                                  );
                                              double clampedY = _dragRawPosition
                                                  .dy
                                                  .clamp(
                                                    0,
                                                    _panelHeight - item.height,
                                                  );
                                              item.position = _snapToGrid(
                                                Offset(clampedX, clampedY),
                                              );
                                            });
                                          }
                                        : null,
                                    onTap: () => _onTapItem(item),
                                    child: _buildBoardItem(item),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: -30,
                        child: Text(
                          "W: ${_panelWidth.toInt()} mm",
                          style: TextStyle(
                            color: Colors.blueGrey.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Positioned(
                        left: -80,
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: Text(
                            "H: ${_panelHeight.toInt()} mm",
                            style: TextStyle(
                              color: Colors.blueGrey.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBoardItem(PlacedItem item) {
    bool isMeasuringStart =
        _isDimensionMode && _dimensionStartPoint?.id == item.id;

    return Container(
      width: item.width,
      height: item.height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isMeasuringStart ? tossBlue.withValues(alpha: 0.1) : pureWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isMeasuringStart
              ? tossBlue
              : (item.isSelected ? tossBlue : Colors.blueGrey.shade300),
          width: isMeasuringStart || item.isSelected ? 3 : 1.5,
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
          item.name,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: isMeasuringStart || item.isSelected ? tossBlue : tossText,
            height: 1.2,
            letterSpacing: -0.3,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildRightInspector() {
    return Container(
      width: 320,
      color: pureWhite,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: tossBg.withValues(alpha: 0.5),
            child: const Text(
              "정밀 제어 패널",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: tossText,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _selectedItem == null
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Text(
                          "도면에서 모듈을 선택하면\n상세 수치를 조절할 수 있습니다.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: tossSubText, height: 1.5),
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "모듈 명칭 (라벨)",
                          style: TextStyle(
                            color: tossSubText,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller:
                              TextEditingController(text: _selectedItem!.name)
                                ..selection = TextSelection.collapsed(
                                  offset: _selectedItem!.name.length,
                                ),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: tossText,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: tossBg,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (val) => setState(
                            () => _selectedItem!.name = val.isEmpty
                                ? "이름 없음"
                                : val,
                          ),
                        ),
                        const SizedBox(height: 28),

                        const Text(
                          "모듈 크기 (W x H)",
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
                              child: _buildInspectorInput(
                                "가로 (mm)",
                                _selectedItem!.width.toInt().toString(),
                                (val) {
                                  setState(
                                    () => _selectedItem!.width =
                                        (double.tryParse(val) ?? 80.0),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildInspectorInput(
                                "세로 (mm)",
                                _selectedItem!.height.toInt().toString(),
                                (val) {
                                  setState(
                                    () => _selectedItem!.height =
                                        (double.tryParse(val) ?? 80.0),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),
                        const Text(
                          "절대 위치 (X, Y)",
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
                              child: _buildInspectorInput(
                                "X (mm)",
                                _selectedItem!.position.dx.toInt().toString(),
                                (val) {
                                  setState(
                                    () => _selectedItem!.position = Offset(
                                      (double.tryParse(val) ?? 0),
                                      _selectedItem!.position.dy,
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildInspectorInput(
                                "Y (mm)",
                                _selectedItem!.position.dy.toInt().toString(),
                                (val) {
                                  setState(
                                    () => _selectedItem!.position = Offset(
                                      _selectedItem!.position.dx,
                                      (double.tryParse(val) ?? 0),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 40),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _dimensions.removeWhere(
                                  (dim) =>
                                      dim.p1.id == _selectedItem!.id ||
                                      dim.p2.id == _selectedItem!.id,
                                );
                                _placedItems.remove(_selectedItem);
                                if (_dimensionStartPoint?.id ==
                                    _selectedItem!.id)
                                  _dimensionStartPoint = null;
                                _selectedItem = null;
                              });
                            },
                            icon: const Icon(
                              Icons.delete_outline,
                              color: warningRed,
                            ),
                            label: const Text(
                              "모듈 삭제",
                              style: TextStyle(
                                color: warningRed,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: warningRed,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInspectorInput(
    String label,
    String value,
    Function(String) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: tossSubText,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: TextEditingController(text: value)
            ..selection = TextSelection.collapsed(offset: value.length),
          keyboardType: TextInputType.number,
          onSubmitted: onChanged,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: tossText,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: tossBg,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------
// Helper Painters
// ---------------------------------------------------------

class SmartGuidePainter extends CustomPainter {
  final PlacedItem item;
  final List<PlacedItem> allItems;
  final double panelWidth;
  final double panelHeight;

  SmartGuidePainter({
    required this.item,
    required this.allItems,
    required this.panelWidth,
    required this.panelHeight,
  });

  void _drawGuideLine(
    Canvas canvas,
    Offset start,
    Offset end,
    double distance,
  ) {
    if (distance <= 2) return;

    final linePaint = Paint()
      ..color = guideColor.withValues(alpha: 0.6)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(start, end, linePaint);

    // 🚀 [수정] 5mm 스냅으로 인해 10mm 이상일 때부터 텍스트 표시
    if (distance >= 10) {
      final textSpan = TextSpan(
        text: "${distance.toInt()} mm",
        style: const TextStyle(
          color: pureWhite,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      final centerOffset = Offset(
        (start.dx + end.dx) / 2,
        (start.dy + end.dy) / 2,
      );

      final bgRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: centerOffset,
          width: textPainter.width + 16,
          height: textPainter.height + 10,
        ),
        const Radius.circular(12),
      );
      canvas.drawRRect(bgRect, Paint()..color = guideColor);
      textPainter.paint(
        canvas,
        Offset(
          centerOffset.dx - textPainter.width / 2,
          centerOffset.dy - textPainter.height / 2,
        ),
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    double left = item.position.dx;
    double right = item.position.dx + item.width;
    double top = item.position.dy;
    double bottom = item.position.dy + item.height;
    double cx = item.center.dx;
    double cy = item.center.dy;

    double boundLeft = 0;
    double boundRight = panelWidth;
    double boundTop = 0;
    double boundBottom = panelHeight;

    for (var other in allItems) {
      if (other.id == item.id) continue;
      double oLeft = other.position.dx;
      double oRight = other.position.dx + other.width;
      double oTop = other.position.dy;
      double oBottom = other.position.dy + other.height;

      if ((left < oRight) && (right > oLeft)) {
        if (oBottom <= top && oBottom > boundTop) boundTop = oBottom;
        if (oTop >= bottom && oTop < boundBottom) boundBottom = oTop;
      }
      if ((top < oBottom) && (bottom > oTop)) {
        if (oRight <= left && oRight > boundLeft) boundLeft = oRight;
        if (oLeft >= right && oLeft < boundRight) boundRight = oLeft;
      }
    }

    _drawGuideLine(
      canvas,
      Offset(cx, top),
      Offset(cx, boundTop),
      top - boundTop,
    );
    _drawGuideLine(
      canvas,
      Offset(cx, bottom),
      Offset(cx, boundBottom),
      boundBottom - bottom,
    );
    _drawGuideLine(
      canvas,
      Offset(left, cy),
      Offset(boundLeft, cy),
      left - boundLeft,
    );
    _drawGuideLine(
      canvas,
      Offset(right, cy),
      Offset(boundRight, cy),
      boundRight - right,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// 🚀 [핵심] 실제 엔지니어링 모눈종이처럼 렌더링 (5mm 얇게, 25mm 굵게)
class GridPainter extends CustomPainter {
  final double gridSize;
  GridPainter({required this.gridSize});

  @override
  void paint(Canvas canvas, Size size) {
    // 5mm 마다 그려질 얇은 선
    final lightPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 0.5;
    // 25mm (5칸) 마다 그려질 굵은 선
    final boldPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1.2;

    for (double i = 0; i <= size.width; i += gridSize) {
      bool isMajor = (i % (gridSize * 5) == 0);
      canvas.drawLine(
        Offset(i, 0),
        Offset(i, size.height),
        isMajor ? boldPaint : lightPaint,
      );
    }
    for (double i = 0; i <= size.height; i += gridSize) {
      bool isMajor = (i % (gridSize * 5) == 0);
      canvas.drawLine(
        Offset(0, i),
        Offset(size.width, i),
        isMajor ? boldPaint : lightPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CenterDimensionPainter extends CustomPainter {
  final List<CenterDimension> dimensions;
  final MeasurePoint? activePoint;

  CenterDimensionPainter({required this.dimensions, this.activePoint});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = dimensionColor.withValues(alpha: 0.8)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()..color = dimensionColor;

    for (var dim in dimensions) {
      Offset c1 = dim.p1.center;
      Offset c2 = dim.p2.center;

      double dx = (c1.dx - c2.dx).abs();
      double dy = (c1.dy - c2.dy).abs();
      if (dx > dy) {
        c2 = Offset(c2.dx, c1.dy);
      } else {
        c2 = Offset(c1.dx, c2.dy);
      }

      canvas.drawLine(c1, c2, linePaint);
      canvas.drawCircle(c1, 4, dotPaint);
      canvas.drawCircle(c2, 4, dotPaint);

      double distance = (c1 - c2).distance;
      if (distance >= 10) {
        final textSpan = TextSpan(
          text: "${distance.toInt()} mm",
          style: const TextStyle(
            color: pureWhite,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        );

        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();
        final centerOffset = Offset((c1.dx + c2.dx) / 2, (c1.dy + c2.dy) / 2);

        final bgRect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: centerOffset,
            width: textPainter.width + 16,
            height: textPainter.height + 10,
          ),
          const Radius.circular(12),
        );
        canvas.drawRRect(bgRect, Paint()..color = dimensionColor);
        textPainter.paint(
          canvas,
          Offset(
            centerOffset.dx - textPainter.width / 2,
            centerOffset.dy - textPainter.height / 2,
          ),
        );
      }
    }

    if (activePoint != null && activePoint is WallPoint) {
      canvas.drawCircle(
        activePoint!.center,
        6,
        Paint()..color = dimensionColor,
      );
      canvas.drawCircle(
        activePoint!.center,
        16,
        Paint()
          ..color = dimensionColor.withValues(alpha: 0.2)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
