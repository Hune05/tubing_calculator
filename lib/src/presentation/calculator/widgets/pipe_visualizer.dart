import 'package:flutter/material.dart';
import 'dart:math' as math;

// 💡 3D 회전 제어를 위해 StatefulWidget으로 변경
class PipeVisualizer extends StatefulWidget {
  final List<Map<String, double>> bendList;

  const PipeVisualizer({super.key, required this.bendList});

  @override
  State<PipeVisualizer> createState() => _PipeVisualizerState();
}

class _PipeVisualizerState extends State<PipeVisualizer> {
  // 🚀 터치 회전 관련 변수
  // 기본 아이소메트릭 각도는 X축 회전(상하) 약 30도(pi/6), Y축 회전(좌우) 45도(pi/4) 부근입니다.
  double _rotationX = math.pi / 6; // 상하 까딱까딱 (Pitch)
  double _rotationY = math.pi / 4; // 좌우 까딱까딱 (Yaw)

  // 🚀 너무 많이 돌아가서 어지럽지 않게 제한(Clamp) 걸기
  final double _minRotX = 0.0;
  final double _maxRotX = math.pi / 3; // 최대 60도
  final double _minRotY = -math.pi / 2; // 최소 -90도
  final double _maxRotY = math.pi; // 최대 +180도

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      // 드래그 속도 민감도 조절 (0.01 곱함)
      _rotationY -= details.delta.dx * 0.01; // 좌우 스와이프 시 Y축 기준 회전
      _rotationX -= details.delta.dy * 0.01; // 상하 스와이프 시 X축 기준 회전

      // 각도 제한 적용 (Clamp)
      _rotationX = _rotationX.clamp(_minRotX, _maxRotX);
      _rotationY = _rotationY.clamp(_minRotY, _maxRotY);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          // 🚀 제스처 감지 영역 (여기서 터치를 받아 회전각을 업데이트합니다)
          onPanUpdate: _onPanUpdate,
          child: CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: IsoPipePainter(
              bendList: widget.bendList,
              rotationX: _rotationX, // 💡 계산된 회전각을 페인터로 넘김
              rotationY: _rotationY,
            ),
          ),
        );
      },
    );
  }
}

class IsoPipePainter extends CustomPainter {
  final List<Map<String, double>> bendList;
  final double rotationX; // 💡 넘어온 상하 회전각
  final double rotationY; // 💡 넘어온 좌우 회전각

  IsoPipePainter({
    required this.bendList,
    required this.rotationX,
    required this.rotationY,
  });

  // 💡 3D 벡터 연산을 위한 헬퍼 함수들
  double _dotProduct(List<double> v1, List<double> v2) {
    return v1[0] * v2[0] + v1[1] * v2[1] + v1[2] * v2[2];
  }

  List<double> _normalize(List<double> v) {
    double mag = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
    if (mag == 0) return [0, 0, 0];
    return [v[0] / mag, v[1] / mag, v[2] / mag];
  }

  // 사용자가 입력한 회전(0~360도 및 특수축)을 3D 절대 타겟 벡터로 변환
  List<double> _getTargetVector(double rot) {
    if (rot == 360.0) return [0, 0, 1]; // FRONT (앞: Z축 양수)
    if (rot == 450.0) return [0, 0, -1]; // BACK (뒤: Z축 음수)

    // 0~359 범위는 XY 평면에서의 회전 방향 (0:UP, 90:RIGHT, 180:DOWN, 270:LEFT)
    // 2D 캔버스 특성상 Y는 아래로 갈수록 양수이므로, 0도(UP)는 -1이 되어야 함
    double rad = rot * math.pi / 180.0;
    return [math.sin(rad), -math.cos(rad), 0.0];
  }

