import 'package:flutter/material.dart';
import 'dart:math' as math;

class PipeVisualizer extends StatefulWidget {
  // 데이터가 dynamic으로 들어올 수도 있으니 유연하게 대처하기 위해 유지
  final List<Map<String, dynamic>> bendList;

  const PipeVisualizer({super.key, required this.bendList});

  @override
  State<PipeVisualizer> createState() => _PipeVisualizerState();
}

class _PipeVisualizerState extends State<PipeVisualizer> {
  // 기본 아이소메트릭 각도
  static const double _defaultRotX = math.pi / 6;
  static const double _defaultRotY = math.pi / 4;

  double _rotationX = _defaultRotX;
  double _rotationY = _defaultRotY;

  // 회전 제한(Clamp)
  final double _minRotX = _defaultRotX - 0.7;
  final double _maxRotX = _defaultRotX + 0.7;
  final double _minRotY = _defaultRotY - 1.2;
  final double _maxRotY = _defaultRotY + 1.2;

  // 🚀 줌 관련 변수
  double _zoomLevel = 1.0;
  double _baseZoom = 1.0;

  // 초기화(리프레시) 함수
  void _resetView() {
    setState(() {
      _rotationX = _defaultRotX;
      _rotationY = _defaultRotY;
      _zoomLevel = 1.0;
    });
  }

  void _zoomIn() {
    setState(() {
      _zoomLevel = (_zoomLevel + 0.2).clamp(0.5, 5.0);
    });
  }

  void _zoomOut() {
    setState(() {
      _zoomLevel = (_zoomLevel - 0.2).clamp(0.5, 5.0);
    });
  }

