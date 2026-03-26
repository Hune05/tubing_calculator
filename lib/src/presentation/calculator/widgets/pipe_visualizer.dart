import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart' as vmath;

const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate600 = Color(0xFF475569);
const Color slate100 = Color(0xFFF1F5F9);
const Color pureWhite = Color(0xFFFFFFFF);

class PipeVisualizer extends StatefulWidget {
  final List<Map<String, dynamic>> bendList;
  final double tailLength;
  final int? selectedSegmentIndex;
  final String initialStartDir;
  final ValueChanged<String>? onStartDirChanged;
  final bool isLightMode;

  final bool startFit;
  final bool endFit;

  const PipeVisualizer({
    super.key,
    required this.bendList,
    this.tailLength = 0.0,
    this.selectedSegmentIndex,
    this.initialStartDir = 'RIGHT',
    this.onStartDirChanged,
    this.isLightMode = false,
    this.startFit = false,
    this.endFit = false,
  });

  @override
  State<PipeVisualizer> createState() => _PipeVisualizerState();
}

class _PipeVisualizerState extends State<PipeVisualizer> {
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
    _startDir = widget.initialStartDir;
  }

  @override
  void didUpdateWidget(PipeVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialStartDir != widget.initialStartDir) {
      setState(() {
        _startDir = widget.initialStartDir;
      });
    }
  }

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
              painter: IsoPipePainter(
                bendList: widget.bendList,
                tailLength: widget.tailLength,
                rotationX: _rotationX,
                rotationY: _rotationY,
                zoomLevel: _zoomLevel,
                panX: _panX,
                panY: _panY,
                isFlippedX: _isFlippedX,
                isFlippedY: _isFlippedY,
                startDirection: _startDir,
                selectedSegmentIndex: widget.selectedSegmentIndex,
                isLightMode: widget.isLightMode,
                // 🚀 위젯에서 받은 피팅 정보를 페인터로 넘겨줌
                startFit: widget.startFit,
                endFit: widget.endFit,
              ),
            ),
          ),
        ),
        if (!widget.isLightMode) ...[
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF2B3643),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _startDir,
                  dropdownColor: const Color(0xFF2B3643),
                  icon: const Icon(
                    Icons.arrow_drop_down,
                    color: Colors.white70,
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() => _startDir = newValue);
                      widget.onStartDirChanged?.call(newValue);
                    }
                  },
                  items: ['RIGHT', 'LEFT', 'UP', 'DOWN', 'FRONT', 'BACK']
                      .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text('시작: $value'),
                        );
                      })
                      .toList(),
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildControlButton(
                  icon: Icons.swap_vert,
                  color: _isFlippedY
                      ? const Color(0xFFE57373)
                      : const Color(0xFF4A6572),
                  onPressed: _toggleFlipY,
                ),
                const SizedBox(height: 12),
                _buildControlButton(
                  icon: Icons.swap_horiz,
                  color: _isFlippedX
                      ? const Color(0xFFE57373)
                      : const Color(0xFF4A6572),
                  onPressed: _toggleFlipX,
                ),
                const SizedBox(height: 12),
                _buildControlButton(
                  icon: Icons.rotate_90_degrees_cw,
                  color: const Color(0xFF4A6572),
                  onPressed: _rotateCamera,
                ),
                const SizedBox(height: 12),
                _buildControlButton(
                  icon: Icons.add,
                  onPressed: () => setState(
                    () => _zoomLevel = (_zoomLevel + 0.2).clamp(0.2, 10.0),
                  ),
                ),
                const SizedBox(height: 8),
                _buildControlButton(
                  icon: Icons.remove,
                  onPressed: () => setState(
                    () => _zoomLevel = (_zoomLevel - 0.2).clamp(0.2, 10.0),
                  ),
                ),
                const SizedBox(height: 8),
                _buildControlButton(icon: Icons.refresh, onPressed: _resetView),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return FloatingActionButton(
      mini: true,
      heroTag: icon.toString(),
      backgroundColor: color ?? const Color(0xFF2B3643),
      elevation: 2,
      onPressed: onPressed,
      child: Icon(icon, color: Colors.white70, size: 20),
    );
  }
}

abstract class Renderable {
  double get z;
  void draw(
    Canvas canvas,
    Paint pipePaint,
    Paint highlightPaint,
    Paint outlinePaint,
  );
}

// 🚀 [추가] 피팅 삽입 형상을 렌더링하는 클래스
class FittingRenderable implements Renderable {
  final Offset p1, p2;
  @override
  final double z;
  final bool isLightMode;

  FittingRenderable(this.p1, this.p2, this.z, {this.isLightMode = false});

  @override
  void draw(
    Canvas canvas,
    Paint pipePaint,
    Paint highlightPaint,
    Paint outlinePaint,
  ) {
    double sf = isLightMode ? 1.2 : 1.0;

    // 피팅 재질 느낌의 컬러 세팅 (파이프보다 두꺼움)
    final fitPaint = Paint()
      ..color = isLightMode ? Colors.blueGrey.shade300 : const Color(0xFF90A4AE)
      ..strokeWidth =
          14.0 *
          sf // 파이프(6.0)보다 훨씬 두껍게
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fitOutline = Paint()
      ..color = isLightMode ? Colors.black87 : Colors.black54
      ..strokeWidth =
          18.0 *
          sf // 외곽선
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(p1, p2, fitOutline);
    canvas.drawLine(p1, p2, fitPaint);
  }
}