  // 🚀 [핵심] 3D 회전 행렬을 적용하는 함수
  List<double> _rotate3D(List<double> point, double rx, double ry) {
    double x = point[0];
    double y = point[1];
    double z = point[2];

    // Y축 회전 (Yaw - 좌우 스와이프)
    double tempX = x * math.cos(ry) + z * math.sin(ry);
    double tempZ = -x * math.sin(ry) + z * math.cos(ry);
    x = tempX;
    z = tempZ;

    // X축 회전 (Pitch - 상하 스와이프)
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

    // 1. 진짜 3D 공간 좌표 및 벡터 계산
    List<List<double>> points3D = [];
    List<double> currPos = [0.0, 0.0, 0.0];
    List<double> currDir = [1.0, 0.0, 0.0]; // 💡 기계에서 나오는 기본 방향: '우(오른쪽)' 직관

    points3D.add([...currPos]); // 시작점 저장

    for (var bend in bendList) {
      double l = bend['length'] ?? 0;
      double a = bend['angle'] ?? 0;
      double rot = bend['rotation'] ?? 0;

      // [스텝 1] 현재 방향(currDir)으로 길이(L)만큼 직진하여 뻗어나감
      if (l > 0) {
        currPos[0] += currDir[0] * l;
        currPos[1] += currDir[1] * l;
        currPos[2] += currDir[2] * l;
      }
      points3D.add([...currPos]);

      // [스텝 2] 해당 노드에서 입력받은 각도(a)와 방향(rot)으로 진짜 3D 벤딩(회전) 수행
      if (a > 0) {
        double radA = a * math.pi / 180.0;
        List<double> targetVec = _getTargetVector(rot);

        // 회전 평면을 구성하기 위한 '직교 벡터(U)' 구하기 (타겟벡터 - 투영벡터)
        double dot = _dotProduct(targetVec, currDir);
        List<double> u = [
          targetVec[0] - dot * currDir[0],
          targetVec[1] - dot * currDir[1],
          targetVec[2] - dot * currDir[2],
        ];

        u = _normalize(u);

        // 안전장치: 현재 진행 방향과 꺾이는 타겟 방향이 완벽하게 일치해버릴 경우 예외 처리
        if (u[0] != 0 || u[1] != 0 || u[2] != 0) {
          // 회전 적용: 새 진행 방향 = 기존방향 * cos(a) + 수직방향 * sin(a)
          currDir = [
            currDir[0] * math.cos(radA) + u[0] * math.sin(radA),
            currDir[1] * math.cos(radA) + u[1] * math.sin(radA),
            currDir[2] * math.cos(radA) + u[2] * math.sin(radA),
          ];
          currDir = _normalize(currDir);
        }
      }
    }

    // 마지막 벤딩 이후 파이프가 뻗어나가는 '진행 꼬리' 표시
    if (bendList.isNotEmpty) {
      currPos[0] += currDir[0] * 100.0; // 시각적 확인용 100mm 꼬리
      currPos[1] += currDir[1] * 100.0;
      currPos[2] += currDir[2] * 100.0;
      points3D.add([...currPos]);
    } else {
      currPos[0] += 50.0;
      points3D.add([...currPos]);
    }

    // 2. 3D 회전 적용 및 2D 투영
    List<Offset> points2D = [];
    double minX = double.infinity, maxX = -double.infinity;
    double minY = double.infinity, maxY = -double.infinity;

    for (var p in points3D) {
      // 🚀 사용자가 드래그한 값으로 3D 공간을 회전시킵니다.
      List<double> rotatedP = _rotate3D(p, rotationX, rotationY);

      // 회전된 3D 좌표를 2D 화면 좌표(X, Y)로 투영
      double screenX = rotatedP[0];
      double screenY = rotatedP[1];

      points2D.add(Offset(screenX, screenY));
      if (screenX < minX) minX = screenX;
      if (screenX > maxX) maxX = screenX;
      if (screenY < minY) minY = screenY;
      if (screenY > maxY) maxY = screenY;
    }

    // 3. 줌(Zoom) 배율 자동 조정 및 화면 중앙 정렬
    double drawWidth = maxX - minX;
    double drawHeight = maxY - minY;
    if (drawWidth == 0) drawWidth = 1;
    if (drawHeight == 0) drawHeight = 1;

    double scaleX = (size.width * 0.7) / drawWidth;
    double scaleY = (size.height * 0.7) / drawHeight;
    double finalScale = math.min(scaleX, scaleY);

    double centerX = minX + (drawWidth / 2);
    double centerY = minY + (drawHeight / 2);
    double screenCenterX = size.width / 2;
    double screenCenterY = size.height / 2;

    List<Offset> finalPoints = [];

    // 4. 배관 선(Line) 그리기
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

    // 5. 노드(점) 및 치수/각도 텍스트 렌더링
    for (int i = 0; i < finalPoints.length; i++) {
      if (i == 0) {
        canvas.drawCircle(finalPoints[i], 6, startNodePaint); // 출발점
      } else if (i <= bendList.length) {
        final bend = bendList[i - 1];
        double a = bend['angle'] ?? 0;
        double l = bend['length'] ?? 0;

        // L(길이)이 0 초과일 때만 직관 구간 중앙에 텍스트 표시
        if (l > 0) {
          canvas.drawCircle(finalPoints[i], 5, nodePaint);

          if (a > 0) {
            _drawText(
              canvas,
              "${a.toStringAsFixed(a % 1 == 0 ? 0 : 1)}°",
              finalPoints[i],
              Colors.amber,
              isAngle: true,
            );
          }

          Offset midPoint = Offset(
            (finalPoints[i - 1].dx + finalPoints[i].dx) / 2,
            (finalPoints[i - 1].dy + finalPoints[i].dy) / 2,
          );
          _drawText(
            canvas,
            "L:${l.toInt()}",
            midPoint,
            Colors.white,
            isAngle: false,
          );
        } else if (a > 0) {
          // 직관 전진 없이 제자리 꺾임만 일어난 지점 (각도만 표시)
          canvas.drawCircle(finalPoints[i], 5, nodePaint);
          _drawText(
            canvas,
            "${a.toStringAsFixed(a % 1 == 0 ? 0 : 1)}°",
            finalPoints[i],
            Colors.amber,
            isAngle: true,
          );
        }
      } else {
        // 마지막 꼬리 방향 가이드라인 표시
        Offset midPoint = Offset(
          (finalPoints[i - 1].dx + finalPoints[i].dx) / 2,
          (finalPoints[i - 1].dy + finalPoints[i].dy) / 2,
        );
        _drawText(canvas, "진행방향", midPoint, Colors.white30, isAngle: false);
      }
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
  // 💡 사용자가 터치할 때마다 계속 다시 그려야 하므로 true를 반환!
  bool shouldRepaint(covariant IsoPipePainter oldDelegate) {
    return oldDelegate.rotationX != rotationX ||
        oldDelegate.rotationY != rotationY;
  }
}