  void _onScaleStart(ScaleStartDetails details) {
    _baseZoom = _zoomLevel;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      // 1. 회전 처리
      _rotationY -= details.focalPointDelta.dx * 0.008;
      _rotationX -= details.focalPointDelta.dy * 0.008;

      _rotationX = _rotationX.clamp(_minRotX, _maxRotX);
      _rotationY = _rotationY.clamp(_minRotY, _maxRotY);

      // 2. 줌 처리
      if (details.scale != 1.0) {
        _zoomLevel = (_baseZoom * details.scale).clamp(0.5, 5.0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
              onDoubleTap: _resetView,
              child: Container(
                color: Colors.transparent,
                child: CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: IsoPipePainter(
                    bendList: widget.bendList,
                    rotationX: _rotationX,
                    rotationY: _rotationY,
                    zoomLevel: _zoomLevel,
                  ),
                ),
              ),
            );
          },
        ),
        // 우측 하단 줌 및 초기화 버튼
        Positioned(
          right: 16,
          bottom: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton(
                mini: true,
                heroTag: "btn_zoom_in",
                backgroundColor: Colors.black54,
                elevation: 0,
                onPressed: _zoomIn,
                child: const Icon(Icons.add, color: Colors.white),
              ),
              const SizedBox(height: 8),
              FloatingActionButton(
                mini: true,
                heroTag: "btn_zoom_out",
                backgroundColor: Colors.black54,
                elevation: 0,
                onPressed: _zoomOut,
                child: const Icon(Icons.remove, color: Colors.white),
              ),
              const SizedBox(height: 8),
              FloatingActionButton(
                mini: true,
                heroTag: "btn_reset",
                backgroundColor: Colors.black54,
                elevation: 0,
                onPressed: _resetView,
                child: const Icon(Icons.refresh, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class IsoPipePainter extends CustomPainter {
  final List<Map<String, dynamic>> bendList;
  final double rotationX;
  final double rotationY;
  final double zoomLevel;

  IsoPipePainter({
    required this.bendList,
    required this.rotationX,
    required this.rotationY,
    required this.zoomLevel,
  });

  double _dotProduct(List<double> v1, List<double> v2) {
    return v1[0] * v2[0] + v1[1] * v2[1] + v1[2] * v2[2];
  }

  List<double> _normalize(List<double> v) {
    double mag = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
    if (mag == 0) return [0, 0, 0];
    return [v[0] / mag, v[1] / mag, v[2] / mag];
  }

  List<double> _getTargetVector(double rot) {
    if (rot == 360.0) return [0, 0, 1];
    if (rot == 450.0) return [0, 0, -1];
    double rad = rot * math.pi / 180.0;
    return [math.sin(rad), -math.cos(rad), 0.0];
  }

  List<double> _rotate3D(List<double> point, double rx, double ry) {
    double x = point[0];
    double y = point[1];
    double z = point[2];

    double tempX = x * math.cos(ry) + z * math.sin(ry);
    double tempZ = -x * math.sin(ry) + z * math.cos(ry);
    x = tempX;
    z = tempZ;

    double tempY = y * math.cos(rx) - z * math.sin(rx);
    tempZ = y * math.sin(rx) + z * math.cos(rx);
    y = tempY;
    z = tempZ;

    return [x, y, z];
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final pipePaint = Paint()
      ..color = const Color(0xFF007580)
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final nodePaint = Paint()
      ..color = Colors.amber
      ..style = PaintingStyle.fill;
    final startNodePaint = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.fill;

    List<List<double>> points3D = [];
    List<double> currPos = [0.0, 0.0, 0.0];
    List<double> currDir = [1.0, 0.0, 0.0];

    points3D.add([...currPos]);

    // 🚀 [안전장치 1] 메인 루프: 데이터 파싱 시 .toDouble() 적용
    for (var bend in bendList) {
      double l = bend['length']?.toDouble() ?? 0.0;
      double a = bend['angle']?.toDouble() ?? 0.0;
      double? rotVal = bend['rotation']?.toDouble();

      if (a == 0 && rotVal != null) {
        currDir = _getTargetVector(rotVal);
      }

      if (l > 0) {
        currPos[0] += currDir[0] * l;
        currPos[1] += currDir[1] * l;
        currPos[2] += currDir[2] * l;
      }
      points3D.add([...currPos]);

      if (a > 0 && rotVal != null) {
        double radA = a * math.pi / 180.0;
        List<double> targetVec = _getTargetVector(rotVal);

        double dot = _dotProduct(targetVec, currDir);
        List<double> u = [
          targetVec[0] - dot * currDir[0],
          targetVec[1] - dot * currDir[1],
          targetVec[2] - dot * currDir[2],
        ];

        u = _normalize(u);

        if (u[0] != 0 || u[1] != 0 || u[2] != 0) {
          currDir = [
            currDir[0] * math.cos(radA) + u[0] * math.sin(radA),
            currDir[1] * math.cos(radA) + u[1] * math.sin(radA),
            currDir[2] * math.cos(radA) + u[2] * math.sin(radA),
          ];
          currDir = _normalize(currDir);
        }
      }
    }

    if (bendList.isNotEmpty) {
      currPos[0] += currDir[0] * 100.0;
      currPos[1] += currDir[1] * 100.0;
      currPos[2] += currDir[2] * 100.0;
      points3D.add([...currPos]);
    } else {
      currPos[0] += 50.0;
      points3D.add([...currPos]);
    }

    List<Offset> points2D = [];
    double minX = double.infinity, maxX = -double.infinity;
    double minY = double.infinity, maxY = -double.infinity;

    for (var p in points3D) {
      List<double> rotatedP = _rotate3D(p, rotationX, rotationY);

      double screenX = rotatedP[0];
      double screenY = rotatedP[1];

      points2D.add(Offset(screenX, screenY));
      if (screenX < minX) minX = screenX;
      if (screenX > maxX) maxX = screenX;
      if (screenY < minY) minY = screenY;
      if (screenY > maxY) maxY = screenY;
    }

    double drawWidth = maxX - minX;
    double drawHeight = maxY - minY;
    if (drawWidth == 0) drawWidth = 1;
    if (drawHeight == 0) drawHeight = 1;

    double scaleX = (size.width * 0.7) / drawWidth;
    double scaleY = (size.height * 0.7) / drawHeight;

    // 계산된 스케일에 사용자가 조작한 zoomLevel 반영
    double finalScale = math.min(scaleX, scaleY) * zoomLevel;

    double centerX = minX + (drawWidth / 2);
    double centerY = minY + (drawHeight / 2);
    double screenCenterX = size.width / 2;
    double screenCenterY = size.height / 2;

    List<Offset> finalPoints = [];

    final path = Path();
    for (int i = 0; i < points2D.length; i++) {
      double finalX = (points2D[i].dx - centerX) * finalScale + screenCenterX;
      double finalY = (points2D[i].dy - centerY) * finalScale + screenCenterY;
      Offset finalPos = Offset(finalX, finalY);
      finalPoints.add(finalPos);

      if (i == 0) {
        path.moveTo(finalPos.dx, finalPos.dy);
      } else {
        path.lineTo(finalPos.dx, finalPos.dy);
      }
    }
    canvas.drawPath(path, pipePaint);

    // 🚀 [안전장치 2] 치수(Length) 텍스트 루프
    for (int i = 0; i < bendList.length; i++) {
      double l = bendList[i]['length']?.toDouble() ?? 0.0;
      if (l > 0) {
        Offset mid = Offset(
          (finalPoints[i].dx + finalPoints[i + 1].dx) / 2,
          (finalPoints[i].dy + finalPoints[i + 1].dy) / 2,
        );
        _drawText(canvas, "L:${l.toInt()}", mid, Colors.white, isAngle: false);
      }
    }

    canvas.drawCircle(finalPoints[0], 6, startNodePaint);

    // 🚀 [안전장치 3] 각도(Angle) 텍스트 루프
    for (int i = 1; i <= bendList.length; i++) {
      canvas.drawCircle(finalPoints[i], 5, nodePaint);

      if (i <= bendList.length) {
        double a = bendList[i - 1]['angle']?.toDouble() ?? 0.0;
        if (a > 0) {
          _drawText(
            canvas,
            "${a.toStringAsFixed(a % 1 == 0 ? 0 : 1)}°",
            finalPoints[i],
            Colors.amber,
            isAngle: true,
          );
        }
      }
    }

    if (finalPoints.length > bendList.length + 1) {
      Offset tailMid = Offset(
        (finalPoints[bendList.length].dx +
                finalPoints[bendList.length + 1].dx) /
            2,
        (finalPoints[bendList.length].dy +
                finalPoints[bendList.length + 1].dy) /
            2,
      );
      _drawText(canvas, "진행방향", tailMid, Colors.white30, isAngle: false);
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset position,
    Color color, {
    required bool isAngle,
  }) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: isAngle ? 14 : 11,
        fontWeight: FontWeight.bold,
        backgroundColor: Colors.black54,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    Offset offsetPos = isAngle
        ? Offset(position.dx + 8, position.dy - 10)
        : Offset(position.dx - (textPainter.width / 2), position.dy - 15);

    textPainter.paint(canvas, offsetPos);
  }

  @override
  bool shouldRepaint(covariant IsoPipePainter oldDelegate) {
    return oldDelegate.rotationX != rotationX ||
        oldDelegate.rotationY != rotationY ||
        oldDelegate.zoomLevel != zoomLevel;
  }
}
