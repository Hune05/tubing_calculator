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
// 🚀 [수정] 수동 측정(센터)이 녹색, 자동 가이드(센터)가 파란색으로
// 서로 달라 헷갈렸음. "센터"는 수동/자동 어디서나 항상 파란색으로 통일.
const Color centerDimColor = tossBlue; // 센터 기준: 파란색(자동 가이드와 통일)
const Color edgeDimColor = Color(0xFFF68657); // 측면 기준: 주황색
const Color guideColor = tossBlue;
const Color tubingLineColor = Color(0xFFFF6B35); // 정밀 튜빙 라인: 주황-레드

// ---------------------------------------------------------
// 1. 데이터 모델
// ---------------------------------------------------------

// 🚀 [추가] 도면 보드의 3가지 작업 모드
enum BoardMode { placeModule, measureDimension, drawTubing }

// 🚀 [추가] 치수 측정 기준 (모바일과 동일하게 센터/측면 두 가지 지원)
enum DimensionType { center, edge }

abstract class MeasurePoint {
  Offset get center;
  Rect get boundingBox;
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

  @override
  Rect get boundingBox =>
      Rect.fromLTWH(position.dx, position.dy, width, height);
}

class WallPoint implements MeasurePoint {
  @override
  final String id;
  final Offset position;

  WallPoint({required this.position})
    : id = "wall_${position.dx}_${position.dy}";

  @override
  Offset get center => position;

  @override
  Rect get boundingBox => Rect.fromLTWH(position.dx, position.dy, 0, 0);
}

class PlacedDimension {
  final String id;
  final MeasurePoint p1;
  final MeasurePoint p2;
  final DimensionType type;

  PlacedDimension({
    required this.id,
    required this.p1,
    required this.p2,
    required this.type,
  });
}

// 🚀 [추가] 실제 배관으로 도면에 남는 정밀 튜빙 라인 (여러 구간/꺾임 가능)
class PlacedTubingLine {
  final String id;
  final List<Offset> points;

  PlacedTubingLine({required this.id, required this.points});

  double get totalLength {
    double total = 0;
    for (int i = 0; i < points.length - 1; i++) {
      total += (points[i + 1] - points[i]).distance;
    }
    return total;
  }
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

  BoardMode _mode = BoardMode.placeModule;
  DimensionType _currentDimType = DimensionType.center;
  // 🚀 [추가] 모듈 배치/이동 중 자동으로 뜨는 가이드선을 모드 전환 없이
  // 그때그때 켜고 끌 수 있는 토글. 센터선/외곽선은 독립적으로 켤 수
  // 있어서 둘 다 동시에 볼 수도 있다.
  bool _showCenterGuide = true;
  bool _showEdgeGuide = false;

  final List<PlacedItem> _placedItems = [];
  final List<PlacedDimension> _dimensions = [];
  // 🚀 [추가] 완료되어 저장된 튜빙 라인들과, 지금 찍고 있는 중인 임시 경로
  final List<PlacedTubingLine> _tubingLines = [];
  List<Offset> _tubingDraftPoints = [];