class SegmentRenderable implements Renderable {
  final Offset p1, p2;
  @override
  final double z;
  final bool isSelected;
  final bool isLightMode;

  SegmentRenderable(
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

class DashedLineRenderable implements Renderable {
  final Offset p1, p2;
  @override
  final double z;
  final bool isLightMode;

  DashedLineRenderable(this.p1, this.p2, this.z, {this.isLightMode = false});

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

// 🚀 EndpointNodeRenderable(동그라미) 클래스는 삭제하지 않고 남겨두었으나, paint()에서 더 이상 호출하지 않습니다.
// (나중에 필요할까 봐 클래스만 유지했습니다)

class LabelRenderable implements Renderable {
  final Offset centerPos;
  @override
  final double z;
  final String text;
  final bool isStraightPipe;
  final bool isSelected;
  final bool isLightMode;
  final bool isStartLabel;

  LabelRenderable(
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

    Color textColor;
    if (isStartLabel) {
      textColor = isLightMode ? Colors.red.shade800 : Colors.redAccent;
    } else {
      textColor = isStraightPipe
          ? (isLightMode ? Colors.black87 : Colors.white70)
          : (isLightMode ? Colors.black : Colors.white);
    }

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

    Color bgColor;
    Color borderColor;

    if (isStartLabel) {
      bgColor = isLightMode
          ? Colors.white.withValues(alpha: 0.8)
          : const Color(0xFF151B22).withValues(alpha: 0.8);
      borderColor = isLightMode
          ? Colors.red.shade200
          : Colors.red.shade900.withValues(alpha: 0.5);
    } else {
      bgColor = isStraightPipe
          ? (isLightMode
                ? Colors.white70
                : Colors.grey.shade800.withValues(alpha: 0.7))
          : (isSelected
                ? Colors.orange.shade400
                : (isLightMode
                      ? Colors.white
                      : const Color(0xFF151B22).withValues(alpha: 0.95)));
      borderColor = isStraightPipe
          ? Colors.grey.shade600
          : (isSelected
                ? Colors.orange.shade800
                : (isLightMode ? Colors.black54 : Colors.grey.shade600));
    }

    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = (isStraightPipe ? 1.0 : 1.5) * sf;

    canvas.drawRRect(rrect, bgPaint);
    canvas.drawRRect(rrect, borderPaint);
    textPainter.paint(canvas, drawPos);
  }
}

class IsoPipePainter extends CustomPainter {
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

  // 🚀 페인터가 피팅 여부를 알 수 있게 추가
  final bool startFit;
  final bool endFit;

  IsoPipePainter({
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
      double angle = (bendList[i]['angle'] ?? 0).toDouble();
      if (angle == 0.0) {
        internalMarkNums.add(0);
      } else {
        internalMarkNums.add(currentMarkNum);
        currentMarkNum++;
      }
    }

    for (int i = 0; i < bendList.length; i++) {
      var bend = bendList[i];
      double realL = (bend['length'] ?? 0).toDouble();
      double angle = (bend['angle'] ?? 0).toDouble();
      double rot = (bend['rotation'] ?? 0).toDouble();
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
            if (currentDir.cross(fallback).length2 < 0.001)
              fallback = vmath.Vector3(0, 1, 0);
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

    List<Renderable> renderQueue = [];
    List<LabelRenderable> labelQueue = [];

    int pipeEndIndex = projectedPts.length - 1;

    for (int i = 0; i < pipeEndIndex; i++) {
      double zAvg = (projectedPts[i].z + projectedPts[i + 1].z) / 2;
      bool isSelected = selectedSegmentIndex == i;

      Offset p1_2d = to2D(projectedPts[i]);
      Offset p2_2d = to2D(projectedPts[i + 1]);

      renderQueue.add(
        SegmentRenderable(
          p1_2d,
          p2_2d,
          zAvg,
          isSelected: isSelected,
          isLightMode: isLightMode,
        ),
      );

      if (i < bendList.length) {
        double realL = bendList[i]['length']?.toDouble() ?? 0.0;
        double angle = bendList[i]['angle']?.toDouble() ?? 0.0;
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
              LabelRenderable(
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
              LabelRenderable(
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

    // 🚀 [추가] 3D 벡터를 계산하여 피팅 형상(두꺼운 파이프 껍데기) 삽입
    double fitVisualLen = 20.0; // 화면에 그려질 피팅의 길이(깊이)

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

        // Z값을 약간 깎아서 튜브보다 위(카메라 쪽)에 렌더링되게 덮어씌움
        renderQueue.add(
          FittingRenderable(
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
          FittingRenderable(
            to2D(projStart),
            to2D(projEnd),
            ((projStart.z + projEnd.z) / 2) - 0.1,
            isLightMode: isLightMode,
          ),
        );
      }
    }

    // 🚀 [수정] 시작/끝단 동그라미(원) 렌더링을 삭제하고, START 글자만 남김
    for (int i = 0; i <= pipeEndIndex; i++) {
      Offset nodePos = to2D(projectedPts[i]);

      if (i == 0) {
        // 기존 원 그리기 코드(EndpointNodeRenderable) 제거!
        labelQueue.add(
          LabelRenderable(
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
      DashedLineRenderable(
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
  bool shouldRepaint(covariant IsoPipePainter oldDelegate) {
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
        oldDelegate.startFit != startFit || // 🚀 피팅 값이 변하면 다시 그림
        oldDelegate.endFit != endFit; // 🚀
  }
}
