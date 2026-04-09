import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart' as vmath;
import 'package:shared_preferences/shared_preferences.dart'; // 🚀 SharedPreferences 추가

const Color makitaTeal = Color(0xFF007580);

// 🚀 기존 태블릿 코드와 충돌하지 않도록 독립적인 모바일 전용 클래스 생성
class MobilePipeVisualizer extends StatefulWidget {
  final List<Map<String, dynamic>> bendList;
  final double tailLength;
  final int? selectedSegmentIndex;
  final String initialStartDir;
  final ValueChanged<String>? onStartDirChanged;
  final bool isLightMode;
  final bool startFit;
  final bool endFit;

  // 🚀 앞서 추가했던 총 컷팅 기장 변수
  final double totalCutLength;

  const MobilePipeVisualizer({
    super.key,
    required this.bendList,
    this.tailLength = 0.0,
    this.selectedSegmentIndex,
    this.initialStartDir = 'RIGHT',
    this.onStartDirChanged,
    this.isLightMode = false,
    this.startFit = false,
    this.endFit = false,
    this.totalCutLength = 0.0,
  });

  @override
  State<MobilePipeVisualizer> createState() => _MobilePipeVisualizerState();
}

class _MobilePipeVisualizerState extends State<MobilePipeVisualizer> {
  static const double _defaultRotX = -math.pi / 6;
  static const double _defaultRotY = -math.pi / 4;

  double _rotationX = _defaultRotX;
  double _rotationY = _defaultRotY;
  double _zoomLevel = 1.0;
  double _baseZoom = 1.0;

  double _panX = 0.0;
  double _panY = 0.0;

  bool _isFlippedX = false;
  bool _isFlippedY = false;

  late String _startDir;

  @override
  void initState() {
    super.initState();
    _startDir = widget.initialStartDir; // 1. 우선 기본값으로 세팅
    _loadSavedDirection(); // 2. 🚀 기기에 저장된 방향이 있다면 무조건 덮어씌움
  }