  MeasurePoint? _dimensionStartPoint;
  PlacedItem? _selectedItem;
  // 🚀 [추가] 사이드바에서 새 모듈을 도면 위로 끌고 오는 중에도 미리보기와
  // 가이드선을 보여주기 위한 임시 아이템(모바일과 동일)
  PlacedItem? _previewItem;
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
      _tubingLines.clear();
      _tubingDraftPoints = [];
      _dimensionStartPoint = null;
      _selectedItem = null;
    });
  }

  // 🚀 [추가] 튜빙 라인 그리기 모드에서 점 추가/실행취소/완료/취소
  void _addTubingPoint(Offset point) {
    HapticFeedback.lightImpact();
    setState(() {
      Offset snapped = _snapToGrid(point);
      if (_tubingDraftPoints.isNotEmpty) {
        // 🚀 실제 배관은 대각선으로 가지 않고 직각으로 꺾이므로, 이전
        // 지점 기준으로 수평/수직 중 더 가까운 축에 자동으로 맞춘다.
        final prev = _tubingDraftPoints.last;
        final dx = (snapped.dx - prev.dx).abs();
        final dy = (snapped.dy - prev.dy).abs();
        snapped = dx >= dy
            ? Offset(snapped.dx, prev.dy)
            : Offset(prev.dx, snapped.dy);
      }
      _tubingDraftPoints = [..._tubingDraftPoints, snapped];
    });
  }

  void _undoTubingPoint() {
    if (_tubingDraftPoints.isEmpty) return;
    setState(() {
      _tubingDraftPoints = _tubingDraftPoints.sublist(
        0,
        _tubingDraftPoints.length - 1,
      );
    });
  }

  void _finishTubingLine() {
    if (_tubingDraftPoints.length < 2) return;
    setState(() {
      _tubingLines.add(
        PlacedTubingLine(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          points: _tubingDraftPoints,
        ),
      );
      _tubingDraftPoints = [];
    });
    HapticFeedback.heavyImpact();
  }

  void _cancelTubingDraft() {
    setState(() {
      _tubingDraftPoints = [];
    });
  }

  void _deleteTubingLine(String id) {
    setState(() {
      _tubingLines.removeWhere((line) => line.id == id);
    });
  }

  void _onAcceptItem(String defaultName, Offset localPosition) {
    HapticFeedback.mediumImpact();
    setState(() {
      for (var item in _placedItems) item.isSelected = false;

      double clampedX = localPosition.dx.clamp(
        0.0,
        math.max(0.0, _panelWidth - 80.0),
      );
      double clampedY = localPosition.dy.clamp(
        0.0,
        math.max(0.0, _panelHeight - 80.0),
      );

      final newItem = PlacedItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: defaultName,
        position: _snapToGrid(Offset(clampedX, clampedY)),
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
              PlacedDimension(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                p1: _dimensionStartPoint!,
                p2: point,
                type: _currentDimType,
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
    if (_mode == BoardMode.measureDimension) {
      _handleDimensionPoint(item);
    } else if (_mode == BoardMode.drawTubing) {
      // 튜빙 라인 그리기 중엔 모듈을 탭하면 그 모듈의 중심에 정확히 붙는다
      _addTubingPoint(item.center);
    } else {
      setState(() {
        for (var i in _placedItems) i.isSelected = false;
        item.isSelected = true;
        _selectedItem = item;
      });
    }
  }

  void _onTapBoard(Offset localPosition) {
    if (_mode == BoardMode.measureDimension) {
      HapticFeedback.lightImpact();
      WallPoint nearestWall = _getNearestWallPoint(localPosition);
      _handleDimensionPoint(nearestWall);
    } else if (_mode == BoardMode.drawTubing) {
      _addTubingPoint(localPosition);
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
            child: Padding(
              padding: const EdgeInsets.all(16),
              // 🚀 [수정] 항목이 딱 2개(박스 1개 + 안내문)뿐이라 스크롤이
              // 필요 없는데도 ListView를 써서, 세로 드래그 제스처를 리스트
              // 스크롤이 항상 먼저 가로채 모듈이 전혀 드래그되지 않는
              // 문제가 있었다(실기기 태블릿에서 확인됨). 스크롤이 필요
              // 없는 Column으로 바꿔 이 제스처 경합 자체를 없앤다.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
          ),
        ],
      ),
    );
  }

  Widget _buildPaletteItem(String defaultName) {
    // 🚀 [수정] width: double.infinity였는데, 사이드바 안에서는 부모
    // Column의 stretch 정렬로 어차피 꽉 차 보여서 문제없었지만, 이
    // 위젯을 Draggable의 feedback(드래그 중 화면에 떠다니는 복사본)으로
    // 쓰면 Overlay가 무한 폭 제약을 줘서 "BoxConstraints forces an
    // infinite width" 예외가 터지고 그 뒤로 레이아웃이 전부 깨져 드래그
    // 자체가 동작하지 않았다(실기기 로그로 확인). 고정 폭으로 바꾸면
    // 사이드바에서도(부모가 stretch라 그대로 꽉 차 보임) feedback으로
    // 써도 둘 다 문제없다.
    return Container(
      width: 208,
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

  // 🚀 [추가] 센터선/외곽선 토글에 따라 최대 2개(둘 다 켜면 동시에)의
  // 가이드선 페인터를 만들어준다.
  List<Widget> _buildGuidePaints(PlacedItem item) {
    return [
      if (_showCenterGuide)
        CustomPaint(
          size: Size.infinite,
          painter: SmartGuidePainter(
            item: item,
            allItems: _placedItems,
            panelWidth: _panelWidth,
            panelHeight: _panelHeight,
            currentType: DimensionType.center,
          ),
        ),
      if (_showEdgeGuide)
        CustomPaint(
          size: Size.infinite,
          painter: SmartGuidePainter(
            item: item,
            allItems: _placedItems,
            panelWidth: _panelWidth,
            panelHeight: _panelHeight,
            currentType: DimensionType.edge,
          ),
        ),
    ];
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
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SegmentedButton<BoardMode>(
                  segments: const [
                    ButtonSegment(
                      value: BoardMode.placeModule,
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
                      value: BoardMode.measureDimension,
                      label: Text(
                        "고정 치수 측정",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      icon: Icon(Icons.straighten_rounded, size: 16),
                    ),
                    ButtonSegment(
                      value: BoardMode.drawTubing,
                      label: Text(
                        "정밀 튜빙 라인",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      icon: Icon(Icons.timeline_rounded, size: 16),
                    ),
                  ],
                  selected: {_mode},
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
                  onSelectionChanged: (Set<BoardMode> newSelection) {
                    setState(() {
                      _mode = newSelection.first;
                      _dimensionStartPoint = null;
                      _tubingDraftPoints = [];
                      for (var i in _placedItems) i.isSelected = false;
                      _selectedItem = null;
                    });
                  },
                ),
                Container(
                  height: 32,
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: Colors.grey.shade300,
                ),
                // 🚀 [수정] 가이드선 토글을 별도 그룹으로 시각적으로 묶어서
                // "모드 선택"과 구분되는 하나의 컨트롤 묶음으로 읽히게 함
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: tossBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(
                          Icons.visibility_outlined,
                          size: 16,
                          color: tossSubText,
                        ),
                      ),
                      FilterChip(
                        label: const Text("센터선"),
                        selected: _showCenterGuide,
                        selectedColor: guideColor.withValues(alpha: 0.15),
                        checkmarkColor: guideColor,
                        backgroundColor: pureWhite,
                        side: BorderSide.none,
                        labelStyle: TextStyle(
                          color: _showCenterGuide ? guideColor : tossSubText,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (val) =>
                            setState(() => _showCenterGuide = val),
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: const Text("외곽선"),
                        selected: _showEdgeGuide,
                        selectedColor: edgeDimColor.withValues(alpha: 0.15),
                        checkmarkColor: edgeDimColor,
                        backgroundColor: pureWhite,
                        side: BorderSide.none,
                        labelStyle: TextStyle(
                          color: _showEdgeGuide ? edgeDimColor : tossSubText,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (val) =>
                            setState(() => _showEdgeGuide = val),
                      ),
                    ],
                  ),
                ),
                if (_mode == BoardMode.measureDimension &&
                    _dimensions.isNotEmpty) ...[
                  const SizedBox(width: 16),
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
              ],
            ),
          ),
        ),

        // 도면 캔버스
        Expanded(
          // 🚀 실제 드래그 불가 원인은 팔레트 아이템의 width:double.infinity가
          // Draggable feedback으로 쓰일 때 무한 폭 제약 크래시를 일으킨
          // 것이었음(_buildPaletteItem에서 수정). 그 크래시가 원인이었으므로
          // InteractiveViewer(핀치줌)는 원래대로 되돌린다.
          child: InteractiveViewer(
            minScale: 0.1,
            maxScale: 4.0,
            boundaryMargin: const EdgeInsets.all(2000),
            child: Center(
            child: DragTarget<String>(
                onMove: (details) {
                  final RenderBox box =
                      _boardKey.currentContext!.findRenderObject() as RenderBox;
                  Offset localPos = box.globalToLocal(details.offset);
                  double clampedX = localPos.dx.clamp(
                    0.0,
                    math.max(0.0, _panelWidth - 80.0),
                  );
                  double clampedY = localPos.dy.clamp(
                    0.0,
                    math.max(0.0, _panelHeight - 80.0),
                  );
                  setState(() {
                    _previewItem = PlacedItem(
                      id: 'preview',
                      name: details.data,
                      position: _snapToGrid(Offset(clampedX, clampedY)),
                      width: 80,
                      height: 80,
                    );
                  });
                },
                onLeave: (data) => setState(() => _previewItem = null),
                onAcceptWithDetails: (details) {
                  final RenderBox box =
                      _boardKey.currentContext!.findRenderObject() as RenderBox;
                  _onAcceptItem(
                    details.data,
                    box.globalToLocal(details.offset),
                  );
                  setState(() => _previewItem = null);
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
                                painter: DimensionPainter(
                                  dimensions: _dimensions,
                                  activePoint: _dimensionStartPoint,
                                ),
                              ),
                              CustomPaint(
                                size: Size.infinite,
                                painter: TubingLinePainter(
                                  lines: _tubingLines,
                                  draftPoints: _tubingDraftPoints,
                                ),
                              ),

                              if (_selectedItem != null &&
                                  _mode == BoardMode.placeModule)
                                ..._buildGuidePaints(_selectedItem!),

                              if (_previewItem != null &&
                                  _mode == BoardMode.placeModule) ...[
                                ..._buildGuidePaints(_previewItem!),
                                Positioned(
                                  left: _previewItem!.position.dx,
                                  top: _previewItem!.position.dy,
                                  child: Opacity(
                                    opacity: 0.5,
                                    child: _buildBoardItem(_previewItem!),
                                  ),
                                ),
                              ],

                              ..._placedItems.map((item) {
                                return Positioned(
                                  left: item.position.dx,
                                  top: item.position.dy,
                                  child: GestureDetector(
                                    onPanStart: _mode == BoardMode.placeModule
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
                                    onPanUpdate: _mode == BoardMode.placeModule
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
        _mode == BoardMode.measureDimension &&
        _dimensionStartPoint?.id == item.id;

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
              child: _mode == BoardMode.drawTubing
                  ? _buildTubingInspector()
                  : _mode == BoardMode.measureDimension
                  ? _buildDimensionInspector()
                  : _selectedItem == null
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
                                  setState(() {
                                    _selectedItem!.width =
                                        (double.tryParse(val) ?? 80.0);
                                    _selectedItem!.position = Offset(
                                      _selectedItem!.position.dx.clamp(
                                        0.0,
                                        math.max(
                                          0.0,
                                          _panelWidth - _selectedItem!.width,
                                        ),
                                      ),
                                      _selectedItem!.position.dy,
                                    );
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildInspectorInput(
                                "세로 (mm)",
                                _selectedItem!.height.toInt().toString(),
                                (val) {
                                  setState(() {
                                    _selectedItem!.height =
                                        (double.tryParse(val) ?? 80.0);
                                    _selectedItem!.position = Offset(
                                      _selectedItem!.position.dx,
                                      _selectedItem!.position.dy.clamp(
                                        0.0,
                                        math.max(
                                          0.0,
                                          _panelHeight - _selectedItem!.height,
                                        ),
                                      ),
                                    );
                                  });
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
                                  setState(() {
                                    double newX = double.tryParse(val) ?? 0;
                                    _selectedItem!.position = Offset(
                                      newX.clamp(
                                        0.0,
                                        math.max(
                                          0.0,
                                          _panelWidth - _selectedItem!.width,
                                        ),
                                      ),
                                      _selectedItem!.position.dy,
                                    );
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildInspectorInput(
                                "Y (mm)",
                                _selectedItem!.position.dy.toInt().toString(),
                                (val) {
                                  setState(() {
                                    double newY = double.tryParse(val) ?? 0;
                                    _selectedItem!.position = Offset(
                                      _selectedItem!.position.dx,
                                      newY.clamp(
                                        0.0,
                                        math.max(
                                          0.0,
                                          _panelHeight - _selectedItem!.height,
                                        ),
                                      ),
                                    );
                                  });
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

  // 🚀 [추가] 고정 치수 측정 컨트롤(우측 패널) - 모바일과 동일하게
  // 센터/측면 기준을 전환할 수 있다.
  Widget _buildDimensionInspector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "측정 기준",
          style: TextStyle(
            color: tossText,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text("센터(중심) 기준"),
              selected: _currentDimType == DimensionType.center,
              selectedColor: centerDimColor.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: _currentDimType == DimensionType.center
                    ? centerDimColor
                    : tossSubText,
                fontWeight: FontWeight.bold,
              ),
              onSelected: (val) {
                setState(() => _currentDimType = DimensionType.center);
              },
            ),
            ChoiceChip(
              label: const Text("측면(여백) 기준"),
              selected: _currentDimType == DimensionType.edge,
              selectedColor: edgeDimColor.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: _currentDimType == DimensionType.edge
                    ? edgeDimColor
                    : tossSubText,
                fontWeight: FontWeight.bold,
              ),
              onSelected: (val) {
                setState(() => _currentDimType = DimensionType.edge);
              },
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          _dimensionStartPoint == null
              ? "💡 측정할 두 지점(모듈 or 벽면)을 순서대로 도면에서 탭하세요."
              : "💡 다음 측정 지점을 탭하면 치수선이 연결됩니다.",
          style: TextStyle(
            color: _dimensionStartPoint == null
                ? tossSubText
                : (_currentDimType == DimensionType.center
                      ? centerDimColor
                      : edgeDimColor),
            fontSize: 13,
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _currentDimType == DimensionType.center
              ? "⚠️ 현재 '센터(중앙점)' 간의 거리를 측정 중입니다."
              : "⚠️ 현재 박스 '끝단(측면/여백)' 간의 거리를 측정 중입니다.",
          style: TextStyle(
            color: _currentDimType == DimensionType.center
                ? centerDimColor
                : edgeDimColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (_dimensions.isNotEmpty) ...[
          const SizedBox(height: 28),
          Row(
            children: [
              const Text(
                "배치된 치수선",
                style: TextStyle(
                  color: tossText,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _dimensions.clear()),
                child: const Text(
                  "전체 삭제",
                  style: TextStyle(
                    color: warningRed,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // 🚀 [추가] 정밀 튜빙 라인 그리기 컨트롤(우측 패널)
  Widget _buildTubingInspector() {
    final double draftLength = _tubingDraftPoints.length < 2
        ? 0
        : PlacedTubingLine(id: 'draft', points: _tubingDraftPoints).totalLength;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _tubingDraftPoints.isEmpty
              ? "💡 튜빙 라인이 지날 지점들을 순서대로 도면에서 탭하세요. 꺾이는 지점마다 탭하면 되고, 항상 직각(수평/수직)으로 자동 정렬됩니다."
              : "💡 다음 지점을 계속 탭해서 이어가거나, 완료를 눌러 확정하세요.\n(현재 ${_tubingDraftPoints.length}개 지점, ${draftLength.toInt()} mm)",
          style: TextStyle(
            color: _tubingDraftPoints.isEmpty ? tossSubText : tubingLineColor,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Tooltip(
              message: "마지막 지점 실행 취소",
              child: OutlinedButton(
                onPressed: _tubingDraftPoints.isEmpty
                    ? null
                    : _undoTubingPoint,
                style: OutlinedButton.styleFrom(
                  foregroundColor: tossText,
                  side: BorderSide(color: Colors.grey.shade300),
                  padding: const EdgeInsets.all(12),
                  minimumSize: const Size(44, 44),
                ),
                child: const Icon(Icons.undo_rounded, size: 18),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _tubingDraftPoints.isEmpty
                    ? null
                    : _cancelTubingDraft,
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text("취소"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: warningRed,
                  side: const BorderSide(color: warningRed),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _tubingDraftPoints.length < 2
                ? null
                : _finishTubingLine,
            icon: const Icon(Icons.check_rounded, size: 16, color: pureWhite),
            label: const Text("완료", style: TextStyle(color: pureWhite)),
            style: ElevatedButton.styleFrom(backgroundColor: tubingLineColor),
          ),
        ),
        if (_tubingLines.isNotEmpty) ...[
          const SizedBox(height: 28),
          Row(
            children: [
              const Text(
                "배치된 튜빙 라인",
                style: TextStyle(
                  color: tossText,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _tubingLines.clear()),
                child: const Text(
                  "전체 삭제",
                  style: TextStyle(
                    color: warningRed,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          ..._tubingLines.asMap().entries.map((entry) {
            final index = entry.key;
            final line = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: tubingLineColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Text(
                    "${index + 1} · ${line.totalLength.toInt()} mm",
                    style: const TextStyle(
                      color: tubingLineColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () => _deleteTubingLine(line.id),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: tubingLineColor,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
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

// 🚀 [수정] 산업 도면(CAD)처럼 얇은 치수선 + 끝단 눈금 + 항상 보이는
// 라벨로 통일. 예전엔 두꺼운 색상 알약(pill) 라벨이 10mm 미만
// 거리에서는 아예 안 보였는데, 라벨을 선 옆으로 살짝 띄워서 거리와
// 무관하게 항상 표시되게 한다.
void drawCadDimensionLine(
  Canvas canvas,
  Offset start,
  Offset end,
  double distance,
  Color color,
  String prefix,
) {
  if (distance < 1) return; // 사실상 붙어있으면 표시할 게 없음

  final linePaint = Paint()
    ..color = color
    ..strokeWidth = 1.3
    ..style = PaintingStyle.stroke;
  canvas.drawLine(start, end, linePaint);

  final dx = end.dx - start.dx;
  final dy = end.dy - start.dy;
  final len = math.sqrt(dx * dx + dy * dy);
  final double px = len == 0 ? 0 : -dy / len;
  final double py = len == 0 ? 0 : dx / len;

  // 끝단 눈금(CAD 치수선의 tick mark)
  final tick = Offset(px, py) * 5;
  canvas.drawLine(start - tick, start + tick, linePaint);
  canvas.drawLine(end - tick, end + tick, linePaint);

  final mid = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
  final label = mid + Offset(px, py) * 15;

  final textSpan = TextSpan(
    text: "$prefix ${distance.toInt()} mm",
    style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800),
  );
  final textPainter = TextPainter(
    text: textSpan,
    textDirection: TextDirection.ltr,
  )..layout();

  final bgRect = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: label,
      width: textPainter.width + 10,
      height: textPainter.height + 6,
    ),
    const Radius.circular(4),
  );
  canvas.drawLine(
    mid,
    label,
    Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 1,
  );
  canvas.drawRRect(bgRect, Paint()..color = pureWhite);
  canvas.drawRRect(
    bgRect,
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1,
  );
  textPainter.paint(
    canvas,
    Offset(label.dx - textPainter.width / 2, label.dy - textPainter.height / 2),
  );
}

// 🚀 [수정] 모바일과 동일하게 센터/측면 기준을 전환할 수 있도록 확장
class SmartGuidePainter extends CustomPainter {
  final PlacedItem item;
  final List<PlacedItem> allItems;
  final double panelWidth;
  final double panelHeight;
  final DimensionType currentType;

  SmartGuidePainter({
    required this.item,
    required this.allItems,
    required this.panelWidth,
    required this.panelHeight,
    required this.currentType,
  });

  void _drawGuideLine(
    Canvas canvas,
    Offset start,
    Offset end,
    double distance,
    Color color,
    String prefix,
  ) {
    drawCadDimensionLine(canvas, start, end, distance, color, prefix);
  }

  @override
  void paint(Canvas canvas, Size size) {
    Color c = currentType == DimensionType.center ? guideColor : edgeDimColor;
    String p = currentType == DimensionType.center ? "센터" : "측면";

    double left = item.position.dx;
    double right = item.position.dx + item.width;
    double top = item.position.dy;
    double bottom = item.position.dy + item.height;
    double cx = item.center.dx;
    double cy = item.center.dy;

    double bL = 0, bR = panelWidth, bT = 0, bB = panelHeight;

    for (var other in allItems) {
      if (other.id == item.id) continue;
      double oLeft = other.position.dx;
      double oRight = other.position.dx + other.width;
      double oTop = other.position.dy;
      double oBottom = other.position.dy + other.height;

      bool hitVerticalRay = (cx >= oLeft) && (cx <= oRight);
      if (hitVerticalRay) {
        if (currentType == DimensionType.center) {
          if (other.center.dy <= cy && other.center.dy > bT) bT = other.center.dy;
          if (other.center.dy >= cy && other.center.dy < bB) bB = other.center.dy;
        } else {
          if (oBottom <= top && oBottom > bT) bT = oBottom;
          if (oTop >= bottom && oTop < bB) bB = oTop;
        }
      }

      bool hitHorizontalRay = (cy >= oTop) && (cy <= oBottom);
      if (hitHorizontalRay) {
        if (currentType == DimensionType.center) {
          if (other.center.dx <= cx && other.center.dx > bL) bL = other.center.dx;
          if (other.center.dx >= cx && other.center.dx < bR) bR = other.center.dx;
        } else {
          if (oRight <= left && oRight > bL) bL = oRight;
          if (oLeft >= right && oLeft < bR) bR = oLeft;
        }
      }
    }

    if (currentType == DimensionType.center) {
      _drawGuideLine(canvas, Offset(cx, cy), Offset(cx, bT), (cy - bT).abs(), c, p);
      _drawGuideLine(canvas, Offset(cx, cy), Offset(cx, bB), (bB - cy).abs(), c, p);
      _drawGuideLine(canvas, Offset(cx, cy), Offset(bL, cy), (cx - bL).abs(), c, p);
      _drawGuideLine(canvas, Offset(cx, cy), Offset(bR, cy), (bR - cx).abs(), c, p);
    } else {
      _drawGuideLine(canvas, Offset(cx, top), Offset(cx, bT), (top - bT).abs(), c, p);
      _drawGuideLine(canvas, Offset(cx, bottom), Offset(cx, bB), (bB - bottom).abs(), c, p);
      _drawGuideLine(canvas, Offset(left, cy), Offset(bL, cy), (left - bL).abs(), c, p);
      _drawGuideLine(canvas, Offset(right, cy), Offset(bR, cy), (bR - right).abs(), c, p);
    }
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

// 🚀 [수정] 모바일과 동일하게 센터/측면 두 기준의 치수선을 지원
class DimensionPainter extends CustomPainter {
  final List<PlacedDimension> dimensions;
  final MeasurePoint? activePoint;

  DimensionPainter({required this.dimensions, this.activePoint});

  @override
  void paint(Canvas canvas, Size size) {
    for (var dim in dimensions) {
      Color dColor = dim.type == DimensionType.center
          ? centerDimColor
          : edgeDimColor;
      String labelPrefix = dim.type == DimensionType.center ? "센터" : "측면";

      Rect r1 = dim.p1.boundingBox;
      Rect r2 = dim.p2.boundingBox;

      double dxCenter = (r1.center.dx - r2.center.dx).abs();
      double dyCenter = (r1.center.dy - r2.center.dy).abs();

      Offset startPt, endPt;
      double distance = 0;

      if (dim.type == DimensionType.center) {
        startPt = r1.center;
        endPt = r2.center;
        if (dxCenter > dyCenter) {
          endPt = Offset(endPt.dx, startPt.dy);
        } else {
          endPt = Offset(startPt.dx, endPt.dy);
        }
        distance = (startPt - endPt).distance;
      } else {
        if (dxCenter > dyCenter) {
          bool isR1Left = r1.center.dx < r2.center.dx;
          double x1 = isR1Left ? r1.right : r1.left;
          double x2 = isR1Left ? r2.left : r2.right;
          double y = (r1.center.dy + r2.center.dy) / 2;
          startPt = Offset(x1, y);
          endPt = Offset(x2, y);
          distance = (x1 - x2).abs();
        } else {
          bool isR1Top = r1.center.dy < r2.center.dy;
          double y1 = isR1Top ? r1.bottom : r1.top;
          double y2 = isR1Top ? r2.top : r2.bottom;
          double x = (r1.center.dx + r2.center.dx) / 2;
          startPt = Offset(x, y1);
          endPt = Offset(x, y2);
          distance = (y1 - y2).abs();
        }
      }

      drawCadDimensionLine(
        canvas,
        startPt,
        endPt,
        distance,
        dColor,
        labelPrefix,
      );
    }

    if (activePoint != null && activePoint is WallPoint) {
      canvas.drawCircle(activePoint!.center, 6, Paint()..color = tossText);
      canvas.drawCircle(
        activePoint!.center,
        16,
        Paint()
          ..color = tossText.withValues(alpha: 0.2)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// 🚀 [추가] 실제 배관으로 남는 정밀 튜빙 라인(여러 구간) 렌더링
class TubingLinePainter extends CustomPainter {
  final List<PlacedTubingLine> lines;
  final List<Offset> draftPoints;

  TubingLinePainter({required this.lines, required this.draftPoints});

  Offset _pointAtArcMidpoint(List<Offset> points, double totalLength) {
    if (totalLength <= 0) return points.first;
    double target = totalLength / 2;
    double accumulated = 0;
    for (int i = 0; i < points.length - 1; i++) {
      final segLength = (points[i + 1] - points[i]).distance;
      if (accumulated + segLength >= target) {
        final t = segLength == 0 ? 0.0 : (target - accumulated) / segLength;
        return Offset.lerp(points[i], points[i + 1], t)!;
      }
      accumulated += segLength;
    }
    return points.last;
  }

  void _drawPath(
    Canvas canvas,
    Size boardSize,
    List<Offset> points, {
    required bool isDraft,
  }) {
    if (points.isEmpty) return;

    final linePaint = Paint()
      ..color = tubingLineColor.withValues(alpha: isDraft ? 0.5 : 0.9)
      ..strokeWidth = isDraft ? 3.0 : 5.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final dotPaint = Paint()..color = tubingLineColor;

    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], linePaint);
    }
    for (final p in points) {
      canvas.drawCircle(p, isDraft ? 4 : 5, dotPaint);
    }

    if (!isDraft && points.length >= 2) {
      double total = 0;
      for (int i = 0; i < points.length - 1; i++) {
        total += (points[i + 1] - points[i]).distance;
      }
      final textSpan = TextSpan(
        text: "${total.toInt()} mm",
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

      final labelW = textPainter.width + 16;
      final labelH = textPainter.height + 10;
      final rawMid = _pointAtArcMidpoint(points, total);
      final mid = Offset(
        rawMid.dx.clamp(
          labelW / 2,
          math.max(labelW / 2, boardSize.width - labelW / 2),
        ),
        rawMid.dy.clamp(
          labelH / 2,
          math.max(labelH / 2, boardSize.height - labelH / 2),
        ),
      );

      final bgRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: mid, width: labelW, height: labelH),
        const Radius.circular(12),
      );
      canvas.drawRRect(bgRect, Paint()..color = tubingLineColor);
      textPainter.paint(
        canvas,
        Offset(mid.dx - textPainter.width / 2, mid.dy - textPainter.height / 2),
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final line in lines) {
      _drawPath(canvas, size, line.points, isDraft: false);
    }
    _drawPath(canvas, size, draftPoints, isDraft: true);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