  // 🚀 [추가됨] 앱을 껐다 켜도, 탭을 이동해도 무조건 기억하도록 로드하는 함수
  Future<void> _loadSavedDirection() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDir = prefs.getString('mobile_saved_start_dir');
    if (savedDir != null && mounted) {
      setState(() {
        _startDir = savedDir;
      });
      // 🚀 불러온 값을 부모에게도 동기화
      if (widget.onStartDirChanged != null) {
        widget.onStartDirChanged!(savedDir);
      }
    }
  }

  // 🚀 [삭제됨] 부모 위젯이 강제로 초기값으로 덮어씌우는 didUpdateWidget 로직을 제거했습니다.
  // 이제 사용자가 직접 드롭다운을 누르기 전까지는 절대 값이 바뀌지 않습니다.

  void _resetView() {
    setState(() {
      _rotationX = _defaultRotX;
      _rotationY = _defaultRotY;
      _zoomLevel = 1.0;
      _panX = 0.0;
      _panY = 0.0;
      _isFlippedX = false;
      _isFlippedY = false;
    });
  }

  void _rotateCamera() {
    setState(() {
      _rotationY -= math.pi / 2;
    });
  }

  void _toggleFlipX() {
    setState(() => _isFlippedX = !_isFlippedX);
  }

  void _toggleFlipY() {
    setState(() => _isFlippedY = !_isFlippedY);
  }

  void _onScaleStart(ScaleStartDetails details) {
    _baseZoom = _zoomLevel;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      if (details.scale == 1.0) {
        _panX += details.focalPointDelta.dx;
        _panY += details.focalPointDelta.dy;
      } else {
        _zoomLevel = (_baseZoom * details.scale).clamp(0.2, 10.0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 🌟 1. 도면 렌더링 (제스처 컨트롤 포함)
        GestureDetector(
          onScaleStart: widget.isLightMode ? null : _onScaleStart,
          onScaleUpdate: widget.isLightMode ? null : _onScaleUpdate,
          onDoubleTap: widget.isLightMode ? null : _resetView,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: widget.isLightMode
                ? Colors.transparent
                : const Color(0xFF151B22),
            child: CustomPaint(
              painter: MobileIsoPipePainter(
                bendList: widget.bendList,
                tailLength: widget.tailLength,
                rotationX: _rotationX,
                rotationY: _rotationY,
                zoomLevel: _zoomLevel,
                panX: _panX,
                panY: _panY,
                isFlippedX: _isFlippedX,
                isFlippedY: _isFlippedY,
                startDirection: _startDir, // 현재 선택된 방향 주입
                selectedSegmentIndex: widget.selectedSegmentIndex,
                isLightMode: widget.isLightMode,
                startFit: widget.startFit,
                endFit: widget.endFit,
              ),
            ),
          ),
        ),

        // 🌟 2. 좌측 상단: 시작 방향 변경 컨트롤러
        Positioned(top: 16, left: 16, child: _buildStartDirSelector()),

        // 🌟 3. 우측 상단: 총 컷팅 기장 표시 뱃지
        if (widget.totalCutLength > 0)
          Positioned(top: 16, right: 16, child: _buildTotalCutBadge()),

        // 🌟 4. 모바일 전용 컴팩트 컨트롤러 (하단 중앙 플로팅 바)
        if (!widget.isLightMode)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2B3643).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildIconBtn(
                      Icons.swap_vert,
                      _isFlippedY ? Colors.redAccent : Colors.white,
                      _toggleFlipY,
                    ),
                    _buildDivider(),
                    _buildIconBtn(
                      Icons.swap_horiz,
                      _isFlippedX ? Colors.redAccent : Colors.white,
                      _toggleFlipX,
                    ),
                    _buildDivider(),
                    _buildIconBtn(
                      Icons.rotate_90_degrees_cw,
                      Colors.white,
                      _rotateCamera,
                    ),
                    _buildDivider(),
                    _buildIconBtn(
                      Icons.remove_circle_outline,
                      Colors.white70,
                      () => setState(
                        () => _zoomLevel = (_zoomLevel - 0.2).clamp(0.2, 10.0),
                      ),
                    ),
                    const SizedBox(width: 4),
                    _buildIconBtn(
                      Icons.add_circle_outline,
                      Colors.white70,
                      () => setState(
                        () => _zoomLevel = (_zoomLevel + 0.2).clamp(0.2, 10.0),
                      ),
                    ),
                    _buildDivider(),
                    _buildIconBtn(Icons.refresh, makitaTeal, _resetView),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // 🚀 좌측 상단: 시작 방향 드롭다운 위젯
  Widget _buildStartDirSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: widget.isLightMode
            ? Colors.white.withValues(alpha: 0.9)
            : const Color(0xFF2B3643).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
        border: Border.all(
          color: widget.isLightMode ? Colors.grey.shade300 : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "시작 방향:",
            style: TextStyle(
              fontSize: 12,
              color: widget.isLightMode ? Colors.black54 : Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _startDir,
              isDense: true,
              dropdownColor: widget.isLightMode
                  ? Colors.white
                  : const Color(0xFF2B3643),
              icon: Icon(
                Icons.arrow_drop_down,
                color: widget.isLightMode ? Colors.black87 : Colors.white,
              ),
              style: TextStyle(
                color: widget.isLightMode ? Colors.black87 : Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              items: ['UP', 'DOWN', 'LEFT', 'RIGHT', 'FRONT', 'BACK'].map((
                dir,
              ) {
                return DropdownMenuItem(value: dir, child: Text(dir));
              }).toList(),
              // 🚀 [수정됨] 사용자가 방향을 바꿀 때 무조건 기기에 영구 저장합니다.
              onChanged: (val) async {
                if (val != null) {
                  setState(() => _startDir = val);

                  // 🚀 기기 내부에 저장
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('mobile_saved_start_dir', val);

                  if (widget.onStartDirChanged != null) {
                    widget.onStartDirChanged!(val);
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // 🚀 우측 상단: 총 컷팅 기장 뱃지 위젯
  Widget _buildTotalCutBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isLightMode
            ? Colors.white.withValues(alpha: 0.9)
            : const Color(0xFF2B3643).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
        border: Border.all(
          color: widget.isLightMode ? Colors.grey.shade300 : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.straighten, size: 14, color: makitaTeal),
          const SizedBox(width: 6),
          Text(
            "총 기장: ",
            style: TextStyle(
              fontSize: 12,
              color: widget.isLightMode ? Colors.black54 : Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            "${widget.totalCutLength.round()} mm",
            style: TextStyle(
              fontSize: 13,
              color: widget.isLightMode
                  ? Colors.red.shade700
                  : Colors.redAccent,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 20,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.white24,
    );
  }
}

// =========================================================
// 🚀 아래부터는 태블릿과 충돌하지 않도록 이름이 변경된 렌더링 클래스들
// =========================================================

abstract class MobileRenderable {
  double get z;
  void draw(
    Canvas canvas,
    Paint pipePaint,
    Paint highlightPaint,
    Paint outlinePaint,
  );
}

class MobileFittingRenderable implements MobileRenderable {
  final Offset p1, p2;
  @override
  final double z;
  final bool isLightMode;

  MobileFittingRenderable(this.p1, this.p2, this.z, {this.isLightMode = false});

  @override
  void draw(
    Canvas canvas,
    Paint pipePaint,
    Paint highlightPaint,
    Paint outlinePaint,
  ) {
    double sf = isLightMode ? 1.2 : 1.0;
    final fitPaint = Paint()
      ..color = isLightMode ? Colors.blueGrey.shade300 : const Color(0xFF90A4AE)
      ..strokeWidth = 14.0 * sf
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fitOutline = Paint()
      ..color = isLightMode ? Colors.black87 : Colors.black54
      ..strokeWidth = 18.0 * sf
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(p1, p2, fitOutline);
    canvas.drawLine(p1, p2, fitPaint);
  }
}

class MobileSegmentRenderable implements MobileRenderable {
  final Offset p1, p2;
  @override
  final double z;
  final bool isSelected;
  final bool isLightMode;

  MobileSegmentRenderable(
    this.p1,
    this.p2,
    this.z, {
    this.isSelected = false,
    this.isLightMode = false,
  });

  @override
  void draw(
    Canvas canvas,
    Paint pipePaint,
    Paint highlightPaint,
    Paint outlinePaint,
  ) {
    double sf = isLightMode ? 1.2 : 1.0;
    canvas.drawLine(p1, p2, outlinePaint);
    canvas.drawLine(p1, p2, isSelected ? highlightPaint : pipePaint);

    double dx = p2.dx - p1.dx;
    double dy = p2.dy - p1.dy;
    double length = math.sqrt(dx * dx + dy * dy);

    if (length > 15 * sf) {
      double arrowSize = 6.0 * sf;
      double lineAngle = math.atan2(dy, dx);
      Offset mid = Offset(p1.dx + dx * 0.55, p1.dy + dy * 0.55);

      Offset arrowP1 = Offset(
        mid.dx - arrowSize * math.cos(lineAngle - math.pi / 6),
        mid.dy - arrowSize * math.sin(lineAngle - math.pi / 6),
      );
      Offset arrowP2 = Offset(
        mid.dx - arrowSize * math.cos(lineAngle + math.pi / 6),
        mid.dy - arrowSize * math.sin(lineAngle + math.pi / 6),
      );

      Path arrowPath = Path()
        ..moveTo(mid.dx, mid.dy)
        ..lineTo(arrowP1.dx, arrowP1.dy)
        ..lineTo(arrowP2.dx, arrowP2.dy)
        ..close();
      Paint arrowPaint = Paint()
        ..color = isLightMode
            ? (isSelected ? Colors.black : Colors.black87)
            : (isSelected ? Colors.white : Colors.white.withValues(alpha: 0.8))
        ..style = PaintingStyle.fill;

      canvas.drawPath(arrowPath, arrowPaint);
    }
  }
}

class MobileDashedLineRenderable implements MobileRenderable {
  final Offset p1, p2;
  @override
  final double z;
  final bool isLightMode;

  MobileDashedLineRenderable(
    this.p1,
    this.p2,
    this.z, {
    this.isLightMode = false,
  });

  @override
  void draw(
    Canvas canvas,
    Paint pipePaint,
    Paint highlightPaint,
    Paint outlinePaint,
  ) {
    double sf = isLightMode ? 1.2 : 1.0;
    final dashPaint = Paint()
      ..color = isLightMode
          ? Colors.orange.shade800
          : Colors.amberAccent.withValues(alpha: 0.9)
      ..strokeWidth = 2.5 * sf
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    double dx = p2.dx - p1.dx;
    double dy = p2.dy - p1.dy;
    double distance = math.sqrt(dx * dx + dy * dy);

    if (distance <= 0) return;

    double dashWidth = 10.0 * sf;
    double dashSpace = 8.0 * sf;
    double unitDx = dx / distance;
    double unitDy = dy / distance;
    double startX = p1.dx;
    double startY = p1.dy;
    double drawn = 0.0;

    while (drawn < distance) {
      double nextDraw = math.min(dashWidth, distance - drawn);
      double endX = startX + unitDx * nextDraw;
      double endY = startY + unitDy * nextDraw;
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), dashPaint);
      drawn += nextDraw + dashSpace;
      startX = endX + unitDx * dashSpace;
      startY = endY + unitDy * dashSpace;
    }

    double arrowSize = 8.0 * sf;
    double lineAngle = math.atan2(dy, dx);
    Offset arrowP1 = Offset(
      p2.dx - arrowSize * math.cos(lineAngle - math.pi / 6),
      p2.dy - arrowSize * math.sin(lineAngle - math.pi / 6),
    );
    Offset arrowP2 = Offset(
      p2.dx - arrowSize * math.cos(lineAngle + math.pi / 6),
      p2.dy - arrowSize * math.sin(lineAngle + math.pi / 6),
    );

    Path arrowPath = Path()
      ..moveTo(p2.dx, p2.dy)
      ..lineTo(arrowP1.dx, arrowP1.dy)
      ..lineTo(arrowP2.dx, arrowP2.dy)
      ..close();
    canvas.drawPath(
      arrowPath,
      Paint()
        ..color = isLightMode ? Colors.orange.shade800 : Colors.amberAccent
        ..style = PaintingStyle.fill,
    );
  }
}

class MobileLabelRenderable implements MobileRenderable {
  final Offset centerPos;
  @override
  final double z;
  final String text;
  final bool isStraightPipe;
  final bool isSelected;
  final bool isLightMode;
  final bool isStartLabel;

  MobileLabelRenderable(
    this.centerPos,
    this.z,
    this.text, {
    this.isStraightPipe = false,
    this.isSelected = false,
    this.isLightMode = false,
    this.isStartLabel = false,
  });

  @override
  void draw(
    Canvas canvas,
    Paint pipePaint,
    Paint highlightPaint,
    Paint outlinePaint,
  ) {
    double sf = isLightMode ? 1.2 : 1.0;

    Color textColor = isStartLabel
        ? (isLightMode ? Colors.red.shade800 : Colors.redAccent)
        : (isStraightPipe
              ? (isLightMode ? Colors.black87 : Colors.white70)
              : (isLightMode ? Colors.black : Colors.white));
    double baseFontSize = isStartLabel
        ? 12.0
        : (isStraightPipe ? 11.0 : (isSelected ? 20.0 : 16.0));
    double fontSize = baseFontSize * sf;

    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: textColor,
        fontSize: fontSize,
        fontWeight: isStartLabel
            ? FontWeight.w900
            : (isStraightPipe ? FontWeight.bold : FontWeight.w900),
        letterSpacing: isStartLabel ? 1.0 * sf : 0.0,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    Offset drawPos = Offset(
      centerPos.dx - (textPainter.width / 2),
      centerPos.dy - (textPainter.height / 2),
    );
    double padX = (isStraightPipe ? 4.0 : 8.0) * sf;
    double padY = (isStraightPipe ? 2.0 : 4.0) * sf;
    final rect = Rect.fromLTWH(
      drawPos.dx - padX,
      drawPos.dy - padY,
      textPainter.width + padX * 2,
      textPainter.height + padY * 2,
    );
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular((isStraightPipe ? 4.0 : 8.0) * sf),
    );

    Color bgColor = isStartLabel
        ? (isLightMode
              ? Colors.white.withValues(alpha: 0.8)
              : const Color(0xFF151B22).withValues(alpha: 0.8))
        : (isStraightPipe
              ? (isLightMode
                    ? Colors.white70
                    : Colors.grey.shade800.withValues(alpha: 0.7))
              : (isSelected
                    ? Colors.orange.shade400
                    : (isLightMode
                          ? Colors.white
                          : const Color(0xFF151B22).withValues(alpha: 0.95))));
    Color borderColor = isStartLabel
        ? (isLightMode
              ? Colors.red.shade200
              : Colors.red.shade900.withValues(alpha: 0.5))
        : (isStraightPipe
              ? Colors.grey.shade600
              : (isSelected
                    ? Colors.orange.shade800
                    : (isLightMode ? Colors.black54 : Colors.grey.shade600)));

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = bgColor
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = (isStraightPipe ? 1.0 : 1.5) * sf,
    );
    textPainter.paint(canvas, drawPos);
  }
}

class MobileIsoPipePainter extends CustomPainter {
  final List<Map<String, dynamic>> bendList;
  final double tailLength;
  final double rotationX;
  final double rotationY;
  final double zoomLevel;
  final double panX;
  final double panY;
  final bool isFlippedX;
  final bool isFlippedY;
  final String startDirection;
  final int? selectedSegmentIndex;
  final bool isLightMode;
  final bool startFit;
  final bool endFit;

  MobileIsoPipePainter({
    required this.bendList,
    this.tailLength = 0.0,
    required this.rotationX,
    required this.rotationY,
    required this.zoomLevel,
    required this.panX,
    required this.panY,
    required this.isFlippedX,
    required this.isFlippedY,
    required this.startDirection,
    this.selectedSegmentIndex,
    required this.isLightMode,
    required this.startFit,
    required this.endFit,
  });

  double _getVisualLength(double realLength) {
    if (realLength <= 0) return 0.0;
    return 40.0 + math.pow(realLength, 0.5) * 6.0;
  }

  vmath.Vector3 _getAbsoluteDirection(double rot) {
    if (rot == 0.0) return vmath.Vector3(0, 1, 0);
    if (rot == 90.0) return vmath.Vector3(1, 0, 0);
    if (rot == 180.0) return vmath.Vector3(0, -1, 0);
    if (rot == 270.0) return vmath.Vector3(-1, 0, 0);
    if (rot == 360.0) return vmath.Vector3(0, 0, 1);
    if (rot == 450.0) return vmath.Vector3(0, 0, -1);
    return vmath.Vector3(1, 0, 0);
  }

  vmath.Vector3 _getStartVector() {
    switch (startDirection) {
      case 'UP':
        return vmath.Vector3(0, 1, 0);
      case 'DOWN':
        return vmath.Vector3(0, -1, 0);
      case 'LEFT':
        return vmath.Vector3(-1, 0, 0);
      case 'FRONT':
        return vmath.Vector3(0, 0, 1);
      case 'BACK':
        return vmath.Vector3(0, 0, -1);
      case 'RIGHT':
      default:
        return vmath.Vector3(1, 0, 0);
    }
  }

  void _drawBlueprintGrid(Canvas canvas, Size size, double sf) {
    final minorPaint = Paint()
      ..color = isLightMode ? Colors.grey.shade200 : const Color(0xFF202A36)
      ..strokeWidth = 1.0 * sf;
    final majorPaint = Paint()
      ..color = isLightMode ? Colors.grey.shade300 : const Color(0xFF2C3948)
      ..strokeWidth = 1.5 * sf;
    double step = 30.0 * sf;
    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i, size.height),
        i % (step * 5) == 0 ? majorPaint : minorPaint,
      );
    }
    for (double i = 0; i < size.height; i += step) {
      canvas.drawLine(
        Offset(0, i),
        Offset(size.width, i),
        i % (step * 5) == 0 ? majorPaint : minorPaint,
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    double sf = isLightMode ? 1.2 : 1.0;
    _drawBlueprintGrid(canvas, size, sf);

    List<vmath.Vector3> pts3D = [];
    vmath.Vector3 currentPos = vmath.Vector3.zero();
    pts3D.add(currentPos.clone());
    vmath.Vector3 currentDir = _getStartVector();

    List<int> internalMarkNums = [];
    int currentMarkNum = 1;
    for (int i = 0; i < bendList.length; i++) {
      double angle = (bendList[i]['angle'] as num?)?.toDouble() ?? 0.0;
      if (angle == 0.0) {
        internalMarkNums.add(0);
      } else {
        internalMarkNums.add(currentMarkNum);
        currentMarkNum++;
      }
    }

    for (int i = 0; i < bendList.length; i++) {
      var bend = bendList[i];
      double realL = (bend['length'] as num?)?.toDouble() ?? 0.0;
      double angle = (bend['angle'] as num?)?.toDouble() ?? 0.0;
      double rot = (bend['rotation'] as num?)?.toDouble() ?? 0.0;
      double visL = _getVisualLength(realL);

      currentPos += (currentDir * visL);
      pts3D.add(currentPos.clone());

      if (angle > 0) {
        vmath.Vector3 targetDir = _getAbsoluteDirection(rot);
        vmath.Vector3 bendAxis = currentDir.cross(targetDir);

        if (bendAxis.length2 > 0.001) {
          bendAxis.normalize();
          vmath.Quaternion bendQuat = vmath.Quaternion.axisAngle(
            bendAxis,
            -angle * math.pi / 180.0,
          );
          currentDir = bendQuat.rotate(currentDir)..normalize();
        } else {
          if (currentDir.dot(targetDir) < -0.9) {
            vmath.Vector3 fallback = vmath.Vector3(0, 0, 1);
            if (currentDir.cross(fallback).length2 < 0.001) {
              fallback = vmath.Vector3(0, 1, 0);
            }
            bendAxis = currentDir.cross(fallback)..normalize();
            vmath.Quaternion bendQuat = vmath.Quaternion.axisAngle(
              bendAxis,
              -angle * math.pi / 180.0,
            );
            currentDir = bendQuat.rotate(currentDir)..normalize();
          }
        }
      }
    }

    if (tailLength > 0) {
      double visTail = _getVisualLength(tailLength);
      currentPos += (currentDir * visTail);
      pts3D.add(currentPos.clone());
    }

    vmath.Vector3 center3D = _calculateCenter(pts3D);
    double maxRadius = _calculateMaxRadius(pts3D, center3D);
    double scale =
        (math.min(size.width, size.height) * 0.4) / maxRadius * zoomLevel;

    vmath.Matrix4 cameraMatrix = vmath.Matrix4.identity()
      ..rotateX(rotationX)
      ..rotateY(rotationY);
    List<vmath.Vector3> projectedPts = [];
    for (var p in pts3D) {
      vmath.Vector3 translated = p - center3D;
      projectedPts.add(cameraMatrix.transformed3(translated));
    }

    Offset to2D(vmath.Vector3 p) {
      double finalX = isFlippedX ? -p.x : p.x;
      double finalY = isFlippedY ? -p.y : p.y;
      return Offset(
        finalX * scale + size.width / 2 + panX,
        -finalY * scale + size.height / 2 + panY,
      );
    }

    List<MobileRenderable> renderQueue = [];
    List<MobileLabelRenderable> labelQueue = [];

    int pipeEndIndex = projectedPts.length - 1;

    for (int i = 0; i < pipeEndIndex; i++) {
      double zAvg = (projectedPts[i].z + projectedPts[i + 1].z) / 2;
      bool isSelected = selectedSegmentIndex == i;

      Offset p1_2d = to2D(projectedPts[i]);
      Offset p2_2d = to2D(projectedPts[i + 1]);

      renderQueue.add(
        MobileSegmentRenderable(
          p1_2d,
          p2_2d,
          zAvg,
          isSelected: isSelected,
          isLightMode: isLightMode,
        ),
      );

      if (i < bendList.length) {
        double realL = (bendList[i]['length'] as num?)?.toDouble() ?? 0.0;
        double angle = (bendList[i]['angle'] as num?)?.toDouble() ?? 0.0;
        int mNum = internalMarkNums[i];

        if (realL > 0) {
          Offset mid = (p1_2d + p2_2d) / 2;
          double dx = p2_2d.dx - p1_2d.dx;
          double dy = p2_2d.dy - p1_2d.dy;
          double len = math.sqrt(dx * dx + dy * dy);

          Offset normal = len > 0
              ? Offset(-dy / len, dx / len)
              : const Offset(0, -1);
          if (normal.dy > 0) normal = Offset(-normal.dx, -normal.dy);
          Offset labelPos = mid + normal * (18.0 * sf);

          if (angle == 0.0) {
            labelQueue.add(
              MobileLabelRenderable(
                labelPos,
                zAvg,
                "L:${realL.toInt()}",
                isStraightPipe: true,
                isSelected: isSelected,
                isLightMode: isLightMode,
              ),
            );
          } else {
            labelQueue.add(
              MobileLabelRenderable(
                labelPos,
                zAvg,
                "$mNum",
                isStraightPipe: false,
                isSelected: isSelected,
                isLightMode: isLightMode,
              ),
            );
          }
        }
      }
    }

    double fitVisualLen = 20.0;
    if (pts3D.length > 1) {
      if (startFit) {
        vmath.Vector3 dir = (pts3D[1] - pts3D[0])..normalize();
        vmath.Vector3 fitEnd =
            pts3D[0] +
            dir * math.min(fitVisualLen, pts3D[0].distanceTo(pts3D[1]));
        vmath.Vector3 projStart = cameraMatrix.transformed3(
          pts3D[0] - center3D,
        );
        vmath.Vector3 projEnd = cameraMatrix.transformed3(fitEnd - center3D);
        renderQueue.add(
          MobileFittingRenderable(
            to2D(projStart),
            to2D(projEnd),
            ((projStart.z + projEnd.z) / 2) - 0.1,
            isLightMode: isLightMode,
          ),
        );
      }
      if (endFit) {
        int last = pipeEndIndex;
        vmath.Vector3 dir = (pts3D[last - 1] - pts3D[last])..normalize();
        vmath.Vector3 fitEnd =
            pts3D[last] +
            dir *
                math.min(fitVisualLen, pts3D[last].distanceTo(pts3D[last - 1]));
        vmath.Vector3 projStart = cameraMatrix.transformed3(
          pts3D[last] - center3D,
        );
        vmath.Vector3 projEnd = cameraMatrix.transformed3(fitEnd - center3D);
        renderQueue.add(
          MobileFittingRenderable(
            to2D(projStart),
            to2D(projEnd),
            ((projStart.z + projEnd.z) / 2) - 0.1,
            isLightMode: isLightMode,
          ),
        );
      }
    }

    for (int i = 0; i <= pipeEndIndex; i++) {
      if (i == 0) {
        Offset nodePos = to2D(projectedPts[i]);
        labelQueue.add(
          MobileLabelRenderable(
            nodePos + Offset(0, -30.0 * sf),
            projectedPts[i].z - 0.1,
            "START",
            isStartLabel: true,
            isLightMode: isLightMode,
          ),
        );
      }
    }

    vmath.Vector3 translatedEnd =
        (currentPos + currentDir * (150.0 / scale)) - center3D;
    vmath.Vector3 pEndDir = cameraMatrix.transformed3(translatedEnd);
    Offset pEndDir2D = to2D(pEndDir);
    Offset pCurrentPos2D = to2D(projectedPts.last);
    double zAvgDir = (projectedPts.last.z + pEndDir.z) / 2;

    renderQueue.add(
      MobileDashedLineRenderable(
        pCurrentPos2D,
        pEndDir2D,
        zAvgDir,
        isLightMode: isLightMode,
      ),
    );

    renderQueue.sort((a, b) => b.z.compareTo(a.z));
    labelQueue.sort((a, b) => b.z.compareTo(a.z));

    final pipePaint = Paint()
      ..color = isLightMode ? const Color(0xFF455A64) : const Color(0xFF607D8B)
      ..strokeWidth = 6.0 * sf
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final highlightPaint = Paint()
      ..color = Colors.orange.shade500
      ..strokeWidth = 8.0 * sf
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final outlinePaint = Paint()
      ..color = isLightMode ? Colors.black87 : Colors.black45
      ..strokeWidth = 8.0 * sf
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    _drawAxisGuide(canvas, cameraMatrix, to2D, scale, sf);
    for (var item in renderQueue) {
      item.draw(canvas, pipePaint, highlightPaint, outlinePaint);
    }
    for (var label in labelQueue) {
      label.draw(canvas, pipePaint, highlightPaint, outlinePaint);
    }
  }

  vmath.Vector3 _calculateCenter(List<vmath.Vector3> pts) {
    double minX = double.infinity,
        maxX = -double.infinity,
        minY = double.infinity,
        maxY = -double.infinity,
        minZ = double.infinity,
        maxZ = -double.infinity;
    for (var p in pts) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
      if (p.z < minZ) minZ = p.z;
      if (p.z > maxZ) maxZ = p.z;
    }
    return vmath.Vector3(
      (minX + maxX) / 2,
      (minY + maxY) / 2,
      (minZ + maxZ) / 2,
    );
  }

  double _calculateMaxRadius(List<vmath.Vector3> pts, vmath.Vector3 center) {
    double maxRadius = 10.0;
    for (var p in pts) {
      double dist = p.distanceTo(center);
      if (dist > maxRadius) maxRadius = dist;
    }
    return maxRadius;
  }

  void _drawAxisGuide(
    Canvas canvas,
    vmath.Matrix4 camMatrix,
    Offset Function(vmath.Vector3) to2D,
    double scale,
    double sf,
  ) {
    double axLen = (40.0 / scale) * sf;
    List<vmath.Vector3> axes = [
      vmath.Vector3(axLen, 0, 0),
      vmath.Vector3(0, axLen, 0),
      vmath.Vector3(0, 0, axLen),
    ];
    List<Color> axColors = [
      const Color(0xFF81C784),
      const Color(0xFFE57373),
      const Color(0xFF64B5F6),
    ];
    vmath.Vector3 originCenter = vmath.Vector3(-axLen * 2, -axLen * 2, 0);
    vmath.Vector3 projOrigin = camMatrix.transformed3(originCenter);
    for (int i = 0; i < 3; i++) {
      vmath.Vector3 endDir = camMatrix.transformed3(originCenter + axes[i]);
      canvas.drawLine(
        to2D(projOrigin),
        to2D(endDir),
        Paint()
          ..color = axColors[i].withValues(alpha: 0.8)
          ..strokeWidth = 2.0 * sf,
      );
    }
  }

  @override
  bool shouldRepaint(covariant MobileIsoPipePainter oldDelegate) {
    return oldDelegate.rotationX != rotationX ||
        oldDelegate.rotationY != rotationY ||
        oldDelegate.zoomLevel != zoomLevel ||
        oldDelegate.panX != panX ||
        oldDelegate.panY != panY ||
        oldDelegate.bendList != bendList ||
        oldDelegate.isFlippedX != isFlippedX ||
        oldDelegate.isFlippedY != isFlippedY ||
        oldDelegate.startDirection != startDirection ||
        oldDelegate.selectedSegmentIndex != selectedSegmentIndex ||
        oldDelegate.isLightMode != isLightMode ||
        oldDelegate.startFit != startFit ||
        oldDelegate.endFit != endFit;
  }
}
